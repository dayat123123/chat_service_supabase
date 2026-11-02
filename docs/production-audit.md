# Audit Production Readiness

Audit pekerjaan yang sudah ada terhadap addendum [PROMPT-PRODUCTION.md](PROMPT-PRODUCTION.md), per 29 Oktober 2026.

Dasar audit:
- kode di repo, termasuk perubahan yang belum di-commit;
- stack Docker yang sedang berjalan;
- database hasil migrasi, dicek langsung dengan query.

**Status:** ✅ sudah memenuhi · 🟡 sebagian · ❌ belum ada
**Effort** (1 engineer): **S** ≤ ½ hari · **M** 1–2 hari · **L** ≥ 3 hari

## Status pengerjaan

| Tahap | Status |
|---|---|
| 1. Infrastruktur | ✅ Selesai 29 Okt 2026 (rincian di bawah) |
| 2. Database (+ fondasi data F1) | ✅ Selesai 29 Okt 2026 (rincian di bawah) |
| 3. auth-bridge | ✅ Selesai 29 Okt 2026 (rincian di bawah) |
| F1, 4–5, 6, F2–F5, 7 | Belum dimulai |

**Urutan kerja** (gabungan addendum produksi dan [PROMPT-FEATURES.md](PROMPT-FEATURES.md), ditetapkan 29 Okt 2026):
1. **Tahap 2** (DB), diperluas dengan fondasi data F1: role admin + 2FA, sanksi, audit log, arsip & legal hold, persetujuan T&C.
2. **Tahap 3** (auth-bridge).
3. **F1** (service & panel admin).
4. **Tahap 4–5** (Flutter).
5. **Tahap 6** (hardening & observabilitas semua service), lalu go-live.
6. **F2–F5.**
7. **Tahap 7** (multi-node).

**Penyesuaian akibat urutan ini:**
- Panel admin (`apps/admin`) menggantikan rencana "UI moderasi di package".
- Dashboard analitik memakai Perses atau panel admin, bukan Grafana (AGPL).
- Integrasi OLT memakai satu protokol: [olt-integration.md](olt-integration.md).

**Penyesuaian 31 Okt 2026: satu dependensi keluar.** Server hanya memverifikasi token login dari OLT ([olt-integration.md](olt-integration.md)). Sejak 31 Okt sore verifikasinya lokal (token sosial bertanda tangan, auth-bridge mode `jwt`), jadi tidak ada panggilan keluar sama sekali. Akibatnya:
- Bagian data pasar dan portofolio di [PROMPT-FEATURES.md](PROMPT-FEATURES.md) dibatalkan: `market-adapter`, harga saat posting, sinkron daftar saham, dan badge holder.
- `customer-adapter` (data nasabah dan aksi akun untuk CS) serta kartu order di chat CS dihapus (migrasi `0037_client_owned_business_data`).
- Web CS Flutter (`apps/cs-console`) dihapus; web CS kini hanya versi React.

**Tahap 1: yang dikerjakan**
- **Profil.** `docker/compose.yml` (dasar) ditambah `compose.dev.yml`, `compose.prod.yml`, `stack.cluster.yml` (kerangka), dan `compose.dummy-olt.yml` (tambahan dev). Pemilihan lewat `make up PROFILE=dev|single|cluster`.
- **Edge (Traefik v3.7.15).**
  - TLS Let's Encrypt, redirect ke HTTPS, minimal TLS 1.2.
  - Rate limit 100/dtk per IP (burst 200) dan maks 20 koneksi WebSocket per IP.
  - Batas body 256 KB (API) dan 10 MB (upload), header keamanan, serta timeout dan batas header.
  - Header alias dibuang dan karakter path ter-encode berbahaya ditolak.
  - Di profil single hanya path API yang publik; `/auth/v1` dan Studio tertutup.
- **Pooler (PgBouncer 1.24).** PostgREST, GoTrue, Storage, Meta, dan Studio lewat pooler. Realtime dan migrasi tetap langsung ke DB.
- **Valkey 9.0.7.** Berpassword, tanpa persistence.
- **Network.** `edge` / `app` / `data` (internal) dan `egress`. Kong hanya mempercayai `X-Forwarded-For` dari subnet edge.
- **Hardening container.**
  - Semua read-only, `cap_drop: ALL`, `no-new-privileges`, dan punya batas CPU/memori/pids.
  - Semua non-root, kecuali entrypoint Postgres.
  - Image di-pin tag + digest.
- **Rahasia.**
  - Docker secrets dipakai di semua profil; `make gen-secrets` memindahkan rahasia dari `.env` lama secara otomatis.
  - auth-bridge mendukung `JWT_SECRET_FILE`.
  - Edge Functions tidak lagi memegang URL DB superuser.
- **Konfigurasi lain.** CORS diatur lewat env (dev `*`, single kosong). Batas tenant Realtime lewat env; update tenant yang sudah ada dilakukan di Tahap 2.

**Tahap 1: verifikasi**
- **Stack baru dari nol** (first boot) dan **stack yang sudah berisi data** (data tetap utuh):
  - 141 pgTAP, smoke 21/21, smoke-dummy 16/16, dan unit test Go;
  - Flutter: analyze, 44 unit/widget, integration 7 + 4, dan E2E Windows 2.
- **Edge:**
  - 429 saat burst lalu pulih, 413 untuk body > 256 KB, 400 untuk `%2F`;
  - header keamanan lengkap dan redirect HTTP → HTTPS;
  - TLS 1.1 ditolak, path non-API 404, Studio hanya lewat port admin.

**Tahap 2: yang dikerjakan** (migrasi `0012`–`0017`)
- **Rate limit berlapis (0012).**
  - Beberapa jendela per aksi (post 5/menit + 50/hari), dengan aksi baru: buat room, upload, ekspor data.
  - `trust_level`: akun baru ×0,5, akun tepercaya ×2.
  - HTTP 429 membawa `Retry-After`, body tetap kompatibel dengan app lama, dan pelanggaran dicatat ke log.
  - Batas dan pengaturan bisa diubah tanpa deploy (`private.settings`).
- **Moderasi & admin (0013).**
  - Status konten `visible` / `held` / `hidden` diterapkan lewat RLS, sehingga tidak bocor lewat Realtime.
  - Admin memakai akun terpisah dengan 2FA (`aal2`), dalam 5 peran.
  - API admin (`admin_api`) mencakup antrean berprioritas, tindak konten, sanksi bertingkat, ban, pencabutan sesi, trust/verifikasi, kata terlarang, pengaturan, dan arsip regulator dengan *legal hold*.
  - Audit log tidak bisa diubah, dan akses ke data pribadi dicatat.
  - Pre-request PostgREST menolak user yang di-ban dan JWT yang sesinya dicabut.
