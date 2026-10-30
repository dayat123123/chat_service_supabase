#!/usr/bin/env bash
# Smoke test CS chat end-to-end lewat Kong: nasabah (login OLT dummy) -> cs_api
# (PostgREST) -> agen 2FA -> customer-adapter -> OLT dummy.
# Butuh: make up DUMMY_OLT=1 (Windows: .\make.ps1 up -DummyOlt).
# Penawaran sesi ke agen dibuat lewat SQL; di CS2 tugas ini diambil alih cs-matcher.
# Batas 5 sesi baru per jam per nasabah berlaku: jangan jalankan lebih dari 5x per jam.
set -uo pipefail

BASE="${SUPABASE_URL:-http://kong:8000}"
OLT="${DUMMY_OLT_URL:-http://dummy-olt:8090}"
BODY=/tmp/smoke-cs-body
: "${ANON_KEY:?ANON_KEY wajib diisi}"
: "${JWT_SECRET:?JWT_SECRET wajib diisi}"

AGENT=5e000000-0000-4000-8000-0000000000c1
SUPERVISOR=5e000000-0000-4000-8000-0000000000c2
pass=0
fail=0

json() { jq -r "$1" "$BODY"; }
sql() { psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -c "$1"; }
uuid() { cat /proc/sys/kernel/random/uuid; }
b64url() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

check() {
  if eval "$2"; then
    echo "ok   - $1"
    pass=$((pass + 1))
  else
    echo "GAGAL - $1 (status ${code:-?}: $(head -c 300 "$BODY" 2>/dev/null))"
    fail=$((fail + 1))
  fi
}

sign() {
  local head payload
  head=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '%s' "$1" | b64url)
  printf '%s.%s.%s' "$head" "$payload" \
    "$(printf '%s.%s' "$head" "$payload" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | b64url)"
}

agent_jwt() {
  local now
  now=$(date +%s)
  sign "{\"sub\":\"$1\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"aal\":\"aal2\",\"iat\":$now,\"exp\":$((now + 3600))}"
}

ensure_agent() {
  sql "select cs.create_agent('$1', '$2', '$3', 'general', '{\"general\": 2, \"account\": 2}', '{id,en}', 3)
       where not exists (select 1 from cs.agents where user_id = '$1');
       update cs.agents set disabled_at = null where user_id = '$1';" > /dev/null
}

login() {
  local olt_token
  olt_token=$(curl -sS -X POST "$OLT/api/login" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$1\",\"password\":\"olt12345\"}" | jq -r '.token // empty')
  code=$(curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
    -H 'Content-Type: application/json' -d "{\"token\":\"$olt_token\"}")
  LOGIN_JWT=$(json '.access_token // empty')
  LOGIN_ID=$(json '.user.id // empty')
}

rpc() {
  curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/rest/v1/rpc/$2" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $1" -H 'Content-Type: application/json' -H "Content-Profile: ${4:-cs_api}" -d "$3"
}

adapter() {
  curl -sS -o "$BODY" -w '%{http_code}' "$BASE/cs/v1$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" "${@:3}"
}

if ! curl -sf "$OLT/health" > /dev/null; then
  echo "OLT dummy tidak berjalan. Jalankan: make up DUMMY_OLT=1 (Windows: .\\make.ps1 up -DummyOlt)" >&2
  exit 1
fi

ensure_agent "$AGENT" "Smoke Agen" "{cs_agent}"
ensure_agent "$SUPERVISOR" "Smoke Supervisor" "{cs_supervisor}"
AGENT_JWT=$(agent_jwt "$AGENT")
SUP_JWT=$(agent_jwt "$SUPERVISOR")

login budi_santoso
JWT=$LOGIN_JWT
CUSTOMER=$LOGIN_ID
check "nasabah login lewat OLT dummy" '[ -n "$JWT" ]'
sql "select cs.close_session(id, 'other', '{smoke}', null) from cs.support_sessions
     where customer_id = '$CUSTOMER' and status <> 'closed'" > /dev/null

code=$(rpc "$JWT" topics '{}')
check "nasabah melihat 7 topik bantuan" '[ "$code" = 200 ] && [ "$(json length)" = 7 ]'
code=$(rpc "$JWT" start_session '{"p_topic":"account","p_screen":"help"}')
SESSION=$(json .id)
ROOM=$(json .room_id)
check "nasabah memulai chat CS dan masuk antrean" '[ "$code" = 200 ] && [ "$(json .status)" = queued ]'
code=$(rpc "$JWT" send_message "{\"p_room_id\":\"$ROOM\",\"p_body\":\"Tidak bisa login, OTP saya 123456\",\"p_client_id\":\"$(uuid)\"}")
check "OTP di pesan nasabah disamarkan server" '[ "$code" = 200 ] && [ "$(json ".[0].body")" = "Tidak bisa login, OTP saya ******" ]'

code=$(rpc "$AGENT_JWT" agent_set_status '{"p_status":"online"}')
check "agen (2FA) online" '[ "$code" = 200 ] && [ "$(json .status)" = online ]'
code=$(rpc "$AGENT_JWT" get_my_rooms '{}' public)
check "akun CS ditolak di API sosial" '[ "$code" = 403 ] && [ "$(json .message)" = cs_staff_social_forbidden ]'
OFFER=$(sql "select (cs.offer('$SESSION', '$AGENT')).id")
code=$(rpc "$AGENT_JWT" agent_inbox '{}')
check "penawaran masuk ke agen dengan cuplikan tersamar" \
  '[ "$code" = 200 ] && [ "$(json ".offers[0].preview")" = "Tidak bisa login, OTP saya ******" ]'
