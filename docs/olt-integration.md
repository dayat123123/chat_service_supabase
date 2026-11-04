# Integrasi OLT: Token Sosial Bertanda Tangan

> **Keputusan 31 Okt 2026.** Server sosial **tidak memanggil sistem OLT sama sekali**. Saat login, OLT menerbitkan *token sosial* (JWT) yang ditandatangani dengan kunci privat OLT. auth-bridge memverifikasinya secara lokal dengan kunci publik OLT. Cara lama (auth-bridge bertanya ke WebSocket OLT) masih ada sebagai mode `websocket`, tetapi bukan default. Semua data bisnis tetap milik app OLT; `market-adapter` dan `customer-adapter` sudah dibatalkan.

## 1. Pembagian tanggung jawab

| Kebutuhan | Server sosial | App / backend OLT |
|---|---|---|
| Login | auth-bridge memverifikasi tanda tangan token sosial, lalu menerbitkan JWT sosial 15 menit | Menerbitkan token sosial saat login dan saat app meminta token baru. App memberikannya lewat `tokenProvider` |
| Daftar dan nama saham | Tidak disimpan. Kode `$KODE` hanya label untuk feed, pantau, dan room saham | Saran `$KODE` lewat `stockSearch`, nama saham lewat `CommunityStockFeed(stockName:)` |
| Harga, grafik, order book | Tidak ada | Halaman saham OLT, dibuka lewat `onStockTap` |
| Order, mutasi dana, portofolio | Tidak ada. Chat CS tidak melampirkan order | Ditampilkan app OLT. Nasabah menjelaskan ke CS lewat teks atau gambar |
| Data nasabah untuk CS | Web CS hanya menampilkan identitas dari token login, riwayat tiket, dan catatan internal | Agen membuka back-office OLT bila butuh data akun |
| Aksi akun (suspend, logout paksa) | Tidak ada | Berhenti menerbitkan token sosial untuk akun itu |

Akibatnya, server sosial bisa berjalan tanpa jalur jaringan ke OLT. Kalau OLT lambat atau mati, fitur sosial yang sudah login tetap jalan. Login baru tidak mungkin terjadi, karena login OLT sendiri sedang tidak bisa.

## 2. Yang perlu disiapkan tim OLT

1. **Pasangan kunci tanda tangan**, sekali. Disarankan Ed25519 (`EdDSA`); P-256 (`ES256`) juga diterima.
   ```bash
   openssl genpkey -algorithm ed25519 -out olt-social-signing.pem   # kunci privat: hanya di server OLT
   ```
2. **Menerbitkan token sosial** (bagian 3):
   - saat user berhasil login;
   - setiap kali app meminta token baru, misalnya lewat pesan di koneksi WebSocket OLT yang sudah ada atau endpoint milik OLT sendiri.

   Bentuk permintaan dari app ke OLT bebas, karena itu urusan app dan backend OLT. Contohnya ada di OLT dummy: pesan `social_token` dan `POST /api/social-token` ([services/dummy-olt](../services/dummy-olt/README.md)).
3. **Memberikan kunci publik dalam format JWKS** ke tim server sosial. File ini **tidak rahasia**.
   ```json
   {"keys":[{"kty":"OKP","crv":"Ed25519","kid":"olt-2026-11","alg":"EdDSA","use":"sig","x":"<kunci publik, base64url>"}]}
   ```
   Nilai `x` didapat dari: `openssl pkey -in olt-social-signing.pem -pubout -outform DER | tail -c 32 | base64 | tr '+/' '-_' | tr -d '='`

Server sosial menyimpan JWKS itu di `docker/secrets/olt_jwks`. Tidak ada endpoint, token layanan, atau network ke OLT yang dibutuhkan.

## 3. Format token sosial

JWT tiga bagian (`header.payload.tanda-tangan`, base64url tanpa padding).

```jsonc
// header
{ "alg": "EdDSA", "typ": "JWT", "kid": "olt-2026-11" }

// payload
{
  "iss": "olt",                       // wajib, sama dengan OLT_JWT_ISSUER
  "aud": "olt-social",                // wajib, string atau array yang memuat OLT_JWT_AUDIENCE
  "sub": "1001",                      // wajib, ID user OLT berupa STRING dan tidak pernah berubah
  "preferred_username": "budi_santoso", // wajib
  "name": "Budi Santoso",             // opsional, nama tampilan
  "email": "budi@example.com",        // opsional
  "iat": 1793440000,                  // wajib, detik Unix
  "exp": 1793440600,                  // wajib, maksimal 15 menit setelah iat (OLT_JWT_MAX_TTL)
  "jti": "a1b2c3"                     // opsional
}
```

