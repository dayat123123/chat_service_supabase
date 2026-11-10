# Todo: Topik fleksibel, FAQ, dan fitur bantuan lanjutan

Status: rencana, belum dikerjakan (dibuat 8 Nov 2026). Prinsipnya: semua isi yang dilihat nasabah diatur dari Rendezvous Hub dan dikirim server. Aplikasi Flutter dan library tidak menyimpan teks, ikon, atau daftar topik secara tetap; nilai bawaan di library hanya cadangan untuk server lama.

Nomor berikutnya saat todo ini dibuat: migrasi `0126`, tes pgTAP `106`. Library masih di bagian CHANGELOG "Belum dirilis" (setelah v1.8.0).

## Ringkasan fase

**Fase 1 — fokus sekarang** (permintaan user, urutan kerja, perkiraan 5–7,5 jam kerja agen berurutan, atau 2,5–3,5 jam dengan 3 agen paralel; direvisi 9 Nov 2026 dari waktu nyata di Agent map):

| Urutan | Bagian | Perkiraan |
|---|---|---|
| 1 | 0. Peran Konten Layanan | 30–45 menit |
| 2 | 1. Topik chat CS sepenuhnya dari server | 1–1,5 jam |
| 3 | 5. Tanggal mengambang saat menggulir chat | 30–60 menit |
| 4 | 3. Geser pesan untuk membalas (library sudah, sisa Hub sentuh, uji di HP, dan pengaturan ambang/arah/getar oleh host) | 45–60 menit |
| 5 | 7. Batas rekening per nasabah jadi 200 | 20–30 menit |
| 6 | 2. FAQ / Pusat Bantuan | 2–3 jam |
| 7 | 4.11 Rilis library | 15–20 menit |

**Fase 2 — berikutnya** (dikerjakan setelah Fase 1 selesai; perkiraan 10–13 jam kerja agen berurutan):

| Bagian | Isi | Perkiraan |
|---|---|---|
| 6 | Lampiran dokumen lain dan video di chat CS (format sudah disetujui, termasuk ClamAV) — dipindah ke Fase 2 atas permintaan user, 9 Nov 2026 | 2–3 jam |
| 4.1 | Tombol "Tandai pengaduan/penipuan" untuk CS | 20–30 menit |
| 4.2 | Pengaduan tamu sebelum login (tanpa OTP, keputusan di CS, reset hanya ke email terdaftar) — dikerjakan 9 Nov malam | ±2–3 jam agen |
| 4.3 | Pertanyaan awal per topik | ±1 jam |
| 4.4 | Status layanan / pengumuman gangguan | 45–60 menit |
| 4.5 | Pesan di luar jam layanan dengan saran FAQ | 20–30 menit |
| 4.6 | Survei kepuasan yang bisa diatur | ±1 jam |
| 4.7 | Saran balasan untuk nasabah | 45 menit |
| 4.8 | Laporan bantuan | 1–1,5 jam |
| 4.9 | SOP singkat per topik untuk CS | ±30 menit |
| 4.10 | Rekomendasi tambahan: artikel FAQ di balasan CS, perkiraan waktu tunggu antrean, riwayat tiket lintas perangkat, unduh transkrip oleh nasabah, CS menandai artikel FAQ yang perlu diperbarui, pengingat tiket menunggu nasabah | 2–3 jam |

# Fase 1 — fokus sekarang

## 0. Peran pengelola konten (SELESAI 9 Nov 2026, migrasi 0126, tes 106; menu Hub Konten Layanan, Topik pindah dari Pengaturan)

- [x] Peran baru **Konten Layanan** (`cs_content`), pola sama dengan peran `product` di migrasi 0121: boleh mengelola topik dan FAQ, tidak boleh menangani tiket. Super Admin tetap boleh.
- [x] Hub: peran bisa dipilih di form akun CS, menu yang tampil mengikuti peran, dan semua perubahan tercatat di Jejak Audit dengan nilai sebelum dan sesudah.
- [x] Tes: pgTAP (peran lain ditolak), Hub (menu dan guard rute), panduan Hub dan PDF.