code=$(rpc "$AGENT_JWT" accept_offer "{\"p_offer_id\":\"$OFFER\"}")
check "agen menerima sesi" '[ "$code" = 200 ] && [ "$(json .status)" = active ]'
code=$(rpc "$AGENT_JWT" agent_send_message "{\"p_session_id\":\"$SESSION\",\"p_body\":\"Halo Pak Budi, saya bantu cek.\",\"p_client_id\":\"$(uuid)\"}")
check "agen membalas, pesan bertanda CS Resmi" '[ "$code" = 200 ] && [ "$(json .message.sender_role)" = agent ]'
code=$(rpc "$AGENT_JWT" agent_send_message "{\"p_session_id\":\"$SESSION\",\"p_body\":\"Mohon kirimkan kode OTP Anda\"}")
check "pesan agen yang meminta OTP diblokir" '[ "$code" = 200 ] && [ "$(json .status)" = blocked ]'
code=$(rpc "$AGENT_JWT" add_note "{\"p_session_id\":\"$SESSION\",\"p_body\":\"SMOKE-NOTE: cek perangkat baru\"}")
check "agen menulis catatan internal" '[ "$code" = 200 ]'

code=$(rpc "$JWT" get_messages "{\"p_room_id\":\"$ROOM\",\"p_limit\":100}")
check "nasabah melihat balasan agen" '[ "$(json "[.[] | select(.sender_role == \"agent\" and .session_id == \"$SESSION\")] | length")" = 1 ]'
check "catatan internal dan pesan yang diblokir tidak terlihat nasabah" \
  '[ "$(json "[.[] | select(.body | test(\"SMOKE-NOTE|kirimkan kode OTP\"))] | length")" = 0 ]'
code=$(rpc "$JWT" notes "{\"p_customer_id\":\"$CUSTOMER\"}")
check "nasabah tidak bisa memanggil API catatan" '[ "$code" = 403 ]'

code=$(adapter "$AGENT_JWT" "/agent/sessions/$SESSION/customer/profile")
check "adapter memberi profil nasabah dari OLT" '[ "$code" = 200 ] && [ "$(json .data.name)" = "Budi Santoso" ]'
check "data sensitif nasabah tersamar" '[[ "$(json .data.nik)" == *"*"* ]] && [[ "$(json .data.phone)" == *"*"* ]]'
code=$(adapter "$JWT" "/agent/sessions/$SESSION/customer/profile")
check "token nasabah ditolak di API agen" '[ "$code" = 403 ]'
code=$(adapter "$SUP_JWT" "/agent/sessions/$(uuid)/customer/profile")
check "sesi yang tidak ada ditolak" '[ "$code" = 403 ]'
code=$(adapter "$AGENT_JWT" "/agent/sessions/$SESSION/customer/reveal" -X POST -H 'Content-Type: application/json' \
  -d '{"field":"phone","reason":"identity_verification"}')
check "membuka satu field dengan alasan" '[ "$code" = 200 ] && [[ "$(json .data.value)" != *"*"* ]]'
code=$(adapter "$AGENT_JWT" "/agent/sessions/$SESSION/customer/secure-account" -X POST)
check "amankan akun dijalankan di OLT" '[ "$code" = 200 ] && [ "$(json .data.ok)" = true ]'
check "nasabah diberi tahu akunnya diamankan" \
  '[ "$(sql "select count(*) from public.messages where session_id = '"'"'$SESSION'"'"' and payload ->> '"'"'code'"'"' = '"'"'secured'"'"'")" = 1 ]'
code=$(adapter "$JWT" "/me/orders?limit=5")
check "nasabah memilih order sendiri untuk kartu konteks" '[ "$code" = 200 ] && [ "$(json .available)" = true ]'
check "akses data nasabah tercatat di audit log" \
  '[ "$(sql "select count(*) from cs.cs_audit_log where session_id = '"'"'$SESSION'"'"' and (action like '"'"'customer_data.%'"'"' or action like '"'"'secure_account.%'"'"')")" -ge 4 ]'

code=$(rpc "$SUP_JWT" session_detail "{\"p_session_id\":\"$SESSION\"}")
check "supervisor memantau perjalanan sesi" '[ "$code" = 200 ] && [ "$(json "[.events[].type] | index(\"accepted\") != null")" = true ]'
code=$(rpc "$AGENT_JWT" close_session "{\"p_session_id\":\"$SESSION\",\"p_outcome\":\"resolved\",\"p_tags\":[\"login\"]}")
check "agen menutup sesi" '[ "$code" = 200 ] && [ "$(json .status)" = closed ]'
code=$(rpc "$JWT" rate_session "{\"p_session_id\":\"$SESSION\",\"p_rating\":5}")
check "nasabah memberi rating" '[ "$code" = 200 ] && [ "$(json .rating)" = 5 ]'
rpc "$AGENT_JWT" agent_set_status '{"p_status":"offline"}' > /dev/null

echo
echo "Hasil: $pass ok, $fail gagal"
[ "$fail" -eq 0 ]
