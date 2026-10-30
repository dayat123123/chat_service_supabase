> **DIBATALKAN (30 Okt 2026).** Pendekatan ticketing/helpdesk di dokumen ini tidak dipakai lagi.
> Penggantinya: [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) (CS lewat chat + matching engine).
> Hasil kerja yang sudah dibuat dari dokumen ini diaudit di [cs-chat/audit-pembersihan.md](../cs-chat/audit-pembersihan.md).

# Addendum 3: Customer Care & Ticketing — Rendezvous OLT

> Addendum ini **melengkapi** `docs/PROMPT.md`, `docs/PROMPT-PRODUCTION.md`, dan `docs/PROMPT-FEATURES.md`. Simpan sebagai `docs/PROMPT-CUSTOMER-CARE.md`.
> Semua aturan sebelumnya tetap berlaku: lisensi permisif, Docker, stateless, siap multi-node, RLS, rate limit berlapis, keamanan, observabilitas, dan backup.
> Bagian bertanda `[...]` wajib disesuaikan. Hal yang terkait regulasi **wajib diverifikasi oleh tim kepatuhan / legal sekuritas** sebelum go-live.

---

## 0. Tujuan & Konteks

Membangun **layanan pelanggan (customer care) terintegrasi** di dalam OLT (Windows desktop + Android) beserta **CS Console** untuk tim customer service. Cakupannya:
- Pusat bantuan (artikel / FAQ) yang bisa dicari.
- **Live chat** dengan agen CS.
- **Ticketing** untuk pertanyaan, permintaan, dan **pengaduan resmi** yang memenuhi ketentuan OJK.
- Panel CS untuk agen, supervisor, dan tim kepatuhan.

### 0.1 Pola yang umum dipakai sekuritas digital di Indonesia (acuan)
- **Live chat di dalam aplikasi** menjadi kanal utama dan tercepat, didukung email, WhatsApp resmi, dan call center.
- **Jam layanan diperpanjang**, termasuk akhir pekan, karena nasabah butuh bantuan di luar jam kerja.
- **Penipuan yang mengatasnamakan CS sangat marak.** Sekuritas aktif mengedukasi bahwa kontak resmi hanya yang tercantum di aplikasi atau situs resmi, dan bahwa CS tidak pernah meminta PIN, OTP, atau password.
- Ada **Pusat Bantuan** (artikel) untuk menjawab pertanyaan umum sebelum nasabah menghubungi CS.
- Ada kanal berbeda per produk atau masalah, misalnya saham lokal vs saham AS.

Fitur di dokumen ini dirancang agar **setara atau lebih baik** dari pola tersebut, dengan keunggulan: **terintegrasi langsung dengan data transaksi OLT**, **aman dari CS palsu**, dan **patuh regulasi sejak awal**.

### 0.2 Prinsip
1. **Satu sumber kebenaran.** Semua interaksi dari kanal mana pun (chat, form, email, telepon yang dicatat CS, surat) menjadi **satu tiket** dengan riwayat lengkap.
2. **Nasabah tidak perlu mengulang cerita.** Konteks (akun, versi aplikasi, perangkat, order terkait) terlampir otomatis.
3. **Patuh regulasi secara otomatis.** Klasifikasi pengaduan, tenggat hari kerja, perpanjangan tertulis, dan laporan dikelola sistem, bukan diingat manual oleh agen.
4. **Privasi dan keamanan nasabah di atas segalanya.** Prinsip *least privilege*, data dimasking, dan setiap akses data tercatat.
5. **Terpisah dari fitur sosial**, tetapi memakai infrastruktur yang sama (Supabase, `auth-bridge`, `market-adapter`, `notifier`, `moderation`). CS tidak memakai room chat sosial.
6. **Isolasi dari trading.** Gangguan pada customer care tidak boleh memengaruhi fitur trading.

---

## 1. Kepatuhan Regulasi (wajib diverifikasi tim kepatuhan)

Dasar acuan yang **harus dicek ulang versi terbarunya**:
- **POJK 22 Tahun 2023** tentang Pelindungan Konsumen dan Masyarakat di Sektor Jasa Keuangan.
- **POJK 18/POJK.07/2018** tentang Layanan Pengaduan Konsumen di Sektor Jasa Keuangan.
- **SEOJK 20/SEOJK.08/2025** tentang Publikasi Penanganan Pengaduan dan Laporan Layanan Pengaduan, berlaku 1 Januari 2027.
- **UU Pelindungan Data Pribadi (UU PDP)**.
- Aturan internal sekuritas dan ketentuan SRO (BEI, KSEI, KPEI) yang relevan.

### 1.1 Klasifikasi interaksi
Setiap tiket memiliki `kind`:
- `inquiry`: pertanyaan informasi, misalnya cara deposit.
- `request`: permintaan layanan, misalnya ubah data atau minta laporan.
- `complaint`: **pengaduan**, yaitu ungkapan ketidakpuasan yang disebabkan adanya kerugian dan/atau potensi kerugian. Ini memicu alur regulasi.
- `incident_report`: laporan masalah teknis atau bug.
- `fraud_report`: laporan penipuan, CS palsu, atau transaksi tidak dikenal.
- `feedback`: saran dan masukan.

Ketentuan klasifikasi:
- Agen bisa mengubah `inquiry`/`request` menjadi `complaint`. **Perubahan dari `complaint` ke jenis lain wajib disetujui supervisor dan tercatat beserta alasannya**, supaya pengaduan tidak "diturunkan" untuk menghindari tenggat.
- Nasabah bisa memilih "Saya ingin mengajukan pengaduan resmi" kapan saja. Pilihan ini otomatis mengubah tiket menjadi `complaint`.

### 1.2 Tenggat waktu pengaduan (dihitung dalam **hari kerja**)
Nilai default dari acuan regulasi, **dibuat dapat dikonfigurasi** dan wajib dikonfirmasi tim kepatuhan:

| Kondisi | Tenggat default |
|---|---|
| Pengaduan **lisan** (chat / telepon) | Diselesaikan paling lama **`[5]` hari kerja** |
| Pengaduan **tertulis** | Ditindaklanjuti dan diselesaikan paling lama **`[10]` hari kerja sejak dokumen pendukung diterima lengkap** |
| Perpanjangan dalam kondisi tertentu | Paling lama **`[10]` hari kerja**, **wajib diberitahukan tertulis ke nasabah sebelum tenggat awal berakhir** |
| Nasabah diminta melengkapi dokumen | Diberi waktu **`[10]` hari kerja**. Jam SLA **dijeda** selama menunggu |

