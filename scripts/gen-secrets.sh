#!/usr/bin/env bash
# Menyiapkan docker/secrets/ (Docker secrets untuk SEMUA profil) dan docker/.env.
#
# Diadaptasi dari supabase/docker/utils/generate-keys.sh (Apache License 2.0),
# yang sebagian berasal dari setup.sh karya Inder Singh (Apache License 2.0).
#
# Dijalankan di container tools oleh `make gen-secrets` (Windows: .\make.ps1 gen-secrets):
#   gen-secrets          Idempoten. Secret yang sudah ada dipertahankan. Secret yang
#                        belum ada diambil dari docker/.env lama (migrasi, mis.
#                        POSTGRES_PASSWORD) atau dibuat acak. Rahasia lalu dihapus
#                        dari docker/.env (cadangan: docker/secrets/.env.backup-*).
#   gen-secrets --force  Buat ulang SEMUA secret. PERINGATAN: password Postgres baru
#                        tidak berlaku untuk volume DB yang sudah ada (perlu
#                        `make reset` atau rotasi manual, lihat docs/operations.md).
set -euo pipefail

DOCKER_DIR="${DOCKER_DIR:-/olt/docker}"
ENV_FILE="$DOCKER_DIR/.env"
EXAMPLE_FILE="$DOCKER_DIR/.env.example"
SECRETS_DIR="$DOCKER_DIR/secrets"
force=false
[ "${1:-}" = "--force" ] && force=true

