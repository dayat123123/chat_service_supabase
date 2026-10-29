# Integrasi OLT: Protokol v1 (Login, Harga, Daftar Saham, Portofolio)

> **Status:** ditetapkan 29 Okt 2026. **Satu protokol** untuk semua kebutuhan server ke OLT. Diimplementasikan bertahap: login sudah ada (auth-bridge), `market-adapter` di F1 (bersama OLT dummy), harga saat posting & daftar saham di F2, badge holder di F3.
> **Dasar:** [PROMPT-FEATURES.md](PROMPT-FEATURES.md) bagian 1 dan 3.1–3.4.

## 1. Cara pakai di produksi

Tim OLT cukup menyediakan **satu endpoint WebSocket** yang berbicara protokol di bawah. Endpoint ini bisa berupa gateway tipis di depan sistem OLT yang sudah ada.

Server sosial tidak perlu diubah kodenya. Isi **parameter** berikut saja:

| Parameter | Tempat | Isi |
|---|---|---|
| `OLT_WS_URL` | `docker/.env` | URL WebSocket OLT, mis. `wss://olt.example.com/social` |
| `olt_service_token` | `docker/secrets/` | Token service untuk header `Authorization: Bearer …` (harga, daftar saham, portofolio) |
| `OLT_WS_*` (opsional) | `docker/.env` | Nama tipe pesan & path field, **hanya bila** format OLT berbeda dari default di bawah |

Kalau format pesan OLT sudah sama dengan protokol ini, cukup isi dua parameter pertama.

Di development, OLT dummy ([`services/dummy-olt`](../services/dummy-olt/)) adalah **implementasi referensi** protokol ini. Dummy menyediakan harga tiruan yang realistis, daftar saham dari seed, dan portofolio tiruan, sehingga seluruh alur bisa dites tanpa OLT asli.

## 2. Protokol v1

### 2.1 Aturan umum

**Transport.** WebSocket, satu pesan JSON per frame teks. Satu request menghasilkan satu response, yang dicocokkan lewat `request_id`. Server boleh mengirim pesan lain (mis. heartbeat), dan klien mengabaikannya.

**Autentikasi.**
- Login user (auth-bridge) memakai token user di dalam pesan.
- Pesan service (`quote`, `instruments`, `holdings`) wajib membawa header `Authorization: Bearer <olt_service_token>` saat koneksi dibuka.

**Bentuk pesan:**

```jsonc
// request
{ "v": 1, "type": "<tipe>", "request_id": "<uuid>", "payload": { } }

// response sukses
{ "v": 1, "type": "<tipe>_result", "request_id": "<uuid>", "status": "OK", "data": { } }

// response gagal
{ "v": 1, "type": "<tipe>_result", "request_id": "<uuid>", "status": "ERROR",
  "error": { "code": "UNAUTHORIZED", "message": "token tidak valid" } }
```

**Kode error:** `UNAUTHORIZED`, `INVALID_REQUEST`, `NOT_FOUND`, `RATE_LIMITED`, `INTERNAL`.

**Satuan:**
- Harga dalam **rupiah bulat**.
- Volume dalam **lembar saham**.
- Waktu dalam **RFC 3339 UTC**.

**Batas:**
- Klien memakai timeout 5 detik per request.
- Server boleh membalas `RATE_LIMITED`. Klien membalasnya dengan circuit breaker dan cache, bukan retry beruntun.

### 2.2 `login`: verifikasi token user (auth-bridge, sudah berjalan)

```jsonc
// request
{ "v": 1, "type": "login", "request_id": "…", "method": "token", "payload": { "token": "<token OLT user>" } }

// response
{ "v": 1, "type": "login_result", "request_id": "…", "status": "OK",
  "data": { "token": "…", "user": { "id": "1001", "username": "budi_santoso",
            "email": "budi@example.com", "full_name": "Budi Santoso" } } }
```

`user.id` adalah ID user OLT, dipakai untuk UUID sosial yang stabil. Default auth-bridge sama dengan pesan di atas (`request_id` = UUID baru per login), jadi cukup `OLT_WS_URL`. Bila format OLT berbeda, timpa lewat `OLT_WS_LOGIN_TEMPLATE`, `OLT_WS_USER_ID_PATH`, dll. Profil `compose.dummy-olt.yml` hanya mengisi `OLT_WS_URL`.

### 2.3 `quote`: harga terakhir (market-adapter)

```jsonc
// request (maks 50 kode)
{ "v": 1, "type": "quote", "request_id": "…", "payload": { "codes": ["BBCA", "GOTO"] } }

// response
{ "v": 1, "type": "quote_result", "request_id": "…", "status": "OK",
  "data": { "quotes": [
    { "code": "BBCA", "last": 9250, "prev_close": 9200, "change": 50, "change_pct": 0.54,
      "volume": 12345600, "time": "2026-10-29T02:15:00Z", "status": "active" }
  ] } }
```

- Kode yang tidak dikenal tidak dimasukkan ke `quotes`.
- `status` bernilai `active` atau `suspended`.

### 2.4 `instruments`: daftar saham (sinkron harian)

```jsonc
// request
{ "v": 1, "type": "instruments", "request_id": "…", "payload": {} }

// response
{ "v": 1, "type": "instruments_result", "request_id": "…", "status": "OK",
  "data": { "instruments": [
    { "code": "BBCA", "name": "Bank Central Asia Tbk", "sector": "Financials",
      "board": "Utama", "type": "stock", "status": "active" }
  ] } }
```

