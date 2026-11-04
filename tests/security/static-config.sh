#!/usr/bin/env bash
# Review statis konfigurasi edge produksi: router Traefik prod/cs, TLS, header keamanan, CORS,
# IP tepercaya Kong. Membaca file di /olt/docker (salinan read-only docker/, tanpa secrets).
set -uo pipefail
source /olt/tests/lib/common.sh

D=/olt/docker
PROD=$D/volumes/traefik/prod.yml
COMMON=$D/volumes/traefik/common.yml
CS=$D/volumes/traefik/cs.yml
OUT="${OUT_DIR:-$RESULTS/security-$(stamp)}"
mkdir -p "$OUT"
TSV="$OUT/static-config.tsv"
printf 'verdict\tseverity\tcheck\tdetail\n' > "$TSV"
pass=0 fail=0 info=0

res() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}" >> "$TSV"
  case "$1" in
    ok) pass=$((pass + 1)) ;;
    INFO) info=$((info + 1)); echo "info   - [$2] $3${4:+: $4}" ;;
    *) fail=$((fail + 1)); echo "TEMUAN - [$2] $3${4:+: $4}" ;;
  esac
}
check() { if eval "$3"; then res ok "$1" "$2"; else res FAIL "$1" "$2" "${4:-}"; fi; }

routers() { awk '/^  routers:/{r=1;next} /^  [a-z]+:/{r=0} r && /^    [a-z0-9-]+:$/{gsub(/[ :]/,"");name=$0} r && /rule:/{sub(/^ *rule: */,""); print name "\t" $0}' "$1"; }
entry_of() { awk -v n="    $2:" '$0==n{f=1;next} f && /^    [a-z0-9-]+:$/{f=0} f && /entryPoints:/{print; exit}' "$1"; }

echo "== router publik (prod.yml, entrypoint websecure)"
while IFS=$'\t' read -r name rule; do
  ep=$(entry_of "$PROD" "$name")
  [[ "$ep" == *websecure* ]] || continue
  check high "router $name dibatasi Host(PROXY_DOMAIN)" '[[ "$rule" == *"Host(\`{{ env \"PROXY_DOMAIN\" }}\`)"* ]]' "$rule"
  for p in /auth/v1 /pg/ /graphql/v1 /project /api/mcp /mcp /functions/v1; do
    check high "router $name tidak membuka $p" '[[ "$rule" != *"\`$p"* ]]' "$rule"
  done
  check high "router $name tidak memakai PathPrefix(\`/\`)" '[[ "$rule" != *"PathPrefix(\`/\`)"* ]]' "$rule"
done < <(routers "$PROD")
check high "router admin hanya di entrypoint admin" '[[ "$(entry_of "$PROD" admin)" == *"[admin]"* ]]'
check high "port admin Traefik terikat 127.0.0.1" 'grep -q "127.0.0.1:\${ADMIN_PORT:-8000}:9000/tcp" $D/compose.prod.yml'
check high "HTTP (80) dialihkan ke HTTPS" 'grep -q "TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_SCHEME: https" $D/compose.prod.yml'
check medium "Studio & pg-meta mati default di produksi (profile admin)" 'awk "/^  studio:/{s=1} s&&/profiles: \\[admin\\]/{print;exit}" $D/compose.prod.yml | grep -q admin'
echo "== API staf hanya di domain CS (T4)"
rule_of() { routers "$1" | awk -F'\t' -v n="$2" '$1==n{print $2}'; }
mw_of() { awk -v n="    $2:" '$0==n{f=1;next} f && /^    [a-z0-9-]+:$/{f=0} f && /middlewares:/{print; exit}' "$1"; }
block_rule=$(rule_of "$PROD" api-cs-staff-block)
check high "router api-cs-staff-block menolak Accept-Profile & Content-Profile cs_api" \
  '[[ "$block_rule" == *"HeaderRegexp(\`Accept-Profile\`, \`(?i)cs_api\`)"* && "$block_rule" == *"HeaderRegexp(\`Content-Profile\`, \`(?i)cs_api\`)"* && "$block_rule" == *"PathPrefix(\`/rest/v1\`)"* ]]' "$block_rule"
