#!/usr/bin/env bash
# Smoke test CS chat end-to-end lewat Kong: nasabah (login OLT dummy) -> cs_api
# (PostgREST) -> CS 2FA mengambil, membalas, mengalihkan, dan menyelesaikan tiket.
# Butuh: make up DUMMY_OLT=1 (Windows: .\make.ps1 up -DummyOlt).
# Batas 5 tiket baru per jam per nasabah berlaku: jangan jalankan lebih dari 5x per jam.
set -uo pipefail

BASE="${SUPABASE_URL:-http://kong:8000}"
OLT="${DUMMY_OLT_URL:-http://dummy-olt:8090}"
BODY=/tmp/smoke-cs-body
: "${ANON_KEY:?ANON_KEY wajib diisi}"
source "$(dirname "$0")/cs-lib.sh"

AGENT=5e000000-0000-4000-8000-0000000000c1
SUPERVISOR=5e000000-0000-4000-8000-0000000000c2
AGENT2=5e000000-0000-4000-8000-0000000000c3
pass=0
fail=0

json() { jq -r "$1" "$BODY"; }
uuid() { cat /proc/sys/kernel/random/uuid; }

check() {
  if eval "$2"; then
    echo "ok   - $1"
    pass=$((pass + 1))
  else
    echo "GAGAL - $1 (status ${code:-?}: $(head -c 300 "$BODY" 2>/dev/null))"
    fail=$((fail + 1))
  fi
}

login() {
  local olt_token
  olt_token=$(curl -sS -X POST "$OLT/api/login" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$1\",\"password\":\"olt12345\"}" | jq -r '.social_token // empty')
  code=$(curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
    -H 'Content-Type: application/json' -d "{\"token\":\"$olt_token\"}")
  LOGIN_JWT=$(json '.access_token // empty')
  LOGIN_ID=$(json '.user.id // empty')
}

rpc() {
  curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/rest/v1/rpc/$2" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $1" -H 'Content-Type: application/json' -H "Content-Profile: ${4:-cs_api}" -d "$3"
}

system_messages() {
  sql "select count(*) from public.messages where session_id = '$TICKET' and payload ->> 'code' = '$1'"
}

if ! curl -sf "$OLT/health" > /dev/null; then
  echo "OLT dummy tidak berjalan. Jalankan: make up DUMMY_OLT=1 (Windows: .\\make.ps1 up -DummyOlt)" >&2
  exit 1
fi

# Skenario ini menguji mode ambil tiket; mode penugasan semula dipulihkan saat selesai.
ASSIGNMENT_MODE=$(sql "select cs.setting('assignment.mode')")
restore_mode() { sql "select cs.set_setting('assignment.mode', '$ASSIGNMENT_MODE', null)" > /dev/null; }
trap restore_mode EXIT
sql "select cs.set_setting('assignment.mode', '\"claim\"', null)" > /dev/null

ensure_agent "$AGENT" "Smoke Agen" "{cs_agent}" general '{"general": 2, "account": 2}'
ensure_agent "$AGENT2" "Smoke Agen Dua" "{cs_agent}" general '{"general": 2, "account": 2}'
ensure_agent "$SUPERVISOR" "Smoke Supervisor" "{cs_super_admin}" general '{"general": 2, "account": 2}'
AGENT_JWT=$(agent_jwt "$AGENT")
AGENT2_JWT=$(agent_jwt "$AGENT2")
SUP_JWT=$(agent_jwt "$SUPERVISOR")

login budi_santoso
JWT=$LOGIN_JWT
CUSTOMER=$LOGIN_ID
check "nasabah login lewat OLT dummy" '[ -n "$JWT" ]'
sql "select cs.finalize_ticket(id, 'other') from cs.tickets where customer_id = '$CUSTOMER' and status <> 'closed'" > /dev/null

code=$(rpc "$JWT" topics '{}')
check "nasabah melihat 7 topik bantuan" '[ "$code" = 200 ] && [ "$(json length)" = 7 ]'
code=$(rpc "$JWT" open_ticket '{"p_topic":"account","p_screen":"help"}')
TICKET=$(json .id)
ROOM=$(json .room_id)
check "nasabah membuka tiket bernomor dan masuk antrean" \
  '[ "$code" = 200 ] && [ "$(json .status)" = open ] && [[ "$(json .ticket_number)" =~ ^CS-[0-9]{8}-[0-9]{4}$ ]]'
