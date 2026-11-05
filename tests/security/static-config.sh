#!/usr/bin/env bash
# Reads /olt/docker, a read-only copy of docker/ with secrets masked.
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
    *) fail=$((fail + 1)); echo "FINDING - [$2] $3${4:+: $4}" ;;
  esac
}
check() { if eval "$3"; then res ok "$1" "$2"; else res FAIL "$1" "$2" "${4:-}"; fi; }

routers() { awk '/^  routers:/{r=1;next} /^  [a-z]+:/{r=0} r && /^    [a-z0-9-]+:$/{gsub(/[ :]/,"");name=$0} r && /rule:/{sub(/^ *rule: */,""); print name "\t" $0}' "$1"; }
entry_of() { awk -v n="    $2:" '$0==n{f=1;next} f && /^    [a-z0-9-]+:$/{f=0} f && /entryPoints:/{print; exit}' "$1"; }

echo "== public routers (prod.yml, websecure entrypoint)"
while IFS=$'\t' read -r name rule; do
  ep=$(entry_of "$PROD" "$name")
  [[ "$ep" == *websecure* ]] || continue
  check high "router $name restricted to Host(PROXY_DOMAIN)" '[[ "$rule" == *"Host(\`{{ env \"PROXY_DOMAIN\" }}\`)"* ]]' "$rule"
  for p in /auth/v1 /pg/ /graphql/v1 /project /api/mcp /mcp /functions/v1; do
    check high "router $name does not expose $p" '[[ "$rule" != *"\`$p"* ]]' "$rule"
  done
  check high "router $name does not use PathPrefix(\`/\`)" '[[ "$rule" != *"PathPrefix(\`/\`)"* ]]' "$rule"
done < <(routers "$PROD")
check high "admin router only on the admin entrypoint" '[[ "$(entry_of "$PROD" admin)" == *"[admin]"* ]]'
check high "Traefik admin port bound to 127.0.0.1" 'grep -q "127.0.0.1:\${ADMIN_PORT:-8000}:9000/tcp" $D/compose.prod.yml'
check high "HTTP (80) redirected to HTTPS" 'grep -q "TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_SCHEME: https" $D/compose.prod.yml'
check medium "Studio & pg-meta off by default in production (admin profile)" 'awk "/^  studio:/{s=1} s&&/profiles: \\[admin\\]/{print;exit}" $D/compose.prod.yml | grep -q admin'
echo "== staff API only on the CS domain (T4)"
rule_of() { routers "$1" | awk -F'\t' -v n="$2" '$1==n{print $2}'; }
mw_of() { awk -v n="    $2:" '$0==n{f=1;next} f && /^    [a-z0-9-]+:$/{f=0} f && /middlewares:/{print; exit}' "$1"; }
block_rule=$(rule_of "$PROD" api-cs-staff-block)
check high "router api-cs-staff-block rejects Accept-Profile & Content-Profile cs_api" \
  '[[ "$block_rule" == *"HeaderRegexp(\`Accept-Profile\`, \`(?i)cs_api\`)"* && "$block_rule" == *"HeaderRegexp(\`Content-Profile\`, \`(?i)cs_api\`)"* && "$block_rule" == *"PathPrefix(\`/rest/v1\`)"* ]]' "$block_rule"
check high "api-cs-staff-block uses staff-api-deny (ipAllowList 255.255.255.255/32)" \
  '[[ "$(mw_of "$PROD" api-cs-staff-block)" == *staff-api-deny* ]] && grep -A2 "^    staff-api-deny:" $PROD | grep -A1 ipAllowList | grep -q "255.255.255.255/32"'
check high "router api strips Accept-Profile & Content-Profile (public schema only)" \
  '[[ "$(mw_of "$PROD" api)" == *public-schema-only* ]] && grep -A4 "^    public-schema-only:" $PROD | grep -q "Accept-Profile: \"\"" && grep -A4 "^    public-schema-only:" $PROD | grep -q "Content-Profile: \"\""'
for r in $(routers "$PROD" | awk -F'\t' '$2 ~ /\/rest\/v1/ {print $1}'); do
  [[ "$r" == api-cs-staff-block ]] && continue
  check high "public REST router $r sets X-Olt-Edge: public (check_request rejects staff JWT, 0100)" '[[ "$(mw_of "$PROD" "$r")" == *public-edge* ]]' "$(mw_of "$PROD" "$r")"
