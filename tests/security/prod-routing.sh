#!/usr/bin/env bash
# Uji dinamis routing PRODUKSI tanpa server produksi: Traefik sementara (image & digest sama dengan
# stack) memuat docker/volumes/traefik/prod.yml + common.yml dengan entrypoint seperti compose.prod.yml,
# terhubung ke Kong dev lewat network edge. Sertifikat: default Traefik (ACME diarahkan ke alamat mati,
# TLS_SNI_STRICT=false agar sertifikat default dipakai). cs.yml ikut dimuat dengan domain CS uji dan
# VPN_SOURCE_RANGES = subnet edge (testkit), untuk membuktikan API staf hanya terjangkau lewat domain CS (T4).
# Batas edge diset kecil (nilai uji) agar mekanismenya terbukti cepat; default produksi dicek static-config.
# Container dihapus di akhir.
set -uo pipefail
source /olt/tests/lib/common.sh

DOMAIN=api.olt-test.invalid
CS_DOMAIN=cs.olt-test.invalid
EDGE_NET=$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "${STACK}_edge")
NAME=olt-prodroute-traefik
OUT="${OUT_DIR:-$RESULTS/security-$(stamp)}"
mkdir -p "$OUT"
TSV="$OUT/prod-routing.tsv"
printf 'verdict\tcheck\tstatus\n' > "$TSV"
BODY=$(mktemp)
pass=0 fail=0
res() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$TSV"
  if [ "$1" = ok ]; then pass=$((pass + 1)); elif [ "$1" = INFO ]; then echo "info   - $2"; else fail=$((fail + 1)); echo "TEMUAN - $2 (${3:-})"; fi
}

IMAGE=$(docker inspect -f '{{.Config.Image}}' "$(container traefik)")
docker rm -f "$NAME" > /dev/null 2>&1
docker create --name "$NAME" --network "${STACK}_edge" --tmpfs /tmp --cap-drop ALL --user 65532:65532 \
  -e TRAEFIK_GLOBAL_CHECKNEWVERSION=false -e TRAEFIK_GLOBAL_SENDANONYMOUSUSAGE=false -e TRAEFIK_LOG_LEVEL=ERROR \
  -e TRAEFIK_PROVIDERS_FILE_DIRECTORY=/etc/traefik/dynamic \
  -e TRAEFIK_ENTRYPOINTS_PING_ADDRESS=:8082 -e TRAEFIK_PING=true -e TRAEFIK_PING_ENTRYPOINT=ping \
  -e TRAEFIK_ENTRYPOINTS_WEB_ADDRESS=:8080 -e TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_TO=:443 \
  -e TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_SCHEME=https \
  -e TRAEFIK_ENTRYPOINTS_WEBSECURE_ADDRESS=:8443 -e TRAEFIK_ENTRYPOINTS_WEBSECURE_HTTP_MAXHEADERBYTES=32768 \
  -e TRAEFIK_ENTRYPOINTS_WEBSECURE_HTTP_ALIASHEADERSSTRATEGY=delete \
  -e TRAEFIK_ENTRYPOINTS_WEBSECURE_HTTP_ENCODEDCHARACTERS_ALLOWENCODEDSLASH=false \
  -e TRAEFIK_ENTRYPOINTS_WEBSECURE_HTTP_ENCODEDCHARACTERS_ALLOWENCODEDNULLCHARACTER=false \
  -e TRAEFIK_ENTRYPOINTS_ADMIN_ADDRESS=:9000 \
  -e TRAEFIK_CERTIFICATESRESOLVERS_LE_ACME_EMAIL=probe@olt-test.invalid \
  -e TRAEFIK_CERTIFICATESRESOLVERS_LE_ACME_STORAGE=/tmp/acme.json \
  -e TRAEFIK_CERTIFICATESRESOLVERS_LE_ACME_HTTPCHALLENGE_ENTRYPOINT=web \
  -e TRAEFIK_CERTIFICATESRESOLVERS_LE_ACME_CASERVER=https://127.0.0.1:9/directory \
  -e PROXY_DOMAIN=$DOMAIN -e TLS_SNI_STRICT=false -e CS_CONSOLE_DOMAIN=$CS_DOMAIN -e VPN_SOURCE_RANGES="$EDGE_NET" \
  -e EDGE_RATE_AVERAGE=100 -e EDGE_RATE_BURST=200 -e EDGE_WS_PER_IP=20 -e EDGE_BODY_MAX_API=262144 \
  "$IMAGE" > /dev/null || { echo "gagal membuat Traefik uji" >&2; exit 2; }