code=$(rpc "$JWT" send_message "{\"p_room_id\":\"$ROOM\",\"p_body\":\"Tidak bisa login, OTP saya 123456\",\"p_client_id\":\"$(uuid)\"}")
check "OTP di pesan nasabah disamarkan server" '[ "$code" = 200 ] && [ "$(json ".[0].body")" = "Tidak bisa login, OTP saya ******" ]'

code=$(rpc "$AGENT_JWT" agent_set_status '{"p_status":"online"}')
check "CS (2FA) online" '[ "$code" = 200 ] && [ "$(json .status)" = online ]'
rpc "$AGENT2_JWT" agent_set_status '{"p_status":"online"}' > /dev/null
code=$(rpc "$AGENT_JWT" get_my_rooms '{}' public)
check "akun CS ditolak di API sosial" '[ "$code" = 403 ] && [ "$(json .message)" = cs_staff_social_forbidden ]'
code=$(rpc "$AGENT_JWT" ticket_lists '{}')
check "tiket muncul di tab Terbuka dengan cuplikan tersamar" \
  '[ "$code" = 200 ] && [ "$(json ".open[] | select(.id == \"$TICKET\") | .preview")" = "Tidak bisa login, OTP saya ******" ]'
code=$(rpc "$AGENT_JWT" agent_send_message "{\"p_ticket_id\":\"$TICKET\",\"p_body\":\"Halo\"}")
check "CS tidak bisa membalas tiket yang belum diambil" '[ "$code" = 409 ] && [ "$(json .message)" = ticket_not_active ]'
code=$(rpc "$AGENT_JWT" claim_ticket "{\"p_ticket_id\":\"$TICKET\"}")
check "CS mengambil tiket" '[ "$code" = 200 ] && [ "$(json .status)" = claimed ] && [ "$(json .owner.id)" = "$AGENT" ]'
code=$(rpc "$AGENT2_JWT" claim_ticket "{\"p_ticket_id\":\"$TICKET\"}")
check "CS lain ditolak: 'Tiket sudah diambil oleh Smoke Agen'" \
  '[ "$code" = 409 ] && [ "$(json .details)" = "Tiket sudah diambil oleh Smoke Agen" ]'
check "nasabah diberi tahu CS yang menangani" '[ "$(system_messages ticket_claimed)" = 1 ]'
code=$(rpc "$AGENT_JWT" agent_send_message "{\"p_ticket_id\":\"$TICKET\",\"p_body\":\"Halo Pak Budi, saya bantu cek.\",\"p_client_id\":\"$(uuid)\"}")
check "CS membalas, pesan bertanda CS Resmi" '[ "$code" = 200 ] && [ "$(json .message.sender_role)" = agent ]'
code=$(rpc "$AGENT_JWT" agent_send_message "{\"p_ticket_id\":\"$TICKET\",\"p_body\":\"Mohon kirimkan kode OTP Anda\"}")
check "pesan CS yang meminta OTP diblokir" '[ "$code" = 200 ] && [ "$(json .status)" = blocked ]'
code=$(rpc "$AGENT_JWT" add_note "{\"p_ticket_id\":\"$TICKET\",\"p_body\":\"SMOKE-NOTE: cek perangkat baru\"}")
check "CS menulis catatan internal" '[ "$code" = 200 ]'
IMAGE="rooms/$ROOM/$AGENT/$(uuid).png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==' | base64 -d > /tmp/smoke-cs.png
code=$(curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/storage/v1/object/attachments/$IMAGE" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $AGENT_JWT" -H 'Content-Type: image/png' --data-binary @/tmp/smoke-cs.png)
check "CS mengunggah gambar ke room tiket yang ia tangani" '[ "$code" = 200 ]'
code=$(rpc "$AGENT_JWT" agent_send_message "{\"p_ticket_id\":\"$TICKET\",\"p_body\":\"\",\"p_client_id\":\"$(uuid)\",\"p_attachments\":[{\"path\":\"$IMAGE\",\"mime\":\"image/png\"}]}")
check "CS mengirim gambar sebagai lampiran" '[ "$code" = 200 ] && [ "$(json ".message.attachments[0].path")" = "$IMAGE" ]'
code=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/storage/v1/object/authenticated/attachments/$IMAGE" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $JWT")
check "nasabah bisa membuka lampiran dari CS" '[ "$code" = 200 ]'

