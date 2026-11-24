# Retensi Data

Panduan ini menjelaskan berapa lama data disimpan, siapa yang boleh mengubah batasnya, dan bagaimana memastikan pembersihan otomatis berjalan. Berlaku sejak migrasi `0195`.

## 1. Ringkasan

- **Penjaga retensi** berjalan otomatis **setiap hari pukul 02.41 WIB** (job pg_cron `retention-guard`). Ia menghapus permanen post, komentar, chat DM/grup, chat room saham, dan chat CS yang sudah melewati batas umur, termasuk file lampirannya.
- Batasnya diatur di Hub: **Kepatuhan → Retensi data**. Super Admin membukanya lewat Ctrl K.
- Batas tidak bisa diubah sembarangan:
  - setiap perubahan wajib diajukan dengan alasan dan **disetujui staf lain**, menggunakan sesi 2FA;
  - perubahan yang **mempercepat penghapusan baru berlaku 7 hari** setelah disetujui dan masih bisa dibatalkan selama masa tunggu;
  - perubahan langsung lewat SQL ditolak database.
- Data yang sedang **ditahan** tidak pernah dihapus. Penahanan bisa dipasang pada akun, room, atau satu konten.

## 2. Batas bawaan

| Data | Bawaan | Rentang yang diizinkan | Dihitung sejak |
|---|---|---|---|
| Post (beserta komentar, reaksi, lampiran) | 5 tahun | 1–30 tahun, atau 0 = tidak pernah | Post dibuat |
| Komentar | 5 tahun | 1–30 tahun, atau 0 | Komentar dibuat |
| Chat DM & grup | 5 tahun | 1–30 tahun, atau 0 | Pesan dikirim |
| Chat room saham | 5 tahun | 1–30 tahun, atau 0 | Pesan dikirim |
| Chat CS | 10 tahun | 5–30 tahun | Tiket terakhir nasabah ditutup |
| Arsip konten yang dihapus | 1.825 hari | 365–3.650 hari | Konten dihapus |
| Bukti karantina | 730 hari | 365–3.650 hari | Bukti terakhir direkam |
| Pesan yang sudah dihapus | 30 hari | 7–365 hari | Pesan dihapus |
| Notifikasi | 90 hari | 30–730 hari | Notifikasi dibuat |
| Audit log admin | 1.825 hari | 365–3.650 hari | Catatan dibuat |
| Log akses data pribadi | 730 hari | 365–3.650 hari | Catatan dibuat |
| Catatan rate limit | 2 hari | 1–30 hari | Catatan dibuat |
| Batas hapus per run | 20.000 baris per jenis data | 1.000–200.000 | – |

Alasan bawaan:

- **Konten komunitas 5 tahun** menyamai masa arsip regulator yang sudah dipakai untuk konten yang dihapus, sehingga riwayat percakapan pasar tetap tersedia untuk pemeriksaan manipulasi.
- **Chat CS 10 tahun** mengikuti masa simpan pengaduan. Minimalnya 5 tahun dan tidak bisa dimatikan.
- **Audit log admin** dinaikkan dari 365 hari menjadi 5 tahun, karena jejak tindakan admin dibutuhkan saat audit.

Kepatuhan wajib meninjau ulang angka-angka ini terhadap ketentuan yang berlaku sebelum server dibuka ke nasabah.

## 3. Yang tidak pernah dihapus penjaga

- Konten yang **ditahan** dari tab **Penahanan**, baik per akun, per room, maupun per konten.
- Konten dengan **laporan terbuka** (status terbuka atau sedang ditinjau).
- Konten dengan **banding** yang belum diputuskan.
- Konten yang buktinya sedang **legal hold** di menu Bukti.
- **Post resmi perusahaan** yang diterbitkan dari Komunitas.
- **Chat CS** milik nasabah yang masih punya tiket aktif, atau yang tiket terakhirnya ditutup belum lewat batas.
- **Komentar yang masih punya balasan.** Komentar ini menunggu sampai balasannya terhapus lebih dulu.

Bila akun dihapus pemiliknya, kontennya tetap dihapus mengikuti alur hapus akun, terlepas dari batas retensi.

## 4. Mengubah batas (Kepatuhan)

