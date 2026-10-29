#!/usr/bin/env bash
# Smoke test auth-bridge MODE WEBSOCKET terhadap OLT dummy (services/dummy-olt).
# Butuh: make up DUMMY_OLT=1 (dan make seed). Kode auth-bridge tidak diubah;
# hanya OLT_MODE + OLT_WS_URL di docker/compose.dummy-olt.yml (default = Protokol v1).
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
# Login password ke OLT dummy (seperti aplikasi OLT), cetak token.
olt_login() { curl -sS -X POST "$OLT/api/login" -H 'Content-Type: application/json' -d "$1" | jq -r '.token // empty'; }
# Token dev untuk akun apa pun (ttl negatif = kedaluwarsa).
dev_token() { curl -sS -X POST "$OLT/api/dev/token" -H 'Content-Type: application/json' -d "$1" | jq -r '.token // empty'; }
exchange() { post "$BASE/bridge/v1/exchange" "{\"token\":\"$1\"}" -H "apikey: $ANON_KEY"; }

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$BASE/bridge/v1/health" -H "apikey: $ANON_KEY")
if [ "$(json .olt_mode)" != "websocket" ]; then
  echo "auth-bridge tidak dalam mode websocket. Jalankan: make up DUMMY_OLT=1 (Windows: .\\make.ps1 up -DummyOlt)" >&2
  exit 1
fi
check "auth-bridge berjalan dalam mode websocket" 'true'

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$OLT/health")
check "OLT dummy sehat" '[ "$code" = 200 ]'

# --- login password -> token OLT -> JWT Supabase --------------------------------
TOKEN=$(olt_login '{"username":"budi_santoso","password":"olt12345"}')
check "login username+password ke OLT dummy memberi token" '[[ "$TOKEN" == olt_* ]]'

code=$(exchange "$TOKEN")
check "exchange token OLT dummy -> 200" '[ "$code" = 200 ]'
JWT=$(json .access_token)
check "id user = UUID v5 seed (olt_user_id 1001)" '[ "$(json .user.id)" = "72689cd3-ea55-584f-9e84-c257af0564e0" ]'

code=$(curl -sS -o "$BODY" -w '%{http_code}' "$BASE/rest/v1/rpc/get_feed?p_scope=global&p_limit=3" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT")
check "JWT hasil exchange bisa membaca feed (RLS)" '[ "$code" = 200 ] && [ "$(json length)" -ge 1 ]'

SARI=$(olt_login '{"email":"sari@olt.test","password":"olt12345"}')
code=$(exchange "$SARI")
check "login email+password -> exchange user sari_invest" '[ "$code" = 200 ] && [ "$(json .user.username)" = sari_invest ]'

code=$(post "$OLT/api/login" '{"username":"budi_santoso","password":"salah"}')
check "password salah ditolak OLT dummy (tanpa token)" '[ "$code" = 401 ]'

# --- token ditolak -> 401 ------------------------------------------------------------
code=$(exchange "${TOKEN%?}x")
check "token diubah -> 401 invalid_token" '[ "$code" = 401 ] && [ "$(json .error)" = invalid_token ]'

code=$(exchange "$(dev_token '{"user":"budi_santoso","ttl":"-1m"}')")
check "token kedaluwarsa -> 401" '[ "$code" = 401 ]'

LOGOUT=$(olt_login '{"username":"andi_trader","password":"olt12345"}')
curl -sS -o /dev/null -X POST "$OLT/api/logout" -H 'Content-Type: application/json' -d "{\"token\":\"$LOGOUT\"}"
code=$(exchange "$LOGOUT")
check "token yang sudah logout -> 401" '[ "$code" = 401 ]'

code=$(exchange "$(dev_token '{"user":"akun_suspend"}')")
check "akun ditangguhkan -> 401" '[ "$code" = 401 ]'

# --- profil otomatis & sanitasi username ------------------------------------------------
code=$(exchange "$(olt_login '{"username":"joko_prasetyo","password":"olt12345"}')")
check "user OLT baru -> profil dibuat otomatis" '[ "$code" = 200 ] && [ "$(json .user.username)" = joko_prasetyo ]'

code=$(exchange "$(olt_login '{"username":"rudi.setiawan","password":"olt12345"}')")
check "username OLT 'rudi.setiawan' disanitasi -> rudi_setiawan" '[ "$code" = 200 ] && [ "$(json .user.username)" = rudi_setiawan ]'

# --- OLT lambat -> timeout auth-bridge -------------------------------------------------
start=$(date +%s)
code=$(exchange "$(dev_token '{"user":"lambat_test"}')")
elapsed=$(( $(date +%s) - start ))
check "OLT lambat (8 dtk) -> 503 olt_unavailable dalam ~5 dtk" \
  '[ "$code" = 503 ] && [ "$(json .error)" = olt_unavailable ] && [ "$elapsed" -lt 8 ]'

# --- kompatibilitas token mock (tes lama tetap jalan) ----------------------------------
code=$(exchange "mock:1001:budi_santoso")
check "token mock lama tetap diterima lewat OLT dummy" '[ "$code" = 200 ] && [ "$(json .user.username)" = budi_santoso ]'

echo
echo "smoke-dummy: $pass ok, $fail gagal"
[ "$fail" -eq 0 ]
