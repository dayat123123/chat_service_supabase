# Pengetahuan Sistem Rendezvous

Pegangan untuk memahami sistem secara utuh: bagian-bagiannya, fungsi setiap node (layanan), teknologi yang dipakai, dan cara server disusun. Dokumen ini untuk tim internal, baik developer baru, tim IT, maupun manajemen teknis. Langkah kerja harian (perintah, pengaturan, gangguan) ada di panduan lain yang ditautkan di setiap bagian.

Kondisi per 23 November 2026: migrasi database sampai `0188`, library `rendezvous_community` v1.49.2.

## 1. Sistem ini apa

Rendezvous adalah **fitur sosial dan layanan nasabah** yang menempel di aplikasi trading OLT. Isinya:

- **Komunitas:** feed postingan saham (`$KODE`), komentar, suka, ikuti akun, akun resmi, pengumuman.
- **Chat:** DM, grup, dan room saham, dengan status terkirim/dibaca dan mengetik secara langsung.
- **Chat CS:** nasabah membuka tiket ke CS, dengan lampiran gambar, dokumen, dan video.
- **Pusat Bantuan:** artikel FAQ dengan gambar dan lampiran, serta pengaduan.
- **Notifikasi:** di dalam aplikasi dan push ke HP, termasuk notifikasi transaksi dari OLT.
- **Rendezvous Hub:** aplikasi web untuk staf (CS, Super Admin, Kepatuhan, tim Komunitas, Pusat Bantuan) yang mengelola semua hal di atas.

Prinsip yang perlu diingat:

1. **Data bisnis trading tetap milik OLT.** Server sosial tidak menyimpan harga, order, mutasi dana, atau portofolio, dan **tidak memanggil sistem OLT** untuk login. OLT menerbitkan token bertanda tangan, dan server memverifikasinya sendiri ([olt-integration.md](../olt-integration.md)).
2. **Logika bisnis ada di database.** Aturan siapa boleh melihat apa, batas kecepatan, moderasi, dan alur tiket ditulis sebagai fungsi SQL dan RLS di Postgres. Layanan lain hanya meneruskan permintaan dan menjaga batas.
3. **Semua jalan di server sendiri (self-hosted).** Pondasinya Supabase open source di Docker, tanpa layanan cloud wajib. Yang keluar ke internet hanya push FCM, alert, backup S3, dan update signature antivirus.
4. **Pengaturan lewat Hub, bukan file.** Kunci Firebase, tujuan backup, kanal alert, kebijakan konten, dan fitur aplikasi diatur Super Admin dari Hub dan tercatat di Jejak Audit.

## 2. Peta besar

```
Nasabah: Aplikasi OLT + library rendezvous_community
         (Flutter: Windows, web, Android, iOS)
    │ HTTPS ke domain API (publik)
    ▼
SERVER SOSIAL (Docker)  ◀── HTTPS ke domain CS (hanya IP kantor) ── Staf: Rendezvous Hub (browser)
    │
    ├─ Pintu      Traefik → Kong
    ├─ Layanan    REST · Realtime · Storage · media · auth-bridge
    │             integration · research · nasabah-gateway · functions
    ├─ Data       PgBouncer → Postgres 17 (semua data + aturan bisnis) · Valkey
    ├─ Latar      notifier · sentinel · healer · backup · janitor · link-preview
    │
    ├──▶ Google FCM          (push ke HP)
    ├──▶ S3 / folder lokal   (backup)
    └──▶ Telegram / email    (alert)

Sistem OLT (milik tim OLT):
  - menerbitkan token sosial bertanda tangan, dibawa aplikasi OLT ke auth-bridge
  - notifEngine mengirim notifikasi transaksi ke /integration/v1
  - csAdmin dipanggil nasabah-gateway untuk menu Akun Nasabah di Hub
```

## 3. Empat bagian dan repo-nya

