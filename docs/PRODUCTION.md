# Panduan Produksi

Panduan ini menjelaskan cara menjalankan OLT Social di VPS Ubuntu dengan profil **`single`** (produksi 1 server): deploy, rahasia, backup, update, moderasi, dan checklist sebelum rilis. Pindah ke banyak node: [scaling.md](scaling.md).

## 1. Arsitektur produksi

```
Internet ──80──▶ Traefik ── redirect ke HTTPS
Internet ──443─▶ Traefik (TLS Let's Encrypt, TLS ≥ 1.2, rate limit per IP,
                 │        batas body & koneksi WebSocket, security headers)
                 │ hanya path API: /rest/v1 /realtime/v1 /storage/v1 /media/v1 /integration/v1
                 │ /functions/v1 /bridge/v1      (lainnya 404, termasuk /auth/v1 & Studio)
                 ▼
               Kong ──▶ PostgREST, Storage, Edge Functions ──▶ PgBouncer ──▶ Postgres 17
                 │      Realtime ─────────────────────────────────────────▶ Postgres
                 │      auth-bridge (verifikasi token sosial OLT lokal, JWKS)   Valkey (rate limit, cache)
                 │      media (cek isi file, buang EXIF/GPS) ──▶ classifier (NSFW) ──▶ Storage
                 │      integration (notifEngine & bot OLT, API key) ──▶ antrean push
 127.0.0.1:8000 ─┘ entrypoint admin: Studio & semua path (SSH tunnel / WireGuard)

Latar belakang: notifier (push FCM), janitor (bersihkan file), sentinel (pantau + alert),
link-preview (pratinjau link, aman SSRF), backup (WAL + backup penuh ──restic──▶ S3 di luar server)
```

- Network dipisah: `edge` (Traefik ↔ Kong), `app`, dan `data` (Postgres, PgBouncer, Valkey). Ketiganya tanpa akses internet. Yang tersambung ke network `egress` hanya Traefik, Edge Functions, notifier (push ke Google FCM), sentinel (alert ke Telegram/SMTP), link-preview (mengambil halaman untuk pratinjau link), dan backup (S3). auth-bridge tidak memanggil OLT, jadi tidak butuh akses keluar.
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
# auth-bridge mode jwt (default): tidak ada alamat OLT yang perlu diisi.
# OLT_JWT_ISSUER / OLT_JWT_AUDIENCE hanya diubah bila OLT memakai nilai lain (docs/olt-integration.md).
```

```bash
# 3. Jalankan (Traefik otomatis meminta sertifikat; DNS A-record harus sudah mengarah ke VPS)
make up PROFILE=single
make seed PROFILE=single   # OPSIONAL: data contoh, hanya untuk staging
make anon-key              # ANON_KEY untuk build app OLT
```

Catatan:
- **Uji sertifikat dulu.** Uji dengan `ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory` agar tidak kena rate limit Let's Encrypt. Setelah berhasil, hapus baris itu, lalu hapus volume `olt-social_traefik-acme`.
- **Mode mock tidak bisa dipakai.** Profil single selalu menjalankan auth-bridge dengan `APP_ENV=production`, dan auth-bridge menolak start bila `AUTH_BRIDGE_OLT_MODE=mock`. Default profil single adalah `jwt`.
- **Ganti kunci publik OLT.** Sebelum `make up`, timpa `docker/secrets/olt_jwks` dengan JWKS dari tim OLT (bagian 2 [olt-integration.md](olt-integration.md)). `make gen-secrets` tidak pernah menimpa JWKS produksi. Kunci dev (`kid` berawalan `dev-`) ditolak di produksi, jadi auth-bridge tidak mau start bila file ini lupa diganti.
- **Rahasia ada di `docker/secrets/`.** Folder ini harus `chmod 700` dan dimiliki deployer. Isinya tidak pernah masuk `.env`, image, atau `docker inspect`.
- **Membuka Studio** (default mati):
  1. Nyalakan Studio: `make admin-up PROFILE=single`.
  2. Buat SSH tunnel: `ssh -L 8000:127.0.0.1:8000 user@vps`.
  3. Buka `http://localhost:8000` di browser.
  4. Login dengan `DASHBOARD_USERNAME` dan password di `docker/secrets/dashboard_password`.
  5. Setelah selesai: `make admin-down PROFILE=single`.
