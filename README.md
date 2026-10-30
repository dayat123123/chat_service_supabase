# OLT Social

Fitur sosial & chat untuk **Rendezvous OLT**. Isinya:
- feed saham dengan tag `$KODE`
- komentar berantai tanpa batas kedalaman
- reaksi, `@mention`, follow, dan watch saham
- chat realtime: DM, grup, dan room per saham
- notifikasi
- moderasi: laporan, blokir, rate limit, filter kata

| Bagian | Isi |
|---|---|
| [`docker/`](docker/) | Supabase self-hosted + auth-bridge + Traefik, PgBouncer, Valkey. Profil `dev` / `single` / `cluster`, image di-pin tag + digest |
| [`supabase/`](supabase/) | Migrasi SQL bernomor, seed development, tes pgTAP |
| [`services/auth-bridge/`](services/auth-bridge/) | Go: tukar token login OLT menjadi JWT Supabase (tanpa login dua kali) |
| [`services/dummy-olt/`](services/dummy-olt/) | Go: server WebSocket OLT **tiruan** (token sendiri, data nasabah tiruan) untuk menguji auth-bridge mode websocket dan `customer-adapter`. Hanya development/testing |
| [`services/cs/`](services/cs/README.md) | Go: `customer-adapter` (data nasabah dari OLT untuk chat CS, amankan akun) |
| [`packages/olt_social/`](packages/olt_social/) | Package Flutter (Bloc, freezed) + app [`example/`](packages/olt_social/example/) Windows, Android & web |
| [`apps/cs-console/`](apps/cs-console/README.md) | Flutter web: web CS khusus CS, supervisor, dan admin CS (login + TOTP, ambil tiket, chat, catatan internal, info nasabah, dashboard supervisor, laporan + CSV, pengaturan admin). Produksi: hanya lewat VPN |
| [`docs/INTEGRATION.md`](docs/INTEGRATION.md) | Cara memasang `olt_social` ke aplikasi OLT |
| [`docs/PRODUCTION.md`](docs/PRODUCTION.md) | Deploy VPS (profil `single`), secrets, backup/restore, update versi, moderasi, checklist produksi |
| [`docs/scaling.md`](docs/scaling.md) | Profil deploy dan langkah migrasi single → cluster |
| [`docs/production-audit.md`](docs/production-audit.md) | Audit terhadap addendum produksi + status per tahap |
| [`docs/market-integration.md`](docs/market-integration.md) | Rencana integrasi data pasar & portofolio OLT (menunggu info tim OLT) |
| [`docs/cs-chat/`](docs/cs-chat/README.md) | Customer service lewat chat + matching engine: status tahap, keputusan, model data, akses, API `cs_api`, kebutuhan data OLT, pertanyaan kepatuhan |
| [`docs/archive/`](docs/archive/customer-care/README.md) | Arsip pendekatan ticketing yang dibatalkan (dokumen saja; kodenya sudah dihapus lewat migrasi `0026_care_cancel`) |
| [`docs/PROMPT.md`](docs/PROMPT.md), [`PROMPT-PRODUCTION.md`](docs/PROMPT-PRODUCTION.md), [`PROMPT-FEATURES.md`](docs/PROMPT-FEATURES.md), [`PROMPT-CS-CHAT.md`](docs/PROMPT-CS-CHAT.md) | Spesifikasi proyek: dasar, produksi, fitur lanjutan, dan customer service lewat chat. Versi ticketing yang dibatalkan ada di [`docs/archive/`](docs/archive/PROMPT-CUSTOMER-CARE.md) |

## Arsitektur

