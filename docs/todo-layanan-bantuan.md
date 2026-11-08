# Todo: Topik fleksibel, FAQ, dan fitur bantuan lanjutan

Status: rencana, belum dikerjakan (dibuat 8 Nov 2026). Prinsipnya: semua isi yang dilihat nasabah diatur dari Rendezvous Hub dan dikirim server. Aplikasi Flutter dan library tidak menyimpan teks, ikon, atau daftar topik secara tetap; nilai bawaan di library hanya cadangan untuk server lama.

Nomor berikutnya saat todo ini dibuat: migrasi `0126`, tes pgTAP `106`. Library masih di bagian CHANGELOG "Belum dirilis" (setelah v1.8.0).

## 0. Peran pengelola konten

- [ ] Peran baru **Konten Layanan** (`cs_content`), pola sama dengan peran `product` di migrasi 0121: boleh mengelola topik dan FAQ, tidak boleh menangani tiket. Super Admin tetap boleh.
- [ ] Hub: peran bisa dipilih di form akun CS, menu yang tampil mengikuti peran, dan semua perubahan tercatat di Jejak Audit dengan nilai sebelum dan sesudah.
- [ ] Tes: pgTAP (peran lain ditolak), Hub (menu dan guard rute), panduan Hub dan PDF.

## 1. Topik chat CS sepenuhnya dari server

Sekarang: nama ID/EN, skill, prioritas, tautan bantuan, aktif, dan urutan sudah diatur dari Hub (Pengaturan → Topik). Ikon dipetakan tetap di library per kode topik; deskripsi di bawah judul ditulis tetap di aplikasi (builder `topicTile`); tanda penipuan hanya lewat database.

Server (migrasi 0126):
- [ ] Kolom baru `cs.support_topics`: `description_id`, `description_en` (maks. 120 karakter), `icon` (kunci dari daftar ikon yang diizinkan, misalnya `account`, `wallet`, `receipt`, `chart`, `tools`, `shield`, `help`, `document`, `phone`), `style` (`normal` atau `danger`, untuk tampilan merah seperti Laporkan Penipuan).
- [ ] Tanda `fraud` dan `complaint` per topik bisa diatur dari Hub. Mengubahnya memberi notifikasi ke Kepatuhan dan tercatat di Jejak Audit, karena tanda ini menentukan masuk tidaknya tiket ke register Kasus.
- [ ] `cs_api.topics(p_language)` mengembalikan `code`, `name`, `description`, `icon`, `style`, `urgent`, `help_url`, dan urutan, sesuai bahasa.
- [ ] Teks judul dan petunjuk halaman pilih topik ("Apa yang bisa kami bantu?") ikut disimpan di pengaturan, ID/EN.

Hub:
- [ ] Form topik: deskripsi ID/EN, pilihan ikon (grid ikon), gaya, tanda penipuan/pengaduan, dan pratinjau kartu topik persis seperti di aplikasi (terang dan gelap).
- [ ] Urutkan dengan drag atau tombol naik/turun.

Library:
- [ ] `SupportTopic` mendapat `description`, `icon`, dan `style` dari server. `CommunitySupportTopicDetails` meneruskannya ke builder.
- [ ] Tampilan bawaan menampilkan deskripsi dan ikon dari server. Pemetaan ikon tetap per kode hanya dipakai bila server belum mengirim `icon`.
- [ ] Kunci ikon dipetakan ke `IconData` di satu tempat, dengan builder `support.topicIcon` agar host bisa memakai ikon sendiri.
- [ ] Tes widget dan screenshot untuk kartu dengan deskripsi, ikon, dan gaya `danger`.

Aplikasi Flutter (`windows_online_trading`):
- [ ] Hapus deskripsi dan ikon yang ditulis tetap di builder `topicTile`; pakai `details.topic.description`, `icon`, dan `style`, atau hapus builder itu bila tampilan bawaan sudah cukup.

## 2. FAQ / Pusat Bantuan

