# Audit Tampilan Web CS (sebelum perbaikan)

Acuan: [PROMPT-CS-UI-POLISH.md](PROMPT-CS-UI-POLISH.md). Aplikasi: repo [`rendezvous_hub`](https://github.com/dayat123123/rendezvous_hub) (dulu `apps/cs-console-react`). Screenshot sebelum (terang dan gelap, 1440×900) diambil dengan `e2e/visual.spec.ts` dari build 30 Okt 2026: login, verifikasi 2 langkah, ruang kerja kosong, percakapan, dialog selesaikan, palet perintah, layar sempit (820 px), dashboard, laporan, dan pengaturan admin.

## Masalah

### Bagian 1: ciri "AI slop"

| # | Masalah | Lokasi |
|---|---|---|
| 1 | Seluruh palet biru/navy: primary `#0B57D0` di tombol, tab aktif, logo, dan avatar. Dark mode memakai latar `#0B1220`, permukaan `#111A2C`, dan border `#25324A` (rona biru). | `globals.css`, semua layar |
| 2 | Terlalu banyak pill berwarna dalam satu baris. Kartu tiket memuat nomor, badge tunggu berlatar warna, badge tanda bergaris, badge belum dibaca merah, dan tombol Ambil biru. Header percakapan memuat pill prioritas, pill status biru "Ditangani", dan tanda. | `ticket-card.tsx`, `conversation-header.tsx` |
| 3 | Kartu membulat dengan bayangan di mana-mana: stat tile, panel "Perlu perhatian", kartu grafik, tabel (`rounded-xl`), kartu login (`rounded-2xl` + shadow), bubble chat (`rounded-2xl`). | dashboard, laporan, login, chat |
| 4 | Ikon dekoratif: ikon di kotak berwarna pada setiap stat tile, ikon besar di empty state, badge hijau "CS Resmi" di setiap grup pesan staf, kotak logo biru. | `stat-tile.tsx`, `states.tsx`, `message-bubble.tsx` |
| 5 | Status memakai latar berwarna: badge tunggu hijau/kuning/merah, badge status tiket, kotak kuning "Anda Offline", alert error berlatar merah, chip koneksi selalu tampil, kotak transfer berlatar aksen. | `badges.tsx`, `ticket-column.tsx`, `status-menu.tsx` |
| 6 | Gerak berlebihan: dialog zoom 95% 200 ms, sheet slide 300 ms, tiket yang diambil CS lain memudar 1000 ms. | `dialog.tsx`, `overlay.tsx`, `ticket-card.tsx` |
| 7 | Bobot 700 (`font-bold`) pada badge prioritas, angka belum dibaca, dan penghitung. Judul halaman 20 px. Ukuran huruf 10/11/12/14 px bercampur tanpa skala. | beberapa komponen |
| 8 | Microcopy panjang: placeholder composer "Tulis balasan… (Enter kirim, Shift+Enter baris baru, / balasan cepat)" dan bar "Pratinjau hanya-baca. Ambil tiket ini untuk membalas." | `id.ts` |

### Bagian 2: token, tipografi, bentuk

| # | Masalah |
|---|---|
| 9 | Tema default mengikuti sistem (`theme.js`, `preferences.ts`), bukan terang. |
| 10 | Tidak ada pembeda `--bg-subtle`/`--bg-selected`. Kolom tiket berwarna putih (`bg-card`), area chat abu kebiruan `#F6F8FB`, dan tiket terpilih memakai aksen biru. |
| 11 | Header 56 px (target 48). Tombol/input 36–40 px tanpa token kepadatan. Kartu tiket ±102 px nyaman / ±78 px padat (target ±76/±64). |
| 12 | Bayangan pada elemen yang tidak melayang: tombol outline, input, select, switch, tab aktif (`shadow-xs`/`shadow-sm`). |
| 13 | Warna di luar token: favicon `#0B57D0`, `text-white`/`bg-black` di penampil lampiran, `bg-white` di QR, overlay `bg-black/50`. |
| 14 | Kontras: `--text-muted` sesuai tabel (`#71717A`) hanya 4,40:1 di atas `--bg-muted` dan 4,24:1 di atas `--bg-selected`. Teks hijau `#16A34A` (3,30:1) dan kuning `#CA8A04` (2,94:1) tidak lolos AA sebagai teks di tema terang. Teks merah gelap `#EF4444` hanya 4,33:1 di atas `--bg-selected`. |

### Bagian 3: per bagian

| # | Bagian | Masalah |
|---|---|---|
| 15 | Header | Navigasi berupa pill dengan ikon. Pencarian 256 px berplaceholder "Cari…". Status berupa tombol bulat bergaris. Indikator Wi-Fi selalu tampil. Tombol akun menampilkan nama dan kode (lebar). |
| 16 | Daftar tiket | Tab berupa pill biru terisi. Tiga select filter selalu tampil dan memakan satu baris. Kartu bersudut dengan avatar, kutipan bertanda petik, dan baris badge. P1 diberi garis kiri merah. Tombol Ambil selalu tampil. |
| 17 | Header percakapan | Judul berupa nomor tiket, bukan nama nasabah. Ada pill prioritas, status, dan tanda. Tombol aksi berikon di baris kedua. "Selesaikan" memuat kbd "E". |
| 18 | Pesan | Bubble `rounded-2xl`. Waktu ada di dalam setiap bubble. Pengelompokan 5 menit. Pemisah tanggal berupa pill. Pesan sistem berupa pill abu (mirip bubble). Kartu order berikon biru. Catatan internal hanya ada di panel nasabah, tidak di linimasa. |
| 19 | Composer | Tab segmented (pill). Lampiran dan kartu tersembunyi di menu "+". Tombol kirim berupa ikon bulat. Ring fokus 3 px. |
| 20 | Bar non-pemilik | Ikon gembok dengan kalimat panjang. Supervisor tidak punya tombol Gabung di bar. |
| 21 | Panel nasabah | Judul seksi 14 px tebal. Tautan biru "Tampilkan" berulang di setiap baris. Order, transaksi, dan riwayat tampil dalam kotak bergaris. Kotak catatan berwarna kuning. |
| 22 | Dashboard | Lima kartu stat berikon. Panel perhatian berupa kartu dengan border berwarna dan pill penghitung. Grafik batang biru di dalam kartu. Meter beban biru. |
| 23 | Laporan | Enam kartu stat. Grafik garis biru/oranye di dalam kartu. Tabel di kartu membulat. |
| 24 | Login | Kartu bergaris dan berbayang, kotak logo biru, tombol biru penuh. Kode 2FA berupa satu input dengan spasi huruf lebar, bukan kotak per digit. |
| 25 | Dialog | `rounded-xl` + `shadow-lg`, judul 18 px, Batal bergaya outline, animasi zoom. |
| 26 | Toast | Kiri bawah, `richColors` (latar berwarna), dan tombol tutup di setiap toast. |
| 27 | Menu | Radius 6 px, item 30 px. |

## Keputusan dan deviasi

- **Kontras AA mengalahkan nilai tabel bila keduanya bertabrakan:**
  - `--text-muted` terang diubah dari `#71717A` ke `#6B6B73`. Kontrasnya 4,64:1 di atas `--bg-selected` dan 5,28:1 di atas putih; secara visual hampir sama.
  - Warna status dari tabel 2.3 tetap dipakai apa adanya untuk titik dan garis.
  - Teks status memakai varian AA:
    - terang: hijau `#166534`, kuning `#854D0E`, merah `#B91C1C`;
    - gelap: merah `#F87171`;
    - biru `#2563EB`/`#60A5FA` lolos di semua permukaan sehingga dipakai apa adanya.
  - Tombol bahaya memakai `#DC2626` dengan teks putih (4,83:1) di kedua tema.
- **Token tambahan:**
  - `--bg-float` untuk popover/menu/dialog: putih di tema terang, `#111111` di tema gelap supaya permukaan melayang tetap terbaca di atas `#0A0A0A`.
  - `--chart-neutral`: `#8A8A93` terang dan `#737373` gelap, dengan kontras grafik ≥ 3:1. Warna aksen grafik memakai `--primary`.
  - `--scrim` untuk overlay dialog.
  - Token kepadatan: `--control-h`, `--control-h-sm`, `--row-py`, `--pane-px`.
- **Skrip tema** tetap file eksternal `/theme.js`, dimuat sinkron di `<head>`, karena CSP `script-src 'self'` melarang script inline. Efeknya sama: kelas tema terpasang sebelum render pertama.
- **`/dev/ui`** hanya aktif saat `APP_ENV=development` dan bisa dibuka tanpa login.
- **Tombol "permintaan verifikasi"** di composer tidak dibuat karena backend belum punya endpoint-nya (lihat [cs-console-audit.md](cs-console-audit.md), B3).
- **Kartu order** hanya menampilkan label, nomor, dan "Lihat detail" karena payload pesan hanya berisi jenis kartu dan nomor referensi. Rincian (saham, sisi, harga, lot, status) tetap ada di dialog detail dari OLT.
- **Catatan internal** tampil di linimasa dari data catatan nasabah yang sudah ada (difilter per tiket). Tidak ada perubahan API.
- **Tombol akun** hanya menampilkan inisial sesuai spesifikasi; nama, kode, dan peran ada di menu. Status koneksi saat terhubung tetap diumumkan ke pembaca layar tanpa tampil di layar.

## Hasil (sesudah perbaikan)

| # | Penyelesaian |
|---|---|
| 1, 9, 10, 13, 14 | Token baru di `globals.css` dengan abu netral. Tema gelap R=G=B. Tema default terang. Tidak ada warna di luar file token (dijaga `npm run lint:tokens`; palet Tailwind bawaan dimatikan). Kontras dicek axe di kedua tema. |
| 2, 5, 16 | Baris tiket tiga baris tanpa kartu. Status tunggu berupa titik, prioritas dan tanda berupa teks kecil, badge belum dibaca berupa lingkaran netral. Tombol Ambil hanya muncul saat baris disorot atau terpilih (selalu tampil di layar sentuh). Filter memakai satu tombol + chip. |
| 3, 12, 25, 27 | Kolom dan kartu tanpa bayangan. Bayangan tunggal `shadow-float` hanya untuk popover, menu, dialog, dan toast. Radius 6/8/12. Dialog 440–520 px, judul 15 px/600, Batal bergaya ghost. Item menu 32 px. |
| 4, 22, 23 | Ikon dekoratif dihapus. Dashboard dan laporan memakai baris angka ringkas tanpa kartu. Grafik memakai satu warna netral + satu aksen, garis putus untuk seri netral, dan grid tipis. Tabel memakai header `--bg-subtle`, baris 40 px, dan garis horizontal saja. |
| 6 | Transisi 140 ms ease-out. Dialog hanya memudar. Tiket yang diambil CS lain memudar dan menyusut 150 ms. `prefers-reduced-motion` dihormati. |
| 7, 8, 11 | Skala huruf 11/12/13/14/15/18 tanpa bobot 700. Header 48 px. Tinggi kontrol dan padding baris mengikuti token kepadatan (Nyaman/Padat). Microcopy dipersingkat. |
| 15 | Header 48 px: logo, navigasi teks bergaris bawah, kotak cari 360 px, status titik + teks, "Aktif x/y", lonceng, avatar inisial. Indikator koneksi hanya muncul saat terputus. |
| 17–20 | Header percakapan dua baris (nama + nomor monospace; topik · prioritas · penanggung jawab · durasi). Aksi secondary + "Selesaikan" primary + menu ⋯. "Tunggu nasabah" otomatis pindah ke menu ⋯ bila kolom sempit. Bubble 68%, radius 12 dengan ekor 4 px, pengelompokan 2 menit, waktu dan centang di bawah grup. Pemisah tanggal bergaris ("28 Okt 2026"). Pesan sistem berupa teks kecil tanpa bubble. Catatan internal tampil di linimasa. Composer satu kotak dengan toolbar ikon dan tombol Kirim. Bar non-pemilik tipis (Ambil tiket / Ditangani oleh … + Gabung). |
| 21 | Panel nasabah `--bg-subtle`: inisial, kode tersamar monospace, status akun. Seksi berlabel kecil uppercase. Pasangan label–nilai. Ikon mata untuk "Tampilkan". Skeleton berupa garis tipis. |
| 24 | Login tanpa kartu, form 360 px, kode 2FA enam kotak (satu input agar isi otomatis OTP tetap jalan). |
| 26 | Toast kecil di kanan bawah, netral, tanpa ikon berwarna besar (hanya titik kecil untuk peringatan/galat). |

Temuan lain yang ikut diperbaiki selama pengerjaan:

- **Pesan nasabah bisa hilang dari layar CS.** Ini terjadi bila nasabah mengirim pesan hampir bersamaan dengan balasan CS. Penyebabnya: kursor sinkron ikut maju ke balasan CS yang baru disimpan lokal. Sekarang kursor hanya maju lewat data server (`cache.ts`, dengan unit test).
- **Daftar pesan tetap menempel di bawah** saat pesan masuk di antara pesan lain.
- **Perbaikan aksesibilitas dari axe:**
  - `aria-expanded` yang tidak sah pada textarea composer diganti dengan `aria-controls`/`aria-activedescendant`;
  - struktur `<dl>` di panel nasabah dirapikan;
  - nama tombol status kini memuat teks yang terlihat.
- **`tailwind-merge` dikonfigurasi** untuk skala huruf kustom. Sebelumnya `text-row` dianggap warna sehingga warna teks tombol kecil hilang.
