#!/usr/bin/env bash
# Sampler metrik selama uji beban: CPU/memori container stack, koneksi Postgres, pool PgBouncer.
# pemakaian: sample.sh <direktori-keluaran> [interval-detik]   (berhenti saat di-kill)
set -uo pipefail
source /olt/tests/lib/common.sh

dir="$1"
every="${2:-5}"
mkdir -p "$dir"
echo 'ts,container,cpu_pct,mem_mib' > "$dir/docker.csv"
echo 'ts,conn_total,conn_active,conn_idle_in_tx,lock_waits,authenticator,realtime,storage,auth' > "$dir/db.csv"
echo 'ts,user,cl_active,cl_waiting,sv_active,sv_idle,sv_used,maxwait_s' > "$dir/pgbouncer.csv"
trap 'exit 0' TERM INT
while :; do
  ts=$(date +%s)
  docker stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}}' 2>/dev/null | grep "^$STACK-" |
    awk -F, -v ts="$ts" '{
      cpu=$2; sub(/%/,"",cpu); split($3,m," / "); v=m[1]; mult=1
      if (v ~ /GiB/) mult=1024; else if (v ~ /KiB/) mult=1/1024; else if (v ~ /kB/) mult=1/1024; else if (v ~ /MB/) mult=1
      gsub(/[A-Za-z]/,"",v); printf "%s,%s,%s,%.1f\n", ts, $1, cpu, v*mult }' >> "$dir/docker.csv"
  psql -X -q -tA -F, -c "select $ts, count(*), count(*) filter (where state = 'active'), count(*) filter (where state = 'idle in transaction'),
      count(*) filter (where wait_event_type = 'Lock'), count(*) filter (where usename = 'authenticator'),
      count(*) filter (where usename = 'supabase_admin' and application_name ilike '%realtime%'),
      count(*) filter (where usename = 'supabase_storage_admin'), count(*) filter (where usename = 'supabase_auth_admin')
      from pg_stat_activity where backend_type = 'client backend'" >> "$dir/db.csv" 2>/dev/null
  PGPASSWORD="$PGPASSWORD" psql -X -q -tA -F, -h pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c 'show pools' 2>/dev/null |
    awk -F, -v ts="$ts" '$1=="postgres" {printf "%s,%s,%s,%s,%s,%s,%s,%s\n", ts, $2, $3, $4, $7, $10, $11, $14}' >> "$dir/pgbouncer.csv"
  sleep "$every"
done
