#!/usr/bin/env bash
# Dumps as supabase_admin so auth, storage and private schemas are included. Storage files are
# archived separately by the `backup` target in Makefile/make.ps1.
set -euo pipefail

DIR=/olt/backups
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
FILE="$DIR/olt-$STAMP.dump"

mkdir -p "$DIR"
echo "backup: dump database -> backups/$(basename "$FILE")"
PGUSER=supabase_admin pg_dump -Fc --no-password -f "$FILE.partial"
PGUSER=supabase_admin pg_restore --list "$FILE.partial" > /dev/null
mv "$FILE.partial" "$FILE"

find "$DIR" -name 'olt-*.dump' -type f -mtime +"$KEEP_DAYS" -print -delete | sed 's/^/backup: removed old /'
echo "backup: done ($(du -h "$FILE" | cut -f1))"
