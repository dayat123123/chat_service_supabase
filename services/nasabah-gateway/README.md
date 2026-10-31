# nasabah-gateway

Gateway kecil antara web CS dan csAdmin (server C++ lama). Hanya meneruskan rute dalam daftar izin (staf `/online/*` dan pengelolaan akun CS `/cs/*`). Gateway login ke csAdmin dengan akun teknis, memvalidasi parameter query, dan menegakkan permission Nasabah per akun console. Gateway juga menimpa kolom pelaku, mengunci akun teknisnya sendiri, memasang password sementara acak untuk akun CS baru, dan mencatat aksi tulis di `cs_audit_log`.

Desain, konfigurasi, daftar rute, dan catatan keamanan: [docs/nasabah/README.md](../../docs/nasabah/README.md).

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Memverifikasi token sesi console dan membuat token `service_role` untuk RPC `nasabah_access`/`nasabah_audit` |
| `POSTGREST_URL` | `http://rest:3000` | |
| `CSADMIN_URL` | kosong | Kosong = `503 not_configured` |
| `CSADMIN_USERNAME` | kosong | |
| `CSADMIN_PASSWORD` / `CSADMIN_PASSWORD_FILE` | kosong | |
| `CSADMIN_ACTOR` | `agent` | `agent` atau `service` |
| `CSADMIN_TIMEOUT` | `15s` | |
| `ACCESS_CACHE_TTL` | `30s` | Cache permission per akun (penolakan 5 detik) |

Endpoint: `/api-nasabah/online/...`, `/api-nasabah/cs/...`, `GET /api-nasabah/gateway/info`, `GET /healthz`, `GET /readyz` (cek PostgREST), subcommand `healthcheck` untuk image distroless.

Tes: `go test ./...` atau `make test-nasabah-gateway`.
