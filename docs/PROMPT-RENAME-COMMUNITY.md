# Prompt: Rename `olt_social` → `rendezvous_community`, Hapus Komentar Kode, Log dalam Bahasa Inggris

> Simpan sebagai `docs/PROMPT-RENAME-COMMUNITY.md`.
> Tugas ini **refactor murni**. **Tidak boleh ada perubahan perilaku, fitur, tampilan, API backend, atau skema database.**
> Semua tes yang ada harus tetap lulus.

---

## 1. Tujuan

1. Ganti nama library Flutter **`olt_social`** menjadi **`rendezvous_community`** di seluruh repo dan di aplikasi yang memakainya (aplikasi OLT dan folder `example/`).
2. **Hapus semua komentar** dari kode library dan aplikasi contoh.
3. **Semua pesan log, pesan exception internal, dan pesan debug ditulis dalam Bahasa Inggris** dengan format yang standar dan konsisten.

---

## 2. Rename

### 2.1 Package & file
- `pubspec.yaml`: `name: rendezvous_community`. Perbarui juga `description` dan `homepage`/`repository` bila ada.
- Folder `packages/olt_social/` → `packages/rendezvous_community/`.
- File library utama `lib/olt_social.dart` → `lib/rendezvous_community.dart`.
- Semua import `package:olt_social/...` → `package:rendezvous_community/...`.
- Dependensi di aplikasi OLT dan `example/` (`pubspec.yaml`, termasuk git dependency/path).
  - Naikkan versi menjadi **major berikutnya** (misalnya `2.0.0`), karena ini perubahan yang tidak kompatibel.
  - Buat tag git sesuai versi.
- Jika ada sub-package/modul terkait (misalnya modul support/CS dengan nama `olt_*`), terapkan pola yang sama: `rendezvous_community_<nama>`. Daftar semuanya terlebih dahulu.

### 2.2 Nama kelas & simbol publik
Hapus prefix `Olt` dari API publik library. Gunakan pola berikut:

| Lama | Baru |
|---|---|
| `OltSocial` (kelas inisialisasi) | `RendezvousCommunity` |
| `OltStreamFeed` | `CommunityStreamFeed` |
| `OltStockFeed` | `CommunityStockFeed` |
| `OltPostDetail` | `CommunityPostDetail` |
| `OltComposePost` | `CommunityComposePost` |
| `OltChatList` | `CommunityChatList` |
| `OltChatRoom` | `CommunityChatRoom` |
| `OltMarketDataProvider` | `CommunityMarketDataProvider` |
| `OltSupport...` / widget CS lainnya | `CommunitySupport...` |
| Kelas/simbol `Olt*` lainnya | `Community*` (konsisten) |

- Terapkan juga pada nama file (`olt_stream_feed.dart` → `community_stream_feed.dart`), nama provider/state, extension, enum, dan konstanta.
- Gunakan fitur rename refactoring (Dart analysis server / IDE), bukan cari-ganti teks buta, supaya referensi tidak terlewat.
- Simbol yang memang merujuk ke **aplikasi OLT** dari sisi host (misalnya callback yang membuka halaman OLT, atau `oltTokenProvider`) **boleh tetap** memakai nama OLT. Daftar semua simbol yang dipertahankan beserta alasannya.

### 2.3 Jangan sampai merusak data atau sesi user (penting)
Mengganti nama **tidak boleh** membuat user ter-logout, kehilangan cache, atau kehilangan pesan yang belum terkirim. Periksa semua identitas yang tersimpan di perangkat:
- Kunci `flutter_secure_storage` (token).
- Nama file database `drift`/SQLite (cache chat, antrean pesan offline).
- Kunci shared preferences (draf, pengaturan notifikasi, tema, dan lainnya).
- Nama channel notifikasi Android, nama kanal push, dan ID notifikasi Windows.
- Nama folder cache gambar/lampiran.

Untuk setiap item, pilih salah satu:
- **Tetap memakai nama/kunci lama** (pilihan paling aman), atau
- **Migrasi otomatis satu kali** saat aplikasi pertama kali dibuka setelah update: salin dari kunci/file lama ke yang baru, verifikasi, lalu hapus yang lama. Proses ini harus idempoten dan aman bila terhenti di tengah.

