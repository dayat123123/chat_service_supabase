#!/usr/bin/env bash
# Backup database ke backups/olt-<UTC>.dump (pg_dump format custom).
# - Dump seluruh database sebagai supabase_admin (lengkap: auth, storage, public, private).
# - Arsip diverifikasi bisa dibaca (pg_restore --list).
# - Backup lebih tua dari BACKUP_KEEP_DAYS (default 14) dihapus.
# File gambar storage dibackup terpisah oleh target `backup` di Makefile/make.ps1.
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

find "$DIR" -name 'olt-*.dump' -type f -mtime +"$KEEP_DAYS" -print -delete | sed 's/^/backup: hapus lama /'
echo "backup: selesai ($(du -h "$FILE" | cut -f1))"