## 1. Topik chat CS sepenuhnya dari server (SELESAI 9 Nov 2026, migrasi 0127, tes 107; library di "Belum dirilis")

Sekarang: nama ID/EN, skill, prioritas, tautan bantuan, aktif, dan urutan sudah diatur dari Hub (Pengaturan → Topik). Ikon dipetakan tetap di library per kode topik; deskripsi di bawah judul ditulis tetap di aplikasi (builder `topicTile`); tanda penipuan hanya lewat database.

Server (migrasi 0126):
- [x] Kolom baru `cs.support_topics`: `description_id`, `description_en` (maks. 120 karakter), `icon` (kunci dari daftar ikon yang diizinkan, misalnya `account`, `wallet`, `receipt`, `chart`, `tools`, `shield`, `help`, `document`, `phone`), `style` (`normal` atau `danger`, untuk tampilan merah seperti Laporkan Penipuan).
- [x] Tanda `fraud` dan `complaint` per topik bisa diatur dari Hub. Mengubahnya hanya oleh Super Admin dan tercatat terpisah di Jejak Audit (aksi topic.flags) yang dipantau Kepatuhan; belum ada sistem notifikasi staf, karena tanda ini menentukan masuk tidaknya tiket ke register Kasus.
- [x] `cs_api.topics(p_language)` mengembalikan `code`, `name`, `description`, `icon`, `style`, `urgent`, `help_url`, dan urutan, sesuai bahasa.
- [x] Teks judul dan petunjuk halaman pilih topik ("Apa yang bisa kami bantu?") ikut disimpan di pengaturan, ID/EN.

Hub:
- [x] Form topik: deskripsi ID/EN, pilihan ikon (grid ikon), gaya, tanda penipuan/pengaduan, dan pratinjau kartu topik persis seperti di aplikasi (terang dan gelap).
- [x] Urutkan dengan seret (drag) atau tombol naik/turun; urutan langsung disimpan (migrasi 0137, tes 117; Hub c9f63da).

Library:
- [x] `SupportTopic` mendapat `description`, `icon`, dan `style` dari server. `CommunitySupportTopicDetails` meneruskannya ke builder.
- [x] Tampilan bawaan menampilkan deskripsi dan ikon dari server. Pemetaan ikon tetap per kode hanya dipakai bila server belum mengirim `icon`.
- [x] Kunci ikon dipetakan ke `IconData` di satu tempat, host bisa memakai ikon sendiri lewat builder `topicTile` (kunci ikon ada di `details.topic.icon`).
- [x] Tes widget dan screenshot untuk kartu dengan deskripsi, ikon, dan gaya `danger`.

Aplikasi Flutter (`windows_online_trading`):
- [x] (Aplikasi contoh library sudah bersih; tim aplikasi OLT cukup memastikan hal yang sama di aplikasinya) Hapus deskripsi dan ikon yang ditulis tetap di builder `topicTile`; pakai `details.topic.description`, `icon`, dan `style`, atau hapus builder itu bila tampilan bawaan sudah cukup.

## 5. Tanggal mengambang saat menggulir chat (ala WhatsApp) (SELESAI 9 Nov 2026; library c9d99e1, Hub)

Saat daftar pesan digulir, label tanggal pesan teratas yang terlihat ("Hari ini", "Kemarin", "Jumat", "6 Nov 2026") menempel di tengah atas daftar. Setelah guliran berhenti sekitar 1,5 detik, label memudar (fade out) sendiri, lalu muncul lagi dengan fade in begitu digulir.

