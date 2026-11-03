#!/usr/bin/env bash
# Uji chaos stack DEV di bawah beban ringan (k6 market-open, 30 VU): matikan/crash/putus jaringan satu
# layanan, ukur dampak dan waktu pulih, periksa perilaku yang diharapkan (fail closed, fallback, tidak ada
# pesan hilang), dan alert Kesehatan sistem (sentinel). Setiap eksperimen memulihkan layanannya sendiri.
# pemakaian: chaos.sh [eksperimen...]  (default semua: classifier realtime pgbouncer valkey storage notifier rest db partition)
# env: CHAOS_VUS (30), CHAOS_OUTAGE (detik layanan mati, default 30), CHAOS_LONG_OUTAGE (classifier, default 150: > ambang alert 120 dtk)
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
[ "$app_env" = development ] || { echo "Chaos hanya untuk stack DEV (APP_ENV=$app_env)" >&2; exit 2; }

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
      "k6: req=\(c("http_reqs")) err=\(((.metrics.http_req_failed.values.rate // 0) * 1000 | round) / 10)% sent=\(c("msg_sent")) send_fail=\(c("msg_send_failed")) recv=\(c("rt_messages_received"))/\(c("rt_expected"))rt_p95=\(p("rt_delivery_ms"; "p(95)"))ms ws_drop=\(c("ws_dropped")) ws_fail=\(c("ws_failed")) join_fail=\(c("rt_join_failed")) login_fail=\(c("login_failed")) sessions=\(c("sessions"))"
    ' "$EXP_DIR/k6-summary.json" > "$EXP_DIR/k6-line.txt"
    note info "beban ringan" "$(cat "$EXP_DIR/k6-line.txt")"
  fi
  rest_errors=$(awk -F, '$2 != 200' "$EXP_DIR/rest-probe.csv" | wc -l)
  note info "probe REST tiap 1 dtk gagal" "$rest_errors dari $(wc -l < "$EXP_DIR/rest-probe.csv")"
  lt_msgs=$(sql "select count(*) from public.messages m join public.profiles p on p.id = m.sender_id
                 where p.username like 'lt\_0%' and m.created_at >= to_timestamp($LOAD_T0 / 1000.0)")
  sent=$(jq -r '.metrics.msg_sent.values.count // 0' "$EXP_DIR/k6-summary.json" 2>/dev/null)
  if [ "${sent:-0}" -gt 0 ]; then
    [ "$lt_msgs" -ge "$sent" ] && note ok "pesan terkirim (200) tersimpan di DB" "$lt_msgs di DB >= $sent sukses" \
      || note FAIL "pesan hilang" "$lt_msgs di DB < $sent sukses"
  fi
}
recovery_from_probe() {
  awk -F, -v t="$1" '$1 >= t && $2 == 200 {print $1 - t; exit}' "$EXP_DIR/rest-probe.csv"
}
alert_snapshot() {
  sql "select key || ' ' || severity || ' opened=' || to_char(opened_at, 'HH24:MI:SS') || coalesce(' resolved=' || to_char(resolved_at, 'HH24:MI:SS'), ' AKTIF')
       from private.health_alerts where opened_at >= to_timestamp($1 / 1000.0) - interval '5 seconds' order by opened_at"
}
probe_state() { sql "select coalesce(ok::text, '?') || ' ' || coalesce(status::text, '') || ' ' || coalesce(left(error, 60), '') from private.health_probes where name = '$1'"; }

begin_exp() {
  EXP_NAME="$1"
  EXP_DIR="$RUN/$1"
  mkdir -p "$EXP_DIR"
  echo
  log "=== eksperimen $1: $2"
}