check high "api-cs-staff-block memakai staff-api-deny (ipAllowList 255.255.255.255/32)" \
  '[[ "$(mw_of "$PROD" api-cs-staff-block)" == *staff-api-deny* ]] && grep -A2 "^    staff-api-deny:" $PROD | grep -A1 ipAllowList | grep -q "255.255.255.255/32"'
check high "router api membuang Accept-Profile & Content-Profile (hanya skema public)" \
  '[[ "$(mw_of "$PROD" api)" == *public-schema-only* ]] && grep -A4 "^    public-schema-only:" $PROD | grep -q "Accept-Profile: \"\"" && grep -A4 "^    public-schema-only:" $PROD | grep -q "Content-Profile: \"\""'
for r in $(routers "$PROD" | awk -F'\t' '$2 ~ /\/rest\/v1/ {print $1}'); do
  [[ "$r" == api-cs-staff-block ]] && continue
  check high "router REST publik $r memasang X-Olt-Edge: public (check_request menolak JWT staf, 0100)" '[[ "$(mw_of "$PROD" "$r")" == *public-edge* ]]' "$(mw_of "$PROD" "$r")"
done
check high "middleware public-edge menimpa X-Olt-Edge: public" 'grep -A3 "^    public-edge:" $PROD | grep -q "X-Olt-Edge: public"'
check high "router cs-api membuang X-Olt-Edge (staf lolos lewat domain CS)" '[[ "$(mw_of "$CS" cs-api)" == *cs-edge* ]] && grep -A3 "^    cs-edge:" $CS | grep -q "X-Olt-Edge: \"\""'
for r in $(routers "$PROD" | awk -F'\t' '$2 ~ /\/(realtime|storage|media)\/v1/ {print $1}'); do
  check high "router publik $r memasang X-Olt-Edge: public (RLS Realtime/Storage menolak JWT staf, 0105)" '[[ "$(mw_of "$PROD" "$r")" == *public-edge* ]]' "$(mw_of "$PROD" "$r")"
done
for r in $(routers "$CS" | awk -F'\t' '$2 ~ /\/(rest|realtime|storage)\/v1/ {print $1}'); do
  check high "router CS $r membuang X-Olt-Edge (staf lolos lewat domain CS)" '[[ "$(mw_of "$CS" "$r")" == *cs-edge* ]]' "$(mw_of "$CS" "$r")"
done
check medium "/functions/v1 (cs-admin) tersedia di domain CS" '[[ "$(rule_of "$CS" cs-api)" == *"PathPrefix(\`/functions/v1\`)"* ]]'
check low "fungsi contoh hello tidak ter-deploy (T10)" '[ ! -e $D/volumes/functions/hello ]' "$(ls $D/volumes/functions | tr '\n' ' ')"
allow_rule=$(rule_of "$PROD" api-cs-customer)
allow=$(sed -n 's|.*\^/rest/v1/rpc/(\([a-z_|]*\))\$.*|\1|p' <<< "$allow_rule" | tr '|' '\n' | sort -u)
check high "api-cs-customer hanya allowlist RPC eksplisit ^/rest/v1/rpc/(...)\$" '[ -n "$allow" ]' "$allow_rule"
staffish=$(grep -E '^(agent_|admin_|supervisor_|community_|integration_|compliance_|nasabah_|report_)' <<< "$allow" | grep -v '^report_fake_cs$' || true)
check high "allowlist cs_api publik tanpa RPC staf (agent_*/admin_*/community_*/integration_*/...)" '[ -z "$staffish" ]' "$staffish"
if [ -d /olt/client-lib ]; then
  used=$(grep -rhoE "_cs\.rpc[A-Za-z]*\('[a-z_]+'" /olt/client-lib | sed -E "s/.*\('([a-z_]+)'/\1/" | sort -u)
  missing=$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$allow"))
  extra=$(comm -13 <(printf '%s\n' "$used") <(printf '%s\n' "$allow"))
  check high "semua RPC cs_api yang dipanggil rendezvous_community ada di allowlist publik ($(wc -l <<< "$used") fungsi)" '[ -z "$missing" ]' "$(tr '\n' ' ' <<< "$missing")"
  check low "allowlist publik tidak lebih luas dari pemanggilan client" '[ -z "$extra" ]' "$(tr '\n' ' ' <<< "$extra")"
