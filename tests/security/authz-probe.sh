#!/usr/bin/env bash
# Uji otorisasi otomatis: anon, nasabah lain, agen CS tanpa izin, agen nonaktif, token palsu.
# Setiap probe mengharapkan PENOLAKAN (non-2xx) atau hasil kosong; probe yang berhasil = temuan.
# Data korban dipilih dari DB dev (milik user selain penyerang); probe tulis diverifikasi lewat SQL.
set -uo pipefail
source /olt/tests/lib/common.sh

OUT="${OUT_DIR:-$RESULTS/security-$(stamp)}"
mkdir -p "$OUT"
TSV="$OUT/authz.tsv"
printf 'verdict\tactor\tprobe\tstatus\tdetail\n' > "$TSV"
BODY=$(mktemp)
API="${API_URL:-$(kong_edge_url)}"
pass=0 fail=0 skip=0 review=0

record() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(head -c 160 "$BODY" | tr '\t\n' '  ')" >> "$TSV"
  case "$1" in
    ok) pass=$((pass + 1)) ;;
    SKIP) skip=$((skip + 1)); echo "skip - [$2] $3" ;;
    REVIEW) review=$((review + 1)); echo "periksa - [$2] $3 -> $4" ;;
    *) fail=$((fail + 1)); echo "TEMUAN - [$2] $3 -> $4 $(head -c 200 "$BODY")" ;;
  esac
}

declare -A AUTH
AUTH[anon]=""
actor_headers() {
  local h=(-H "apikey: $ANON_KEY")
  [ -n "${AUTH[$1]:-}" ] && h+=(-H "Authorization: Bearer ${AUTH[$1]}")
  printf '%s\0' "${h[@]}"
}

call() {
  local actor="$1" method="$2" path="$3" data="${4:-}"
  shift 4 || shift $#
  local hdr=()
  while IFS= read -r -d '' x; do hdr+=("$x"); done < <(actor_headers "$actor")
  code=$(curl -sS -o "$BODY" -w '%{http_code}' -X "$method" "$API$path" "${hdr[@]}" \
    -H 'Content-Type: application/json' "$@" ${data:+--data "$data"} 2>/dev/null || echo 000)
}

empty_body() { jq -e '(. == null) or (. == []) or (. == {}) or (type == "array" and length == 0)' "$BODY" > /dev/null 2>&1 || [ ! -s "$BODY" ]; }
expect_denied() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ "$code" =~ ^2 ]]; then record FAIL "$actor" "$name" "$code"; else record ok "$actor" "$name" "$code"; fi
}
expect_empty() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ "$code" =~ ^2 ]] && ! empty_body; then record FAIL "$actor" "$name" "$code"; else record ok "$actor" "$name" "$code"; fi
}
expect_auth_denied() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ "$code" =~ ^(401|403)$ ]]; then record ok "$actor" "$name" "$code"; else record FAIL "$actor" "$name (harus 401/403)" "$code"; fi
}
expect_denied_sweep() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ ! "$code" =~ ^2 ]]; then record ok "$actor" "$name" "$code"
  elif empty_body; then record REVIEW "$actor" "$name (2xx tanpa data, periksa manual)" "$code"
  else record FAIL "$actor" "$name" "$code"; fi
}
expect_unchanged() {
  local actor="$1" name="$2" check="$3"; shift 3
  local before after
  before=$(sql "$check")
  call "$actor" "$@"
  after=$(sql "$check")
  if [ "$before" != "$after" ]; then record FAIL "$actor" "$name (data berubah: $before -> $after)" "$code"; else record ok "$actor" "$name" "$code"; fi
}

