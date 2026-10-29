# Panduan Produksi

Panduan ini menjelaskan cara menjalankan OLT Social di VPS Ubuntu dengan profil **`single`** (produksi 1 server): deploy, rahasia, backup, update, moderasi, dan checklist sebelum rilis. Pindah ke banyak node: [scaling.md](scaling.md).

## 1. Arsitektur produksi

```
Internet ──80──▶ Traefik ── redirect ke HTTPS
Internet ──443─▶ Traefik (TLS Let's Encrypt, TLS ≥ 1.2, rate limit per IP,
                 │        batas body & koneksi WebSocket, security headers)
                 │ hanya path API: /rest/v1 /realtime/v1 /storage/v1
                 │ /functions/v1 /bridge/v1      (lainnya 404, termasuk /auth/v1 & Studio)
                 ▼
               Kong ──▶ PostgREST, Storage, Edge Functions ──▶ PgBouncer ──▶ Postgres 17
                 │      Realtime ─────────────────────────────────────────▶ Postgres
                 │      auth-bridge ──▶ WebSocket OLT        Valkey (rate limit, cache)
 127.0.0.1:8000 ─┘ entrypoint admin: Studio & semua path (SSH tunnel / WireGuard)
```

- Network dipisah: `edge` (Traefik ↔ Kong), `app`, dan `data` (Postgres, PgBouncer, Valkey). Ketiganya tanpa akses internet; hanya Traefik, auth-bridge, dan Edge Functions yang tersambung ke network `egress`.
- Semua container read-only, non-root (kecuali entrypoint Postgres), `cap_drop: ALL`, `no-new-privileges`, dan punya batas CPU/memori/pids.
- Rahasia hanya dari Docker secrets di `docker/secrets/`.

## 2. Deploy pertama

```bash
# 1. Server: Docker Engine + compose plugin, firewall hanya SSH/80/443
sudo apt-get update && sudo apt-get install -y make git
curl -fsSL https://get.docker.com | sh
sudo ufw allow OpenSSH && sudo ufw allow 80/tcp && sudo ufw allow 443 && sudo ufw enable

# 2. Kode & rahasia
git clone <repo> olt-social && cd olt-social
make gen-secrets                 # docker/secrets/ (rahasia acak) + docker/.env
```

Edit `docker/.env` (tidak berisi rahasia):

```dotenv
PROXY_DOMAIN=social-api.domain.com
ACME_EMAIL=ops@domain.com
SUPABASE_PUBLIC_URL=https://social-api.domain.com
API_EXTERNAL_URL=https://social-api.domain.com/auth/v1
OLT_WS_URL=wss://<server-olt>/<path>
# OLT_WS_* lain: sesuaikan dengan format login OLT (services/auth-bridge/README.md)
```

```bash
# 3. Jalankan (Traefik otomatis meminta sertifikat; DNS A-record harus sudah mengarah ke VPS)
make up PROFILE=single
make seed PROFILE=single   # OPSIONAL: hanya untuk staging. Di produksi isi stocks lewat sync_stocks.
make anon-key              # ANON_KEY untuk build app OLT
```

Catatan:
- **Uji sertifikat dulu.** Uji dengan `ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory` agar tidak kena rate limit Let's Encrypt. Setelah berhasil, hapus baris itu, lalu hapus volume `olt-social_traefik-acme`.
- **Mode mock tidak bisa dipakai.** Profil single selalu menjalankan auth-bridge dengan `APP_ENV=production`, dan auth-bridge menolak start bila `AUTH_BRIDGE_OLT_MODE=mock`. Default profil single adalah `websocket`.
- **Rahasia ada di `docker/secrets/`.** Folder ini harus `chmod 700` dan dimiliki deployer. Isinya tidak pernah masuk `.env`, image, atau `docker inspect`.
- **Membuka Studio** (default mati):
  1. Nyalakan Studio: `make admin-up PROFILE=single`.
  2. Buat SSH tunnel: `ssh -L 8000:127.0.0.1:8000 user@vps`.
  3. Buka `http://localhost:8000` di browser.
  4. Login dengan `DASHBOARD_USERNAME` dan password di `docker/secrets/dashboard_password`.
  5. Setelah selesai: `make admin-down PROFILE=single`.
