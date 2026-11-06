# Panduan Rendezvous Hub untuk Staf

Panduan pelatihan sebelum rilis untuk staf non-teknis: **CS (agen)**, **Supervisor / Super Admin** bagian operasional CS, **Kepatuhan**, dan **moderator Komunitas**. Nama menu, tab, dan tombol ditulis **tebal**, persis seperti tampil di Hub (bahasa Indonesia).

Bacalah bagian 1 dulu, lalu bagian untuk peran Anda. Bagian 6 (situasi darurat) wajib dibaca semua staf.

## 1. Pendahuluan

### 1.1 Apa itu Rendezvous Hub

Rendezvous Hub (selanjutnya "Hub") adalah aplikasi web internal untuk staf. Dari Hub, staf:

- melayani chat nasabah dari aplikasi OLT lewat **tiket**;
- memantau layanan CS, membuat laporan, dan mengatur Hub;
- mengawasi pengaduan, kasus penipuan, dan kebijakan konten;
- mengelola postingan resmi, notifikasi, dan moderasi komunitas.

Semua tindakan penting tercatat di **Jejak Audit** dan tidak bisa dihapus.

### 1.2 Cara masuk

1. Buka alamat Hub yang diberikan tim IT. Hub hanya bisa dibuka dari **jaringan kantor** (atau VPN kantor bila disediakan IT). Dari jaringan lain halaman tidak terbuka.
2. Di halaman **Masuk ke Rendezvous Hub**, isi **Email** (email kerja) dan **Password**, lalu klik **Masuk**.
3. **Login pertama** atau setelah password direset: Hub meminta **Ganti password**.
   - Isi **Password baru** dan **Ulangi password baru**, lalu **Simpan password**.
   - Minimal 12 karakter. Harus berbeda dari password sementara. Jangan pakai ulang password akun lain.
4. Untuk keluar: klik avatar di kanan atas, lalu **Keluar**.

Hal yang perlu diketahui:

- **Lupa password:** minta Super Admin melakukan **Reset password**. Anda mendapat password sementara baru yang wajib diganti saat login berikutnya. Tidak ada reset mandiri lewat email.
- **Keluar otomatis:** bila Hub tidak dipakai beberapa saat (bawaan 30 menit), muncul dialog **Masih di sana?**. Klik **Tetap masuk**, atau Hub keluar otomatis.
- Pesan **Email atau password salah.** berarti salah ketik. Pesan **Terlalu banyak percobaan. Tunggu sebentar.** berarti tunggu sebelum mencoba lagi.
- Pesan **Akun ini bukan akun CS aktif.** berarti akun Anda nonaktif. Hubungi Super Admin.
- Satu browser boleh membuka beberapa akun berbeda di tab berbeda; masing-masing tab tetap memakai akunnya sendiri.

### 1.3 Peran dan menu

Super Admin memberi setiap akun **peran** dan, bila perlu, **izin tambahan**:

| Peran | Untuk siapa |
|---|---|
| **CS** | Agen yang menangani tiket chat nasabah |
| **Super Admin** | Supervisor / admin operasional CS. Memantau tiket dan CS, tidak membalas nasabah. Mengelola akun staf dan semua pengaturan |
| **Kepatuhan** | Tim kepatuhan: pengaduan, penipuan, audit, kebijakan, dokumen hukum, bukti |
| **Komunitas** | Tim riset/marketing/moderasi yang tidak menangani tiket. Menunya ditentukan **Izin Komunitas** |
| **Fitur & Kampanye** | Tim produk/marketing yang mengelola fitur sosial, kill switch, versi minimum aplikasi, serta banner dan popup. Tidak bisa membuka Pengaturan, Dashboard, Laporan, atau tiket |

Izin tambahan:

- **Izin Komunitas** (5 izin, bisa diberikan ke peran apa pun) membuka menu **Komunitas**. Lihat bagian 5.
- **Akses Akun Nasabah** (khusus akun berperan CS) membuka menu **Akun Nasabah**. Lihat bagian 2.7.

Menu di bar atas mengikuti peran dan izin. Satu akun bisa punya lebih dari satu peran; menunya digabung.

| Menu | CS | Super Admin | Kepatuhan | Komunitas | Fitur & Kampanye |
|---|---|---|---|---|---|
| **Layanan Nasabah** (tiket) | Ya | Ya, hanya pantau | – | – | – |
| **Dashboard** | – | Ya | – | – | – |
| **Laporan** | – | Ya | – | – | – |
| **Akun Nasabah** | Bila punya Akses Akun Nasabah | – | – | – | – |
| **Komunitas** | Bila punya Izin Komunitas | Ya (tab **Analitik**; tab lain sesuai Izin Komunitas) | Bila punya Izin Komunitas | Bila punya Izin Komunitas | – |
| **Fitur & Kampanye** | – | Ya | – | – | Ya |
| **Pengaturan** | – | Ya | – | – | – |
| **Ringkasan**, **Kasus**, **Jejak Audit**, **Kebijakan**, **Kata terlarang**, **Kebijakan konten**, **Dokumen hukum** | – | – | Ya | – | – |
| **Bukti** | – | Hanya baca, lewat Ctrl K | Ya | – | – |

Bila akun tidak punya menu sama sekali, Hub menampilkan **Peran akun ini belum punya menu di web CS. Hubungi Super Admin.**

### 1.4 Tampilan umum

- **Kotak cari di tengah bar atas (Ctrl K):** cari tiket, nasabah, menu, atau perintah.
- **Indikator koneksi** di kanan atas: **Terhubung**, **Menyambung ulang…**, atau **Offline**. Bila tidak **Terhubung**, periksa jaringan Anda.
- **Ikon lonceng:** atur **Notifikasi tiket baru** (**Semua tiket**, **Prioritas tinggi saja**, atau **Mati**), **Izinkan notifikasi browser**, dan **Tes suara**.
- **Avatar (menu akun):** **Profil saya**, **Kinerja saya** (khusus staf yang menangani tiket), **Ganti password**, **Tema** (**Terang**, **Gelap**, **Ikuti sistem**), **Kepadatan** (**Nyaman**, **Padat**), **Bahasa**, **Pintasan keyboard**, **Keluar dari semua perangkat**, dan **Keluar**.
  - **Profil saya** (hanya-baca): email login, nama yang dilihat nasabah, kode staf, peran, tim, batas tiket aktif, bahasa layanan, izin Komunitas dan Akun Nasabah, tanggal akun dibuat, dan kapan password terakhir diganti (**Belum tercatat** bila belum pernah diganti lewat Hub sejak fitur ini ada). Untuk mengubah data ini, hubungi Super Admin.
  - **Ganti password:** isi **Password saat ini**, **Password baru**, dan **Ulangi password baru**, lalu **Ganti password**. Aturannya sama dengan ganti password pertama: minimal 12 karakter dan harus berbeda dari password saat ini. Bila password saat ini salah, muncul **Password saat ini salah.** dan Anda tetap masuk. Setelah berhasil, akun ini otomatis keluar di perangkat dan tab lain; tab ini tetap masuk. Penggantian tercatat di Jejak Audit (tanpa isi password).
  - **Keluar dari semua perangkat:** setelah konfirmasi, semua sesi akun ini (perangkat lain dan tab ini) dikeluarkan dan Hub kembali ke halaman masuk. Pakai bila Anda lupa keluar di komputer lain atau curiga akun dipakai orang lain, lalu segera ganti password. Tercatat di Jejak Audit.
  - Kedua aksi di atas hanya memengaruhi **akun Anda sendiri**. Akun lain yang terbuka di tab lain pada browser yang sama tidak ikut keluar. Tab lain yang memakai akun Anda kembali ke halaman masuk dengan pesan sesi berakhir.
- Waktu di Hub memakai **WIB**.

## 2. Untuk CS (agen)

### 2.1 Aturan penting

> **Jangan pernah meminta OTP, PIN, password, CVV, atau nomor kartu nasabah.** Hub menahan pesan seperti itu dengan peringatan **CS tidak boleh meminta OTP, PIN, password, atau nomor kartu. Ubah kalimat sebelum mengirim.** Bila tetap terkirim ke server, pesan ditahan, Super Admin diberi tahu, dan percobaan Anda tercatat di Ringkasan Kepatuhan.

1. Ubah status ke **Online** sebelum mulai bekerja, dan **Keluar** saat selesai.
2. **Nama tampilan** Anda terlihat oleh nasabah. Bersikaplah sebagai "CS Resmi".
3. Informasi untuk sesama staf ditulis di **Catatan internal**, bukan di balasan. Nasabah tidak pernah melihat catatan internal.
4. Jangan menyalin isi chat atau data nasabah ke luar Hub (chat pribadi, email pribadi, foto layar ke grup).
5. Jangan berbagi akun atau password. Setiap aksi tercatat atas nama Anda.
6. Tautan yang dikirim ke nasabah hanya tautan **https://** ke situs bantuan resmi.
7. Data akun nasabah (profil, order, dana, logout paksa) tidak ada di chat. Untuk data dan aksi akun, pakai menu **Akun Nasabah** (bila diberi izin) atau back-office OLT sesuai prosedur kantor.

### 2.2 Status kerja

Klik status Anda di kanan atas (**Ubah status**). Saat login, status selalu dimulai **Offline**.

| Status | Ambil tiket / terima transfer | Membalas nasabah |
|---|---|---|
| **Online** | Ya, selama batas tiket aktif belum penuh | Ya |
| **Sibuk** | Tidak | Ya, untuk menyelesaikan percakapan yang berjalan |
| **Istirahat** | Tidak | Ya, untuk menyelesaikan percakapan yang berjalan |
| **Offline** | Tidak | Tidak. Kotak balas terkunci, draf tidak hilang |

