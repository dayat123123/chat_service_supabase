# Panduan Backup dan Pemulihan

Panduan praktis untuk Super Admin dan tim IT yang menjalankan server Rendezvous (OLT Social) di Windows dengan `.\make.ps1`. Untuk Linux, perintahnya sama dengan `make` (contoh: `make backup-snapshots`). Penjelasan teknis lengkap ada di [README backup](../backup/README.md) dan [services/backup](../../services/backup/README.md).

**Simpan dokumen ini bersama password backup.** Saat terjadi masalah, dokumen ini yang dibuka pertama.

---

## 1. Ringkasan

| Yang dibackup | Isinya |
|---|---|
| Database | Akun nasabah, chat CS dan tiket, postingan, komentar, notifikasi, pengaturan Hub, jejak audit |
| File | Foto dan dokumen yang diunggah (lampiran chat CS, foto profil, gambar postingan) |

| Kapan | Apa |
|---|---|
| Setiap hari 02.00 WIB | Backup penuh database + file |
| Setiap 5 menit | Perubahan database (WAL) dikirim ke repositori |
| Setiap Minggu 04.00 WIB | Uji restore otomatis |

| Disimpan berapa lama | |
|---|---|
| Backup harian / mingguan / bulanan | 7 / 4 / 6 |
| Pemulihan ke menit tertentu | 7 hari terakhir |

Jam dan lama simpan bisa diubah di **Pengaturan → Sistem → Backup → Jadwal & retensi**.

**Data yang mungkin hilang saat pemulihan:** paling banyak sekitar 5 menit terakhir untuk database. File yang diunggah setelah backup harian terakhir hanya hilang bila disk atau server rusak.

Backup disimpan terenkripsi di **repositori restic**: bucket S3 (disarankan) atau folder di server. Isinya tidak bisa dibuka tanpa **password enkripsi backup**.

---

## 2. Persiapan wajib (sekali, sebelum ada masalah)

Tanpa bagian ini, beberapa kejadian di bab 7 **tidak bisa dipulihkan**.

### 2.1 Simpan di luar server

Simpan di tempat aman di luar server, misalnya password manager perusahaan, disk eksternal yang disimpan terpisah, atau amplop tersegel di brankas:

- [ ] **Password enkripsi backup.** Dibuat saat mengatur tujuan backup dan tidak bisa dilihat lagi dari web. Tanpa password ini backup tidak bisa dibuka oleh siapa pun.
- [ ] Kredensial S3 (endpoint, bucket, access key ID, secret access key), bila memakai S3.
- [ ] Folder `docker\secrets\` dan file `docker\.env` dari folder `chat_service_supabase`.
- [ ] **Kunci Vault** `pgsodium_root.key`. Ambil dengan perintah di bawah. Kunci ini membuat isian rahasia di Hub (kunci Firebase, password backup, kanal alert) ikut pulih di server baru.

```powershell
cd "D:\...\chat_service_supabase"          # sesuaikan dengan folder Anda
docker cp olt-social-db-1:/etc/postgresql-custom/pgsodium_root.key E:\simpanan-aman\
```

Semua berkas di atas bersifat rahasia. Jangan dikirim lewat chat atau email.

### 2.2 Salinan backup di luar server

Bila memakai **folder lokal**, salin repositori backup ke luar server secara rutin (lihat bab 5). Backup yang hanya ada di server ikut hilang bila server rusak, dicuri, atau terkena ransomware.

---

## 3. Mengatur backup dari Hub

Buka **Pengaturan → Sistem → Backup** (khusus Super Admin).

1. Bagian **Tujuan backup → Jenis tujuan**:
   - **S3** (disarankan): isi endpoint `https://…`, bucket, folder (prefix), region bila diminta, access key ID, dan secret access key. Pakai access key yang hanya punya akses ke bucket itu.
   - **Folder lokal di server**: cukup isi password. Folder aslinya diatur `BACKUP_LOCAL_REPO_DIR` di `docker\.env` (bawaan `backups\restic`). Sebaiknya di **disk lain** dari disk database.
2. Isi **Password enkripsi backup** minimal 16 karakter, ketik ulang untuk konfirmasi, lalu catat sesuai bab 2.1.
3. Tekan **Simpan tujuan**. Dalam satu menit layanan backup membuat repositori, mulai mengalirkan WAL, dan membuat backup penuh pertama.
4. (Opsional) Ubah **Jadwal & retensi**: jam backup penuh harian, interval kirim WAL, lama simpan, serta hari dan jam uji restore.

