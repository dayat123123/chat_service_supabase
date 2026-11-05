#!/usr/bin/env bash
# The temporary password is printed only once and must be changed at the first login.
set -euo pipefail
source "$(dirname "$0")/cs-lib.sh"
: "${ANON_KEY:?ANON_KEY is required}"

email=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
name=$(printf '%s' "${2:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
force=${3:-}

if ! [[ "$email" =~ ^[^@]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$ ]]; then
  echo 'Invalid email. Example: make cs-bootstrap-admin EMAIL=name@company.co.id NAME="Full Name"' >&2
  exit 2
fi
if [ "${#name}" -lt 2 ] || [ "${#name}" -gt 60 ]; then
  echo 'Name must be 2-60 characters, e.g. NAME="Full Name"' >&2
  exit 2
fi
active=$(sql "select count(*) from cs.agents where disabled_at is null and 'cs_super_admin' = any (roles)")
if [ "$active" != 0 ] && [ "$force" != "--force" ]; then
  echo "There are already $active active super admin(s). Create further accounts in the Hub (Pengaturan -> Akun CS), or re-run with FORCE=1 (Windows: -Force)." >&2
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
  echo "Could not create the login user: $(jq -r '.msg // .message // .error_description // .error // "unknown"' <<< "$created")" >&2
  exit 1
fi

if ! psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -v id="$id" -v name="$name" > /dev/null <<'SQL'
select cs.create_agent(:'id'::uuid, :'name', '{cs_super_admin}', 'general', '{}', '{id,en}', 5);
select cs.audit('agent.bootstrap', null, null, jsonb_build_object('agent', :'id'::uuid));
SQL
then
  auth_admin DELETE "users/$id" > /dev/null || true
  echo 'Could not register the super admin; the login user was rolled back.' >&2
  exit 1
fi

printf 'Super admin created.\n  Name              : %s\n  Email             : %s\n  Temporary password: %s\n' "$name" "$email" "$password"
printf 'This password is shown only once and must be changed at the first web CS login.\n'