- Untuk **Sibuk**, **Istirahat**, atau **Offline**, Anda bisa memilih alasan: **Makan siang**, **Rapat**, **Ibadah**, **Lainnya**, lalu **Terapkan**.
- Angka **Aktif n/maks** menunjukkan tiket aktif Anda dibanding batas maksimal. Bila penuh, selesaikan atau lepas tiket dulu.
- Saat **Keluar**, status otomatis menjadi **Offline**.
- **Tiket tetap milik Anda walau Anda Offline.** Nasabah diberi tahu bahwa CS sedang tidak aktif. Super Admin bisa memindahkan tiket Anda ke CS lain.

### 2.3 Daftar tiket (menu **Layanan Nasabah**)

Layar dibagi tiga: daftar tiket di kiri, percakapan di tengah, **Info nasabah** di kanan.

Tab daftar tiket:

| Tab | Isi |
|---|---|
| **Terbuka** | Tiket di antrean yang belum diambil CS |
| **Tiket saya** | Tiket yang sedang Anda tangani |
| **Selesai hari ini** | Tiket yang Anda selesaikan hari ini |

- Di atas daftar ada **Transfer masuk** (permintaan dari CS lain) dan **Menunggu diterima** (transfer yang Anda kirim).
- **Filter**: **Topik**, **Prioritas** (P1 paling mendesak sampai P4), **Tanda** (**Pengaduan**, **Fraud**, **VIP**), dan **Label** (muncul bila ada tiket berlabel di daftar).
- **Label tiket** tampil berwarna di baris tiket dan di bawah nama nasabah pada percakapan. Label hanya untuk staf; nasabah tidak pernah melihatnya.
- Kotak **Cari nomor, nama, pesan** mencari tiket.
- Nomor tiket berbentuk `CS-YYYYMMDD-NNNN`. Setiap nasabah paling banyak punya satu tiket aktif.

Status tiket:

| Status | Arti |
|---|---|
| **Terbuka** | Menunggu diambil CS |
| **Ditangani** | Sedang ditangani seorang CS |
| **Menunggu nasabah** | CS menunggu balasan nasabah |
| **Selesai** | CS sudah menyelesaikan; nasabah diminta memberi rating |
| **Ditutup** | Tiket berakhir dan tidak bisa dibalas lagi |

### 2.4 Mengambil tiket dan menerima transfer

**Mengambil tiket (mode bawaan "Ambil tiket"):**

1. Pastikan status **Online**.
2. Di tab **Terbuka**, klik tiket. Anda bisa membaca pesannya (pratinjau, hanya baca) dengan keterangan **Ambil tiket ini untuk membalas**.
3. Klik **Ambil** (atau tekan **A**).
4. Bila CS lain lebih cepat, muncul **Tiket sudah diambil oleh [nama].** Pilih tiket lain.

Bila status bukan Online, muncul pesan **Status Anda … Ubah ke Online dulu untuk mengambil tiket.** dengan tombol **Ubah ke Online**.

**Penugasan otomatis:** bila Super Admin memakai mode **Penugasan otomatis**, sistem membagikan tiket ke CS yang Online, sesuai skill, dan masih punya slot. Anda mendapat bunyi dan notifikasi **Tiket baru ditugaskan ke Anda**.

**Menerima transfer dari CS lain:**

1. Permintaan tampil di **Transfer masuk** beserta catatan serah terima dan batas waktunya (**berlaku sampai …**).
2. Klik **Terima** (wajib Online dan punya slot), atau **Tolak** dengan alasan (opsional).
3. Setelah diterima: **Transfer diterima. Tiket sekarang milik Anda.**

### 2.5 Membalas nasabah

Kotak balas punya dua mode: **Balas** (terkirim ke nasabah) dan **Catatan internal** (**Tidak terlihat nasabah**).

- **Enter** kirim, **Shift+Enter** baris baru. Tekan **R** untuk ke kotak balas, **N** untuk catatan internal.
- Status pesan Anda: **Mengirim…**, **Terkirim**, **Dibaca**, atau **Gagal terkirim** (pilih **Kirim ulang** atau **Buang**).
- Arahkan ke sebuah pesan lalu pilih **Balas pesan ini** untuk mengutipnya.
- Titik di samping nama nasabah menunjukkan apakah nasabah sedang membuka chat.

**Lampiran:**

1. Klik ikon klip (**Lampirkan gambar atau PDF**), seret file ke kotak balas, atau tempel gambar dengan **Ctrl+V** (misalnya setelah tangkapan layar).
2. Klik thumbnail untuk **Pratinjau lampiran** sebelum mengirim.
3. Yang diterima: gambar (JPEG, PNG, WebP, GIF) dan **PDF maksimal 10 MB**. Maksimal 4 lampiran per pesan. Gambar besar dikecilkan otomatis.
4. Video, voice note, dan file Office **tidak diterima**. Minta nasabah mengirim tangkapan layar atau PDF.

