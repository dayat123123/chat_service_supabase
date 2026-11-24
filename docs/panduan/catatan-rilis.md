# Catatan Rilis untuk Operator

Langkah tambahan yang dibutuhkan saat memperbarui server ke rilis tertentu, terbaru di atas. Langkah update biasa ada di [pembaruan-sistem.md](pembaruan-sistem.md). Baca bagian rilis yang akan dipasang **sebelum** menjalankan `make up`.

Rilis yang tidak tercantum di sini cukup mengikuti langkah update biasa.

## 24 November 2026

### Notifikasi dikelompokkan ala Instagram (migrasi `0191`)

- **Like** ke post atau komentar yang sama selalu masuk ke satu notifikasi. Like baru membuat notifikasi itu belum dibaca lagi dan naik ke atas. Unlike menghapus orangnya dari daftar; bila semua unlike, notifikasinya hilang.
- **Follow** digabung selama belum dibaca, tanpa batas waktu. **Komentar** di post digabung per post, **balasan** ke komentar digabung per komentar. Mention tetap satu per kejadian. **Postingan akun yang diikuti** digabung per penulis per hari.
- Daftar notifikasi menampilkan gambar pertama post sebagai thumbnail (perlu versi library yang mendukungnya).
- **Data lama dirapikan saat migrasi:** notifikasi like ganda untuk konten yang sama dilebur menjadi satu (yang terbaru dipertahankan, pelakunya digabung). Push tidak dikirim saat migrasi.
- **Cara pasang:** `git pull --ff-only && make up`. Tidak ada perubahan Kong atau layanan Go. Aplikasi lama tetap jalan; tampilan pengelompokan dan thumbnail mengikuti pembaruan library.

## 23 November 2026

### API kesehatan sistem untuk aplikasi lain (migrasi `0189` dan `0190`, layanan `integration` 0.3.0, Hub)

- **Baru:** aplikasi internal bisa membaca isi **Kesehatan sistem** dan **Peta layanan** Hub lewat `GET /integration/v1/system/health` dan `GET /integration/v1/system/nodes`. Isinya sama dengan Hub karena memakai fungsi database yang sama: status, pemeriksaan, alert, layanan, probe, disk, database, antrean, cron, backup, serta container dengan usage CPU dan memorinya.
- **Yang tidak dikirim keluar:** alamat internal probe, lokasi backup, dan detail kanal alert (email, host SMTP, chat ID Telegram).
- **API key:** di Hub, menu **Pengaturan → API Notifikasi** kini bernama **API Integrasi** dan punya izin baru **Baca kesehatan sistem**. Setelah key dibuat, Hub langsung menampilkan alamat endpoint dan contoh request. Key hanya bisa membaca, bisa dibatasi IP, dan dicabut kapan saja.
- **Kontrak:** tag **Kesehatan sistem** di `docs/api/openapi.yaml` dan bagian 4a [docs/integration/README.md](../integration/README.md).
- **Halaman API Integrasi dirapikan (migrasi `0190`):** tabel API key tetap satu, sedangkan statistik dan panduan dipisah menjadi bagian **Notifikasi & bot** dan **Kesehatan sistem**. Statistik notifikasi hanya menghitung key notifikasi dan bot. Key yang sudah dicabut kini bisa **Dihapus** dari daftar; datanya disembunyikan, bukan dibuang, dan penghapusan tercatat di Jejak Audit.
- **Panduan khusus:** [docs/integration/kesehatan-sistem.md](../integration/kesehatan-sistem.md) (ada versi PDF) dan kontrak [docs/api/kesehatan-sistem.openapi.yaml](../api/kesehatan-sistem.openapi.yaml).
- **Lebih sederhana untuk semua API integrasi:** `/integration/v1` (notifikasi, bot, kesehatan sistem) kini cukup memakai header `Authorization: Bearer oik_…`. Header `apikey` (anon key) tidak wajib lagi. Sistem yang masih mengirimnya, seperti notifEngine OLT, tetap berjalan tanpa perubahan.
- **Cara pasang:** `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`. `make up` membangun ulang image `integration` 0.3.0. Karena konfigurasi Kong berubah, buat ulang Kong sekali sesudahnya: `docker compose -f docker/compose.yml -f docker/compose.dev.yml up -d --force-recreate kong` (profil produksi: `compose.prod.yml`). Aplikasi nasabah tidak perlu diperbarui.

## 22 November 2026

### Lampiran PDF, gambar, dan video di artikel Pusat Bantuan (migrasi `0188`, Hub, library 1.49.0)

- **Baru:** di **Pusat Bantuan → Artikel bantuan**, editor artikel punya bagian **Lampiran**. Staf bisa memasang sampai **10 file** per artikel:
  - PDF, maksimal 10 MB;
  - gambar JPEG, PNG, atau WebP, maksimal 5 MB (gambar yang lebih besar diperkecil otomatis);
  - video MP4, WebM, atau MOV, maksimal 25 MB.
