#!/bin/sh
# Entrypoint pembungkus untuk semua service yang punya shell, di semua profil.
#
# Nilai environment boleh berisi placeholder {{secret:NAMA}}. Sebelum perintah
# asli image dijalankan, placeholder diganti dengan isi /run/secrets/NAMA
# (Docker secrets: file di compose, secret Swarm di cluster). Dengan begitu
# rahasia tidak pernah tertulis di file compose, `.env`, atau `docker inspect`.
#
#   GOTRUE_DB_DATABASE_URL: "postgres://user:{{secret:postgres_password}}@pgbouncer:6432/postgres"
#   entrypoint: ["/bin/sh", "/opt/olt/with-secrets.sh", <entrypoint asli image>]
#
# Service gagal start dengan pesan jelas bila secret yang dibutuhkan tidak ada.
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
      echo "with-secrets: secret '$secret' (untuk $name) tidak ditemukan di $file." >&2
      echo "with-secrets: jalankan 'make gen-secrets' (Windows: .\\make.ps1 gen-secrets)." >&2
      exit 1
    fi
    result="$result$prefix$(cat "$file")"
  done
  export "$name=$result$value"
done

exec "$@"
