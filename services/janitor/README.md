# janitor

Pembersih file Storage yang tertinggal. Janitor mengambil (claim) antrean folder Storage dari Postgres lewat RPC PostgREST `storage_cleanup_claim`, menghapus isinya lewat API Supabase Storage (`DELETE /object/{bucket}`), lalu melaporkan hasil semua folder sekaligus lewat `storage_cleanup_report`. Janitor hanya memakai standard library Go dan langsung menghubungi container `storage` (tanpa Kong, tanpa header `apikey`).

Isi antrean berasal dari dua sumber:

- **Penghapusan akun**: avatar (`avatars`), lampiran postingan dan lampiran chat (`attachments`), serta dokumen chat CS (`cs-documents`) milik akun yang dihapus.
- **Retensi surat**: dokumen surat yang masa simpannya sudah habis (`care-documents`).

## Antrean, lease, dan backoff

Database yang mengatur antrean. Setiap baris berisi satu folder (`bucket` + `prefix`). Saat claim, database mengunci baris selama `LEASE` atas nama `INSTANCE_ID` dan mengirim paling banyak `OBJECTS_PER_ENTRY` nama objek per folder. Objek yang dikirim hanya objek yang sudah ada sebelum folder itu masuk antrean, jadi akun yang dibuat ulang dengan id yang sama tetap menyimpan file barunya.

Janitor menghapus nama-nama itu per potongan `DELETE_CHUNK`, berurutan dalam satu folder, dan paling banyak `CONCURRENCY` folder diproses bersamaan. Hasil per folder:

| Hasil | Kondisi | Yang dilakukan database |
|---|---|---|
| selesai | Semua potongan terhapus, atau folder sudah kosong (`objects` kosong) | Folder ditandai selesai jika tidak ada objek tersisa |
| gagal (`error`) | Potongan pertama yang gagal menghentikan folder itu saja. `deleted` = jumlah yang sudah terhapus | Dicoba lagi dengan jeda yang makin panjang, maksimal 6 jam |
| dilepas (`release`) | Shutdown, atau `LEASE` hampir habis sebelum potongan berikutnya dimulai | Kunci dilepas tanpa dihitung sebagai kegagalan |

Janitor tidak memulai potongan baru setelah `waktu claim + LEASE − REQUEST_TIMEOUT − 5 detik`, supaya hasil sempat dilaporkan sebelum kunci habis. Jika laporan gagal (dicoba ulang setelah 250 ms, 500 ms, dan 1 detik), janitor mencatat error lalu lanjut. Baris yang terkunci kembali ke antrean setelah masa `LEASE` habis, dan menghapus objek yang sudah tidak ada tetap aman.

Claim berikutnya langsung dijalankan jika claim terakhir penuh (`BATCH_SIZE` folder) atau ada folder tanpa error yang menerima tepat `OBJECTS_PER_ENTRY` nama (kemungkinan masih ada sisa). Selain itu janitor menunggu `POLL_INTERVAL`. Jika claim gagal, janitor mencoba lagi dengan jeda 1 detik yang berlipat ganda sampai maksimal 60 detik.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | HTTP internal (`/healthz`, `/readyz`, `/metrics`), tidak untuk publik |
| `LOG_LEVEL` | `info` | |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter. Dipakai membuat token `service_role` 1 menit untuk RPC dan Storage |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `STORAGE_URL` | `http://storage:5000` | Langsung ke container storage-api |
| `INSTANCE_ID` | hostname | Nama pemegang kunci claim (maks. 100 karakter) |
| `BATCH_SIZE` | `20` | Jumlah folder per claim (1–100) |
| `OBJECTS_PER_ENTRY` | `1000` | Jumlah nama objek maksimal per folder per claim (1–1000) |
| `DELETE_CHUNK` | `100` | Jumlah nama per request `DELETE` ke Storage (1–1000) |
| `CONCURRENCY` | `4` | Jumlah folder yang diproses paralel (1–32) |
| `LEASE` | `5m` | Lama baris dikunci per claim (30s–1h, minimal `REQUEST_TIMEOUT` + 10s) |
| `POLL_INTERVAL` | `30s` | Jeda claim saat antrean tidak penuh (1s–10m) |
| `REQUEST_TIMEOUT` | `30s` | Batas waktu per request HTTP ke PostgREST dan Storage (1s–5m) |
| `SHUTDOWN_TIMEOUT` | `20s` | Waktu menyelesaikan request yang sedang jalan saat SIGTERM (1s–5m) |

Log berformat JSON. Setiap claim yang berisi folder menghasilkan satu baris info (`entries`, `objects_deleted`, `failed`, `released`, `took_ms`). Folder yang gagal dicatat sebagai warning dengan `bucket`, `prefix`, dan error. Daftar nama objek tidak pernah ditulis ke log.

## Endpoint dan metrik

`GET /healthz` (liveness), `GET /readyz` (200 jika PostgREST dan Storage (`GET /status`) terjangkau, 503 jika tidak), `GET /metrics` (format teks Prometheus), dan subcommand `janitor healthcheck` untuk image distroless.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `janitor_objects_deleted_total` | counter | Objek Storage yang terhapus |
| `janitor_entries_total{outcome}` | counter | `cleaned` (tanpa error dan tidak dilepas), `failed`, `released` |
| `janitor_claim_errors_total` | counter | Claim yang gagal |
| `janitor_last_success_timestamp_seconds` | gauge | Waktu Unix laporan terakhir yang berhasil (0 jika belum ada). Tidak bergerak saat antrean kosong |

Saat SIGTERM, janitor berhenti claim dan tidak memulai potongan baru. Request yang sedang jalan diberi waktu `SHUTDOWN_TIMEOUT`, lalu hasilnya dilaporkan (folder yang belum selesai dilepas) dan janitor keluar dengan kode 0. Atur `stop_grace_period` container agar lebih panjang dari `SHUTDOWN_TIMEOUT` (misalnya 40s).

Tes: `go test ./...`.
