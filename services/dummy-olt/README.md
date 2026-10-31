# dummy-olt

Server **tiruan** OLT untuk development dan testing. Dummy ini berperan sebagai backend OLT: melayani login (WebSocket/HTTP) dan **menerbitkan token sosial** (JWT EdDSA) yang ditandatangani dengan kunci dev. auth-bridge memverifikasinya dalam **mode `jwt`**, jalur yang sama dengan produksi. Dummy ini juga menjadi contoh nyata kontrak untuk tim OLT ([docs/olt-integration.md](../../docs/olt-integration.md)).

- **auth-bridge tidak diubah dan tidak menghubungi dummy.** [`docker/compose.dummy-olt.yml`](../../docker/compose.dummy-olt.yml) hanya mengganti `OLT_MODE` ke `jwt`. Kunci publik dummy sudah ada di `docker/secrets/olt_jwks` (dibuat `make gen-secrets`).
- **Hanya untuk development/testing.** Makefile menolak `DUMMY_OLT` di luar profil dev, dan auth-bridge produksi menolak kunci dev (`kid` berawalan `dev-`).

```bash
make up DUMMY_OLT=1        # Windows: .\make.ps1 up -DummyOlt
make smoke-dummy           # 22 skenario: login, token sosial, perpanjangan, token diubah/kedaluwarsa, suspend, ...
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
| 1009 | `akun_suspend` | suspend@olt.test | **Ditangguhkan**: login dan permintaan token sosial ditolak (`ACCOUNT_SUSPENDED`) |
| 1010 | `lambat_test` | lambat@olt.test | Login token WebSocket dijawab setelah **8 detik**, untuk menguji timeout di sisi app |

Daftar ini juga tersedia lewat `GET http://localhost:8090/api/users`.

## Dua jenis token

| Token | Bentuk | Dipakai untuk |
|---|---|---|
| **Token sesi OLT** | `olt_<base64url(JSON {uid, iat, exp, jti})>.<HMAC-SHA256>`, 24 jam (`DUMMY_OLT_TOKEN_TTL`) | Login ulang ke OLT dan meminta token sosial baru. **Ditolak auth-bridge** |
| **Token sosial** | JWT `EdDSA`, `kid` `dev-olt-1`, `iss` `olt`, `aud` `olt-social`, 10 menit (`DUMMY_OLT_SOCIAL_TTL`) | Ditukar di `POST /bridge/v1/exchange`. Diberikan app lewat `tokenProvider` |

- **Token sesi** stateless: tetap valid setelah restart selama `DUMMY_OLT_SECRET` tidak berubah. Token yang sudah logout dicatat di memori dan ditolak.
- **Token sosial** tidak bisa dicabut. Pencabutan dilakukan dengan berhenti menerbitkannya: sesi yang logout atau akun yang ditangguhkan tidak mendapat token sosial baru.

## Membuat token

| Cara | Perintah |
|---|---|
| Login WebSocket (seperti app OLT) | Lihat protokol di bawah. Contoh di app `example/` (form "Login OLT dummy") |
| Login HTTP (curl) | `curl -X POST localhost:8090/api/login -H 'Content-Type: application/json' -d '{"username":"budi_santoso","password":"olt12345"}'`. Balasan berisi `token` (sesi) dan `social_token` |
| Token sosial baru dari sesi | `curl -X POST localhost:8090/api/social-token -H 'Content-Type: application/json' -d '{"token":"olt_..."}'` |
| CLI, tanpa password | `make dummy-token U=sari_invest` (token sosial). Windows: `.\make.ps1 dummy-token -User sari_invest` |
| Akun mana pun / kedaluwarsa / audience lain (khusus tes) | `curl -X POST localhost:8090/api/dev/token -d '{"user":"budi_santoso","kind":"social","ttl":"-1m","audience":"olt-trading"}'`. Tanpa `kind` = token sesi |

Token sosial ditukar ke JWT Supabase:

```bash
curl -X POST localhost:8000/bridge/v1/exchange -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' -d '{"token":"<social_token>"}'
```

**Token mock lama.** Dalam mode `jwt`, auth-bridge menolak `mock:<id>:<username>` mentah. Dummy menerima token mock sebagai token sesi (`DUMMY_OLT_ACCEPT_MOCK_TOKENS=true`), jadi tombol mock di app contoh menukarnya dulu lewat `social_token` lalu memakai token sosial hasilnya. Set `false` untuk menguji hanya dengan login asli.

