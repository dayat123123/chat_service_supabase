# notifier

Pengirim push notification. Notifier mengambil (claim) antrean push dari Postgres lewat RPC PostgREST `push_claim`, mengirimnya ke Firebase Cloud Messaging (FCM HTTP v1), lalu melaporkan hasil semua pesan sekaligus lewat `push_report`. Setiap 30 detik, dan juga langsung saat start, saat kunci Firebase berubah, atau saat status error berubah, notifier mengirim `push_heartbeat` beserta revisi kunci yang sedang dipakai. Dari heartbeat inilah web CS menampilkan status push. Notifier hanya memakai standard library Go dan tidak membutuhkan SDK Firebase.

Antrean, backoff per pesan, batas percobaan, penghapusan perangkat yang tokennya mati, dan penyimpanan kunci Firebase diatur oleh database (migrasi `0058_push_notifications.sql` dan `0059_push_credentials.sql`). Notifier hanya mengirim pesan dan memberi label hasilnya. Pengiriman bersifat *at-least-once*: jika notifier mati di tengah batch, baris yang sedang dikunci kembali ke antrean setelah masa `LEASE` habis.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | HTTP internal (`/healthz`, `/readyz`, `/metrics`), tidak untuk publik |
| `LOG_LEVEL` | `info` | `debug` mencatat juga pesan yang di-retry atau tokennya tidak berlaku |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter. Dipakai membuat token `service_role` 1 menit untuk RPC |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `INSTANCE_ID` | hostname | Nama instance di heartbeat dan kunci claim (maks. 100 karakter) |
| `CREDENTIALS_RELOAD` | `5s` | Interval cek revisi kunci Firebase di database (1s–10m) |
| `OAUTH_TOKEN_URL` | `https://oauth2.googleapis.com/token` | Endpoint token Google. `token_uri` di file kunci diabaikan |
| `FCM_BASE_URL` | `https://fcm.googleapis.com` | |
| `ANDROID_CHANNEL_ID` | kosong | `android.notification.channel_id`. Kosong = tidak dikirim |
| `BATCH_SIZE` | `100` | Jumlah pesan per claim (1–500) |
| `CONCURRENCY` | `20` | Jumlah pengiriman paralel ke FCM (1–200) |
| `LEASE` | `60s` | Lama baris dikunci per claim (10s–10m, minimal `SEND_TIMEOUT` + 5s) |
| `POLL_INTERVAL` | `1s` | Jeda claim saat antrean tidak penuh (100ms–30s). Batch penuh langsung di-claim lagi |
| `HEARTBEAT_INTERVAL` | `30s` | 5s–60s. Web CS menganggap notifier offline setelah 90 detik tanpa heartbeat |
| `SEND_TIMEOUT` | `10s` | Batas waktu per request ke FCM dan endpoint token Google (1s–60s) |
| `SHUTDOWN_TIMEOUT` | `20s` | Waktu menyelesaikan batch yang sedang jalan saat SIGTERM (1s–5m) |

Notifier berhenti mengambil pesan baru dalam satu batch jika batas `LEASE` hampir habis. Pesan yang belum sempat dikirim dilepas lagi ke antrean (`release`), supaya instance lain tidak mengirim pesan yang sama dua kali.

## Kunci Firebase

Super Admin mengunggah file JSON kunci akun layanan di web CS (**Pengaturan → Push notification**). Database menyimpannya terenkripsi di Supabase Vault bersama nomor revisi. Panduan operasional dan integrasi aplikasi: [docs/push](../../docs/push/README.md).

