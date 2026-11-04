# Kesehatan sistem dan alert

Super Admin memantau semua layanan dari web CS, menu **Kesehatan sistem** (`/system`). Alert dikirim ke Telegram dan email. Semua pengaturan dilakukan dari web, tanpa mengubah file di server.

Migrasi: `0064_system_health`. Layanan: [`services/sentinel`](../../services/sentinel/README.md).

## Cara kerja

```
sentinel ──(30 dtk) health_report: probe HTTP/TCP + disk──▶ database
media, backup, notifier ──(30 dtk) heartbeat──────────────▶ database
pg_cron ──(1 menit) private.health_evaluate()─────────────▶ masalah → alert → antrean kirim
sentinel ◀──(5 dtk) alert_claim / alert_report── kirim ke Telegram + email
web CS ◀── cs_api.system_health (Super Admin)
```

- **Aturan alert dihitung di database** (`private.health_current()`), bukan di sentinel. Hasilnya sama dilihat dari web, dari pg_cron, dan dari tes.
- **Sentinel** hanya mengumpulkan data (probe ke setiap layanan internal dan pemakaian disk) lalu mengirim pesan yang sudah disusun database. Bila laporan gagal terkirim (mis. API sibuk), sentinel 0.3.0 membawa hitungan laporan, sampel, dan probe yang hilang ke laporan berikutnya, sehingga celahnya ikut dinilai (`0108`).
- Evaluasi berjalan setiap kali sentinel melapor, dan juga setiap menit lewat pg_cron (`health-evaluate`). Jadi masalah tetap tercatat walau sentinel mati.

## Yang diperiksa