**Balasan cepat:** ketik **/** di kotak balas, atau klik **Sisipkan balasan cepat**, lalu pilih (panah atas/bawah, **Enter** atau **Tab**). Daftar dibagi dua grup: **Pribadi** (milik Anda) dan **Bersama** (disiapkan Super Admin di menu **Quick reply**). Pencarian mencakup keduanya.

**Balasan cepat pribadi:** klik **Kelola balasan pribadi** di bawah daftar balasan cepat. Isi **Judul**, **Isi balasan**, dan bila mau **Pintasan** (kosongkan agar dibuat otomatis dari judul). Batas: judul 80 karakter, isi 2.000 karakter, maksimal 50 balasan per staf. Hanya Anda yang melihatnya. Balasan yang meminta OTP/PIN/password ditolak, nomor rekening/kartu disamarkan saat disimpan, dan saat dikirim isinya tetap diperiksa seperti pesan biasa.

**Label tiket:** klik ikon label di kepala percakapan, lalu centang atau hapus centang label. Maksimal 5 label per tiket. Yang bisa mengubah: CS pemegang tiket (selama tiket ditangani/menunggu nasabah) dan Super Admin. Perubahan label tercatat di riwayat tiket dan langsung terlihat oleh staf lain yang membuka tiket yang sama.

**Kirim lainnya** (tombol di kotak balas):

- **Tautan bantuan**: isi **Judul** dan **Alamat (https)**.
- **Pilihan cepat**: isi **Pertanyaan** dan 2–4 pilihan; nasabah tinggal mengetuk salah satu.

**Penyamaran data sensitif:** bila nasabah (atau CS) mengetik OTP, password, nomor kartu, NIK, atau nomor rekening di chat, sistem menyamarkannya otomatis. Pesan diberi keterangan **Disamarkan otomatis** beserta jenis datanya. Ini disengaja; jangan minta nasabah mengirim ulang data tersebut.

**Tautan dari nasabah:** bila Anda membuka tautan ke luar situs bantuan resmi, Hub bertanya **Buka tautan luar?**. Buka hanya bila yakin aman.

### 2.6 Info nasabah

Panel **Info nasabah** di kanan (bisa diciutkan) berisi:

- **Riwayat tiket** nasabah sebelumnya, termasuk rating (**Nilai n/5**).
- **Catatan internal**: klik **Tambah catatan**, pilih **Untuk tiket ini** atau **Untuk nasabah (semua tiket)**. Catatan per nasabah tetap terlihat di tiket berikutnya. Catatan tidak bisa diubah setelah disimpan.
- Bagian **Akun Nasabah** (hanya bila Anda punya Akses Akun Nasabah dan nasabah terdaftar di sistem Akun Nasabah): LoginId, tipe, status, email dan HP, rekening tertaut, serta tautan **Buka di Akun Nasabah**.

Anda bisa membaca seluruh riwayat chat nasabah selama menangani tiketnya, dan sampai 24 jam setelah tiket selesai. Akses ini hilang bila tiket dilepas atau ditransfer.

### 2.7 Menu Akun Nasabah (bila diberi izin)

Menu ini menampilkan dan mengelola Online ID nasabah. Menu hanya tampil bila Super Admin memberi **Akses Akun Nasabah** dan integrasi API Nasabah sudah aktif. Isi menu mengikuti izin Anda:

| Izin (sesuai teks di Hub) | Boleh |
|---|---|
| **Lihat nasabah online** | Lihat daftar nasabah dan rekening tertautnya |
| **Kelola Online ID (pengajuan, rekening tertaut, reset password/PIN)** | **Ajukan Online ID**, **Ajukan perubahan**, **Ajukan hapus**, **Kelola rekening tertaut**, **Reset password**, **Reset PIN** |
| **Kelola akun demo saja** | Pengajuan hanya untuk akun demo |
| **Approval pengajuan Online ID dari CS lain** | **Setujui** / **Tolak** pengajuan CS lain di tab **Approval** |
| **Approve pengajuan sendiri tanpa menunggu CS lain** | Memutuskan pengajuan sendiri |
| **Kirim email pembukaan rekening** | Tab **Pembukaan rekening**: **Kirim email** satu per satu atau beberapa sekaligus |
| **Ubah status Online ID langsung (wajib alasan, tanpa approval)** | Tombol **Ubah status**, alasan 10–200 karakter |

Cara kerja umum:

1. Tab **Online ID**: cari LoginId atau email, klik baris untuk membuka detail.
2. Perubahan data (buat, ubah, hapus, tautan rekening) **diajukan** dulu dan baru berlaku setelah **disetujui**. Sebelum terkirim ada konfirmasi **Kirim pengajuan …?**.
3. Tab **Approval**: pengajuan menunggu keputusan. Secara bawaan pengajuan Anda harus diputuskan CS lain.
4. **Reset password** dan **Reset PIN** langsung membuat kredensial baru dan mengirimnya ke **email terdaftar nasabah**. Kredensial lama langsung tidak berlaku. Lakukan hanya atas permintaan nasabah yang sudah diverifikasi sesuai prosedur kantor.
5. Email pembukaan rekening berisi data rekening beserta password dan PIN aktif nasabah. Periksa alamat email tujuan sebelum mengirim.
6. Sakelar **Hanya data belum lengkap** menandai nasabah tanpa email, nomor HP, atau tanggal lahir. Tombol **Lengkapi data** membuka form pengajuan perubahan.

Semua aksi tulis tercatat dengan kode CS Anda.

### 2.8 Menunggu, melepas, mentransfer, dan menyelesaikan tiket

Tombol di atas percakapan (hanya untuk pemilik tiket):

| Tombol | Kapan dipakai | Yang terjadi |
|---|---|---|
| **Tunggu nasabah** | Anda menunggu nasabah mengirim info/bukti | Status **Menunggu nasabah**. Kembali **Ditangani** saat nasabah membalas |
| **Lepas** | Anda tidak bisa melanjutkan (misalnya pulang, bukan bidang Anda) | Isi **Alasan** (minimal 3 karakter). Tiket kembali ke **Terbuka** dan bisa diambil CS lain |
| **Transfer** | Ingin menyerahkan ke CS tertentu | Pilih **CS tujuan** (hanya CS yang online dan punya slot) dan isi **Catatan serah terima**. **Tiket tetap milik Anda sampai CS tujuan menerima.** Bila tidak diterima sampai batas waktu, transfer kedaluwarsa |
| **Selesaikan** (tombol **E**) | Masalah nasabah sudah tuntas | Pilih **Hasil**, isi **Ringkasan** 5–500 karakter. Ringkasan tidak terlihat nasabah. Nasabah diminta memberi rating |

- Menu **Aksi lainnya** (ikon titik tiga) berisi **Ubah prioritas** (P1–P4).
- Bila Hub menampilkan **Tiket sudah berubah. Data terbaru dimuat ulang.**, berarti tiket diubah orang lain; periksa lagi sebelum melanjutkan.

### 2.9 Rating, tutup otomatis, dan tiket tertutup

1. Setelah **Selesaikan**, nasabah diminta memberi rating 1–5.
2. **Setelah nasabah memberi rating, tiket langsung ditutup.**
3. Bila nasabah membalas **sebelum** memberi rating dan sebelum batas tutup otomatis, tiket dibuka kembali dan kembali ke Anda (atau ke antrean bila Anda tidak aktif atau penuh).
4. Bila nasabah tidak memberi rating, tiket **ditutup otomatis** setelah batas hari yang diatur Super Admin (bawaan 3 hari).
5. **Tiket yang sudah ditutup tidak bisa dibalas.** Nasabah membuat tiket baru untuk chat lagi. Di Hub tampil **Tiket ditutup dan tidak bisa dibalas lagi.** Bila nasabah sudah punya tiket aktif baru, klik **Buka tiket aktif**.

### 2.10 Pengaduan resmi dan laporan CS palsu

**Pengaduan resmi.** Nasabah bisa mengajukan pengaduan dari aplikasi.

- Tiketnya diberi tanda **Pengaduan** dan prioritasnya dinaikkan.
- Sistem mencatat waktu pengaduan diterima dan **tenggat pengaduan** dalam hari kerja (kalender WIB). Nasabah langsung menerima pesan berisi keduanya. Tenggat terlihat di atas percakapan (**tenggat pengaduan …**).
- Tangani seperti biasa, tetapi utamakan sebelum tenggat. Kepatuhan memantau ketepatan waktunya dan bisa memperpanjang tenggat satu kali (bagian 4.2).

**Laporan CS palsu.** Bila nasabah melapor dihubungi orang yang mengaku CS:

- Tiketnya diberi tanda **Fraud** dengan prioritas P1. Cerita nasabah muncul di chat sebagai pesan **Laporan CS palsu: …**.
- Super Admin langsung mendapat notifikasi **Laporan CS palsu**, dan kasusnya masuk register Kepatuhan.
- Tegaskan bahwa CS resmi hanya ada di room CS di aplikasi dan tidak pernah meminta OTP, PIN, atau password. Catat kronologi di **Catatan internal**.

### 2.11 Pintasan keyboard

| Tombol | Fungsi |
|---|---|
| **Ctrl K** | Buka command palette |
| **J** / **K** | Tiket berikutnya / sebelumnya |
| **A** | Ambil tiket terpilih |
| **R** | Fokus kolom balas |
| **N** | Tulis catatan internal |
| **E** | Selesaikan tiket |
| **Ctrl Enter** | Kirim pesan |
| **?** | Daftar pintasan |

### 2.12 Kinerja saya

Buka dari avatar → **Kinerja saya**, atau ikon pengukur di samping **Aktif n/maks**. Pilih periode **Hari ini**, **7 hari**, atau **30 hari** (WIB, menurut tanggal tiket dibuat). Yang ditampilkan hanya angka Anda sendiri:

- **Tiket diselesaikan** dari jumlah tiket yang terakhir Anda tangani, dan **Sedang ditangani** (tiket aktif saat ini).
- **Rata-rata respons pertama** (sejak tiket diambil) dan **Rata-rata waktu selesai** (sejak tiket dibuat, untuk tiket yang Anda selesaikan).
- **Rating rata-rata**, jumlah rating, dan **Distribusi rating** 1–5 bintang.
- **Pengaduan** dari tiket Anda.

Definisinya sama dengan baris Anda di **Laporan** Super Admin, jadi angkanya cocok untuk periode yang sama.

## 3. Untuk Supervisor / Super Admin operasional

Super Admin **memantau dan mengelola**, tidak melayani nasabah. Super Admin tidak mengambil, membalas, menyelesaikan, melepas, atau mentransfer tiket, dan tidak pernah menerima tiket.

### 3.1 Memantau tiket (mode pantau)

Di menu **Layanan Nasabah**, Super Admin melihat **Mode pantau**, dengan tab **Semua aktif** dan **Terbuka**. Super Admin bisa:

- membaca semua tiket dan percakapan (hanya baca);
- menulis **Catatan internal**;
- **Ubah prioritas** lewat **Aksi lainnya**;
- **Pindahkan ke…**: memindahkan tiket langsung ke CS lain dengan alasan. Pakai untuk tiket milik CS yang offline agar nasabah tidak menunggu. Pemindahan tercatat di audit.

Notifikasi khusus Super Admin: tiket yang belum diambil melewati batas waktu, **Laporan CS palsu**, dan **CS mencoba meminta data rahasia**.

### 3.2 Dashboard

Diperbarui otomatis. Angka di menu **Dashboard** adalah jumlah tiket yang perlu perhatian.

- Angka utama: **Tiket terbuka**, **Tunggu terlama**, **Sedang ditangani**, **Selesai hari ini**, **CS online**.
- **Perlu perhatian**: tiket belum diambil melewati batas (P1 punya batas lebih pendek), **Fraud / pengaduan belum diambil**, dan tiket **Milik CS yang offline**. Klik tiket untuk membukanya di **Layanan Nasabah**.
- **Status CS hari ini**: status, tiket aktif, selesai hari ini, dan sejak kapan statusnya. Keterangan **Web CS tidak mengirim heartbeat** berarti koneksi CS itu kemungkinan terputus.
- **Antrean per prioritas**.

### 3.3 Laporan

1. Pilih rentang: **Hari ini**, **7 hari**, **30 hari**, atau **Pilih tanggal**.
2. Lihat **Tiket masuk**, **Selesai**, **Rata-rata sampai diambil**, **Respons pertama**, **Durasi sampai selesai**, dan **Rating rata-rata**.
3. Tabel: **Tiket per hari**, **Per CS**, **Topik terbanyak**, **Tiket per label** (jumlah tiket masuk per label dan tiket tanpa label), dan **Per nasabah**.
4. **Per nasabah**: klik nama nasabah untuk membuka **Jejak layanan nasabah**. **Akses ke jejak layanan ini tercatat di audit log.** Buka hanya bila ada keperluan kerja.
5. **Ekspor CSV** per bagian. File berisi data nasabah: simpan di folder kerja yang aman, jangan dikirim ke luar.

### 3.4 Pengaturan

Menu **Pengaturan** hanya untuk Super Admin. Setiap perubahan tercatat di Jejak Audit.

**Form penting terkunci.** Integrasi API Nasabah, Integrasi aplikasi (skema deep link), Push notification (kunci Firebase), Alert, Backup, Penugasan, dan Komunitas tampil terkunci. Klik **Ubah** untuk membuka, lalu **Simpan**: Hub menampilkan konfirmasi yang menjelaskan dampaknya, dan perubahan baru tersimpan setelah dikonfirmasi. **Batal** atau **Esc** mengembalikan nilai semula. Tes koneksi, Kirim uji, dan push uji tetap bisa langsung dijalankan; Backup penuh dan Uji restore meminta konfirmasi.

 Menu samping dikelompokkan dalam empat judul kecil: **Layanan CS**, **Komunitas**, **Integrasi**, dan **Sistem**. Fitur sosial, versi minimum, serta banner dan popup untuk nasabah ada di menu **Fitur & Kampanye** (bagian 3.5).

| Kelompok | Bagian | Fungsi | Kapan dipakai |
|---|---|---|---|
| **Layanan CS** | **Akun CS** | Tambah akun staf, peran, tim, batas tiket, izin, reset password, nonaktifkan | Staf baru, pindah tugas, lupa password, staf keluar |
| | **Topik** | Topik yang dipilih nasabah, prioritas default, skill, tautan bantuan | Ada jenis masalah baru |
| | **Quick reply** | Balasan cepat untuk semua CS | Jawaban baku baru atau berubah |
| | **Label tiket** | Daftar label yang dipasang CS pada tiket (nama, warna, aktif, urutan) | Pengelompokan kasus baru untuk laporan |
| | **Jam layanan & libur** | Jam buka CS (WIB) dan hari libur | Awal tahun, perubahan jam kerja |
| | **Pesan otomatis** | Pesan sistem ke nasabah (ID/EN) | Mengubah kata-kata pesan sistem |
| | **Penugasan, tiket & alert** | Mode penugasan, lepas otomatis, tutup otomatis, batas alert | Mengatur alur kerja tim |
| **Komunitas** | **Aturan persetujuan** | Aturan empat mata postingan/notifikasi dan kebijakan konten | Jarang; atas permintaan Kepatuhan |
| **Integrasi** | **Integrasi API Nasabah** | Sambungan menu Akun Nasabah | Pemasangan awal bersama IT |
| | **Integrasi aplikasi** | Data untuk tim aplikasi OLT dan status login OLT (hanya baca) | Diminta tim aplikasi, cek login |
| | **API Notifikasi** | API key untuk sistem lain yang mengirim notifikasi | Sistem baru, rotasi key |
| | **Push notification** | Kunci Firebase dan push uji | Pemasangan awal, ganti kunci |
| **Sistem** | **Backup** | Tujuan, password, jadwal backup, uji restore | Pemasangan awal, cek mingguan |
| | **Alert** | Kanal alert gangguan (Telegram/email) | Pemasangan awal, ganti penerima |

#### Akun CS

1. Klik **Tambah akun**. Isi email kerja, **Nama tampilan** (2–40 karakter, **terlihat oleh nasabah**), **Peran**, **Tim**, dan **Batas tiket aktif (1–20)**.
2. Bila perlu, centang **Izin Komunitas** (bagian 5) dan **Akses Akun Nasabah** (hanya untuk akun berperan CS).
3. Klik **Buat akun**. **Password sementara hanya ditampilkan sekali.** Serahkan email dan password lewat jalur aman (bukan grup chat). CS wajib menggantinya saat login pertama.
4. **Reset password**: password lama langsung tidak berlaku; password sementara baru hanya ditampilkan sekali.
5. Menonaktifkan akun (matikan **Akun aktif**): akun langsung tidak bisa login, tiket aktifnya kembali ke antrean dengan tanda "Akun CS dinonaktifkan", dan transfer yang menunggunya dibatalkan. Lakukan di hari terakhir staf bekerja.
6. Anda tidak bisa menonaktifkan akun sendiri atau melepas peran Super Admin Anda sendiri.

#### Topik dan Quick reply

- **Topik**: **Kode** tidak bisa diubah setelah dibuat. Atur **Nama (Indonesia)**, **Nama (Inggris)**, **Skill CS**, **Prioritas default**, **Tautan bantuan (opsional)** (https ke situs bantuan resmi), urutan, dan **Tampilkan ke nasabah**.
- **Quick reply**: atur **Pintasan**, **Judul**, **Isi balasan**, dan **Bahasa**. Quick reply yang meminta OTP/PIN/password ditolak. Balasan pribadi CS tidak tampil di sini; tiap CS mengelolanya sendiri dari kotak balas.

#### Label tiket

- Klik **Tambah label**, isi **Nama label** (maksimal 30 karakter, tidak boleh sama dengan label lain) dan pilih **Warna** (abu-abu, biru, hijau, kuning, merah).
- Maksimal 50 label aktif. Label yang **dinonaktifkan** tidak bisa dipasang lagi, tetapi tetap tampil di tiket lama dan di laporan.
- Atur urutan dengan tombol panah; urutan ini dipakai di menu label pada tiket.
- Kolom **Dipakai** menunjukkan jumlah tiket yang berlabel tersebut. Setiap simpan dan perubahan urutan tercatat di Jejak Audit (dengan nilai sebelum dan sesudah).

#### Jam layanan & libur, dan Pesan otomatis

- **Jam layanan (WIB)**: atur **Buka**/**Tutup** per hari, lalu **Simpan jam layanan**. Di luar jam layanan nasabah menerima pesan otomatis.
- **Hari libur**: **Libur nasional** dan **Cuti bersama** menutup layanan CS. **Libur bursa** hanya menutup pasar; layanan CS tetap buka. Periksa kalender tahun berikutnya sebelum pergantian tahun.
- **Pesan otomatis**: ubah teks Bahasa Indonesia dan Bahasa Inggris. Variabel dalam kurung kurawal diisi otomatis; hanya variabel yang sudah ada yang boleh dipakai. Setiap pesan sistem disimpan dalam kedua bahasa, jadi nasabah dan staf melihatnya mengikuti bahasa aplikasi atau Hub yang sedang dipakai (tanggal ikut diformat sesuai bahasa). Perubahan teks berlaku untuk pesan baru; pesan yang dibuat sebelum 6 Nov 2026 tetap dalam bahasa tiketnya.

