#!/usr/bin/env bash
# Helper bersama smoke-cs.sh dan cs-demo-setup.sh (berjalan di container tools).

: "${JWT_SECRET:?JWT_SECRET wajib diisi}"

sql() { psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -c "$1"; }
b64url() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

sign() {
  local head payload
  head=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '%s' "$1" | b64url)
  printf '%s.%s.%s' "$head" "$payload" \
    "$(printf '%s.%s' "$head" "$payload" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | b64url)"
}

# agent_jwt <uuid> [detik]: JWT agen seperti terbitan GoTrue setelah login email + password.
agent_jwt() {
  local now
  now=$(date +%s)
  sign "{\"sub\":\"$1\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"aal\":\"aal1\",\"iat\":$now,\"exp\":$((now + ${2:-3600}))}"
}

# ensure_agent <uuid> <nama> <peran> <tim> <skill-json>: agen dev/uji dengan ID tetap.
ensure_agent() {
  sql "select cs.create_agent('$1', '$2', '$3', '$4', '$5', '{id,en}', 5)
       where not exists (select 1 from cs.agents where user_id = '$1');
       update cs.agents set disabled_at = null where user_id = '$1';" > /dev/null
}
