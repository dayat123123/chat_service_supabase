#!/usr/bin/env bash
# Smoke test auth-bridge MODE JWT terhadap OLT dummy (services/dummy-olt).
# Butuh: make up DUMMY_OLT=1 (dan make seed). OLT dummy menerbitkan token sosial bertanda
# tangan; auth-bridge memverifikasinya dengan kunci publik (docker/secrets/olt_jwks) tanpa
# menghubungi OLT, persis seperti produksi.
set -uo pipefail

BASE="${SUPABASE_URL:-http://kong:8000}"
OLT="${DUMMY_OLT_URL:-http://dummy-olt:8090}"
: "${ANON_KEY:?ANON_KEY wajib diisi}"
BODY=/tmp/smoke-dummy-body
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
json() { jq -r "$1" "$BODY"; }
post() { curl -sS -o "$BODY" -w '%{http_code}' -X POST "$1" -H 'Content-Type: application/json' "${@:3}" -d "$2"; }
# Login password ke OLT dummy (seperti aplikasi OLT). Respons berisi token sesi OLT dan token sosial.
olt_login() { curl -sS -X POST "$OLT/api/login" -H 'Content-Type: application/json' -d "$1"; }
social_of() { jq -r '.social_token // empty' <<< "$1"; }
session_of() { jq -r '.token // empty' <<< "$1"; }
# Token dev untuk akun apa pun (kind social = token sosial; ttl negatif = kedaluwarsa).
dev_token() { curl -sS -X POST "$OLT/api/dev/token" -H 'Content-Type: application/json' -d "$1" | jq -r '.token // empty'; }
renew() { post "$OLT/api/social-token" "{\"token\":\"$1\"}"; }
exchange() { post "$BASE/bridge/v1/exchange" "{\"token\":\"$1\"}" -H "apikey: $ANON_KEY"; }

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$BASE/bridge/v1/health" -H "apikey: $ANON_KEY")
if [ "$(json .olt_mode)" != "jwt" ]; then
  echo "auth-bridge tidak dalam mode jwt. Jalankan: make up DUMMY_OLT=1 (Windows: .\\make.ps1 up -DummyOlt)" >&2
  exit 1
fi
check "auth-bridge berjalan dalam mode jwt" 'true'

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$OLT/health")
check "OLT dummy sehat" '[ "$code" = 200 ]'

# --- login password -> token sosial -> JWT Supabase -------------------------------
BUDI=$(olt_login '{"username":"budi_santoso","password":"olt12345"}')
SOCIAL=$(social_of "$BUDI")
check "login username+password memberi token sesi OLT dan token sosial (JWT)" \
  '[[ "$(session_of "$BUDI")" == olt_* ]] && [ "$(tr -cd . <<< "$SOCIAL" | wc -c)" = 2 ]'

code=$(exchange "$SOCIAL")
check "exchange token sosial -> 200" '[ "$code" = 200 ]'
JWT=$(json .access_token)
check "id user = UUID v5 seed (olt_user_id 1001)" '[ "$(json .user.id)" = "72689cd3-ea55-584f-9e84-c257af0564e0" ]'

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=3" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT")
check "JWT hasil exchange bisa membaca feed (RLS)" '[ "$code" = 200 ] && [ "$(json length)" -ge 1 ]'

code=$(exchange "$(social_of "$(olt_login '{"email":"sari@olt.test","password":"olt12345"}')")")
check "login email+password -> exchange user sari_invest" '[ "$code" = 200 ] && [ "$(json .user.username)" = sari_invest ]'

code=$(post "$OLT/api/login" '{"username":"budi_santoso","password":"salah"}')
check "password salah ditolak OLT dummy (tanpa token)" '[ "$code" = 401 ]'

# --- token sosial baru dari sesi OLT yang masih aktif ----------------------------
code=$(renew "$(session_of "$BUDI")")
RENEWED=$(json .token)
check "sesi OLT aktif -> token sosial baru" '[ "$code" = 200 ] && [ -n "$RENEWED" ] && [ "$RENEWED" != "$SOCIAL" ]'
code=$(exchange "$RENEWED")
check "token sosial baru -> exchange 200" '[ "$code" = 200 ]'

# --- token ditolak -> 401 tanpa menghubungi OLT ------------------------------------
code=$(exchange "$(session_of "$BUDI")")
check "token sesi OLT (bukan token sosial) -> 401" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

code=$(exchange "${SOCIAL%?}x")
check "tanda tangan diubah -> 401 invalid_token" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