Server (migrasi 0127):
- [ ] Tabel `cs.faq_categories` (kode, nama ID/EN, ikon, urutan, aktif) dan `cs.faq_articles` (kategori, pertanyaan ID/EN, jawaban ID/EN dalam Markdown terbatas, kata kunci, topik chat terkait, urutan, status draf/terbit, versi, diubah oleh).
- [ ] `cs.faq_feedback`: "Apakah ini membantu?" ya/tidak, satu suara per nasabah per artikel, dengan komentar opsional.
- [ ] API nasabah: `cs_api.faq(p_language)` (kategori dan artikel terbit), `cs_api.faq_search(p_query, p_language)`, `cs_api.faq_feedback(p_article_id, p_helpful, p_comment)`. Pencarian tanpa hasil dicatat (teks dipangkas, tanpa data pribadi) untuk bahan artikel baru.
- [ ] Gambar jawaban disimpan lewat layanan media yang sudah ada; tautan hanya `https`.
- [ ] Batas laju untuk pencarian dan umpan balik.

Hub (menu **Bantuan / FAQ**, peran Konten Layanan dan Super Admin):
- [ ] Daftar kategori dan artikel, cari, saring status, urutkan.
- [ ] Editor dua bahasa dengan pratinjau tampilan aplikasi, draf, terbitkan, arsipkan, dan riwayat versi (bisa kembali ke versi lama).
- [ ] Statistik per artikel: dilihat, membantu (%), dan tiket yang tetap dibuat setelah membaca.
- [ ] Daftar "pencarian tanpa hasil" untuk menentukan artikel baru.

Library:
- [ ] Widget `CommunityHelpCenter`: kategori, pencarian, detail artikel, dan tombol "Masih butuh bantuan? Chat CS" yang langsung membuka chat dengan topik terkait. Fungsi buka `openCommunityHelpCenter(context)`.
- [ ] Di halaman pilih topik chat CS, tampilkan 3 artikel teratas untuk topik yang dipilih sebelum tiket dibuat ("Mungkin ini membantu"), dengan pilihan tetap lanjut chat.
- [ ] Semua bagian punya builder (`CommunityHelpBuilders`), teks ID/EN, mode gelap, dan cache agar FAQ tetap terbuka saat offline.
- [ ] Tes unit, widget, dan screenshot; dokumentasi `doc/features.md` dan `doc/customization.md`.

Aplikasi Flutter:
- [ ] Pintu masuk Pusat Bantuan di menu aplikasi.

## 3. Geser pesan untuk membalas (ala WhatsApp)

Contoh: nasabah atau CS menggeser pesan "aku sayang dia" ke kanan untuk membalasnya.

Library (sudah dibuat, commit `9f33202`, masih di "Belum dirilis"):
- [x] Di layar sentuh, gelembung pesan (milik sendiri maupun orang lain) bisa digeser ke kanan; ikon balas muncul perlahan.
- [x] Getar halus (`HapticFeedback.lightImpact`) sekali saat melewati ambang 56 px; dilepas setelah ambang = membalas pesan itu dan kolom ketik langsung fokus.
- [x] Geser pendek, geser ke kiri, dan drag mouse tidak memicu balasan (pilih teks dengan mouse di desktop tetap jalan). Berlaku juga untuk gelembung dari builder `chat.message`.
- [ ] Coba di aplikasi Flutter di HP sungguhan (Android dan iOS): rasa geser, getar, dan tidak bentrok dengan gulir daftar pesan atau geser kembali (back gesture) iOS.
- [ ] Opsional: ambang, arah (kanan untuk pesan orang lain, kiri untuk pesan sendiri seperti WhatsApp iOS), dan getar bisa diatur host lewat konfigurasi atau builder.
- [ ] Masuk rilis library berikutnya (lihat bagian 4.11).

Hub (web CS):
- [ ] Geser untuk membalas di perangkat sentuh (tablet/HP yang membuka Hub), dengan getar lewat `navigator.vibrate` bila didukung. Di desktop tetap tombol Balas yang sudah ada (klik Balas langsung fokus ke kolom ketik sudah dibuat).
- [ ] Tes komponen untuk geser sentuh, geser pendek, dan mouse.

