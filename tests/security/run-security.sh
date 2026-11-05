#!/usr/bin/env bash
# Dependency and image scanning runs separately on the host: make scan-deps.
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
echo "results: ${OUT_DIR#/olt/}"
exit "$status"
