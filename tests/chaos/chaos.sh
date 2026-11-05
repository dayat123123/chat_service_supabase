#!/usr/bin/env bash
# usage: chaos.sh [experiment...]  (default all: classifier realtime pgbouncer valkey storage notifier rest db partition)
# env: CHAOS_VUS (30), CHAOS_OUTAGE (seconds a service is down, default 30),
# CHAOS_LONG_OUTAGE (classifier, default 150: must exceed the 120 s sentinel alert threshold)
set -uo pipefail
source /olt/tests/lib/common.sh

ALPINE=alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
RUN="$RESULTS/chaos-$(stamp)"
mkdir -p "$RUN"
API=$(kong_edge_url)
VUS="${CHAOS_VUS:-30}"
OUTAGE="${CHAOS_OUTAGE:-30}"
LONG="${CHAOS_LONG_OUTAGE:-150}"
experiments="${*:-classifier realtime pgbouncer valkey storage notifier rest db partition}"
REPORT="$RUN/report.tsv"
printf 'experiment\tverdict\tmetric\tvalue\n' > "$REPORT"
k6pid="" probepid=""

note() { printf '%s\t%s\t%s\t%s\n' "$EXP_NAME" "$1" "$2" "$3" >> "$REPORT"; log "  [$1] $2: $3"; }
since() { echo $(( ($(now_ms) - $1) )); }
secs() { awk -v ms="$1" 'BEGIN {printf "%.1fs", ms / 1000}'; }

app_env=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$(container auth-bridge)" | sed -n 's/^APP_ENV=//p')
[ "$app_env" = development ] || { echo "Chaos tests only run against the DEV stack (APP_ENV=$app_env)" >&2; exit 2; }