done
check high "public-edge middleware overwrites X-Olt-Edge: public" 'grep -A3 "^    public-edge:" $PROD | grep -q "X-Olt-Edge: public"'
check high "router cs-api strips X-Olt-Edge (staff pass via CS domain)" '[[ "$(mw_of "$CS" cs-api)" == *cs-edge* ]] && grep -A3 "^    cs-edge:" $CS | grep -q "X-Olt-Edge: \"\""'
for r in $(routers "$PROD" | awk -F'\t' '$2 ~ /\/(realtime|storage|media)\/v1/ {print $1}'); do
  check high "public router $r sets X-Olt-Edge: public (Realtime/Storage RLS rejects staff JWT, 0105)" '[[ "$(mw_of "$PROD" "$r")" == *public-edge* ]]' "$(mw_of "$PROD" "$r")"
done
for r in $(routers "$CS" | awk -F'\t' '$2 ~ /\/(rest|realtime|storage)\/v1/ {print $1}'); do
  check high "CS router $r strips X-Olt-Edge (staff pass via CS domain)" '[[ "$(mw_of "$CS" "$r")" == *cs-edge* ]]' "$(mw_of "$CS" "$r")"
done
check medium "/functions/v1 (cs-admin) available on the CS domain" '[[ "$(rule_of "$CS" cs-api)" == *"PathPrefix(\`/functions/v1\`)"* ]]'
check low "sample function hello is not deployed (T10)" '[ ! -e $D/volumes/functions/hello ]' "$(ls $D/volumes/functions | tr '\n' ' ')"
allow_rule=$(rule_of "$PROD" api-cs-customer)
allow=$(sed -n 's|.*\^/rest/v1/rpc/(\([a-z_|]*\))\$.*|\1|p' <<< "$allow_rule" | tr '|' '\n' | sort -u)
check high "api-cs-customer allows only an explicit RPC allowlist ^/rest/v1/rpc/(...)\$" '[ -n "$allow" ]' "$allow_rule"
staffish=$(grep -E '^(agent_|admin_|supervisor_|community_|integration_|compliance_|nasabah_|report_)' <<< "$allow" | grep -v '^report_fake_cs$' || true)
check high "public cs_api allowlist has no staff RPCs (agent_*/admin_*/community_*/integration_*/...)" '[ -z "$staffish" ]' "$staffish"
if [ -d /olt/client-lib ]; then
  used=$(grep -rhoE "_cs\.rpc[A-Za-z]*\('[a-z_]+'" /olt/client-lib | sed -E "s/.*\('([a-z_]+)'/\1/" | sort -u)
  missing=$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$allow"))
  extra=$(comm -13 <(printf '%s\n' "$used") <(printf '%s\n' "$allow"))
  check high "every cs_api RPC called by rendezvous_community is in the public allowlist ($(wc -l <<< "$used") functions)" '[ -z "$missing" ]' "$(tr '\n' ' ' <<< "$missing")"
  check low "public allowlist is no wider than client calls" '[ -z "$extra" ]' "$(tr '\n' ' ' <<< "$extra")"
else
  res INFO low "rendezvous_community repo not found (PKG, /olt/client-lib): public cs_api allowlist not matched against the client"
fi

