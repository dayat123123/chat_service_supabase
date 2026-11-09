#!/usr/bin/env bash
# Every probe expects a denial (non-2xx) or an empty result; a probe that succeeds is a finding.
# Victim data comes from the dev DB (owned by users other than the attacker); write probes are verified via SQL.
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
    REVIEW) review=$((review + 1)); echo "review - [$2] $3 -> $4" ;;
    *) fail=$((fail + 1)); echo "FINDING - [$2] $3 -> $4 $(head -c 200 "$BODY")" ;;
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
  if [[ "$code" =~ ^(401|403)$ ]]; then record ok "$actor" "$name" "$code"; else record FAIL "$actor" "$name (must be 401/403)" "$code"; fi
}
expect_denied_sweep() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ ! "$code" =~ ^2 ]]; then record ok "$actor" "$name" "$code"
  elif empty_body; then record REVIEW "$actor" "$name (2xx without data, review manually)" "$code"
  else record FAIL "$actor" "$name" "$code"; fi
}
expect_unchanged() {
  local actor="$1" name="$2" check="$3"; shift 3
  local before after
  before=$(sql "$check")
  call "$actor" "$@"
  after=$(sql "$check")
  if [ "$before" != "$after" ]; then record FAIL "$actor" "$name (data changed: $before -> $after)" "$code"; else record ok "$actor" "$name" "$code"; fi
}

log "API: $API"
ATTACKER=joko_prasetyo
ATTACKER_ID=$(sql "select id from public.profiles where username = '$ATTACKER'")
AUTH[customer]=$(customer_jwt "$API" "$ATTACKER" 198.51.100.21)
[ -n "${AUTH[customer]}" ] || { echo "Failed to log in customer $ATTACKER via dummy OLT + auth-bridge" >&2; exit 2; }
AGENT_ID=5e000000-0000-4000-8000-0000000000c1
DISABLED_ID=$(sql "select user_id from cs.agents where disabled_at is not null and not ('cs_super_admin' = any (roles)) order by created_at limit 1")
AUTH[agent]=$(staff_jwt "$AGENT_ID")
[ -n "$DISABLED_ID" ] && AUTH[disabled_agent]=$(staff_jwt "$DISABLED_ID")
AUTH[jwt_forged]=$(JWT_SECRET=not-the-real-secret sign_hs256 "{\"sub\":\"$ATTACKER_ID\",\"role\":\"service_role\",\"aud\":\"authenticated\",\"exp\":$(( $(date +%s) + 600 ))}")
AUTH[jwt_alg_none]="$(printf '%s' '{"alg":"none","typ":"JWT"}' | b64url).$(printf '%s' "{\"sub\":\"$ATTACKER_ID\",\"role\":\"service_role\",\"exp\":$(( $(date +%s) + 600 ))}" | b64url)."
AUTH[jwt_expired]=$(sign_hs256 "{\"sub\":\"$ATTACKER_ID\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"iat\":$(( $(date +%s) - 7200 )),\"exp\":$(( $(date +%s) - 3600 ))}")
AUTH[jwt_role_service]=$(sign_hs256 "{\"sub\":\"$ATTACKER_ID\",\"role\":\"supabase_admin\",\"aud\":\"authenticated\",\"exp\":$(( $(date +%s) + 600 ))}")
grep -q . <<< "$AGENT_ID" && sql "select 1 from cs.agents where user_id = '$AGENT_ID' and roles = '{cs_agent}' and community_permissions = '{}' and nasabah_permissions = '{}'" | grep -q 1 \
  || echo "Warning: test agent $AGENT_ID is missing or has extra permissions (run make smoke-cs once)" >&2

echo "== positive controls (test tokens actually work)"
control() {
  local actor="$1" name="$2"; shift 2
  call "$actor" "$@"
  if [[ "$code" =~ ^2 ]]; then record ok "$actor" "control: $name" "$code"; else record FAIL "$actor" "control failed (probe results invalid): $name" "$code"; fi
}
control customer "customer reads feed" GET '/rest/v1/rpc/get_feed?p_limit=1' ''
control agent "agent reads agent_me" POST /rest/v1/rpc/agent_me '{}' -H 'Content-Profile: cs_api'
control anon "anon key: auth-bridge health" GET /bridge/v1/health ''

echo "== forged / expired tokens"
for a in jwt_forged jwt_alg_none jwt_expired jwt_role_service; do
  expect_denied "$a" "read feed with invalid token" GET '/rest/v1/rpc/get_feed?p_limit=1' ''
  expect_denied "$a" "cs_api.agent_me with invalid token" POST /rest/v1/rpc/agent_me '{}' -H 'Content-Profile: cs_api'
