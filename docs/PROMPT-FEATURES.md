# Addendum 2: Fitur Lanjutan, Integrasi Pasar & Moderasi — OLT Social

> Addendum ini **melengkapi** `docs/PROMPT.md` dan `docs/PROMPT-PRODUCTION.md`. Simpan sebagai `docs/PROMPT-FEATURES.md`.
> Semua aturan di dua dokumen sebelumnya tetap berlaku untuk fitur di sini, yaitu lisensi permisif, Docker, stateless, RLS, rate limit, dan keamanan.
> Bagian bertanda `[...]` silakan disesuaikan.

---

## 0. Prinsip

- Package `olt_social` tetap **terpisah dari kode trading**. Data pasar dan portofolio masuk lewat **interface / adapter**, bukan dengan memanggil kode OLT langsung.
- **Data yang memengaruhi kredibilitas tidak boleh berasal dari client**, karena client bisa dimanipulasi. Contohnya harga saat posting, badge holder, dan badge verifikasi. Data tersebut diambil atau diverifikasi **di sisi server**.
- Setiap fitur baru berada di balik **feature flag** (bagian 6), supaya bisa dirilis bertahap dan dimatikan seketika.
- Setiap fitur baru wajib punya RLS, rate limit, tes, dan dokumentasi.

---

## 1. Integrasi Data Pasar & Portofolio OLT

### 1.1 Service `market-adapter` (baru, Dockerized, stateless)
Service internal yang menjadi jembatan ke data pasar OLT. Sumber datanya:
`[jelaskan sumber data harga OLT, contoh: WebSocket market feed OLT / GRPC ClientEngine, format pesan harga]`.

Endpoint internal (tidak diakses publik, hanya dipanggil service lain dan database):
- `GET /quote/{code}`: harga terakhir, perubahan, persentase, volume, dan timestamp.
- `POST /quotes`: batch beberapa kode.
- Cache harga di Valkey dengan TTL `[1–3 detik]`, supaya ribuan post tidak membanjiri sumber data OLT.
- Pakai timeout, circuit breaker, dan fallback. Kalau data pasar tidak tersedia, fitur sosial tetap jalan, hanya kartu harga yang menampilkan "harga tidak tersedia".

Untuk development, sediakan **mode mock** yang menghasilkan harga acak realistis untuk saham-saham di seed.

### 1.2 Sinkronisasi daftar saham
- Isi tabel `stocks` dari sumber OLT dengan kolom kode, nama, sektor, papan, dan status (aktif, suspend, delisting).
- Sinkron otomatis harian lewat job terjadwal yang berjalan sekali per cluster.

### 1.3 Portofolio (untuk badge Holder)
- Data kepemilikan diambil server-side dari OLT `[jelaskan sumber: WebSocket / GRPC, request portofolio per user]` lewat `market-adapter` atau `auth-bridge`.
- Yang disimpan **hanya status boolean per saham** (`holds = true/false`) beserta waktu verifikasi terakhir. **Jangan pernah menyimpan jumlah lot, nilai, atau harga beli.**

### 1.4 Di sisi Flutter
Aplikasi host (OLT) menyuplai harga real-time lewat interface, supaya kartu saham di UI memakai stream harga OLT yang sudah ada tanpa koneksi tambahan:

```dart
abstract class OltMarketDataProvider {
  Stream<StockQuote> watchQuote(String code);
  Future<StockQuote?> getQuote(String code);
}
```

Callback `onStockTap(code)` membuka halaman saham atau order di OLT.

---

## 2. Fitur Wajib Sebelum Launch

### 2.1 Panel Admin & Moderasi
Dibangun sebagai **Flutter web** di dalam monorepo (`apps/admin`), di-deploy sebagai container Nginx statis, dan **hanya bisa diakses lewat VPN**.

