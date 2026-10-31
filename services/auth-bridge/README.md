# auth-bridge

Service Go yang menukar **token login OLT** menjadi **JWT Supabase**, sehingga user tidak perlu login dua kali.

```
App OLT ──POST /bridge/v1/exchange {"token": "<token OLT>"}──▶ Kong ──▶ auth-bridge
                                                                         │ 1. rate limit per IP (Valkey, sliding window)
                                                                         │ 2. cache verifikasi (Valkey, kunci = hash token, TTL singkat)
                                                                         │ 3. verifikasi ke WebSocket OLT (Protokol v1)
                                                                         │    lewat circuit breaker; timeout 5 dtk;
                                                                         │    koneksi ditutup setelah respons
                                                                         │ 4. upsert profiles (RPC service_role, retry + backoff)
                                                                         │    user yang di-ban ditolak (403)
                                                                         │ 5. rate limit per user OLT
                                                                         ▼ 6. JWT HS256 (role authenticated, 15 mnt)
```

- auth-bridge **tidak pernah menerima atau menyimpan password**. Login dengan username/email + password tetap dilakukan app OLT langsung ke WebSocket OLT.
- **Token tidak pernah ditulis ke log, metrik, atau cache.** Cache Valkey memakai SHA-256 token sebagai kunci dan hanya menyimpan profil publik.
- **ID user** dihitung dengan `UUIDv5(namespace 0b7f6c1e-5a2d-4c8e-9f3b-7d1a2e4c6f80, olt_user_id)`:
  - Hasilnya stabil selamanya dan sama dengan `supabase/seed/seed.sql`.
  - Namespace ini **jangan pernah diubah**.
- **Profil** di-upsert lewat RPC `upsert_olt_profile` di PostgREST internal, memakai JWT `service_role` yang ditandatangani sendiri. Akibatnya bridge tidak butuh kredensial database.
- **Username OLT** disanitasi ke `[A-Za-z0-9_]{3,30}`. Bila bentrok dengan user lain, diberi akhiran unik.
- **Email** disimpan di `private.user_private`, yang tidak bisa dibaca user lain. Email **tidak** dimasukkan ke JWT.

## API

`POST /exchange` dipanggil lewat Kong di `/bridge/v1/exchange`, dengan header `apikey: <ANON_KEY>`.

```json
// request
{ "token": "<token login OLT>" }

// 200
{
  "access_token": "<JWT>",
  "token_type": "bearer",
  "expires_in": 900,
  "expires_at": 1793270000,
  "user": { "id": "72689cd3-…", "olt_user_id": "1001", "username": "budi_santoso",
            "display_name": "Budi Santoso", "avatar_url": null, "is_verified": true }
}
```

| Status | `error` | Arti |
|---|---|---|
| 400 | `invalid_request` | Body bukan `{"token": "..."}` |
| 401 | `invalid_token` | OLT menolak token; user perlu login ulang di OLT |
| 403 | `user_banned` | User sedang di-ban dari fitur sosial |
| 429 | `rate_limited` | Melebihi `RATE_LIMIT_PER_MINUTE` per IP atau `RATE_LIMIT_PER_USER_PER_MINUTE` per user. Ada header `Retry-After` |
| 502 | `exchange_failed` | Gagal upsert profil (setelah retry) |
| 503 | `olt_unavailable` | Server OLT tidak menjawab dalam `OLT_WS_TIMEOUT`, atau circuit breaker terbuka |

**Isi JWT** sengaja minimal karena bisa dibaca siapa pun yang memegangnya: `sub` (UUID), `role: authenticated`, `aud: authenticated`, `iss: olt-auth-bridge`, `iat`/`exp`, dan `app_metadata.provider: olt`. Tidak ada email, username, atau `olt_user_id`.

`GET /health` (port publik) mengembalikan `{"status": "ok", "olt_mode": "..."}`. Endpoint ini dipakai healthcheck Docker lewat `auth-bridge healthcheck`.

### Port ops (internal)

