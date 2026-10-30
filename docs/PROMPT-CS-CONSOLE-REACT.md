# Migrasi Web CS: Flutter Web → React (TypeScript)

> Simpan sebagai `docs/PROMPT-CS-CONSOLE-REACT.md`. Dokumen ini melengkapi `PROMPT-CS-CHAT.md` dan `PROMPT-CS-REVISI-2.md`.
> Semua aturan sebelumnya tetap berlaku: Docker, lisensi permisif, keamanan, RLS, audit, dan rate limit.
> Bagian `[...]` silakan disesuaikan.

---

## 0. Tujuan

Membangun ulang **web CS** (`apps/cs-console`, saat ini Flutter web) dengan **React + TypeScript**, supaya tampilannya profesional, cepat, nyaman dipakai seharian, dan terasa seperti aplikasi web modern.

**Prinsip:**
- **Backend tidak berubah.** Pakai RPC, tabel, RLS, Realtime, dan fungsi (`cs.claim_ticket`, release, transfer, dan lainnya) yang sudah ada. Kalau ada kebutuhan backend baru, **catat dan tanyakan dulu** sebelum mengubahnya.
- **Paritas fitur penuh.** Semua yang bisa dilakukan di console Flutter (termasuk semua fitur di `PROMPT-CS-REVISI-2.md` bagian 4) harus bisa dilakukan di versi baru.
- Aplikasi nasabah (Flutter OLT) **tidak disentuh**.
- Console Flutter lama tetap berjalan sampai versi React lolos uji dan disetujui (bagian 9).

---

## 1. Stack

Semua berlisensi MIT/ISC/Apache 2.0. Pin versi stabil terbaru, dan **verifikasi lisensinya**.

| Bagian | Pilihan |
|---|---|
| Bahasa & build | **TypeScript (strict)** + **Vite** |
| UI framework | **React** (versi stabil terbaru) |
| Komponen | **shadcn/ui** (Radix UI) + **Tailwind CSS** |
| Ikon | **lucide-react** |
| Data server | **@supabase/supabase-js** + **TanStack Query** |
| Routing | **TanStack Router** (type-safe), atau React Router bila lebih sederhana |
| State UI lokal | **Zustand** |
| Daftar panjang | **TanStack Virtual** (daftar tiket & pesan) |
| Tabel laporan | **TanStack Table** |
| Form & validasi | **react-hook-form** + **zod** |
| Layout kolom | **react-resizable-panels** |
| Command palette | **cmdk** |
| Toast | **sonner** |
| Tanggal | **date-fns** (+ `date-fns-tz`, zona `Asia/Jakarta`) |
| Grafik dashboard | **Recharts** |
| i18n | **i18next** (ID default, EN siap) |
| Lint & format | ESLint + Prettier, ditambah **typecheck** di CI |
| Tes | **Vitest** + **Testing Library** + **Playwright** (E2E) + **MSW** (mock API untuk unit test) |

Tidak memakai server Node di produksi. Hasil build berupa **SPA statis**.

---

## 2. Struktur Proyek

```
apps/cs-console/
├── src/
│   ├── app/                 # bootstrap, providers, router, error boundary
│   ├── config/              # runtime config (env.js), konstanta
│   ├── lib/                 # supabase client, query client, realtime manager, logger, utils
│   ├── features/
│   │   ├── auth/            # login, 2FA, sesi, idle timeout
│   │   ├── presence/        # status agen (online/istirahat/offline), heartbeat
│   │   ├── tickets/         # daftar, filter, klaim, aksi tiket
│   │   ├── conversation/    # chat, composer, quick reply, catatan internal
│   │   ├── customer/        # panel info nasabah, masking & reveal
│   │   ├── supervisor/      # dashboard, semua tiket aktif, pindahkan, gabung
│   │   ├── reports/         # laporan & ekspor CSV
│   │   └── settings/        # agen, topik, quick reply, jam layanan, mode penugasan
│   ├── components/          # komponen UI bersama (shadcn di components/ui)
│   ├── hooks/
│   ├── types/               # tipe dari database (generate otomatis)
│   ├── i18n/
│   └── styles/
├── e2e/                     # Playwright
├── public/
├── Dockerfile
├── nginx.conf
└── README.md
```