#### Penugasan, tiket & alert

- **Mode penugasan**: **Ambil tiket (default)** (CS memilih sendiri) atau **Penugasan otomatis** (sistem membagikan ke CS online yang sesuai skill dan punya slot).
- **Lepas otomatis bila pemilik offline**: default mati. Bila aktif, tiket milik CS yang offline lebih lama dari batas kembali ke antrean.
- **Tutup tiket selesai**: **Batas tanpa rating (hari, 1–30)**. Tiket yang sudah dinilai selalu langsung ditutup.
- **Alert Super Admin**: batas menit tiket belum diambil, dan batas khusus tiket P1.

#### Aturan persetujuan (empat mata)

- **Aturan empat mata**: default aktif. Postingan dan notifikasi resmi wajib disetujui staf lain, bukan pembuatnya.
- **Empat mata kebijakan konten**: default aktif. Perubahan kebijakan konten wajib disetujui staf Kepatuhan lain.
- **Risiko:** mematikan empat mata membuat satu orang bisa langsung menerbitkan ke semua pengguna. Biarkan aktif kecuali tim memang hanya satu orang, dan catat alasannya.

#### Integrasi API Nasabah

Dipakai bersama tim IT saat pemasangan. Isi **Alamat API Nasabah** dan **Client id**, lalu **Simpan & aktifkan**: koneksi dites dulu dan hanya disimpan bila berhasil. **Putuskan** langsung menyembunyikan menu Akun Nasabah untuk semua CS.

#### Integrasi aplikasi

Data koneksi untuk tim aplikasi OLT (URL API, anon key, versi library) dan **Status login OLT** bersifat hanya-baca. Anon key memang publik, bukan rahasia. Bila status bukan **Aktif**, laporkan ke IT. Kunci OLT tidak bisa diganti dari Hub.

**Skema deep link aplikasi** (terkunci, **Ubah** → **Simpan** → konfirmasi): awalan tautan yang membuka halaman di dalam aplikasi OLT dari banner atau popup, mis. `olt://promo/akhir-tahun` membuka halaman promo di aplikasi, bukan di browser. Isi sesuai skema yang didaftarkan aplikasi OLT (bawaan `olt`, maksimal 5); biasanya cukup diatur sekali oleh tim IT. Dikosongkan berarti tautan banner hanya boleh `https://`. Skema web dan skema berbahaya (javascript, data, file, intent, content, dan sejenisnya) selalu ditolak. Banner aktif yang memakai skema yang dicabut tetap tampil, tetapi tanpa tautan dan tombol. Hanya Super Admin yang bisa mengubahnya; peran Fitur & Kampanye hanya melihat daftarnya saat mengisi tautan banner.

#### API Notifikasi

API key untuk sistem lain yang mengirim push ke aplikasi (transaksi, pengumuman) atau memposting sebagai bot resmi.

1. **Buat API key**: beri **Nama key**, pilih **Izin** (**Notifikasi per rekening**, **Notifikasi massal**, **Postingan bot**), isi **IP atau CIDR yang diizinkan** dan **Batas request per menit**.
2. **Key hanya ditampilkan sekali.** Salin dan serahkan ke pemilik sistem pengirim lewat jalur aman. Jangan tempel di chat, tiket, email, atau dokumen.
3. **Notifikasi massal** bisa mengirim ke SEMUA pengguna. Berikan hanya ke sistem tepercaya dan batasi IP-nya.
4. **Rotasi:** buat key baru, pasang di sistem pengirim, pastikan **Terakhir dipakai** key baru bergerak, baru **Cabut** key lama.
5. **Cabut** bersifat permanen. Untuk berhenti sementara, matikan **Key aktif**.

#### Push notification

- Status layanan: **Aktif**, **Belum dipasang**, **Bermasalah**, atau **Layanan mati**. Bila push mati, notifikasi tetap masuk ke kotak notifikasi aplikasi.
- Kunci Firebase diunggah sebagai file JSON (**Pilih file JSON**, lalu **Simpan kunci**). Langkahnya tertulis di layar. **Setelah diunggah, hapus file JSON dari komputer Anda.** Kunci tidak bisa diunduh lagi dari Hub.
- **Hapus kunci** menghentikan push ke HP untuk semua pengguna. Jangan dilakukan tanpa koordinasi IT.
- **Kirim push uji**: cari pengguna, lalu **Kirim uji**, untuk memastikan push sampai.