```
 App OLT (Flutter, Windows/Android)                 Server OLT (WebSocket)
  ├─ login OLT (username/email+password / token) ──▶       ▲
  └─ olt_social ── token OLT ──┐                           │ login metode token
                               ▼                           │ (verifikasi, timeout 5 dtk)
 ┌──────────────── docker compose (profil dev / single) ──┼──────────────────────────┐
 │ Traefik ─▶ Kong ─┬─ /bridge/v1    ─▶ auth-bridge (Go) ─┘   (Valkey: rate limit/cache) │
 │ (edge: TLS,      │                    └─ RPC upsert profil                             │
 │  rate limit,     ├─ /rest/v1       ─▶ PostgREST ─┐                                     │
 │  header)         ├─ /storage/v1    ─▶ Storage ───┼─▶ PgBouncer ─▶ Postgres 17          │
 │ dev  :8000       ├─ /functions/v1  ─▶ Edge Runtime│                RLS semua tabel     │
 │ single :443      ├─ /realtime/v1   ─▶ Realtime ── langsung (replikasi logis) ─▶ Postgres│
 │                  ├─ /auth/v1 (dev) ─▶ GoTrue ────┘                                     │
 │                  └─ /  (dev)       ─▶ Studio                                          │
 │ migrate (one-shot): menjalankan supabase/migrations setiap stack naik                 │
 └──────────────────────────────────────────────────────────────────────────────────────┘
```

**Profil deploy** (image, nama service, dan nama env sama di semua profil; lihat [docs/scaling.md](docs/scaling.md)):

| Profil | File | Perintah | Kegunaan |
|---|---|---|---|
| `dev` | `docker/compose.yml` + `compose.dev.yml` | `make up` | Laptop: `http://localhost:8000`, Studio, token mock OLT, CORS `*` |
| `single` | `docker/compose.yml` + `compose.prod.yml` | `make up PROFILE=single` | Produksi 1 server: HTTPS Let's Encrypt, hanya path API publik, Studio mati |
| `cluster` | `docker/compose.yml` + `stack.cluster.yml` | `make up PROFILE=cluster` | Docker Swarm multi-node (kerangka; dilengkapi Tahap 7) |

**Hardening container.**
- Semua service read-only, `cap_drop: ALL`, `no-new-privileges`, dan punya batas CPU/memori/pids.
- Semua non-root, kecuali Postgres: entrypoint-nya mulai sebagai root lalu turun ke user `postgres`.
- Network dipisah `edge` / `app` / `data` / `egress`, dan hanya Traefik yang membuka port.

**Rahasia.** Semua rahasia ada di `docker/secrets/` (Docker secrets, dibuat `make gen-secrets`), tidak ada di `.env` maupun `docker inspect`. Env berisi placeholder `{{secret:nama}}` yang diisi saat container start oleh [`with-secrets.sh`](docker/volumes/olt/with-secrets.sh).

**Satu login.**
- App mengirim token OLT ke `POST /bridge/v1/exchange`.
- auth-bridge memverifikasinya ke WebSocket OLT, melakukan upsert `profiles`, lalu mengembalikan JWT Supabase (`role authenticated`, 15 menit).
- ID user = `UUIDv5(olt_user_id)`, stabil.
- Client memperbarui JWT secara otomatis, termasuk untuk koneksi realtime. Password user tidak pernah melewati auth-bridge.

**Keamanan data.**
- RLS aktif di semua tabel, dan anon tidak punya hak apa pun.
- User hanya bisa menulis datanya sendiri.
- Post, komentar, dan pesan dari user yang saling blokir disembunyikan.
- Pesan chat hanya terbaca oleh anggota room.
- `olt_user_id` dan email tidak bisa dibaca user lain.
- Helper `security definer` berada di schema `private`, yang tidak di-expose oleh PostgREST.

**Rate limit & integritas konten di DB.**
- **Batas default:**
  - post 5/menit dan 50/hari, komentar 20/menit, pesan 30/menit, like 60/menit;
  - follow 30/jam, laporan 10/jam, buat room 10/jam;
  - upload 50/hari, ekspor data 3/hari.
