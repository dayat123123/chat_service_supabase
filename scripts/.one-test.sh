set -u
export PGUSER=postgres
psql -X -q -U postgres -c "set client_min_messages=warning; create extension if not exists pgtap with schema extensions;" >/dev/null
psql -X -q -U postgres -c "set client_min_messages=warning;" -f /olt/supabase/tests/helpers/test_helpers.sql >/dev/null
pg_prove --ext .sql --failures --comments "$@"
s=$?
psql -X -q -U postgres -c "set client_min_messages=warning; drop schema if exists tests cascade;" >/dev/null
exit $s
