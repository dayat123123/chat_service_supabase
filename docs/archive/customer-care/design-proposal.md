# Usulan Desain: Aplikasi Nasabah & CS Console

> **Untuk:** pemilik produk dan pemangku kepentingan layanan pelanggan.
> **Status:** keputusan ditetapkan 30 Okt 2026 (bagian 5). C1 selesai, lihat [backend.md](backend.md).
> **Dasar:** [PROMPT-CUSTOMER-CARE.md](../PROMPT-CUSTOMER-CARE.md) bagian 3, 6, 9, dan 10.

Dokumen ini berisi:
- gambaran sistem;
- wireframe layar utama aplikasi nasabah (`olt_care`) dan CS Console;
- alur status tiket, tenggat pengaduan, dan live chat;
- keputusan yang perlu Anda konfirmasi sebelum C1 dimulai.

Wireframe hanya menunjukkan susunan dan isi layar. Warna dan gaya akhir mengikuti tema aplikasi OLT, sama seperti `olt_social`.

## 1. Gambaran sistem

```text
 [Aplikasi OLT: olt_social + olt_care]        [CS Console: staf, VPN, TOTP]
                  │ internet                              │ jalur internal
                  └──────────────► Traefik ──► Kong ◄─────┘
                                                │
        ┌───────────────┬───────────────┬───────┴───────┐
        ▼               ▼               ▼               ▼
    PostgREST       Realtime         Storage       auth-bridge
        │           (care:*)        (lampiran)     (sudah ada)
        ▼               ▲
 [Postgres · schema care: RLS, lini masa & audit append-only]
        ▲                               ▲
        │                               │ catat setiap akses
 [care-worker: tenggat, pengingat,   [customer-adapter] ── Protokol v1 ──► [OLT]
  penugasan, PDF, email]             hanya-baca + 2 aksi
```

| Komponen baru | Isi | Tahap |
|---|---|---|
| Schema `care` | Tabel sesuai bagian 9 spesifikasi. RLS di semua tabel. Lini masa dan audit log *append-only*. Partisi bulanan untuk tabel besar | C1 |
| `care-worker` (`services/care`) | Go, stateless, aman dijalankan banyak replika. Isinya: surat PDF dan email keluar (C1), penugasan chat dan pemeriksaan lampiran (C2–C3). Timer tenggat, peringatan, dan pengingat dijalankan pg_cron di database | C1 |
| `customer-adapter` (`services/care`) | Go, stateless. Jembatan hanya-baca ke OLT lewat Protokol v1, ditambah dua aksi (amankan akun, verifikasi identitas). Mode mock memakai OLT dummy | C1 |
| `packages/olt_staff_kit` | Login staf + 2FA, batas waktu sesi, dan komponen desain bersama. Dipakai CS Console sekarang dan panel admin F1 nanti | C1–C3 |
| `packages/olt_care` | Package Flutter untuk aplikasi OLT (Windows & Android) dengan pola sama seperti `olt_social`: per fitur, cubit, dan freezed. Berbagi sesi login dengan `olt_social` | C2 |
| `apps/cs-console` | Flutter web untuk layar lebar, disajikan container statis, hanya bisa diakses lewat VPN | C3 |

**Keputusan teknis yang diusulkan:**
- **Login staf.**
  - Memakai GoTrue (Supabase Auth, sudah berjalan, lisensi MIT): email + password + TOTP. Pendaftaran publik mati; staf diundang oleh `cc_admin`.
  - Server menolak aksi staf bila login belum melewati 2FA (`aal2`) atau akun staf dinonaktifkan.
  - Token nasabah dari auth-bridge tidak pernah lolos pemeriksaan staf.
- **Jalur staf terpisah.**
  - CS Console dan API staf hanya dibuka di entrypoint internal (VPN).
  - Token staf yang datang lewat jalur publik ditolak di server, lewat pemeriksaan per request yang sudah ada dan diperluas.
- **Realtime.**
  - Memakai broadcast privat dari database dengan dua topik per tiket:
    - `care:ticket:<id>`: untuk nasabah dan staf;
    - `care:ticket:<id>:staff`: catatan internal dan "siapa yang sedang melihat/mengetik", sehingga catatan internal **tidak pernah** sampai ke perangkat nasabah.
  - Sinkron ulang saat tersambung kembali, dengan pola yang sama seperti perbaikan centang chat.
  - Perbaikan `REGION` Realtime yang baru dipasang adalah prasyarat, karena semua pembaruan customer care memakai broadcast dari database.
- **Mesin tenggat di database.**
  - Fungsi SQL hari kerja + kalender (`holidays`, `business_hours`, zona WIB). Tenggat, laporan, dan RLS memakai angka yang sama.
  - Diuji dengan pgTAP: libur nasional, cuti bersama, pergantian tahun, jeda, dan perpanjangan.