Implementasi:
- **Kalender hari kerja** yang dikelola dari panel: hari libur nasional, cuti bersama, dan hari libur bursa, dengan zona waktu WIB.
- Mesin SLA menghitung tenggat berdasarkan kalender ini.
- Jika pengaduan lisan membutuhkan dokumen, sistem memandu agen untuk **mengonversinya menjadi pengaduan tertulis**. Tenggat kemudian mengikuti aturan tertulis, dan nasabah diberi tahu.
- **Perpanjangan** hanya bisa dilakukan lewat tombol khusus yang:
  1. Wajib mengisi alasan dari daftar kondisi yang diizinkan.
  2. Otomatis mengirim **surat pemberitahuan perpanjangan** ke nasabah (in-app + email, dengan PDF).
  3. Hanya bisa dilakukan sebelum tenggat lewat dan **maksimal satu kali**, atau sesuai konfigurasi.
- Peringatan bertahap ke agen, supervisor, dan kepatuhan, misalnya pada H-3, H-1, hari H, dan saat terlambat.
- Tenggat tidak bisa diubah manual. Hanya bisa berubah lewat aksi resmi (jeda karena menunggu dokumen, perpanjangan), dan semuanya tercatat.

### 1.3 Bukti & tanggapan tertulis
- Setiap tiket mendapat **nomor tiket unik yang mudah dibaca**, misalnya `CC-2026-10-000123`. Untuk pengaduan, gunakan nomor pengaduan terpisah dengan format `[sesuai kebutuhan pelaporan]`.
- Nasabah langsung menerima **bukti penerimaan pengaduan** (in-app + email + PDF) berisi nomor, tanggal dan jam, ringkasan, dan perkiraan tenggat.
- **Tanggapan akhir pengaduan** dibuat dari template resmi (PDF bertanda tangan elektronik / berkop sekuritas), memuat hasil penanganan dan **informasi hak nasabah untuk melanjutkan** ke lembaga alternatif penyelesaian sengketa (LAPS SJK) atau layanan pengaduan OJK jika tidak puas, `[redaksi dari tim legal]`.
- Nasabah bisa menyatakan **keberatan** atas tanggapan. Keberatan dengan dokumen baru membuka kembali pengaduan dengan tenggat baru sesuai ketentuan.

### 1.4 Pelaporan & publikasi
- Laporan berkala penanganan pengaduan (jumlah, kategori, status, ketepatan waktu, penyelesaian) dalam format yang dapat dikonfigurasi, dengan ekspor CSV/XLSX/PDF, untuk kebutuhan laporan ke OJK dan publikasi sesuai SEOJK terbaru. **Format final mengikuti arahan tim kepatuhan.**
- Halaman publikasi ringkasan penanganan pengaduan (anonim, agregat) bisa diekspor untuk situs sekuritas.

### 1.5 Retensi & arsip
- Tiket, percakapan, lampiran, dan audit log disimpan sesuai kebijakan retensi `[X tahun]` yang ditetapkan kepatuhan. Arsip **tidak bisa diubah** (append-only).
- Penghapusan akun nasabah tidak menghapus catatan pengaduan yang wajib disimpan. Data tersebut dipisahkan dan aksesnya diperketat sesuai UU PDP.

### 1.6 Aksesibilitas & kesetaraan layanan
- Aplikasi dan CS Console mendukung pembaca layar, ukuran teks besar, kontras tinggi, dan navigasi keyboard.
- Nasabah bisa meminta **dihubungi balik (callback)** lewat telepon bila kesulitan mengetik.
- Bahasa: Indonesia (default) dan Inggris.

---

## 2. Kanal Layanan

| Kanal | Fase | Catatan |
|---|---|---|
| **Pusat Bantuan in-app** (artikel / FAQ) | C1 | Bisa dibuka tanpa login untuk artikel publik |
| **Live chat in-app** (Windows + Android) | C1 | Kanal utama dan terverifikasi karena user sudah login |
| **Formulir tiket in-app** | C1 | Untuk masalah yang tidak mendesak atau di luar jam layanan |
| **Pencatatan manual oleh CS** (telepon, surat, walk-in, media sosial) | C1 | CS membuat tiket atas nama nasabah dengan kanal sumber yang tercatat |
| **Email masuk → tiket** | C2 | Email ke `[support@...]` otomatis menjadi tiket, balasan email masuk ke tiket yang sama (threading) |
| **Pusat Bantuan web publik** | C2 | Artikel publik untuk SEO dan nasabah yang belum login |
| **WhatsApp Business** | Fase lanjut, opsional | Lewat penyedia resmi dan berbayar. Siapkan interface kanal agar mudah ditambahkan |

Semua kanal masuk ke **satu inbox** di CS Console dengan label kanal.

**Jam layanan**: `[Senin–Jumat 08.00–22.00 WIB, Sabtu–Minggu 09.00–18.00 WIB]`, diatur dari panel termasuk pengecualian hari libur.
- **Penerimaan pengaduan tetap 24 jam.** Di luar jam layanan, live chat berubah menjadi formulir tiket dengan pesan "Tim kami akan membalas pada jam layanan berikutnya: [waktu]".
- **Tombol darurat 24 jam tetap aktif**, misalnya "Blokir akun saya" (bagian 4.6).

---

## 3. Pengalaman Nasabah (Aplikasi OLT)

Dibangun sebagai package Flutter terpisah **`olt_care`** (pola sama seperti `olt_social`), dengan API sederhana:

```dart
await OltCare.initialize(...);   // berbagi auth dengan olt_social
OltHelpCenter();                  // pusat bantuan
OltSupportHome();                 // beranda bantuan: chat, tiket saya, status layanan
OltTicketDetail(ticketId: '...');
OltCare.openContextual(orderId: '...');  // buka bantuan dari layar order
```

### 3.1 Beranda Bantuan
- Kolom pencarian artikel yang besar di bagian atas.
- **Status layanan**: banner jika ada gangguan yang diketahui (lihat 6.6), misalnya "Sedang ada keterlambatan pencairan dana, estimasi pulih 14.00 WIB".
- Kategori populer, artikel teratas, dan "Tiket saya" dengan badge jumlah balasan baru.
- Tombol **"Chat dengan CS"** beserta info jam layanan, perkiraan waktu tunggu, dan posisi antrean.
- Kartu **"Kontak resmi"** berisi daftar kanal resmi beserta peringatan: *"CS kami tidak pernah meminta PIN, password, OTP, atau meminta transfer dana ke rekening pribadi."* Ada tombol **"Laporkan CS palsu"**.

