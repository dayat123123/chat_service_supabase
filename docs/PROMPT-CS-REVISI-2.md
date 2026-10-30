# Revisi CS-2: Tiket Bebas Diambil CS, Integrasi ke Aplikasi Nasabah & Web CS Khusus

> Revisi ini **memperbarui `docs/PROMPT-CS-CHAT.md`**. Simpan sebagai `docs/PROMPT-CS-REVISI-2.md`.
> Jika ada yang bertentangan, **revisi ini yang berlaku**. Bagian `[...]` silakan disesuaikan.
> Pekerjaan CS1 (backend, `cs_api`, `customer-adapter`, demo page) **dipertahankan dan disempurnakan**, bukan dibuat ulang.

---

## 0. Ringkasan Perubahan

1. **Model penugasan berubah menjadi "ambil tiket" (pull/claim).**
   - Setiap permintaan bantuan nasabah menjadi **tiket**.
   - Tiket baru masuk ke **daftar tiket terbuka** yang terlihat oleh semua CS.
   - **CS mana pun bebas memilih dan mengambil** tiket.
   - **Begitu satu CS mengambil tiket, CS lain tidak bisa mengambilnya lagi.**
   - Matching engine otomatis (penawaran ke agen dengan hitung mundur) **dinonaktifkan secara default**, tetapi kodenya boleh disimpan sebagai mode opsional `auto_assign` di pengaturan.
2. **Fitur CS dipasang langsung di aplikasi OLT** (Flutter Windows + Android), memakai fitur chat yang sudah ada (stream, room, widget chat, Realtime, lampiran, cache offline).
3. **Web CS khusus untuk CS saja**:
   - Kolom "Nasabah" di sisi kiri halaman demo **dihapus** dari web CS.
   - Tombol pemilih agen (Nadia / Bima / Laras) **diganti login akun CS** yang sebenarnya.
   - Halaman demo yang sekarang **hanya boleh ada di profil `dev`** dan tidak ikut ter-deploy ke produksi.

---

## 1. Tiket

### 1.1 Definisi
- **Tiket = satu sesi bantuan** di dalam room CS permanen milik nasabah (`support_sessions` dari CS1). Ganti istilah di UI dan API menjadi "tiket" dengan **nomor tiket** yang mudah dibaca, misalnya `CS-20261030-0042`.
- Riwayat chat nasabah tetap menyambung dalam satu room. Setiap tiket menandai rentang percakapannya sendiri, dengan pemisah "Tiket #CS-... dibuka / ditutup" di chat.

### 1.2 Status tiket

| Status | Arti | Siapa yang bisa membalas sebagai CS |
|---|---|---|
| `open` | Baru, belum diambil CS | Belum ada |
| `claimed` | Sudah diambil satu CS (pemilik) | **Hanya pemilik** |
| `waiting_customer` | CS menunggu balasan nasabah | Hanya pemilik |
| `resolved` | Diselesaikan CS. Nasabah bisa membuka kembali dalam `[24 jam]` | — |
| `closed` | Final (otomatis setelah masa buka kembali, atau ditutup nasabah) | — |

Transisi status ditegakkan di **server** (state machine). Transisi yang tidak sah ditolak.

### 1.3 Aturan tiket per nasabah
- Satu nasabah hanya boleh punya **satu tiket aktif** (`open` / `claimed` / `waiting_customer`) pada satu waktu. Ditegakkan dengan **partial unique index**.
- Kalau nasabah menekan "Chat CS" saat masih punya tiket aktif, aplikasi langsung membuka tiket tersebut. Tidak dibuat tiket baru.
- Nasabah mengetik setelah tiket `resolved`:
  - Masih dalam masa buka kembali: tiket yang sama dibuka lagi dan kembali ke CS pemilik.
  - Kalau CS pemilik offline lebih dari `[X menit]`: kembali ke `open`.
- Nasabah mengetik setelah tiket `closed`: dibuat tiket baru.

---

## 2. Mengambil Tiket (inti revisi)

### 2.1 Aturan bisnis
- Semua CS yang login melihat **daftar tiket `open`**, dan bebas memilih tiket mana pun (tidak harus urutan teratas).
- Tombol **"Ambil tiket"** mengubah tiket menjadi `claimed` dengan pemilik = CS tersebut.
- **Sekali diambil, tiket terkunci untuk CS itu**:
  - Tiket hilang dari daftar terbuka **di layar semua CS lain secara realtime**.
  - CS lain **tidak bisa** mengambil, membalas, menutup, atau mengubah tiket tersebut.