Fitur:
- Antrean report dengan prioritas, aksi (hapus, sembunyikan, abaikan), dan alasan.
- Detail user: riwayat post, report, dan pelanggaran, serta aksi **peringatan, mute, ban sementara, dan ban permanen**.
- Kelola filter kata, daftar domain terlarang, dan aturan anti-spam tanpa deploy ulang.
- Kelola badge verifikasi, akun bot, dan konten yang di-pin.
- Kelola feature flag.
- Dashboard ringkas berisi jumlah report, konten yang dihapus, dan peringatan manipulasi (bagian 2.2).

Hak akses dan pencatatan:
- Role admin: `super_admin` (teknis), `compliance_admin` (akun sekuritas, pemegang kebijakan konten, lihat 2.6.c), `moderator`, `room_moderator`, dan `viewer`. Dicek di RLS dan fungsi server, bukan hanya disembunyikan di UI.
- **Login admin** memakai akun terpisah dengan 2FA (TOTP).
- **Semua aksi admin tercatat di audit log** dan tidak bisa dihapus dari panel.

### 2.2 Anti Manipulasi Pasar ("goreng saham")
**Deteksi** lewat job berkala, misalnya tiap `[5]` menit:
- **Lonjakan mention** suatu saham jauh di atas rata-rata historisnya, misalnya > `[5]`x rata-rata 7 hari.
- **Konsentrasi akun baru**: mayoritas mention suatu saham berasal dari akun berumur < `[7]` hari.
- **Pola terkoordinasi**: banyak akun memposting teks sangat mirip dalam waktu singkat (kemiripan dengan `pg_trgm`), atau akun-akun yang saling follow dan saling like secara intens.

**Hasil deteksi:**
- Masuk ke tabel `manipulation_alerts`, tampil di panel admin, dan memicu alert ke moderator.
- Aksi otomatis yang bisa dikonfigurasi:
  - Turunkan peringkat konten di trending.
  - Tandai post dengan label "Konten sedang ditinjau".
  - Aktifkan *slow mode* di room saham terkait.

**Filter promosi:**
- Blokir atau tahan untuk review konten yang mengandung nomor telepon, link WhatsApp/Telegram/Discord, kata kunci "grup VIP", "sinyal berbayar", "join premium", dan sejenisnya. Daftar ini bisa diatur dari panel.

**Retensi untuk regulator:**
- Konten yang dihapus user maupun moderator tetap disimpan di arsip (`content_archive`) selama `[X tahun]` dan hanya bisa diakses `super_admin`.
- Sediakan ekspor data per saham atau per user untuk rentang waktu tertentu (CSV/JSON) guna memenuhi permintaan resmi.
- Arsip ini dikecualikan dari "hapus akun" sejauh diwajibkan regulasi. Jelaskan konsekuensinya di kebijakan privasi.

### 2.3 Syarat & Ketentuan dan Pedoman Komunitas
- Tabel `legal_documents` (jenis, versi, isi, tanggal berlaku) dan `user_consents` (user, dokumen, versi, waktu setuju).
- User **wajib menyetujui** versi terbaru sebelum posting, berkomentar, atau chat. Kalau dokumen diperbarui, user diminta menyetujui ulang.
- Penegakan di **server**: RPC tulis menolak user yang belum menyetujui versi terbaru.
- Isi dokumen: `[disusun bersama tim legal]`. Sediakan template draf awal dalam Bahasa Indonesia.

### 2.4 Notifikasi
Jenis notifikasi:
- Balasan komentar
- Mention
- Like
- Follow
- Pesan chat
- Post baru dari user yang di-follow (opsional)
- Aktivitas di saham watchlist (opsional)

**Pengaturan per user:**
- Nyala/mati per jenis dan per kanal (in-app, push).
- **Jam tenang**.
- **Mute kata, user, atau saham tertentu**. Konten yang di-mute disaring di server lewat RPC feed, bukan hanya disembunyikan di client.

**Push notification:**
- **Android**: Firebase Cloud Messaging (`firebase_messaging`). Pengiriman dilakukan service `notifier` (baru, Dockerized, stateless) yang membaca antrean notifikasi dari Postgres.
  - Gunakan `SELECT ... FOR UPDATE SKIP LOCKED` supaya aman dijalankan banyak replika.
  - Retry dengan backoff, dan hapus token perangkat yang tidak valid.