## Protokol WebSocket (`ws://localhost:8090/ws`)

```jsonc
// server -> saat tersambung, lalu heartbeat berkala
{"type":"welcome","server":"dummy-olt","server_time":"2026-10-29T10:00:00Z"}
{"type":"heartbeat","server_time":"..."}

// login password (username ATAU email)
{"type":"login","request_id":"r1","method":"password","payload":{"username":"budi_santoso","password":"olt12345"}}
// login token (app saat login ulang)
{"type":"login","request_id":"r2","method":"token","payload":{"token":"olt_..."}}

// balasan sukses: token sesi + token sosial
{"type":"login_result","request_id":"r1","status":"OK",
 "data":{"token":"olt_...","expires_at":"2026-10-30T10:00:00Z",
         "social_token":"eyJ...","social_token_expires_at":"2026-10-29T10:10:00Z",
         "user":{"id":1001,"username":"budi_santoso","email":"budi@olt.test","full_name":"Budi Santoso"}}}
// balasan gagal
{"type":"login_result","request_id":"r1","status":"FAILED",
 "error":{"code":"INVALID_CREDENTIALS","message":"Username/email atau password salah"}}

// token sosial baru (sebelum yang lama habis)
{"type":"social_token","request_id":"r3","payload":{"token":"olt_..."}}
  -> {"type":"social_token_result","request_id":"r3","status":"OK",
      "data":{"token":"eyJ...","expires_at":"...","user":{...}}}

// logout & ping
{"type":"logout","request_id":"r4","payload":{"token":"olt_..."}}   -> {"type":"logout_result","status":"OK"}
{"type":"ping"}                                                    -> {"type":"pong"}
```

Kode error yang mungkin muncul: `BAD_REQUEST`, `INVALID_CREDENTIALS`, `ACCOUNT_SUSPENDED`, `INVALID_TOKEN`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`, `UNKNOWN_TYPE`.

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `DUMMY_OLT_PORT` | `8090` | Port host. Bind memakai `EDGE_HTTP_BIND` |
| `DUMMY_OLT_SECRET` | secret dev | Kunci HMAC token sesi (bukan rahasia produksi) |
| `DUMMY_OLT_TOKEN_TTL` | `24h` | Masa berlaku token sesi |
| `DUMMY_OLT_SIGNING_KEY_FILE` | wajib | Kunci privat Ed25519 (PKCS#8 PEM). Compose: secret `olt_dev_signing_key` dari `make gen-secrets` |
| `DUMMY_OLT_SIGNING_KID` | `dev-olt-1` | `kid` di header token sosial; harus sama dengan JWKS di `docker/secrets/olt_jwks` |
| `DUMMY_OLT_SOCIAL_TTL` | `10m` | Masa berlaku token sosial (maksimal `OLT_JWT_MAX_TTL` auth-bridge) |
| `DUMMY_OLT_SOCIAL_ISSUER` / `DUMMY_OLT_SOCIAL_AUDIENCE` | `olt` / `olt-social` | Klaim `iss` / `aud` |
| `DUMMY_OLT_ACCEPT_MOCK_TOKENS` | `true` | Terima juga token `mock:<id>:<username>` sebagai token sesi |
| `DUMMY_OLT_SLOW_DELAY` | `8s` | Jeda login token akun `lambat_test` |

## Tes

| Perintah | Isi |
|---|---|
| `make test-dummy-olt` | Unit test Go: token sesi, token sosial, login password/email/token, perpanjangan, logout, akun ditangguhkan, mock, lambat, dan heartbeat |
| `make smoke-dummy` | 22 skenario end-to-end lewat Kong + auth-bridge mode jwt |
| `make smoke-cs` | 30 pemeriksaan CS chat end-to-end (nasabah, agen, supervisor, transfer, rating) |
| `make test-flutter-it-dummy` | Package Flutter dengan token sosial hasil login WebSocket (password → token sosial → `RendezvousCommunity`) |
| `make e2e-windows-dummy` | App contoh: form login OLT dummy (password salah ditolak, login email masuk) |