- **Tipe TypeScript dari skema database di-generate otomatis** (`supabase gen types`), lalu dibungkus di lapisan `api` per fitur. Komponen UI tidak boleh memanggil `supabase.from(...)` langsung.
- Satu folder per fitur, berisi `api.ts`, `hooks.ts`, `components/`, dan `types.ts`.

---

## 3. Desain & UX

### 3.1 Sistem desain
- **Design token** (warna, radius, spasi, tipografi) didefinisikan sebagai CSS variables. Ada tema **terang & gelap**, dengan default mengikuti sistem dan pilihan disimpan.
- Warna brand: `[warna utama sekuritas]`. Warna status yang konsisten:
  - Prioritas P1–P4
  - SLA tunggu: hijau / kuning / merah
  - Flag: `complaint`, `fraud`, VIP
  - Status agen
- Tipografi: font sans modern yang mudah dibaca, misalnya **Inter** (self-host, tanpa CDN). Ukuran dasar 14px, dengan **mode kepadatan** "Nyaman" dan "Padat".
- Komponen konsisten dari shadcn/ui. Jangan mencampur gaya lain.
- Aksesibilitas **WCAG 2.1 AA**: kontras, fokus keyboard yang terlihat, label ARIA, dan bisa dipakai penuh tanpa mouse.