### Membaca halaman Backup

| Kartu | Kondisi sehat |
|---|---|
| Layanan backup | **Berjalan** |
| Streaming WAL | **Mengalir** |
| Backup penuh terakhir | Jam dalam 24 jam terakhir |
| Kiriman WAL terakhir ke repositori | Beberapa menit lalu. "Belum pernah" wajar sampai ±5 menit setelah backup penuh pertama |
| Uji restore terakhir | **Berhasil** dalam 7 hari terakhir |
| Disk staging backup / Disk repositori lokal | Terpakai di bawah 90 % |

Tombol **Backup penuh sekarang** dan **Uji restore sekarang** ada di bagian **Jalankan sekarang**. Uji restore memulihkan backup ke database sementara; database produksi tidak disentuh.

Bila ada masalah, alert muncul di **Pengaturan → Sistem → Kesehatan sistem**, angka merah di menu **Pengaturan**, dan pesan ke Telegram/email yang diatur di **Pengaturan → Sistem → Alert**.

---

## 4. Pemeriksaan rutin

| Kapan | Yang dilakukan |
|---|---|
| Setiap hari kerja | Lihat halaman Backup: semua kartu sehat, tidak ada alert `backup:*` |
| Setiap minggu | Pastikan **Uji restore terakhir** berhasil. Salin repositori ke luar server (bab 5) bila memakai folder lokal |
| Setiap bulan | Jalankan `.\make.ps1 backup-snapshots` dan pastikan rentang pemulihan sampai jam sekarang. Cek sisa disk |
| Sebelum upgrade besar | `.\make.ps1 backup` (bab 8) |
| Setiap 3–6 bulan | Latihan pemulihan skenario 7.1 di komputer uji, bukan di server produksi |

---

## 5. Lokasi backup dan menyalinnya ke luar server

### 5.1 Mencari folder repositori (tujuan folder lokal)

```powershell
(docker inspect olt-social-backup-1 | ConvertFrom-Json).Mounts | Where-Object Destination -eq '/var/lib/olt-backup-repo' | Select-Object -ExpandProperty Source
```

Hasilnya berbentuk path Docker Desktop. Buang awalan `/run/desktop/mnt/host/`, lalu huruf berikutnya adalah huruf drive. Contoh: `/run/desktop/mnt/host/e/backup/restic` berarti `E:\backup\restic`.

Isi folder ini (`config`, `data`, `index`, `keys`, `snapshots`) terenkripsi dan tidak bisa dibuka langsung.

### 5.2 Menyalin ke disk eksternal atau NAS

Hentikan layanan backup sebentar agar tidak ada berkas setengah jadi. Pilih jam di luar 02.00 (jadwal backup penuh).

```powershell
docker stop olt-social-backup-1
robocopy "E:\backup\restic" "F:\salinan-backup\restic" /MIR
docker start olt-social-backup-1
```

