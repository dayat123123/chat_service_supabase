# Business Requirements Document (BRD) Sistem Rendezvous

## 1. Informasi dokumen

| Butir | Isi |
|---|---|
| Judul | Business Requirements Document (BRD) Sistem Rendezvous: lapisan sosial dan layanan nasabah di aplikasi OLT |
| Versi | 1.0 |
| Tanggal | 23 November 2026 |
| Status | Draf |
| Pemilik dokumen | `[Nama pemilik produk]` |
| Penyusun | `[Nama penyusun]` |
| Dokumen terkait | [srs.md](srs.md) (Software Requirements Specification, rincian teknis), [daftar-fitur.md](../panduan/daftar-fitur.md), [pengetahuan-sistem.md](../panduan/pengetahuan-sistem.md), [hub-untuk-staf.md](../panduan/hub-untuk-staf.md) |
| Kondisi sistem yang diacu | Migrasi database sampai `0188`, library `rendezvous_community` v1.49.2, Rendezvous Hub per 22 November 2026 |

### 1.1 Riwayat revisi

| Versi | Tanggal | Penulis | Perubahan |
|---|---|---|---|
| 1.0 | 23 November 2026 | `[Nama penyusun]` | Draf pertama: kebutuhan bisnis seluruh modul, aturan bisnis, kepatuhan, risiko, dan status implementasi |

### 1.2 Cara membaca dokumen ini

