# auth-bridge

Service Go yang menukar **token login OLT** menjadi **JWT Supabase**, sehingga user tidak perlu login dua kali.

```
App OLT ──POST /bridge/v1/exchange {"token": "<token OLT>"}──▶ Kong ──▶ auth-bridge
                                                                         │ 1. rate limit per IP
                                                                         │ 2. cache (hash token, TTL singkat)
                                                                         │ 3. verifikasi ke WebSocket OLT
                                                                         │    (login metode token, timeout 5 dtk,
                                                                         │     koneksi ditutup setelah respons)
                                                                         │ 4. upsert profiles (RPC service_role)
                                                                         ▼ 5. JWT HS256 (role authenticated, 15 mnt)
```

- auth-bridge **tidak pernah menerima atau menyimpan password**. Login dengan username/email + password tetap dilakukan app OLT langsung ke WebSocket OLT.
- **ID user** dihitung dengan `UUIDv5(namespace 0b7f6c1e-5a2d-4c8e-9f3b-7d1a2e4c6f80, olt_user_id)`:
  - Hasilnya stabil selamanya dan sama dengan `supabase/seed/seed.sql`.
  - Namespace ini **jangan pernah diubah**.
- **Profil** di-upsert lewat RPC `upsert_olt_profile` di PostgREST internal, memakai JWT `service_role` yang ditandatangani sendiri. Akibatnya bridge tidak butuh kredensial database.
- **Username OLT** disanitasi ke `[A-Za-z0-9_]{3,30}`. Bila bentrok dengan user lain, diberi akhiran unik.
- **Email** disimpan di `private.user_private`, yang tidak bisa dibaca user lain.

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
| 429 | `rate_limited` | Melebihi `RATE_LIMIT_PER_MINUTE` per IP. Ada header `Retry-After` |
| 502 | `exchange_failed` | Gagal upsert profil |
| 503 | `olt_unavailable` | Server OLT tidak menjawab dalam `OLT_WS_TIMEOUT` |

`GET /health` mengembalikan `{"status": "ok", "olt_mode": "mock"}`. Endpoint ini dipakai healthcheck Docker lewat `auth-bridge healthcheck`.

Isi JWT: `sub` (UUID), `role: authenticated`, `aud: authenticated`, `iss: olt-auth-bridge`, `iat`/`exp`, `email` (bila ada), `app_metadata.olt_user_id`, dan `user_metadata.username`.

## Mode OLT

### `mock` (development)

Token berformat `mock:<olt_user_id>:<username>[:<nama tampilan>]`, contohnya `mock:1001:budi_santoso`. Mode ini **ditolak saat `APP_ENV=production`**.

### `websocket` (produksi)

Untuk mencoba mode ini tanpa server OLT asli, jalankan `make up DUMMY_OLT=1`. Perintah ini memakai server OLT tiruan [`services/dummy-olt`](../dummy-olt/) dan hanya mengubah konfigurasi di bawah; kode auth-bridge tetap sama.

Format protokol login OLT dibuat bisa dikonfigurasi. Isi variabel berikut di `docker/.env` sesuai payload OLT.

Contoh: OLT mengirim `{"type":"login_result","status":"OK","user":{"id":1001,"username":"budi","email":"b@x.id","full_name":"Budi S"}}` sebagai jawaban dari request `{"type":"login","method":"token","payload":{"token":"..."}}`:

```dotenv
AUTH_BRIDGE_OLT_MODE=websocket
APP_ENV=production
OLT_WS_URL=wss://ws.olt.example.com/socket
OLT_WS_TIMEOUT=5
OLT_WS_LOGIN_TEMPLATE={"type":"login","method":"token","payload":{"token":"{{token}}"}}
OLT_WS_RESPONSE_MATCH_PATH=type          # abaikan pesan lain (heartbeat, ticker, ...)
OLT_WS_RESPONSE_MATCH_VALUE=login_result
OLT_WS_SUCCESS_PATH=status
OLT_WS_SUCCESS_VALUE=OK                  # perbandingan tidak peka huruf besar/kecil
OLT_WS_ERROR_MESSAGE_PATH=error.message
OLT_WS_USER_ID_PATH=user.id
OLT_WS_USERNAME_PATH=user.username
OLT_WS_EMAIL_PATH=user.email
OLT_WS_DISPLAY_NAME_PATH=user.full_name
```

Cara kerja adapter:
- **Template login** di-parse sebagai JSON, lalu setiap nilai string berisi `{{token}}` diganti token. Karena bekerja pada struktur JSON (bukan teks), token yang mengandung tanda kutip tidak bisa menyuntikkan JSON.
- **Path** memakai notasi titik. Indeks array ditulis sebagai angka, misalnya `data.items.0.id`. Angka besar dibaca tanpa kehilangan presisi.

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `APP_ENV` | `development` | `production` menolak `OLT_MODE=mock` |
| `PORT` | `8080` | |
| `LOG_LEVEL` | `info` | `debug` / `info` / `warn` / `error`. Log berupa JSON (slog) dengan `request_id`. Token tidak pernah ditulis ke log |
| `JWT_SECRET` | wajib | Sama dengan JWT secret Supabase, minimal 32 karakter |
| `JWT_TTL` | `900` | Masa berlaku JWT user, dalam detik |
| `POSTGREST_URL` | `http://rest:3000` | PostgREST internal |
| `VERIFY_CACHE_TTL` | `60` | Cache hasil exchange per hash token, dalam detik |
| `RATE_LIMIT_PER_MINUTE` | `30` | Per IP klien |
| `TRUSTED_PROXIES` | jaringan privat | `X-Forwarded-For` hanya dipercaya dari proxy ini (Kong/Caddy). IP klien = IP paling kanan yang bukan proxy |
| `OLT_MODE` | `mock` | `mock` / `websocket` |
| `OLT_WS_*` | lihat di atas | Adapter WebSocket OLT |

## Development

```bash
go test ./...                 # unit test (termasuk server WebSocket OLT tiruan)
go vet ./...
make test-bridge              # dari root repo, tes di container Go
```

Dependensi: Go stdlib + `github.com/gorilla/websocket` (BSD-2-Clause).