echo "== per-IP (T3) and per-user limits"
num() { grep -oE "$1:-[0-9]+" "$2" | head -1 | grep -oE '[0-9]+$'; }
tpl() { sed -n "s/.*env \"$1\" | default \"\([0-9]*\)\".*/\1/p" "$COMMON" | head -1; }
check medium "EDGE_WS_PER_IP default >= 1000 (~1,000 customers per CGNAT/office Wi-Fi IP)" '[ "$(num EDGE_WS_PER_IP $D/compose.yml)" -ge 1000 ] && [ "$(tpl EDGE_WS_PER_IP)" -ge 1000 ]' "compose $(num EDGE_WS_PER_IP $D/compose.yml), common $(tpl EDGE_WS_PER_IP)"
check medium "EDGE_RATE_AVERAGE/BURST default >= 600/1200 per IP" '[ "$(num EDGE_RATE_AVERAGE $D/compose.yml)" -ge 600 ] && [ "$(num EDGE_RATE_BURST $D/compose.yml)" -ge 1200 ] && [ "$(tpl EDGE_RATE_AVERAGE)" -ge 600 ] && [ "$(tpl EDGE_RATE_BURST)" -ge 1200 ]'
check medium "compose default = common.yml default (same without traefik env)" '[ "$(num EDGE_WS_PER_IP $D/compose.yml)" = "$(tpl EDGE_WS_PER_IP)" ] && [ "$(num EDGE_RATE_AVERAGE $D/compose.yml)" = "$(tpl EDGE_RATE_AVERAGE)" ] && [ "$(num EDGE_RATE_BURST $D/compose.yml)" = "$(tpl EDGE_RATE_BURST)" ]'
check medium "auth-bridge exchange per IP default >= 1000/min" '[ "$(num AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE $D/compose.yml)" -ge 1000 ]' "$(num AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE $D/compose.yml)"
check high "auth-bridge per OLT user stays strict (<= 10/min) in base compose" '[ "$(num AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE $D/compose.yml)" -le 10 ]' "$(num AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE $D/compose.yml)"
traefik_mem=$(awk '/^  traefik:/{t=1;next} t&&/^  [a-z]/{exit} t&&/memory:/{match($0,/memory: [0-9]+M/); print substr($0,RSTART+8,RLENGTH-9); exit}' $D/compose.yml)
check medium "Traefik memory >= 512M (~0.26 MiB per WebSocket, EDGE_WS_PER_IP 1500)" '[ -n "$traefik_mem" ] && [ "$traefik_mem" -ge 512 ]' "${traefik_mem}M"
envex=$(sed -n 's/^AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE=\([0-9]*\).*/\1/p' $D/.env.example | tail -1)
check medium "auth-bridge exchange per IP in .env.example >= 1000/min (server .env does not lower the default)" '[ -n "$envex" ] && [ "$envex" -ge 1000 ]' "$envex"
check medium "PostgREST fails fast when the pool is exhausted (PGRST_DB_POOL_ACQUISITION_TIMEOUT default <= 5 s)" '[ "$(num PGRST_DB_POOL_ACQUISITION_TIMEOUT $D/compose.yml)" -le 5 ]' "$(num PGRST_DB_POOL_ACQUISITION_TIMEOUT $D/compose.yml)"
check medium "PgBouncer server_login_retry default <= 1 s (REST recovers quickly after Postgres restart, T6)" 'awk -v v="$(grep "^server_login_retry = " $D/pgbouncer/entrypoint.sh | grep -oE "RETRY:-[0-9.]+" | grep -oE "[0-9.]+$")" "BEGIN { exit !(v != \"\" && v <= 1) }"' 
check medium "PgBouncer uses the watched database host IP, not the c-ares DNS cache (T6)" 'grep -q "getent hosts" $D/pgbouncer/entrypoint.sh && grep -q "host=\$1 port=" $D/pgbouncer/entrypoint.sh && grep -q "kill -HUP" $D/pgbouncer/entrypoint.sh'
check medium "Realtime tenant limits are set (connections, joins/s, channels per client)" 'grep -q "TENANT_MAX_CONCURRENT_USERS:" $D/compose.yml && grep -q "TENANT_MAX_JOINS_PER_SECOND:" $D/compose.yml && grep -q "TENANT_MAX_CHANNELS_PER_CLIENT:" $D/compose.yml'
if grep -q 'PathPrefix(`/realtime/v1`)' "$PROD"; then
  res INFO low "public /realtime/v1 includes REST /realtime/v1/api/* (broadcast); tenants & openapi blocked by Kong, broadcast limited by realtime.messages RLS"
fi

echo "== TLS"
check high "TLS minimum 1.2" 'grep -q "minVersion: VersionTLS12" $PROD'
check medium "sniStrict default true" 'grep -q "sniStrict: {{ env \"TLS_SNI_STRICT\" | default \"true\" }}" $PROD && grep -q "TLS_SNI_STRICT:-true" $D/compose.prod.yml'
weak=$(awk '/cipherSuites:/{c=1;next} c&&/^ *- /{print $2;next} c{c=0}' "$PROD" | grep -v -E '^TLS_ECDHE_(ECDSA|RSA)_WITH_(AES_(128|256)_GCM_SHA(256|384)|CHACHA20_POLY1305)$' || true)
check high "TLS 1.2 cipher suites ECDHE + AEAD only" '[ -z "$weak" ]' "$weak"
check medium "curves X25519/P-256/P-384 only" '! awk "/curvePreferences:/{c=1;next} c&&/^ *- /{print \$2;next} c{c=0}" $PROD | grep -q -v -E "^(X25519|CurveP256|CurveP384)$"'
check medium "all websecure routers use certResolver le" '[ "$(grep -c "certResolver: le" $PROD)" -ge "$(grep -c "entryPoints: \[websecure\]" $PROD)" ]'