- **Nomor pengaduan tanpa celah** memakai tabel penghitung per tahun dengan *row lock*. Sequence Postgres tidak dipakai karena bisa melompat.
- **Penyamaran isi pesan.**
  - Dilakukan oleh trigger database sebelum pesan disimpan, untuk pesan nasabah maupun agen.
  - Aplikasi memberi peringatan sebelum pesan dikirim.
  - Polanya sama di Dart dan SQL, dan diuji di kedua sisi, seperti parser `$KODE`.
- **Surat PDF.**
  - Dibuat `care-worker` dari template berversi.
  - Saat implementasi dipilih fpdf (MIT) + font Go (BSD), bukan Typst, agar image tetap satu binary tanpa program luar.
  - Nomor dokumen dan hash SHA-256 dicatat di `official_letters` untuk cek keaslian.
- **Lampiran.**
  - Disimpan di bucket privat dan dibuka lewat signed URL berumur pendek.
  - Gambar ditulis ulang sehingga metadata EXIF hilang. PDF diperiksa strukturnya (pdfcpu, Apache-2.0) dan ditolak bila berisi JavaScript atau file tertanam.
  - Lampiran baru bisa dibuka setelah lolos pemeriksaan.

## 2. Aplikasi nasabah (`olt_care`)

Responsif: Android satu kolom; Windows (lebar ≥ 840 px) dua kolom. Wireframe di bawah memakai tampilan Android.

### A1. Beranda Bantuan

```text
┌──────────────────────────────────────────────┐
│ ‹ Bantuan                                    │
├──────────────────────────────────────────────┤
│ (!) Penarikan via Bank X sedang tertunda.    │
│     Estimasi pulih 14.00 WIB.       Detail › │
├──────────────────────────────────────────────┤
│ Hai Budi, ada yang bisa kami bantu?          │
│ ┌──────────────────────────────────────────┐ │
│ │ Cari: "deposit belum masuk"              │ │
│ └──────────────────────────────────────────┘ │
│ [ Chat dengan CS ]   Online · tunggu ±2 mnt  │
│ [ Buat tiket     ]   Dibalas di jam layanan  │
│ Jam layanan: Sen–Jum 08–22, Sab–Min 09–18    │
├──────────────────────────────────────────────┤
│ Tiket saya                           Semua › │
│ ┌──────────────────────────────────────────┐ │
│ │ CC-2026-10-000123          ● 1 balasan   │ │
│ │ Deposit belum masuk                      │ │
│ │ Menunggu tanggapan Anda                  │ │
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ Kategori populer                             │
│ [Dana (RDN)] [Order] [Login] [Dividen]       │
│ Artikel teratas                              │
│ • Cara deposit lewat virtual account         │
│ • Kenapa order saya ditolak?                 │
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ Kontak resmi                             │ │
│ │ CS kami tidak pernah meminta PIN,        │ │
│ │ password, OTP, atau transfer dana ke     │ │
│ │ rekening pribadi.                        │ │
│ │ [Lihat kontak resmi] [Laporkan CS palsu] │ │
│ └──────────────────────────────────────────┘ │
│ [ Amankan akun saya ]   tersedia 24 jam      │
└──────────────────────────────────────────────┘
```

Di Windows, kolom kiri berisi pencarian, kategori, dan artikel. Kolom kanan berisi kartu chat/tiket, "Tiket saya", dan kontak resmi. Banner status layanan berasal dari insiden yang dibuat supervisor (B6).

### A2. Pusat Bantuan

```text
┌──────────────────────────────────────────────┐
│ ‹ Cari: "deposit belum masu|"           ✕    │
├──────────────────────────────────────────────┤
│ 3 artikel                                    │
│ • Deposit belum masuk ke RDN                 │
│   Dana (RDN) · 2 menit baca                  │
│ • Jam proses deposit tiap bank               │
│   Dana (RDN) · 1 menit baca                  │
│ • Cara deposit lewat virtual account         │
│   Dana (RDN) · 3 menit baca                  │
├──────────────────────────────────────────────┤
│ Tidak menemukan jawaban?                     │
│ [ Chat dengan CS ]   [ Buat tiket ]          │
└──────────────────────────────────────────────┘
```