Tulis keputusan per item di ringkasan.

**Yang tidak boleh berubah:** nama topik Realtime, nama tabel/RPC, URL endpoint, dan apa pun yang dipakai backend. Rename ini **hanya di sisi client**.

### 2.4 Referensi lain
Perbarui semua referensi di:
- Dokumentasi (`README`, `docs/`, file `PROMPT-*.md` yang menyebut `olt_social`). Tambahkan catatan "sebelumnya bernama `olt_social`" di README.
- CI/CD, script build, Makefile, Dockerfile, dan konfigurasi analisis (`analysis_options.yaml`).
- Nama route, deep link internal, dan kunci lokalisasi (`.arb`) yang mengandung `olt_social`. Kunci lokalisasi boleh diganti, asalkan teksnya tidak berubah.

Setelah selesai, **pencarian `olt_social`, `OltSocial`, dan `package:olt_` di seluruh repo harus kosong**, kecuali yang sengaja dipertahankan di 2.2/2.3 dan catatan riwayat di README/CHANGELOG.

---

## 3. Hapus Semua Komentar Kode

Berlaku untuk seluruh kode Dart di `packages/rendezvous_community/` (termasuk sub-package) dan `example/`.

- Hapus komentar baris (`//`), komentar blok (`/* */`), dan **doc comment** (`///`).
- Hapus kode yang dikomentari (kode mati). Kalau ternyata masih dibutuhkan, laporkan dulu sebelum dihapus.
- Hapus komentar `TODO`/`FIXME`. Pindahkan isinya ke `docs/rendezvous-community/backlog.md` (file, baris lama, dan isi) supaya tidak hilang.
- **Pengecualian, tetap dipertahankan** karena fungsional:
  - Directive analyzer `// ignore:` dan `// ignore_for_file:`. Sebisa mungkin perbaiki penyebab lint-nya supaya directive tidak diperlukan. Sisanya boleh tetap ada.
  - Header lisensi pihak ketiga yang wajib dipertahankan oleh lisensinya.
  - File hasil generate (`*.g.dart`, `*.freezed.dart`, dan sejenisnya). **Jangan diedit manual.** File itu akan dibuat ulang oleh build_runner.
- Karena tidak ada komentar, **kode harus menjelaskan dirinya sendiri**:
  - Nama variabel, fungsi, dan kelas yang jelas dalam Bahasa Inggris.
  - Fungsi kecil.
  - Konstanta bernama, bukan angka/string ajaib.
  - Bila ada logika yang sebelumnya hanya bisa dipahami lewat komentar, refactor menjadi fungsi dengan nama yang menjelaskan maksudnya.
- Tambahkan aturan di CI yang **gagal** bila ada komentar baru di luar pengecualian di atas, misalnya script yang memindai `//`, `/*`, dan `///` dengan whitelist untuk `// ignore` dan file hasil generate.
- Penjelasan arsitektur dan cara pakai library dipindahkan ke `docs/rendezvous-community/` (Markdown), bukan di dalam kode.

---

## 4. Pesan Log dalam Bahasa Inggris

### 4.1 Cakupan
Semua pesan berikut **wajib Bahasa Inggris**:
- Pesan log (semua level).
- Pesan exception/error internal dan `assert`.
- Pesan `debugPrint`/`print`. `print` sebaiknya dihapus dan diganti logger.
- Pesan di tes (deskripsi tes, `reason` pada assertion).

**Tidak berlaku** untuk **teks yang dilihat user** (UI, snackbar, dialog, notifikasi). Teks itu tetap memakai lokalisasi (`.arb`), dengan Bahasa Indonesia default dan Inggris. Pastikan **tidak ada teks UI yang hardcode di kode**: semua lewat lokalisasi.