- **Integritas konten (0014).**
  - `client_id` idempoten untuk post (RPC baru `create_post`) dan komentar (`create_comment` kompatibel dengan versi lama).
  - Validasi: karakter kontrol; maksimal 3 link, 10 mention, dan 10 kode saham.
  - Anti-duplikat: konten sama ke-3 dalam 5 menit ditolak.
  - User yang di-mute tidak bisa mengirim konten.
  - Syarat & Ketentuan (`legal_documents`, `user_consents`) wajib disetujui, ditegakkan di server.
- **Privasi (0015).**
  - Mute user/kata/saham disaring di `get_feed`.
  - `delete_my_account`: konten diarsipkan untuk regulator, profil dianonimkan, sesi dicabut.
  - `export_my_data`.
  - `upsert_olt_profile`: akun baru mulai di trust 0, akun yang dihapus dibuat ulang bersih, status ban ikut dikembalikan.
  - Retensi dan promosi akun baru dijalankan `pg_cron` (sekali per cluster).
- **Role DB (0016, superuser).**
  - Batas koneksi dan `idle_in_transaction` untuk role bawaan.
  - `service_role` `statement_timeout` 15 dtk.
  - Role monitoring `olt_monitor`.
  - Runner migrasi kini mendukung penanda `-- olt:run-as=supabase_admin`.
- **Perbaikan (0017).** Izin pre-request untuk `service_role`. Tanpa izin ini exchange token gagal; masalahnya terdeteksi lewat uji HTTP lalu diperbaiki.

**Tahap 2: verifikasi**
- **pgTAP 255** (141 lama + 114 baru, file 010–014).
- **Uji HTTP:**
  - 429 + `Retry-After: 59`;
  - JWT yang sesinya dicabut ditolak dengan 401, JWT baru diterima.
- **Regresi:**
  - smoke 21/21, smoke-dummy 16/16, dan tes Go;
  - Flutter: analyze, 44 unit/widget, integration 7 + 4;
  - E2E Windows 2.
- **Teks tes dibuat unik** di integration/E2E, supaya tidak tertolak aturan anti-duplikat.

**Tahap 2: dilanjutkan di tahap lain**
- **Tahap 3.** ✅ auth-bridge menolak exchange untuk user yang di-ban (`403 user_banned`, dari field `banned` milik `upsert_olt_profile`).
- **F1.**
  - `admin_api` diekspos lewat PostgREST (`PGRST_DB_SCHEMAS`) + filter header di Traefik.
  - Panel admin.
  - ✅ Worker `storage_cleanup_queue` (file akun yang dihapus): layanan `services/janitor`, migrasi `0060_storage_cleanup`.
  - Notifikasi untuk konten `held` (`held` disetel service `moderation`).
- **Tahap 4–5.** Flutter:
  - `create_post` / `create_comment` dengan `client_id`;
  - pesan error baru (`user_muted`, `consent_required`, `duplicate_content`, `too_many_*`, `session_revoked`);
  - UI persetujuan S&K, mute, hapus/ekspor akun.
- **Tahap 6.**
  - Batas payload Realtime 64 KB: seeding self-host Realtime v2.143.3 membuat ulang tenant di setiap start dengan default 3000 KB, jadi perlu pengelolaan tenant sendiri.
  - Login role `olt_monitor` untuk exporter.
  - `retention.archive_days` (default sementara 5 tahun) ditetapkan legal.
- **Catatan uji lokal.** Batas `/exchange` auth-bridge (30/menit per IP) bisa terpicu bila banyak tes dijalankan beruntun dari satu IP. ✅ Tahap 3: batas kini di Valkey. Tes dari container `tools` dan dari host memakai kuota terpisah. Batas per user di profil dev 60/menit.

**Tahap 3: yang dikerjakan** (auth-bridge 0.3.0)
- **State bersama di Valkey.**
  - Rate limit sliding window (Lua + sorted set): 30/menit per IP dan 10/menit per user OLT (profil dev 60).
  - Cache hasil verifikasi per hash token (60 dtk). Token tidak pernah disimpan.
  - Bila Valkey mati: rate limit memakai limiter in-memory, cache dilewati, error dihitung di metrik, dan log dibatasi sekali per menit.
  - `VALKEY_ADDR` wajib saat `APP_ENV=production`.
- **Circuit breaker ke OLT.**
  - Terbuka setelah 5 kegagalan berturut-turut, lalu cooldown 30 dtk dan satu request uji (half-open).
  - Token yang ditolak OLT dihitung sukses. Request yang dibatalkan klien tidak dihitung.
- **Retry PostgREST**: maksimal 3 kali dengan backoff eksponensial + jitter, khusus error jaringan/5xx.
- **User di-ban** → `403 user_banned`, tidak di-cache.
- **JWT minimal**: tanpa email, username, dan `olt_user_id`.
- **Port ops internal 9100** (tidak lewat Kong, tidak dipublikasikan):
  - `/metrics`: format Prometheus, tanpa dependensi luar;
  - `/livez`;
  - `/readyz`: PostgREST wajib; Valkey dan breaker OLT opsional (gagal → `degraded`, bukan `not_ready`, supaya semua replika tidak ditarik bersamaan).
- **Default adapter OLT = Protokol v1** (`request_id` UUID per login). Produksi cukup mengisi `OLT_WS_URL`. Profil OLT dummy kini juga hanya mengisi `OLT_MODE` + `OLT_WS_URL`.
- **IP klien.** Bila semua hop X-Forwarded-For berupa IP privat, dipakai hop paling kiri. Sebelumnya dipakai IP Kong, sehingga semua klien internal berbagi satu kuota.
- **Toolchain Go 1.24.5 → 1.27.3.** Go 1.24 sudah tidak menerima patch keamanan, dan go-redis butuh Go ≥ 1.26. Dependensi baru:
  - `go-redis` v9.23.0 (BSD-2-Clause);
  - `miniredis` (MIT), khusus tes.
- **Build image deterministik.** Sebelumnya `up --build` me-restart PgBouncer, auth-bridge, dll. di setiap `up`, walau tidak ada yang berubah. Dua penyebab dan perbaikannya:
  1. Bug BuildKit menulis alamat pointer di riwayat `EXPOSE`. Perbaikan: `EXPOSE` dihapus dari Dockerfile.
  2. Provenance attestation berisi timestamp. Perbaikan: `BUILDX_NO_DEFAULT_ATTESTATIONS=1` di Makefile dan make.ps1. Opsi compose `provenance: false` tidak berefek di Compose 2.39.

  Sekarang `up` kedua tidak membuat ulang container apa pun.

