# Prompt: Fitur Sosial & Chat untuk Rendezvous OLT

> Salin seluruh isi file ini ke AI coding agent (misalnya Claude Code) di root folder proyek. Bagian yang diapit `[...]` silakan disesuaikan dulu.

---

## 1. Peran & Konteks

Kamu adalah senior engineer Flutter dan backend. Kerjakan proyek ini dengan kode yang rapi, terstruktur, terdokumentasi, dan siap produksi.

**Konteks aplikasi:**
- **Rendezvous OLT** adalah aplikasi online trading saham untuk Bursa Efek Indonesia (IDX).
- Dibangun dengan **Flutter** untuk **Windows desktop** dan **Android** (dirilis di Play Store).
- OLT adalah produk komersial dan **closed-source**. Semua dependensi wajib berlisensi permisif (MIT, Apache 2.0, BSD). Jangan pakai dependensi AGPL atau GPL.
- Login user OLT saat ini dilakukan dengan **mengirim (push) pesan login ke WebSocket server OLT**. Metode login yang didukung:
  - **username + password**
  - **email + password**
  - **token** (login ulang memakai token sesi yang sudah dimiliki)
  - Format pesan login dan respons WebSocket: `[tempel contoh payload request & response login, termasuk field user id, username, email, dan token]`.

**Tujuan:** menambahkan fitur sosial di dalam OLT:
1. **Feed / Stream**: user bisa membuat post. Post bisa ditandai kode saham (`$BBCA`, `$GOTO`, dan seterusnya), lalu tampil di halaman saham terkait dan di stream umum.
2. **Komentar berantai tanpa batas kedalaman**: user bisa membalas komentar, lalu membalas balasannya, dan seterusnya.
3. **Reaksi/like**, **mention `@username`**, **follow user**, dan **watch saham**.
4. **Chat realtime**: DM 1-on-1, grup, dan room per saham.
5. **Moderasi**: report, block user, rate limit, filter kata, dan disclaimer.

---

## 2. Aturan Teknis Wajib

- **Semua backend berjalan di Docker** lewat satu `docker compose`. Tidak boleh ada service yang harus diinstal manual di host.
- Backend memakai **Supabase self-hosted**, berbasis docker-compose resmi dari repo `supabase/supabase` folder `docker`.
  - **Pin semua versi image.** Jangan pakai tag `latest`.
- Flutter client memakai **`supabase_flutter` versi stabil 2.x**. Jangan pakai versi `3.0.0-dev`.
- Semua rahasia disimpan di `.env`. Sertakan `.env.example`, dan jangan pernah commit `.env`.
- Semua perubahan skema database dibuat sebagai **file migrasi SQL bernomor**, idempoten jika memungkinkan, dan dijalankan otomatis saat container DB pertama kali naik.
- Keamanan database wajib memakai **Row Level Security (RLS) aktif di semua tabel**. Client hanya memakai `anon key`, dan `service_role key` tidak boleh ada di aplikasi Flutter.
- Kode Flutter mengikuti arsitektur berlapis (presentation / domain / data):
  - Deteksi state management yang **sudah dipakai di proyek OLT** dan ikuti. Kalau belum ada, gunakan **Riverpod**.
  - Pakai model immutable (`freezed` + `json_serializable`).
  - Kode lolos `dart analyze` tanpa warning.
- Kode, nama tabel, dan kolom ditulis dalam bahasa Inggris. Komentar kode dan README boleh berbahasa Indonesia.

---

## 3. Struktur Repository

