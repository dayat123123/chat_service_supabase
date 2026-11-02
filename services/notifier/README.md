# notifier

Pengirim push notification. Notifier mengambil (claim) antrean push dari Postgres lewat RPC PostgREST `push_claim`, mengirimnya ke Firebase Cloud Messaging (FCM HTTP v1), lalu melaporkan hasil semua pesan sekaligus lewat `push_report`. Setiap 30 detik, dan juga langsung saat start, saat kredensial berubah, atau saat status error berubah, notifier mengirim `push_heartbeat`. Dari heartbeat inilah web CS menampilkan status push. Notifier hanya memakai standard library Go dan tidak membutuhkan SDK Firebase.

Antrean, backoff per pesan, batas percobaan, dan penghapusan perangkat yang tokennya mati diatur oleh database (migrasi `0058_push_notifications.sql`). Notifier hanya mengirim pesan dan memberi label hasilnya. Pengiriman bersifat *at-least-once*: jika notifier mati di tengah batch, baris yang sedang dikunci kembali ke antrean setelah masa `LEASE` habis.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | HTTP internal (`/healthz`, `/readyz`, `/metrics`), tidak untuk publik |
| `LOG_LEVEL` | `info` | `debug` mencatat juga pesan yang di-retry atau tokennya tidak berlaku |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter. Dipakai membuat token `service_role` 1 menit untuk RPC |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `INSTANCE_ID` | hostname | Nama instance di heartbeat dan kunci claim (maks. 100 karakter) |
| `FIREBASE_CREDENTIALS` | `/run/firebase` | File atau folder kredensial akun layanan Firebase (lihat di bawah) |
| `CREDENTIALS_RELOAD` | `30s` | Interval cek ulang file kredensial (1s–10m) |
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

## Kredensial Firebase

Di stack compose, foldernya `docker/secrets/firebase/` (di-mount read-only ke `/run/firebase`); di profil cluster, Docker secret `firebase_service_account`. Panduan operasional dan integrasi aplikasi: [docs/push](../../docs/push/README.md).

Taruh **satu** file JSON kunci akun layanan di folder yang di-mount ke `FIREBASE_CREDENTIALS`. Notifier tidak perlu di-restart. Dalam `CREDENTIALS_RELOAD` (30 detik) file itu terbaca dan heartbeat langsung dikirim. Cara mendapatkan file: Firebase Console → Project settings → Service accounts → *Generate new private key*.

- **Folder**: notifier memakai satu-satunya file `*.json` di folder itu. File berawalan titik, file selain `.json`, subfolder, dan file kosong diabaikan.
- **File**: `FIREBASE_CREDENTIALS` juga boleh langsung menunjuk ke file, misalnya Docker secret.
- **Belum dikonfigurasi**: path tidak ada, folder tidak berisi `.json`, atau file kosong/hanya spasi (placeholder secret). Status `configured=false`, tanpa error.
- **Error kredensial**: ada lebih dari satu `.json`, file tidak bisa dibaca, atau isinya bukan akun layanan (`type` harus `service_account`, wajib ada `project_id`, `client_email`, `private_key` RSA PEM PKCS#8/PKCS#1). Status `configured=true` dan pesan error tampil di web CS.
- File diganti atau dihapus (path, ukuran, atau waktu ubah berubah) → kredensial dimuat ulang, token akses lama dibuang, dan status error serta jeda kirim di-reset.

Image berjalan sebagai user `nonroot` (uid 65532). File kredensial harus bisa dibaca user itu, misalnya `chmod 644` atau grup yang sesuai. Mount sebaiknya read-only. Isi kredensial dan token akses tidak pernah ditulis ke log. Token perangkat di log hanya ditampilkan 6 karakter terakhirnya.

Token akses OAuth2 dibuat dari assertion JWT RS256 (`scope` `firebase.messaging`) dan disimpan di cache sampai 5 menit sebelum kedaluwarsa.

## Status di web CS

Web CS hanya membaca heartbeat 90 detik terakhir:

| Status | Kondisi |
|---|---|
| offline | Tidak ada heartbeat |
| belum dikonfigurasi | `configured=false` |
| aktif | `configured=true` dan tanpa error |
| error | `configured=true` dan ada error (kredensial salah, Firebase menolak akses, Google atau FCM tidak bisa dihubungi, APNs/Web Push ditolak) |

Gangguan sistemik ditangani begini: token ditolak Google, 401 berulang, 403/404 dari FCM, atau jaringan/timeout ke FCM. Sisa batch dilepas (`release`, percobaan tidak dihitung), heartbeat error langsung dikirim, dan claim dijeda 15 detik. Jeda berlipat ganda sampai maksimal 5 menit. Error hilang setelah ada pengiriman atau pengambilan token yang berhasil.

Pemetaan hasil FCM per pesan:

| Hasil | Kondisi |
|---|---|
| `sent` | 2xx |
| `invalid` | `UNREGISTERED`, `SENDER_ID_MISMATCH`, `INVALID_ARGUMENT` tentang registration token. Database menghapus perangkatnya |
| `failed` | `INVALID_ARGUMENT` lain (payload salah), `THIRD_PARTY_AUTH_ERROR` (juga memasang error status) |
| `retry` | `QUOTA_EXCEEDED`/429, `UNAVAILABLE`/503, `INTERNAL`/500, 5xx lain. Header `Retry-After` dipatuhi |
| `release` | Gangguan sistemik, shutdown, atau `LEASE` hampir habis |

## Endpoint dan metrik

`GET /healthz` (liveness), `GET /readyz` (200 jika PostgREST terjangkau, 503 jika tidak), `GET /metrics` (format teks Prometheus), dan subcommand `notifier healthcheck` untuk image distroless.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `notifier_push_total{outcome}` | counter | `sent`, `retry`, `invalid`, `failed`, `release` |
| `notifier_claim_batches_total` | counter | Claim yang menghasilkan minimal satu pesan |
| `notifier_queue_depth` | gauge | Panjang antrean menurut heartbeat terakhir |
| `notifier_configured` | gauge | 1 jika ada file kredensial |
| `notifier_healthy` | gauge | 1 jika terkonfigurasi dan tanpa error |

Saat SIGTERM, notifier berhenti claim dan menyelesaikan batch yang sedang jalan dalam batas `SHUTDOWN_TIMEOUT`, melaporkan hasilnya, lalu keluar dengan kode 0. Atur `stop_grace_period` container agar lebih panjang dari `SHUTDOWN_TIMEOUT` (misalnya 30s).

Tes: `go test ./...`.