code=$(rpc "$JWT" get_messages "{\"p_room_id\":\"$ROOM\",\"p_limit\":100}")
check "nasabah melihat balasan CS" \
  '[ "$(json "[.[] | select(.session_id == \"$TICKET\" and .sender_role == \"agent\" and .body != \"\")] | length")" = 1 ]'
check "catatan internal dan pesan yang diblokir tidak terlihat nasabah" \
  '[ "$(json "[.[] | select(.body | test(\"SMOKE-NOTE|kirimkan kode OTP\"))] | length")" = 0 ]'
code=$(rpc "$JWT" notes "{\"p_customer_id\":\"$CUSTOMER\"}")
check "nasabah tidak bisa memanggil API catatan" '[ "$code" = 403 ]'

code=$(rpc "$JWT" ticket_lists '{}')
check "token nasabah ditolak di API CS" '[ "$code" = 403 ]'

code=$(rpc "$AGENT_JWT" request_transfer "{\"p_ticket_id\":\"$TICKET\",\"p_to_agent_id\":\"$AGENT2\",\"p_note\":\"Lanjutkan cek perangkat\"}")
TRANSFER=$(json .id)
check "CS meminta transfer ke CS lain" '[ "$code" = 200 ] && [ -n "$TRANSFER" ]'
code=$(rpc "$AGENT2_JWT" ticket_lists '{}')
check "permintaan transfer masuk ke CS tujuan" '[ "$(json ".transfers_in[] | select(.id == \"$TRANSFER\") | .from_name")" = "Smoke Agen" ]'
code=$(rpc "$AGENT2_JWT" respond_transfer "{\"p_transfer_id\":\"$TRANSFER\",\"p_accept\":true}")
check "CS tujuan menerima transfer dan menjadi pemilik" '[ "$code" = 200 ] && [ "$(json .owner.id)" = "$AGENT2" ]'
VERSION=$(json .version)
check "nasabah diberi tahu tiket dialihkan" '[ "$(system_messages ticket_transferred)" = 1 ]'

code=$(rpc "$AGENT2_JWT" resolve_ticket "{\"p_ticket_id\":\"$TICKET\",\"p_outcome\":\"answered\",\"p_summary\":\"Perangkat baru diblokir\",\"p_version\":$((VERSION - 1))}")
check "aksi dengan versi tiket lama ditolak" '[ "$code" = 409 ] && [ "$(json .message)" = stale_ticket ]'
code=$(rpc "$AGENT2_JWT" resolve_ticket "{\"p_ticket_id\":\"$TICKET\",\"p_outcome\":\"answered\",\"p_summary\":\"Perangkat baru diblokir\",\"p_tags\":[\"login\"],\"p_version\":$VERSION}")
check "CS menyelesaikan tiket" '[ "$code" = 200 ] && [ "$(json .status)" = resolved ]'
code=$(rpc "$JWT" my_tickets '{}')
check "nasabah melihat tiket selesai dan bisa memberi nilai" \
  '[ "$(json ".[] | select(.id == \"$TICKET\") | .status + \"/\" + (.can_rate | tostring)")" = resolved/true ]'
code=$(rpc "$JWT" rate_ticket "{\"p_ticket_id\":\"$TICKET\",\"p_rating\":5}")
check "nasabah memberi rating" '[ "$code" = 200 ] && [ "$(json .rating)" = 5 ]'

code=$(rpc "$SUP_JWT" ticket_detail "{\"p_ticket_id\":\"$TICKET\"}")
check "supervisor melihat perjalanan tiket: dibuka, diambil, ditransfer, selesai" \
  '[ "$code" = 200 ] && [ "$(json "[.events[].type] | (index(\"opened\") < index(\"claimed\")) and (index(\"claimed\") < index(\"transferred\")) and (index(\"transferred\") < index(\"resolved\"))")" = true ]'
for jwt in "$AGENT_JWT" "$AGENT2_JWT"; do
  rpc "$jwt" agent_set_status '{"p_status":"offline"}' > /dev/null
done

echo
echo "Hasil: $pass ok, $fail gagal"
[ "$fail" -eq 0 ]