- **Customer service lewat chat.** Chat CS nasabah memakai schema `cs_api` lewat `/rest/v1` dan Realtime (sudah ada di `PGRST_DB_SCHEMAS` default), jadi tidak butuh service tambahan. Server tidak mengambil data nasabah dari OLT; agen membuka back-office OLT bila butuh data akun ([olt-integration.md](olt-integration.md)). Detail: [docs/cs-chat](cs-chat/README.md).
- **Web CS React** ([`apps/cs-console-react`](../apps/cs-console-react/README.md)) mati secara default di profil single. Nyalakan dengan `make up PROFILE=single CS=1` (Windows: `-Cs`), yang memakai overlay `docker/compose.cs.yml`. Isi di `docker/.env`:
  1. `CS_CONSOLE_DOMAIN`: domain khusus web CS. Web CS dan API agen (`/auth/v1`, `/functions/v1`, `/rest/v1`, `/realtime/v1`, `/storage/v1`) disajikan di domain ini, jadi tidak perlu CORS.
  2. `VPN_SOURCE_RANGES`: rentang IP yang boleh membuka web CS, dipisah koma. Semua router domain ini (`docker/volumes/traefik/cs.yml`) memakai `ipAllowList`; IP lain mendapat 403. VPN **tidak wajib**: isi dengan jaringan kantor, tanpa mengubah kode.
     - Server di jaringan kantor: isi rentang LAN, mis. `192.168.1.0/24`. Arahkan domain CS ke IP LAN server lewat DNS internal (atau file hosts). Bila PC staf membuka IP publik server dari dalam kantor (hairpin NAT), yang terlihat adalah IP router, jadi tambahkan IP itu.
     - Server di cloud: isi IP publik kantor, mis. `203.0.113.10/32`.
     - Firewall saja tidak cukup. API nasabah (`PROXY_DOMAIN`) dan web CS sama-sama di port 443, dan firewall tidak bisa membedakan domain. Pembatasan per domain dilakukan `ipAllowList` ini. Firewall cukup membuka 22/80/443, dengan SSH hanya dari kantor.

  Sertifikat memakai Let's Encrypt HTTP-01 seperti `PROXY_DOMAIN`, jadi DNS publik domain ini harus mengarah ke server. IP di luar daftar tetap mendapat 403. Header keamanan dan CSP diatur nginx container `cs-console` berdasarkan `SUPABASE_URL`.
