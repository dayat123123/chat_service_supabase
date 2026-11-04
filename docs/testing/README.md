# Uji keamanan, beban, dan chaos

Alat uji untuk Poin 14: sebelum produksi, sistem diuji keamanan, beban, dan ketahanannya terhadap gangguan. Semua alat bisa dijalankan ulang, berjalan di container dengan image yang di-pin tag + digest, dan hanya menyasar **stack dev dengan OLT dummy**. Hasil uji pertama ada di [report-2026-11-03.md](report-2026-11-03.md).

> Jangan arahkan alat ini ke produksi. Target dan skrip menolak berjalan bila `PROFILE` bukan `dev`, bila auth-bridge bukan `APP_ENV=development` + mode `jwt`, atau bila `dummy-olt` tidak berjalan.

## Ringkas

| Perintah (Linux/macOS/WSL) | Windows | Isi | Lama |
|---|---|---|---|
| `make test-security` | `.\make.ps1 test-security` | Probe otorisasi (±1.050 probe), review statis edge produksi, uji dinamis routing produksi | ±1 menit |
| `make test-zap` | `.\make.ps1 test-zap` | OWASP ZAP baseline pasif (opsional, image ±1,2 GB) ke web CS `:8085` dan API dev `:8000` | ±2 menit |
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

`tests/Dockerfile` membangun satu image berisi k6 2.2.0, `tokengen`, bash, curl, jq, openssl, psql 17, dan docker CLI. Container dijalankan di network `edge`, `app`, dan `data`, sehingga bisa memanggil Kong langsung, membaca Postgres/PgBouncer untuk metrik, dan, lewat `docker.sock`, mematikan atau memutus jaringan container untuk uji chaos. Secret yang di-mount hanya `anon_key`, `jwt_secret`, `postgres_password`, dan `olt_dev_signing_key`. Folder `docker/` di-mount read-only dan `docker/secrets` ditutup tmpfs. `lib/` repo library `rendezvous_community` (`../rendezvous_community` atau `PKG=<path>`, bila ada) di-mount read-only ke `/olt/client-lib` agar `static-config.sh` bisa mencocokkan allowlist `cs_api` publik dengan pemanggilan client.

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
4. Membuka WebSocket Realtime dan join kanal privat `room:<id>` seperti aplikasi:
   - pesan baru sebagai broadcast server `message` di kanal privat `room:<id>` (sejak `0098`, bukan lagi `postgres_changes`);
   - presence di kanal yang sama;
   - selama sesi: isi celah seperti aplikasi (`MessageGapFill` + `GapFillSchedule` di paket Flutter, sejak `0103`):
     - mulai dari **horizon**, yaitu `(created_at, id)` terbaru yang sudah dikonfirmasi server (halaman awal `get_messages` atau isi celah sebelumnya). Pesan Realtime tidak memajukan horizon;
     - overlap 10 dtk (`GAP_OVERLAP`), tetapi tidak lebih tua dari pesan terlama yang sudah dimuat;
     - jalur id: `get_message_ids(p_after, 1000)` sampai 5 halaman, lalu hanya id yang belum dikenal diambil lewat `get_messages_by_ids` per 100. Lebih dari 5 halaman atau lebih dari 500 id hilang: muat ulang halaman terbaru (`gap_too_long`). `GAP_IDS=0` memakai jalur lama `get_messages(p_after)` 5 × 100;
     - jadwal: sekali setelah join pertama, berkala tiap 45 dtk × acak 0,75–1,25 (`GAP_EVERY`), setelah sambung ulang dengan jeda acak 0–5 dtk (`RECONNECT_JITTER`), lalu sekali lagi 5–10 dtk sesudahnya (`GAP_RECHECK`), dan sekali di akhir sesi untuk pengukuran;
   - bila WebSocket putus: sambung ulang dengan backoff 1–8 detik, join ulang, lalu isi celah sesuai jadwal di atas (`RECONNECT=0` mematikan).
5. Selama sesi, setiap VU:
   - mengirim pesan sekitar tiap `LOAD_MSG_EVERY` detik (default 20 ± 50%);
   - membaca feed saham dan jumlah notifikasi sekitar tiap 45 detik;
   - membaca `get_notifications` sekali;
   - membuat satu postingan bertanda `$LTPOST` (20% VU).