- Tiket hanya berpindah pemilik lewat jalur resmi:
  1. Pemilik **melepas** tiket ("Lepas ke antrean"), sehingga status kembali `open`. Wajib mengisi alasan.
  2. Pemilik **mentransfer** langsung ke CS tertentu. CS penerima harus menerima, dan selama belum diterima, tiket tetap milik pengirim.
  3. **Supervisor** memindahkan tiket. Wajib mengisi alasan, dan tercatat di audit log.
- Pemilik yang offline atau logout **tetap menjadi pemilik** tiketnya. Tiket tidak kembali ke antrean secara otomatis, **kecuali** diaktifkan di pengaturan: "lepas otomatis jika pemilik offline > `[N]` menit" (default: **mati**). Dashboard supervisor menandai tiket milik CS yang sedang offline.
- **Batas tiket aktif per CS**: `[5]`, dapat diatur per CS. Saat sudah penuh, tombol "Ambil" dinonaktifkan dengan keterangan.
- CS harus berstatus **Online** untuk mengambil tiket.

### 2.2 Implementasi wajib anti-rebutan (race condition)
Pengambilan tiket **wajib atomik di database**, bukan dicek di client lalu di-update terpisah. Gunakan satu fungsi Postgres `cs.claim_ticket(ticket_id)` dengan `SECURITY DEFINER`, `search_path` eksplisit, dan identitas CS dari `auth.uid()` (bukan dari parameter):

```sql
-- inti logika (sesuaikan dengan schema yang ada)
UPDATE cs.tickets
SET    status = 'claimed', owner_agent_id = <agent dari auth.uid()>,
       claimed_at = now(), version = version + 1
WHERE  id = $1
  AND  status = 'open'
  AND  owner_agent_id IS NULL
  AND  <agen online dan jumlah tiket aktifnya < batas>
RETURNING *;
```

- Kalau 0 baris terpengaruh, kembalikan error yang jelas: **"Tiket sudah diambil oleh [nama CS]"** atau "Batas tiket aktif Anda sudah penuh".
- Pengecekan batas tiket aktif dilakukan **di transaksi yang sama**, dengan mengunci baris CS (`SELECT ... FOR UPDATE` pada data agen). Dua klik "Ambil" bersamaan oleh CS yang sama tidak boleh melewati batas.
- Lapisan pengaman tambahan di database:
  - Constraint/trigger: tiket berstatus `claimed` / `waiting_customer` **wajib** punya `owner_agent_id`.
  - **Trigger/RLS pada `messages`**: pesan dengan `sender_role = 'agent'` di room tiket hanya diterima jika pengirim adalah **pemilik tiket aktif** atau supervisor yang bergabung. Pesan dari CS lain ditolak di server, walaupun UI-nya dimanipulasi.
  - Semua aksi ubah tiket (balas, tutup, lepas, transfer) memeriksa kepemilikan di server.
- Optimistic concurrency: kolom `version` dipakai untuk aksi ubah tiket. Kalau versi berbeda, aksi ditolak dan UI memuat ulang.
- **Realtime**: setelah claim berhasil, broadcast event `ticket_claimed` ke topik `cs:queue`. Semua web CS langsung menghapus tiket dari daftar terbuka (atau menampilkannya sebagai "Diambil oleh [nama]" selama 2 detik lalu hilang).
- **UI**: tombol "Ambil" langsung berubah menjadi loading dan nonaktif setelah diklik, supaya tidak terjadi klik ganda. Kalau server menolak, tampilkan toast dengan alasannya dan hapus tiket dari daftar.
- Event `claimed`, `released`, `transferred`, `reassigned`, `resolved`, `reopened`, dan `closed` dicatat di `session_events` / audit log, lengkap dengan siapa dan kapan.

### 2.3 Tes wajib
- **Tes konkurensi**: `[50]` CS mencoba mengambil tiket yang sama secara bersamaan (paralel, langsung ke fungsi database). **Tepat 1 yang berhasil**, dan sisanya mendapat pesan "sudah diambil".
- `[200]` tiket dan `[30]` CS mengambil secara acak dan bersamaan. Tidak ada tiket dengan dua pemilik, dan tidak ada CS yang melebihi batas tiket aktif.
- CS non-pemilik mencoba membalas atau menutup tiket lewat API langsung → **ditolak**.
- Alur lepas, transfer (diterima/ditolak), dan reassign supervisor.
- Tes ini juga dijalankan pada setup **multi-replika** API.

