#!/usr/bin/env bash
# Kode TOTP saat ini untuk akun staf dev, dibaca dari staff.json lewat stdin (make cs-totp).
set -euo pipefail
source "$(dirname "$0")/cs-lib.sh"

staff=$(cat)
left=$((30 - $(date +%s) % 30))
while read -r email secret; do
  printf '%-24s %s\n' "$email" "$(totp "$secret")"
done < <(jq -r '.staff[] | "\(.email) \(.totp_secret)"' <<< "$staff")
echo "(berlaku $left detik lagi)"