### 3.2 Tata letak utama (layar ≥ 1280px)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ▣ CS Console  │ Ctrl+K Cari…                │ ● Online ▾ │ Aktif 2/5 │ 🔔 │ 👤 ▾ │
├───────────────┬────────────────────────────────────────────┬─────────────────┤
│ Terbuka (7)   │ #CS-20261030-0042 · Order & Transaksi · P2 │ Sari Wulandari  │
│ Tiket saya (2)│ Ditangani: Anda · menunggu 3m              │ Kode ****1234   │
│ Selesai hari… │ [Tunggu nasabah][Lepas][Transfer][Selesai] │ ─ Order terkait │
│ ───────────── │────────────────────────────────────────────│ ─ Transaksi dana│
│ 🔍 Filter ▾   │                                            │ ─ Perangkat     │
│ ┌───────────┐ │   percakapan (virtualized)                 │ ─ Riwayat tiket │
│ │ kartu tiket│ │                                            │ ─ Catatan intern│
│ └───────────┘ │────────────────────────────────────────────│                 │
│  …            │ [Balas | Catatan internal]  / quick reply  │   (bisa ciut)   │
└───────────────┴────────────────────────────────────────────┴─────────────────┘
```

- Tiga kolom yang **bisa diubah lebarnya** dan ukurannya diingat. Kolom kanan bisa diciutkan.
- Di layar < 1280px: kolom kanan menjadi drawer. Di < 900px: daftar dan chat bergantian (tidak perlu dioptimalkan untuk ponsel).
- **Tidak ada** panel simulasi nasabah dan tidak ada pemilih agen demo.

### 3.3 Detail interaksi penting
- **Kartu tiket**: avatar/inisial, nama, topik, prioritas, potongan pesan terakhir, lama menunggu (warna), badge belum dibaca, flag, dan tombol **Ambil** (tab Terbuka).
- **Klaim tiket**:
  - Tombol langsung loading + nonaktif setelah diklik (cegah klik ganda).
  - Kalau berhasil, tiket pindah ke "Tiket saya" dan terbuka otomatis.
  - Kalau gagal, toast "Sudah diambil oleh [nama]" dan tiket hilang dari daftar.
  - Tiket yang diambil CS lain **hilang dari daftar secara realtime** dengan animasi halus.
- **Pratinjau** tiket yang belum diambil bersifat hanya-baca, dengan banner "Ambil tiket untuk membalas".
- **Composer**:
  - Teks multi-baris (Enter kirim, Shift+Enter baris baru) dan tempel gambar langsung dari clipboard.
  - Drag & drop lampiran dengan pratinjau.
  - Quick reply dengan mengetik `/`, lengkap dengan pencarian dan variabel.
  - Tab **Catatan internal** dengan latar kuning dan label "Tidak terlihat nasabah".
  - Hitungan karakter.
  - Draf per tiket tersimpan otomatis (lokal).
- **Pesan**:
  - Dikelompokkan per pengirim dan per tanggal, dengan pemisah "Tiket #… dibuka/ditutup".
  - Status terkirim/dibaca, balas (quote), kartu order, dan gambar dengan lightbox.
  - Pesan sistem ditampilkan ringkas.
- **Pemeriksaan sebelum kirim**: pesan yang meminta OTP/PIN/password diblokir dengan penjelasan (aturan yang sama dengan backend).
- **Typing indicator** dua arah dan presence nasabah (online/terakhir aktif) bila tersedia.
- **Panel nasabah**:
  - Data dimasking, dan tombol "Tampilkan" membuka dialog alasan (tercatat di audit log).
  - Data OLT dimuat **saat bagian dibuka**, dengan skeleton loading dan pesan jelas bila adapter gagal.
- **Konfirmasi** untuk aksi penting (lepas, transfer, selesaikan) memakai dialog dengan field wajib (alasan, tag hasil, ringkasan).
- **Empty state, loading (skeleton), dan error state** yang rapi di setiap bagian.

### 3.4 Keyboard & produktivitas
- **Ctrl/Cmd+K**: command palette (cari tiket/nasabah, ganti status, pindah tab, aksi tiket).
- Shortcut berikut, dengan daftar shortcut yang bisa dibuka lewat `?`:
  - `J` / `K`: tiket berikutnya/sebelumnya
  - `A`: ambil
  - `R`: fokus balas
  - `N`: catatan internal
  - `E`: selesaikan
  - `Ctrl+Enter`: kirim
- Notifikasi:
  - **Suara + notifikasi browser** untuk tiket baru (mode: semua / prioritas tinggi / mati) dan pesan baru di tiket saya.
  - **Judul tab** menampilkan jumlah belum dibaca, misalnya `(3) CS Console`.
  - Notifikasi tetap bekerja walaupun tab tidak aktif.

---

## 4. Data, Realtime & Keandalan

- **TanStack Query** untuk semua data server: cache, refetch saat fokus/reconnect, dan **optimistic update** untuk kirim pesan (dengan `client_id` idempoten dan rollback bila gagal).
- **Realtime manager** terpusat (satu modul) yang:
  - Subscribe ke topik privat `cs:queue`, `cs:agent:<id>`, dan `cs:room:<id>` (tiket yang sedang dibuka).
  - Memperbarui cache TanStack Query dari event.
  - **Reconnect otomatis** dengan backoff + jitter, re-subscribe, lalu **sinkron ulang** data sejak event terakhir supaya tidak ada pesan atau perubahan yang terlewat.
  - Menampilkan indikator koneksi di header (Terhubung / Menyambung ulang / Offline).
- **Heartbeat presence** agen sesuai mekanisme backend yang ada. Saat tab ditutup, status diperbarui semaksimal mungkin (`pagehide` / `beforeunload`).
- **Multi-tab**: kalau agen membuka console di dua tab, gunakan `BroadcastChannel` supaya hanya satu tab yang memutar suara notifikasi dan mengirim heartbeat.
- **Virtualisasi** daftar tiket dan pesan, dan muat pesan lama secara bertahap (infinite scroll ke atas) dengan posisi scroll yang tetap stabil.
- Error boundary per kolom. Error di panel nasabah tidak boleh membuat chat ikut mati.

---

## 5. Autentikasi & Keamanan

- Login akun staf memakai Supabase Auth yang sudah ada dengan **MFA TOTP wajib**. Ada alur pendaftaran 2FA pertama kali dan kode pemulihan, sesuai mekanisme backend yang sudah dibuat.
- **Idle timeout** `[30 menit]`: peringatan 1 menit sebelumnya, lalu logout dan bersihkan cache serta draf.
- Hanya memakai **anon key**. Tidak ada service key atau secret di bundle. Konfigurasi diambil dari `env.js` saat runtime (bagian 7), bukan di-hardcode saat build.
- Role (`cs_agent`, `cs_supervisor`, `cs_admin`, `compliance`) menentukan menu yang tampil. **Otorisasi sebenarnya tetap di server (RLS/RPC)**, sedangkan UI hanya mengikuti.
- Konten pesan dirender sebagai **teks biasa**. Tidak ada `dangerouslySetInnerHTML` untuk konten pengguna. Link dibuka dengan `rel="noopener noreferrer"` dan konfirmasi untuk domain luar.
- Lampiran dibuka lewat signed URL berumur pendek, dengan watermark nama/ID agen saat ditampilkan (sesuai aturan sebelumnya).
- Header keamanan dari Nginx:
  - CSP ketat: `default-src 'self'`, ditambah izin ke domain Supabase/Realtime, tanpa `unsafe-inline` untuk script.
  - HSTS, `X-Frame-Options: DENY`, `Referrer-Policy`, dan `Permissions-Policy`.
- Log di browser tidak mencetak token atau isi pesan di build produksi.

---

## 6. Paritas Fitur (checklist wajib)

Buat `docs/cs-console-parity.md` berisi tabel **fitur Flutter lama → fitur React baru → status → tes**. Minimal mencakup:

- [ ] Login + 2FA + idle timeout + logout
- [ ] Status agen (Online/Istirahat/Offline + alasan), heartbeat, dan batas tiket aktif
- [ ] Tab Terbuka / Tiket saya / Selesai hari ini, plus Semua aktif (supervisor)
- [ ] Filter (topik, prioritas, flag) dan pencarian (nomor tiket, nama, kode nasabah, isi pesan)
- [ ] Ambil tiket (atomik), pratinjau hanya-baca, dan pembaruan realtime saat diambil CS lain
- [ ] Chat: teks, lampiran, kartu order, quick reply, permintaan konfirmasi identitas, tautan bantuan, typing, dan status dibaca
- [ ] Catatan internal (per tiket & per nasabah)
- [ ] Tunggu nasabah, lepas (alasan), transfer ke CS (diterima/ditolak), dan selesaikan (tag + ringkasan)
- [ ] Info nasabah ber-masking, reveal dengan alasan, data OLT hanya-baca, dan riwayat tiket
- [ ] Supervisor: dashboard realtime, alert tiket lama tidak diambil / P1, pindahkan, gabung, dan ubah prioritas
- [ ] Laporan + ekspor CSV
- [ ] Pengaturan: akun CS, topik, quick reply, jam layanan, lepas otomatis, dan mode penugasan
- [ ] Notifikasi suara/browser dan judul tab
- [ ] Tema terang/gelap dan mode kepadatan

---

## 7. Docker & Deploy

- **Dockerfile multi-stage**: build dengan Node (versi LTS di-pin), lalu jalankan dengan **`nginx-unprivileged`** (non-root, read-only filesystem + tmpfs, resource limits). Ikuti aturan container hardening di PROMPT-PRODUCTION.
- `nginx.conf`:
  - SPA fallback ke `index.html`.
  - Cache panjang untuk asset ber-hash dan `no-cache` untuk `index.html` / `env.js`.
  - Gzip/brotli.
  - Header keamanan (bagian 5).
  - Endpoint `/healthz`.
- **Runtime config**: `entrypoint` menulis `env.js` dari environment variable container (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_ENV`, dan lainnya). Dengan begitu, satu image yang sama bisa dipakai di dev, staging, dan produksi.
- Tambahkan service `cs-console` ke compose dev/single dan stack cluster, di belakang Traefik dan **hanya bisa diakses lewat VPN**, sama seperti sebelumnya.
- CI: lint, typecheck, unit test, build, E2E (Playwright terhadap stack Docker lokal), scan image (Trivy), dan cek lisensi dependensi npm (gagal bila ada GPL/AGPL).