IFS=. read -r head payload signature <<< "$SOCIAL"
forged=$(printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -c '.sub = "1002"' | base64 -w0 | tr '/+' '_-' | tr -d '=')
code=$(exchange "$head.$forged.$signature")
check "isi token diubah (sub user lain) -> 401" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

code=$(exchange "$(dev_token '{"user":"budi_santoso","kind":"social","ttl":"-1m"}')")
check "token sosial kedaluwarsa -> 401" '[ "$code" = 401 ]'

code=$(exchange "$(dev_token '{"user":"budi_santoso","kind":"social","audience":"olt-trading"}')")
check "token untuk sistem lain (aud bukan olt-social) -> 401" '[ "$code" = 401 ]'

code=$(exchange "mock:1001:budi_santoso")
check "token mock mentah -> 401 (mode jwt hanya menerima token bertanda tangan)" '[ "$code" = 401 ]'

# --- pencabutan: OLT berhenti menerbitkan token sosial ------------------------------
code=$(post "$OLT/api/login" '{"username":"akun_suspend","password":"olt12345"}')
check "akun ditangguhkan tidak bisa login ke OLT" '[ "$code" = 403 ]'
code=$(renew "$(dev_token '{"user":"akun_suspend"}')")
check "akun ditangguhkan tidak mendapat token sosial baru" '[ "$code" = 403 ] && [ "$(json .error.code)" = ACCOUNT_SUSPENDED ]'

ANDI=$(olt_login '{"username":"andi_trader","password":"olt12345"}')
curl -sS -o /dev/null -X POST "$OLT/api/logout" -H 'Content-Type: application/json' -d "{\"token\":\"$(session_of "$ANDI")\"}"
code=$(renew "$(session_of "$ANDI")")
check "sesi OLT yang sudah logout tidak mendapat token sosial baru" '[ "$code" = 401 ]'

# --- profil otomatis & sanitasi username -------------------------------------------
code=$(exchange "$(social_of "$(olt_login '{"username":"joko_prasetyo","password":"olt12345"}')")")
check "user OLT baru -> profil dibuat otomatis" '[ "$code" = 200 ] && [ "$(json .user.username)" = joko_prasetyo ]'

code=$(exchange "$(social_of "$(olt_login '{"username":"rudi.setiawan","password":"olt12345"}')")")
check "username OLT 'rudi.setiawan' disanitasi -> rudi_setiawan" '[ "$code" = 200 ] && [ "$(json .user.username)" = rudi_setiawan ]'

# --- kompatibilitas tes lama: token mock ditukar ke token sosial lewat OLT dummy -----
code=$(renew "mock:1001:budi_santoso")
code=$(exchange "$(json .token)")
check "token mock -> token sosial dummy -> exchange 200" '[ "$code" = 200 ] && [ "$(json .user.username)" = budi_santoso ]'

# --- upload media lewat /media/v1 (cek isi file, buang EXIF/GPS) --------------------
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
check "upload langsung ke Storage tanpa layanan media ditolak" '[ "$code" != 200 ]'
code=$(upload "media/v1/object/attachments/posts/$BUDI_ID/$NAME.png" "$PHOTO")
MEDIA_PATH=$(json .path)
check "foto lewat /media/v1 -> 200, jenis dari isi file, ekstensi dibetulkan"   '[ "$code" = 200 ] && [ "$(json .mime)" = image/jpeg ] && [ "$MEDIA_PATH" = "posts/$BUDI_ID/$NAME.jpg" ]'
curl -sS -o "$STORED" "$BASE/storage/v1/object/authenticated/attachments/$MEDIA_PATH"   -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT"
check "file tersimpan tanpa EXIF/GPS dan komentar"   '[ -s "$STORED" ] && grep -qF GPSMARKER "$PHOTO" && ! grep -qF Exif "$STORED" && ! grep -qF GPSMARKER "$STORED"'
printf 'bukan gambar' > /tmp/smoke-fake.jpg
code=$(upload "media/v1/object/attachments/posts/$BUDI_ID/$NAME-palsu.jpg" /tmp/smoke-fake.jpg)
check "file palsu berekstensi .jpg ditolak 415 unsupported_type" '[ "$code" = 415 ] && [ "$(json .code)" = unsupported_type ]'
curl -sS -o /dev/null -X DELETE "$BASE/storage/v1/object/attachments/$MEDIA_PATH"   -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT"

echo
echo "smoke-dummy: $pass ok, $fail gagal"
[ "$fail" -eq 0 ]