```
olt-social/
├── docker/
│   ├── docker-compose.yml          # Supabase stack + service tambahan
│   ├── .env.example
│   └── volumes/                    # config kong, db init, storage, dll
├── supabase/
│   ├── migrations/                 # 0001_init.sql, 0002_feed.sql, ...
│   ├── seed/seed.sql               # data dummy untuk development
│   └── tests/                      # tes SQL / RLS (pgTAP)
├── services/
│   └── auth-bridge/                # tukar token OLT -> JWT Supabase (Dockerized)
├── packages/
│   └── rendezvous_community/                 # Flutter package, dipakai app OLT
│       ├── lib/
│       │   ├── rendezvous_community.dart     # public API
│       │   └── src/
│       │       ├── core/           # config, client, errors, utils
│       │       ├── data/           # models, datasources, repositories impl
│       │       ├── domain/         # entities, repository contracts
│       │       └── presentation/   # widgets, screens, controllers
│       ├── test/
│       └── example/                # app contoh (Windows + Android)
├── Makefile                        # make up, make down, make reset, make seed, make test
└── README.md
```

Fitur sosial dibuat sebagai **package Flutter terpisah** (`rendezvous_community`) agar mudah diintegrasikan ke OLT hanya lewat `pubspec.yaml` dan beberapa baris inisialisasi.

---

## 4. Docker

- `docker/docker-compose.yml` berisi seluruh stack Supabase:
  - db (Postgres), kong, auth (GoTrue), rest (PostgREST), realtime, storage, imgproxy, meta, studio, dan edge functions.
  - Ditambah service **`auth-bridge`**.
- Mount `supabase/migrations` agar migrasi otomatis jalan saat inisialisasi DB.
- Siapkan healthcheck untuk setiap service, `restart: unless-stopped`, network internal, dan volume persisten untuk data DB dan storage.
- Hanya expose port yang perlu, yaitu gateway API (Kong) dan Studio. Studio hanya untuk lokal atau dilindungi password.
- Siapkan `Makefile` dengan target berikut:
  - `up`, `down`, `logs`
  - `reset`: hapus volume, lalu naik ulang
  - `seed`, `migrate`
  - `test-db`, `gen-keys`: generate JWT secret, anon key, dan service key
- README menjelaskan langkah deploy ke VPS (Ubuntu): reverse proxy HTTPS (Caddy atau Nginx di Docker), backup DB terjadwal, dan cara update versi.

---

## 5. Integrasi Auth (auth-bridge)

User **tidak boleh login dua kali**. Alurnya:
1. App OLT sudah memegang token login OLT.
2. App memanggil `auth-bridge` (`POST /exchange`) dengan token OLT.
3. `auth-bridge` memverifikasi token ke sistem OLT dengan membuka koneksi ke **WebSocket server OLT** dan mengirim pesan login memakai token tersebut (metode login token). Data user (user id, username, email) diambil dari respons login.
   - `auth-bridge` **tidak pernah menerima atau menyimpan password user**. Login username/email + password tetap dilakukan app OLT langsung ke WebSocket OLT seperti sekarang.
   - Koneksi WebSocket untuk verifikasi ditutup setelah respons diterima, dengan timeout `[5]` detik.
   - Hasil verifikasi di-cache singkat agar tidak membebani server OLT.
4. `auth-bridge` membuat atau meng-update baris `profiles` lewat upsert.
5. `auth-bridge` mengembalikan **JWT Supabase** yang ditandatangani dengan JWT secret Supabase. JWT ini memuat `sub` berupa UUID user yang stabil per user OLT, `role: authenticated`, dan expiry pendek.
6. Client memakai JWT tersebut ke Supabase. Saat expired, client meminta ulang otomatis.

Ketentuan teknis `auth-bridge`:
- Dibuat dengan stack ringan: `[pilih: Dart (shelf) / Node.js (Fastify) / Go]`.
- Dockerized dan punya endpoint `/health`.
- Rate limit per IP dan logging yang rapi.

---

## 6. Skema Database

Buat tabel berikut, lengkap dengan constraint, index, timestamp (`created_at`, `updated_at`), dan soft delete jika relevan.

