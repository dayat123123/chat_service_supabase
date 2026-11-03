# backup

Backup PostgreSQL berkelanjutan dengan pemulihan ke titik waktu (PITR), ditambah backup file Storage, ke repositori [restic](https://restic.net) di S3 (atau layanan S3-compatible) yang terenkripsi. Seminggu sekali layanan ini memulihkan backup terbaru ke PostgreSQL sementara dan menghitung isi beberapa tabel penting, jadi kita tahu backup benar-benar bisa dipakai, bukan sekadar ada.

Orkestratornya ditulis dengan standard library Go saja. Ia menjalankan `pg_receivewal`, `pg_basebackup`, `pg_verifybackup`, `postgres`/`pg_ctl` 17, `psql`, dan `restic` sebagai proses anak. Pengaturan (tujuan S3, password enkripsi, jadwal, retensi) dikelola Super Admin dari web CS dan dibaca lewat RPC `backup_config`. Tidak ada kredensial backup yang disimpan di file server.

## Arsitektur

```
db (supabase/postgres, tidak diubah)
 │  protokol replikasi, role olt_backup, slot fisik olt_backup
 ├─► pg_receivewal ──► /var/lib/olt-backup/wal/        (WAL terus-menerus, segmen terakhir *.partial)
 └─► pg_basebackup ──► /var/lib/olt-backup/base/<label>/ (base harian, plain + manifest SHA256)
                                │ pg_verifybackup
/mnt/storage (read-only) ───────┤
                                ▼
                 restic backup --tag base|files|wal ──► s3:https://host/bucket/prefix (AES-256, dedup, zstd)
```

Kenapa susunan ini:

- **Image database tidak diubah.** Tidak perlu `archive_command`, WAL-G, atau skrip di container `db` (`archive_mode` tetap `off`). Layanan ini hanya klien replikasi biasa: role `olt_backup` (LOGIN REPLICATION, batas 6 koneksi) dan baris `replication olt_backup` di `pg_hba.conf`.
- **`pg_receivewal` + slot fisik** menerima WAL begitu ditulis, jadi data di disk staging tertinggal beberapa detik saja. Slot `olt_backup` mencegah PostgreSQL membuang WAL yang belum diterima. Karena `max_slot_wal_keep_size = 512MB`, disk database tidak bisa penuh gara-gara layanan backup mati: bila tertinggal lebih dari 512 MB, slot menjadi `lost`, PostgreSQL membuang WAL lama, dan layanan ini membuat slot baru serta base backup baru (titik pemulihan di sela itu hilang dan dilaporkan sebagai `slot_lost`).
- **`pg_basebackup -Fp -X stream --checkpoint=fast --manifest-checksums=SHA256`** menghasilkan salinan fisik yang konsisten berikut WAL-nya sendiri, lalu `pg_verifybackup` mencocokkan setiap file dengan checksum manifest sebelum diunggah.
- **restic** mengenkripsi di sisi klien (S3 tidak pernah melihat isi data), menghapus duplikat antar snapshot, mengompres, dan menyediakan `forget`/`prune`/`check`. Kiriman WAL tiap beberapa menit hanya mengunggah potongan yang berubah.

Isi `DATA_DIR` (volume staging):

| Path | Isi |
|---|---|
| `wal/` | Keluaran `pg_receivewal`. Segmen yang sedang ditulis berakhiran `.partial` (ikut dikirim, tidak pernah dihapus lokal) |
| `wal-detached-<UTC>/` | WAL lama yang dipindahkan saat slot hilang/dibuat ulang atau database diganti. Tetap dikirim ke S3 lalu dihapus setelah ada base yang lebih baru |
| `base/<label>/` | Base backup terbaru saja (label `base-YYYYMMDDTHHMMSSZ`) |
| `restore-test/` | Data dir sementara uji restore, selalu dihapus setelah uji (juga saat start) |
| `state.json` | Keadaan lokal: base terakhir, waktu tiap pekerjaan, id sistem database |
| `cache/`, `tmp/` | Cache dan file sementara restic (root filesystem container read-only) |

Lisensi komponen di image (`alpine:3.22.7`, paket di-pin): PostgreSQL 17.11 (`postgresql17`, `postgresql17-client`; PostgreSQL License), restic 0.18.0 (BSD-2-Clause), ICU, OpenSSL, zstd, lz4, libxml2, OpenLDAP (dependensi PostgreSQL; lisensi permisif). Tidak ada komponen GPL/AGPL. Image sekitar 136 MB dan berjalan sebagai uid 10001.

## Jadwal

Semua jam memakai zona dari pengaturan (`Asia/Jakarta`).

| Pekerjaan | Kapan | `busy` | Dicatat (`backup_record`) |
|---|---|---|---|
| Streaming WAL | Terus-menerus, dijalankan ulang dengan jeda 1 detik → 1 menit bila keluar | – | – |
| Kirim WAL ke S3 | Tiap `offsite_minutes` (didahulukan di antara pekerjaan lain) | `offsite` | `wal`: setiap kegagalan, satu keberhasilan per jam, dan keberhasilan pertama setelah gagal |
| Base backup | Harian pada `base_time`; segera bila belum ada base, slot hilang/dibuat ulang, database diganti, atau repositori pindah; atas permintaan web | `base` | `base` |
| Backup file Storage | Langsung setelah base dan harian pada `base_time` | `files` | `files` |
| Retensi (`forget`) | Setelah setiap base | `prune` | `prune` dengan `detail.prune=false` |
| Retensi + `prune` | Mingguan | `prune` | `prune` dengan `detail.prune=true` |
| `restic check --read-data-subset=2%` | Mingguan | `check` | `check` |
| Uji restore | Mingguan bila `restore_test=true`; atas permintaan web | `restore_test` | `restore_test` |

Jendela mingguan = `restore_test_weekday` (0 = Minggu) pukul `restore_test_time`, urutannya prune → check → uji restore. Hanya satu pekerjaan berjalan pada satu waktu (selain streaming WAL); sisanya antre. Permintaan manual dari web (`base`, `restore_test`) masuk antrean yang sama; bila backup belum dikonfigurasi atau repositori belum siap, permintaan langsung dicatat gagal dengan alasannya. Jadwal yang terlewat (layanan mati) dijalankan begitu layanan hidup. Base dan backup file yang gagal dicoba lagi setelah 15 menit, lalu 30 menit, 1 jam, ... maksimal 6 jam. Pekerjaan mingguan yang gagal menunggu jendela minggu berikutnya (atau permintaan manual).

Sebelum base dimulai, layanan memastikan streaming WAL sudah berjalan dan slot sudah menahan WAL (menunggu maksimal 2 menit). Tanpa itu base tidak bisa dipakai untuk PITR, jadi base ditunda dan dicatat gagal.

## Retensi

- `base` dan `files`: `restic forget --keep-daily D --keep-weekly W --keep-monthly M`, per host snapshot (`olt-social`, tetap walau container dibuat ulang).
- `wal`: `restic forget --keep-within <wal_days>d`. Jadi PITR ke sembarang detik hanya bisa dalam `wal_days` terakhir; base yang lebih tua tetap bisa dipulihkan ke titik akhirnya sendiri.
- Lokal: hanya base terbaru. Segmen WAL lokal dihapus setelah terkirim lengkap dalam snapshot yang berhasil **dan** lebih tua dari awal base lokal terbaru. File `.partial` dan `.history` tidak pernah dihapus.
- Keamanan disk: sebelum base, layanan memperkirakan ukuran database (`sum(pg_database_size)`). Bila ruang kosong kurang dari perkiraan × 1,2, base lama lokal (sudah ada di S3) dihapus dulu kalau itu cukup; kalau tetap tidak cukup, base tidak dijalankan dan dicatat gagal dengan pesan "Ruang disk staging tidak cukup ...". Uji restore memakai pemeriksaan serupa.

## RPO dan RTO

- **RPO server database rusak, disk staging selamat:** beberapa detik (WAL ditulis `pg_receivewal` begitu diterima; posisi dilaporkan tiap 10 detik).
- **RPO server hilang total:** paling lama `offsite_minutes` (default 5 menit), ditambah lama pekerjaan panjang yang sedang berjalan saat itu (kiriman WAL tidak berjalan bersamaan dengan base/uji restore). Segmen `.partial` ikut dikirim, jadi tidak perlu menunggu segmen 16 MB penuh.
- **RTO:** waktu unduh base + WAL dari S3, lalu replay WAL sejak base (paling banyak satu hari). Untuk produksi hitung kira-kira `ukuran database ÷ bandwidth unduh` + replay, dan pakai `duration_s` uji restore mingguan sebagai patokan nyata.

Angka uji end-to-end di laptop dev (database 49 MB, file Storage 11 MB, repositori SeaweedFS lokal):

| Langkah | Hasil |
|---|---|
| Base pertama (`pg_basebackup` + `pg_verifybackup` + upload) | 7 detik, 73 MB lokal, 52 MB terunggah setelah kompresi; base berikutnya hanya 7 MB baru (dedup) |
| Backup file Storage | 1 detik, 41 file |
| Kiriman WAL | < 1 detik per kiriman |
| Uji restore (unduh + verifikasi + recovery + hitung) | 5–6 detik, jumlah baris sama persis dengan database asli |
| `restore` PITR ke volume baru + start image `supabase/postgres:17.6.1.136` | restore 3 detik; recovery berhenti tepat sebelum commit pertama setelah waktu target, promosi ke timeline 2 |

Saat repositori pertama kali dibuat di bucket yang belum ada, `restic cat config` terus mencoba ulang; layanan memotongnya setelah 45 detik lalu menjalankan `restic init` (yang sekaligus membuat bucket). Jadi konfigurasi pertama butuh sekitar satu menit sebelum streaming dimulai.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | HTTP internal (`/healthz`, `/readyz`, `/metrics`), tidak untuk publik |
| `LOG_LEVEL` | `info` | `debug` menampilkan setiap baris `pg_receivewal` |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter. Untuk token `service_role` 1 menit ke PostgREST |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `INSTANCE_ID` | hostname + 6 hex acak | Nama instance di heartbeat (maks. 100 karakter) |
| `PGHOST` / `PGPORT` | `db` / `5432` | Langsung ke PostgreSQL (bukan PgBouncer: replikasi butuh koneksi langsung) |
| `PGUSER` | `olt_backup` | Role LOGIN REPLICATION |
| `PGPASSWORD_FILE` (atau `PGPASSWORD`) | wajib | `/run/secrets/backup_db_password` |
| `PGDATABASE` | `postgres` | Untuk query status slot dan ukuran database |
| `DATA_DIR` | `/var/lib/olt-backup` | Volume staging (lihat tabel di atas) |
| `STORAGE_DIR` | `/mnt/storage` | Volume file Storage, di-mount read-only |
| `CONFIG_POLL` | `15s` | Interval cek revisi pengaturan (`backup_config(p_revision)`, 1s–10m) |
| `HEARTBEAT_INTERVAL` | `30s` | 5s–60s; heartbeat juga dikirim segera saat keadaan berubah |
| `REQUEST_TIMEOUT` | `10s` | Batas waktu RPC dan query status (1s–2m) |
| `RESTORE_TEST_TIMEOUT` | `2h` | Batas waktu satu uji restore (5m–24h) |
| `SHUTDOWN_TIMEOUT` | `60s` | Waktu menunggu proses anak berhenti saat SIGTERM (5s–10m) |

Password database, password restic, dan secret S3 hanya diteruskan ke proses anak lewat environment (`PGPASSWORD`, `RESTIC_PASSWORD`, `AWS_SECRET_ACCESS_KEY`), tidak pernah lewat argumen. Proses anak tidak mewarisi environment layanan (hanya daftar variabel yang dibutuhkan). Semua keluaran proses anak yang masuk log, heartbeat, atau catatan pekerjaan disaring: nilai variabel rahasia dan kredensial di URL diganti `[redacted]`. Pengaturan dari database tidak pernah ditulis utuh ke log (hanya revisi dan alamat repositori).

Pengaturan dibaca dengan revisi: bila revisi sama, database hanya menjawab `unchanged`. Bila tujuan atau kredensial berubah, repositori dibuka ulang (`restic cat config`, lalu `restic init` bila belum ada; bucket yang belum ada ikut dibuat), dan `restic unlock` membersihkan kunci basi. Password yang salah untuk repositori yang sudah ada tampil sebagai error, repositori **tidak** di-init ulang. Pindah ke repositori lain memicu base dan backup file baru. Bila backup dimatikan dari web (`configured=false`), streaming berhenti dan slot `olt_backup` dihapus supaya database tidak lagi menahan WAL.

## Heartbeat dan catatan

`backup_heartbeat` dikirim tiap `HEARTBEAT_INTERVAL` dan segera saat keadaan berubah, dengan `p_config_revision` revisi pengaturan yang sedang dipakai. Isi `p_state`:

| Field | Arti |
|---|---|
| `repository_ready` | Pengaturan valid dan repositori terbuka dengan password itu |
| `wal.streaming` | `pg_receivewal` berjalan dan sudah mulai streaming |
| `wal.slot_lost` | Slot pernah hilang/dibuat ulang dan base baru belum selesai |
| `wal.last_segment` | Nama segmen terbaru di `wal/` (tanpa `.partial`) |
| `wal.last_received_at` | Waktu file WAL terakhir ditulis. Database yang sepi memang jarang menulis WAL |
| `wal.local_bytes` | Ukuran WAL di disk staging (termasuk `wal-detached-*`) |
| `wal.error` | Alasan streaming berhenti, atau peringatan slot `unreserved` (hampir hilang) |
| `offsite.last_ok_at` / `last_snapshot` / `last_error` | Kiriman WAL terakhir yang berhasil, id snapshot-nya, error kiriman terakhir |
| `offsite.pending_bytes` | Ukuran file WAL yang berubah sejak awal kiriman terakhir yang berhasil (segmen `.partial` dihitung penuh 16 MB) |
| `local_base` | Label, waktu selesai, dan ukuran base lokal |
| `disk` | `statfs` `DATA_DIR` |
| `busy` | Pekerjaan yang sedang berjalan |
| `error` | Pengaturan tidak valid (mis. secret Vault tidak bisa dibuka) atau repositori tidak bisa dibuka |

Database menandai status layanan `error` bila `error` atau `wal.error` terisi. Catatan `backup_record` yang gagal terkirim disimpan di memori (maksimal 100) dan dikirim ulang setelah heartbeat berhasil.

`detail` per jenis catatan: `base` → `label`, `start_wal`, `estimated_db_bytes`, `data_added`, `backup_s`, `verified`; `files` → `files`, `data_added`; `wal` → `files`, `data_added`, `removed_local`; `prune` → `prune`, `removed{base,files,wal}`; `check` → `read_data_subset`; `restore_test` → `recovered_until`, `last_message_at`, `tables{public.profiles,public.messages,cs.tickets}`, `base_label`, `base_snapshot`, `wal_snapshot`, `start_wal`, `wal_segments`. Semua menyertakan `duration_s`.

## Uji restore

1. Kirim WAL terbaru ke S3 dulu, lalu ambil base terbaru dan snapshot WAL terbaru dari repositori (bukan dari disk lokal: yang diuji adalah salinan di luar server).
2. Restore ke `DATA_DIR/restore-test/data`, kumpulkan WAL ke `restore_wal/`, ganti nama `.partial` terakhir menjadi segmen biasa, dan periksa rantai WAL dari awal base sampai akhir tanpa celah.
3. `pg_verifybackup` mencocokkan base hasil restore dengan manifest-nya.
4. Jalankan `postgres` 17 sebagai uid layanan dengan konfigurasi minimal: hanya Unix socket di folder sementara (`listen_addresses=''`), `shared_preload_libraries=''`, `hot_standby=off`, `autovacuum=off`, `fsync=off`, `restore_command` dari `restore_wal/`, `recovery_target_action=promote`.
5. Tunggu sampai recovery selesai dan server promosi, lalu hitung `public.profiles`, `public.messages`, `cs.tickets`, `max(created_at)` pesan, dan `pg_last_xact_replay_timestamp()` (= `recovered_until`).
6. Hentikan dengan `pg_ctl -m fast`, hapus folder sementara (juga saat gagal atau melewati `RESTORE_TEST_TIMEOUT`).

## Prosedur pemulihan

**Simpan offline (Super Admin):** password enkripsi restic, access key dan secret S3, alamat repositori (`s3:https://host/bucket/prefix`). Tanpa password restic backup **tidak bisa dibuka oleh siapa pun**; password tersimpan di Vault database, yang justru ikut hilang bila server hilang. Untuk pemulihan ke server baru simpan juga salinan `docker/secrets/` dan `docker/.env` (password role database di backup harus cocok dengan secret yang dipakai layanan lain).

Lihat titik pemulihan yang tersedia:

```sh
make backup-snapshots          # .\make.ps1 backup-snapshots
```

Perintah ini membaca kredensial dari database lewat layanan backup. Bila database sudah mati, isi env `RESTIC_REPOSITORY`, `RESTIC_PASSWORD` (atau `RESTIC_PASSWORD_FILE`), `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION` (bila perlu). Keluaran berisi rentang `--target-time` yang bisa dipakai.

### A. Server yang sama (salah hapus data, korupsi)

1. Pilih waktu target sebelum kejadian, format RFC3339 dengan zona, mis. `2026-11-03T10:15:00+07:00`, atau `latest` untuk WAL terbaru.
2. Isi env kredensial di atas pada shell (jangan ditulis ke file di repo).
3. Jalankan `make restore-pitr AT=2026-11-03T10:15:00+07:00 CONFIRM=yes` (Windows: `.\make.ps1 restore-pitr -At 2026-11-03T10:15:00+07:00 -Yes`). Target ini:
   1. menghentikan seluruh stack;
   2. menjalankan `backup restore --target-time ... --data-dir /restore --wipe` sebagai root di container sekali-pakai dengan volume `db-data` di `/restore`. Perintah ini menolak bila `postmaster.pid` masih ada, memilih base terbaru **sebelum** waktu target dan kiriman WAL pertama **sesudahnya**, mengosongkan data dir, me-restore base dan WAL ke `restore_wal/`, memeriksa rantai WAL, menjalankan `pg_verifybackup`, menambahkan `restore_command`, `recovery_target_time`, `recovery_target_action='promote'` ke `postgresql.auto.conf`, membuat `recovery.signal`, lalu mengubah pemilik ke `100:101` (user `postgres` image Supabase) dengan mode `0700`;
   3. menyalakan `db` dan menunggu `pg_isready` berhasil (recovery selesai dan promosi; selama recovery koneksi ditolak), maksimal satu jam;
   4. menghapus pengaturan pemulihan (`ALTER SYSTEM RESET ...`) dan folder `restore_wal/`.
4. Periksa data (mis. `make psql`), lalu `make up`.
5. Layanan backup melihat slot `olt_backup` tidak ada lagi (slot tidak ikut base backup) dan timeline baru: WAL lokal lama dipindah ke `wal-detached-*`, slot dibuat ulang, base baru diambil otomatis. Realtime membuat ulang slot logisnya sendiri.

Bila log database berisi `recovery ended before configured recovery target was reached`, tidak ada transaksi yang tercatat setelah waktu target (database sepi). Ulangi dengan `AT=latest`; hasilnya sama.

Langkah manual yang setara (tanpa make; `docker compose` dengan file `-f` sesuai profil seperti di Makefile):

```sh
docker compose stop
docker run --rm --user 0:0 --network olt-social_egress \
  -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
  -v olt-social_db-data:/restore olt-social/backup:0.1.0 \
  restore --target-time 2026-11-03T10:15:00+07:00 --data-dir /restore --wipe
docker compose up -d db
until docker compose exec -T db pg_isready -U postgres -h localhost -q; do sleep 5; done
docker compose exec -T db psql -U supabase_admin -d postgres \
  -c "ALTER SYSTEM RESET restore_command" -c "ALTER SYSTEM RESET recovery_target_time" \
  -c "ALTER SYSTEM RESET recovery_target_action" -c "ALTER SYSTEM RESET recovery_target_timeline" \
  -c "SELECT pg_reload_conf()"
docker compose exec -T -u postgres db rm -rf /var/lib/postgresql/data/restore_wal
```

Langkah ini sudah diuji dengan image `supabase/postgres:17.6.1.136` (container sekali-pakai di volume terpisah): recovery berhenti tepat sebelum commit pertama setelah waktu target, server promosi, `pg_isready` berhasil, dan perintah pembersihan di atas berjalan.

### B. Server baru

1. Siapkan repo dan kembalikan `docker/secrets/` serta `docker/.env` dari salinan offline (atau `make gen-secrets` bila tidak ada; lihat catatan di bawah).
2. `make up` sekali agar semua volume dibuat compose, lalu jalankan langkah A.2–A.4 dengan `AT=latest` (atau waktu tertentu). Isi `db-data` hasil inisialisasi diganti hasil restore.
3. **Kunci Vault tidak ikut backup.** Kunci akar pgsodium/Vault ada di volume `db-config` (`/etc/postgresql-custom/pgsodium_root.key`), bukan di data dir, jadi server baru punya kunci lain dan semua secret Vault dari backup tidak bisa dibuka. Setelah pemulihan:
   - unggah ulang kunci Firebase dari web CS (**Pengaturan → Push notification**);
   - isi ulang secret access key dan password enkripsi **yang sama** untuk lokasi yang sama dari web CS (**Kesehatan sistem → Backup**). Selama rahasia lama tidak terbaca, web mengizinkan password diisi ulang untuk repositori yang sama (migrasi `0067`, audit `password_recovered`). Sampai itu dilakukan, `backup_config` menjawab `configured=false` + `problem=secret_unreadable` dan muncul alert kritis `backup:secret`;
   - isi ulang token Telegram / password SMTP di **Kesehatan sistem → Alert** (alert `alerts:secret`).
4. Bila `docker/secrets/` tidak bisa dikembalikan, password role database di hasil restore tidak cocok dengan secret baru; setel ulang password role (`postgres`, `authenticator`, `supabase_*`, `olt_backup`) lewat `psql -U supabase_admin` di container `db` agar sama dengan isi `docker/secrets/`.

## Endpoint dan metrik

`GET /healthz` (liveness), `GET /readyz` (200 jika PostgREST terjangkau), `GET /metrics` (format teks Prometheus), dan subcommand `backup healthcheck`.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `backup_configured` | gauge | 1 jika pengaturan valid |
| `backup_repository_ready` | gauge | 1 jika repositori terbuka |
| `backup_wal_streaming` | gauge | 1 saat `pg_receivewal` streaming |
| `backup_wal_slot_lost` | gauge | 1 setelah slot hilang sampai base baru selesai |
| `backup_busy{job}` | gauge | Pekerjaan yang sedang berjalan |
| `backup_runs_total{kind,status}` | counter | Pekerjaan selesai per jenis dan hasil |
| `backup_wal_receiver_restarts_total` | counter | Berapa kali `pg_receivewal` keluar dan dijalankan ulang |
| `backup_wal_local_bytes` | gauge | WAL di disk staging |
| `backup_offsite_pending_bytes` | gauge | WAL yang berubah sejak kiriman terakhir yang berhasil |
| `backup_local_base_bytes` | gauge | Ukuran base lokal |
| `backup_disk_total_bytes` / `backup_disk_avail_bytes` | gauge | Disk staging |
| `backup_wal_last_received_timestamp_seconds` | gauge | Waktu Unix WAL terakhir ditulis |
| `backup_offsite_last_success_timestamp_seconds` | gauge | Kiriman WAL terakhir yang berhasil |
| `backup_base_last_success_timestamp_seconds` | gauge | Base terakhir yang berhasil |
| `backup_restore_test_last_success_timestamp_seconds` | gauge | Uji restore terakhir yang berhasil |

Saat SIGTERM, proses anak dihentikan dengan SIGINT (`pg_receivewal` menutup file dengan rapi, restic melepas kuncinya), dibunuh setelah 30 detik, dan layanan keluar paling lambat `SHUTDOWN_TIMEOUT`. Pekerjaan yang terpotong tidak dicatat gagal dan diulang sesuai jadwal. Atur `stop_grace_period` container lebih panjang dari `SHUTDOWN_TIMEOUT` (misalnya 90s), dan beri container `hostname` tetap supaya restic mengenali kunci basi miliknya sendiri.

Hak akses database yang dibutuhkan: `LOGIN REPLICATION` untuk `olt_backup`, plus hak `CONNECT` ke database `postgres` (dari `PUBLIC`, default) untuk membaca `pg_replication_slots` dan `pg_database_size`. Bila `CONNECT` dicabut dari `PUBLIC`, berikan `GRANT CONNECT ON DATABASE postgres TO olt_backup`.

Tes: `go test ./...` (juga `-race`).
