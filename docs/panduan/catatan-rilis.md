# Catatan Rilis untuk Operator

Langkah tambahan yang dibutuhkan saat memperbarui server ke rilis tertentu, terbaru di atas. Langkah update biasa ada di [pembaruan-sistem.md](pembaruan-sistem.md). Baca bagian rilis yang akan dipasang **sebelum** menjalankan `make up`.

Rilis yang tidak tercantum di sini cukup mengikuti langkah update biasa.

## 18 November 2026

### Jeda bergabung lagi setelah hapus akun (migrasi `0175`, auth-bridge, library 1.38.0, Hub)

- Setelah menghapus akun komunitas, login yang sama baru bisa membuka komunitas lagi setelah **72 jam**. Saat bergabung lagi, akun dimulai sebagai akun baru.
- Lama jeda diatur di Hub: **Kepatuhan → Kebijakan konten → Aturan → Jeda bergabung lagi setelah hapus akun** (0–720 jam, 0 = tanpa jeda). Perubahannya lewat draf dan persetujuan staf Kepatuhan lain, sama seperti kebijakan konten lain.
- Selama jeda, app menampilkan sisa waktunya dan tombol **Hubungi CS** yang membuka pengaduan tamu. Chat CS di dalam app ikut tertutup, sama seperti akun yang di-ban. Akun yang di-ban kini juga mendapat pesan yang jelas, bukan error umum.
- `make up` memasang migrasi dan membangun ulang auth-bridge sekaligus. Tidak ada pengaturan di `docker/.env` atau container baru. Pasang server lebih dulu, baru aplikasi dengan library 1.38.0. Aplikasi lama tetap ditolak selama jeda, hanya saja dengan pesan error umum.
- Jeda berlaku juga untuk akun yang dihapus sebelum rilis ini, dihitung dari waktu hapusnya.

### Blokir tetap berlaku setelah hapus akun (migrasi `0174`)

- Sebelumnya, pengguna yang diblokir bisa menghapus akun komunitas lalu login lagi, dan blokir dari orang lain terhadap dirinya ikut hilang. Sekarang blokir dan mute dari orang lain tetap disimpan dan berlaku lagi saat ia login kembali.
- Blokir yang hilang karena hapus akun sebelum rilis ini tidak bisa dipulihkan. Pengguna yang terdampak perlu memblokir ulang.
- Migrasi berjalan otomatis lewat `make up`. Aplikasi tidak perlu diperbarui.

### Mention di grup (migrasi `0173`, library 1.36.0)

- Di chat grup, pengguna bisa menyebut anggota grup dengan `@`. Saran nama hanya berisi anggota grup itu, dan `$KODE` di grup tetap mati.
- Anggota yang disebut mendapat notifikasi "X menyebut Anda di <grup>" sebagai pengganti notifikasi pesan biasa, walaupun ia membisukan grup itu. Pengaturan "Siapa yang bisa menyebut saya" tetap dihormati.
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan atau container baru. `0172` dan `0173` boleh terpasang dalam satu kali update.
- Aplikasi dengan library 1.35.0 tetap jalan, hanya tanpa saran `@` di grup.

### Pengaturan mention (migrasi `0172`, library 1.35.0)

- Pengguna bisa memilih siapa yang boleh menyebut dirinya: semua orang (bawaan), hanya yang ia ikuti, atau tidak ada. Mention dari orang yang tidak diizinkan tidak memberi notifikasi, dan namanya tidak muncul di saran `@`. Teks `@nama` di postingan tetap tampil apa adanya.
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan, container, atau API key baru.
- Pasang server lebih dulu, baru aplikasi dengan library 1.35.0. Aplikasi lama tetap jalan tanpa pilihan ini, dan aturan notifikasi sudah berlaku untuk semua aplikasi karena ditegakkan di server.
- Di library 1.35.0, mention `@` dan `$KODE` hanya aktif di room saham. Di chat langsung, grup, dan chat CS keduanya menjadi teks biasa.

### Notifikasi ke satu login untuk alert harga (migrasi `0171`)

