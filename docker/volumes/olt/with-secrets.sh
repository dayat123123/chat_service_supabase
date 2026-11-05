#!/bin/sh
# Wrapper entrypoint: replaces {{secret:NAME}} placeholders in environment values with the
# contents of /run/secrets/NAME before exec'ing the image's original entrypoint, so secrets never
# appear in compose files, .env, or `docker inspect`. Usage:
#
#   GOTRUE_DB_DATABASE_URL: "postgres://user:{{secret:postgres_password}}@pgbouncer:6432/postgres"
#   entrypoint: ["/bin/sh", "/opt/olt/with-secrets.sh", <original image entrypoint>]
set -eu

secrets_dir="${OLT_SECRETS_DIR:-/run/secrets}"

for name in $(env | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*{{secret:[a-z0-9_]*}}.*$/\1/p'); do
  eval "value=\${$name}"
  result=''
  while :; do
    case $value in
      *'{{secret:'*'}}'*) ;;
      *) break ;;
    esac
    prefix=${value%%'{{secret:'*}
    rest=${value#*'{{secret:'}
    secret=${rest%%'}}'*}
    value=${rest#*'}}'}
    file="$secrets_dir/$secret"
    if [ ! -r "$file" ]; then
      echo "with-secrets: secret '$secret' (for $name) not found at $file." >&2
      echo "with-secrets: run 'make gen-secrets' (Windows: .\\make.ps1 gen-secrets)." >&2
      exit 1
    fi
    result="$result$prefix$(cat "$file")"
  done
  export "$name=$result$value"
done

exec "$@"