- Nama lampiran bisa diubah, urutannya bisa dinaikkan atau diturunkan, dan lampiran bisa dihapus. Lampiran tampil di **Pratinjau di aplikasi** dan di dialog **Sisipkan artikel FAQ** milik agen CS. Lampiran sama untuk kedua bahasa dan ikut tersimpan di riwayat versi, sehingga **Pulihkan** versi lama membawa lampirannya kembali.
- **Di aplikasi nasabah** (library 1.49.0): lampiran tampil di bawah jawaban. Gambar dibuka di layar penuh, video diputar di aplikasi, PDF dibuka dengan aplikasi bawaan perangkat. Aplikasi yang belum diperbarui tetap menampilkan artikel seperti biasa, hanya tanpa lampiran.
- **Keamanan:** file disimpan di bucket publik baru `faq-files` dengan nama acak. Hanya staf Super Admin dan Pusat Bantuan yang bisa mengunggah. Server memeriksa jenis, ukuran, dan keberadaan setiap file saat artikel disimpan, sehingga tautan ke situs lain tidak bisa dipasang sebagai lampiran.
- **Cara pasang:** `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`. Agar nasabah bisa melihat lampiran, aplikasi OLT perlu memakai library `v1.49.0`.

## 20 November 2026

### Satu pengaturan untuk semua batasan akun baru (migrasi `0187`, Hub)

- **Sebelumnya:** walaupun **Masa akun baru** diisi 0 hari, akun yang baru daftar atau bergabung lagi tetap dibatasi 24 jam pertama (tingkat kepercayaan 0). Angka 24 jam itu tidak ada di Hub, sehingga misalnya Share P/L dari akun yang baru daftar ditolak sehari.
- **Sekarang:** kartu **Masa akun baru** (Kepatuhan → Kebijakan konten → tab Kategori) mengatur semuanya:
  - gambar di postingan, komentar, DM, grup, dan room saham, termasuk Share P/L;
  - tautan selain domain tepercaya;
  - DM ke orang yang tidak saling mengikuti lewat Permintaan pesan;
  - batas kecepatan kirim separuh dari akun biasa.
- **0 hari** berarti akun baru langsung bebas sejak daftar. Masa dihitung sejak daftar, atau sejak bergabung lagi setelah dihapus. Kartu di Hub kini menyebut semua yang dikendalikan, yang tetap boleh, dan siapa yang tidak terkena.
- **Dampak setelah pasang:**
  - Server dengan masa 0 hari: akun yang sedang tertahan di masa 24 jam langsung bebas.
  - Server dengan masa lebih dari 0 (bawaan 3 hari): batas kecepatan separuh kini berlaku selama masa itu, bukan hanya 24 jam pertama.
- **Cara pasang:** `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`. Aplikasi nasabah tidak perlu diperbarui.

### 2FA wajib untuk Super Admin dan kunci akun staf (migrasi `0186`, Hub, nasabah-gateway)

- **Baru:**
  - **2FA (TOTP)** wajib untuk Super Admin. Peran lain bisa ikut diwajibkan dari Hub, di **Pengaturan → Keamanan login**.
  - Staf yang belum mendaftar diminta memindai kode QR saat login berikutnya. Staf yang sudah mendaftar diminta 6 digit kode dari aplikasi authenticator setiap kali masuk.
  - **Kunci akun:** setelah 5 kali password salah (bawaan), akun staf dikunci 15 menit (bawaan), dan password yang benar pun ditolak. Kedua angka bisa diubah di Hub. Setiap penguncian tercatat di Jejak Audit.
  - **Akun CS** menampilkan status 2FA dan akun terkunci, serta tombol **Buka kunci** dan **Reset 2FA** untuk staf lain.
  - 2FA ditegakkan di server, bukan hanya di tampilan Hub: RPC staf dan menu Akun Nasabah menolak sesi Super Admin yang belum memasukkan kode.
- **Dampak setelah pasang:** semua Super Admin, termasuk yang sedang masuk, langsung diminta mendaftarkan 2FA. Siapkan aplikasi authenticator di HP masing-masing sebelum update. Jam server harus tersinkron (NTP), karena kode berganti setiap 30 detik.
- **Darurat** (Super Admin terakhir kehilangan HP): `make cs-mfa-reset EMAIL=nama@perusahaan.co.id` (Windows: `.\make.ps1 cs-mfa-reset -Email ...`, tambahkan `PROFILE=single` / `-Profile single` di produksi). Perintah ini menghapus 2FA dan membuka kunci akun itu, lalu tercatat di audit.
- **Server dev:** jalankan `make cs-staff` lagi setelah update. Akun dev Super Admin (Sinta, Adi) mendapat authenticator dev yang rahasianya ditulis sebagai `totp_secret` di `scripts/cs-demo/runtime/staff.json`, dan E2E Hub memakainya otomatis.
- **Cara pasang:** `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`. `make up` sekaligus membangun ulang `nasabah-gateway` dan menyalakan hook kunci akun di layanan login. Aplikasi nasabah tidak perlu diperbarui.

## 19 November 2026

### Popup dan notifikasi info saling terhubung (migrasi `0185`)

