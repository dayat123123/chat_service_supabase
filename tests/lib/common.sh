#!/usr/bin/env bash

STACK="${STACK:-olt-social}"
SECRETS="${SECRETS_DIR:-/olt/secrets}"
RESULTS="${RESULTS_DIR:-/olt/results}"
TESTS="${TESTS_DIR:-/olt/tests}"
OLT="${DUMMY_OLT_URL:-http://dummy-olt:8090}"

secret() { tr -d '\r\n' < "$SECRETS/$1"; }

export PGHOST="${PGHOST:-db}" PGPORT="${PGPORT:-5432}" PGDATABASE="${PGDATABASE:-postgres}" PGUSER="${PGUSER:-postgres}"
PGPASSWORD="$(secret postgres_password)"
export PGPASSWORD
ANON_KEY="$(secret anon_key)"
JWT_SECRET="$(secret jwt_secret)"

sql() { psql -X -q -tA -v ON_ERROR_STOP=1 -c "$1"; }
sql_bouncer() { psql -X -q -h pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c "$1"; }

container() { printf '%s-%s-1' "$STACK" "$1"; }
ip_on() { docker inspect -f "{{with index .NetworkSettings.Networks \"${STACK}_$2\"}}{{.IPAddress}}{{end}}" "$(container "$1")"; }

kong_edge_url() { printf 'http://%s:8000' "$(ip_on kong edge)"; }
traefik_url() { printf 'http://%s:8000' "$(ip_on traefik edge)"; }

b64url() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
sign_hs256() {
  local head payload
  head=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '%s' "$1" | b64url)
  printf '%s.%s.%s' "$head" "$payload" \
    "$(printf '%s.%s' "$head" "$payload" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | b64url)"
}
staff_jwt() {
  local now
  now=$(date +%s)
  sign_hs256 "{\"sub\":\"$1\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"aal\":\"aal1\",\"iat\":$now,\"exp\":$((now + ${2:-1800}))}"
}

olt_social_token() {
  curl -sS -X POST "$OLT/api/dev/token" -H 'Content-Type: application/json' \
    -d "{\"user\":\"$1\",\"kind\":\"social\"}" | jq -r '.token // empty'
}
customer_jwt() {
  local base="$1" user="$2" ip="${3:-}" social
  social=$(olt_social_token "$user")
  [ -n "$social" ] || return 1
  curl -sS -X POST "$base/bridge/v1/exchange" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    ${ip:+-H "X-Forwarded-For: $ip"} -d "{\"token\":\"$social\"}" | jq -r '.access_token // empty'
}

now_ms() { date +%s%3N; }
stamp() { date -u +%Y%m%d-%H%M%S; }
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

wait_healthy() {
  local name deadline status
  name=$(container "$1")
  deadline=$(( $(date +%s) + ${2:-180} ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$name" 2>/dev/null)
    [ "$status" = healthy ] && return 0
    sleep 1
  done
  return 1
}
