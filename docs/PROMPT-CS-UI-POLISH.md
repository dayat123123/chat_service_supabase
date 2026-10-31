# Perbaikan Tampilan Web CS — Bersih, Profesional, Bukan "AI Slop"

> Simpan sebagai `docs/PROMPT-CS-UI-POLISH.md`. Tugas ini **khusus tampilan (UI/UX)** pada `apps/cs-console` (React).
> **Jangan mengubah logika, API, RLS, atau backend.** Semua tes yang ada harus tetap lulus.

---

## 0. Masalah & Arah

Tampilan sekarang terasa generik ("AI slop") dan dark mode-nya kebiruan. Arah baru:

- **Tema terang (putih) sebagai default.** Dark mode tersedia sebagai pilihan.
- **Dark mode berwarna hitam/abu netral**, **bukan biru atau navy**. Tidak boleh ada rona biru di latar, permukaan, maupun border.
- Gaya **tenang, padat informasi, presisi**, seperti alat kerja profesional yang dipakai 8 jam sehari. Acuan *kualitas* (bukan untuk ditiru mentah): inbox tim support modern, Linear, Slack, dan aplikasi email profesional. Ciri-cirinya: hierarki jelas, warna hemat, tipografi rapi, dan detail kecil yang konsisten.

---

## 1. Larangan (ciri "AI slop" yang harus dihapus)

- Gradien di latar, tombol, header, atau kartu.
- Efek glow, glassmorphism/blur, dan bayangan tebal di mana-mana.
- Warna ungu/biru neon. Aksen tidak boleh dipakai berlebihan.
- Semua elemen dijadikan kartu membulat besar (`rounded-2xl` + shadow) yang saling bertumpuk.
- Emoji dan ikon dekoratif di UI (✨ 🚀 🎉), termasuk di judul, tombol, empty state, dan toast.
- Terlalu banyak pill/badge berwarna dalam satu baris.
- Padding raksasa, elemen yang terlalu besar, dan teks yang diletakkan di tengah tanpa alasan.
- Teks bombastis ("Supercharge your support!"). Microcopy harus singkat, jelas, dalam Bahasa Indonesia yang wajar.
- Ikon yang tidak konsisten (campur set ikon, ukuran, atau ketebalan garis).
- Animasi berlebihan (bounce, scale besar, transisi lambat).

---

## 2. Design Token

Definisikan sebagai CSS variables di `:root` (terang) dan `.dark` (gelap). Hubungkan ke tema shadcn/Tailwind. **Ganti semua warna hardcode** di komponen dengan token ini.

### 2.1 Terang (default)

| Token | Nilai | Pemakaian |
|---|---|---|
| `--bg` | `#FFFFFF` | Latar utama, area chat |
| `--bg-subtle` | `#FAFAFA` | Kolom daftar tiket, sidebar, header tabel |
| `--bg-muted` | `#F4F4F5` | Hover baris, input nonaktif, bubble pesan nasabah |
| `--bg-selected` | `#F0F0F1` | Tiket yang sedang dibuka |
| `--border` | `#E4E4E7` | Garis pemisah kolom, border input & kartu |
| `--border-strong` | `#D4D4D8` | Border input saat hover |
| `--text` | `#18181B` | Teks utama |
| `--text-muted` | `#71717A` | Teks sekunder, waktu, metadata |
| `--text-subtle` | `#A1A1AA` | Placeholder, label nonaktif |
| `--primary` | `[warna brand sekuritas, default #18181B]` | Tombol utama, fokus, link |
| `--primary-fg` | `#FFFFFF` | Teks di atas primary |
| `--bubble-agent` | `[primary]` atau `#18181B` | Bubble pesan CS |
| `--bubble-agent-fg` | `#FFFFFF` | |
| `--note-bg` | `#FFFBEB` | Catatan internal |
| `--note-border` | `#FDE68A` | |

### 2.2 Gelap (netral, tanpa biru)

| Token | Nilai |
|---|---|
| `--bg` | `#0A0A0A` |
| `--bg-subtle` | `#111111` |
| `--bg-muted` | `#1A1A1A` |
| `--bg-selected` | `#202020` |
| `--border` | `#262626` |
| `--border-strong` | `#333333` |
| `--text` | `#EDEDED` |
| `--text-muted` | `#A1A1A1` |
| `--text-subtle` | `#6B6B6B` |
| `--primary` | `#FAFAFA` (atau versi terang warna brand, bila brand berwarna) |
| `--primary-fg` | `#0A0A0A` |
| `--bubble-agent` | `#EDEDED` |
| `--bubble-agent-fg` | `#0A0A0A` |
| `--note-bg` | `#1F1A0E` |
| `--note-border` | `#4A3B14` |