Untuk mengukur latensi pengiriman end-to-end, setiap pesan membawa cap waktu pengirim (base36). Penerima mencatat selisihnya dengan waktu terima di metrik `rt_delivery_ms`.

Keterkiriman dihitung per sesi terhadap `count=exact` pesan room di jendela sesi (`rt_expected`):

- `rt_recv_window`: pesan unik yang sampai lewat Realtime;
- `rt_gap_only`: pesan yang hanya didapat dari isi celah.

Di `steps.tsv` keduanya menjadi kolom `rt_win_pct` dan `eventual_pct`. Akhir sesi disebar 0–10 detik (`END_SPREAD`) agar ratusan VU tidak menghitung serentak. Sesi yang hitungannya gagal tidak dihitung (`count_failed`).

Postingan memakai kode `$LTPOST`, bukan `$LTHOT`. Deteksi manipulasi pasar (`cs.detect_manipulation`, tiap 5 menit) akan membuka alert dan slow mode otomatis (paling ketat sama dengan jam ramai, 10 detik) untuk kode yang mendadak ramai dari akun baru. Itu perilaku yang benar, tetapi bila kode yang sama dipakai untuk room uji, kapasitas chat ikut terhambat. Lihat laporan.

`run-load.sh` menjalankan langkah VU berurutan, masing-masing dengan token baru (TTL 14 menit), lalu:

- mengambil sampel `docker stats`, `pg_stat_activity`, dan PgBouncer `SHOW POOLS` tiap 5 detik ke `docker.csv`, `db.csv`, dan `pgbouncer.csv`;
- mengambil sampel antrean pratinjau room (`private.room_preview_queue`), selisih `chat_rooms.last_message_at` dengan pesan terbaru room uji, dan `send_message` yang menunggu lock ke `preview.csv`;
- menulis ringkasan per langkah ke `steps.tsv`, termasuk p95 `get_message_ids`/`get_messages_by_ids`, jumlah isi celah, `gap_too_long`, dan respons `PGRST003` (504 pool PostgREST).

Env: `LOAD_STEPS`, `LOAD_HOLD`, `LOAD_RAMP`, `LOAD_MSG_EVERY`, `LOAD_FORCE=1` (jangan berhenti otomatis), dan `LOAD_VIA=traefik` (lewat Traefik, sehingga terkena batas per IP edge).

Typing, presence, dan daftar chat (`0106`/`0107`):

- `TYPING=1` meniru aplikasi:
  - `send_typing(true)` 1–3 dtk sebelum setiap `send_message`, lalu `send_typing(false)` sesudahnya.
  - Bawaannya 0, agar angka tetap sebanding dengan laporan 3 Nov.
- `PRESENCE=0` mematikan `track`. Join presence mengirim `enabled: true` seperti klien Dart.
- `LIST_VUS=n`: n VU pertama tidak join Realtime. Mereka hanya memoll `get_room_previews` seperti daftar chat yang terlihat.
  - Interval dari `poll_seconds` server, dijepit 5–300 dtk, × 0,75–1,25.
  - `LIST_POLL` hanya dipakai sebelum respons pertama.
- `realtime.tsv` per langkah:
  - `typing_rpc`, `typing_ev`/`typing_ev_s` (event `typing` yang diterima), `summary_ev` (`typing_summary`), `msg_ev_s`;
  - `presence_ev`/`presence_kb` (`presence_state`/`presence_diff`), `presence_denied` (reply `track` bukan `ok`);
  - `list_polls`/`list_fail`, p95 `get_room_previews` dan `send_typing`;
  - `rt_limit_logs` (baris log Realtime `MessagePerSecondRateLimitReached`/`too_many_requests` selama langkah).
- Perbandingan A/B tanpa migrasi ulang:
  - perilaku lama: `update private.settings set value = '1000000' where key in ('rooms.typing_aggregate_members', 'rooms.presence_stock_members')`;
  - kembalikan ke `50` dan `0` sesudahnya.

Bila batas perlu dinaikkan khusus untuk mengukur kapasitas, jangan ubah `docker/.env` atau compose utama. Pakai overlay opt-in [docker/compose.loadtest.yml](../../docker/compose.loadtest.yml). Saat ini overlay itu hanya menaikkan `TENANT_MAX_EVENTS_PER_SECOND` Realtime. Realtime men-seed ulang tenant dari env setiap start, jadi `UPDATE _realtime.tenants` tidak bertahan.

