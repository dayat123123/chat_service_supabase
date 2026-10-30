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