Gunakan **abu netral murni** (R=G=B). Jangan pakai palet slate/blue-gray Tailwind.

### 2.3 Warna status (hemat dan redup)

Pakai warna semantik **hanya sebagai titik kecil, teks, atau garis tipis**, bukan latar besar:

| Arti | Terang | Gelap |
|---|---|---|
| Sukses / online / tunggu < 5 m | `#16A34A` | `#22C55E` |
| Peringatan / tunggu 5–15 m | `#CA8A04` | `#EAB308` |
| Bahaya / P1 / fraud / tunggu > 15 m | `#DC2626` | `#EF4444` |
| Info / pengaduan | `#2563EB` | `#60A5FA` (teks saja, **bukan latar**) |
| Netral / offline | `--text-subtle` | `--text-subtle` |

- Prioritas ditampilkan sebagai **teks kecil berbobot sedang** (`P1`, `P2`) dengan warna di atas. P3/P4 cukup abu. Tidak memakai pill berwarna penuh.
- Badge belum dibaca: lingkaran kecil `--text` (terang) / `--primary` (gelap) dengan angka.

### 2.4 Tipografi
- Font **Inter** (self-hosted, `font-feature-settings: "cv11", "ss01"`, dan *tabular numbers* untuk angka/waktu).
- Skala:
  - `12px`: metadata, waktu, label kecil
  - `13px`: daftar tiket, tabel
  - `14px`: teks chat, input (dasar)
  - `15–16px`: judul panel
  - `18px`: judul halaman (jarang)
- Berat: 400 normal, 500 untuk label/nama, dan 600 hanya untuk judul. **Hindari 700+.**
- Tinggi baris 1.45–1.5 untuk teks chat. Huruf kecil normal (*sentence case*), tidak ALL CAPS, kecuali label seksi kecil dengan `letter-spacing` sedikit.

### 2.5 Ukuran, spasi & bentuk
- Grid **4px**. Spasi yang umum dipakai: 4, 8, 12, 16, 24.
- Radius: `6px` untuk input/tombol/badge, `8px` untuk popover/dialog, dan **bubble chat `12px`**. Tidak ada `rounded-2xl`/`3xl`.
- Bayangan **hanya** untuk elemen melayang (popover, dropdown, dialog, toast): satu bayangan halus. Kolom dan kartu **tidak memakai shadow**, cukup dipisahkan border 1px.
- Tinggi kontrol: tombol/input `32px` (padat) atau `36px` (nyaman), header aplikasi `48px`, dan baris tiket `±64px` (padat) / `±76px` (nyaman).
- Ikon **lucide** ukuran `16px`, stroke `1.75`, warna `--text-muted`. Ikon hanya dipakai bila membantu.

### 2.6 Gerak
- Transisi `120–160ms ease-out`, hanya untuk warna latar, opacity, dan posisi kecil.
- Tiket yang diambil CS lain menghilang dengan fade + collapse tinggi `150ms`.
- Hormati `prefers-reduced-motion`.

---

## 3. Spesifikasi per Bagian

### 3.1 Header aplikasi (48px, `--bg`, border bawah)
- Kiri: logo kecil + "CS Console" (500, 14px).
- Tengah: kotak pencarian/Ctrl+K yang tipis (lebar `±360px`, `--bg-muted`, placeholder "Cari tiket atau nasabah…", hint `Ctrl K` di kanan).
- Kanan:
  - Pemilih status berupa **titik warna + teks** ("Online"), dropdown.
  - Teks "Aktif 2/5" (muted).
  - Ikon notifikasi.
  - Avatar/inisial dengan menu (profil, tema: Terang / Gelap / Ikuti sistem, kepadatan, shortcut, keluar).
- Indikator koneksi hanya muncul saat **tidak** terhubung (strip tipis atau teks kecil "Menyambung ulang…").