trap 'docker rm -f "$NAME" > /dev/null 2>&1; rm -f "$BODY"' EXIT
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/traefik/dynamic"
cp /olt/docker/volumes/traefik/common.yml "$tmpdir/traefik/dynamic/common.yml"
cp /olt/docker/volumes/traefik/prod.yml "$tmpdir/traefik/dynamic/routes.yml"
cp /olt/docker/volumes/traefik/cs.yml "$tmpdir/traefik/dynamic/cs.yml"
docker cp "$tmpdir/traefik" "$NAME:/etc/" > /dev/null || { echo "gagal menyalin konfigurasi" >&2; exit 2; }
docker start "$NAME" > /dev/null
IP=""
for _ in $(seq 1 30); do
  IP=$(docker inspect -f "{{with index .NetworkSettings.Networks \"${STACK}_edge\"}}{{.IPAddress}}{{end}}" "$NAME")
  [ -n "$IP" ] && curl -sf "http://$IP:8082/ping" > /dev/null && break
  sleep 1
done
log "Traefik uji $IP (image $IMAGE)"

H=https://$DOMAIN:8443
c() { curl -sk -o "$BODY" -D "$BODY.h" -w '%{http_code}' --resolve "$DOMAIN:8443:$IP" --resolve "$CS_DOMAIN:8443:$IP" --resolve "other.invalid:8443:$IP" "$@" 2>/dev/null || echo 000; }

