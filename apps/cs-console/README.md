# CS Console (web CS)

Web khusus CS, supervisor, dan admin CS OLT, dibuat dengan Flutter web. Spesifikasinya ada di [PROMPT-CS-REVISI-2.md](../../docs/PROMPT-CS-REVISI-2.md) bagian 4. Konsol ini tidak punya kolom nasabah dan tidak punya pemilih agen demo.

Menu di top bar mengikuti peran:

| Menu | Peran |
|---|---|
| **Tiket** | CS dan supervisor |
| **Dashboard** | Supervisor. Badge berisi jumlah tiket yang perlu perhatian |
| **Laporan** | Supervisor dan admin |
| **Pengaturan** | Admin CS |

## Menjalankan (dev)

```bash
make up DUMMY_OLT=1        # Windows: .\make.ps1 up -DummyOlt
make cs-console            # Windows: .\make.ps1 cs-console
make cs-totp               # kode TOTP akun staf dev saat ini
```

`make cs-console` melakukan tiga hal:
1. Menyiapkan akun staf dev: Nadia, Bima, dan Laras (CS), Sinta (supervisor), Adi (admin CS).
2. Membangun web CS.
3. Menyajikannya di http://localhost:8084.

Email, password, dan secret TOTP akun dev disimpan di `scripts/cs-demo/runtime/staff.json` (di-gitignore). Untuk login, tambahkan secret ke aplikasi authenticator, atau pakai `make cs-totp`. Password dev diturunkan dari JWT secret lingkungan ini, jadi tetap sama setiap kali perintah dijalankan.

## Alur kerja CS

1. **Login.** Masuk dengan email + password, lalu TOTP. Akun yang belum punya TOTP diminta mendaftarkan authenticator (QR) saat pertama login. Setelah login status selalu **Offline**.
2. **Ambil tiket.** Pilih **Online**, lalu ambil tiket dari tab **Terbuka**. Mengklik kartu tanpa mengambil hanya membuka pratinjau hanya-baca. Bila CS lain lebih dulu mengambil, server menolak dengan pesan "Tiket sudah diambil oleh [nama]".
3. **Tangani.** Pemilik tiket bisa:
   - membalas (ketik `/` untuk balasan cepat dengan variabel `{nama}`, `{nomor_tiket}`, `{nama_cs}`), mengirim gambar, tautan bantuan, dan kartu order;
   - menulis **catatan internal** (latar kuning, tidak terlihat nasabah);
   - mengubah prioritas;
   - memakai **Tunggu nasabah**, **Lepas** (wajib alasan), **Transfer** (CS tujuan harus menerima), dan **Selesaikan** (hasil + ringkasan).
4. **Info nasabah.** Data di kolom kanan disamarkan. Tombol **Tampilkan** wajib alasan, berlaku 5 menit, dan tercatat di audit log. Data OLT (order, transaksi dana, perangkat, keamanan) dibaca lewat `customer-adapter` hanya untuk tiket milik sendiri atau oleh supervisor.
5. **Supervisor.** Supervisor punya tab **Semua aktif**, tombol **Gabung**, dan **Pindahkan ke…** (wajib alasan). Menu **Dashboard** berisi:
   - ringkasan antrean (terbuka, tunggu terlama, ditangani, selesai hari ini, CS online);
   - daftar tiket yang perlu perhatian (belum diambil melewati batas, fraud/pengaduan, milik CS offline);
   - status setiap CS.

   Tiket yang melewati batas memicu suara dan notifikasi browser. Menu **Laporan** menampilkan tiket per hari, waktu sampai diambil, respons pertama, durasi, rating per CS, dan topik terbanyak, dengan ekspor CSV.
6. **Admin.** Menu **Pengaturan** berisi:
   - akun CS: tambah akun, ubah peran/tim/batas tiket aktif, nonaktifkan;
   - topik dan prioritas default;
   - quick reply global;
   - jam layanan dan hari libur;
   - pesan otomatis ID/EN;
   - lepas otomatis bila pemilik offline, mode penugasan, dan batas alert supervisor.

   Akun baru mendapat password sementara yang hanya ditampilkan sekali. Saat login pertama, CS wajib mengganti password lalu mendaftarkan TOTP. Akun yang dinonaktifkan langsung keluar dari konsol, dan tiket aktifnya kembali ke antrean dengan tanda.

