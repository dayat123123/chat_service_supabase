#!/usr/bin/env bash
# Rangkaian uji keamanan di dalam testkit: otorisasi (API, Storage, Realtime, integrasi),
# review statis konfigurasi edge, dan uji dinamis routing produksi. Pindai dependensi/image
# dijalankan terpisah di host: make scan-deps (tests/security/scan-deps.sh).
set -uo pipefail
source /olt/tests/lib/common.sh

export OUT_DIR="$RESULTS/security-$(stamp)"
mkdir -p "$OUT_DIR"
status=0
for part in authz-probe static-config prod-routing; do
  echo
  echo "################ $part"
  bash "/olt/tests/security/$part.sh" 2>&1 | tee "$OUT_DIR/$part.log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done
echo
grep -h -E '^(authz-probe|static-config|prod-routing):' "$OUT_DIR"/*.log
echo "hasil: ${OUT_DIR#/olt/}"
exit "$status"