- **Kebutuhan bisnis** diberi kode `BR-<MODUL>-<nn>` (bagian 9). SRS ([srs.md](srs.md)) menelusuri setiap kebutuhan fungsionalnya ke kode ini.
- **Aturan bisnis** diberi kode `ATR-<nn>` (bagian 10). Angka di aturan adalah nilai bawaan yang berlaku di kode saat dokumen ini ditulis; sebagian bisa diubah dari Hub.
- **Prioritas** memakai MoSCoW: **M** (Must, wajib), **S** (Should, sebaiknya), **C** (Could, bila sempat), **W** (Won't, tidak di rilis ini).
- **Status**:

  | Status | Arti |
  |---|---|
  | **Terpasang** | Sudah ada di kode server, Hub, dan/atau library, dan sudah dipasang di server uji. Produksi belum go-live, jadi "terpasang" belum berarti dipakai nasabah sungguhan |
  | **Dijeda** | Kode sudah ada tetapi fitur sengaja dimatikan |
  | **Rencana** | Belum ada kode, atau baru berupa kerangka |

- Angka target di bagian KPI berlabel **usulan** dan belum pernah diukur di produksi.

## 2. Ringkasan eksekutif

Rendezvous adalah lapisan **komunitas sosial** dan **layanan nasabah** yang menempel di aplikasi trading OLT milik perusahaan sekuritas. Nasabah memakainya tanpa login terpisah: aplikasi OLT menerbitkan token sosial bertanda tangan, dan server Rendezvous memverifikasinya sendiri.

Sistem terdiri dari tiga bagian yang dikembangkan tim Rendezvous:

| Bagian | Fungsi bisnis |
|---|---|
| **Server sosial** (self-hosted, Docker) | Menyimpan dan menegakkan semua aturan bisnis: siapa boleh melihat apa, alur tiket CS, moderasi, batas kecepatan, retensi, dan audit |
| **Rendezvous Hub** (web staf) | Tempat staf CS, Super Admin, Kepatuhan, Komunitas, Pusat Bantuan, serta Fitur & Banner bekerja dan mengatur sistem |
| **Library Flutter `rendezvous_community`** | Semua layar sosial dan layanan nasabah yang dipasang tim aplikasi OLT di aplikasinya (Windows, web, Android, iOS) |

Nilai bisnis utama:

1. **Komunitas yang terawasi di dalam aplikasi sendiri.** Diskusi saham (`$KODE`), feed, chat, dan room saham berlangsung di kanal resmi perusahaan, dengan moderasi, anti-manipulasi pasar, dan jejak bukti untuk regulator.
2. **Layanan nasabah lewat chat** dengan model tiket yang diklaim agen, tenggat pengaduan hari kerja, rating yang menutup tiket, serta laporan per nasabah dan per agen.
3. **Pusat Bantuan** yang mengurangi tiket: artikel FAQ dua bahasa, saran artikel sebelum chat, dan statistik "tercegah".
4. **Satu kanal notifikasi** ke nasabah: notifikasi komunitas, notifikasi transaksi dari OLT, kampanye, serta banner dan popup, semuanya lewat satu jalur push.
5. **Kendali dan kepatuhan**: semua perubahan pengaturan tercatat di Jejak Audit, perubahan kebijakan konten butuh persetujuan empat mata, 2FA wajib untuk Super Admin, dan data bisnis trading tetap milik OLT.

Status per 23 November 2026: hampir semua kebutuhan sudah **Terpasang** di server uji; fitur **Berbagi Trade** **Dijeda**; profil server **cluster** dan **SDK native non-Flutter** masih **Rencana**. Produksi belum go-live dan mengikuti [checklist-go-live.md](../panduan/checklist-go-live.md).

## 3. Latar belakang dan masalah bisnis

### 3.1 Latar belakang

Perusahaan sekuritas pemilik OLT ingin nasabah berdiskusi, bertanya ke CS, dan menerima informasi di dalam aplikasi OLT sendiri. Beberapa prinsip ditetapkan sejak awal dan menjadi batas desain:

1. **Data bisnis trading tetap milik OLT.** Harga, order, mutasi dana, dan portofolio tidak disimpan di server sosial. Server hanya menyimpan kode saham sebagai label.
2. **Server sosial tidak memanggil OLT untuk login.** Keputusan 31 Oktober 2026: OLT menerbitkan token sosial bertanda tangan, dan auth-bridge memverifikasinya dengan kunci publik OLT (JWKS). Bila OLT lambat atau mati, sesi sosial yang sudah berjalan tetap jalan.
3. **Logika bisnis di database.** Aturan ditegakkan Postgres (fungsi SQL dan RLS), sehingga berlaku untuk semua klien.
4. **Self-hosted.** Tidak ada layanan cloud wajib. Yang keluar ke internet hanya push FCM, alert, backup S3, dan pembaruan signature antivirus.
5. **Pengaturan lewat Hub, bukan file.** Kredensial dan pengaturan operasional diatur Super Admin dari Hub dan tercatat di Jejak Audit.

### 3.2 Masalah bisnis yang dijawab

> Belum ada dokumen as-is resmi. Daftar di bawah disusun dari keputusan dan riwayat yang tercatat di repo, dan perlu divalidasi pemilik produk.

| No | Masalah | Dampak bila tidak ditangani | Jawaban Rendezvous |
|---|---|---|---|
| M1 | Diskusi saham nasabah tidak punya kanal resmi yang diawasi perusahaan | Risiko pom-pom saham, penipuan "grup VIP", dan konten ilegal tanpa jejak; reputasi dan kepatuhan pasar modal | Komunitas di aplikasi dengan moderasi, anti-manipulasi, kata terlarang, dan karantina bukti |
| M2 | Layanan nasabah butuh kanal chat yang tercatat, dengan tenggat pengaduan | Pengaduan tanpa tenggat terukur, sulit diaudit Kepatuhan | Chat CS bermodel tiket, tenggat hari kerja, register kasus, transkrip bersidik |
| M3 | Nasabah yang tidak bisa login tidak punya jalan mengadu dari aplikasi | Nasabah terkunci harus menelepon atau datang ke kantor | Pengaduan tamu dari halaman login tanpa sesi dan tanpa OTP |
| M4 | Pertanyaan berulang membebani CS | Antrean panjang, biaya layanan naik | Pusat Bantuan, saran artikel sebelum chat, statistik "tercegah" |
| M5 | Sistem notifikasi OLT harus mengurus perangkat, token FCM, dan OAuth Google sendiri | Duplikasi pekerjaan, data perangkat tersebar | API integrasi: notifEngine cukup mengirim `cust_id` dan isi pesan |
| M6 | Pengelolaan Online ID nasabah ada di aplikasi csAdmin lama yang terpisah | Staf berpindah aplikasi, aksi tidak tercatat terpadu | Menu Akun Nasabah di Hub lewat gateway, dengan izin rinci dan audit |
| M7 | Promosi dan pengumuman butuh kanal di dalam aplikasi tanpa iklan pihak ketiga | Ketergantungan pihak ketiga, privasi | Banner & Popup, kampanye notifikasi, notifikasi info |
| M8 | Konfigurasi dan rahasia operasional sering tersimpan di file server | Perubahan tanpa jejak, sulit diaudit | Pengaturan di Hub, rahasia di Vault, semua perubahan tercatat |

## 4. Tujuan bisnis dan ukuran keberhasilan (KPI)

### 4.1 Tujuan bisnis

| ID | Tujuan |
|---|---|
| TB-1 | Menyediakan komunitas saham resmi yang aman dan patuh di dalam aplikasi OLT |
| TB-2 | Menangani pertanyaan dan pengaduan nasabah lewat chat dengan waktu respons dan tenggat yang terukur |
| TB-3 | Mengurangi beban CS lewat swalayan (Pusat Bantuan) |
| TB-4 | Menyatukan kanal notifikasi dan promosi ke nasabah |
| TB-5 | Memberi Kepatuhan kendali dan bukti: audit, kebijakan berversi, karantina bukti, retensi |
| TB-6 | Menjalankan sistem secara mandiri (self-hosted) dengan ketersediaan, backup, dan pemulihan yang terukur |
| TB-7 | Tidak menambah ketergantungan teknis ke sistem OLT selain token sosial dan API integrasi yang dipanggil OLT |

### 4.2 KPI

Semua target di tabel ini **usulan** dan belum diukur di produksi. Sumber angka sudah tersedia di sistem (kolom "Sumber data").

| KPI | Definisi | Target (usulan) | Sumber data |
|---|---|---|---|
| Adopsi komunitas | MAU komunitas dibanding nasabah aktif OLT | `[X]%` dalam 6 bulan setelah go-live | Hub → Komunitas → Analitik (DAU/WAU/MAU) |
| Kelekatan | DAU/MAU (stickiness) | ≥ 20% | Analitik `stickiness_pct` |
| Retensi pengguna baru | Kohort mingguan aktif di minggu ke-4 | ≥ 25% | Analitik retensi mingguan |
| Sosial ke order | Pengguna yang mengetuk order dari sosial dibanding yang mengetuk saham | ≥ 5% | Analitik "Dari sosial ke order" |
| Waktu sampai diambil | Median tiket dari dibuat sampai diklaim, jam layanan | ≤ 2 menit | Hub → Laporan |
| Respons pertama CS | Median sejak diambil sampai balasan pertama | ≤ 1 menit | Hub → Laporan, Kinerja saya |
| Rating CS | Rata-rata rating tiket | ≥ 4,5 dari 5 | Hub → Laporan |
| Ketepatan tenggat pengaduan | Pengaduan selesai sebelum tenggat (30 hari) | 100% | Kepatuhan → Ringkasan "Tepat waktu (30 hari)" |
| Tiket tercegah | Pembaca artikel yang tidak membuat tiket dalam 24 jam | ≥ 60% | Laporan bantuan |
| Artikel membantu | Persen "Ya" pada "Apakah ini membantu?" | ≥ 75% | Pusat Bantuan → Artikel bantuan |
| Pencarian tanpa hasil | Persen pencarian FAQ tanpa hasil | ≤ 10% | Pencarian tanpa hasil (30 hari) |
| Waktu tindak laporan | Median laporan pengguna sampai diputus moderator | ≤ 4 jam di hari kerja | Komunitas → Moderasi, Jejak Audit |
| Ketersediaan API | Persen waktu layanan inti sehat | ≥ 99,5% per bulan | Kesehatan sistem, pemantau uptime eksternal |
| Keberhasilan push | Push terkirim dibanding diantrekan (tanpa token mati) | ≥ 98% | Pengaturan → Push notification, statistik integrasi |
| Uji restore | Uji restore mingguan berhasil | 100% minggu | Pengaturan → Sistem → Backup |
| RPO / RTO | Data yang mungkin hilang / lama pemulihan | RPO ≤ 5 menit, RTO ≤ 1 jam (target desain di [docs/backup](../backup/README.md)) | Backup, uji restore |

**Hasil uji yang sudah tercatat** (lingkungan dev, bukan produksi; [docs/testing](../testing/README.md), [laporan 3–4 Nov](../testing/report-2026-11-03.md)):

- API REST, RPC, auth-bridge, dan PgBouncer: p95 di bawah 25 ms, error 0% sampai 400 VU.
- Pengiriman realtime: 100% sampai lewat Realtime hingga 400 penerima satu room setelah perbaikan `0098`. Batas praktis stack `single` saat itu: satu room saham dengan ±450 nasabah aktif mengobrol (±25 pesan/detik).
- 1.042 probe otorisasi tanpa kebocoran data antar-nasabah, antar-peran, atau dari anon.
- 9 eksperimen chaos pulih sendiri tanpa tindakan manual.

## 5. Ruang lingkup

### 5.1 Dalam lingkup (rilis ini)

| Area | Isi |
|---|---|
| Akun & privasi | Login lewat token OLT, profil sosial, privasi DM, pengaturan mention, blokir, bisukan, hapus akun dan bergabung lagi, unduh data |
| Komunitas | Stream, postingan, polling, komentar dan kontrol komentar, suka, ikuti, akun resmi, pengumuman, Tab Stream, feed indeks dan instrumen, trending, sentimen, pencarian, bookmark, bagikan ke chat, Share P/L sebagai gambar |
| Chat | DM, grup dan kelola grup, room saham, permintaan pesan, edit/sembunyikan/hapus, tanda terima, mengetik, lampiran gambar, kartu saham |
| Layanan nasabah (CS) | Tiket, topik, antrean dan klaim, transfer, lampiran dokumen/video, pengaduan resmi, laporan CS palsu, pengaduan tamu, rating dan survei, transkrip, label, SOP, di luar jam layanan |
| Pusat Bantuan | Artikel FAQ dua bahasa dengan gambar dan lampiran, pencarian, umpan balik, saran per topik, status gangguan |
| Notifikasi | In-app, push FCM, preferensi dan jam tenang, notifikasi transaksi OLT, siaran, target alert harga, kampanye, Banner & Popup, notifikasi info |
| Moderasi & keamanan konten | Kata terlarang, kategori tautan/kontak, NSFW, antivirus, masa akun baru, anti-manipulasi, laporan, sanksi, banding, toleransi nol, karantina bukti |
| Kepatuhan | Ringkasan, kasus, Jejak Audit, kebijakan konten berversi dengan empat mata, tenggat & retensi, dokumen hukum dan persetujuan |
| Hub | Akun staf dan peran, 2FA dan kunci akun, pengaturan, fitur dan versi minimum, kill switch, dashboard, laporan, analitik, Akun Nasabah |
| Integrasi | Token sosial, API integrasi (notifikasi dan bot), nasabah-gateway, library Flutter, spesifikasi OpenAPI/AsyncAPI |
| Operasional | Monitoring dan alert, peta layanan, healer, backup dan restore, janitor, deploy dan update, profil `single` produksi |

### 5.2 Di luar lingkup

| Butir | Alasan |
|---|---|
| Data trading (harga, order book, order, mutasi dana, portofolio) | Milik OLT. Ditampilkan aplikasi OLT, bukan server sosial |
| Aksi akun trading dari chat (suspend, logout paksa, kartu order di chat CS) | Dihapus 31 Oktober 2026 (`0037`). Aksi akun lewat back-office OLT atau menu Akun Nasabah |
| Telepon CS ke nasabah | Fitur dikeluarkan dari kebutuhan |
| Sistem user management C++ terpisah | Dibatalkan |
| Klien non-Flutter berbasis WebView atau iframe | Ditolak |
| Database terkelola penyedia cloud (managed DB) | Tidak didukung: sistem memakai role, ekstensi, dan Vault milik image Supabase |
| Iklan pihak ketiga | Promosi hanya lewat Banner & Popup dan kampanye notifikasi |
| Order otomatis atau copy trade | Mendekati jasa nasihat atau pengelolaan investasi yang butuh izin khusus |
| Reset password staf mandiri lewat email | Reset hanya oleh Super Admin |

### 5.3 Lingkup masa depan

| Butir | Status | Catatan |
|---|---|---|
| Berbagi Trade | Dijeda | Kode ada (`0160`–`0167`, `services/trade-relay`), menu Hub disembunyikan, relay tidak ikut `make up`. Diaktifkan lagi hanya atas keputusan bisnis |
| Profil server `cluster` (Docker Swarm, banyak node) | Rencana (kerangka) | Dilengkapi dan diuji di Tahap 7 |
| SDK headless Kotlin Multiplatform (Android/iOS native) dan TypeScript | Rencana | Status diskusi, belum ada kode ([rencana](../sdk-mobile/rencana.md)) |
| Kanal pelaporan CSAM ke pihak berwenang | Rencana | Ditentukan tim legal sebelum produksi |

## 6. Pemangku kepentingan

### 6.1 Daftar pemangku kepentingan

| Pemangku kepentingan | Peran dan kepentingan |
|---|---|
| Manajemen | Sponsor, menyetujui lingkup, prioritas, anggaran, dan go-live |
| Kepatuhan | Kebijakan konten, dokumen hukum, tenggat pengaduan, retensi, pengawasan kasus, bukti untuk regulator |
| Tim CS (termasuk Supervisor/Super Admin operasional CS) | Melayani tiket; Super Admin memantau, mengelola akun staf dan pengaturan |
| Tim Komunitas | Postingan dan pengumuman resmi, kampanye notifikasi, moderasi dan sanksi, akun resmi, room saham |
| Tim Pusat Bantuan | Topik chat CS, artikel FAQ, SOP, saran balasan |
| Tim IT / vendor | Pemasangan server, update, backup, monitoring, penanganan gangguan, pengembangan Rendezvous |
| Tim backend OLT | Menerbitkan token sosial, menyerahkan JWKS, notifEngine, csAdmin |
| Tim aplikasi OLT | Memasang library, `tokenProvider`, data saham, push, rilis aplikasi |
| Nasabah | Pengguna akhir komunitas, chat, CS, dan Pusat Bantuan |

### 6.2 RACI

R = Responsible (mengerjakan), A = Accountable (memutuskan), C = Consulted (dimintai pendapat), I = Informed (diberi tahu).

| Aktivitas | Manajemen | Kepatuhan | Tim CS | Tim Komunitas | Tim Pusat Bantuan | IT/vendor | Backend OLT | Aplikasi OLT | Nasabah |
|---|---|---|---|---|---|---|---|---|---|
| Lingkup dan prioritas kebutuhan | A | C | C | C | C | R | C | C | I |
| Kebijakan konten dan kata terlarang | I | A/R | I | C | – | C | – | I | I |
| Dokumen hukum (S&K, Pedoman, Privasi) | C | A/R | I | I | I | C | – | I | I |
| Tenggat pengaduan dan retensi | C | A/R | I | – | – | C | – | – | I |
| Operasional tiket harian | I | I | A/R | – | C | – | – | – | C |
| Akun staf, peran, 2FA | I | C | A/R (Super Admin) | I | I | C | – | – | – |
| Postingan, pengumuman, kampanye resmi | C | C | – | A/R | – | – | – | – | I |
| Moderasi, sanksi, banding | I | C | – | A/R | – | – | – | – | I |
| Toleransi nol (CSAM) dan pelaporan | I | A | – | R | – | C | – | – | – |
| Topik CS dan artikel FAQ | I | C | C | – | A/R | – | – | – | I |
| Banner, popup, fitur, versi minimum, kill switch | C | C | I | C | – | C | – | C | I |
| Token sosial dan JWKS | I | – | – | – | – | C | A/R | C | – |
| Integrasi notifEngine dan bot | I | C | – | C | – | C | A/R | – | I |
| Pemasangan library dan rilis aplikasi | I | – | – | – | – | C | C | A/R | I |
| Server, backup, monitoring, insiden | I | I | I | I | I | A/R | C | C | – |
| UAT dan go-live | A | R | R | R | R | R | R | R | – |

Catatan: baris "Banner, popup, fitur, versi minimum, kill switch" dikerjakan staf berperan **Fitur & Banner** atau Super Admin (R). Akuntabilitasnya `[ditetapkan manajemen]`, karena peran itu bisa berada di tim produk atau marketing.

## 7. Pengguna dan persona

### 7.1 Pengguna aplikasi nasabah

| Persona | Siapa | Kebutuhan utama | Batasan |
|---|---|---|---|
| **Nasabah** | Pengguna OLT yang sudah login. Profil sosial dibuat otomatis saat pertama membuka fitur komunitas | Berdiskusi saham, chat, bertanya ke CS, membaca FAQ, menerima notifikasi | Tunduk pada kebijakan konten, batas kecepatan, dan masa akun baru |
| **Nasabah akun baru** | Nasabah yang mendaftar atau bergabung lagi kurang dari "Masa akun baru" hari | Sama seperti nasabah | Tanpa gambar dan tautan (kecuali domain tepercaya), DM lewat permintaan pesan, batas kecepatan separuh |
| **Tamu (guest)** | Orang yang tidak bisa login (lupa password/PIN, akun terkunci) | Mengadu ke CS dari halaman login | Belum terverifikasi; hanya chat teks di tiketnya selama 24 jam; tidak menerima data akun |
| **Moderator room** | Nasabah tepercaya yang ditunjuk staf untuk room saham tertentu | Menjaga room tetap tertib | Bisa menyembunyikan pesan, membisukan sementara, eskalasi; aksinya bisa dibatalkan staf |
| **Trader** dan **pelanggan** Berbagi Trade | Nasabah yang disetujui Kepatuhan dan pelanggannya | Berbagi dan menerima info trade | **Dijeda** |

### 7.2 Peran staf di Rendezvous Hub

Peran disimpan dengan kode berikut di Hub dan server. Satu akun boleh punya beberapa peran; menunya digabung.

| Peran (nama di Hub) | Kode | Untuk siapa | Menu utama | Tidak boleh |
|---|---|---|---|---|
| **CS** | `cs_agent` | Agen yang menangani tiket chat nasabah | Layanan Nasabah, Akun Nasabah (bila diberi Akses Akun Nasabah), Komunitas (bila diberi Izin Komunitas) | Dashboard, Laporan, Pengaturan |
| **Super Admin** | `cs_super_admin` | Supervisor/admin operasional CS | Layanan Nasabah (mode pantau), Dashboard, Laporan, Pusat Bantuan, Banner & Popup, Pengaturan, Komunitas (Fitur & versi, Tab Stream, Analitik; tab lain sesuai Izin Komunitas), Bukti (hanya baca) | Mengambil, membalas, menyelesaikan, melepas, atau mentransfer tiket; mengubah tenggat & retensi; menu Akun Nasabah |
| **Kepatuhan** | `compliance` | Tim kepatuhan | Ringkasan, Kasus, Kebijakan konten (termasuk Kata terlarang), Tenggat & retensi, Dokumen hukum, Jejak Audit, Bukti | Menangani tiket |
| **Komunitas** | `community` | Tim riset/marketing/moderasi yang tidak menangani tiket | Komunitas, sesuai Izin Komunitas | Peran ini **tidak dipilih manual**: akun yang hanya diberi Izin Komunitas otomatis menjadi staf Komunitas |
| **Fitur & Banner** | `product` | Tim produk/marketing | Komunitas (hanya tab Fitur & versi dan Tab Stream), Banner & Popup | Pengaturan, Dashboard, Laporan, tiket |
| **Pusat Bantuan** | `cs_content` | Pengelola isi bantuan | Pusat Bantuan (Topik chat CS, Artikel bantuan) | Pengaturan, Dashboard, Laporan, tiket |

Super Admin sudah mencakup Fitur & Banner dan Pusat Bantuan; kedua peran itu tidak disimpan terpisah untuk akun Super Admin.

**Izin tambahan:**

| Izin | Kode | Diberikan ke | Membuka |
|---|---|---|---|
| Tulis postingan resmi | `community.post` | Peran apa pun | Draf postingan, pengumuman, notifikasi |
| Setujui & terbitkan | `community.publish` | Peran apa pun | Persetujuan, jadwal, sematan, hapus postingan resmi; persetujuan notifikasi |
| Moderasi konten | `community.moderate` | Peran apa pun | Laporan, konten/gambar ditahan, indikasi manipulasi, banding konten, room saham, indeks |
| Sanksi pengguna | `community.sanction` | Peran apa pun | Peringatan, bisukan, blokir, cabut sesi, banding sanksi, toleransi nol |
| Kelola akun resmi | `community.accounts` | Peran apa pun | Akun resmi, badge verifikasi |
| Akses Akun Nasabah (beberapa izin rinci) | `online_user.*` | Hanya akun berperan CS | Menu Akun Nasabah |

### 7.3 Pihak sistem

| Pihak | Peran |
|---|---|
| Backend OLT | Menerbitkan token sosial; notifEngine memanggil API integrasi |
| csAdmin OLT | Sumber data Online ID untuk menu Akun Nasabah |
| Akun resmi | Akun perusahaan berbadge **Resmi**, tidak bisa login dari aplikasi |
| Bot resmi | Sistem OLT yang memposting atas nama akun resmi lewat API key |
| Tim IT | Bukan peran Hub; mengoperasikan server lewat perintah `make` dan panduan operasional |

## 8. Proses bisnis as-is dan to-be

> As-is disusun dari riwayat keputusan di repo (dokumen arsip, catatan rilis, migrasi). Bagian yang tidak punya catatan sebelumnya ditandai "asumsi" dan perlu divalidasi pemilik produk.

### 8.1 Login dan identitas

| | Proses |
|---|---|
| **As-is** | Mode lama `websocket`: auth-bridge bertanya ke WebSocket OLT untuk setiap login sosial. Server sosial bergantung pada ketersediaan OLT |
| **To-be** | 1. Nasabah login di OLT. 2. OLT menerbitkan token sosial (JWT EdDSA/ES256, maks. 15 menit). 3. Library menukarnya ke auth-bridge. 4. auth-bridge memverifikasi dengan JWKS lokal, membuat/memperbarui profil, menerbitkan sesi sosial 15 menit. 5. Sebelum habis, library meminta token baru lewat `tokenProvider`. 6. Bila OLT berhenti menerbitkan token (suspend/logout), akses sosial berakhir ≤ 15 menit |

### 8.2 Komunitas

| | Proses |
|---|---|
| **As-is** (asumsi) | Belum ada komunitas resmi di aplikasi; diskusi nasabah terjadi di kanal di luar kendali perusahaan |
| **To-be** | 1. Nasabah menulis postingan (teks, gambar, polling, sentimen, `$KODE`). 2. Media gateway membuang EXIF/GPS dan classifier menilai NSFW. 3. Database memeriksa persetujuan dokumen hukum, kata terlarang, kategori tautan/kontak, masa akun baru, dan batas kecepatan. 4. Konten tampil, ditahan untuk moderator, disensor, atau ditolak. 5. Pengikut dan pemantau saham menerima notifikasi. 6. Moderator menindak laporan; Kepatuhan memantau indikasi manipulasi |

### 8.3 Chat

| | Proses |
|---|---|
| **As-is** (asumsi) | Tidak ada chat antar-nasabah di aplikasi |
| **To-be** | 1. DM ke orang yang tidak mengikuti penerima masuk ke Permintaan pesan (maks. 3 pesan). 2. Pesan dikirim lewat RPC dan disiarkan dari database ke topik room. 3. Status terkirim/dibaca tercatat per penerima. 4. Bila koneksi putus, library menambal pesan yang tertinggal. 5. Room saham memakai slow mode jam ramai dan moderator room |

### 8.4 Layanan nasabah (CS)

| | Proses |
|---|---|
| **As-is** | Pendekatan ticketing/helpdesk terpisah (`care`) dan kartu order di chat dibatalkan (Oktober 2026). Data akun nasabah dibuka di back-office OLT |
| **To-be** | 1. Nasabah membuka room CS (selalu paling atas), memilih topik. 2. Library menampilkan saran artikel FAQ, lalu form pertanyaan awal. 3. Tiket masuk antrean sesuai skill dan prioritas; di luar jam layanan nasabah tetap bisa meninggalkan pesan. 4. CS berstatus Online mengklaim tiket (atau penugasan otomatis). 5. CS membalas, melampirkan file, memberi label, menulis catatan internal, menyisipkan artikel FAQ. 6. CS menyelesaikan dengan hasil dan ringkasan. 7. Nasabah memberi rating → tiket ditutup; tanpa rating → tutup otomatis setelah N hari. 8. Tiket tertutup tidak bisa dibalas; nasabah membuat tiket baru. 9. Pengaduan mendapat tenggat hari kerja dan dipantau Kepatuhan |

### 8.5 Pengaduan tamu

| | Proses |
|---|---|
| **As-is** (asumsi) | Nasabah yang tidak bisa login harus memakai kanal di luar aplikasi |
| **To-be** | 1. Nasabah menekan "Tidak bisa masuk? Hubungi CS" di halaman login. 2. Mengisi nama, Login ID (opsional), jenis masalah, dan cerita. 3. Tiket masuk antrean dengan lencana Tamu dan banner "belum terverifikasi". 4. CS tidak menampilkan data akun; bantuan akun hanya Reset password/PIN dari menu Akun Nasabah yang dikirim ke email terdaftar. 5. Sesi berlaku 24 jam |

### 8.6 Pusat Bantuan

| | Proses |
|---|---|
| **As-is** (asumsi) | Jawaban berulang diberikan manual oleh CS |
| **To-be** | 1. Tim Pusat Bantuan menulis artikel dua bahasa (draf → terbit, berversi). 2. Nasabah mencari atau membuka kategori, membaca, menilai "Apakah ini membantu?". 3. Sebelum chat CS, artikel topik terkait disarankan. 4. CS menandai artikel yang perlu diperbarui. 5. Laporan bantuan menunjukkan artikel lemah dan pencarian tanpa hasil |

### 8.7 Notifikasi transaksi OLT

| | Proses |
|---|---|
| **As-is** | notifEngine OLT harus tahu perangkat, token FCM, dan OAuth Google untuk mengirim push (bagian "Yang bisa dihapus dari notifEngine" di [docs/integration](../integration/README.md)) |
| **To-be** | 1. Token sosial membawa klaim `accounts` (cust id milik login). 2. Saat order match, notifEngine memanggil `/integration/v1/notify/messages` dengan `cust_id`. 3. Server memetakan rekening ke profil, menerapkan preferensi dan jam tenang, mengantrekan push per perangkat. 4. Notifier mengirim lewat FCM. 5. Push transaksi dibuka oleh layar OLT |

### 8.8 Banner, popup, dan kampanye

| | Proses |
|---|---|
| **As-is** | Notifikasi dari banner sempat dibuat sebagai kampanye Komunitas yang butuh akun resmi dan persetujuan di menu Komunitas (`0180`) |
| **To-be** | 1. Staf Fitur & Banner membuat strip atau popup dengan jadwal, sasaran, platform, versi, prioritas, frekuensi. 2. Opsional: kirim juga sebagai notifikasi info (konfirmasi jumlah penerima; empat mata opsional). 3. Aplikasi menampilkan banner sesuai frekuensi per akun. 4. Statistik tayang, klik, tutup, dibuka, diketuk tampil di Hub |

### 8.9 Moderasi dan kebijakan konten

| | Proses |
|---|---|
| **As-is** | Sebelum `0092`, perubahan kebijakan langsung berlaku tanpa versi dan tanpa persetujuan kedua |
| **To-be** | 1. Kepatuhan mengubah aturan di draf. 2. Menjalankan simulasi terhadap konten nyata. 3. Mengajukan dengan alasan. 4. Staf Kepatuhan lain menyetujui atau menolak (empat mata). 5. Versi baru terbentuk; bisa dipulihkan. 6. Moderator menindak antrean laporan, konten dan gambar ditahan, indikasi manipulasi, dan banding |

### 8.10 Akun Nasabah (Online ID)

| | Proses |
|---|---|
| **As-is** | Pengelolaan Online ID lewat aplikasi csAdmin lama (C++ + SQL Server) |
| **To-be** | 1. CS dengan Akses Akun Nasabah (wajib 2FA bila diwajibkan) membuka menu. 2. nasabah-gateway memeriksa izin, meneruskan rute `/online/*` ke csAdmin dengan token integrasi Ed25519. 3. Perubahan data diajukan dan disetujui CS lain (maker-checker), kecuali izin approve sendiri. 4. Semua aksi tulis tercatat dengan kode CS |

### 8.11 Staf dan keamanan login

| | Proses |
|---|---|
| **As-is** | Sejak `0039` login Hub cukup email dan password tanpa TOTP |
| **To-be** | 1. Super Admin membuat akun; password sementara tampil sekali. 2. Login pertama wajib ganti password (≥ 12 karakter). 3. Super Admin wajib 2FA TOTP; peran lain bisa diwajibkan. 4. 5 password salah mengunci akun 15 menit. 5. Super Admin lain bisa Buka kunci dan Reset 2FA. 6. Semua tercatat di Jejak Audit |

### 8.12 Operasional server

| | Proses |
|---|---|
| **As-is** | Rencana awal backup memakai WAL-G dan pengaturan lewat file server; diganti restic + pengaturan dari Hub |
| **To-be** | 1. Server baru dipasang `server-install.sh`. 2. Update dengan `git pull` kedua repo lalu `make up` (migrasi otomatis). 3. Sentinel memantau, mengirim alert ke Telegram/email; healer me-restart layanan macet. 4. Backup WAL terus-menerus dan backup penuh harian terenkripsi, uji restore mingguan. 5. Restore dilakukan tim IT |

## 9. Kebutuhan bisnis

Rincian teknis setiap kebutuhan (RPC, tabel, kode error, layar) ada di [srs.md](srs.md) pada modul dengan kode yang sama.

### 9.1 AKUN: akun, profil, dan privasi

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-AKUN-01 | Nasabah masuk ke fitur sosial memakai login OLT yang sudah ada, tanpa username/password terpisah | Satu identitas; OLT tetap pemilik akun | M | Terpasang |
| BR-AKUN-02 | Sesi sosial berlaku singkat (15 menit) dan diperpanjang otomatis selama OLT masih menerbitkan token | Suspend atau logout di OLT otomatis menghentikan akses sosial tanpa integrasi tambahan | M | Terpasang |
| BR-AKUN-03 | Profil sosial dibuat dan diperbarui otomatis dari data token (ID tetap, username, nama tampilan) | Nasabah langsung bisa memakai komunitas tanpa pendaftaran | M | Terpasang |
| BR-AKUN-04 | Nasabah bisa melihat dan mengubah profil sosialnya (nama tampilan, bio, foto) dan melihat profil orang lain | Identitas komunitas | M | Terpasang |
| BR-AKUN-05 | Nasabah melihat daftar pengikut dan yang diikuti, dengan tombol Ikuti/Ikuti balik; akun terhapus, tamu, staf, yang di-ban, dan yang saling blokir tidak tampil | Navigasi sosial tanpa membocorkan akun yang tidak boleh terlihat | S | Terpasang |
| BR-AKUN-06 | Nasabah memilih siapa yang boleh mengirim DM: semua orang (lewat permintaan pesan), hanya yang ia ikuti, atau tidak ada | Perlindungan dari spam dan penipuan lewat DM | M | Terpasang |
| BR-AKUN-07 | Nasabah memilih siapa yang boleh menyebutnya (`@`): semua orang, hanya yang ia ikuti, atau tidak ada; mention yang tidak diizinkan tidak memberi notifikasi dan namanya tidak muncul di saran `@` | Kendali atas perhatian dan privasi | S | Terpasang |
| BR-AKUN-08 | Nasabah bisa memblokir pengguna lain; blokir berlaku dua arah untuk DM, komentar, pencarian, dan tampilan konten | Perlindungan dari pelecehan | M | Terpasang |
| BR-AKUN-09 | Nasabah bisa membisukan pengguna, kata kunci (maks. 50), dan kode saham dari feed-nya | Kendali isi feed tanpa memblokir | S | Terpasang |
| BR-AKUN-10 | Nasabah bisa menghapus akun komunitas sendiri dengan konfirmasi (mengetik `HAPUS`); postingan, komentar, dan chat hilang dari tampilan, salinan diarsipkan untuk regulator, riwayat CS dan akun trading tidak tersentuh | Hak penghapusan data pribadi | M | Terpasang |
| BR-AKUN-11 | Login yang sama baru bisa bergabung lagi setelah jeda (bawaan 72 jam) dan dimulai sebagai akun baru; selama jeda aplikasi menampilkan sisa waktu dan tombol Hubungi CS (pengaduan tamu) | Mencegah hapus-lalu-daftar untuk lolos dari batasan | M | Terpasang |
| BR-AKUN-12 | Blokir dan bisuan dari orang lain, sanksi moderator, laporan, dan penolakan permintaan DM tetap berlaku setelah akun dihapus lalu bergabung lagi | Sanksi dan perlindungan tidak bisa dihindari dengan hapus akun | M | Terpasang |
| BR-AKUN-13 | Nasabah bisa mengunduh data komunitasnya sebagai file JSON (profil, konten, preferensi, persetujuan, rekening tertaut, tiket CS, banding, dan lainnya), maks. 3 kali sehari | Hak akses dan portabilitas data pribadi | M | Terpasang |
| BR-AKUN-14 | Logout dan hapus akun membersihkan sesi, cache lokal, antrean kirim, dan token push di perangkat | Data tidak tertinggal di perangkat bersama | M | Terpasang |
| BR-AKUN-15 | Cache offline di perangkat bisa dienkripsi dengan kunci dari aplikasi host | Perlindungan data di perangkat yang hilang | S | Terpasang |
| BR-AKUN-16 | Akun yang di-ban tetap bisa melihat sanksinya, mengajukan banding, dan menghubungi CS | Hak keberatan dan kanal pengaduan tetap terbuka | M | Terpasang |

### 9.2 KOM: komunitas dan stream

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-KOM-01 | Stream umum dengan cakupan Terbaru, Mengikuti, Untuk Anda, akun resmi, dan saham pantauan | Pintu masuk utama komunitas | M | Terpasang |
| BR-KOM-02 | Empat tab Stream bawaan (Terbaru, Teratas, Grafik & Media, Polling) dengan urutan tetap, bisa dinyalakan/dimatikan dari Hub tanpa rilis aplikasi | Kendali tampilan tanpa rilis | S | Terpasang |
| BR-KOM-03 | Stream per saham dan tab Diskusi di halaman saham OLT; nasabah bisa memantau (watch) saham | Diskusi terikat ke saham yang sedang dilihat | M | Terpasang |
| BR-KOM-04 | Filter Indeks di Stream dan feed per indeks/instrumen (46 indeks OLT, alias seperti IHSG/JCI untuk COMPOSITE); daftar dikelola dari Hub | Diskusi per indeks sesuai daftar OLT | S | Terpasang |
| BR-KOM-05 | Feed hashtag `#topik` | Penemuan topik | S | Terpasang |
| BR-KOM-06 | Membuat postingan: teks, sampai 4 gambar, sentimen bullish/bearish/netral, `$KODE`, `@user`, `#hashtag`, dengan disclaimer "bukan rekomendasi investasi" | Inti komunitas saham | M | Terpasang |
| BR-KOM-07 | Polling 2–4 pilihan dengan durasi 1 jam–7 hari; satu suara per orang, hasil tampil setelah memilih atau selesai | Interaksi ringan | S | Terpasang |
| BR-KOM-08 | Draf postingan tersimpan otomatis dan tersinkron | Nasabah tidak kehilangan tulisan | C | Terpasang |
| BR-KOM-09 | Penulis bisa mengedit postingan dan komentar dalam batas waktu (bawaan 15 menit, polling tidak bisa diedit), dengan label "diedit"; versi lama disimpan untuk moderator | Koreksi salah ketik tanpa membuka celah manipulasi | S | Terpasang |
| BR-KOM-10 | Penulis bisa menghapus postingan dan komentarnya; salinan diarsipkan | Kendali konten sendiri, arsip regulator | M | Terpasang |
| BR-KOM-11 | Komentar berantai dengan mention, urutan yang bisa diganti, dan komentar teratas di kartu post; komentar terhapus hilang tanpa jejak dan balasannya naik ke induk | Diskusi rapi | M | Terpasang |
| BR-KOM-12 | Pemilik post membatasi siapa yang boleh berkomentar (semua orang, yang diikuti, pengikut, keduanya, atau mati), per akun maupun per post | Perlindungan dari serbuan komentar | S | Terpasang |
| BR-KOM-13 | Saklar untuk mematikan komentar di semua postingan sekaligus tanpa mengubah pengaturan per post | Perlindungan cepat saat diserbu | S | Terpasang |
| BR-KOM-14 | Suka pada postingan dan komentar | Interaksi dasar | M | Terpasang |
| BR-KOM-15 | Ikuti dan berhenti mengikuti pengguna, serta saran akun untuk diikuti dari penulis aktif | Membangun jaringan | M | Terpasang |
| BR-KOM-16 | Akun resmi perusahaan berbadge **Resmi**, tidak bisa login dari aplikasi, hanya bisa diikuti, dan tidak menerima DM dari pengguna biasa | Kanal resmi yang tidak bisa ditiru dan tidak dipakai sebagai jalur CS | M | Terpasang |
| BR-KOM-17 | Badge verifikasi untuk analis/tokoh yang identitasnya diperiksa staf | Kepercayaan terhadap sumber | S | Terpasang |
| BR-KOM-18 | Postingan dan pengumuman resmi dari Hub dengan persetujuan empat mata, jadwal terbit, dan sematan di stream umum atau stream saham (maks. 3 sematan tampil, pengumuman lebih dulu) | Komunikasi resmi yang terkendali | M | Terpasang |
| BR-KOM-19 | Postingan bot resmi dari sistem OLT (berita, aksi korporasi) berlabel **Bot** | Informasi pasar otomatis | S | Terpasang |
| BR-KOM-20 | Trending saham, saham naik daun (rising), hashtag, dan postingan populer untuk jendela 24 jam dan 7 hari, dengan bobot rendah untuk akun baru dan saham yang punya alert manipulasi | Penemuan konten tanpa mudah digoreng | S | Terpasang |
| BR-KOM-21 | Sentimen saham (persentase bullish/bearish/netral, berbobot penulis) sebagai panel Market Mood | Gambaran suasana tanpa bisa digeser akun baru | S | Terpasang |
| BR-KOM-22 | Pencarian pengguna, postingan, saham/indeks, dan hashtag, termasuk toleransi salah ketik; staf, tamu, dan akun yang di-ban tidak bisa dicari | Penemuan | M | Terpasang |
| BR-KOM-23 | Bookmark postingan dan daftar tersimpan | Membaca nanti | C | Terpasang |
| BR-KOM-24 | Pratinjau tautan (judul, deskripsi, gambar) dibuat server secara aman; tautan berbahaya dan gambar NSFW disaring | Pengalaman baca tanpa risiko keamanan | S | Terpasang |
| BR-KOM-25 | Bagikan postingan ke chat sebagai kartu; kartu menampilkan "Postingan tidak tersedia" bila dihapus, ditahan, atau saling blokir | Penyebaran konten tanpa membocorkan yang ditindak | S | Terpasang |
| BR-KOM-26 | Share P/L: aplikasi OLT membuka composer dengan gambar kartu (misalnya kartu laba/rugi) untuk diposting; gambar tunduk pada aturan unggah dan masa akun baru | Nasabah memamerkan hasil tanpa server menyimpan data portofolio | S | Terpasang |
| BR-KOM-27 | Penulis melihat status kontennya sendiri ("Menunggu tinjauan", "Disembunyikan moderator") dan tombol banding; orang lain tidak melihat konten itu | Transparansi bagi penulis | M | Terpasang |
| BR-KOM-28 | Kode saham hanya label; nama, harga, dan saran `$KODE` diambil dari data OLT di aplikasi | Data trading tetap milik OLT | M | Terpasang |

### 9.3 CHAT: pesan langsung, grup, dan room saham

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-CHAT-01 | Pesan langsung (DM) realtime antar-nasabah | Komunikasi pribadi | M | Terpasang |
| BR-CHAT-02 | DM dari orang yang tidak diikuti penerima masuk ke **Permintaan pesan**; pengirim maks. 3 pesan sampai diterima; penerima bisa terima, tolak, atau blokir (dengan laporan spam) | Mencegah spam dan penipuan lewat DM | M | Terpasang |
| BR-CHAT-03 | Chat grup dengan peran owner, admin, dan member; maks. 100 anggota | Diskusi kelompok | M | Terpasang |
| BR-CHAT-04 | Kelola grup: tambah/keluarkan anggota, jadikan admin, pindah kepemilikan, ubah nama/deskripsi/foto, dengan pesan sistem untuk setiap perubahan | Grup terkelola ala WhatsApp | S | Terpasang |
| BR-CHAT-05 | Pengaturan grup "hanya admin yang boleh mengirim" dan "hanya admin yang boleh mengubah info" | Grup pengumuman | S | Terpasang |
| BR-CHAT-06 | Room saham per kode (termasuk room indeks) yang dibuat otomatis saat pertama dibuka; room indeks bisa dimatikan dari Hub | Diskusi terbuka per saham | M | Terpasang |
| BR-CHAT-07 | Slow mode di room saham (dari moderator, alert manipulasi, atau jam ramai) dan satu pesan disematkan per room, ditampilkan realtime | Mengendalikan room ramai | M | Terpasang |
| BR-CHAT-08 | Mention `@` dan `$KODE` aktif di room saham; di grup hanya mention ke sesama anggota (memberi notifikasi walau grup dibisukan); di DM dan chat CS keduanya teks biasa | Mention sesuai konteks tanpa membuka jalan spam | S | Terpasang |
| BR-CHAT-09 | Status pesan ala WhatsApp: mengirim, terkirim ke server, diterima perangkat, dibaca; di grup naik setelah semua anggota | Kepastian pesan sampai | M | Terpasang |
| BR-CHAT-10 | Info pesan: pengirim melihat kapan pesan diterima dan dibaca tiap penerima (DM, grup, chat CS); waktu disimpan 30 hari | Transparansi pengiriman | S | Terpasang |
| BR-CHAT-11 | Indikator mengetik dan status online di DM; room besar (≥ 50 anggota) hanya ringkasan tanpa nama; presence tidak dipakai di room saham | Interaksi hidup tanpa membebani server | S | Terpasang |
| BR-CHAT-12 | Balas (kutip) pesan, geser untuk membalas, dan reaksi emoji tetap (👍 ❤️ 😂 😮 😢 🔥) | Percakapan natural | S | Terpasang |
| BR-CHAT-13 | Pengirim bisa mengedit pesan teks dalam batas waktu (bawaan 15 menit); riwayat edit disimpan dan hanya bisa dibuka staf dengan aturan pembukaan pesan pribadi | Koreksi pesan dengan jejak | S | Terpasang |
| BR-CHAT-14 | Pengirim bisa menghapus pesan; pratinjau daftar chat berganti "[pesan dihapus]" | Kendali pesan sendiri | M | Terpasang |
| BR-CHAT-15 | Hapus chat untuk diri sendiri (riwayat dikosongkan di sisi pengguna), keluar grup, dan hapus grup oleh owner (pesan diarsipkan, tercatat di audit) | Kerapian daftar chat ala WhatsApp | S | Terpasang |
| BR-CHAT-16 | Lampiran gambar di DM, grup, dan room saham (JPEG, PNG, WebP, GIF; HEIC diubah ke JPEG), maks. 4 per pesan, termasuk tempel dari clipboard; penampil gambar dengan unduh | Berbagi tangkapan layar dan grafik | M | Terpasang |
| BR-CHAT-17 | Kartu saham di chat (maks. 3) dengan nama dan harga dari data OLT | Diskusi saham di chat | C | Terpasang |
| BR-CHAT-18 | Daftar chat berhalaman dengan badge belum dibaca, bisukan room, room CS resmi selalu paling atas; pratinjau room saham diperbarui berkala | Navigasi chat | M | Terpasang |
| BR-CHAT-19 | Pesan teks yang gagal terkirim saat offline dikirim ulang otomatis; pesan yang tertinggal saat koneksi putus ditambal otomatis | Keandalan di jaringan seluler | M | Terpasang |
| BR-CHAT-20 | Pengguna biasa tidak bisa memulai DM, mengirim ke DM, atau memasukkan akun resmi ke grup | Akun resmi bukan jalur CS | M | Terpasang |

### 9.4 CS: layanan nasabah lewat chat

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-CS-01 | Setiap nasabah punya satu room CS resmi yang disematkan paling atas, berbadge resmi, tidak bisa dibisukan, ditinggalkan, atau disembunyikan | Kanal CS mudah ditemukan dan tidak bisa ditiru | M | Terpasang |
| BR-CS-02 | Nasabah memilih topik chat CS yang isinya (nama, deskripsi, ikon, tampilan merah, skill, prioritas default, teks halaman) dikelola dari Hub | Antrean ke tim yang tepat | M | Terpasang |
| BR-CS-03 | Topik bisa punya sampai 8 pertanyaan awal (teks, angka, tanggal, pilihan; wajib/opsional) yang diisi sebelum chat dimulai | CS langsung punya konteks | S | Terpasang |
| BR-CS-04 | Paling banyak satu tiket aktif per nasabah, bernomor `CS-YYYYMMDD-NNNN`; pesan di room tanpa tiket aktif membuka tiket baru | Satu percakapan, satu penanggung jawab | M | Terpasang |
| BR-CS-05 | Tiket masuk antrean dan **diklaim** agen secara atomik: dua agen yang mengklik bersamaan tidak mungkin sama-sama berhasil | Tidak ada tiket ganda | M | Terpasang |
| BR-CS-06 | Mengklaim tiket dan menerima transfer hanya bila agen berstatus Online dan belum mencapai batas tiket aktif (1–20 per agen, bawaan 5) | Beban kerja terkendali | M | Terpasang |
| BR-CS-07 | Penugasan otomatis opsional ke agen Online yang sesuai skill dan bahasa, heartbeat-nya segar, dan masih punya slot; tiket yang dilepas tidak ditugaskan kembali ke agen yang melepas | Antrean bergerak tanpa klaim manual | S | Terpasang |
| BR-CS-08 | Status kerja agen Online, Sibuk, Istirahat, Offline dengan alasan; agen Offline tidak bisa membalas (draf tidak hilang); tiket tetap milik agen walau Offline | Kejelasan siapa melayani | M | Terpasang |
| BR-CS-09 | Agen pemilik bisa menunggu nasabah, melepas tiket (wajib alasan), atau mentransfer ke agen tertentu yang harus menerima dalam 10 menit | Serah terima yang jelas | M | Terpasang |
| BR-CS-10 | Lepas otomatis opsional bila pemilik offline lebih dari batas (bawaan mati) | Tiket tidak tertahan | C | Terpasang |
| BR-CS-11 | Super Admin hanya memantau: membaca semua tiket, menulis catatan internal, mengubah prioritas dan tanda, dan memindahkan tiket ke agen lain dengan alasan; tidak membalas dan tidak pernah menerima tiket | Pemisahan pengawas dan pelaksana | M | Terpasang |
| BR-CS-12 | Prioritas P1–P4 dari topik, dinaikkan otomatis oleh tanda dan kata kunci di pesan pertama (misalnya "dibobol" → P1 + Fraud); tanda Pengaduan, Fraud, dan VIP | Kasus mendesak ditangani dulu | M | Terpasang |
| BR-CS-13 | Pengaduan resmi mendapat waktu diterima dan tenggat dalam hari kerja (kalender WIB); nasabah langsung menerima pesan berisi keduanya | Kepatuhan penanganan pengaduan | M | Terpasang |
| BR-CS-14 | Laporan CS palsu dari nasabah menjadi tiket Fraud P1, Super Admin langsung diberi tahu, dan kasusnya masuk register Kepatuhan | Respons cepat terhadap penipuan atas nama CS | M | Terpasang |
| BR-CS-15 | Agen pemilik atau Super Admin bisa menandai tiket sebagai pengaduan atau penipuan dengan alasan; Kepatuhan langsung diberi tahu | Kasus yang terlewat tetap masuk register | M | Terpasang |
| BR-CS-16 | Pesan agen yang meminta OTP, PIN, password, CVV, atau nomor kartu ditahan; Super Admin diberi tahu dan percobaan tercatat di Ringkasan Kepatuhan | Perlindungan nasabah dari penyalahgunaan oleh staf | M | Terpasang |
| BR-CS-17 | OTP, password, nomor kartu, NIK, dan nomor rekening yang diketik di chat CS disamarkan otomatis dan diberi keterangan | Minimisasi data sensitif di transkrip | M | Terpasang |
| BR-CS-18 | Catatan internal per tiket atau per nasabah, tidak pernah terlihat nasabah, tidak bisa diubah setelah disimpan | Koordinasi antar-staf yang tercatat | M | Terpasang |
| BR-CS-19 | Balasan cepat bersama (dikelola Super Admin) dan pribadi (maks. 50 per agen); balasan yang meminta OTP/PIN/password ditolak | Kecepatan dan konsistensi jawaban | S | Terpasang |
| BR-CS-20 | Label tiket berwarna (maks. 50 aktif, maks. 5 per tiket) yang hanya terlihat staf dan masuk laporan | Pengelompokan kasus untuk analisis | S | Terpasang |
| BR-CS-21 | Panel tiket menampilkan jawaban awal nasabah dan SOP topik untuk agen | Penanganan seragam | S | Terpasang |
| BR-CS-22 | Agen bisa menyisipkan artikel FAQ ke balasan dan menandai artikel yang perlu diperbarui | Jawaban konsisten dengan Pusat Bantuan | S | Terpasang |
| BR-CS-23 | Agen bisa mengirim tautan bantuan (hanya `https://` ke host yang diizinkan) dan pilihan cepat 2–4 opsi | Interaksi terstruktur | C | Terpasang |
| BR-CS-24 | Lampiran dua arah di chat CS: gambar, dokumen (PDF, `.docx`, `.xlsx`, `.pptx`, `.txt`, `.csv`), dan video (MP4, MOV, WebM); jenis, format, ukuran, dan durasi diatur Super Admin; dokumen dan video dipindai antivirus | Nasabah bisa mengirim bukti transfer dan formulir | M | Terpasang |
| BR-CS-25 | Nasabah melihat posisi antrean, perkiraan waktu tunggu, dan saran balasan cepat dari topik | Ekspektasi yang jelas | S | Terpasang |
| BR-CS-26 | Jam layanan (WIB) dan kalender libur (nasional, cuti bersama menutup CS; libur bursa tidak); di luar jam layanan nasabah melihat jam buka berikutnya, saran artikel, dan tetap bisa meninggalkan pesan | Layanan jelas di luar jam kerja | M | Terpasang |
| BR-CS-27 | Pesan otomatis sistem dua bahasa (ID/EN) yang teksnya diatur Super Admin | Komunikasi konsisten | S | Terpasang |
| BR-CS-28 | Pengingat otomatis ke nasabah bila tiket menunggu balasannya lebih lama dari batas (bawaan 24 jam, 1–72 jam) | Tiket tidak menggantung | C | Terpasang |
| BR-CS-29 | Agen menyelesaikan tiket dengan hasil dan ringkasan internal (5–500 karakter); nasabah diminta rating | Penutupan tercatat | M | Terpasang |
| BR-CS-30 | Survei kepuasan yang bisa diatur: skala 3 (wajah) atau 5 (bintang), batas nilai rendah, dan sampai 8 alasan nilai rendah | Umpan balik yang bisa dianalisis | S | Terpasang |
| BR-CS-31 | **Rating nasabah langsung menutup tiket**; tiket selesai tanpa rating ditutup otomatis setelah N hari (bawaan 3, 1–30) | Siklus tiket yang pasti | M | Terpasang |
| BR-CS-32 | Bila nasabah membalas sebelum memberi rating dan sebelum batas tutup otomatis, tiket dibuka kembali ke agen pemilik (atau antrean bila pemilik tidak aktif/penuh) | Masalah yang belum tuntas tidak hilang | M | Terpasang |
| BR-CS-33 | **Tiket tertutup tidak bisa dibalas**; nasabah membuat tiket baru dan agen diarahkan ke tiket aktif nasabah | Satu tiket untuk satu masalah | M | Terpasang |
| BR-CS-34 | Nasabah bisa mengakhiri chat sendiri | Kendali nasabah | S | Terpasang |
| BR-CS-35 | Nasabah melihat "Tiket saya" dan bisa mengunduh transkrip tiket yang selesai/ditutup sebagai file teks | Bukti layanan bagi nasabah | S | Terpasang |
| BR-CS-36 | **Pengaduan tamu** dari halaman login tanpa sesi dan tanpa OTP: nama, Login ID opsional, jenis masalah, cerita; tiket berlencana Tamu "belum terverifikasi", data akun tidak ditampilkan, chat teks 24 jam; bisa dimatikan Super Admin | Nasabah terkunci tetap bisa mengadu, tanpa membocorkan data akun | M | Terpasang |
| BR-CS-37 | Agen bisa pratinjau tiket terbuka (hanya baca); pemilik membaca seluruh riwayat room nasabah selama menangani dan sampai 24 jam setelah selesai; akses hilang saat dilepas atau ditransfer | Akses data seperlunya | M | Terpasang |
| BR-CS-38 | Chat CS tetap berjalan walau kill switch sosial aktif, nasabah di-ban dari fitur sosial, atau nasabah belum menyetujui dokumen hukum baru | Kanal pengaduan tidak boleh tertutup | M | Terpasang |
| BR-CS-39 | Pesan di chat CS tidak bisa diedit atau dihapus nasabah, room CS tidak bisa disembunyikan, dan hapus akun tidak menghapus riwayat CS | Transkrip adalah catatan pengaduan | M | Terpasang |
| BR-CS-40 | Tiket pengaduan dan penipuan otomatis masuk register kasus Kepatuhan (lihat PATUH) | Pengawasan pengaduan | M | Terpasang |
| BR-CS-41 | Panel Info nasabah menampilkan riwayat tiket (dengan rating), catatan internal, dan ringkasan Akun Nasabah bila agen punya izin | Konteks tanpa membuka sistem lain | S | Terpasang |

### 9.5 BANTU: Pusat Bantuan

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-BANTU-01 | Pusat Bantuan di aplikasi: kategori (dengan ikon dan urutan) dan artikel tanya-jawab dua bahasa (ID/EN) | Swalayan nasabah | M | Terpasang |
| BR-BANTU-02 | Editor artikel di Hub dengan format terbatas (tebal, miring, daftar, tautan `https://`) dan gambar sisip (JPEG/PNG/WebP, maks. 2 MB, diperkecil otomatis); HTML dan gambar dari situs lain ditolak | Konten kaya tanpa risiko keamanan | M | Terpasang |
| BR-BANTU-03 | Sampai 10 lampiran per artikel, sama untuk kedua bahasa: PDF (maks. 10 MB), gambar (maks. 5 MB), video MP4/WebM/MOV (maks. 25 MB); nama dan urutan bisa diubah; ikut riwayat versi | Panduan berupa formulir, gambar, dan video | S | Terpasang |
| BR-BANTU-04 | Siklus artikel draf → terbit → draf/arsip, setiap simpan membuat versi baru, versi lama bisa dipulihkan, dan simpan bersamaan oleh dua staf ditolak untuk yang kedua | Konten terkendali dan tidak saling timpa | M | Terpasang |
| BR-BANTU-05 | Pencarian artikel dari 2 sampai 100 karakter, maks. 20 hasil, urut kecocokan dan nilai membantu | Nasabah cepat menemukan jawaban | M | Terpasang |
| BR-BANTU-06 | "Apakah ini membantu?" Ya/Tidak per artikel dengan komentar opsional (maks. 500 karakter); komentar tampil di Hub tanpa identitas nasabah | Mengukur kualitas artikel | S | Terpasang |
| BR-BANTU-07 | Saat nasabah memilih topik chat CS, maks. 3 artikel teratas topik itu disarankan ("Mungkin ini membantu") sebelum tiket dibuat | Mengurangi tiket | M | Terpasang |
| BR-BANTU-08 | Pencarian tanpa hasil dicatat dengan angka panjang dan email disamarkan, untuk bahan artikel baru; data lebih dari 90 hari dihapus | Bahan perbaikan konten tanpa data pribadi | S | Terpasang |
| BR-BANTU-09 | Statistik per artikel: dilihat, persen membantu, "tetap buat tiket" dalam 24 jam, dan tercegah; urut "paling kurang membantu" | Prioritas perbaikan artikel | S | Terpasang |
| BR-BANTU-10 | Laporan bantuan per topik, per artikel, dan pencarian tanpa hasil, dengan ekspor CSV | Pelaporan manajemen | S | Terpasang |
| BR-BANTU-11 | Pusat Bantuan tetap bisa dibaca saat offline dari cache terakhir | Bantuan saat jaringan buruk | S | Terpasang |
| BR-BANTU-12 | Catatan "perlu diperbarui" dari CS tampil sebagai lencana di artikel dan bisa ditandai selesai | Umpan balik dari lapangan | S | Terpasang |
| BR-BANTU-13 | Pengumuman status layanan/gangguan (judul, isi ID/EN, tingkat info/peringatan/kritis, waktu mulai/selesai, artikel terkait) tampil di chat CS, halaman pilih topik, dan Pusat Bantuan; daftar menampilkan jumlah tiket selama gangguan | Mengurangi tiket berulang saat insiden | M | Terpasang |
| BR-BANTU-14 | "Masih butuh bantuan? Chat CS" di bawah artikel, kategori, dan hasil pencarian, membuka tiket dengan topik terkait | Jalur lanjut yang mulus | S | Terpasang |
| BR-BANTU-15 | Tim Pusat Bantuan mengelola topik chat CS (termasuk isian awal, saran balasan, SOP, urutan, pratinjau); tanda tiket Pengaduan/Penipuan pada topik hanya bisa diubah Super Admin | Pemisahan isi dan kebijakan | M | Terpasang |

### 9.6 NOTIF: notifikasi dan promosi

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-NOTIF-01 | Kotak notifikasi di aplikasi dengan badge untuk balasan, mention, suka, ikuti, pesan, pengumuman, banding, postingan dari akun yang diikuti, ringkasan pantauan, moderasi, dan notifikasi OLT | Nasabah tahu yang terjadi | M | Terpasang |
| BR-NOTIF-02 | Push ke HP lewat FCM untuk semua notifikasi; kunci Firebase diunggah Super Admin dari Hub (terenkripsi, tidak bisa diunduh lagi); tanpa kunci, notifikasi tetap masuk kotak notifikasi | Satu jalur push untuk semua fitur | M | Terpasang |
| BR-NOTIF-03 | Preferensi per jenis notifikasi (kotak masuk dan push terpisah); notifikasi moderasi di kotak masuk selalu aktif | Kendali nasabah | M | Terpasang |
| BR-NOTIF-04 | Jam tenang (WIB) yang menunda push sampai jam tenang selesai, termasuk lintas tengah malam | Tidak mengganggu di jam istirahat | S | Terpasang |
| BR-NOTIF-05 | Penggabungan notifikasi suka dan ikuti dalam jendela 60 menit ("Budi dan 3 lainnya…") | Mengurangi kebisingan | S | Terpasang |
| BR-NOTIF-06 | Push chat CS selalu terkirim, tidak terkena preferensi sosial | Layanan nasabah bukan notifikasi sosial | M | Terpasang |
| BR-NOTIF-07 | Notifikasi transaksi OLT per rekening (cust id) ke semua HP pemilik rekening, berdasarkan rekening yang dinyatakan token OLT | OLT tidak perlu mengurus perangkat | M | Terpasang |
| BR-NOTIF-08 | Notifikasi OLT dikelompokkan Transaksi, Dana, Pasar, Info, Promo dengan preferensi masing-masing; promo push mati sampai nasabah mengaktifkan; kategori "important" menembus preferensi dan jam tenang | Relevansi dan persetujuan promosi | M | Terpasang |
| BR-NOTIF-09 | Siaran dari OLT ke daftar login, semua pengguna, atau pemantau satu saham, dengan batas 3 siaran non-important per nasabah per hari | Informasi pasar dan IPO tanpa membanjiri nasabah | S | Terpasang |
| BR-NOTIF-10 | Notifikasi ke satu login (`olt_user_id`) untuk alert harga yang dipasang di aplikasi OLT | Alert harga lewat jalur push yang sama | S | Terpasang |
| BR-NOTIF-11 | Kampanye notifikasi Komunitas ke segmen (semua, pemantau saham, pengguna baru, tidak aktif, platform, pengikut akun resmi) dengan perkiraan penerima, jadwal, dan persetujuan empat mata | Komunikasi pemasaran terkendali | S | Terpasang |
| BR-NOTIF-12 | Banner strip atas dan popup tengah dengan judul, isi, tautan, label tombol, sasaran (semua atau pengguna baru ≤ N hari), tingkat, jadwal, platform, versi aplikasi, boleh ditutup, prioritas, dan gambar popup (rasio 4:5 atau 1:1) | Promosi dan pengumuman tanpa iklan pihak ketiga | M | Terpasang |
| BR-NOTIF-13 | Frekuensi banner per akun: sekali per pengguna, sekali sehari, atau setiap buka aplikasi; berlaku lintas perangkat dan setelah login ulang | Tidak mengganggu nasabah | S | Terpasang |
| BR-NOTIF-14 | Statistik banner: tayang, klik, tutup, pengguna unik, CTR, rincian 7 hari | Mengukur kampanye | S | Terpasang |
| BR-NOTIF-15 | Tautan banner hanya `https://` atau deep link aplikasi dengan skema yang didaftarkan Super Admin; skema berbahaya selalu ditolak | Mencegah tautan berbahaya | M | Terpasang |
| BR-NOTIF-16 | Banner baru bisa sekaligus dikirim sebagai **notifikasi info** ke semua nasabah sasaran, dengan konfirmasi jumlah penerima, halaman info berisi isi lengkap, status pengiriman, pembatalan, dan empat mata opsional | Satu langkah untuk pengumuman yang terbaca lengkap | S | Terpasang |
| BR-NOTIF-17 | Popup yang tampil atau klik banner menandai notifikasi info terkait sebagai terbaca, dan sebaliknya | Nasabah tidak melihat info yang sama dua kali | C | Terpasang |
| BR-NOTIF-18 | Ringkasan saham pantauan harian dengan jam kirim yang diatur Super Admin (bawaan 17:05 WIB) | Nasabah mengikuti saham pantauannya | C | Terpasang |
| BR-NOTIF-19 | Statistik dibuka dan diketuk untuk kampanye, siaran, dan notifikasi info | Mengukur efektivitas | S | Terpasang |
| BR-NOTIF-20 | Push transaksi OLT dibuka oleh layar OLT, push komunitas oleh library | Pengalaman sesuai pemilik data | M | Terpasang |

### 9.7 MOD: moderasi dan keamanan konten

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-MOD-01 | Daftar kata terlarang dengan aksi sensor atau blokir, untuk post, komentar, polling, dan chat; import/ekspor Excel (maks. 1.000 baris per file) | Konten kasar, judi, dan pornografi tidak tampil | M | Terpasang |
| BR-MOD-02 | Pencocokan tahan penyamaran: huruf fullwidth, homoglyph, karakter tak terlihat, huruf dipisah titik/spasi, leet (`g0bl0k`), huruf berulang; harga dan kode saham tidak terkena | Aturan tidak mudah diakali | M | Terpasang |
| BR-MOD-03 | Kategori konten (judi, pornografi, phishing, domain diblokir, pemendek tautan, messenger/grup chat, nomor HP, frasa promosi, tautan lain) dengan aksi izinkan/sensor/tahan/blokir dan cakupan publik atau publik + DM & grup | Kebijakan per jenis risiko | M | Terpasang |
| BR-MOD-04 | Domain diblokir, domain tepercaya (misalnya idx.co.id, ojk.go.id), istilah pengecualian, dan frasa promosi dikelola Kepatuhan | Menyesuaikan dengan konteks pasar | M | Terpasang |
| BR-MOD-05 | Uji teks: Kepatuhan memeriksa perlakuan aturan berlaku terhadap sebuah teks tanpa menyimpan apa pun | Memastikan aturan bekerja | S | Terpasang |
| BR-MOD-06 | Kebijakan konten berversi: draf per staf, simulasi terhadap konten nyata, pengajuan beralasan, persetujuan **empat mata** oleh staf Kepatuhan lain, riwayat versi, dan pemulihan versi | Perubahan kebijakan terkendali dan bisa dibuktikan | M | Terpasang |
| BR-MOD-07 | Moderasi gambar NSFW dengan model lokal sebelum gambar tampil; ambang tahan/blokir per kategori diatur Kepatuhan; pornografi wajib punya ambang | Gambar tidak pantas tidak tampil | M | Terpasang |
| BR-MOD-08 | Semua unggahan nasabah lewat media gateway yang mengenali jenis file dari isinya dan membuang EXIF/GPS | Mencegah file berbahaya dan kebocoran lokasi | M | Terpasang |
| BR-MOD-09 | Dokumen dan video chat CS dipindai antivirus; file Office bermakro atau berobjek berbahaya ditolak; bila pemindai mati, unggahan ditolak | Keamanan file yang dibuka staf | M | Terpasang |
| BR-MOD-10 | Satu angka **Masa akun baru** (hari, 0–30, bawaan 3) mengendalikan semua batasan akun baru: gambar (termasuk Share P/L), tautan selain domain tepercaya, DM lewat permintaan pesan, dan batas kecepatan separuh; 0 berarti tanpa batasan | Satu kendali yang mudah dipahami Kepatuhan | M | Terpasang |
| BR-MOD-11 | Batas kecepatan per aksi per pengguna (posting, komentar, pesan, suka, ikuti, laporan, unggah, dan lainnya), dikali faktor akun baru | Mencegah spam dan banjir | M | Terpasang |
| BR-MOD-12 | Integritas konten: maks. tautan, mention, dan kode saham per konten, karakter kontrol ditolak, dan kiriman berulang dengan isi sama ditolak | Mencegah spam terstruktur | M | Terpasang |
| BR-MOD-13 | Deteksi manipulasi pasar tiap 5 menit (lonjakan mention, konsentrasi akun baru, posting terkoordinasi) dengan aksi otomatis slow mode dan penahanan posting mirip | Kepatuhan integritas pasar modal | M | Terpasang |
| BR-MOD-14 | Slow mode jam ramai di room saham pada rentang WIB hari bursa (bawaan 08:55–09:30 dan 15:50–16:15, 10 detik) | Room tetap terbaca saat pembukaan dan penutupan | S | Terpasang |
| BR-MOD-15 | Nasabah bisa melaporkan postingan, komentar, pesan, atau akun; antrean laporan diurutkan menurut jumlah laporan, kepercayaan pelapor, dan jenis (penipuan dan pom-pom lebih berat) | Komunitas ikut menjaga | M | Terpasang |
| BR-MOD-16 | Moderator memutus laporan (sembunyikan, hapus, pulihkan, setujui, abaikan), meninjau konten dan gambar ditahan, dan meninjau atau menolak alert manipulasi, semua dengan alasan | Penindakan tercatat | M | Terpasang |
| BR-MOD-17 | Sanksi pengguna sesuai tangga sanksi atau pilihan (peringatan, bisukan 24 jam/7 hari, blokir 7 hari/permanen), cabut sanksi, dan keluarkan dari semua perangkat; staf dan akun resmi tidak bisa diberi sanksi | Penegakan bertingkat | M | Terpasang |
| BR-MOD-18 | **Toleransi nol** untuk CSAM: blokir permanen, cabut semua sesi, sembunyikan semua konten sebagai bukti, tidak bisa dibanding, dengan konfirmasi berlapis | Kewajiban hukum dan moral | M | Terpasang |
| BR-MOD-19 | Banding atas sanksi atau konten yang disembunyikan/dihapus (alasan 10–1.000 karakter, dalam 30 hari, maks. 10 per hari, satu per target); peninjau harus berbeda dari pemutus awal; hasil dikirim ke pengguna | Keadilan prosedural | M | Terpasang |
| BR-MOD-20 | Moderator room dari nasabah tepercaya untuk room saham tertentu: sembunyikan pesan, bisukan sementara, eskalasi; staf bisa membatalkan aksinya dan mencopot moderator; daftar bisu tidak disiarkan ke anggota | Skala moderasi room ramai | S | Terpasang |
| BR-MOD-21 | **Karantina bukti**: konten yang dilaporkan, dihapus moderator/sistem, gambar yang dihapus, dan konten akun toleransi nol disalin utuh (tambah-saja, sidik SHA-256 berantai) beserta file-nya | Bukti untuk penyidik, OJK, dan sengketa | M | Terpasang |
| BR-MOD-22 | Pesan pribadi (DM/grup) hanya bisa dibuka staf bila dilaporkan, ditandai sistem, atau tidak tampil; setiap pembukaan tercatat di audit | Privasi pesan pribadi | M | Terpasang |
| BR-MOD-23 | Konten ditahan tidak memicu notifikasi, pratinjau tautan, atau cuplikan room; di DM/grup "tahan" diperlakukan sebagai "tolak" | Konten bermasalah tidak bocor lewat jalur lain | M | Terpasang |
| BR-MOD-24 | Pesan error ke nasabah tidak menyebut kata, kategori, atau daftar yang cocok | Aturan tidak mudah dipetakan | S | Terpasang |

### 9.8 PATUH: kepatuhan, audit, dan data pribadi

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-PATUH-01 | Menu Kepatuhan khusus peran `compliance`; Kepatuhan mengawasi dan tidak menangani tiket | Pemisahan fungsi | M | Terpasang |
| BR-PATUH-02 | Ringkasan: pengaduan aktif, jatuh tempo ≤ 1 hari kerja, lewat tenggat, tepat waktu 30 hari, penipuan aktif, belum ditinjau, serta sinyal keamanan (laporan CS palsu, permintaan data rahasia oleh CS) | Pengawasan harian | M | Terpasang |
| BR-PATUH-03 | Register kasus pengaduan dan penipuan dengan filter, pencarian, dan ekspor CSV; status tenggat Berjalan, Segera jatuh tempo, Lewat tenggat, Tepat waktu, Terlambat | Pelaporan berkala | M | Terpasang |
| BR-PATUH-04 | Detail kasus berisi transkrip (pesan dan catatan internal), riwayat, dan tinjauan; setiap pembukaan tercatat sebagai akses data nasabah | Akuntabilitas akses | M | Terpasang |
| BR-PATUH-05 | Tinjauan kasus (Sesuai, Perlu tindak lanjut, Pelanggaran) dengan catatan, tambah-saja; tinjauan terbaru menjadi status | Riwayat penilaian tidak bisa diubah | M | Terpasang |
| BR-PATUH-06 | Perpanjangan tenggat pengaduan **satu kali**, sebelum tenggat lewat, dengan alasan internal; nasabah langsung diberi tahu tenggat baru | Kepatuhan prosedur pengaduan | M | Terpasang |
| BR-PATUH-07 | Unduh transkrip dengan sidik SHA-256 yang dicatat di Jejak Audit | Keaslian transkrip bisa dibuktikan | M | Terpasang |
| BR-PATUH-08 | Kepatuhan bisa membuka tiket biasa (bukan pengaduan/penipuan) hanya-baca selama 12 jam, dan setiap pembukaan tercatat | Pemeriksaan acak tanpa akses permanen | S | Terpasang |
| BR-PATUH-09 | Nilai **Tenggat & retensi** (tenggat pengaduan 1–20 hari kerja, perpanjangan 0–20 hari kerja, retensi riwayat chat CS 5–30 tahun) wajib dikonfirmasi Kepatuhan, beserta dasar ketentuan; Super Admin tidak bisa mengubahnya | Nilai regulasi diputuskan Kepatuhan | M | Terpasang |
| BR-PATUH-10 | **Jejak Audit** tambah-saja untuk semua aksi CS, Super Admin, Kepatuhan, nasabah, dan sistem, dengan filter, pencarian, dan ekspor CSV; tidak bisa diubah atau dihapus | Bukti tata kelola | M | Terpasang |
| BR-PATUH-11 | Dokumen hukum (S&K, Pedoman Komunitas, Kebijakan Privasi): draf, ajukan, persetujuan staf Kepatuhan lain (persetujuan sendiri hanya bila satu staf aktif, ditandai), terbit langsung atau terjadwal, versi terbit tidak bisa diubah | Dokumen hukum terkendali | M | Terpasang |
| BR-PATUH-12 | Persetujuan nasabah per versi dokumen; dokumen wajib harus disetujui sebelum membuat konten atau chat komunitas (aksi diulang otomatis setelah setuju); chat CS tidak butuh persetujuan; persentase persetujuan tampil di Hub | Dasar hukum pemrosesan dan kanal pengaduan tetap terbuka | M | Terpasang |
| BR-PATUH-13 | Hak subjek data: ekspor data (BR-AKUN-13) dan hapus akun (BR-AKUN-10) tersedia swalayan di aplikasi | Pemenuhan hak pelindungan data pribadi | M | Terpasang |
| BR-PATUH-14 | Minimisasi data: analitik tanpa teks pengguna, pencarian tanpa hasil disamarkan, data sensitif di chat CS disamarkan, EXIF/GPS dibuang, token perangkat tidak terbaca aplikasi | Prinsip pelindungan data | M | Terpasang |
| BR-PATUH-15 | Retensi data terjadwal per jenis (lihat ATR bagian retensi) dengan penghapusan otomatis | Data tidak disimpan lebih lama dari perlu | M | Terpasang |
| BR-PATUH-16 | Arsip regulator: konten yang dihapus pengguna atau moderator dan riwayat edit disimpan sebagai arsip dengan dukungan legal hold | Permintaan regulator tetap bisa dipenuhi | M | Terpasang |
| BR-PATUH-17 | Menu Bukti: pemeriksaan integritas, pasang/lepas legal hold (alasan 10–500 karakter), ekspor paket bukti bersidik (khusus Kepatuhan); Super Admin hanya membaca; setiap akses tercatat | Rantai penanganan bukti | M | Terpasang |
| BR-PATUH-18 | Notifikasi kasus baru (ikon perisai) untuk Kepatuhan dan Super Admin, termasuk kasus yang ditandai CS beserta alasannya | Kasus tidak terlewat | S | Terpasang |
| BR-PATUH-19 | Akses jejak layanan per nasabah di Laporan tercatat di audit | Akses data pribadi tercatat | M | Terpasang |

### 9.9 HUB: aplikasi web staf

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-HUB-01 | Login staf dengan email kerja dan password; tidak ada pendaftaran publik; login pertama dan setelah reset wajib ganti password (≥ 12 karakter, berbeda dari password sementara) | Akun staf terkendali | M | Terpasang |
| BR-HUB-02 | **2FA TOTP wajib untuk Super Admin**, bisa diwajibkan untuk peran lain dari Hub; ditegakkan di server, termasuk menu Akun Nasabah | Akun berhak tinggi terlindungi | M | Terpasang |
| BR-HUB-03 | **Kunci akun staf** setelah password salah berulang (bawaan 5 kali, kunci 15 menit, bisa diatur); Super Admin bisa Buka kunci dan Reset 2FA staf lain; prosedur darurat bila Super Admin terakhir kehilangan HP | Mencegah tebak password | M | Terpasang |
| BR-HUB-04 | Keluar otomatis setelah tidak dipakai (bawaan 30 menit, dengan peringatan), ganti password sendiri, dan keluar dari semua perangkat; semuanya tercatat | Keamanan sesi | M | Terpasang |
| BR-HUB-05 | Hub dapat dibatasi ke IP kantor/VPN (opsional); API staf ditolak di domain publik | Mengurangi permukaan serangan | M | Terpasang |
| BR-HUB-06 | Staf bisa membuka beberapa akun berbeda di tab berbeda pada satu browser; sesi, realtime, dan heartbeat terpisah per tab/akun | Kebutuhan kerja staf yang memegang lebih dari satu akun | M | Terpasang |
| BR-HUB-07 | Peran dan izin staf sesuai bagian 7.2; menu mengikuti gabungan peran dan izin; akun wajib punya minimal satu peran atau satu Izin Komunitas | Akses seperlunya | M | Terpasang |
| BR-HUB-08 | Super Admin mengelola akun staf: tambah (password sementara tampil sekali), ubah peran/tim/batas tiket/izin, reset password, nonaktifkan (tiket aktif kembali ke antrean, transfer dibatalkan); tidak bisa menonaktifkan diri sendiri atau melepas peran Super Admin sendiri | Siklus hidup akun staf | M | Terpasang |
| BR-HUB-09 | Profil saya (hanya baca) dan Kinerja saya (tiket diselesaikan, respons pertama, waktu selesai, rating, pengaduan) dengan definisi yang sama dengan Laporan | Transparansi kinerja agen | S | Terpasang |
| BR-HUB-10 | Dashboard live untuk Super Admin: tiket terbuka, tunggu terlama, sedang ditangani, selesai hari ini, CS online, daftar "Perlu perhatian", status CS, antrean per prioritas, dan alert suara/browser untuk tiket terlambat | Supervisi real-time | M | Terpasang |
| BR-HUB-11 | Laporan (maks. 93 hari, WIB): tiket masuk, selesai, waktu sampai diambil, respons pertama, durasi, rating, per hari, per CS, topik, label, **per nasabah** dengan jejak layanan, alasan nilai rendah, laporan bantuan; ekspor CSV dengan penetralan formula spreadsheet | Pelaporan manajemen dan Kepatuhan | M | Terpasang |
| BR-HUB-12 | Pengaturan Layanan CS: akun CS, quick reply, label, jam layanan & libur, pesan otomatis, penugasan/tiket/alert, pengaduan tanpa login, lampiran chat CS, status gangguan, survei kepuasan | Operasional CS dikelola tanpa developer | M | Terpasang |
| BR-HUB-13 | Form pengaturan penting terkunci (Ubah → Simpan → konfirmasi dampak) dan setiap perubahan tercatat dengan nilai sebelum/sesudah | Mencegah salah ubah | M | Terpasang |
| BR-HUB-14 | Aturan empat mata yang bisa diatur Super Admin: Komunitas (bawaan aktif), kebijakan konten (bawaan aktif), notifikasi info Banner & Popup (bawaan mati) | Kontrol ganda untuk publikasi massal | M | Terpasang |
| BR-HUB-15 | Fitur aplikasi: delapan sakelar tetap (pencarian, trending, simpan postingan, edit postingan, reaksi pesan, bagikan ke chat, pengaturan notifikasi, analitik), berlaku tanpa rilis aplikasi | Mematikan fitur bermasalah dengan cepat | S | Terpasang |
| BR-HUB-16 | **Kill switch** fitur sosial dengan alasan dan konfirmasi berlapis: tulis konten dan chat non-CS ditolak untuk semua pengguna, membaca dan chat CS tetap jalan | Penanganan insiden besar | M | Terpasang |
| BR-HUB-17 | Versi minimum aplikasi per platform; aplikasi lebih lama diminta memperbarui | Memutus klien lama yang tidak kompatibel | M | Terpasang |
| BR-HUB-18 | Menu Akun Nasabah (khusus akun CS dengan izin rinci): lihat nasabah online dan rekening tertaut, ajukan buat/ubah/hapus Online ID dan rekening tertaut, approval oleh CS lain (atau approve sendiri bila diizinkan), reset password/PIN ke email terdaftar, kirim email pembukaan rekening, ubah status langsung dengan alasan, akun demo saja | Satu aplikasi kerja untuk CS dengan maker-checker | M | Terpasang |
| BR-HUB-19 | Pengaturan Integrasi: alamat API Nasabah (aktif hanya setelah tes koneksi berhasil), data koneksi aplikasi dan status login OLT (hanya baca), skema deep link, batas rekening per nasabah, API key notifikasi, kunci Firebase dan push uji | Integrasi dikelola dari web | M | Terpasang |
| BR-HUB-20 | Pengaturan Sistem: keamanan login, kesehatan sistem, backup, dan kanal alert; rahasia (token bot, password SMTP, password backup, kunci Firebase) tersimpan terenkripsi dan tidak pernah ditampilkan lagi | Operasional lewat web dengan jejak audit | M | Terpasang |
| BR-HUB-21 | Pengaturan Komunitas: Izin Komunitas per staf dan jam ringkasan saham pantauan | Pembagian tugas tim Komunitas | S | Terpasang |
| BR-HUB-22 | Analitik komunitas untuk Super Admin: DAU/WAU/MAU, konten, retensi mingguan, saham paling dibahas, dan "Dari sosial ke order", tanpa teks pengguna | Mengukur nilai bisnis | S | Terpasang |
| BR-HUB-23 | Kemudahan kerja: command palette (Ctrl K), pintasan keyboard, dua bahasa ID/EN, tema terang/gelap, kepadatan, notifikasi tiket baru (semua/prioritas tinggi/mati), indikator koneksi | Produktivitas staf | S | Terpasang |
| BR-HUB-24 | Menu Komunitas: postingan resmi, notifikasi, moderasi, room saham, indeks, akun resmi, fitur & versi, Tab Stream, analitik, dengan tab sesuai izin dan angka antrean di atasnya | Satu tempat kerja tim Komunitas | M | Terpasang |
| BR-HUB-25 | Menu Banner & Popup untuk Super Admin dan Fitur & Banner, dengan pratinjau strip dan ponsel | Pengelolaan promosi | M | Terpasang |

### 9.10 INT: integrasi

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-INT-01 | Token sosial JWT bertanda tangan OLT (EdDSA disarankan, ES256 diterima) diverifikasi lokal dengan JWKS OLT; algoritma lain ditolak; tidak ada panggilan jaringan ke OLT untuk login | Nol dependensi keluar untuk login | M | Terpasang |
| BR-INT-02 | Rotasi kunci OLT dengan `kid` baru tanpa henti layanan; kunci dev ditolak di produksi; kunci tidak bisa diganti dari Hub | Keamanan identitas nasabah | M | Terpasang |
| BR-INT-03 | Status login OLT di Hub (heartbeat auth-bridge): Aktif/Peringatan/Tidak ada heartbeat, `kid`, issuer, audience, login terakhir, jumlah login 24 jam | Pemeriksaan integrasi tanpa SSH | S | Terpasang |
| BR-INT-04 | Klaim `accounts` di token menautkan rekening (cust id) ke login; diganti persis setiap penukaran token; tautan tidak dipakai setelah 30 hari tanpa pembaruan; login staf OLT tidak boleh membawa rekening nasabah | Kepemilikan rekening dinyatakan OLT, tidak bisa dipalsukan aplikasi | M | Terpasang |
| BR-INT-05 | API notifikasi `POST /integration/v1/notify/messages` untuk target rekening, satu login, daftar login, semua pengguna, atau pemantau saham, dengan idempotensi `id` 7 hari dan pemrosesan batch dalam satu transaksi | Kiriman ulang aman | M | Terpasang |
| BR-INT-06 | API bot `POST /integration/v1/bot/posts` untuk memposting atas nama satu akun resmi, dengan `id` unik selamanya dan batas per jam | Konten otomatis terkendali | S | Terpasang |
| BR-INT-07 | API key integrasi dibuat Super Admin dengan izin (`notify`, `notify_broadcast`, `bot_post`), CIDR yang diizinkan, dan batas per menit; key tampil sekali, disimpan sebagai hash; bisa dinonaktifkan sementara atau dicabut permanen; statistik per key dan per siaran | Kendali akses sistem lain | M | Terpasang |
| BR-INT-08 | nasabah-gateway meneruskan permintaan menu Akun Nasabah ke csAdmin hanya untuk rute `/online/*` yang diizinkan, memakai token integrasi Ed25519, memvalidasi filter, mengisi pelaku dengan kode CS, dan mencatat aksi tulis | Integrasi aman ke sistem lama tanpa memindahkan datanya | M | Terpasang |
| BR-INT-09 | Library Flutter dipasang di aplikasi OLT sebagai widget tanpa `Scaffold` (Stream, Diskusi saham, Chat, lonceng, Chat CS, Pusat Bantuan, profil, pencarian, trending, bookmark) sehingga layout tetap milik OLT | Integrasi rapi dengan aplikasi host | M | Terpasang |
| BR-INT-10 | Library menerima token lewat `tokenProvider`, data saham lewat `stockSearch`/`stockInfo`/`onStockTap`, dan menyediakan `registerPushToken`, host banner/popup, pengaduan tamu, `appVersion`/`onUpdateRequired`, `signOut()`, `deleteMyAccount()` | Kontrak integrasi yang jelas untuk tim aplikasi | M | Terpasang |
| BR-INT-11 | Tampilan library bisa disesuaikan (tema mengikuti OLT, builder dan slot untuk bubble chat, kartu post, badge, ikon, halaman info) dan log library bisa diteruskan ke logger host | Konsistensi merek OLT | S | Terpasang |
| BR-INT-12 | Kompatibilitas maju-mundur: library baru jalan di server lama dan sebaliknya; fitur yang butuh migrasi baru hanya tidak tampil sampai keduanya sejajar | Rilis server dan aplikasi tidak harus bersamaan | M | Terpasang |
| BR-INT-13 | Analitik pemakaian dari aplikasi berupa event anonim tanpa teks (buka feed, buat post, ketuk saham, ketuk order, cari) dengan properti yang di-whitelist | Mengukur nilai tanpa melanggar privasi | S | Terpasang |
| BR-INT-14 | Spesifikasi API chat dalam OpenAPI dan AsyncAPI untuk klien lain | Dasar klien non-Flutter | S | Terpasang |
| BR-INT-15 | SDK headless untuk klien non-Flutter (Kotlin Multiplatform untuk Android/iOS, TypeScript) dengan perilaku setara library Flutter; WebView tidak dipakai | Klien yang aplikasinya bukan Flutter | C | Rencana |

### 9.11 OPS: operasional dan infrastruktur

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-OPS-01 | Sistem berjalan self-hosted di Docker tanpa layanan cloud wajib; hanya beberapa layanan yang boleh keluar ke internet (push, alert, backup, signature antivirus) | Kendali penuh atas data | M | Terpasang |
| BR-OPS-02 | Dua domain: API publik hanya meloloskan path resmi; domain Hub dapat dibatasi ke IP kantor (opsional) | Permukaan serangan minimal | M | Terpasang |
| BR-OPS-03 | Container dikunci (read-only, non-root, tanpa capability, batas CPU/memori), jaringan internal dipisah, rahasia dari Docker secrets dan Vault | Pengerasan keamanan | M | Terpasang |
| BR-OPS-04 | Kesehatan sistem: pemantauan layanan, disk, database, antrean, kapasitas, dan backup; alert dibuka, memburuk, dan pulih dikirim ke Telegram/email; Super Admin bisa menandai sudah ditangani | Gangguan cepat diketahui | M | Terpasang |
| BR-OPS-05 | Peta layanan realtime (diperbarui ±5 detik) dengan status, replika, CPU, dan RAM setiap node | Gambaran kesehatan bagi Super Admin dan IT | S | Terpasang |
| BR-OPS-06 | Restart otomatis layanan yang hidup tetapi macet, satu replika demi satu, dengan batas restart per jam dan penahanan saat masalah sistemik | Pulih sendiri tanpa memperparah | M | Terpasang |
| BR-OPS-07 | Backup database (WAL terus-menerus + backup penuh harian) dan file storage, terenkripsi, ke S3 (disarankan) atau folder lokal, dengan pemulihan ke titik waktu dan uji restore otomatis mingguan; diatur Super Admin dari Hub | Data tidak hilang | M | Terpasang |
| BR-OPS-08 | Pemulihan (restore) hanya dilakukan tim IT mengikuti panduan, bukan dari Hub | Restore memundurkan data semua orang | M | Terpasang |
| BR-OPS-09 | Pembersihan file yang tidak dipakai (misalnya lampiran akun yang dihapus) lewat antrean, tanpa menghapus file yang masih menjadi bukti | Privasi dan hemat ruang tanpa merusak bukti | M | Terpasang |
| BR-OPS-10 | Pemasangan server baru dengan satu skrip, dan update dengan `git pull` kedua repo lalu `make up` yang memasang migrasi berurutan; migrasi terpasang tidak boleh berubah (dicek checksum); catatan rilis per rilis dan panduan rollback | Update yang bisa diulang dan diaudit | M | Terpasang |
| BR-OPS-11 | Profil deploy `dev` dan `single` (produksi satu server, HTTPS otomatis), dengan replika 2 untuk layanan sibuk dan pool koneksi PgBouncer | Produksi awal siap pakai | M | Terpasang |
| BR-OPS-12 | Profil `cluster` (Docker Swarm, Realtime cluster, storage S3, database terpisah) | Pertumbuhan di atas kapasitas satu server | S | Rencana |
| BR-OPS-13 | Batas per IP di edge cukup longgar untuk ±1.000 nasabah di balik satu IP (CGNAT, Wi-Fi kantor), sementara batas per akun tetap ketat | Nasabah tidak terblokir saat pasar buka | M | Terpasang |
| BR-OPS-14 | Pengiriman realtime dengan batas tenant yang bisa diatur dan pengisian celah di klien, sehingga pesan tidak hilang walau terlambat | Keandalan chat di room ramai | M | Terpasang |
| BR-OPS-15 | Gerbang mutu sebelum commit dan di CI: tes pgTAP aturan bisnis di database sekali pakai, tes Go, tes Hub, tes library, pemindaian rahasia (gitleaks) | Mencegah regresi dan kebocoran | M | Terpasang |
| BR-OPS-16 | Alat uji keamanan, beban, dan chaos yang hanya berjalan di stack dev; uji beban setara produksi dan pentest independen sebelum go-live | Bukti kesiapan produksi | M | Terpasang (alat); uji pra-produksi Rencana |
| BR-OPS-17 | Rahasia di Vault yang tidak terbaca setelah restore ke server baru memunculkan alert dan bisa diisi ulang dari Hub | Pemulihan bencana yang tuntas | S | Terpasang |

### 9.12 TRADE: Berbagi Trade

| ID | Kebutuhan | Rasional | Prioritas | Status |
|---|---|---|---|---|
| BR-TRADE-01 | Nasabah yang disetujui Kepatuhan (trader) membagikan trade yang sudah done (match) di rekeningnya kepada pelanggan | Fitur sosial trading yang transparan | W | Dijeda |
| BR-TRADE-02 | Relay pasif hanya-baca menerima order/trade realtime dari iProxy OLT, hanya untuk rekening yang disetujui | Data yang keluar dari OLT seminimal mungkin | W | Dijeda |
| BR-TRADE-03 | Pelanggan berlangganan trader (dengan pernyataan risiko wajib), bisa membisukan atau berhenti, dan menerima notifikasi trade | Persetujuan risiko oleh pelanggan | W | Dijeda |
| BR-TRADE-04 | Kepatuhan menyetujui, menangguhkan, mencabut trader, mengatur pengaturan global, memantau aktivitas, dan memakai tombol darurat | Kendali penuh Kepatuhan | W | Dijeda |
| BR-TRADE-05 | Tidak ada order otomatis, tombol "ikuti order", atau copy trade | Di luar izin usaha (nasihat/pengelolaan investasi) | W | Dijeda (tetap di luar lingkup) |

### 9.13 Ringkasan jumlah kebutuhan

| Modul | Jumlah BR | Terpasang | Dijeda | Rencana |
|---|---|---|---|---|
| AKUN | 16 | 16 | 0 | 0 |
| KOM | 28 | 28 | 0 | 0 |
| CHAT | 20 | 20 | 0 | 0 |
| CS | 41 | 41 | 0 | 0 |
| BANTU | 15 | 15 | 0 | 0 |
| NOTIF | 20 | 20 | 0 | 0 |
| MOD | 24 | 24 | 0 | 0 |
| PATUH | 19 | 19 | 0 | 0 |
| HUB | 25 | 25 | 0 | 0 |
| INT | 15 | 14 | 0 | 1 |
| OPS | 17 | 16 | 0 | 1 |
| TRADE | 5 | 0 | 5 | 0 |
| **Total** | **245** | **238** | **5** | **2** |

BR-OPS-16 dihitung Terpasang untuk alatnya; uji beban setara produksi dan pentest independen masih harus dijalankan sebelum go-live (bagian 14).

## 10. Aturan bisnis

Nilai berikut adalah bawaan di kode per migrasi `0188`. Kolom "Diatur dari" menunjukkan siapa yang bisa mengubahnya tanpa rilis.

### 10.1 Akun dan identitas

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-01 | Token sosial OLT: `iss`, `aud`, `sub` (string tetap), `preferred_username`, `iat`, `exp` wajib; umur maks. 15 menit; toleransi jam 30 detik; panjang maks. 16 KB. `sub` yang berubah dianggap orang lain | Konfigurasi server (bukan Hub) |
| ATR-02 | Sesi sosial berlaku 15 menit. Penukaran token per user OLT maks. 10 per menit; per IP maks. 1.500 per menit | `docker/.env` |
| ATR-03 | Klaim `accounts`: maks. 200 item (bisa diturunkan Super Admin 1–200), pola `^[A-Za-z0-9._-]{1,32}$`, tidak peka huruf besar; tautan kedaluwarsa setelah 30 hari tanpa penukaran token | Hub → Integrasi aplikasi |
| ATR-04 | Jeda bergabung lagi setelah hapus akun: 72 jam (0–720, 0 = tanpa jeda), lewat draf dan empat mata kebijakan | Kepatuhan → Kebijakan konten |
| ATR-05 | Unduh data saya maks. 3 kali per 24 jam | Server |

### 10.2 Konten komunitas dan chat

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-06 | Panjang teks: postingan 1–2.000 karakter, komentar 1–1.000, pesan chat maks. 4.000, pesan tamu 1–2.000 | Tetap |
| ATR-07 | Lampiran maks. 4 per postingan dan per pesan. Gambar chat global maks. 5 MB; hanya gambar di DM, grup, dan room saham | Tetap |
| ATR-08 | Per konten maks. 3 tautan, 10 mention, 10 kode saham. Kiriman ke-3 dengan isi sama (≥ 10 karakter) dalam 300 detik ditolak | Server (`private.settings`) |
| ATR-09 | Batas edit postingan, komentar, dan pesan: 15 menit sejak dibuat; postingan berpolling dan pesan berlampiran tidak bisa diedit | Server |
| ATR-10 | Polling: 2–4 pilihan, label maks. 40 karakter dan tidak boleh sama, durasi 1 jam–7 hari, satu suara per orang yang tidak bisa diubah, pembuat tidak ikut memilih; batas memilih 30 per menit dan 500 per hari | Tetap |
| ATR-11 | Hashtag: pola `^[a-z0-9_]{2,50}$`, maks. 10 per postingan. Kode saham `^[A-Z][A-Z0-9]{1,11}$`; kode instrumen berstrip harus terdaftar | Tetap; indeks dari Hub |
| ATR-12 | Pencarian: 2–100 karakter, 30 per menit dan 600 per jam per pengguna; hasil per halaman 1–50 | Server |
| ATR-13 | Grup maks. 100 anggota; nama grup 1–80 karakter, deskripsi maks. 500. Bawaan: semua anggota boleh mengirim, hanya admin yang mengubah info | Pengaturan grup oleh owner/admin |
| ATR-14 | Permintaan pesan: pengirim maks. 3 pesan sampai diterima. Akun baru selalu lewat permintaan pesan bila tidak saling mengikuti | Server |
| ATR-15 | Room saham: slow mode efektif = nilai terbesar dari pengaturan moderator (maks. berlaku 30 hari), alert manipulasi, dan jam ramai (10 detik pada 08:55–09:30 dan 15:50–16:15 WIB hari bursa). Satu pesan disematkan per room. Akun resmi tidak terkena | Moderator (Komunitas → Room saham), Kepatuhan (jam ramai) |
| ATR-16 | Mengetik di room ≥ 50 anggota hanya berupa ringkasan maks. 1 per 3 detik; presence ditolak di room saham | Server |
| ATR-17 | Waktu "Info pesan" disimpan 30 hari | Server |
| ATR-18 | Batas kecepatan dasar per pengguna: postingan 5/menit dan 50/hari; komentar 20/menit; pesan 30/menit; suka 120/menit; ikuti 60/menit dan 30/jam; laporan 10/jam; unggah 50/hari; membuat room 10/jam; membuat room saham 20/jam; edit konten 20/menit; bookmark 120/menit; reaksi pesan 60/menit; banding 10/hari. Akun baru dikali 0,5 | Server (`private.rate_limits`) |
| ATR-19 | Kontrol komentar: `everyone` (bawaan), `following`, `followers`, `following_and_followers`, `off` (hanya per post). Saat komentar mati, komentar lama disembunyikan, tidak dihapus | Pemilik post |

### 10.3 Masa akun baru dan keamanan konten

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-20 | Masa akun baru: 3 hari (0–30) sejak daftar atau bergabung lagi. Selama masa itu: tanpa gambar (termasuk Share P/L), tanpa tautan selain domain tepercaya, DM lewat permintaan pesan, batas kecepatan × 0,5. Trust level 2 ke atas tidak pernah dianggap baru. Akun trust 0 naik ke 1 setelah masa yang sama (job tiap 15 menit) | Kepatuhan → Kebijakan konten → Kategori |
| ATR-21 | Aksi kategori bawaan: judi, pornografi, phishing, domain diblokir, frasa promosi = blokir (semua cakupan); pemendek tautan, messenger, nomor HP = tahan (publik); tautan lain = izinkan. Di DM/grup, "tahan" menjadi "tolak" | Kepatuhan |
| ATR-22 | Domain tepercaya bawaan: idx.co.id, ojk.go.id, ksei.co.id, kpei.co.id, bi.go.id | Kepatuhan |
| ATR-23 | Kata terlarang: 2–50 karakter (huruf, angka, spasi), cocok kata utuh, tidak peka huruf besar; import Excel maks. 1.000 baris, tidak menghapus kata yang ada | Kepatuhan |
| ATR-24 | Perubahan kebijakan konten masuk draf; berlaku setelah diajukan (alasan 5–500 karakter) dan disetujui staf Kepatuhan lain bila empat mata aktif (bawaan aktif). Pembuat tidak boleh menyetujui; Super Admin hanya melihat | Kepatuhan; saklar empat mata oleh Super Admin |
| ATR-25 | Deteksi manipulasi (tiap 5 menit): lonjakan mention > 5× rata-rata per jam 7 hari sebelumnya dan ≥ 20; > 60% mention 1 jam dari akun < 7 hari dan ≥ 10; posting mirip (kemiripan ≥ 0,8) dari ≥ 5 penulis dalam 30 menit. Aksi otomatis: slow mode selama 60 menit, paling ketat sama dengan slow mode jam ramai; tahan posting mirip | Kepatuhan → Anti-manipulasi |
| ATR-26 | Banding: alasan 10–1.000 karakter, dalam 30 hari sejak penindakan, maks. 10 per hari, satu per target; konten yang masih ditahan tidak bisa dibanding; toleransi nol tidak bisa dibanding | Server |
| ATR-27 | Sanksi: peringatan, bisukan 24 jam, bisukan 7 hari, blokir 7 hari, blokir permanen, atau otomatis sesuai tangga sanksi. Tindakan moderasi yang meminta alasan: 5–500 karakter | Moderator dengan izin Sanksi |
| ATR-28 | Gambar diblokir atau ditahan menurut ambang skor classifier per kategori; bila classifier tidak tersedia, unggahan gambar ditolak (fail closed) | Kepatuhan → Ambang gambar |

### 10.4 Layanan nasabah

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-29 | Satu tiket aktif per nasabah. Nomor `CS-YYYYMMDD-NNNN` urut per hari WIB | Tetap |
| ATR-30 | Batas tiket aktif per agen 1–20, bawaan 5 | Super Admin → Akun CS |
| ATR-31 | Klaim dan terima transfer hanya bila Online dan punya slot; agen Offline tidak bisa membalas; Sibuk/Istirahat tetap boleh membalas percakapan yang berjalan | Tetap |
| ATR-32 | Transfer kedaluwarsa 10 menit bila tidak diterima. Lepas tiket wajib alasan ≥ 3 karakter. Agen dianggap tidak aktif setelah 10 menit | Server |
| ATR-33 | Penugasan otomatis memilih agen Online dengan slot, menguasai bahasa tiket, heartbeat < 90 detik; urutan level skill tertinggi, tiket aktif paling sedikit, lalu paling lama tidak mendapat tiket. Tidak dibatasi jam layanan | Super Admin → Penugasan |
| ATR-34 | Tutup otomatis tiket selesai tanpa rating: 3 hari (1–30). Tiket yang dinilai langsung ditutup. Tiket tertutup ditolak bila dibalas | Super Admin → Penugasan, tiket & alert |
| ATR-35 | Pengingat tiket menunggu nasabah: 24 jam (1–72) | Super Admin |
| ATR-36 | Alert Super Admin: tiket belum diambil > 10 menit; P1 > 2 menit | Super Admin |
| ATR-37 | Prioritas: tanda Fraud → P1; Pengaduan → paling rendah P2; kata kunci di pesan pertama (misalnya "dibobol", "penipuan") → P1 + Fraud | Server (`priority.rules`) |
| ATR-38 | Tenggat pengaduan: 5 hari kerja (1–20); perpanjangan 10 hari kerja (0–20), sekali, sebelum tenggat lewat, alasan 10–500 karakter. Nilai bawaan berstatus usulan sampai dikonfirmasi Kepatuhan; perubahan hanya untuk pengaduan baru | Kepatuhan → Tenggat & retensi |
| ATR-39 | Ringkasan penyelesaian 5–500 karakter, tidak terlihat nasabah. Alasan tandai pengaduan/penipuan 5–300 karakter | Tetap |
| ATR-40 | Akses agen ke riwayat nasabah: pemilik selama menangani + 24 jam setelah selesai; agen lain hanya pratinjau tiket `open` | Server |
| ATR-41 | Batas nasabah: 5 tiket baru per jam, 30 pesan per menit di chat CS | Server |
| ATR-42 | Lampiran chat CS bawaan: gambar JPEG/PNG/WebP/GIF maks. 10 MB (gambar besar dikecilkan), dokumen PDF/DOCX/XLSX/PPTX/TXT/CSV maks. 10 MB, video MP4/MOV/WebM maks. 25 MB dan 2 menit (5–120 detik bisa diatur); maks. 4 per pesan. Selalu ditolak: Office lama dan bermakro, arsip, program/skrip, HTML/SVG, voice note | Super Admin → Lampiran chat CS |
| ATR-43 | Pengaduan tamu: nama 2–60 karakter, Login ID opsional maks. 50, cerita 10–1.000 karakter; per perangkat 3 per jam dan 10 per hari; per Login ID 5 per hari; pesan tamu 20 per menit; sesi 24 jam | Super Admin (saklar Pengaduan tanpa login) |
| ATR-44 | Label tiket: nama maks. 30 karakter, unik, 5 warna, maks. 50 aktif, maks. 5 per tiket. Balasan cepat: judul 80, isi 2.000, maks. 50 pribadi per agen | Super Admin / agen |
| ATR-45 | Topik: sampai 8 pertanyaan awal (jawaban maks. 200 karakter), sampai 6 saran balasan (maks. 40 karakter), SOP maks. 4.000 karakter, deskripsi maks. 120 karakter | Pusat Bantuan / Super Admin |
| ATR-46 | Libur nasional dan cuti bersama menutup layanan CS; libur bursa hanya menutup pasar. Hari kerja = Senin–Jumat yang bukan hari libur (WIB) | Super Admin → Jam layanan & libur |

### 10.5 Pusat Bantuan

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-47 | Gambar sisip artikel: JPEG/PNG/WebP maks. 2 MB, hanya dari bucket resmi. Tautan hanya `https://`; HTML ditolak | Tetap |
| ATR-48 | Lampiran artikel: maks. 10 per artikel; PDF maks. 10 MB, gambar maks. 5 MB, video MP4/WebM/MOV maks. 25 MB; nama 1–120 karakter; diperiksa jenis, ukuran, dan keberadaannya saat artikel disimpan | Tetap |
| ATR-49 | Pencarian FAQ 30 per menit, umpan balik 20 per jam, komentar umpan balik maks. 500 karakter. Saran artikel per topik maks. 3; bila server tidak menjawab dalam 4 detik, tiket langsung dibuat | Server |

### 10.6 Notifikasi dan banner

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-50 | Bawaan preferensi: semua jenis aktif untuk kotak masuk dan push, kecuali push `olt.promo` dan push `followed_post` yang mati. `important` menembus preferensi dan jam tenang. Jam tenang bawaan mati | Nasabah |
| ATR-51 | Penggabungan suka/ikuti dalam 60 menit; push hanya untuk yang pertama | Server |
| ATR-52 | Siaran non-important maks. 3 per nasabah per hari WIB; dikirim bertahap 2.000 profil per putaran tiap 15 detik. Idempotensi `id` 7 hari per key. Batas bawaan key baru 3.000 permintaan per menit | Super Admin (per key) |
| ATR-53 | Bot: `body` 1–2.000 karakter; maks. 50 postingan per permintaan dan 30 per key per jam | Server |
| ATR-54 | Push: kedaluwarsa 24 jam, maks. 6 percobaan, riwayat 7 hari, perangkat kedaluwarsa setelah 270 hari tidak aktif, maks. 10 perangkat per pengguna | Server |
| ATR-55 | Banner: judul 1–120 karakter (tanda bila > 65), isi strip maks. 300, isi popup dan notifikasi info maks. 5.000 (cuplikan push ±280), label tombol maks. 24, prioritas 0–1000, sasaran pengguna baru 1–90 hari; gambar popup < 2 MB, rasio 4:5 atau 1:1; aplikasi menerima maks. 10 banner aktif; statistik disimpan 180 hari; satu event per pengguna per hari per jenis | Fitur & Banner / Super Admin |
| ATR-56 | Kampanye notifikasi Komunitas: judul 3–120, isi 3–500 karakter; tujuan ketuk kotak notifikasi, postingan resmi, atau `https://` | Tim Komunitas |
| ATR-57 | Skema deep link banner bawaan `olt`, maks. 5; skema web dan berbahaya selalu ditolak | Super Admin |

### 10.7 Staf dan Hub

| ID | Aturan | Diatur dari |
|---|---|---|
| ATR-58 | Password staf minimal 12 karakter, berbeda dari password sementara; password sementara acak hanya tampil sekali | Tetap |
| ATR-59 | Kunci akun: 3–20 kali salah (bawaan 5), lama kunci 1–1.440 menit (bawaan 15); salah dihitung dalam rentang lama kunci | Super Admin → Keamanan login |
| ATR-60 | 2FA wajib untuk Super Admin dan tidak bisa dilepas; staf yang sudah mendaftar 2FA tetap diminta kode walau perannya tidak diwajibkan; Super Admin tidak bisa mereset 2FA sendiri | Super Admin |
| ATR-61 | Keluar otomatis setelah 30 menit tidak dipakai | Hub |
| ATR-62 | Kill switch: alasan 10–500 karakter dan ketik `MATIKAN` / `NYALAKAN`; tidak mati sendiri | Super Admin / Fitur & Banner |
| ATR-63 | Nama tampilan staf 2–40 karakter dan terlihat nasabah | Super Admin |
| ATR-64 | Akun Nasabah: alasan ubah status langsung 10–200 karakter; pengajuan diputus CS lain kecuali izin approve sendiri; reset password/PIN selalu ke email terdaftar | Super Admin (izin) |
| ATR-65 | Laporan maks. 93 hari; Jejak Audit dan register kasus maks. 366 hari per permintaan | Tetap |

### 10.8 Retensi data

| ID | Data | Masa simpan bawaan |
|---|---|---|
| ATR-66 | Riwayat chat CS | 10 tahun sejak tiket terakhir ditutup (5–30, usulan, wajib dikonfirmasi Kepatuhan) |
| ATR-67 | Arsip konten terhapus dan riwayat edit (arsip regulator) | 1.825 hari (5 tahun), kecuali legal hold |
| ATR-68 | Karantina bukti | 730 hari sejak terakhir direkam/ditautkan; legal hold menangguhkan; setelah hold dilepas minimal 30 hari lagi |
| ATR-69 | Notifikasi | 90 hari |
| ATR-70 | Pesan yang dihapus | 30 hari |
| ATR-71 | Event analitik | 12 bulan |
| ATR-72 | Statistik banner | 180 hari (kecuali tayang/tutup terakhir per pengguna selama banner aktif) |
| ATR-73 | Pencarian FAQ tanpa hasil | 90 hari |
| ATR-74 | Waktu tanda terima pesan | 30 hari |
| ATR-75 | Riwayat alert sistem | 90 hari |
| ATR-76 | Riwayat push | 7 hari |
| ATR-77 | Backup | 7 harian, 4 mingguan, 6 bulanan; jendela PITR 7 hari |
| ATR-78 | Jejak Audit staf | Tambah-saja; tidak ada penghapusan otomatis yang ditemukan di kode |

## 11. Kebutuhan regulasi dan kepatuhan

Bagian ini berisi **pertimbangan**, bukan klaim kepatuhan atau sertifikasi. Penilaian kepatuhan akhir dilakukan Kepatuhan dan tim legal. Nomor dan isi ketentuan yang disebut perlu dikonfirmasi tim legal.

### 11.1 UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi (PDP)

| Prinsip/kewajiban | Yang disediakan sistem | Yang tetap perlu dilakukan organisasi |
|---|---|---|
| Dasar pemrosesan dan persetujuan | Dokumen hukum (S&K, Pedoman, Kebijakan Privasi) berversi; persetujuan per versi tersimpan dan ikut ekspor; dokumen wajib harus disetujui sebelum membuat konten (BR-PATUH-11, BR-PATUH-12) | Menyusun isi Kebijakan Privasi, menetapkan dasar pemrosesan setiap jenis data |
| Hak akses dan portabilitas | Unduh data saya (BR-AKUN-13) | Prosedur permintaan di luar aplikasi bila ada |
| Hak penghapusan | Hapus akun komunitas swalayan, pembersihan file, token push, cache (BR-AKUN-10, BR-OPS-09) | Menjelaskan pengecualian (arsip regulator, riwayat CS) di Kebijakan Privasi |
| Pembatasan tujuan dan minimisasi | Data trading tidak disimpan; analitik tanpa teks; penyamaran data sensitif di chat CS; EXIF/GPS dibuang; pencarian tanpa hasil disamarkan (BR-PATUH-14) | Menilai kebutuhan setiap data yang dikumpulkan |
| Retensi | Masa simpan per jenis data dengan penghapusan otomatis; retensi chat CS dikonfirmasi Kepatuhan (bagian 10.8) | Menetapkan dan mengonfirmasi nilai akhir |
| Keamanan | RLS di semua tabel, 2FA staf, kunci akun, pembatasan IP Hub (opsional), rahasia di Vault, enkripsi backup, pengerasan container, audit akses data | Pentest independen, pengelolaan akses fisik dan kunci |
| Akuntabilitas | Jejak Audit tambah-saja; akses kasus, transkrip, jejak layanan, DM, dan bukti tercatat | Peninjauan audit berkala |
| Insiden data | Alert sistem ke Telegram/email | Prosedur pemberitahuan kegagalan pelindungan data kepada subjek data dan otoritas sesuai UU PDP |
| Lokasi data | Self-hosted; panduan backup menyarankan bucket S3 di penyedia di Indonesia | Menetapkan kebijakan lokasi data dan transfer lintas batas (FCM, alert) |

### 11.2 Pelindungan konsumen sektor jasa keuangan (OJK)

Pertimbangan berdasarkan prinsip pelindungan konsumen OJK (antara lain POJK tentang Pelindungan Konsumen dan Masyarakat di Sektor Jasa Keuangan; nomor ketentuan berlaku dikonfirmasi legal):

| Prinsip | Yang disediakan sistem |
|---|---|
| Penanganan pengaduan yang terukur | Tanda Pengaduan, waktu diterima dan tenggat hari kerja yang diberitahukan ke nasabah, perpanjangan sekali dengan pemberitahuan, register kasus dan ketepatan waktu (BR-CS-13, BR-PATUH-03, BR-PATUH-06) |
| Akses pengaduan yang mudah | Chat CS tetap terbuka saat kill switch, ban, atau dokumen belum disetujui; pengaduan tamu tanpa login (BR-CS-36, BR-CS-38) |
| Keamanan dan kerahasiaan data konsumen | Pemblokiran permintaan OTP/PIN/password oleh staf, penyamaran data sensitif, laporan CS palsu, reset kredensial hanya ke email terdaftar (BR-CS-14, BR-CS-16, BR-CS-17, BR-HUB-18) |
| Transparansi | Disclaimer "bukan rekomendasi investasi", badge Resmi yang tidak bisa ditiru, label Bot (BR-KOM-06, BR-KOM-16, BR-KOM-19) |
| Perlakuan adil | Banding atas sanksi, peninjau berbeda, alasan wajib (BR-MOD-19) |
| Pemasaran yang bertanggung jawab | Push promo opt-in, batas siaran per hari, jam tenang, empat mata kampanye (BR-NOTIF-08, BR-NOTIF-09, BR-NOTIF-11) |

### 11.3 Integritas pasar modal

Pertimbangan terkait larangan manipulasi pasar dan informasi menyesatkan (UU Pasar Modal dan perubahannya; dikonfirmasi legal):

- Deteksi manipulasi, slow mode otomatis, penahanan posting terkoordinasi, bobot rendah akun baru di trending dan sentimen (BR-MOD-13, BR-KOM-20, BR-KOM-21).
- Frasa promosi "grup VIP"/"sinyal berbayar" diblokir; tautan messenger dan nomor HP ditahan (BR-MOD-03).
- Berbagi Trade dijeda dan tidak menyediakan copy trade, karena mendekati jasa nasihat/pengelolaan investasi (BR-TRADE-05).

### 11.4 Penyimpanan rekaman dan permintaan regulator

- Retensi chat CS bawaan 10 tahun (usulan, dikonfirmasi Kepatuhan, rentang 5–30 tahun). Kepatuhan perlu mencocokkan nilai ini dengan ketentuan penyimpanan dokumen yang berlaku.
- Arsip regulator untuk konten terhapus dan riwayat edit (5 tahun) dengan legal hold.
- Karantina bukti dengan legal hold untuk permintaan penyidik, OJK, atau sengketa, sidik SHA-256 berantai, pemeriksaan integritas, dan paket ekspor (BR-MOD-21, BR-PATUH-17).
- Transkrip bersidik SHA-256 dengan jejak unduh (BR-PATUH-07).

### 11.5 CSAM

Sistem menyediakan toleransi nol dan penyimpanan bukti (BR-MOD-18). **Kanal pelaporan ke pihak berwenang belum ditetapkan** dan harus dilengkapi tim legal sebelum produksi.

## 12. Asumsi, ketergantungan, dan batasan

### 12.1 Asumsi

| ID | Asumsi |
|---|---|
| AS-1 | Tim backend OLT menerbitkan token sosial sesuai format dan menyerahkan JWKS produksi sebelum go-live |
| AS-2 | Aplikasi OLT memasang library dengan tag rilis terbaru yang dibutuhkan fitur (lampiran artikel butuh v1.49.0) |
| AS-3 | Nasabah memakai aplikasi OLT versi yang memenuhi versi minimum per platform |
| AS-4 | Kepatuhan mengonfirmasi tenggat pengaduan, perpanjangan, retensi chat, dan menerbitkan dokumen hukum sebelum go-live |
| AS-5 | Jam server dan jam server OLT tersinkron (NTP), karena token dan 2FA bergantung pada waktu |
| AS-6 | Hub diakses dari jaringan kantor atau VPN yang ditetapkan IT |
| AS-7 | Sasaran KPI usulan disetujui manajemen setelah data awal tersedia |
| AS-8 | Proses as-is yang ditandai "asumsi" di bagian 8 divalidasi pemilik produk |

### 12.2 Ketergantungan

| ID | Ketergantungan | Dampak bila tidak tersedia |
|---|---|---|
| DP-1 | Penerbitan token sosial oleh OLT | Login baru tidak mungkin; sesi berjalan tetap jalan sampai habis |
| DP-2 | notifEngine OLT memanggil API integrasi | Tidak ada notifikasi transaksi lewat Rendezvous |
| DP-3 | csAdmin OLT dan jaringan ke csAdmin | Hanya menu Akun Nasabah terganggu; chat, tiket, Kepatuhan tidak terpengaruh. Aksi tulis ke csAdmin sungguhan belum pernah diuji |
| DP-4 | Google FCM dan kunci Firebase | Push tidak terkirim; notifikasi tetap masuk kotak notifikasi |
| DP-5 | S3 atau disk backup terpisah | Backup hanya lokal; tidak melindungi dari server hilang |
| DP-6 | Telegram/SMTP | Alert tidak terkirim keluar |
| DP-7 | Pembaruan signature ClamAV | Pemindaian berkurang mutunya; bila pemindai mati, unggahan dokumen/video ditolak |
| DP-8 | Image Supabase open source (Postgres, PostgREST, Realtime, GoTrue, Storage) | Pembaruan keamanan pihak ketiga mengikuti vendor |
| DP-9 | Siklus rilis aplikasi OLT | Fitur library baru sampai ke nasabah setelah aplikasi dirilis ulang |

### 12.3 Batasan

| ID | Batasan |
|---|---|
| BT-1 | Data trading tidak disimpan dan tidak ditampilkan server sosial |
| BT-2 | Database terkelola penyedia cloud tidak didukung |
| BT-3 | Profil produksi yang siap hanya `single` (satu server); `cluster` masih kerangka |
| BT-4 | Realtime satu instance di profil `single`; batas praktis yang teruji ±450 penerima aktif dalam satu room ramai (lebih dari itu pesan tetap sampai lewat pengisian celah, tetapi terlambat) |
| BT-5 | Klien resmi hanya library Flutter; klien lain menunggu SDK headless |
| BT-6 | Feature flag terbatas delapan kunci tetap; fitur baru butuh migrasi baru |
| BT-7 | Tab Stream terkunci ke empat tab bawaan |
| BT-8 | Restore dari backup hanya oleh tim IT dan memundurkan data semua pengguna |
| BT-9 | Kunci OLT tidak bisa diganti dari Hub |
| BT-10 | Rekomendasi ukuran server: minimum 8 vCPU / 16 GB / 200 GB NVMe; produksi awal 16 vCPU / 32 GB / 500 GB NVMe ([spesifikasi-server.md](../panduan/spesifikasi-server.md)) |

## 13. Risiko dan mitigasi

| ID | Risiko | Dampak | Kemungkinan | Mitigasi |
|---|---|---|---|---|
| R-01 | Kunci privat OLT bocor | Tinggi: token palsu atas nama nasabah | Rendah | Kunci hanya di server OLT; rotasi `kid`; token maks. 15 menit; kunci tidak bisa diganti dari Hub |
| R-02 | Akun Super Admin diambil alih | Tinggi | Rendah | 2FA wajib, kunci akun, pembatasan IP Hub (opsional), keluar otomatis, audit, Reset 2FA oleh Super Admin lain |
| R-03 | Staf meminta OTP/PIN atau menyalahgunakan data nasabah | Tinggi | Sedang | Pemblokiran server, penyamaran, catatan audit, sinyal keamanan di Ringkasan Kepatuhan, pelatihan |
| R-04 | Penipu menyamar sebagai CS | Tinggi | Sedang | Room CS resmi berbadge, akun resmi tanpa DM, laporan CS palsu P1, pesan pengingat keamanan |
| R-05 | Manipulasi pasar atau pom-pom saham lewat komunitas | Tinggi | Sedang | Deteksi otomatis, slow mode, bobot akun baru, frasa promosi, moderasi, karantina bukti |
| R-06 | Konten ilegal (CSAM, judi, pornografi) | Tinggi | Sedang | Classifier NSFW, kata terlarang, kategori domain, toleransi nol; kanal pelaporan CSAM belum ditetapkan |
| R-07 | Kebijakan konten diubah sepihak atau keliru | Sedang | Rendah | Draf, simulasi, empat mata, versi dan rollback |
| R-08 | Pengaduan lewat tenggat | Tinggi (kepatuhan) | Sedang | Tenggat terlihat, alert, Ringkasan Kepatuhan, perpanjangan sekali |
| R-09 | Pengaduan tamu dipakai untuk social engineering | Sedang | Sedang | Data akun disembunyikan, reset hanya ke email terdaftar, batas per perangkat dan per Login ID, penghitung pengaduan 24 jam |
| R-10 | Kehilangan data | Tinggi | Rendah | WAL terus-menerus, backup penuh harian terenkripsi, uji restore mingguan, alert backup |
| R-11 | Backup hanya di folder lokal | Tinggi bila server hilang | Sedang (sebelum S3 tersedia) | Peringatan di Hub, disk terpisah, salin ke luar server, pindah ke S3 |
| R-12 | Password backup hilang | Tinggi: backup tidak bisa dipulihkan | Rendah | Pernyataan wajib saat simpan, simpan di luar server |
| R-13 | Lonjakan saat pasar buka melampaui kapasitas | Sedang | Sedang | Replika, batas edge, slow mode jam ramai, alert kapasitas, pengisian celah, rencana cluster |
| R-14 | Nasabah di balik satu IP (CGNAT) terkena batas per IP | Sedang | Sedang | Batas edge untuk ±1.000 nasabah per IP; konfigurasi proxy tepercaya bila ada load balancer |
| R-15 | Aplikasi lama tidak kompatibel setelah rilis server | Sedang | Sedang | Kompatibilitas maju-mundur, versi minimum per platform, urutan rilis di catatan rilis |
| R-16 | Kill switch lupa dinyalakan kembali | Sedang | Rendah | Kill switch tidak mati sendiri; checklist pasca-gangguan |
| R-17 | Ketergantungan pada vendor image pihak ketiga dengan CVE | Sedang | Sedang | Pemindaian dependensi, pembaruan ke rilis stabil vendor |
| R-18 | csAdmin lama punya celah keamanan di luar gateway | Tinggi | Sedang | Jangan buka port csAdmin ke internet, ganti kredensial bila pernah terbuka, gateway memvalidasi filter dan pelaku |
| R-19 | Pemakaian Hub di komputer bersama | Sedang | Sedang | Keluar otomatis, keluar dari semua perangkat, sesi per tab |
| R-20 | Notifikasi massal salah kirim | Sedang | Rendah | Empat mata, perkiraan penerima, konfirmasi, izin `notify_broadcast` terpisah, batas siaran per hari |
| R-21 | Profil cluster belum siap saat pertumbuhan cepat | Sedang | Sedang | Pantau kapasitas, server lebih besar dan database terpisah, kerjakan Tahap 7 |
| R-22 | Nilai retensi dan tenggat belum dikonfirmasi Kepatuhan | Tinggi (kepatuhan) | Sedang | Spanduk "Belum dikonfirmasi" di Hub, butir checklist go-live |

## 14. Tahapan rilis dan status implementasi

### 14.1 Sudah terpasang (di server uji, migrasi sampai `0188`)

| Kelompok | Rilis penting |
|---|---|
| Fondasi sosial | Profil, postingan, komentar, reaksi, feed, chat, moderasi, realtime, storage, rate limit, privasi, polling (`0001`–`0020`) |
| Layanan nasabah | Model ambil tiket, Hub React, integrasi aplikasi, dashboard, laporan, pengaturan (Oktober 2026, `0027`–`0056`); tutup setelah rating dan laporan per nasabah (`0056`) |
| Kepatuhan | Menu Kepatuhan (`0042`), dokumen hukum (`0062`), kebijakan berversi (`0092`), karantina bukti (`0095`), akses tiket biasa 12 jam (`0125`) |
| Komunitas & keamanan konten | Menu Komunitas (`0057`), keamanan konten, permintaan DM, banding, anti-manipulasi (`0069`–`0072`), fitur sosial tahap 3 (`0073`–`0091`), moderator room (`0093`) |
| Notifikasi | Push (`0058`–`0059`), integrasi OLT (`0068`, `0086`–`0088`), banner dan popup (`0089`, `0119`), notifikasi info (`0182`–`0185`), target alert harga (`0171`) |
| Operasional | Media gateway, kesehatan sistem, backup (`0061`–`0065`, `0112`), healer (`0113`), peta layanan (`0168`), dua replika layanan sibuk (16 Nov) |
| Pusat Bantuan | Pusat Bantuan dan gambar (`0129`–`0130`), isian dan SOP topik, gangguan dan survei, laporan bantuan (`0134`–`0136`), pengaduan tamu (`0140`–`0141`, `0159`), lampiran artikel (`0188`, 22 Nov) |
| Chat lanjutan | Kelola grup (`0146`), hapus/sembunyikan/edit (`0154`–`0157`, `0179`), mention (`0172`–`0173`) |
| Akun | Hapus akun mempertahankan blokir orang lain (`0174`), jeda bergabung lagi (`0175`, `0177`) |
| Keamanan staf | 2FA wajib Super Admin dan kunci akun (`0186`, 20 Nov) |
| Kebijakan akun baru | Satu angka Masa akun baru (`0187`, 20 Nov) |

### 14.2 Dijeda

| Butir | Kondisi | Cara mengaktifkan |
|---|---|---|
| Berbagi Trade (`0160`–`0167`, `services/trade-relay`) | Menu Hub tersembunyi, relay di profil compose terpisah, tombol darurat mati | Keputusan bisnis, konfirmasi Kepatuhan, bahan dari OLT (port iProxy, frame contoh), UAT; runbook di [docs/berbagi-trade/operasional.md](../berbagi-trade/operasional.md) |

### 14.3 Rencana

| Butir | Catatan |
|---|---|
| Go-live produksi | Mengikuti [checklist-go-live.md](../panduan/checklist-go-live.md): JWKS OLT, server produksi, Hub dan staf, aplikasi OLT, Kepatuhan dan legal, uji beban setara produksi, pentest independen, review kode senior |
| Profil `cluster` (Tahap 7) | Swarm 3 manager, registry privat, SeaweedFS, replika database, cutover |
| SDK headless non-Flutter | Kotlin Multiplatform dan TypeScript; status diskusi |
| Kanal pelaporan CSAM | Ditetapkan tim legal |
| Uji aksi tulis ke csAdmin sungguhan | Setelah csAdmin baru dipasang di server |

### 14.4 Urutan rilis setiap perubahan fitur

1. Migrasi SQL dan tes pgTAP di server.
2. Halaman Hub.
3. Layar library dan rilis tag.
4. Aplikasi OLT menaikkan tag dan merilis ulang.

Server dan Hub di-update bersamaan; library dirilis terpisah dan tetap kompatibel dengan server lama.

## 15. Glosarium

| Istilah | Arti |
|---|---|
| **Akun resmi** | Akun perusahaan berbadge **Resmi**, tidak bisa login dari aplikasi, tidak menerima DM |
| **Antrean** | Daftar tiket berstatus Terbuka yang belum diambil agen |
| **Banding** | Permintaan pengguna agar sanksi atau penindakan konten ditinjau ulang |
| **Bukti (karantina bukti)** | Salinan utuh konten yang dilaporkan/dihapus untuk keperluan hukum, tambah-saja dan bersidik |
| **cust id** | Nomor rekening nasabah di OLT, dibawa klaim `accounts` token sosial |
| **Draf** | Perubahan yang tersimpan tetapi belum berlaku |
| **Empat mata** | Perubahan atau terbitan wajib disetujui staf kedua, bukan pembuatnya |
| **Hari kerja** | Senin–Jumat yang bukan hari libur di kalender layanan (WIB) |
| **Hub** | Rendezvous Hub, aplikasi web staf |
| **JWKS** | Daftar kunci publik OLT untuk memverifikasi token sosial |
| **Kill switch** | Saklar darurat untuk mematikan tulis konten dan chat non-CS bagi semua pengguna |
| **Klaim (tiket)** | Agen mengambil tiket dari antrean menjadi miliknya |
| **Legal hold** | Penanda agar bukti atau arsip tidak dihapus walau masa simpannya habis |
| **Masa akun baru** | Jumlah hari sejak daftar atau bergabung lagi yang mengendalikan semua batasan akun baru |
| **Mode pantau** | Cara kerja Super Admin di Layanan Nasabah: melihat tanpa membalas |
| **notifEngine** | Sistem notifikasi OLT yang memanggil API integrasi |
| **Notifikasi info** | Notifikasi dari Banner & Popup yang membuka halaman info berisi isi lengkap |
| **P1–P4** | Prioritas tiket; P1 paling mendesak |
| **Pengaduan** | Keluhan resmi nasabah dengan tenggat hari kerja |
| **Pengaduan tamu** | Pengaduan dari halaman login tanpa sesi dan tanpa OTP |
| **Permintaan pesan** | DM dari orang yang tidak diikuti penerima, menunggu diterima |
| **PITR** | Point-in-time recovery, pemulihan ke titik waktu tertentu |
| **RLS** | Row Level Security, aturan database yang menentukan baris mana boleh dilihat/diubah |
| **Room saham** | Ruang chat terbuka per kode saham atau indeks |
| **Sidik (SHA-256)** | Nilai hash untuk membuktikan isi atau file tidak berubah |
| **Slow mode** | Jeda wajib antarpesan di room saham |
| **Tiket** | Satu percakapan layanan nasabah, bernomor `CS-YYYYMMDD-NNNN` |
| **Token sosial** | JWT dari OLT yang membuktikan nasabah sudah login di OLT |
| **Toleransi nol** | Tindakan permanen untuk CSAM: blokir, cabut sesi, sembunyikan konten sebagai bukti |
| **Trust level** | Tingkat kepercayaan akun (0–3) yang memengaruhi batasan dan bobot |
| **Tutup otomatis** | Tiket selesai yang tidak dinilai ditutup setelah N hari |

## 16. Persetujuan

| Peran | Nama | Tanda tangan | Tanggal |
|---|---|---|---|
| Sponsor / Manajemen | | | |
| Pemilik produk | | | |
| Kepatuhan | | | |
| Kepala Layanan Nasabah (CS) | | | |
| Tim Komunitas | | | |
| Tim Pusat Bantuan | | | |
| IT / vendor | | | |
| Tim backend OLT | | | |
| Tim aplikasi OLT | | | |
