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
| [`docker/`](docker/) | Supabase self-hosted (image di-pin) + auth-bridge + Caddy (produksi), satu `docker compose` |
| [`supabase/`](supabase/) | Migrasi SQL bernomor, seed development, tes pgTAP |
| [`services/auth-bridge/`](services/auth-bridge/) | Go: tukar token login OLT menjadi JWT Supabase (tanpa login dua kali) |
| [`services/dummy-olt/`](services/dummy-olt/) | Go: server WebSocket OLT **tiruan** (token sendiri) untuk menguji auth-bridge mode websocket. Hanya development/testing |
| [`packages/olt_social/`](packages/olt_social/) | Package Flutter (Bloc, freezed) + app [`example/`](packages/olt_social/example/) Windows, Android & web |
| [`docs/INTEGRATION.md`](docs/INTEGRATION.md) | Cara memasang `olt_social` ke aplikasi OLT |
| [`docs/PRODUCTION.md`](docs/PRODUCTION.md) | Deploy VPS, backup/restore, update versi, moderasi, checklist produksi |

## Arsitektur

```
 App OLT (Flutter, Windows/Android)                 Server OLT (WebSocket)
  ├─ login OLT (username/email+password / token) ──▶       ▲
  └─ olt_social ── token OLT ──┐                           │ login metode token
                               ▼                           │ (verifikasi, timeout 5 dtk)
 ┌─────────────────────── docker compose ─────────────────┼────────────────────┐
 │ [Caddy :443, produksi] ─▶ Kong :8000 ─┬─ /bridge/v1   ─▶ auth-bridge (Go) ────┘ │
 │                                       │                   └─ RPC upsert profil   │
 │                                       ├─ /rest/v1     ─▶ PostgREST ─┐            │
 │                                       ├─ /realtime/v1 ─▶ Realtime  ─┤            │
 │                                       ├─ /storage/v1  ─▶ Storage ───┼─▶ Postgres 17
 │                                       ├─ /auth/v1     ─▶ GoTrue ────┤  RLS semua tabel
 │                                       ├─ /functions/v1─▶ Edge Runtime│            │
 │                                       └─ /  (dev)     ─▶ Studio      │            │
 │ migrate (one-shot): menjalankan supabase/migrations setiap stack naik            │
 └───────────────────────────────────────────────────────────────────────────────┘
```

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

**Rate limit & moderasi di DB.**
- Batas default: post 5/menit, komentar 20/menit, pesan 30/menit, reaksi 120/menit, laporan 10/jam. Semuanya bisa diubah di `private.rate_limits` tanpa migrasi.
- Kata terlarang di-*mask* atau di-*block*.
- Konten yang dihapus diarsipkan untuk audit moderasi.

**Realtime.**
- `postgres_changes` (tunduk RLS) untuk `messages`, `posts`, `comments`, `reactions`, `notifications`.
- Channel *private* untuk presence online, indikator mengetik, dan read receipt. Otorisasinya lewat policy `realtime.messages`.

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
make gen-keys        # buat docker/.env berisi rahasia acak     (Windows: .\make.ps1 gen-keys)
make up              # semua service + migrasi otomatis, tunggu healthy
make seed            # 6 user, 49 saham/indeks IDX, post, thread 5 level, chat
make smoke           # 21 cek end-to-end lewat Kong
```

| Apa | URL |
|---|---|
| API gateway (dipakai Flutter) | `http://localhost:8000` |
| Studio | `http://localhost:8000`, login dengan `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD` dari `docker/.env` |
| Emulator Android | `http://10.0.2.2:8000` |
| HP fisik di LAN | Set `KONG_HTTP_BIND=0.0.0.0`, lalu pakai `http://<IP-PC>:8000` |
| App contoh versi web (`make web-example`) | `http://localhost:8081` |

Jalankan app contoh: lihat [packages/olt_social/example/README.md](packages/olt_social/example/README.md).

```bash
cd packages/olt_social/example
flutter run -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY dari docker/.env>
```

Untuk testing beberapa user sekaligus, jalankan juga versi web: `make web-example` (Windows: `.\make.ps1 web-example`). Buka `http://localhost:8081/?user=sari_invest` untuk langsung masuk sebagai Sari. Tiap tab browser bisa menjadi user berbeda, jadi chat dan notifikasi realtime bisa dicoba antara tab dengan tab, atau tab dengan app Windows.

Login dev memakai **token mock**. Contohnya `mock:1001:budi_santoso`, yang sama dengan user seed Budi. User lain: `1002 sari_invest`, `1003 andi_trader`, `1004 rina_saham`, `1005 dewi_cuan`, dan `1006 olt_official`.

### Testing dengan OLT dummy (token sendiri)

Selama format login OLT asli belum tersedia, [`services/dummy-olt`](services/dummy-olt/) berperan sebagai server WebSocket OLT tiruan. Ia menerbitkan token sesinya sendiri, dan auth-bridge memverifikasinya lewat **mode `websocket`**, jalur yang sama dengan produksi.

