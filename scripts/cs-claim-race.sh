#!/usr/bin/env bash
# Tes rebutan pengambilan tiket CS (docs/PROMPT-CS-REVISI-2.md bagian 2.3), berjalan di container tools:
#   1. 50 CS mengambil 1 tiket yang sama bersamaan: tepat 1 berhasil, 49 mendapat "Tiket sudah diambil oleh …".
#   2. 200 tiket diambil acak oleh 30 CS bersamaan: tidak ada tiket ganda, tidak ada CS melebihi batas 5 tiket.
# Keduanya dijalankan langsung ke fungsi database lalu lewat API PostgREST yang dibagi rata ke semua replika.
# Argumen: URL replika PostgREST (default http://rest:3000). `make cs-race` menyalakan 3 replika khusus tes.
# Data uji (CS Race NN dengan UUID tetap, nasabah race:*) dibuat di awal dan selalu dihapus di akhir.
set -uo pipefail
source "$(dirname "$0")/cs-lib.sh"

REPLICAS=("$@")
[ ${#REPLICAS[@]} -eq 0 ] && REPLICAS=(http://rest:3000)
AGENT_PREFIX=5e000000-0000-4000-8000-0000000001
RACE_AGENTS="select a.user_id from cs.agents a where a.user_id::text like '$AGENT_PREFIX%'"
RACE_CUSTOMERS="select p.id from public.profiles p where p.olt_user_id like 'race:%'"
RACE_TICKETS="select t.id from cs.tickets t where t.customer_id in ($RACE_CUSTOMERS)"
GROUP_FROM=20
WORK=$(mktemp -d)
pass=0
fail=0

check() {
  if eval "$2"; then
    echo "ok   - $1"
    pass=$((pass + 1))
  else
    echo "GAGAL - $1"
    fail=$((fail + 1))
    return 1
  fi
}

remove_race_data() {
  psql -X -q -v ON_ERROR_STOP=1 -U postgres > /dev/null <<SQL
begin;
select set_config('cs.retention', 'on', true);
create temp table race_tickets on commit drop as select t.id, t.room_id from cs.tickets t where t.id in ($RACE_TICKETS);
delete from public.messages where room_id in (select room_id from race_tickets);
delete from cs.session_events where session_id in (select id from race_tickets);
delete from cs.cs_audit_log where session_id in (select id from race_tickets) or actor_id in ($RACE_AGENTS);
delete from cs.ticket_transfers where ticket_id in (select id from race_tickets);
delete from cs.agent_notes where customer_id in ($RACE_CUSTOMERS) or author_id in ($RACE_AGENTS);
delete from cs.tickets where id in (select id from race_tickets);
delete from public.chat_rooms where id in (select room_id from race_tickets);
create temp table race_profiles on commit drop as $RACE_AGENTS union all $RACE_CUSTOMERS;
delete from cs.agents where user_id in (select user_id from race_profiles);
delete from public.profiles where id in (select user_id from race_profiles);
commit;
SQL
}

finish() {
  remove_race_data || echo "GAGAL - data uji tidak bisa dihapus" >&2
  rm -rf "$WORK"
}
trap finish EXIT

remove_race_data
psql -X -q -v ON_ERROR_STOP=1 -U postgres > /dev/null <<SQL
do \$\$
declare
  v_id uuid;
begin
  for i in 1 .. 50 loop
    perform cs.create_agent(('$AGENT_PREFIX' || lpad(i::text, 2, '0'))::uuid, 'Race ' || lpad(i::text, 2, '0'),
                            '{cs_agent}', 'general', '{"general": 1}', '{id,en}', 5);
  end loop;
  update cs.agent_status set status = 'online', last_heartbeat_at = now() where agent_id in ($RACE_AGENTS);
  for i in 1 .. 201 loop
    v_id := gen_random_uuid();
    insert into public.profiles (id, olt_user_id, username, display_name)
    values (v_id, 'race:' || v_id, 'race_' || replace(left(v_id::text, 13), '-', ''), 'Nasabah Race ' || i);
    perform cs.open_ticket(v_id, 'other', 'id', '{}', '{}', null);
  end loop;
end;
\$\$;
SQL

mapfile -t AGENTS < <(sql "$RACE_AGENTS order by a.user_id")
mapfile -t TICKETS < <(sql "$RACE_TICKETS and t.status = 'open' order by t.id")
T0=${TICKETS[0]}
printf '%s\n' "${TICKETS[@]:1}" > "$WORK/tickets"
check "persiapan: 50 CS Online dan 201 tiket open" '[ ${#AGENTS[@]} = 50 ] && [ ${#TICKETS[@]} = 201 ]'

declare -a TOKENS
for i in "${!AGENTS[@]}"; do
  TOKENS[$i]=$(agent_jwt "${AGENTS[$i]}" 900)
done

reset_tickets() {
  sql "update cs.tickets set status = 'open', owner_agent_id = null, claimed_at = null, version = version + 1
        where id in ($RACE_TICKETS) and status <> 'open';
       select cs.leave_staff(t.room_id) from cs.tickets t where t.id in ($RACE_TICKETS);
       select cs.refresh_agent_load(user_id) from ($RACE_AGENTS) a;" > /dev/null
}

claimed_events() {
  sql "select count(*) from cs.session_events where session_id = '$1' and type = 'claimed' and created_at >= '$2'"
}

start_at() { sql "select (clock_timestamp() + interval '3 seconds')::text"; }
now_db() { sql "select clock_timestamp()::text"; }

db_session() {
  echo "select pg_sleep_until('$2') as waited \\gset"
  echo "set role authenticated;"
  echo "set request.jwt.claims to '{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal2\"}';"
}

db_claim() { echo "select 'CLAIMED ' || (cs_api.claim_ticket('$1') ->> 'id');"; }

api_claim() {
  local code body="$WORK/body-$1"
  code=$(curl -sS -o "$body" -w '%{http_code}' -X POST "${REPLICAS[$(($3 % ${#REPLICAS[@]}))]}/rpc/claim_ticket" \
    -H "Authorization: Bearer ${TOKENS[$1]}" -H 'Content-Type: application/json' -H 'Content-Profile: cs_api' \
    -d "{\"p_ticket_id\":\"$2\"}")
  if [ "$code" = 200 ]; then
    echo "CLAIMED $(jq -r .id "$body")"
  else
    echo "$code $(cat "$body" 2>/dev/null)"
  fi
}

release_api_clients() {
  sleep 1
  touch "$WORK/go-$1"
  wait
}

await_go() { while [ ! -f "$WORK/go-$1" ]; do sleep 0.01; done; }

single_ticket_checks() {
  local label=$1 prefix=$2 loser=$3 since=$4 winners losers owner winner_index
  winners=$(grep -l "^CLAIMED $T0" "$WORK/$prefix"-*.out | wc -l)
  losers=$(grep -l "$loser" "$WORK/$prefix"-*.out | wc -l)
  owner=$(sql "select owner_agent_id from cs.tickets where id = '$T0'")
  winner_index=$(grep -l '^CLAIMED' "$WORK/$prefix"-*.out | head -1 | sed 's/.*-\([0-9]*\)\.out$/\1/')
  check "$label: 50 CS berebut 1 tiket bersamaan, tepat 1 berhasil" '[ "$winners" = 1 ]'
  check "$label: 49 CS lain ditolak dengan 'Tiket sudah diambil oleh Race NN'" '[ "$losers" = 49 ]' ||
    grep -hv -e '^CLAIMED' -e "$loser" "$WORK/$prefix"-*.out | sort | uniq -c | head -5 >&2
  check "$label: pemilik tiket = CS yang menerima respons berhasil" '[ "$owner" = "${AGENTS[$winner_index]:-}" ]'
  check "$label: tiket tercatat diambil tepat sekali" '[ "$(claimed_events "$T0" "$since")" = 1 ]'
}

many_tickets_checks() {
  local label=$1 prefix=$2 since=$3 doubles over drift full
  for i in $(seq $GROUP_FROM 49); do
    sed -n "s/^CLAIMED /${AGENTS[$i]} /p" "$WORK/$prefix-$i.out"
  done | sort > "$WORK/$prefix.client"
  sql "select owner_agent_id || ' ' || id from cs.tickets where id in ($RACE_TICKETS) and status = 'claimed'" \
    | sort > "$WORK/$prefix.db"
  doubles=$(sql "select count(*) from (select session_id from cs.session_events
                 where session_id in ($RACE_TICKETS) and type = 'claimed' and created_at >= '$since'
                 group by session_id having count(*) > 1) x")
  over=$(sql "select count(*) from cs.agents a where a.user_id in ($RACE_AGENTS)
              and cs.active_ticket_count(a.user_id) > a.max_active_tickets")
  drift=$(sql "select count(*) from cs.agent_status st where st.agent_id in ($RACE_AGENTS)
               and st.active_tickets <> cs.active_ticket_count(st.agent_id)")
  full=$(sql "select count(*) from ($RACE_AGENTS) a where cs.active_ticket_count(a.user_id) = 5")
  check "$label: total 150 tiket diambil (30 CS × batas 5)" '[ "$(wc -l < "$WORK/$prefix.db")" = 150 ]'
  check "$label: tidak ada tiket yang diambil dua kali" '[ "$doubles" = 0 ]'
  check "$label: respons berhasil yang diterima CS sama persis dengan pemilik di database" \
    'cmp -s "$WORK/$prefix.client" "$WORK/$prefix.db"'
  check "$label: tidak ada CS melebihi batas 5 tiket aktif" '[ "$over" = 0 ]'
  check "$label: semua 30 CS mendapat tepat 5 tiket" '[ "$full" = 30 ]'
  check "$label: hitungan beban CS (active_tickets) konsisten" '[ "$drift" = 0 ]'
}

since=$(now_db)
start=$(start_at)
for i in "${!AGENTS[@]}"; do
  { db_session "${AGENTS[$i]}" "$start"; db_claim "$T0"; } \
    | psql -X -q -tA -U postgres > "$WORK/db1-$i.out" 2>&1 &
done
wait
single_ticket_checks "DB" db1 '^DETAIL: *Tiket sudah diambil oleh Race [0-9]' "$since"

reset_tickets
since=$(now_db)
start=$(start_at)
for i in $(seq $GROUP_FROM 49); do
  { db_session "${AGENTS[$i]}" "$start"; shuf "$WORK/tickets" | while read -r t; do db_claim "$t"; done; } \
    | psql -X -q -tA -U postgres > "$WORK/db2-$i.out" 2>&1 &
done
wait
many_tickets_checks "DB 200 tiket × 30 CS" db2 "$since"

ready=0
for url in "${REPLICAS[@]}"; do
  for _ in $(seq 1 120); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url/" || true)
    if [ "$code" != 000 ] && [ "$code" != 503 ]; then
      ready=$((ready + 1))
      break
    fi
    sleep 0.5
  done
done
check "API: ${#REPLICAS[@]} replika PostgREST siap" '[ "$ready" = ${#REPLICAS[@]} ]'

reset_tickets
since=$(now_db)
for i in "${!AGENTS[@]}"; do
  ( await_go api1; api_claim "$i" "$T0" "$i" > "$WORK/api1-$i.out" ) &
done
release_api_clients api1
single_ticket_checks "API ${#REPLICAS[@]} replika" api1 '^409 .*"details":"Tiket sudah diambil oleh Race [0-9]' "$since"

reset_tickets
since=$(now_db)
for i in $(seq $GROUP_FROM 49); do
  (
    await_go api2
    got=0
    n=$i
    while read -r ticket; do
      n=$((n + 1))
      result=$(api_claim "$i" "$ticket" "$n")
      echo "$result" >> "$WORK/api2-$i.out"
      [[ $result == CLAIMED* ]] && got=$((got + 1))
      [ "$got" -ge 5 ] && break
    done < <(shuf "$WORK/tickets")
  ) &
done
release_api_clients api2
many_tickets_checks "API ${#REPLICAS[@]} replika, 200 tiket × 30 CS" api2 "$since"

echo
echo "Hasil: $pass ok, $fail gagal (replika API: ${#REPLICAS[@]})"
[ "$fail" -eq 0 ]