**Tahap 3: verifikasi**
- **Unit test Go:**
  - breaker (termasuk request uji yang dibatalkan);
  - limiter dan cache Valkey (miniredis, dibagi antar instance, fallback);
  - metrik;
  - server: ban, batas per user, readiness, metrik, IP klien;
  - retry PostgREST;
  - default Protokol v1.
- **Uji langsung di stack:**
  - `/livez`, `/readyz`, `/metrics` → 404 lewat Kong; port 9100 tidak terbuka ke host;
  - key Valkey berupa hash;
  - X-Forwarded-For palsu dari host dibuang Traefik;
  - OLT dummy dimatikan: 5× `503` (±4 dtk), lalu `503` dalam 0,2 dtk (breaker terbuka), readiness `degraded`, `olt_breaker_open 1`;
  - OLT hidup lagi: setelah cooldown, exchange `200`, breaker tertutup, readiness `ready`.
- **Regresi:**
  - pgTAP 255;
  - smoke 23/23 (+2: exchange user di-ban → 403; JWT lama user di-ban ditolak PostgREST), smoke-dummy 16/16;
  - Flutter: analyze, 44 unit/widget, integration 7 + 4, E2E Windows 2.
- **E2E `app_test`** tidak lagi menunggu post seed `$ANTM` muncul di urutan teratas feed (rapuh setelah ada post baru), cukup kartu post pertama.

**Tahap 3: dilanjutkan di tahap lain**
- **Tahap 6.**
  - Prometheus men-scrape `auth-bridge:9100/metrics`, dengan alert untuk breaker terbuka, lonjakan `valkey_errors_total`, dan rasio 429.
  - Provenance/SBOM dibuat di CI saat image di-push ke registry, bukan di build lokal.

**Permintaan tambahan 29 Okt 2026: centang ala WhatsApp, mengetik di daftar chat, polling, kode bersih**
- **Database** (migrasi `0018_chat_receipts`, `0019_polls`; ditulis tanpa komentar; migrasi lama tidak diubah karena dikunci checksum):
  - `chat_members.last_delivered_at`; RPC `mark_rooms_delivered` dan `mark_room_read` (kini *security definer*) menyiarkan `receipt` dari server lewat `realtime.send`.
  - Hak `UPDATE last_read_at` langsung dicabut, sehingga tanda terima tidak bisa dipalsukan klien.
  - `get_my_rooms.last_message_status` dihitung di server (grup: semua anggota). Room saham tidak dilacak.
  - Polling:
    - tabel `post_polls`, `post_poll_options`, `post_poll_votes` (RLS aktif, tidak bisa dibaca langsung);
    - `create_post(..., p_poll)` dalam satu transaksi, `vote_poll` (invoker, tunduk RLS post);
    - counter lewat trigger, rate limit `poll_vote`;
    - hasil tersembunyi sampai memilih, polling selesai, atau bagi pembuat;
    - ekspor data memuat polling dan suara.
- **Flutter** (`rendezvous_community`):
  - Struktur per fitur (`app` / `core` / `shared` / `features/<fitur>/{domain,data,presentation}`) dan cubit dipisah dari widget.
  - `RoomChannelHub`: satu channel per room dengan ref-count, dibagi oleh daftar chat dan room.
  - Presence dipindah dari channel global `online` ke channel room, sehingga tidak ada lagi siaran daftar semua user online ke semua klien.
  - `DeliveryTracker` di tingkat aplikasi; composer memakai `create_post` + `client_id` per draf; editor polling dan `CommunityPollView`.
  - Pemetaan error per kode stabil, misalnya `poll_closed` dan `duplicate_content`.
- **Kode tanpa komentar:**
  - Semua Dart dan Go dibersihkan memakai scanner resmi (`package:analyzer`, `go/scanner`), sehingga string dan directive (`// ignore:`, `//go:`) aman.
  - Penjelasan dipindah ke README.
- **Build image deterministik tetap terjaga:** hanya auth-bridge 0.3.1 dan dummy-olt 0.1.2 yang dibuat ulang.
- **Verifikasi:**
  - pgTAP 302 (+26 polling, +21 tanda terima);
  - Flutter: analyze bersih, 87 unit/widget (sebelumnya 44); integration 8 + 4, termasuk centang terkirim → dibaca dan polling ke backend nyata; E2E Windows 2;
  - smoke 23/23, smoke-dummy 16/16, tes Go.

**Perbaikan 30 Okt 2026: centang berhenti di ✓, badge chat belum dibaca**
- **Akar masalah (Realtime, bukan aplikasi):**
  - Region node Realtime default `local`, sedangkan tenant hasil seed self-host dikunci `us-east-1`.
  - Pemeriksaan *rebalance* (tiap `REBALANCE_CHECK_INTERVAL_IN_MS`, default 10 menit) menganggap tenant ada di region yang salah, lalu mematikan koneksi DB tenant (`Tenant realtime-dev has been terminated: {:shutdown, :rebalancing}`).
  - Ikut mati: replikasi *Broadcast Changes* yang membawa `realtime.send` dari database. Slot replikasinya *temporary*, jadi broadcast selama jeda hilang. Replikasi baru hidup lagi saat ada klien yang join channel baru. Pesan tetap mengalir, tetapi tanda terima tidak sampai, tanpa error di klien.
- **Bukti:**
  - Log 29–30 Okt: pola terminate tiap ±10 menit setelah inisialisasi.
  - 01:06:55 tenant dimatikan dan slot `supabase_realtime_messages_replication_slot_` hilang dari `pg_replication_slots`.
  - Reproduksi dipercepat (`REBALANCE_CHECK_INTERVAL_IN_MS=20000`, langganan ditahan 45 dtk):
    - sebelum perbaikan, receipt "dibaca" tidak pernah diterima;
    - sesudah perbaikan, receipt diterima dan tidak ada rebalance.
- **Perbaikan:**
  - `REGION: us-east-1` di service `realtime` (`docker/compose.yml`, ikut ke `stack.cluster.yml`).
  - Pengaman di klien: saat channel `room:<id>` tersambung ulang, room memuat ulang anggota (digabung, tanda terima tidak pernah mundur) dan daftar chat memuat ulang `get_my_rooms`. Broadcast yang terlewat karena restart Realtime atau jaringan putus ikut terkoreksi.