---

## 8. Pengujian

- **Unit/komponen** (Vitest + Testing Library + MSW): composer, quick reply, masking/reveal, filter, dan reducer realtime.
- **E2E Playwright** terhadap stack Docker dengan data seed:
  1. Login + 2FA.
  2. **Dua agen di dua browser** mengeklik "Ambil" pada tiket yang sama hampir bersamaan: tepat satu yang berhasil, dan tiket hilang dari daftar agen lain.
  3. Chat dua arah dengan nasabah simulasi (script/API), termasuk lampiran dan status dibaca.
  4. Lepas, transfer, dan selesaikan, lalu tiket tampil benar di tab masing-masing.
  5. Agen non-pemilik tidak bisa membalas (input nonaktif, dan API menolak).
  6. Putuskan jaringan lalu sambung lagi: pesan yang terlewat muncul dan tidak ada yang dobel.
  7. Supervisor memindahkan tiket dan bergabung ke chat.
- **Kinerja**:
  - Daftar 1.000 tiket dan percakapan 5.000 pesan tetap mulus (60fps saat scroll).
  - Bundle awal < `[300 KB]` gzip, dengan code-splitting per route (laporan & pengaturan dimuat terpisah).
  - Lighthouse (desktop) Performance & Accessibility ≥ `[90]`.
