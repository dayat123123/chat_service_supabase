#!/usr/bin/env bash
set -euo pipefail

email=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
if ! [[ "$email" =~ ^[^@]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$ ]]; then
  echo 'Invalid email. Example: make cs-mfa-reset EMAIL=name@company.co.id' >&2
  exit 2
fi

result=$(psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -v email="$email" <<'SQL'
select private.staff_security_recover(:'email');
SQL
)
printf '2FA and the login lock were cleared for %s.\n  Result: %s\n' "$email" "$result"
printf 'All sessions of this account were signed out. At the next Hub login the staff member sets up 2FA again.\n'
