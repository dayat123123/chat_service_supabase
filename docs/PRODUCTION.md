# Panduan Produksi

Panduan ini menjelaskan cara menjalankan OLT Social di VPS Ubuntu dengan profil **`single`** (produksi 1 server): deploy, rahasia, backup, update, moderasi, dan checklist sebelum rilis. Pindah ke banyak node: [scaling.md](scaling.md).

## 1. Arsitektur produksi

```
Internet ──80──▶ Traefik ── redirect ke HTTPS
Internet ──443─▶ Traefik (TLS Let's Encrypt, TLS ≥ 1.2, rate limit per IP,
                 │        batas body & koneksi WebSocket, security headers)
                 │ hanya path API: /rest/v1 /realtime/v1 /storage/v1 /media/v1 /integration/v1
                 │ /bridge/v1   (lainnya 404, termasuk /auth/v1, /functions/v1 & Studio;
                 │               cs_api hanya RPC chat CS nasabah, API staf di domain CS)
                 ▼
               Kong ──▶ PostgREST, Storage, Edge Functions ──▶ PgBouncer ──▶ Postgres 17
                 │      Realtime ─────────────────────────────────────────▶ Postgres
                 │      auth-bridge (verifikasi token sosial OLT lokal, JWKS)   Valkey (rate limit, cache)
                 │      media (cek isi file, buang EXIF/GPS) ──▶ classifier (NSFW) ──▶ Storage
                 │      integration (notifEngine & bot OLT, API key) ──▶ antrean push
 127.0.0.1:8000 ─┘ entrypoint admin: Studio & semua path (SSH tunnel / WireGuard)

Latar belakang: notifier (push FCM), janitor (bersihkan file), sentinel (pantau + alert),
link-preview (pratinjau link, aman SSRF), backup (WAL + backup penuh ──restic──▶ S3 di luar server, atau folder lokal bila S3 belum ada)
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
git clone <repo> chat_service_supabase
git clone <repo rendezvous_hub> rendezvous_hub   # hanya bila Hub (CS=1) dipasang; bersebelahan dengan repo ini
cd chat_service_supabase
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
- **API staf hanya di domain CS** (temuan T4, [laporan uji 3 Nov](testing/report-2026-11-03.md)). Di domain publik `PROXY_DOMAIN` (`docker/volumes/traefik/prod.yml`):
  1. Skema `cs_api` hanya dibuka untuk 14 RPC chat CS yang dipanggil app nasabah (router `api-cs-customer`: `support_home`, `topics`, `open_ticket`, `my_tickets`, `ticket_messages`, `close_ticket`, `rate_ticket`, `request_complaint`, `report_fake_cs`, `check_sensitive`, `get_messages`, `send_message`, `mark_read`, `room_members`). Permintaan lain dengan `Accept-Profile`/`Content-Profile` `cs_api` dijawab 403 (`api-cs-staff-block`), dan router `api` membuang kedua header itu sehingga hanya skema `public` yang terjangkau.
  2. Router REST publik memasang header `X-Olt-Edge: public` (menimpa nilai dari klien). `private.check_request` (migrasi `0100`) menolak JWT akun CS yang datang dengan penanda ini (`403 cs_staff_public_edge`), jadi JWT staf yang bocor tidak bisa dipakai dari internet, termasuk untuk RPC yang dibuka bagi nasabah. Domain CS membuang header ini.
  3. `/functions/v1` (Edge Function `cs-admin`) tidak dipublikasikan; hanya ada di domain CS. Fungsi contoh `hello` sudah dihapus.
  4. Router Realtime, Storage, dan `/media/v1` publik juga memasang `X-Olt-Edge: public`. Realtime meneruskan header `x-*` dari koneksi WebSocket ke `request.headers` saat memeriksa RLS, dan Storage meneruskan semua header. Migrasi `0105` memakai `private.staff_on_public_edge()`:
     - di `olt_realtime_receive`/`olt_realtime_send`, join kanal privat (`cs:*`, `room:*`) dan presence oleh JWT staf ditolak ("Unauthorized");
     - policy restrictive `cs_staff_public_edge` di `storage.objects` menolak semua operasi staf di semua bucket (`cs-documents`, `evidence`, `attachments`, `avatars`), termasuk signed URL dan list;
     - layanan media meneruskan penanda ke Storage, jadi upload staf lewat `/media/v1` publik juga ditolak (`403 upload_forbidden`);
     - trigger `cs_staff_postgres_changes` menolak langganan `postgres_changes` akun CS di semua domain, karena header tidak sampai ke langganan ini dan web CS tidak memakainya.

     Domain CS (`cs-api`, `cs-realtime`, `cs-storage-upload`) membuang header ini. Topik Realtime `online` ikut ditutup di `0105` karena tidak dipakai klien dan bisa dipakai membanjiri batas presence tenant. Objek bucket publik `avatars` tetap bisa diunduh siapa saja tanpa JWT, dan itu memang sesuai desain.

  Bila app nasabah menambah pemanggilan RPC `cs_api`, tambahkan namanya ke regex `api-cs-customer`. `make test-security` (static-config) mencocokkan allowlist ini dengan `lib/` repo library `rendezvous_community` (clone di `../rendezvous_community` atau `PKG=<path>`) dan gagal bila ada yang terlewat. Profil dev tidak membatasi apa pun (web CS dev di `:8085` memakai API `:8000`). Pastikan `SUPABASE_URL` cs-console di server = domain CS. Kalau diarahkan ke domain publik, REST, Realtime, dan Storage staf ditolak.

  Setelah `prod.yml`/`cs.yml` berubah, jalankan `docker compose ... up -d --force-recreate traefik`, karena watcher file belum tentu menangkap file bind mount yang diganti `git pull`. Di cluster (Swarm), isi config tidak bisa diubah, jadi buat config dengan nama baru lalu `docker stack deploy`.
- **Rendezvous Hub** (web CS, repo [`rendezvous_hub`](https://github.com/dayat123123/rendezvous_hub)) mati secara default di profil single. Nyalakan dengan `make up PROFILE=single CS=1` (Windows: `-Cs`), yang memakai overlay `docker/compose.cs.yml` dan membangun image `cs-console` dari checkout Hub di sebelah repo ini (`../rendezvous_hub`, atau `HUB_DIR` di `docker/.env`, relatif terhadap `docker/`). Tanpa checkout itu `make up ... CS=1` berhenti dengan pesan `Rendezvous Hub checkout not found at ...`. Update Hub: `git -C ../rendezvous_hub pull --ff-only` sebelum `make up`. Isi di `docker/.env`:
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
- **Backup**: isi tujuan (S3, atau sementara **Folder lokal di server** dengan `BACKUP_LOCAL_REPO_DIR` di disk terpisah) dan password enkripsi di **Pengaturan → Backup** segera setelah deploy. Sebelum itu muncul alert "Backup belum diatur". Simpan password enkripsi dan salinan `pgsodium_root.key` di luar server. Detail: [docs/backup](backup/README.md).
- **Moderasi gambar**: layanan `classifier` (model NSFW MobileNetV4, Apache-2.0, CPU) dipanggil `media` untuk setiap gambar nasabah sebelum disimpan. Gambar porno ditolak, gambar meragukan ditahan (hanya terlihat pengunggah dan moderator) dan masuk antrean **Komunitas → Moderasi → Gambar ditahan**. Bila `classifier` mati, upload gambar ditolak (fail closed) dan Kesehatan sistem memberi alert. Ambang diatur Kepatuhan (**Kepatuhan → Kebijakan konten → Ambang gambar**). Detail: [services/classifier](../services/classifier/README.md).
- **Keamanan konten & anti goreng saham**: filter kata ternormalisasi, domain/link, kontak dan frasa promosi, batasan akun baru, permintaan pesan DM, banding, deteksi manipulasi, dan slow mode room saham berjalan otomatis; kebijakannya diatur Kepatuhan dari web. Detail: [docs/content-safety.md](content-safety.md).
- **Kill switch & versi minimum**: Super Admin atau peran Fitur & Kampanye (migrasi `0121`) dapat mematikan fitur sosial seketika (wajib alasan; chat CS tetap jalan), membuka fitur bertahap lewat feature flag, dan mewajibkan update aplikasi di **Fitur & Kampanye → Fitur & versi**. Selama kill switch aktif, tulis konten dan chat non-CS dari nasabah ditolak dengan **`403 social_disabled`** (SQLSTATE `PT403`, migrasi `0109`; sebelumnya `503`, lihat T24 di bawah). Paket Flutter mengenali kode `social_disabled`, bukan statusnya. Detail: [docs/social](social/README.md).
- **Gateway integrasi OLT** (`/integration/v1`, layanan `integration`): notifEngine OLT mengirim notifikasi transaksi per `cust_id`; server memetakan ke pemilik rekening dari klaim `accounts` di token sosial OLT. API key dibuat Super Admin di **Pengaturan → Integrasi OLT** (ditampilkan sekali). Batasi sumbernya dengan CIDR pada key. Spesifikasi untuk tim OLT: [docs/integration](integration/README.md).
- **Pratinjau link**: layanan `link-preview` (satu-satunya yang mengambil URL internet sembarang, dengan proteksi SSRF) membuat pratinjau link di postingan dan chat. Detail: [services/link-preview](../services/link-preview/README.md).
- **Pembersihan file storage**: layanan `janitor` menghapus file milik akun yang dihapus (avatar, lampiran postingan dan chat, dokumen CS) serta surat yang lewat masa simpan, dari antrean `private.storage_cleanup_queue`. Tidak perlu konfigurasi. Folder yang gagal dicoba ulang dengan jeda sampai 6 jam. Cek antrean: `select bucket_id, prefix, failures, error from private.storage_cleanup_queue where done_at is null;`. Detail: [services/janitor](../services/janitor/README.md).
- **Karantina bukti** (migrasi `0095`): konten yang dilaporkan atau dihapus moderator/sistem disimpan utuh (teks, konteks, sidik SHA-256) dan file-nya disalin `janitor` ke bucket privat `evidence` sebelum aslinya dibersihkan. Bukti append-only, disimpan 730 hari (`private.settings` kunci `retention.evidence_days`) kecuali Kepatuhan memasang legal hold, lalu dihapus job `evidence-purge`. Akses hanya Kepatuhan (dan Super Admin baca saja) di **Kepatuhan → Bukti**, setiap buka/periksa/ekspor tercatat. Hitung ukuran bucket `evidence` dalam kapasitas disk storage. Cek salinan yang tertahan: `select status, count(*) from private.evidence_files group by 1;`. Detail: [docs/evidence](evidence/README.md).

## 3. Backup & restore

Backup berkelanjutan dijalankan layanan `backup`, dan diatur Super Admin dari web CS (**Pengaturan → Backup**). Prosesnya:
- WAL dialirkan terus lewat replikasi.
- Backup penuh harian dan file storage dibuat otomatis.
- Semuanya dikirim ke repositori restic terenkripsi di S3 di luar server. Bila S3 belum ada, pilih **Folder lokal di server**: repositori disimpan di `BACKUP_LOCAL_REPO_DIR` (`docker/.env`, arahkan ke disk terpisah, mis. `/mnt/backup/restic` milik uid 10001). Folder lokal tidak melindungi dari server rusak/hilang, jadi salin isinya ke luar server secara berkala (`restic copy` atau salin folder saat backup berhenti) dan pindah ke S3 begitu tersedia. Detail: [docs/backup → Tujuan folder lokal](backup/README.md#tujuan-folder-lokal).
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
   git -C ../rendezvous_hub pull --ff-only   # bila Hub dipasang
   make up PROFILE=single   # service `migrate` menjalankan migrasi baru secara otomatis
   ```