done
expect_denied anon "REST without apikey" GET '/rest/v1/messages?limit=1' '' -H 'apikey:'
call anon GET '/rest/v1/' ''
[[ "$code" =~ ^2 ]] && record FAIL anon "OpenAPI root /rest/v1/ with anon key" "$code" || record ok anon "OpenAPI root /rest/v1/ service_role only" "$code"

echo "== schemas that must not be exposed"
for schema in private cs auth vault storage olt_internal admin_api realtime _realtime cron net extensions supabase_functions; do
  for a in anon customer agent; do
    expect_denied "$a" "Accept-Profile $schema" GET '/rest/v1/settings?limit=1' '' -H "Accept-Profile: $schema"
  done
done
call customer POST /graphql/v1 '{"query":"{ __schema { types { name } } }"}'
if [[ "$code" =~ ^2 ]] && jq -e '.data != null' "$BODY" > /dev/null 2>&1; then record FAIL customer "GraphQL introspection" "$code"; else record ok customer "GraphQL introspection denied (pg_graphql disabled)" "$code"; fi

echo "== public tables: other users' data"
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
  if [ -z "$id" ]; then echo "skip: no victim $room room" >&2; continue; fi
  ids=$(sql "select coalesce(string_agg('\"' || id || '\"', ','), '') from (select id from public.messages where room_id = '$id' limit 5) x")
  for a in anon customer agent; do
    expect_empty "$a" "messages of someone else's $room room (REST)" GET "/rest/v1/messages?room_id=eq.$id&select=id,body" ''
    expect_empty "$a" "chat_members of someone else's $room room" GET "/rest/v1/chat_members?room_id=eq.$id" ''
    expect_empty "$a" "rpc get_messages on someone else's $room room" POST /rest/v1/rpc/get_messages "{\"p_room_id\":\"$id\"}"
    expect_empty "$a" "rpc get_room_members on someone else's $room room" POST /rest/v1/rpc/get_room_members "{\"p_room_id\":\"$id\"}"
    expect_empty "$a" "rpc get_message_ids on someone else's $room room" POST /rest/v1/rpc/get_message_ids \
      "{\"p_room_id\":\"$id\",\"p_after\":\"1970-01-01T00:00:00.000000Z|00000000-0000-0000-0000-000000000000\"}"
    expect_empty "$a" "rpc get_messages_by_ids on someone else's $room room" POST /rest/v1/rpc/get_messages_by_ids \
      "{\"p_room_id\":\"$id\",\"p_ids\":[$ids]}"
  done
  if [ -n "$OWN_ROOM" ]; then
    expect_empty customer "rpc get_messages_by_ids on own room with message ids from someone else's $room room" POST /rest/v1/rpc/get_messages_by_ids \
      "{\"p_room_id\":\"$OWN_ROOM\",\"p_ids\":[$ids]}"
  fi
  expect_unchanged customer "send_message to someone else's $room room" \
    "select count(*) from public.messages where room_id = '$id'" POST /rest/v1/rpc/send_message "{\"p_room_id\":\"$id\",\"p_body\":\"probe otorisasi\"}"
  expect_unchanged customer "mark_room_read on someone else's $room room" \
    "select count(*) from public.chat_members where room_id = '$id' and user_id = '$ATTACKER_ID'" POST /rest/v1/rpc/mark_room_read "{\"p_room_id\":\"$id\"}"
done
[ -n "$SUPPORT" ] && expect_empty customer "cs_api.ticket_messages of someone else's support room" POST /rest/v1/rpc/ticket_messages "{\"p_room_id\":\"$SUPPORT\"}" -H 'Content-Profile: cs_api'

for a in anon customer agent; do
  expect_empty "$a" "other user's notifications" GET "/rest/v1/notifications?user_id=eq.$VICTIM&select=id" ''
  [ -n "$DRAFT_OWNER" ] && expect_empty "$a" "other user's post_drafts" GET "/rest/v1/post_drafts?user_id=eq.$DRAFT_OWNER" ''
  [ -n "$BOOKMARK_OWNER" ] && expect_empty "$a" "other user's bookmarks" GET "/rest/v1/bookmarks?user_id=eq.$BOOKMARK_OWNER" ''
  [ -n "$WATCH_OWNER" ] && expect_empty "$a" "other user's stock_watchers" GET "/rest/v1/stock_watchers?user_id=eq.$WATCH_OWNER" ''
  expect_empty "$a" "other user's user_consents" GET "/rest/v1/user_consents?user_id=eq.$VICTIM" ''
  expect_empty "$a" "other user's blocks/mutes" GET "/rest/v1/blocks?blocker_id=eq.$VICTIM" ''
  expect_empty "$a" "reports of all users" GET "/rest/v1/reports?select=id&reporter_id=neq.$ATTACKER_ID" ''
  expect_empty "$a" "profiles directly (olt_user_id, email)" GET '/rest/v1/profiles?select=*&limit=5' ''
  expect_empty "$a" "appeals / banned_words / link_previews directly" GET '/rest/v1/banned_words?select=*&limit=5' ''