| Bagian | Repo | Isi | Dipakai oleh |
|---|---|---|---|
| **Server sosial** | `chat_service_supabase` | Compose Docker, migrasi SQL, tes pgTAP, layanan Go buatan sendiri, panduan | Tim IT (pasang/update), developer |
| **Rendezvous Hub** | `rendezvous_hub` | Web staf (React + TypeScript), dibangun jadi image `cs-console` saat `make up` | Staf CS, Super Admin, Kepatuhan, Komunitas, Pusat Bantuan |
| **Library Flutter** | `rendezvous_community` | Semua layar dan logika fitur sosial untuk aplikasi nasabah. Rilis lewat tag Git (`v1.49.2`) | Aplikasi OLT |
| **Aplikasi OLT** | `windows_online_trading` (milik tim aplikasi) | Aplikasi trading. Memasang library dengan `ref:` tag, memberi token login lewat `tokenProvider` | Nasabah |

Hubungan versinya:

- Server dan Hub di-update bersamaan dengan `git pull` di server lalu `make up`.
- Library dirilis terpisah. Aplikasi OLT baru mendapat fitur library baru setelah menaikkan tag dan dibangun ulang.
- Library baru tetap jalan di server lama, dan sebaliknya: fitur yang butuh migrasi baru hanya tidak tampil sampai keduanya sejajar. Contoh: lampiran artikel butuh migrasi `0188` dan library 1.49.0.

## 4. Teknologi yang dipakai

