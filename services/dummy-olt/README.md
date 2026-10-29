# dummy-olt

Server **tiruan** WebSocket OLT untuk development dan testing. Gunanya agar auth-bridge bisa diuji dalam **mode `websocket`**, jalur yang sama dengan produksi, selama format login OLT asli belum tersedia.

- **auth-bridge tidak diubah.** Penyambungannya hanya lewat konfigurasi `OLT_WS_*` di [`docker/docker-compose.dummy-olt.yml`](../../docker/docker-compose.dummy-olt.yml).
- **Hanya untuk development/testing.** Makefile menolak `DUMMY_OLT` bila dipakai bersama `PROD`.

```bash
make up DUMMY_OLT=1        # Windows: .\make.ps1 up -DummyOlt
make smoke-dummy           # 16 skenario: login, exchange, token ditolak, timeout, ...
make down DUMMY_OLT=1      # kembali normal: make up (auth-bridge mode mock)
```

## Akun dummy

Semua akun memakai password **`olt12345`**. Login bisa dengan username atau email.

| id | username | email | Catatan |
|---|---|---|---|
| 1001 | `budi_santoso` | budi@olt.test | Sama dengan user seed (id sosial `72689cd3-…`) |
| 1002 | `sari_invest` | sari@olt.test | user seed |
| 1003 | `andi_trader` | andi@olt.test | user seed |
| 1004 | `rina_saham` | rina@olt.test | user seed |
| 1005 | `dewi_cuan` | dewi@olt.test | user seed |
| 1006 | `olt_official` | official@olt.test | user seed (terverifikasi) |
| 1007 | `joko_prasetyo` | joko@olt.test | Belum ada di seed: profil dibuat otomatis saat exchange pertama |
| 1008 | `rudi.setiawan` | rudi@olt.test | Username bertitik: auth-bridge menyanitasi menjadi `rudi_setiawan` |
| 1009 | `akun_suspend` | suspend@olt.test | **Ditangguhkan**: login password dan token ditolak |
| 1010 | `lambat_test` | lambat@olt.test | Login token dijawab setelah **8 detik**; auth-bridge timeout 5 detik dan membalas 503 |

Daftar ini juga tersedia lewat `GET http://localhost:8090/api/users`.

## Membuat token

| Cara | Perintah |
|---|---|
| Login WebSocket (seperti app OLT) | Lihat protokol di bawah. Contoh di app `example/` (form "Login OLT dummy") |
| Login HTTP (curl) | `curl -X POST localhost:8090/api/login -H 'Content-Type: application/json' -d '{"username":"budi_santoso","password":"olt12345"}'` |
| CLI, tanpa password | `make dummy-token U=sari_invest TTL=2h`. Windows: `.\make.ps1 dummy-token -User sari_invest -Ttl 2h` |
| Akun mana pun / kedaluwarsa (khusus tes) | `curl -X POST localhost:8090/api/dev/token -d '{"user":"akun_suspend","ttl":"-1m"}'` |

Token yang didapat ditukar ke JWT Supabase:

```bash
curl -X POST localhost:8000/bridge/v1/exchange -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{"token":"olt_..."}'
```

**Format token:** `olt_<base64url(JSON {uid, iat, exp, jti})>.<base64url(HMAC-SHA256)>`.
- **Masa berlaku:** default 24 jam (`DUMMY_OLT_TOKEN_TTL`).
- **Stateless:** tetap valid setelah server restart selama `DUMMY_OLT_SECRET` tidak berubah.
- **Logout:** token yang sudah logout dicatat di memori dan ditolak.

**Token mock lama tetap diterima.** Format `mock:<id>:<username>` juga lolos (`DUMMY_OLT_ACCEPT_MOCK_TOKENS=true`), sehingga semua tes dan tombol mock di app contoh tetap jalan dalam mode ini. Set `false` untuk menguji hanya dengan token "asli".

## Protokol WebSocket (`ws://localhost:8090/ws`)

```jsonc
// server -> saat tersambung, lalu heartbeat berkala
{"type":"welcome","server":"dummy-olt","server_time":"2026-10-29T10:00:00Z"}
{"type":"heartbeat","server_time":"..."}

// login password (username ATAU email)
{"type":"login","request_id":"r1","method":"password","payload":{"username":"budi_santoso","password":"olt12345"}}
// login token (dipakai auth-bridge & app saat login ulang)
{"type":"login","request_id":"r2","method":"token","payload":{"token":"olt_..."}}

// balasan sukses
{"type":"login_result","request_id":"r1","status":"OK",
 "data":{"token":"olt_...","expires_at":"2026-10-30T10:00:00Z",
         "user":{"id":1001,"username":"budi_santoso","email":"budi@olt.test","full_name":"Budi Santoso"}}}
// balasan gagal
{"type":"login_result","request_id":"r1","status":"FAILED",
 "error":{"code":"INVALID_CREDENTIALS","message":"Username/email atau password salah"}}

// logout & ping
{"type":"logout","request_id":"r3","payload":{"token":"olt_..."}}   -> {"type":"logout_result","status":"OK"}
{"type":"ping"}                                                    -> {"type":"pong"}
```

Kode error yang mungkin muncul: `BAD_REQUEST`, `INVALID_CREDENTIALS`, `ACCOUNT_SUSPENDED`, `INVALID_TOKEN`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`, `UNKNOWN_TYPE`.

## Pemetaan ke auth-bridge

Isi `docker/docker-compose.dummy-olt.yml` di bawah ini adalah konfigurasi lengkap adapter auth-bridge untuk protokol di atas. Saat format OLT asli tersedia, cukup ganti nilainya di `docker/.env`; kode tidak perlu disentuh.

```dotenv
AUTH_BRIDGE_OLT_MODE=websocket
OLT_WS_URL=ws://dummy-olt:8090/ws
OLT_WS_LOGIN_TEMPLATE={"type":"login","method":"token","payload":{"token":"{{token}}"}}
OLT_WS_RESPONSE_MATCH_PATH=type            # lewati welcome/heartbeat
OLT_WS_RESPONSE_MATCH_VALUE=login_result
OLT_WS_SUCCESS_PATH=status
OLT_WS_SUCCESS_VALUE=OK
OLT_WS_ERROR_MESSAGE_PATH=error.message
OLT_WS_USER_ID_PATH=data.user.id
OLT_WS_USERNAME_PATH=data.user.username
OLT_WS_EMAIL_PATH=data.user.email
OLT_WS_DISPLAY_NAME_PATH=data.user.full_name
```

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `DUMMY_OLT_PORT` | `8090` | Port host. Bind memakai `KONG_HTTP_BIND` |
| `DUMMY_OLT_SECRET` | secret dev | Kunci HMAC token dummy (bukan rahasia produksi) |
| `DUMMY_OLT_TOKEN_TTL` | `24h` | Masa berlaku token login password |
| `DUMMY_OLT_ACCEPT_MOCK_TOKENS` | `true` | Terima juga token `mock:<id>:<username>` |
| `DUMMY_OLT_SLOW_DELAY` | `8s` | Jeda login token akun `lambat_test` |

## Tes

| Perintah | Isi |
|---|---|
| `make test-dummy-olt` | Unit test Go: token, login password/email/token, logout, akun ditangguhkan, mock, lambat, heartbeat |
| `make smoke-dummy` | 16 skenario end-to-end lewat Kong + auth-bridge mode websocket |
| `make test-flutter-it-dummy` | Package Flutter dengan token hasil login WebSocket (password → token → `OltSocial`) |
| `make e2e-windows-dummy` | App contoh: form login OLT dummy (password salah ditolak, login email masuk) |