else
  res INFO low "repo rendezvous_community tidak ditemukan (PKG, /olt/client-lib): allowlist cs_api publik tidak dicocokkan dengan client"
fi

echo "== batas per IP (T3) dan per user"
num() { grep -oE "$1:-[0-9]+" "$2" | head -1 | grep -oE '[0-9]+$'; }
tpl() { sed -n "s/.*env \"$1\" | default \"\([0-9]*\)\".*/\1/p" "$COMMON" | head -1; }
check medium "EDGE_WS_PER_IP default >= 100 (CGNAT/Wi-Fi kantor)" '[ "$(num EDGE_WS_PER_IP $D/compose.yml)" -ge 100 ] && [ "$(tpl EDGE_WS_PER_IP)" -ge 100 ]' "compose $(num EDGE_WS_PER_IP $D/compose.yml), common $(tpl EDGE_WS_PER_IP)"
check medium "EDGE_RATE_AVERAGE/BURST default >= 300/600 per IP" '[ "$(num EDGE_RATE_AVERAGE $D/compose.yml)" -ge 300 ] && [ "$(num EDGE_RATE_BURST $D/compose.yml)" -ge 600 ] && [ "$(tpl EDGE_RATE_AVERAGE)" -ge 300 ] && [ "$(tpl EDGE_RATE_BURST)" -ge 600 ]'
check medium "default compose = default common.yml (tanpa env traefik tetap sama)" '[ "$(num EDGE_WS_PER_IP $D/compose.yml)" = "$(tpl EDGE_WS_PER_IP)" ] && [ "$(num EDGE_RATE_AVERAGE $D/compose.yml)" = "$(tpl EDGE_RATE_AVERAGE)" ] && [ "$(num EDGE_RATE_BURST $D/compose.yml)" = "$(tpl EDGE_RATE_BURST)" ]'
check medium "auth-bridge exchange per IP default >= 300/menit" '[ "$(num AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE $D/compose.yml)" -ge 300 ]' "$(num AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE $D/compose.yml)"
check high "auth-bridge per user OLT tetap ketat (<= 10/menit) di compose dasar" '[ "$(num AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE $D/compose.yml)" -le 10 ]' "$(num AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE $D/compose.yml)"
envex=$(sed -n 's/^AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE=\([0-9]*\).*/\1/p' $D/.env.example | tail -1)
check medium "auth-bridge exchange per IP di .env.example >= 300/menit (.env server tidak menurunkan default)" '[ -n "$envex" ] && [ "$envex" -ge 300 ]' "$envex"
check medium "PostgREST gagal cepat saat pool habis (PGRST_DB_POOL_ACQUISITION_TIMEOUT default <= 5 dtk)" '[ "$(num PGRST_DB_POOL_ACQUISITION_TIMEOUT $D/compose.yml)" -le 5 ]' "$(num PGRST_DB_POOL_ACQUISITION_TIMEOUT $D/compose.yml)"
check medium "PgBouncer server_login_retry default <= 5 dtk (REST cepat pulih setelah Postgres restart, T6)" '[ "$(grep "^server_login_retry = " $D/pgbouncer/entrypoint.sh | grep -oE "RETRY:-[0-9]+" | grep -oE "[0-9]+")" -le 5 ]'
check medium "batas tenant Realtime tetap diset (koneksi, join/dtk, kanal per klien)" 'grep -q "TENANT_MAX_CONCURRENT_USERS:" $D/compose.yml && grep -q "TENANT_MAX_JOINS_PER_SECOND:" $D/compose.yml && grep -q "TENANT_MAX_CHANNELS_PER_CLIENT:" $D/compose.yml'
if grep -q 'PathPrefix(`/realtime/v1`)' "$PROD"; then
  res INFO low "/realtime/v1 publik mencakup REST /realtime/v1/api/* (broadcast); tenants & openapi diblok Kong, broadcast dibatasi RLS realtime.messages"