done
expect_empty customer "rpc get_profile does not leak olt_user_id/email" GET "/rest/v1/rpc/get_profile?p_username=budi_santoso&select=olt_user_id" ''
call customer GET "/rest/v1/rpc/get_profile?p_username=budi_santoso" ''
if grep -q -E '"(olt_user_id|email)"' "$BODY"; then record FAIL customer "get_profile includes olt_user_id/email" "$code"; else record ok customer "get_profile without olt_user_id/email" "$code"; fi

[ -n "$NOTIF" ] && expect_unchanged customer "delete other user's notification (REST DELETE)" \
  "select count(*) from public.notifications where id = '$NOTIF'" DELETE "/rest/v1/notifications?id=eq.$NOTIF" ''
expect_unchanged customer "insert stock_watchers on behalf of another user" \
  "select count(*) from public.stock_watchers where user_id = '$VICTIM'" POST /rest/v1/stock_watchers "{\"user_id\":\"$VICTIM\",\"stock_code\":\"PROBE\"}"
expect_unchanged customer "follow on behalf of another user" \
  "select count(*) from public.follows where follower_id = '$VICTIM'" POST /rest/v1/follows "{\"follower_id\":\"$VICTIM\",\"following_id\":\"$ATTACKER_ID\"}"
[ -n "$POST_OTHER" ] && expect_unchanged customer "delete_post owned by another user" \
  "select count(*) from public.posts where id = '$POST_OTHER' and deleted_at is null" POST /rest/v1/rpc/delete_post "{\"p_post_id\":\"$POST_OTHER\"}"
[ -n "$MSG_OTHER" ] && expect_unchanged customer "delete_message owned by another user" \
  "select count(*) from public.messages where id = '$MSG_OTHER' and deleted_at is null" POST /rest/v1/rpc/delete_message "{\"p_message_id\":\"$MSG_OTHER\"}"
expect_unchanged customer "PATCH posts owned by other users (REST)" \
  "select md5(string_agg(body, '')) from public.posts where author_id <> '$ATTACKER_ID'" PATCH "/rest/v1/posts?author_id=neq.$ATTACKER_ID" '{"body":"diubah probe"}'