**Profil & relasi**
- `profiles`: id (uuid, = auth sub), olt_user_id (unik), username (unik), display_name, avatar_url, bio, is_verified, created_at.
- `follows`: follower_id, following_id (PK gabungan, tidak bisa follow diri sendiri).
- `blocks`: blocker_id, blocked_id.
- `stocks`: code (PK, misal `BBCA`), name. Diisi dari seed dan bisa di-sync.
- `stock_watchers`: user_id, stock_code.

**Feed**
- `posts`: id, author_id, body (teks, maks `[2000]` karakter), sentiment (`bullish` / `bearish` / `neutral`, opsional), attachments (jsonb), like_count, comment_count, deleted_at, created_at.
- `post_stocks`: post_id, stock_code. Isinya hasil parsing otomatis `$KODE` dari body, divalidasi terhadap tabel `stocks`.
- `post_mentions`: post_id, user_id. Isinya hasil parsing `@username`.

**Komentar berantai**
- `comments`: id, post_id, parent_id (nullable), author_id, body, **path (`ltree`)**, depth, like_count, reply_count, deleted_at, created_at.
- `path` diisi otomatis oleh trigger berdasarkan path parent.
- Index GiST pada `path`, dan index pada `(post_id, path)`.
- Komentar yang dihapus tetap disimpan sebagai "[komentar dihapus]" agar thread tidak rusak.

**Reaksi**
- `reactions`: user_id, target_type (`post` / `comment`), target_id, type (`like`, dan bisa dikembangkan). Unik per user per target.

**Chat**
- `chat_rooms`: id, type (`direct` / `group` / `stock`), name, stock_code (untuk room saham), created_by.
- `chat_members`: room_id, user_id, role (`owner` / `admin` / `member`), last_read_at, muted.
- `messages`: id, room_id, sender_id, body, reply_to_id, attachments, edited_at, deleted_at, created_at.
- Pesan DM antara dua user harus memakai **room yang sama**, tidak membuat room duplikat.

**Moderasi**
- `reports`: reporter_id, target_type, target_id, reason, status.
- `banned_words`: daftar kata terlarang.
- `notifications`: user_id, type (`reply` / `mention` / `like` / `follow` / `message`), payload, read_at.

**Trigger & fungsi (RPC)**
- Trigger counter (`like_count`, `comment_count`, `reply_count`) yang konsisten.
- Trigger parsing `$KODE` dan `@mention`.
- Trigger pembuatan notifikasi.
- `get_feed(scope, stock_code, cursor, limit)`:
  - `scope` bisa `global`, `following`, atau `stock`.
  - Pagination memakai **cursor (keyset)**, bukan OFFSET.
  - Hasilnya mengecualikan user yang diblokir.
- `get_comment_thread(post_id, root_comment_id, max_depth, cursor, limit)`:
  - Mengembalikan komentar terurut sesuai pohon.
  - Mendukung "load more replies" per cabang.
- `create_comment(post_id, parent_id, body)` dengan validasi dan rate limit.
- `get_or_create_direct_room(other_user_id)`.
- `mark_room_read(room_id)` dan `get_unread_counts()`.
- **Rate limit di sisi DB**, misalnya maks `[5]` post/menit dan `[20]` komentar/menit per user.

**RLS**
- Semua user terautentikasi boleh membaca post dan komentar, kecuali milik user yang memblokir atau diblokir.
- User hanya boleh insert, update, dan delete milik sendiri.
- Pesan chat hanya bisa dibaca anggota room.
- Sertakan **tes RLS** (pgTAP) untuk skenario utama.

**Realtime & Storage**
- Aktifkan publikasi realtime untuk tabel `messages`, `posts`, `comments`, `reactions`, dan `notifications`.
- Gunakan presence untuk status online dan indikator "sedang mengetik" di chat.
- Buat bucket storage `avatars` dan `attachments` dengan policy, batas ukuran file, dan jenis file (gambar saja).

---

## 7. Flutter Package `rendezvous_community`

**API publik yang sederhana**, contohnya:

```dart
await RendezvousCommunity.initialize(
  supabaseUrl: '...',
  anonKey: '...',
  authBridgeUrl: '...',
  oltTokenProvider: () async => oltAuth.currentToken,
);

// Widget siap pakai:
CommunityStreamFeed();                       // stream umum
CommunityStockFeed(stockCode: 'BBCA');       // feed di halaman saham
CommunityPostDetail(postId: '...');          // post + thread komentar
CommunityChatList();
CommunityChatRoom(roomId: '...');
CommunityComposePost(initialStock: 'BBCA');
```

**Ketentuan UI/UX**
- Layout responsif.
  - **Windows desktop**: tampilan lebar dan multi-panel, mendukung mouse hover dan shortcut keyboard (Enter untuk kirim, Shift+Enter untuk baris baru).
  - **Android**: tampilan mobile.
- Thread komentar ditampilkan bertingkat dengan garis indentasi.
  - Mulai level ke-`[4]`, indentasi berhenti bertambah dan muncul tombol "Lanjutkan thread".
  - Tersedia tombol "Lihat N balasan lainnya" dan collapse/expand per cabang.
- Kode saham `$BBCA` dan mention `@user` di teks bisa diklik melalui callback `onStockTap` dan `onUserTap`. Dengan begitu OLT bisa membuka halaman saham sendiri.
- Badge sentimen bullish/bearish, infinite scroll, pull-to-refresh, serta state kosong, loading (skeleton), dan error yang rapi.
- Pakai **optimistic update** untuk like dan kirim pesan, dengan rollback jika gagal.
- Chat menampilkan status terkirim, unread badge, typing indicator, balas pesan, dan reconnect otomatis saat koneksi putus.
- Tema mengikuti `ThemeData` aplikasi host (mendukung dark mode). Jangan hardcode warna.
- Disclaimer kecil di composer dan detail post: *"Konten ini opini pengguna, bukan rekomendasi investasi."*
- Lokalisasi Indonesia (default) dan Inggris.

**Kualitas**
- Unit test untuk repository dan parser (`$KODE`, `@mention`).
- Widget test untuk thread komentar.
- Folder `example/` bisa dijalankan di Windows dan Android, terhubung ke Docker lokal.

---

## 8. Tahapan Pengerjaan

Kerjakan **bertahap**. Setelah setiap tahap selesai, berhenti, ringkas hasilnya, dan tunggu konfirmasi sebelum lanjut.

1. **Infrastruktur**:
   - Struktur repo, docker-compose Supabase + auth-bridge, Makefile, `.env.example`, dan README setup.
   - Kriteria selesai: `make up` berhasil, semua service healthy, dan Studio bisa dibuka.
2. **Database**:
   - Semua migrasi, trigger, RPC, RLS, seed (beberapa user, saham IDX populer, post, dan thread komentar 5 level), serta tes pgTAP.
   - Kriteria selesai: `make test-db` lulus.
3. **Auth bridge**:
   - Endpoint exchange dan tesnya. Selama sistem OLT belum tersambung, sediakan mode mock token untuk development.
4. **Flutter data layer**:
   - Model, datasource, repository, dan realtime subscription, beserta unit test.
5. **Flutter UI**:
   - Feed, compose, detail + thread komentar, chat list, chat room, dan notifikasi.
   - App `example/` berjalan di Windows dan Android.
6. **Hardening**:
   - Rate limit, filter kata, report/block, logging, panduan deploy VPS, backup, dan checklist produksi.
7. **Panduan integrasi**:
   - Dokumen langkah memasang `rendezvous_community` ke proyek OLT yang sudah ada.

Sebelum mulai, **periksa dulu struktur proyek OLT** (state management, routing, tema, dan versi Flutter/Dart) supaya package mengikuti konvensi yang ada. Kalau ada keputusan yang ambigu, tanyakan dulu, jangan menebak.