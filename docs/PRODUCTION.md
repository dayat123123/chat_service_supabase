# Panduan Produksi

Panduan ini menjelaskan cara menjalankan OLT Social di VPS Ubuntu: deploy, keamanan, backup, update, moderasi, dan checklist sebelum rilis.

## 1. Arsitektur produksi

```
Internet ──443──▶ Caddy (TLS Let's Encrypt)
                   │ hanya path API: /auth/v1 /rest/v1 /realtime/v1 /storage/v1
                   │ /functions/v1 /graphql/v1 /bridge/v1   (lainnya 404)
                   ▼
                 Kong 127.0.0.1:8000 ──▶ PostgREST, Realtime, Storage, GoTrue,
                   ▲                      Edge Functions, auth-bridge ──▶ WebSocket OLT
       SSH tunnel ─┘ (Studio, hanya admin)          │
                                                  Postgres 17 (tanpa port publik,
                                                  network internal tanpa internet)
```

## 2. Deploy pertama

```bash
# 1. Server: Docker Engine + compose plugin, firewall hanya SSH/80/443
sudo apt-get update && sudo apt-get install -y make git
curl -fsSL https://get.docker.com | sh
sudo ufw allow OpenSSH && sudo ufw allow 80/tcp && sudo ufw allow 443 && sudo ufw enable

# 2. Kode & rahasia
git clone <repo> olt-social && cd olt-social
make gen-keys                     # membuat docker/.env dengan rahasia acak
```

Edit `docker/.env`:

```dotenv
PROXY_DOMAIN=social-api.domain.com
SUPABASE_PUBLIC_URL=https://social-api.domain.com
API_EXTERNAL_URL=https://social-api.domain.com/auth/v1
APP_ENV=production
AUTH_BRIDGE_OLT_MODE=websocket
OLT_WS_URL=wss://<server-olt>/<path>
# OLT_WS_* lain: sesuaikan dengan format login OLT (services/auth-bridge/README.md)
```

```bash
# 3. Jalankan (Caddy otomatis meminta sertifikat; DNS A-record harus sudah mengarah ke VPS)
make up PROD=1
make seed            # OPSIONAL: hanya untuk staging. Di produksi isi stocks lewat sync_stocks.
```

Catatan:
- **Mode mock tidak bisa dipakai di produksi.** Dengan `APP_ENV=production`, auth-bridge menolak start bila `AUTH_BRIDGE_OLT_MODE=mock`.
- **Membuka Studio:**
  1. Buat SSH tunnel: `ssh -L 8000:127.0.0.1:8000 user@vps`.
  2. Buka `http://localhost:8000` di browser.
  3. Login memakai `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD`.
- **Sinkronisasi daftar saham dari sistem OLT** (pakai `SERVICE_ROLE_KEY`, hanya dari server):

  ```bash
  curl -X POST https://social-api.domain.com/rest/v1/rpc/sync_stocks \
    -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H 'Content-Type: application/json' \
    -d '{"p_stocks":[{"code":"BBCA","name":"Bank Central Asia Tbk","sector":"Financials"}]}'
  ```

## 3. Backup & restore

`make backup` melakukan dua hal:
- **Database:** `pg_dump` format custom ke `backups/olt-<UTC>.dump`. Arsip diverifikasi bisa dibaca dengan `pg_restore --list`. Dump lebih tua dari `BACKUP_KEEP_DAYS` (default 14 hari) dihapus otomatis.
- **File storage:** avatar dan lampiran diarsipkan ke `backups/storage-<UTC>.tar.gz`.

Jadwal harian (`crontab -e` di VPS):

```cron
0 2 * * * cd /home/ubuntu/olt-social && make backup >> backups/backup.log 2>&1
30 2 * * * rclone sync /home/ubuntu/olt-social/backups remote:olt-social-backups   # salinan di luar VPS
```

Restore:

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml stop
docker compose -f docker/docker-compose.yml start db
make restore FILE=olt-20261029-020000.dump CONFIRM=yes
# file storage:
docker run --rm -v olt-social_storage-data:/data -v "$PWD/backups:/backup" alpine:3.22.7 \
  sh -c 'rm -rf /data/* && tar xzf /backup/storage-20261029-020000.tar.gz -C /data'