- **Perbaikan:** nasabah yang sudah melihat popup Banner & Popup masih melihat notifikasi info untuk banner yang sama sebagai belum dibaca, dan angka di lonceng tidak berkurang.
- **Sekarang:**
  - Popup yang tampil, atau klik tombol pada banner apa pun, menandai notifikasi info banner itu sebagai terbaca, dan angka lonceng langsung berkurang. Strip yang sekadar tayang tidak menandai terbaca.
  - Sebaliknya, nasabah yang sudah membuka notifikasi info dianggap sudah melihat popupnya, jadi popup "Sekali per pengguna" tidak muncul lagi untuknya. **Tandai semua terbaca** tidak dihitung, supaya popup yang belum pernah dilihat tetap muncul.
- **Cara pasang:** `git pull --ff-only && make up`. Tidak perlu memperbarui aplikasi.

### Teks banner dan notifikasi lebih panjang (migrasi `0184`, Hub, library 1.43.0)

- **Batas baru:**

  | Isian | Sebelumnya | Sekarang |
  |---|---|---|
  | Judul banner dan notifikasi info | 80 | 120 |
  | Isi strip | 300 | 300 (tetap) |
  | Isi popup dan notifikasi info | 300 | 5.000 |
  | Judul notifikasi Komunitas | 80 | 120 |
  | Isi notifikasi Komunitas | 240 | 500 |

- Hub memberi tanda bila judul lebih dari 65 karakter, karena bagian setelahnya bisa terpotong di notifikasi ponsel.
- **Notifikasi info dengan isi panjang:** daftar notifikasi dan push hanya membawa cuplikan ±280 karakter. Saat diketuk, aplikasi (library 1.43.0) membuka halaman info dan memuat isi lengkapnya dari server. Aplikasi dengan library lama menampilkan cuplikan yang diakhiri "…". Cara ini menjaga push tetap di bawah batas 1.000 karakter dan database tidak membesar karena isi panjang disalin ke setiap nasabah.
- **Cara pasang:** perbarui server dan Hub lalu `make up`:
  `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`
  App OLT pindah ke library `ref: v1.43.0`.

### Frekuensi banner berlaku per akun dan rasio gambar popup (migrasi `0183`, Hub, library 1.41.0)

- **Perbaikan:** banner **Sekali per pengguna** (strip maupun popup) muncul lagi setiap nasabah logout lalu login. Penyebabnya, aplikasi hanya mencatat riwayat tayang di perangkat, dan catatan itu memang dihapus saat logout. Banner yang sudah ditutup nasabah juga muncul lagi dengan cara yang sama.
- **Sekarang:**
  - Server mengirim ke aplikasi kapan banner terakhir tampil dan ditutup untuk nasabah yang login, diambil dari statistik tayang yang sudah dicatat.
  - Frekuensi **Sekali per pengguna** dan **Sekali sehari**, serta strip yang ditutup, berlaku per akun: tetap berlaku setelah login ulang, instal ulang, atau di perangkat lain.
  - Setelah login, aplikasi menunggu data banner milik akun itu sebelum menampilkan strip atau popup.
- **Rasio gambar popup:** pilihan **4:5** atau **1:1** saat memotong gambar kini disimpan dan dikirim ke aplikasi, sehingga bentuk popup mengikuti pilihan itu. Sebelumnya rasio hanya dipakai untuk memotong, dan aplikasi menampilkan kotak gambar dengan bentuk yang sama. Popup lama yang belum punya rasio tersimpan tetap memakai bentuk dari gambarnya; buka dan simpan ulang dengan memilih gambar lagi bila ingin rasionya pasti.
- **Retensi statistik:** event tetap dihapus setelah 180 hari, kecuali tayang dan tutup terakhir tiap nasabah pada banner yang masih aktif, supaya banner **Sekali per pengguna** yang tayang lebih dari 180 hari tidak muncul lagi.
- **Riwayat yang sudah ada ikut terpakai:** nasabah yang sudah melihat banner sebelum pembaruan tidak akan melihatnya lagi, selama tayangannya sudah tercatat di statistik. Tayangan strip baru tercatat sejak library 1.39.0.
- **Cara pasang:**
  1. Perbarui server dan Hub, lalu jalankan `make up`:
     `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`
  2. App OLT pindah ke library `ref: v1.41.0`.
  Aplikasi dengan library lama tetap berjalan seperti sebelumnya.

## 18 November 2026

### Notifikasi info dari Banner & Popup (migrasi `0182`, Hub, library 1.40.0)

- **Notifikasi dari banner tidak lagi lewat Komunitas.** Sakelar **Kirim juga sebagai notifikasi** kini mengirim notifikasi info langsung ke daftar notifikasi dan push semua nasabah sasaran banner, tanpa akun resmi dan tanpa persetujuan di Komunitas → Notifikasi. Ajuan lama dari banner yang masih menunggu di Komunitas dibatalkan otomatis oleh migrasi.
- **Konfirmasi dan status:**
  - Sebelum simpan, Hub menampilkan perkiraan jumlah penerima.
  - Baris banner menampilkan status notifikasinya (terjadwal, sedang dikirim, terkirim ke N nasabah, dibuka, diketuk), dengan tombol **Batalkan notifikasi** selama belum selesai.
