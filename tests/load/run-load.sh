#!/usr/bin/env bash
# Uji beban "pembukaan pasar 09:00 WIB + saham ramai" (k6) terhadap stack DEV.
# pemakaian: run-load.sh [smoke|step|spike|light] ; env: LOAD_STEPS ("50 100 200 300 400"), LOAD_HOLD (detik),
# LOAD_RAMP (detik), LOAD_MSG_EVERY (detik), LOAD_FORCE=1 (lanjut walau batas berhenti terlampaui), LOAD_VIA=kong|traefik.
# - User uji: lt_00001.. (token sosial dev ditandatangani kunci OLT dummy, IP sintetis 198.18.0.0/15 per user
#   lewat X-Forwarded-For yang hanya dipercaya Kong dari network edge, sehingga batas per IP berlaku per user).
# - Tanpa push: notifier dihentikan selama uji dan dinyalakan lagi di akhir; user lt_ tidak punya perangkat push.
# - Pesan tanpa URL/mention; postingan menandai $LTPOST (bukan room uji) agar deteksi manipulasi tidak
#   menahan room $LTHOT.
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
  *) echo "profil tidak dikenal: $profile" >&2; exit 2 ;;
esac
msg_every="${LOAD_MSG_EVERY:-20}"
API=$( [ "${LOAD_VIA:-kong}" = traefik ] && traefik_url || kong_edge_url )

app_env=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$(container auth-bridge)" | sed -n 's/^APP_ENV=//p')
olt_mode=$(curl -sS "$API/bridge/v1/health" -H "apikey: $ANON_KEY" | jq -r '.olt_mode // empty')
if [ "$app_env" != development ] || [ "$olt_mode" != jwt ] || ! docker inspect "$(container dummy-olt)" > /dev/null 2>&1; then
  echo "Uji beban hanya untuk stack DEV dengan OLT dummy (APP_ENV=$app_env, olt_mode=$olt_mode). Jalankan: make up DUMMY_OLT=1" >&2
  exit 2
fi
devices=$(sql "select count(*) from private.push_devices d join public.profiles p on p.id = d.user_id where p.username like 'lt\_%'")
if [ "${devices:-0}" != 0 ]; then
  echo "Ada $devices perangkat push milik user lt_*; hapus dulu (make loadtest-cleanup) agar tidak ada push nyata." >&2
  exit 2
fi

notifier_was_running=$(docker inspect -f '{{.State.Running}}' "$(container notifier)" 2>/dev/null)
sampler=""
cleanup() {
  [ -n "$sampler" ] && kill "$sampler" 2>/dev/null
  if [ "$notifier_was_running" = true ]; then
    docker start "$(container notifier)" > /dev/null && log "notifier dinyalakan lagi"
  fi
}
trap cleanup EXIT
if [ "$notifier_was_running" = true ]; then
  docker stop "$(container notifier)" > /dev/null && log "notifier dihentikan selama uji (tidak ada push nyata)"
fi
queued_before=$(sql "select count(*) from private.push_queue")
PREVIEW_SQL="select 'lag_s=' || coalesce(round(extract(epoch from (select max(m.created_at) from public.messages m where m.room_id = r.id) - r.last_message_at)::numeric, 3)::text, '-')
  || ' queue=' || (select count(*) from private.room_preview_queue) from public.chat_rooms r where r.type = 'stock' and r.stock_code = 'LTHOT'"

max=0
for n in $steps; do [ "$n" -gt "$max" ] && max=$n; done
log "profil $profile, langkah VU: $steps, ramp ${ramp}s, tahan ${hold}s, pesan tiap ~${msg_every}s, API $API"
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

