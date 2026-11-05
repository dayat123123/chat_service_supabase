#!/usr/bin/env bash
# OVERWRITES the existing data. Stop the other services first (make down) so no connections are
# active, then: make restore FILE=... CONFIRM=yes, and afterwards: make up.
set -euo pipefail

name="${1:-}"
if [ -z "$name" ]; then
  echo "restore: specify a file, e.g. restore olt-20261029-020000.dump" >&2
  ls -1 /olt/backups/*.dump 2>/dev/null | xargs -r -n1 basename >&2
  exit 2
fi
file="/olt/backups/$(basename "$name")"
if [ ! -f "$file" ]; then
  echo "restore: $file not found" >&2
  exit 1
fi
if [ "${CONFIRM:-}" != "yes" ]; then
  echo "restore: this will OVERWRITE the database. Re-run with CONFIRM=yes." >&2
  exit 1
fi

echo "restore: restoring $(basename "$file")"
PGUSER=supabase_admin pg_restore --no-password --clean --if-exists -d "${PGDATABASE:-postgres}" "$file"
echo "restore: done. Run 'make up' to start all services."
