# Modul 4: PostgREST dan JWT

**Tujuan:** mengerti bagaimana fungsi SQL dari modul 2 menjadi endpoint HTTP, dan bagaimana token membawa identitas pengguna sampai ke `auth.uid()` di modul 3.

---

## 4.1 JWT dalam lima menit

JWT (JSON Web Token) adalah teks tiga bagian yang dipisah titik:

```
eyJhbGciOiJIUzI1NiJ9 . eyJzdWIiOiI3MjY4…In0 . sY9…xQ
      header                  payload           signature
```

- **Header**: algoritma tanda tangan (`HS256`, `EdDSA`, `ES256`) dan `kid` (id kunci).
- **Payload**: klaim, yaitu data tentang pengguna. Hanya di-*encode* base64url, **tidak dienkripsi**: siapa pun yang memegang token bisa membacanya. Jangan menaruh rahasia di sini.
- **Signature**: tanda tangan atas header + payload. Mengubah satu huruf payload membuat tanda tangan tidak cocok, sehingga token ditolak.

Klaim standar:

| Klaim | Arti |
|---|---|
| `sub` | Subjek: id pengguna |
| `iss` | Penerbit (`olt`, `olt-auth-bridge`) |
| `aud` | Untuk siapa token ini (`olt-social`, `authenticated`) |
| `exp` / `iat` / `nbf` | Kedaluwarsa / diterbitkan / belum berlaku sebelum (detik Unix) |
| `role` | Klaim khusus PostgREST: role database yang dipakai |

### Dua jenis tanda tangan

| | HS256 (simetris) | EdDSA / ES256 (asimetris) |
|---|---|---|
| Kunci | Satu rahasia, dipakai untuk menandatangani **dan** memeriksa | Kunci privat untuk menandatangani, kunci publik untuk memeriksa |
| Cocok untuk | Di dalam satu sistem | Antar sistem: penerima tidak bisa ikut membuat token |
| Di sistem kita | Token Rendezvous (auth-bridge ↔ PostgREST, Realtime, media) | Token sosial OLT. Kita hanya memegang kunci publiknya (JWKS) |

Inilah alasan OLT memakai kunci asimetris: walaupun server kita dibobol, penyerang tidak bisa membuat token sosial OLT palsu.

## 4.2 Alur login kita

```
App OLT ── login ke OLT ──► OLT menerbitkan TOKEN SOSIAL (EdDSA, iss=olt, aud=olt-social, sub=1001, 10 mnt)
   │
   └─ POST /bridge/v1/exchange {token} ─► auth-bridge:
          1. periksa tanda tangan dengan JWKS OLT, iss, aud, exp
          2. buat/ambil profil: id profil = UUID v5 dari "1001" (selalu sama untuk login yang sama)
          3. simpan klaim accounts (rekening) bila ada
          4. terbitkan TOKEN RENDEZVOUS (HS256, sub=<uuid profil>, role=authenticated, 15 mnt)
   │
   └─ semua request berikutnya: Authorization: Bearer <token Rendezvous>
```

Isi token Rendezvous sengaja minimal: `sub`, `role: authenticated`, `aud: authenticated`, `iss: olt-auth-bridge`, `iat`/`exp`, dan `app_metadata.provider: olt`. Tidak ada username atau email ([services/auth-bridge](../../services/auth-bridge/README.md)).

## 4.3 Mencoba sendiri

Butuh: stack dev berjalan dengan dummy OLT (`make up DUMMY_OLT=1`). Dua perintah bantu sudah tersedia:

```powershell
.\make.ps1 anon-key                       # mencetak ANON_KEY
.\make.ps1 dummy-token -User budi_santoso # mencetak token sosial dummy OLT (Linux: make dummy-token U=budi_santoso)
```

Cara lain lewat login dummy OLT dengan username dan password ada di [services/dummy-olt/README.md](../../services/dummy-olt/README.md).

PowerShell:

```powershell
$ANON   = "<hasil anon-key>"
$SOSIAL = "<hasil dummy-token>"

$sesi = Invoke-RestMethod -Method Post -Uri http://localhost:8000/bridge/v1/exchange `
  -Headers @{ apikey = $ANON } -ContentType 'application/json' `
  -Body (@{ token = $SOSIAL } | ConvertTo-Json)
$TOKEN = $sesi.access_token
$sesi.user

$h = @{ apikey = $ANON; Authorization = "Bearer $TOKEN" }
Invoke-RestMethod -Method Post -Uri http://localhost:8000/rest/v1/rpc/get_dm_policy -Headers $h -ContentType 'application/json' -Body '{}'
Invoke-RestMethod -Method Post -Uri http://localhost:8000/rest/v1/rpc/get_my_rooms -Headers $h -ContentType 'application/json' -Body '{"p_limit":3}'
```

Membaca isi token tanpa situs luar:

```powershell
$p = $TOKEN.Split('.')[1].Replace('-', '+').Replace('_', '/')
switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
```

Token dev boleh ditempel di <https://jwt.io> untuk dilihat. Token produksi **jangan** pernah ditempel ke situs mana pun.

## 4.4 Bagaimana PostgREST bekerja

```
POST /rest/v1/rpc/get_my_rooms   {"p_limit": 3}
  │ Kong: cek header apikey, buang awalan /rest/v1, teruskan ke rest:3000
  ▼
PostgREST
  1. verifikasi JWT (HS256, secret sama dengan auth-bridge); kedaluwarsa → 401
  2. begin;
     set local role authenticated;                      -- dari klaim role
     select set_config('request.jwt.claims', '{…}', true);
  3. select * from public.get_my_rooms(p_limit := 3);   -- key JSON = nama parameter
  4. ubah hasil jadi JSON; commit (atau rollback bila error)
```

Yang perlu diingat:

| Hal | Penjelasan |
|---|---|
| **Schema yang dibuka** | `PGRST_DB_SCHEMAS=public,graphql_public,cs_api` di [docker/compose.yml](../../docker/compose.yml). Schema `private` dan `cs` tidak bisa dipanggil dari luar |
| **Memilih schema** | Bawaan `public`. Hub memanggil `cs_api` dengan header `Content-Profile: cs_api` (POST) atau `Accept-Profile: cs_api` (GET) |
| **Schema cache** | PostgREST menyimpan daftar fungsi di memori. Setelah migrasi, `notify pgrst, 'reload schema'` ([scripts/migrate.sh](../../scripts/migrate.sh)). Fungsi yang belum dikenal → `404 PGRST202` |
| **Overload** | Dua fungsi bernama sama dengan parameter berbeda membingungkan PostgREST. Saat menambah parameter, kita `drop` versi lama lalu membuat yang baru dengan `default` (contoh: `p_comment_audience text default null` di `create_post`) |
| **Satu request = satu transaksi** | Error di mana pun dalam fungsi membatalkan semuanya |
| **Tabel juga bisa diakses** | `GET /rest/v1/profiles?select=username&limit=3` membaca tabel langsung, tetap disaring GRANT dan RLS. Kita lebih banyak memakai RPC supaya aturan bisnis ada di satu tempat |

### Pemetaan error

| Di SQL | HTTP |
|---|---|
| `api_error(403, 'not_member')` → SQLSTATE `PT403` | `403 {"code":"PT403","message":"not_member"}` |
| Pelanggaran `with check` RLS (`42501`) | `403` |
| `unique_violation` (`23505`) | `409` |
| Fungsi tidak ada | `404 PGRST202` |
| JWT kedaluwarsa atau salah | `401 PGRST301/PGRST303` |

Daftar lengkap ada di dokumentasi PostgREST, bagian *Errors*.

## 4.5 Kong dan apikey

`apikey` (ANON_KEY) **bukan** rahasia pengguna: semua aplikasi memakai nilai yang sama, dan nilainya ada di dalam aplikasi. Fungsinya hanya sebagai penanda di Kong bahwa request datang dari klien yang dikenal, supaya Kong mau meneruskannya. Identitas pengguna selalu datang dari `Authorization: Bearer`.

Rute Kong ada di [docker/volumes/api/kong.yml](../../docker/volumes/api/kong.yml): `/rest/v1` ke PostgREST, `/realtime/v1` ke Realtime, `/bridge/v1` ke auth-bridge, `/media/v1` ke media, `/integration/v1` ke integration.

---

## Latihan

1. Jalankan 4.3, lalu decode token Rendezvous Anda. Klaim apa saja yang ada? Cocokkan `sub` dengan `select id from public.profiles where username = 'budi_santoso'`.
2. Ubah satu huruf di bagian payload token, lalu panggil `get_dm_policy`. Error apa yang muncul dan dari mana?
3. Panggil `get_messages` untuk room yang **bukan** milik Budi (ambil id-nya lewat psql). Cocokkan kode error dengan `\sf public.get_messages`.
4. Panggil `get_dm_policy` lewat **GET** (`Invoke-RestMethod -Method Get …/rpc/get_dm_policy`). Lalu coba `mark_room_read` lewat GET. Kenapa yang kedua gagal? (Petunjuk: modul 2.4.)
5. Baca [docs/api/openapi.yaml](../api/openapi.yaml) dan import ke Postman. Kirim `send_message` ke room DM Budi, lalu lihat pesannya di psql.

## Cek pemahaman

- Kenapa token OLT asimetris, sedangkan token Rendezvous cukup HS256?
- Apa yang terjadi di database saat PostgREST menerima token dengan `role: authenticated`?
- Apa bedanya `apikey` dan `Authorization`?

**Bacaan:** <https://jwt.io/introduction>; PostgREST docs: *Authentication*, *Functions as RPC*, *Schemas*, *Errors*.
