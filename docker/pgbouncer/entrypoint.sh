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

# Host database diubah ke alamat IP lewat getent (resolver musl, tanpa cache) dan dipantau
# setiap PGBOUNCER_DB_WATCH_SECONDS. PgBouncer 1.24 memakai c-ares yang menyimpan jawaban
# DNS sampai TTL-nya (DNS Docker: 600 dtk), sehingga setelah container db dibuat ulang atau
# di-stop/start dengan IP baru PgBouncer terus menyambung ke IP lama hingga 10 menit (T6).
# Bila IP berubah, konfigurasi ditulis ulang lalu dimuat ulang dengan SIGHUP.
watch="${PGBOUNCER_DB_WATCH_SECONDS:-2}"
resolve() { getent hosts "$1" 2>/dev/null | awk 'NR == 1 { print $1 }'; }

write_config() {
cat > "$conf_dir/pgbouncer.ini.tmp" <<EOF
[databases]
* = host=$1 port=$db_port

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
# 0,25 dtk: percobaan ulang PostgREST (1, 3, 7 dtk setelah gagal) tidak lagi menabrak
# error yang masih di-cache dari klien lain (sebelumnya 1 dtk: REST pulih di percobaan
# berikutnya, +2 dtk).
server_login_retry = ${PGBOUNCER_SERVER_LOGIN_RETRY:-0.25}
ignore_startup_parameters = extra_float_digits
# Storage mengirim "-c search_path=..." lewat parameter startup "options";
# PgBouncer menerimanya bila parameternya dilacak dan memulihkannya per klien.
track_extra_parameters = IntervalStyle, search_path, multigres.unsafe_connection

stats_users = $stats_users
log_connections = 0
log_disconnections = 0
log_pooler_errors = 1
EOF
mv "$conf_dir/pgbouncer.ini.tmp" "$conf_dir/pgbouncer.ini"
}

db_addr=$(resolve "$db_host")
db_addr="${db_addr:-$db_host}"
write_config "$db_addr"

if [ "$watch" = 0 ]; then
  exec pgbouncer "$conf_dir/pgbouncer.ini"
fi

pgbouncer "$conf_dir/pgbouncer.ini" &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null' TERM
trap 'kill -INT "$pid" 2>/dev/null' INT
while kill -0 "$pid" 2>/dev/null; do
  sleep "$watch" &
  wait $! 2>/dev/null || true
  addr=$(resolve "$db_host")
  if [ -n "$addr" ] && [ "$addr" != "$db_addr" ] && kill -0 "$pid" 2>/dev/null; then
    echo "pgbouncer-entrypoint: $db_host sekarang $addr (sebelumnya $db_addr), konfigurasi dimuat ulang" >&2
    db_addr="$addr"
    write_config "$db_addr"
    kill -HUP "$pid"
  fi
done
wait "$pid"