WAL tetap ditahan database selama layanan berhenti dan dikirim setelah layanan menyala lagi. Cara tanpa menghentikan layanan (`restic copy`) ada di [README backup](../backup/README.md#tujuan-folder-lokal).

Bila memakai **S3**, backup sudah berada di luar server. Langkah ini tidak perlu.

---

## 6. Melihat daftar backup

```powershell
.\make.ps1 backup-snapshots
```

Saat server berjalan normal, perintah ini memakai pengaturan dari Hub. Contoh hasil:

```
TIME                       ID        KIND   SIZE       NOTE
2026-11-16T02:00:02+07:00  8f73ca46  base   123.3 MiB  base-20261115T190002Z
2026-11-16T02:00:04+07:00  70dd6eb0  files  59.2 MiB   51 file
2026-11-16T13:34:11+07:00  d7ff1d74  wal    144.0 MiB  9 file

Base backups: 2026-11-04T14:25:40+07:00 to 2026-11-16T02:00:02+07:00
Point-in-time restore (--target-time) is possible between 2026-11-04T14:25:40+07:00 and 2026-11-16T13:34:11+07:00 (WAL within retention), or latest.
```

| KIND | Artinya |
|---|---|
| `base` | Backup penuh database |
| `files` | Backup file (foto dan dokumen) |
| `wal` | Kiriman perubahan database |

Baris terakhir menunjukkan **rentang waktu yang bisa dipulihkan**. Bila tertulis `No WAL uploaded after the base yet`, pemulihan hanya bisa ke titik backup penuh. Itu wajar beberapa menit setelah backup penuh pertama (lihat bab 9).

Bila database sudah mati atau Anda memakai salinan di disk lain, isi lokasi dan password lebih dulu:

```powershell
$env:RESTIC_REPOSITORY = 'E:\backup\restic'                        # folder repositori atau salinannya
$env:RESTIC_PASSWORD_FILE = 'E:\simpanan-aman\password-backup.txt'  # berkas teks berisi password
.\make.ps1 backup-snapshots
```

Untuk S3: `$env:RESTIC_REPOSITORY = 's3:https://host/bucket/folder'`, lalu isi juga `$env:AWS_ACCESS_KEY_ID` dan `$env:AWS_SECRET_ACCESS_KEY`.

Hapus berkas password dari disk server setelah selesai.

---

## 7. Pemulihan per kejadian

Hal penting sebelum memulai:

- `restore-pitr` **mengembalikan seluruh database** ke waktu yang dipilih. Semua data yang masuk setelah waktu itu ikut hilang. Umumkan ke tim bahwa sistem berhenti sementara.
- Perintah ini menghentikan semua layanan, memulihkan database, lalu hanya menyalakan database. Layanan lain dinyalakan dengan `.\make.ps1 up` setelah data diperiksa.
- Waktu ditulis lengkap dengan zona, contoh `2026-11-16T10:15:00+07:00`, atau `latest` untuk yang terbaru.

### 7.1 Data terhapus atau salah ubah (server sehat)

1. Catat jam kejadian, misalnya data terhapus sekitar 10.20 WIB.
2. Cek rentang yang tersedia: `.\make.ps1 backup-snapshots`.
3. Pulihkan ke **sebelum** kejadian:
   ```powershell
   .\make.ps1 restore-pitr -At 2026-11-16T10:15:00+07:00 -Yes
   ```
4. Periksa datanya, lalu jalankan `.\make.ps1 up`.

### 7.2 Upgrade gagal (setelah `git pull` + `.\make.ps1 up`)

Kembalikan **kode** lebih dulu. Bila hanya database yang dipulihkan, migrasi baru akan berjalan lagi.

```powershell
git log --oneline -5                       # cari commit sebelum upgrade
git checkout <commit-sebelumnya>           # lakukan juga di folder rendezvous_hub bila Hub ikut diupdate
.\make.ps1 restore-pitr -At <jam sebelum upgrade> -Yes
.\make.ps1 up
```

Laporkan masalahnya ke tim pengembang. Setelah diperbaiki, kembali ke versi terbaru dengan `git checkout main` lalu `git pull`.

### 7.3 Database rusak (mis. listrik padam, database tidak mau start)

```powershell
.\make.ps1 restore-pitr -At latest -Yes
.\make.ps1 up
```

### 7.4 Disk database rusak (repositori backup selamat)

1. Ganti disk, pasang ulang Docker bila perlu, lalu jalankan `.\make.ps1 up` sekali agar volume dibuat ulang.
2. Isi lokasi dan password repositori seperti di bab 6, lalu pulihkan database:
   ```powershell
   .\make.ps1 restore-pitr -At latest -Yes
   ```
3. Pulihkan file (foto dan dokumen). Password akan ditanyakan:
   ```powershell
   docker run --rm -it --user 0:0 --entrypoint restic -v "E:\backup\restic:/repo" -e RESTIC_REPOSITORY=/repo -v olt-social_storage-data:/mnt/storage olt-social/backup:0.2.1 --no-cache restore latest --tag files --target /
   ```
4. Jalankan `.\make.ps1 up` dan periksa data.

### 7.5 Server hilang, rusak total, atau terkena ransomware

Gunakan **server baru yang bersih** dan **salinan backup di luar server**.

1. Siapkan server baru (Docker, Git, kedua repo) sesuai [panduan instalasi server](instalasi-server.md).
2. Kembalikan `docker\secrets\` dan `docker\.env` dari simpanan.
3. Jalankan `.\make.ps1 up` sekali, lalu `.\make.ps1 down`.
4. Kembalikan kunci Vault sebelum database dipulihkan:
   ```powershell
   docker run --rm -v olt-social_db-config:/cfg -v E:\simpanan-aman:/src alpine sh -c "cp /src/pgsodium_root.key /cfg/ && chown 100:101 /cfg/pgsodium_root.key && chmod 640 /cfg/pgsodium_root.key"
   ```
5. Jalankan langkah 7.4 nomor 2 dan 3, dengan lokasi repositori diarahkan ke salinan di disk eksternal (atau bucket S3).
6. Jalankan `.\make.ps1 up` dan periksa data.
7. Bila kunci Vault tidak tersimpan, isi ulang dari Hub:
   - kunci Firebase di **Pengaturan → Integrasi → Push notification**;
   - password backup **yang sama** di **Pengaturan → Sistem → Backup**;
   - kanal Telegram/email di **Pengaturan → Sistem → Alert**.

Bila `docker\secrets\` juga hilang, hubungi tim pengembang: password akun database di hasil pemulihan harus disetel ulang.

### 7.6 Kepatuhan meminta data periode lama

Jangan dipulihkan ke server produksi, karena semua data terbaru akan tertimpa. Data lama dibuka di database terpisah dari backup mingguan/bulanan. Hubungi tim pengembang untuk prosedurnya.

---

## 8. Mengambil isi backup tanpa menyentuh database

### 8.1 Mengambil file (foto dan dokumen) ke sebuah folder

Contoh: mengembalikan lampiran yang terhapus. Password akan ditanyakan.

```powershell
# lihat daftar snapshot
docker run --rm -it --entrypoint restic -v "E:\backup\restic:/repo" -e RESTIC_REPOSITORY=/repo olt-social/backup:0.2.1 --no-cache snapshots

# ambil file terbaru ke D:\hasil-restore (hasilnya di D:\hasil-restore\mnt\storage)
docker run --rm -it --entrypoint restic -v "E:\backup\restic:/repo" -v "D:\hasil-restore:/out" -e RESTIC_REPOSITORY=/repo olt-social/backup:0.2.1 --no-cache restore latest --tag files --target /out
```

Ganti `latest` dengan ID snapshot (kolom ID) untuk mengambil versi tertentu.

### 8.2 Backup sesaat sebelum upgrade

```powershell
.\make.ps1 backup
```

Hasilnya di folder `backups\`: `olt-<tanggal>.dump` (database) dan `storage-<tanggal>.tar.gz` (file). Untuk mengembalikan database dari dump:

```powershell
.\make.ps1 down                                                                      # hentikan semua layanan
docker compose -f docker/compose.yml -f docker/compose.dev.yml up -d --wait db      # nyalakan database saja
.\make.ps1 restore -File olt-20261116-020000.dump -Yes
.\make.ps1 up
```

Perintah kedua untuk profil dev (`.\make.ps1 up` biasa). Untuk profil single, ganti `compose.dev.yml` dengan `compose.prod.yml`.

Ini pelengkap, bukan pengganti backup otomatis.

---

## 9. Masalah yang sering terjadi

| Gejala | Penyebab dan tindakan |
|---|---|
| `No WAL uploaded after the base yet` / kartu "Kiriman WAL terakhir" berisi "Belum pernah" | Wajar sampai ±5 menit setelah backup penuh pertama. Bila lebih dari 30 menit, muncul alert kritis `backup:offsite`. Kirim hasil `.\make.ps1 logs -Service backup` ke tim pengembang |
| Alert `backup:repository` | Repositori tidak bisa dibuka: password salah, folder belum ada atau tidak bisa ditulis, atau kredensial S3 salah. Periksa **Tujuan backup** |
| Alert `backup:base` | Backup penuh terakhir lebih dari 26 jam lalu. Tekan **Backup penuh sekarang**, lalu periksa log bila gagal |
| Alert `backup:disk` / `backup:repository_disk` | Disk hampir penuh. Kosongkan ruang, kurangi lama simpan, atau pindahkan repositori ke disk yang lebih besar |
| Alert `backup:secret` (setelah pindah server) | Kunci Vault tidak ikut. Isi ulang password backup **yang sama** di **Pengaturan → Sistem → Backup** |
| Lupa password enkripsi backup | Backup lama **tidak bisa dibuka** oleh siapa pun. Buat tujuan baru (folder/bucket baru) dengan password baru agar backup berikutnya aman |
| Log database: `recovery ended before configured recovery target was reached` | Tidak ada perubahan setelah waktu yang dipilih (sistem sepi). Ulangi dengan `-At latest`; hasilnya sama |
| `... is not a restic repository (config file missing)` | `RESTIC_REPOSITORY` menunjuk folder yang salah. Arahkan ke folder yang berisi berkas `config` |