- **Windows**: notifikasi lokal Windows (toast) dipicu dari Realtime selama aplikasi berjalan.

Tabel `device_tokens` mencatat user, platform, token, dan terakhir aktif. Notifikasi digabung (*batching*), misalnya "5 orang menyukai post Anda", supaya tidak spam.

### 2.5 Pencarian
- Menggunakan Postgres **full-text search** dengan konfigurasi bahasa Indonesia + `simple`, ditambah **`pg_trgm`** untuk pencarian mirip / salah ketik. Tidak perlu service tambahan.
- Cakupan:
  - Post (isi teks)
  - User (username, display name)
  - Saham (kode, nama)
  - Hashtag `#topik`
- RPC `search(query, type, cursor, limit)` dengan pagination cursor, menghormati block/mute, dan memakai rate limit.
- Index GIN untuk performa, dengan hasil diurutkan berdasarkan relevansi + kesegaran.

### 2.6 Keamanan Konten (Content Safety)

**Tujuan:** fitur sosial OLT **tidak boleh** menjadi tempat konten porno, judi online, penipuan, atau konten berbahaya lainnya, baik di feed, komentar, maupun chat pribadi dan grup. Konten yang melanggar harus **diblokir sebelum tampil**, bukan hanya dihapus setelah dilaporkan.

#### a. Kategori konten terlarang
Setiap kategori punya tingkat keparahan dan aksi default yang **bisa diubah oleh akun sekuritas** (bagian c):

| Kategori | Contoh | Aksi default |
|---|---|---|
| **Eksploitasi seksual anak (CSAM)** | Apa pun yang melibatkan anak | **Toleransi nol**: blokir, tidak bisa diubah oleh siapa pun, simpan bukti secara aman sesuai hukum, ban permanen, laporkan ke pihak berwenang (bagian f) |
| **Pornografi & konten seksual** | Gambar telanjang/vulgar, ajakan seksual, *open BO*, jual konten dewasa, link situs porno | Blokir + peringatan, ban jika berulang |
| **Judi online** | Promosi situs judi/slot, "gacor", "maxwin", link deposit | Blokir + ban |
| **Penipuan & investasi bodong** | Janji profit pasti, skema ponzi, *robot trading* ilegal, penawaran jasa kelola dana, phishing, akun yang menyamar sebagai pihak sekuritas | Blokir + tahan untuk review |
| **Pinjol ilegal & jual-beli data** | Promosi pinjaman ilegal, jual data/akun | Blokir |
| **Ujaran kebencian & SARA** | Serangan berdasarkan suku, agama, ras, antargolongan | Tahan untuk review |
| **Kekerasan, ancaman, & konten sadis** | Ancaman ke user lain, gambar sadis | Blokir + review |
| **Pelecehan & perundungan** | Hinaan berulang ke user tertentu, doxxing (menyebar data pribadi) | Tahan untuk review |
| **Narkoba & barang ilegal** | Jual-beli narkoba, senjata | Blokir + ban |
| **Spam & promosi** | Promosi berulang, grup VIP, sinyal berbayar (lihat 2.2) | Tahan untuk review |
| **Kata kasar ringan** | Umpatan umum | Sensor otomatis (`***`) atau izinkan, sesuai kebijakan |

#### b. Pipeline moderasi
Buat service baru **`moderation`** (Dockerized, stateless, bisa banyak replika):

