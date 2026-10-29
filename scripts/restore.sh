#!/usr/bin/env bash
# Restore database dari file backup (hasil backup.sh).
#   restore <nama-file.dump>      (file di folder backups/)
# MENIMPA data yang ada. Hentikan service lain dulu agar tidak ada koneksi aktif:
#   docker compose -f docker/docker-compose.yml stop
#   docker compose -f docker/docker-compose.yml start db
# Lihat README bagian "Backup & restore".
set -euo pipefail

name="${1:-}"
if [ -z "$name" ]; then
  echo "restore: sebutkan file, mis. restore olt-20261029-020000.dump" >&2
  ls -1 /olt/backups/*.dump 2>/dev/null | xargs -r -n1 basename >&2
  exit 2
fi
file="/olt/backups/$(basename "$name")"
if [ ! -f "$file" ]; then
  echo "restore: $file tidak ditemukan" >&2
  exit 1
fi
if [ "${CONFIRM:-}" != "yes" ]; then
  echo "restore: ini akan MENIMPA database. Jalankan ulang dengan CONFIRM=yes." >&2
  exit 1
fi

echo "restore: memulihkan $(basename "$file")"
PGUSER=supabase_admin pg_restore --no-password --clean --if-exists -d "${PGDATABASE:-postgres}" "$file"
echo "restore: selesai. Jalankan 'make up' untuk menyalakan semua service."