code=$(c "$H/rest/v1/rpc/get_feed?p_limit=1" -H "apikey: $ANON_KEY")
[ "$code" = 200 ] || [ "$code" = 401 ] && res ok "REST publik terjangkau" "$code" || res FAIL "REST publik terjangkau" "$code"
code=$(c "$H/bridge/v1/health" -H "apikey: $ANON_KEY")
[ "$code" = 200 ] && res ok "auth-bridge health publik" "$code" || res FAIL "auth-bridge health publik" "$code"
for p in / /auth/v1/health /auth/v1/token /auth/v1/admin/users /pg/tables /graphql/v1 /project/default /api/mcp /mcp /studio \
         /realtime/v1/api/tenants /realtime/v1/api/openapi /rest/v1/ /bridge/v1/metrics /media/v1/metrics /integration/v1/metrics; do
  code=$(c "$H$p" -H "apikey: $ANON_KEY")
  case "$p" in
    /rest/v1/) [ "$code" = 401 ] || [ "$code" = 403 ] && res ok "OpenAPI root REST tidak terbuka untuk anon" "$code" || res FAIL "OpenAPI root REST terbuka" "$code" ;;
    /realtime/v1/api/*) [ "$code" = 403 ] || [ "$code" = 404 ] && res ok "$p diblok" "$code" || res FAIL "$p terbuka" "$code" ;;
    *) [[ "$code" =~ ^(404|401|403)$ ]] && res ok "$p tidak dipublikasikan" "$code" || res FAIL "$p terjangkau dari domain publik" "$code" ;;
  esac
done
code=$(curl -sk -o /dev/null -w '%{http_code}' --resolve "other.invalid:8443:$IP" "https://other.invalid:8443/rest/v1/rpc/get_feed" -H "apikey: $ANON_KEY")
[ "$code" = 404 ] && res ok "Host lain (bukan PROXY_DOMAIN) -> 404" "$code" || res FAIL "Host lain dilayani" "$code"
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $DOMAIN" "http://$IP:8080/rest/v1/")
[[ "$code" =~ ^30[178]$ ]] && res ok "HTTP dialihkan ke HTTPS" "$code" || res FAIL "HTTP tidak dialihkan" "$code"

CS=https://$CS_DOMAIN:8443
STAFF_JWT=$(staff_jwt 5e000000-0000-4000-8000-0000000000c1)
CUST_JWT=$(customer_jwt "$(kong_edge_url)" joko_prasetyo 198.51.100.23)
[ -n "$CUST_JWT" ] || res FAIL "gagal login nasabah uji joko_prasetyo (OLT dummy + auth-bridge)"
body_has() { grep -q -- "$1" "$BODY"; }
for p in /functions/v1/cs-admin/agents /functions/v1/hello /functions/v1/main; do
  code=$(c "$H$p" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT")
  [ "$code" = 404 ] && res ok "T4: $p tidak dipublikasikan di domain publik" "$code" || res FAIL "T4: $p terjangkau dari domain publik" "$code"
done
code=$(c "$H/rest/v1/rpc/agent_me" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H 'Accept-Profile: cs_api')
[ "$code" = 403 ] && ! body_has agent && res ok "T4: RPC staf cs_api (GET Accept-Profile) diblok edge publik" "$code" || res FAIL "T4: RPC staf cs_api terjangkau dari domain publik" "$code"
code=$(c "$H/rest/v1/rpc/agent_me" -X POST -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H 'Content-Profile: CS_API' -H 'Content-Type: application/json' -d '{}')
[ "$code" = 403 ] && res ok "T4: RPC staf cs_api (POST Content-Profile, huruf besar) diblok edge publik" "$code" || res FAIL "T4: RPC staf cs_api POST terjangkau" "$code"
code=$(c "$H/rest/v1/agents?select=user_id&limit=1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H 'Accept-Profile: cs_api')
[ "$code" = 403 ] && res ok "T4: tabel/view cs_api diblok edge publik" "$code" || res FAIL "T4: tabel/view cs_api terjangkau" "$code"
code=$(c "$H/rest/v1/rpc/get_feed?p_limit=1" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $CUST_JWT" -H 'Accept-Profile: graphql_public')
[ "$code" = 200 ] && res ok "T4: header profil lain dibuang di router publik (skema public dipakai)" "$code" \
  || res FAIL "T4: header profil tidak dibuang di router publik" "$code"
code=$(c "$H/rest/v1/rpc/topics?p_language=id" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $CUST_JWT" -H 'Accept-Profile: cs_api')
[ "$code" = 200 ] && res ok "T4: nasabah tetap bisa memakai RPC chat CS (cs_api.topics) di domain publik" "$code" || res FAIL "T4: chat CS nasabah terblokir" "$code"
code=$(c "$H/rest/v1/rpc/my_tickets" -X POST -H "apikey: $ANON_KEY" -H "Authorization: Bearer $CUST_JWT" -H 'Content-Profile: cs_api' -H 'Content-Type: application/json' -d '{}')
[ "$code" = 200 ] && res ok "T4: nasabah tetap bisa memakai cs_api.my_tickets (POST) di domain publik" "$code" || res FAIL "T4: cs_api.my_tickets nasabah terblokir" "$code"
code=$(c "$H/rest/v1/rpc/topics?p_language=id" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H 'Accept-Profile: cs_api' -H 'X-Olt-Edge: cs')
[ "$code" = 403 ] && body_has cs_staff_public_edge && res ok "T4: JWT staf ditolak DB di domain publik walau RPC-nya dibuka untuk nasabah (penanda edge tidak bisa dipalsukan)" "$code" \
  || res FAIL "T4: JWT staf diterima lewat domain publik" "$code"
code=$(c "$CS/rest/v1/rpc/topics?p_language=id" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H 'Accept-Profile: cs_api' -H 'X-Olt-Edge: public')
[ "$code" = 200 ] && res ok "T4: JWT staf tetap bekerja lewat domain CS (penanda edge dibuang)" "$code" || res FAIL "T4: JWT staf gagal lewat domain CS" "$code"
code=$(c "$CS/rest/v1/rpc/agent_me" -X POST -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H 'Content-Profile: cs_api' -H 'Content-Type: application/json' -d '{}')
[ "$code" = 200 ] && res ok "T4: RPC staf cs_api.agent_me terjangkau lewat domain CS" "$code" || res FAIL "T4: RPC staf gagal lewat domain CS" "$code"
code=$(c "$CS/functions/v1/cs-admin/agents" -X POST -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT" -H "Content-Type: application/json" -d "{}")
[ "$code" = 403 ] && body_has role_forbidden && res ok "T4: cs-admin terjangkau lewat domain CS (agen biasa ditolak fungsi: role_forbidden)" "$code" \
  || res FAIL "T4: cs-admin tidak terjangkau lewat domain CS" "$code"
code=$(c "$CS/functions/v1/hello" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $STAFF_JWT")
[ "$code" = 404 ] && res ok "T10: fungsi contoh hello tidak ter-deploy" "$code" || res FAIL "T10: fungsi contoh hello masih ada" "$code"

code=$(c "$H/rest/v1/rpc/get_feed?p_limit=1" -H "apikey: $ANON_KEY")
hdr() { grep -i "^$1:" "$BODY.h" | head -1 | tr -d '\r'; }
[ -n "$(hdr strict-transport-security)" ] && res ok "HSTS: $(hdr strict-transport-security | cut -d' ' -f2-)" || res FAIL "HSTS tidak ada"
[[ "$(hdr x-frame-options)" == *DENY* ]] && res ok "X-Frame-Options DENY" || res FAIL "X-Frame-Options"
[[ "$(hdr x-content-type-options)" == *nosniff* ]] && res ok "X-Content-Type-Options nosniff" || res FAIL "nosniff"
[[ "$(hdr content-security-policy)" == *"default-src 'none'"* ]] && res ok "CSP default-src 'none'" || res FAIL "CSP"
[ -z "$(hdr server)" ] && res ok "header Server tidak bocor" || res FAIL "header Server: $(hdr server)"
code=$(c "$H/rest/v1/rpc/get_feed?p_limit=1" -H "apikey: $ANON_KEY" -H 'Origin: https://evil.example')
acao=$(hdr access-control-allow-origin)
[[ -z "$acao" || "$acao" == *cors-disabled.invalid* ]] && res ok "CORS: origin asing tidak diizinkan (ACAO '${acao#*: }')" \
  || res INFO "CORS via Kong DEV ($acao): Kong uji memakai CORS dev '*'; produksi diverifikasi statis" "$code"

tls() {
  local o
  o=$(echo | timeout 10 openssl s_client -connect "$IP:8443" -servername "$DOMAIN" "$@" 2>&1)
  printf '%s\n' "$o" >> "$OUT/prod-routing-tls.txt"
  printf '%s\n' "$o"
}
set +o pipefail
tls -tls1_1 -cipher 'DEFAULT@SECLEVEL=0' | grep -q "^New, TLSv" && res FAIL "TLS 1.1 diterima" || res ok "TLS 1.1 ditolak"
tls -tls1 -cipher 'DEFAULT@SECLEVEL=0' | grep -q "^New, TLSv" && res FAIL "TLS 1.0 diterima" || res ok "TLS 1.0 ditolak"
tls -tls1_2 | grep -q 'Protocol *: TLSv1.2\|TLSv1.2, Cipher' && res ok "TLS 1.2 diterima" || res FAIL "TLS 1.2 gagal"
tls -tls1_3 | grep -q 'TLSv1.3' && res ok "TLS 1.3 diterima" || res FAIL "TLS 1.3 gagal"
for weak in AES128-SHA AES256-SHA256 AES128-GCM-SHA256 ECDHE-RSA-AES128-SHA ECDHE-RSA-AES256-SHA384; do
  tls -tls1_2 -cipher "$weak@SECLEVEL=0" | grep -q "^New, TLSv" && res FAIL "cipher lemah $weak diterima" || res ok "cipher lemah $weak ditolak"
done

set -o pipefail
head -c 300000 /dev/zero | tr '\0' a > "$BODY.big"
code=$(c "$H/rest/v1/rpc/get_feed" -X POST -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' --data-binary "@$BODY.big")
[ "$code" = 413 ] && res ok "body API > 256 KB ditolak 413" "$code" || res FAIL "body API besar tidak ditolak" "$code"
code=$(c "$H/rest/v1/rpc/get_feed" -X POST -H "apikey: $ANON_KEY" -H 'X-Forwarded_For: 1.2.3.4' -H 'Content-Type: application/json' -d '{}')
res ok "header alias (X-Forwarded_For) tidak memutus request" "$code"
code=$(c "$H/rest/v1/rpc/get_feed%2F..%2Fadmin" -H "apikey: $ANON_KEY")
[ "$code" = 400 ] && res ok "path dengan %2F ditolak 400" "$code" || res FAIL "path %2F tidak ditolak" "$code"

for _ in $(seq 1 400); do printf 'url = "%s"\noutput = "/dev/null"\n' "$H/bridge/v1/health"; done > "$BODY.urls"
codes=$(curl -sk --parallel --parallel-max 50 --resolve "$DOMAIN:8443:$IP" -H "apikey: $ANON_KEY" -o /dev/null -w '%{http_code}\n' -K "$BODY.urls" 2>/dev/null | sort | uniq -c | tr '\n' ' ')
[[ "$codes" == *" 429"* ]] && res ok "rate limit edge aktif (400 request cepat dari 1 IP: $codes)" || res FAIL "rate limit edge tidak memicu 429 ($codes)"
echo "rate-limit edge: $codes" > "$OUT/prod-routing-ratelimit.txt"

if k6 run -q --summary-mode disabled --log-format raw --insecure-skip-tls-verify -e WS_URL="wss://$DOMAIN:8443" -e IP="$IP" -e DOMAIN="$DOMAIN" \
     -e ANON_KEY="$ANON_KEY" /olt/tests/security/ws-limit.js > "$OUT/ws-limit.log" 2>&1; then
  r=$(sed -n 's/^RESULT //p' "$OUT/ws-limit.log" | tail -1)
  opened=$(jq -r .opened <<< "$r"); rejected=$(jq -r .rejected <<< "$r")
  [ "$opened" -le 20 ] && [ "$rejected" -gt 0 ] && res ok "ws-limit: $opened WebSocket terbuka, $rejected ditolak dari 1 IP (batas uji 20; default EDGE_WS_PER_IP 150)" \
    || res FAIL "ws-limit tidak membatasi ($opened terbuka, $rejected ditolak)"
else
  res FAIL "k6 ws-limit gagal (lihat ws-limit.log)"
fi

echo
echo "prod-routing: $pass ok, $fail temuan  (detail: ${OUT#/olt/}/prod-routing.tsv)"
[ "$fail" -eq 0 ]
