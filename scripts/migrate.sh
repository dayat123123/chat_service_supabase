#!/usr/bin/env bash
# Menjalankan migrasi SQL bernomor di supabase/migrations secara berurutan.
#
# - Setiap file dijalankan sekali, di dalam satu transaksi.
# - Versi yang sudah dijalankan dicatat di olt_internal.schema_migrations
#   beserta checksum-nya; file yang berubah setelah dijalankan akan ditolak.
# - Dijalankan otomatis oleh service one-shot `migrate` setiap kali stack naik,
#   dan manual lewat `make migrate` (service tools).
#
# Env: PGHOST, PGPORT, PGDATABASE, PGPASSWORD (standar libpq).
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
  echo "migrate: tidak ada file migrasi di $MIGRATIONS_DIR"
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
      echo "migrate: GAGAL - $version sudah dijalankan tetapi isinya berubah." >&2
      echo "         Jangan ubah migrasi lama; buat file migrasi baru." >&2
      exit 1
    fi
    continue
  fi

  # Baris "-- olt:run-as=supabase_admin" di awal file: jalankan sebagai superuser.
  # Hanya untuk perubahan yang butuh superuser (role bawaan Supabase, tenant
  # Realtime); objek baru tetap dibuat di migrasi biasa (pemilik: postgres).
  run_as="$PGUSER" label=""
  if head -n 5 "$file" | grep -qx -- '-- olt:run-as=supabase_admin'; then
    run_as=supabase_admin label=" (sebagai supabase_admin)"
  fi

  echo "migrate: menjalankan $version$label"
  # File migrasi dan pencatatannya berada dalam satu transaksi yang sama.
  {
    echo "set client_min_messages = warning;"
    cat "$file"
    printf '\ninsert into olt_internal.schema_migrations (version, checksum) values (%s, %s);\n' \
      "'$version'" "'$checksum'"
  } | PGUSER="$run_as" psql_q --single-transaction -f -
  applied=$((applied + 1))
done

# Password role replikasi layanan backup dari Docker secret (tidak pernah ditulis di migrasi).
backup_password_file="${BACKUP_DB_PASSWORD_FILE:-/run/secrets/backup_db_password}"
if [ -s "$backup_password_file" ]; then
  backup_password="$(tr -d '\r\n' < "$backup_password_file")"
  if ! [[ "$backup_password" =~ ^[0-9a-f]{32,}$ ]]; then
    echo "migrate: GAGAL - secret backup_db_password harus hex minimal 32 karakter (make gen-secrets)." >&2
    exit 1
  fi
  # Dikirim sebagai opsi koneksi (bukan teks statement) agar tidak tercatat di log statement/pgaudit.
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
  # PostgREST juga memantau DDL lewat event trigger; ini hanya untuk memastikan.
  psql_q -c "notify pgrst, 'reload schema';"
fi

echo "migrate: selesai ($applied migrasi baru, ${#files[@]} total)"