Library (`message_list.dart`, sudah punya pemisah tanggal di antara pesan):
- [x] Pil tanggal mengambang di atas daftar: teksnya mengikuti hari dari pesan teratas yang terlihat, memakai label yang sama dengan pemisah tanggal (`dayLabel`), berganti tanpa berkedip saat melewati batas hari.
- [x] Muncul (fade in sekitar 150 ms) saat mulai menggulir; memudar (fade out sekitar 300 ms) setelah 1,5 detik tanpa guliran; tidak muncul saat posisi di pesan terbaru dan tidak menutupi pemisah tanggal yang sedang tepat di atas.
- [x] Gaya pil sama dengan pemisah tanggal (tema terang dan gelap), tidak bisa diketuk, tidak menghalangi gulir atau ketukan pesan di bawahnya; dibacakan pembaca layar hanya saat tanggal berganti. (Catatan: pil diabaikan pembaca layar karena pemisah tanggal asli sudah dibacakan; pengumuman saat tanggal berganti belum dibuat.)
- [x] Slot builder `chat.floatingDate` (details: tanggal, label, terlihat) supaya host bisa mengganti tampilannya; durasi tampil bisa diatur. (Catatan: durasi tetap 1,5 detik, belum bisa diatur host.)
- [x] Tes widget: muncul saat digulir, label mengikuti pesan teratas, hilang setelah jeda (pakai `pump` waktu), tidak muncul di posisi terbawah; screenshot terang/gelap. (Catatan: tes widget ada; scene screenshot khusus belum dibuat.)

Hub (`message-list.tsx`, baris `day` dari virtualizer):
- [x] Pil tanggal yang sama di atas daftar pesan, label dari baris `day` terdekat di atas item teratas yang terlihat.
- [x] Fade in/out dengan transisi CSS, menghormati `prefers-reduced-motion` (langsung muncul/hilang tanpa animasi).
- [x] Tes komponen dengan timer palsu: muncul saat scroll, hilang setelah jeda.

## 3. Geser pesan untuk membalas (ala WhatsApp) (SELESAI 9 Nov 2026; library 7d0e96a, Hub 598d726; uji di HP oleh user)

Contoh: nasabah atau CS menggeser pesan "aku sayang dia" ke kanan untuk membalasnya.

Library (sudah dibuat, commit `9f33202`, masih di "Belum dirilis"):
- [x] Di layar sentuh, gelembung pesan (milik sendiri maupun orang lain) bisa digeser ke kanan; ikon balas muncul perlahan.
- [x] Getar halus (`HapticFeedback.lightImpact`) sekali saat melewati ambang 56 px; dilepas setelah ambang = membalas pesan itu dan kolom ketik langsung fokus.
- [x] Geser pendek, geser ke kiri, dan drag mouse tidak memicu balasan (pilih teks dengan mouse di desktop tetap jalan). Berlaku juga untuk gelembung dari builder `chat.message`.
- [ ] Coba di aplikasi Flutter di HP sungguhan (Android dan iOS): rasa geser, getar, dan tidak bentrok dengan gulir daftar pesan atau geser kembali (back gesture) iOS.
- [x] Pengaturan oleh host (Fase 1): ambang, arah (kanan untuk pesan orang lain, kiri untuk pesan sendiri seperti WhatsApp iOS), dan getar bisa diatur host lewat `CommunitySwipeToReplyScope` dengan `CommunitySwipeToReplySettings`; bawaan tidak berubah.
- [x] Masuk rilis library v1.9.0 (bagian 4.11).

Hub (web CS):
- [x] Geser untuk membalas di perangkat sentuh (tablet/HP yang membuka Hub), dengan getar lewat `navigator.vibrate` bila didukung. Di desktop tetap tombol Balas yang sudah ada (klik Balas langsung fokus ke kolom ketik sudah dibuat).
- [x] Tes komponen untuk geser sentuh, geser pendek, gulir vertikal, dan mouse.

## 7. Batas rekening per nasabah jadi 200 (SELESAI 9 Nov 2026, migrasi 0128, tes 108; Hub Pengaturan → Integrasi aplikasi)