#### Backup

Backup database dan file berjalan terus-menerus dan dienkripsi.

1. **Tujuan backup**: pilih **S3** (disarankan, di luar server) atau **Folder lokal di server**. Folder lokal tidak melindungi dari server rusak atau hilang; minta IT menyalinnya ke luar server secara berkala.
2. **Password enkripsi backup**: buat password panjang (minimal 16 karakter).
   - **Simpan password di luar server** (password manager perusahaan atau amplop tersegel di brankas) **sebelum** menyimpan. Centang pernyataan **Saya sudah menyimpan password ini di tempat aman; tanpa password ini backup tidak bisa dipulihkan.**
   - Password tidak pernah ditampilkan lagi dan tidak bisa diganti untuk repositori yang sudah ada.
3. **Jadwal & retensi**: jam backup penuh harian (pilih jam sepi) dan lama penyimpanan. Aktifkan **Jalankan uji restore otomatis** mingguan.
4. **Jalankan sekarang**: **Backup penuh sekarang** (misalnya sebelum update besar) dan **Uji restore sekarang**.
5. **Cek setiap minggu**: **Uji restore terakhir** berhasil. Bila **Gagal**, segera laporkan ke IT.
6. **Restore (pemulihan) dilakukan tim IT**, tidak dari Hub. Restore memundurkan data semua orang ke satu titik waktu.

#### Alert

Ke mana alert gangguan sistem dikirim.

1. **Label & tautan**: label di awal pesan alert dan **Alamat web CS**.
2. **Telegram**: ikuti langkah di layar, isi **Token bot** dan **Chat ID**, aktifkan **Kirim alert ke Telegram**, simpan.
3. **Email**: isi **Host SMTP**, **Port**, **Keamanan**, **Pengirim**, dan **Penerima**, aktifkan **Kirim alert lewat email**, simpan. Data SMTP biasanya dari IT.
4. Klik **Kirim uji Telegram** / **Kirim uji email** dan pastikan pesannya sampai. Status pengiriman tampil di bawahnya.
5. Token bot dan password SMTP tersimpan terenkripsi dan tidak bisa ditampilkan lagi. Jangan menuliskannya di tempat lain.

Halaman **Kesehatan sistem** (status layanan dan alert terbuka) tidak tampil di menu. Bila diminta IT saat gangguan, Super Admin bisa membukanya lewat alamat yang diberikan IT.

### 3.5 Fitur & Kampanye

Menu **Fitur & Kampanye** untuk Super Admin dan akun berperan **Fitur & Kampanye**: fitur sosial, kill switch, versi minimum aplikasi, serta kampanye banner dan popup untuk nasabah. Isinya dua tab; tab yang terbuka ikut tersimpan di alamat halaman, jadi tautannya bisa dibagikan ke sesama pengelola. Setiap perubahan tercatat di Jejak Audit.

| Tab | Fungsi | Kapan dipakai |
|---|---|---|
| **Fitur & versi** | Kill switch, sakelar fitur aplikasi, versi minimum | Insiden, rilis aplikasi |
| **Banner & popup** | Strip di atas atau popup di tengah aplikasi nasabah, dengan statistik tayang dan klik | Gangguan, pemeliharaan, info, promo |

#### Fitur & versi

- **Kill switch fitur sosial**: lihat bagian 6.
- **Fitur aplikasi** (klik **Ubah** dulu; setiap sakelar meminta konfirmasi, lalu **Selesai** untuk mengunci lagi): nyalakan/matikan fitur seperti **Pencarian**, **Trending**, **Simpan postingan**, **Edit postingan**, **Reaksi pesan**, **Bagikan ke chat**, **Pengaturan notifikasi**, **Analitik aplikasi**. Berlaku saat aplikasi berikutnya membaca pengaturan.
- **Versi minimum aplikasi** per platform (terkunci per baris: **Ubah** → **Simpan** → konfirmasi): pengguna versi lebih lama diminta memperbarui aplikasi. **Risiko:** pastikan versi itu sudah tersedia di toko aplikasi; bila belum, pengguna tidak bisa memakai aplikasi.

#### Banner & popup

Ada dua **Tampilan**: **Strip atas** (pengumuman singkat di bagian atas aplikasi, misalnya gangguan atau pemeliharaan) dan **Popup tengah** (kartu di tengah layar dengan latar gelap, cocok untuk promo).

1. **Tambah banner**, pilih **Tampilan**, lalu isi **Judul**, **Isi (opsional)**, **Tautan (opsional)**, **Label tombol (opsional)**, **Sasaran**, **Tingkat** (**Info**, **Peringatan**, **Kritis**), **Mulai (WIB)**, **Berakhir (WIB)**, **Platform**, versi, **Boleh ditutup pengguna**, dan **Prioritas (0–1000)**.
2. **Tautan** boleh `https://…` atau deep link aplikasi dengan skema yang diizinkan, misalnya `olt://promo/akhir-tahun` untuk membuka halaman di dalam aplikasi OLT. `http://`, `javascript:`, `intent:`, dan skema yang belum didaftarkan ditolak. **Label tombol** (maksimal 24 karakter) hanya dipakai bila ada tautan; bila kosong, aplikasi memakai label bawaan.
3. Khusus **Popup tengah**:
   - **Gambar (opsional)**: JPEG, PNG, atau WebP. Pilih **Rasio potong** **4:5 (disarankan)** atau **1:1**, geser dan perbesar gambar, lalu **Pakai gambar**. Gambar dikecilkan otomatis sampai di bawah 2 MB dan baru diunggah saat banner disimpan. **Ganti gambar** atau **Hapus gambar** bisa dilakukan kapan saja; gambar lama dibersihkan otomatis.
   - **Frekuensi**: **Sekali per pengguna**, **Sekali sehari**, atau **Setiap buka aplikasi**.
