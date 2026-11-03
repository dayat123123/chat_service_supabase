# Uji keamanan, beban, dan chaos

Alat uji untuk Poin 14: sebelum produksi, sistem diuji keamanan, beban, dan ketahanannya terhadap gangguan. Semua alat bisa dijalankan ulang, berjalan di container dengan image yang di-pin tag + digest, dan hanya menyasar **stack dev dengan OLT dummy**. Hasil uji pertama ada di [report-2026-11-03.md](report-2026-11-03.md).

> Jangan arahkan alat ini ke produksi. Target dan skrip menolak berjalan bila `PROFILE` bukan `dev`, bila auth-bridge bukan `APP_ENV=development` + mode `jwt`, atau bila `dummy-olt` tidak berjalan.

## Ringkas

| Perintah (Linux/macOS/WSL) | Windows | Isi | Lama |
|---|---|---|---|
| `make test-security` | `.\make.ps1 test-security` | Probe otorisasi (±1.050 probe), review statis edge produksi, uji dinamis routing produksi | ±1 menit |
| `make scan-deps` | `.\make.ps1 scan-deps` (butuh Git Bash) | govulncheck, `npm audit --omit=dev`, osv-scanner, Trivy HIGH/CRITICAL | ±4 menit |
| `make load-test P=smoke` | `.\make.ps1 load-test -Load smoke` | Uji beban singkat 10 VU (cek alat) | ±1,5 menit |
| `make load-test P=step` | `.\make.ps1 load-test -Load step` | Bertahap 50 → 100 → 200 → 300 → 400 VU, berhenti otomatis bila error > 1% atau p95 realtime melonjak | ±20 menit |
| `make load-test P=spike` | `.\make.ps1 load-test -Load spike` | Lonjakan 0 → 300 VU dalam 10 detik (bel pembukaan) | ±3 menit |
| `make load-integration` | `.\make.ps1 load-integration` | API integrasi OLT: notify per `cust_id` dan siaran `stock_watchers` (kanal inbox saja) | ±4 menit |
| `make chaos-test` | `.\make.ps1 chaos-test` | 9 eksperimen gangguan di bawah beban ringan 30 VU | ±35 menit |
| `make loadtest-cleanup` | `.\make.ps1 loadtest-cleanup` | Hapus data uji `lt_*` (`DRY=1` / `-DryRun` untuk melihat dulu) | detik |

Prasyarat: stack dev berjalan dengan OLT dummy (`make up DUMMY_OLT=1`, Windows `.\make.ps1 up -DummyOlt`) dan `make smoke-cs` pernah dijalankan sekali (membuat agen uji `Smoke Agen` dan `Smoke Supervisor` yang dipakai probe otorisasi dan uji integrasi).

Hasil ditulis ke `tests/results/<jenis>-<waktu>/` (di-ignore git).

## Cara kerja

### Image `olt-social/testkit`

`tests/Dockerfile` membangun satu image berisi k6 2.2.0, `tokengen`, bash, curl, jq, openssl, psql 17, dan docker CLI. Container dijalankan di network `edge`, `app`, dan `data`, sehingga bisa memanggil Kong langsung, membaca Postgres/PgBouncer untuk metrik, dan, lewat `docker.sock`, mematikan atau memutus jaringan container untuk uji chaos. Secret yang di-mount hanya `anon_key`, `jwt_secret`, `postgres_password`, dan `olt_dev_signing_key`. Folder `docker/` di-mount read-only dan `docker/secrets` ditutup tmpfs.

### User uji `lt_*`

- `tokengen` (`tests/load/tokengen`, Go) menandatangani token sosial dev dengan kunci OLT dummy, sama seperti `dummy-olt`, untuk user `lt_00001`, `lt_00002`, dan seterusnya. Nilai `olt_user_id` mulai 9100001, jadi tidak bentrok dengan seed.
- Profil dibuat otomatis saat exchange di auth-bridge, persis seperti nasabah baru.
- Setiap user diberi IP sintetis `198.18.x.y` (RFC 2544) lewat `X-Forwarded-For`.
  - Kong hanya mempercayai header itu dari subnet `edge` ([compose.yml](../../docker/compose.yml), `KONG_TRUSTED_IPS`), sehingga batas per IP auth-bridge (30/menit) berlaku per user seperti di produksi.
  - Batas tidak dilonggarkan. Lewat Traefik, header yang sama dibuang (diuji di `test-security`).