Sekarang: maksimal 50 rekening per nasabah di klaim `accounts` token sosial, ditulis tetap di auth-bridge (`MaxAccounts = 50` di `services/auth-bridge/internal/olt/accounts.go`) dan di fungsi penyimpan tautan rekening (`limit 50` di migrasi 0068). Kelebihannya diabaikan dan dicatat di log. Diminta user (9 Nov 2026): naikkan menjadi 200.

- [x] Batas jadi pengaturan server `accounts.max_per_customer` (bawaan 200, rentang 1–200). Auth-bridge memegang batas atas 200 (`olt.MaxAccounts`) dan fungsi database menerapkan pengaturan; jumlah yang benar-benar ditautkan diambil dari balasan database, sisanya dihitung `accounts_ignored`. Mengubahnya dari Hub hanya Super Admin dan tercatat di Jejak Audit (`setting.update`).
- [x] Migrasi baru mendefinisikan ulang fungsi penyimpan tautan rekening (migrasi 0068 tidak diubah) supaya memakai pengaturan itu.
- [x] Auth-bridge: batas ukuran token dinaikkan ke 16 KB (`olt.MaxTokenBytes`), karena 200 kode × 32 karakter bisa sekitar 7 KB ditambah klaim lain. Ditemukan juga batas tersembunyi di handler exchange (token maks 4.096 karakter, body 8 KB); keduanya kini mengikuti `MaxTokenBytes` (body 17 KB).
- [x] Tes: Go (200 diterima, ke-201 diabaikan dan dihitung, token 16 KB diterima, di atasnya ditolak), pgTAP (fungsi mengikuti pengaturan), `smoke-dummy`.
- [x] Dokumen: `docs/olt-integration.md`, `docs/integration/README.md`, README auth-bridge, dan panduan Hub (batas 200) dan prompt penerbit token C++ untuk tim OLT (batas akun di `CSocialTokenIssuer` menjadi 200).

## 2. FAQ / Pusat Bantuan (SELESAI 9 Nov 2026, migrasi 0129 dan 0130, tes 109 dan 110; Hub Konten Layanan → Pusat Bantuan; library 8d448f9 dan 770e610)

Server (migrasi 0129, gambar 0130):
- [x] Tabel `cs.faq_categories` (kode, nama ID/EN, ikon, urutan, aktif) dan `cs.faq_articles` (kategori, pertanyaan ID/EN, jawaban ID/EN dalam Markdown terbatas, kata kunci, topik chat terkait, urutan, status draf/terbit, versi, diubah oleh).
- [x] `cs.faq_feedback`: "Apakah ini membantu?" ya/tidak, satu suara per nasabah per artikel, dengan komentar opsional.
- [x] API nasabah: `cs_api.faq(p_language)` (kategori dan artikel terbit), `cs_api.faq_search(p_query, p_language)`, `cs_api.faq_feedback(p_article_id, p_helpful, p_comment)`. Pencarian tanpa hasil dicatat (teks dipangkas, tanpa data pribadi) untuk bahan artikel baru.
- [x] Gambar jawaban diunggah dari Hub ke bucket publik `faq-images` (JPEG/PNG/WebP, 2 MB, hanya Super Admin dan Konten Layanan), seperti gambar banner; server menolak gambar dari situs lain. Tautan biasa hanya `https`.
- [x] Batas laju: pencarian 30/menit, umpan balik 20/jam per nasabah. Tambahan: `cs_api.faq_article` (mencatat baca) dan `cs_api.faq_for_topic`; kelima RPC masuk allowlist domain publik Traefik.

Hub (tab **Pusat Bantuan** di menu Konten Layanan, peran Konten Layanan dan Super Admin):
- [x] Daftar kategori dan artikel, cari, saring status, urutkan.
- [x] Editor dua bahasa dengan pratinjau tampilan aplikasi, draf, terbitkan, arsipkan, dan riwayat versi (bisa kembali ke versi lama).
- [x] Statistik per artikel: dilihat, membantu (%), dan tiket yang tetap dibuat setelah membaca.
- [x] Daftar "pencarian tanpa hasil" untuk menentukan artikel baru.

