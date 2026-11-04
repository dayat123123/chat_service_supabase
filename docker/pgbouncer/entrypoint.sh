#!/bin/sh
# Membuat konfigurasi PgBouncer dari environment (di tmpfs), lalu menjalankannya.
#
# Autentikasi klien memakai auth_query ke fungsi bawaan image Supabase
# pgbouncer.get_auth(), sehingga password user tidak perlu disalin ke sini.
# Hanya password user `pgbouncer` (PGBOUNCER_AUTH_PASSWORD) yang dibutuhkan.
#
# Mode default `session`: kompatibel dengan semua service Supabase (LISTEN
# PostgREST, migrasi GoTrue/Storage). Bisa diganti `transaction` lewat
# PGBOUNCER_POOL_MODE tanpa mengubah kode aplikasi.
set -eu

: "${PGBOUNCER_AUTH_PASSWORD:?PGBOUNCER_AUTH_PASSWORD wajib diisi}"
db_host="${PGBOUNCER_DB_HOST:-db}"
db_port="${PGBOUNCER_DB_PORT:-5432}"
conf_dir="${PGBOUNCER_CONF_DIR:-/tmp/pgbouncer}"

mkdir -p "$conf_dir"
umask 077

printf '"pgbouncer" "%s"\n' "$PGBOUNCER_AUTH_PASSWORD" > "$conf_dir/userlist.txt"
# User `olt_stats` (opsional): hanya konsol admin (stats_users, perintah SHOW) untuk
# sentinel. Role ini tidak ada di Postgres, jadi tidak bisa membuka database.
stats_users=pgbouncer
if [ -n "${PGBOUNCER_STATS_PASSWORD:-}" ]; then
  printf '"olt_stats" "%s"\n' "$PGBOUNCER_STATS_PASSWORD" >> "$conf_dir/userlist.txt"
  stats_users="pgbouncer, olt_stats"
fi

cat > "$conf_dir/pgbouncer.ini" <<EOF
[databases]
* = host=$db_host port=$db_port

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
unix_socket_dir =

auth_type = scram-sha-256
auth_file = $conf_dir/userlist.txt
auth_user = pgbouncer
auth_query = SELECT username, password FROM pgbouncer.get_auth(\$1)
auth_dbname = ${PGBOUNCER_AUTH_DBNAME:-postgres}

pool_mode = ${PGBOUNCER_POOL_MODE:-session}
max_client_conn = ${PGBOUNCER_MAX_CLIENT_CONN:-500}
default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE:-20}
reserve_pool_size = ${PGBOUNCER_RESERVE_POOL_SIZE:-5}
max_db_connections = ${PGBOUNCER_MAX_DB_CONNECTIONS:-80}
max_prepared_statements = ${PGBOUNCER_MAX_PREPARED_STATEMENTS:-100}

server_idle_timeout = 300
server_lifetime = 3600
query_wait_timeout = ${PGBOUNCER_QUERY_WAIT_TIMEOUT:-30}
client_login_timeout = 30
# Default PgBouncer 15 dtk: setelah Postgres restart, error login di-cache dan semua
# klien ditolak 15 dtk walau DB sudah siap (T6, docs/testing/report-2026-11-03.md).
server_login_retry = ${PGBOUNCER_SERVER_LOGIN_RETRY:-1}
ignore_startup_parameters = extra_float_digits
# Storage mengirim "-c search_path=..." lewat parameter startup "options";
# PgBouncer menerimanya bila parameternya dilacak dan memulihkannya per klien.
track_extra_parameters = IntervalStyle, search_path, multigres.unsafe_connection

stats_users = $stats_users
log_connections = 0
log_disconnections = 0
log_pooler_errors = 1
EOF

exec pgbouncer "$conf_dir/pgbouncer.ini"
