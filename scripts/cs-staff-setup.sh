#!/usr/bin/env bash
# Akun staf dev untuk web CS (make cs-console): CS demo dengan ID tetap, login GoTrue email + password,
# dan faktor TOTP terverifikasi. Mencetak JSON (email, password, secret TOTP) ke stdout; make menyimpannya
# di scripts/cs-demo/runtime/staff.json (di-gitignore). JSON sebelumnya dibaca dari stdin agar secret TOTP
# yang masih aktif tidak diganti. Password diturunkan dari JWT secret lingkungan ini. Hanya untuk profil dev.
set -euo pipefail
source "$(dirname "$0")/cs-lib.sh"
: "${ANON_KEY:?ANON_KEY wajib diisi}"

AUTH="${SUPABASE_URL:-http://kong:8000}/auth/v1"
STAFF=(
  '5e000000-0000-4000-8000-0000000000d1|Nadia|nadia|{cs_agent}|general|{"general": 2, "account": 3, "funds": 2, "technical": 2}'
  '5e000000-0000-4000-8000-0000000000d2|Bima|bima|{cs_agent}|trading|{"trading": 3, "portfolio": 2, "general": 1}'
  '5e000000-0000-4000-8000-0000000000d3|Laras|laras|{cs_agent}|complaints|{"complaint": 3, "fraud": 3, "general": 1}'
  '5e000000-0000-4000-8000-0000000000d4|Sinta|sinta|{cs_supervisor}|general|{"general": 3, "complaint": 2, "fraud": 2}'
  '5e000000-0000-4000-8000-0000000000d5|Adi|adi|{cs_admin}|general|{}'
)

previous='{}'
[ -t 0 ] || previous=$(cat)
[ -n "$previous" ] || previous='{}'
now=$(date +%s)
SERVICE=$(sign "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$now,\"exp\":$((now + 600))}")

admin() {
  curl -sS -X "$1" "$AUTH/admin/$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SERVICE" \
    -H 'Content-Type: application/json' ${3:+-d "$3"}
}

as_user() {
  local body='{}'
  [ $# -lt 4 ] || body=$4
  curl -sS -X "$1" "$AUTH/$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $3" \
    -H 'Content-Type: application/json' -d "$body"
}

enroll_totp() {
  local id=$1 email=$2 password=$3 token enroll factor challenge
  for factor in $(admin GET "users/$id/factors" | jq -r '.[]?.id'); do
    admin DELETE "users/$id/factors/$factor" > /dev/null
  done
  token=$(curl -sS -X POST "$AUTH/token?grant_type=password" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" | jq -r '.access_token // empty')
  [ -n "$token" ] || { echo "Login $email gagal" >&2; exit 1; }
  enroll=$(as_user POST factors "$token" '{"factor_type":"totp","friendly_name":"CS Console (dev)"}')
  factor=$(jq -r '.id // empty' <<< "$enroll")
  [ -n "$factor" ] || { echo "Daftar TOTP $email gagal: $(jq -r '.msg // .message // .error // empty' <<< "$enroll")" >&2; exit 1; }
  TOTP_SECRET=$(jq -r '.totp.secret' <<< "$enroll")
  challenge=$(as_user POST "factors/$factor/challenge" "$token" | jq -r '.id')
  as_user POST "factors/$factor/verify" "$token" "{\"challenge_id\":\"$challenge\",\"code\":\"$(totp "$TOTP_SECRET")\"}" \
    | jq -e '.access_token' > /dev/null || { echo "Verifikasi TOTP $email gagal" >&2; exit 1; }
}

entries=()
for row in "${STAFF[@]}"; do
  IFS='|' read -r id name login roles team skills <<< "$row"
  email="$login@cs.olt.local"
  password=$(printf 'cs-staff-dev:%s' "$id" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 | tr -dc 'A-Za-z0-9' | head -c 20)
  ensure_agent "$id" "$name" "$roles" "$team" "$skills"
  user="{\"email\":\"$email\",\"password\":\"$password\",\"email_confirm\":true}"
  if [ -n "$(admin GET "users/$id" | jq -r '.id // empty')" ]; then
    admin PUT "users/$id" "$user" > /dev/null
  else
    admin POST users "$(jq -c --arg id "$id" '. + {id: $id}' <<< "$user")" > /dev/null
  fi
  TOTP_SECRET=$(jq -r --arg id "$id" '.staff[]? | select(.id == $id) | .totp_secret // empty' <<< "$previous")
  verified=$(admin GET "users/$id/factors" | jq '[.[]? | select(.status == "verified")] | length')
  if [ -z "$TOTP_SECRET" ] || [ "$verified" != 1 ]; then
    enroll_totp "$id" "$email" "$password"
  fi
  code=$(sql "select agent_code from cs.agents where user_id = '$id'")
  entries+=("$(jq -cn --arg id "$id" --arg name "$name" --arg code "$code" --arg email "$email" --arg password "$password" \
    --arg roles "$roles" --arg secret "$TOTP_SECRET" \
    '{id: $id, name: $name, agent_code: $code, email: $email, password: $password, roles: $roles, totp_secret: $secret}')")
done

sql "insert into cs.quick_replies (scope, shortcut, title, body, language)
     select v.scope, v.shortcut, v.title, v.body, 'id' from (values
       ('global', 'salam', 'Salam pembuka',
        'Halo {nama}, terima kasih sudah menghubungi CS OLT. Saya {nama_cs}, siap membantu tiket {nomor_tiket}.'),
       ('global', 'cek', 'Sedang dicek', 'Baik {nama}, mohon tunggu sebentar, saya cek dulu ya.'),
       ('global', 'order-ditolak', 'Order ditolak',
        'Order Anda ditolak sistem bursa karena harga tidak sesuai fraksi. Silakan cek detail di menu Riwayat Order lalu kirim ulang.'),
       ('global', 'penutup', 'Penutup',
        'Terima kasih {nama}. Jika masih ada pertanyaan, balas chat ini ya. Tiket {nomor_tiket} kami tandai selesai.')
     ) v(scope, shortcut, title, body)
     where not exists (select 1 from cs.quick_replies q
                       where q.scope = v.scope and q.shortcut = v.shortcut and q.language = 'id')" > /dev/null

jq -n --arg console "${CS_CONSOLE_URL:-http://localhost:8084}" --argjson staff "[$(IFS=,; echo "${entries[*]}")]" \
  '{console: $console, staff: $staff}'
