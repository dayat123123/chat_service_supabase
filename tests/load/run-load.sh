#!/usr/bin/env bash
# usage: run-load.sh [smoke|step|spike|light]
# env: LOAD_STEPS ("50 100 200 300 400"), LOAD_HOLD, LOAD_RAMP, LOAD_MSG_EVERY (seconds), LOAD_FORCE=1 (ignore stop limits),
# LOAD_VIA=kong|traefik, TYPING=1 (send_typing like the app), LIST_VUS=n (first n VUs only poll get_room_previews every
# LIST_POLL seconds), PRESENCE=0 (no presence track).
# Each lt_ user gets a synthetic 198.18.0.0/15 IP via X-Forwarded-For, which Kong trusts only from the edge network,
# so per-IP limits apply per user. The notifier is stopped during the run so no real push is sent.
# Posts tag $LTPOST instead of the test room so manipulation detection does not throttle $LTHOT.
set -uo pipefail
source /olt/tests/lib/common.sh

profile="${1:-smoke}"
RUN="$RESULTS/load-$(stamp)-$profile"
mkdir -p "$RUN"
case "$profile" in
  smoke) steps="${LOAD_STEPS:-10}"; hold="${LOAD_HOLD:-45}"; ramp="${LOAD_RAMP:-10}" ;;
  step)  steps="${LOAD_STEPS:-50 100 200 300 400}"; hold="${LOAD_HOLD:-150}"; ramp="${LOAD_RAMP:-30}" ;;
  spike) steps="${LOAD_STEPS:-300}"; hold="${LOAD_HOLD:-120}"; ramp="${LOAD_RAMP:-10}" ;;
  light) steps="${LOAD_STEPS:-30}"; hold="${LOAD_HOLD:-600}"; ramp="${LOAD_RAMP:-15}" ;;
  *) echo "unknown profile: $profile" >&2; exit 2 ;;
esac
msg_every="${LOAD_MSG_EVERY:-20}"
API=$( [ "${LOAD_VIA:-kong}" = traefik ] && traefik_url || kong_edge_url )

app_env=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$(container auth-bridge)" | sed -n 's/^APP_ENV=//p')
olt_mode=$(curl -sS "$API/bridge/v1/health" -H "apikey: $ANON_KEY" | jq -r '.olt_mode // empty')
if [ "$app_env" != development ] || [ "$olt_mode" != jwt ] || ! docker inspect "$(container dummy-olt)" > /dev/null 2>&1; then
  echo "Load tests only run against the DEV stack with the dummy OLT (APP_ENV=$app_env, olt_mode=$olt_mode). Run: make up DUMMY_OLT=1" >&2
  exit 2
fi
devices=$(sql "select count(*) from private.push_devices d join public.profiles p on p.id = d.user_id where p.username like 'lt\_%'")
if [ "${devices:-0}" != 0 ]; then
  echo "lt_* users own $devices push devices; remove them first (make loadtest-cleanup) so no real push is sent." >&2
  exit 2
fi

notifier_was_running=$(docker inspect -f '{{.State.Running}}' "$(container notifier)" 2>/dev/null)
sampler=""
cleanup() {
  [ -n "$sampler" ] && kill "$sampler" 2>/dev/null
  if [ "$notifier_was_running" = true ]; then
    docker start "$(container notifier)" > /dev/null && log "notifier started again"
  fi
}
trap cleanup EXIT
if [ "$notifier_was_running" = true ]; then
  docker stop "$(container notifier)" > /dev/null && log "notifier stopped during the test (no real push)"
fi
queued_before=$(sql "select count(*) from private.push_queue")
PREVIEW_SQL="select 'lag_s=' || coalesce(round(extract(epoch from (select max(m.created_at) from public.messages m where m.room_id = r.id) - r.last_message_at)::numeric, 3)::text, '-')
  || ' queue=' || (select count(*) from private.room_preview_queue) from public.chat_rooms r where r.type = 'stock' and r.stock_code = 'LTHOT'"

max=0
for n in $steps; do [ "$n" -gt "$max" ] && max=$n; done
log "profile $profile, VU steps: $steps, ramp ${ramp}s, hold ${hold}s, message every ~${msg_every}s, API $API"
{
  echo "profile=$profile"; echo "steps=$steps"; echo "ramp=$ramp"; echo "hold=$hold"; echo "msg_every=$msg_every"; echo "api=$API"
  echo "started=$(date -u +%FT%TZ)"; echo "host_cpus=$(nproc)"
  docker info --format 'docker_cpus={{.NCPU}} docker_mem={{.MemTotal}}' 2>/dev/null
} > "$RUN/run-info.txt"

