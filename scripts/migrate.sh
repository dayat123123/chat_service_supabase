#!/usr/bin/env bash
# Each numbered file runs once in its own transaction. Applied versions are recorded with their
# checksum in olt_internal.schema_migrations, and a file that changed after it ran is rejected.
set -euo pipefail

MIGRATIONS_DIR="${MIGRATIONS_DIR:-/olt/supabase/migrations}"
export PGUSER="${MIGRATE_USER:-postgres}"

psql_q() {
  psql -X -q -v ON_ERROR_STOP=1 --no-password "$@"
}

psql_q <<'SQL'
set client_min_messages = warning;
create schema if not exists olt_internal;
revoke all on schema olt_internal from public;
create table if not exists olt_internal.schema_migrations (
  version    text primary key,
  checksum   text not null,
  applied_at timestamptz not null default now()
);
SQL

shopt -s nullglob
files=("$MIGRATIONS_DIR"/[0-9]*.sql)
if [ ${#files[@]} -eq 0 ]; then
  echo "migrate: no migration files in $MIGRATIONS_DIR"
  exit 0
fi

applied=0
for file in "${files[@]}"; do
  version="$(basename "$file" .sql)"
  checksum="$(sha256sum "$file" | cut -d' ' -f1)"
  existing="$(psql_q -tA -v v="$version" <<'SQL'
select checksum from olt_internal.schema_migrations where version = :'v';
SQL
)"

  if [ -n "$existing" ]; then
    if [ "$existing" != "$checksum" ]; then
      echo "migrate: FAILED - $version was already applied but its content changed." >&2
      echo "         Never edit an applied migration; add a new migration file." >&2
      exit 1
    fi
    continue
  fi

  # "-- olt:run-as=supabase_admin" near the top runs the file as superuser. Use it only for changes
  # that need one (built-in Supabase roles, Realtime tenant); new objects belong in regular
  # migrations so postgres owns them.
  run_as="$PGUSER" label=""
  if head -n 5 "$file" | grep -qx -- '-- olt:run-as=supabase_admin'; then
    run_as=supabase_admin label=" (as supabase_admin)"
  fi

  echo "migrate: applying $version$label"
  {
    echo "set client_min_messages = warning;"
    cat "$file"
    printf '\ninsert into olt_internal.schema_migrations (version, checksum) values (%s, %s);\n' \
      "'$version'" "'$checksum'"
  } | PGUSER="$run_as" psql_q --single-transaction -f -
  applied=$((applied + 1))
done

# The backup replication role password comes from a Docker secret and is never written in a migration.
backup_password_file="${BACKUP_DB_PASSWORD_FILE:-/run/secrets/backup_db_password}"
if [ -s "$backup_password_file" ]; then
  backup_password="$(tr -d '\r\n' < "$backup_password_file")"
  if ! [[ "$backup_password" =~ ^[0-9a-f]{32,}$ ]]; then
    echo "migrate: FAILED - secret backup_db_password must be at least 32 hex characters (make gen-secrets)." >&2
    exit 1
  fi
  # Passed as a connection option, not statement text, so it never reaches the statement/pgaudit logs.
  PGUSER=supabase_admin PGOPTIONS="-c olt.backup_password=$backup_password" psql_q <<'SQL'
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'olt_backup') then
    execute format('alter role olt_backup with login password %L', current_setting('olt.backup_password'));
  end if;
end;
$$;
SQL
fi

if [ "$applied" -gt 0 ]; then
  psql_q -c "notify pgrst, 'reload schema';"
fi

echo "migrate: done ($applied new, ${#files[@]} total)"