```text
┌──────────────────────────────────────────────┐
│ ‹ Dana (RDN) › Deposit                       │
├──────────────────────────────────────────────┤
│ Deposit belum masuk ke RDN                   │
│ Diperbarui 28 Okt 2026 · Android & Windows   │
│                                              │
│ 1. Pastikan transfer ke nomor virtual        │
│    account di menu Deposit.                  │
│ 2. Transfer antarbank bisa memakan waktu     │
│    hingga 1 jam kerja.                       │
│ 3. Lewat 1 jam kerja? Buat tiket dengan      │
│    bukti transfer.                           │
│ [ Buka menu Deposit › ]     (tautan ke OLT)  │
├──────────────────────────────────────────────┤
│ Apakah ini membantu?        [ Ya ] [ Tidak ] │
│ Terkait: Jam proses deposit tiap bank     ›  │
│ Masih butuh bantuan?  [Chat CS] [Buat tiket] │
└──────────────────────────────────────────────┘
```

Pencarian memakai full-text bahasa Indonesia + `pg_trgm`, sehingga salah ketik tetap ketemu. Tombol di artikel bisa langsung membuka layar OLT lewat deep link.

### A3. Membuat tiket (alur pintar)

```text
┌──────────────────────────────────────────────┐
│ ‹ Buat tiket                    Langkah 1/4  │
├──────────────────────────────────────────────┤
│ Apa masalah Anda?                            │
│ ○ Akun & Registrasi                          │
│ ● Dana (RDN)                                 │
│     ● Deposit belum masuk                    │
│     ○ Penarikan tertunda / gagal             │
│     ○ Saldo tidak sesuai                     │
│ ○ Transaksi / Order                          │
│ ○ Login & Keamanan                           │
│ ○ Lainnya …                                  │
│                                 [ Lanjut › ] │
└──────────────────────────────────────────────┘
```

```text
┌──────────────────────────────────────────────┐
│ ‹ Coba ini dulu                 Langkah 2/4  │
├──────────────────────────────────────────────┤
│ Artikel ini sering menyelesaikan masalah     │
│ yang sama:                                   │
│ • Deposit belum masuk ke RDN              ›  │
│ • Jam proses deposit tiap bank            ›  │
├──────────────────────────────────────────────┤
│ [ Masalah saya sudah selesai ]               │
│ [ Tetap lanjut buat tiket › ]                │
└──────────────────────────────────────────────┘
```

```text
┌──────────────────────────────────────────────┐
│ ‹ Detail                        Langkah 3/4  │
├──────────────────────────────────────────────┤
│ Transaksi terkait *                          │
│ ┌──────────────────────────────────────────┐ │
│ │ ● 29 Okt 10.12 · Deposit Rp5.000.000     │ │
│ │   BCA · Diproses                         │ │
│ │ ○ 27 Okt 15.40 · Deposit Rp2.000.000     │ │
│ │   BCA · Berhasil                         │ │
│ └──────────────────────────────────────────┘ │
│ Ceritakan masalahnya *                       │
│ ┌──────────────────────────────────────────┐ │
│ │ Sudah 3 jam belum masuk ke RDN…          │ │
│ └──────────────────────────────────────────┘ │
│ Lampiran (maks 5 file, 10 MB)                │
│ [ + Tangkap layar OLT ] [ + Gambar/PDF ]     │
│ (!) Tutupi data sensitif sebelum mengirim.   │
│     [ Buka alat tutup/blur ]                 │
│                                 [ Lanjut › ] │
└──────────────────────────────────────────────┘
```

```text
┌──────────────────────────────────────────────┐
│ ‹ Tinjau & kirim                Langkah 4/4  │
├──────────────────────────────────────────────┤
│ Dana (RDN) › Deposit belum masuk             │
│ Rp5.000.000 · BCA · 29 Okt 10.12             │
│ Data yang ikut dikirim            [ Lihat ▾ ]│
│ • Versi app 3.2.1 · Android 15 · Pixel 8     │
│ • Layar terakhir: Deposit                    │
│ • Log teknis (sudah disanitasi)              │
├──────────────────────────────────────────────┤
│ ☐ Ajukan sebagai pengaduan resmi             │
│   Pengaduan punya tenggat penyelesaian dan   │
│   bukti tertulis resmi.  (i) Apa bedanya?    │
├──────────────────────────────────────────────┤
│                                  [ Kirim ]   │
└──────────────────────────────────────────────┘
```

Setelah dikirim:

```text
┌──────────────────────────────────────────────┐
│ ✓ Tiket diterima                             │
├──────────────────────────────────────────────┤
│ Nomor tiket       CC-2026-10-000123          │
│ Perkiraan respons hari ini, sebelum 14.00    │
│ Pengaduan: bukti penerimaan (PDF) dikirim    │
│ ke aplikasi dan email.                       │
│ [ Unduh bukti ]           [ Lihat tiket › ]  │
└──────────────────────────────────────────────┘
```

Bila nasabah sudah punya tiket terbuka untuk kategori atau transaksi yang sama:

```text
┌──────────────────────────────────────────────┐
│ Anda sudah punya tiket terbuka untuk         │
│ transaksi ini: CC-2026-10-000118.            │
│ [ Lanjutkan di sana ]  [ Tetap buat baru ]   │
└──────────────────────────────────────────────┘
```

Catatan:
- **Formulir langkah 3 dinamis per kategori**, diatur dari panel. Contoh: kategori Order menampilkan daftar order OLT nasabah, kategori Dana menampilkan transaksi RDN.
- **Konteks perangkat terlihat oleh nasabah** sebelum dikirim. Bila OLT sedang tidak bisa dihubungi, tiket tetap dibuat dan konteksnya ditandai "tidak tersedia".

### A4. Live chat

```text
┌──────────────────────────────────────────────┐
│ ‹ Chat CS · CC-2026-10-000124             ⋮  │
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ Rina · ID CS-0412          Agen resmi ✓  │ │
│ │ Kode verifikasi 7K4-Q2          [ Cek ]  │ │
│ └──────────────────────────────────────────┘ │
│       Posisi antrean 3 · tunggu ±2 mnt       │
│       (tampil sebelum agen bergabung)        │
│ [Sistem] Rina bergabung · tim Dana           │
│                  Halo, deposit saya belum    │
│                  masuk.          10.15 ✓✓    │
│ Rina: Baik Pak Budi, saya cek dulu ya.       │
│ ┌──────────────────────────────────────────┐ │
│ │ Kartu transaksi                          │ │
│ │ Deposit Rp5.000.000 · BCA · Diproses     │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ Permintaan dokumen                       │ │
│ │ Bukti transfer               [ Unggah ]  │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ Verifikasi identitas · ubah rekening     │ │
│ │ [ Verifikasi di OLT ]  PIN / biometrik   │ │
│ │ Jangan pernah ketik PIN di chat.         │ │
│ └──────────────────────────────────────────┘ │
│ Rina sedang mengetik…                        │
├──────────────────────────────────────────────┤
│ (!) Pesan Anda terlihat seperti kode OTP.    │
│     CS tidak pernah meminta OTP.             │
│     [ Hapus ]  [ Tetap kirim (disamarkan) ]  │
│ [+] [ Tulis pesan…                ] [Kirim]  │
└──────────────────────────────────────────────┘
```

Di akhir chat:

```text
┌──────────────────────────────────────────────┐
│ Chat selesai                                 │
├──────────────────────────────────────────────┤
│ Bagaimana layanan kami?     ★ ★ ★ ★ ☆        │
│ Masalah Anda selesai?       [ Ya ] [ Belum ] │
│ Komentar (opsional)                          │
│ ┌──────────────────────────────────────────┐ │
│ │                                          │ │
│ └──────────────────────────────────────────┘ │
│ [ Kirim ]               [ Unduh transkrip ]  │
└──────────────────────────────────────────────┘
```

Catatan:
- Posisi antrean diperbarui realtime.
- Bila nasabah menutup aplikasi, chat berlanjut sebagai tiket dan balasan agen datang sebagai notifikasi.
- Pesan yang tampak berisi OTP, PIN, password, nomor kartu, atau rekening lengkap memunculkan peringatan. Bila tetap dikirim, server menyamarkannya sebelum disimpan.

### A5. Tiket saya