- **Menu Akun Nasabah (CS Admin service)** diatur dari web, tidak ada nilai di `docker/.env`:
  1. `make gen-secrets` sudah membuat kunci integrasi (`docker/secrets/csadmin_signing_key`).
  2. Login sebagai Super Admin, lalu buka **Pengaturan → Integrasi API Nasabah** (bertanda "Belum diatur"). Isi alamat dan client id.
  3. Salin blok `integration { … }` dari halaman yang sama ke config CS Admin service di server API Nasabah (nama file mengikuti kode broker), lalu restart service-nya. Sebaiknya tambahkan `allowed_ips = <IP server web CS>`.
  4. Klik **Simpan & aktifkan**. Gateway mengetes koneksi dulu dan hanya menyimpan bila berhasil. Setelah itu menu Akun Nasabah tampil untuk CS yang punya izin, paling lambat 1 menit, tanpa restart.

  Rinciannya ada di [docs/nasabah](nasabah/README.md#konfigurasi-gateway).
- **Menu Komunitas** (postingan resmi, pengumuman, notifikasi, moderasi) tidak butuh konfigurasi server. Super Admin memberi izin per staf di **Pengaturan → Akun CS** dan membuat akun resmi pertama di **Komunitas → Akun resmi** (butuh izin "Kelola akun resmi"). Foto akun resmi memakai `SUPABASE_PUBLIC_URL`, jadi isi dengan domain API publik. Rinciannya ada di [docs/community](community/README.md).
- **Push notification ke HP**: Super Admin mengunggah file kunci service account Firebase (`.json`) di web CS, **Pengaturan → Push notification → Kunci Firebase**. Kunci disimpan terenkripsi di Vault, notifier memuat dan memeriksanya ke Google dalam beberapa detik tanpa restart, lalu status menjadi Aktif. Sebelum itu semua notifikasi tetap masuk ke kotak notifikasi aplikasi. Panduan lengkap (APNs, rotasi kunci, restore, integrasi aplikasi): [docs/push](push/README.md).
- **Upload media nasabah**: aplikasi mengunggah foto dan PDF lewat `/media/v1`, bukan langsung ke Storage. Layanan `media` memeriksa isi file (bukan nama atau header), membuang EXIF/GPS, XMP, dan metadata teks tanpa menurunkan kualitas gambar, serta menolak PDF terenkripsi atau berisi JavaScript. Storage menolak upload nasabah yang tidak lewat layanan ini (migrasi `0063`). Staf di web CS tetap mengunggah langsung. Tidak perlu konfigurasi. Detail: [services/media](../services/media/README.md).
- **Dokumen hukum (S&K, Pedoman Komunitas, Kebijakan Privasi)** diterbitkan staf Kepatuhan dari web CS (**Kepatuhan → Dokumen hukum**) dengan persetujuan empat mata. Selama belum ada dokumen yang terbit, nasabah tidak diminta menyetujui apa pun. Detail: [kepatuhan.md](cs-chat/kepatuhan.md#dokumen-hukum).
- **Kesehatan sistem dan alert**: Super Admin membuka **Kesehatan sistem** di web CS untuk melihat status semua layanan, disk, database, antrean, dan backup. Isi kanal alert Telegram dan/atau email di tab **Alert**, lalu tekan **Kirim uji**. Detail: [docs/system-health](system-health/README.md).
- **Backup**: isi tujuan S3 dan password enkripsi di **Kesehatan sistem → Backup** segera setelah deploy. Sebelum itu muncul alert "Backup belum diatur". Simpan password enkripsi dan salinan `pgsodium_root.key` di luar server. Detail: [docs/backup](backup/README.md).
- **Moderasi gambar**: layanan `classifier` (model NSFW MobileNetV4, Apache-2.0, CPU) dipanggil `media` untuk setiap gambar nasabah sebelum disimpan. Gambar porno ditolak, gambar meragukan ditahan (hanya terlihat pengunggah dan moderator) dan masuk antrean **Komunitas → Moderasi → Gambar ditahan**. Bila `classifier` mati, upload gambar ditolak (fail closed) dan Kesehatan sistem memberi alert. Ambang diatur Kepatuhan (**Kepatuhan → Kebijakan konten → Ambang gambar**). Detail: [services/classifier](../services/classifier/README.md).
- **Keamanan konten & anti goreng saham**: filter kata ternormalisasi, domain/link, kontak dan frasa promosi, batasan akun baru, permintaan pesan DM, banding, deteksi manipulasi, dan slow mode room saham berjalan otomatis; kebijakannya diatur Kepatuhan dari web. Detail: [docs/content-safety.md](content-safety.md).
- **Kill switch & versi minimum**: Super Admin dapat mematikan fitur sosial seketika (wajib alasan; chat CS tetap jalan), membuka fitur bertahap lewat feature flag, dan mewajibkan update aplikasi di **Pengaturan → Fitur & versi**. Detail: [docs/social](social/README.md).
- **Gateway integrasi OLT** (`/integration/v1`, layanan `integration`): notifEngine OLT mengirim notifikasi transaksi per `cust_id`; server memetakan ke pemilik rekening dari klaim `accounts` di token sosial OLT. API key dibuat Super Admin di **Pengaturan → Integrasi OLT** (ditampilkan sekali). Batasi sumbernya dengan CIDR pada key. Spesifikasi untuk tim OLT: [docs/integration](integration/README.md).
- **Pratinjau link**: layanan `link-preview` (satu-satunya yang mengambil URL internet sembarang, dengan proteksi SSRF) membuat pratinjau link di postingan dan chat. Detail: [services/link-preview](../services/link-preview/README.md).
- **Pembersihan file storage**: layanan `janitor` menghapus file milik akun yang dihapus (avatar, lampiran postingan dan chat, dokumen CS) serta surat yang lewat masa simpan, dari antrean `private.storage_cleanup_queue`. Tidak perlu konfigurasi. Folder yang gagal dicoba ulang dengan jeda sampai 6 jam. Cek antrean: `select bucket_id, prefix, failures, error from private.storage_cleanup_queue where done_at is null;`. Detail: [services/janitor](../services/janitor/README.md).
- **Karantina bukti** (migrasi `0095`): konten yang dilaporkan atau dihapus moderator/sistem disimpan utuh (teks, konteks, sidik SHA-256) dan file-nya disalin `janitor` ke bucket privat `evidence` sebelum aslinya dibersihkan. Bukti append-only, disimpan 730 hari (`private.settings` kunci `retention.evidence_days`) kecuali Kepatuhan memasang legal hold, lalu dihapus job `evidence-purge`. Akses hanya Kepatuhan (dan Super Admin baca saja) di **Kepatuhan → Bukti**, setiap buka/periksa/ekspor tercatat. Hitung ukuran bucket `evidence` dalam kapasitas disk storage. Cek salinan yang tertahan: `select status, count(*) from private.evidence_files group by 1;`. Detail: [docs/evidence](evidence/README.md).

## 3. Backup & restore

Backup berkelanjutan dijalankan layanan `backup`, dan diatur Super Admin dari web CS (**Kesehatan sistem → Backup**). Prosesnya:
- WAL dialirkan terus lewat replikasi.
- Backup penuh harian dan file storage dibuat otomatis.
- Semuanya dikirim ke repositori restic terenkripsi di S3 di luar server.
- Uji restore berjalan otomatis setiap minggu.

Arsitektur, jadwal, retensi, alert, dan pemulihan ke titik waktu tertentu dijelaskan di [docs/backup](backup/README.md). Perintah teknisnya ada di [services/backup](../services/backup/README.md).

`make backup` tetap ada untuk salinan sesaat (`pg_dump` + arsip file storage ke `backups/`), misalnya sebelum upgrade besar:

```bash
make backup PROFILE=single
make down PROFILE=single
docker compose -f docker/compose.yml -f docker/compose.prod.yml up -d --wait db
make restore PROFILE=single FILE=olt-20261029-020000.dump CONFIRM=yes
make up PROFILE=single
```

Bucket `evidence` (karantina bukti) ikut backup file storage. Bukti yang sudah lewat masa simpan masih ada di backup lama sampai backup itu terpangkas (retensi bulanan 6 bulan); sampaikan ini ke tim legal bila menjawab permintaan penghapusan data.

Kunci enkripsi Vault (volume `db-config`) tidak ikut backup mana pun. Setelah memulihkan ke server baru, isi ulang kunci Firebase, tujuan backup, dan kanal alert dari web, atau pulihkan salinan `pgsodium_root.key` yang disimpan di luar server.

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

### 5.1 Lewat API admin

Moderasi dijalankan lewat fungsi di schema `admin_api`. Panel admin web (F1) memakai fungsi-fungsi ini.

**Login admin.**
- Admin memakai akun GoTrue terpisah, bukan akun OLT, dan wajib 2FA TOTP (klaim `aal2`).
- Peran disimpan di `private.admin_users`.

**Peran:**

| Peran | Boleh |
|---|---|
| `viewer` | Lihat antrean dan detail user, tanpa data pribadi |
| `room_moderator` | Tindak laporan pesan di room yang ditugaskan |
| `moderator` | Tindak semua laporan, beri sanksi, cabut sesi |
| `compliance_admin` | Semua hak moderator, ditambah kata terlarang, `trust_level`, verifikasi, dokumen S&K, menunjuk moderator, baca audit log, ubah pengaturan |
| `super_admin` | Semua hak di atas, ditambah menunjuk admin lain, arsip regulator, dan *legal hold* |

**Fungsi:**

| Kebutuhan | Fungsi |
|---|---|
| Antrean laporan (prioritas) | `admin_api.report_queue(p_status, p_limit)` |
| Tindak konten | `admin_api.resolve_target(type, id, 'remove' \| 'hide' \| 'approve' \| 'restore' \| 'dismiss', alasan)` |
| Sanksi bertingkat | `admin_api.sanction_user(user_id, alasan)`. Tanpa `p_kind`, tangga dipakai: peringatan → mute 1 jam → mute 24 jam → ban 7 hari → ban permanen |
| Cabut sanksi / sesi | `admin_api.revoke_sanction(id, alasan)` / `admin_api.revoke_user_sessions(user_id, alasan)` |
| Detail user | `admin_api.user_detail(user_id)`. Email hanya untuk compliance/super, dan setiap aksesnya dicatat |
| Kata terlarang | Web CS: **Kepatuhan → Kata terlarang** (tambah, ubah aksi, hapus, import/unduh Excel). Lewat API: `admin_api.upsert_banned_word(kata, 'mask' \| 'block')` / `admin_api.delete_banned_word(kata)` |
| Trust & verifikasi | `admin_api.set_trust_level(user_id, 0..3, alasan)` / `admin_api.set_verified(user_id, true, alasan)` |
| Syarat & Ketentuan | `admin_api.publish_legal_document('terms', judul, isi)`. User wajib menyetujui ulang versi baru |
| Pengaturan | `admin_api.update_setting(key, value)`. Contoh: `retention.archive_days`, `rate_limit.new_account_factor` |
| Arsip regulator | `admin_api.archive(...)` / `admin_api.set_legal_hold(id, true, alasan)` (super_admin) |
| Audit log | `admin_api.audit_log(limit)`: semua aksi admin tercatat dan tidak bisa diubah/dihapus |

### 5.2 Darurat lewat SQL (sebelum panel admin F1 siap)

Studio berjalan sebagai `postgres`, bukan akun admin `aal2`, sehingga tidak bisa memakai `admin_api`. Nyalakan Studio dengan `make admin-up PROFILE=single` (lihat bagian 2). Setiap tindakan darurat **wajib dicatat manual** di `private.admin_audit_log`.

| Kebutuhan | SQL |
|---|---|
| Sembunyikan konten | `update posts set moderation_status = 'hidden', moderated_at = now() where id = '<id>';` (juga `comments`, `messages`) |
| Mute / ban | `insert into private.user_sanctions (user_id, kind, reason, ends_at) values ('<user>', 'ban', '...', null);` |
| Cabut sesi | `select private.revoke_sessions('<user>', 'alasan');` |
| Ubah rate limit | `update private.rate_limits set max_count = 10 where action = 'post' and window_seconds = 60;` |

## 6. Rotasi kunci

> Prosedur lengkap dengan masa transisi akan ditulis di `docs/operations.md` (Tahap 6).

Mengganti `jwt_secret` akan **membatalkan `anon_key`, `service_role_key`, dan semua JWT user**:
1. Di staging, hapus file `docker/secrets/jwt_secret`, `anon_key`, dan `service_role_key`, lalu jalankan `make gen-secrets`. Ketiganya dibuat ulang dengan pasangan yang cocok.
2. Salin ketiga file itu ke `docker/secrets/` produksi. **Jangan** buat ulang `postgres_password` (`make gen-secrets FORCE=1` akan membuatnya ulang), karena itu butuh `ALTER ROLE` manual.
3. Jalankan `make up PROFILE=single`.
4. Rilis app OLT dengan `ANON_KEY` baru. `ANON_KEY` tertanam di app yang sudah terpasang, jadi siapkan masa transisi bila versi app lama masih dipakai.

## 7. Monitoring & log

- **Kesehatan sistem** (web CS, Super Admin): status layanan, probe, disk, database, antrean, cron, dan backup. Alert dikirim ke Telegram/email. Bila database mati, sentinel tetap mengirim alert "API/database tidak bisa dihubungi". Detail: [docs/system-health](system-health/README.md).
- **Pemantau dari luar server:** pasang Uptime Kuma atau layanan uptime lain di server berbeda untuk memeriksa `https://<PROXY_DOMAIN>/bridge/v1/health` (header `apikey`). Alert dari dalam server tidak bisa terkirim bila seluruh server mati.
- **Log:** `make logs PROFILE=single s=auth-bridge`.
  - Log Traefik (akses) dan auth-bridge berupa JSON. Log auth-bridge memuat `request_id`, `user_id`, `status`, dan `duration_ms`.
  - Header, token, dan password tidak pernah ditulis ke log.
- **Rotasi log:** semua container memakai rotasi json-file 10 MB × 5 file.
- **Health:** `make ps PROFILE=single`. Semua service punya healthcheck; service `migrate` dan `volume-init` harus `Exited (0)`.
- **auth-bridge (port ops internal 9100).** Port ini tidak dipublikasikan dan tidak lewat Kong; akses dari jaringan Docker:

  ```bash
  docker compose -f docker/compose.yml -f docker/compose.prod.yml run --rm --entrypoint sh tools \
    -c 'curl -s http://auth-bridge:9100/readyz; curl -s http://auth-bridge:9100/metrics | grep ^olt_'
  ```

  - `/readyz` bernilai `degraded` bila Valkey bermasalah (rate limit jatuh ke per-instance) atau circuit breaker OLT terbuka.
  - Metrik dan alert yang disarankan ada di [services/auth-bridge/README.md](../services/auth-bridge/README.md#port-ops-internal).
- **Yang perlu dipantau:**
  - disk (volume `db-data`, `storage-data`, folder `backups/`)
  - koneksi Postgres (PgBouncer membatasi maks 80 koneksi server)
  - error 5xx dan 429 di log Traefik/Kong
  - error `olt_unavailable` di auth-bridge (server OLT bermasalah), `olt_auth_bridge_olt_breaker_open = 1`, dan kenaikan `olt_auth_bridge_valkey_errors_total`

## 8. Checklist sebelum rilis

> Tahap 6 memindahkan checklist ini ke `docs/production-checklist.md` dan melengkapinya sesuai addendum.

**Keamanan**
- [ ] `docker/secrets/` berisi rahasia hasil `make gen-secrets`, tidak di-commit, dan folder hanya bisa dibuka deployer (`chmod 700`).
- [ ] `docker/.env` tidak berisi rahasia; `PROXY_DOMAIN` dan `ACME_EMAIL` terisi.
- [ ] `docker/secrets/olt_jwks` berisi JWKS dari OLT (bukan kunci dev), dan exchange sudah diuji dengan token sosial yang diterbitkan OLT asli.
- [ ] OLT dummy tidak berjalan (`docker ps` tidak menampilkan `dummy-olt`).
- [ ] `https://domain/` dan `https://domain/auth/v1/health` mengembalikan 404. `http://domain/` di-redirect ke HTTPS.
- [ ] Studio mati (`make admin-down PROFILE=single`), dan port admin hanya terikat ke `127.0.0.1`.
- [ ] Firewall hanya membuka 22/80/443. Akses SSH memakai key, tanpa password.
- [ ] `SERVICE_ROLE_KEY` tidak ada di app Flutter. App hanya memakai `ANON_KEY`.
- [ ] `make test-db` lulus. Tes ini antara lain memeriksa RLS aktif di semua tabel, anon tanpa akses, `olt_user_id` tidak terbaca, peran admin, dan audit log yang tidak bisa diubah.
- [ ] `retention.archive_days` (arsip regulator) sudah ditetapkan bersama tim legal. Default sementara: 5 tahun.

**Data & operasional**
- [ ] Tujuan backup S3 diatur di web (**Kesehatan sistem → Backup**), backup penuh pertama berhasil, dan uji restore berhasil. Password enkripsi dan salinan `pgsodium_root.key` disimpan di luar server.
- [ ] Kanal alert (Telegram dan/atau email) diisi, dan **Kirim uji** sudah diterima tim operasional. Pemantau uptime dari luar server sudah dipasang.
- [ ] Halaman **Kesehatan sistem** tidak menampilkan masalah kritis.
- [ ] Dokumen hukum (S&K, Pedoman Komunitas, Kebijakan Privasi) diterbitkan Kepatuhan dari web, dan jenis dokumen yang wajib disetujui sudah ditentukan.
- [ ] Daftar kata terlarang (web CS, Kepatuhan → Kata terlarang) dan rate limit sudah ditinjau tim compliance.
- [ ] Prosedur moderasi (bagian 5) sudah disosialisasikan.
- [ ] DNS dan sertifikat HTTPS valid (Traefik memperbarui otomatis).

**Customer service lewat chat (sebelum dibuka untuk nasabah; lihat [docs/cs-chat](cs-chat/README.md))**
- [ ] Revisi CS-2 (R1–R4) selesai. `make test-db`, `make cs-race`, dan `make smoke-cs` lulus di staging. `make cs-race` mencakup tes rebutan lewat beberapa replika API.
- [ ] Tim kepatuhan sudah menjawab [compliance-questions.md](cs-chat/compliance-questions.md), dan nilai di `cs.cs_settings` (tenggat pengaduan, retensi, jam layanan, pesan otomatis) sudah disesuaikan.
- [ ] Kalender libur tahun berjalan dan tahun depan sudah diperiksa kepatuhan (`cs.holidays.verified = true`), termasuk libur bursa dari pengumuman BEI.
- [ ] API agen (`cs_api.agent_*`) dan web CS (`apps/cs-console-react`, domain `CS_CONSOLE_DOMAIN`) hanya bisa diakses dari IP di `VPN_SOURCE_RANGES` (LAN kantor atau VPN): uji dari jaringan lain harus mendapat 403. Staf CS login dengan email + password (tanpa TOTP, jadi pembatasan jaringan dan password kuat minimal 12 karakter adalah lapisan utamanya), dan pendaftaran publik GoTrue tetap mati.
- [ ] `make test-cs-console` lulus dan E2E web CS (`make e2e-cs-console`) lulus di staging.
- [ ] Endpoint login GoTrue (`/auth/v1/token`, `/auth/v1/factors`, `/auth/v1/user`) hanya dari jaringan yang diizinkan. Nasabah tidak memakainya karena JWT nasabah diterbitkan auth-bridge.
- [ ] Edge Function `cs-admin` (`/functions/v1/cs-admin/*`, dipakai menu Pengaturan → Akun CS) hanya dari jaringan yang diizinkan. Kunci service role hanya ada sebagai secret container functions, tidak pernah di client.
- [ ] Super admin pertama dibuat sekali dari server:

  ```bash
  make cs-bootstrap-admin PROFILE=single EMAIL=nama@perusahaan.co.id NAME="Nama Lengkap"
  # Windows: .\make.ps1 cs-bootstrap-admin -Profile single -Email nama@perusahaan.co.id -Name "Nama Lengkap"
  ```

  Perintah ini membuat akun login GoTrue dan akun `cs_super_admin`, mencatatnya di audit log, lalu mencetak password sementara **sekali**. Serahkan password itu lewat jalur aman; saat login pertama di web CS (dari jaringan yang diizinkan), super admin wajib menggantinya. Bila sudah ada super admin aktif, perintah menolak kecuali diberi `FORCE=1` (Windows: `-Force`).

  Akun CS berikutnya dibuat super admin dari menu Pengaturan → Akun CS, termasuk reset password bila CS lupa. `scripts/cs-staff-setup.sh` hanya untuk dev.
- [ ] Halaman demo `scripts/cs-demo` tidak ikut di-deploy. Halaman ini hanya disajikan `make cs-demo` di profil dev.
- [ ] Web CS disajikan dengan header keamanan (`Content-Security-Policy` yang membatasi `connect-src` ke API internal, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`) dan tanpa cache untuk `index.html`.
- [ ] Partisi `cs.*_default` kosong, dan job `cs-partitions` tercatat sukses di `cron.job_run_details`.

**Aplikasi**
- [ ] App OLT memakai URL HTTPS produksi. Build release Android tidak mengizinkan cleartext.
- [ ] `make license-audit` lulus (tanpa GPL/AGPL).
- [ ] `make e2e-windows` dan uji manual di Android lulus terhadap staging.
