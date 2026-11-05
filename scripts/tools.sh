#!/usr/bin/env bash
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
  smoke-cs) bash "$SCRIPTS/smoke-cs.sh" "$@" ;;
  cs-demo-config) bash "$SCRIPTS/cs-demo-setup.sh" "$@" ;;
  cs-race)  bash "$SCRIPTS/cs-claim-race.sh" "$@" ;;
  cs-staff) bash "$SCRIPTS/cs-staff-setup.sh" "$@" ;;
  cs-bootstrap-admin) bash "$SCRIPTS/cs-bootstrap-admin.sh" "$@" ;;
  backup)   bash "$SCRIPTS/backup.sh" "$@" ;;
  restore)  bash "$SCRIPTS/restore.sh" "$@" ;;
  psql)     exec psql -U postgres "$@" ;;
  *)
    echo "Commands: migrate | seed | test-db | smoke | smoke-dummy | smoke-cs | cs-race [replica-url...] | cs-staff | cs-bootstrap-admin <email> <name> [--force] | cs-demo-config | backup | restore <file> | gen-secrets [--force] | psql" >&2
    exit 2
    ;;
esac