```text
┌──────────────────────────────────────────────┐
│ ‹ Tiket saya                           Cari  │
├──────────────────────────────────────────────┤
│ [Terbuka 2] [Menunggu Anda 1] [Selesai]      │
│ ┌──────────────────────────────────────────┐ │
│ │ CC-2026-10-000123          ● 1 balasan   │ │
│ │ Deposit belum masuk                      │ │
│ │ Menunggu tanggapan Anda · 2 jam lalu     │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ PGD-2026-000045               Pengaduan  │ │
│ │ Order tidak tereksekusi                  │ │
│ │ Sedang diproses · tenggat 26 Nov         │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

```text
┌──────────────────────────────────────────────┐
│ ‹ PGD-2026-000045 · Pengaduan                │
├──────────────────────────────────────────────┤
│ Sedang diproses (diperpanjang)               │
│ Tenggat penyelesaian: 26 Nov 2026            │
├──────────────────────────────────────────────┤
│ ● 29 Okt 10.20  Pengaduan diterima           │
│                 [ Bukti penerimaan (PDF) ]   │
│ ● 29 Okt 10.45  Rina: mohon unggah           │
│                 konfirmasi transaksi.        │
│ ● 29 Okt 11.02  Anda mengunggah 1 file       │
│ ● 6 Nov 09.00   Tenggat diperpanjang 10      │
│                 hari kerja. [ Surat (PDF) ]  │
├──────────────────────────────────────────────┤
│ [ Balas ]  [ Unggah dokumen ]                │
│ [ Masalah sudah selesai ]                    │
│ [ Ajukan keberatan ]  (setelah tanggapan)    │
└──────────────────────────────────────────────┘
```

### A6. Verifikasi agen dan tombol darurat

```text
┌──────────────────────────────────────────────┐
│ Verifikasi agen                              │
├──────────────────────────────────────────────┤
│ Ada yang mengaku CS menghubungi Anda         │
│ lewat telepon, WhatsApp, atau email?         │
│ Masukkan ID dan kode yang ia sebutkan.       │
│ ID agen   [ CS-0412        ]                 │
│ Kode      [ 7K4-Q2         ]                 │
│ [ Periksa ]                                  │
├──────────────────────────────────────────────┤
│ ✓ Agen resmi: Rina (CS-0412), sedang         │
│   menangani tiket Anda CC-2026-10-000124.    │
│ ✗ Tidak cocok: jangan berikan data apa pun.  │
│   [ Laporkan CS palsu ]                      │
└──────────────────────────────────────────────┘
```

```text
┌──────────────────────────────────────────────┐
│ Amankan akun saya                            │
├──────────────────────────────────────────────┤
│ Kami akan segera:                            │
│ • mengeluarkan akun dari semua perangkat     │
│ • mengunci transaksi sementara               │
│ • melapor ke tim keamanan (prioritas P1)     │
│ Membuka kunci memerlukan verifikasi resmi.   │
│ [ Batal ]              [ Amankan sekarang ]  │
└──────────────────────────────────────────────┘
```

"Verifikasi agen" ditujukan untuk orang yang **mengaku CS di luar aplikasi**, misalnya lewat telepon atau WhatsApp.
- Kode agen berganti setiap 60 detik.
- Hasil hanya "cocok" bila agen itu sedang menangani tiket nasabah yang memeriksa.

Halaman "Kontak resmi" (dikelola dari panel) dan "Laporkan CS palsu" bisa dibuka dari Beranda Bantuan.

## 3. CS Console

Dioptimalkan untuk layar lebar (≥ 1440 px). Semua aksi punya shortcut keyboard (daftarnya dibuka dengan `?`).

### B1. Login staf

```text
┌────────────────────────────────────────────┐
│ CS Console                                 │
├────────────────────────────────────────────┤
│ Email kerja   [                        ]   │
│ Password      [                        ]   │
│ [ Masuk ]                                  │
│ Hanya bisa diakses lewat VPN kantor.       │
└────────────────────────────────────────────┘
```

```text
┌────────────────────────────────────────────┐
│ Verifikasi 2 langkah                       │
├────────────────────────────────────────────┤
│ Kode dari aplikasi authenticator           │
│ [ _ _ _ _ _ _ ]                            │
│ [ Verifikasi ]                             │
│ Sesi berakhir setelah 15 menit tanpa       │
│ aktivitas.                                 │
└────────────────────────────────────────────┘
```

### B2. Inbox (tata letak utama)

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ● Online ▾ · Chat 2/3 · Tiket aktif 14/25 · [ Cari tiket, nasabah, pesan…  Ctrl+K ] · Notif 3    │
├──────────────────────┬──────────────────────────────────────┬────────────────────────────────────┤
│ TAMPILAN             │ Mendekati tenggat (7)       Kolom ▾  │ CC-2026-10-000123                  │
│ Chat aktif saya    2 │ Status ▾  Prioritas ▾  Kanal ▾       │ Deposit belum masuk · P3           │
│ Tiket saya        14 │ ──────────────────────────────────── │                                    │
│ Belum ditugaskan   9 │ [M] 00:42  P2  PGD-2026-000045 chat  │ (isi workspace: lihat B3)          │
│ Mendekati tenggat  7 │     Budi S. · Order tdk tereksekusi  │                                    │
│ Pengaduan          5 │ [K] 03:10  P3  CC-2026-10-000123 app │                                    │
│ Menunggu nasabah   6 │     Sari I. · Deposit belum masuk    │                                    │
│ Eskalasi ke saya   1 │ [H] 1j20   P3  CC-2026-10-000130 mail│                                    │
│ ──────────────────── │     Dewi C. · Lupa PIN               │                                    │
│ TERSIMPAN            │ ──────────────────────────────────── │                                    │
│ Dana > 2 hari      3 │ Sisa SLA: [M]erah [K]uning [H]ijau   │                                    │
│ + Tampilan baru      │                                      │                                    │
└──────────────────────┴──────────────────────────────────────┴────────────────────────────────────┘
```