### 3.2 Pusat Bantuan (Knowledge Base)
- Artikel tersusun per kategori (bagian 5.2) dengan pencarian full-text bahasa Indonesia + toleransi salah ketik (`pg_trgm`).
- Artikel mendukung teks, gambar, langkah-langkah bernomor, dan tautan dalam aplikasi (*deep link*, misalnya ke halaman deposit).
- Rating artikel "Apakah ini membantu?" dengan alasan jika tidak membantu.
- Artikel terkait, terakhir diperbarui, dan versi bahasa.
- Artikel bisa ditandai khusus platform (Windows / Android) dan versi aplikasi.

### 3.3 Membuat Tiket / Memulai Chat (alur pintar)
1. Nasabah memilih **kategori → subkategori** dari pohon kategori (bagian 5.2).
2. Sistem menampilkan **artikel yang relevan dulu** (*deflection*). Kalau masalah terselesaikan, catat sebagai "selesai mandiri".
3. **Formulir dinamis per kategori**, dengan field yang dikonfigurasi dari panel. Contoh:
   - **Masalah order**: pilih order dari **daftar order OLT nasabah** (tanggal, kode saham, tipe, harga, lot, status). Nasabah tidak perlu mengetik ulang.
   - **Deposit / tarik dana**: pilih transaksi RDN terkait, nominal, waktu, dan bank. Unggah bukti transfer.
   - **Dividen / aksi korporasi**: pilih saham dan jenis aksi korporasi.
   - **Login / akun**: tidak memerlukan data sensitif.
4. **Konteks otomatis terlampir** (nasabah bisa melihatnya sebelum mengirim):
   - Versi aplikasi, platform, OS, model perangkat, dan bahasa.
   - Waktu kejadian.
   - Status koneksi.
   - Log teknis terakhir yang sudah **disanitasi** (tanpa token, password, atau data sensitif).
   - Layar terakhir.
5. **Lampiran**: screenshot langsung dari aplikasi (desktop: tangkap jendela OLT; Android: pilih dari galeri / tangkapan), gambar, dan PDF.
   - Ada batas ukuran dan jumlah file.
   - **Sebelum dikirim, nasabah diingatkan untuk menutupi data sensitif.** Di layar pratinjau tersedia **alat blur/tutup** sederhana.
6. Pilihan **"Ajukan sebagai pengaduan resmi"** beserta penjelasan singkat bedanya.
7. Kirim. Nasabah langsung mendapat **nomor tiket**, bukti penerimaan, dan perkiraan waktu respons.

**Pencegahan duplikat**: kalau nasabah sudah punya tiket terbuka dengan kategori atau order yang sama, tampilkan "Anda sudah punya tiket untuk ini, lanjutkan di sana?"

### 3.4 Live Chat (sisi nasabah)
- Chat dimulai dari alur 3.3, sehingga agen langsung tahu konteksnya.
- Tampilan berisi:
  - Posisi antrean dan perkiraan waktu tunggu (diperbarui realtime).
  - Nama panggilan agen, foto atau avatar standar, dan **kode verifikasi agen** (bagian 4.5).
  - Indikator agen sedang mengetik, status terkirim/dibaca, lampiran, dan **pesan sistem** (misalnya "Chat dialihkan ke tim Settlement").
- Kalau nasabah menutup aplikasi, chat tetap tersimpan dan **berlanjut sebagai tiket**. Balasan agen datang sebagai notifikasi push / Windows.
- Agen bisa mengirim **pesan terstruktur**:
  - Tombol pilihan cepat.
  - Permintaan dokumen (formulir unggah).
  - Tautan artikel.
  - **Permintaan verifikasi identitas** (bagian 4.3).
  - Kartu order dari OLT.
- **Deteksi data sensitif** di input nasabah: kalau nasabah mengetik atau menempel sesuatu yang terlihat seperti OTP, PIN, password, nomor kartu, atau nomor rekening lengkap, aplikasi **memperingatkan sebelum mengirim**. Kalau tetap dikirim, data tersebut **dimasking di server** sebelum disimpan dan ditampilkan ke agen.
- Kalau tidak ada balasan dari nasabah selama `[10]` menit, kirim pengingat. Setelah `[20]` menit, chat ditutup otomatis dan bisa dibuka kembali dalam `[7]` hari.
- Di akhir chat: **survei kepuasan (CSAT)** 1–5 dengan komentar opsional, plus pertanyaan "Apakah masalah Anda selesai?" (untuk FCR).
- **Transkrip chat** bisa diunduh atau dikirim ke email.

### 3.5 "Tiket Saya"
- Daftar tiket dengan filter (terbuka / menunggu Anda / selesai) dan pencarian.
- Detail tiket berisi:
  - Status yang mudah dipahami nasabah (bagian 5.3), **lini masa** semua aktivitas publik, tenggat (untuk pengaduan), dan lampiran.
- Aksi yang bisa dilakukan nasabah:
  - Membalas.
  - Mengunggah dokumen yang diminta (dengan pengingat tenggat 10 hari kerja).
  - **Menutup tiket sendiri** ("Masalah sudah selesai").
  - **Membuka kembali** dalam `[7]` hari setelah selesai.
  - **Eskalasi menjadi pengaduan resmi**.
  - **Menyatakan keberatan** atas tanggapan.
  - Mengunduh PDF bukti dan tanggapan.
- Badge dan notifikasi saat ada balasan, permintaan dokumen, perubahan status, perpanjangan, atau penyelesaian.

### 3.6 Bantuan Kontekstual
- Tombol bantuan kecil di layar penting OLT (order, deposit/tarik dana, portofolio, aksi korporasi, login). Saat ditekan, langsung membuka kategori yang sesuai dengan konteks sudah terisi.
- Saat order ditolak atau terjadi error, pesan error menampilkan **kode error + tombol "Butuh bantuan?"** yang membuat tiket dengan kode error tersebut.

### 3.7 Notifikasi Nasabah
- In-app, push (Android lewat `notifier`), notifikasi Windows, dan email untuk dokumen resmi.
- Preferensi notifikasi bisa diatur, **kecuali** notifikasi wajib terkait pengaduan (bukti terima, perpanjangan, tanggapan akhir) yang selalu dikirim.

---

## 4. Keamanan & Anti-Penipuan

### 4.1 Prinsip
- Kanal in-app adalah **kanal terautentikasi**: identitas nasabah sudah terverifikasi lewat login OLT.
- **CS tidak pernah boleh meminta** PIN, password, OTP, kode verifikasi, atau data kartu lengkap. Sistem membantu menegakkannya:
  - **Macro dan balasan agen dipindai.** Kalau agen mengetik permintaan semacam itu (misalnya "mohon kirimkan OTP"), pesan **ditahan** dan supervisor diberi peringatan.
  - Field input di sisi nasabah tidak pernah meminta data tersebut.

