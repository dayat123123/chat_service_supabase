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
  for p in /auth/v1 /pg/ /graphql/v1 /project /api/mcp /mcp; do
    check high "router $name tidak membuka $p" '[[ "$rule" != *"\`$p"* ]]' "$rule"
  done
  check high "router $name tidak memakai PathPrefix(\`/\`)" '[[ "$rule" != *"PathPrefix(\`/\`)"* ]]' "$rule"
done < <(routers "$PROD")
check high "router admin hanya di entrypoint admin" '[[ "$(entry_of "$PROD" admin)" == *"[admin]"* ]]'
check high "port admin Traefik terikat 127.0.0.1" 'grep -q "127.0.0.1:\${ADMIN_PORT:-8000}:9000/tcp" $D/compose.prod.yml'
check high "HTTP (80) dialihkan ke HTTPS" 'grep -q "TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_SCHEME: https" $D/compose.prod.yml'
check medium "Studio & pg-meta mati default di produksi (profile admin)" 'awk "/^  studio:/{s=1} s&&/profiles: \\[admin\\]/{print;exit}" $D/compose.prod.yml | grep -q admin'
if grep -q 'PathPrefix(`/functions/v1`)' "$PROD"; then
  res INFO medium "/functions/v1 publik: semua Edge Function (termasuk cs-admin & contoh 'hello') terjangkau dari internet; cs-admin hanya dilindungi JWT super admin, bukan pembatasan jaringan VPN" \
    "$(ls $D/volumes/functions | tr '\n' ' ')"
fi
if grep -q 'PathPrefix(`/rest/v1`)' "$PROD"; then
  res INFO medium "/rest/v1 publik melayani skema cs_api (Content-Profile) termasuk RPC staf; JWT staf yang bocor bisa dipakai dari luar VPN (pembatasan VPN hanya pada domain CS & /auth/v1)"
fi
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
  res INFO medium "rate-limit & ws-limit per IP memakai alamat koneksi langsung (depth 0): bila nanti di belakang load balancer/CDN semua nasabah berbagi satu IP; NAT operator seluler (CGNAT) juga berbagi IP"

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
check high "auth-bridge produksi APP_ENV=production" 'grep -A3 "^  auth-bridge:" $D/compose.prod.yml | grep -q "APP_ENV: production"'

echo
echo "static-config: $pass ok, $fail temuan, $info catatan  (detail: ${OUT#/olt/}/static-config.tsv)"
[ "$fail" -eq 0 ]