## Arsitektur

Struktur per fitur seperti `olt_social`:
- data: repository ke `cs_api` dan adapter;
- domain: model freezed;
- presentation: Cubit + widget.

| Fitur | Isi |
|---|---|
| `auth` | Login GoTrue, TOTP (daftar dan verifikasi), penanda logout (manual/idle/sesi habis/bukan staf) |
| `agent` | Profil CS, status, heartbeat 20 detik, top bar |
| `tickets` | Daftar tiket (tab, filter, cari), ambil tiket, transfer masuk/keluar, event realtime `cs:queue` dan `cs:agent:<id>` |
| `conversation` | Detail tiket, aksi pemilik/supervisor, composer (balasan, catatan, `/`, lampiran) |
| `customer` | Kolom info nasabah: profil tersamar + buka data, data OLT, riwayat tiket, catatan |
| `notifications` | Suara + notifikasi browser (tiket baru: semua / prioritas tinggi / mati; pesan di tiket saya; transfer; peringatan supervisor; tiket terlambat) |
| `supervisor` | Dashboard (`supervisor_overview`, dimuat ulang saat ada event + tiap 30 detik), laporan (`report_summary`) dan ekspor CSV |
| `admin` | Pengaturan admin: repository `cs_api.admin_*` + Edge Function `cs-admin`, cubit daftar generik, halaman per bagian |
| `shell` | Menu per peran, tata letak 3 kolom tiket, logout otomatis setelah idle (default 30 menit, peringatan 60 detik sebelumnya) |

Widget chat (daftar pesan, bubble, badge CS Resmi, pesan sistem, kartu, pilihan cepat, mengetik, tanda baca) diambil dari `olt_social`, sama dengan aplikasi nasabah. Konsol menyediakan `OltSupportStaff` (sesi GoTrue staf) dan composer CS sendiri.

## Keamanan

- **Hanya lewat VPN di produksi.** Sajikan hasil build di host internal, dan batasi juga `/auth/v1` dan `/cs/v1/agent` ke jaringan VPN (lihat [PRODUCTION.md](../../docs/PRODUCTION.md)).
- **Sesi disimpan di `sessionStorage` tab**, bukan `localStorage`. Menutup tab berarti keluar.
- **API CS menuntut `aal2`.** Setelah verifikasi TOTP, token aal2 langsung dipasang ke klien realtime, karena `supabase_flutter` tidak memperbaruinya pada event MFA. Tanpa langkah ini channel privat `cs:*` ditolak.
- **Tidak ada `service_role` di aplikasi.** Akun staf dibuat lewat Edge Function `cs-admin`, yang memeriksa bahwa pemanggil adalah admin CS `aal2` dan memakai kunci service role di sisi server. Pendaftaran publik tetap mati.
- **Akun dinonaktifkan = akses dicabut.** Login GoTrue diblokir, setiap panggilan `cs_api` ditolak, dan konsol yang sedang terbuka keluar sendiri pada heartbeat berikutnya.
- **Pengaturan dibatasi.** Admin hanya bisa mengubah kunci yang diizinkan, dengan nilai yang divalidasi server. Contohnya, pesan otomatis hanya boleh memakai variabel yang sudah ada. Retensi data dan batas akses data nasabah tidak bisa diubah dari konsol.
- **Data OLT tidak disimpan di browser.** Data hanya ditampilkan dari adapter, termasuk lot dan harga, dan tidak ditulis ke storage.

## Tes

```bash
cd apps/cs-console && flutter test     # daftar tiket, auth + TOTP + ganti password, percakapan, dashboard, laporan + CSV, admin
make license-audit                      # semua dependensi runtime harus MIT/BSD/Apache/ISC/Zlib
```