```bash
docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml \
  -f docker/compose.loadtest.yml --profile cs up -d --no-deps --wait realtime
make load-test P=step LOAD_STEPS="200 400" LOAD_FORCE=1
docker compose -f docker/compose.yml -f docker/compose.dev.yml -f docker/compose.dummy-olt.yml \
  --profile cs up -d --no-deps --wait realtime    # kembali ke batas bawaan (10000 sejak 0098)
```

Laporan menandai dengan jelas langkah yang memakai overlay ini.

### Uji keamanan `tests/security/`

| Skrip | Isi |
|---|---|
| `authz-probe.sh` | Aktor: anon, nasabah (`joko_prasetyo`), agen CS tanpa izin (`Smoke Agen`), agen nonaktif, dan token palsu (secret salah, `alg: none`, kedaluwarsa, `role: supabase_admin`). Kontrol positif memastikan token uji benar-benar berlaku. Yang diuji ada di daftar di bawah tabel |
| `realtime-authz.js` | k6: penyerang join kanal privat `room:<DM orang lain>` dan `user:<nasabah lain>` (harus ditolak). Anggota room mengirim event server palsu (`message`, `message_hidden`, `room_state`, `reaction`, `receipt`, `typing`) lewat WebSocket dan REST broadcast: tidak boleh sampai (T2, diperbaiki `0098`). Kontrol: pesan baru sampai lewat broadcast server, aktivitas di `user:<id>`, typing lewat RPC membawa identitas JWT, presence tetap jalan, `postgres_changes` `messages` tidak mengirim apa pun |
| `static-config.sh` | Router `prod.yml`/`cs.yml`: Host wajib, tanpa `/auth/v1`, `/functions/v1`, `/pg`, `/graphql`, atau Studio. API staf (T4): blok `cs_api` di domain publik, allowlist RPC nasabah = pemanggilan `cs_api` di `lib/` repo library `rendezvous_community`, header profil dibuang, penanda `X-Olt-Edge` di semua router REST/Realtime/Storage/media publik dan dibuang di semua router CS (0100, 0105), fungsi `hello` tidak ada. Batas per IP dan per user (T3). Juga TLS (versi, cipher, kurva, SNI), HSTS/CSP/nosniff, batas body, CORS dev vs prod, proxy tepercaya |
| `prod-routing.sh` | Traefik sementara (image yang sama) memuat `prod.yml` + `cs.yml` + `common.yml` di depan Kong dev (domain CS uji, `VPN_SOURCE_RANGES` = subnet edge). Memeriksa path publik vs 404, redirect HTTP, TLS 1.0/1.1 dan cipher lemah ditolak, header, 413, `%2F`, rate limit edge (429), batas WebSocket per IP (nilai uji 20), dan T4: RPC/tabel staf `cs_api` 403 dan `/functions/v1/*` 404 di domain publik, RPC chat CS nasabah tetap 200, JWT staf ditolak DB di domain publik (`cs_staff_public_edge`) tetapi bekerja lewat domain CS, `cs-admin` terjangkau di domain CS. Lanjutan T4 (0105): JWT staf tidak bisa upload, list, sign, atau hapus Storage dan upload lewat `/media/v1` di domain publik, tetapi upload/list/hapus lewat domain CS berhasil. Nasabah tetap memakai Storage publik. `realtime-edge.js` (k6, sebelum ws-limit): staf join `cs:queue` ditolak di domain publik (termasuk dengan header palsu) dan berhasil di domain CS, `postgres_changes` staf ditolak, topik `online` ditutup, nasabah tetap join `user:<id>` dan `postgres_changes` |
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
| `valkey` | stop 30 dtk | Exchange auth-bridge (fail open ke limiter lokal), batas lokal (exchange satu user dari satu IP sebanyak min(batas IP, batas user) + 5, dibaca dari env auth-bridge), `/readyz` degraded |
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
3. Jalankan E2E app example (`make e2e-windows`) **setelah** `loadtest-cleanup`. Ratusan postingan `$LTPOST` membuat postingan seed yang dicari `app_test` tidak terjangkau. `make test-db` sebaiknya dijalankan sebelum E2E, karena postingan E2E Budi memberi notifikasi `followed_post` ke pengikut seed yang dihitung tes 066 (laporan 10.9).
