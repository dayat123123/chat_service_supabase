#!/usr/bin/env bash
# Membuat rahasia baru untuk docker/.env: JWT secret, anon key, service role key,
# password Postgres & dashboard, serta kunci enkripsi service lain.
#
# Diadaptasi dari supabase/docker/utils/generate-keys.sh (Apache License 2.0),
# yang sebagian berasal dari setup.sh karya Inder Singh (Apache License 2.0).
#
# Pemakaian (lewat service tools):
#   gen-keys           buat docker/.env dari .env.example bila belum ada, lalu isi rahasia.
#                      Jika .env sudah berisi rahasia, hanya mencetak kunci baru.
#   gen-keys --force   timpa rahasia di .env yang sudah ada.
#                      PERINGATAN: password Postgres baru tidak berlaku untuk volume DB
#                      yang sudah ada; jalankan `make reset` setelahnya.
set -euo pipefail

ENV_DIR="${ENV_DIR:-/olt/docker}"
ENV_FILE="$ENV_DIR/.env"
EXAMPLE_FILE="$ENV_DIR/.env.example"
force=false
[ "${1:-}" = "--force" ] && force=true

gen_hex()    { openssl rand -hex "$1"; }
gen_base64() { openssl rand -base64 "$1" | tr -d '\n'; }
b64url()     { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

sign_jwt() {
  local payload="$1" header='{"alg":"HS256","typ":"JWT"}' content
  content="$(printf %s "$header" | b64url).$(printf %s "$payload" | b64url)"
  printf '%s.%s' "$content" \
    "$(printf %s "$content" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | b64url)"
}

JWT_SECRET="$(gen_base64 48)"
iat="$(date +%s)"
exp=$((iat + 5 * 365 * 24 * 3600)) # 5 tahun

declare -A keys=(
  [JWT_SECRET]="$JWT_SECRET"
  [ANON_KEY]="$(sign_jwt "{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}")"
  [SERVICE_ROLE_KEY]="$(sign_jwt "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}")"
  [POSTGRES_PASSWORD]="$(gen_hex 16)"
  [DASHBOARD_PASSWORD]="$(gen_hex 16)"
  [SECRET_KEY_BASE]="$(gen_base64 48)"
  [REALTIME_DB_ENC_KEY]="$(gen_hex 8)"
  [PG_META_CRYPTO_KEY]="$(gen_base64 24)"
  [S3_PROTOCOL_ACCESS_KEY_ID]="$(gen_hex 16)"
  [S3_PROTOCOL_ACCESS_KEY_SECRET]="$(gen_hex 32)"
)
order=(JWT_SECRET ANON_KEY SERVICE_ROLE_KEY POSTGRES_PASSWORD DASHBOARD_PASSWORD
       SECRET_KEY_BASE REALTIME_DB_ENC_KEY PG_META_CRYPTO_KEY
       S3_PROTOCOL_ACCESS_KEY_ID S3_PROTOCOL_ACCESS_KEY_SECRET)

if [ ! -f "$ENV_FILE" ]; then
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  echo "gen-keys: membuat docker/.env dari .env.example"
elif ! grep -q '^POSTGRES_PASSWORD=CHANGE_ME' "$ENV_FILE" && [ "$force" != true ]; then
  echo "gen-keys: docker/.env sudah berisi rahasia; tidak ditimpa."
  echo "          Kunci baru di bawah hanya dicetak. Pakai --force untuk menimpa."
  echo
  for k in "${order[@]}"; do echo "$k=${keys[$k]}"; done
  exit 0
fi

# Tulis lewat file sementara lalu `cat >` agar aman di bind mount Windows.
tmp="$(mktemp)"
cp "$ENV_FILE" "$tmp"
for k in "${order[@]}"; do
  sed -i "s|^$k=.*$|$k=${keys[$k]}|" "$tmp"
done
cat "$tmp" > "$ENV_FILE"
rm -f "$tmp"

echo "gen-keys: rahasia baru ditulis ke docker/.env"
echo "          ANON_KEY (untuk client Flutter):"
echo "          ${keys[ANON_KEY]}"
echo "          Login Studio: user di DASHBOARD_USERNAME, password di DASHBOARD_PASSWORD (docker/.env)."