prev_p95=0
for n in $steps; do
  step="$RUN/step-$n"
  mkdir -p "$step"
  tokengen -prefix lt_ -start 1 -count "$max" -ttl 14m > "$RUN/users.json" || exit 2
  bash /olt/tests/load/sample.sh "$step" 5 &
  sampler=$!
  log "langkah $n VU dimulai"
  k6 run --quiet --log-format raw -e API="$API" -e ANON_KEY="$ANON_KEY" -e USERS="$RUN/users.json" -e VUS="$n" \
    -e RAMP="$ramp" -e HOLD="$hold" -e MSG_EVERY="$msg_every" -e SUMMARY="$step/summary.json" \
    /olt/tests/load/market-open.js > "$step/k6.log" 2>&1
  kill "$sampler" 2>/dev/null; wait "$sampler" 2>/dev/null; sampler=""
  rm -f "$RUN/users.json"
  if [ ! -s "$step/summary.json" ]; then
    log "k6 gagal pada langkah $n, lihat $step/k6.log"; tail -5 "$step/k6.log"; break
  fi
  summary "$n" "$step/summary.json" >> "$RUN/steps.tsv"
  awk -F, 'NR>1 {c[$2]=($3>c[$2]?$3:c[$2]); m[$2]=($4>m[$2]?$4:m[$2])} END {for (k in c) printf "%s\t%.1f\t%.0f\n", k, c[k], m[k]}' "$step/docker.csv" \
    | sort -k2 -n -r > "$step/peak-container.tsv"
  awk -F, 'NR>1 {for (i=2;i<=NF;i++) if ($i>p[i]) p[i]=$i} END {printf "peak conn_total=%d active=%d idle_in_tx=%d lock_waits=%d authenticator=%d\n", p[2], p[3], p[4], p[5], p[6]}' "$step/db.csv" > "$step/peak-db.txt"
  awk -F, 'NR>1 && $2=="authenticator" {if ($4>w) w=$4; if ($8>mw) mw=$8; if ($5>a) a=$5} END {printf "pgbouncer authenticator peak cl_waiting=%s sv_active=%s maxwait_s=%s\n", w+0, a+0, mw+0}' "$step/pgbouncer.csv" >> "$step/peak-db.txt"
  awk -F, 'NR>1 && $4!="" {if ($2>q) q=$2; if ($3>o) o=$3; if ($4>l) l=$4; if ($5>s) s=$5} END {printf "room preview peak queue=%d oldest_s=%.1f lag_s=%.1f send_lock_waits=%d\n", q, o, l, s}' "$step/preview.csv" >> "$step/peak-db.txt"
  sleep 3
  echo "room preview after step: $(sql "$PREVIEW_SQL")" >> "$step/peak-db.txt"
  column -t -s $'\t' "$RUN/steps.tsv" | tail -1
  head -6 "$step/peak-container.tsv" | sed 's/^/    cpu% puncak: /'
  sed 's/^/    /' "$step/peak-db.txt"
  err=$(jq -r '.metrics.http_req_failed.values.rate // 0' "$step/summary.json")
  p95=$(jq -r '.metrics.rt_delivery_ms.values["p(95)"] // 0' "$step/summary.json")
  ratio=$(jq -r '(.metrics.rt_messages_received.values.count // 0) as $r | (.metrics.rt_expected.values.count // 0) as $e | if $e > 0 then $r / $e else 1 end' "$step/summary.json")
  if [ "${LOAD_FORCE:-0}" != 1 ]; then
    if awk -v e="$err" 'BEGIN {exit !(e > 0.01)}'; then log "berhenti: error rate $err > 1%"; break; fi
    if awk -v r="$ratio" 'BEGIN {exit !(r < 0.99)}'; then log "berhenti: hanya $ratio pesan realtime sampai ke penerima (< 99%)"; break; fi
    if [ "$prev_p95" != 0 ] && awk -v a="$p95" -v b="$prev_p95" 'BEGIN {exit !(a > 3 * b && a > 1000)}'; then
      log "berhenti: p95 pengiriman realtime melonjak ($prev_p95 -> $p95 ms)"; break
    fi
  fi
  prev_p95=$p95
  sleep 20
done
queued_after=$(sql "select count(*) from private.push_queue")
echo "push_queue sebelum=$queued_before sesudah=$queued_after (notifier mati selama uji)" | tee -a "$RUN/run-info.txt"
echo "finished=$(date -u +%FT%TZ)" >> "$RUN/run-info.txt"
echo
column -t -s $'\t' "$RUN/steps.tsv"
echo "hasil: ${RUN#/olt/}"
