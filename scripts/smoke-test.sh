#!/usr/bin/env bash
# Needs a running stack, the seed data and AUTH_BRIDGE_OLT_MODE=mock. The one post it creates is
# soft-deleted at the end and the banned test user is removed.
set -uo pipefail

BASE="${SUPABASE_URL:-http://kong:8000}"
: "${ANON_KEY:?ANON_KEY is required}"
BODY=/tmp/smoke-body
pass=0
fail=0

check() {
  if eval "$2"; then
    echo "ok   - $1"
    pass=$((pass + 1))
  else
    echo "FAILED - $1 (status $code: $(head -c 300 "$BODY"))"
    fail=$((fail + 1))
  fi
}
req() { curl -sS -o "$BODY" -w '%{http_code}' "$@"; }
json() { jq -r "$1" "$BODY"; }

code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{"token":"mock:1001:budi_santoso"}')
check "exchange mock token -> 200" '[ "$code" = 200 ]'
JWT=$(json .access_token)
ME=$(json .user.id)
check "user id = the same UUID v5 as the seed" '[ "$ME" = "72689cd3-ea55-584f-9e84-c257af0564e0" ]'

code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{"token":"bukan-token-valid"}')
check "invalid OLT token -> 401" '[ "$code" = 401 ]'

code=$(req -X POST "$BASE/bridge/v1/exchange" -H 'Content-Type: application/json' \
  -d '{"token":"mock:1001:budi_santoso"}')
check "exchange without apikey rejected by Kong -> 401" '[ "$code" = 401 ]'

# A throwaway user is banned directly in the DB and deleted afterwards (the sanction cascades).
sql() { psql -U postgres -X -q -t -A -v ON_ERROR_STOP=1 -c "$1"; }
BAN_OLT_ID="99$(date +%s)$((RANDOM % 1000))"
code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d "{\"token\":\"mock:$BAN_OLT_ID:smoke_ban\"}")
BAN_JWT=$(json .access_token)
BAN_ID=$(json .user.id)
if [ "$code" = 200 ] && sql "insert into private.user_sanctions (user_id, kind, reason, ends_at)
    values ('$BAN_ID', 'ban', 'smoke test', now() + interval '10 minutes')" > /dev/null; then
  # A different display name makes a new token so the verification cache does not answer.
  code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
    -H 'Content-Type: application/json' -d "{\"token\":\"mock:$BAN_OLT_ID:smoke_ban:Smoke Ban\"}")
  check "exchange for a banned user -> 403 user_banned" '[ "$code" = 403 ] && [ "$(json .error)" = user_banned ]'
  code=$(req "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $BAN_JWT")
  check "old JWT of a banned user rejected by PostgREST -> 403" '[ "$code" = 403 ]'
else
  check "prepare a banned user (exchange + sanction)" 'false'
fi
if [ -n "$BAN_ID" ] && [ "$BAN_ID" != null ]; then
  sql "delete from public.profiles where id = '$BAN_ID'" > /dev/null || echo "WARNING: test user $BAN_ID could not be deleted" >&2
fi