### 4.2 Akses data nasabah oleh agen
- Agen hanya bisa membuka **profil nasabah yang terkait tiket yang ditugaskan kepadanya**, kecuali role tertentu (supervisor, kepatuhan).
- Data sensitif **dimasking secara default**, misalnya NIK `3174********0001`, rekening `****1234`, email `bu***@gmail.com`, dan nomor HP `0812****789`.
- Tombol **"Tampilkan"** (*reveal*) mewajibkan agen memilih alasan, hanya berlaku untuk satu field selama `[5]` menit, dan **tercatat di audit log**.
- Data keuangan (saldo, portofolio, riwayat order) **hanya-baca**, diambil langsung dari OLT lewat adapter saat dibutuhkan. **Tidak disalin** ke database customer care, kecuali snapshot yang dilampirkan ke tiket secara sadar.
- **Agen tidak bisa melakukan transaksi atau mengubah data nasabah langsung** dari CS Console. Perubahan data (misalnya ubah nomor HP atau rekening bank) mengikuti alur `request` yang diverifikasi dan diproses tim terkait dengan **persetujuan dua tahap (maker–checker)**.

### 4.3 Verifikasi identitas tambahan
Untuk permintaan berisiko tinggi (perubahan data, reset akses, buka blokir akun, informasi detail transaksi lewat kanal non-aplikasi):
- Agen mengirim **permintaan verifikasi** dari chat. Nasabah menyetujuinya **di dalam aplikasi OLT** (misalnya lewat PIN atau biometrik yang diproses oleh OLT, bukan diketik di chat).
- Hasil verifikasi tercatat di tiket (berhasil / gagal / waktu), tanpa menyimpan PIN.
- Untuk kanal email atau telepon yang tidak terautentikasi, informasi akun **tidak diberikan** sampai nasabah terverifikasi lewat aplikasi atau prosedur resmi `[ditentukan]`.

### 4.4 Data sensitif di percakapan
- Masking otomatis di server untuk pola sensitif (nomor kartu, OTP, NIK, nomor rekening, password) **sebelum disimpan**, baik dari nasabah maupun agen.
- Lampiran tersimpan di bucket privat terenkripsi, diakses dengan signed URL berumur pendek, dengan **watermark** nama/ID agen saat dibuka di CS Console.
- Unduh lampiran dari CS Console dibatasi per role dan tercatat.

### 4.5 Anti CS Palsu
- Setiap agen memiliki **ID agen** dan **kode verifikasi dinamis** yang tampil di chat. Nasabah bisa mengecek keasliannya lewat tombol **"Verifikasi agen ini"**.
- Halaman **"Kontak Resmi"** di aplikasi dikelola dari panel.
- Edukasi rutin lewat banner dan artikel.
- **"Laporkan CS palsu / penipuan"** membuat tiket `fraud_report` prioritas tinggi. Pola nomor, akun media sosial, atau situs palsu yang dilaporkan dicatat untuk ditindaklanjuti dan bisa dibagikan ke modul `moderation` di fitur sosial supaya otomatis diblokir.
- Fitur sosial: akun atau pesan yang mengaku CS (selain akun resmi berbadge) diblokir oleh `moderation`, sesuai PROMPT-FEATURES 2.6.

### 4.6 Tindakan Darurat Nasabah (24 jam)
- Tombol **"Amankan akun saya"** untuk nasabah yang merasa akunnya diakses orang lain:
  - Memicu aksi di OLT (`[logout semua perangkat, kunci sementara transaksi / akun, sesuai kemampuan OLT]`).
  - Membuat tiket P1 otomatis.
  - Mengirim notifikasi ke tim keamanan.
- Kalau aksi di OLT gagal, tiket P1 tetap dibuat dan tim on-call dihubungi (bagian 6.5).

### 4.7 Keamanan CS Console
- Hanya bisa diakses lewat **VPN** + login akun staf dengan **2FA (TOTP)**, plus *session timeout* `[15 menit]` idle dan batas sesi aktif per agen.
- Opsional: integrasi SSO internal `[jika ada]`.
- Role-based access control (bagian 6.1) ditegakkan di server (RLS + fungsi). UI hanya mengikuti.
- **Audit log** lengkap dan tidak bisa diubah:
  - Login dan logout.
  - Membuka tiket atau profil.
  - Reveal data.
  - Unduh lampiran.
  - Ubah status, klasifikasi, atau prioritas.
  - Perpanjangan tenggat.
  - Ekspor laporan.
  - Perubahan konfigurasi.
- Pencegahan kebocoran:
  - Ekspor data massal hanya untuk role tertentu, dengan alasan dan persetujuan.
  - Tidak ada salin massal data nasabah.
  - Watermark di tampilan detail nasabah.
  - Batas jumlah profil yang bisa dibuka per jam (deteksi anomali).

---

## 5. Model Tiket

### 5.1 Atribut tiket
- **Identitas**: nomor tiket, nomor pengaduan (jika ada), `kind`, kanal sumber, nasabah (id OLT, kode nasabah / SID `[masking]`), bahasa.
- **Isi**: kategori dan subkategori, judul, deskripsi, field dinamis, konteks perangkat, order / transaksi terkait, dan lampiran.
- **Penanganan**: status, prioritas, tim / antrean, agen yang ditugaskan, pengikut (*followers*), tag, tiket terkait (induk/anak, duplikat), dan insiden terkait.
- **Waktu & SLA**: dibuat, respons pertama, terakhir diperbarui, tenggat respons, tenggat penyelesaian, tenggat regulasi, periode jeda, perpanjangan, dan diselesaikan/ditutup.
- **Hasil**: kategori akar masalah, resolusi, kompensasi (jika ada, dengan persetujuan), CSAT, dan selesai di kontak pertama (FCR).

### 5.2 Pohon kategori awal (dapat dikelola dari panel)
Setiap kategori memiliki: tim default, prioritas default, target SLA, formulir dinamis, artikel terkait, dan penanda "berpotensi pengaduan".