---

## 3. Integrasi di Aplikasi Nasabah (OLT Flutter)

Pasang ke aplikasi OLT yang sebenarnya (bukan halaman demo), memakai package `olt_social` / modul chat yang sudah ada. Buat modul `support` di dalamnya, atau package `olt_support` bila lebih rapi. **Ikuti konvensi kode OLT** (state management, routing, tema).

### 3.1 Titik masuk
- Menu **"Bantuan / Chat CS"** di navigasi utama, dengan badge jumlah balasan CS yang belum dibaca.
- **Room CS ditampilkan di daftar chat** yang sudah ada, di urutan teratas dan disematkan, dengan nama "CS [Nama Sekuritas]" dan **badge resmi**. Room ini tidak bisa dihapus atau dibisukan sepenuhnya oleh nasabah.
- Tombol bantuan kontekstual di layar order, deposit/tarik dana, dan portofolio. Topik dan kartu order/transaksi terisi otomatis.

### 3.2 Membuat tiket
1. Nasabah menekan "Chat CS".
2. Kalau sudah ada tiket aktif, langsung buka tiket itu.
3. Kalau belum, nasabah memilih topik (satu layar), lalu boleh melampirkan kartu order/transaksi dengan sekali ketuk.
4. Tiket langsung dibuat dan nasabah bisa mengetik.

### 3.3 Tampilan di room CS
- **Header tiket** (menempel di atas chat): nomor tiket, topik, dan status yang ramah:
  - "Menunggu CS" (+ jumlah tiket di depan / perkiraan tunggu bila tersedia)
  - "Ditangani oleh **[nama CS]** – CS Resmi"
  - "Menunggu balasan Anda"
  - "Selesai"
- Pesan sistem **ringkas dan tidak berulang**. Satu pesan untuk setiap kejadian penting: tiket dibuat, diambil CS, dialihkan, selesai. Salam dan pengingat keamanan digabung menjadi satu pesan.
- Pesan CS menampilkan nama dan badge "CS Resmi".
- Fitur chat lengkap: teks, gambar/screenshot, kartu order, typing indicator, status terkirim/dibaca, dan balas pesan.
- Aksi nasabah:
  - **Akhiri chat / tandai selesai**.
  - **Ajukan pengaduan** (flag `complaint`).
  - **Laporkan CS palsu**.
  - **Lampirkan order**.

  Taruh aksi ini di menu "⋯" atau di baris di atas kolom input supaya tidak memenuhi layar.
- Setelah tiket `resolved`: **rating 1–5** + komentar opsional, langsung di dalam chat.
- **Riwayat tiket**: menu "Tiket saya" berisi daftar tiket lama (nomor, topik, tanggal, status, rating). Ketuk tiket untuk melompat ke bagian chat tersebut.
- **Notifikasi**: push (Android) dan notifikasi Windows saat CS mengambil tiket, membalas, atau menyelesaikan tiket.
- **Offline**: pesan diantrekan dan dikirim saat online (pakai `client_id`, idempoten). Status koneksi ditampilkan.
- Peringatan saat nasabah mengetik pola OTP, PIN, password, atau nomor kartu/rekening, serta masking di server (sudah ada di CS1, pastikan aktif).

### 3.4 Desktop vs Android
- **Windows**: room CS bisa dibuka sebagai panel samping atau jendela terpisah, supaya nasabah tetap bisa melihat layar trading sambil chat.
- **Android**: layar penuh dengan tombol kembali ke layar asal.

---

## 4. Web CS (khusus CS)

Web terpisah `apps/cs-console` (Flutter web). **Hanya untuk CS dan supervisor.** Tidak ada kolom nasabah dan tidak ada pemilih agen demo.

### 4.1 Login
- Halaman login akun CS (email/username + password + **2FA TOTP**). Akses hanya lewat **VPN**.
- Sesi berakhir setelah idle `[30 menit]` dengan peringatan sebelum logout.
- Setelah login, status default **Offline**. CS harus memilih **Online** untuk mulai mengambil tiket.

### 4.2 Tata letak (lebar penuh, 3 kolom)

