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

## 3. Ide lain yang bisa disediakan

Diurutkan dari dampak terbesar.

- [ ] **Tombol "Tandai pengaduan/penipuan" untuk CS di Hub.** Fungsi server `flag_ticket` sudah ada, tombolnya belum, sehingga keluhan yang tidak diajukan lewat menu nasabah tidak masuk register Kasus.
- [ ] **Bantuan tanpa login** untuk nasabah yang tidak bisa masuk aplikasi: FAQ terbuka tanpa login, dan chat tamu terbatas (nomor HP atau email + OTP) khusus topik Akun & Login.
- [ ] **Pertanyaan awal per topik**: isian singkat sebelum chat (misalnya nomor order, tanggal transaksi, jenis perangkat), diatur dari Hub, ditampilkan ke CS di kepala tiket. Mempercepat penanganan.
- [ ] **Status layanan / gangguan**: Super Admin memasang pengumuman gangguan (misalnya "Order sedang lambat") yang tampil di chat CS dan Pusat Bantuan, dengan tautan artikel FAQ. Mengurangi tiket berulang saat gangguan.
- [ ] **Pesan di luar jam layanan** yang menyarankan artikel FAQ sesuai topik.
- [ ] **Survei kepuasan yang bisa diatur**: pertanyaan dan pilihan alasan rating diatur dari Hub.
- [ ] **Saran balasan untuk nasabah** per topik (tombol jawaban cepat di chat), diatur dari Hub.
- [ ] **Laporan bantuan** di menu Laporan: topik terbanyak, artikel paling membantu, tiket yang tercegah oleh FAQ, dan pencarian tanpa hasil.
- [ ] **Deskripsi topik untuk CS**: catatan internal per topik (SOP singkat) yang tampil di Hub saat menangani tiket.
- [ ] **Rilis library** setelah fitur di atas: naikkan versi, rapikan CHANGELOG, buat tag, perbarui rujukan versi di dokumen monorepo.

## Cara kerja per bagian

Setiap bagian dikerjakan dengan pola yang sudah dipakai: tes ditulis lebih dulu, migrasi baru (migrasi lama tidak diubah), pgTAP lengkap + tes keamanan + smoke, CI Hub dan library hijau, panduan Hub dan PDF diperbarui, lalu perintah update untuk server LAN.