fi

echo "== TLS"
check high "TLS minimal 1.2" 'grep -q "minVersion: VersionTLS12" $PROD'
check medium "sniStrict default true" 'grep -q "sniStrict: {{ env \"TLS_SNI_STRICT\" | default \"true\" }}" $PROD && grep -q "TLS_SNI_STRICT:-true" $D/compose.prod.yml'
weak=$(awk '/cipherSuites:/{c=1;next} c&&/^ *- /{print $2;next} c{c=0}' "$PROD" | grep -v -E '^TLS_ECDHE_(ECDSA|RSA)_WITH_(AES_(128|256)_GCM_SHA(256|384)|CHACHA20_POLY1305)$' || true)
check high "cipher suite TLS 1.2 hanya ECDHE + AEAD" '[ -z "$weak" ]' "$weak"
check medium "kurva X25519/P-256/P-384 saja" '! awk "/curvePreferences:/{c=1;next} c&&/^ *- /{print \$2;next} c{c=0}" $PROD | grep -q -v -E "^(X25519|CurveP256|CurveP384)$"'
check medium "semua router websecure memakai certResolver le" '[ "$(grep -c "certResolver: le" $PROD)" -ge "$(grep -c "entryPoints: \[websecure\]" $PROD)" ]'

echo "== header keamanan"
check medium "HSTS max-age >= 1 tahun" 'grep -q "stsSeconds: 31536000" $COMMON'
check low "HSTS includeSubdomains" 'grep -q "stsIncludeSubdomains: true" $COMMON'
grep -q 'stsPreload: true' "$COMMON" || res INFO low "HSTS tanpa preload (opsional, butuh pendaftaran hstspreload.org)"
for r in $(routers "$PROD" | cut -f1); do
  [[ "$(entry_of "$PROD" "$r")" == *websecure* ]] || continue
  mw=$(awk -v n="    $r:" '$0==n{f=1;next} f && /^    [a-z0-9-]+:$/{f=0} f && /middlewares:/{print; exit}' "$PROD")
  check medium "router $r: hsts + security-headers + rate-limit" '[[ "$mw" == *hsts* && "$mw" == *security-headers* && "$mw" == *rate-limit* ]]' "$mw"
  check medium "router $r: batas body" '[[ "$r" == realtime || "$r" == storage || "$mw" == *body-* ]]' "$mw"
done
check medium "API: X-Frame-Options DENY, nosniff, CSP default-src none" 'grep -A8 "^    security-headers:" $COMMON | grep -q frameDeny && grep -A8 "^    security-headers:" $COMMON | grep -q "default-src '"'"'none'"'"'"'
check low "header Server dihapus" 'grep -q "Server: \"\"" $COMMON'
grep -q 'Permissions-Policy\|permissionsPolicy' "$COMMON" || res INFO low "Permissions-Policy tidak diset (tidak relevan untuk respons API JSON)"
check medium "akses log Traefik membuang header (token)" 'grep -q "TRAEFIK_ACCESSLOG_FIELDS_HEADERS_DEFAULTMODE: drop" $D/compose.yml'
check medium "Traefik menolak karakter path ter-encode berbahaya (websecure)" '[ "$(grep -c "WEBSECURE_HTTP_ENCODEDCHARACTERS_ALLOW.*\"false\"" $D/compose.prod.yml)" -ge 5 ]'
grep -q 'ipStrategy:' "$COMMON" && grep -A2 'ipStrategy:' "$COMMON" | grep -q 'depth: 0' && \
  res INFO medium "rate-limit & ws-limit per IP memakai alamat koneksi langsung (depth 0): bila nanti di belakang load balancer/CDN semua nasabah berbagi satu IP (atur ipStrategy); CGNAT/Wi-Fi kantor ditampung default longgar (T3)"