exp_classifier() {
  begin_exp classifier "classifier mati ${LONG}s: upload gambar harus ditolak (fail closed), alert sentinel muncul lalu pulih"
  load_start $((LONG + 90))
  [ "$(upload_code)" = 200 ] && note ok "upload sebelum gangguan" 200 || note FAIL "upload sebelum gangguan gagal" "$(cat "$RUN/upload.out")"
  t0=$(now_ms)
  docker stop "$(container classifier)" > /dev/null
  sleep 5
  codes=""
  for _ in 1 2 3; do codes="$codes $(upload_code)"; sleep 2; done
  [[ "$codes" != *200* ]] && note ok "upload saat classifier mati ditolak (fail closed)" "$codes $(jq -c '{code, message}' "$RUN/upload.out" 2>/dev/null)" \
    || note FAIL "upload diterima saat classifier mati" "$codes"
  note info "health_probes classifier saat mati" "$(probe_state classifier)"
  note info "link-preview saat classifier mati" "tidak diuji live (hindari fetch situs eksternal); perilaku fail closed (pratinjau tanpa gambar) dicakup unit test services/link-preview (fakeClassifier)"
  sleep $(( LONG - 11 ))
  note info "alert setelah ${LONG}s mati" "$(alert_snapshot "$t0" | tr '\n' ';')"
  t1=$(now_ms)
  docker start "$(container classifier)" > /dev/null
  wait_state classifier healthy 120
  note info "classifier healthy lagi" "$(secs "$(since "$t1")")"
  t2=$(now_ms)
  for _ in $(seq 1 60); do [ "$(upload_code)" = 200 ] && break; sleep 1; done
  note info "upload pulih setelah start" "$(secs "$(since "$t1")") (media memeriksa classifier via readyz)"
  sleep 75
  note info "alert setelah pulih (+75s, ambang resolve 60s)" "$(alert_snapshot "$t0" | tr '\n' ';')"
  load_stop
}

exp_realtime() {
  begin_exp realtime "crash Realtime (kill -9): klien tersambung ulang, pesan tetap tersimpan, sinkron ulang lewat get_messages"
  load_start $((OUTAGE + 120))
  t0=$(now_ms)
  crash realtime
  wait_state realtime healthy 180 && note info "realtime healthy lagi setelah crash" "$(secs "$(since "$t0")") (restart policy)" \
    || note FAIL "realtime tidak pulih" "$(health realtime)"
  sleep 60
  load_stop
  k6_rejoin=$(grep -c . "$EXP_DIR/k6.log" 2>/dev/null)
  note info "status kanal setelah pulih" "lihat ws_drop/sessions pada baris k6 (sesi yang putus login ulang & join ulang)"
}

exp_pgbouncer() {
  begin_exp pgbouncer "crash PgBouncer: PostgREST/GoTrue/Storage kehilangan koneksi lalu pulih"
  load_start $((OUTAGE + 90))
  t0=$(now_ms)
  crash pgbouncer
  wait_state pgbouncer healthy 120 && note info "pgbouncer healthy lagi" "$(secs "$(since "$t0")")"
  r=$(recovery_from_probe $(( t0 + 1000 )))
  note info "REST pulih (probe 200 pertama setelah crash)" "$(secs "${r:-999999}")"
  sleep 45
  load_stop
}

exp_valkey() {
  begin_exp valkey "Valkey mati ${OUTAGE}s: perilaku rate limit & exchange auth-bridge"
  load_start $((OUTAGE + 90))
  docker stop "$(container valkey)" > /dev/null
  t0=$(now_ms)
  sleep 3
  note info "auth-bridge /readyz saat Valkey mati" "$(curl -s -m 3 http://auth-bridge:9100/readyz | tr -d '\n')"
  c=$(exchange_code 1 198.51.100.63)
  [ "$c" = 200 ] && note ok "exchange tetap berhasil saat Valkey mati (fail open ke limiter lokal per instance)" "$c" \
    || note info "exchange saat Valkey mati" "$c"
  codes=$(for i in $(seq 1 35); do exchange_code 2 198.51.100.64; echo; done | sort | uniq -c | tr '\n' ' ')
  [[ "$codes" == *429* ]] && note ok "batas per IP tetap berlaku lewat limiter lokal (35 exchange dari 1 IP)" "$codes" \
    || note FAIL "batas per IP hilang saat Valkey mati" "$codes"
  sleep $(( OUTAGE > 10 ? OUTAGE - 8 : 1 ))
  docker start "$(container valkey)" > /dev/null
  wait_state valkey healthy 60
  sleep 3
  note info "auth-bridge /readyz setelah Valkey pulih" "$(curl -s -m 3 http://auth-bridge:9100/readyz | tr -d '\n') ($(secs "$(since "$t0")") sejak mati)"
  note info "catatan" "Valkey tanpa persistence: restart menghapus jendela rate limit (counter mulai nol)"
  sleep 30
  load_stop
}