```
┌───────────────────────────────────────────────────────────────────────────┐
│ Logo · CS Console     [● Online ▾]  Tiket aktif 2/5   🔔  Nadia (CS-0045) ▾│
├──────────────────────┬───────────────────────────────────┬────────────────┤
│ [Terbuka 7] [Saya 2] │ #CS-20261030-0042 · Order ·  P2   │ Info nasabah   │
│ [Selesai hari ini]   │ Sari Wulandari  · Ditangani: Anda │ (masking)      │
│ 🔍 cari / filter     │───────────────────────────────────│ Order terkait  │
│ ┌──────────────────┐ │                                   │ Transaksi dana │
│ │Sari W. · Order   │ │        percakapan                 │ Perangkat      │
│ │"order saya..."   │ │                                   │ Riwayat tiket  │
│ │menunggu 3m [Ambil]│ │                                   │ Catatan intern │
│ └──────────────────┘ │───────────────────────────────────│                │
│  ...                 │ [Balas | Catatan internal]  /quick │                │
│                      │ [Lepas] [Transfer] [Selesaikan]    │                │
└──────────────────────┴───────────────────────────────────┴────────────────┘
```

Kolom-kolomnya **khusus pekerjaan CS**. Tidak ada panel simulasi nasabah.

### 4.3 Kolom daftar tiket (kiri)
- Tab:
  - **Terbuka**: semua tiket `open`, bisa diambil.
  - **Tiket saya**: `claimed` + `waiting_customer` milik saya.
  - **Selesai hari ini**.
  - Untuk supervisor, tab tambahan **Semua aktif**, yang menampilkan pemilik setiap tiket.
- Setiap kartu tiket menampilkan:
  - Nama nasabah (atau inisial)
  - Topik
  - Prioritas
  - Potongan pesan terakhir
  - **Lama menunggu** (berwarna: hijau < `[5]` menit, kuning < `[15]` menit, merah di atasnya)
  - Badge pesan belum dibaca
  - Flag `complaint` / `fraud` / VIP
- Tombol **"Ambil"** langsung di kartu (tab Terbuka). Mengeklik kartu tanpa mengambil hanya membuka **pratinjau hanya-baca** dengan banner "Ambil tiket ini untuk membalas".
- Urutan default: prioritas, lalu waktu menunggu terlama. Ada filter berdasarkan topik, prioritas, flag, dan pencarian (nomor tiket, nama, kode nasabah, isi pesan).
- Daftar diperbarui **realtime**:
  - Tiket baru muncul.
  - Tiket yang diambil CS lain hilang.
  - Pesan baru menaikkan badge.
- **Notifikasi**: suara + notifikasi browser untuk tiket baru (bisa diatur: semua / prioritas tinggi saja / mati) dan untuk pesan baru di "Tiket saya", termasuk saat tab browser tidak aktif.

### 4.4 Kolom percakapan (tengah)
- Header: nomor tiket, topik, prioritas (bisa diubah pemilik), status, pemilik, dan waktu dibuat.
- Widget chat yang sama dengan aplikasi nasabah, plus fitur CS:
  - **Quick reply** dengan mengetik `/` (variabel `{nama}`, `{nomor_tiket}`, `{nama_cs}`).
  - Lampiran.
  - Kartu order.
  - Permintaan konfirmasi identitas (disetujui nasabah di aplikasi OLT).
  - Tautan bantuan.
- Tab **Catatan internal**, dengan latar kuning dan label "Tidak terlihat nasabah", disimpan di tabel terpisah.
- Pesan CS yang meminta OTP, PIN, atau password **ditahan** dan supervisor diberi peringatan.
- Aksi pemilik:
  - **Tunggu nasabah**: status menjadi `waiting_customer`.
  - **Lepas ke antrean** (wajib alasan).
  - **Transfer ke CS** (pilih CS yang online, beserta catatan serah terima).
  - **Selesaikan** (wajib pilih hasil/tag: terjawab, perlu tindak lanjut, pengaduan, dan lainnya, plus ringkasan singkat).
- Kalau tiket bukan milik saya: kolom input **dinonaktifkan** dengan keterangan "Ditangani oleh [nama CS]". Supervisor mendapat tombol **"Gabung"** dan **"Pindahkan ke…"**.
- Typing indicator dua arah dan status dibaca.