Library:
- [x] Widget `CommunityHelpCenter`: kategori, pencarian, detail artikel, dan tombol "Masih butuh bantuan? Chat CS" yang langsung membuka chat dengan topik terkait. Fungsi buka `openCommunityHelpCenter(context)`.
- [x] Di halaman pilih topik chat CS, tampilkan 3 artikel teratas untuk topik yang dipilih sebelum tiket dibuat ("Mungkin ini membantu"), dengan pilihan tetap lanjut chat.
- [x] Semua bagian punya builder (`CommunityHelpBuilders`), teks ID/EN, mode gelap, dan cache agar FAQ tetap terbuka saat offline.
- [x] Tes unit, widget, dan screenshot; dokumentasi `doc/features.md` dan `doc/customization.md`.

Aplikasi Flutter:
- [x] Pintu masuk Pusat Bantuan di app bar aplikasi contoh (`openCommunityHelpCenter`). Aplikasi OLT memasang hal yang sama di menunya.

## 4.11 Rilis library (SELESAI 9 Nov 2026: v1.9.0, commit d5c931b)
- [x] Setelah bagian yang menyentuh library selesai: naikkan versi, rapikan CHANGELOG, buat tag, perbarui rujukan versi di dokumen monorepo, dan beri tahu cara update di aplikasi (termasuk `<queries>` Android untuk `tel`/`mailto`).

# Fase 2 — berikutnya

## 6. Lampiran dokumen lain dan video di chat CS (SELESAI 9 Nov 2026, migrasi 0131 dan 0132, tes 111 dan 112; media 0.3.0 + ClamAV; Hub 63bad43; library ca05f60; HEIC iOS dan video di HP sungguhan diuji user)

Sekarang: chat CS menerima gambar dan PDF (maks. 10 MB, bucket `cs-documents`, migrasi 0053/0054); chat sosial hanya gambar. Bagian ini memperluas **chat CS saja** (nasabah dan CS, dari library maupun Hub). Chat sosial tetap gambar saja, karena isinya dilihat banyak orang dan sulit dimoderasi.

Keputusan format (disetujui user 8 Nov 2026, termasuk pemindai antivirus):

| Jenis | Format diizinkan | Batas | Alasan |
|---|---|---|---|
| Dokumen | PDF (sudah), Word `.docx`, Excel `.xlsx`, PowerPoint `.pptx`, teks `.txt`, `.csv` | 10 MB per file | Format kantor modern tanpa makro; yang paling sering dikirim nasabah (laporan, rekening koran, bukti) |
| Gambar | JPEG, PNG, WebP (sudah); HEIC dari iPhone diubah ke JPEG di perangkat sebelum dikirim | 10 MB | Tetap seperti sekarang, ditambah HEIC agar foto iPhone tidak gagal |
| Video | MP4 (H.264/AAC), MOV dari iPhone, WebM | 25 MB dan maks. 2 menit | Rekaman layar sangat membantu CS melihat error aplikasi; dibatasi agar penyimpanan dan kuota nasabah tetap wajar |

Ditolak, meski diganti ekstensinya: dokumen bermakro (`.docm`, `.xlsm`, `.pptm`) dan file Office lama (`.doc`, `.xls`, `.ppt`) yang tidak bisa diperiksa makronya; arsip (`.zip`, `.rar`, `.7z`) yang bisa menyembunyikan isi; program dan skrip (`.exe`, `.apk`, `.bat`, `.js`, dan sejenisnya); HTML dan SVG (bisa berisi skrip). Audio dan pesan suara tidak termasuk di bagian ini.