- **Catatan perilaku:** ✓ tetap satu bila penerima tidak sedang membuka aplikasi. Itu benar seperti WhatsApp; ✓✓ abu-abu muncul begitu aplikasi penerima terbuka.
- **Badge tab chat** (migrasi `0020_chat_unread_badge`):
  - RPC `get_unread_chat_count`: jumlah chat DM/grup yang tidak dibisukan dan punya pesan belum dibaca dari orang lain. Pesan terhapus dan room saham tidak dihitung.
  - Widget `CommunityChatBadge` memuat ulang saat ada notifikasi baru untuk user (yang dibuat server hanya untuk DM/grup yang tidak dibisukan, sehingga room saham ramai tidak memicu permintaan) dan saat room dibaca, dibisukan, atau ditinggalkan di perangkat ini.
- **Verifikasi:**
  - pgTAP 314 (+12 badge);
  - Flutter: analyze bersih, 101 unit/widget (+14), integration 9 (+1 badge ke backend nyata).

**Tahap 1: sengaja ditunda**
- **WAL archiving** → Tahap 6, bersama WAL-G. Image DB perlu ditambah WAL-G.
- **Profil cluster lengkap** → Tahap 7.
- **Log JSON Kong dan `correlation-id`** → Tahap 6 (observabilitas).

## Ringkasan

| Tahap | Isi utama | Perkiraan |
|---|---|---|
| 1. Infrastruktur | 3 profil, Traefik, PgBouncer, Valkey, network edge/app/data, hardening container, Docker secrets, `gen-secrets` | 8–10 hari |
| 2. Database | rate limit multi-jendela + `trust_level`, `client_id` post/komentar, anti-spam, role & timeout, audit log, moderasi (ban, mute, moderator), revoke sesi, UU PDP | 8–10 hari |
| 3. auth-bridge | rate limit & cache di Valkey, circuit breaker, revoke, metrik, readiness, `*_FILE` | 2,5–3 hari |
| 4–5. Flutter | secure storage, `client_id`, timeout & isolasi, upload aman, HTTPS, link aman, UI moderasi, hapus/ekspor akun | 7–8 hari |
| 6. Hardening | upload lewat Edge Function, observabilitas, backup PITR + uji restore, CI, skrip host, uji keamanan/limit/beban/chaos, dokumen | 17–20 hari |
| 7. Multi-node | stack Swarm, Realtime cluster, storage S3, replica DB, uji multi-node | 5–8 hari* |
| **Total** | | **± 48–59 hari kerja** (10–12 minggu) |

\* Tergantung spesifikasi cluster (lihat keputusan no. 1).

**Yang sudah kuat dan tinggal dipertahankan:**
- RLS di semua tabel `public` & `private`, dan ada tes yang gagal kalau tabel baru tanpa RLS.
- `anon` tidak punya hak tabel maupun RPC. Email dan `olt_user_id` tidak terbaca user.
- Semua fungsi `SECURITY DEFINER` punya `search_path` eksplisit, dan tidak ada fungsi yang bisa dieksekusi `PUBLIC`.
- Rate limit DB berbasis tabel (bisa diubah tanpa deploy) dan filter kata.
- Pesan chat idempoten lewat `client_id`.
- JWT 15 menit dengan refresh otomatis. auth-bridge tidak menerima password, tidak mencatat token, dan berhenti dengan graceful saat SIGTERM.
- Signup GoTrue mati, disclaimer tampil, dan `RendezvousCommunity.initialize()` tidak memblokir app host.
- Tes yang sudah ada: 141 pgTAP, smoke 21 + 16 skenario, unit/widget/integration Flutter, E2E Windows.

### Yang harus diganti (bukan sekadar ditambah)

1. **Edge:** Caddy (override produksi) diganti Traefik di semua profil.
2. **File compose:** `docker-compose.yml` + override menjadi `compose.yml` (dasar) + `compose.dev.yml` / `compose.prod.yml` / `stack.cluster.yml`. Nama target Makefile tetap; `PROD=1` menjadi `PROFILE=single`, dengan alias lama dipertahankan.
3. **auth-bridge:** rate limit dan cache di memori proses dipindah ke Valkey. auth-bridge jadi butuh Valkey untuk jalan.
4. **Upload:** jalur Flutter → Storage langsung menjadi Flutter → Edge Function `upload-image` → Storage. Edge Function memeriksa magic bytes, menghapus EXIF, dan menegakkan kuota. Policy INSERT langsung dari user dicabut, dan GIF tidak diterima lagi.
5. **Moderasi:** sekarang lewat Studio. Karena Studio dimatikan di produksi, moderasi pindah ke RPC dan UI moderator di app.
6. **Backup:** `pg_dump` harian diganti WAL-G (PITR) + restic (file storage, snapshot mingguan/bulanan), terenkripsi dan disimpan di luar server.
7. **Batas Realtime:** tenant masih memakai default 200 koneksi bersamaan. Ini **penghambat produksi**, jadi batasnya harus dinaikkan sesuai kapasitas.
8. **Klaim JWT:** `olt_user_id` dan `username` dikeluarkan dari JWT bila tidak dipakai.

## Keputusan yang perlu dikonfirmasi

Setiap poin punya usulan default. Balas "setuju semua" atau sebutkan nomor yang ingin diubah.

1. **Spesifikasi cluster.**
   - Masalahnya: addendum merujuk "bagian 8 PROMPT.md" untuk Docker Swarm. Bagian 8 di `prompt.md` kita berisi tahapan kerja, dan Tahap 7 lama ("panduan integrasi") sudah selesai di [INTEGRATION.md](INTEGRATION.md).
   - **Default:** saya rancang sendiri dengan isi berikut:
     - Swarm 3 node.
     - Postgres primary + 1 replica streaming, dengan failover manual yang terdokumentasi.
     - Realtime cluster lewat DNS.
     - Storage di SeaweedFS (Apache 2.0).
     - Valkey primary + replica.
   - Alternatif: kirimkan bagian spesifikasi yang hilang.
2. **Lisensi monitoring.**
   - Masalahnya: Grafana dan Loki berlisensi **AGPL-3.0**. Addendum menyebut Loki Apache 2.0, padahal itu sudah tidak berlaku sejak 2021. Promtail juga AGPL dan sudah EOL.
   - **Default:** stack yang seluruhnya permisif: Prometheus + Alertmanager + VictoriaLogs + Grafana Alloy + Perses (semua Apache 2.0).
   - Alternatif: Grafana + Loki khusus untuk internal ops (tidak melayani user, tanpa modifikasi).
