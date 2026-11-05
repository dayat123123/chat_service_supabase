#!/usr/bin/env bash
set -uo pipefail

suite="${1:-help}"
shift || true
case "$suite" in
  security)      exec bash /olt/tests/security/run-security.sh "$@" ;;
  authz)         exec bash /olt/tests/security/authz-probe.sh "$@" ;;
  static-config) exec bash /olt/tests/security/static-config.sh "$@" ;;
  prod-routing)  exec bash /olt/tests/security/prod-routing.sh "$@" ;;
  zap)           exec bash /olt/tests/security/zap-baseline.sh "$@" ;;
  load)          exec bash /olt/tests/load/run-load.sh "$@" ;;
  chaos)         exec bash /olt/tests/chaos/chaos.sh "$@" ;;
  integration)   exec bash /olt/tests/load/integration.sh "$@" ;;
  cleanup)       exec bash /olt/tests/load/cleanup.sh "$@" ;;
  shell)         exec bash "$@" ;;
  *)
    echo "usage: security | authz | static-config | prod-routing | zap | load [profile] | integration | chaos [experiment...] | cleanup" >&2
    exit 2
    ;;
esac
