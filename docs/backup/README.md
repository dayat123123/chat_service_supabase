# Backup dan pemulihan

Database PostgreSQL dan file storage dibackup terus-menerus ke repositori **restic** terenkripsi, di **S3** (di luar server, disarankan) atau di **folder lokal di server** bila S3 belum ada (lihat [Tujuan folder lokal](#tujuan-folder-lokal)). Pemulihan bisa ke titik waktu tertentu (PITR). Semua pengaturan dilakukan Super Admin dari web CS, menu **Pengaturan → Backup**.

Migrasi: `0061_backup_role`, `0065_backups`, `0112_backup_local_destination` (tujuan folder lokal). Layanan: [`services/backup`](../../services/backup/README.md) (langkah teknis pemulihan ada di sana).

## Arsitektur

```
Postgres ──replikasi fisik (slot olt_backup)──▶ pg_receivewal ──▶ /var/lib/olt-backup/wal ─┐
Postgres ──pg_basebackup harian──────────────▶ /var/lib/olt-backup/base ─────────────────┼─▶ restic ──▶ S3 atau folder lokal (terenkripsi)
volume storage-data (read-only) ───────────────────────────────────────────────────────────┘
```

- **WAL dialirkan terus** lewat koneksi replikasi (`pg_receivewal`), lalu dikirim ke repositori backup setiap beberapa menit. Inilah yang memungkinkan pemulihan ke menit tertentu.
- **Backup penuh harian** (`pg_basebackup`, diverifikasi `pg_verifybackup`) dan backup file storage dikirim ke repositori yang sama.
- **restic** mengenkripsi di sisi server (AES-256), menghapus duplikasi, dan menerapkan retensi harian/mingguan/bulanan.
- **Uji restore otomatis mingguan**: backup terbaru dipulihkan ke folder sementara, Postgres sementara dijalankan sampai WAL terakhir, lalu jumlah baris tabel utama diperiksa. Hasilnya tampil di web.

**Mengapa bukan WAL-G.** Rencana awal (audit produksi) memakai WAL-G. Rencana itu diganti karena dua alasan:
1. WAL-G butuh `archive_command` di dalam container database, sehingga image `supabase/postgres` harus diturunkan sendiri.
2. Saat S3 mati, WAL yang belum terarsip menumpuk di disk database tanpa batas.

Dengan slot replikasi, image database tidak diubah. WAL yang ditahan juga dibatasi `max_slot_wal_keep_size` (512 MB): bila layanan backup mati terlalu lama, slot dilepas (alert kritis) dan backup penuh baru dibuat otomatis. Database tidak pernah penuh karena backup.

## Mengatur dari web (Super Admin)

1. Siapkan bucket S3 di penyedia di Indonesia (sesuai kebijakan lokasi data) dan buat access key yang hanya punya akses ke bucket itu.
2. Buka **Pengaturan → Backup → Tujuan**, pilih jenis **S3**. Isi endpoint (`https://…`), bucket, folder (prefix), region bila diminta, access key ID, dan secret access key.
3. Buat **password enkripsi** minimal 16 karakter. **Simpan password ini di luar server** (password manager perusahaan, amplop tersegel di brankas). Tanpa password ini backup tidak bisa dipulihkan, dan password tidak bisa dilihat lagi dari web.
4. Simpan. Dalam beberapa detik layanan backup membuat repositori, mulai mengalirkan WAL, dan membuat backup penuh pertama.

Rahasia (secret access key, password enkripsi) disimpan terenkripsi di Supabase Vault dan hanya dibaca layanan backup lewat RPC `backup_config` (khusus `service_role`). Semua perubahan tercatat di **Kepatuhan → Jejak Audit** (`backup.*`) tanpa isi rahasia.

**Rotasi access key S3:** isi access key baru di form yang sama. Password enkripsi tidak perlu diubah.

**Ganti password enkripsi:** password repositori yang sudah ada tidak bisa diganti dari web. Pakai folder atau bucket baru dengan password baru. Repositori lama tetap bisa dipakai untuk pemulihan sampai masa retensinya habis.

## Tujuan folder lokal

Bila belum ada S3, pilih **Folder lokal di server** di **Pengaturan → Backup → Tujuan**. Yang diisi hanya password enkripsi (+ konfirmasi). Repositori restic dibuat di folder `BACKUP_LOCAL_REPO_DIR` di server (bawaan `backups/restic` di repo, sudah di-gitignore), yang di-mount ke `/var/lib/olt-backup-repo` di container `backup` (migrasi `0112_backup_local_destination`, layanan `olt-social/backup:0.2.0`). Isinya sama terenkripsinya dengan repositori S3, dan jadwal, retensi, uji restore, serta PITR berjalan sama persis.

**Risikonya:** folder itu ada di server yang sama dengan database. Backup lokal melindungi dari salah hapus data, korupsi database, atau upgrade yang gagal, tetapi **tidak** melindungi dari server yang rusak, disk yang mati (bila satu disk), ransomware, atau server yang hilang. Halaman Backup menampilkan peringatan ini selama tujuan lokal dipakai. Karena itu:

1. **Pakai disk terpisah dari disk database.** Di produksi isi `docker/.env`:
   ```bash
   BACKUP_LOCAL_REPO_DIR=/mnt/backup/restic
   sudo install -d -o 10001 -g 10001 -m 0700 /mnt/backup/restic   # layanan backup berjalan sebagai uid 10001
   ```
   lalu `make up PROFILE=single`. Folder yang belum di-mount atau tidak bisa ditulis tampil sebagai error repositori (alert `backup:repository`) dengan alasannya. Sentinel juga mengukur disk folder ini (`disk:backup-repo`), dan layanan backup melaporkan alert `backup:repository_disk` bila sisa ruangnya < 10 % (kritis < 5 %).
2. **Salin isi folder ke luar server secara berkala** (disk eksternal, NAS, atau server lain), minimal harian. Dua cara:
   - `restic copy` dari repositori lokal ke repositori kedua (disk eksternal atau server lain lewat `sftp:`). Repositori tujuan dibuat sekali dengan `restic init --from-repo /mnt/backup/restic --copy-chunker-params` agar deduplikasi tetap jalan, lalu jalankan berkala (cron host):
     ```bash
     export RESTIC_FROM_REPOSITORY=/mnt/backup/restic RESTIC_FROM_PASSWORD_FILE=/root/password-backup
     export RESTIC_REPOSITORY=/media/usb-backup/restic RESTIC_PASSWORD_FILE=/root/password-backup
     restic copy        # hanya snapshot yang belum ada yang disalin; aman saat layanan backup berjalan
     restic check       # sesekali, untuk memastikan salinan utuh
     ```
     Tanpa restic di host, pakai binary di image backup: `docker run --rm --user 0:0 --entrypoint restic -v /mnt/backup/restic:/src -v /media/usb-backup/restic:/dst -v /root/password-backup:/pw:ro -e RESTIC_FROM_REPOSITORY=/src -e RESTIC_FROM_PASSWORD_FILE=/pw -e RESTIC_REPOSITORY=/dst -e RESTIC_PASSWORD_FILE=/pw olt-social/backup:0.2.0 --no-cache copy`.
   - Salin foldernya apa adanya (`rsync -a --delete /mnt/backup/restic/ /media/usb-backup/restic/`) **saat backup tidak berjalan**: hentikan dulu layanan backup (`docker compose … stop backup`), salin, lalu nyalakan lagi (`… start backup`). Folder yang disalin di tengah backup bisa berisi berkas setengah jadi. Pilih jam di luar jadwal backup penuh dan kiriman WAL.
   Simpan password enkripsi di luar server; salinan tanpa password tidak berguna.
3. **Pindah ke S3 begitu tersedia.** Pilih **S3** di form Tujuan, isi endpoint, bucket, access key, dan **password enkripsi baru** (pindah jenis tujuan = repositori baru). Layanan backup langsung membuat backup penuh baru di S3. Repositori lokal tidak dihapus otomatis; simpan sampai masa retensi WAL dan backup harian lewat, lalu hapus foldernya.

Pemulihan dari folder lokal memakai perintah yang sama dengan S3, cukup isi `RESTIC_REPOSITORY` dengan path folder di server (tanpa kredensial AWS), lihat [Pemulihan](#pemulihan).

## Jadwal dan retensi (default)

| Pengaturan | Default |
|---|---|
| Backup penuh + file storage | setiap hari 02:00 WIB |
| Kirim WAL ke repositori | setiap 5 menit |
| Retensi backup penuh dan file | 7 harian, 4 mingguan, 6 bulanan |
| Retensi WAL (jendela PITR) | 7 hari |
| Uji restore | setiap Minggu 04:00 WIB |
| Pemangkasan (`restic prune`) dan pemeriksaan (`restic check`, sampel 2 %) | mingguan |

Super Admin juga bisa menekan **Backup penuh sekarang** dan **Uji restore sekarang**.

**Target pemulihan:**
- **RPO** (data yang mungkin hilang) ≤ interval kirim WAL, default 5 menit.
- **RTO** (lama pemulihan) ≤ 1 jam untuk database sampai puluhan GB. Waktunya bergantung pada ukuran backup penuh dan kecepatan unduh dari S3 (folder lokal biasanya lebih cepat). Durasi uji restore mingguan di web adalah perkiraan paling nyata.

## Alert

| Kunci | Tingkat | Kapan |
|---|---|---|
| `backup:config` | peringatan | Tujuan backup (S3 atau folder lokal) belum diatur |
| `backup:repository` | kritis | Repositori tidak bisa dibuka 5 menit setelah diatur (alamat, kunci akses, atau password salah; untuk folder lokal: folder belum di-mount atau tidak bisa ditulis uid 10001) |
| `backup:wal` | kritis | `pg_receivewal` tidak berjalan |
| `backup:slot` | kritis | Slot `olt_backup` hilang; backup penuh baru dibuat otomatis, titik pemulihan sebelumnya terputus |
| `backup:base` | kritis | Backup penuh terakhir yang berhasil lebih dari 26 jam lalu (atau belum ada 2 jam setelah diatur) |
| `backup:base_failed` | peringatan | Backup penuh terakhir gagal |
| `backup:offsite` | kritis | WAL belum terkirim ke repositori backup lebih dari 30 menit (atau 3× interval) |
| `backup:restore_test` | peringatan | Uji restore terakhir gagal, atau belum ada uji yang berhasil selama 8 hari |
| `backup:disk` | peringatan | Disk staging backup tersisa kurang dari 10 % |
| `backup:repository_disk` | peringatan / kritis | Tujuan folder lokal: disk repositori tersisa < 10 % (kritis < 5 %) |

Lihat juga [docs/system-health](../system-health/README.md).

## Pemulihan

Langkah lengkap ada di [services/backup/README.md](../../services/backup/README.md#prosedur-pemulihan). Ringkasnya:

1. **Hentikan stack** (kecuali yang dibutuhkan untuk restore).
2. **Pulihkan backup penuh + WAL** sampai waktu target ke volume database:
   ```bash
   export RESTIC_REPOSITORY=s3:https://s3.penyedia.co.id/olt-backup/prod RESTIC_PASSWORD_FILE=/aman/password-backup
   export AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=…
   make backup-snapshots                                              # lihat rentang waktu yang bisa dipulihkan
   make restore-pitr AT=2026-11-03T10:15:00+07:00 CONFIRM=yes          # atau AT=latest
   ```
   Tujuan folder lokal: `RESTIC_REPOSITORY` diisi path folder di server dan `AWS_*` tidak perlu, mis. `export RESTIC_REPOSITORY=/mnt/backup/restic` (Windows: `$env:RESTIC_REPOSITORY = 'backups\restic'`). Folder itu di-mount otomatis ke container restore. Salinan di disk eksternal juga bisa dipakai dengan cara yang sama.
   Windows: `.\make.ps1 restore-pitr -At 2026-11-03T10:15:00+07:00 -Yes`. Kredensial dan password diambil dari salinan yang Anda simpan di luar server.
3. **Jalankan database.** Postgres memutar WAL sampai waktu target lalu naik sebagai primary.
4. **Jalankan stack lagi**, lalu periksa data.

**Kunci Vault.** Kunci enkripsi Supabase Vault ada di volume `db-config` (`/etc/postgresql-custom/pgsodium_root.key`), bukan di backup database. Bila memulihkan di server yang sama, volume itu tetap ada dan semua rahasia di Vault terbaca. Bila memulihkan ke **server baru**, rahasia di Vault tidak bisa dibuka, dan Kesehatan sistem menampilkan alert `backup:secret` / `alerts:secret`. Isi ulang dari web:
- kunci Firebase (Pengaturan → Push notification);
- secret access key (S3) dan password enkripsi **yang sama** untuk tujuan backup yang sama (Pengaturan → Backup). Selama rahasia lama tidak terbaca, password repositori yang ada boleh diisi ulang;
- kanal alert Telegram/email (Kesehatan sistem → Alert).

Simpan juga `docker/secrets/` dan `docker/.env` di luar server. Password role database ada di dalam backup dan harus cocok dengan isi `docker/secrets/`.

Simpan juga salinan `pgsodium_root.key` di tempat aman bersama password backup. Dengan salinan itu, rahasia di Vault ikut pulih.

**`make backup`** (pg_dump + arsip file storage ke folder `backups/`) tetap tersedia untuk salinan sesaat, misalnya sebelum upgrade besar. Itu bukan pengganti backup berkelanjutan.

## Profil cluster

Di profil cluster, layanan backup berjalan satu replika di node database. File storage di cluster disimpan di SeaweedFS (S3), jadi backup file di cluster mengandalkan replikasi SeaweedFS. Bagian `files` restic hanya berlaku untuk backend storage `file` (profil single).