1. **Pemeriksaan teks sinkron (sebelum disimpan, target < `[50 ms]`)**
   - Dipanggil oleh RPC tulis (post, komentar, pesan chat, bio, username, nama grup).
   - **Normalisasi** sebelum dicek, untuk melawan akal-akalan penulisan:
     - Huruf kecil semua.
     - Hapus spasi/titik di antara huruf (`b.o.k.e.p` → `bokep`).
     - Ganti angka/simbol menjadi huruf (`p0rn` → `porn`, `$lot` → `slot`).
     - Ringkas huruf berulang.
     - Ubah emoji ke kategori.
     - Seragamkan karakter Unicode yang mirip (homoglyph).
   - Pencocokan **daftar kata dan pola (regex) bahasa Indonesia + Inggris**, termasuk slang lokal.
     - Daftar awal disiapkan di seed.
     - Selanjutnya dikelola akun sekuritas dari panel admin, di-cache di Valkey, dan di-refresh otomatis saat berubah.
   - Pemeriksaan **link**: domain dicocokkan dengan daftar blokir (porno, judi, phishing) dan daftar izin. Link pendek (bit.ly dan sejenisnya) di-resolve dulu dengan proteksi SSRF yang sama seperti link preview.
   - Hasilnya salah satu dari: `allow`, `censor`, `hold` (tahan untuk review, hanya terlihat oleh pengirim), atau `block` (ditolak dengan pesan yang jelas ke user).
2. **Pemeriksaan gambar asinkron (sebelum terlihat orang lain)**
   - Setiap gambar yang diunggah (post, komentar, chat, avatar, banner) berstatus **`pending`** dan **tidak terlihat oleh user lain** sampai lolos pemeriksaan.
   - Gunakan **model klasifikasi NSFW open-source yang dijalankan sendiri** (ONNX Runtime, CPU cukup) di dalam container `moderation`.
     - **Wajib memilih model dengan lisensi permisif** (MIT/Apache 2.0) dan mencatat lisensinya, contohnya model NSFW image classifier berlisensi Apache 2.0 dari Hugging Face. **Verifikasi lisensinya, jangan menebak.**
   - Threshold per kategori (porno, seksi/provokatif, sadis) bisa diatur dari panel. Skor di antara ambang aman dan ambang blokir masuk antrean review manual.
   - Gunakan antrean di Postgres (`SKIP LOCKED`) agar aman dijalankan di banyak replika. Kalau service moderasi mati, gambar tetap `pending` (*fail closed*), bukan otomatis lolos.
3. **Klasifikasi teks berbasis model (opsional, fase berikutnya)**
   - Siapkan interface supaya model toksisitas bahasa Indonesia (lisensi permisif, self-hosted) bisa ditambahkan nanti untuk menangkap ujaran kebencian yang tidak terdeteksi daftar kata.
4. **Pemeriksaan reaktif**
   - Report dari user, akumulasi report pada satu konten (otomatis disembunyikan setelah `[N]` report dari akun tepercaya), dan pemindaian ulang konten lama saat daftar kata atau model diperbarui.

Semua keputusan moderasi dicatat di `moderation_decisions` (konten, kategori, skor, aturan yang cocok, aksi, waktu), supaya bisa diaudit dan dipakai menyetel aturan.

#### c. Boundary (Kebijakan) yang Diatur Akun Sekuritas
Akun **sekuritas** (pemilik platform) memiliki role tertinggi untuk kebijakan konten, yaitu **`compliance_admin`**. Akun ini bisa membuat dan mengubah **boundary** dari panel admin tanpa deploy ulang:

- **Kebijakan global** berlaku untuk semua feed dan chat:
  - Kategori yang aktif, tingkat keparahan, aksi (`allow` / `censor` / `hold` / `block`), dan threshold skor gambar per kategori.
  - Daftar kata, frasa, dan regex terlarang, ditambah daftar pengecualian (*allowlist*). Contohnya, istilah saham yang mirip kata terlarang tidak ikut terblokir.
  - Daftar domain yang diblokir dan diizinkan, serta apakah link boleh dikirim sama sekali.
  - Jenis konten yang diizinkan: teks saja, gambar, link, dan polling.
- **Batasan berdasarkan kepercayaan akun**:
  - Akun baru (umur < `[X hari]` atau `trust_level` rendah) **tidak bisa** mengirim gambar, link, atau DM ke orang yang tidak saling follow.
  - Hanya akun terverifikasi yang boleh membuat grup atau room publik.
- **Aturan DM**:
  - Pesan dari orang yang tidak di-follow masuk ke **"Permintaan pesan"** terlebih dahulu, dan gambar di permintaan pesan diburamkan sampai diterima.
  - User bisa mematikan DM dari orang asing.
