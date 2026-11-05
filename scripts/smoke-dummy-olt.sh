#!/usr/bin/env bash
# Needs make up DUMMY_OLT=1 and make seed. auth-bridge verifies the dummy OLT's signed social tokens
# with docker/secrets/olt_jwks without calling OLT, exactly as in production.
set -uo pipefail

BASE="${SUPABASE_URL:-http://kong:8000}"
OLT="${DUMMY_OLT_URL:-http://dummy-olt:8090}"
: "${ANON_KEY:?ANON_KEY is required}"
BODY=/tmp/smoke-dummy-body
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
json() { jq -r "$1" "$BODY"; }
post() { curl -sS -o "$BODY" -w '%{http_code}' -X POST "$1" -H 'Content-Type: application/json' "${@:3}" -d "$2"; }
olt_login() { curl -sS -X POST "$OLT/api/login" -H 'Content-Type: application/json' -d "$1"; }
social_of() { jq -r '.social_token // empty' <<< "$1"; }
session_of() { jq -r '.token // empty' <<< "$1"; }
# kind social = social token; a negative ttl = already expired.
dev_token() { curl -sS -X POST "$OLT/api/dev/token" -H 'Content-Type: application/json' -d "$1" | jq -r '.token // empty'; }
renew() { post "$OLT/api/social-token" "{\"token\":\"$1\"}"; }
exchange() { post "$BASE/bridge/v1/exchange" "{\"token\":\"$1\"}" -H "apikey: $ANON_KEY"; }

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$BASE/bridge/v1/health" -H "apikey: $ANON_KEY")
if [ "$(json .olt_mode)" != "jwt" ]; then
  echo "auth-bridge is not in jwt mode. Run: make up DUMMY_OLT=1 (Windows: .\\make.ps1 up -DummyOlt)" >&2
  exit 1
fi
check "auth-bridge runs in jwt mode" 'true'

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$OLT/health")
check "dummy OLT healthy" '[ "$code" = 200 ]'

BUDI=$(olt_login '{"username":"budi_santoso","password":"olt12345"}')
SOCIAL=$(social_of "$BUDI")
check "username+password login returns an OLT session token and a social token (JWT)" \
  '[[ "$(session_of "$BUDI")" == olt_* ]] && [ "$(tr -cd . <<< "$SOCIAL" | wc -c)" = 2 ]'

code=$(exchange "$SOCIAL")
check "exchange social token -> 200" '[ "$code" = 200 ]'
JWT=$(json .access_token)
check "user id = seed UUID v5 (olt_user_id 1001)" '[ "$(json .user.id)" = "72689cd3-ea55-584f-9e84-c257af0564e0" ]'

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=3" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT")
check "exchanged JWT can read the feed (RLS)" '[ "$code" = 200 ] && [ "$(json length)" -ge 1 ]'

code=$(exchange "$(social_of "$(olt_login '{"email":"sari@olt.test","password":"olt12345"}')")")
check "email+password login -> exchange user sari_invest" '[ "$code" = 200 ] && [ "$(json .user.username)" = sari_invest ]'

code=$(post "$OLT/api/login" '{"username":"budi_santoso","password":"salah"}')
check "wrong password rejected by the dummy OLT (no token)" '[ "$code" = 401 ]'

code=$(renew "$(session_of "$BUDI")")
RENEWED=$(json .token)
check "active OLT session -> new social token" '[ "$code" = 200 ] && [ -n "$RENEWED" ] && [ "$RENEWED" != "$SOCIAL" ]'
code=$(exchange "$RENEWED")
check "new social token -> exchange 200" '[ "$code" = 200 ]'

code=$(exchange "$(session_of "$BUDI")")
check "OLT session token (not a social token) -> 401" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

code=$(exchange "${SOCIAL%?}x")
check "tampered signature -> 401 invalid_token" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

IFS=. read -r head payload signature <<< "$SOCIAL"
forged=$(printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -c '.sub = "1002"' | base64 -w0 | tr '/+' '_-' | tr -d '=')
code=$(exchange "$head.$forged.$signature")
check "tampered payload (another user's sub) -> 401" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

code=$(exchange "$(dev_token '{"user":"budi_santoso","kind":"social","ttl":"-1m"}')")
check "expired social token -> 401" '[ "$code" = 401 ]'

code=$(exchange "$(dev_token '{"user":"budi_santoso","kind":"social","audience":"olt-trading"}')")
check "token for another system (aud is not olt-social) -> 401" '[ "$code" = 401 ]'

code=$(exchange "mock:1001:budi_santoso")
check "raw mock token -> 401 (jwt mode only accepts signed tokens)" '[ "$code" = 401 ]'