- **Halaman info di aplikasi:** mengetuk notifikasinya, dari daftar maupun dari push, membuka halaman info berisi judul, waktu, gambar, isi, dan tombol tautan banner (termasuk deep link aplikasi). Tampilannya bisa diganti lewat builder `system.notice` di library.
- **Empat mata opsional:**
  - Ada sakelar baru di **Pengaturan → Persetujuan → Aturan empat mata**, bawaannya mati.
  - Bila dinyalakan, Super Admin atau staf Fitur & Banner lain menyetujui atau menolak dari baris banner.
  - Menu Pengaturan "Aturan persetujuan" kini bernama **Aturan empat mata** di grup **Persetujuan**, dan kartu empat mata Komunitas bernama **Empat mata Komunitas**.
- **Peran:**
  - Tidak ada peran baru. Yang bisa mengirim, menyetujui, dan membatalkan sama dengan yang bisa mengelola banner: Super Admin dan Fitur & Banner.
  - Yang mengubah aturan empat matanya hanya Super Admin. Semua tindakan tercatat di Jejak Audit (`banner.notice_*`).
- **Penerima:** semua nasabah yang pernah membuka fitur komunitas di aplikasi (punya profil), sesuai sasaran banner (semua pengguna atau pengguna baru). Akun resmi dan akun staf tidak menerima.
- **Cara pasang:**
  1. Perbarui server dan Hub, lalu jalankan `make up`:
     `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`
  2. App OLT pindah ke library `ref: v1.40.0`.
  App lama tetap menampilkan notifikasinya di daftar notifikasi, tetapi mengetuknya tidak membuka halaman info.

### Frekuensi dan statistik banner strip (migrasi `0181`, Hub, library 1.39.0)

- **Strip punya frekuensi seperti popup:** Sekali per pengguna, Sekali sehari, atau Setiap buka aplikasi. Strip yang sudah muncul tetap tampil sampai aplikasi ditutup, setelah itu mengikuti frekuensinya. Migrasi menyetel strip lama ke **Setiap buka aplikasi** supaya perilakunya tidak berubah diam-diam; ubah lewat Hub bila perlu.
- **Statistik tayang strip kini bertambah:** sebelumnya library hanya mencatat popup, jadi strip selalu 0 tayang. Library 1.39.0 mencatat tayang (sekali per banner per buka aplikasi), klik tombol, dan tutup.
- **Bilah menu atas Hub:** kotak cari mengecil bila menu banyak, lalu menjadi ikon saja. Tanda Ctrl K tidak lagi terpotong. Ctrl K tetap bisa dipakai kapan saja.
- **Cara pasang:**
  1. Perbarui server dan Hub, lalu jalankan `make up`:
     `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`
  2. App OLT pindah ke library `v1.39.0` (`ref: v1.39.0`).
  App lama tetap menampilkan strip setiap kali dan tidak mengirim statistik strip.

### Form akun staf dirapikan (Hub)

- Setiap kartu **Peran** kini menjelaskan menu yang dibukanya.
- **Super Admin** sudah termasuk **Fitur & Banner** dan **Pusat Bantuan**. Saat Super Admin dicentang, kedua peran itu tampil terkunci dan tidak disimpan terpisah. Akses tidak berubah, karena server memang sudah menerima Super Admin untuk menu tersebut.
- Kartu **Komunitas** dihapus. Akun yang hanya diberi Izin Komunitas otomatis menjadi staf Komunitas.
- **Tim**, **Batas tiket aktif**, dan **Akses Akun Nasabah** dikelompokkan di **Pengaturan CS** dan hanya muncul untuk peran CS.
- Grup **Akses Akun Nasabah**, **Izin Komunitas**, dan **Izin Berbagi Trade** punya tombol **Pilih semua** dan **Kosongkan**.
- Peran lama yang tersimpan berlebih, misalnya Super Admin yang juga punya Fitur & Banner, dirapikan saat akun itu disimpan lagi.
- Cukup perbarui Hub (`git -C ~/rendezvous_hub pull --ff-only && make up`). Tidak ada perubahan server.

### Banner sekaligus notifikasi, Tab Stream tetap empat tab (migrasi `0180`, Hub)

- **Banner baru bisa sekaligus menjadi notifikasi.** Form Tambah banner punya sakelar **Kirim juga sebagai notifikasi**, bawaan menyala. Saat disimpan, server membuat ajuan kampanye notifikasi dengan judul, isi, tautan `https://`, dan sasaran yang sama. Pengirimnya akun resmi aktif yang paling lama dibuat. Notifikasi baru masuk ke kotak notifikasi dan push nasabah setelah disetujui staf lain di **Komunitas → Notifikasi**. Deep link aplikasi tidak ikut.
  - Perlu minimal satu akun resmi aktif. Bila belum ada, simpan banner ditolak dengan pesan yang menjelaskannya. Buat akun resmi di **Komunitas → Akun resmi**, atau matikan sakelarnya.
  - Mengubah banner lama tidak membuat notifikasi.
- **Tab Stream dikunci ke empat tab bawaan**: Terbaru, Teratas, Grafik & Media, dan Polling, dengan urutan tetap. Di **Komunitas → Tab Stream** tab hanya bisa dinyalakan atau dimatikan.
  - Migrasi menghapus tab tambahan yang pernah dibuat dan mengembalikan nama, isi, ikon, dan urutan keempat tab ke bawaan. Status nyala/mati yang sudah diatur tetap.
  - Instalasi baru langsung berisi empat tab itu.