- **Penyesuaian per akun:** akun baru (`trust_level` 0, 24 jam pertama) mendapat setengahnya, dan akun tepercaya (`trust_level` ≥ 2) dua kalinya.
- **Respons 429** membawa header `Retry-After`, dan setiap pelanggaran dicatat ke log.
- **Mengubah tanpa migrasi:** batas ada di `private.rate_limits`, pengaturan lain di `private.settings`.
- **Validasi server:**
  - karakter kontrol ditolak;
  - maksimal 3 link, 10 mention, dan 10 kode saham per konten;
  - konten sama ≥ 3x dalam 5 menit ditolak.
- **Idempotensi:** post, komentar, dan pesan memakai `client_id`, jadi kirim ulang tidak membuat data ganda.
- **Syarat & Ketentuan:** wajib disetujui (versi terbaru) sebelum posting, berkomentar, atau chat.

**Moderasi & admin.**
- **Status konten** `visible` / `held` / `hidden`: konten yang tidak `visible` hanya terlihat penulisnya, termasuk lewat Realtime.
- **Kata terlarang** di-*mask* atau di-*block*.
- **Admin:**
  - Memakai akun terpisah dengan 2FA (`aal2`).
  - Ada 5 peran: `super_admin`, `compliance_admin`, `moderator`, `room_moderator`, `viewer`.
  - Semua aksi lewat schema `admin_api`.
  - Audit log tidak bisa diubah maupun dihapus.
- **Sanksi bertingkat** (peringatan → mute → ban). Ban dan pencabutan sesi langsung menolak JWT yang masih aktif, lewat pre-request PostgREST.
- **Arsip regulator:** konten yang dihapus diarsipkan, dengan retensi dan *legal hold*.

**Privasi (UU PDP).**
- **Mute** user, kata, atau saham; penyaringannya dilakukan di server.
- **Akun:** `delete_my_account` dan `export_my_data`.
- **Retensi otomatis** lewat `pg_cron`, dan akses ke data pribadi dicatat.

**Realtime.**
- `postgres_changes` (tunduk RLS) untuk `messages`, `posts`, `comments`, `reactions`, `notifications`.
- Channel *private* `room:<id>` untuk presence per room, indikator mengetik, dan tanda terima (centang ✓ / ✓✓ / ✓✓ biru) yang disiarkan **server** lewat `realtime.send`. Otorisasinya lewat policy `realtime.messages`.

**Storage.**
- `avatars`: publik, maksimal 2 MB.
- `attachments`: privat, maksimal 5 MB. Lampiran chat hanya bisa dibaca anggota room.
- Kedua bucket hanya menerima gambar.

## Prasyarat

- Docker dengan Compose v2.24+. Semua backend berjalan di container, dan migrate/seed/test juga dijalankan di container.
- **Windows:** PowerShell 5.1+, lalu pakai `.\make.ps1 <target>`. **Linux/macOS/WSL/VPS:** `make <target>`.
- Hanya untuk package/app Flutter: Flutter ≥ 3.44, ditambah Visual Studio 2022 (build Windows) dan Android SDK (build Android).

## Quick start (development)

```bash
make gen-secrets     # docker/secrets/ (rahasia acak) + docker/.env   (Windows: .\make.ps1 gen-secrets)
make up              # semua service + migrasi otomatis, tunggu healthy
make seed            # 6 user, 49 saham/indeks IDX, post, thread 5 level, chat
make smoke           # 21 cek end-to-end lewat Kong
make anon-key        # ANON_KEY untuk app Flutter
```

`make gen-secrets` aman diulang: secret yang sudah ada dipertahankan. Rahasia dari `docker/.env` versi lama dipindahkan otomatis (password DB tetap sama), dan cadangannya disimpan di `docker/secrets/`.

| Apa | URL |
|---|---|
| API gateway (dipakai Flutter) | `http://localhost:8000` (Traefik) |
| Studio | `http://localhost:8000`, login `DASHBOARD_USERNAME` (`docker/.env`) + password di `docker/secrets/dashboard_password` |
| Emulator Android | `http://10.0.2.2:8000` |
| HP fisik di LAN | Set `EDGE_HTTP_BIND=0.0.0.0`, lalu pakai `http://<IP-PC>:8000` |
| App contoh versi web (`make web-example`) | `http://localhost:8081` |