AUTH=(-H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT")
JSON=(-H 'Content-Type: application/json')

code=$(req "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=5" "${AUTH[@]}")
check "get_feed global -> 200 with posts" '[ "$code" = 200 ] && [ "$(json length)" -ge 1 ]'

code=$(req "$BASE/rest/v1/rpc/get_feed?p_scope=global" -H "apikey: $ANON_KEY")
check "get_feed without a user JWT rejected" '[ "$code" = 401 ] || [ "$code" = 403 ]'

code=$(req -X POST "$BASE/rest/v1/posts" "${AUTH[@]}" "${JSON[@]}" -H 'Prefer: return=representation' \
  -d "{\"author_id\":\"$ME\",\"body\":\"Smoke test \$BBCA $(date +%s)\",\"sentiment\":\"neutral\"}")
check "create post -> 201" '[ "$code" = 201 ]'
POST_ID=$(json '.[0].id')

code=$(req "$BASE/rest/v1/rpc/get_post?p_post_id=$POST_ID" "${AUTH[@]}")
check "new post tagged BBCA" '[ "$code" = 200 ] && [ "$(json ".[0].stock_codes[0]")" = BBCA ]'

code=$(req -X POST "$BASE/rest/v1/posts" "${AUTH[@]}" "${JSON[@]}" \
  -d '{"author_id":"00000000-0000-0000-0000-000000000000","body":"palsu"}')
check "post on behalf of someone else rejected by RLS" '[ "$code" = 403 ] || [ "$code" = 401 ]'

code=$(req -X POST "$BASE/rest/v1/rpc/create_comment" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"p_post_id\":\"$POST_ID\",\"p_parent_id\":null,\"p_body\":\"Komentar smoke test\"}")
check "create_comment -> 200" '[ "$code" = 200 ] && [ "$(json ".[0].depth")" = 0 ]'

code=$(req -X POST "$BASE/rest/v1/reactions" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"user_id\":\"$ME\",\"target_type\":\"post\",\"target_id\":\"$POST_ID\"}")
check "like post -> 201" '[ "$code" = 201 ]'

code=$(req "$BASE/rest/v1/rpc/get_comment_thread?p_post_id=a0000000-0000-4000-8000-000000000001&p_max_depth=10&p_replies_limit=10" "${AUTH[@]}")
check "seed thread has 5 levels" '[ "$code" = 200 ] && [ "$(json "map(.depth) | max")" = 4 ]'

code=$(req "$BASE/rest/v1/rpc/get_profile?p_username=sari_invest" "${AUTH[@]}")
SARI=$(json '.[0].id')
check "get_profile by username" '[ "$code" = 200 ] && [ -n "$SARI" ] && [ "$SARI" != null ]'

code=$(req -X POST "$BASE/rest/v1/rpc/get_or_create_direct_room" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"p_other_user_id\":\"$SARI\"}")
ROOM=$(json .)
check "DM reuses the existing seed room" '[ "$ROOM" = "d0000000-0000-4000-8000-000000000001" ]'

code=$(req -X POST "$BASE/rest/v1/rpc/send_message" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"p_room_id\":\"$ROOM\",\"p_body\":\"Smoke test chat\",\"p_client_id\":\"$(cat /proc/sys/kernel/random/uuid)\"}")
check "send_message -> 200" '[ "$code" = 200 ] && [ "$(json ".[0].sender_username")" = budi_santoso ]'

code=$(req "$BASE/rest/v1/rpc/get_my_rooms" "${AUTH[@]}")
check "get_my_rooms includes the DM" '[ "$code" = 200 ] && [ "$(json "map(select(.id == \"$ROOM\")) | length")" = 1 ]'

PNG=/tmp/smoke.png
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d > "$PNG"

code=$(req -X POST "$BASE/storage/v1/object/avatars/$ME/smoke.png" "${AUTH[@]}" \
  -H 'Content-Type: image/png' -H 'x-upsert: true' --data-binary "@$PNG")
check "upload avatar to own folder -> 200" '[ "$code" = 200 ]'

code=$(req "$BASE/storage/v1/object/public/avatars/$ME/smoke.png")
check "public avatar is readable" '[ "$code" = 200 ]'

code=$(req -X POST "$BASE/storage/v1/object/avatars/$SARI/hack.png" "${AUTH[@]}" \
  -H 'Content-Type: image/png' --data-binary "@$PNG")
check "upload to another user's folder rejected" '[ "$code" = 400 ] || [ "$code" = 403 ]'

code=$(req -X POST "$BASE/storage/v1/object/attachments/posts/$ME/note.txt" "${AUTH[@]}" \
  -H 'Content-Type: text/plain' --data-binary 'bukan gambar')
check "non-image file rejected by the bucket" '[ "$code" != 200 ]'

code=$(req -X POST "$BASE/rest/v1/rpc/delete_post" "${AUTH[@]}" "${JSON[@]}" -d "{\"p_post_id\":\"$POST_ID\"}")
check "delete_post -> 2xx" '[ "$code" = 200 ] || [ "$code" = 204 ]'

echo
echo "smoke: $pass ok, $fail failed"
[ "$fail" -eq 0 ]