- **Aturan per room / per saham**: boleh **memperketat** kebijakan global (misalnya room saham tertentu hanya teks, slow mode, atau hanya akun terverifikasi), tetapi **tidak boleh melonggarkannya**. Aturan ini ditegakkan di server.
- **Aturan berbasis waktu**, misalnya mode ketat otomatis di jam ramai atau saat ada insiden.
- **Sanksi bertingkat** yang bisa diatur:
  - Peringatan → mute `[1 jam]` → mute `[24 jam]` → ban `[7 hari]` → ban permanen.
  - Pelanggaran kategori berat (CSAM, judi, porno) bisa langsung ke ban permanen.
- **Pengamanan perubahan kebijakan**:
  - Setiap perubahan **diberi versi**, tercatat di audit log (siapa, kapan, apa yang diubah), dan **bisa dikembalikan (rollback)**.
  - Sediakan fitur **simulasi**: uji aturan baru terhadap contoh teks dan konten 7 hari terakhir untuk melihat berapa banyak yang akan terblokir, sebelum diaktifkan.
  - Perubahan yang melonggarkan kategori berat butuh persetujuan **dua orang** `compliance_admin` (*four-eyes*). Kategori CSAM tidak bisa dilonggarkan sama sekali.

Hierarki peran:
- **`compliance_admin`** (akun sekuritas): mengatur kebijakan global dan menunjuk moderator.
- **`moderator`**: menegakkan kebijakan (review antrean, hapus konten, beri sanksi), tetapi tidak bisa mengubah kebijakan global.
- **`room_moderator`**: hanya mengelola room tertentu dan hanya bisa memperketat.

Semua peran dicek di RLS dan fungsi server.

Akun resmi sekuritas tampil dengan **badge resmi** yang tidak bisa ditiru. Username, display name, atau avatar yang meniru nama atau logo sekuritas **diblokir** untuk mencegah penipuan yang mengatasnamakan sekuritas.

#### d. Pengalaman User
- Saat konten diblokir, user mendapat pesan yang jelas tanpa membocorkan detail aturan, misalnya "Pesan Anda melanggar Pedoman Komunitas (konten dewasa)".
- Konten yang ditahan diberi label "Sedang ditinjau" dan hanya terlihat oleh pengirim.
- User bisa **mengajukan banding** atas konten yang dihapus atau sanksi. Banding masuk ke antrean moderator dan ditinjau oleh moderator lain.
- Tombol **report** tersedia di semua tempat (post, komentar, pesan chat, profil, grup) dengan pilihan kategori. Gambar yang dilaporkan sebagai porno langsung diburamkan sementara untuk pelapor.
- Fitur **block** dan **mute** user.

#### e. Penanganan Bukti & Privasi Moderator
- Konten yang diblokir disimpan di **karantina terenkripsi** (bucket privat terpisah) dengan akses terbatas dan tercatat, lalu otomatis dihapus setelah `[X hari]`. Pengecualiannya adalah bukti yang wajib disimpan untuk proses hukum.
- Di panel review, gambar yang ditandai porno atau sadis **ditampilkan buram secara default**, dan moderator harus mengeklik untuk melihat. Ini melindungi kesehatan mental moderator.
- Moderator hanya bisa membuka isi DM yang **dilaporkan** atau **ditandai sistem**. Tidak boleh ada akses bebas ke seluruh percakapan pribadi, dan setiap akses tercatat di audit log.

#### f. Penanganan CSAM
- Toleransi nol: konten diblokir otomatis, akun di-ban permanen, dan **semua konten akun tersebut disembunyikan**.
- Bukti tidak boleh disebarkan atau ditampilkan ulang. Akses hanya untuk `compliance_admin` yang ditunjuk, dan setiap akses tercatat.
- Sediakan alur pelaporan ke pihak berwenang sesuai hukum Indonesia, `[ditentukan bersama tim legal, misalnya Komdigi / Polri]`. Dokumentasikan prosedurnya di `docs/content-safety.md`.
- Siapkan integrasi opsional ke layanan pencocokan hash CSAM resmi bila tersedia dan perizinannya terpenuhi.