- User uji tidak pernah mendaftarkan perangkat push. `load-test` juga menghentikan `notifier` selama uji dan menyalakannya lagi di akhir, jadi tidak ada push nyata.
- Pesan uji tidak berisi URL (tidak memicu link-preview) dan tidak menyebut user lain. Uji ini juga tidak membuat laporan.

### Skenario beban `tests/load/market-open.js`

Setiap VU adalah satu nasabah yang membuka aplikasi tepat setelah bel pembukaan:

1. Exchange token di `/bridge/v1/exchange`.
2. `get_client_config`, `get_feed` global, `get_trending`, `get_notification_unread_count`.
3. `join_stock_room('LTHOT')`, memantau saham (`stock_watchers`), `get_messages`, `mark_room_read`.
4. Membuka WebSocket Realtime dan join dua kanal seperti aplikasi:
   - `postgres_changes` tabel `messages` dengan filter `room_id`;
   - kanal privat `room:<id>` dengan presence.
5. Selama sesi, setiap VU:
   - mengirim pesan sekitar tiap `LOAD_MSG_EVERY` detik (default 20 ± 50%);
   - membaca feed saham dan jumlah notifikasi sekitar tiap 45 detik;
   - membaca `get_notifications` sekali;
   - membuat satu postingan bertanda `$LTPOST` (20% VU).

Untuk mengukur latensi pengiriman end-to-end, setiap pesan membawa cap waktu pengirim (base36). Penerima mencatat selisihnya dengan waktu terima di metrik `rt_delivery_ms`.

Postingan memakai kode `$LTPOST`, bukan `$LTHOT`. Deteksi manipulasi pasar (`cs.detect_manipulation`, tiap 5 menit) akan membuka alert dan slow mode 30 detik untuk kode yang mendadak ramai dari akun baru. Itu perilaku yang benar, tetapi bila kode yang sama dipakai untuk room uji, kapasitas chat ikut terhambat. Lihat laporan.

`run-load.sh` menjalankan langkah VU berurutan, masing-masing dengan token baru (TTL 14 menit), lalu:

- mengambil sampel `docker stats`, `pg_stat_activity`, dan PgBouncer `SHOW POOLS` tiap 5 detik ke `docker.csv`, `db.csv`, dan `pgbouncer.csv`;
- menulis ringkasan per langkah ke `steps.tsv`.

Env: `LOAD_STEPS`, `LOAD_HOLD`, `LOAD_RAMP`, `LOAD_MSG_EVERY`, `LOAD_FORCE=1` (jangan berhenti otomatis), dan `LOAD_VIA=traefik` (lewat Traefik, sehingga terkena batas per IP edge).

Bila batas perlu dinaikkan khusus untuk mengukur kapasitas, jangan ubah `docker/.env` atau compose utama. Pakai overlay opt-in [docker/compose.loadtest.yml](../../docker/compose.loadtest.yml). Saat ini overlay itu hanya menaikkan `TENANT_MAX_EVENTS_PER_SECOND` Realtime. Realtime men-seed ulang tenant dari env setiap start, jadi `UPDATE _realtime.tenants` tidak bertahan.

```bash
docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml \
  -f docker/compose.loadtest.yml --profile cs up -d --no-deps --wait realtime
make load-test P=step LOAD_STEPS="200 400" LOAD_FORCE=1
docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml \
  --profile cs up -d --no-deps --wait realtime    # kembali ke batas bawaan 1000
```

Laporan menandai dengan jelas langkah yang memakai overlay ini.

### Uji keamanan `tests/security/`