echo "== security headers"
check medium "HSTS max-age >= 1 year" 'grep -q "stsSeconds: 31536000" $COMMON'
check low "HSTS includeSubdomains" 'grep -q "stsIncludeSubdomains: true" $COMMON'
grep -q 'stsPreload: true' "$COMMON" || res INFO low "HSTS without preload (optional, requires hstspreload.org registration)"
for r in $(routers "$PROD" | cut -f1); do
  [[ "$(entry_of "$PROD" "$r")" == *websecure* ]] || continue
  mw=$(awk -v n="    $r:" '$0==n{f=1;next} f && /^    [a-z0-9-]+:$/{f=0} f && /middlewares:/{print; exit}' "$PROD")
  check medium "router $r: hsts + security-headers + rate-limit" '[[ "$mw" == *hsts* && "$mw" == *security-headers* && "$mw" == *rate-limit* ]]' "$mw"
  check medium "router $r: body limit" '[[ "$r" == realtime || "$r" == storage || "$mw" == *body-* ]]' "$mw"
done
check medium "API: X-Frame-Options DENY, nosniff, CSP default-src none" 'grep -A8 "^    security-headers:" $COMMON | grep -q frameDeny && grep -A8 "^    security-headers:" $COMMON | grep -q "default-src '"'"'none'"'"'"'
check low "Server header removed" 'grep -q "Server: \"\"" $COMMON'
grep -q 'Permissions-Policy\|permissionsPolicy' "$COMMON" || res INFO low "Permissions-Policy not set (not relevant for JSON API responses)"
check medium "Traefik access log drops headers (tokens)" 'grep -q "TRAEFIK_ACCESSLOG_FIELDS_HEADERS_DEFAULTMODE: drop" $D/compose.yml'
check medium "Traefik rejects dangerous encoded path characters (websecure)" '[ "$(grep -c "WEBSECURE_HTTP_ENCODEDCHARACTERS_ALLOW.*\"false\"" $D/compose.prod.yml)" -ge 5 ]'
grep -q 'ipStrategy:' "$COMMON" && grep -A2 'ipStrategy:' "$COMMON" | grep -q 'depth: 0' && \
  res INFO medium "per-IP rate-limit & ws-limit use the direct connection address (depth 0): behind a load balancer/CDN all customers would share one IP (set ipStrategy); CGNAT/office Wi-Fi is covered by the loose defaults (T3)"

echo "== CORS"
check high "production: CORS_ALLOWED_ORIGINS default empty" 'grep -A3 "^  kong:" $D/compose.prod.yml | grep -q "CORS_ALLOWED_ORIGINS: \${CORS_ALLOWED_ORIGINS:-}"'
check high "base compose: CORS default empty (secure by default)" 'grep -q "CORS_ALLOWED_ORIGINS: \${CORS_ALLOWED_ORIGINS:-}" $D/compose.yml'
check high "kong-entrypoint: empty origin -> unused origin" 'grep -q "cors-disabled.invalid" $D/volumes/api/kong-entrypoint.sh'
grep -q 'CORS_ALLOWED_ORIGINS:-\*' "$D/compose.dev.yml" && res INFO low "dev: CORS * (dev profile only; do not use on a shared server)"
check medium "production web CS is single-origin (cs.yml without CORS, VPN ipAllowList)" 'grep -q "vpn-only" $CS && [ "$(grep -c "vpn-only" $CS)" -ge 6 ]'

echo "== trusted proxies"
check high "Kong trusts X-Forwarded-For only from the edge subnet" 'grep -q "KONG_TRUSTED_IPS: \${EDGE_SUBNET:-10.250.250.0/24}" $D/compose.yml'
grep -q 'forwardedHeaders' "$D/compose.yml" "$D/compose.prod.yml" || res ok low "Traefik does not trust client X-Forwarded-For (forwardedHeaders not set)"
grep -q 'TRUSTED_PROXIES' "$D/compose.yml" || res INFO low "auth-bridge TRUSTED_PROXIES defaults to all RFC1918; safe because only Kong can reach it (app network), but other containers on the app network could forge X-Forwarded-For to auth-bridge"