exp_storage() {
  begin_exp storage "Storage mati ${OUTAGE}s: upload & unduh gagal, REST tetap jalan"
  load_start $((OUTAGE + 90))
  docker stop "$(container storage)" > /dev/null
  t0=$(now_ms)
  sleep 3
  c=$(upload_code); [ "$c" != 200 ] && note ok "upload saat storage mati gagal dengan jelas" "$c $(head -c 120 "$RUN/upload.out")" || note FAIL "upload sukses saat storage mati?" "$c"
  rest_ok && note ok "REST tetap melayani saat storage mati" 200 || note FAIL "REST ikut gagal saat storage mati" "-"
  sleep "$OUTAGE"
  t1=$(now_ms)
  docker start "$(container storage)" > /dev/null
  wait_state storage healthy 120 && note info "storage healthy lagi" "$(secs "$(since "$t1")")"
  for _ in $(seq 1 60); do [ "$(upload_code)" = 200 ] && break; sleep 1; done
  note info "upload pulih setelah start" "$(secs "$(since "$t1")")"
  note info "health_probes storage" "$(probe_state storage)"
  sleep 30
  load_stop
}

exp_notifier() {
  begin_exp notifier "crash notifier: pulih otomatis; lease antrean mencegah kirim ganda (uji SQL di transaksi yang di-rollback)"
  t0=$(now_ms)
  crash notifier
  wait_state notifier healthy 120 && note info "notifier healthy lagi setelah crash" "$(secs "$(since "$t0")") (restart policy)" \
    || note FAIL "notifier tidak pulih" "$(health notifier)"
  out=$(psql -X -q -tA -v ON_ERROR_STOP=1 2>&1 <<SQL
begin;
insert into private.push_devices (user_id, token, platform) values ('$PROBE_ID', 'chaos-fake-token-tidak-pernah-dikirim', 'android') returning 'device';
insert into private.push_queue (user_id, device_id, kind, ref, title, body, data, status, available_at, expires_at)
  select '$PROBE_ID', d.id, 'system', 'chaos', 'uji', 'uji', '{}', 'queued', now(), now() + interval '1 hour'
  from private.push_devices d where d.user_id = '$PROBE_ID' returning 'queued';
select set_config('role', 'service_role', true), set_config('request.jwt.claims', '{"role":"service_role"}', true);
select 'klaim A: ' || jsonb_array_length(public.push_claim('chaos-a', 10, 1));
select 'klaim B saat A masih memegang lease: ' || jsonb_array_length(public.push_claim('chaos-b', 10, 60));
select pg_sleep(1.5);
select 'klaim B setelah lease A habis (A dianggap crash): ' || jsonb_array_length(public.push_claim('chaos-b', 10, 60));
select 'laporan A yang basi diterima: ' || public.push_report('chaos-a', (select jsonb_agg(jsonb_build_object('id', id, 'outcome', 'sent')) from private.push_queue where ref = 'chaos'));
rollback;
SQL
)
  note info "uji lease push_queue (rollback)" "$(grep -E 'klaim|laporan' <<< "$out" | tr '\n' ';')"
  grep -q 'saat A masih memegang lease: 0' <<< "$out" && grep -q 'basi diterima: 0' <<< "$out" \
    && note ok "tidak ada klaim ganda selama lease; laporan instance lama ditolak" "-" \
    || note FAIL "lease push_queue" "$(tr '\n' ' ' <<< "$out" | head -c 300)"
  note info "catatan" "pengiriman at-least-once: bila notifier crash setelah FCM menerima tetapi sebelum push_report, item dikirim ulang setelah lease (60 dtk); collapse_key mengurangi dampak di HP"
}