log "API: $API"
ATTACKER=joko_prasetyo
ATTACKER_ID=$(sql "select id from public.profiles where username = '$ATTACKER'")
AUTH[nasabah]=$(customer_jwt "$API" "$ATTACKER" 198.51.100.21)
[ -n "${AUTH[nasabah]}" ] || { echo "Gagal login nasabah $ATTACKER lewat OLT dummy + auth-bridge" >&2; exit 2; }
AGENT_ID=5e000000-0000-4000-8000-0000000000c1
DISABLED_ID=$(sql "select user_id from cs.agents where disabled_at is not null and not ('cs_super_admin' = any (roles)) order by created_at limit 1")
AUTH[agen]=$(staff_jwt "$AGENT_ID")
[ -n "$DISABLED_ID" ] && AUTH[agen_nonaktif]=$(staff_jwt "$DISABLED_ID")
AUTH[jwt_palsu]=$(JWT_SECRET=bukan-rahasia-yang-benar sign_hs256 "{\"sub\":\"$ATTACKER_ID\",\"role\":\"service_role\",\"aud\":\"authenticated\",\"exp\":$(( $(date +%s) + 600 ))}")
AUTH[jwt_alg_none]="$(printf '%s' '{"alg":"none","typ":"JWT"}' | b64url).$(printf '%s' "{\"sub\":\"$ATTACKER_ID\",\"role\":\"service_role\",\"exp\":$(( $(date +%s) + 600 ))}" | b64url)."
AUTH[jwt_kedaluwarsa]=$(sign_hs256 "{\"sub\":\"$ATTACKER_ID\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"iat\":$(( $(date +%s) - 7200 )),\"exp\":$(( $(date +%s) - 3600 ))}")
AUTH[jwt_role_service]=$(sign_hs256 "{\"sub\":\"$ATTACKER_ID\",\"role\":\"supabase_admin\",\"aud\":\"authenticated\",\"exp\":$(( $(date +%s) + 600 ))}")
grep -q . <<< "$AGENT_ID" && sql "select 1 from cs.agents where user_id = '$AGENT_ID' and roles = '{cs_agent}' and community_permissions = '{}' and nasabah_permissions = '{}'" | grep -q 1 \
  || echo "Peringatan: agen uji $AGENT_ID tidak ada / punya izin tambahan (jalankan make smoke-cs sekali)" >&2

echo "== kontrol positif (token uji benar-benar berlaku)"
control() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ "$code" =~ ^2 ]]; then record ok "$actor" "kontrol: $name" "$code"; else record FAIL "$actor" "kontrol gagal (hasil probe tidak sah): $name" "$code"; fi
}
control nasabah "nasabah membaca feed" GET '/rest/v1/rpc/get_feed?p_limit=1' ''
control agen "agen membaca agent_me" POST /rest/v1/rpc/agent_me '{}' -H 'Content-Profile: cs_api'
control anon "anon key: health auth-bridge" GET /bridge/v1/health ''

echo "== token palsu / kedaluwarsa"
for a in jwt_palsu jwt_alg_none jwt_kedaluwarsa jwt_role_service; do
  expect_denied "$a" "baca feed dengan token tidak sah" GET '/rest/v1/rpc/get_feed?p_limit=1' ''
  expect_denied "$a" "cs_api.agent_me dengan token tidak sah" POST /rest/v1/rpc/agent_me '{}' -H 'Content-Profile: cs_api'
done
expect_denied anon "REST tanpa apikey" GET '/rest/v1/messages?limit=1' '' -H 'apikey:'
call anon GET '/rest/v1/' ''
[[ "$code" =~ ^2 ]] && record FAIL anon "OpenAPI root /rest/v1/ dengan anon key" "$code" || record ok anon "OpenAPI root /rest/v1/ hanya service_role" "$code"

echo "== skema yang tidak boleh terekspos"
for schema in private cs auth vault storage olt_internal admin_api realtime _realtime cron net extensions supabase_functions; do
  for a in anon nasabah agen; do
    expect_denied "$a" "Accept-Profile $schema" GET '/rest/v1/settings?limit=1' '' -H "Accept-Profile: $schema"
  done