## 4. Fitur bantuan lanjutan

Diurutkan dari dampak terbesar. Semua isi diatur dari Hub dan tercatat di Jejak Audit.

### 4.1 Tombol "Tandai pengaduan/penipuan" untuk CS
- [ ] Hub: aksi di kepala tiket untuk CS pemilik tiket dan Super Admin, memanggil `cs_api.flag_ticket` yang sudah ada; wajib alasan singkat.
- [ ] Server: alasan disimpan di riwayat tiket; Kepatuhan menerima notifikasi kasus baru.
- [ ] Tes pgTAP dan Hub.

### 4.2 Bantuan tanpa login
- [ ] FAQ terbuka tanpa login (endpoint publik hanya baca, dengan batas laju).
- [ ] Chat tamu khusus topik Akun & Login: verifikasi nomor HP atau email terdaftar dengan OTP, sesi pendek, tanpa akses fitur sosial; tiket ditandai "tamu" di Hub.
- [ ] Library: pintu masuk "Tidak bisa masuk? Hubungi CS" yang bisa dipasang di halaman login aplikasi.
- [ ] Tinjauan keamanan: OTP tidak bisa ditebak, batas percobaan, tidak membocorkan apakah akun ada.

### 4.3 Pertanyaan awal per topik
- [ ] Server: daftar isian per topik (teks, angka, tanggal, pilihan; wajib/opsional), ID/EN.
- [ ] Library: form singkat setelah memilih topik, sebelum chat dimulai.
- [ ] Hub: pengaturan isian per topik; jawaban tampil di kepala tiket untuk CS.

### 4.4 Status layanan / gangguan
- [ ] Hub: Super Admin memasang pengumuman gangguan (judul, isi ID/EN, tingkat, mulai/selesai, artikel FAQ terkait).
- [ ] Library: banner di chat CS, halaman pilih topik, dan Pusat Bantuan; ikut hilang otomatis saat selesai.
- [ ] Laporan: jumlah tiket selama gangguan.

### 4.5 Pesan di luar jam layanan
- [ ] Pesan di luar jam (sudah ada) ditambah saran artikel FAQ sesuai topik yang dipilih, dan tombol "Tinggalkan pesan".

### 4.6 Survei kepuasan yang bisa diatur
- [ ] Hub: pertanyaan, skala, dan pilihan alasan rating rendah (ID/EN).
- [ ] Library: dialog rating mengikuti pengaturan server.
- [ ] Laporan: alasan rating rendah terbanyak per topik dan per CS.

### 4.7 Saran balasan untuk nasabah
- [ ] Hub: daftar tombol jawaban cepat per topik (misalnya "Sudah saya coba", "Belum bisa").
- [ ] Library: tombol muncul di atas kolom ketik di chat CS.

### 4.8 Laporan bantuan
- [ ] Menu Laporan: topik terbanyak, artikel FAQ paling membantu, tiket yang tercegah oleh FAQ, pencarian tanpa hasil, waktu tanggapan per topik.
- [ ] Ekspor CSV.

### 4.9 SOP singkat per topik untuk CS
- [ ] Hub: catatan internal per topik (langkah penanganan, dokumen yang diminta), tampil di panel tiket saat CS menangani.

### 4.10 Rekomendasi tambahan
- [ ] **Template jawaban berbasis artikel FAQ**: CS bisa menyisipkan tautan atau ringkasan artikel FAQ ke chat dari Hub.
- [ ] **Antrean dan perkiraan waktu tunggu** yang lebih jelas di aplikasi (posisi antrean sudah ada; tambah perkiraan menit dari rata-rata waktu klaim).
- [ ] **Lanjutkan di perangkat lain**: notifikasi push saat CS membalas sudah ada; pastikan riwayat tiket dan transkrip bisa dibuka nasabah dari menu riwayat.
- [ ] **Unduh transkrip oleh nasabah** (PDF/TXT) untuk tiket yang sudah selesai.
- [ ] **Penilaian artikel oleh CS**: CS menandai artikel FAQ yang perlu diperbarui langsung dari Hub.
- [ ] **Pengingat tiket menunggu nasabah**: pesan otomatis bila nasabah belum membalas dalam N jam, sebelum tiket ditutup otomatis (penutupan otomatis sudah ada).