- **Sinkronisasi daftar saham dari sistem OLT.** Ini memakai service key, jadi hanya dijalankan dari server lewat port admin:

  ```bash
  SERVICE_ROLE_KEY=$(cat docker/secrets/service_role_key)
  curl -X POST http://127.0.0.1:8000/rest/v1/rpc/sync_stocks \
    -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H 'Content-Type: application/json' \
    -d '{"p_stocks":[{"code":"BBCA","name":"Bank Central Asia Tbk","sector":"Financials"}]}'
  ```

## 3. Backup & restore

> Tahap 6 menggantinya dengan WAL-G (point-in-time recovery) + restic terenkripsi di luar server. Lihat [production-audit.md](production-audit.md).

`make backup` melakukan dua hal:
- **Database:** `pg_dump` format custom ke `backups/olt-<UTC>.dump`. Arsip diverifikasi bisa dibaca dengan `pg_restore --list`. Dump lebih tua dari `BACKUP_KEEP_DAYS` (default 14 hari) dihapus otomatis.
- **File storage:** avatar dan lampiran diarsipkan ke `backups/storage-<UTC>.tar.gz`.

Jadwal harian (`crontab -e` di VPS):

```cron
0 2 * * * cd /home/ubuntu/olt-social && make backup PROFILE=single >> backups/backup.log 2>&1
30 2 * * * rclone sync /home/ubuntu/olt-social/backups remote:olt-social-backups   # salinan di luar VPS
```

Restore:

```bash
make down PROFILE=single
docker compose -f docker/compose.yml -f docker/compose.prod.yml up -d --wait db
make restore PROFILE=single FILE=olt-20261029-020000.dump CONFIRM=yes
# file storage (Storage berjalan sebagai uid 1000):
docker run --rm -v olt-social_storage-data:/data -v "$PWD/backups:/backup" alpine:3.22.7 \
  sh -c 'rm -rf /data/* && tar xzf /backup/storage-20261029-020000.tar.gz -C /data && chown -R 1000:1000 /data'
make up PROFILE=single
```

**Uji restore secara berkala**, minimal bulanan, di VPS staging.

## 4. Update versi