### B3. Workspace tiket

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PGD-2026-000045 · Pengaduan (tertulis) · P2 · Sedang diproses ▾ · Tim Transaksi                 │
│ SLA respons: terpenuhi · Tenggat regulasi: 12 Nov 23.59 WIB (sisa 4 hari kerja)                 │
│ Sari (L2) sedang melihat tiket ini · sedang mengetik…                                           │
├────────────────────────────────────────────────────────────────┬────────────────────────────────┤
│ 29 Okt 10.20  Nasabah · chat                                   │ CUSTOMER 360                   │
│   Order BBCA saya tidak tereksekusi padahal harga sudah        │ Budi S****** · ID 1001         │
│   menyentuh.                          [ screenshot.png ]       │ Kode nsb ****1001 [Tampilkan]  │
│ 29 Okt 10.22  Sistem: dijadikan pengaduan; bukti terkirim      │ Akun aktif · sejak 2021        │
│ 29 Okt 10.30  ░ CATATAN INTERNAL · Rina ░                      │ Email bu***@gmail.com          │
│               ░ Cek log matching engine sesi 1. ░              │ HP 0812****789                 │
│ 29 Okt 10.31  Rina (publik): Baik Pak, kami cek dulu.          │ ────────────────────────────── │
│ ────────────────────────────────────────────────────────────── │ Tiket sebelumnya (3)        ›  │
│ (●) Balasan publik    ( ) Catatan internal                     │ CSAT rata-rata 4,3             │
│ Macro ▾  Artikel ▾  Lampiran  Minta dokumen  Verifikasi        │ ────────────────────────────── │
│ [ Halo Pak {nama_panggilan}, mohon kirim kode OTP…     ]       │ DATA OLT (hanya-baca)          │
│ (!) Balasan meminta "kode OTP". CS dilarang meminta OTP.       │ Order terkait:                 │
│     Pesan ditahan, supervisor diberi tahu. [ Ubah balasan ]    │ BBCA Beli 10 lot @9.250        │
│ [ Kirim & set: Menunggu nasabah ▾ ]              [ Aksi ▾ ]    │ Ditolak · E-1021               │
│                                                                │ [Order terakhir] [Dana RDN]    │
│                                                                │ [Sesi & perangkat] [Keamanan]  │
│                                                                │ ────────────────────────────── │
│                                                                │ Catatan: lebih suka email      │
└────────────────────────────────────────────────────────────────┴────────────────────────────────┘
```

Menu **Aksi**:
- eskalasi atau transfer (dengan catatan serah terima);
- jeda menunggu dokumen;
- perpanjang tenggat (B5);
- gabung/pisah tiket;
- hubungkan ke insiden;
- tiket anak;
- ajukan kompensasi;
- tutup (akar masalah dan ringkasan resolusi wajib diisi).

Semua perubahan status mengikuti aturan di bagian 4.1 dan ditolak server bila tidak sah.

### B4. Membuka data tersamar

```text
┌──────────────────────────────────────────────┐
│ Tampilkan data                               │
├──────────────────────────────────────────────┤
│ Field      Nomor HP                          │
│ Alasan *   [ Verifikasi panggilan balik ▾ ]  │
│ Berlaku 5 menit, hanya untuk field ini.      │
│ Tercatat di audit log atas nama Anda.        │
│ [ Batal ]                    [ Tampilkan ]   │
└──────────────────────────────────────────────┘
```

### B5. Perpanjang tenggat pengaduan

```text
┌────────────────────────────────────────────────────────┐
│ Perpanjang tenggat · PGD-2026-000045                   │
├────────────────────────────────────────────────────────┤
│ Tenggat saat ini   12 Nov 2026 (sisa 4 hari kerja)     │
│ Kondisi *          [ Butuh data pihak ketiga      ▾ ]  │
│ Penjelasan untuk nasabah *                             │
│ ┌────────────────────────────────────────────────────┐ │
│ │ Kami menunggu konfirmasi dari bank kustodian…      │ │
│ └────────────────────────────────────────────────────┘ │
│ Tenggat baru       26 Nov 2026 (+10 hari kerja)        │
│ Surat perpanjangan dikirim lewat aplikasi, email, PDF. │
│                                  [ Pratinjau surat ]   │
│ Hanya 1 kali, sebelum tenggat; tidak bisa dibatalkan.  │
│ [ Batal ]                      [ Perpanjang & kirim ]  │
└────────────────────────────────────────────────────────┘
```

### B6. Dashboard supervisor

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Antrean 12 · Tunggu terlama 4:12 · Agen online 8, istirahat 2 · Chat 19/24 kapasitas            │
├──────────────────────────────────────────────┬──────────────────────────────────────────────────┤
│ ANTREAN PER TIM            ANTRE  TUNGGU     │ PENGADUAN MENDEKATI TENGGAT                      │
│ Dana       ██████████        6     3:40      │ PGD-2026-000045   H-1   Rina      [ Buka ]       │
│ Transaksi  █████             3     1:05      │ PGD-2026-000051   H-3   Dimas     [ Buka ]       │
│ Umum       ███               2     0:30      │ Lewat SLA internal: 2 tiket       [ Lihat ]      │
│ ──────────────────────────────────────────── │ ──────────────────────────────────────────────── │
│ AGEN       STATUS         CHAT               │ INSIDEN AKTIF                                    │
│ Rina       Online         2/3                │ Penarikan via Bank X tertunda · 37 tiket         │
│ Sari       Online         3/3  penuh         │ Banner aktif     [ Kirim pembaruan massal ]      │
│ Dimas      Istirahat      0/3                │ Saran: lonjakan "Login" +12 dalam 15 menit       │
│                                              │                           [ Buat insiden ]       │
└──────────────────────────────────────────────┴──────────────────────────────────────────────────┘
```