done
call nasabah POST /graphql/v1 '{"query":"{ __schema { types { name } } }"}'
if [[ "$code" =~ ^2 ]] && jq -e '.data != null' "$BODY" > /dev/null 2>&1; then record FAIL nasabah "GraphQL introspeksi" "$code"; else record ok nasabah "GraphQL introspeksi ditolak (pg_graphql nonaktif)" "$code"; fi

echo "== tabel publik: data user lain"
DM=$(sql "select r.id from public.chat_rooms r where r.type = 'direct' and exists (select 1 from public.messages m where m.room_id = r.id)
          and not exists (select 1 from public.chat_members cm where cm.room_id = r.id and cm.user_id = '$ATTACKER_ID') limit 1")
SUPPORT=$(sql "select r.id from public.chat_rooms r where r.type = 'support' and exists (select 1 from public.messages m where m.room_id = r.id)
          and not exists (select 1 from public.chat_members cm where cm.room_id = r.id and cm.user_id = '$ATTACKER_ID') limit 1")
GROUP=$(sql "select r.id from public.chat_rooms r where r.type = 'group' and exists (select 1 from public.messages m where m.room_id = r.id)
          and not exists (select 1 from public.chat_members cm where cm.room_id = r.id and cm.user_id = '$ATTACKER_ID') limit 1")
VICTIM=$(sql "select user_id from public.chat_members where room_id = '${DM:-00000000-0000-0000-0000-000000000000}' limit 1")
VICTIM=${VICTIM:-$(sql "select id from public.profiles where username = 'budi_santoso'")}
NOTIF=$(sql "select id from public.notifications where user_id <> '$ATTACKER_ID' order by created_at desc limit 1")
DRAFT_OWNER=$(sql "select user_id from public.post_drafts where user_id <> '$ATTACKER_ID' limit 1")
BOOKMARK_OWNER=$(sql "select user_id from public.bookmarks where user_id <> '$ATTACKER_ID' limit 1")
WATCH_OWNER=$(sql "select user_id from public.stock_watchers where user_id <> '$ATTACKER_ID' limit 1")
POST_OTHER=$(sql "select id from public.posts where author_id <> '$ATTACKER_ID' and deleted_at is null limit 1")
OWN_ROOM=$(sql "select room_id from public.chat_members where user_id = '$ATTACKER_ID' limit 1")
MSG_OTHER=$(sql "select id from public.messages where room_id = '${DM:-00000000-0000-0000-0000-000000000000}' and deleted_at is null limit 1")

for room in DM SUPPORT GROUP; do
  id=${!room}
  if [ -z "$id" ]; then echo "skip: tidak ada room $room korban" >&2; continue; fi
  ids=$(sql "select coalesce(string_agg('\"' || id || '\"', ','), '') from (select id from public.messages where room_id = '$id' limit 5) x")
  for a in anon nasabah agen; do
    expect_empty "$a" "messages room $room orang lain (REST)" GET "/rest/v1/messages?room_id=eq.$id&select=id,body" ''
    expect_empty "$a" "chat_members room $room orang lain" GET "/rest/v1/chat_members?room_id=eq.$id" ''
    expect_empty "$a" "rpc get_messages room $room orang lain" POST /rest/v1/rpc/get_messages "{\"p_room_id\":\"$id\"}"
    expect_empty "$a" "rpc get_room_members room $room orang lain" POST /rest/v1/rpc/get_room_members "{\"p_room_id\":\"$id\"}"
    expect_empty "$a" "rpc get_message_ids room $room orang lain" POST /rest/v1/rpc/get_message_ids \
      "{\"p_room_id\":\"$id\",\"p_after\":\"1970-01-01T00:00:00.000000Z|00000000-0000-0000-0000-000000000000\"}"
    expect_empty "$a" "rpc get_messages_by_ids room $room orang lain" POST /rest/v1/rpc/get_messages_by_ids \
      "{\"p_room_id\":\"$id\",\"p_ids\":[$ids]}"
  done
  if [ -n "$OWN_ROOM" ]; then
    expect_empty nasabah "rpc get_messages_by_ids room sendiri dengan id pesan room $room orang lain" POST /rest/v1/rpc/get_messages_by_ids \
      "{\"p_room_id\":\"$OWN_ROOM\",\"p_ids\":[$ids]}"
  fi
  expect_unchanged nasabah "send_message ke room $room orang lain" \
    "select count(*) from public.messages where room_id = '$id'" POST /rest/v1/rpc/send_message "{\"p_room_id\":\"$id\",\"p_body\":\"probe otorisasi\"}"
  expect_unchanged nasabah "mark_room_read room $room orang lain" \
    "select count(*) from public.chat_members where room_id = '$id' and user_id = '$ATTACKER_ID'" POST /rest/v1/rpc/mark_room_read "{\"p_room_id\":\"$id\"}"
done
[ -n "$SUPPORT" ] && expect_empty nasabah "cs_api.ticket_messages room support orang lain" POST /rest/v1/rpc/ticket_messages "{\"p_room_id\":\"$SUPPORT\"}" -H 'Content-Profile: cs_api'

for a in anon nasabah agen; do
  expect_empty "$a" "notifications user lain" GET "/rest/v1/notifications?user_id=eq.$VICTIM&select=id" ''
  [ -n "$DRAFT_OWNER" ] && expect_empty "$a" "post_drafts user lain" GET "/rest/v1/post_drafts?user_id=eq.$DRAFT_OWNER" ''
  [ -n "$BOOKMARK_OWNER" ] && expect_empty "$a" "bookmarks user lain" GET "/rest/v1/bookmarks?user_id=eq.$BOOKMARK_OWNER" ''
  [ -n "$WATCH_OWNER" ] && expect_empty "$a" "stock_watchers user lain" GET "/rest/v1/stock_watchers?user_id=eq.$WATCH_OWNER" ''
  expect_empty "$a" "user_consents user lain" GET "/rest/v1/user_consents?user_id=eq.$VICTIM" ''
  expect_empty "$a" "blocks/mutes user lain" GET "/rest/v1/blocks?blocker_id=eq.$VICTIM" ''
  expect_empty "$a" "reports semua user" GET "/rest/v1/reports?select=id&reporter_id=neq.$ATTACKER_ID" ''
  expect_empty "$a" "profiles langsung (olt_user_id, email)" GET '/rest/v1/profiles?select=*&limit=5' ''
  expect_empty "$a" "appeals / banned_words / link_previews langsung" GET '/rest/v1/banned_words?select=*&limit=5' ''
done
expect_empty nasabah "rpc get_profile tidak membocorkan olt_user_id/email" GET "/rest/v1/rpc/get_profile?p_username=budi_santoso&select=olt_user_id" ''
call nasabah GET "/rest/v1/rpc/get_profile?p_username=budi_santoso" ''
if grep -q -E '"(olt_user_id|email)"' "$BODY"; then record FAIL nasabah "get_profile memuat olt_user_id/email" "$code"; else record ok nasabah "get_profile tanpa olt_user_id/email" "$code"; fi

[ -n "$NOTIF" ] && expect_unchanged nasabah "hapus notifikasi user lain (REST DELETE)" \
  "select count(*) from public.notifications where id = '$NOTIF'" DELETE "/rest/v1/notifications?id=eq.$NOTIF" ''
expect_unchanged nasabah "tambah stock_watchers atas nama user lain" \
  "select count(*) from public.stock_watchers where user_id = '$VICTIM'" POST /rest/v1/stock_watchers "{\"user_id\":\"$VICTIM\",\"stock_code\":\"PROBE\"}"
expect_unchanged nasabah "follow atas nama user lain" \
  "select count(*) from public.follows where follower_id = '$VICTIM'" POST /rest/v1/follows "{\"follower_id\":\"$VICTIM\",\"following_id\":\"$ATTACKER_ID\"}"
[ -n "$POST_OTHER" ] && expect_unchanged nasabah "delete_post milik user lain" \
  "select count(*) from public.posts where id = '$POST_OTHER' and deleted_at is null" POST /rest/v1/rpc/delete_post "{\"p_post_id\":\"$POST_OTHER\"}"
[ -n "$MSG_OTHER" ] && expect_unchanged nasabah "delete_message milik user lain" \
  "select count(*) from public.messages where id = '$MSG_OTHER' and deleted_at is null" POST /rest/v1/rpc/delete_message "{\"p_message_id\":\"$MSG_OTHER\"}"
expect_unchanged nasabah "PATCH posts milik user lain (REST)" \
  "select md5(string_agg(body, '')) from public.posts where author_id <> '$ATTACKER_ID'" PATCH "/rest/v1/posts?author_id=neq.$ATTACKER_ID" '{"body":"diubah probe"}'

echo "== RPC khusus service_role (public)"
mapfile -t SERVICE_FNS < <(sql "select p.proname || '|' || coalesce((select jsonb_object_agg(a, null)::text from unnest(p.proargnames[1:p.pronargs]) a), '{}')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and not has_function_privilege('authenticated', p.oid, 'execute') order by 1")
for row in "${SERVICE_FNS[@]}"; do
  fn=${row%%|*}; args=${row#*|}
  for a in anon nasabah agen; do
    expect_denied_sweep "$a" "rpc service-only public.$fn" POST "/rest/v1/rpc/$fn" "$args"
  done
done

echo "== cs_api: semua fungsi dengan argumen null"
STAFF_ONLY='^(admin_|app_integration_|agent_(heartbeat|me|send_message|set_status|typing)|alert_|backup_|claim_ticket|community_|compliance_|customer_history|evidence_|flag_ticket|health_|integration_|legal_|nasabah_|notes|add_note|online_agents|push_|quick_replies|reassign_ticket|release_ticket|report_customer|report_summary|request_transfer|respond_transfer|cancel_transfer|resolve_ticket|search_tickets|service_|set_ticket_priority|supervisor_|system_health|ticket_customer_login|ticket_detail|ticket_lists|wait_customer|room_members|get_messages)'
PERM_GATED='^(admin_|alert_|app_integration_|backup_|community_|compliance_|evidence_|health_acknowledge|integration_|legal_(draft_approve|draft_reject|set_required|cancel_scheduled)|nasabah_(save|clear)_integration|push_|service_|supervisor_|report_summary|report_customers|report_customer_trail)'
mapfile -t CS_FNS < <(sql "select p.proname || '|' || coalesce((select jsonb_object_agg(a, null)::text from unnest(p.proargnames[1:p.pronargs]) a), '{}')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'cs_api' order by 1")
for row in "${CS_FNS[@]}"; do
  fn=${row%%|*}; args=${row#*|}
  expect_denied_sweep anon "cs_api.$fn" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  if [[ "$fn" =~ $STAFF_ONLY ]]; then
    expect_denied_sweep nasabah "cs_api.$fn (khusus staf)" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  fi
  if [[ "$fn" =~ $PERM_GATED ]]; then
    expect_denied_sweep agen "cs_api.$fn (butuh izin/peran lain)" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  fi
  if [ -n "${AUTH[agen_nonaktif]:-}" ] && [[ "$fn" =~ $STAFF_ONLY ]]; then
    expect_denied_sweep agen_nonaktif "cs_api.$fn (agen nonaktif)" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  fi
done

echo "== Edge Function cs-admin"
for a in anon nasabah agen; do
  expect_denied "$a" "cs-admin buat akun CS" POST /functions/v1/cs-admin/agents '{"email":"probe@invalid.test","display_name":"Probe"}'
  expect_denied "$a" "cs-admin reset password (id fiktif)" POST /functions/v1/cs-admin/agents/00000000-0000-4000-8000-000000000000/reset-password '{}'
done

echo "== Storage"
pick() { sql "select name from storage.objects where bucket_id = '$1' and coalesce(owner_id, '') <> '$ATTACKER_ID' $2 order by created_at desc limit 1"; }
for target in "evidence|" "cs-documents|" "attachments|and name like 'rooms/%'"; do
  bucket=${target%%|*}; filter=${target#*|}
  obj=$(pick "$bucket" "$filter")
  for a in anon nasabah agen; do
    call "$a" POST "/storage/v1/object/list/$bucket" '{"prefix":"","limit":20}'
    if [[ "$code" =~ ^2 ]] && jq -e 'map(select(.name != "posts")) | length > 0' "$BODY" > /dev/null 2>&1; then
      record FAIL "$a" "list bucket $bucket (selain folder posts publik)" "$code"
    else record ok "$a" "list bucket $bucket (hanya folder posts yang memang publik)" "$code"; fi
    expect_empty "$a" "list bucket $bucket prefix rooms/" POST "/storage/v1/object/list/$bucket" '{"prefix":"rooms/","limit":20}'
    if [ -n "$obj" ]; then
      expect_denied "$a" "unduh objek $bucket milik orang lain" GET "/storage/v1/object/authenticated/$bucket/$obj" ''
      expect_denied "$a" "signed URL objek $bucket milik orang lain" POST "/storage/v1/object/sign/$bucket/$obj" '{"expiresIn":60}'
      expect_denied "$a" "objek $bucket lewat jalur public" GET "/storage/v1/object/public/$bucket/$obj" ''
    fi
  done
done
AVATAR=$(sql "select name from storage.objects where bucket_id = 'avatars' and coalesce(owner_id, '') <> '$ATTACKER_ID' limit 1")
if [ -n "$AVATAR" ]; then
  expect_unchanged nasabah "hapus avatar user lain" "select count(*) from storage.objects where bucket_id = 'avatars' and name = '$AVATAR'" \
    DELETE "/storage/v1/object/avatars/$AVATAR" ''
  expect_unchanged nasabah "timpa avatar user lain (upsert)" "select coalesce(max(updated_at)::text, '') from storage.objects where bucket_id = 'avatars' and name = '$AVATAR'" \
    PUT "/storage/v1/object/avatars/$AVATAR" 'bukan-gambar' -H 'x-upsert: true' -H 'Content-Type: image/jpeg'
fi
expect_denied nasabah "upload langsung ke evidence" POST "/storage/v1/object/evidence/probe/$ATTACKER_ID.txt" 'x' -H 'Content-Type: text/plain'
expect_denied nasabah "upload langsung ke cs-documents room orang lain" POST "/storage/v1/object/cs-documents/rooms/${SUPPORT:-x}/$ATTACKER_ID/probe.pdf" 'x' -H 'Content-Type: application/pdf'
expect_denied nasabah "buat bucket baru" POST /storage/v1/bucket '{"id":"probe","name":"probe","public":true}'
expect_denied nasabah "ubah bucket evidence jadi public" PUT /storage/v1/bucket/evidence '{"public":true}'
call anon GET /storage/v1/bucket ''
if [[ "$code" =~ ^2 ]] && jq -e 'map(select(.public == false)) | length > 0' "$BODY" > /dev/null 2>&1; then
  record FAIL anon "daftar bucket privat terlihat anon" "$code"; else record ok anon "daftar bucket (tanpa bucket privat)" "$code"; fi

echo "== Integrasi API"
NOTIFY='{"messages":[{"id":"probe-1","cust_id":"PROBE","title":"t","body":"b"}]}'
for a in anon nasabah; do
  expect_auth_denied "$a" "integration notify tanpa key integrasi" POST /integration/v1/notify/messages "$NOTIFY"
done
expect_auth_denied anon "integration notify key salah" POST /integration/v1/notify/messages "$NOTIFY" -H "Authorization: Bearer olt_int_$(openssl rand -hex 24)"
expect_auth_denied anon "integration notify anon key sebagai Bearer" POST /integration/v1/notify/messages "$NOTIFY" -H "Authorization: Bearer $ANON_KEY"
expect_auth_denied anon "integration tanpa apikey Kong" POST /integration/v1/notify/messages "$NOTIFY" -H 'apikey:'
expect_auth_denied anon "integration bot_post key salah" POST /integration/v1/bot/posts '{"posts":[]}' -H 'Authorization: Bearer salah'

echo "== Realtime: kanal room DM dua user uji lt_sec*"
tokengen -prefix lt_sec -start 1 -count 2 -base 9190000 > "$OUT/lt_sec.json"
SEC_A=$(curl -sS -X POST "$API/bridge/v1/exchange" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 198.51.100.31' -d "{\"token\":\"$(jq -r '.[0].token' "$OUT/lt_sec.json")\"}" | jq -r '.access_token // empty')
SEC_B_JSON=$(curl -sS -X POST "$API/bridge/v1/exchange" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 198.51.100.32' -d "{\"token\":\"$(jq -r '.[1].token' "$OUT/lt_sec.json")\"}")
SEC_B_ID=$(jq -r '.user.id // empty' <<< "$SEC_B_JSON")
SEC_B=$(jq -r '.access_token // empty' <<< "$SEC_B_JSON")
rm -f "$OUT/lt_sec.json"
SEC_ROOM=""
if [ -n "$SEC_A" ] && [ -n "$SEC_B_ID" ]; then
  AUTH[lt_sec_a]=$SEC_A
  call lt_sec_a POST /rest/v1/rpc/get_or_create_direct_room "{\"p_other_user_id\":\"$SEC_B_ID\"}"
  SEC_ROOM=$(jq -r 'if type == "string" then . else empty end' "$BODY" 2>/dev/null)
  if [ -n "$SEC_ROOM" ] && [ -n "$SEC_B" ]; then
    AUTH[lt_sec_b]=$SEC_B
    call lt_sec_b POST /rest/v1/rpc/respond_message_request "{\"p_room_id\":\"$SEC_ROOM\",\"p_action\":\"accept\"}"
  fi
  call lt_sec_a POST /rest/v1/rpc/join_stock_room '{"p_stock_code":"LTSEC"}'
  SEC_STOCK=$(jq -r 'if type == "string" then . else empty end' "$BODY" 2>/dev/null)
fi
if [ -n "$SEC_ROOM" ]; then
  if k6 run -q --summary-mode disabled --log-format raw -e API="$API" -e ANON_KEY="$ANON_KEY" -e JWT="${AUTH[nasabah]}" -e VICTIM_JWT="$SEC_A" -e ROOM="$SEC_ROOM" \
       -e STOCK_ROOM="${SEC_STOCK:-}" \
       /olt/tests/security/realtime-authz.js > "$OUT/realtime-authz.log" 2>&1; then
    sed -n 's/^RESULT //p' "$OUT/realtime-authz.log" | jq -s . > "$OUT/realtime-authz.json"
    jq -r '.[] | [.verdict, .actor, .probe, .status, .detail] | @tsv' "$OUT/realtime-authz.json" >> "$TSV"
    while IFS=$'\t' read -r v a p s d; do
      if [ "$v" = ok ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "TEMUAN - [$a] $p -> $s $d"; fi
    done < <(jq -r '.[] | [.verdict, .actor, .probe, .status, .detail] | @tsv' "$OUT/realtime-authz.json")
  else
    echo "k6 realtime-authz gagal, lihat $OUT/realtime-authz.log" >&2; fail=$((fail + 1))
  fi
else
  echo "skip: gagal menyiapkan room DM lt_sec (status $code)" >&2; skip=$((skip + 1))
fi

echo
echo "authz-probe: $pass ok, $fail temuan, $review perlu diperiksa, $skip dilewati  (detail: ${OUT#/olt/}/authz.tsv)"
[ "$fail" -eq 0 ]