- **Tidak ada kode yang diubah.** Auth-bridge, package Flutter, dan database tetap sama; yang berbeda hanya konfigurasi `OLT_WS_*` di [`docker/docker-compose.dummy-olt.yml`](docker/docker-compose.dummy-olt.yml).
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
| `up` / `down` / `ps` / `logs` | Kelola stack (`logs s=auth-bridge` atau `-Service auth-bridge` untuk satu service) |
| `reset` | **Hapus volume DB & storage**, lalu naik ulang dari nol |
| `migrate` / `seed` | Jalankan migrasi baru / isi data dummy (idempoten) |
| `test` | `test-db` + `test-bridge` + `test-dummy-olt` |
| `test-db` | 141 tes pgTAP: skema, RLS, parser, thread, reaksi, feed, chat, moderasi, realtime/storage |
| `test-bridge` | Unit test Go auth-bridge (di container) |
| `smoke` | 21 cek end-to-end lewat Kong (exchange, RLS, RPC, storage) |
| `test-flutter` | `flutter analyze` + unit/widget test package |
| `test-flutter-it` | Integration test Flutter ke stack: realtime, channel private, presence, rate limit |
| `e2e-windows` | E2E app contoh di Windows (login → feed → thread → komentar/chat dengan Enter) |
| `web-example` | Build app contoh untuk web, sajikan di `http://localhost:8081` (`?user=<username>` langsung login) |
| `license-audit` | Audit lisensi dependensi runtime Flutter (tolak GPL/AGPL/LGPL/MPL) |
| `backup` / `restore` | Backup DB + file storage ke `backups/`; restore: `make restore FILE=... CONFIRM=yes` |
| `gen-keys` | Buat `docker/.env` + rahasia (`FORCE=1` / `-Force` untuk menimpa) |
| `psql` | psql ke DB sebagai `postgres` |
| `up DUMMY_OLT=1` / `-DummyOlt` | Stack + OLT dummy, auth-bridge mode websocket (tidak bisa digabung dengan `PROD=1`) |
| `dummy-token` | Token OLT dummy: `U=<user> [TTL=1h]` / `-User <user> [-Ttl 1h]` |
| `smoke-dummy` | 16 skenario auth-bridge mode websocket vs OLT dummy |
| `test-dummy-olt` | Unit test Go OLT dummy (di container) |
| `test-flutter-it-dummy` | Integration test Flutter dengan token hasil login WebSocket OLT dummy |
| `e2e-windows-dummy` | E2E app contoh: form login OLT dummy |

Produksi memakai `make up PROD=1`, yang menambahkan Caddy HTTPS dan menutup Studio dari internet. Lihat [docs/PRODUCTION.md](docs/PRODUCTION.md).

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

Dasarnya adalah `docker/docker-compose.yml` resmi `supabase/supabase`, commit `6a421fe` (29 Okt 2026).

| Service | Image |
|---|---|
| db | `supabase/postgres:17.6.1.136` |
| kong | `kong/kong:3.9.3` |
| auth | `supabase/gotrue:v2.197.0` |
| rest | `postgrest/postgrest:v14.18` |
| realtime | `supabase/realtime:v2.143.3` |
| storage | `supabase/storage-api:v1.81.0` |
| imgproxy | `darthsim/imgproxy:v3.31.4` |
| meta | `supabase/postgres-meta:v0.100.0` |
| studio | `supabase/studio:2026.10.12-sha-3699278` |
| functions | `supabase/edge-runtime:v1.77.4` |
| caddy (prod) | `caddy:2.10.2-alpine` |
| auth-bridge | build lokal `golang:1.24.5-alpine3.22` → `distroless/static-debian12:nonroot@sha256:afa5c872…` (di-pin digest) |
| migrate / tools | build lokal `alpine:3.22.7` (psql 17, pg_prove 3.37 di-pin, curl, jq) |

**Perbedaan dari compose resmi:**
- Gateway memakai Kong (upstream sekarang default-nya Envoy).
- Analytics (Logflare), Vector, dan Supavisor tidak disertakan.
- Data disimpan di named volume.
- Ada dua network: `internal` tanpa internet, dan `public` untuk Kong, auth-bridge, GoTrue, dan Edge Functions.
- Log tiap container dirotasi.

## Lisensi

Kode di repo ini bersifat proprietary untuk Rendezvous OLT. Seluruh dependensi app berlisensi permisif:
- **Flutter:** MIT/BSD/Apache-2.0, diverifikasi dengan `make license-audit`.
- **auth-bridge:** Go stdlib (BSD) + gorilla/websocket (BSD-2).

Komponen Supabase, Kong, Caddy, dan Postgres hanya berjalan sebagai service terpisah dan tidak di-link ke aplikasi OLT.
#   c h a t _ s e r v i c e _ s u p a b a s e  
 