## 4. Alur utama

### 4.1 Status tiket (ditegakkan di server)

Alur utama: `new → open → resolved → closed`. Transisi selain yang ada di tabel ditolak server.

| Dari | Ke | Oleh / syarat |
|---|---|---|
| `new` | `open` | Agen mengambil, atau sistem menugaskan |
| `new`, `open` | `cancelled` | Dibatalkan nasabah, atau ditandai duplikat oleh agen (wajib alasan) |
| `open` | `pending_customer` | Agen meminta info/dokumen. SLA dijeda |
| `pending_customer` | `open` | Nasabah membalas atau mengunggah |
| `pending_customer` | `resolved` | Otomatis setelah 7 hari kerja, **kecuali pengaduan** |
| `open` | `pending_internal`, `pending_third_party` | Menunggu tim lain / pihak ketiga. SLA tetap jalan |
| `pending_internal`, `pending_third_party` | `open` | Jawaban diterima |
| `open`, `pending_*` | `escalated` | Eskalasi dengan alasan |
| `escalated` | `open` | Diterima tim/level tujuan |
| `open`, `pending_*`, `escalated` | `extended` | Hanya pengaduan, lewat aksi Perpanjang (sekali, sebelum tenggat) |
| `extended` | `open`, `pending_*` | Penanganan berlanjut. Label "diperpanjang" tetap tampil |
| `open`, `pending_*`, `escalated`, `extended` | `resolved` | Akar masalah + resolusi wajib. Pengaduan: tanggapan akhir terkirim |
| `resolved` | `open` | Nasabah membuka kembali (≤ 7 hari) atau menyatakan keberatan |
| `resolved` | `closed` | Otomatis setelah 7 hari |
| `closed` | – | Final. Balasan baru membuat tiket lanjutan yang tertaut |

### 4.2 Tenggat pengaduan

```text
Lisan (chat, telepon, datang langsung)
  diterima ──────────── 5 hari kerja ────────────► tenggat
  └ bukti penerimaan seketika (aplikasi + email + PDF)

Tertulis (formulir, email, surat)
  diterima ── menunggu dokumen ── lengkap ──── 10 hari kerja ────► tenggat
              (nasabah ≤ 10 hari     └ bila perlu: perpanjangan sekali,
               kerja; tenggat belum    +10 hari kerja, surat terkirim
               berjalan)               sebelum tenggat awal

Peringatan otomatis: H-3 · H-1 · hari H · terlambat ──► agen, supervisor, kepatuhan
```

Tenggat tidak bisa diubah manual. Tenggat hanya berubah lewat dua aksi resmi: jeda menunggu dokumen dan perpanjangan. Keduanya tercatat. Nilai di atas adalah default spesifikasi dan menunggu konfirmasi tim kepatuhan ([compliance-questions.md](compliance-questions.md) bagian C).

### 4.3 Live chat: antrean dan penugasan

1. **Mulai chat.** Nasabah memulai chat dari alur A3 (kategori + konteks). Tiket dan sesi chat masuk ke antrean tim sesuai aturan routing.
2. **Posisi antrean.** Posisi dan perkiraan waktu tunggu dikirim realtime ke `care:customer:<id>`.
3. **Memilih agen.** `care-worker` memilih agen yang:
   - Online;
   - masih di bawah kapasitas;
   - keahliannya cocok;
   - diutamakan agen yang sama bila nasabah kembali dalam 48 jam.

   Pemilihan memakai `FOR UPDATE SKIP LOCKED`, sehingga aman di banyak replika. Tawaran dikirim ke `care:agent:<id>`.
