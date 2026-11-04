# sentinel

Pemantau sistem dan pengirim alert. Sentinel memeriksa layanan internal (HTTP/TCP), sisa ruang disk, dan metrik kapasitas (pool PostgREST, laju event Realtime, antrean PgBouncer), lalu melaporkannya ke database lewat RPC PostgREST `health_report`. Aturan alert dihitung di database (migrasi `0064_system_health.sql`). Sentinel tidak memutuskan apa pun: ia hanya mengumpulkan data, lalu mengirim pesan yang sudah disusun database ke Telegram dan email. Satu-satunya pengecualian: saat API/database sendiri tidak bisa dihubungi, sentinel mengirim alert sendiri lewat kanal terakhir yang tersimpan di memori. Sentinel hanya memakai standard library Go.

## Alur

1. **Laporan kesehatan** (setiap `REPORT_INTERVAL`, pertama kali langsung saat start): semua probe dan sumber metrik dijalankan paralel, disk diukur dengan `statfs`, lalu dikirim lewat `health_report(p_instance, p_version, p_started_at, p_probes, p_disks, p_metrics)` (`p_metrics` hanya dikirim bila `METRICS_SOURCES` terisi; migrasi `0104`). Database mencatat heartbeat `sentinel`, menyimpan hasil probe dan disk, lalu langsung mengevaluasi aturan alert.
   - Bila laporan gagal terkirim, putaran itu dibawa ke laporan berikutnya (0.3.0, migrasi `0108`): setiap probe dan sumber metrik membawa `missed` (jumlah kegagalannya di laporan yang hilang), dan sumber sintetis `sentinel` membawa `sentinel_reports_lost`. Hitungan direset setelah satu laporan terkirim. Dengan begitu `rest:pool` dan `metrics:<sumber>` tetap terbuka walau laporan hilang tepat saat PostgREST runtuh.
2. **Kanal alert** (setiap `ALERT_POLL`): `alert_channels(p_revision)` dipanggil dengan revisi yang sedang dipakai. Bila sama, database hanya menjawab `unchanged` tanpa mengirim token atau password. Bila berubah, kanal di memori diganti tanpa restart dan dicatat sekali di log (jumlah chat, host SMTP, jumlah penerima; tanpa token/password).
3. **Pengiriman** (setelah cek kanal, di putaran yang sama): `alert_claim(p_instance, p_limit, p_lease_seconds)` mengambil maksimal `BATCH_SIZE` pesan. Telegram dan email dikirim bersamaan (masing-masing berurutan), lalu semua hasil dilaporkan sekaligus lewat `alert_report`. Bila claim penuh, sentinel langsung claim lagi. Laporan yang gagal dicoba lagi setelah 250 ms, 500 ms, dan 1 detik. Bila tetap gagal, pesan kembali ke antrean setelah lease habis.
4. **Database tidak bisa dihubungi**: lihat bagian di bawah.

