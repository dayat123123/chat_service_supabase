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

# CS chat attachments (0131): documents and videos via /media/v1, checked by content, scanned by clamd.
sql() { psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -c "$1"; }
ROOM=$(sql "select id from public.chat_rooms where type = 'support' and customer_id = '$BUDI_ID' order by created_at desc limit 1")
OPENED=""
if [ -z "$ROOM" ]; then
  code=$(post "$BASE/rest/v1/rpc/open_ticket" '{"p_topic":"account","p_screen":"help"}' -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $JWT" -H 'Content-Profile: cs_api')
  ROOM=$(json '.room_id // empty')
  OPENED=$(json '.id // empty')
fi
check "customer has a support room for CS attachments" '[ -n "$ROOM" ]'
CS_DIR="rooms/$ROOM/$BUDI_ID/$NAME"
cs_upload() { curl -sS -o "$BODY" -w '%{http_code}' -X POST "$BASE/media/v1/object/$1/$CS_DIR/$2" -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/octet-stream' --data-binary "@$3"; }
fetch() { curl -sS -o "$2" -w '%{http_code}' "$BASE/storage/v1/object/authenticated/$1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT"; }
fixture() { awk -v want="$1" '/^[A-Z0-9]+_B64$/ { on = ($0 == want); next } on' <<'FIXTURES' | base64 -d > "$2"
DOCX_B64
UEsDBBQAAAAIANuSaV3JTxqw7gAAAK4BAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QvU7DMBSF
d57C8opiBwaEUJwO/IzAUB7Asm8SC/va8r0N6dujtKUDKszn5zs63WZJUcxQKWQ08ka1UgC67AOO
Rn5sX5p7KYgtehszgpF7ILnpr7rtvgCJJUUkIyfm8qA1uQmSJZUL4JLikGuyTCrXURfrPu0I+rZt
77TLyIDc8Noh++4JBruLLJ4XBjwOqRBJisejcWUZaUuJwVkOGfWM/helORFUhXjw0BQKXS8pSn2R
sCp/A065txlqDR7Eu638ahMYqb9y9dpnt0uArP6vubAzD0NwcM6vbaVmB0QBxxTVWUk24M9+fbi7
/wZQSwMEFAAAAAgA25JpXbmBRHGzAAAAKgEAAAsAAABfcmVscy8ucmVsc43PsY7CMBAE0J6vsLa/
OFyBEIpDczqJFoUPsOxNYmHvWl7fEf6ehgIQBe1o9EbT7ZcU1T8WCUwG1k0LCsmxDzQZOA2/X1tQ
Ui15G5nQwBUF9v2qO2K0NTDJHLKoJUUSA3Oteae1uBmTlYYz0pLiyCXZKg2XSWfrznZC/d22G10e
DeifTHXwBsrBr0EN14yf2DyOweEPu7+EVN9MvDRADbZMWA1cuHjt73GzpAi67/TTxf4GUEsDBBQA
AAAIANuSaV06D2lXqQAAAN8AAAARAAAAd29yZC9kb2N1bWVudC54bWxFzj0OwjAMBeCdU0TZaQoD
QlV/BiQuABwgNKatiO0oDrTcHqUMLN8brKfnulvQqzdEmZgavStKrYB6dhMNjb5dz9ujVpIsOeuZ
oNEfEN21m3quHPcvBEpqQU9SzY0eUwqVMdKPgFYKDkAL+gdHtEkKjoOZOboQuQeRiQb0Zl+WB4N2
It3Wc3Vn98kZMjGT2gvyE1QCScrxMy+q06U2+ZSNq2H1Vzf/19ovUEsBAhQAFAAAAAgA25JpXclP
GrDuAAAArgEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAAUAAAA
CADbkmlduYFEcbMAAAAqAQAACwAAAAAAAAAAAAAAgAEfAQAAX3JlbHMvLnJlbHNQSwECFAAUAAAA
CADbkmldOg9pV6kAAADfAAAAEQAAAAAAAAAAAAAAgAH7AQAAd29yZC9kb2N1bWVudC54bWxQSwUG
AAAAAAMAAwC5AAAA0wIAAAAA
MACRO_B64
UEsDBBQAAAAIANuSaV3JTxqw7gAAAK4BAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QvU7DMBSF
d57C8opiBwaEUJwO/IzAUB7Asm8SC/va8r0N6dujtKUDKszn5zs63WZJUcxQKWQ08ka1UgC67AOO
Rn5sX5p7KYgtehszgpF7ILnpr7rtvgCJJUUkIyfm8qA1uQmSJZUL4JLikGuyTCrXURfrPu0I+rZt
77TLyIDc8Noh++4JBruLLJ4XBjwOqRBJisejcWUZaUuJwVkOGfWM/helORFUhXjw0BQKXS8pSn2R
sCp/A065txlqDR7Eu638ahMYqb9y9dpnt0uArP6vubAzD0NwcM6vbaVmB0QBxxTVWUk24M9+fbi7
/wZQSwMEFAAAAAgA25JpXbmBRHGzAAAAKgEAAAsAAABfcmVscy8ucmVsc43PsY7CMBAE0J6vsLa/
OFyBEIpDczqJFoUPsOxNYmHvWl7fEf6ehgIQBe1o9EbT7ZcU1T8WCUwG1k0LCsmxDzQZOA2/X1tQ
Ui15G5nQwBUF9v2qO2K0NTDJHLKoJUUSA3Oteae1uBmTlYYz0pLiyCXZKg2XSWfrznZC/d22G10e
DeifTHXwBsrBr0EN14yf2DyOweEPu7+EVN9MvDRADbZMWA1cuHjt73GzpAi67/TTxf4GUEsDBBQA
AAAIANuSaV06D2lXqQAAAN8AAAARAAAAd29yZC9kb2N1bWVudC54bWxFzj0OwjAMBeCdU0TZaQoD
QlV/BiQuABwgNKatiO0oDrTcHqUMLN8brKfnulvQqzdEmZgavStKrYB6dhMNjb5dz9ujVpIsOeuZ
oNEfEN21m3quHPcvBEpqQU9SzY0eUwqVMdKPgFYKDkAL+gdHtEkKjoOZOboQuQeRiQb0Zl+WB4N2
It3Wc3Vn98kZMjGT2gvyE1QCScrxMy+q06U2+ZSNq2H1Vzf/19ovUEsDBBQAAAAIANuSaV3BswQk
CgAAAAgAAAATAAAAd29yZC92YmFQcm9qZWN0LmJpbrtwXvCBQllSIgBQSwECFAAUAAAACADbkmld
yU8asO4AAACuAQAAEwAAAAAAAAAAAAAAgAEAAAAAW0NvbnRlbnRfVHlwZXNdLnhtbFBLAQIUABQA
AAAIANuSaV25gURxswAAACoBAAALAAAAAAAAAAAAAACAAR8BAABfcmVscy8ucmVsc1BLAQIUABQA
AAAIANuSaV06D2lXqQAAAN8AAAARAAAAAAAAAAAAAACAAfsBAAB3b3JkL2RvY3VtZW50LnhtbFBL
AQIUABQAAAAIANuSaV3BswQkCgAAAAgAAAATAAAAAAAAAAAAAACAAdMCAAB3b3JkL3ZiYVByb2pl
Y3QuYmluUEsFBgAAAAAEAAQA+gAAAA4DAAAAAA==
MP4_B64
AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAABEttZGF0AAACpgYF//+i
3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NCByMzEwOCAtIEguMjY0L01QRUctNCBBVkMg
Y29kZWMgLSBDb3B5bGVmdCAyMDAzLTIwMjMgLSBodHRwOi8vd3d3LnZpZGVvbGFuLm9yZy94MjY0
Lmh0bWwgLSBvcHRpb25zOiBjYWJhYz0xIHJlZj0xNiBkZWJsb2NrPTE6MDowIGFuYWx5c2U9MHgz
OjB4MTMzIG1lPXVtaCBzdWJtZT0xMCBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0x
IG1lX3JhbmdlPTI0IGNocm9tYV9tZT0xIHRyZWxsaXM9MiA4eDhkY3Q9MSBjcW09MCBkZWFkem9u
ZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTIgbG9va2Fo
ZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2Vk
PTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz04IGJfcHlyYW1p
ZD0yIGJfYWRhcHQ9MiBiX2JpYXM9MCBkaXJlY3Q9MyB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWln
aHRwPTIga2V5aW50PTEwIGtleWludF9taW49MSBzY2VuZWN1dD00MCBpbnRyYV9yZWZyZXNoPTAg
cmNfbG9va2FoZWFkPTEwIHJjPWNyZiBtYnRyZWU9MSBjcmY9NDUuMCBxY29tcD0wLjYwIHFwbWlu
PTAgcXBtYXg9NjkgcXBzdGVwPTQgaXBfcmF0aW89MS40MCBhcT0xOjEuMDAAgAAAAQhliIEAE//M
ypxdDdl55VX0nCrORo80/k0tYm6ak9OzdPCOzzggaraAfOmjMkC/dvZapWP0j83swm1vH+12XYNZ
yUc6YRW9yXwnBFPyoaCQUKCOlhPWVr53D6l45FcyAdDC56rJTHZfEmhJfrz3bBALpVRdePvnSkBl
ILRPeWFvG0NnIPzyrfNX776MQQqQCzIvo/UJb0bxD3IBtgrb1awQRncqABc3d5MutSjc+rSporlw
QTmdWzx83wCqXVfeuhRyLQdtEA1cL0eQ3f4eWO6qdpAYKVTJLMiHt2vgp6D2KcWW35AihsdPBWX7
b0f6KzynMLSEltETa/FeY2EXf60HqssL24c+3/0AAAAbQZoJDYjPjL4HI27P+6oFhy+8IGDTUlyN
PNagAAAAC0GeEIcRX7lr3W3HAAAACQGeGCaIz7nloAAAAAoBnhhGiM+66oP5AAAACgGeGGaIz7rq
g/kAAAAIAZ4YrUjPqYEAAAAIAZ4YzUjPqYEAAAAIAZ4Y7UjPqYAAAAAOQZoZKTUCAtEymBGfe0AA
AAPgbW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAA+gAAQAAAQAAAAAAAAAAAAAAAAEAAAAA
AAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AgAAAr90cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAA+gAAAAAAAAAAAAAAAAAAAAA
AAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAEAAAABAAAAAAAAkZWR0cwAAABxl
bHN0AAAAAAAAAAEAAAPoAAAIAAABAAAAAAI3bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAAAoAAAA
KABVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAAB4m1p
bmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAA
AQAAAaJzdGJsAAAAwnN0c2QAAAAAAAAAAQAAALJhdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA
AEAAQABIAAAASAAAAAAAAAABFUxhdmM2MC4zMS4xMDIgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAA
OGF2Y0MBZAAK/+EAGmdkAAqscgREJsBEAAADAAQAAAMAUDxIlhGAAQAHaOhDgTSyLP34+AAAAAAQ
cGFzcAAAAAEAAAABAAAAFGJ0cnQAAAAAAAAiGAAAIhgAAAAYc3R0cwAAAAAAAAABAAAACgAABAAA
AAAUc3RzcwAAAAAAAAABAAAAAQAAAEBjdHRzAAAAAAAAAAYAAAABAAAIAAAAAAEAACQAAAAAAQAA
EAAAAAADAAAAAAAAAAMAAAQAAAAAAQAACAAAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAoAAAABAAAA
PHN0c3oAAAAAAAAAAAAAAAoAAAO2AAAAHwAAAA8AAAANAAAADgAAAA4AAAAMAAAADAAAAAwAAAAS
AAAAFHN0Y28AAAAAAAAAAQAAADAAAACtdWR0YQAAAIJtZXRhAAAAAAAAACFoZGxyAAAAAAAAAABt
ZGlyYXBwbAAAAAAAAAAAAAAAAFVpbHN0AAAAKKluYW0AAAAgZGF0YQAAAAEAAAAAU01PS0UtR1BT
LU1BUktFUgAAACWpdG9vAAAAHWRhdGEAAAABAAAAAExhdmY2MC4xNi4xMDAAAAAjbG9jaQAAAAAA
AAAAAFaQYgAbl3MikgAAZWFydGgAAA==
FIXTURES
}
fixture DOCX_B64 /tmp/smoke.docx
fixture MACRO_B64 /tmp/smoke-macro.docx
fixture MP4_B64 /tmp/smoke-clip.mp4
printf 'nama;saldo;catatan\nBudi Santoso;1500000;rekening koran Oktober\n' > /tmp/smoke.csv
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/smoke-eicar.txt

code=$(cs_upload cs-documents laporan.bin /tmp/smoke.docx)
DOC_PATH=$(json .path)
check "DOCX via /media/v1 -> 200, type from content, stored as .docx" \
  '[ "$code" = 200 ] && [ "$(json .mime)" = application/vnd.openxmlformats-officedocument.wordprocessingml.document ] && [ "$DOC_PATH" = "$CS_DIR/laporan.docx" ]'
code=$(fetch "cs-documents/$DOC_PATH" /tmp/smoke-docx-stored)
check "stored DOCX is byte for byte the upload" '[ "$code" = 200 ] && cmp -s /tmp/smoke.docx /tmp/smoke-docx-stored'
code=$(cs_upload cs-documents rekening.csv /tmp/smoke.csv)
check "CSV via /media/v1 -> 200 text/csv" '[ "$code" = 200 ] && [ "$(json .mime)" = text/csv ] && [ "$(json .path)" = "$CS_DIR/rekening.csv" ]'
code=$(cs_upload cs-documents makro.docx /tmp/smoke-macro.docx)
check "DOCX with a VBA project rejected 422 office_macro" '[ "$code" = 422 ] && [ "$(json .code)" = office_macro ]'
code=$(cs_upload cs-documents eicar.txt /tmp/smoke-eicar.txt)
check "EICAR test file rejected by clamd 422 malware_detected" '[ "$code" = 422 ] && [ "$(json .code)" = malware_detected ]'
code=$(cs_upload cs-documents program.pdf /tmp/smoke-fake.jpg)
check "text renamed to .pdf rejected 415 unsupported_type" '[ "$code" = 415 ] && [ "$(json .code)" = unsupported_type ]'

code=$(cs_upload cs-videos layar.mov /tmp/smoke-clip.mp4)
VIDEO_PATH=$(json .path)
THUMB_PATH=$(json .thumbnail)
check "MP4 via /media/v1 -> 200 with duration, size, and thumbnail" \
  '[ "$code" = 200 ] && [ "$(json .mime)" = video/mp4 ] && [ "$VIDEO_PATH" = "$CS_DIR/layar.mp4" ] && [ "$THUMB_PATH" = "$CS_DIR/layar.jpg" ] && [ "$(json .width)" = 64 ] && [ "$(json .height)" = 64 ] && jq -e ".duration > 0.5 and .duration <= 1.5" "$BODY" > /dev/null'
code=$(fetch "cs-videos/$VIDEO_PATH" /tmp/smoke-video-stored)
check "stored video has no location or title metadata" \
  '[ "$code" = 200 ] && [ -s /tmp/smoke-video-stored ] && grep -qaF SMOKE-GPS-MARKER /tmp/smoke-clip.mp4 && ! grep -qaF SMOKE-GPS-MARKER /tmp/smoke-video-stored && ! grep -qaF 8850 /tmp/smoke-video-stored'
code=$(fetch "cs-videos/$THUMB_PATH" /tmp/smoke-thumb)
check "video thumbnail is a JPEG next to the video" '[ "$code" = 200 ] && [ "$(head -c 3 /tmp/smoke-thumb | od -An -tx1 | tr -d " ")" = ffd8ff ]'
code=$(cs_upload cs-videos bukan-video.mp4 /tmp/smoke.csv)
check "non-video to cs-videos rejected 415 unsupported_type" '[ "$code" = 415 ] && [ "$(json .code)" = unsupported_type ]'

sql "insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
     values ('cs-documents', '$CS_DIR/', 'smoke'), ('cs-videos', '$CS_DIR/', 'smoke')" > /dev/null
if [ -n "$OPENED" ]; then
  sql "select cs.finalize_ticket('$OPENED', 'other')" > /dev/null
fi

echo
echo "smoke-dummy: $pass ok, $fail failed"
[ "$fail" -eq 0 ]
