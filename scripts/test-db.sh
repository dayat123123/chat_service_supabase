#!/usr/bin/env bash
# Every test file wraps itself in begin; ... rollback; so the database is left unchanged.
set -uo pipefail

TESTS_DIR="${TESTS_DIR:-/olt/supabase/tests}"
export PGUSER=postgres

psql_q() {
  psql -X -q -v ON_ERROR_STOP=1 --no-password "$@"
}

shopt -s nullglob
files=("$TESTS_DIR"/*.sql)
if [ ${#files[@]} -eq 0 ]; then
  echo "test-db: no test files in $TESTS_DIR"
  exit 0
fi

psql_q -c "set client_min_messages = warning; create extension if not exists pgtap with schema extensions;" || exit 1
psql_q -c "set client_min_messages = warning;" -f "$TESTS_DIR/helpers/test_helpers.sql" || exit 1

pg_prove --ext .sql --failures --comments "${files[@]}"
status=$?

psql_q -c "set client_min_messages = warning; drop schema if exists tests cascade;"
exit $status