Server (migrasi baru dan layanan `media`):
- [x] Daftar format dan batas ukuran disimpan di pengaturan server dan diatur Super Admin dari Hub (bisa mematikan per jenis, misalnya video), bukan ditulis tetap di aplikasi. Aplikasi dan Hub membaca daftar ini dari server.
- [x] Bucket `cs-documents` menerima MIME baru; bucket video terpisah atau prefix khusus dengan batas 25 MB.
- [x] Pemeriksaan isi file di layanan `media` (sudah ada paket `sniff`): tipe ditentukan dari isi file (magic bytes), bukan ekstensi; file Office dibuka sebagai ZIP dan ditolak bila berisi makro (`vbaProject.bin`), objek tertanam yang dapat dieksekusi, atau terlalu banyak file di dalamnya (zip bomb); CSV/TXT harus UTF-8 dan ukurannya wajar.
- [x] Video diperiksa dengan `ffprobe` (format, codec, durasi ≤ 2 menit), metadata lokasi dihapus, dan dibuatkan thumbnail.
- [x] Pemindai antivirus (ClamAV, container terpisah) untuk dokumen dan video; file berstatus "sedang diperiksa" sampai lolos, dan ditolak bila terdeteksi. Ikut dipantau di Kesehatan sistem.
- [x] File diberi nama acak di storage, nama asli disimpan terpisah; diunduh dengan `Content-Disposition: attachment` (tidak dibuka langsung di browser kecuali gambar, PDF, dan video).
- [x] Ikut aturan yang sudah ada: hapus akun dan janitor ikut menghapus lampiran baru ini, transkrip Kepatuhan mencantumkan lampiran, batas laju unggah.
- [x] Tes pgTAP (MIME dan ukuran per jenis, chat sosial menolak) dan tes Go `media` (makro, zip bomb, ekstensi palsu, video kepanjangan).

Hub (composer dan gelembung pesan):
- [x] Pilih, tempel, dan seret file dengan daftar format dari server; pesan galat jelas bila format atau ukuran ditolak.
- [x] Kartu dokumen dengan ikon per jenis (Word, Excel, PowerPoint, CSV, teks), nama, ukuran, dan tombol unduh.
- [x] Video: thumbnail, pemutar bawaan browser (`<video controls preload="metadata">`), durasi, unduh.
- [x] Tes komponen dan panduan Hub.

Library dan aplikasi Flutter:
- [x] Pemilih file (`file_selector`, sudah dipakai) memakai daftar format dari server; foto HEIC diubah ke JPEG sebelum dikirim.
- [x] Kartu dokumen per jenis (sama dengan Hub) yang membuka file dengan aplikasi bawaan perangkat setelah diunduh.
- [x] Video: thumbnail dan durasi di gelembung. Putar di dalam aplikasi di Android/iOS/web (`video_player`); di Windows, `video_player` resmi belum mendukung, jadi video dibuka di pemutar bawaan Windows setelah diunduh (tidak menambah paket berat seperti `media_kit`).
- [x] Builder untuk kartu dokumen dan video; teks ID/EN; tes widget dan screenshot.
- [x] Android: izin baca media hanya bila perlu (pemilih sistem tidak butuh izin penyimpanan).

## 4. Fitur bantuan lanjutan (SELESAI 9 Nov 2026; 4.2 menyusul 9 Nov malam; migrasi 0133–0136, tes 113–116; Hub b5df01e..b724373; library 6c641f2..18b1a74, rilis v1.10.0)

Diurutkan dari dampak terbesar. Semua isi diatur dari Hub dan tercatat di Jejak Audit.

### 4.1 Tombol "Tandai pengaduan/penipuan" untuk CS
- [x] Hub: aksi di kepala tiket untuk CS pemilik tiket dan Super Admin, memanggil `cs_api.flag_ticket` yang sudah ada; wajib alasan singkat.
- [x] Server: alasan disimpan di riwayat tiket; Kepatuhan menerima notifikasi kasus baru.
- [x] Tes pgTAP dan Hub.

### 4.2 Pengaduan tamu sebelum login (SELESAI 9 Nov 2026, migrasi 0140, tes 120; Hub 7c49712; library v1.12.0)

Diminta user (9 Nov 2026 malam): cukup **pengaduan** untuk menjembatani nasabah yang tidak bisa login dengan CS; keputusan ada di CS (misalnya kirim reset password/PIN dari menu Akun Nasabah). **Tanpa OTP** dan **tanpa bergantung pada csAdmin** (dari csAdmin hanya reset password/PIN yang dipakai). FAQ tanpa login tidak termasuk.

