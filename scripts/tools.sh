#!/usr/bin/env bash
# Entrypoint service `tools` (lihat docker/compose.yml).
# Dipanggil oleh Makefile / make.ps1:  docker compose run --rm tools <perintah>
set -euo pipefail

SCRIPTS=/olt/scripts
cmd="${1:-help}"
shift || true

case "$cmd" in
  migrate)  bash "$SCRIPTS/migrate.sh" "$@" ;;
  seed)     bash "$SCRIPTS/seed.sh" "$@" ;;
  test-db)  bash "$SCRIPTS/test-db.sh" "$@" ;;
  gen-secrets) bash "$SCRIPTS/gen-secrets.sh" "$@" ;;
  smoke)    bash "$SCRIPTS/smoke-test.sh" "$@" ;;
  smoke-dummy) bash "$SCRIPTS/smoke-dummy-olt.sh" "$@" ;;
  backup)   bash "$SCRIPTS/backup.sh" "$@" ;;
  restore)  bash "$SCRIPTS/restore.sh" "$@" ;;
  psql)     exec psql -U postgres "$@" ;;
  *)
    echo "Perintah: migrate | seed | test-db | smoke | smoke-dummy | backup | restore <file> | gen-secrets [--force] | psql" >&2
    exit 2
    ;;
esac
