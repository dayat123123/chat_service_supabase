#!/usr/bin/env bash
# Super admin web CS pertama (dev, staging, atau produksi), dijalankan dari server lewat container tools.
# Akun berikutnya dibuat super admin dari Pengaturan -> Akun CS. Password sementara hanya dicetak sekali
# dan wajib diganti saat login pertama.
set -euo pipefail
source "$(dirname "$0")/cs-lib.sh"
: "${ANON_KEY:?ANON_KEY wajib diisi}"

email=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
name=$(printf '%s' "${2:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
force=${3:-}

if ! [[ "$email" =~ ^[^@]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$ ]]; then
  echo 'Email tidak valid. Contoh: make cs-bootstrap-admin EMAIL=nama@perusahaan.co.id NAME="Nama Lengkap"' >&2
  exit 2
fi
if [ "${#name}" -lt 2 ] || [ "${#name}" -gt 60 ]; then
  echo 'Nama wajib 2-60 karakter, mis. NAME="Nama Lengkap"' >&2
  exit 2
fi
active=$(sql "select count(*) from cs.agents where disabled_at is null and 'cs_super_admin' = any (roles)")
if [ "$active" != 0 ] && [ "$force" != "--force" ]; then
  echo "Sudah ada $active super admin aktif. Buat akun berikutnya dari Pengaturan -> Akun CS, atau ulangi dengan FORCE=1 (Windows: -Force)." >&2
  exit 3
fi

AUTH="${SUPABASE_URL:-http://kong:8000}/auth/v1"
now=$(date +%s)
SERVICE=$(sign "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$now,\"exp\":$((now + 300))}")
password=''
while [ "${#password}" -lt 20 ]; do
  password+=$(openssl rand -base64 48 | LC_ALL=C tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789')
done
password=${password:0:20}

auth_admin() {
  curl -sS -X "$1" "$AUTH/admin/$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SERVICE" \
    -H 'Content-Type: application/json' ${3:+-d "$3"}
}

created=$(auth_admin POST users "$(jq -cn --arg email "$email" --arg password "$password" \
  '{email: $email, password: $password, email_confirm: true,
    app_metadata: {cs_staff: true}, user_metadata: {must_change_password: true}}')")
id=$(jq -r '.id // empty' <<< "$created")
if [ -z "$id" ]; then
  echo "Gagal membuat user login: $(jq -r '.msg // .message // .error_description // .error // "tidak diketahui"' <<< "$created")" >&2
  exit 1
fi

if ! psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -v id="$id" -v name="$name" > /dev/null <<'SQL'
select cs.create_agent(:'id'::uuid, :'name', '{cs_super_admin}', 'general', '{}', '{id,en}', 5);
select cs.audit('agent.bootstrap', null, null, jsonb_build_object('agent', :'id'::uuid));
SQL
then
  auth_admin DELETE "users/$id" > /dev/null || true
  echo 'Gagal mendaftarkan super admin; user login dibatalkan.' >&2
  exit 1
fi

printf 'Super admin dibuat.\n  Nama              : %s\n  Email             : %s\n  Password sementara: %s\n' "$name" "$email" "$password"
printf 'Password ini hanya tampil sekali dan wajib diganti saat login pertama di web CS.\n'
