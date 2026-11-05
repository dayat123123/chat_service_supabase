#!/usr/bin/env bash
set -euo pipefail

SEED_FILE="${SEED_FILE:-/olt/supabase/seed/seed.sql}"

echo "seed: running $SEED_FILE"
psql -X -q -v ON_ERROR_STOP=1 --no-password -U postgres --single-transaction -f "$SEED_FILE"
echo "seed: done"