Logika anti-penipuan:
- **Pengaman utama ada di aksi CS, bukan di verifikasi pengadu.** Satu-satunya bantuan akun untuk pengaduan tamu adalah **Reset password/PIN**, dan kredensial baru selalu dikirim csAdmin ke **email yang terdaftar** di akun, bukan ke kontak yang disebut pengadu. Penipu yang mengaku pemilik akun hanya membuat pemilik asli menerima email reset, tanpa mendapat akses.
- **Tiket ditandai "belum terverifikasi"** dan Hub menampilkan SOP: jangan menyebut data akun (email, HP, rekening, saldo), jangan mengubah email/HP/data akun dari chat ini (arahkan ke kantor cabang dengan identitas), jangan meminta atau menerima password/PIN/OTP.
- **Tamu tidak bisa mengakses data apa pun**: tidak ada sesi login, tidak ada fitur sosial, hanya chat teks di tiketnya sendiri. Riwayat tiket lain milik Login ID yang diklaim tidak pernah ditampilkan ke tamu.
- **Batas laju**: 3 pengaduan per perangkat per jam, 10 per hari (hash IP ber-pepper, IP tidak disimpan apa adanya), 5 per Login ID per hari, dan 20 pesan per menit. Hub menampilkan jumlah pengaduan tamu untuk Login ID yang sama dalam 24 jam sebagai sinyal penyalahgunaan.
- **Token sesi** acak 256 bit, disimpan hanya sebagai hash, berlaku 24 jam, bisa diakhiri tamu.
- **Sakelar darurat** `guest.enabled` untuk Super Admin.

Server (migrasi 0140):
- [x] Profil tamu (`profiles.is_guest`) dan tiket CS biasa dengan `context.guest` (Login ID klaim, jenis masalah, belum terverifikasi). Profil tamu tidak muncul di pencarian pengguna dan pencarian staf.
- [x] RPC tanpa login: `cs_api.guest_config`, `guest_start`, `guest_poll`, `guest_send`, `guest_end` (allowlist Traefik, uji keamanan menolak token palsu).
- [x] Tampilan agen memuat `guest` (Login ID, jenis, jumlah 24 jam); panel Akun Nasabah tidak memuat data akun untuk tiket tamu (migrasi 0141, permintaan user 10 Nov); CS mencari sendiri Login ID di menu Akun Nasabah.

Hub:
- [x] Banner "belum terverifikasi" + SOP di tiket tamu, lencana **Tamu** (daftar tiket, transfer, dashboard, kepala percakapan), panel nasabah "Tamu (belum login)" dengan Login ID klaim tanpa data akun, dan sakelar di **Pengaturan → Penugasan, tiket & alert** (Hub 7c49712).

Library:
- [x] `openCommunityGuestSupport` untuk tombol "Tidak bisa masuk? Hubungi CS" di halaman login: form, catatan keamanan, chat dengan polling 4 detik, tanpa sesi dan tanpa menukar token OLT (library v1.12.0, 0aaf06f). Token sesi tamu disimpan di memori; host bisa memasang penyimpanan aman sendiri.
- [x] Composer tamu memakai gaya dan builder `chat.composer` yang sama dengan chat CS (library v1.12.1): kolom pil, tombol kirim bulat, Enter mengirim di desktop, tanpa tombol lampiran dan tanpa saran `$saham`/`@user`.

### 4.3 Pertanyaan awal per topik
- [x] Server: daftar isian per topik (teks, angka, tanggal, pilihan; wajib/opsional), ID/EN.
- [x] Library: form singkat setelah memilih topik, sebelum chat dimulai.
- [x] Hub: pengaturan isian per topik; jawaban tampil di kepala tiket untuk CS.