Jalankan app contoh: lihat [packages/olt_social/example/README.md](packages/olt_social/example/README.md).

```bash
cd packages/olt_social/example
flutter run -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY: make anon-key>
```

Untuk testing beberapa user sekaligus, jalankan juga versi web: `make web-example` (Windows: `.\make.ps1 web-example`). Buka `http://localhost:8081/?user=sari_invest` untuk langsung masuk sebagai Sari. Tiap tab browser bisa menjadi user berbeda, jadi chat dan notifikasi realtime bisa dicoba antara tab dengan tab, atau tab dengan app Windows.

Login dev memakai **token mock**. Contohnya `mock:1001:budi_santoso`, yang sama dengan user seed Budi. User lain: `1002 sari_invest`, `1003 andi_trader`, `1004 rina_saham`, `1005 dewi_cuan`, dan `1006 olt_official`.

### Testing dengan OLT dummy (token sendiri)

Selama format login OLT asli belum tersedia, [`services/dummy-olt`](services/dummy-olt/) berperan sebagai server WebSocket OLT tiruan. Ia menerbitkan token sesinya sendiri, dan auth-bridge memverifikasinya lewat **mode `websocket`**, jalur yang sama dengan produksi.

- **Tidak ada kode yang diubah.** Auth-bridge, package Flutter, dan database tetap sama; yang berbeda hanya `OLT_MODE` dan `OLT_WS_URL` di [`docker/compose.dummy-olt.yml`](docker/compose.dummy-olt.yml). Dummy berbicara Protokol v1, sama dengan default auth-bridge.
- **Token mock lama tetap diterima** dalam mode ini, sehingga semua tes lama juga berjalan lewat jalur websocket.

```bash
make up DUMMY_OLT=1                 # Windows: .\make.ps1 up -DummyOlt
make smoke-dummy                    # 16 skenario (login, exchange, token ditolak, timeout OLT, ...)
make dummy-token U=sari_invest      # cetak token OLT dummy;  Windows: .\make.ps1 dummy-token -User sari_invest
make down DUMMY_OLT=1 && make up    # kembali ke mode mock
```

Semua akun dummy memakai password `olt12345`. Akun 1001–1006 sama dengan user seed; daftar lengkapnya (termasuk akun ditangguhkan dan simulasi OLT lambat) ada di [services/dummy-olt/README.md](services/dummy-olt/README.md).

Di app contoh tersedia form **"Login OLT dummy (WebSocket)"**: username/email + password → token OLT dummy → fitur sosial.

## Target Makefile / make.ps1