| Kunci | Tingkat | Kapan |
|---|---|---|
| `service:<nama>` | kritis | Layanan wajib (`health.expected_services`: media, sentinel, backup, notifier) tidak mengirim heartbeat selama 90 detik |
| `service:<nama>:status` | kritis/peringatan | Layanan melapor `error` atau `degraded` (mis. media tidak bisa menghubungi Storage, kunci Firebase ditolak) |
| `probe:<nama>` | kritis | Layanan internal tidak merespons probe sentinel (HTTP ≥ 500, timeout, atau koneksi TCP gagal) |
| `disk:<nama>` | peringatan ≥ 80 %, kritis ≥ 90 % | Volume database, storage, atau staging backup hampir penuh |
| `db:connections` | peringatan ≥ 80 %, kritis ≥ 90 % | Koneksi Postgres hampir habis |
| `db:slot:<nama>` | kritis | Slot replikasi hilang (`wal_status = lost`) |
| `db:slot:<nama>:retained` | peringatan | Slot tidak aktif menahan WAL lebih dari 256 MB |
| `db:long_transaction` | peringatan | Ada transaksi aktif lebih dari 15 menit |
| `cron:<job>` | peringatan | Jalannya terakhir job pg_cron gagal |
| `queue:push` | peringatan | Push menunggu lebih dari 10 menit padahal kunci Firebase terpasang |
| `queue:storage_cleanup` | peringatan | Folder gagal dibersihkan janitor 3 kali atau lebih |
| `alerts:delivery` | peringatan | Ada alert yang gagal dikirim dalam 24 jam |
| `backup:*` | lihat [docs/backup](../backup/README.md#alert) | Backup belum diatur, WAL berhenti, backup penuh terlambat, offsite tertunda, uji restore gagal |
| `backup:secret` | kritis | Rahasia backup di Vault tidak bisa dibuka (biasanya setelah restore ke server baru); isi ulang di tab Backup |
| `alerts:secret` | peringatan | Token Telegram atau password SMTP di Vault tidak bisa dibuka; isi ulang di tab Alert |
| `rest:pool` | peringatan ≥ 1 timeout, ≥ 1 request menunggu, atau ≥ 2 laporan/sampel `rest` hilang; kritis ≥ 20 timeout, atau sampel hilang saat probe `rest` gagal | Pool PostgREST penuh: timeout `PGRST003` (504) dalam 5 menit, atau request menunggu koneksi saat pool kosong (migrasi `0104`). Sejak `0108` juga saat laporan sentinel tidak terkirim ("API (PostgREST) tidak menjawab") |
| `realtime:events` | peringatan ≥ 70 %, kritis ≥ 90 % | Laju event Realtime 45 dtk terakhir (satu interval laporan) dibanding `max_events_per_second` tenant; di atas 100 % event dibuang |
| `pgbouncer:queue` | peringatan `cl_waiting` ≥ 1 atau `maxwait` ≥ 1 dtk, kritis `maxwait` ≥ 5 dtk | Klien PgBouncer mengantre koneksi server (`SHOW POOLS`) |
| `db:lock_waits` | peringatan ≥ 5 proses atau ≥ 5 dtk, kritis ≥ 20 proses atau ≥ 30 dtk | Proses database menunggu lock (`pg_locks`) |
| `queue:room_preview` | peringatan ≥ 60 dtk, kritis ≥ 300 dtk | Antrean pratinjau room (`0102`) tidak diproses: job `chat-room-preview` mati atau macet |
| `metrics:<sumber>` | peringatan | Sentinel gagal membaca sumber metrik (`METRICS_SOURCES`) pada laporan terakhir, atau ≥ 2 kali dalam 5 menit (termasuk di laporan yang tidak terkirim) |

Ambang dapat diubah tanpa deploy di `private.settings`: `health.alert_after_seconds` (default 120), `health.resolve_after_seconds` (60), `health.disk_warn_ratio` (0,8), `health.disk_critical_ratio` (0,9), `health.expected_services`. Ambang metrik kapasitas (`0104`): `health.rest_pool_timeouts_warn` (1), `health.rest_pool_timeouts_critical` (20), `health.rest_pool_waiting_warn` (1), `health.realtime_events_warn_ratio` (0,7), `health.realtime_events_critical_ratio` (0,9), `health.realtime_events_limit` (10.000, cadangan bila `_realtime.tenants` tidak terbaca), `health.pgbouncer_waiting_warn` (1), `health.pgbouncer_maxwait_warn_seconds` (1), `health.pgbouncer_maxwait_critical_seconds` (5), `health.lock_waiters_warn` (5), `health.lock_waiters_critical` (20), `health.lock_wait_warn_seconds` (5), `health.lock_wait_critical_seconds` (30), `health.room_preview_lag_warn_seconds` (60), `health.room_preview_lag_critical_seconds` (300). Latensi dan sampel hilang (`0108`): `health.alert_after_seconds.<kunci>` atau `.<prefiks>:*` (25 untuk `rest:pool`, `realtime:events`, `pgbouncer:queue`, `db:lock_waits`, `metrics:*`; tidak melebihi nilai global), `health.realtime_events_window_seconds` (45), `health.metrics_missed_warn` (2), `health.metrics_missed_window_seconds` (300), `health.rest_blind_warn` (2). Sumber metrik dan alasannya: [PRODUCTION.md](../PRODUCTION.md#alert-kapasitas-sentinel-030-migrasi-0104-0108).

## Siklus alert

1. Masalah muncul dan bertahan selama `health.alert_after_seconds` (120 dtk; kunci kapasitas 25 dtk, yaitu dua laporan sentinel berturut-turut) → alert **dibuka**, pesan dikirim ke setiap kanal yang aktif. Waktu buka yang tercatat adalah awal masalah.
2. Peringatan berubah menjadi kritis → pesan **memburuk**.
3. Masalah hilang selama `health.resolve_after_seconds` → alert **pulih**, pesan pulih dikirim beserta lama gangguan.
4. Super Admin bisa menekan **Tandai sudah ditangani**. Alert tetap terbuka sampai pulih, tetapi tidak lagi dihitung di lencana menu.

Riwayat alert dan pengiriman disimpan 90 hari (`health-purge`).

Contoh pesan:

```
🔴 KRITIS — Layanan Backup tidak aktif
Tidak ada heartbeat dalam 90 detik terakhir
Sejak: 3 Nov 2026 10:42 WIB
Buka: https://cs.perusahaan.co.id/system
```

## Mengatur kanal alert (web CS → Kesehatan sistem → Alert)

**Label dan alamat web CS.** Label muncul di subjek, mis. `[OLT Produksi]`. Alamat web CS dipakai untuk tautan "Buka" di setiap pesan.

**Telegram.**
1. Buat bot lewat [@BotFather](https://t.me/BotFather) (`/newbot`) dan salin tokennya.
2. Buat grup tim operasional, lalu tambahkan bot ke grup itu.
3. Cari chat ID grup, mis. dengan mengirim pesan di grup lalu membuka `https://api.telegram.org/bot<TOKEN>/getUpdates` dari komputer Anda. ID grup diawali `-100`.
4. Isi token dan chat ID (maksimal 5) di web, aktifkan, lalu simpan. Token disimpan terenkripsi di Vault dan tidak bisa dilihat lagi.
5. Tekan **Kirim uji** dan pastikan pesan masuk ke grup.

**Email.** Isi host SMTP, port, keamanan (`starttls` untuk 587, `tls` untuk 465), username, password, alamat pengirim, dan maksimal 10 penerima. Password disimpan terenkripsi di Vault. Kosongkan kolom password untuk mempertahankan password lama.

Setiap perubahan tercatat di **Kepatuhan → Jejak Audit** (`alerts.*`) tanpa token atau password. Pesan uji dibatasi satu per 20 detik per kanal.

## Bila database atau API mati

Database tidak bisa mengevaluasi apa pun saat ia sendiri mati. Untuk kasus ini sentinel menyimpan konfigurasi kanal terakhir di memori. Bila semua panggilan ke API gagal selama 2 menit (`DB_DOWN_AFTER`), sentinel langsung mengirim "API/database tidak bisa dihubungi". Saat pulih, sentinel mengirim "API/database pulih" beserta lama gangguan.

Bila **seluruh server** mati, tidak ada yang bisa mengirim alert dari dalam server. Pasang pemantau dari luar, misalnya Uptime Kuma (MIT) di server lain atau layanan uptime pihak ketiga, yang memeriksa `https://<domain>/bridge/v1/health` (header `apikey`) dan halaman web CS.

## Pemecahan masalah

| Gejala | Periksa |
|---|---|
| Halaman menampilkan "belum ada data dari pemantau" | Sentinel tidak berjalan: `make ps`, lalu `make logs s=sentinel` |
| Alert tidak sampai ke Telegram | Status kiriman terakhir di tab Alert. "chat not found" berarti bot belum ada di grup atau chat ID salah |
| Email ditolak | Error SMTP tampil di tab Alert. 535 berarti username/password salah; 550 berarti alamat pengirim tidak diizinkan server SMTP |
| Alert `cron:*` | Cek `select * from cron.job_run_details order by start_time desc limit 20;` |
| `db:slot:olt_backup:retained` | Layanan backup mati atau streaming WAL berhenti. Lihat tab Backup |