4. **Tidak diterima 60 detik.** Chat dialihkan ke agen lain, dan kejadiannya dicatat. Bila semua agen sibuk, nasabah melihat antrean dan bisa "tinggalkan pesan" (menjadi tiket).
5. **Percakapan.** Berjalan lewat `care:ticket:<id>`. Catatan internal dan deteksi tabrakan lewat `care:ticket:<id>:staff`. Database tetap sumber kebenaran, dan klien sinkron ulang setelah reconnect.
6. **Agen istirahat atau logout.** Chat aktifnya tidak hilang: agen wajib menyerahkannya, atau chat kembali ke antrean setelah N menit.
7. **Selesai.** Nasabah mengisi CSAT dan "masalah selesai?" (FCR), dan transkrip bisa diunduh.

## 5. Keputusan (ditetapkan 30 Okt 2026)

Pemilik produk meminta tim memilih yang terbaik sesuai standar customer care. Keempat usulan di bawah dipakai apa adanya.

1. **Snapshot order berisi lot dan harga.**
   - Aturan proyek sebelumnya: *"jangan pernah menyimpan jumlah lot, nilai, atau harga beli"* (untuk fitur sosial). Pengaduan order butuh salinan order sebagai bukti, karena data di OLT bisa berubah.
   - **Usulan:** diizinkan **hanya** di schema `care`, dengan syarat:
     - hanya order yang dipilih nasabah atau dilampirkan agen secara sadar;
     - hanya bisa dibuka agen yang menangani, supervisor, dan kepatuhan, dan setiap pembukaan tercatat;
     - tidak pernah masuk log atau fitur sosial.
   - Ringkasan portofolio tidak pernah disimpan.
2. **Login staf.** GoTrue + TOTP, dipakai bersama panel admin F1 lewat `olt_staff_kit`. SSO internal bisa menyusul bila perusahaan punya.
3. **`customer-adapter` sebagai service terpisah**, bukan modul `market-adapter`. Kredensial dan jaringannya terpisah, karena data nasabah jauh lebih sensitif dari harga.
4. **Urutan kerja.**
   - Spesifikasi menempatkan customer care setelah tahap 6 (hardening produksi). Tahap 4–7 addendum produksi dan F1 (panel admin, `notifier`, `moderation`) belum dikerjakan.
   - **Usulan:** C1 (fondasi backend, belum ada UI) dimulai sekarang, karena tidak bergantung pada tahap itu.
   - Selama jawaban kepatuhan belum lengkap, sistem memakai nilai default spesifikasi sebagai **konfigurasi**. Jawaban kepatuhan nanti hanya mengubah konfigurasi, bukan kode.
   - Peluncuran ke nasabah tetap menunggu:
     - tahap 6 produksi;
     - push notification (`notifier`, F1);
     - jawaban kepatuhan yang berlabel "Sebelum peluncuran".

## 6. Rencana C1 (selesai 30 Okt 2026)

Hasilnya dirangkum di [backend.md](backend.md). Ada dua penyesuaian dari rencana:
- **Timer tenggat dan peringatan dijalankan pg_cron di database**, bukan oleh `care-worker`. Dengan begitu tenggat, peringatan, dan datanya berada dalam satu transaksi yang dites pgTAP. `care-worker` hanya mengurus PDF dan email.
- **Staf contoh per peran belum dibuat di seed.** Staf butuh akun GoTrue dengan TOTP, yang disiapkan bersama login CS Console di C3. Tes memakai helper `tests.create_staff`.

- **Migrasi schema `care`.**
  - Kategori dan formulir dinamis.
  - Tiket dan lini masa (*append-only*, partisi bulanan).
  - Pesan yang sudah disamarkan.
  - State machine (bagian 4.1).
  - Mesin tenggat + kalender hari kerja.
  - Pengaduan: lisan/tertulis, nomor tanpa celah, jeda, dan perpanjangan sekali.
  - Staf dan role (GoTrue + TOTP, `aal2`).
  - Audit log *append-only*.
- **`care-worker`.**
  - Timer tenggat dan peringatan bertahap.
  - Bukti penerimaan PDF + email lewat pola *outbox*. Di development, email ditangkap Mailpit (MIT).
- **`customer-adapter` mode mock.** OLT dummy diperluas dengan nasabah, order, dan transaksi tiruan.
- **Seed.** Kategori awal (bagian 5.2 spesifikasi), contoh kalender libur 2026–2027 (ditandai "wajib diperiksa kepatuhan"), dan staf contoh untuk setiap role.
- **Tes.**
  - pgTAP: hari kerja, state machine, RLS per role, *append-only*, klasifikasi, dan penomoran.
  - Go: PDF, email, dan adapter.
- **Kriteria selesai:** semua tes SLA & regulasi lulus.