echo "== service_role-only RPCs (public)"
mapfile -t SERVICE_FNS < <(sql "select p.proname || '|' || coalesce((select jsonb_object_agg(a, null)::text from unnest(p.proargnames[1:p.pronargs]) a), '{}')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and not has_function_privilege('authenticated', p.oid, 'execute') order by 1")
for row in "${SERVICE_FNS[@]}"; do
  fn=${row%%|*}; args=${row#*|}
  for a in anon customer agent; do
    expect_denied_sweep "$a" "rpc service-only public.$fn" POST "/rest/v1/rpc/$fn" "$args"
  done
done

echo "== cs_api: every function with null arguments"
STAFF_ONLY='^(admin_|app_integration_|agent_(heartbeat|me|my_profile|my_stats|password_changed|send_message|set_status|signed_out_everywhere|typing)|alert_|backup_|claim_ticket|community_|compliance_|customer_history|evidence_|flag_ticket|health_|integration_|legal_|nasabah_|notes|add_note|online_agents|push_|quick_replies|my_quick_replies|save_my_quick_reply|delete_my_quick_reply|ticket_labels|add_ticket_label|remove_ticket_label|report_ticket_labels|reassign_ticket|release_ticket|report_customer|report_summary|request_transfer|respond_transfer|cancel_transfer|resolve_ticket|search_tickets|service_create_|set_ticket_priority|supervisor_|system_health|ticket_customer_login|ticket_detail|ticket_lists|wait_customer|room_members|get_messages)'
PERM_GATED='^(admin_|alert_|app_integration_|backup_|community_|compliance_|evidence_|health_acknowledge|integration_|legal_(draft_approve|draft_reject|set_required|cancel_scheduled)|nasabah_(save|clear)_integration|push_|service_create_|supervisor_|report_summary|report_customers|report_customer_trail|report_ticket_labels)'
mapfile -t CS_FNS < <(sql "select p.proname || '|' || coalesce((select jsonb_object_agg(a, null)::text from unnest(p.proargnames[1:p.pronargs]) a), '{}')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'cs_api' order by 1")
GUEST_PUBLIC='^guest_(config|start|poll|send|end)$'
for row in "${CS_FNS[@]}"; do
  fn=${row%%|*}; args=${row#*|}
  if [[ "$fn" =~ $GUEST_PUBLIC ]]; then
    if [ "$fn" != guest_config ] && [ "$fn" != guest_start ]; then
      call anon POST "/rest/v1/rpc/$fn" '{"p_token":"probe-token-that-does-not-exist-000000"}' -H 'Content-Profile: cs_api'
      if [ "$code" = 401 ]; then record ok anon "cs_api.$fn (guest RPC, unknown session token)" "$code"
      else record FAIL anon "cs_api.$fn (guest RPC must refuse an unknown session token)" "$code"; fi
    fi
    continue
  fi
  expect_denied_sweep anon "cs_api.$fn" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  if [[ "$fn" =~ $STAFF_ONLY ]]; then
    expect_denied_sweep customer "cs_api.$fn (staff only)" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  fi
  if [[ "$fn" =~ $PERM_GATED ]]; then
    expect_denied_sweep agent "cs_api.$fn (needs another permission/role)" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  fi
  if [ -n "${AUTH[disabled_agent]:-}" ] && [[ "$fn" =~ $STAFF_ONLY ]]; then
    expect_denied_sweep disabled_agent "cs_api.$fn (disabled agent)" POST "/rest/v1/rpc/$fn" "$args" -H 'Content-Profile: cs_api'
  fi
done

echo "== Edge Function cs-admin"
for a in anon customer agent; do
  expect_denied "$a" "cs-admin create CS account" POST /functions/v1/cs-admin/agents '{"email":"probe@invalid.test","display_name":"Probe"}'
  expect_denied "$a" "cs-admin reset password (fake id)" POST /functions/v1/cs-admin/agents/00000000-0000-4000-8000-000000000000/reset-password '{}'
done

echo "== Storage"
pick() { sql "select name from storage.objects where bucket_id = '$1' and coalesce(owner_id, '') <> '$ATTACKER_ID' $2 order by created_at desc limit 1"; }
for target in "evidence|" "cs-documents|" "attachments|and name like 'rooms/%'"; do
  bucket=${target%%|*}; filter=${target#*|}
  obj=$(pick "$bucket" "$filter")
  for a in anon customer agent; do
    call "$a" POST "/storage/v1/object/list/$bucket" '{"prefix":"","limit":20}'
    if [[ "$code" =~ ^2 ]] && jq -e 'map(select(.name != "posts")) | length > 0' "$BODY" > /dev/null 2>&1; then
      record FAIL "$a" "list bucket $bucket (beyond the public posts folder)" "$code"
    else record ok "$a" "list bucket $bucket (only the intentionally public posts folder)" "$code"; fi
    expect_empty "$a" "list bucket $bucket prefix rooms/" POST "/storage/v1/object/list/$bucket" '{"prefix":"rooms/","limit":20}'
    if [ -n "$obj" ]; then
      expect_denied "$a" "download someone else's $bucket object" GET "/storage/v1/object/authenticated/$bucket/$obj" ''
      expect_denied "$a" "signed URL for someone else's $bucket object" POST "/storage/v1/object/sign/$bucket/$obj" '{"expiresIn":60}'
      expect_denied "$a" "$bucket object via public path" GET "/storage/v1/object/public/$bucket/$obj" ''
    fi
  done
done
AVATAR=$(sql "select name from storage.objects where bucket_id = 'avatars' and coalesce(owner_id, '') <> '$ATTACKER_ID' limit 1")
if [ -n "$AVATAR" ]; then
  expect_unchanged customer "delete other user's avatar" "select count(*) from storage.objects where bucket_id = 'avatars' and name = '$AVATAR'" \
    DELETE "/storage/v1/object/avatars/$AVATAR" ''
  expect_unchanged customer "overwrite other user's avatar (upsert)" "select coalesce(max(updated_at)::text, '') from storage.objects where bucket_id = 'avatars' and name = '$AVATAR'" \
    PUT "/storage/v1/object/avatars/$AVATAR" 'not-an-image' -H 'x-upsert: true' -H 'Content-Type: image/jpeg'
fi
BANNER_OBJ="$(cat /proc/sys/kernel/random/uuid).jpg"
for a in customer agent; do
  expect_denied "$a" "direct upload to app-banners (Super Admin only)" POST "/storage/v1/object/app-banners/$BANNER_OBJ" 'x' -H 'Content-Type: image/jpeg'
done
for a in anon customer agent; do
  expect_empty "$a" "list bucket app-banners (includes scheduled promo images)" POST /storage/v1/object/list/app-banners '{"prefix":"","limit":20}'
done
expect_denied anon "rpc record_banner_event without login" POST /rest/v1/rpc/record_banner_event '{"p_banner_id":"00000000-0000-4000-8000-000000000000","p_event":"impression"}'
expect_denied agent "rpc record_banner_event by a CS account" POST /rest/v1/rpc/record_banner_event '{"p_banner_id":"00000000-0000-4000-8000-000000000000","p_event":"impression"}'
expect_denied customer "direct upload to evidence" POST "/storage/v1/object/evidence/probe/$ATTACKER_ID.txt" 'x' -H 'Content-Type: text/plain'
expect_denied customer "direct upload to cs-documents of someone else's room" POST "/storage/v1/object/cs-documents/rooms/${SUPPORT:-x}/$ATTACKER_ID/probe.pdf" 'x' -H 'Content-Type: application/pdf'
expect_denied customer "create new bucket" POST /storage/v1/bucket '{"id":"probe","name":"probe","public":true}'
expect_denied customer "make evidence bucket public" PUT /storage/v1/bucket/evidence '{"public":true}'
call anon GET /storage/v1/bucket ''
if [[ "$code" =~ ^2 ]] && jq -e 'map(select(.public == false)) | length > 0' "$BODY" > /dev/null 2>&1; then
  record FAIL anon "private buckets visible to anon in bucket list" "$code"; else record ok anon "bucket list (no private buckets)" "$code"; fi

echo "== Integration API"
NOTIFY='{"messages":[{"id":"probe-1","cust_id":"PROBE","title":"t","body":"b"}]}'
for a in anon customer; do
  expect_auth_denied "$a" "integration notify without integration key" POST /integration/v1/notify/messages "$NOTIFY"
done
expect_auth_denied anon "integration notify with wrong key" POST /integration/v1/notify/messages "$NOTIFY" -H "Authorization: Bearer olt_int_$(openssl rand -hex 24)"
expect_auth_denied anon "integration notify with anon key as Bearer" POST /integration/v1/notify/messages "$NOTIFY" -H "Authorization: Bearer $ANON_KEY"
expect_auth_denied anon "integration without Kong apikey" POST /integration/v1/notify/messages "$NOTIFY" -H 'apikey:'
expect_auth_denied anon "integration bot_post with wrong key" POST /integration/v1/bot/posts '{"posts":[]}' -H 'Authorization: Bearer wrong'

echo "== Realtime: DM room channel of two lt_sec* test users"
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
  if k6 run -q --summary-mode disabled --log-format raw -e API="$API" -e ANON_KEY="$ANON_KEY" -e JWT="${AUTH[customer]}" -e VICTIM_JWT="$SEC_A" -e ROOM="$SEC_ROOM" \
       -e STOCK_ROOM="${SEC_STOCK:-}" \
       /olt/tests/security/realtime-authz.js > "$OUT/realtime-authz.log" 2>&1; then
    sed -n 's/^RESULT //p' "$OUT/realtime-authz.log" | jq -s . > "$OUT/realtime-authz.json"
    jq -r '.[] | [.verdict, .actor, .probe, .status, .detail] | @tsv' "$OUT/realtime-authz.json" >> "$TSV"
    while IFS=$'\t' read -r v a p s d; do
      if [ "$v" = ok ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FINDING - [$a] $p -> $s $d"; fi
    done < <(jq -r '.[] | [.verdict, .actor, .probe, .status, .detail] | @tsv' "$OUT/realtime-authz.json")
  else
    echo "k6 realtime-authz failed, see $OUT/realtime-authz.log" >&2; fail=$((fail + 1))
  fi
else
  echo "skip: failed to set up lt_sec DM room (status $code)" >&2; skip=$((skip + 1))
fi

echo
echo "authz-probe: $pass ok, $fail findings, $review to review, $skip skipped  (detail: ${OUT#/olt/}/authz.tsv)"
[ "$fail" -eq 0 ]