5. Upgrade major Postgres (misalnya 17 → 18) butuh `pg_upgrade` dan tidak tercakup langkah di atas.

**Rilis alert kapasitas (migrasi `0104`, sentinel 0.2.0, image PgBouncer `1.24.0-4`):** rilis ini menambah Docker secret `pgbouncer_stats_password` (user konsol admin PgBouncer `olt_stats` untuk sentinel). Jalankan `make gen-secrets` (Windows: `.\make.ps1 gen-secrets`) sebelum `make up`; secret yang sudah ada dipertahankan dan hanya yang belum ada dibuat. Tanpa secret ini `check-config` gagal dan PgBouncer tidak mau start.

**Rilis batas CGNAT dan latensi alert (migrasi `0108`, sentinel 0.3.0, image PgBouncer `1.24.0-5`, 4 Nov):** sebelum `make up`, periksa `docker/.env` server. Baris `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` atau `EDGE_WS_PER_IP` yang lebih kecil dari 1.000 (mis. sisa 30/300/150 dari rilis lama) membuat `check-config` profil `single`/`cluster` gagal; hapus barisnya agar default baru (1.500) dipakai. Traefik kini dibatasi 768M (sebelumnya 256M). PgBouncer dan sentinel di-build ulang otomatis oleh `make up`.