`OPS_PORT` (default `9100`) **tidak dipublikasikan dan tidak diteruskan Kong**. Hanya bisa dijangkau dari jaringan Docker (Prometheus, probe).

| Endpoint | Isi |
|---|---|
| `GET /metrics` | Metrik Prometheus (lihat di bawah) |
| `GET /livez` | `200` selama proses hidup |
| `GET /readyz` | `200 ready`, `200 degraded` (dependensi opsional bermasalah: Valkey, breaker OLT terbuka), atau `503 not_ready` (PostgREST tidak terjangkau). Detail error hanya ke log |

Metrik:

| Nama | Label | Keterangan |
|---|---|---|
| `olt_auth_bridge_http_requests_total` | `path`, `status` | Request HTTP port publik |
| `olt_auth_bridge_http_request_duration_seconds` | `path` | Histogram durasi |
| `olt_auth_bridge_exchanges_total` | `result` | `ok`, `cached`, `invalid_token`, `olt_unavailable`, `banned`, `rate_limited_ip`, `rate_limited_user`, `error` |
| `olt_auth_bridge_olt_breaker_open` | – | `1` bila circuit breaker ke OLT terbuka |
| `olt_auth_bridge_valkey_errors_total` | `op` | Error Valkey (`ratelimit`, `cache`) |

### Ketahanan

- **Valkey** menyimpan rate limit dan cache bersama untuk semua replika. Bila Valkey mati, rate limit jatuh ke limiter in-memory per instance dan cache dilewati. Layanan tetap jalan, error dicatat di metrik, dan log dibatasi sekali per menit.
- **Circuit breaker**: setelah `BREAKER_FAILURE_THRESHOLD` kegagalan OLT berturut-turut, verifikasi baru langsung ditolak `503` selama `BREAKER_COOLDOWN` detik. Setelah itu satu request uji diizinkan. Token yang ditolak OLT dihitung sukses (OLT sehat). Request yang dibatalkan klien tidak dihitung. State breaker per instance.
- **PostgREST**: error jaringan dan `5xx` di-retry maksimal 3 kali dengan backoff eksponensial + jitter (100 ms, 200 ms). `4xx` tidak di-retry.
- **User di-ban**: exchange ditolak `403` dan tidak di-cache. Di database, `private.check_request` juga menolak setiap request user yang di-ban, jadi JWT yang terbit sebelum ban pun tidak berguna.

## Mode OLT

### `mock` (development)

Token berformat `mock:<olt_user_id>:<username>[:<nama tampilan>]`, contohnya `mock:1001:budi_santoso`. Mode ini **ditolak saat `APP_ENV=production`**.

### `websocket` (produksi)

Default adapter **sama dengan Protokol v1** ([docs/olt-integration.md](../../docs/olt-integration.md)). Bila OLT memakai protokol itu, cukup isi:

```dotenv
AUTH_BRIDGE_OLT_MODE=websocket
OLT_WS_URL=wss://olt.example.com/social
```

Pesan yang dikirim dan dibaca auth-bridge:

```jsonc
// request (request_id = UUID v4 baru per login)
{ "v": 1, "type": "login", "request_id": "…", "method": "token", "payload": { "token": "<token OLT>" } }

// response
{ "v": 1, "type": "login_result", "request_id": "…", "status": "OK",
  "data": { "user": { "id": "1001", "username": "budi_santoso", "email": "…", "full_name": "Budi Santoso" } } }
```

Untuk mencoba mode ini tanpa server OLT asli, jalankan `make up DUMMY_OLT=1`. Perintah ini memakai server OLT tiruan [`services/dummy-olt`](../dummy-olt/), yang juga berbicara Protokol v1. Profil itu hanya mengisi `OLT_MODE` dan `OLT_WS_URL`, persis seperti produksi.

**Bila format OLT berbeda**, timpa default lewat `docker/.env` tanpa mengubah kode. Contoh: OLT membalas `{"action":"login_result","ok":true,"user":{"uid":1001,"nick":"budi"}}`:

```dotenv
OLT_WS_LOGIN_TEMPLATE={"action":"login","token":"{{token}}"}
OLT_WS_RESPONSE_MATCH_PATH=action          # lewati pesan lain (heartbeat, ticker, ...)
OLT_WS_RESPONSE_MATCH_VALUE=login_result
OLT_WS_SUCCESS_PATH=ok
OLT_WS_SUCCESS_VALUE=true                  # perbandingan tidak peka huruf besar/kecil
OLT_WS_ERROR_MESSAGE_PATH=message
OLT_WS_USER_ID_PATH=user.uid
OLT_WS_USERNAME_PATH=user.nick
```

Cara kerja adapter:
- **Template login** di-parse sebagai JSON. Setiap nilai string berisi `{{token}}` atau `{{request_id}}` lalu diganti. Karena bekerja pada struktur JSON (bukan teks), token yang mengandung tanda kutip tidak bisa menyuntikkan JSON.
- **Path** memakai notasi titik. Indeks array ditulis sebagai angka, misalnya `data.items.0.id`. Angka besar dibaca tanpa kehilangan presisi.

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `APP_ENV` | `development` | `production` menolak `OLT_MODE=mock` dan mewajibkan `VALKEY_ADDR` |
| `PORT` | `8080` | Port publik (lewat Kong) |
| `OPS_PORT` | `9100` | Port internal `/metrics`, `/livez`, `/readyz`. `0` = mati |
| `LOG_LEVEL` | `info` | `debug` / `info` / `warn` / `error`. Log berupa JSON (slog) dengan `request_id`. Token tidak pernah ditulis ke log |
| `JWT_SECRET` | wajib | Sama dengan JWT secret Supabase, minimal 32 karakter |
| `JWT_SECRET_FILE` | – | Baca `JWT_SECRET` dari file (Docker secrets). Dipakai compose: `/run/secrets/jwt_secret` |
| `JWT_TTL` | `900` | Masa berlaku JWT user, dalam detik |
| `POSTGREST_URL` | `http://rest:3000` | PostgREST internal |
| `VALKEY_ADDR` | – | `host:port` Valkey. Kosong = in-memory per instance (hanya development) |
| `VALKEY_PASSWORD` / `VALKEY_PASSWORD_FILE` | – | Compose memakai `/run/secrets/valkey_password` |
| `VALKEY_DB` | `0` | |
| `VERIFY_CACHE_TTL` | `60` | Cache hasil exchange per hash token, dalam detik |
| `RATE_LIMIT_PER_MINUTE` | `30` | Per IP klien |
| `RATE_LIMIT_PER_USER_PER_MINUTE` | `10` | Per user OLT |
| `BREAKER_FAILURE_THRESHOLD` | `5` | Kegagalan OLT berturut-turut sebelum breaker terbuka |
| `BREAKER_COOLDOWN` | `30` | Detik sebelum request uji ke OLT |
| `TRUSTED_PROXIES` | jaringan privat | `X-Forwarded-For` hanya dipercaya dari proxy ini (Kong/Traefik). IP klien = IP paling kanan yang bukan proxy. Bila semua hop berupa IP privat (dev/service internal), dipakai hop paling kiri agar klien internal tidak berbagi satu kuota. XFF kiriman internet dibuang Traefik sebelum sampai ke sini |
| `OLT_MODE` | `mock` | `mock` / `websocket` |
| `OLT_WS_*` | Protokol v1 | Adapter WebSocket OLT, lihat di atas |

Di compose, variabel ini diisi dari `docker/.env` dengan awalan `AUTH_BRIDGE_` (mis. `AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE`).

## Development

```bash
go test ./...                 # unit test (termasuk server WebSocket OLT tiruan & Valkey tiruan)
go vet ./...
make test-bridge              # dari root repo, tes di container Go
```

Dependensi runtime: Go stdlib, `github.com/gorilla/websocket` (BSD-2-Clause), `github.com/redis/go-redis/v9` (BSD-2-Clause) beserta `cespare/xxhash` (MIT), `go.uber.org/atomic` (MIT), dan `golang.org/x/sys` (BSD-3-Clause). Khusus tes: `github.com/alicebob/miniredis/v2` (MIT).