code=$(post "$OLT/api/login" '{"username":"akun_suspend","password":"olt12345"}')
check "suspended account cannot log in to OLT" '[ "$code" = 403 ]'
code=$(renew "$(dev_token '{"user":"akun_suspend"}')")
check "suspended account gets no new social token" '[ "$code" = 403 ] && [ "$(json .error.code)" = ACCOUNT_SUSPENDED ]'

ANDI=$(olt_login '{"username":"andi_trader","password":"olt12345"}')
curl -sS -o /dev/null -X POST "$OLT/api/logout" -H 'Content-Type: application/json' -d "{\"token\":\"$(session_of "$ANDI")\"}"
code=$(renew "$(session_of "$ANDI")")
check "logged-out OLT session gets no new social token" '[ "$code" = 401 ]'

code=$(exchange "$(social_of "$(olt_login '{"username":"joko_prasetyo","password":"olt12345"}')")")
check "new OLT user -> profile created automatically" '[ "$code" = 200 ] && [ "$(json .user.username)" = joko_prasetyo ]'

code=$(exchange "$(social_of "$(olt_login '{"username":"rudi.setiawan","password":"olt12345"}')")")
check "OLT username 'rudi.setiawan' sanitized -> rudi_setiawan" '[ "$code" = 200 ] && [ "$(json .user.username)" = rudi_setiawan ]'

code=$(renew "mock:1001:budi_santoso")
code=$(exchange "$(json .token)")
check "mock token -> dummy social token -> exchange 200" '[ "$code" = 200 ] && [ "$(json .user.username)" = budi_santoso ]'

BUDI_ID=72689cd3-ea55-584f-9e84-c257af0564e0
PHOTO=/tmp/smoke-photo.jpg
STORED=/tmp/smoke-stored.jpg
base64 -d > "$PHOTO" <<'B64'
/9j/4QA0RXhpZgAASUkqAAgAAAABACWIBAABAAAAGgAAAAAAAAABAAEAAgACAAAAUwAAAAAAAAD/
/gAgR1BTTUFSS0VSLU9MVCAtNi4yMDg4LDEwNi44NDU2/9sAhAAGBAUGBQQGBgUGBwcGCAoQCgoJ
CQoUDg8MEBcUGBgXFBYWGh0lHxobIxwWFiAsICMmJykqKRkfLTAtKDAlKCkoAQcHBwoIChMKChMo
GhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAAR
CAAIABADASIAAhEBAxEB/8QBogAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoLEAACAQMDAgQD
BQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygp
KjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJma
oqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+foB
AAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKCxEAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJB
UQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RV
VldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6
wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDjtL+H/T91
+ldhpfw/6fuf0rotL7V2Gl9q4sbm+J11PJ4Yz7F+77x//9k=
B64
NAME="smoke-$(date +%s)-$RANDOM"
upload() { curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/$1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT"   -H 'Content-Type: image/jpeg' --data-binary "@$2"; }

code=$(upload "storage/v1/object/attachments/posts/$BUDI_ID/$NAME-direct.jpg" "$PHOTO")
check "direct Storage upload bypassing the media service rejected" '[ "$code" != 200 ]'
code=$(upload "media/v1/object/attachments/posts/$BUDI_ID/$NAME.png" "$PHOTO")
MEDIA_PATH=$(json .path)
check "photo via /media/v1 -> 200, type from content, extension corrected"   '[ "$code" = 200 ] && [ "$(json .mime)" = image/jpeg ] && [ "$MEDIA_PATH" = "posts/$BUDI_ID/$NAME.jpg" ]'
curl -sS -o "$STORED" "$BASE/storage/v1/object/authenticated/attachments/$MEDIA_PATH"   -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT"
check "stored file has no EXIF/GPS or comment"   '[ -s "$STORED" ] && grep -qF GPSMARKER "$PHOTO" && ! grep -qF Exif "$STORED" && ! grep -qF GPSMARKER "$STORED"'
printf 'bukan gambar' > /tmp/smoke-fake.jpg
code=$(upload "media/v1/object/attachments/posts/$BUDI_ID/$NAME-palsu.jpg" /tmp/smoke-fake.jpg)
check "fake .jpg file rejected 415 unsupported_type" '[ "$code" = 415 ] && [ "$(json .code)" = unsupported_type ]'
curl -sS -o /dev/null -X DELETE "$BASE/storage/v1/object/attachments/$MEDIA_PATH"   -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT"

echo
echo "smoke-dummy: $pass ok, $fail failed"
[ "$fail" -eq 0 ]
