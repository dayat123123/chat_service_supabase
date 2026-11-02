#!/usr/bin/env bash
# Menyiapkan halaman demo CS (development): agen demo dengan ID tetap, lalu mencetak isi
# runtime/config.js (URL API, anon key, dan token agen uji berlaku 8 jam) ke stdout.
# Dipanggil `make cs-demo`; file hasilnya di-gitignore dan hanya disajikan ke localhost.
set -euo pipefail
source "$(dirname "$0")/cs-lib.sh"
: "${ANON_KEY:?ANON_KEY wajib diisi}"

AGENTS=(
  '5e000000-0000-4000-8000-0000000000d1|Nadia|general|{"general": 2, "account": 3, "funds": 2, "technical": 2}'
  '5e000000-0000-4000-8000-0000000000d2|Bima|trading|{"trading": 3, "portfolio": 2, "general": 1}'
  '5e000000-0000-4000-8000-0000000000d3|Laras|complaints|{"complaint": 3, "fraud": 3, "general": 1}'
)

entries=()
for row in "${AGENTS[@]}"; do
  IFS='|' read -r id name team skills <<< "$row"
  ensure_agent "$id" "$name" "{cs_agent}" "$team" "$skills"
  code=$(sql "select agent_code from cs.agents where user_id = '$id'")
  entries+=("{\"id\":\"$id\",\"name\":\"$name\",\"code\":\"$code\",\"team\":\"$team\",\"token\":\"$(agent_jwt "$id" 28800)\"}")
done

customers='[{"id":"1002","username":"sari_invest"},{"id":"1003","username":"andi_trader"},{"id":"1005","username":"dewi_cuan"},{"id":"1004","username":"rina_saham"},{"id":"1001","username":"budi_santoso"}]'
printf 'window.CS_DEMO = {"api":"%s","anonKey":"%s","agents":[%s],"customers":%s};\n' \
  "${CS_DEMO_API:-http://localhost:8000}" "$ANON_KEY" "$(IFS=,; echo "${entries[*]}")" "$customers"