echo "== container"
check medium "Studio has no public router" '! grep -q "studio" $PROD'
check high "dummy-olt is absent from production compose" '! grep -v "^ *#" $D/compose.prod.yml $D/compose.yml | grep -q "dummy-olt"'
published=$(for f in $D/compose*.yml $D/stack.cluster.yml; do awk '/^  [a-z0-9-]+:$/{svc=$1} /^    ports:/{sub(":","",svc); print svc}' "$f"; done | sort -u | grep -vxE 'traefik|dummy-olt' || true)
check high "only Traefik (and dev dummy-olt) publish ports; PostgREST admin/metrics, Realtime, PgBouncer, sentinel stay internal" '[ -z "$published" ]' "$(tr '\n' ' ' <<< "$published")"
check high "Kong and Traefik do not route the PostgREST admin server (:3001) or /metrics" '! grep -qE ":3001|/metrics" $D/volumes/api/kong.yml $D/volumes/traefik/*.yml'
check high "production auth-bridge APP_ENV=production" 'grep -A3 "^  auth-bridge:" $D/compose.prod.yml | grep -q "APP_ENV: production"'

echo "== healer (automatic restart, Docker socket)"
block() { tr -d '\r' < "$1" | awk -v s="  $2:" '$0==s{f=1;next} f&&(/^  [a-z0-9-]+:$/||/^[a-z]/){f=0} f'; }
healer=$(block $D/compose.yml healer)
check high "healer exists in base compose" '[ -n "$healer" ]'
check high "healer has no network at all (network_mode: none)" 'grep -qx "    network_mode: none" <<< "$healer"'
check high "healer has no ports/expose/networks (no listener)" '! grep -qE "^    (ports|expose|networks):" <<< "$healer"'
check high "healer uses base hardening (read-only, cap_drop ALL, no-new-privileges) and a non-root user" 'grep -qx "    <<: \*base" <<< "$healer" && grep -qx "    user: \"65532:65532\"" <<< "$healer"'
check medium "healer is limited to small memory/CPU" 'grep -qE "limits: \{cpus: \"0\.[0-9]+\", memory: [0-9]+M" <<< "$healer"'
socks=$(for f in $D/compose*.yml $D/stack.cluster.yml; do tr -d '\r' < "$f" | awk -v F="${f##*/}" '/^  [a-z0-9-]+:$/{svc=$1} /docker\.sock/ && !/^ *#/{sub(":","",svc); print F ":" svc}'; done | sort -u)
check high "Docker socket is mounted only into healer" '[ "$socks" = "compose.yml:healer" ]' "$(tr '\n' ' ' <<< "$socks")"
check high "healer does not run in the cluster profile (replicas 0; Swarm replaces unhealthy tasks)" 'block $D/stack.cluster.yml healer | grep -qx "      replicas: 0"'
check medium "cluster sentinel does not read healer state (no false healer:stale)" 'block $D/stack.cluster.yml sentinel | grep -q "HEALER_STATE_FILE: \"\""'
autoheal=$(tr -d '\r' < $D/compose.yml | awk '/^  [a-z0-9-]+:$/{svc=$1} /olt\.autoheal=true/ && !/^ *#/{sub(":","",svc); print svc}' | sort -u)
bad_autoheal=$(grep -xE "db|valkey|sentinel|healer|migrate|tools|volume-init|studio|meta" <<< "$autoheal" || true)
check high "db, valkey, sentinel, healer, and one-shot services are not labeled olt.autoheal" '[ -z "$bad_autoheal" ]' "$(tr '\n' ' ' <<< "$bad_autoheal")"
check medium "stateless services with healthchecks are labeled olt.autoheal (rest, realtime, kong, auth, pgbouncer, traefik, ...)" '[ "$(grep -cxE "traefik|kong|auth|rest|realtime|storage|imgproxy|functions|pgbouncer|auth-bridge|notifier|janitor|classifier|media|backup|integration|link-preview|cs-console|nasabah-gateway" <<< "$autoheal")" -eq 19 ]' "$(tr '\n' ' ' <<< "$autoheal")"

echo
echo "static-config: $pass ok, $fail findings, $info notes  (detail: ${OUT#/olt/}/static-config.tsv)"
[ "$fail" -eq 0 ]