### 4.11 Rilis library
- [ ] Setelah bagian yang menyentuh library selesai: naikkan versi, rapikan CHANGELOG, buat tag, perbarui rujukan versi di dokumen monorepo, dan beri tahu cara update di aplikasi (termasuk `<queries>` Android untuk `tel`/`mailto`).

## 5. Tanggal mengambang saat menggulir chat (ala WhatsApp)

Saat daftar pesan digulir, label tanggal pesan teratas yang terlihat ("Hari ini", "Kemarin", "Jumat", "6 Nov 2026") menempel di tengah atas daftar. Setelah guliran berhenti sekitar 1,5 detik, label memudar (fade out) sendiri, lalu muncul lagi dengan fade in begitu digulir.

Library (`message_list.dart`, sudah punya pemisah tanggal di antara pesan):
- [ ] Pil tanggal mengambang di atas daftar: teksnya mengikuti hari dari pesan teratas yang terlihat, memakai label yang sama dengan pemisah tanggal (`dayLabel`), berganti tanpa berkedip saat melewati batas hari.
- [ ] Muncul (fade in sekitar 150 ms) saat mulai menggulir; memudar (fade out sekitar 300 ms) setelah 1,5 detik tanpa guliran; tidak muncul saat posisi di pesan terbaru dan tidak menutupi pemisah tanggal yang sedang tepat di atas.
- [ ] Gaya pil sama dengan pemisah tanggal (tema terang dan gelap), tidak bisa diketuk, tidak menghalangi gulir atau ketukan pesan di bawahnya; dibacakan pembaca layar hanya saat tanggal berganti.
- [ ] Slot builder `chat.floatingDate` (details: tanggal, label, terlihat) supaya host bisa mengganti tampilannya; durasi tampil bisa diatur.
- [ ] Tes widget: muncul saat digulir, label mengikuti pesan teratas, hilang setelah jeda (pakai `pump` waktu), tidak muncul di posisi terbawah; screenshot terang/gelap.

Hub (`message-list.tsx`, baris `day` dari virtualizer):
- [ ] Pil tanggal yang sama di atas daftar pesan, label dari baris `day` terdekat di atas item teratas yang terlihat.
- [ ] Fade in/out dengan transisi CSS, menghormati `prefers-reduced-motion` (langsung muncul/hilang tanpa animasi).
- [ ] Tes komponen dengan timer palsu: muncul saat scroll, hilang setelah jeda.

## 6. Lampiran dokumen lain dan video di chat CS

Sekarang: chat CS menerima gambar dan PDF (maks. 10 MB, bucket `cs-documents`, migrasi 0053/0054); chat sosial hanya gambar. Bagian ini memperluas **chat CS saja** (nasabah dan CS, dari library maupun Hub). Chat sosial tetap gambar saja, karena isinya dilihat banyak orang dan sulit dimoderasi.

Keputusan format (rekomendasi):

| Jenis | Format diizinkan | Batas | Alasan |
|---|---|---|---|
| Dokumen | PDF (sudah), Word `.docx`, Excel `.xlsx`, PowerPoint `.pptx`, teks `.txt`, `.csv` | 10 MB per file | Format kantor modern tanpa makro; yang paling sering dikirim nasabah (laporan, rekening koran, bukti) |
| Gambar | JPEG, PNG, WebP (sudah); HEIC dari iPhone diubah ke JPEG di perangkat sebelum dikirim | 10 MB | Tetap seperti sekarang, ditambah HEIC agar foto iPhone tidak gagal |
| Video | MP4 (H.264/AAC), MOV dari iPhone, WebM | 25 MB dan maks. 2 menit | Rekaman layar sangat membantu CS melihat error aplikasi; dibatasi agar penyimpanan dan kuota nasabah tetap wajar |