exp_rest() {
  begin_exp rest "crash PostgREST"
  load_start $((OUTAGE + 90))
  t0=$(now_ms)
  crash rest
  wait_state rest healthy 120 && note info "rest healthy lagi" "$(secs "$(since "$t0")")"
  r=$(recovery_from_probe $(( t0 + 1000 )))
  note info "REST pulih (probe 200 pertama)" "$(secs "${r:-999999}")"
  sleep 45
  load_stop
}

exp_db() {
  begin_exp db "restart Postgres (graceful): waktu pulih; migrate tidak dijalankan ulang"
  migrate_before=$(docker inspect -f '{{.State.FinishedAt}} exit={{.State.ExitCode}}' "$(container migrate)" 2>/dev/null)
  mig_count_before=$(sql "select count(*) from olt_internal.schema_migrations" 2>/dev/null || echo '?')
  load_start $((OUTAGE + 120))
  t0=$(now_ms)
  docker restart "$(container db)" > /dev/null
  note info "docker restart db selesai" "$(secs "$(since "$t0")")"
  wait_state db healthy 180 && note info "db healthy" "$(secs "$(since "$t0")")"
  r=$(recovery_from_probe $(( t0 + 1000 )))
  note info "REST pulih (probe 200 pertama sejak restart)" "$(secs "${r:-999999}")"
  sleep 60
  load_stop
  migrate_after=$(docker inspect -f '{{.State.FinishedAt}} exit={{.State.ExitCode}}' "$(container migrate)" 2>/dev/null)
  mig_count_after=$(sql "select count(*) from olt_internal.schema_migrations" 2>/dev/null || echo '?')
  [ "$migrate_before" = "$migrate_after" ] && [ "$mig_count_before" = "$mig_count_after" ] \
    && note ok "migrate tidak berjalan ulang" "container: $migrate_after; baris migrasi $mig_count_after" \
    || note FAIL "migrate berubah" "$migrate_before -> $migrate_after; $mig_count_before -> $mig_count_after"
  for s in rest auth storage realtime auth-bridge pgbouncer; do note info "status $s setelah restart db" "$(health "$s")"; done
}

exp_partition() {
  begin_exp partition "putus network data dari PostgREST ${OUTAGE}s (docker network disconnect) lalu sambung lagi"
  load_start $((OUTAGE + 90))
  t0=$(now_ms)
  docker network disconnect "${STACK}_data" "$(container rest)"
  sleep "$OUTAGE"
  note info "status rest saat terputus" "$(health rest)"
  t1=$(now_ms)
  docker network connect "${STACK}_data" "$(container rest)"
  r=$(recovery_from_probe "$t1")
  note info "REST pulih setelah network tersambung" "$(secs "${r:-999999}")"
  wait_state rest healthy 120
  sleep 40
  load_stop
}

restore_all() {
  [ -n "$probepid" ] && kill "$probepid" 2>/dev/null
  [ -n "$k6pid" ] && kill "$k6pid" 2>/dev/null
  for s in classifier valkey storage notifier realtime rest pgbouncer db; do
    st=$(docker inspect -f '{{.State.Running}}' "$(container "$s")" 2>/dev/null)
    [ "$st" = false ] && docker start "$(container "$s")" > /dev/null && log "dipulihkan: $s"
  done
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$(container rest)" | grep -q "${STACK}_data" \
    || docker network connect "${STACK}_data" "$(container rest)"
  rm -f "$users_file" "$RUN/probe-users.json" "$JPEG"
}
trap restore_all EXIT

probe_user
[ -n "$PROBE_JWT" ] || { echo "gagal login user probe lt_c00001" >&2; exit 2; }
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
echo "hasil: ${RUN#/olt/}"