echo "== CORS"
check high "produksi: CORS_ALLOWED_ORIGINS default kosong" 'grep -A3 "^  kong:" $D/compose.prod.yml | grep -q "CORS_ALLOWED_ORIGINS: \${CORS_ALLOWED_ORIGINS:-}"'
check high "base compose: CORS default kosong (secure by default)" 'grep -q "CORS_ALLOWED_ORIGINS: \${CORS_ALLOWED_ORIGINS:-}" $D/compose.yml'
check high "kong-entrypoint: origin kosong -> origin tak-terpakai" 'grep -q "cors-disabled.invalid" $D/volumes/api/kong-entrypoint.sh'
grep -q 'CORS_ALLOWED_ORIGINS:-\*' "$D/compose.dev.yml" && res INFO low "dev: CORS * (hanya profil dev; jangan dipakai di server bersama)"
check medium "web CS produksi satu origin (cs.yml tanpa CORS, ipAllowList VPN)" 'grep -q "vpn-only" $CS && [ "$(grep -c "vpn-only" $CS)" -ge 6 ]'

echo "== proxy tepercaya"
check high "Kong hanya mempercayai X-Forwarded-For dari subnet edge" 'grep -q "KONG_TRUSTED_IPS: \${EDGE_SUBNET:-10.250.250.0/24}" $D/compose.yml'
grep -q 'forwardedHeaders' "$D/compose.yml" "$D/compose.prod.yml" || res ok low "Traefik tidak mempercayai X-Forwarded-For dari klien (forwardedHeaders tidak diset)"
grep -q 'TRUSTED_PROXIES' "$D/compose.yml" || res INFO low "auth-bridge TRUSTED_PROXIES default semua RFC1918; aman karena hanya Kong yang bisa menjangkaunya (network app), tetapi container lain di network app dapat memalsukan X-Forwarded-For ke auth-bridge"

echo "== container"
check medium "Studio tidak punya router publik" '! grep -q "studio" $PROD'
check high "dummy-olt tidak ada di compose produksi" '! grep -v "^ *#" $D/compose.prod.yml $D/compose.yml | grep -q "dummy-olt"'
published=$(for f in $D/compose*.yml $D/stack.cluster.yml; do awk '/^  [a-z0-9-]+:$/{svc=$1} /^    ports:/{sub(":","",svc); print svc}' "$f"; done | sort -u | grep -vxE 'traefik|dummy-olt' || true)
check high "hanya Traefik (dan dummy-olt dev) yang mem-publish port; admin/metrik PostgREST, Realtime, PgBouncer, sentinel internal" '[ -z "$published" ]' "$(tr '\n' ' ' <<< "$published")"
check high "Kong dan Traefik tidak me-route admin server PostgREST (:3001) atau /metrics" '! grep -qE ":3001|/metrics" $D/volumes/api/kong.yml $D/volumes/traefik/*.yml'
check high "auth-bridge produksi APP_ENV=production" 'grep -A3 "^  auth-bridge:" $D/compose.prod.yml | grep -q "APP_ENV: production"'

echo
echo "static-config: $pass ok, $fail temuan, $info catatan  (detail: ${OUT#/olt/}/static-config.tsv)"
[ "$fail" -eq 0 ]
