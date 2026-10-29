#!/usr/bin/env bash
# Smoke test end-to-end lewat Kong, meniru client Flutter:
# exchange token mock -> JWT -> RPC/REST -> storage.
# Butuh stack berjalan, seed terpasang, dan AUTH_BRIDGE_OLT_MODE=mock.
# Data yang dibuat (1 post) di-soft-delete di akhir; user uji ban dihapus.
set -uo pipefail

BASE="${SUPABASE_URL:-http://kong:8000}"
: "${ANON_KEY:?ANON_KEY wajib diisi}"
BODY=/tmp/smoke-body
pass=0
fail=0

check() {
  if eval "$2"; then
    echo "ok   - $1"
    pass=$((pass + 1))
  else
    echo "GAGAL - $1 (status $code: $(head -c 300 "$BODY"))"
    fail=$((fail + 1))
  fi
}
req() { curl -sS -o "$BODY" -w '%{http_code}' "$@"; }
json() { jq -r "$1" "$BODY"; }

# --- auth-bridge ------------------------------------------------------------
code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{"token":"mock:1001:budi_santoso"}')
check "exchange token mock -> 200" '[ "$code" = 200 ]'
JWT=$(json .access_token)
ME=$(json .user.id)
check "id user = UUID v5 yang sama dengan seed" '[ "$ME" = "72689cd3-ea55-584f-9e84-c257af0564e0" ]'

code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{"token":"bukan-token-valid"}')
check "token OLT tidak valid -> 401" '[ "$code" = 401 ]'

code=$(req -X POST "$BASE/bridge/v1/exchange" -H 'Content-Type: application/json' \
  -d '{"token":"mock:1001:budi_santoso"}')
check "exchange tanpa apikey ditolak Kong -> 401" '[ "$code" = 401 ]'

# User di-ban: user sekali pakai dibuat lewat exchange, di-ban langsung di DB,
# lalu dihapus lagi (sanksi ikut terhapus lewat cascade).
sql() { psql -U postgres -X -q -t -A -v ON_ERROR_STOP=1 -c "$1"; }
BAN_OLT_ID="99$(date +%s)$((RANDOM % 1000))"
code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d "{\"token\":\"mock:$BAN_OLT_ID:smoke_ban\"}")
BAN_JWT=$(json .access_token)
BAN_ID=$(json .user.id)
if [ "$code" = 200 ] && sql "insert into private.user_sanctions (user_id, kind, reason, ends_at)
    values ('$BAN_ID', 'ban', 'smoke test', now() + interval '10 minutes')" > /dev/null; then
  # Token berbeda (nama tampilan) agar tidak dilayani cache verifikasi.
  code=$(req -X POST "$BASE/bridge/v1/exchange" -H "apikey: $ANON_KEY" \
    -H 'Content-Type: application/json' -d "{\"token\":\"mock:$BAN_OLT_ID:smoke_ban:Smoke Ban\"}")
  check "exchange user yang di-ban -> 403 user_banned" '[ "$code" = 403 ] && [ "$(json .error)" = user_banned ]'
  code=$(req "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $BAN_JWT")
  check "JWT lama user yang di-ban ditolak PostgREST -> 403" '[ "$code" = 403 ]'
else
  check "siapkan user di-ban (exchange + sanksi)" 'false'
fi
if [ -n "$BAN_ID" ] && [ "$BAN_ID" != null ]; then
  sql "delete from public.profiles where id = '$BAN_ID'" > /dev/null || echo "PERINGATAN: user uji $BAN_ID gagal dihapus" >&2
fi