- **Akun & Registrasi**: pembukaan rekening / KYC, verifikasi data, aktivasi RDN, perubahan data pribadi, perubahan rekening bank, penutupan akun, SID / AKSes KSEI.
- **Login & Keamanan**: lupa password/PIN, akun terkunci, perangkat baru, aktivitas mencurigakan, OTP tidak masuk.
- **Dana (RDN)**: deposit belum masuk, penarikan tertunda/gagal, saldo tidak sesuai, biaya transfer.
- **Transaksi / Order**: order ditolak, order tidak tereksekusi, harga tidak sesuai, order tidak bisa dibatalkan / amend, lot atau saldo tidak cukup, auto order / trailing, *trade confirmation*.
- **Portofolio & Settlement**: saham belum masuk, posisi tidak sesuai, settlement T+2, *average price*.
- **Aksi Korporasi**: dividen, right issue, stock split / reverse, tender offer, warrant, e-IPO.
- **Biaya, Pajak & Laporan**: fee transaksi, pajak, bukti potong, *monthly statement*, laporan portofolio, konfirmasi transaksi.
- **Aplikasi & Teknis**: aplikasi error atau crash, data harga tidak update, chart, notifikasi, update aplikasi, kinerja lambat.
- **Fitur Sosial**: banding moderasi, laporan konten, masalah chat sosial. Dihubungkan ke modul `moderation`.
- **Penipuan & Keamanan**: CS palsu, phishing, transaksi tidak dikenal, peretasan akun.
- **Saran & Masukan**.
- **Lainnya**.

### 5.3 Status tiket

| Status internal | Label untuk nasabah | Keterangan |
|---|---|---|
| `new` | Diterima | Belum ditangani |
| `open` | Sedang diproses | Ditangani agen |
| `pending_customer` | Menunggu tanggapan Anda | Jam SLA **dijeda** sesuai aturan. Ada pengingat otomatis |
| `pending_internal` | Sedang diproses | Menunggu tim lain (settlement, finance, IT). SLA **tetap berjalan** |
| `pending_third_party` | Sedang diproses | Menunggu pihak ketiga (bank, KSEI, BEI). Catat pihak dan nomor referensi |
| `escalated` | Sedang diproses | Dinaikkan ke level/tim lebih tinggi |
| `extended` | Diproses (diperpanjang) | Pengaduan dengan perpanjangan resmi |
| `resolved` | Selesai | Solusi diberikan. Nasabah bisa membuka kembali dalam `[7]` hari |
| `closed` | Ditutup | Final. Balasan baru membuat tiket lanjutan yang terhubung |
| `cancelled` | Dibatalkan | Oleh nasabah, atau duplikat (dengan alasan) |

- Transisi status mengikuti **state machine** yang ditegakkan di server. Transisi tidak sah ditolak.
- Penutupan otomatis: `pending_customer` tanpa respons `[3]` hari kerja → pengingat; `[7]` hari kerja → `resolved` otomatis dengan pemberitahuan. **Pengaduan** mengikuti aturan khusus dari kepatuhan.

### 5.4 Prioritas
Matriks **dampak × urgensi** menghasilkan P1–P4. Aturan otomatis yang dapat dikonfigurasi:

- **P1 (kritis)**: dugaan peretasan / transaksi tidak dikenal, laporan penipuan aktif, nasabah tidak bisa menjual atau membeli **saat jam bursa** karena masalah sistem, dana hilang atau tidak sesuai dalam jumlah besar `[> X]`.
- **P2 (tinggi)**: pengaduan resmi, penarikan dana tertunda melewati batas, order bermasalah di jam bursa.
- **P3 (normal)**: sebagian besar pertanyaan dan permintaan.
- **P4 (rendah)**: saran dan pertanyaan umum di luar jam bursa.

Target SLA default (dapat dikonfigurasi), dihitung dalam jam layanan kecuali P1:

| Prioritas | Respons pertama | Target penyelesaian internal |
|---|---|---|
| P1 | `[15 menit]` (24/7 lewat on-call) | `[4 jam]` |
| P2 | `[1 jam]` | `[1 hari kerja]` |
| P3 | `[4 jam]` | `[3 hari kerja]` |
| P4 | `[1 hari kerja]` | `[5 hari kerja]` |

Target live chat: waktu tunggu rata-rata < `[2 menit]` di jam layanan.

**Tenggat regulasi untuk pengaduan selalu berlaku** dan tidak bisa dilonggarkan oleh target internal.

---

## 6. CS Console (Panel Customer Service)

Dibangun sebagai **Flutter web** di monorepo (`apps/cs-console`), berbagi komponen desain dan autentikasi staf dengan panel admin dari PROMPT-FEATURES. Di-deploy sebagai container Nginx statis di belakang VPN. Dioptimalkan untuk **layar lebar desktop**, karena agen bekerja seharian.

### 6.1 Role & Hak Akses

| Role | Hak utama |
|---|---|
| `agent_l1` | Menangani chat & tiket di antreannya, melihat data nasabah ber-masking, memakai macro, membuat tiket manual |
| `agent_l2` | Seperti L1, ditambah kategori lanjutan (settlement, aksi korporasi) dan eskalasi teknis |
| `specialist` (finance / settlement / IT / keamanan) | Hanya tiket yang dieskalasi ke timnya, catatan internal, dan tanggapan teknis |
| `supervisor` | Semua tiket timnya, penugasan ulang, persetujuan (turun klasifikasi, kompensasi, perpanjangan), dashboard realtime, QA |
| `compliance` | Semua pengaduan, laporan regulasi, audit log, kalender hari kerja, template resmi, retensi |
| `kb_editor` | Mengelola artikel Pusat Bantuan |
| `cc_admin` | Konfigurasi kategori, routing, SLA, jam layanan, macro global, akun staf (tanpa akses isi tiket kecuali diberi role lain) |

Satu staf bisa punya beberapa role. Semua dicek di server.

### 6.2 Tata Letak Utama
- **Sidebar kiri**: tampilan / antrean seperti "Chat aktif saya", "Tiket saya", "Belum ditugaskan", "Mendekati tenggat", "Pengaduan", "Menunggu nasabah", "Eskalasi ke saya", serta tampilan simpanan custom. Setiap item menampilkan jumlah.
- **Daftar tiket** (tengah): kolom yang bisa diatur, sortir, filter lanjutan, pencarian global (nomor tiket, nama, kode nasabah, isi pesan), indikator SLA berwarna (hijau / kuning / merah dengan hitung mundur), ikon kanal, prioritas, dan tag.
- **Workspace tiket** (kanan): percakapan + panel konteks nasabah.
- **Bar status agen** di atas: status (Online / Istirahat / Rapat / Offline, dengan alasan), jumlah chat aktif vs kapasitas, notifikasi, dan pencarian cepat.