- **Cara pasang:** perbarui server dan Hub bersamaan, lalu jalankan `make up`, yang memasang migrasi dulu lalu membangun ulang Hub:
  `git pull --ff-only && git -C ~/rendezvous_hub pull --ff-only && make up`
  Hub lama tidak bisa mengubah Tab Stream setelah migrasi ini, dan Hub baru butuh migrasi ini. Aplikasi dan library tidak perlu diperbarui.

### Nama menu Hub disesuaikan dengan isinya (Hub)

- **Konten Layanan** menjadi **Pusat Bantuan** (tab **Topik chat CS** dan **Artikel bantuan**, dulu tab "Pusat Bantuan").
- **Fitur & Kampanye** dipecah supaya sejenis dengan isinya:
  - Tab **Fitur & versi** dan **Tab Stream** pindah ke menu **Komunitas** (tab terakhir sebelum Analitik).
  - Sisanya menjadi menu **Banner & Popup** (kampanye banner strip dan popup promo).
  - Tab **Stream** di Komunitas berganti nama menjadi **Postingan resmi**, supaya tidak tertukar dengan Tab Stream.
- Nama peran staf **Fitur & Kampanye** menjadi **Fitur & Banner**. Hak aksesnya tetap: Super Admin dan peran ini saja yang bisa mengubah fitur, versi minimum, tab Stream, dan banner (server juga menolak peran lain). Peran ini kini bisa membuka menu Komunitas, tetapi hanya melihat dua tab tersebut, tanpa angka moderasi. Staf Komunitas tanpa peran ini tidak melihat kedua tab itu.
- Tautan dan bookmark lama dialihkan otomatis ke letak barunya.
- Cukup perbarui Hub (`git -C ~/rendezvous_hub pull --ff-only && make up`). Tidak ada perubahan server.

### Menu Hub dirapikan (Hub)

- **Kata terlarang** pindah menjadi tab pertama di **Kebijakan konten**. Alamat lama dialihkan otomatis.
- Menu **Kebijakan** berganti nama menjadi **Tenggat & retensi** (tenggat pengaduan, perpanjangan, retensi chat), supaya tidak tertukar dengan Kebijakan konten.
- Untuk akun Kepatuhan yang juga punya menu lain (misalnya Super Admin), semua menu Kepatuhan digabung dalam satu menu bertingkat **Kepatuhan ▾**, sehingga bilah menu atas tidak terpotong. Akun yang hanya Kepatuhan tetap melihat menunya berjajar.
- Cukup perbarui Hub (`git -C ~/rendezvous_hub pull --ff-only && make up`). Tidak ada perubahan server.

### Pratinjau daftar chat setelah pesan dihapus (migrasi `0179`)

- Sebelumnya, setelah pesan terakhir dihapus, di dalam chat tertulis "[pesan dihapus]" tetapi daftar chat masih menampilkan isi pesan lama.
- Sekarang pratinjau di daftar chat berganti menjadi "[pesan dihapus]", dan daftar chat yang sedang terbuka langsung diperbarui. Ini berlaku juga untuk pesan yang dihapus moderator atau ikut terhapus bersama akun.
- Room yang pratinjaunya sudah telanjur memuat pesan terhapus ikut diperbaiki saat migrasi. Aplikasi tidak perlu diperbarui.

### Kata terlarang yang sudah disetujui tetap lolos (migrasi `0178`)

- Pola pencocokan kata terlarang, frasa promosi, pengecualian, dan domain (`private.policy_patterns`, `private.policy_forms`) bisa tertinggal dari isi daftar. Penyebabnya percobaan yang gagal sebelum `0176`, atau data hasil restore/seed. Akibatnya kata yang sudah disetujui tetap lolos di Uji teks dan di app.
- `0178` membangun ulang semua pola saat `make up`. Tes `155` memastikan pola selalu sesuai dengan daftar.
- Untuk memperbaiki tanpa menunggu update: `docker exec olt-social-db-1 psql -U postgres -c "select private.rebuild_policy_patterns(p) from unnest(array['words', 'promo', 'allow', 'domains']) p"`

### Akun yang baru dihapus tidak bisa muncul lagi lewat Coba lagi (migrasi `0177`)

- Sebelumnya, dalam 60 detik setelah hapus akun, menekan Coba lagi di app bisa membuka komunitas lagi dengan akun yang sudah terhapus. Penyebabnya: auth-bridge menyimpan hasil login sebentar di cache (`VERIFY_CACHE_TTL`, 60 detik), jadi masa tunggu baru terasa setelah login ulang.
- Sekarang server menolak setiap request dari akun komunitas yang sudah dihapus (`403 account_rejoin_cooldown`), dari mana pun sesinya didapat. App menampilkan "Akun komunitas Anda baru saja dihapus" dan tombol Hubungi CS sampai masa tunggu habis.
- Migrasi berjalan otomatis lewat `make up`. Aplikasi tidak perlu diperbarui.

### Perbaikan kebijakan konten di Hub (migrasi `0176`, Hub, library 1.38.1)

