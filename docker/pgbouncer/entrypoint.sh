#!/bin/sh
# Client auth uses auth_query against the Supabase image's pgbouncer.get_auth(), so only the
# `pgbouncer` user's password is needed here, never the application users' passwords.
# pool_mode defaults to `session` because it works with every Supabase service (PostgREST
# LISTEN, GoTrue/Storage migrations); PGBOUNCER_POOL_MODE can switch it to `transaction`.
set -eu

: "${PGBOUNCER_AUTH_PASSWORD:?PGBOUNCER_AUTH_PASSWORD is required}"
db_host="${PGBOUNCER_DB_HOST:-db}"
db_port="${PGBOUNCER_DB_PORT:-5432}"
conf_dir="${PGBOUNCER_CONF_DIR:-/tmp/pgbouncer}"

mkdir -p "$conf_dir"
umask 077

printf '"pgbouncer" "%s"\n' "$PGBOUNCER_AUTH_PASSWORD" > "$conf_dir/userlist.txt"
# Optional `olt_stats` user for sentinel: admin console SHOW commands only. The role does
# not exist in Postgres, so it cannot open a database.
stats_users=pgbouncer
if [ -n "${PGBOUNCER_STATS_PASSWORD:-}" ]; then
  printf '"olt_stats" "%s"\n' "$PGBOUNCER_STATS_PASSWORD" >> "$conf_dir/userlist.txt"
  stats_users="pgbouncer, olt_stats"
fi

# The database host is resolved to an IP with getent (musl resolver, no cache) and re-checked
# every PGBOUNCER_DB_WATCH_SECONDS. PgBouncer 1.24 uses c-ares, which caches DNS answers for
# their TTL (600 s on Docker DNS), so after the db container gets a new IP it would keep
# dialing the old one for up to 10 minutes. On change the config is rewritten and SIGHUPed.
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
# PgBouncer's 15 s default caches the login error after a Postgres restart and rejects every
# client for 15 s even once the DB is ready. At 0.25 s, PostgREST's retries (1, 3, 7 s after a
# failure) no longer hit an error still cached from another client.
server_login_retry = ${PGBOUNCER_SERVER_LOGIN_RETRY:-0.25}
ignore_startup_parameters = extra_float_digits
# Storage sends "-c search_path=..." in the "options" startup parameter; PgBouncer only
# accepts it when the parameter is tracked, and then restores it per client.
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
    echo "pgbouncer-entrypoint: $db_host is now $addr (was $db_addr), config reloaded" >&2
    db_addr="$addr"
    write_config "$db_addr"
    kill -HUP "$pid"
  fi
done
wait "$pid"
