#!/usr/bin/env bash
# Akun staf dev untuk web CS (make cs-staff): CS, super admin, dan kepatuhan demo dengan ID tetap, login GoTrue
# email + password tanpa TOTP. Mencetak JSON (email, password) ke stdout; make menyimpannya di
# scripts/cs-demo/runtime/staff.json (di-gitignore). Password diturunkan dari JWT secret lingkungan ini.
# Hanya untuk profil dev.
set -euo pipefail
source "$(dirname "$0")/cs-lib.sh"
: "${ANON_KEY:?ANON_KEY wajib diisi}"

AUTH="${SUPABASE_URL:-http://kong:8000}/auth/v1"
STAFF=(
  '5e000000-0000-4000-8000-0000000000d1|Nadia|nadia|{cs_agent}|general|{"general": 2, "account": 3, "funds": 2, "technical": 2}'
  '5e000000-0000-4000-8000-0000000000d2|Bima|bima|{cs_agent}|trading|{"trading": 3, "portfolio": 2, "general": 1}'
  '5e000000-0000-4000-8000-0000000000d3|Laras|laras|{cs_agent}|complaints|{"complaint": 3, "fraud": 3, "general": 1}'
  '5e000000-0000-4000-8000-0000000000d4|Sinta|sinta|{cs_super_admin}|general|{"general": 3, "complaint": 2, "fraud": 2}'
  '5e000000-0000-4000-8000-0000000000d5|Adi|adi|{cs_super_admin}|general|{}'
  '5e000000-0000-4000-8000-0000000000d6|Kirana|kirana|{compliance}|general|{}'
)

now=$(date +%s)
SERVICE=$(sign "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$now,\"exp\":$((now + 600))}")

admin() {
  curl -sS -X "$1" "$AUTH/admin/$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SERVICE" \
    -H 'Content-Type: application/json' ${3:+-d "$3"}
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
  for factor in $(admin GET "users/$id/factors" | jq -r 'if type == "array" then .[].id else empty end'); do
    admin DELETE "users/$id/factors/$factor" > /dev/null
  done
  code=$(sql "select agent_code from cs.agents where user_id = '$id'")
  entries+=("$(jq -cn --arg id "$id" --arg name "$name" --arg code "$code" --arg email "$email" --arg password "$password" \
    --arg roles "$roles" \
    '{id: $id, name: $name, agent_code: $code, email: $email, password: $password, roles: $roles}')")
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

jq -n --arg console "${CS_CONSOLE_URL:-http://localhost:8085}" --argjson staff "[$(IFS=,; echo "${entries[*]}")]" \
  '{console: $console, staff: $staff}'