#### g. Pengujian
- **Tes daftar kata dan normalisasi**: kumpulan contoh teks pelanggaran (termasuk akal-akalan penulisan) yang harus terblokir, dan contoh teks wajar seputar saham yang **tidak boleh** ikut terblokir (uji *false positive*).
- **Tes gambar** memakai dataset uji yang aman dan legal. **Jangan pernah memakai atau membuat konten CSAM untuk pengujian.** Kategori CSAM cukup diuji lewat alur (mock flag), bukan dengan konten nyata.
- Tes bahwa gambar `pending` tidak bisa diakses user lain lewat URL atau API apa pun.
- Tes bahwa aturan room tidak bisa melonggarkan kebijakan global.
- Tes bahwa *fail closed* bekerja ketika service moderasi mati.

---

## 3. Fitur Pembeda

### 3.1 Kartu Saham Live
- `$KODE` di post, komentar, dan chat dirender sebagai **kartu kecil**: kode, nama, harga terakhir, perubahan, dan persentase berwarna hijau/merah.
- Harga diperbarui real-time dari `OltMarketDataProvider`.
- Kalau lebih dari satu saham disebut, tampilkan maksimal `[3]` kartu, lalu sisanya sebagai chip.

### 3.2 Harga Saat Posting & Track Record
- Saat post dibuat, **server** (trigger / Edge Function → `market-adapter`) mengambil harga setiap saham yang disebut, lalu menyimpannya di `post_stocks.price_at_post` dan `price_at_post_time`. **Harga dari client diabaikan.**
- Di UI, tampilkan misalnya "Diposting saat BBCA 9.250 · sekarang 9.600 (+3,8%)".
- **Track record user** (opsional, bisa disembunyikan user):
  - Untuk post dengan sentimen bullish/bearish, hitung arah harga setelah `[1 hari, 1 minggu, 1 bulan]`.
  - Tampilkan ringkasan akurasi di profil.
  - Dihitung lewat job berkala, bukan saat request.
- Tampilkan disclaimer bahwa track record tidak menjamin hasil di masa depan.

### 3.3 Sentimen & Trending
Di halaman saham:
- Rasio bullish/bearish `[24 jam / 7 hari]`
- Jumlah post
- Daftar post terpopuler

Halaman **Trending**:
- Saham paling banyak dibahas, saham dengan kenaikan diskusi tertinggi, dan post populer.
- Skor popularitas memakai peluruhan waktu (misalnya gaya *hot ranking*) dan dihitung di materialized view / tabel agregat yang di-refresh berkala, bukan dihitung per request.
- Konten dengan `manipulation_alerts` aktif atau dari akun baru diberi bobot lebih rendah.

### 3.4 Badge Holder (opt-in)
- User mengaktifkan dari pengaturan privasi (**default: mati**). Badge "Holder" lalu muncul di post atau komentar tentang saham yang **benar-benar** dimilikinya.
- Status diverifikasi server dari portofolio OLT (bagian 1.3) saat posting dan di-refresh berkala. Badge dicabut otomatis kalau saham sudah dijual.
- Tidak pernah menampilkan jumlah, nilai, atau harga beli.

### 3.5 Badge Verifikasi & Akun Bot
Jenis badge dikelola dari panel admin:
- `verified_analyst`
- `official_broker`
- `official_account`

Akun bot resmi untuk aksi korporasi, berita, dan pengumuman:
- Berlabel jelas "Bot", posting lewat API internal dengan service key khusus, dan memiliki rate limit sendiri.
- Sumber data: `[jelaskan sumber berita/aksi korporasi]`.

### 3.6 Share Chart dari OLT
OLT bisa membuka composer dengan gambar chart yang sudah dirender, misalnya `OltComposePost(initialStock: 'BBCA', initialImage: bytes)`.

Gambar diunggah lewat jalur upload yang sama: validasi, penghapusan metadata, dan imgproxy.