- **Uji visual**: screenshot Playwright tema terang/gelap untuk layar utama.

---

## 9. Rencana Migrasi

1. **M1: Fondasi**
   - Setup proyek, sistem desain & tema, layout 3 kolom, login + 2FA, supabase client, realtime manager, runtime config, dan Docker.
   - Tunjukkan screenshot tampilan kosong + login.
2. **M2: Inti CS**
   - Daftar tiket, klaim, pratinjau, percakapan, composer, catatan internal, quick reply, aksi tiket, dan panel nasabah.
   - Kriteria selesai: E2E 1–6 lulus.
3. **M3: Supervisor, laporan & pengaturan**
   - Dashboard realtime, alert, pindahkan/gabung, laporan, pengaturan, command palette, shortcut, dan notifikasi.
4. **M4: Uji paralel**
   - Console React di-deploy di **URL terpisah** (misalnya `cs-new.[domain-internal]`) dan dipakai `[2–3]` CS bersamaan dengan console lama (backend sama). Kumpulkan masukan dan perbaiki.
   - Kriteria selesai: checklist paritas 100%, semua tes lulus, dan persetujuan saya.
5. **M5: Cutover & pembersihan**
   - Pindahkan URL utama ke console React.
   - Console Flutter lama tetap tersedia `[1–2 minggu]` sebagai cadangan, lalu dihapus dari repo, compose, dan stack.
   - Widget chat Flutter yang masih dipakai aplikasi nasabah **tidak boleh ikut terhapus**.
   - Perbarui dokumentasi.

Setiap tahap: berhenti, tunjukkan hasil (screenshot / rekaman singkat), lalu tunggu konfirmasi saya.

**Sebelum mulai M1:**
1. Audit console Flutter yang ada, lalu daftar semua fitur, RPC, tabel, dan topik Realtime yang dipakai. Ini menjadi dasar checklist paritas.
2. Daftar kebutuhan backend baru, bila ada.
3. Usulkan palet warna & contoh tampilan (gambar atau mockup sederhana) untuk saya setujui.

Lalu tunggu jawaban saya.