- `type` bernilai `stock`, `index`, `etf`, `warrant`, atau `right`.
- `status` bernilai `active`, `suspended`, atau `delisted`.
- Saham yang tidak lagi muncul ditandai `delisted`, bukan dihapus.

### 2.5 `holdings`: status kepemilikan (badge holder, opt-in)

```jsonc
// request: hanya untuk user yang mengaktifkan badge holder
{ "v": 1, "type": "holdings", "request_id": "…", "payload": { "user_id": "1001", "codes": ["BBCA", "GOTO"] } }

// response: HANYA daftar kode yang dipegang, tanpa lot/nilai/harga beli
{ "v": 1, "type": "holdings_result", "request_id": "…", "status": "OK",
  "data": { "user_id": "1001", "held": ["BBCA"] } }
```

- Protokol sengaja tidak punya field jumlah, sehingga data sensitif tidak pernah dikirim ke server sosial.
- Server sosial hanya menyimpan `holds` (boolean) dan `verified_at` per saham.

## 3. Komponen di server sosial

```
 App OLT ── stream harga OLT yang sudah ada ──▶ OltMarketDataProvider ──▶ kartu saham live
 Postgres ── antrean (FOR UPDATE SKIP LOCKED) ──▶ market-adapter ──▶ Valkey (cache 1–3 dtk, lock)
    ▲                                              (Go, stateless)  │
    └──── RPC service_role: tulis hasil ◀──────────────────────────┴──▶ OLT (protokol v1)
```

### `market-adapter` (F1)

- **Teknologi:** Go dan image distroless, seperti auth-bridge.
- **Network:**
  - Bergabung ke `app`, `data` (Valkey), dan `egress`.
  - Tidak dirutekan Kong/Traefik, jadi tidak bisa diakses dari internet.
  - Pemanggil wajib membawa service key internal.
- **Endpoint internal:**
  - `GET /quote/{code}` dan `POST /quotes`;
  - `GET /livez` dan `/readyz`;
  - `/metrics`.
- **Cache dan beban:**
  - Cache per kode di Valkey dengan TTL 1–3 detik.
  - *Single-flight* lewat lock Valkey, sehingga hanya ada satu request ke OLT per kode per TTL.
  - Rate limit keluar ke OLT.
- **Ketahanan:**
  - Timeout dan circuit breaker.
  - Kalau OLT lambat atau mati, respons berisi `available: false`, dan kartu menampilkan "harga tidak tersedia". Fitur sosial lain tetap jalan.

### Harga saat posting (F2)

1. Trigger `post_stocks` menandai baris baru `price_status = 'pending'`. Kolom harga hanya bisa ditulis `service_role`, jadi harga dari client diabaikan.
2. Worker `market-adapter` mengambil antrean (`SKIP LOCKED`), lalu menulis `price_at_post` dan `price_at_post_time` (waktu quote dari bursa).
3. Kalau harga tidak tersedia dalam N detik, baris ditandai `unavailable`.

### Sinkron daftar saham (F2)

Job harian di `market-adapter` (dengan lock Valkey: sekali per cluster) mengirim pesan `instruments`, lalu memanggil `sync_stocks` (diperluas dengan `board` dan `status`).

### Badge holder (F3)

- Default **mati**. Hanya user yang mengaktifkannya yang diperiksa lewat `holdings`.
- Pemeriksaan dilakukan saat posting (asinkron) dan berkala.
- Kalau saham dijual, badge dicabut otomatis pada pemeriksaan berikutnya.
- Data disimpan di `user_holdings_flags(user_id, stock_code, holds, verified_at)`.

## 4. Sisi Flutter: parameter untuk app OLT

App OLT produksi punya struktur sendiri. Agar tetap kompatibel, package hanya meminta **adapter** lewat parameter `initialize`:

```dart
await OltSocial.initialize(
  supabaseUrl: 'https://social-api.domain.com',
  anonKey: '...',
  oltTokenProvider: () async => oltAuth.currentToken,  // sudah ada
  marketData: OltPriceAdapter(oltPriceService),          // F1/F2: opsional
  onStockTap: (context, code) => openOltStockPage(code), // sudah ada
);

/// Contoh adapter di app OLT: membungkus stream harga yang sudah dimiliki OLT.
class OltPriceAdapter implements OltMarketDataProvider {
  OltPriceAdapter(this._prices);
  final PriceService _prices; // class milik OLT

  @override
  Stream<StockQuote> watchQuote(String code) => _prices.stream(code).map(
        (p) => StockQuote(code: code, last: p.last, prevClose: p.prevClose, time: p.time),
      );

  @override
  Future<StockQuote?> getQuote(String code) async => (await _prices.snapshot(code))?.toStockQuote();
}
```

- **Tanpa `marketData`:** kartu saham tetap tampil, hanya tanpa harga.
- **App contoh:** memakai adapter mock.
- **Panduan lengkap:** [INTEGRATION.md](INTEGRATION.md) diperbarui saat F2.

## 5. Pengujian

- **OLT dummy** mengimplementasikan `quote`, `instruments`, dan `holdings`. Ada juga endpoint dev untuk "membeli/menjual" saham tiruan.
- **Tes otomatis:**
  - harga dari client diabaikan;
  - single-flight bekerja (satu request ke OLT per TTL);
  - circuit breaker terbuka saat OLT lambat;
  - badge hilang setelah saham dijual;
  - lot dan nilai tidak pernah tersimpan atau masuk log.