AUTH=(-H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT")
JSON=(-H 'Content-Type: application/json')

# --- feed & post -------------------------------------------------------------
code=$(req "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=5" "${AUTH[@]}")
check "get_feed global -> 200 berisi post" '[ "$code" = 200 ] && [ "$(json length)" -ge 1 ]'

code=$(req "$BASE/rest/v1/rpc/get_feed?p_scope=global" -H "apikey: $ANON_KEY")
check "get_feed tanpa JWT user ditolak" '[ "$code" = 401 ] || [ "$code" = 403 ]'

code=$(req -X POST "$BASE/rest/v1/posts" "${AUTH[@]}" "${JSON[@]}" -H 'Prefer: return=representation' \
  -d "{\"author_id\":\"$ME\",\"body\":\"Smoke test \$BBCA $(date +%s)\",\"sentiment\":\"neutral\"}")
check "buat post -> 201" '[ "$code" = 201 ]'
POST_ID=$(json '.[0].id')

code=$(req "$BASE/rest/v1/rpc/get_post?p_post_id=$POST_ID" "${AUTH[@]}")
check "post baru bertag BBCA" '[ "$code" = 200 ] && [ "$(json ".[0].stock_codes[0]")" = BBCA ]'

code=$(req -X POST "$BASE/rest/v1/posts" "${AUTH[@]}" "${JSON[@]}" \
  -d '{"author_id":"00000000-0000-0000-0000-000000000000","body":"palsu"}')
check "post atas nama orang lain ditolak RLS" '[ "$code" = 403 ] || [ "$code" = 401 ]'

code=$(req -X POST "$BASE/rest/v1/rpc/create_comment" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"p_post_id\":\"$POST_ID\",\"p_parent_id\":null,\"p_body\":\"Komentar smoke test\"}")
check "create_comment -> 200" '[ "$code" = 200 ] && [ "$(json ".[0].depth")" = 0 ]'

code=$(req -X POST "$BASE/rest/v1/reactions" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"user_id\":\"$ME\",\"target_type\":\"post\",\"target_id\":\"$POST_ID\"}")
check "like post -> 201" '[ "$code" = 201 ]'

code=$(req "$BASE/rest/v1/rpc/get_comment_thread?p_post_id=a0000000-0000-4000-8000-000000000001&p_max_depth=10&p_replies_limit=10" "${AUTH[@]}")
check "thread seed berisi 5 level" '[ "$code" = 200 ] && [ "$(json "map(.depth) | max")" = 4 ]'

# --- chat --------------------------------------------------------------------
code=$(req "$BASE/rest/v1/rpc/get_profile?p_username=sari_invest" "${AUTH[@]}")
SARI=$(json '.[0].id')
check "get_profile by username" '[ "$code" = 200 ] && [ -n "$SARI" ] && [ "$SARI" != null ]'

code=$(req -X POST "$BASE/rest/v1/rpc/get_or_create_direct_room" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"p_other_user_id\":\"$SARI\"}")
ROOM=$(json .)
check "DM memakai room seed yang sudah ada" '[ "$ROOM" = "d0000000-0000-4000-8000-000000000001" ]'

code=$(req -X POST "$BASE/rest/v1/rpc/send_message" "${AUTH[@]}" "${JSON[@]}" \
  -d "{\"p_room_id\":\"$ROOM\",\"p_body\":\"Smoke test chat\",\"p_client_id\":\"$(cat /proc/sys/kernel/random/uuid)\"}")
check "send_message -> 200" '[ "$code" = 200 ] && [ "$(json ".[0].sender_username")" = budi_santoso ]'

code=$(req "$BASE/rest/v1/rpc/get_my_rooms" "${AUTH[@]}")
check "get_my_rooms memuat DM" '[ "$code" = 200 ] && [ "$(json "map(select(.id == \"$ROOM\")) | length")" = 1 ]'

# --- storage -----------------------------------------------------------------
PNG=/tmp/smoke.png
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d > "$PNG"

code=$(req -X POST "$BASE/storage/v1/object/avatars/$ME/smoke.png" "${AUTH[@]}" \
  -H 'Content-Type: image/png' -H 'x-upsert: true' --data-binary "@$PNG")
check "upload avatar ke folder sendiri -> 200" '[ "$code" = 200 ]'

code=$(req "$BASE/storage/v1/object/public/avatars/$ME/smoke.png")
check "avatar publik bisa dibaca" '[ "$code" = 200 ]'

code=$(req -X POST "$BASE/storage/v1/object/avatars/$SARI/hack.png" "${AUTH[@]}" \
  -H 'Content-Type: image/png' --data-binary "@$PNG")
check "upload ke folder user lain ditolak" '[ "$code" = 400 ] || [ "$code" = 403 ]'

code=$(req -X POST "$BASE/storage/v1/object/attachments/posts/$ME/note.txt" "${AUTH[@]}" \
  -H 'Content-Type: text/plain' --data-binary 'bukan gambar')
check "file non-gambar ditolak bucket" '[ "$code" != 200 ]'

# --- bersih-bersih -------------------------------------------------------------
code=$(req -X POST "$BASE/rest/v1/rpc/delete_post" "${AUTH[@]}" "${JSON[@]}" -d "{\"p_post_id\":\"$POST_ID\"}")
check "delete_post -> 2xx" '[ "$code" = 200 ] || [ "$code" = 204 ]'

echo
echo "smoke: $pass ok, $fail gagal"
[ "$fail" -eq 0 ]
