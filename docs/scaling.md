# Skalabilitas: single → cluster

> Status: profil `dev` dan `single` sudah berjalan dan teruji. Profil `cluster` masih **kerangka** dan akan dilengkapi serta diuji di Tahap 7 (lihat [production-audit.md](production-audit.md)).

## Profil deploy

Ketiga profil memakai **image, nama service, dan nama environment variable yang sama**. Perbedaannya hanya di file override, sehingga pindah profil tidak mengubah kode aplikasi.

| Profil | File | Perintah | Isi khusus |
|---|---|---|---|
| `dev` | `docker/compose.yml` + `compose.dev.yml` | `make up` | HTTP `:8000`, semua path (Studio), CORS `*`, token mock, log debug |
| `single` | `docker/compose.yml` + `compose.prod.yml` | `make up PROFILE=single` | HTTPS Let's Encrypt, hanya path API publik, Studio mati, `APP_ENV=production` |
| `cluster` | `docker/compose.yml` + `stack.cluster.yml` | `make up PROFILE=cluster` | Swarm: replika, rolling update `start-first`, overlay terenkripsi, Realtime cluster, storage S3 |

## Yang sudah siap multi-node sejak profil single

- **Edge sama.** Traefik dan Kong dipakai di semua profil dengan konfigurasi dinamis yang sama (`docker/volumes/traefik/`).
- **Pooler.** Aplikasi konek ke Postgres lewat PgBouncer, sehingga menambah replika service tidak melipatgandakan koneksi DB. Pengecualian: Realtime (replikasi logis) dan migrasi.
- **Valkey tersedia** untuk state bersama: rate limit, cache, dan lock (dipakai auth-bridge mulai Tahap 3).
- **Rahasia lewat Docker secrets.** Di compose, sumbernya file `docker/secrets/`. Di Swarm, sumbernya secret yang sama, dibuat saat `docker stack deploy`.
- **Config file lewat `configs`.** Konfigurasi Kong, Traefik, dan init DB dipasang sebagai `configs`, bukan bind mount, sehingga juga jalan di Swarm.
- **Tanpa `container_name`.** Nama tetap Realtime (`realtime-dev.supabase-realtime`) diganti alias network, sehingga service bisa direplikasi.
- **Region Realtime.** Semua node memakai `REGION: us-east-1`, sama dengan region tenant hasil seed self-host. Bila berbeda, Realtime memutus koneksi DB tenant tiap 10 menit ("rebalancing") dan broadcast dari database (tanda terima chat) hilang.
- **Storage S3-ready.** Pindah dari backend `file` cukup lewat env: `STORAGE_BACKEND=s3` dan `GLOBAL_S3_*`.

## Ukuran pool PostgREST di belakang PgBouncer

PgBouncer berjalan dalam mode `session`. Artinya satu koneksi klien memegang satu koneksi server sampai klien itu menutupnya. Setiap instance PostgREST memakai hingga `PGRST_DB_POOL` koneksi, ditambah 1 koneksi `LISTEN` untuk reload schema cache. Karena itu, untuk setiap instance PgBouncer berlaku:

```
replika PostgREST × (PGRST_DB_POOL + 1) ≤ PGBOUNCER_DEFAULT_POOL_SIZE
```

`PGBOUNCER_RESERVE_POOL_SIZE` (5) hanya cadangan dan baru dipakai setelah klien menunggu 5 detik.

Bila aturan ini dilanggar, permintaan saat lonjakan menunggu koneksi server lebih lama dari `query_wait_timeout` (30 detik), lalu PostgREST membalas `503 PGRST001`. Contoh nyata dari `make cs-race`: 3 replika tambahan dengan pool bawaan 10 menghasilkan 33 klien untuk pool 20+5, dan 11 dari 50 klaim gagal dengan 503. Karena itu tes tersebut menjalankan replikanya dengan `PGRST_DB_POOL=3`.

Dengan nilai bawaan (`PGRST_DB_POOL=10`, `PGBOUNCER_DEFAULT_POOL_SIZE=20`), satu PgBouncer cukup untuk 1 replika PostgREST. Untuk lebih banyak replika per PgBouncer, ada dua pilihan:

- Naikkan `PGBOUNCER_DEFAULT_POOL_SIZE`. Total koneksi server dari semua PgBouncer tetap harus di bawah batas role `authenticator` (60) dan `max_connections` Postgres (100).
- Turunkan `PGRST_DB_POOL`.

Profil `cluster` (2 replika `rest`, 2 replika `pgbouncer`) hanya aman bila koneksi terbagi rata. Ini diverifikasi di Tahap 7.

## Garis besar migrasi single → cluster (dirinci di Tahap 7)

1. **Siapkan node.** Inisialisasi Swarm dengan 3 manager. Beri label node DB: `docker node update --label-add olt.db=primary <node>`.
2. **Registry.** Push image buatan sendiri (`auth-bridge`, `pgbouncer`, `tools`) ke registry privat (`REGISTRY`).
3. **Object storage.** Siapkan SeaweedFS (Apache 2.0). Salin isi volume `storage-data` ke bucket. Saat migrasi, profil single tetap melayani baca.
4. **Database.** Buat replica streaming dari primary single, lalu promosikan saat cutover. Downtime hanya sebatas jendela cutover.
5. **Cutover.**
   1. Hentikan tulis sebentar.
   2. Sinkronkan file storage terakhir.
   3. Jalankan `make up PROFILE=cluster`.
   4. Pindahkan DNS ke node manager.
6. **Verifikasi.** Jalankan skenario uji multi-node. Rollback: arahkan DNS kembali ke server single, yang belum dimatikan.