gen_hex()    { openssl rand -hex "$1"; }
gen_base64() { openssl rand -base64 "$1" | tr -d '\n'; }
gen_ed25519() { openssl genpkey -algorithm ed25519 2>/dev/null; }
b64url()     { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

sign_jwt() { # sign_jwt <secret> <payload>
  local header='{"alg":"HS256","typ":"JWT"}' content
  content="$(printf %s "$header" | b64url).$(printf %s "$2" | b64url)"
  printf '%s.%s' "$content" \
    "$(printf %s "$content" | openssl dgst -binary -sha256 -hmac "$1" | b64url)"
}

# Nilai KEY dari docker/.env (tanpa tanda kutip pembungkus). Kosong jika tidak ada
# atau masih placeholder CHANGE_ME.
env_get() {
  [ -f "$ENV_FILE" ] || return 0
  local v
  v="$(grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true)"
  v="${v%$'\r'}"
  case $v in \"*\") v="${v:1:${#v}-2}" ;; \'*\') v="${v:1:${#v}-2}" ;; esac
  case $v in CHANGE_ME*) v='' ;; esac
  printf '%s' "$v"
}

secret_get() { [ -s "$SECRETS_DIR/$1" ] && cat "$SECRETS_DIR/$1" || true; }

secret_put() { # secret_put <nama> <nilai>
  local tmp
  tmp="$(mktemp)"
  printf '%s' "$2" > "$tmp"
  cat "$tmp" > "$SECRETS_DIR/$1"
  rm -f "$tmp"
  chmod 644 "$SECRETS_DIR/$1" 2>/dev/null || true
}

# --- docker/.env (konfigurasi non-rahasia) ------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  echo "gen-secrets: membuat docker/.env dari .env.example"
fi
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

# --- secret -------------------------------------------------------------------
# nama secret -> key lama di docker/.env (untuk migrasi dari versi sebelumnya)
declare -A legacy=(
  [postgres_password]=POSTGRES_PASSWORD
  [jwt_secret]=JWT_SECRET
  [anon_key]=ANON_KEY
  [service_role_key]=SERVICE_ROLE_KEY
  [dashboard_password]=DASHBOARD_PASSWORD
  [secret_key_base]=SECRET_KEY_BASE
  [realtime_db_enc_key]=REALTIME_DB_ENC_KEY
  [pg_meta_crypto_key]=PG_META_CRYPTO_KEY
  [s3_protocol_access_key_id]=S3_PROTOCOL_ACCESS_KEY_ID
  [s3_protocol_access_key_secret]=S3_PROTOCOL_ACCESS_KEY_SECRET
)

declare -A source_of=()
resolve() { # resolve <nama> <generator...>: pertahankan -> migrasi -> buat baru
  local name="$1" value=''; shift
  if [ "$force" != true ]; then
    value="$(secret_get "$name")"
    [ -n "$value" ] && source_of[$name]=dipertahankan
    if [ -z "$value" ] && [ -n "${legacy[$name]:-}" ]; then
      value="$(env_get "${legacy[$name]}")"
      [ -n "$value" ] && source_of[$name]="dimigrasi dari .env ${legacy[$name]}"
    fi
  fi
  if [ -z "$value" ]; then
    value="$("$@")"
    source_of[$name]=dibuat
  fi
  secret_put "$name" "$value"
}

iat="$(date +%s)"
exp=$((iat + 5 * 365 * 24 * 3600)) # 5 tahun
anon_jwt()    { sign_jwt "$(secret_get jwt_secret)" "{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}"; }
service_jwt() { sign_jwt "$(secret_get jwt_secret)" "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}"; }

# Hex: aman dipakai di dalam URL koneksi Postgres.
resolve postgres_password             gen_hex 24
# >= 64 karakter.
resolve jwt_secret                    gen_base64 48
# Anon/service key ditandatangani jwt_secret: dibuat ulang bila jwt_secret baru.
if [ "${source_of[jwt_secret]}" = dibuat ]; then
  rm -f "$SECRETS_DIR/anon_key" "$SECRETS_DIR/service_role_key"
fi
resolve anon_key                      anon_jwt
resolve service_role_key              service_jwt
resolve dashboard_password            gen_hex 16
resolve secret_key_base               gen_base64 48
resolve realtime_db_enc_key           gen_hex 8
# 32 karakter: Realtime memakainya sebagai nama channel LISTEN Postgres (maks 63 byte).
resolve realtime_erlang_cookie        gen_hex 16
resolve pg_meta_crypto_key            gen_base64 24
resolve s3_protocol_access_key_id     gen_hex 16
resolve s3_protocol_access_key_secret gen_hex 32
resolve valkey_password               gen_hex 24
resolve pgbouncer_stats_password      gen_hex 24
# Password role replikasi olt_backup (layanan backup); dipasang service migrate.
resolve backup_db_password            gen_hex 24
# Kunci penanda tangan token sosial OLT dummy (hanya dev; dipakai services/dummy-olt).
resolve olt_dev_signing_key           gen_ed25519

# Kunci publik OLT (JWKS) untuk auth-bridge mode jwt. Dibuat dari kunci dev hanya bila belum ada,
# atau bila masih JWKS dev dan kuncinya baru dibuat. Produksi: isi dengan JWKS dari tim OLT;
# JWKS produksi tidak pernah ditimpa.
dev_jwks() {
  local x
  x="$(secret_get olt_dev_signing_key | openssl pkey -pubout -outform DER | tail -c 32 | b64url)"
  printf '{"keys":[{"kty":"OKP","crv":"Ed25519","kid":"dev-olt-1","alg":"EdDSA","use":"sig","x":"%s"}]}' "$x"
}
if [ -z "$(secret_get olt_jwks)" ]; then
  secret_put olt_jwks "$(dev_jwks)"
  source_of[olt_jwks]="dibuat (kunci dev)"
elif [ "${source_of[olt_dev_signing_key]}" = dibuat ] && grep -q '"kid":"dev-olt-1"' "$SECRETS_DIR/olt_jwks"; then
  secret_put olt_jwks "$(dev_jwks)"
  source_of[olt_jwks]="diperbarui (kunci dev baru)"
else
  source_of[olt_jwks]=dipertahankan
fi

# Kunci penanda tangan token integrasi csAdmin untuk nasabah-gateway (docs/nasabah/README.md).
# Kunci publiknya diisi di blok integration { public_key } pada csAdminEL.cfg.
resolve csadmin_signing_key           gen_ed25519
csadmin_public_key="$(secret_get csadmin_signing_key | openssl pkey -pubout -outform DER | openssl enc -base64 -A | tr -d '=')"

# Turunan: URI koneksi PostgREST (image tanpa shell membaca file ini lewat @file).
pooler_host="$(env_get DB_POOLER_HOST)"; pooler_port="$(env_get DB_POOLER_PORT)"; db_name="$(env_get POSTGRES_DB)"
secret_put postgrest_db_uri "postgres://authenticator:$(secret_get postgres_password)@${pooler_host:-pgbouncer}:${pooler_port:-6432}/${db_name:-postgres}"
source_of[postgrest_db_uri]=diturunkan

# --- bersihkan rahasia dari docker/.env -----------------------------------------
pattern="$(printf '%s|' "${legacy[@]}")"
pattern="^(${pattern%|})="
if grep -qE "$pattern" "$ENV_FILE"; then
  backup="$SECRETS_DIR/.env.backup-$(date -u +%Y%m%d-%H%M%S)"
  cp "$ENV_FILE" "$backup"
  chmod 600 "$backup" 2>/dev/null || true
  tmp="$(mktemp)"
  grep -vE "$pattern" "$ENV_FILE" > "$tmp" || true
  cat "$tmp" > "$ENV_FILE"
  rm -f "$tmp"
  echo "gen-secrets: rahasia dihapus dari docker/.env (cadangan: docker/secrets/$(basename "$backup"))"
fi

# Nama variabel lama -> baru (Kong tidak lagi membuka port; Traefik yang membuka).
for pair in KONG_HTTP_BIND:EDGE_HTTP_BIND KONG_HTTP_PORT:EDGE_HTTP_PORT; do
  old="${pair%%:*}" new="${pair##*:}"
  if grep -qE "^$old=" "$ENV_FILE" && ! grep -qE "^$new=" "$ENV_FILE"; then
    sed "s/^$old=/$new=/" "$ENV_FILE" > "$ENV_FILE.tmp" && cat "$ENV_FILE.tmp" > "$ENV_FILE" && rm -f "$ENV_FILE.tmp"
    echo "gen-secrets: $old diganti nama menjadi $new di docker/.env"
  fi
done

echo "gen-secrets: docker/secrets/ siap"
for name in $(printf '%s\n' "${!source_of[@]}" | sort); do
  printf '  %-30s %s\n' "$name" "${source_of[$name]}"
done
if [ "$force" = true ]; then
  echo "gen-secrets: PERINGATAN --force: secret baru tidak cocok dengan volume DB lama. Jalankan 'make reset'."
fi
echo "gen-secrets: ANON_KEY untuk client Flutter ada di docker/secrets/anon_key (make anon-key)."
echo "gen-secrets: isi public_key di blok integration csAdminEL.cfg dengan: $csadmin_public_key"