4. **Sasaran**: **Semua pengguna** atau **Pengguna baru ≤ N hari** (1–90 hari sejak profil dibuat). Pengunjung yang belum login hanya melihat banner untuk semua pengguna.
5. Periksa **Pratinjau** di sisi kanan (strip, atau ponsel kecil untuk popup), lalu simpan.
6. Daftar banner menampilkan jenis (**Strip**/**Popup**), status (**Terjadwal**, **Aktif**, **Selesai**), dan ringkasan statistik (tayang, klik, CTR). Tombol grafik di setiap baris membuka **Statistik**: tayang, klik, tutup, pengguna unik, CTR, dan rincian 7 hari terakhir. Satu pengguna dihitung paling banyak sekali per hari (WIB) untuk setiap jenis event; data disimpan 180 hari.
7. **Skema deep link**: tautan banner boleh `https://` atau deep link aplikasi dengan skema yang diizinkan (ditampilkan di bawah kolom tautan). Daftar skemanya diatur Super Admin di **Pengaturan → Integrasi → Integrasi aplikasi**.
8. Aplikasi menerima paling banyak 10 banner aktif, urut prioritas. Banner yang sudah ditutup pengguna tidak muncul lagi di perangkatnya; untuk menampilkan ulang ke semua orang, buat banner baru. Menghapus banner ikut menghapus statistik dan gambarnya.

Data koneksi untuk tim aplikasi OLT ada di **Pengaturan → Integrasi → Integrasi aplikasi** (bagian 3.4). Tautan lama berawalan `/app` otomatis dialihkan ke menu ini atau ke Pengaturan.

### 3.6 Analitik komunitas

Super Admin selalu punya tab **Analitik** di menu **Komunitas**: pengguna aktif harian (DAU, WAU, MAU), konten, retensi mingguan, **Saham paling dibahas**, dan **Dari sosial ke order**. Data ini tidak memuat teks pengguna.

## 4. Untuk Kepatuhan

Kepatuhan **mengawasi**, tidak menangani tiket. Akun Kepatuhan langsung membuka **Ringkasan**. Akses ke kasus, transkrip, dan bukti tercatat di Jejak Audit.

### 4.1 Ringkasan

- Angka: **Pengaduan aktif**, **Jatuh tempo ≤ 1 hari kerja**, **Lewat tenggat**, **Tepat waktu (30 hari)**, **Penipuan aktif**, **Belum ditinjau**.
- Daftar: **Tenggat pengaduan terdekat**, **Kasus penipuan aktif**, **Selesai, belum ditinjau**.
- **Sinyal keamanan (30 hari)**: **Laporan CS palsu** dan **Permintaan data rahasia diblokir**, dengan tabel CS yang mencoba meminta PIN, OTP, atau password. Klik **Buka di Jejak Audit** untuk detail.
- Bila ada spanduk kebijakan belum dikonfirmasi, klik **Buka Kebijakan** (bagian 4.4).

### 4.2 Kasus

Register pengaduan dan penipuan dari chat CS. Angka merah di menu **Kasus** = pengaduan lewat tenggat atau jatuh tempo ≤ 1 hari kerja.

1. Saring dengan **Jenis kasus**, **Keadaan**, **Periode tiket dibuat**, atau cari nomor tiket/nasabah. **Ekspor CSV** untuk laporan berkala.
2. Klik kasus untuk membuka detail dengan tab **Transkrip**, **Riwayat**, dan **Tinjauan**.
3. **Unduh transkrip**: sidik SHA-256 file dicatat di Jejak Audit, sehingga keaslian transkrip bisa diperiksa.
4. **Perpanjang tenggat**: hanya untuk pengaduan aktif, **satu kali**, sebelum tenggat lewat. Isi **Alasan perpanjangan** (10–500 karakter, internal). Nasabah langsung menerima pesan berisi tenggat baru.
5. **Tinjauan baru**: pilih **Putusan** (**Sesuai**, **Perlu tindak lanjut**, **Pelanggaran**), isi **Catatan tinjauan**, lalu **Simpan tinjauan**. Tinjauan tidak bisa diubah; tinjauan terbaru menjadi status kasus.

Status tenggat: **Berjalan**, **Segera jatuh tempo**, **Lewat tenggat**, **Tepat waktu**, **Terlambat**. Semua dihitung dalam hari kerja WIB.

### 4.3 Jejak Audit

Catatan semua aksi CS, Super Admin, Kepatuhan, nasabah, dan sistem. **Catatan tidak bisa diubah atau dihapus.**

- Pilih periode (**Hari ini**, **7 hari**, **30 hari**), saring **Aksi**, atau cari pelaku/tiket/nasabah.
- **Ekspor CSV** untuk pemeriksaan.
- Dipakai juga saat gangguan: melihat siapa mengubah pengaturan apa dan kapan.

### 4.4 Kebijakan

Nilai yang wajib dikonfirmasi Kepatuhan. **Super Admin tidak bisa mengubahnya.**

| Kebijakan | Arti |
|---|---|
| **Tenggat pengaduan** | Hari kerja sejak pengaduan diterima (1–20) |
| **Perpanjangan tenggat** | Hari kerja tambahan, paling banyak sekali per pengaduan (0–20; 0 = tidak bisa diperpanjang) |
| **Retensi riwayat chat** | Lama riwayat chat CS disimpan sejak tiket terakhir ditutup (5–30 tahun) |

1. Periksa nilai yang berstatus **Belum dikonfirmasi** (nilai usulan sedang dipakai).
2. Ubah bila perlu, isi **Dasar ketentuan (opsional)**, lalu **Konfirmasi nilai ini** atau **Simpan & konfirmasi**.
3. Perubahan hanya berlaku untuk pengaduan baru. Lihat **Riwayat perubahan** di bawahnya.

### 4.5 Kata terlarang

Berlaku untuk post, komentar, polling, dan chat di aplikasi nasabah. Aksi: **Sensor** (kata diganti bintang, konten tetap terkirim) atau **Blokir** (konten ditolak).

- **Tambah kata**: 2–50 karakter, huruf/angka/spasi. Huruf besar/kecil tidak berpengaruh, dan yang cocok hanya kata utuh ("penipu" tidak mengenai "penipuan").
- **Import Excel**:
  1. Klik **Unduh template**.
  2. Kolom A kata atau frasa, kolom B aksinya (**sensor** atau **blokir**; kosong = sensor). Maksimal 1.000 baris per file.
  3. Klik **Import Excel**, pilih file, periksa pratinjau (**Baru**, **Aksi berubah**, **Sudah ada**, **Duplikat**, **Tidak valid**), lalu **Import n kata**.
  4. Import tidak menghapus kata yang sudah ada; hanya menambah atau mengubah aksi.
- **Unduh Excel** untuk mengekspor daftar.
- Bila **Empat mata kebijakan konten** aktif, perubahan masuk draf dulu dan baru berlaku setelah disetujui staf Kepatuhan lain (bagian 4.6).

### 4.6 Kebijakan konten

Aturan keamanan konten komunitas. Tabnya:

| Tab | Isi |
|---|---|
| **Kategori** | Aksi per kategori (**Judi**, **Pornografi**, **Phishing & IP logger**, **Pemendek tautan**, **Grup chat & messenger**, **Nomor HP**, **Frasa promosi**, **Tautan lain**, dll.): **Izinkan**, **Sensor**, **Tahan** (ditinjau moderator), atau **Blokir**, dengan cakupan **Publik saja** atau **Publik + DM & grup**. Juga **Masa akun baru** |
| **Domain** | **Domain diblokir** (domain atau kata kunci) dan **Domain tepercaya** (selalu lolos) |
| **Frasa & pengecualian** | **Frasa promosi** dan **Istilah pengecualian** (mis. istilah wajar yang mengandung kata terlarang) |
| **Ambang gambar** | Skor classifier per kategori: **Tahan ≥** dan **Blokir ≥**. Pornografi wajib punya ambang |
| **Anti-manipulasi** | Deteksi manipulasi saham dan slow mode (bagian 4.9) |
| **Versi & persetujuan** | Draf, persetujuan empat mata, simulasi, riwayat, dan pemulihan versi |
| **Uji teks** | Cek perlakuan aturan yang berlaku terhadap sebuah teks, tanpa menyimpan apa pun |

**Alur perubahan (versi, draf, empat mata):**

1. Ubah aturan di tab mana pun atau di **Kata terlarang**. Perubahan masuk ke **Draf perubahan Anda** dan **belum berlaku**.
2. Buka tab **Versi & persetujuan**. Klik **Simulasi** → **Jalankan simulasi** untuk melihat konten nyata yang perlakuannya berubah (**Lebih ketat** / **Lebih longgar**). Simulasi tidak menyimpan apa pun.
3. Isi **Alasan perubahan**, lalu **Ajukan untuk persetujuan**. (Bila empat mata dimatikan Super Admin, tombolnya **Aktifkan sekarang**.)
4. Staf Kepatuhan **lain** membuka **Menunggu persetujuan**, membaca alasan, isi perubahan, dan hasil simulasi, lalu **Setujui** atau **Tolak** (alasan penolakan terlihat pembuat). Pengaju bisa **Tarik**.
5. Setiap perubahan yang berlaku menjadi versi bernomor baru (v1, v2, …). Versi tidak pernah dihapus.
6. **Rollback:** di **Riwayat versi**, klik **Pulihkan** pada versi lama. Pemulihan membuat versi baru dengan isi yang sama dan, bila empat mata aktif, juga harus disetujui staf lain.
7. **Buang draf** menghapus draf tanpa mengubah kebijakan yang berlaku.

### 4.7 Dokumen hukum

**Syarat & Ketentuan**, **Pedoman Komunitas**, dan **Kebijakan Privasi** yang disetujui nasabah di aplikasi.

1. **Draf baru** atau **Buat dari versi berlaku**. Isi **Judul**, **Isi dokumen**, **Yang berubah** (ringkasan untuk nasabah), dan **Tanggal berlaku (WIB)** (kosong = berlaku segera setelah disetujui). Cek **Pratinjau**.
2. **Simpan draf**, lalu **Ajukan untuk persetujuan**. Draf yang diajukan tidak bisa diubah; **Tarik kembali** dulu bila perlu.
3. Staf Kepatuhan lain **Tinjau**, lalu **Setujui & terbitkan** / **Setujui & jadwalkan**, atau **Tolak** dengan alasan. Bila hanya ada satu staf Kepatuhan aktif, ia boleh menyetujui sendiri dan Jejak Audit menandainya sebagai persetujuan sendiri.
4. Versi terjadwal bisa dibatalkan dengan **Batalkan jadwal** sebelum berlaku.
5. **Wajibkan** / **Jadikan tidak wajib**: bila dokumen wajib, setiap pengguna harus menyetujui versi baru sebelum bisa posting, berkomentar, atau chat komunitas. **Chat dengan CS tetap bisa.**

Versi yang sudah terbit tidak bisa diubah. Persentase pengguna yang sudah menyetujui tampil di halaman.

### 4.8 Bukti (karantina bukti)

Salinan utuh konten yang dilaporkan atau dihapus, disimpan untuk keperluan hukum (permintaan penyidik, OJK, sengketa). Isi dan file tidak bisa diubah; setiap akses tercatat.

- Bukti direkam otomatis dari **Laporan pengguna**, **Dihapus moderator**, **Dihapus sistem**, **Gambar dihapus**, dan **Toleransi nol**.
- Ringkasan: **Total bukti**, **Legal hold**, **Habis ≤ 30 hari**, **File menunggu disalin**, **File hilang/gagal**, **Masa simpan**. Cari dengan kode **EV-…**, ID, atau username.
- Detail bukti: isi asli, file, sidik SHA-256, laporan terkait, dan **Jejak penanganan**.
- **Periksa integritas**: memastikan isi dan file tidak berubah (**Utuh: semua sidik cocok**). Bila muncul **Ditemukan ketidaksesuaian**, laporkan segera.
- **Pasang legal hold** (alasan 10–500 karakter, mis. nomor surat permintaan penyidik): bukti tidak dihapus walau masa simpan habis. **Lepas legal hold** bila perkara selesai.
- **Ekspor paket bukti** (isi tujuan ekspor): file JSON berisi isi, sidik, dan tautan unduh file yang berlaku 1 jam. Serahkan sesuai prosedur legal.
- Super Admin hanya bisa melihat dan memeriksa; legal hold dan ekspor khusus Kepatuhan.

### 4.9 Deteksi manipulasi pasar dan slow mode

Di **Kebijakan konten → Anti-manipulasi**, Kepatuhan mengatur:

- **Lonjakan mention**, **Konsentrasi akun baru**, dan **Posting terkoordinasi**: ambang deteksi. Deteksi berjalan tiap 5 menit dari postingan yang memuat $KODE.
- **Aksi otomatis** saat alert muncul:
  - **Slow mode otomatis** di room saham yang terkena alert. Jedanya **paling ketat sama dengan jeda jam ramai** (10 detik bila jam ramai mati). Slow mode yang lebih ketat dinyalakan **manual oleh moderator** di **Komunitas → Room saham**.
  - **Tahan posting mirip** sampai alert ditinjau. Menolak alert melepasnya kembali.
- **Slow mode jam ramai**: jeda dan rentang jam ramai (WIB), hanya di hari bursa.

Alert ditinjau moderator di **Komunitas → Moderasi → Indikasi manipulasi** (bagian 5.3).

## 5. Untuk moderator Komunitas

Menu **Komunitas** mengelola stream komunitas di aplikasi nasabah. Tab yang tampil mengikuti **Izin Komunitas** Anda:

| Izin | Boleh | Tab |
|---|---|---|
| **Tulis postingan resmi** | Membuat draf postingan, pengumuman, dan notifikasi atas nama akun resmi | **Stream**, **Notifikasi** |
| **Setujui & terbitkan** | Menyetujui, menerbitkan, menjadwalkan, menyematkan, dan menghapus postingan resmi; menyetujui notifikasi | **Stream**, **Notifikasi** |
| **Moderasi konten** | Antrean laporan, konten dan gambar ditahan, indikasi manipulasi, banding konten, serta slow mode dan pin room saham | **Moderasi**, **Room saham** |
| **Sanksi pengguna** | Peringatan, bisukan, blokir, cabut sesi, banding sanksi, dan toleransi nol | **Moderasi** |
| **Kelola akun resmi** | Membuat akun resmi dan memberi badge verifikasi | **Akun resmi** |

Di atas tab ada angka: **Postingan menunggu persetujuan**, **Postingan terjadwal**, **Notifikasi menunggu persetujuan**, **Laporan terbuka**.

Semua tindakan yang meminta **Alasan** (5–500 karakter) tercatat di Jejak Audit. Tulis fakta singkat.

### 5.1 Postingan dan pengumuman resmi (tab **Stream**)

1. Klik **Buat postingan**. Pilih **Jenis**: **Postingan** atau **Pengumuman** (wajib berjudul, selalu disematkan).
2. Pilih **Akun resmi** pengirim. Tulis **Isi**; tulis **$KODE** untuk menautkan saham. Kata terlarang ditolak otomatis. Tambah gambar bila perlu.
3. **Sematkan**: **Tidak disematkan**, **Stream umum**, atau **Stream saham**, dan opsional **Sematkan sampai (WIB)**.
4. Opsional: **Kirim notifikasi saat terbit**.
5. **Waktu terbit**: **Segera setelah disetujui** atau **Jadwalkan**.
6. **Simpan draf** atau **Simpan & ajukan**.

**Menyetujui (empat mata):**

1. Saring **Perlu ditinjau**. Buka postingan.
2. Klik **Setujui & terbitkan** / **Setujui & jadwalkan**, atau **Tolak** dengan **Catatan untuk pembuat** (draf kembali ke pembuat).
3. **Pembuat tidak bisa menyetujui postingannya sendiri** (**Anda yang membuat ini, jadi persetujuannya harus dari staf lain.**).

Lainnya: **Lepas sematan**, **Sematkan lagi**, **Batalkan** (postingan tidak terbit), dan **Hapus dari stream** (hilang dari aplikasi, diarsipkan untuk audit). Bila status **Gagal terbit**, baca alasannya, perbaiki, lalu ajukan lagi.

### 5.2 Kampanye notifikasi (tab **Notifikasi**)

1. Klik **Buat notifikasi**. Isi **Judul notifikasi** dan **Isi notifikasi**. Periksa **Pratinjau** (**Tampilan di layar HP**).
2. **Saat diketuk**: **Buka kotak notifikasi**, **Buka postingan resmi**, atau **Buka tautan** (https).
3. **Segmen penerima**: **Semua pengguna**, **Pemantau saham**, **Pengguna baru**, **Pengguna tidak aktif**, **Platform**, atau **Pengikut akun resmi**. Hub menampilkan perkiraan jumlah penerima.
4. **Waktu kirim**: **Segera setelah disetujui** atau **Jadwalkan**.
5. **Simpan & ajukan**. Staf lain menyetujui dengan **Setujui & kirim**, atau **Tolak**.
6. Setelah terkirim, detail menampilkan jumlah push **terkirim**, **menunggu**, dan **gagal**.

> Notifikasi ke **Semua pengguna** sampai ke seluruh pengguna aplikasi. Periksa ejaan, tautan, dan jadwal sebelum menyetujui. Notifikasi yang sudah terkirim tidak bisa ditarik.

### 5.3 Moderasi (tab **Moderasi**)

Antrean yang tampil mengikuti izin:

| Antrean | Izin | Isi dan tindakan |
|---|---|---|
| **Laporan** | Moderasi atau Sanksi | Laporan pengguna, diurutkan menurut prioritas (jumlah laporan, jenis: penipuan dan pom-pom saham lebih berat). **Sembunyikan**, **Hapus**, **Pulihkan**, **Setujui**, atau **Abaikan** |
| **Konten ditahan** | Moderasi | Konten yang ditahan kebijakan konten atau deteksi manipulasi. **Loloskan**, **Sembunyikan**, atau **Hapus** |
| **Gambar ditahan** | Moderasi | Gambar yang skornya melewati ambang tahan, tampil buram. Klik **Tampilkan** hanya bila perlu. **Loloskan** atau **Hapus gambar** |
| **Indikasi manipulasi** | Moderasi | Alert manipulasi saham. **Tandai ditinjau** (aksi otomatis tetap berjalan) atau **Tolak alert** (bukan manipulasi: posting yang ditahan dilepas dan slow mode dari alert dimatikan) |
| **Banding** | Moderasi (banding konten) / Sanksi (banding sanksi) | Banding dari pengguna. **Terima** atau **Tolak** dengan catatan 5–1.000 karakter yang dikirim ke pengguna |

Catatan:

- **Sembunyikan**: konten tersimpan tetapi tidak tampil. **Hapus**: konten dihapus dan diarsipkan. Penulis bisa mengajukan banding.
- Bila Anda pemberi keputusan awal, banding harus ditinjau staf lain.
- Membuka **pesan pribadi** (DM) tercatat di Jejak Audit, dan hanya bisa bila pesan itu dilaporkan, ditandai sistem, atau tidak tampil.

**Sanksi (izin Sanksi pengguna):**

1. **Cari pengguna** (nama atau @username), buka **Detail pengguna**: jumlah konten, laporan, konten terbaru, dan **Riwayat sanksi**.
2. **Beri sanksi**: **Otomatis sesuai tangga sanksi**, **Peringatan**, **Bisukan 24 jam**, **Bisukan 7 hari**, **Blokir 7 hari**, atau **Blokir permanen**, dengan alasan.
3. **Cabut** sanksi bila keliru. **Keluarkan dari semua perangkat** memaksa pengguna login ulang.
4. Akun staf dan akun resmi tidak bisa diberi sanksi.

**Toleransi nol (CSAM, materi eksploitasi seksual anak):**

1. **Jangan membuka, mengunduh, meneruskan, atau menghapus materi.**
2. Di detail pengguna, klik **Toleransi nol**, isi alasan berupa fakta singkat tanpa menyalin materi, centang pernyataan, **Lanjutkan**.
3. Ketik username pengguna, lalu **Terapkan toleransi nol**. Akun diblokir permanen, semua sesi dicabut, dan semua kontennya disembunyikan sebagai bukti. Tidak bisa dibanding.
4. Segera beri tahu Kepatuhan. Pelaporan ke pihak berwenang ditentukan tim legal.

### 5.4 Room saham (tab **Room saham**, izin Moderasi konten)

1. Ketik **Kode saham** (mis. BBCA), klik **Buka**. **Status saat ini** menampilkan slow mode yang berlaku dan sumbernya (**moderator**, **alert manipulasi**, atau **jam ramai**).
2. **Slow mode moderator**: pilih **Pilihan cepat** atau isi **Jeda antarpesan (detik)** (0 mematikan slow mode dari moderator), opsional **Berlaku sampai (WIB)** (maksimal 30 hari; kosong = tanpa batas), lalu **Simpan slow mode**.
3. Slow mode yang berlaku adalah **nilai terbesar** dari pengaturan moderator, alert manipulasi, dan jam ramai. Akun resmi tidak terkena.
4. **Pesan disematkan**: pilih dari **Pilih dari pesan terbaru**, atau **Sematkan dengan ID pesan**. Satu room hanya punya satu pesan disematkan. **Lepas sematan** untuk melepasnya.
5. Bila ada alert terbuka untuk saham itu, klik **Lihat alert**.
6. **Moderator room**: cari nasabah tepercaya lalu klik **Tunjuk** untuk menjadikannya moderator room (bisa menyembunyikan pesan, membisukan anggota sementara, dan eskalasi ke staf). Pantau **Log aksi moderator**; aksi yang keliru bisa **Batalkan**. **Copot** moderator yang menyalahgunakan haknya. Syarat dan batas moderator room hanya diubah Kepatuhan atau Super Admin.

Saat jam ramai atau gangguan kapasitas, moderator bisa menyalakan slow mode di room saham yang ramai.

### 5.5 Akun resmi (tab **Akun resmi**, izin Kelola akun resmi)

- Akun atas nama perusahaan, tidak bisa login dari aplikasi, selalu tampil dengan badge **Resmi**.
- **Buat akun resmi**: **Nama tampilan**, **Username** (3–30 karakter), **Bio**, dan foto. Foto bisa diseret atau dipilih, lalu dipotong (**Atur foto akun**, **Pakai foto**). Periksa **Tampilan di aplikasi**.
- Mengganti username: mention lama tidak lagi mengarah ke akun ini.
- **Nonaktifkan**: akun tidak bisa dipakai untuk postingan atau notifikasi baru; postingan lamanya tetap tampil. **Aktifkan** untuk memakainya lagi.
- **Badge verifikasi pengguna**: **Verifikasi** atau **Cabut verifikasi** untuk analis/tokoh yang identitasnya sudah diperiksa.

## 6. Situasi darurat

### 6.1 Kill switch fitur sosial

**Siapa:** **Super Admin** atau akun berperan **Fitur & Kampanye**, di **Fitur & Kampanye → Fitur & versi → Kill switch fitur sosial**.

**Kapan:** insiden besar seperti spam masif, konten berbahaya yang menyebar, atau gangguan yang belum dipahami dan butuh waktu untuk diperbaiki.

**Akibatnya:**

- Postingan, komentar, edit, dan pesan chat non-CS baru ditolak untuk **semua pengguna di semua platform**.
- Membaca, like, follow, dan reaksi tetap jalan.
- **Chat CS dengan nasabah tidak terpengaruh.**
- Postingan staf, akun resmi, dan bot tetap bisa terbit.

**Langkah:**

1. Klik **Matikan fitur sosial**.
2. Isi **Alasan** (10–500 karakter; terlihat oleh Super Admin lain).
3. Ketik **MATIKAN**, lalu klik tombolnya. Hub menampilkan konfirmasi terakhir berisi dampak dan alasannya; konfirmasi untuk menerapkan.
4. Beri tahu tim CS, Kepatuhan, dan IT bahwa kill switch aktif. Pertimbangkan **Fitur & Kampanye → Banner & popup** untuk memberi tahu pengguna.
5. Setelah masalah beres: **Nyalakan kembali**, isi alasan, ketik **NYALAKAN**, lalu konfirmasi.

Jangan lupa menyalakan kembali; kill switch tidak mati sendiri.

### 6.2 Eskalasi

| Gejala | Yang dilakukan staf |
|---|---|
| Satu-dua nasabah tidak bisa kirim pesan | Biasanya aturan yang bekerja (slow mode, filter konten, dibisukan, versi aplikasi lama). Minta tangkapan layar pesan error, cek di menu terkait |
| Banyak nasabah/semua staf terganggu (chat tidak terkirim, tidak muncul, tidak bisa login) | Segera lapor ke **IT/operasional**. IT mengikuti `docs/runbook-gangguan.md` |
| Indikator Hub **Menyambung ulang…** terus | Periksa jaringan Anda; bila staf lain juga, lapor ke IT |
| Spam masif atau konten berbahaya | Moderator: tindak di **Moderasi**, slow mode di **Room saham**. Super Admin: pertimbangkan kill switch |
| Alert backup gagal | Super Admin: cek **Pengaturan → Backup**, lapor ke IT |
| Laporan CS palsu berulang | Super Admin dan Kepatuhan: pantau **Ringkasan**, koordinasi dengan legal |

**Data untuk dilaporkan ke IT:** jam kejadian dan sejak kapan, satu contoh akun yang terkena, tangkapan layar pesan error, dan menu yang dipakai. Kirim lewat kanal resmi kantor; jangan sertakan data pribadi nasabah di grup umum.

### 6.3 Yang tidak boleh dilakukan

- Jangan meminta tim IT melakukan **restore backup** untuk masalah yang bukan kerusakan data. Restore memundurkan data semua orang.
- Jangan mengubah banyak pengaturan sekaligus saat panik. Ubah satu, catat, amati.
- Jangan **Hapus kunci** Firebase, **Putuskan** integrasi API Nasabah, atau **Cabut** API key tanpa koordinasi IT.
- Jangan mematikan **Aturan empat mata** untuk mempercepat penerbitan saat insiden.
- Jangan membuka, mengunduh, atau meneruskan materi CSAM.
- Jangan membagikan password, password sementara, API key, token bot, atau password backup lewat chat atau email.
- Setelah gangguan selesai: nyalakan kembali kill switch, matikan slow mode darurat, dan hapus banner gangguan.

## 7. Glosarium

| Istilah | Arti |
|---|---|
| **Tiket** | Satu percakapan layanan nasabah, bernomor `CS-YYYYMMDD-NNNN` |
| **Ambil / klaim** | CS mengambil tiket dari antrean **Terbuka** menjadi miliknya |
| **Antrean** | Daftar tiket **Terbuka** yang belum diambil |
| **P1–P4** | Prioritas tiket. P1 paling mendesak (mis. fraud), P4 paling rendah |
| **Tanda** | Label tiket: **Pengaduan**, **Fraud**, **VIP** |
| **Batas tiket aktif** | Jumlah maksimal tiket yang boleh ditangani CS bersamaan |
| **Transfer** | Menyerahkan tiket ke CS lain; berpindah setelah CS tujuan menerima |
| **Lepas** | Mengembalikan tiket ke antrean dengan alasan |
| **Pindahkan** | Super Admin memindahkan tiket langsung ke CS lain |
| **Selesai** | CS menyelesaikan tiket; menunggu rating nasabah |
| **Ditutup** | Tiket berakhir (setelah rating, tutup otomatis, atau diakhiri nasabah); tidak bisa dibalas |
| **Tutup otomatis** | Tiket selesai yang tidak dinilai ditutup setelah N hari |
| **Catatan internal** | Catatan antar-staf; tidak pernah terlihat nasabah |
| **Balasan cepat / Quick reply** | Jawaban siap pakai, dipanggil dengan **/** |
| **Mode pantau** | Cara kerja Super Admin di **Layanan Nasabah**: melihat tanpa membalas |
| **Pengaduan** | Keluhan resmi nasabah dengan tenggat hari kerja |
| **Hari kerja** | Senin–Jumat yang tidak tercatat sebagai hari libur di kalender layanan (WIB) |
| **Empat mata** | Perubahan atau terbitan wajib disetujui staf lain, bukan pembuatnya |
| **Draf** | Perubahan yang disimpan tetapi belum berlaku |
| **Simulasi** | Uji draf kebijakan terhadap konten nyata tanpa menyimpan apa pun |
| **Slow mode** | Jeda wajib antarpesan di room saham |
| **Jam ramai** | Rentang jam di hari bursa dengan slow mode otomatis |
| **Room saham** | Ruang diskusi per kode saham di aplikasi |
| **Akun resmi** | Akun perusahaan berbadge **Resmi**, tidak bisa login dari aplikasi |
| **Banding** | Permintaan pengguna agar sanksi atau penindakan konten ditinjau ulang |
| **Toleransi nol** | Tindakan permanen untuk CSAM: blokir, cabut sesi, sembunyikan konten |
| **Kill switch** | Sakelar darurat untuk mematikan fitur sosial bagi semua pengguna |
| **Legal hold** | Penanda agar bukti tidak dihapus walau masa simpannya habis |
| **Sidik (SHA-256)** | "Sidik jari" file atau isi; bila isi berubah, sidiknya berubah |
| **Jejak Audit** | Catatan permanen semua aksi di Hub |
| **Push** | Notifikasi yang muncul di layar HP pengguna |

## 8. FAQ

#### Saya tidak bisa mengambil tiket.

Periksa status: harus **Online**. Periksa juga **Aktif n/maks**; bila penuh, selesaikan atau lepas tiket dulu.

#### Kotak balas terkunci.

Status Anda **Offline**, atau Anda bukan pemilik tiket. Klik **Ubah ke Online**, atau **Ambil** tiketnya.

#### Pesan saya ditahan.

Kalimat Anda terbaca sebagai meminta OTP, PIN, password, atau nomor kartu. Ubah kalimatnya. Contoh aman: "Mohon jangan bagikan OTP atau PIN kepada siapa pun, termasuk CS."

#### Nasabah bilang tidak bisa membalas di tiket lama.

Tiket itu sudah ditutup. Nasabah membuat tiket baru dari aplikasi.

#### Tiket saya dipindah ke CS lain.

Super Admin bisa memindahkan tiket, biasanya karena Anda offline. Pemindahan tercatat di audit.

#### Menu yang saya butuhkan tidak muncul.

Menu mengikuti peran dan izin. Minta Super Admin memeriksa akun Anda di **Pengaturan → Akun CS**. Perubahan izin Akun Nasabah berlaku tanpa login ulang.

#### Saya lupa password.

Minta Super Admin melakukan **Reset password**. Ganti password sementara saat login berikutnya.

#### Notifikasi atau suara tiket baru tidak muncul.

Klik ikon lonceng: pastikan **Notifikasi tiket baru** tidak **Mati**, klik **Izinkan notifikasi browser**, lalu **Tes suara**.

#### Apakah nasabah bisa melihat catatan internal atau ringkasan penyelesaian?

Tidak. Keduanya hanya untuk staf.

#### Bolehkah Super Admin membalas nasabah?

Tidak. Super Admin memantau, menulis catatan internal, mengubah prioritas, dan memindahkan tiket.

#### Kepatuhan perlu memperpanjang tenggat pengaduan untuk kedua kalinya.

Tidak bisa. Perpanjangan hanya sekali per pengaduan dan harus sebelum tenggat lewat.

#### Perubahan kata terlarang saya belum berlaku.

Perubahan masuk draf dulu. Ajukan di **Kebijakan konten → Versi & persetujuan** dan minta staf Kepatuhan lain menyetujui.

#### Postingan resmi saya tidak bisa saya setujui sendiri.

Itu aturan empat mata. Minta staf lain dengan izin **Setujui & terbitkan**.