**Rilis image pihak ketiga (T5, 4 Nov):** Postgres `17.6.1.136` → `17.11.0.008` (PostgreSQL 17.6 → 17.11, major sama, tanpa dump/restore), Realtime `v2.148.6`, Storage `v1.84.32`, Studio `2026.10.26-sha-478bd88`, edge-runtime `v1.77.9`, Kong `3.9.4`, Traefik `v3.7.16`. Rincian dan alasan per image: [laporan uji 12.7](testing/report-2026-11-03.md#127-t5-versi-image-pihak-ketiga-4-nov).

- Wajib `make backup PROFILE=single` sebelum `make up`. Image `db` berganti, jadi `db` dan layanan yang bergantung padanya dibuat ulang. Di dev, semua service healthy lagi dalam ±2 menit.
- PostgreSQL 17.11 hanya mengizinkan output plugin di `output_plugin_libraries`. `postgresql.conf` image sudah berisi `pgoutput, test_decoding, wal2json`. Bila config Postgres diganti sendiri, `wal2json` wajib ada; tanpa itu `postgres_changes` Realtime berhenti.
- Tidak perlu `REINDEX`: tidak ada `btree_gist`, `comments.path` (ltree) jauh di bawah 14.653 label, dan tidak ada fungsi kita yang memakai PGP pgcrypto.
- Volume `db-config` (`/etc/postgresql-custom`) tidak diperbarui otomatis. Isinya tetap berkas image lama (`supautils.conf`, `extension-custom-scripts/`, tanpa `conf.d/pg_net.conf`), sama seperti upstream. Server baru mendapat versi baru. Jangan hapus volume ini (berisi `pgsodium_root.key`).
- `make up --wait` bisa gagal sekali dengan `rest is unhealthy`: PgBouncer ikut dibuat ulang, listener PostgREST mundur 8 → 16 → 32 dtk, dan `/ready` 503 ±70 dtk. Tunggu sebentar, lalu jalankan `make up` lagi.
- Storage `v1.84.32` tidak menambah migrasi internal (terakhir tetap `74 unlock-object-versioning`), jadi kembali ke `v1.81.0` masih aman.
- Realtime `v2.148.6` memakai Phoenix 1.8.15: pesan WebSocket dengan `join_ref` yang tidak cocok dengan join channel diabaikan diam-diam. Klien Dart (`realtime_client`) dan realtime-js aman. Klien buatan sendiri wajib mengirim `join_ref` = `ref` dari `phx_join` channel itu.

**Rilis Realtime Broadcast (migrasi `0098`, `rendezvous_community` 1.5.0) memutus klien lama.** Klien 1.4.x tetap tersambung, tetapi tidak lagi menerima pesan baru secara realtime (hanya saat memuat ulang) dan typing-nya tidak sampai. Urutan rilis:

1. App OLT dengan `rendezvous_community` 1.5.0 sudah tersedia di toko aplikasi / kanal update Windows untuk semua platform.
2. Deploy backend (`git pull`, `make up`).
3. Segera setelahnya, Super Admin atau peran Fitur & Kampanye membuka web CS **Fitur & Kampanye → Fitur & versi → Versi minimum aplikasi** dan mengisi versi app OLT pertama yang membawa 1.5.0 untuk setiap platform yang dipakai OLT (`android`, `windows`, dan `ios`/`macos`/`linux`/`web` bila ada). Yang dibandingkan adalah `appVersion` app OLT yang dikirim ke `initialize(...)`, bukan versi package. Perubahan tercatat di jejak audit. App yang lebih lama menerima `update_required: true` dari `get_client_config` dan callback `onUpdateRequired` mengarahkan nasabah ke update. Detail: [panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md#kompatibilitas-server-dan-versi-minimum).
4. Data di database tidak perlu diubah manual.

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
- **Restart otomatis (healer, profil single):** container yang mati di-restart Docker (`restart: unless-stopped`), tetapi container yang hanya **unhealthy** tidak. Layanan `healer` ([services/healer](../services/healer/README.md)) me-restart container berlabel `olt.autoheal=true` yang unhealthy ≥ 60 dtk dan sudah berjalan ≥ 120 dtk, maks 3 kali per layanan per jam (lalu menyerah dan membuka alert kritis `healer:gave_up:<layanan>`), maks 1 restart per 30 dtk untuk seluruh stack. Riwayatnya di web CS, Kesehatan sistem → Restart otomatis. Di Linux, isi `HEALER_DOCKER_GID` di `docker/.env` dengan GID grup `docker` (`getent group docker | cut -d: -f3`); tanpa itu healer tidak bisa membaca socket dan alert `healer:stale` terbuka. Healer adalah satu-satunya container dengan Docker socket (setara root di host), karena itu tanpa jaringan, tanpa port, read-only, non-root, dan diperiksa `make test-security`. Profil cluster tidak menjalankannya (Swarm mengganti task unhealthy).
- **auth-bridge (port ops internal 9100).** Port ini tidak dipublikasikan dan tidak lewat Kong; akses dari jaringan Docker:

  ```bash
  docker compose -f docker/compose.yml -f docker/compose.prod.yml run --rm --entrypoint sh tools \
    -c 'curl -s http://auth-bridge:9100/readyz; curl -s http://auth-bridge:9100/metrics | grep ^olt_'
  ```

  - `/readyz` bernilai `degraded` bila Valkey bermasalah (rate limit jatuh ke per-instance) atau circuit breaker OLT terbuka.
  - Metrik dan alert yang disarankan ada di [services/auth-bridge/README.md](../services/auth-bridge/README.md#port-ops-internal).
- **Yang perlu dipantau:**
  - disk (volume `db-data`, `storage-data`, folder `backups/`, repositori backup lokal `BACKUP_LOCAL_REPO_DIR`)
  - koneksi Postgres (PgBouncer membatasi maks 80 koneksi server)
  - error 5xx dan 429 di log Traefik/Kong
  - error `olt_unavailable` di auth-bridge (server OLT bermasalah), `olt_auth_bridge_olt_breaker_open = 1`, dan kenaikan `olt_auth_bridge_valkey_errors_total`

### Alert kapasitas (sentinel 0.3.0, migrasi `0104`, `0108`)

Sentinel membaca metrik internal setiap `REPORT_INTERVAL` (30 dtk) lewat `METRICS_SOURCES` dan mengirim angka mentahnya ke `health_report(p_metrics)`. Aturan dihitung di database, sama seperti probe dan disk. Alert dikirim ke kanal Telegram/email yang diatur Super Admin di web. Ambang ada di `private.settings` (`health.*`) dan bisa diubah tanpa deploy.

- **Kapan alert dibuka.** Alert lain dibuka bila masalah bertahan `health.alert_after_seconds` (120 dtk). Kunci kapasitas (`rest:pool`, `realtime:events`, `pgbouncer:queue`, `db:lock_waits`, `metrics:*`) memakai `health.alert_after_seconds.<kunci>` (atau `.<prefiks>:*`), bawaan **25 dtk**, yaitu dua laporan sentinel berturut-turut yang sama-sama melanggar. Nilai per kunci tidak pernah melebihi nilai global. Satu laporan yang melanggar tidak membuka alert; alert yang sudah terbuka baru pulih setelah bersih `health.resolve_after_seconds` (60 dtk). Sebelum `0108`, `realtime:events` butuh ±4 menit beban berkelanjutan (rata-rata 2 menit + 120 dtk); kini ±60–90 dtk (laporan uji bagian 12).
- **Laporan yang tidak terkirim.** Sentinel melapor lewat PostgREST, jadi saat `rest` runtuh laporannya ikut gagal (504 `PGRST003`) dan sampel hilang. Sentinel 0.3.0 menyimpan hitungan putaran yang hilang dan mengirimnya di laporan berikutnya: jumlah laporan yang hilang (sumber sintetis `sentinel`, `sentinel_reports_lost`), kegagalan baca tiap sumber (`missed`), dan kegagalan probe (`missed`). Database mencatatnya di `private.health_report_misses` (disimpan 15 menit).

| Kunci alert | Sumber | Peringatan | Kritis | Catatan |
|---|---|---|---|---|
| `rest:pool` | Admin server PostgREST `http://rest:3001/metrics`: `pgrst_db_pool_timeouts_total`, `pgrst_db_pool_waiting`, `pgrst_db_pool_available`, `pgrst_db_pool_max`; laporan sentinel yang hilang | ≥ 1 timeout PGRST003 (504) dalam 5 menit, ≥ 1 request menunggu saat pool kosong (`available` 0) pada sampel terakhir, atau ≥ 2 laporan sentinel/sampel `rest` hilang dalam 5 menit (`health.rest_blind_warn`) | ≥ 20 timeout dalam 5 menit, atau sampel/laporan hilang **dan** probe `rest` gagal dalam 5 menit (judul "API (PostgREST) tidak menjawab") | Gejala T17 (konvoi kunci baris). `waiting` saja tidak dipakai: gauge ini sering 1 sesaat walau koneksi masih tersedia (termasuk saat probe sentinel). Counter dijumlah lintas replika; restart replika (counter reset) dihitung benar |
| `realtime:events` | Realtime `/metrics` (JWT dari `jwt_secret`, sama dengan `METRICS_JWT_SECRET`): laju `realtime_channel_global_events` dalam `health.realtime_events_window_seconds` (45 dtk) terakhir sebelum sampel terbaru, yaitu satu interval laporan | ≥ 70% `max_events_per_second` tenant | ≥ 90%; judul berubah menjadi "membuang event" pada ≥ 100% | Batas dibaca dari `_realtime.tenants` (cadangan `health.realtime_events_limit`). Lihat catatan di bawah |
| `pgbouncer:queue` | Konsol admin PgBouncer, `SHOW POOLS` sebagai `olt_stats` | `cl_waiting` ≥ 1 atau `maxwait` ≥ 1 dtk (sampel terakhir) | `maxwait` ≥ 5 dtk | Pool konsol `pgbouncer` diabaikan |
| `db:lock_waits` | `pg_locks` (`not granted`, `waitstart`) saat evaluasi | ≥ 5 proses menunggu lock, atau tunggu terlama ≥ 5 dtk | ≥ 20 proses atau ≥ 30 dtk | Sinyal dini T17 dan migrasi yang tertahan lock |
| `queue:room_preview` | `private.room_preview_queue` (migrasi `0102`) | Baris tertua ≥ 60 dtk | ≥ 300 dtk | Job `chat-room-preview` (tiap 10 dtk) mati atau macet. Kegagalan job itu sendiri juga muncul sebagai `cron:chat-room-preview` (aturan cron 0064 mencakup semua job aktif) |
| `metrics:<sumber>` | Status baca sumber metrik | Sumber gagal dibaca pada laporan terakhir, atau ≥ 2 sampel gagal dibaca dalam 5 menit (`health.metrics_missed_warn`, `health.metrics_missed_window_seconds`), termasuk kegagalan di laporan yang tidak terkirim | — | Supaya alert di atas tidak diam-diam mati (mis. secret salah, port admin tertutup, `rest` terlalu sibuk menjawab `/metrics`) |

- **Kenapa Realtime lewat metrik, bukan log.** Realtime v2.143–v2.148 tidak punya counter khusus `MessagePerSecondRateLimitReached`/`UnableToBroadcastChanges` di `/metrics`; keduanya hanya ada di log. Membaca log butuh akses Docker socket atau pengiriman log, yang tidak diberikan ke sentinel. Batas tenant dihitung Realtime dari rata-rata bergerak counter event yang sama dengan `realtime_channel_global_events`, jadi laju counter itu dibanding `max_events_per_second` memberi peringatan **sebelum** event dibuang. Di cluster, laju dijumlah dari semua node (lebih awal waspada bila batas ternyata per node).
- **Endpoint internal saja.** Admin server PostgREST (`PGRST_ADMIN_SERVER_HOST: 0.0.0.0`, port 3001: `/live`, `/ready`, `/metrics`, `/schema_cache`), `/metrics` Realtime, dan konsol PgBouncer hanya ada di network Docker `app`/`data`. Tidak ada yang di-publish ke host atau di-route Kong/Traefik; `make test-security` (static-config) memeriksanya.
- **User `olt_stats`** hanya ada di `userlist.txt` PgBouncer dan di `stats_users` (perintah `SHOW` saja). Role ini tidak ada di Postgres, jadi tidak bisa membuka database. Password dari Docker secret `pgbouncer_stats_password`, seperti rahasia infrastruktur lain (bukan kredensial operasional yang dikelola dari web).
- **Cluster:** `stack.cluster.yml` memakai `tasks.rest`, `tasks.realtime`, `tasks.pgbouncer`, sehingga setiap replika dibaca terpisah (bukan lewat VIP yang bergantian).
- **Uji pemicu:** saat uji beban 500/600 VU (`make load-test`), `rest:pool` dan `db:lock_waits` seharusnya terbuka sebelum T17 diperbaiki, dan `realtime:events` pada ±450+ penerima per room. Matikan job dengan `select cron.alter_job((select jobid from cron.job where jobname = 'chat-room-preview'), active := false)` di staging lalu kirim pesan ke room saham untuk memicu `queue:room_preview` (nyalakan lagi sesudahnya).

### Batas & rate limit

Batas per IP dibuat longgar karena banyak nasabah bisa berbagi satu IP: NAT operator seluler (CGNAT) atau Wi-Fi kantor saat pasar buka 09:00 (temuan T3, [laporan uji 3 Nov](testing/report-2026-11-03.md), bagian 12). Default-nya cukup untuk **±1.000 nasabah di balik satu IP**; uji 800 VU dari satu IP lewat Traefik: 0 × 429, semua WebSocket terbuka. Perlindungan dari penyalahgunaan per akun tetap dijaga batas per user. Semua nilai bisa diubah lewat `docker/.env` tanpa ubah kode.

| Batas | Variabel `docker/.env` | Default | Catatan |
|---|---|---|---|
| Request per IP (Traefik) | `EDGE_RATE_AVERAGE` / `EDGE_RATE_BURST` | 600 / 1.200 per detik | Sebelumnya 300/600 (awalnya 100/200). Satu nasabah aktif ±0,15–0,25 req/dtk, jadi 1.000 nasabah ±250 req/dtk ditambah lonjakan login |
| WebSocket bersamaan per IP (Traefik) | `EDGE_WS_PER_IP` | 1.500 | Sebelumnya 150 (awalnya 20). Satu nasabah memakai 1 WebSocket; sisa 50% untuk soket lama yang belum ditutup saat sambung ulang. Jumlah koneksi total tetap dijaga batas tenant Realtime. `make up`/`check-config` profil `single`/`cluster` gagal bila `docker/.env` berisi < 1.000 |
| Exchange auth-bridge per IP | `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` | 1.500 per menit | Sebelumnya 300 (awalnya 30). 1.000 nasabah yang membuka aplikasi dalam satu menit saat 09:00 = 1.000 exchange dari satu IP; JWT TTL 15 menit menambah ±70/menit. `.env` lama bisa masih berisi 30 atau 300: `make up`/`check-config` profil `single`/`cluster` gagal bila nilainya < 1.000 |
| Exchange auth-bridge per user OLT | `AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE` | 10 per menit | Tetap ketat (dev 60) |
| Aksi per user (pesan, postingan, laporan, dsb.) | `private.rate_limits` (SQL, bagian 5.2) | per aksi | Tidak bergantung IP; akun baru dibatasi lebih ketat |
| Realtime per tenant | `REALTIME_MAX_CONCURRENT_USERS`, `REALTIME_MAX_JOINS_PER_SECOND`, `REALTIME_MAX_CHANNELS_PER_CLIENT`, `REALTIME_MAX_EVENTS_PER_SECOND` | 10.000 / 500 / 100 / 20.000 | Menjaga sumber daya Realtime walau batas WebSocket per IP dinaikkan. Lihat [Batas Realtime](#batas-realtime) |
| Tunggu koneksi pool PostgREST | `PGRST_DB_POOL_ACQUISITION_TIMEOUT` | 2 dtk | Sebelumnya 10 (bawaan PostgREST). Saat pool (`PGRST_DB_POOL`, 10) habis, request gagal cepat dengan 504 `PGRST003` alih-alih menumpuk 10 dtk dan memperpanjang keruntuhan (T17). Klien mencoba ulang; pantau alert `rest:pool` |
| Thread runtime PostgREST | `PGRST_GHCRTS` → `GHCRTS` | `-N1` | `-N<n>` harus sama dengan batas CPU service `rest`. Bawaan image (`-N`) membuat satu capability per core host; di kuota 1 vCPU `rest` runtuh pada ±90 req/dtk dan tidak pulih (T20). Naikkan bersama `cpus` bila `rest` diberi lebih dari 1 vCPU |
| Jeda login ulang PgBouncer ke Postgres | `PGBOUNCER_SERVER_LOGIN_RETRY` | 0,25 dtk | Bawaan PgBouncer 15 dtk membuat REST 503 ±16 dtk setelah Postgres restart. Dengan 1 dtk, percobaan ulang PostgREST pertama (1 dtk setelah gagal) masih menabrak error yang di-cache sehingga REST baru pulih di percobaan kedua (3 dtk) (T6) |
| Cek IP host database oleh PgBouncer | `PGBOUNCER_DB_WATCH_SECONDS` | 2 dtk | PgBouncer 1.24 memakai c-ares yang menyimpan jawaban DNS sampai TTL DNS Docker (600 dtk). Tanpa cek ini, setelah container `db` dibuat ulang atau di-stop/start dengan IP baru, PgBouncer terus menyambung ke IP lama hingga 10 menit dan seluruh API mati. Entrypoint PgBouncer menulis IP hasil `getent` ke konfigurasi dan memuat ulang (SIGHUP) saat IP berubah (T6) |
| API key integrasi OLT | kolom `rate_limit_per_minute` (web CS, Pengaturan → Integrasi OLT) | 3.000 per menit (key baru, migrasi `0101`) | Batas keras per key (T7). notifEngine wajib mengirim batch 100–500 pesan per request. Key lama tetap pada nilainya; naikkan dari web bila perlu |

Bila server nanti berada di belakang load balancer/CDN, semua nasabah terlihat dari satu IP. Atur `ipStrategy` middleware `rate-limit`/`ws-limit` di `docker/volumes/traefik/common.yml` (saat ini `depth: 0`, alamat koneksi langsung) sebelum memindahkannya.

### Batas Realtime

- Realtime men-seed ulang tenant dari env setiap start (`SEED_SELF_HOST`). `UPDATE _realtime.tenants` hilang setelah restart, jadi ubah `REALTIME_MAX_EVENTS_PER_SECOND` di `docker/.env`, lalu `docker compose ... up -d --no-deps realtime`.
- Pesan chat dikirim lewat Broadcast dari database (`0098`, [docs/social](social/README.md#pengiriman-pesan-realtime-0098)). Setiap event yang **diterima** satu klien dihitung ke batas ini: satu pesan di room berisi 400 orang = 400 event. Room saham ramai dengan 12 pesan/detik dan 400 penerima ≈ 4.800 event/detik.
- Bawaan 20.000/detik (sebelumnya 10.000). Fan-out satu room saham ≈ penerima × pesan/dtk ke room itu, kira-kira N²/20 pada room ramai: 10.000 habis di ±450 penerima aktif, 20.000 cukup untuk ±630. Butuh `realtime` 2 vCPU (batas di compose); uji 40.000 tanpa event dibuang dengan CPU `realtime` ≤ 53% (laporan uji bagian 10). Naikkan bersama CPU bila room terbesar lebih ramai. Di atas batas, Realtime membuang event diam-diam (log `MessagePerSecondRateLimitReached`, lalu `UnableToBroadcastChanges: too_many_requests`). Alert `realtime:events` (Kesehatan sistem) terbuka mulai 70% batas, kritis mulai 90%. Klien Flutter dan web CS mengisi celah lewat `get_messages(p_after)` saat tersambung, tiap 45 detik, dan saat kembali ke aplikasi. Pesan tidak hilang, hanya terlambat.
- Naikkan bertahap sambil memantau CPU container `realtime` (laporan uji: CPU Realtime rendah, bottleneck sebelumnya adalah RLS `postgres_changes` di Postgres, yang kini tidak dipakai untuk pesan).
- `REALTIME_MAX_BYTES_PER_SECOND` tidak ditegakkan oleh Realtime v2.143–v2.148 (diperiksa ulang di sumber v2.148.6). `max_presence_events_per_second` (1.000) tidak bisa diatur lewat env.
- Typing dan presence di room besar dibatasi server (`0106`, [docs/social](social/README.md#typing-dan-presence-di-room-besar-0106)). Room non-CS mulai 50 anggota hanya menerima `typing_summary` (maksimal 1 per 3 dtk per room), sehingga di room 500 penerima typing turun dari ±25.000 menjadi ±167 event/dtk. Presence di room saham ditolak. Settingnya `rooms.typing_*` dan `rooms.presence_*` di `private.settings`.
- Daftar chat aplikasi memoll `get_room_previews` untuk room saham (`0107`, bawaan 15 dtk, `rooms.preview_poll_seconds`). Polling ini tidak memakai anggaran Realtime. Bila REST/DB sedang berat, naikkan nilainya; klien mengikuti mulai poll berikutnya.

### Perilaku saat gangguan (laporan uji chaos 3 Nov)

- **Valkey mati** (T8): auth-bridge tetap melayani exchange (fail open) dengan limiter lokal per instance; `/readyz` bernilai `degraded`. Batas efektif menjadi batas × jumlah replika auth-bridge, dan restart Valkey mengosongkan jendela rate limit. Ini disengaja: login nasabah lebih penting daripada ketepatan batas selama beberapa menit. Pantau `olt_auth_bridge_valkey_errors_total`.
- **Postgres restart** (T6, diperbaiki 4 Nov, laporan uji bagian 12): jendela gagal REST kini **±1,2 dtk** untuk `docker restart db` (sebelumnya 3,2 dtk dengan beban ringan, 9,5 dtk di uji chaos, awalnya ±16 dtk), dan REST pulih **≤ 2,2 dtk setelah Postgres menerima koneksi** walau DB mati 5 dtk.
  - Saat koneksi putus, PostgREST mengosongkan schema cache dan menjawab 503 `PGRST002` sampai percobaan ulang berhasil. Jadwal percobaannya tetap di kode (1, 2, 4, 8, … maks. 32 dtk setelah gagal, kumulatif 1, 3, 7, 15 dtk) dan tidak bisa diatur.
  - PgBouncer menyimpan error login selama `server_login_retry`. Dengan 1 dtk, percobaan PostgREST di detik ke-1 masih kena error dari klien lain sehingga REST menunggu percobaan detik ke-3. Kini 0,25 dtk.
  - Bila DB mati lebih dari ±3 dtk, REST pulih pada percobaan PostgREST berikutnya (detik ke-7, lalu ke-15). Restart DB terencana: jalankan `CHECKPOINT` dulu agar shutdown singkat, dan lakukan di luar jam bursa.
  - Container `db` yang dibuat ulang atau di-stop/start bisa mendapat IP baru. Sebelum 4 Nov, PgBouncer terus memakai IP lama dari cache DNS c-ares (TTL Docker 600 dtk) dan seluruh API mati sampai PgBouncer di-restart. Kini entrypoint PgBouncer memantau IP setiap 2 dtk dan memuat ulang konfigurasi.
  - Listener `LISTEN pgrst` PostgREST memakai backoff sendiri yang bisa tertinggal di 32 dtk setelah gangguan panjang. Selama itu `/ready` 503 dan Docker menandai `rest` unhealthy, tetapi request API tetap dilayani.
  - Realtime tetap menolak join sampai tenant tersambung ulang. Semua pulih sendiri; aplikasi mencoba ulang.
- **Status 503 dari aplikasi** (T24, diperbaiki 4 Nov, migrasi `0109`): PostgREST v14 menganggap **setiap** respons 503 sebagai database putus (`isServiceUnavailable` di `App.hs`). Setiap 503 menjalankan worker koneksi: pool di-flush, versi Postgres dicek, schema cache dimuat ulang, dan header `Retry-After` ditambahkan. Dulu kill switch menjawab `api_error(503, 'social_disabled')`. Dengan kill switch aktif, ini memicu 233 flush dalam ±76 dtk sampai PgBouncer menolak login (`too many connections for role "pgbouncer"`). Kini statusnya `403`; burst 200 request saat kill switch aktif tidak memicu flush.
  - **Aturan:** jangan pernah memakai status 503 untuk penolakan aplikasi. Jangan memanggil `private.api_error(503, …)`, jangan me-raise `PT503`, dan jangan me-raise SQLSTATE kelas `08`, `53` (kecuali `53400`), atau `57P01`, karena PostgREST juga memetakannya ke 503.
  - Fitur yang dimatikan dijawab `403`, konflik `409`, rate limit `429`. Tes `supabase/tests/089_kill_switch_status_test.sql` gagal bila ada fungsi yang memanggil `api_error(503` atau me-raise `PT503`.
- **Pool PostgREST habis** (T17): request yang tidak mendapat koneksi dalam `PGRST_DB_POOL_ACQUISITION_TIMEOUT` (2 dtk) dijawab 504 `PGRST003`. Alert `rest:pool` dan `db:lock_waits` terbuka bila kondisinya bertahan 25 dtk (dua laporan sentinel berturut-turut, migrasi `0108`).
- **Koneksi rest ↔ database putus tanpa RST** (T9): PostgREST memakai keepalive dan `tcp_user_timeout` libpq (`docker/volumes/rest/pg_service.conf`), sehingga koneksi menggantung diputus ±8 dtk, `/ready` menjadi 503, dan healthcheck `postgrest --ready` menandai `rest` unhealthy dalam ±20 dtk (sebelumnya ±40 dtk sebelum `/ready` berubah). Sentinel juga mem-probe `http://rest:3000/` (menyentuh DB).
- **Container macet (unhealthy) di profil single** (healer, migrasi `0113`): healer me-restart layanan yang unhealthy terus-menerus ≥ 60 dtk (mis. `rest` yang `/ready`-nya tetap 503 setelah backoff listener tertinggal) dengan jeda 30 dtk antar restart. Restart **ditahan** bila `db` tidak sehat, bila `pgbouncer` tidak sehat (hanya pgbouncer yang di-restart), atau bila ≥ 50 % layanan berlabel unhealthy bersamaan (gangguan sistemik: host kehabisan memori/CPU/disk, jaringan Docker). Penahanan dicatat sekali dan membuka peringatan `healer:systemic` bila bertahan 120 dtk; tindak lanjutnya manual (`docker stats`, `df -h`, `make logs`). Layanan yang tetap unhealthy setelah 3 restart dalam 1 jam ditinggalkan (alert kritis `healer:gave_up:<layanan>`); healer mencoba lagi setelah jendela 1 jam lewat. Saat uji chaos atau perawatan yang sengaja membuat layanan unhealthy, hentikan healer dulu (`docker compose ... stop healer`) agar hasil uji tidak tercampur restart otomatis.

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
- [ ] Tujuan backup diatur di web (**Pengaturan → Backup**): S3, atau folder lokal di disk terpisah yang disalin ke luar server secara berkala, backup penuh pertama berhasil, dan uji restore berhasil. Password enkripsi dan salinan `pgsodium_root.key` disimpan di luar server.
- [ ] Kanal alert (Telegram dan/atau email) diisi, dan **Kirim uji** sudah diterima tim operasional. Pemantau uptime dari luar server sudah dipasang.
- [ ] Halaman **Kesehatan sistem** tidak menampilkan masalah kritis, dan tidak ada "Metrik … tidak bisa dibaca" (sumber `rest`, `realtime`, `pgbouncer` terbaca sentinel).
- [ ] `docker/.env` server tidak menurunkan `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` atau `EDGE_WS_PER_IP` di bawah 1.000 (`check-config` menolaknya) dan `/bridge/v1/health` menunjukkan `olt_mode: jwt`.
- [ ] Secret `pgbouncer_stats_password` ada (`make gen-secrets`).

**Klien**
- [ ] App OLT yang dirilis memakai `rendezvous_community` ≥ 1.5.0 (wajib sejak migrasi `0098`).
- [ ] Setelah backend naik, Super Admin atau peran Fitur & Kampanye menaikkan **Fitur & Kampanye → Fitur & versi → Versi minimum aplikasi** per platform ke versi app OLT pertama yang membawa 1.5.0 (bagian 4), dan app 1.4.x terbukti mendapat `update_required`.
- [ ] Dokumen hukum (S&K, Pedoman Komunitas, Kebijakan Privasi) diterbitkan Kepatuhan dari web, dan jenis dokumen yang wajib disetujui sudah ditentukan.
- [ ] Daftar kata terlarang (web CS, Kepatuhan → Kata terlarang) dan rate limit sudah ditinjau tim compliance.
- [ ] Prosedur moderasi (bagian 5) sudah disosialisasikan.
- [ ] DNS dan sertifikat HTTPS valid (Traefik memperbarui otomatis).

**Customer service lewat chat (sebelum dibuka untuk nasabah; lihat [docs/cs-chat](cs-chat/README.md))**
- [ ] Revisi CS-2 (R1–R4) selesai. `make test-db`, `make cs-race`, dan `make smoke-cs` lulus di staging. `make cs-race` mencakup tes rebutan lewat beberapa replika API.
- [ ] Tim kepatuhan sudah menjawab [compliance-questions.md](cs-chat/compliance-questions.md), dan nilai di `cs.cs_settings` (tenggat pengaduan, retensi, jam layanan, pesan otomatis) sudah disesuaikan.
- [ ] Kalender libur tahun berjalan dan tahun depan sudah diperiksa kepatuhan (`cs.holidays.verified = true`), termasuk libur bursa dari pengumuman BEI.
- [ ] API agen (`cs_api.agent_*`) dan web CS (Rendezvous Hub, repo `rendezvous_hub`, domain `CS_CONSOLE_DOMAIN`) hanya bisa diakses dari IP di `VPN_SOURCE_RANGES` (LAN kantor atau VPN): uji dari jaringan lain harus mendapat 403. Staf CS login dengan email + password (tanpa TOTP, jadi pembatasan jaringan dan password kuat minimal 12 karakter adalah lapisan utamanya), dan pendaftaran publik GoTrue tetap mati.
- [ ] `make test-cs-console` (CI repo `rendezvous_hub`) lulus dan E2E web CS (`make e2e-cs-console`) lulus di staging, dari commit Hub yang akan dirilis.
- [ ] Endpoint login GoTrue (`/auth/v1/token`, `/auth/v1/factors`, `/auth/v1/user`) hanya dari jaringan yang diizinkan. Nasabah tidak memakainya karena JWT nasabah diterbitkan auth-bridge.
- [ ] Edge Function `cs-admin` (`/functions/v1/cs-admin/*`, dipakai menu Pengaturan → Akun CS) hanya dari jaringan yang diizinkan: `https://<PROXY_DOMAIN>/functions/v1/cs-admin/agents` harus 404, dan RPC agen (`Accept-Profile: cs_api`, mis. `/rest/v1/rpc/agent_me`) di domain publik harus 403. Kunci service role hanya ada sebagai secret container functions, tidak pernah di client.
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