### 4.2 Standar logger
- Gunakan **satu logger terpusat** di library (misalnya package `logging`, BSD-3), dengan nama logger per komponen, misalnya `RendezvousCommunity.Chat`, `RendezvousCommunity.Feed`, `RendezvousCommunity.Realtime`, `RendezvousCommunity.Support`, dan `RendezvousCommunity.Auth`.
- Library **tidak mencetak langsung ke konsol**. Host app (OLT) memasang handler lewat `RendezvousCommunity.initialize(logHandler: ...)` supaya log masuk ke sistem log OLT. Default-nya hanya mencetak di mode debug.
- Level yang dipakai: `fine` (debug), `info`, `warning`, `severe` (error).
  - Di build release, default minimal `info`.
  - Event berfrekuensi tinggi (misalnya setiap pesan realtime) memakai level `fine`.
- **Format pesan**:
  - Kalimat singkat dalam bentuk lampau atau keadaan, diawali huruf kapital, tanpa titik di akhir.
  - Data variabel dikirim sebagai **field terstruktur** (map), bukan disisipkan bebas ke dalam kalimat.

  Contoh:
  ```
  info    "Realtime channel subscribed"          {channel: "room:<id>"}
  warning "Realtime connection lost, retrying"   {attempt: 3, delayMs: 4000}
  severe  "Failed to send message"               {roomId: "...", clientId: "...", error: "..."}
  info    "Support ticket claimed"               {ticketId: "...", agentId: "..."}
  ```
- **Exception**: buat kelas exception domain dengan `code` yang stabil (misalnya `CommunityException(code: 'RATE_LIMITED', message: 'Rate limit exceeded')`). Lapisan UI memetakan `code` ke teks lokalisasi untuk ditampilkan ke user.
- **Data sensitif tidak boleh muncul di log** dalam bahasa apa pun: token, JWT, password, OTP, isi pesan chat, isi post, nomor rekening, dan NIK.
  - ID boleh dicatat.
  - Tambahkan fungsi sanitasi di logger, plus tes yang memastikan nilai sensitif tersamarkan.
- Ganti semua pesan log yang masih berbahasa Indonesia. **Buat daftar pesan lama → baru** di ringkasan.

---

## 5. Verifikasi

- `dart format` dan `dart analyze` (atau `flutter analyze`) **tanpa warning** di library, `example/`, dan aplikasi OLT.
- `build_runner` dijalankan ulang, dan file hasil generate ter-update.
- Semua **unit test dan widget test lulus**. Integration test di `example/` lulus di **Windows dan Android**.
- **Uji upgrade**:
  1. Pasang build lama (`olt_social`).
  2. Login, buka chat, simpan draf, dan antrekan pesan saat offline.
  3. Update ke build baru (`rendezvous_community`).
  4. Pastikan **tetap login**, cache chat masih ada, draf masih ada, dan pesan offline terkirim.
- Pencarian sisa nama lama (bagian 2.4) kosong.
- Pemeriksa komentar di CI (bagian 3) dan pemeriksa log sensitif (bagian 4.2) lulus.
- Aplikasi OLT berjalan normal: feed, komentar berantai, chat, Chat CS, notifikasi, dan **fitur trading tidak terpengaruh**.

---

## 6. Tahapan

1. **R0: Inventaris**
   - Daftar semua tempat yang terdampak: package, file, simbol publik, identitas yang tersimpan di perangkat (2.3), referensi di docs/CI, jumlah komentar per file, dan semua pesan log/exception berbahasa Indonesia.
   - Usulkan keputusan untuk setiap item di 2.3.
   - **Berhenti dan tunggu persetujuan saya.**
2. **R1: Rename** package, file, import, dan simbol, beserta migrasi/penanganan data perangkat dan pembaruan aplikasi OLT & `example/`.
3. **R2: Hapus komentar**, backlog TODO, refactor nama bila perlu, dan pemeriksa CI.
4. **R3: Logger & pesan Bahasa Inggris**, kelas exception dengan `code`, sanitasi data sensitif, dan pemetaan error ke lokalisasi.
5. **R4: Verifikasi** (bagian 5), CHANGELOG versi baru, dan tag git.

Setiap tahap: berhenti, ringkas perubahan (jumlah file, contoh diff penting, dan hasil tes), lalu tunggu konfirmasi saya.