Aturan verifikasi di auth-bridge:
- **Algoritma:** hanya `EdDSA` dan `ES256`, dan harus cocok dengan jenis kunci dari `kid`. `none`, `HS256`, dan lainnya ditolak.
- **`kid`:** wajib bila JWKS berisi lebih dari satu kunci.
- **Waktu:** toleransi selisih jam 30 detik.
- **Tanda tangan:** base64url wajib kanonik. Token yang tulisannya diubah walau maknanya sama tetap ditolak.
- **ID user:** server menurunkan UUID sosial yang stabil dari `sub`. Kalau `sub` berubah, user itu dianggap orang lain.

**Rotasi kunci:**
1. OLT membuat kunci baru dengan `kid` baru.
2. Tim server sosial menambahkan kunci publiknya ke JWKS, lalu me-restart auth-bridge.
3. OLT mulai menandatangani dengan kunci baru.
4. Setelah token lama habis (≤ 15 menit), kunci lama dihapus dari JWKS.

**Pencabutan:** bila akun disuspend atau logout, OLT berhenti menerbitkan token sosial untuk akun itu. Akses fitur sosial berakhir paling lambat setelah token terakhir dan JWT sosial habis (≤ 15 menit).

## 4. Konfigurasi server sosial

| Parameter | Tempat | Default |
|---|---|---|
| `AUTH_BRIDGE_OLT_MODE` | `docker/.env` | `jwt` (profil dev tanpa dummy: `mock`) |
| Kunci publik OLT | `docker/secrets/olt_jwks` | Kunci OLT dummy dari `make gen-secrets`. **Produksi wajib diganti**; `kid` berawalan `dev-` ditolak saat `APP_ENV=production` |
| `OLT_JWT_ISSUER` | `docker/.env` | `olt` |
| `OLT_JWT_AUDIENCE` | `docker/.env` | `olt-social` |
| `OLT_JWT_MAX_TTL` | `docker/.env` | `900` detik |

## 5. Pengujian

- **OLT dummy** ([services/dummy-olt](../services/dummy-olt/README.md)) adalah implementasi referensi: menerbitkan token sosial saat login dan lewat `social_token`.
- `make up DUMMY_OLT=1` menjalankan auth-bridge mode `jwt` dengan kunci publik dummy, persis seperti produksi.
- `make smoke-dummy` menguji 22 skenario: login, perpanjangan, token diubah, kedaluwarsa, audience lain, akun ditangguhkan, dan logout.
- Untuk menguji token buatan OLT asli sebelum produksi: isi `docker/secrets/olt_jwks` dengan JWKS OLT, lalu tukar token sosial dari OLT ke `POST /bridge/v1/exchange`.
- **Cek status di Hub** tanpa SSH: Super Admin membuka **Pengaturan → Integrasi aplikasi**. Halaman ini hanya-baca dan berisi:
  - **Data koneksi aplikasi** untuk tim aplikasi OLT: URL API, anon key, contoh `config/prod.json`, versi library minimum, dan versi minimum aplikasi per platform. Semuanya bisa disalin.
  - **Status login OLT** dari heartbeat auth-bridge (tiap 30 detik): *Aktif*, *Peringatan*, atau *Tidak ada heartbeat* (tidak ada heartbeat dalam 3 menit), beserta mode, `kid` + algoritma yang terpasang, issuer, audience, dan umur maksimal token. Isi kunci tidak pernah dikirim ke database.
  - Login nasabah terakhir (WIB) dan jumlah nasabah yang login 24 jam terakhir, tanpa data pribadi.
  - Peringatan muncul bila ada `kid` berawalan `dev-` (wajar di dev dengan OLT dummy, tidak mungkin di produksi karena auth-bridge menolak start), mode bukan `jwt` di luar development, atau instance auth-bridge memakai kunci yang berbeda.
- Setelah tim OLT menyerahkan JWKS: isi `docker/secrets/olt_jwks`, jalankan `make up`, lalu pastikan di Hub `kid` OLT tampil, status *Aktif*, dan login nasabah terakhir bergerak setelah login uji. Kunci **tidak bisa** diganti dari Hub: siapa pun yang bisa mengganti kunci bisa membuat token atas nama nasabah.