| Target | Fungsi |
|---|---|
| `up` / `down` / `ps` / `logs` | Kelola stack; `PROFILE=dev\|single\|cluster` (Windows `-Profile`). `logs s=auth-bridge` / `-Service auth-bridge` untuk satu service |
| `reset` | **Hapus volume DB & storage**, lalu naik ulang dari nol. Wajib `CONFIRM=yes` (Windows `-Yes`) |
| `migrate` / `seed` | Jalankan migrasi baru / isi data dummy (idempoten) |
| `test` | `test-db` + `test-bridge` + `test-dummy-olt` + `test-cs` |
| `test-db` | 504 tes pgTAP: skema, RLS, parser, thread, reaksi, feed, chat, moderasi, realtime/storage, rate limit, integritas konten, admin & sanksi, privasi, role, polling, centang, badge unread, serta CS chat (kalender, state machine sesi, RLS & catatan internal, penyamaran) |
| `test-bridge` | Unit test Go auth-bridge (di container) |
| `smoke` | 21 cek end-to-end lewat Kong (exchange, RLS, RPC, storage) |
| `test-flutter` | `flutter analyze` + unit/widget test package |
| `test-flutter-it` | Integration test Flutter ke stack: realtime, channel private, presence, rate limit |
| `e2e-windows` | E2E app contoh di Windows (login → feed → thread → komentar/chat dengan Enter) |
| `web-example` | Build app contoh untuk web, sajikan di `http://localhost:8081` (`?user=<username>` langsung login) |
| `license-audit` | Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL/LGPL/MPL) |
| `backup` / `restore` | Backup DB + file storage ke `backups/`; restore: `make restore FILE=... CONFIRM=yes` |
| `gen-secrets` | Buat `docker/secrets/` + `docker/.env`. Idempoten; `FORCE=1` / `-Force` membuat ulang semua rahasia. `gen-keys` = alias lama |
| `anon-key` | Cetak `ANON_KEY` untuk build app Flutter |
| `admin-up` / `admin-down` | Nyalakan/matikan Studio di profil `single` (akses lewat SSH tunnel ke `127.0.0.1:8000`) |
| `psql` | psql ke DB sebagai `postgres` |
| `up DUMMY_OLT=1` / `-DummyOlt` | Stack + OLT dummy, auth-bridge mode websocket (hanya profil `dev`) |
| `dummy-token` | Token OLT dummy: `U=<user> [TTL=1h]` / `-User <user> [-Ttl 1h]` |
| `smoke-dummy` | 16 skenario auth-bridge mode websocket vs OLT dummy |
| `test-dummy-olt` | Unit test Go OLT dummy (di container) |
| `test-flutter-it-dummy` | Integration test Flutter dengan token hasil login WebSocket OLT dummy |
| `e2e-windows-dummy` | E2E app contoh: form login OLT dummy |
| `test-cs` | Unit test Go `customer-adapter` (di container) |
| `smoke-cs` | 40 skenario CS chat end-to-end: buka tiket, ambil & rebutan, balas, penyamaran, catatan internal, adapter + OLT dummy, amankan akun, transfer, selesai, rating (butuh `DUMMY_OLT=1`) |
| `cs-race` | Tes rebutan ambil tiket: 50 CS × 1 tiket dan 200 tiket × 30 CS, langsung ke database dan lewat 3 replika PostgREST |
| `cs-console` | Web CS di `http://localhost:8084` + akun staf dev dengan TOTP (`scripts/cs-demo/runtime/staff.json`). Butuh Flutter SDK dan `DUMMY_OLT=1` |
| `cs-totp` | Kode TOTP saat ini untuk akun staf dev |
| `cs-demo` | Halaman demo CS (dev) di `http://localhost:8082`: nasabah dan panel CS berdampingan lewat API asli. Stop: `docker rm -f olt-cs-demo` (butuh `DUMMY_OLT=1`) |
| `up PROFILE=single CS=1` / `-Profile single -Cs` | Nyalakan CS chat (`customer-adapter`) di produksi (di dev selalu aktif). Butuh endpoint OLT nasabah, lihat [docs/cs-chat](docs/cs-chat/README.md) |