| Lapisan | Teknologi | Versi | Kenapa dipilih |
|---|---|---|---|
| Container | Docker Engine + Compose (Swarm untuk profil cluster) | — | Satu cara pasang di semua server; profil berbeda hanya lewat file override |
| Pintu internet | Traefik | 3.7 | HTTPS otomatis (Let's Encrypt), rate limit per IP, routing per path |
| Gerbang API | Kong | 3.9 | Meneruskan ke layanan Supabase, memeriksa kunci API |
| Database | PostgreSQL (image Supabase) | 17.11 | Semua data + logika bisnis (fungsi, trigger, RLS), ekstensi pg_cron, pgsodium/Vault, pgTAP |
| API data | PostgREST | 14.18 | Mengubah tabel dan fungsi SQL menjadi REST API, langsung patuh RLS |
| Realtime | Supabase Realtime (Elixir) | 2.148 | Chat langsung, mengetik, presence, siaran dari database |
| Login staf | GoTrue (Supabase Auth) | 2.197 | Sesi staf Hub, 2FA TOTP, hook kunci akun |
| File | Supabase Storage API | 1.84 | Bucket file dengan aturan akses per baris (RLS) |
| Pengolah gambar | imgproxy | 3.31 | Mengecilkan gambar supaya cepat dimuat di HP |
| Fungsi tambahan | Supabase Edge Runtime (Deno) | 1.77 | Fungsi `cs-admin` untuk mengelola akun staf |
| Pool koneksi | PgBouncer | 1.24 | Membatasi koneksi ke Postgres saat layanan direplika |
| Cache | Valkey (pengganti Redis, open source) | 9.0 | Penghitung rate limit login |
| Antivirus | ClamAV | 1.5.4 | Memindai dokumen dan video chat CS |
| Layanan buatan sendiri | Go | 1.24 / 1.26 | auth-bridge, media, classifier, notifier, sentinel, healer, backup, janitor, integration, research, nasabah-gateway, link-preview, trade-relay |
| Backup | pg_receivewal + pg_basebackup + restic | — | WAL terus-menerus + backup penuh terenkripsi ke S3 atau folder lokal |
| Push | Firebase Cloud Messaging (FCM) | — | Push ke Android dan iOS |
| Web staf | React, TypeScript, Vite, TanStack Query/Router, Tailwind, Radix UI, Zod | React 19, Node 24 | Hub cepat, terketik, dan teruji (±900 tes) |
| Aplikasi | Flutter + Dart, `flutter_bloc`, `freezed`, `supabase_flutter`, `drift`/SQLite (cache offline, bisa terenkripsi) | Flutter ≥ 3.47, Dart ≥ 3.12 | Satu kode untuk Windows, web, Android, iOS; ±1.470 tes |
| Uji database | pgTAP | — | 165 file tes, ±4.300 assertion untuk aturan bisnis |
| Keamanan repo | gitleaks | 8.28 | Mencegah kunci atau password ikut ter-commit |

## 5. Semua node di server dan fungsinya

Setiap node adalah satu container. Kartu yang sama tampil di Hub, **Pengaturan → Sistem → Kesehatan sistem → Peta layanan**, beserta statusnya setiap 5 detik. Dampak bila sebuah node bermasalah ada di [operasional.md](operasional.md#kenali-setiap-layanan).

### 5.1 Pintu dan gerbang

| Node | Fungsi | Teknologi |
|---|---|---|
| `traefik` | Satu-satunya yang menerima koneksi dari internet: HTTPS, sertifikat, rate limit per IP, batas ukuran upload, dan hanya meloloskan path API resmi. Hub dilayani di domain CS yang hanya boleh dibuka dari IP kantor | Traefik |
| `kong` | Membagi permintaan ke REST, Realtime, Storage, functions, media, auth-bridge, dan integration, serta memeriksa kunci API | Kong |

### 5.2 API dan layanan inti Supabase

| Node | Fungsi | Teknologi |
|---|---|---|
| `rest` (2 replika) | API utama untuk aplikasi dan Hub: feed, chat, profil, tiket, Pusat Bantuan. Semua lewat fungsi SQL dan RLS | PostgREST |
| `realtime` | Mengantar pesan chat baru, status mengetik, presence, dan siaran dari trigger database secara seketika | Supabase Realtime |
| `auth` | Akun dan sesi **staf** Hub, 2FA, kunci akun setelah salah password. Nasabah tidak login di sini | GoTrue |
| `storage` | Penyimpanan file: foto profil, gambar postingan, lampiran chat CS, gambar dan lampiran FAQ, gambar banner | Supabase Storage |
| `imgproxy` (2 replika) | Mengecilkan dan memotong gambar sesuai ukuran layar | imgproxy |
| `functions` | Fungsi `cs-admin` untuk Hub: membuat akun staf, reset password staf | Deno Edge Runtime |
| `meta`, `studio` | Dashboard database untuk tim teknis. Di produksi hanya lewat jalur admin `127.0.0.1` | Supabase Studio |

### 5.3 Layanan buatan sendiri (Go)

| Node | Fungsi |
|---|---|
| `auth-bridge` (2 replika) | Memverifikasi token sosial dari OLT dengan kunci publik OLT (JWKS), membuat atau memperbarui profil nasabah, lalu menerbitkan sesi sosial 15 menit. Menahan login ulang 72 jam setelah akun dihapus |
| `media` (2 replika) | Pintu unggah file nasabah: memeriksa jenis file, membuang EXIF/GPS, meminta `classifier` menilai gambar dan `clamav` memindai dokumen/video, lalu menyimpan ke Storage |
| `classifier` (2 replika) | Model AI lokal untuk menilai gambar tidak pantas (NSFW) sebelum boleh tampil |
| `clamav` | Antivirus untuk dokumen dan video chat CS (signature diperbarui otomatis) |
| `integration` (2 replika) | API `/integration/v1` untuk sistem OLT: notifikasi transaksi ke nasabah dan postingan akun bot resmi, dengan API key yang dibuat di Hub |
| `research` | Riset: menerima data riset (saat ini file XBRL laporan keuangan IDX) di `/integration/v1/research` dan dari Hub, mengurai satu file sekali jalan, lalu membuat ringkasan dan kartu riset sebagai postingan resmi yang menunggu persetujuan. Dokumen sumber (PDF/XLSX laporan asli) diperiksa isi dan antivirusnya sebelum ikut dilampirkan. Container sendiri dengan batas CPU dan memori kecil agar tidak membebani layanan lain |
| `nasabah-gateway` | Jembatan menu **Akun Nasabah** di Hub ke csAdmin OLT dengan token integrasi Ed25519. Khusus staf, dan memeriksa 2FA |
| `notifier` | Mengambil antrean push di database dan mengirimnya ke HP lewat FCM. Kunci Firebase diunggah Super Admin di Hub (disimpan di Vault) |
| `link-preview` | Mengambil judul dan gambar untuk pratinjau tautan, dengan pengaman SSRF (tidak bisa diarahkan ke jaringan internal) |
| `janitor` | Menghapus file yang sudah tidak dipakai, misalnya lampiran akun yang dihapus (antrean `storage_cleanup_queue`) |
| `sentinel` | Memantau semua layanan, disk, dan database setiap ±30 detik, membuat alert, mengirimnya ke Telegram/email, dan mengisi Peta layanan |
| `healer` | Me-restart otomatis layanan yang hidup tetapi macet, satu replika demi satu |
| `backup` | WAL terus-menerus + backup penuh terenkripsi (restic) ke S3 atau folder lokal, uji restore mingguan |
| `trade-relay` | Relay order/trade realtime dari OLT untuk fitur Berbagi Trade. **Dijeda**, tidak berjalan |

### 5.4 Data

| Node | Fungsi |
|---|---|
| `db` | PostgreSQL 17: semua data dan aturan bisnis. Satu-satunya bagian yang tidak boleh hilang; backup melindunginya |
| `pgbouncer` | Pool koneksi antara layanan dan Postgres (mode `session`, pool bawaan 24), supaya menambah replika tidak melipatgandakan koneksi database |
| `valkey` | Penghitung rate limit login. Tidak menyimpan data penting; isinya boleh hilang |

### 5.5 Berjalan sekali, alat, dan khusus dev

| Node | Fungsi |
|---|---|
| `migrate` | Memasang migrasi SQL baru setiap `make up`, lalu selesai. Setiap file dicatat dengan checksum di `olt_internal.schema_migrations`; file yang berubah setelah terpasang ditolak |
| `volume-init` | Menyiapkan folder volume dan izinnya, lalu selesai |
| `tools` | Alat operasional (backup sesaat, uji, data contoh), dijalankan tim IT sesekali |
| `cs-console` | Web Hub (hasil build `rendezvous_hub`) |
| `dummy-olt` | OLT tiruan untuk uji login di dev. Tidak dipakai di produksi |

## 6. Database: jantung sistem

**Isi utama per skema:**

| Skema | Isi |
|---|---|
| `public` | Data komunitas dan chat: profil, postingan, komentar, follow, room, pesan, notifikasi, pengaturan privasi |
| `cs` | Data CS dan Hub: staf, tiket, topik, FAQ, kepatuhan, audit, banner, kebijakan |
| `cs_api` | Fungsi yang boleh dipanggil: RPC chat CS untuk nasabah dan RPC staf untuk Hub |
| `private` | Fungsi dan tabel internal yang tidak terbuka ke API: pengaturan, rate limit, moderasi, antrean push, pembersihan file |
| `admin_api` | API moderasi lama untuk admin |
| `olt_internal` | Catatan migrasi |
| `vault` | Rahasia terenkripsi (kunci Firebase, password backup, token alert), dikelola dari Hub |

**Cara kerjanya:**

- **RLS (Row Level Security)** di setiap tabel: Postgres sendiri yang menolak data yang bukan hak pengguna, jadi bocornya data tidak bergantung pada kode aplikasi.
- **RPC (fungsi SQL)**: aksi penting seperti kirim pesan, buka tiket, dan simpan artikel adalah fungsi `security definer` yang memeriksa peran, batas, dan input, lalu mencatat audit.
- **pg_cron**: ±30 jadwal berjalan di dalam database, misalnya promosi akun baru setiap 15 menit, pengingat tiket, tutup tiket otomatis, retensi data, dan ringkasan.
- **Siaran realtime** dikirim oleh trigger database ke topik Realtime, sehingga aplikasi tidak perlu bertanya ulang.
- **Migrasi** ada di `supabase/migrations` (`0001`…`0188`). Migrasi yang sudah terpasang tidak pernah diubah; perubahan selalu berupa file baru. File wajib berakhiran baris LF karena dicek checksum-nya.
- **Tes pgTAP** di `supabase/tests` (165 file) menguji setiap aturan. Tes dijalankan di database sekali pakai, bukan di database dev.

## 7. Alur penting

**Login nasabah**

1. Nasabah login di aplikasi OLT seperti biasa.
2. Backend OLT menerbitkan **token sosial** (JWT bertanda tangan Ed25519).
3. Library mengirimnya ke `auth-bridge`. auth-bridge memverifikasi tanda tangan dengan kunci publik OLT, membuat/memperbarui profil, lalu menerbitkan sesi sosial 15 menit.
4. Sebelum sesi habis, library meminta token baru lewat `tokenProvider` aplikasi. Bila OLT berhenti menerbitkan token untuk akun itu (misalnya suspend), akses sosialnya ikut berhenti.

**Postingan dengan gambar**

1. Aplikasi mengunggah gambar ke `/media/v1`.
2. `media` membuang EXIF/GPS dan `classifier` menilai NSFW. Gambar yang lolos disimpan ke `storage`.
3. Aplikasi memanggil RPC lewat `rest`. Database memeriksa kata terlarang, masa akun baru, dan batas kecepatan, lalu menyimpan postingan.
4. Trigger membuat notifikasi untuk pengikut. `notifier` mengirim push bila perlu.

**Chat langsung**

1. Pesan dikirim lewat RPC `send_message` ke `rest`.
2. Trigger database menyiarkan pesan ke topik room di `realtime`, sekali per pesan, bukan per anggota.
3. Aplikasi lawan bicara menerima siaran dan menampilkannya seketika. Bila koneksi putus, library menambal pesan yang tertinggal saat tersambung lagi.

**Chat CS**

1. Nasabah memilih topik. Library menampilkan saran artikel FAQ untuk topik itu terlebih dahulu.
2. Tiket dibuat dan masuk antrean Hub sesuai skill dan prioritas topik.
3. Agen mengklaim lalu membalas. Lampiran dari nasabah lewat `media` + `clamav`.
4. Tiket ditutup dengan rating, atau otomatis setelah N hari tanpa balasan.

**Notifikasi transaksi dari OLT**

1. notifEngine OLT memanggil `/integration/v1` dengan API key.
2. `integration` memasukkan notifikasi ke database, sesuai akun nasabah (klaim `accounts`).
3. Notifikasi tampil di aplikasi, dan `notifier` mengirim push ke HP.

**Menu Akun Nasabah di Hub**

1. Staf (wajib 2FA) membuka menu Akun Nasabah.
2. `nasabah-gateway` memeriksa hak staf di database, lalu meneruskan permintaan ke csAdmin OLT dengan token integrasi.
3. Alamat csAdmin diatur dari Hub.

## 8. Jaringan dan keamanan

- **Dua domain:**
  - **Domain API (publik):** untuk aplikasi nasabah. Hanya meloloskan `/rest/v1`, `/realtime/v1`, `/storage/v1`, `/media/v1`, `/integration/v1`, dan `/bridge/v1`. Path lain menghasilkan 404, termasuk `/auth/v1`, `/functions/v1`, dan Studio. RPC staf ditolak di domain ini.
  - **Domain CS:** untuk Hub, hanya dari IP kantor (`VPN_SOURCE_RANGES`).
- **Network Docker dipisah:** `edge` (Traefik ↔ Kong), `app`, dan `data` (Postgres, PgBouncer, Valkey) tanpa akses internet. Hanya beberapa node yang tersambung ke `egress`: Traefik, functions, notifier, sentinel, link-preview, backup, clamav.
- **Container dikunci:** read-only, non-root, `cap_drop: ALL`, `no-new-privileges`, dan batas CPU/memori/pids.
- **Rahasia** hanya dari Docker secrets (`docker/secrets/`) dan Vault. `docker/.env` berisi konfigurasi, bukan kunci.
- **Staf:**
  - 2FA TOTP wajib untuk Super Admin, dan bisa diwajibkan untuk peran lain.
  - Akun dikunci 15 menit setelah 5 password salah.
  - Semua perubahan pengaturan tercatat di **Kepatuhan → Jejak Audit**.
  - Perubahan kebijakan konten butuh persetujuan staf kedua (empat mata).
- **Konten:** kata terlarang, NSFW lokal, antivirus, masa akun baru, rate limit per aksi, dan anti-manipulasi pasar ([content-safety.md](../content-safety.md)).

## 9. Server

### 9.1 Profil deploy

Semua profil memakai image dan nama layanan yang sama; bedanya hanya file override ([skalabilitas.md](skalabilitas.md)).

| Profil | Untuk | Ciri |
|---|---|---|
| `dev` | Pengembangan dan uji | HTTP `:8000`, semua path terbuka (Studio), log debug, bisa memakai OLT tiruan |
| `single` | Produksi satu server (**siap pakai**) | HTTPS Let's Encrypt, hanya path API publik, Studio mati |
| `cluster` | Banyak server (Docker Swarm) | Replika antar-node, Realtime cluster, storage S3. **Masih kerangka**, dirinci di Tahap 7 |

Database terkelola dari penyedia cloud (managed DB) belum didukung, karena sistem memakai role, ekstensi, dan Vault milik image Supabase.

### 9.2 Ukuran server

| Tahap | CPU | RAM | Disk |
|---|---|---|---|
| Minimum (UAT, pilot) | 8 vCPU | 16 GB | 200 GB NVMe |
| **Produksi awal (disarankan)** | **16 vCPU** | **32 GB** | **500 GB NVMe** |
| Tumbuh besar | Server aplikasi 16–32 vCPU / 32–64 GB + **server database terpisah** | | NVMe terpisah |

Sistem operasi Ubuntu LTS; firewall hanya membuka 80/443, dan 22 untuk IP admin. Rincian: [spesifikasi-server.md](spesifikasi-server.md).

### 9.3 Server yang dipakai sekarang

| Server | Peran |
|---|---|
| Laptop/PC developer | Stack `dev` lokal untuk pengembangan. Database dev **tidak** dipasangi migrasi baru sembarangan; tes memakai database sekali pakai |
| `192.168.0.235` (jaringan kantor) | Server uji tempat update dipasang (`git pull` + `make up`). Konfigurasi aplikasi OLT saat ini menunjuk ke sini |
| Produksi | Belum go-live. Mengikuti [instalasi-server.md](instalasi-server.md) dan [checklist-go-live.md](checklist-go-live.md) |

### 9.4 Memasang dan memperbarui

- **Server baru:** skrip `scripts/server-install.sh` memasang Docker, meng-clone kedua repo (`~/chat_service_supabase` dan `~/rendezvous_hub`), membuat rahasia, lalu menjalankan stack ([instalasi-server.md](instalasi-server.md)).
- **Update:** `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`. `make up` membangun ulang image yang berubah, menjalankan `migrate`, lalu menyalakan layanan. Baca [catatan-rilis.md](catatan-rilis.md) sebelum update. Rollback ada di [pembaruan-sistem.md](pembaruan-sistem.md).
- **Di mana mengatur apa:** Hub untuk hampir semua pengaturan, `docker/.env` untuk domain dan kapasitas, `docker/secrets/` untuk kunci dasar ([operasional.md](operasional.md#2-di-mana-mengatur-apa)).

## 10. Pemantauan dan pemulihan

- **Peta layanan dan alert:** `sentinel` mengirim alert ke Telegram/email saat layanan mati, disk hampir penuh, antrean menumpuk, backup gagal, atau pemindai virus tidak sehat. Kanal alert diatur di Hub.
- **Pulih sendiri:** Docker menyalakan ulang container yang mati, `healer` me-restart yang macet, dan aplikasi menyambung ulang serta menambal pesan sendiri.
- **Backup:** WAL dikirim terus-menerus dan backup penuh dibuat berkala ke S3 di luar server (atau folder lokal), dengan uji restore mingguan. Simpan password backup, `docker/.env`, `docker/secrets/`, dan `pgsodium_root.key` di luar server ([backup.md](backup.md)).
- **Saat gangguan:** ikuti [gangguan.md](gangguan.md).

## 11. Cara kerja pengembangan

- **Alur perubahan fitur yang biasa:**
  1. Migrasi SQL dan tes pgTAP baru di server.
  2. Halaman Hub.
  3. Layar library dan rilis tag.
  4. Aplikasi OLT menaikkan tag.
- **Verifikasi sebelum commit:**
  - **Server:** pgTAP penuh di database sekali pakai.
  - **Hub:** `npm run ci` (lint, typecheck, tes, build, ukuran bundle, lisensi).
  - **Library:** analyze, format, tes, pemeriksaan komentar dan logging.
  - Semua repo dipindai gitleaks sebelum commit.
- **Aturan kode:**
  - Kode baru tanpa komentar kecuali yang penting.
  - Log dan pesan error internal dalam bahasa Inggris; teks produk dan dokumentasi dalam bahasa Indonesia.
  - Migrasi lama tidak diubah.
- **CI:** GitHub Actions di setiap repo:
  - **Server** (`backend.yml`): tes Go, pemeriksaan komentar Go, pgTAP, smoke test, dan gitleaks.
  - **Hub** (`ci.yml`): pemeriksaan yang sama dengan `npm run ci`.
  - **Library** (`ci.yml`): analyze, format, tes, dan audit lisensi.

## 12. Istilah

| Istilah | Arti |
|---|---|
| **RLS** | Row Level Security: aturan di database yang menentukan baris mana yang boleh dilihat atau diubah setiap pengguna |
| **RPC** | Fungsi SQL yang dipanggil aplikasi lewat `/rest/v1/rpc/<nama>` |
| **Migrasi** | File SQL bernomor yang mengubah struktur atau aturan database, dipasang berurutan oleh `migrate` |
| **Token sosial** | JWT dari OLT yang membuktikan nasabah sudah login di OLT; ditukar auth-bridge menjadi sesi sosial |
| **JWKS** | Daftar kunci publik OLT yang dipakai auth-bridge untuk memverifikasi token sosial |
| **WAL** | Catatan perubahan Postgres; dikirim terus ke backup supaya data bisa dipulihkan sampai detik terakhir |
| **Replika** | Salinan layanan yang berjalan bersamaan untuk membagi beban |
| **Profil** | Susunan compose (`dev`, `single`, `cluster`) yang menentukan cara stack dijalankan |
| **Empat mata** | Perubahan yang harus disetujui staf kedua sebelum berlaku |
| **Kill switch** | Saklar di Hub untuk mematikan fitur tertentu di aplikasi seketika |

## 13. Baca lanjut

| Topik | Dokumen |
|---|---|
| Semua fitur | [daftar-fitur.md](daftar-fitur.md) |
| Operasional harian dan dampak per layanan | [operasional.md](operasional.md) |
| Arsitektur produksi, monitoring, rotasi kunci | [produksi.md](produksi.md) |
| Replika dan rencana cluster | [skalabilitas.md](skalabilitas.md) |
| Server dev untuk tim aplikasi | [server-development.md](server-development.md) |
| Integrasi login OLT | [olt-integration.md](../olt-integration.md) |
| Library Flutter | [rendezvous-community/](../rendezvous-community/README.md) |
| Modul belajar teknis (SQL, RLS, PostgREST, Realtime, infrastruktur) | [belajar/](../belajar/README.md) |
| Pelatihan staf memakai Hub | [hub-untuk-staf.md](hub-untuk-staf.md) |
