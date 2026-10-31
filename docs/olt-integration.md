# Integrasi OLT: Hanya Validasi Token

> **Keputusan 31 Okt 2026.** Server sosial hanya punya **satu panggilan keluar ke sistem OLT**: memvalidasi token login (auth-bridge). Semua data bisnis tetap milik app OLT. Keputusan ini membatalkan rencana `market-adapter` (harga, daftar saham, portofolio, badge holder) dan menghapus `customer-adapter` (data nasabah untuk CS).

## 1. Pembagian tanggung jawab

| Kebutuhan | Server sosial | App OLT |
|---|---|---|
| Login | auth-bridge memvalidasi token ke OLT, lalu menerbitkan JWT sosial 15 menit | Memberi token sesi lewat `oltTokenProvider` |
| Daftar dan nama saham | Tidak disimpan. Kode `$KODE` hanya label untuk feed, pantau, dan room saham | Saran `$KODE` lewat `stockSearch`, nama saham lewat `OltStockFeed(stockName:)` |
| Harga, grafik, order book | Tidak ada | Halaman saham OLT, dibuka lewat `onStockTap` |
| Order, mutasi dana, portofolio | Tidak ada. Chat CS tidak melampirkan order | Ditampilkan app OLT. Nasabah menjelaskan ke CS lewat teks atau gambar |
| Data nasabah untuk CS | Web CS hanya menampilkan identitas dari token login, riwayat tiket, dan catatan internal | Agen membuka back-office OLT bila butuh data akun |
| Aksi akun (logout paksa, kunci transaksi) | Tidak ada | Dijalankan di back-office OLT |

Akibatnya, app atau sistem lain cukup menyediakan cara memvalidasi token untuk memakai service ini.

Yang tetap keluar dari server tapi **bukan** ke sistem OLT: sertifikat Let's Encrypt dan, nanti, backup off-site. Push notification saat app tertutup belum dibangun. Bila nanti memakai FCM, itu panggilan ke layanan infrastruktur dan perlu diputuskan tersendiri.

## 2. Yang perlu disiapkan tim OLT

Satu endpoint WebSocket yang menjawab pesan `login` (bagian 3). Endpoint ini boleh berupa gateway tipis di depan sistem OLT yang sudah ada.

| Parameter | Tempat | Isi |
|---|---|---|
| `OLT_WS_URL` | `docker/.env` | URL WebSocket OLT, mis. `wss://olt.example.com/social` |
| `OLT_WS_*` (opsional) | `docker/.env` | Nama tipe pesan dan path field, **hanya bila** format OLT berbeda dari default di bawah. Daftarnya ada di [services/auth-bridge/README.md](../services/auth-bridge/README.md) |

Tidak ada token layanan atau endpoint lain yang dibutuhkan.

## 3. Protokol v1: `login`

**Transport.** WebSocket, satu pesan JSON per frame teks. Response dicocokkan lewat `request_id`. Pesan lain dari server (mis. `welcome`, `heartbeat`) diabaikan.

```jsonc
// request
{ "v": 1, "type": "login", "request_id": "<uuid>", "method": "token", "payload": { "token": "<token OLT user>" } }

// response sukses
{ "v": 1, "type": "login_result", "request_id": "<uuid>", "status": "OK",
  "data": { "token": "…", "user": { "id": "1001", "username": "budi_santoso",
            "email": "budi@example.com", "full_name": "Budi Santoso" } } }

// response gagal
{ "v": 1, "type": "login_result", "request_id": "<uuid>", "status": "ERROR",
  "error": { "code": "UNAUTHORIZED", "message": "token tidak valid" } }
```

- `user.id` adalah ID user OLT. Server menurunkan UUID sosial yang stabil darinya, jadi nilainya tidak boleh berubah.
- Semua status selain `OK` dianggap token ditolak.
- auth-bridge memakai timeout 5 detik, circuit breaker, dan cache hasil 60 detik. Saat OLT lambat atau mati, app menampilkan "Server OLT sedang tidak dapat dihubungi"; fitur yang sudah punya JWT tetap jalan sampai JWT habis.

## 4. Pengujian

- **OLT dummy** ([services/dummy-olt](../services/dummy-olt/README.md)) adalah implementasi referensi protokol ini, khusus development.
- `make up DUMMY_OLT=1` menjalankan auth-bridge mode `websocket` ke OLT dummy, persis seperti produksi.
- `make smoke-dummy` menguji alur login end-to-end lewat Kong.