### 4.4 Status layanan / gangguan
- [x] Hub: Super Admin memasang pengumuman gangguan (judul, isi ID/EN, tingkat, mulai/selesai, artikel FAQ terkait).
- [x] Library: banner di chat CS, halaman pilih topik, dan Pusat Bantuan; ikut hilang otomatis saat selesai.
- [x] Laporan: jumlah tiket selama gangguan.

### 4.5 Pesan di luar jam layanan
- [x] Pesan di luar jam (sudah ada) ditambah saran artikel FAQ sesuai topik yang dipilih, dan tombol "Tinggalkan pesan".

### 4.6 Survei kepuasan yang bisa diatur
- [x] Hub: pertanyaan, skala, dan pilihan alasan rating rendah (ID/EN).
- [x] Library: dialog rating mengikuti pengaturan server.
- [x] Laporan: alasan rating rendah terbanyak per topik dan per CS.

### 4.7 Saran balasan untuk nasabah
- [x] Hub: daftar tombol jawaban cepat per topik (misalnya "Sudah saya coba", "Belum bisa").
- [x] Library: tombol muncul di atas kolom ketik di chat CS.

### 4.8 Laporan bantuan
- [x] Menu Laporan: topik terbanyak, artikel FAQ paling membantu, tiket yang tercegah oleh FAQ, pencarian tanpa hasil, waktu tanggapan per topik.
- [x] Ekspor CSV.

### 4.9 SOP singkat per topik untuk CS
- [x] Hub: catatan internal per topik (langkah penanganan, dokumen yang diminta), tampil di panel tiket saat CS menangani.

### 4.10 Rekomendasi tambahan
- [x] **Template jawaban berbasis artikel FAQ**: CS bisa menyisipkan tautan atau ringkasan artikel FAQ ke chat dari Hub.
- [x] **Antrean dan perkiraan waktu tunggu** yang lebih jelas di aplikasi (posisi antrean sudah ada; tambah perkiraan menit dari rata-rata waktu klaim).
- [x] **Lanjutkan di perangkat lain**: notifikasi push saat CS membalas sudah ada; pastikan riwayat tiket dan transkrip bisa dibuka nasabah dari menu riwayat.
- [x] **Unduh transkrip oleh nasabah** (PDF/TXT) untuk tiket yang sudah selesai.
- [x] **Penilaian artikel oleh CS**: CS menandai artikel FAQ yang perlu diperbarui langsung dari Hub.
- [x] **Pengingat tiket menunggu nasabah**: pesan otomatis bila nasabah belum membalas dalam N jam, sebelum tiket ditutup otomatis (penutupan otomatis sudah ada).

## Penyesuaian setelah selesai (9 Nov 2026 malam)

Yang sebelumnya berbeda dari rencana kini disesuaikan:
- [x] Gambar chat CS maksimal **10 MB** sesuai tabel bagian 6 (migrasi 0138). Chat global dan postingan tetap 5 MB.
- [x] Thumbnail video ikut pemeriksaan gambar tidak pantas (classifier NSFW); bila ditahan atau diblokir, video ditolak.
- [x] Thumbnail yang tertinggal saat unggah video gagal langsung dihapus layanan media.
- [x] `make up` menunggu sampai 15 menit, cukup untuk unduhan signature ClamAV pertama.
- [x] Video di Hub kini bisa diputar (CSP `media-src` mengizinkan origin API; sebelumnya tampil "Video tidak bisa dimuat").
- [x] Library v1.11.0: tombol **Unduh video** di gelembung video, selain tombol putar.
- [x] Urutan topik bisa diatur dengan seret atau tombol naik/turun (migrasi 0137).

Tetap: uji di HP sungguhan oleh user.

## Cara kerja per bagian

Setiap bagian dikerjakan dengan pola yang sudah dipakai: tes ditulis lebih dulu, migrasi baru (migrasi lama tidak diubah), pgTAP lengkap + tes keamanan + smoke, CI Hub dan library hijau, panduan Hub dan PDF diperbarui, lalu perintah update untuk server LAN.