### 6.3 Workspace Tiket / Chat
- **Lini masa terpadu**: pesan nasabah, balasan publik, **catatan internal** (latar berbeda dan tidak pernah terlihat nasabah), perubahan status, penugasan, panggilan telepon yang dicatat, email, dan peristiwa sistem.
- **Editor balasan**:
  - Pilihan *balasan publik* vs *catatan internal* dengan peringatan visual yang jelas.
  - **Macro / canned response** dengan variabel (`{nama_panggilan}`, `{nomor_tiket}`, `{tenggat}`) yang bisa sekaligus mengubah status, tag, dan prioritas.
  - Sisipkan artikel KB.
  - Lampirkan file.
  - Kirim permintaan dokumen atau verifikasi.
  - Pemeriksa ejaan.
  - Pratinjau tampilan di sisi nasabah.
- **Pemeriksaan sebelum kirim**:
  - Peringatan jika balasan berisi permintaan data terlarang (4.1).
  - Peringatan jika lupa melampirkan file yang disebut di teks.
  - Peringatan jika membalas tiket yang sedang dibalas agen lain.
- **Deteksi tabrakan (collision)**: menampilkan siapa saja yang sedang melihat atau mengetik di tiket yang sama, secara realtime.
- **@mention rekan** di catatan internal, yang memicu notifikasi.
- **Aksi tiket**:
  - Ubah status, prioritas, kategori, dan klasifikasi (dengan aturan 1.1).
  - Tugaskan ulang atau transfer chat ke agen / tim lain dengan catatan serah terima.
  - Eskalasi ke L2 / specialist dengan form alasan.
  - Gabung (merge) dan pisah (split) tiket.
  - Hubungkan ke insiden.
  - Buat tiket anak untuk tim lain.
  - Jeda menunggu dokumen.
  - Perpanjangan tenggat (khusus pengaduan, dengan alur 1.2).
  - Ajukan kompensasi (butuh persetujuan).
  - Tutup dengan **kategori akar masalah** dan ringkasan resolusi, keduanya wajib diisi.
- **Panel konteks nasabah (Customer 360)**:
  - Identitas ber-masking, status akun, tanggal bergabung, segmen `[jika ada]`, dan bahasa.
  - **Riwayat tiket** dan CSAT sebelumnya.
  - **Data OLT hanya-baca** (lewat adapter, dimuat saat diminta):
    - Order terkait dan order terakhir `[N]`.
    - Status RDN dan transaksi dana terakhir.
    - Ringkasan portofolio (hanya bila relevan dan sesuai role).
    - Perangkat dan sesi login terakhir.
    - Status keamanan akun.
  - Konteks perangkat dari tiket (versi aplikasi, OS).
  - Catatan nasabah yang persisten (misalnya "lebih suka dihubungi via email"), terlihat oleh agen dan bukan nasabah.
  - Tautan cepat ke data sosial nasabah (sanksi moderasi) **hanya untuk role yang berwenang**.
- **Shortcut keyboard** untuk aksi umum (balas, catatan internal, macro, tutup, tiket berikutnya), dengan daftar shortcut yang bisa dibuka.

### 6.4 Routing & Penugasan
- **Antrean per tim** (Umum, Akun, Dana, Transaksi, Teknis, Pengaduan, Keamanan/Fraud) dengan aturan routing dari panel. Kondisinya bisa berupa kategori, prioritas, kanal, bahasa, segmen nasabah, dan jam.
- Mode penugasan per antrean:
  - **Otomatis**: round-robin, beban terendah, atau berdasarkan keahlian (*skill-based*).
  - **Manual**: agen mengambil sendiri.
- **Kapasitas agen**: maksimum chat bersamaan `[3]` dan tiket aktif `[N]`. Penugasan otomatis hanya ke agen yang Online dan di bawah kapasitas.
- **Kelekatan (stickiness)**: nasabah yang kembali dalam `[48 jam]` diutamakan ke agen yang sama bila sedang online.
- Chat tidak dijawab dalam `[60 detik]` otomatis dialihkan ke agen lain, dan kejadiannya dicatat.
- Kalau agen logout atau ganti status ke istirahat, chat aktifnya **tidak hilang**: agen harus menyerahkannya dulu, atau setelah `[N]` menit chat dialihkan otomatis ke antrean.
- Kalau semua agen sibuk, nasabah melihat posisi antrean dan perkiraan tunggu, plus opsi "tinggalkan pesan" (jadi tiket).

### 6.5 Eskalasi & On-Call
- **Eskalasi fungsional** (ke tim specialist) dan **hierarkis** (ke supervisor / manajemen).
- **Aturan eskalasi otomatis**: SLA hampir lewat, CSAT buruk, nasabah membuka kembali lebih dari `[2]`x, kata kunci tertentu ("OJK", "lapor polisi", "pengacara", "viral"), atau nasabah VIP `[jika ada]`.
- **On-call 24/7 untuk P1**: jadwal on-call di panel, dengan notifikasi berlapis (push → panggilan / Telegram `[pilih]`) sampai ada yang mengakui (*acknowledge*).

### 6.6 Manajemen Insiden Massal
- Supervisor bisa membuat **insiden**, misalnya "Penarikan dana tertunda dari Bank X".
  - Tiket terkait digabungkan ke insiden.
  - **Banner status layanan** muncul di aplikasi.
  - **Balasan massal** dikirim ke semua tiket terkait saat ada pembaruan.
- Selesaikan insiden sekaligus dengan resolusi bersama. Tiap tiket tetap dicatat terpisah untuk laporan.
- Deteksi otomatis: lonjakan tiket dengan kategori yang sama dalam `[15 menit]` memicu saran pembuatan insiden ke supervisor.

### 6.7 Dashboard & Laporan
- **Realtime (supervisor)**:
  - Antrean saat ini, waktu tunggu terlama, dan agen online / istirahat / kapasitas.
  - Chat aktif.
  - Tiket mendekati atau melewati SLA.
  - Pengaduan mendekati tenggat regulasi.
  - Insiden aktif.
- **Kinerja** (per periode, tim, agen, kategori, kanal):
  - Volume masuk / selesai dan backlog.
  - Waktu respons pertama dan waktu penyelesaian (median & p90).
  - Kepatuhan SLA (%) dan kepatuhan tenggat regulasi (%).
  - CSAT, FCR, dan tingkat buka kembali.
  - AHT (rata-rata durasi penanganan).
  - Tingkat *deflection* Pusat Bantuan.
  - Topik / akar masalah teratas.
- **Laporan regulasi** sesuai 1.4, hanya untuk role `compliance`.
- **Insight produk**: kategori dan akar masalah teratas per versi aplikasi. Bisa diekspor untuk tim produk/IT, sehingga keluhan menjadi masukan perbaikan.
- Semua laporan bisa diekspor (CSV / XLSX / PDF), dan ekspor tercatat di audit log.

