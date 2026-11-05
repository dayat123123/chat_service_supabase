#!/usr/bin/env bash
# All sends use the inbox channel only, so no real push is ever delivered.
# The "lt_loadtest" key is created as the smoke-cs test super admin and revoked on exit; both show in the audit trail.
set -uo pipefail
source /olt/tests/lib/common.sh

RUN="${OUT_DIR:-$RESULTS/integration-$(stamp)}"
mkdir -p "$RUN"
API=$(kong_edge_url)
STOCK="${ROOM_CODE:-LTHOT}"
SUPER=5e000000-0000-4000-8000-0000000000c2
sql "select 1 from cs.agents where user_id = '$SUPER' and 'cs_super_admin' = any (roles) and disabled_at is null" | grep -q 1 \
  || { echo "smoke-cs test super admin ($SUPER) not found; run make smoke-cs once." >&2; exit 2; }
SUP_JWT=$(staff_jwt "$SUPER" 1800)
rpc_cs() { curl -sS -X POST "$API/rest/v1/rpc/$1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $SUP_JWT" \
  -H 'Content-Type: application/json' -H 'Content-Profile: cs_api' -d "$2"; }

created=$(rpc_cs integration_key_create "{\"p_name\":\"lt_loadtest\",\"p_scopes\":[\"notify\",\"notify_broadcast\"]${INTEGRATION_RATE:+,\"p_rate_limit_per_minute\":$INTEGRATION_RATE}}")
KEY=$(jq -r '.key // empty' <<< "$created")
KEY_ID=$(jq -r '.id // .key_id // empty' <<< "$created")
[ -n "$KEY" ] || { echo "failed to create test key: $(jq -c 'del(.key)' <<< "$created" 2>/dev/null)" >&2; exit 2; }
revoke() { [ -n "$KEY_ID" ] && rpc_cs integration_key_revoke "{\"p_id\":\"$KEY_ID\",\"p_reason\":\"uji beban selesai\"}" > /dev/null && log "test key revoked"; }
trap revoke EXIT
log "test key created ($KEY_ID), limit $(sql "select rate_limit_per_minute from private.integration_keys where id = '$KEY_ID'")/min ($( [ -n "${INTEGRATION_RATE:-}" ] && echo "INTEGRATION_RATE" || echo "default"))" | tee -a "$RUN/summary.txt"

run_k6() {
  k6 run --quiet --log-format raw -e API="$API" -e ANON_KEY="$ANON_KEY" -e KEY="$KEY" -e RUN="$(date +%s)" \
    -e RATE="$1" -e BATCH="$2" -e DURATION="$3" -e SUMMARY="$RUN/notify-r$1-b$2.json" /olt/tests/load/integration-notify.js > "$RUN/notify-r$1-b$2.log" 2>&1
  jq -r --arg r "$1" --arg b "$2" '
    def v(m; s): (.metrics[m].values[s] // 0) * 10 | round / 10;
    "rate=\($r)/s batch=\($b): req=\(.metrics.http_reqs.values.count) p50=\(v("http_req_duration{name:notify}"; "med"))ms p95=\(v("http_req_duration{name:notify}"; "p(95)"))ms p99=\(v("http_req_duration{name:notify}"; "p(99)"))ms " +
    ([.metrics | to_entries[] | select(.key | startswith("notify_results{")) | select(.value.values.count > 0) | "\(.key | sub("notify_results\\{status:"; "") | sub("}"; ""))=\(.value.values.count)"] | join(" "))
  ' "$RUN/notify-r$1-b$2.json" | tee -a "$RUN/summary.txt"
}
log "throughput per cust_id (unlinked accounts, inbox channel)"
run_k6 5 1 60s
run_k6 20 1 60s
run_k6 60 1 60s
run_k6 5 100 60s

watchers=$(sql "select count(*) from public.stock_watchers where stock_code = '$STOCK'")
log "stock_watchers broadcast $STOCK ($watchers watchers), inbox channel, category important (no daily cap)"
mid="lt-bc-$(date +%s)"
sent_at=$(now_ms)
resp=$(curl -sS -X POST "$API/integration/v1/notify/messages" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d "{\"messages\":[{\"id\":\"$mid\",\"target\":{\"audience\":\"stock_watchers\",\"stock\":\"$STOCK\"},\"kind\":\"olt.info.loadtest\",\"category\":\"important\",\"channels\":[\"inbox\"],\"title\":\"Uji beban siaran\",\"body\":\"Abaikan\"}]}")
bid=$(jq -r '.results[0].broadcast_id // empty' <<< "$resp")
echo "response: $(jq -c '{queued,accepted,invalid,results: [.results[] | {status, error}]}' <<< "$resp")" | tee -a "$RUN/summary.txt"
if [ -n "$bid" ]; then
  for _ in $(seq 1 120); do
    st=$(sql "select status from private.integration_broadcasts where id = '$bid'")
    [ "$st" = done ] || [ "$st" = failed ] && break
    sleep 1
  done
  done_ms=$(now_ms)
  sql "select 'broadcast ' || status || ': targeted=' || targeted || ' recipients=' || recipients || ' inbox=' || inbox || ' devices=' || devices ||
       ' capped=' || capped || ' queued->started=' || round(extract(epoch from started_at - created_at)::numeric, 1) || 's started->finished=' ||
       round(extract(epoch from finished_at - started_at)::numeric, 2) || 's'
       from private.integration_broadcasts where id = '$bid'" | tee -a "$RUN/summary.txt"
  echo "total API->finished: $(( (done_ms - sent_at) / 1000 ))s (cron integration-broadcasts every 15 s)" | tee -a "$RUN/summary.txt"
fi
echo "results: ${RUN#/olt/}"
