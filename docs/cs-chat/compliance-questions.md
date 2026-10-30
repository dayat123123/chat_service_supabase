# Pertanyaan untuk Tim Kepatuhan & Legal: CS lewat Chat

> **Untuk:** tim kepatuhan (compliance) dan legal sekuritas.
> **Dari:** tim pengembang OLT.
> **Dasar:** [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) bagian 1, 2, 4, dan 6.

Customer service OLT dibangun sebagai chat dua arah di dalam aplikasi, tanpa sistem tiket. Daftar ini lebih pendek dari versi ticketing yang dibatalkan, karena surat resmi, penomoran tiket, dan alur keberatan tidak lagi dibangun.

**Cara menjawab:**
- Setiap pertanyaan memuat **usulan kami**. Usulan itu sudah dipakai sebagai pengaturan (`cs_settings`) dan bisa diubah tanpa mengubah program. Cukup jawab "setuju", atau tuliskan aturan yang benar beserta rujukannya.
- Chat CS **tidak dibuka untuk nasabah** sebelum semua pertanyaan terjawab.

## A. Pengaduan lewat chat

| No | Pertanyaan | Usulan (dipakai sekarang) | Dibutuhkan |
|---|---|---|---|
| A1 | Apakah pengaduan lewat chat termasuk pengaduan **lisan** (5 hari kerja) atau **tertulis** (10 hari kerja)? | Lisan, 5 hari kerja (`complaint.days`) | Sebelum peluncuran |
| A2 | Kapan pengaduan dianggap **diterima**: saat nasabah menekan "Saya ingin mengajukan pengaduan", atau saat agen menandai sesi sebagai pengaduan? | Saat sesi ditandai pengaduan (oleh nasabah atau agen), memakai waktu server. Nasabah langsung mendapat pesan berisi waktu diterima dan tenggatnya | Sebelum peluncuran |
| A3 | Definisi **hari kerja**: apakah libur bursa ikut dikecualikan? Apakah Sabtu dihitung bila CS buka? | Senin–Jumat, kecuali libur nasional, cuti bersama, dan libur bursa. Sabtu tidak dihitung walaupun CS buka | Sebelum peluncuran |
| A4 | **Hari pertama**: apakah hari penerimaan dihitung hari ke-0? Bagaimana pengaduan di luar hari kerja? | Hari penerimaan = hari ke-0. Pengaduan di luar hari kerja dianggap diterima hari kerja berikutnya. Tenggat jatuh pukul 23.59 WIB hari kerja ke-N. Semua dalam WIB | Sebelum peluncuran |
| A5 | **Perpanjangan** tenggat: kondisi apa yang membolehkan, berapa kali, dan bagaimana memberitahukannya lewat chat? | Maksimal 1 kali, 10 hari kerja, diberitahukan lewat pesan sistem di chat (dibangun di CS5) | Sebelum CS5 |
| A6 | Apakah **transkrip chat** yang diekspor ke PDF bernomor sah sebagai catatan pengaduan? Perlu bukti integritas tambahan? | Ya. Pesan CS tidak bisa diedit atau dihapus nasabah, log kejadian sesi tidak bisa diubah, dan PDF memuat sidik digital (hash) | Sebelum CS5 |

## B. Data, penyamaran, dan retensi

| No | Pertanyaan | Usulan (dipakai sekarang) | Dibutuhkan |
|---|---|---|---|
| B1 | OTP, PIN, password, nomor kartu, NIK, dan nomor rekening yang terketik di chat **disamarkan sebelum disimpan**, sehingga nilai aslinya tidak pernah tersimpan. Apakah ini dapat diterima, atau ada kewajiban menyimpan pesan asli? | Hanya versi tersamar yang disimpan, beserta catatan jenis data yang disamarkan | Sebelum peluncuran |
| B2 | Data apa yang wajib disamarkan di **panel agen**, dan alasan apa yang sah untuk membukanya? | NIK, rekening, email, HP, SID, alamat, dan tanggal lahir disamarkan. Membuka satu field berlaku 5 menit, wajib memilih alasan (verifikasi identitas, koreksi data, investigasi penipuan, permintaan regulator), dan tercatat di audit log | Sebelum CS4 |
| B3 | **Retensi** riwayat chat CS: berapa tahun, dan dihitung sejak kapan? | 10 tahun sejak sesi terakhir ditutup (`retention.chat_years`) | Sebelum peluncuran |
| B4 | Saat nasabah **menghapus akun**, apakah riwayat chat CS boleh tetap disimpan? Siapa yang boleh membukanya? | Riwayat chat CS tetap disimpan utuh (sudah berlaku). Setelah akun dihapus, hanya supervisor dan kepatuhan yang bisa membukanya | Sebelum peluncuran |
| B5 | Bolehkah **notifikasi push** memuat potongan balasan CS? Server push Android (FCM) berada di luar negeri | Notifikasi hanya berisi teks umum ("Ada balasan dari CS OLT"). Potongan pesan hanya tampil di dalam aplikasi | Sebelum CS3 |
| B6 | **Akses agen ke riwayat** nasabah: hanya selama menangani, atau seluruh riwayat yang pernah ia tangani? | Agen membaca seluruh riwayat room nasabah **selama** menangani sesinya, dan sampai 24 jam setelah sesi yang ia tangani ditutup (`agent.history_hours`). Akses dicabut saat sesi ditransfer. Supervisor membaca semua; kepatuhan membaca sesi berflag pengaduan/fraud | Sebelum CS4 |

## C. Identitas, keamanan, dan kanal resmi

| No | Pertanyaan | Usulan (dipakai sekarang) | Dibutuhkan |
|---|---|---|---|
| C1 | **Identitas agen** di chat: nama asli atau nama panggilan? | Nama panggilan + kode agen (mis. "Rina – CS Resmi", CS-0007) | Sebelum CS3 |
| C2 | Persetujuan **teks pengingat keamanan** di awal setiap sesi | *"CS kami tidak pernah meminta PIN, password, atau OTP."* | Sebelum CS3 |
| C3 | Permintaan apa yang wajib **konfirmasi identitas** di aplikasi OLT (PIN/biometrik diproses OLT)? Berapa lama permintaan berlaku? | Perubahan data pribadi, perubahan rekening bank, reset akses, membuka blokir akun. Berlaku 10 menit | Sebelum CS4 |
| C4 | **"Amankan akun"** untuk laporan peretasan: tindakan apa yang boleh dilakukan agen, siapa yang membuka kunci, dan apakah wajib pemberitahuan tertulis? | Keluarkan semua sesi + kunci transaksi sementara (`secure_account.actions`). Nasabah diberi tahu lewat pesan di chat | Sebelum CS4 |
| C5 | **Daftar kontak resmi** yang ditampilkan di aplikasi (email, call center, WhatsApp resmi, media sosial, situs) | Belum diisi | Sebelum CS3 |
| C6 | **Jam layanan** CS chat. Apakah penerimaan pengaduan tetap 24 jam? | Senin–Jumat 08.00–22.00 WIB, Sabtu–Minggu 09.00–18.00 WIB, tutup saat libur nasional dan cuti bersama. Di luar jam layanan nasabah tetap bisa mengirim pesan dan pengaduan tetap tercatat | Sebelum CS3 |
| C7 | **Rate limit** nasabah: 30 pesan/menit dan 5 sesi baru/jam. Apakah ada keberatan, misalnya untuk nasabah yang sedang mengalami penipuan? | Nilai di samping. Nasabah yang di-ban dari fitur sosial tetap bisa chat CS | Sebelum CS3 |