make up PROD=1
```

**Uji restore secara berkala**, minimal bulanan, di VPS staging.

## 4. Update versi

1. Baca `docker/versions.md` dan CHANGELOG di [supabase/supabase/docker](https://github.com/supabase/supabase/tree/master/docker).
2. Ubah tag image di `docker/docker-compose.yml`. Tag harus selalu di-pin; jangan pernah memakai `latest`.
3. Uji di lokal atau staging:

   ```bash
   make reset && make seed && make test && make smoke && make test-flutter-it
   ```

4. Di produksi, backup dulu, lalu:

   ```bash
   make backup
   git pull
   docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml pull
   make up PROD=1        # service `migrate` menjalankan migrasi baru secara otomatis
   ```

5. Upgrade major Postgres (misalnya 17 → 18) butuh `pg_upgrade` dan tidak tercakup langkah di atas.

**Aturan migrasi:**
- Tambahkan file migrasi baru dengan nomor berikutnya. **Jangan pernah mengedit file yang sudah jalan**; runner menolaknya lewat pengecekan checksum.
- Uji setiap perubahan skema dengan `make test-db`.

## 5. Moderasi

| Kebutuhan | Cara |
|---|---|
| Antrean laporan | Studio → SQL: `select * from private.report_queue;` (target paling sering dilaporkan di atas) |
| Hapus konten | `select delete_post('<id>');` / `delete_comment` / `delete_message`. Dijalankan sebagai service_role / Studio; isi asli diarsipkan di `private.content_archive` |
| Tutup laporan | `update reports set status = 'resolved', resolution_note = '...', resolved_at = now() where target_id = '<id>';` |
| Kata terlarang | `insert into banned_words (word, action) values ('kata', 'mask');`. `mask` mengganti kata dengan `***`, `block` menolak konten (HTTP 422). Hanya huruf kecil/angka/spasi |
| Ubah rate limit | `update private.rate_limits set max_count = 10 where action = 'post';`. Action: `post`, `comment`, `message`, `reaction`, `follow`, `report` |
| Akun resmi | `update profiles set is_verified = true where username = 'olt_official';` |

## 6. Rotasi kunci

Mengganti `JWT_SECRET` akan **membatalkan `ANON_KEY`, `SERVICE_ROLE_KEY`, dan semua JWT user**:
1. Jalankan `make gen-keys FORCE=1` di staging untuk mendapat nilai baru, atau buat manual dengan `scripts/gen-keys.sh`.
2. Perbarui `JWT_SECRET`, `ANON_KEY`, dan `SERVICE_ROLE_KEY` di `docker/.env` produksi. **Jangan** ubah `POSTGRES_PASSWORD`, karena itu butuh `ALTER ROLE` manual.
3. Jalankan `make up PROD=1`.
4. Rilis app OLT dengan `ANON_KEY` baru. Siapkan masa transisi bila versi app lama masih dipakai.

## 7. Monitoring & log

- **Log:** `make logs s=auth-bridge`. Log auth-bridge berupa JSON (`request_id`, `user_id`, `status`, `duration_ms`). Token dan password tidak pernah ditulis ke log.
- **Rotasi log:** semua container memakai rotasi json-file 10 MB × 5 file.
- **Health:** `docker compose ps`. Semua service punya healthcheck; service `migrate` harus `Exited (0)`.
- **Yang perlu dipantau:**
  - disk (volume `db-data`, `storage-data`, folder `backups/`)
  - koneksi Postgres
  - error 5xx dan 429 di log Kong
  - error `olt_unavailable` di auth-bridge (server OLT bermasalah)

## 8. Checklist sebelum rilis

**Keamanan**
- [ ] `docker/.env` berisi rahasia hasil `make gen-keys`, tidak di-commit, dan hanya bisa dibaca root/deployer (`chmod 600`).
- [ ] `APP_ENV=production` dan `AUTH_BRIDGE_OLT_MODE=websocket`, sudah diuji dengan token OLT asli.
- [ ] `make up PROD=1`: Kong hanya di `127.0.0.1`, Studio tidak bisa diakses dari internet (cek bahwa `https://domain/` mengembalikan 404).
- [ ] Firewall hanya membuka 22/80/443. Akses SSH memakai key, tanpa password.
- [ ] `SERVICE_ROLE_KEY` tidak ada di app Flutter. App hanya memakai `ANON_KEY`.
- [ ] Signup GoTrue tetap mati (`DISABLE_SIGNUP=true`, `ENABLE_EMAIL_SIGNUP=false`).
- [ ] `make test-db` lulus. Tes ini antara lain memeriksa RLS aktif di semua tabel, anon tanpa akses, dan `olt_user_id` tidak terbaca.

**Data & operasional**
- [ ] Cron backup aktif, salinan offsite tersedia, restore sudah diuji.
- [ ] Daftar saham tersinkron (`sync_stocks`). Daftar kata terlarang dan rate limit sudah ditinjau tim compliance.
- [ ] Prosedur moderasi (bagian 5) sudah disosialisasikan.
- [ ] DNS dan sertifikat HTTPS valid (Caddy otomatis memperbarui).

**Aplikasi**
- [ ] App OLT memakai URL HTTPS produksi. Build release Android tidak mengizinkan cleartext.
- [ ] `make license-audit` lulus (tanpa GPL/AGPL).
- [ ] `make e2e-windows` dan uji manual di Android lulus terhadap staging.