1. Buka **Kepatuhan → Retensi data**, tab **Aturan**.
2. Klik **Ajukan perubahan** di baris yang diinginkan. Isi **Nilai baru** dan **Alasan perubahan** (10–500 karakter, cantumkan dasar keputusan).
3. Hub menampilkan dampaknya:
   - **Data disimpan lebih lama** (nilai lebih besar, 0 = tidak pernah, atau penjaga dihentikan) langsung berlaku setelah disetujui.
   - **Data terhapus lebih cepat** (nilai lebih kecil, penjaga dinyalakan, atau batas hapus per run dinaikkan) baru berlaku **7 hari setelah disetujui**.
4. Staf Kepatuhan atau Super Admin **lain** membuka tab **Permintaan**, lalu **Setujui** atau **Tolak**. Penolakan wajib diberi alasan. Penyetuju wajib masuk dengan 2FA.
5. Selama belum berlaku, permintaan bisa **Dibatalkan** oleh staf Kepatuhan mana pun.
6. Permintaan yang tidak diputuskan dalam **14 hari** kedaluwarsa dan harus diajukan ulang.

Satu aturan hanya bisa punya satu permintaan terbuka. Semua langkah tercatat di Jejak Audit (`retention.*`) dan di riwayat retensi yang tidak bisa diubah.

## 5. Menahan data (Kepatuhan)

1. Tab **Penahanan** → **Tambah penahanan**.
2. Pilih **Jenis target**:
   - **Semua konten akun**: isi `@username` atau ID akun;
   - **Semua pesan room**, **Post**, **Komentar**, atau **Pesan chat**: isi ID-nya.
3. Isi **Alasan penahanan** (misalnya nomor surat permintaan penyidik), **Nomor referensi** bila ada, dan **Berlaku sampai** bila penahanan punya batas waktu.
4. Penahanan hanya bisa **dilepas staf lain**, menggunakan sesi 2FA dan disertai alasan. Setelah dilepas, data kembali mengikuti batas retensi dan bisa terhapus pada run berikutnya.

## 6. Memastikan penjaga berjalan (Super Admin / tim IT)

- Tab **Riwayat run** mencatat setiap run: jumlah yang dihapus per jenis, file yang diantrekan ke janitor, batas baris yang tercapai, dan kegagalan.
- **Hitung sekarang** di tab yang sama menampilkan jumlah data yang akan dihapus bila penjaga berjalan sekarang, sudah memperhitungkan penahanan.
- **Kesehatan sistem** memunculkan peringatan:
  - **Pembersihan data terjadwal tidak berjalan**: tidak ada run lebih dari 26 jam saat penjaga aktif;
  - **Pembersihan data terjadwal gagal sebagian**: run terakhir gagal di salah satu jenis data.
- Super Admin bisa menekan **Jalankan sekarang** (sekali per 10 menit). Run manual memakai aturan dan batas yang sama dengan run terjadwal.
- Pemeriksaan dari server (hanya baca): jalankan `make psql` (Windows: `.\make.ps1 psql`), lalu:

  ```sql
  select jobname, schedule, active from cron.job where jobname like 'retention-%';
  select finished_at, source, enabled, deleted, capped, errors from private.retention_runs order by finished_at desc limit 5;
  ```

  Kedua job (`retention-guard` dan `retention-apply-due`) harus `active = t`. Jadwal `41 19 * * *` ditulis dalam UTC, sama dengan 02.41 WIB.

File lampiran tidak dihapus langsung oleh database. File diantrekan ke `private.storage_cleanup_queue` (alasan `retention`) dan dihapus layanan **janitor**. Pastikan layanan janitor menyala di **Kesehatan sistem → Peta layanan**.

## 7. Pembersihan lain yang sudah ada

Job lama tetap berjalan seperti biasa dan kini memakai batas yang sama dari halaman ini:

- `olt-retention` (10.17 WIB): notifikasi, pesan yang sudah dihapus, arsip konten, audit log admin, log akses, dan rate limit;
- `evidence-purge`: bukti karantina;
- `social-content-edits-retention`: riwayat edit konten.

Masa simpan arsip konten ditetapkan saat konten dihapus, jadi perubahan `Arsip konten yang dihapus` hanya berlaku untuk konten yang dihapus setelahnya.