crash() {
  local pid
  pid=$(docker inspect -f '{{.State.Pid}}' "$(container "$1")")
  [ "${pid:-0}" -gt 0 ] || return 1
  docker run --rm --pid=host --privileged "$ALPINE" kill -9 "$pid" > /dev/null
}
health() { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$(container "$1")" 2>/dev/null; }
wait_state() {
  local svc="$1" want="$2" limit="${3:-240}" t0
  t0=$(date +%s)
  while [ $(( $(date +%s) - t0 )) -lt "$limit" ]; do
    [ "$(health "$svc")" = "$want" ] && return 0
    sleep 1
  done
  return 1
}

users_file="$RUN/users.json"
probe_user() {
  tokengen -prefix lt_c -start 1 -count 3 -base 9180000 -ttl 14m > "$RUN/probe-users.json"
  PROBE_JWT=$(curl -sS -X POST "$API/bridge/v1/exchange" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -H 'X-Forwarded-For: 198.51.100.61' -d "{\"token\":\"$(jq -r '.[0].token' "$RUN/probe-users.json")\"}" | jq -r '.access_token // empty')
  PROBE_ID=$(sql "select id from public.profiles where username = 'lt_c00001'")
}
rest_ok() {
  [ "$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/rest/v1/rpc/get_feed?p_limit=1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $PROBE_JWT")" = 200 ]
}
exchange_code() {
  curl -s -o /dev/null -m 5 -w '%{http_code}' -X POST "$API/bridge/v1/exchange" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -H "X-Forwarded-For: ${2:-198.51.100.62}" -d "{\"token\":\"$(jq -r ".[${1:-1}].token" "$RUN/probe-users.json")\"}"
}
JPEG=$(mktemp)
base64 -d /olt/tests/lib/fixture-photo.jpg.b64 > "$JPEG"
upload_code() {
  local name="posts/$PROBE_ID/chaos-$(date +%s%N).jpg" code
  code=$(curl -s -o "$RUN/upload.out" -m 15 -w '%{http_code}' -X POST "$API/media/v1/object/attachments/$name" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $PROBE_JWT" -H 'Content-Type: image/jpeg' --data-binary "@$JPEG")
  if [ "$code" = 200 ]; then
    local stored
    stored=$(jq -r '.path // empty' "$RUN/upload.out")
    curl -s -o /dev/null -m 5 -X DELETE "$API/storage/v1/object/attachments/${stored:-$name}" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $PROBE_JWT"
  fi
  echo "$code"
}

load_start() {
  tokengen -prefix lt_ -start 2001 -count "$VUS" -ttl 14m > "$users_file"
  k6 run --quiet --log-format raw -e API="$API" -e ANON_KEY="$ANON_KEY" -e USERS="$users_file" -e VUS="$VUS" -e RAMP=10 \
    -e HOLD="$1" -e MSG_EVERY=10 -e FEED_EVERY=30 -e POST_PROB=0 -e ROOM_CODE=LTHOT -e SUMMARY="$EXP_DIR/k6-summary.json" \
    /olt/tests/load/market-open.js > "$EXP_DIR/k6.log" 2>&1 &
  k6pid=$!
  ( while :; do
      t=$(date +%s%3N)
      c=$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$API/rest/v1/rpc/get_feed?p_limit=1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $PROBE_JWT")
      echo "$t,$c"
      sleep 1
    done ) > "$EXP_DIR/rest-probe.csv" &
  probepid=$!
  LOAD_T0=$(now_ms)
  sleep 25
}
load_stop() {
  [ -n "$probepid" ] && kill "$probepid" 2>/dev/null; probepid=""
  [ -n "$k6pid" ] && wait "$k6pid" 2>/dev/null; k6pid=""
  if [ -s "$EXP_DIR/k6-summary.json" ]; then
    jq -r '
      def c(m): (.metrics[m].values.count // 0);
      def p(m; s): ((.metrics[m].values[s] // 0) | round);
      "k6: req=\(c("http_reqs")) err=\(((.metrics.http_req_failed.values.rate // 0) * 1000 | round) / 10)% sent=\(c("msg_sent")) send_fail=\(c("msg_send_failed")) recv=\(c("rt_messages_received"))/\(c("rt_expected")) rt_window=\(c("rt_recv_window")) gap_only=\(c("rt_gap_only")) eventual=\(if c("rt_expected") > 0 then (((c("rt_recv_window") + c("rt_gap_only")) / c("rt_expected") * 1000 | round) / 10) else "-" end)% reconnected=\(c("ws_reconnected")) gap_runs=\(c("gap_runs")) gap_too_long=\(c("gap_too_long")) gap_failed=\(c("gap_failed")) pgrst003=\(c("pgrst003")) rt_p95=\(p("rt_delivery_ms"; "p(95)"))ms ws_drop=\(c("ws_dropped")) ws_fail=\(c("ws_failed")) join_fail=\(c("rt_join_failed")) login_fail=\(c("login_failed")) sessions=\(c("sessions"))"
    ' "$EXP_DIR/k6-summary.json" > "$EXP_DIR/k6-line.txt"
    note info "light load" "$(cat "$EXP_DIR/k6-line.txt")"
  fi
  if [ -n "${FAULT_T0:-}" ]; then
    r=$(recovery_from_probe "$FAULT_T0")
    note info "REST failure window (first failure -> first 200)" "$( [ "$r" = 0 ] && echo "no failed probes" || secs "${r:-999999}")"
    FAULT_T0=""
  fi
  rest_errors=$(awk -F, '$2 != 200' "$EXP_DIR/rest-probe.csv" | wc -l)
  note info "failed 1 s REST probes" "$rest_errors of $(wc -l < "$EXP_DIR/rest-probe.csv")"
  lt_msgs=$(sql "select count(*) from public.messages m join public.profiles p on p.id = m.sender_id
                 where p.username like 'lt\_0%' and m.created_at >= to_timestamp($LOAD_T0 / 1000.0)")
  sent=$(jq -r '.metrics.msg_sent.values.count // 0' "$EXP_DIR/k6-summary.json" 2>/dev/null)
  if [ "${sent:-0}" -gt 0 ]; then
    [ "$lt_msgs" -ge "$sent" ] && note ok "sent messages (200) persisted in DB" "$lt_msgs in DB >= $sent succeeded" \
      || note FAIL "messages lost" "$lt_msgs in DB < $sent succeeded"
  fi
}
recovery_from_probe() {
  awk -F, -v t="$1" '($1 + 0) >= (t + 0) { if ($2 != 200 && f == "") f = $1; if ($2 == 200 && f != "") { print $1 - f; done = 1; exit } } END { if (!done) print (f == "" ? 0 : "") }' "$EXP_DIR/rest-probe.csv"
}
alert_snapshot() {
  sql "select key || ' ' || severity || ' opened=' || to_char(opened_at, 'HH24:MI:SS') || coalesce(' resolved=' || to_char(resolved_at, 'HH24:MI:SS'), ' ACTIVE')
       from private.health_alerts where opened_at >= to_timestamp($1 / 1000.0) - interval '5 seconds' order by opened_at"
}
probe_state() { sql "select coalesce(ok::text, '?') || ' ' || coalesce(status::text, '') || ' ' || coalesce(left(error, 60), '') from private.health_probes where name = '$1'"; }

begin_exp() {
  EXP_NAME="$1"
  EXP_DIR="$RUN/$1"
  mkdir -p "$EXP_DIR"
  echo
  log "=== experiment $1: $2"
}

exp_classifier() {
  begin_exp classifier "classifier down ${LONG}s: image uploads must be rejected (fail closed), sentinel alert opens then resolves"
  load_start $((LONG + 90))
  [ "$(upload_code)" = 200 ] && note ok "upload before the fault" 200 || note FAIL "upload before the fault failed" "$(cat "$RUN/upload.out")"
  t0=$(now_ms)
  docker stop "$(container classifier)" > /dev/null
  sleep 5
  codes=""
  for _ in 1 2 3; do codes="$codes $(upload_code)"; sleep 2; done
  [[ "$codes" != *200* ]] && note ok "upload rejected while classifier is down (fail closed)" "$codes $(jq -c '{code, message}' "$RUN/upload.out" 2>/dev/null)" \
    || note FAIL "upload accepted while classifier is down" "$codes"
  note info "classifier health_probes while down" "$(probe_state classifier)"
  note info "link-preview while classifier is down" "not tested live (avoids fetching external sites); fail-closed behavior (preview without image) is covered by services/link-preview unit tests (fakeClassifier)"
  sleep $(( LONG - 11 ))
  note info "alerts after ${LONG}s down" "$(alert_snapshot "$t0" | tr '\n' ';')"
  t1=$(now_ms)
  docker start "$(container classifier)" > /dev/null
  wait_state classifier healthy 120
  note info "classifier healthy again" "$(secs "$(since "$t1")")"
  t2=$(now_ms)
  for _ in $(seq 1 60); do [ "$(upload_code)" = 200 ] && break; sleep 1; done
  note info "upload recovered after start" "$(secs "$(since "$t1")") (media checks classifier via readyz)"
  sleep 75
  note info "alerts after recovery (+75s, resolve threshold 60s)" "$(alert_snapshot "$t0" | tr '\n' ';')"
  load_stop
}

exp_realtime() {
  begin_exp realtime "crash Realtime (kill -9): clients reconnect, messages stay persisted, gap fill from horizon (get_message_ids + get_messages_by_ids)"
  load_start $((OUTAGE + 120))
  t0=$(now_ms)
  crash realtime
  wait_state realtime healthy 180 && note info "realtime healthy again after crash" "$(secs "$(since "$t0")") (restart policy)" \
    || note FAIL "realtime did not recover" "$(health realtime)"
  sleep 60
  load_stop
  k6_rejoin=$(grep -c . "$EXP_DIR/k6.log" 2>/dev/null)
  note info "channel status after recovery" "see ws_drop/sessions in the k6 line (dropped sessions log in and join again)"
}

exp_pgbouncer() {
  begin_exp pgbouncer "crash PgBouncer: PostgREST/GoTrue/Storage lose connections then recover"
  load_start $((OUTAGE + 90))
  t0=$(now_ms)
  crash pgbouncer
  wait_state pgbouncer healthy 120 && note info "pgbouncer healthy again" "$(secs "$(since "$t0")")"
  FAULT_T0=$t0
  sleep 45
  load_stop
}

exp_valkey() {
  begin_exp valkey "Valkey down ${OUTAGE}s: auth-bridge rate limit & exchange behavior"
  load_start $((OUTAGE + 90))
  docker stop "$(container valkey)" > /dev/null
  t0=$(now_ms)
  sleep 3
  note info "auth-bridge /readyz while Valkey is down" "$(curl -s -m 3 http://auth-bridge:9100/readyz | tr -d '\n')"
  c=$(exchange_code 1 198.51.100.63)
  [ "$c" = 200 ] && note ok "exchange still succeeds while Valkey is down (fail open to per-instance local limiter)" "$c" \
    || note info "exchange while Valkey is down" "$c"
  env_ab=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$(container auth-bridge)")
  lim_ip=$(sed -n 's/^RATE_LIMIT_PER_MINUTE=//p' <<< "$env_ab"); lim_user=$(sed -n 's/^RATE_LIMIT_PER_USER_PER_MINUTE=//p' <<< "$env_ab")
  burst=$(( ${lim_ip:-300} < ${lim_user:-10} ? ${lim_ip:-300} : ${lim_user:-10} ))
  burst=$(( burst + 5 ))
  codes=$(for i in $(seq 1 "$burst"); do exchange_code 2 198.51.100.64; echo; done | sort | uniq -c | tr '\n' ' ')
  [[ "$codes" == *429* ]] && note ok "per-IP/per-user limits still enforced by the local limiter ($burst exchanges for one user from 1 IP; IP limit ${lim_ip:-300}, user ${lim_user:-10})" "$codes" \
    || note FAIL "rate limits lost while Valkey is down" "$codes"
  sleep $(( OUTAGE > 10 ? OUTAGE - 8 : 1 ))
  docker start "$(container valkey)" > /dev/null
  wait_state valkey healthy 60
  sleep 3
  note info "auth-bridge /readyz after Valkey recovered" "$(curl -s -m 3 http://auth-bridge:9100/readyz | tr -d '\n') ($(secs "$(since "$t0")") since stop)"
  note info "note" "Valkey has no persistence: a restart clears rate limit windows (counters start at zero)"
  sleep 30
  load_stop
}

exp_storage() {
  begin_exp storage "Storage down ${OUTAGE}s: upload & download fail, REST keeps working"
  load_start $((OUTAGE + 90))
  docker stop "$(container storage)" > /dev/null
  t0=$(now_ms)
  sleep 3
  c=$(upload_code); [ "$c" != 200 ] && note ok "upload fails clearly while storage is down" "$c $(head -c 120 "$RUN/upload.out")" || note FAIL "upload succeeded while storage is down?" "$c"
  rest_ok && note ok "REST keeps serving while storage is down" 200 || note FAIL "REST also fails while storage is down" "-"
  sleep "$OUTAGE"
  t1=$(now_ms)
  docker start "$(container storage)" > /dev/null
  wait_state storage healthy 120 && note info "storage healthy again" "$(secs "$(since "$t1")")"
  for _ in $(seq 1 60); do [ "$(upload_code)" = 200 ] && break; sleep 1; done
  note info "upload recovered after start" "$(secs "$(since "$t1")")"
  note info "health_probes storage" "$(probe_state storage)"
  sleep 30
  load_stop
}

exp_notifier() {
  begin_exp notifier "crash notifier: recovers automatically; queue lease prevents double sends (SQL test in a rolled-back transaction)"
  t0=$(now_ms)
  crash notifier
  wait_state notifier healthy 120 && note info "notifier healthy again after crash" "$(secs "$(since "$t0")") (restart policy)" \
    || note FAIL "notifier did not recover" "$(health notifier)"
  out=$(psql -X -q -tA -v ON_ERROR_STOP=1 2>&1 <<SQL
begin;
insert into private.push_devices (user_id, token, platform) values ('$PROBE_ID', 'chaos-fake-token-never-sent', 'android') returning 'device';
insert into private.push_queue (user_id, device_id, kind, ref, title, body, data, status, available_at, expires_at)
  select '$PROBE_ID', d.id, 'system', 'chaos', 'uji', 'uji', '{}', 'queued', now(), now() + interval '1 hour'
  from private.push_devices d where d.user_id = '$PROBE_ID' returning 'queued';
select jsonb_agg(jsonb_build_object('id', id, 'outcome', 'sent'))::text as report from private.push_queue where ref = 'chaos' \gset
select set_config('role', 'service_role', true), set_config('request.jwt.claims', '{"role":"service_role"}', true);
select 'claim A: ' || jsonb_array_length(public.push_claim('chaos-a', 10, 60));
select 'claim B while A holds the lease: ' || jsonb_array_length(public.push_claim('chaos-b', 10, 60));
reset role;
update private.push_queue set locked_until = now() - interval '1 second' where ref = 'chaos';
select set_config('role', 'service_role', true);
select 'claim B after lease A expired (A presumed crashed): ' || jsonb_array_length(public.push_claim('chaos-b', 10, 60));
select 'stale report from A accepted: ' || public.push_report('chaos-a', :'report'::jsonb);
select 'report from B accepted: ' || public.push_report('chaos-b', :'report'::jsonb);
rollback;
SQL
)
  note info "push_queue lease test (rollback)" "$(grep -E 'claim|report' <<< "$out" | tr '\n' ';')"
  grep -q 'while A holds the lease: 0' <<< "$out" && grep -q 'lease A expired (A presumed crashed): 1' <<< "$out" && grep -q 'stale report from A accepted: 0' <<< "$out" \
    && note ok "no double claim during the lease; taken over after the lease expired; stale instance report rejected" "-" \
    || note FAIL "push_queue lease" "$(tr '\n' ' ' <<< "$out" | head -c 300)"
  note info "note" "at-least-once delivery: if the notifier crashes after FCM accepted but before push_report, the item is resent after the lease (60 s); collapse_key limits the impact on the phone"
}

exp_rest() {
  begin_exp rest "crash PostgREST"
  load_start $((OUTAGE + 90))
  t0=$(now_ms)
  crash rest
  wait_state rest healthy 120 && note info "rest healthy again" "$(secs "$(since "$t0")")"
  FAULT_T0=$t0
  sleep 45
  load_stop
}

exp_db() {
  begin_exp db "restart Postgres (graceful): recovery time; migrate does not run again"
  migrate_before=$(docker inspect -f '{{.State.FinishedAt}} exit={{.State.ExitCode}}' "$(container migrate)" 2>/dev/null)
  mig_count_before=$(sql "select count(*) from olt_internal.schema_migrations" 2>/dev/null || echo '?')
  load_start $((OUTAGE + 120))
  t0=$(now_ms)
  docker restart "$(container db)" > /dev/null
  note info "docker restart db finished" "$(secs "$(since "$t0")")"
  wait_state db healthy 180 && note info "db healthy" "$(secs "$(since "$t0")")"
  FAULT_T0=$t0
  sleep 60
  load_stop
  migrate_after=$(docker inspect -f '{{.State.FinishedAt}} exit={{.State.ExitCode}}' "$(container migrate)" 2>/dev/null)
  mig_count_after=$(sql "select count(*) from olt_internal.schema_migrations" 2>/dev/null || echo '?')
  [ "$migrate_before" = "$migrate_after" ] && [ "$mig_count_before" = "$mig_count_after" ] \
    && note ok "migrate did not run again" "container: $migrate_after; migration rows $mig_count_after" \
    || note FAIL "migrate changed" "$migrate_before -> $migrate_after; $mig_count_before -> $mig_count_after"
  for s in rest auth storage realtime auth-bridge pgbouncer; do note info "status $s after db restart" "$(health "$s")"; done
}

exp_partition() {
  begin_exp partition "disconnect PostgREST from the data network for ${OUTAGE}s (docker network disconnect), then reconnect"
  load_start $((OUTAGE + 90))
  t0=$(now_ms)
  docker network disconnect "${STACK}_data" "$(container rest)"
  sleep "$OUTAGE"
  note info "rest status while disconnected" "$(health rest)"
  t1=$(now_ms)
  docker network connect "${STACK}_data" "$(container rest)"
  FAULT_T0=$t0
  wait_state rest healthy 120
  sleep 40
  load_stop
}

restore_all() {
  [ -n "$probepid" ] && kill "$probepid" 2>/dev/null
  [ -n "$k6pid" ] && kill "$k6pid" 2>/dev/null
  for s in classifier valkey storage notifier realtime rest pgbouncer db; do
    st=$(docker inspect -f '{{.State.Running}}' "$(container "$s")" 2>/dev/null)
    [ "$st" = false ] && docker start "$(container "$s")" > /dev/null && log "restored: $s"
  done
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$(container rest)" | grep -q "${STACK}_data" \
    || docker network connect "${STACK}_data" "$(container rest)"
  rm -f "$users_file" "$RUN/probe-users.json" "$JPEG"
}
trap restore_all EXIT

probe_user
[ -n "$PROBE_JWT" ] || { echo "failed to log in probe user lt_c00001" >&2; exit 2; }
notifier_running=$(docker inspect -f '{{.State.Running}}' "$(container notifier)")
for e in $experiments; do
  if [ "$e" != notifier ] && [ "$(docker inspect -f '{{.State.Running}}' "$(container notifier)")" = true ]; then
    docker stop "$(container notifier)" > /dev/null
  fi
  [ "$e" = notifier ] && docker start "$(container notifier)" > /dev/null && wait_state notifier healthy 60
  "exp_$e"
  probe_user
done
[ "$notifier_running" = true ] && docker start "$(container notifier)" > /dev/null
echo
column -t -s $'\t' "$REPORT"
echo "results: ${RUN#/olt/}"
