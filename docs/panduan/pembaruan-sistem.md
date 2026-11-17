# Panduan Pembaruan Sistem

Cara memasang versi baru server sosial dan Rendezvous Hub, memeriksa hasilnya, dan kembali ke versi sebelumnya bila ada masalah. Untuk Super Admin dan tim IT.

Server menjalankan dua repo yang diletakkan berdampingan:

| Repo | Isi |
|---|---|
| `chat_service_supabase` | Database, layanan server, perintah `make` / `.\make.ps1` |
| `rendezvous_hub` | Web Rendezvous Hub, dibangun saat `make up` |

Library aplikasi nasabah (`rendezvous_community`) diperbarui tim aplikasi OLT di aplikasinya sendiri, bukan di server.

---

## 1. Sebelum update

1. **Pilih waktu sepi**, di luar jam bursa (sebelum 08.30 atau setelah 16.30 WIB) dan bukan saat tim CS sedang ramai. Beri tahu tim bahwa sistem bisa tersendat 2–5 menit.
2. **Baca [catatan-rilis.md](catatan-rilis.md)** untuk rilis yang akan dipasang. Beberapa rilis butuh langkah tambahan sebelum `make up`.
3. **Pastikan sistem sehat**: Hub → **Pengaturan → Sistem → Kesehatan sistem**, tidak ada alert kritis dan Peta layanan hijau.
4. **Pastikan backup berjalan**: **Pengaturan → Sistem → Backup**, backup penuh terakhir kurang dari 24 jam dan kiriman WAL baru saja.
5. **Buat salinan sesaat** dan **catat versi yang sedang berjalan** (untuk rollback):

   ```powershell
   cd "D:\...\chat_service_supabase"         # sesuaikan dengan folder Anda
   .\make.ps1 backup
   git rev-parse --short HEAD                 # catat, mis. 11fcf27
   git -C ..\rendezvous_hub rev-parse --short HEAD
   ```

6. **Pastikan tidak ada perubahan lokal** yang menghalangi `git pull`:

   ```powershell
   git status --short
   git -C ..\rendezvous_hub status --short
   ```

   Hasilnya harus kosong. File di server tidak boleh diedit langsung; pengaturan ada di `docker\.env` (tidak ikut Git) dan di Hub.

---

## 2. Memasang versi baru

Windows (cara yang dipakai di server lokal):

```powershell
cd ..\rendezvous_hub; git pull; cd ..\chat_service_supabase; git pull; .\make.ps1 up
```

Tambahkan opsi yang biasa dipakai di server tersebut, misalnya `.\make.ps1 up -Cs` atau `.\make.ps1 up -DummyOlt`.

Linux (profil produksi):

```bash
cd ~/chat_service_supabase
git -C ~/rendezvous_hub pull --ff-only
git pull --ff-only
make up PROFILE=single CS=1
```

`make up` membangun image yang berubah, menjalankan **migrasi database baru secara otomatis**, lalu menunggu semua layanan sehat (bisa beberapa menit).

Bila berhenti dengan pesan `... is unhealthy` atau `dependency failed to start`, biasanya karena layanan API sedang memuat ulang setelah migrasi. Tunggu 1 menit lalu jalankan `make up` sekali lagi.

---

## 3. Memeriksa hasil

1. **Semua layanan berjalan**:

   ```powershell
   .\make.ps1 ps
   ```

   Semua `healthy`. Container `migrate` dan `volume-init` memang selesai dengan `Exited (0)`.
2. **Migrasi berhasil**:

   ```powershell
   docker logs olt-social-migrate-1 --tail 5
   ```

   Baris terakhir `migrate: done (... new, ... total)`.
3. **Hub**: login, buka **Pengaturan → Sistem → Kesehatan sistem**. Peta layanan hijau dan tidak ada alert kritis baru. Alert **Peringatan** pool koneksi yang muncul sebentar saat restart lalu pulih sendiri adalah wajar.
4. **Uji fungsi utama**: buka aplikasi OLT, login ke fitur sosial, kirim satu chat, dan pastikan tiket CS bisa dibalas dari Hub.

---

## 4. Bila ada masalah: rollback

### 4.1 Masalah hanya di tampilan Hub

Kembalikan Hub saja, database tidak perlu diubah:

```powershell
git -C ..\rendezvous_hub checkout <commit-hub-sebelumnya>
.\make.ps1 up
```

### 4.2 Masalah di server, data masih baik

Kembalikan kode ke versi sebelumnya:

```powershell
git checkout <commit-sebelumnya>
.\make.ps1 up
```

Ini cukup bila rilis tidak membawa migrasi database baru, atau migrasinya hanya menambah hal baru (tabel, kolom, fungsi) yang tidak dipakai versi lama.

### 4.3 Migrasi merusak data atau versi lama tidak mau jalan

Kembalikan kode **dan** database ke sebelum update. Data yang masuk setelah waktu itu ikut hilang.

```powershell
git checkout <commit-sebelumnya>
git -C ..\rendezvous_hub checkout <commit-hub-sebelumnya>
.\make.ps1 restore-pitr -At <jam sebelum update, mis. 2026-11-16T05:00:00+07:00> -Yes
.\make.ps1 up
```

Rincian pemulihan ada di [backup.md](backup.md#72-upgrade-gagal-setelah-git-pull--makeps1-up).

### 4.4 Setelah rollback

- Server sedang berada di commit lama ("detached HEAD"). Laporkan masalahnya ke tim pengembang beserta pesan error dan jam kejadian.
- Setelah perbaikan dirilis, kembali ke versi terbaru: `git checkout main`, `git pull`, lalu `.\make.ps1 up` (lakukan juga di `rendezvous_hub` bila ikut dikembalikan).

---

## 5. Aturan

- Kode hanya datang dari Git. Jangan mengedit file compose, skrip, atau kode langsung di server.
- Jangan menjalankan `make reset` atau `docker volume rm` di server produksi: keduanya menghapus database dan file.
- File migrasi yang sudah berjalan tidak pernah diubah; perbaikan selalu berupa migrasi baru.
- Ganti versi image pihak ketiga (Postgres, Realtime, Kong) mengikuti [produksi.md](produksi.md#4-update-versi).