### 4.5 Kolom info nasabah (kanan)
- Data **ber-masking** (NIK, rekening, email, HP). Tombol "Tampilkan" mewajibkan alasan, berlaku sementara, dan tercatat di audit log.
- Data OLT hanya-baca dari `customer-adapter`, dimuat saat dibuka: order terkait / terakhir, transaksi dana terakhir, perangkat & sesi login, dan status keamanan akun.
- Riwayat tiket nasabah sebelumnya beserta rating dan CS penangannya.
- Catatan internal tentang nasabah (persisten antar tiket).
- Kolom bisa diciutkan supaya area chat lebih lebar.

### 4.6 Supervisor
- Tab "Semua aktif" dan dashboard ringkas yang **realtime**:
  - Jumlah tiket terbuka dan waktu tunggu terlama.
  - CS online dan jumlah tiket aktif masing-masing.
  - Tiket milik CS yang sedang offline.
  - Tiket `fraud` / `complaint` yang belum diambil.
- Alert jika tiket terbuka tidak diambil lebih dari `[X menit]`, atau tiket P1 tidak diambil lebih dari `[2 menit]`.
- Aksi: pindahkan tiket (dengan alasan), gabung chat, dan ubah prioritas.
- Laporan sederhana:
  - Tiket per hari.
  - Waktu sampai diambil.
  - Waktu respons pertama dan durasi.
  - Rating per CS.
  - Topik terbanyak.
  - Ekspor CSV.

### 4.7 Pengaturan (`cs_admin`)
- Akun CS (tambah/nonaktifkan, role, batas tiket aktif). Menonaktifkan akun membuat tiket aktif CS tersebut kembali `open` dan diberi tanda.
- Daftar topik dan prioritas default.
- Quick reply global.
- Jam layanan, hari libur, dan pesan otomatis.
- Opsi "lepas otomatis jika pemilik offline" (default mati).
- Mode penugasan: **`claim` (default)** atau `auto_assign` (opsional, memakai matching engine CS2).

---

## 5. Perbaikan dari Demo Saat Ini (wajib dicek)

- **Pesan sistem berulang/bertumpuk** di sisi nasabah (salam, pengingat keamanan, "Anda masuk antrean", "Koneksi CS terputus...") → gabungkan dan rapikan sesuai 3.3.
- **"Koneksi CS terputus. Anda sedang dihubungkan ke CS lain"** saat CS ganti status ke Offline → dengan model baru, **tiket tetap milik CS tersebut**. Ganti pesannya menjadi: "CS [nama] sedang tidak aktif. Pesan Anda tetap tersimpan dan akan dibalas." Jangan memindahkan tiket otomatis kecuali pengaturan 2.1 aktif.
- **Status header nasabah tidak konsisten**: "Menunggu CS · posisi antrean 1" masih tampil padahal tiket pernah ditangani. Status header harus selalu sesuai status tiket dari server.
- Tiket yang sudah `resolved` tetap tercatat di "Selesai hari ini", sementara nasabah masih bisa mengetik. Pastikan alur buka kembali (1.3) dan pembuatan tiket baru berjalan benar.
- Format waktu: `HH.mm` untuk hari ini, ditambah tanggal untuk hari sebelumnya, dengan pemisah tanggal di chat.
- **Pemilih agen (Nadia/Bima/Laras) dan kolom nasabah** hanya ada di halaman demo profil `dev`.

---

## 6. Tahapan

1. **R1: Backend claim**
   - Fungsi `cs.claim_ticket`, release, transfer (dengan penerimaan), reassign supervisor, state machine baru, constraint, trigger kepemilikan pada `messages`, broadcast realtime, dan audit.
   - Kriteria selesai: semua tes di 2.3 lulus.
2. **R2: Web CS**
   - Login + 2FA, tata letak 3 kolom, tab tiket, ambil/pratinjau, chat + catatan internal + quick reply, info nasabah, notifikasi, serta aksi tiket.
3. **R3: Aplikasi nasabah**
   - Integrasi room CS ke OLT (Windows + Android): header tiket, pesan sistem yang rapi, aksi, rating, riwayat tiket, notifikasi, dan offline.
4. **R4: Supervisor, pengaturan & perbaikan demo**
   - Dashboard, alert, laporan, pengaturan, dan semua poin di bagian 5.

Setiap tahap: berhenti, tunjukkan hasil (screenshot web CS dan aplikasi), lalu tunggu konfirmasi saya.

**Sebelum mulai R1:** jelaskan perubahan apa saja terhadap kode CS1/CS2 yang sudah ada (apa yang dipakai ulang, diubah, atau dinonaktifkan), lalu tunggu persetujuan saya.