### 3.2 Kolom daftar tiket (`--bg-subtle`, border kanan)
- **Tab** berupa teks dengan garis bawah 2px untuk tab aktif dan angka abu di sebelahnya: `Terbuka 7 · Tiket saya 2 · Selesai`. Tidak memakai tombol pill berwarna.
- Baris filter: satu tombol "Filter" kecil + chip filter aktif yang bisa dihapus.
- **Baris tiket** (bukan kartu bershadow), dipisah border tipis:
  ```
  ● Sari Wulandari                         3m
    Order & Transaksi · P2
    order saya belum tereksekusi dari tadi…   (2)
  ```
  - Baris 1: titik status tunggu (hijau/kuning/merah), nama (500), dan waktu di kanan (muted, tabular).
  - Baris 2: topik · prioritas (teks kecil, muted). Flag `Pengaduan` / `Fraud` sebagai teks kecil berwarna.
  - Baris 3: potongan pesan (1 baris, ellipsis, muted) dan badge belum dibaca di kanan.
  - Hover: `--bg-muted`. Terpilih: `--bg-selected` + garis kiri 2px `--text`.
  - Tombol **Ambil** hanya di tab Terbuka. Tombolnya kecil, gaya *secondary/outline*, dan muncul di kanan baris 1 **saat hover atau terpilih**. Di layar sentuh, tombol selalu tampil.
- Empty state: teks singkat abu di tengah kolom, misalnya "Tidak ada tiket terbuka." Tanpa ilustrasi atau emoji.

### 3.3 Kolom percakapan (`--bg`)
- **Header tiket** (2 baris, border bawah):
  - Baris 1: nama nasabah (500, 15px) + nomor tiket (muted, monospace kecil).
  - Baris 2: topik · prioritas · "Ditangani: Anda" · durasi.
  - Kanan: tombol aksi **secondary** kecil (Tunggu nasabah, Lepas, Transfer) dan satu tombol **primary** "Selesaikan". Aksi sisanya di menu `⋯`.
- **Pesan**:
  - Nasabah di kiri dengan bubble `--bg-muted`. CS di kanan dengan bubble `--bubble-agent`.
  - Lebar maksimum `±68%`, padding `8px 12px`, radius 12px, dan sudut ekor 4px di sisi pengirim.
  - Pesan berurutan dari pengirim yang sama dalam 2 menit **dikelompokkan**: nama & waktu hanya di pesan pertama/terakhir, dan jarak antar pesan 2px.
  - Waktu (12px, muted) di bawah grup, beserta status dibaca (ikon centang kecil).
  - **Pemisah tanggal** di tengah berupa teks kecil muted dengan garis tipis di kedua sisi ("Hari ini", "Kemarin", "28 Okt 2026").
  - **Pesan sistem** di tengah sebagai teks kecil muted **tanpa bubble**, satu baris, misalnya "Tiket #CS-…-0042 diambil oleh Nadia · 15.58".
  - **Kartu order** di dalam bubble: border 1px, `--bg`, label kecil "Order", nomor dalam monospace, ringkasan (saham, sisi, harga, lot, status), dan link "Lihat detail".
  - **Catatan internal**: latar `--note-bg` + border kiri 2px `--note-border`, label kecil "Catatan internal · tidak terlihat nasabah", lebar penuh.
- **Composer** (border atas, `--bg`):
  - Tab teks kecil "Balas | Catatan internal". Saat mode catatan, latar composer berubah menjadi `--note-bg`.
  - Textarea yang tumbuh otomatis (maksimal 8 baris) tanpa border ganda. Fokus ditandai ring 2px halus memakai `--primary` dengan opacity rendah.
  - Baris bawah: ikon lampiran, kartu order, quick reply (`/`), dan permintaan verifikasi. Di kanan: hint "Enter kirim · Shift+Enter baris baru" (muted) + tombol **Kirim** primary kecil.
- Kalau tiket bukan milik CS ini: composer diganti bar tipis "Ditangani oleh **Bima**" (+ tombol "Gabung" untuk supervisor). Untuk tiket Terbuka: bar berisi "Ambil tiket ini untuk membalas" + tombol primary **Ambil tiket**.

### 3.4 Kolom info nasabah (`--bg-subtle`, border kiri, bisa diciutkan)
- Bagian atas: inisial dalam lingkaran abu, nama, kode nasabah (masked, monospace), dan status akun (titik + teks).
- Bagian yang bisa dilipat (*accordion* tanpa kartu): **Order terkait**, **Transaksi dana**, **Perangkat & sesi**, **Riwayat tiket**, **Catatan**.
  - Judul bagian berupa label kecil uppercase muted (11–12px) dengan spasi huruf sedikit.
  - Isinya berupa **pasangan label–nilai** dua kolom (label muted di kiri, nilai di kanan, angka tabular).
