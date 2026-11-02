# nasabah-gateway

Gateway kecil antara web CS dan csAdmin (server C++ lama). Hanya meneruskan rute staf `/online/*` dalam daftar izin. Gateway mendapat token csAdmin lewat `POST /integration/token` dengan assertion Ed25519 (tanpa akun csAdmin), memvalidasi parameter query, dan menegakkan permission Akun Nasabah per akun CS console. Gateway juga menimpa kolom pelaku dengan kode CS dan mencatat aksi tulis di `cs_audit_log`.

Desain, konfigurasi, daftar rute, dan catatan keamanan: [docs/nasabah/README.md](../../docs/nasabah/README.md).

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Memverifikasi token sesi console dan membuat token `service_role` untuk RPC `nasabah_access`/`nasabah_audit` |
| `POSTGREST_URL` | `http://rest:3000` | |
| `CSADMIN_URL` | kosong | Kosong = `503 not_configured` |
| `CSADMIN_CLIENT_ID` | `web-cs` | Sama dengan `client_id` di blok `integration` csAdminEL.cfg |
| `CSADMIN_SIGNING_KEY` / `CSADMIN_SIGNING_KEY_FILE` | kosong | Kunci privat Ed25519 (PEM PKCS#8). Kosong = `503 not_configured`. Saat start, gateway mencatat baris kunci publik untuk config csAdmin |
| `CSADMIN_TIMEOUT` | `15s` | |
| `ACCESS_CACHE_TTL` | `30s` | Cache permission per akun (penolakan 5 detik) |

Endpoint: `/api-nasabah/online/...`, `GET /healthz`, `GET /readyz` (cek PostgREST), subcommand `healthcheck` untuk image distroless.

Tes: `go test ./...` atau `make test-nasabah-gateway`.