- **Error "UPDATE requires a WHERE clause" diperbaiki.** Sebelumnya setiap perubahan Kata terlarang, frasa promosi, pengecualian, atau domain dari Hub gagal dengan error ini, jadi daftarnya tidak pernah bertambah. Setelah update, **tambahkan ulang** kata atau domain yang tadi gagal disimpan.
- **Kata terlarang tidak terisi otomatis.** Uji teks dan penyaringan hanya mencocokkan kata yang ada di daftar. Kata kasar, porno, atau judi yang belum dimasukkan ke menu Kata terlarang tetap lolos.
- **Draf belum berlaku.** Semua perubahan kebijakan masuk ke draf. Draf baru berlaku setelah diajukan di tab Versi & persetujuan dan disetujui staf Kepatuhan lain (empat mata). Selama itu, nilai lama tetap berlaku, misalnya jeda 72 jam walaupun draf berisi 0.
- **Tampilan lebih jelas:**
  - kartu Masa akun baru dan Jeda bergabung lagi kini menjelaskan dampaknya bagi nasabah;
  - kartu itu menampilkan nilai yang berlaku sekarang di samping nilai di draf;
  - ada terjemahan jam ke hari (72 jam = 3 hari) dan tombol pilihan cepat;
  - Uji teks menampilkan kesimpulan dalam bahasa biasa, menyebut jumlah kata dan frasa di daftar, dan memberi peringatan bila ada draf yang belum berlaku.
- **App yang sedang terbuka** (library 1.38.2) memeriksa ulang jeda paling lama 30 detik setelah penolakan terakhir, atau saat nasabah menekan Coba lagi setelah itu. Dengan 1.38.1, Coba lagi dalam 5 menit masih memakai penolakan lama. Layar "akun baru dihapus" punya tombol Coba lagi di samping Hubungi CS.
- `make up` memasang migrasi dan membangun ulang Hub. Tidak ada pengaturan baru.

### Jeda bergabung lagi setelah hapus akun (migrasi `0175`, auth-bridge, library 1.38.0, Hub)

- Setelah menghapus akun komunitas, login yang sama baru bisa membuka komunitas lagi setelah **72 jam**. Saat bergabung lagi, akun dimulai sebagai akun baru.
- Lama jeda diatur di Hub: menu **Kebijakan konten** (`/compliance/content`) → tab **Kategori** → kartu **Jeda bergabung lagi setelah hapus akun**, di bawah kartu "Masa akun baru" (0–720 jam, 0 = tanpa jeda). Perubahannya lewat draf dan persetujuan staf Kepatuhan lain, sama seperti kebijakan konten lain.
- Selama jeda, app menampilkan sisa waktunya dan tombol **Hubungi CS** yang membuka pengaduan tamu. Chat CS di dalam app ikut tertutup, sama seperti akun yang di-ban. Akun yang di-ban kini juga mendapat pesan yang jelas, bukan error umum.
- `make up` memasang migrasi dan membangun ulang auth-bridge sekaligus. Tidak ada pengaturan di `docker/.env` atau container baru. Pasang server lebih dulu, baru aplikasi dengan library 1.38.0. Aplikasi lama tetap ditolak selama jeda, hanya saja dengan pesan error umum.
- Jeda berlaku juga untuk akun yang dihapus sebelum rilis ini, dihitung dari waktu hapusnya.

### Blokir tetap berlaku setelah hapus akun (migrasi `0174`)

- Sebelumnya, pengguna yang diblokir bisa menghapus akun komunitas lalu login lagi, dan blokir dari orang lain terhadap dirinya ikut hilang. Sekarang blokir dan mute dari orang lain tetap disimpan dan berlaku lagi saat ia login kembali.
- Blokir yang hilang karena hapus akun sebelum rilis ini tidak bisa dipulihkan. Pengguna yang terdampak perlu memblokir ulang.
- Migrasi berjalan otomatis lewat `make up`. Aplikasi tidak perlu diperbarui.

### Mention di grup (migrasi `0173`, library 1.36.0)

- Di chat grup, pengguna bisa menyebut anggota grup dengan `@`. Saran nama hanya berisi anggota grup itu, dan `$KODE` di grup tetap mati.
- Anggota yang disebut mendapat notifikasi "X menyebut Anda di <grup>" sebagai pengganti notifikasi pesan biasa, walaupun ia membisukan grup itu. Pengaturan "Siapa yang bisa menyebut saya" tetap dihormati.
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan atau container baru. `0172` dan `0173` boleh terpasang dalam satu kali update.
- Aplikasi dengan library 1.35.0 tetap jalan, hanya tanpa saran `@` di grup.

### Pengaturan mention (migrasi `0172`, library 1.35.0)

- Pengguna bisa memilih siapa yang boleh menyebut dirinya: semua orang (bawaan), hanya yang ia ikuti, atau tidak ada. Mention dari orang yang tidak diizinkan tidak memberi notifikasi, dan namanya tidak muncul di saran `@`. Teks `@nama` di postingan tetap tampil apa adanya.
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan, container, atau API key baru.
- Pasang server lebih dulu, baru aplikasi dengan library 1.35.0. Aplikasi lama tetap jalan tanpa pilihan ini, dan aturan notifikasi sudah berlaku untuk semua aplikasi karena ditegakkan di server.
- Di library 1.35.0, mention `@` dan `$KODE` hanya aktif di room saham. Di chat langsung, grup, dan chat CS keduanya menjadi teks biasa.