### 6.8 Quality Assurance (QA)
- Supervisor menilai sampel percakapan memakai **rubrik** yang bisa dikonfigurasi (sapaan, empati, ketepatan, kepatuhan, penutupan), lalu memberi umpan balik ke agen.
- Sampel acak otomatis dengan porsi lebih besar untuk tiket dengan CSAT buruk dan pengaduan.
- Agen bisa melihat skor dan umpan baliknya sendiri.

### 6.9 Pengelolaan Konten & Konfigurasi
- **Editor Knowledge Base**:
  - Draf → review → terbit.
  - Versi dan riwayat.
  - Jadwal terbit.
  - Bahasa ID/EN.
  - Pratinjau tampilan di aplikasi.
  - Statistik artikel (dilihat, membantu, tiket setelah membaca).
  - Penanda artikel internal (khusus agen) vs publik.
- **Macro**: pribadi, tim, dan global, dengan statistik pemakaian.
- **Template resmi**: bukti terima, permintaan dokumen, pemberitahuan perpanjangan, dan tanggapan akhir. Dikelola oleh `compliance`, berversi, dan perubahan butuh persetujuan.
- **Konfigurasi**: kategori & formulir dinamis, routing, SLA & prioritas, jam layanan, kalender hari kerja, pesan otomatis (salam, di luar jam, antrean), survei CSAT, kanal resmi yang ditampilkan di aplikasi, dan batas lampiran. **Semua perubahan konfigurasi berversi dan tercatat.**

### 6.10 Manajemen Staf
- Undang staf, atur role, tim, keahlian, bahasa, dan kapasitas.
- Nonaktifkan akun staf **seketika**: semua sesi dicabut dan tiket aktifnya dikembalikan ke antrean.
- Jadwal shift `[sederhana]` untuk perhitungan kapasitas dan on-call.
- Riwayat aktivitas staf (dari audit log).

---

## 7. Otomasi
- **Balasan otomatis** saat tiket dibuat: nomor tiket, perkiraan waktu, dan artikel terkait.
- **Kategorisasi dan prioritas otomatis** berbasis aturan (kategori, kata kunci, nilai field). Agen bisa mengoreksi, dan koreksinya tercatat sebagai bahan perbaikan aturan.
- **Saran artikel** untuk agen berdasarkan isi tiket (full-text).
- **Pengingat otomatis**: dokumen belum dikirim nasabah, tiket tanpa aktivitas, dan tenggat.
- **Pemicu (triggers)** yang bisa dikonfigurasi dengan format "jika [kondisi] maka [aksi]", misalnya: jika kategori "Penipuan" maka prioritas P1 + antrean Keamanan + notifikasi on-call.
- **Chatbot FAQ (opsional, fase lanjut)**:
  - Mulai dengan bot berbasis aturan / pohon pilihan yang mengarahkan ke artikel atau formulir.
  - Jika nanti memakai AI generatif, wajib ada batasan: hanya menjawab dari KB resmi, **tidak pernah memberi rekomendasi investasi**, tidak mengakses data nasabah tanpa izin, selalu menawarkan "bicara dengan agen", dan ditandai jelas sebagai bot.
- **Ringkasan otomatis** saat tiket dialihkan ke agen/tim lain, berupa template terstruktur yang diisi agen sebelumnya: masalah, yang sudah dicek, dan langkah berikutnya.

---

## 8. Integrasi dengan OLT

- **`customer-adapter`** (service baru, Dockerized, stateless), atau memperluas `market-adapter` sebagai modul terpisah. Fungsinya mengambil data nasabah dari OLT secara **hanya-baca**:
  - Profil.
  - Daftar order dan detailnya.
  - Transaksi RDN.
  - Ringkasan portofolio.
  - Perangkat / sesi.
  - Status keamanan.

  Sumber data: `[jelaskan: WebSocket OLT / GRPC ClientEngine / API internal, format pesan, autentikasi service-to-service]`.
- Setiap akses data lewat adapter mencatat **siapa (agen), tiket mana, data apa, dan kapan** di audit log.
- Aksi ke OLT yang diizinkan dari customer care hanya **"Amankan akun"** (4.6) dan **permintaan verifikasi identitas** (4.3), dengan protokol yang jelas dan teruji. Tidak ada aksi transaksi.
- Mode **mock** untuk development dengan data nasabah, order, dan transaksi palsu yang realistis.
- Deep link dari tiket di aplikasi ke layar OLT (order, deposit), dan sebaliknya (bantuan kontekstual, 3.6).
- Satu identitas: nasabah memakai login OLT yang sama lewat `auth-bridge`. Staf CS memakai akun staf terpisah dengan 2FA.

---

## 9. Model Data (ringkas)

Migrasi baru di schema terpisah, misalnya `care`, semuanya ber-RLS:

| Kelompok | Tabel |
|---|---|
| Tiket | `tickets`, `ticket_events` (lini masa, append-only), `ticket_messages`, `ticket_attachments`, `ticket_links` (merge/induk/duplikat), `ticket_tags`, `ticket_field_values`, `ticket_context` (perangkat/konteks) |
| Kategori & formulir | `categories` (pohon), `category_forms`, `form_fields` |
| SLA & kalender | `sla_policies`, `ticket_sla` (tenggat, jeda, perpanjangan), `business_hours`, `holidays`, `regulatory_deadlines` |
| Pengaduan | `complaints` (nomor pengaduan, jenis lisan/tertulis, tanggal dokumen lengkap, perpanjangan, tanggapan akhir, keberatan), `official_letters` (PDF yang dikirim) |
| Live chat | `chat_sessions`, `chat_queue`, `agent_presence` (cukup lewat Realtime presence + snapshot berkala) |
| Staf | `staff`, `staff_roles`, `teams`, `team_members`, `skills`, `staff_skills`, `oncall_schedules`, `shifts` |
| Routing & otomasi | `queues`, `routing_rules`, `triggers`, `macros`, `canned_attachments` |
| KB | `kb_articles`, `kb_article_versions`, `kb_categories`, `kb_feedback` |
| Kualitas | `csat_responses`, `qa_rubrics`, `qa_reviews` |
| Insiden | `incidents`, `incident_tickets`, `service_status_banners` |
| Keamanan | `care_audit_log` (append-only), `data_reveal_log`, `identity_verifications`, `fraud_reports`, `official_channels` |
| Konfigurasi | `care_settings` (berversi), `message_templates` (berversi, ID/EN) |

