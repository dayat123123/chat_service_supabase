#!/usr/bin/env bash
# OWASP ZAP baseline (pasif, spider 1 menit) terhadap web CS (Traefik :8085) dan API dev (Traefik :8000).
# Opsional: image ZAP besar (±1,5 GB). Container ZAP di network edge; laporan disalin keluar lewat docker cp.
set -uo pipefail
source /olt/tests/lib/common.sh

ZAP_IMG="${ZAP_IMG:-ghcr.io/zaproxy/zaproxy:2.17.0@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af}"
OUT="${OUT_DIR:-$RESULTS/security-$(stamp)}"
mkdir -p "$OUT"
T=$(ip_on traefik edge)
for target in "cs-console|http://$T:8085/" "api|http://$T:8000/rest/v1/"; do
  name=${target%%|*}; url=${target#*|}
  c="olt-zap-$name"
  docker rm -f "$c" > /dev/null 2>&1
  log "ZAP baseline $name -> $url"
  docker run --name "$c" --network "${STACK}_edge" -u zap --entrypoint sh "$ZAP_IMG" \
    -c "mkdir -p /zap/wrk && zap-baseline.py -t $url -m 1 -I -J zap-$name.json -r zap-$name.html" \
    > "$OUT/zap-$name.log" 2>&1
  docker cp "$c:/zap/wrk/zap-$name.json" "$OUT/" > /dev/null 2>&1 || docker cp "$c:/home/zap/zap-$name.json" "$OUT/" > /dev/null 2>&1
  docker cp "$c:/zap/wrk/zap-$name.html" "$OUT/" > /dev/null 2>&1
  docker rm -f "$c" > /dev/null 2>&1
  grep -E '^(WARN-NEW|FAIL-NEW|PASS|FAIL-INPROG|WARN-INPROG|INFO)' "$OUT/zap-$name.log" | tail -3
  grep -E '^WARN-NEW: |^FAIL-NEW: ' "$OUT/zap-$name.log" | sed 's/^/  /'
done
echo "hasil: ${OUT#/olt/}"