| Skrip | Isi |
|---|---|
| `authz-probe.sh` | Aktor: anon, nasabah (`joko_prasetyo`), agen CS tanpa izin (`Smoke Agen`), agen nonaktif, dan token palsu (secret salah, `alg: none`, kedaluwarsa, `role: supabase_admin`). Kontrol positif memastikan token uji benar-benar berlaku. Yang diuji ada di daftar di bawah tabel |
| `realtime-authz.js` | k6: penyerang join kanal privat `room:<DM orang lain>` (harus ditolak). `postgres_changes` dan broadcast room orang lain tidak boleh sampai. Juga memeriksa apakah anggota room bisa mengirim event server (lihat laporan) |
| `static-config.sh` | Router `prod.yml`/`cs.yml`: Host wajib, tanpa `/auth/v1`, `/pg`, `/graphql`, atau Studio. Juga TLS (versi, cipher, kurva, SNI), HSTS/CSP/nosniff, batas body, CORS dev vs prod, proxy tepercaya |
| `prod-routing.sh` | Traefik sementara (image yang sama) memuat `prod.yml` + `common.yml` di depan Kong dev. Memeriksa path publik vs 404, redirect HTTP, TLS 1.0/1.1 dan cipher lemah ditolak, header, 413, `%2F`, rate limit edge (429), dan batas 20 WebSocket per IP |
| `scan-deps.sh` | Dijalankan di host (bash). Image alat di-pin digest. `--strict` gagal bila ada temuan penghalang. `--third-party` ikut memindai image Supabase dan lainnya |

Yang diuji `authz-probe.sh`:

- skema yang tidak diekspos (`private`, `cs`, `auth`, `vault`, ...);
- data nasabah lain lewat REST dan RPC: DM, room support, room grup, notifikasi, draft, bookmark, watchlist, consent, blokir, laporan, profil mentah;
- tulis atas nama orang lain, dengan verifikasi di DB;
- semua RPC `public` khusus `service_role`;
- semua 208 fungsi `cs_api` dengan argumen null;
- Edge Function `cs-admin`;
- Storage: bucket `evidence`, `cs-documents`, lampiran room, signed URL, timpa/hapus avatar orang lain, buat/ubah bucket;
- API integrasi tanpa key, dengan key salah, anon key, atau tanpa apikey.

### Uji chaos `tests/chaos/chaos.sh`

Setiap eksperimen menyalakan beban ringan (30 VU) dan probe REST tiap detik, lalu memberi gangguan, mengukur waktu pulih, dan memulihkan layanan. `trap` di akhir menyalakan lagi apa pun yang masih mati.

| Eksperimen | Gangguan | Yang diperiksa |
|---|---|---|
| `classifier` | stop 150 dtk | Upload gambar ditolak (fail closed); alert sentinel muncul setelah 120 dtk lalu selesai |
| `realtime` | `kill -9` proses (restart policy) | Waktu pulih, klien putus lalu login dan join ulang, pesan yang dijawab 200 tetap tersimpan |
| `pgbouncer` | `kill -9` | Jendela error REST, waktu pulih |
| `valkey` | stop 30 dtk | Exchange auth-bridge (fail open ke limiter lokal), batas per IP lokal, `/readyz` degraded |
| `storage` | stop 30 dtk | Upload/unduh gagal jelas, REST tetap jalan |
| `notifier` | `kill -9` | Pulih otomatis; lease `push_queue` (uji SQL di transaksi yang di-rollback) |
| `rest` | `kill -9` | Waktu pulih |
| `db` | `docker restart` | Waktu pulih semua layanan; `migrate` tidak berjalan ulang (`olt_internal.schema_migrations`) |
| `partition` | `docker network disconnect` data ↔ rest 30 dtk | Waktu pulih setelah tersambung |

Pilih sebagian: `make chaos-test E="realtime valkey"` (Windows `-Experiments "realtime valkey"`).

`kill -9` dijalankan dari container `alpine` dengan `--pid=host`. Ini mensimulasikan crash sungguhan: `docker kill` dianggap stop manual dan tidak memicu restart policy.

## Setelah uji

1. `make loadtest-cleanup` menghapus profil `lt_*` (cascade ke postingan, pesan, notifikasi, keanggotaan, dan watchlist), room saham uji `LTHOT`/`LTPOST`/`PROBE`, DM/grup yang semua anggotanya `lt_*`, alert manipulasi dan agregat trending untuk kode uji, serta baris tanpa FK yang memuat id `lt_*`.
   - Tabel audit, bukti, dan log tidak disentuh.
   - Key integrasi uji `lt_loadtest` sudah dicabut dan dibiarkan sebagai jejak audit.
2. Periksa stack:
   - `docker ps`: semua healthy;
   - `make smoke-dummy`: 26/26. Bila kena rate limit per IP auth-bridge, tunggu satu menit;
   - `make test-db`.