- API notifikasi OLT menerima target baru `{"olt_user_id": "..."}`: satu login, dikirim langsung, cukup izin `notify`, dan tidak kena batas 3 siaran per hari. Dipakai untuk alert harga yang dipasang pengguna di app OLT. Rinciannya untuk tim OLT ada di [docs/integration](../integration/README.md#2c-satu-login-targetolt_user_id-alert-harga).
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan, container, atau API key baru; key `notify` yang sudah ada langsung bisa dipakai.
- Target lama (`cust_id`, `olt_user_ids`, `audience`) tidak berubah. Aplikasi tidak perlu diperbarui.

## 17 November 2026

### Kontrol komentar (migrasi `0169`, library 1.31.0)

- Pemilik post bisa mematikan komentar atau membatasi siapa yang boleh berkomentar. Semua post lama tetap terbuka untuk semua orang.
- Migrasi berjalan otomatis lewat `make up` (atau `make migrate`). Tidak ada pengaturan baru di `docker/.env` dan tidak ada container baru.
- Pasang server lebih dulu, baru aplikasi dengan library 1.31.0. Aplikasi dengan library lama tetap jalan: pilihan komentar tidak tampil, dan komentar ke post yang dimatikan ditolak dengan pesan error umum.
- Komentar yang disembunyikan tidak dihapus. Hub tetap bisa melihat dan memoderasinya.

### Matikan komentar di semua postingan (migrasi `0170`, library 1.33.0)

- Saklar baru di pengaturan komunitas: pengguna bisa mematikan komentar di semua postingannya sekaligus. Pengaturan per post tidak diubah, jadi saat saklar dimatikan setiap post kembali ke pengaturannya sendiri.
- Migrasi berjalan otomatis lewat `make up`. Tidak ada pengaturan atau container baru. `0169` dan `0170` boleh terpasang dalam satu kali update.
- Aplikasi dengan library 1.31.0–1.32.0 tetap jalan tanpa saklar ini. Post milik pengguna yang menyalakan saklar tetap tertutup untuk semua klien karena aturannya ditegakkan di server.

## 16 November 2026

### Kesehatan sistem pindah ke Pengaturan (Hub)

- Kesehatan sistem kini ada di **Pengaturan → Sistem → Kesehatan sistem** (di atas Backup dan Alert), berisi tab Peta layanan, Status, dan Restart otomatis. Menu "Kesehatan sistem" di bar atas dihapus.
- Bila ada alert gangguan, angka merah tampil di menu **Pengaturan**.
- Alamat lama `/system` dialihkan otomatis untuk Super Admin.
- Cukup `git pull` di `rendezvous_hub` lalu `make up`.

### Peta layanan (migrasi `0168`, healer 0.2.0, sentinel 0.5.0)

- Healer membaca daftar semua container (hanya baca) dan menulis `nodes.json`; sentinel meneruskannya ke database setiap ±10 detik. Hasilnya tampil di tab **Peta layanan**.
- Batas healer naik menjadi 0,25 CPU / 48 MB. Pengaturan baru (opsional) `HEALER_NODES_FILE` dan `HEALER_NODES_SECONDS`; kosongkan `HEALER_NODES_FILE` untuk mematikan.
- `make up` membangun ulang healer dan sentinel. Data peta muncul ±20 detik setelah keduanya berjalan.
- Profil cluster belum didukung (healer tidak berjalan di Swarm).

### Dua replika untuk layanan sibuk

- `rest`, `auth-bridge`, `media`, `classifier`, `imgproxy`, dan `integration` kini berjalan 2 replika. Jumlahnya diatur `*_REPLICAS` di `docker/.env` ([skalabilitas.md](skalabilitas.md#replika-di-profil-dev-dan-single)).
- Batas RAM semua container naik ±2,5 GB. Pastikan server punya ruang ([spesifikasi-server.md](spesifikasi-server.md)).
- Pool PgBouncer bawaan naik dari 20 ke 24. Bila `docker/.env` mengisi `PGBOUNCER_DEFAULT_POOL_SIZE` sendiri, nilainya harus ≥ 22 (2 × 11).

### Jenis notifikasi Berbagi Trade disembunyikan (migrasi `0167`)

- `trade_activity` dan `trade_share` hanya muncul di pengaturan notifikasi aplikasi bila Berbagi Trade dinyalakan. Sebelumnya aplikasi dengan library lama menampilkannya sebagai kode mentah.
- Tidak ada langkah tambahan; migrasi berjalan otomatis.

## 15 November 2026

### Berbagi Trade (migrasi `0160`–`0166`), dijeda

- Fitur Berbagi Trade dan layanan relay trade ada di repo tetapi **tidak aktif**: menu Hub disembunyikan (`SHOW_TRADE_SHARE = false`), container `trade-relay` dan `dummy-iproxy` berada di profil compose `trade-relay` sehingga tidak ikut `make up`, dan tombol darurat `trade_share.enabled` mati.
- Bila server sempat menjalankan relay sebelum dijeda, matikan sekali: `docker stop olt-social-trade-relay-1`.
- Cara mengaktifkan lagi: [docs/berbagi-trade/operasional.md](../berbagi-trade/operasional.md).

## Rilis sebelumnya

### 4 November 2026 — Batas CGNAT dan latensi alert (migrasi `0108`, sentinel 0.3.0, PgBouncer `1.24.0-5`)

sebelum `make up`, periksa `docker/.env` server. Baris `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` atau `EDGE_WS_PER_IP` yang lebih kecil dari 1.000 (mis. sisa 30/300/150 dari rilis lama) membuat `check-config` profil `single`/`cluster` gagal; hapus barisnya agar default baru (1.500) dipakai. Traefik kini dibatasi 768M (sebelumnya 256M). PgBouncer dan sentinel di-build ulang otomatis oleh `make up`.

### 4 November 2026 — Image pihak ketiga (T5)

Postgres `17.6.1.136` → `17.11.0.008` (PostgreSQL 17.6 → 17.11, major sama, tanpa dump/restore), Realtime `v2.148.6`, Storage `v1.84.32`, Studio `2026.10.26-sha-478bd88`, edge-runtime `v1.77.9`, Kong `3.9.4`, Traefik `v3.7.16`. Rincian dan alasan per image: [laporan uji 12.7](../testing/report-2026-11-03.md#127-t5-versi-image-pihak-ketiga-4-nov).

- Wajib `make backup PROFILE=single` sebelum `make up`. Image `db` berganti, jadi `db` dan layanan yang bergantung padanya dibuat ulang. Di dev, semua service healthy lagi dalam ±2 menit.
- PostgreSQL 17.11 hanya mengizinkan output plugin di `output_plugin_libraries`. `postgresql.conf` image sudah berisi `pgoutput, test_decoding, wal2json`. Bila config Postgres diganti sendiri, `wal2json` wajib ada; tanpa itu `postgres_changes` Realtime berhenti.
- Tidak perlu `REINDEX`: tidak ada `btree_gist`, `comments.path` (ltree) jauh di bawah 14.653 label, dan tidak ada fungsi kita yang memakai PGP pgcrypto.
- Volume `db-config` (`/etc/postgresql-custom`) tidak diperbarui otomatis. Isinya tetap berkas image lama (`supautils.conf`, `extension-custom-scripts/`, tanpa `conf.d/pg_net.conf`), sama seperti upstream. Server baru mendapat versi baru. Jangan hapus volume ini (berisi `pgsodium_root.key`).
- `make up --wait` bisa gagal sekali dengan `rest is unhealthy`: PgBouncer ikut dibuat ulang, listener PostgREST mundur 8 → 16 → 32 dtk, dan `/ready` 503 ±70 dtk. Tunggu sebentar, lalu jalankan `make up` lagi.
- Storage `v1.84.32` tidak menambah migrasi internal (terakhir tetap `74 unlock-object-versioning`), jadi kembali ke `v1.81.0` masih aman.
- Realtime `v2.148.6` memakai Phoenix 1.8.15: pesan WebSocket dengan `join_ref` yang tidak cocok dengan join channel diabaikan diam-diam. Klien Dart (`realtime_client`) dan realtime-js aman. Klien buatan sendiri wajib mengirim `join_ref` = `ref` dari `phx_join` channel itu.

### Alert kapasitas (migrasi `0104`, sentinel 0.2.0, PgBouncer `1.24.0-4`)

rilis ini menambah Docker secret `pgbouncer_stats_password` (user konsol admin PgBouncer `olt_stats` untuk sentinel). Jalankan `make gen-secrets` (Windows: `.\make.ps1 gen-secrets`) sebelum `make up`; secret yang sudah ada dipertahankan dan hanya yang belum ada dibuat. Tanpa secret ini `check-config` gagal dan PgBouncer tidak mau start.

### Realtime Broadcast (migrasi `0098`, `rendezvous_community` 1.5.0)

Rilis ini memutus klien lama. Klien 1.4.x tetap tersambung, tetapi tidak lagi menerima pesan baru secara realtime (hanya saat memuat ulang) dan typing-nya tidak sampai. Urutan rilis:

1. App OLT dengan `rendezvous_community` 1.5.0 sudah tersedia di toko aplikasi / kanal update Windows untuk semua platform.
2. Deploy backend (`git pull`, `make up`).
3. Segera setelahnya, Super Admin atau peran Fitur & Kampanye membuka web CS **Fitur & Kampanye → Fitur & versi → Versi minimum aplikasi** dan mengisi versi app OLT pertama yang membawa 1.5.0 untuk setiap platform yang dipakai OLT (`android`, `windows`, dan `ios`/`macos`/`linux`/`web` bila ada). Yang dibandingkan adalah `appVersion` app OLT yang dikirim ke `initialize(...)`, bukan versi package. Perubahan tercatat di jejak audit. App yang lebih lama menerima `update_required: true` dari `get_client_config` dan callback `onUpdateRequired` mengarahkan nasabah ke update. Detail: [panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md#kompatibilitas-server-dan-versi-minimum).
4. Data di database tidak perlu diubah manual.