- Setiap `CREDENTIALS_RELOAD` notifier memanggil RPC `push_credentials(p_revision)` dengan revisi yang sedang dipakai. Bila revisinya sama, database hanya menjawab `unchanged` tanpa mengirim kunci. Bila berubah, kunci baru dimuat tanpa restart, token akses lama dibuang, dan status error serta jeda kirim di-reset.
- Kunci yang baru dimuat langsung **diperiksa**: notifier mengambil token OAuth2 (assertion JWT RS256, `scope` `firebase.messaging`), lalu mengirim pesan `validate_only` ke FCM dengan token perangkat palsu. Balasan "token tidak valid" berarti kunci, izin, dan API FCM beres. Kunci yang dicabut (`invalid_grant`), API FCM yang belum aktif (403), atau project yang salah (404) langsung tampil sebagai error di web CS sebelum ada push yang dikirim.
- Kunci dihapus dari web → notifier melepas kunci dan berhenti mengambil antrean (`configured=false`).
- Kunci yang tidak bisa dibuka (misalnya database dipulihkan ke server tanpa kunci enkripsi Vault) → status error "Kredensial Firebase tersimpan tidak bisa dibuka". Unggah ulang dari web.
- Database tidak bisa dihubungi saat cek revisi → notifier tetap memakai kunci terakhir dan mencoba lagi di interval berikutnya. Error ini dicatat sekali di log, bukan setiap interval.

Kunci, token akses, dan isi kunci tidak pernah ditulis ke log. Token perangkat di log hanya ditampilkan 6 karakter terakhirnya. Token akses disimpan di cache sampai 5 menit sebelum kedaluwarsa.

## Status di web CS

Web CS hanya membaca heartbeat 90 detik terakhir:

| Status | Kondisi |
|---|---|
| offline | Tidak ada heartbeat |
| belum dikonfigurasi | `configured=false` |
| aktif | `configured=true` dan tanpa error |
| error | `configured=true` dan ada error (kunci salah atau dicabut, Firebase menolak akses, Google atau FCM tidak bisa dihubungi, APNs/Web Push ditolak, token dari project lain) |

Web CS membandingkan `credentials_revision` di heartbeat dengan revisi kunci terbaru untuk menampilkan "sedang memuat kunci".

Gangguan sistemik ditangani begini: token ditolak Google, 401 berulang, 403/404 dari FCM, atau jaringan/timeout ke FCM. Sisa batch dilepas (`release`, percobaan tidak dihitung), heartbeat error langsung dikirim, dan claim dijeda 15 detik. Jeda berlipat ganda sampai maksimal 5 menit. Setelah jeda habis, notifier memeriksa ulang kunci dengan pesan `validate_only` walaupun antrean kosong, jadi status kembali aktif tanpa menunggu ada push. Error juga hilang setelah ada pengiriman yang berhasil. Peringatan yang tidak bisa diperiksa dengan cara itu (APNs/Web Push, token dari project lain) baru hilang setelah satu batch terkirim tanpa masalah.

Pemetaan hasil FCM per pesan:

| Hasil | Kondisi |
|---|---|
| `sent` | 2xx |
| `invalid` | `UNREGISTERED`, `INVALID_ARGUMENT` tentang registration token. Database menghapus perangkatnya |
| `failed` | `INVALID_ARGUMENT` lain (payload salah), `THIRD_PARTY_AUTH_ERROR` dan `SENDER_ID_MISMATCH` (keduanya juga memasang error status; perangkat tidak dihapus karena penyebabnya biasanya kunci dari project yang salah) |
| `retry` | `QUOTA_EXCEEDED`/429, `UNAVAILABLE`/503, `INTERNAL`/500, 5xx lain. Header `Retry-After` dipatuhi |
| `release` | Gangguan sistemik, shutdown, atau `LEASE` hampir habis |

## Endpoint dan metrik

`GET /healthz` (liveness), `GET /readyz` (200 jika PostgREST terjangkau, 503 jika tidak), `GET /metrics` (format teks Prometheus), dan subcommand `notifier healthcheck` untuk image distroless.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `notifier_push_total{outcome}` | counter | `sent`, `retry`, `invalid`, `failed`, `release` |
| `notifier_claim_batches_total` | counter | Claim yang menghasilkan minimal satu pesan |
| `notifier_queue_depth` | gauge | Panjang antrean menurut heartbeat terakhir |
| `notifier_configured` | gauge | 1 jika kunci Firebase sudah diunggah |
| `notifier_healthy` | gauge | 1 jika terkonfigurasi dan tanpa error |

Saat SIGTERM, notifier berhenti claim dan menyelesaikan batch yang sedang jalan dalam batas `SHUTDOWN_TIMEOUT`, melaporkan hasilnya, lalu keluar dengan kode 0. Atur `stop_grace_period` container agar lebih panjang dari `SHUTDOWN_TIMEOUT` (misalnya 30s).

Tes: `go test ./...`.