Ketentuan:
- `ticket_events` dan audit log **append-only**. RLS dan trigger menolak `UPDATE`/`DELETE`.
- Isi pesan disimpan **setelah masking** (4.4).
- Gunakan index dan partisi (per bulan) untuk tabel besar (`ticket_events`, `ticket_messages`, audit log).

---

## 10. Non-Fungsional

- **Realtime**:
  - Pesan chat dan pembaruan tiket memakai Realtime Broadcast dengan topik privat `care:ticket:<id>`, `care:customer:<id>`, `care:queue:<team>`, dan `care:agent:<id>`.
  - Database tetap sumber kebenaran.
  - Sinkron ulang setelah reconnect.
  - Siap multi-node (sesuai PROMPT bagian 8).
- **Kinerja**: daftar tiket dan pencarian < `[300 ms]` p95 untuk `[1 juta]` tiket. Gunakan pagination cursor.
- **Rate limit**:
  - Nasabah: pembuatan tiket `[5]`/jam, pesan chat `[30]`/menit, dan lampiran `[20]`/hari.
  - Agen: pembukaan profil nasabah dibatasi untuk deteksi anomali (4.7).
- **Lampiran**:
  - Hanya gambar (JPEG/PNG/WebP) dan PDF, dicek dari magic bytes.
  - Gambar di-*re-encode* dan metadata EXIF dihapus.
  - PDF divalidasi strukturnya, dan konten aktif (JavaScript, embedded file) **ditolak**.
  - Pemindaian malware: alat dengan lisensi GPL seperti ClamAV **hanya boleh dipakai jika disetujui legal**, sebagai service terpisah tanpa modifikasi. Jika tidak disetujui, andalkan pembatasan jenis file dan sanitasi di atas.
- **Email keluar**: lewat SMTP yang dapat dikonfigurasi `[penyedia SMTP]`, dengan SPF, DKIM, DMARC, template HTML + teks, dan pelacakan bounce. Email resmi menyertakan nomor tiket di subjek untuk threading.
- **PDF resmi**: dibuat di server dari template, dengan nomor dokumen dan hash yang dicatat (untuk verifikasi keaslian). Opsional: tanda tangan elektronik `[penyedia tersertifikasi]`.
- **Ketersediaan**: penerimaan tiket & pengaduan harus tetap berjalan walaupun `customer-adapter` atau OLT bermasalah. Konteks yang gagal diambil ditandai "tidak tersedia", tetapi tiket tetap dibuat.
- **Observabilitas**: metrik antrean, waktu tunggu, SLA, error adapter, dan email gagal kirim di Grafana, beserta alert.

---

## 11. Pengujian

- **Mesin SLA**: unit test perhitungan hari kerja dengan libur nasional, cuti bersama, akhir pekan, pergantian tahun, jeda, perpanjangan, dan tenggat yang jatuh di hari libur.
- **State machine** status tiket: semua transisi sah dan yang ditolak.
- **RLS & role**:
  - Agen tidak bisa membuka tiket atau profil di luar haknya.
  - Catatan internal tidak pernah terlihat nasabah, baik lewat API maupun Realtime.
  - Audit log tidak bisa diubah.
- **Keamanan**:
  - Masking data sensitif di pesan nasabah dan agen.
  - Macro yang meminta OTP ditahan.
  - Reveal tercatat.
  - Lampiran berbahaya ditolak.
  - Signed URL kedaluwarsa.
- **Regulasi**:
  - Tiket `complaint` tidak bisa diturunkan tanpa persetujuan.
  - Perpanjangan mengirim surat sebelum tenggat.
  - Laporan regulasi sesuai data.
- **Live chat end-to-end**: antrean, penugasan otomatis, transfer, chat tidak dijawab dialihkan, agen logout, nasabah offline lalu online, dan multi-node.
- **Uji beban** di jam sibuk, misalnya saat pembukaan pasar atau gangguan massal: `[X]` chat bersamaan dan `[Y]` tiket/menit.
- **Uji kegunaan** CS Console dengan skenario nyata (simulasi shift agen).

---

## 12. Tahapan Pengerjaan

Dikerjakan setelah tahap 6 (single-node production) dari PROMPT.md. Urutannya bisa paralel dengan F2–F5, tetapi **C1–C3 wajib sebelum customer care diluncurkan ke nasabah**.

1. **C1: Fondasi tiket & regulasi**
   - Schema `care`, kategori & formulir dinamis, state machine, mesin SLA + kalender hari kerja, klasifikasi pengaduan, bukti terima PDF, `customer-adapter` (mode mock), audit log, dan role staf.
   - Kriteria selesai: semua tes SLA & regulasi lulus.
2. **C2: Aplikasi nasabah (`olt_care`)**
   - Beranda bantuan, Pusat Bantuan, alur pembuatan tiket pintar dengan konteks otomatis, "Tiket saya", notifikasi, bantuan kontekstual, kontak resmi & laporkan CS palsu, serta tombol darurat.
   - Berjalan di Windows dan Android.
3. **C3: CS Console inti & live chat**
   - Inbox, workspace tiket, Customer 360 ber-masking, macro, catatan internal, collision detection, routing & penugasan otomatis, kapasitas agen, live chat realtime, CSAT, verifikasi agen, dan verifikasi identitas nasabah.
   - Kriteria selesai: skenario end-to-end live chat dan tiket lulus.
4. **C4: Supervisor & kepatuhan**
   - Dashboard realtime, laporan kinerja & regulasi, perpanjangan & surat resmi, eskalasi & on-call, manajemen insiden + banner status, QA, serta template resmi berversi.
5. **C5: Kanal tambahan & otomasi**
   - Email → tiket, Pusat Bantuan web publik, triggers, saran artikel, dan pengingat otomatis.
6. **C6: Penyempurnaan**
   - Chatbot FAQ berbasis aturan, insight produk, aksesibilitas penuh, serta uji beban & keamanan menyeluruh.
   - Dokumen `docs/customer-care.md` (operasional, SOP agen, dan panduan konfigurasi).

Setiap tahap: berhenti, ringkas hasilnya, perbarui dokumentasi dan checklist produksi, lalu tunggu konfirmasi saya.

**Sebelum mulai C1**, berikan kepada saya:
1. Daftar pertanyaan untuk **tim kepatuhan** (tenggat, format nomor pengaduan, isi template resmi, format laporan, retensi, prosedur verifikasi identitas).
2. Daftar informasi yang kamu butuhkan tentang **sumber data nasabah OLT** untuk `customer-adapter`.
3. Usulan desain (wireframe teks atau diagram) untuk layar utama aplikasi nasabah dan CS Console.

Lalu tunggu jawaban saya.