Produksi memakai `make up PROFILE=single`: Traefik HTTPS (Let's Encrypt), hanya path API yang publik, dan Studio mati. Lihat [docs/PRODUCTION.md](docs/PRODUCTION.md).

## Database

Migrasi ada di `supabase/migrations`. Service `migrate` menjalankannya otomatis setiap `make up`, setelah GoTrue, Storage, dan Realtime selesai menyiapkan skemanya.

| File | Isi |
|---|---|
| `0001_init` | Extension `ltree`, `citext`, `pg_trgm` |
| `0002_profiles` | Schema `private` (helper, rate limit, filter kata, arsip), `profiles`, `follows`, `blocks`, `stocks`, `stock_watchers`, RPC `upsert_olt_profile` / `sync_stocks` (service_role), `search_profiles`, `search_stocks`, `get_profile` |
| `0003_notifications` | `notifications` (digabung per grup selama belum dibaca), `get_notifications`, `mark_notifications_read` |
| `0004_posts` | `posts`, `post_stocks` & `post_mentions` (parsing `$KODE`/`@mention` otomatis), `delete_post` |
| `0005_comments` | `comments` dengan `path ltree` + index GiST & `(post_id, path)`, counter, notifikasi balasan/mention, `delete_comment` |
| `0006_reactions` | `reactions` (unik per user per target), `like_count`, notifikasi like |
| `0007_feed_rpc` | `get_feed(scope, stock_code, cursor, limit)` keyset, `get_post`, `get_comment_thread(...)`, `create_comment` |
| `0008_chat` | `chat_rooms` (DM unik per pasangan), `chat_members`, `messages` (`client_id` idempoten), `get_or_create_direct_room`, `mark_room_read`, `get_unread_counts`, `send_message`, `get_messages`, `get_my_rooms`, grup & room saham |
| `0009_moderation` | `reports` + `private.report_queue` |
| `0010_realtime` | Publikasi realtime + otorisasi channel private |
| `0011_storage` | Bucket `avatars` & `attachments` + policy |

**Aturan migrasi:**
- Tambahkan file dengan nomor berikutnya. **Jangan mengubah file yang sudah jalan**; runner mencatat checksum dan menolak perubahan.
- Error API memakai SQLSTATE `PT<status>`, misalnya `PT429` → HTTP 429, dengan `message` berisi kode stabil seperti `rate_limited`.

## Versi image (semua di-pin)

Dasarnya adalah `docker/docker-compose.yml` resmi `supabase/supabase`, commit `6a421fe` (29 Okt 2026). Semua image di `docker/compose.yml` di-pin **tag + digest** (`image@sha256:…`).

| Service | Image |
|---|---|
| traefik | `traefik:v3.7.15` |
| db | `supabase/postgres:17.6.1.136` |
| pgbouncer | build lokal `alpine:3.22.7` + `pgbouncer=1.24.0-r0` |
| valkey | `valkey/valkey:9.0.7-alpine` |
| kong | `kong/kong:3.9.3` |
| auth | `supabase/gotrue:v2.197.0` |
| rest | `postgrest/postgrest:v14.18` |
| realtime | `supabase/realtime:v2.143.3` |
| storage | `supabase/storage-api:v1.81.0` |
| imgproxy | `darthsim/imgproxy:v3.31.4` |
| meta | `supabase/postgres-meta:v0.100.0` |
| studio | `supabase/studio:2026.10.12-sha-3699278` |
| functions | `supabase/edge-runtime:v1.77.4` |
| auth-bridge | build lokal `golang:1.27.3-alpine3.24` → `distroless/static-debian12:nonroot` (keduanya di-pin digest) |
| migrate / tools | build lokal `alpine:3.22.7` (psql 17, pg_prove 3.37 di-pin, curl, jq) |

**Perbedaan dari compose resmi:**
- Edge memakai Traefik di depan Kong (upstream sekarang default-nya Envoy).
- PgBouncer (bukan Supavisor) sebagai pooler. Analytics (Logflare) dan Vector tidak disertakan.
- Rahasia lewat Docker secrets, container di-hardening, dan network dipisah per lapisan (lihat [Arsitektur](#arsitektur)).
- Data disimpan di named volume, dan log tiap container dirotasi.

## Lisensi

Kode di repo ini bersifat proprietary untuk Rendezvous OLT. Seluruh dependensi app berlisensi permisif:
- **Flutter:** MIT/BSD/Apache-2.0, diverifikasi dengan `make license-audit`.
- **auth-bridge:** Go stdlib (BSD) + gorilla/websocket (BSD-2).

Komponen Supabase, Kong, Traefik (MIT), PgBouncer (ISC), Valkey (BSD-3), dan Postgres hanya berjalan sebagai service terpisah dan tidak di-link ke aplikasi OLT.
#   c h a t _ s e r v i c e _ s u p a b a s e  
 