### Notifikasi ke satu login untuk alert harga (migrasi `0171`)

- API notifikasi OLT menerima target baru `{"olt_user_id": "..."}`: satu login, dikirim langsung, cukup izin `notify`, dan tidak kena batas 3 siaran per hari. Dipakai untuk alert harga yang dipasang pengguna di app OLT. Rinciannya untuk tim OLT ada di [docs/integration](../integration/README.md#2c-satu-login-targetolt_user_id-alert-harga).
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan, container, atau API key baru; key `notify` yang sudah ada langsung bisa dipakai.
- Target lama (`cust_id`, `olt_user_ids`, `audience`) tidak berubah. Aplikasi tidak perlu diperbarui.

## 17 November 2026

### Kontrol komentar (migrasi `0169`, library 1.31.0)

- Pemilik post bisa mematikan komentar atau membatasi siapa yang boleh berkomentar. Semua post lama tetap terbuka untuk semua orang.
- Migrasi berjalan otomatis lewat `make up` (atau `make migrate`). Tidak ada pengaturan baru di `docker/.env` dan tidak ada container baru.
- Pasang server lebih dulu, baru aplikasi dengan library 1.31.0. Aplikasi dengan library lama tetap jalan: pilihan komentar tidak tampil, dan komentar ke post yang dimatikan ditolak dengan pesan error umum.
- Komentar yang disembunyikan tidak dihapus. Hub tetap bisa melihat dan memoderasinya.

### Matikan komentar di semua postingan (migrasi `0170`, library 1.33.0)

- Saklar baru di pengaturan komunitas: pengguna bisa mematikan komentar di semua postingannya sekaligus. Pengaturan per post tidak diubah, jadi saat saklar dimatikan setiap post kembali ke pengaturannya sendiri.
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan atau container baru. `0169` dan `0170` boleh terpasang dalam satu kali update.
- Aplikasi dengan library 1.31.0–1.32.0 tetap jalan tanpa saklar ini. Post milik pengguna yang menyalakan saklar tetap tertutup untuk semua klien karena aturannya ditegakkan di server.

## 16 November 2026

### Kesehatan sistem pindah ke Pengaturan (Hub)

- Kesehatan sistem kini ada di **Pengaturan → Sistem → Kesehatan sistem** (di atas Backup dan Alert), berisi tab Peta layanan, Status, dan Restart otomatis. Menu "Kesehatan sistem" di bar atas dihapus.
- Bila ada alert gangguan, angka merah tampil di menu **Pengaturan**.
- Alamat lama `/system` dialihkan otomatis untuk Super Admin.
- Cukup `git pull` di `rendezvous_hub` lalu `make up`.

### Peta layanan (migrasi `0168`, healer 0.2.0, sentinel 0.5.0)

- Healer membaca daftar semua container (hanya baca) dan menulis `nodes.json`; sentinel meneruskannya ke database setiap ±10 detik. Hasilnya tampil di tab **Peta layanan**.
- Batas healer naik menjadi 0,25 CPU / 48 MB. Pengaturan baru (opsional) `HEALER_NODES_FILE` dan `HEALER_NODES_SECONDS`; kosongkan `HEALER_NODES_FILE` untuk mematikan.
- `make up` membangun ulang healer dan sentinel. Data peta muncul ±20 detik setelah keduanya berjalan.
- Profil cluster belum didukung (healer tidak berjalan di Swarm).

### Dua replika untuk layanan sibuk

- `rest`, `auth-bridge`, `media`, `classifier`, `imgproxy`, dan `integration` kini berjalan 2 replika. Jumlahnya diatur `*_REPLICAS` di `docker/.env` ([skalabilitas.md](skalabilitas.md#replika-di-profil-dev-dan-single)).
- Batas RAM semua container naik ±2,5 GB. Pastikan server punya ruang ([spesifikasi-server.md](spesifikasi-server.md)).
- Pool PgBouncer bawaan naik dari 20 ke 24. Bila `docker/.env` mengisi `PGBOUNCER_DEFAULT_POOL_SIZE` sendiri, nilainya harus ≥ 22 (2 × 11).

### Jenis notifikasi Berbagi Trade disembunyikan (migrasi `0167`)

- `trade_activity` dan `trade_share` hanya muncul di pengaturan notifikasi aplikasi bila Berbagi Trade dinyalakan. Sebelumnya aplikasi dengan library lama menampilkannya sebagai kode mentah.
- Tidak ada langkah tambahan; migrasi berjalan otomatis.

## 15 November 2026

### Berbagi Trade (migrasi `0160`–`0166`), dijeda

- Fitur Berbagi Trade dan layanan relay trade ada di repo tetapi **tidak aktif**: menu Hub disembunyikan (`SHOW_TRADE_SHARE = false`), container `trade-relay` dan `dummy-iproxy` berada di profil compose `trade-relay` sehingga tidak ikut `make up`, dan tombol darurat `trade_share.enabled` mati.
- Bila server sempat menjalankan relay sebelum dijeda, matikan sekali: `docker stop olt-social-trade-relay-1`.
- Cara mengaktifkan lagi: [docs/berbagi-trade/operasional.md](../berbagi-trade/operasional.md).

## Rilis sebelumnya

### 4 November 2026 — Batas CGNAT dan latensi alert (migrasi `0108`, sentinel 0.3.0, PgBouncer `1.24.0-5`)

sebelum `make up`, periksa `docker/.env` server. Baris `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` atau `EDGE_WS_PER_IP` yang lebih kecil dari 1.000 (mis. sisa 30/300/150 dari rilis lama) membuat `check-config` profil `single`/`cluster` gagal; hapus barisnya agar default baru (1.500) dipakai. Traefik kini dibatasi 768M (sebelumnya 256M). PgBouncer dan sentinel di-build ulang otomatis oleh `make up`.

### 4 November 2026 — Image pihak ketiga (T5)

Postgres `17.6.1.136` → `17.11.0.008` (PostgreSQL 17.6 → 17.11, major sama, tanpa dump/restore), Realtime `v2.148.6`, Storage `v1.84.32`, Studio `2026.10.26-sha-478bd88`, edge-runtime `v1.77.9`, Kong `3.9.4`, Traefik `v3.7.16`. Rincian dan alasan per image: [laporan uji 12.7](../testing/report-2026-11-03.md#127-t5-versi-image-pihak-ketiga-4-nov).

- Wajib `make backup PROFILE=single` sebelum `make up`. Image `db` berganti, jadi `db` dan layanan yang bergantung padanya dibuat ulang. Di dev, semua service healthy lagi dalam ±2 menit.
- PostgreSQL 17.11 hanya mengizinkan output plugin di `output_plugin_libraries`. `postgresql.conf` image sudah berisi `pgoutput, test_decoding, wal2json`. Bila config Postgres diganti sendiri, `wal2json` wajib ada; tanpa itu `postgres_changes` Realtime berhenti.
- Tidak perlu `REINDEX`: tidak ada `btree_gist`, `comments.path` (ltree) jauh di bawah 14.653 label, dan tidak ada fungsi kita yang memakai PGP pgcrypto.
- Volume `db-config` (`/etc/postgresql-custom`) tidak diperbarui otomatis. Isinya tetap berkas image lama (`supautils.conf`, `extension-custom-scripts/`, tanpa `conf.d/pg_net.conf`), sama seperti upstream. Server baru mendapat versi baru. Jangan hapus volume ini (berisi `pgsodium_root.key`).
- `make up --wait` bisa gagal sekali dengan `rest is unhealthy`: PgBouncer ikut dibuat ulang, listener PostgREST mundur 8 → 16 → 32 dtk, dan `/ready` 503 ±70 dtk. Tunggu sebentar, lalu jalankan `make up` lagi.
- Storage `v1.84.32` tidak menambah migrasi internal (terakhir tetap `74 unlock-object-versioning`), jadi kembali ke `v1.81.0` masih aman.
- Realtime `v2.148.6` memakai Phoenix 1.8.15: pesan WebSocket dengan `join_ref` yang tidak cocok dengan join channel diabaikan diam-diam. Klien Dart (`realtime_client`) dan realtime-js aman. Klien buatan sendiri wajib mengirim `join_ref` = `ref` dari `phx_join` channel itu.

### Alert kapasitas (migrasi `0104`, sentinel 0.2.0, PgBouncer `1.24.0-4`)

rilis ini menambah Docker secret `pgbouncer_stats_password` (user konsol admin PgBouncer `olt_stats` untuk sentinel). Jalankan `make gen-secrets` (Windows: `.\make.ps1 gen-secrets`) sebelum `make up`; secret yang sudah ada dipertahankan dan hanya yang belum ada dibuat. Tanpa secret ini `check-config` gagal dan PgBouncer tidak mau start.

### Realtime Broadcast (migrasi `0098`, `rendezvous_community` 1.5.0)

Rilis ini memutus klien lama. Klien 1.4.x tetap tersambung, tetapi tidak lagi menerima pesan baru secara realtime (hanya saat memuat ulang) dan typing-nya tidak sampai. Urutan rilis:

1. App OLT dengan `rendezvous_community` 1.5.0 sudah tersedia di toko aplikasi / kanal update Windows untuk semua platform.
2. Deploy backend (`git pull`, `make up`).
3. Segera setelahnya, Super Admin atau peran Fitur & Kampanye membuka web CS **Fitur & Kampanye → Fitur & versi → Versi minimum aplikasi** dan mengisi versi app OLT pertama yang membawa 1.5.0 untuk setiap platform yang dipakai OLT (`android`, `windows`, dan `ios`/`macos`/`linux`/`web` bila ada). Yang dibandingkan adalah `appVersion` app OLT yang dikirim ke `initialize(...)`, bukan versi package. Perubahan tercatat di jejak audit. App yang lebih lama menerima `update_required: true` dari `get_client_config` dan callback `onUpdateRequired` mengarahkan nasabah ke update. Detail: [panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md#kompatibilitas-server-dan-versi-minimum).
4. Data di database tidak perlu diubah manual.