### 3.7 Room Saham & Slow Mode
- Room chat otomatis per saham (`type = stock`). Siapa pun bisa bergabung, dan pesan bisa dibaca anggota.
- **Slow mode**: jeda minimal antar pesan per user (misalnya `[10]` detik).
  - Otomatis aktif di jam ramai (`[08:55–09:30 WIB]` dan `[15:50–16:15 WIB]`), saat ada manipulation alert, atau saat diaktifkan moderator.
  - Ditegakkan di server.
- Pesan yang di-pin oleh moderator room.

### 3.8 Fitur Sosial Tambahan
- **Polling** di post: 2–4 opsi, durasi, satu suara per user (ditegakkan constraint), dan hasil realtime.
- **Bookmark** post.
- **Draft** post, disimpan lokal di perangkat dan opsional disinkronkan.
- **Edit post/komentar** dengan riwayat edit yang tersimpan dan label "diedit". Edit hanya diizinkan dalam `[15 menit]`, untuk mencegah mengubah isi setelah harga bergerak.
- **Reaksi di chat**, **share post ke chat**, dan **share kartu saham ke chat**.
- **Hashtag** `#topik` yang bisa diklik dan dicari.

---

## 4. Teknis Tambahan

### 4.1 Cache Lokal & Offline (Flutter)
- Gunakan **`drift`** (SQLite, lisensi MIT) untuk cache riwayat chat, daftar room, dan halaman feed terakhir. Aplikasi langsung menampilkan data cache saat dibuka, lalu menyegarkan di latar belakang.
- Antrean pesan keluar disimpan di SQLite dan dikirim ulang saat online, dengan `client_id` untuk idempotensi.
- Ukuran cache dibatasi, misalnya `[N]` pesan terakhir per room, dengan pembersihan otomatis.
- Data cache **dihapus saat logout**.

### 4.2 Link Preview
- Preview dibuat **di server** lewat Edge Function / service `link-preview`, lalu hasilnya di-cache di database.
- **Proteksi SSRF wajib**:
  - Hanya `http`/`https`.
  - Tolak IP privat, loopback, dan metadata cloud, termasuk setelah resolusi DNS dan redirect.
  - Batasi jumlah redirect, ukuran respons, dan timeout.
- Gambar preview diproksikan lewat imgproxy. URL dari domain terlarang tidak dibuatkan preview.

### 4.3 Feature Flag, Remote Config & Kill Switch
- Tabel `feature_flags` dengan target semua user, persentase user, daftar user tertentu, versi aplikasi minimum, dan platform. Dikelola dari panel admin.
- Client membaca flag saat start dan mendengarkan perubahan lewat Realtime.
- **Kill switch global**: satu flag untuk mematikan seluruh fitur sosial seketika. UI sosial disembunyikan dengan rapi, dan fitur trading OLT tidak terpengaruh.
- Remote config untuk nilai seperti batas karakter, jam slow mode, dan teks disclaimer.

### 4.4 Versi Minimum Aplikasi
- Endpoint atau config `min_supported_version` per platform. Kalau versi aplikasi di bawah minimum, fitur sosial menampilkan ajakan update dan memakai mekanisme self-update OLT yang sudah ada.
- RPC dan API lama tetap didukung minimal `[N]` versi ke belakang, sesuai aturan versioning di PROMPT-PRODUCTION.

### 4.5 Analitik Produk (self-hosted, sederhana)
- Tabel `analytics_events` yang dipartisi per bulan dan diisi lewat RPC batch dari client, dengan rate limit.
- Event yang dicatat:
  - Buka feed
  - Buat post, buat komentar, kirim pesan
  - Klik kartu saham
  - Klik dari sosial ke halaman order, untuk mengukur dampak fitur sosial ke trading
- Dashboard Grafana berisi DAU/WAU/MAU, retensi, jumlah konten, dan saham paling dibahas.
- **Privasi**:
  - Tanpa isi pesan atau teks post.
  - Retensi `[12 bulan]`.
  - Ikut terhapus saat user menghapus akun.

---