Ditolak, meski diganti ekstensinya: dokumen bermakro (`.docm`, `.xlsm`, `.pptm`) dan file Office lama (`.doc`, `.xls`, `.ppt`) yang tidak bisa diperiksa makronya; arsip (`.zip`, `.rar`, `.7z`) yang bisa menyembunyikan isi; program dan skrip (`.exe`, `.apk`, `.bat`, `.js`, dan sejenisnya); HTML dan SVG (bisa berisi skrip). Audio dan pesan suara tidak termasuk di bagian ini.

Server (migrasi baru dan layanan `media`):
- [ ] Daftar format dan batas ukuran disimpan di pengaturan server dan diatur Super Admin dari Hub (bisa mematikan per jenis, misalnya video), bukan ditulis tetap di aplikasi. Aplikasi dan Hub membaca daftar ini dari server.
- [ ] Bucket `cs-documents` menerima MIME baru; bucket video terpisah atau prefix khusus dengan batas 25 MB.
- [ ] Pemeriksaan isi file di layanan `media` (sudah ada paket `sniff`): tipe ditentukan dari isi file (magic bytes), bukan ekstensi; file Office dibuka sebagai ZIP dan ditolak bila berisi makro (`vbaProject.bin`), objek tertanam yang dapat dieksekusi, atau terlalu banyak file di dalamnya (zip bomb); CSV/TXT harus UTF-8 dan ukurannya wajar.
- [ ] Video diperiksa dengan `ffprobe` (format, codec, durasi ≤ 2 menit), metadata lokasi dihapus, dan dibuatkan thumbnail.
- [ ] Opsional yang direkomendasikan: pemindai antivirus (ClamAV, container terpisah) untuk dokumen; file berstatus "sedang diperiksa" sampai lolos.
- [ ] File diberi nama acak di storage, nama asli disimpan terpisah; diunduh dengan `Content-Disposition: attachment` (tidak dibuka langsung di browser kecuali gambar, PDF, dan video).
- [ ] Ikut aturan yang sudah ada: hapus akun dan janitor ikut menghapus lampiran baru ini, transkrip Kepatuhan mencantumkan lampiran, batas laju unggah.
- [ ] Tes pgTAP (MIME dan ukuran per jenis, chat sosial menolak) dan tes Go `media` (makro, zip bomb, ekstensi palsu, video kepanjangan).

Hub (composer dan gelembung pesan):
- [ ] Pilih, tempel, dan seret file dengan daftar format dari server; pesan galat jelas bila format atau ukuran ditolak.
- [ ] Kartu dokumen dengan ikon per jenis (Word, Excel, PowerPoint, CSV, teks), nama, ukuran, dan tombol unduh.
- [ ] Video: thumbnail, pemutar bawaan browser (`<video controls preload="metadata">`), durasi, unduh.
- [ ] Tes komponen dan panduan Hub.

Library dan aplikasi Flutter:
- [ ] Pemilih file (`file_selector`, sudah dipakai) memakai daftar format dari server; foto HEIC diubah ke JPEG sebelum dikirim.
- [ ] Kartu dokumen per jenis (sama dengan Hub) yang membuka file dengan aplikasi bawaan perangkat setelah diunduh.
- [ ] Video: thumbnail dan durasi di gelembung. Putar di dalam aplikasi di Android/iOS/web (`video_player`); di Windows, `video_player` resmi belum mendukung, jadi video dibuka di pemutar bawaan Windows setelah diunduh (tidak menambah paket berat seperti `media_kit`).
- [ ] Builder untuk kartu dokumen dan video; teks ID/EN; tes widget dan screenshot.
- [ ] Android: izin baca media hanya bila perlu (pemilih sistem tidak butuh izin penyimpanan).

## Cara kerja per bagian

Setiap bagian dikerjakan dengan pola yang sudah dipakai: tes ditulis lebih dulu, migrasi baru (migrasi lama tidak diubah), pgTAP lengkap + tes keamanan + smoke, CI Hub dan library hijau, panduan Hub dan PDF diperbarui, lalu perintah update untuk server LAN.