1. Baca `docker/versions.md` dan CHANGELOG di [supabase/supabase/docker](https://github.com/supabase/supabase/tree/master/docker).
2. Ubah image di `docker/compose.yml` dengan tag **dan** digest baru. Digest multi-arch didapat dengan `docker buildx imagetools inspect <image:tag>`. Jangan pernah memakai `latest`.
3. Uji di lokal atau staging:

   ```bash
   make reset CONFIRM=yes && make seed && make test && make smoke && make test-flutter-it
   ```

4. Di produksi, backup dulu, lalu:

   ```bash
   make backup PROFILE=single
   git pull
   make up PROFILE=single   # service `migrate` menjalankan migrasi baru secara otomatis
   ```

5. Upgrade major Postgres (misalnya 17 → 18) butuh `pg_upgrade` dan tidak tercakup langkah di atas.

**Aturan migrasi:**
- Tambahkan file migrasi baru dengan nomor berikutnya. **Jangan pernah mengedit file yang sudah jalan**; runner menolaknya lewat pengecekan checksum.
- Uji setiap perubahan skema dengan `make test-db`.

## 5. Moderasi

> Studio mati secara default di profil single. Nyalakan dengan `make admin-up PROFILE=single` dan akses lewat SSH tunnel (bagian 2). Tahap 2 menambahkan RPC dan UI moderator sehingga Studio tidak lagi dibutuhkan.

| Kebutuhan | Cara |
|---|---|
| Antrean laporan | Studio → SQL: `select * from private.report_queue;` (target paling sering dilaporkan di atas) |
| Hapus konten | `select delete_post('<id>');` / `delete_comment` / `delete_message`. Dijalankan sebagai service_role / Studio; isi asli diarsipkan di `private.content_archive` |
| Tutup laporan | `update reports set status = 'resolved', resolution_note = '...', resolved_at = now() where target_id = '<id>';` |
| Kata terlarang | `insert into banned_words (word, action) values ('kata', 'mask');`. `mask` mengganti kata dengan `***`, `block` menolak konten (HTTP 422). Hanya huruf kecil/angka/spasi |
| Ubah rate limit | `update private.rate_limits set max_count = 10 where action = 'post';`. Action: `post`, `comment`, `message`, `reaction`, `follow`, `report` |
| Akun resmi | `update profiles set is_verified = true where username = 'olt_official';` |

## 6. Rotasi kunci

> Prosedur lengkap dengan masa transisi akan ditulis di `docs/operations.md` (Tahap 6).

Mengganti `jwt_secret` akan **membatalkan `anon_key`, `service_role_key`, dan semua JWT user**:
1. Di staging, hapus file `docker/secrets/jwt_secret`, `anon_key`, dan `service_role_key`, lalu jalankan `make gen-secrets`. Ketiganya dibuat ulang dengan pasangan yang cocok.
2. Salin ketiga file itu ke `docker/secrets/` produksi. **Jangan** buat ulang `postgres_password` (`make gen-secrets FORCE=1` akan membuatnya ulang), karena itu butuh `ALTER ROLE` manual.
3. Jalankan `make up PROFILE=single`.
4. Rilis app OLT dengan `ANON_KEY` baru. `ANON_KEY` tertanam di app yang sudah terpasang, jadi siapkan masa transisi bila versi app lama masih dipakai.

## 7. Monitoring & log

> Prometheus, log terpusat, dan alert ditambahkan di Tahap 6.

- **Log:** `make logs PROFILE=single s=auth-bridge`.
  - Log Traefik (akses) dan auth-bridge berupa JSON. Log auth-bridge memuat `request_id`, `user_id`, `status`, dan `duration_ms`.
  - Header, token, dan password tidak pernah ditulis ke log.
- **Rotasi log:** semua container memakai rotasi json-file 10 MB × 5 file.
- **Health:** `make ps PROFILE=single`. Semua service punya healthcheck; service `migrate` dan `volume-init` harus `Exited (0)`.
- **Yang perlu dipantau:**
  - disk (volume `db-data`, `storage-data`, folder `backups/`)
  - koneksi Postgres (PgBouncer membatasi maks 80 koneksi server)
  - error 5xx dan 429 di log Traefik/Kong
  - error `olt_unavailable` di auth-bridge (server OLT bermasalah)

## 8. Checklist sebelum rilis

> Tahap 6 memindahkan checklist ini ke `docs/production-checklist.md` dan melengkapinya sesuai addendum.

**Keamanan**
- [ ] `docker/secrets/` berisi rahasia hasil `make gen-secrets`, tidak di-commit, dan folder hanya bisa dibuka deployer (`chmod 700`).
- [ ] `docker/.env` tidak berisi rahasia; `PROXY_DOMAIN` dan `ACME_EMAIL` terisi.
- [ ] `OLT_WS_URL` mengarah ke server OLT asli, sudah diuji dengan token OLT asli.
- [ ] OLT dummy tidak berjalan (`docker ps` tidak menampilkan `dummy-olt`).
- [ ] `https://domain/` dan `https://domain/auth/v1/health` mengembalikan 404. `http://domain/` di-redirect ke HTTPS.
- [ ] Studio mati (`make admin-down PROFILE=single`), dan port admin hanya terikat ke `127.0.0.1`.
- [ ] Firewall hanya membuka 22/80/443. Akses SSH memakai key, tanpa password.
- [ ] `SERVICE_ROLE_KEY` tidak ada di app Flutter. App hanya memakai `ANON_KEY`.
- [ ] `make test-db` lulus. Tes ini antara lain memeriksa RLS aktif di semua tabel, anon tanpa akses, dan `olt_user_id` tidak terbaca.

**Data & operasional**
- [ ] Cron backup aktif, salinan offsite tersedia, restore sudah diuji.
- [ ] Daftar saham tersinkron (`sync_stocks`). Daftar kata terlarang dan rate limit sudah ditinjau tim compliance.
- [ ] Prosedur moderasi (bagian 5) sudah disosialisasikan.
- [ ] DNS dan sertifikat HTTPS valid (Traefik memperbarui otomatis).

**Aplikasi**
- [ ] App OLT memakai URL HTTPS produksi. Build release Android tidak mengizinkan cleartext.
- [ ] `make license-audit` lulus (tanpa GPL/AGPL).
- [ ] `make e2e-windows` dan uji manual di Android lulus terhadap staging.