Pengiriman bersifat *at-least-once*. Sentinel tidak memulai kiriman baru setelah `waktu claim + LEASE − max(SMTP_TIMEOUT, REQUEST_TIMEOUT) − 3 detik`. Pesan yang belum sempat dikirim dilaporkan `retry` dengan error "Belum sempat dikirim, dijadwalkan ulang".

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | HTTP internal (`/livez`, `/readyz`, `/metrics`), tidak untuk publik |
| `LOG_LEVEL` | `info` | |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter. Dipakai membuat token `service_role` 1 menit untuk RPC |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | Langsung ke container PostgREST, tanpa Kong |
| `INSTANCE_ID` | hostname + akhiran acak | Nama instance di heartbeat dan kunci claim (maks. 100 karakter). Berganti setiap start |
| `PROBES` | kosong | Daftar probe, lihat di bawah |
| `PROBES_EXTRA` | kosong | Probe tambahan yang digabung ke `PROBES`. Dipakai overlay compose profil CS (web CS, gateway nasabah) agar server tanpa CS tidak memunculkan alert palsu |
| `DISKS` | kosong | Daftar disk, lihat di bawah |
| `METRICS_SOURCES` | kosong | Sumber metrik kapasitas, lihat [Metrik kapasitas](#metrik-kapasitas) |
| `PGBOUNCER_STATS_PASSWORD` / `PGBOUNCER_STATS_PASSWORD_FILE` | wajib bila ada sumber `pgbouncer://` | Password user konsol admin PgBouncer (`olt_stats`) |
| `REPORT_INTERVAL` | `30s` | Jeda antar laporan kesehatan (5s–10m) |
| `PROBE_TIMEOUT` | `5s` | Batas waktu per probe (1s–60s, harus lebih pendek dari `REPORT_INTERVAL`) |
| `ALERT_POLL` | `5s` | Jeda cek revisi kanal dan claim alert (1s–5m) |
| `DB_DOWN_AFTER` | `2m` | Lama semua panggilan RPC gagal sebelum sentinel mengirim alert sendiri (30s–1h, minimal 2 × `ALERT_POLL`) |
| `TELEGRAM_API_URL` | `https://api.telegram.org` | Diganti hanya untuk tes |
| `SMTP_TIMEOUT` | `20s` | Batas waktu satu percakapan SMTP dari sambungan sampai QUIT (1s–5m) |
| `REQUEST_TIMEOUT` | `10s` | Batas waktu per request ke PostgREST dan Telegram (1s–60s) |
| `BATCH_SIZE` | `20` | Jumlah alert per claim (1–100) |
| `LEASE` | `60s` | Lama pesan dikunci per claim (10s–10m, minimal `SMTP_TIMEOUT` dan `REQUEST_TIMEOUT` + 10s) |
| `SHUTDOWN_TIMEOUT` | `20s` | Waktu menyelesaikan kiriman yang sedang jalan saat SIGTERM (1s–5m) |

## Probe dan disk

`PROBES` berisi pasangan `nama=url` dipisah koma. Nama huruf kecil, angka, `.`, `_`, `-` (maks. 60 karakter, sama dengan aturan di database). Maksimal 100 probe.

| Bentuk | Pemeriksaan | Dianggap hidup |
|---|---|---|
| `http://host:port/path`, `https://...` | `GET` tanpa mengikuti redirect, koneksi baru setiap kali (tanpa keep-alive) | Ada respons dengan status < 500. 401, 404, dan 3xx dihitung hidup |
| `tcp://host:port` | Membuka koneksi TCP lalu menutupnya | Koneksi berhasil. `status` dikirim `null` |

URL dengan username/password ditolak saat start. `latency_ms` adalah waktu sampai header respons (HTTP) atau sampai koneksi terbuka (TCP). Error dikirim singkat dalam Bahasa Indonesia: `HTTP 503`, `waktu habis setelah 5s`, `koneksi ditolak`, `koneksi diputus`, `nama host tidak ditemukan`, atau `gagal: ...`.

Contoh daftar untuk stack ini (nama sama dengan label di database):

```
storage=http://storage:5000/status,auth=http://auth:9999/health,rest=http://rest:3000/,
realtime=http://realtime:4000/healthcheck,functions=http://functions:9000/,imgproxy=http://imgproxy:5001/health,
kong=http://kong:8000/,auth-bridge=http://auth-bridge:9100/livez,notifier=http://notifier:8080/healthz,
janitor=http://janitor:8080/healthz,nasabah-gateway=http://nasabah-gateway:8080/healthz,
cs-console=http://cs-console:8080/healthz,media=http://media:9100/livez,backup=http://backup:8080/livez,
db=tcp://db:5432,pgbouncer=tcp://pgbouncer:6432,valkey=tcp://valkey:6379
```

`DISKS` berisi pasangan `nama=/path` dipisah koma (nama maks. 40 karakter, maksimal 20 disk). Path adalah titik mount di dalam container sentinel; volume dipasang read-only, misalnya `db-data:/mnt/disks/db:ro`. Yang dikirim hanya `total_bytes`, `free_bytes` (termasuk cadangan root), dan `avail_bytes` (yang bisa dipakai proses non-root); path tidak dikirim. Disk yang gagal diukur tidak ikut dilaporkan (supaya tidak terbaca sebagai disk penuh) dan dicatat sekali di log. Volume Docker yang berada di filesystem yang sama melaporkan angka yang sama. Pengukuran hanya tersedia di Linux.

## Metrik kapasitas

`METRICS_SOURCES` berisi pasangan `nama=url` dipisah koma (aturan nama sama dengan probe, maksimal 20). Nama dipakai sebagai label di database (`rest`, `realtime`, `pgbouncer`).

| Bentuk | Dibaca |
|---|---|
| `http://host:port/path`, `https://...` | Teks Prometheus. Hanya family yang dipakai aturan alert yang dikirim (dijumlah lintas label): `pgrst_db_pool_timeouts_total`, `pgrst_db_pool_waiting`, `pgrst_db_pool_available`, `pgrst_db_pool_max`, `realtime_channel_global_events`, `realtime_connections_global_connected` |
| `jwt+http://...`, `jwt+https://...` | Sama, dengan header `Authorization: Bearer` token `service_role` 1 menit yang ditandatangani `JWT_SECRET` (Realtime memverifikasinya dengan `METRICS_JWT_SECRET`, di compose sama dengan `jwt_secret`) |
| `pgbouncer://user@host:port` | Konsol admin PgBouncer (database `pgbouncer`), `SHOW POOLS`. Protokol Postgres ditulis sendiri dengan standard library: autentikasi SCRAM-SHA-256 (tanda tangan server diverifikasi) atau md5. User bawaan `olt_stats`. Dikirim: `pgbouncer_cl_active`, `pgbouncer_cl_waiting`, `pgbouncer_sv_active`, `pgbouncer_sv_idle` (jumlah semua pool), `pgbouncer_maxwait_seconds` (terlama), `pgbouncer_pools`; pool konsol `pgbouncer` diabaikan |

URL dengan password ditolak saat start. Nama host di-resolve setiap putaran dan **setiap alamat dibaca terpisah** (`instance` = IP), jadi `tasks.rest` di Swarm membaca tiap replika, bukan VIP yang bergantian. Batas waktu per sumber `PROBE_TIMEOUT`. Hasil per sumber: `{"source","instance","ok","error","values":{...}}`. Kegagalan dicatat sekali per perubahan keadaan di log dan menjadi alert `metrics:<sumber>` di database. Aturan alert dan ambangnya: [docs/system-health](../../docs/system-health/README.md#yang-diperiksa).

Contoh stack ini (default `docker/compose.yml`):

```
rest=http://rest:3001/metrics,realtime=jwt+http://realtime:4000/metrics,pgbouncer=pgbouncer://olt_stats@pgbouncer:6432
```

## Telegram

`POST {TELEGRAM_API_URL}/bot{token}/sendMessage` dengan JSON `{"chat_id","text","disable_web_page_preview":true}`, teks biasa tanpa `parse_mode`, dipotong ke 4096 karakter (UTF-16) bila lebih panjang. Satu alert dikirim ke setiap chat id dan dianggap berhasil bila semua chat id menerima. Chat id yang sudah menerima dicatat di memori (24 jam), jadi saat alert dicoba ulang, chat itu tidak menerima pesan ganda.

| Balasan | Hasil |
|---|---|
| 2xx `ok:true` | Terkirim |
| 429 | `retry`. Pengiriman Telegram berikutnya ditahan sampai `parameters.retry_after` (atau header `Retry-After`, minimal 1 detik). Alert berikutnya di batch yang sama menunggu bila jeda selesai sebelum batas lease, kalau tidak langsung dilaporkan `retry` |
| 5xx, jaringan, timeout | `retry` |
| 401, 404, format token salah | `retry` (token bot salah; setelah diperbaiki di web, alert yang tersisa ikut terkirim) |
| 400 dengan `migrate_to_chat_id` | Grup sudah menjadi supergroup: dikirim ulang ke chat id baru dan chat id baru dipakai sampai kanal diubah. Peringatan dicatat sekali di log |
| 400, 403, 4xx lain | Gagal permanen untuk chat itu (`retry:false`). Chat lain tetap dikirimi |

URL Telegram memuat token, jadi error jaringan tidak pernah menampilkan URL; token juga dihapus dari teks error yang dikembalikan Telegram.

## Email

`net/smtp`, satu email ke semua penerima `to` (header `To` berisi semua alamat). `security`:

| Nilai | Perilaku |
|---|---|
| `tls` | TLS langsung sejak sambungan (biasanya port 465) |
| `starttls` | Sambungan biasa lalu wajib `STARTTLS`; bila server tidak menawarkannya, pengiriman gagal permanen |
| `none` | Tanpa enkripsi, khusus dev. Username tidak boleh diisi: password tidak pernah dikirim tanpa TLS |

Sertifikat server diverifikasi (TLS 1.2+). Bila `username` terisi, sentinel login dengan `AUTH PLAIN` (server harus menawarkan `AUTH`). EHLO memakai domain alamat pengirim. Header: `From`, `To`, `Subject` (RFC 2047 UTF-8, dilipat bila panjang), `Date`, `Message-ID` (`<acak@domain-pengirim>`), `MIME-Version`, `Content-Type: text/plain; charset=utf-8`, `Content-Transfer-Encoding: quoted-printable`, `Auto-Submitted: auto-generated`. Bila `subject` kosong, baris pertama teks dipakai.

| Kegagalan | Hasil |
|---|---|
| Balasan SMTP 4xx (greylisting, kuota, login sementara gagal) | `retry` |
| Jaringan, timeout, putus di tengah | `retry` |
| Balasan SMTP 5xx (login ditolak, pengirim/penerima ditolak, pesan ditolak) | Gagal permanen |
| Sertifikat TLS tidak valid, STARTTLS/AUTH tidak ditawarkan, konfigurasi salah | Gagal permanen |

Satu penerima yang ditolak membatalkan seluruh email (tidak ada yang terkirim), supaya percobaan ulang tidak mengirim ganda. Password (dan bentuk base64 kredensial `AUTH PLAIN`) dihapus dari teks error.

Batas percobaan dan jeda ulang diatur database: `retry` dijadwalkan ulang 30 detik × 2^(percobaan−1) sampai maksimal 1 jam, paling banyak 8 percobaan, dan pesan yang menunggu lebih dari 6 jam dianggap gagal.

## Saat API/database tidak bisa dihubungi

Setiap panggilan RPC (`health_report`, `alert_channels`, `alert_claim`, `alert_report`) dicatat. Yang dihitung gagal hanya error jaringan, timeout, dan status 5xx (PostgREST menjawab 503 bila database mati). Status 4xx berarti API masih menjawab, jadi tidak dihitung. Satu panggilan yang berhasil mengakhiri hitungan.

- Bila semua panggilan gagal terus selama `DB_DOWN_AFTER` sejak kegagalan pertama, sentinel mengirim **sekali** pesan "API/database tidak bisa dihubungi" ke kanal terakhir di memori (Telegram dan/atau email). Isinya: waktu mulai (WIB), nama instance, error terakhir, dan probe yang sedang gagal.
- Pada panggilan pertama yang berhasil sesudahnya, sentinel mengirim **sekali** "API/database pulih" dengan waktu mulai, waktu pulih, dan lama gangguan.
- Bila belum ada kanal di memori (misalnya sentinel start saat database mati), kejadian hanya dicatat di log dan pesan pulih juga tidak dikirim.
- Kegagalan sementara saat mengirim pesan ini dicoba lagi setiap `ALERT_POLL` tanpa mengirim ganda ke chat yang sudah menerima. Pesan "tidak bisa dihubungi" yang belum terkirim dibuang saat database pulih (pesan pulih sudah memuat waktu mulainya). Pesan pulih dicoba paling lama 1 jam.
- Selama database tidak bisa dihubungi, sentinel tetap memakai kanal di memori dan tidak mencoba claim.

## Endpoint dan metrik

`GET /livez` (liveness), `GET /readyz` (200 jika PostgREST terjangkau, 503 jika tidak), `GET /metrics` (format teks Prometheus), dan subcommand `sentinel healthcheck` untuk image distroless.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `sentinel_probe_up{probe}` | gauge | 1 bila probe terakhir berhasil |
| `sentinel_probe_latency_seconds{probe}` | gauge | Durasi probe terakhir |
| `sentinel_disk_total_bytes{disk}`, `sentinel_disk_free_bytes{disk}`, `sentinel_disk_avail_bytes{disk}` | gauge | Hasil `statfs` terakhir |
| `sentinel_scrape_up{source,instance}` | gauge | 1 bila pembacaan terakhir sumber metrik berhasil |
| `sentinel_health_reports_total{outcome}` | counter | `ok`, `failed` |
| `sentinel_last_report_timestamp_seconds` | gauge | Waktu Unix laporan terakhir yang diterima (0 jika belum ada) |
| `sentinel_alerts_total{channel,outcome}` | counter | `telegram`/`email`/`other` × `sent`/`retry`/`failed` |
| `sentinel_direct_alerts_total{outcome}` | counter | Pesan langsung saat database tidak bisa dihubungi, per kanal: `sent`, `failed` |
| `sentinel_channels_revision` | gauge | Revisi kanal di memori (−1 sebelum dimuat) |
| `sentinel_channel_configured{channel}` | gauge | 1 bila kanal aktif |
| `sentinel_database_reachable` | gauge | 1 bila panggilan RPC terakhir sampai ke API |
| `sentinel_database_down` | gauge | 1 selama gangguan API/database sudah diumumkan |
| `sentinel_database_outages_total` | counter | Jumlah gangguan sejak start |

Log berformat JSON. Probe yang mati/hidup kembali, disk yang gagal diukur, dan error RPC dicatat sekali per perubahan keadaan, bukan setiap interval. Token bot, password SMTP, dan isi pesan tidak pernah ditulis ke log.

Saat SIGTERM, sentinel berhenti mengambil alert baru, menyelesaikan kiriman yang sedang jalan dalam batas `SHUTDOWN_TIMEOUT`, melaporkan hasilnya, lalu keluar dengan kode 0. Atur `stop_grace_period` container agar lebih panjang dari `SHUTDOWN_TIMEOUT` (misalnya 30s).

Tes: `go test ./...` (pengukuran disk sungguhan hanya diuji di Linux; jalankan juga `go test -race ./...` di container Linux).