- Nilai yang dimasking dengan ikon mata kecil untuk "Tampilkan" (dialog alasan).
- Skeleton loading berupa garis abu tipis, bukan spinner besar.

### 3.5 Dashboard supervisor & laporan
- Baris **angka ringkas** (4–6 metrik) tanpa kartu bershadow: angka besar 24px tabular + label kecil muted, dipisah border tipis.
- Grafik Recharts: garis/bar tipis, satu warna netral + satu warna aksen, grid sangat tipis atau tanpa grid, tooltip sederhana, dan tidak ada gradien area.
- Tabel: header `--bg-subtle`, baris 40px, border horizontal saja, angka rata kanan, dan sorting dengan ikon kecil.

### 3.6 Login
- Halaman putih (atau `--bg` gelap) dengan form sempit di tengah (`±360px`): logo kecil, judul "Masuk ke CS Console", input email/username, password, lalu langkah 2FA (input 6 digit berkotak).
- Tanpa ilustrasi, gradien, atau latar foto.

### 3.7 Dialog, toast, menu
- Dialog: lebar 440–520px, judul 15px/600, deskripsi muted, dan tombol di kanan bawah (Batal = ghost, aksi utama = primary). Aksi berbahaya memakai tombol merah.
- Toast (sonner): kecil di kanan bawah, teks singkat, tanpa ikon berwarna besar.
- Dropdown/popover: radius 8px, border + bayangan halus, item 32px.

---

## 4. Tema & Pengaturan

- **Default: Terang**, bukan mengikuti sistem. Pilihan di menu avatar: **Terang / Gelap / Ikuti sistem**. Pilihan tersimpan (localStorage dengan try/catch).
- Terapkan kelas tema **sebelum render pertama** (script kecil inline di `index.html`) supaya tidak ada kedipan warna saat halaman dimuat.
- Mode kepadatan **Nyaman / Padat** (default Nyaman) yang mengubah tinggi baris dan padding lewat token.
- Pastikan **semua** komponen (termasuk shadcn, Recharts, scrollbar, selection, dan placeholder) mengikuti token di kedua tema. **Tidak boleh ada sisa warna biru/slate di dark mode.**
- Scrollbar tipis dan netral (`--border-strong`). Warna seleksi teks netral.

---

## 5. Kualitas & Verifikasi

- **Audit dulu**: ambil screenshot semua layar saat ini (terang & gelap), lalu daftar masalahnya berdasarkan bagian 1–3.
- Buat **halaman `/dev/ui`** (hanya di profil dev) yang menampilkan semua token, tipografi, tombol, input, baris tiket (semua variasi status), bubble, pesan sistem, catatan internal, kartu order, dialog, dan toast, dalam kedua tema. Halaman ini menjadi acuan konsistensi.
- Kontras minimal **WCAG AA** untuk teks di kedua tema. Cek otomatis dengan axe di Playwright.
- **Uji visual Playwright** (screenshot) untuk layar utama di kedua tema, sebelum dan sesudah. Lampirkan perbandingan sebelum vs sesudah di ringkasan tahap.
- Uji di resolusi 1366×768 (umum di PC kantor), 1920×1080, dan 2560×1440. Tidak boleh ada teks terpotong atau scroll horizontal.
- Tidak boleh ada warna hardcode tersisa. Tambahkan aturan lint/grep di CI yang gagal bila ada kode hex atau kelas warna Tailwind mentah (`bg-blue-*`, `text-slate-*`, dan sejenisnya) di luar file token.

---

## 6. Tahapan

1. **U1: Audit + token + `/dev/ui`**
   - Screenshot sebelum, daftar masalah, design token terang/gelap, tipografi, dan halaman `/dev/ui`.
   - **Berhenti dan tunjukkan screenshot `/dev/ui` kedua tema** untuk persetujuan saya.
2. **U2: Layout & daftar tiket**
   - Header, tab, baris tiket, filter, empty state, dan tema/kepadatan.
3. **U3: Percakapan & composer**
   - Bubble, pengelompokan, pesan sistem, kartu order, catatan internal, composer, dan bar non-pemilik.
4. **U4: Info nasabah, supervisor, laporan, login, dialog**
5. **U5: Verifikasi**
   - Uji kontras, uji visual, berbagai resolusi, lint warna, dan perbandingan sebelum/sesudah.

Setiap tahap: berhenti, tunjukkan screenshot **terang dan gelap**, lalu tunggu konfirmasi saya.