summary() {
  jq -r --arg step "$1" '
    def p(m; s): (.metrics[m].values[s] // null) | if . == null then "-" else (. * 10 | round / 10 | tostring) end;
    def c(m): (.metrics[m].values.count // 0);
    def r(m): (.metrics[m].values.rate // 0);
    [ $step,
      p("http_req_duration"; "med"), p("http_req_duration"; "p(95)"), p("http_req_duration"; "p(99)"),
      ((r("http_req_failed") * 10000 | round) / 100 | tostring) + "%",
      p("http_req_duration{name:send_message}"; "p(95)"), p("http_req_duration{name:bridge_exchange}"; "p(95)"),
      p("http_req_duration{name:get_feed}"; "p(95)"), p("http_req_duration{name:join_stock_room}"; "p(95)"),
      p("rt_delivery_ms"; "med"), p("rt_delivery_ms"; "p(95)"), p("rt_delivery_ms"; "p(99)"),
      c("msg_sent"), c("msg_send_failed"), c("rt_messages_received"), c("rt_expected"),
      (if c("rt_expected") > 0 then ((c("rt_messages_received") / c("rt_expected") * 1000 | round) / 10 | tostring) + "%" else "-" end),
      c("rt_subscribed"),
      c("rate_limited"), c("login_failed"), c("ws_failed"), c("rt_join_failed"), c("ws_dropped"),
      ((.metrics.http_reqs.values.rate // 0) * 10 | round / 10 | tostring),
      c("rt_recv_window"), c("rt_gap_only"),
      (if c("rt_expected") > 0 then ((c("rt_recv_window") / c("rt_expected") * 1000 | round) / 10 | tostring) + "%" else "-" end),
      (if c("rt_expected") > 0 then (((c("rt_recv_window") + c("rt_gap_only")) / c("rt_expected") * 1000 | round) / 10 | tostring) + "%" else "-" end),
      p("http_req_duration{name:get_message_ids}"; "p(95)"), p("http_req_duration{name:get_messages_by_ids}"; "p(95)"),
      c("gap_runs"), c("gap_too_long"), c("gap_failed"), c("pgrst003")
    ] | @tsv' "$2"
}
printf 'vus\thttp_p50\thttp_p95\thttp_p99\thttp_err\tsend_p95\texchange_p95\tfeed_p95\tjoin_p95\trt_p50\trt_p95\trt_p99\tsent\tsend_fail\trt_recv\trt_expected\trt_delivered\tsubscribed\trate_limited\tlogin_fail\tws_fail\tjoin_fail\tws_drop\treq_per_s\trt_recv_win\tgap_only\trt_win_pct\teventual_pct\tids_p95\tbyids_p95\tgap_runs\tgap_too_long\tgap_failed\tpgrst003\n' > "$RUN/steps.tsv"
printf 'vus\tsecs\ttyping_rpc\ttyping_ev\ttyping_ev_s\tsummary_ev\tmsg_ev_s\tpresence_ev\tpresence_kb\tpresence_denied\tlist_polls\tlist_fail\tpreviews_p95\ttyping_p95\trt_limit_logs\n' > "$RUN/realtime.tsv"
realtime_summary() {
  jq -r --arg step "$1" --arg logs "$3" '
    def c(m): (.metrics[m].values.count // 0);
    def p(m; s): (.metrics[m].values[s] // null) | if . == null then "-" else (. * 10 | round / 10 | tostring) end;
    ((.state.testRunDurationMs // 1000) / 1000) as $s |
    [ $step, ($s | round | tostring), c("typing_rpc_sent"), c("rt_typing_events"),
      ((c("rt_typing_events") / $s * 10 | round) / 10 | tostring), c("rt_typing_summary_events"),
      ((c("rt_messages_received") / $s * 10 | round) / 10 | tostring),
      c("rt_presence_events"), ((c("rt_presence_bytes") / 1024) | round | tostring), c("presence_track_denied"),
      c("list_polls"), c("list_poll_failed"),
      p("http_req_duration{name:get_room_previews}"; "p(95)"), p("http_req_duration{name:send_typing}"; "p(95)"), $logs
    ] | @tsv' "$2"
}

prev_p95=0
for n in $steps; do
  step="$RUN/step-$n"
  mkdir -p "$step"
  tokengen -prefix lt_ -start 1 -count "$max" -ttl 14m > "$RUN/users.json" || exit 2
  step_started=$(date -u +%FT%TZ)
  bash /olt/tests/load/sample.sh "$step" 5 &
  sampler=$!
  log "step $n VU started"
  k6 run --quiet --log-format raw -e API="$API" -e ANON_KEY="$ANON_KEY" -e USERS="$RUN/users.json" -e VUS="$n" \
    -e RAMP="$ramp" -e HOLD="$hold" -e MSG_EVERY="$msg_every" -e SUMMARY="$step/summary.json" \
    -e TYPING="${TYPING:-0}" -e LIST_VUS="${LIST_VUS:-0}" -e LIST_POLL="${LIST_POLL:-15}" -e PRESENCE="${PRESENCE:-1}" \
    /olt/tests/load/market-open.js > "$step/k6.log" 2>&1
  kill "$sampler" 2>/dev/null; wait "$sampler" 2>/dev/null; sampler=""
  rm -f "$RUN/users.json"
  if [ ! -s "$step/summary.json" ]; then
    log "k6 failed at step $n, see $step/k6.log"; tail -5 "$step/k6.log"; break
  fi
  summary "$n" "$step/summary.json" >> "$RUN/steps.tsv"
  limit_logs=$(docker logs --since "$step_started" "$(container realtime)" 2>&1 | grep -c -E "MessagePerSecondRateLimitReached|too_many_requests|RateLimit")
  realtime_summary "$n" "$step/summary.json" "${limit_logs:-0}" >> "$RUN/realtime.tsv"
  column -t -s $'\t' "$RUN/realtime.tsv" | tail -1 | sed 's/^/    realtime: /'
  awk -F, 'NR>1 {c[$2]=($3>c[$2]?$3:c[$2]); m[$2]=($4>m[$2]?$4:m[$2])} END {for (k in c) printf "%s\t%.1f\t%.0f\n", k, c[k], m[k]}' "$step/docker.csv" \
    | sort -k2 -n -r > "$step/peak-container.tsv"
  awk -F, 'NR>1 {for (i=2;i<=NF;i++) if ($i>p[i]) p[i]=$i} END {printf "peak conn_total=%d active=%d idle_in_tx=%d lock_waits=%d authenticator=%d\n", p[2], p[3], p[4], p[5], p[6]}' "$step/db.csv" > "$step/peak-db.txt"
  awk -F, 'NR>1 && $2=="authenticator" {if ($4>w) w=$4; if ($8>mw) mw=$8; if ($5>a) a=$5} END {printf "pgbouncer authenticator peak cl_waiting=%s sv_active=%s maxwait_s=%s\n", w+0, a+0, mw+0}' "$step/pgbouncer.csv" >> "$step/peak-db.txt"
  awk -F, 'NR>1 && $4!="" {if ($2>q) q=$2; if ($3>o) o=$3; if ($4>l) l=$4; if ($5>s) s=$5} END {printf "room preview peak queue=%d oldest_s=%.1f lag_s=%.1f send_lock_waits=%d\n", q, o, l, s}' "$step/preview.csv" >> "$step/peak-db.txt"
  sleep 3
  echo "room preview after step: $(sql "$PREVIEW_SQL")" >> "$step/peak-db.txt"
  column -t -s $'\t' "$RUN/steps.tsv" | tail -1
  head -6 "$step/peak-container.tsv" | sed 's/^/    peak cpu%: /'
  sed 's/^/    /' "$step/peak-db.txt"
  err=$(jq -r '.metrics.http_req_failed.values.rate // 0' "$step/summary.json")
  p95=$(jq -r '.metrics.rt_delivery_ms.values["p(95)"] // 0' "$step/summary.json")
  ratio=$(jq -r '(.metrics.rt_messages_received.values.count // 0) as $r | (.metrics.rt_expected.values.count // 0) as $e | if $e > 0 then $r / $e else 1 end' "$step/summary.json")
  if [ "${LOAD_FORCE:-0}" != 1 ]; then
    if awk -v e="$err" 'BEGIN {exit !(e > 0.01)}'; then log "stopping: error rate $err > 1%"; break; fi
    if awk -v r="$ratio" 'BEGIN {exit !(r < 0.99)}'; then log "stopping: only $ratio of realtime messages reached recipients (< 99%)"; break; fi
    if [ "$prev_p95" != 0 ] && awk -v a="$p95" -v b="$prev_p95" 'BEGIN {exit !(a > 3 * b && a > 1000)}'; then
      log "stopping: realtime delivery p95 spiked ($prev_p95 -> $p95 ms)"; break
    fi
  fi
  prev_p95=$p95
  sleep 20
done
queued_after=$(sql "select count(*) from private.push_queue")
echo "push_queue before=$queued_before after=$queued_after (notifier stopped during the test)" | tee -a "$RUN/run-info.txt"
echo "finished=$(date -u +%FT%TZ)" >> "$RUN/run-info.txt"
echo
column -t -s $'\t' "$RUN/steps.tsv"
echo
column -t -s $'\t' "$RUN/realtime.tsv"
echo "results: ${RUN#/olt/}"