## 5. Model Data Tambahan (ringkas)

Buat migrasi baru (jangan ubah migrasi lama). Semua tabel ber-RLS, dengan index yang sesuai:

| Kelompok | Tabel |
|---|---|
| Admin & moderasi | `admin_users`, `admin_roles`, `admin_audit_log`, `user_sanctions`, `manipulation_alerts`, `content_archive`, `blocked_patterns` |
| Keamanan konten | `content_policies` (berversi), `policy_categories`, `policy_rules` (kata/regex/domain), `policy_allowlist`, `room_policies`, `moderation_queue`, `moderation_decisions`, `media_scan_results`, `quarantine_items`, `appeals`, `message_requests`, `policy_change_approvals` |
| Legal | `legal_documents`, `user_consents` |
| Notifikasi | `notification_preferences`, `muted_keywords`, `muted_stocks`, `device_tokens`, `notification_queue` |
| Pasar | Kolom tambahan `stocks.sector / board / status`, `post_stocks.price_at_post / price_at_post_time`, `user_holdings_flags`, `stock_sentiment_agg`, `trending_scores` |
| Sosial | `badges`, `user_badges`, `polls`, `poll_options`, `poll_votes`, `bookmarks`, `post_edits`, `hashtags`, `post_hashtags`, `link_previews` |
| Chat | Kolom `chat_rooms.slow_mode_seconds`, `pinned_messages`, `message_reactions` |
| Platform | `feature_flags`, `app_versions`, `analytics_events` (dipartisi) |

---

## 6. Tahapan Pengerjaan Tambahan

Tahap F1 dikerjakan **sebelum go-live**. Tahap F2–F5 dikerjakan setelah tahap 6 (single-node production) dan **sebelum** tahap 7 (multi-node). Semua tetap harus memenuhi aturan stateless supaya otomatis siap multi-node.

1. **F1: Wajib launch**
   - `market-adapter` (mode mock dulu), panel admin + moderasi, **service `moderation` + boundary kebijakan akun sekuritas (2.6)**, anti manipulasi, T&C/consent, notifikasi + push, pencarian, feature flag + kill switch.
   - Kriteria selesai:
     - Moderator bisa menangani report end-to-end.
     - Konten porno, judi, dan penipuan (termasuk penulisan akal-akalan) terblokir di feed, komentar, dan chat. Gambar tidak terlihat orang lain sebelum lolos pemindaian.
     - `compliance_admin` bisa mengubah boundary dari panel, menyimulasikannya, lalu melakukan rollback. Semua tes di 2.6.g lulus.
     - Kill switch terbukti mematikan fitur sosial tanpa mengganggu trading.
     - Push notification sampai di Android.
2. **F2: Integrasi pasar**
   - Kartu saham live, harga saat posting (server-side), sinkron daftar saham, sentimen & trending.
   - Kriteria selesai: harga saat posting tidak bisa dipalsukan dari client (ada tesnya).
3. **F3: Kepercayaan**
   - Badge holder (opt-in), badge verifikasi, akun bot, dan track record.
   - Kriteria selesai: badge holder hilang otomatis setelah saham dijual (dengan data mock).
4. **F4: Pengalaman sosial**
   - Room saham + slow mode, polling, bookmark, draft, edit dengan riwayat, hashtag, reaksi chat, share ke chat, share chart, dan link preview.
   - Kriteria selesai: tes SSRF link preview lulus.
5. **F5: Platform**
   - Cache offline `drift`, versi minimum aplikasi, dan analitik produk.
   - Kriteria selesai: aplikasi bisa dibuka dan menampilkan chat terakhir dalam mode offline.

Setiap tahap: berhenti, ringkas hasilnya, perbarui dokumentasi dan checklist produksi, lalu tunggu konfirmasi saya.

**Sebelum mulai F1:** jelaskan rencana integrasi ke sumber data pasar dan portofolio OLT berdasarkan informasi yang tersedia. Daftar informasi yang masih kurang dari saya (format pesan, endpoint, autentikasi), lalu tunggu jawaban saya.