3. **Pooler.** **Default:** PgBouncer (ISC), image dibangun dari Alpine yang di-pin. Alternatif: Supavisor (Apache 2.0), yang lebih berat.
4. **Backup.** **Default:** WAL-G (Apache 2.0) untuk PITR, dan restic (BSD-2) untuk file storage serta snapshot mingguan/bulanan. Targetnya object storage S3-compatible di Indonesia; kredensial menyusul.
5. **CI.** **Default:** GitHub Actions, karena remote repo ada di GitHub.
6. **Kanal alert.** **Default:** Telegram + email lewat Alertmanager.
7. **Retensi data (UU PDP).** Usulan default berikut perlu dicek tim compliance:

   | Data | Disimpan |
   |---|---|
   | Notifikasi | 90 hari |
   | Konten yang dihapus user | 30 hari, lalu dihapus permanen |
   | Arsip moderasi | 180 hari |
   | Log aplikasi | 30 hari |
   | Audit log | 1 tahun |
   | Pesan chat | selama akun aktif; ikut terhapus saat akun dihapus |

8. **Lingkungan uji.**
   - Pertanyaan: apakah sudah ada VPS staging + domain?
   - Kalau belum, semua diverifikasi di Docker Desktop. Item yang butuh server asli ditandai "verifikasi di staging" (lihat [bagian di bawah](#yang-tidak-bisa-dibuktikan-di-laptop)).
9. **Cara jalan.** **Default:** per tahap 1 → 7, berhenti di akhir tiap tahap untuk konfirmasi (sesuai prompt). Alternatif: dikerjakan berurutan tanpa jeda.
10. **Housekeeping.** `prompt.md` dipindah ke `docs/PROMPT.md`, karena addendum merujuk path itu. `add-prompt.md` di root dihapus, karena isinya sudah ada di `docs/PROMPT-PRODUCTION.md`.

## Temuan per bagian addendum

### 1. Profil deploy & komponen wajib

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 1.1 | Profil dev / single / cluster dengan image, nama service, dan env yang sama | 🟡 | Ada `docker-compose.yml` + override `prod` (Caddy) + `dummy-olt`. → `compose.yml` + `compose.dev.yml` + `compose.prod.yml` + `stack.cluster.yml` (kerangka). Makefile memakai `PROFILE=…`. | M |
| 1.2 | Traefik sebagai edge | ❌ | Dev langsung ke Kong, prod lewat Caddy. → Traefik v3 (MIT) di semua profil. | M |
| 1.3 | Pooler; aplikasi tidak konek langsung ke Postgres | ❌ | Supavisor sengaja dilepas; PostgREST, GoTrue, Storage, Meta, dan Edge Functions konek langsung. → PgBouncer. Realtime (replikasi logis) dan migrasi tetap langsung, dicatat sebagai pengecualian. | M |
| 1.4 | Valkey | ❌ | Belum ada. → Valkey 8 (BSD-3) dengan password. | S |
| 1.5 | Storage backend `file`, S3-ready lewat env | 🟡 | `STORAGE_BACKEND=file` ✅, tetapi env S3 belum diteruskan. → env S3 + panduan pindah ke SeaweedFS. | S |
| 1.6 | WAL archiving aktif | ❌ | `archive_mode=off` (`wal_level=logical` ✅). Image `supabase/postgres` tidak berisi WAL-G maupun pgBackRest, jadi perlu image turunan. | bagian 7 |
| 1.7 | `docs/scaling.md` | ❌ | → panduan migrasi single → cluster. | M |

### 2. Stateless & konsistensi

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 2.1 | Sesi hanya JWT; cache verifikasi OLT di Valkey | 🟡 | JWT stateless ✅. Cache verifikasi masih di memori proses auth-bridge. → Valkey dengan TTL pendek. | S |
| 2.2 | Tanpa file lokal; folder sementara di tmpfs | 🟡 | Upload langsung ke Storage API ✅. Container belum read-only/tmpfs. → bagian 4.3. | – |
| 2.3 | `client_id` idempoten untuk aksi tulis | 🟡 | Pesan chat ✅ (unik `(sender_id, client_id)`, `send_message` idempoten, kirim ulang di UI). Post ❌ (insert tabel) dan komentar ❌ (`create_comment`). `/exchange` aman diulang ✅. → kolom + constraint unik + parameter opsional, supaya app lama tetap jalan. | M |
| 2.4 | Job terjadwal sekali per cluster | ❌ | Belum ada job; backup lewat `make backup` (manual/cron host). `pg_cron` sudah ter-preload di image ✅ → dipakai untuk job DB; job lain memakai lock. | S |
| 2.5 | Graceful shutdown | 🟡 | auth-bridge ✅ (SIGTERM → `Shutdown`). → `stop_grace_period` per service, drain di Traefik/Kong. | S |
| 2.6 | Konfigurasi 12-factor, gagal start dengan pesan jelas | 🟡 | auth-bridge ✅ (validasi config; mode mock ditolak saat `APP_ENV=production`). Compose belum memakai `${VAR:?pesan}`. Docker secrets → 4.4. | S |
| 2.7 | Timestamp UTC, tampil sesuai zona user | ✅ | `timestamptz` di semua tabel; Flutter menampilkan zona perangkat. NTP → skrip host (4.1). | – |

### 3. Rate limit berlapis

| # | Lapisan | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 3.1 | Edge: per IP 100 req/dtk (burst 200), body 10 MB upload / 256 KB API | ❌ | Caddy tanpa limit. → middleware Traefik `rateLimit` dan `buffering` per route. | 1.2 |
| 3.2 | Edge: maks 20 koneksi WebSocket per IP | ❌ | → Traefik `inFlightReq` di route Realtime. | 1.2 |
| 3.3 | auth-bridge per IP & per `olt_user_id` (Valkey, sliding window) | 🟡 | Per IP 30/menit, fixed window, di memori. → Valkey: 30/menit per IP, 10/menit per user. | M |
| 3.4 | GoTrue | ✅ | Signup, email, dan anonymous mati. Client tidak memakai GoTrue sama sekali → usul: `/auth/v1` ditutup di edge. | S |
| 3.5 | DB: `check_rate_limit(user_id, action)` | 🟡 | Trigger + tabel `private.rate_limits` ✅. Kurang: multi-jendela (50 post/hari), aksi baru, user baru lebih ketat, `trust_level`, pencatatan pelanggaran, dan fungsi yang bisa dipanggil dari RPC. | M |
| 3.6 | Realtime: koneksi, channel, event, payload | 🟡 | Masih default tenant: **200 koneksi**, 100 event/dtk per tenant, 100 channel per klien. → `TENANT_MAX_*` + update tenant. Batas 10 event/dtk **per klien** tidak tersedia bawaan → throttle di klien + batas koneksi di edge. Batas payload 64 KB masih perlu dicek. | M |
| 3.7 | Storage: ukuran, jenis, kuota | 🟡 | Batas per bucket ✅ (avatar 2 MB, lampiran 5 MB). GIF masih diterima ❌, kuota 50 upload/hari ❌. → bagian 4.7. | – |
| 3.8 | Anti-spam | 🟡 | Filter kata (mask/block, tabel) ✅. Konten sama 3× dalam 5 menit ❌, maks 3 link per post ❌. | S |
| 3.9 | 429 + `Retry-After`, pesan ramah di Flutter | 🟡 | auth-bridge ✅. DB sudah mengembalikan HTTP 429 tetapi tanpa `Retry-After` → error `PGRST` dengan header. Pesan ramah di Flutter ✅. | S |
| 3.10 | Pelanggaran tercatat di log & metrik | ❌ | → `RAISE LOG` di DB (exception membatalkan insert ke tabel), metrik 429 dari Traefik dan auth-bridge. | bagian 6 |

Batas per user di DB, sekarang vs addendum:

| Aksi | Sekarang | Addendum |
|---|---|---|
| Post | 5/menit | 5/menit + 50/hari |
| Komentar | 20/menit | 20/menit |
| Pesan chat | 30/menit | 30/menit |
| Like | 120/menit | 60/menit |
| Report | 10/jam | 10/jam |
| Follow | 60/menit | 30/jam |
| Buat room | – | 10/jam |
| Upload | – | 50/hari |

### 4.1 Jaringan & server

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.1.1 | Hanya port 80/443 publik; Studio hanya lewat VPN | 🟡 | Prod: Caddy 80/443 dan Kong di `127.0.0.1` ✅; DB dan Realtime tidak di-expose ✅. Studio tetap berjalan di prod (hanya tidak dipublikasikan). → Studio di profil `admin` dan default mati; akses lewat WireGuard/SSH tunnel. | S |
| 4.1.2 | Network `edge` / `app` / `data` | 🟡 | Sekarang `internal` + `public`; beberapa service masuk `public` untuk egress. Kong prod `KONG_TRUSTED_IPS=0.0.0.0/0`. → 3 network + network egress khusus; trusted IP hanya subnet edge. | M |
| 4.1.3 | Skrip hardening host Ubuntu | ❌ | Baru berupa panduan manual. → `scripts/host/harden-ubuntu.sh` (UFW, SSH key-only, unattended-upgrades, CrowdSec, chrony) + panduan WireGuard. | M |
| 4.1.4 | Docker daemon tidak lewat TCP; log rotation | 🟡 | Rotasi log per container ✅. → `daemon.json` di skrip host. | S |

### 4.2 TLS & HTTP

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.2.1 | HTTPS Let's Encrypt, TLS ≥ 1.2, redirect ke HTTPS | 🟡 | Sudah di Caddy ✅ → dipindah ke Traefik (min TLS 1.2, utamakan 1.3). | 1.2 |
| 4.2.2 | Security headers | 🟡 | HSTS, nosniff, Referrer-Policy ✅. `X-Frame-Options` dan CSP ❌. | S |
| 4.2.3 | CORS hanya origin yang diizinkan | ❌ | Plugin `cors` Kong tanpa daftar origin, jadi `*`. → env `CORS_ALLOWED_ORIGINS` (dev `*`, prod hanya origin web). | S |
| 4.2.4 | Timeout di edge | ❌ | Masih default. → timeout request, idle WebSocket, dan batas header di Traefik. | S |

### 4.3 Container hardening

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.3.1 | Tag + digest | 🟡 | Semua tag di-pin ✅; digest baru ada di base image auth-bridge. → `image@sha256:…` untuk semua + skrip pembaruan. | S |
| 4.3.2 | Non-root | 🟡 | Sudah non-root: kong, gotrue, postgrest, realtime, imgproxy, auth-bridge. Masih root: studio, storage, meta, edge-runtime, tools; db mulai sebagai root lalu turun ke `postgres` via gosu. | L (4.3.2–4.3.4) |
| 4.3.3 | `read_only` + tmpfs, `cap_drop: [ALL]`, `no-new-privileges` | ❌ | Belum ada. Beberapa image mungkin butuh pengecualian, yang akan dicatat. | ↑ |
| 4.3.4 | Batas CPU/memori dan `pids_limit` | ❌ | Belum ada. | ↑ |
| 4.3.5 | Healthcheck + `restart: unless-stopped` | ✅ | Semua service. | – |
| 4.3.6 | Scan Trivy di CI | ❌ | → bagian 8. | – |
| 4.3.7 | SBOM + daftar lisensi | 🟡 | Audit lisensi Flutter ✅ (`make license-audit`). Go module dan image ❌, SBOM ❌. → `go-licenses` + Trivy CycloneDX. | S |

### 4.4 Secrets

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.4.1 | Tidak ada secret di repo, image, atau log | ✅ | `.env` di-gitignore, image tanpa secret, token tidak di-log. | – |
| 4.4.2 | Produksi memakai Docker secrets (`*_FILE`) | ❌ | Produksi masih memakai `.env`. Banyak image Supabase tidak mendukung `*_FILE`, jadi caranya per service: `@file` (PostgREST), `POSTGRES_PASSWORD_FILE`, wrapper shell, dan dukungan `*_FILE` di auth-bridge. | L |
| 4.4.3 | `make gen-secrets` | 🟡 | `gen-keys` sudah membuat JWT secret 64 karakter, anon/service key, dan password DB. Kurang: Erlang cookie, password Valkey, dan output file Docker secrets. | S |
| 4.4.4 | `service_role` hanya untuk service internal | 🟡 | Flutter hanya memakai anon key ✅. Edge Functions menerima `SUPABASE_DB_URL` sebagai superuser `postgres` → role terbatas. | S |
| 4.4.5 | Prosedur rotasi | 🟡 | Ada di `PRODUCTION.md` §6, tetapi tanpa masa transisi. **Catatan penting:** `ANON_KEY` adalah JWT yang ditandatangani `JWT_SECRET` dan tertanam di app yang sudah rilis, jadi rotasi JWT secret mematikannya. → masa transisi (Kong menerima key lama & baru), atau pindah ke API key baru Supabase (`sb_publishable_…`). Perlu diuji. | M |
| 4.4.6 | gitleaks pre-commit | ❌ | → hook + `make install-hooks` + job CI. | S |

### 4.5 Database

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.5.1 | RLS di semua tabel + tes yang gagal untuk tabel baru tanpa RLS | ✅ | `tests/001` (public & private); anon tanpa hak tabel/RPC. | – |
| 4.5.2 | Role terpisah, least privilege, cabut hak `PUBLIC` | 🟡 | anon / authenticated / service_role ✅. Hak `EXECUTE` dari `PUBLIC` sudah dicabut (0 fungsi terbuka) ✅. Role migrasi ❌ (migrasi jalan sebagai superuser), role monitoring read-only ❌. | M |
| 4.5.3 | `SECURITY DEFINER`: `search_path`, validasi input, cek `auth.uid()` | 🟡 | `search_path` eksplisit di semua fungsi (0 pelanggaran) ✅. Validasi input dan cek `auth.uid()` → review menyeluruh + tes. | S |
| 4.5.4 | `statement_timeout`, `idle_in_transaction_session_timeout`, batas koneksi per role | 🟡 | Default image Supabase: anon 3 dtk, authenticated & authenticator 8 dtk ✅. `service_role` tanpa timeout, idle-in-transaction hanya di role auth, dan belum ada batas koneksi. | S |
| 4.5.5 | Query berparameter | ✅ | SQL dinamis hanya `format(%I)` + `USING`. | – |
| 4.5.6 | Email & `olt_user_id` tidak terekspos | ✅ | Column grant + tes; email di `private.user_private`. Klaim JWT → 4.6. | – |
| 4.5.7 | Audit log aksi penting | 🟡 | Baru ada arsip konten yang dihapus (`private.content_archive`). → `private.audit_log` untuk hapus konten, ban, perubahan role, dan aksi moderator. | M |

### 4.6 Auth & token

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.6.1 | JWT pendek + refresh, klaim minimal | 🟡 | JWT 15 menit, refresh otomatis 60 dtk sebelum habis ✅. Klaim masih memuat `olt_user_id` dan `username` → dikurangi. | S |
| 4.6.2 | Verifikasi OLT: timeout, circuit breaker, cache Valkey | 🟡 | Timeout 5 dtk ✅. Circuit breaker ❌; cache masih di memori. | M |
| 4.6.3 | Tanpa password, token tidak di-log | ✅ | | – |
| 4.6.4 | Revoke sesi | ❌ | → versi sesi per user; dicek di `db-pre-request` PostgREST dan policy Storage/Realtime; auth-bridge menolak user yang di-ban. | M |
| 4.6.5 | Signup publik mati | ✅ | Lihat 3.4. | – |

### 4.7 Validasi konten & upload

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.7.1 | Validasi di client & server | 🟡 | Panjang teks di DB ✅. Karakter kontrol, jumlah mention/tag saham, dan URL ❌. | S |
| 4.7.2 | Render teks biasa; link dibuka dengan konfirmasi | 🟡 | Teks biasa ✅; URL belum bisa diklik (aman). → link http(s) bisa diklik dengan dialog konfirmasi, skema lain diblokir. | S |
| 4.7.3 | Upload: JPEG/PNG/WebP saja, magic bytes, ukuran, hapus EXIF, imgproxy | 🟡 | Batas ukuran ✅. GIF masih diizinkan; Storage hanya memeriksa header `Content-Type`; EXIF tidak dihapus; gambar asli disajikan tanpa imgproxy. → Edge Function `upload-image` + validasi di client + tampilan lewat endpoint render (imgproxy). | L |
| 4.7.4 | Nama file UUID | 🟡 | Post & chat ✅; avatar masih `avatar-<timestamp>` → UUID. | S |
| 4.7.5 | `attachments` privat, `avatars` publik | ✅ | Lampiran diunduh dengan JWT lewat endpoint `authenticated`, jadi RLS dicek di setiap request (lebih ketat dari signed URL). Signed URL pendek ditambahkan untuk kasus yang memang butuh URL. | S |

### 4.8 Moderasi & kepatuhan

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.8.1 | Report, block, mute, hapus oleh moderator, ban, antrean moderasi | 🟡 | Report ✅, block ✅, mute room ✅. Mute user ❌, peran moderator dan ban ❌. Antrean `private.report_queue` hanya bisa dibuka lewat Studio, yang akan dimatikan. → role moderator, RPC moderasi, UI antrean di package. | L |
| 4.8.2 | Filter kata & spam diatur tanpa deploy | 🟡 | Kata terlarang ✅ (tabel). Ambang spam → tabel konfigurasi. | 3.8 |
| 4.8.3 | Disclaimer | ✅ | Composer dan detail post. | – |
| 4.8.4 | UU PDP: retensi, hapus akun, ekspor data, log akses data pribadi | ❌ | → retensi lewat `pg_cron`, RPC `delete_my_account` / `export_my_data`, dan `pgaudit` (sudah ter-preload) untuk akses `private.user_private`. | M |
| 4.8.5 | Data disimpan di Indonesia | – | Keputusan hosting; dicatat di checklist. | – |

### 4.9 Keamanan client Flutter

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 4.9.1 | Token di secure storage | ❌ | Token hanya di memori. → `flutter_secure_storage` (BSD-3) untuk JWT sosial dengan kunci hash token OLT; di web tetap di memori. | S |
| 4.9.2 | HTTPS/WSS saja; certificate pinning opsional | ❌ | Belum dipaksa. → `http://` ditolak di build release; pinning opsional lewat konfigurasi. | M |
| 4.9.3 | Tanpa service key atau URL internal di build | ✅ | | – |
| 4.9.4 | Log release tanpa token atau isi pesan | ✅ | Package tidak mencetak log. | – |

### 5. Keandalan

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 5.1 | Liveness & readiness | 🟡 | Healthcheck di semua service ✅; auth-bridge punya `/health` (+ `?deep=1`). → `/livez` dan `/readyz` (cek Valkey + PostgREST). | S |
| 5.2 | Retry dengan backoff + jitter | 🟡 | Token manager retry tetap 15 dtk tanpa jitter; auth-bridge → PostgREST tanpa retry. | S |
| 5.3 | Degradasi anggun saat Realtime putus | ✅ | Chat dikirim lewat REST, celah diisi setelah reconnect, banner "Menyambungkan ulang" ✅. Belum diuji chaos (bagian 9). | – |
| 5.4 | Isolasi dari fitur trading OLT | 🟡 | `initialize()` tidak memblokir dan error tidak bocor ke host ✅. Panggilan data belum punya timeout → timeout di semua request + uji "backend sosial mati, halaman trading tetap jalan". | M |
| 5.5 | Kapasitas jam puncak (09:00 WIB) | ❌ | Belum diukur, dan batas Realtime masih 200 koneksi. → uji beban (9.6). | – |

### 6. Observabilitas

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 6.1 | Log JSON + `request_id` lintas service | 🟡 | auth-bridge sudah JSON + `X-Request-Id` ✅. Log Kong berformat `combined` dan request id tidak diteruskan. Postgres `log_min_messages=fatal` menyembunyikan error. → log JSON di edge/Kong, plugin `correlation-id`, level log DB dinaikkan. | M |
| 6.2 | Metrik Prometheus + dashboard | ❌ | → Prometheus, exporter (node, cAdvisor, postgres, redis), metrik Traefik/Kong/Realtime/auth-bridge, dashboard. | L (6.2–6.4) |
| 6.3 | Log terpusat | ❌ | → Alloy + VictoriaLogs (atau Loki; lihat keputusan no. 2). | ↑ |
| 6.4 | Alert | ❌ | → Alertmanager untuk: service down, error rate, disk > 80 %, backup gagal, sertifikat hampir habis, lonjakan 429, replication lag. | ↑ |
| 6.5 | Uptime monitoring dari luar | ❌ | → compose Uptime Kuma (MIT) untuk server terpisah. | S |

### 7. Backup & disaster recovery

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 7.1 | Full backup harian + WAL kontinu (PITR) | ❌ | Baru `pg_dump` lewat `make backup`. → image DB turunan + WAL-G, `archive_timeout` 60 dtk. | L |
| 7.2 | Backup object storage harian | 🟡 | `make backup` membuat tar volume di lokal. → restic. | S |
| 7.3 | Disimpan di luar server, terenkripsi | ❌ | Lokal di `backups/`, tanpa enkripsi. | 7.1–7.2 |
| 7.4 | Retensi harian 7 / mingguan 4 / bulanan 6 | ❌ | Satu tingkat, 14 hari. | 7.1–7.2 |
| 7.5 | `make restore` + uji restore otomatis berkala | 🟡 | `make restore` (pg_restore) ✅. PITR ❌, uji restore berkala ❌ → job mingguan + metrik + alert. | M |
| 7.6 | RPO ≤ 5 menit, RTO ≤ 1 jam, `docs/operations.md` | ❌ | | M |

### 8. CI/CD & rilis

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 8.1 | Pipeline CI | ❌ | Semua tes hanya bisa jalan lewat `make` di lokal. → GitHub Actions: format/lint, analyze + tes Flutter, tes Go, pgTAP, build image + Trivy, cek lisensi, gitleaks. | M |
| 8.2 | Migrasi berurutan dan terlacak | ✅ | `olt_internal.schema_migrations` dengan checksum. | – |
| 8.3 | Migrasi backward-compatible; destruktif tidak otomatis | ❌ | Belum ada aturan tertulis maupun penjaga. → panduan expand → migrate → contract; `migrate` menolak `DROP`/`TRUNCATE`/ubah tipe tanpa persetujuan eksplisit. | S |
| 8.4 | Rolling update + rollback satu perintah | 🟡 | Panduan update ada. → `make deploy SERVICE=… TAG=…`, `make rollback`, tag image = versi/commit. | M |
| 8.5 | Staging dengan konfigurasi sama seperti produksi | ❌ | → profil `single` + env staging + panduan. | S |
| 8.6 | Versioning API/RPC | ❌ | → aturan + konvensi `_v2`. Perubahan di audit ini dibuat kompatibel (parameter opsional). | S |

### 9. Pengujian produksi

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 9.1 | Tes RLS untuk akses silang antar user | 🟡 | 141 tes pgTAP untuk skenario utama ✅; diperluas untuk fitur baru. | M (9.1–9.4) |
| 9.2 | Endpoint internal tidak bisa diakses dari luar | ❌ | → skrip cek port dan route. | ↑ |
| 9.3 | Scan OWASP ZAP | ❌ | → `zap-api-scan` terhadap API. | ↑ |
| 9.4 | Upload file berbahaya | ❌ | → file palsu, polyglot, SVG, EXIF GPS, file kebesaran. | ↑ |
| 9.5 | Rate limit tiap lapisan: 429 lalu pulih | 🟡 | DB dan auth-bridge sudah diuji ✅. Edge, Realtime, Storage, dan pemulihan setelah jendela waktu ❌. | M |
| 9.6 | Uji beban profil single | ❌ | k6 berlisensi AGPL → alat uji beban Go sendiri (koneksi WebSocket + pesan/dtk, p50/p95/p99). | M |
| 9.7 | Chaos ringan | ❌ | → skrip restart DB, Valkey, dan Realtime, lalu verifikasi pulih tanpa kehilangan data. | S |

### 10. Checklist production readiness

| # | Syarat | Status | Sekarang → perubahan | Effort |
|---|---|---|---|---|
| 10 | `docs/production-checklist.md` | 🟡 | `PRODUCTION.md` §8 sudah punya checklist sebagian → dipindah dan dilengkapi sesuai addendum. | S |

## Yang tidak bisa dibuktikan di laptop

Item berikut ditandai "verifikasi di staging" sampai ada server asli:

| Item | Yang dibutuhkan |
|---|---|
| Sertifikat Let's Encrypt asli dan port publik 80/443 | Domain + VPS |
| Backup di luar server | Target S3 atau server lain. Di lokal disimulasikan dengan SeaweedFS sebagai target. |
| Angka kapasitas | Spesifikasi VPS produksi. Angka dari laptop hanya relatif. |
| Isolasi dari fitur trading | Di lokal disimulasikan dengan halaman "trading" tiruan di app contoh; konfirmasi akhir di app OLT asli. |
| Lokasi data, WireGuard, CrowdSec | Server produksi |

## Urutan pengerjaan dan kriteria selesai

1. **Infrastruktur.**
   - `make up PROFILE=dev` dan `PROFILE=single` naik dengan semua service healthy.
   - Semua tes lama tetap lulus.
   - Container ter-hardening dan Studio mati di profil single.
2. **Database.** `make test-db` lulus, termasuk tes untuk fitur baru.
3. **auth-bridge.** Unit test dan smoke lulus, mencakup Valkey, circuit breaker, dan revoke.
4. **Flutter (tahap 4–5).** Analyze bersih; unit, widget, dan integration test lulus; E2E Windows lulus.
5. **Hardening (tahap 6).** Checklist bagian 10 tercentang di profil single, dengan catatan untuk item yang butuh staging.
6. **Multi-node (tahap 7).** Skenario uji multi-node lulus tanpa perubahan kode aplikasi.
