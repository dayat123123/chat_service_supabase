# Integrasi OLT: Notifikasi Transaksi dan Bot Resmi

Dokumen ini untuk **tim OLT** (backend trading, notifEngine, app). Isinya dua hal:

1. **Klaim `accounts`** di token sosial, supaya server sosial tahu rekening (cust id) mana milik login mana.
2. **API gateway integrasi** (`/integration/v1`): notifEngine cukup mengirim `cust_id` + isi pesan saat order match, lalu server sosial mengirim push (dan bila diminta, notifikasi di kotak masuk aplikasi) ke semua HP pemilik rekening itu. Dengan izin tambahan, API yang sama bisa **menyiarkan** pesan ke daftar user OLT, semua pengguna, atau pemantau satu saham (bagian 2a). API yang sama dipakai bot resmi (berita, aksi korporasi) untuk memposting di feed.

Dengan ini notifEngine tidak perlu lagi tahu perangkat, token FCM, atau Google OAuth.

```
Login app OLT ──▶ OLT menerbitkan token sosial {sub, ..., accounts:["W137","C1626"]}
                    │
                    ▼  POST /bridge/v1/exchange
               auth-bridge ──▶ private.account_links (W137 → budi, C1626 → budi)

Order match ──▶ notifEngine ──POST /integration/v1/notify/messages {cust_id:"W137", ...}──▶ integration
                                                                                              │ API key, IP, rate limit
                                                                                              ▼
                              W137 → profil budi → preferensi push → antrean push (1 baris per HP)
                                                                                              │
                                                                         notifier ──FCM──▶ HP budi
```

Tidak ada koneksi dari server sosial ke OLT. Arah panggilan selalu OLT → server sosial.

## 1. Klaim `accounts` di token sosial

Tambahkan satu klaim opsional di payload token sosial (format token lengkap: [docs/olt-integration.md](../olt-integration.md)):

```jsonc
{
  "iss": "olt", "aud": "olt-social", "sub": "1001", "preferred_username": "budi_santoso",
  "iat": 1793440000, "exp": 1793440600,
  "accounts": ["W137", "C1626"]   // cust id rekening yang DIMILIKI login ini
}
```

**Aturan isi (dari sisi OLT):**

| LoginType | Isi `accounts` |
|---|---|
| 1 (nasabah) | Semua `AccountId` di `TAccountLinked` milik login itu |
| 2 (sales), 3 (cabang), 4 (pusat) | `[]`. Login staf **tidak boleh** menerima notifikasi transaksi rekening nasabah lewat jalur ini |

**Format:**
- Array string, maksimal **50** item. Tiap item `^[A-Za-z0-9._-]{1,32}$`.
- Huruf besar/kecil tidak dibedakan (disimpan huruf besar), sama seperti collation SQL Server OLT. `w137` dan `W137` dianggap sama.
- Item yang salah format diabaikan (token tetap diterima). Klaim yang bukan array diabaikan seluruhnya.

**Perilaku server sosial:**

| Klaim | Hasil |
|---|---|
| Tidak ada | Tautan rekening login itu **tidak diubah**. OLT versi lama tetap jalan |
| `[]` | Semua tautan rekening login itu **dilepas** |
| `["W137", ...]` | Tautan login itu **diganti** persis dengan isi array setiap kali token ditukar |

- Tautan diperbarui setiap kali app menukar token sosial (login, perpanjangan token). Tautan yang tidak diperbarui selama **30 hari** (`integration.account_link_days`) tidak dipakai lagi, jadi nasabah yang lama tidak membuka app tidak menerima push untuk rekening yang mungkin sudah dipindah.
- Satu rekening boleh tertaut ke lebih dari satu login (misalnya rekening bersama). Semua login itu menerima push.
- Rekening dihapus dari `TAccountLinked` → hilang dari klaim → tautan dilepas pada penukaran token berikutnya (≤ 10–15 menit selama app aktif).
- Akun sosial dihapus nasabah → semua tautannya ikut dihapus. Daftar rekening tertaut ikut diekspor di "Unduh data saya".

**Kenapa dari token, bukan dari app?** Daftar rekening dari app bisa dipalsukan oleh app yang dimodifikasi untuk menerima notifikasi rekening orang lain. Token sosial ditandatangani kunci privat OLT, jadi hanya OLT yang bisa menyatakan kepemilikan rekening.

## 2. API notifEngine: `POST /integration/v1/notify/messages`

### Akses

| Item | Nilai |
|---|---|
| URL produksi | `https://<domain API sosial>/integration/v1/notify/messages` |
| Header wajib | `apikey: <ANON_KEY>` (sama dengan app), `Authorization: Bearer <API key integrasi>`, `Content-Type: application/json` |
| API key integrasi | Dibuat Super Admin di web CS. Berawalan `oik_`, **hanya ditampilkan sekali**. Simpan di konfigurasi rahasia notifEngine, jangan di kode atau log |
| Izin (scope) | `notify`. Target selain `cust_id` (siaran) butuh izin tambahan `notify_broadcast` |
| IP pengirim | Bila Super Admin mengisi daftar IP/CIDR pada key, request dari IP lain ditolak `403 ip_not_allowed` |
| Batas | Maks **500 pesan** per request, body maks **2 MiB**, `rate_limit_per_minute` request per key (default 600) |

### Body

```json
{
  "messages": [
    {
      "id": "trade-20261103-IDX-000123",
      "cust_id": "W137",
      "kind": "olt.trade",
      "title": {"id": "Order BBCA match", "en": "BBCA order matched"},
      "body": {"id": "Beli 10 lot BBCA @ 9.250", "en": "Buy 10 lots BBCA @ 9,250"},
      "data": {"order_id": "O-77", "stock": "BBCA", "side": "B"},
      "ttl_seconds": 3600,
      "collapse_key": "order-O-77",
      "priority": "high"
    }
  ]
}
```

| Field | Wajib | Aturan |
|---|---|---|
| `id` | ya | Id unik event, `^[A-Za-z0-9._:-]{1,100}$`. Kunci idempotensi (bagian 3) |
| `cust_id` | ya* | String, format sama dengan klaim `accounts`. *Tidak dipakai (harus kosong) bila `target` diisi |
| `target` | tidak | Objek, salah satu dari: `{"cust_id": "W137"}` (sama dengan `cust_id`), `{"olt_user_ids": ["1001", ...]}`, `{"audience": "all"}`, `{"audience": "stock_watchers", "stock": "BBCA"}`. Selain `cust_id` disebut **siaran** (bagian 2a) |
| `kind` | tidak | Default `olt.trade` untuk `cust_id`, `olt.info` untuk siaran. Harus berawalan `olt.`, huruf kecil/angka/`_`, dipisah titik, maks 40 karakter. Contoh: `olt.trade`, `olt.trade.partial`, `olt.order.rejected`, `olt.deposit.received`, `olt.ipo.offer`. Aplikasi memakai `kind` untuk memilih layar; `kind` juga menentukan jenis preferensi nasabah (bagian 2b) |
| `title` | ya | String 1–200 karakter, atau objek `{"id": "...", "en": "..."}`. HP menampilkan sesuai bahasa aplikasi |
| `body` | tidak | String ≤ 1000 karakter atau objek `{"id","en"}` |
| `data` | tidak | Objek, maks 2 KB. Nilai dikirim ke app sebagai string. Server menambahkan `kind`, `source: "olt"`, `message_id`, `cust_id` (target rekening), `category` (bila dikirim, selalu untuk siaran), dan `notification_id` (bila juga masuk kotak notifikasi) |
| `ttl_seconds` | tidak | 60–2419200. Push yang belum terkirim setelah ini dibuang. Default 24 jam; untuk order match disarankan `3600` |
| `collapse_key` | tidak | 1–64 karakter. Push dengan kunci sama saling menimpa di HP (mis. beberapa partial fill satu order) |
| `priority` | tidak | `high` (default) atau `normal` |
| `channels` | tidak | Subset `["push", "inbox"]`. Default `["push"]` untuk `cust_id` (perilaku lama), `["push", "inbox"]` untuk siaran. `inbox` = notifikasi di kotak masuk aplikasi sosial |
| `category` | tidak | `important`, `info` (default), atau `promo`. Lihat bagian 2b |

Tanpa `channels`, push transaksi **hanya** dikirim ke HP dan tidak masuk kotak notifikasi aplikasi sosial (riwayat transaksi tetap milik app OLT). Dengan `"channels": ["push", "inbox"]` pesan juga masuk kotak notifikasi sebagai pengumuman OLT (judul, isi, `kind`, `category`, `data`); ketukan diteruskan ke aplikasi host (`onOltNotificationTap` di paket Flutter). Push tetap satu per HP walaupun pesan juga masuk kotak notifikasi.

### Contoh `curl`

```bash
curl -sS -X POST "https://api.contoh.co.id/integration/v1/notify/messages" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $OLT_INTEGRATION_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Request-Id: notif-batch-000123" \
  -d '{"messages":[{"id":"trade-20261103-000123","cust_id":"W137","title":"Order BBCA match","body":"Beli 10 lot BBCA @ 9.250","ttl_seconds":3600}]}'
```

### Respons 200 (per pesan)

```json
{
  "results": [
    {"index": 0, "id": "trade-20261103-000123", "status": "queued", "devices": 2},
    {"index": 1, "id": "trade-20261103-000124", "status": "no_recipient"},
    {"index": 2, "id": "trade-20261103-000123", "status": "duplicate"},
    {"index": 3, "id": "trade-x", "status": "invalid", "error": "invalid_title"},
    {"index": 4, "id": "promo-ipo-20261103", "status": "accepted", "broadcast_id": "6f1c2a54-0b9e-4c55-9a52-0d5f3f0c2b11"}
  ],
  "queued": 1, "devices": 2, "no_recipient": 1, "duplicate": 1, "invalid": 1, "accepted": 1, "inbox": 0
}
```

| `status` | Arti | Tindakan notifEngine |
|---|---|---|
| `queued` | Masuk antrean push untuk `devices` HP (dan `inbox` notifikasi kotak masuk bila `channels` memuat `inbox`) | Selesai |
| `accepted` | Siaran diterima; dikirim bertahap oleh server (bagian 2a). `broadcast_id` untuk dilacak di web CS | Selesai |
| `no_recipient` | Rekening belum tertaut ke login sosial aktif, pemilik belum mendaftarkan HP, atau mematikan push jenis ini | Selesai, jangan kirim ulang |
| `duplicate` | `id` ini sudah diterima dalam 7 hari terakhir (siaran: `broadcast_id` yang sama disertakan) | Selesai |
| `invalid` | Format salah. `error`: `invalid_message`, `invalid_id`, `invalid_cust_id`, `invalid_target`, `invalid_kind`, `invalid_title`, `invalid_body`, `invalid_data`, `invalid_ttl`, `invalid_collapse_key`, `invalid_priority`, `invalid_channels`, `invalid_category`, atau `scope_forbidden` (siaran dengan key tanpa izin `notify_broadcast`) | Perbaiki lalu kirim pesan itu saja |

`200` artinya batch diproses seluruhnya; status tiap pesan ada di `results` sesuai urutan (`index` mulai 0).

### Kode error batch

Format: `{"error": "<kode>", "message": "<penjelasan>"}` + header `X-Request-Id`.

| HTTP | `error` | Arti | Kirim ulang? |
|---|---|---|---|
| 400 | `invalid_json`, `invalid_batch` | Body bukan JSON atau `messages` bukan array 1–500 | Tidak, perbaiki |
| 401 | `missing_key`, `invalid_key` | Key tidak ada, salah, nonaktif, atau dicabut | Tidak, periksa key |
| 403 | `ip_not_allowed`, `scope_forbidden` | IP pengirim tidak diizinkan / key tanpa izin `notify` | Tidak |
| 413 | `body_too_large` | Body > 2 MiB | Pecah batch |
| 429 | `rate_limited`, `too_many_auth_failures` | Batas per menit key / terlalu banyak key salah dari IP itu | Ya, setelah `Retry-After` |
| 502 | kode lain | Respons tak terduga dari database | Ya, dengan backoff |
| 503 | `unavailable`, `busy` | Database tidak terjangkau / server sibuk | Ya, batch yang **sama**, setelah `Retry-After` |

## 2a. Siaran: `target` selain `cust_id`

Untuk informasi pasar, IPO, pengumuman layanan, atau promo ke banyak nasabah sekaligus. Butuh API key dengan izin `notify` **dan** `notify_broadcast` (Super Admin memberi izin ini secara terpisah karena bisa menjangkau semua pengguna).

| `target` | Penerima |
|---|---|
| `{"olt_user_ids": ["1001", "1002"]}` | Login OLT (`sub` token sosial) yang sudah punya profil sosial aktif. 1–500 id (string atau angka, `^[A-Za-z0-9._-]{1,64}$`, duplikat diabaikan); id tanpa profil dilewati |
| `{"audience": "all"}` | Semua profil aktif (belum dihapus, bukan akun resmi/staf) |
| `{"audience": "stock_watchers", "stock": "BBCA"}` | Pengguna yang memantau saham itu (watchlist sosial). Kode `^[A-Z][A-Z0-9]{1,11}$`, huruf kecil diubah besar |

- **Asinkron.** Setiap pesan siaran menjadi satu job (`private.integration_broadcasts`) dan langsung dijawab `accepted` + `broadcast_id`. Cron `integration-broadcasts` (tiap 15 detik) mengirimnya bertahap, `integration.broadcast_batch_size` (2.000) profil per putaran berurutan id profil, sehingga `audience: all` tidak membebani satu request. Target `cust_id` tetap sinkron seperti sebelumnya.
- **Batas frekuensi.** Siaran selain kategori `important` dikirim maksimal `integration.broadcast_daily_cap` (3) kali per nasabah per hari WIB (gabungan semua key). Nasabah yang sudah mencapai batas dilewati dan dihitung `capped`.
- **Status job:** `queued` → `sending` → `done`, atau `failed` (mis. key dinonaktifkan/dicabut atau izin `notify_broadcast` dicabut sebelum selesai: `error = key_inactive`). Penghitung: `targeted` (profil diproses), `recipients` (menerima push dan/atau kotak masuk), `devices`, `inbox`, `capped`, `pref_skipped` (kanal yang diminta dimatikan nasabah). Super Admin melihatnya di web CS (Integrasi → key → Broadcast).
- Push siaran memakai `ttl_seconds`/`collapse_key`/`priority` yang sama; masa berlaku dihitung dari saat batch dikirim.

```bash
curl -sS -X POST "https://api.contoh.co.id/integration/v1/notify/messages" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $OLT_BROADCAST_KEY" -H "Content-Type: application/json" \
  -d '{"messages":[{"id":"ipo-ABCD-20261103","target":{"audience":"all"},"kind":"olt.ipo.offer","category":"promo",
        "title":{"id":"IPO ABCD dibuka","en":"ABCD IPO is open"},"body":"Masa penawaran 3–5 Nov 2026","ttl_seconds":86400}]}'

curl -sS -X POST "https://api.contoh.co.id/integration/v1/notify/messages" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $OLT_BROADCAST_KEY" -H "Content-Type: application/json" \
  -d '{"messages":[{"id":"ca-BBCA-suspend-20261103","target":{"audience":"stock_watchers","stock":"BBCA"},
        "kind":"olt.corporate_action.suspend","category":"important","channels":["push","inbox"],
        "title":"BBCA disuspensi bursa","body":"Perdagangan BBCA dihentikan sementara mulai sesi I."}]}'

curl -sS -X POST "https://api.contoh.co.id/integration/v1/notify/messages" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $OLT_BROADCAST_KEY" -H "Content-Type: application/json" \
  -d '{"messages":[{"id":"rdn-maint-20261103","target":{"olt_user_ids":["1001","1002"]},"kind":"olt.rdn.maintenance",
        "title":"Pemeliharaan RDN","body":"Top up RDN tidak tersedia pukul 23.00–24.00 WIB."}]}'
```

## 2b. Kategori dan preferensi nasabah

Nasabah mengatur notifikasi OLT per jenis di aplikasi (kotak masuk dan push terpisah). Jenis ditentukan dari `kind` dan `category`:

| Preferensi (label app) | Pesan | Bawaan |
|---|---|---|
| `olt.trade` (Transaksi) | `kind` berawalan `olt.trade` atau `olt.order` | kotak masuk + push aktif |
| `olt.funds` (Dana) | `olt.deposit*`, `olt.withdrawal*`, `olt.rdn*` | kotak masuk + push aktif |
| `olt.market` (Pasar) | `olt.price_alert*`, `olt.ipo*`, `olt.corporate_action*` | kotak masuk + push aktif |
| `olt.info` (Info) | `olt.*` lainnya | kotak masuk + push aktif |
| `olt.promo` (Promo) | `category: "promo"` (apa pun `kind`-nya) | kotak masuk aktif, **push mati** sampai nasabah mengaktifkan |

- `important`: **menembus** preferensi per jenis dan jam tenang (push tidak ditunda), dan tidak dihitung ke batas frekuensi siaran. Tetap hanya ke HP yang terdaftar. Pakai hanya untuk informasi yang wajib diketahui nasabah (suspensi, gangguan layanan, keamanan akun).
- `info` (default): mengikuti preferensi jenisnya dan jam tenang (push ditunda sampai jam tenang selesai).
- `promo`: mengikuti preferensi `olt.promo` (push opt-in) dan jam tenang.
- Nasabah yang sebelum perubahan ini mematikan push `olt.trade` (dulu mencakup semua `olt.*`) otomatis juga mematikan push Dana, Pasar, dan Info.

## 3. Idempotensi dan kirim ulang

- `id` diingat **7 hari** per API key (`integration.receipt_days`). Kiriman dengan `id` yang sama dalam 7 hari dijawab `duplicate` dan tidak menimbulkan push kedua. Ini berlaku juga untuk siaran: siaran yang sama tidak dibuat dua kali, dan `duplicate` menyertakan `broadcast_id` siaran pertama.
- Buat `id` dari data event yang stabil, bukan dari waktu kirim. Contoh: `trade-<tanggal>-<nomor trade bursa>`, atau `order-<orderId>-fill-<seq>`. Jangan memakai UUID acak per percobaan.
- Bila koneksi putus, timeout, atau mendapat 429/5xx, **kirim ulang batch yang sama persis**. Pesan yang ternyata sudah diterima akan dijawab `duplicate`. Backoff yang disarankan: 1, 2, 4, 8, … detik (maks 60 detik) + jitter, ikuti `Retry-After` bila ada, berhenti setelah ± 10 menit (push transaksi sudah basi).
- Satu batch diproses dalam satu transaksi database: kalau server gagal di tengah, tidak ada pesan yang tersimpan, jadi kirim ulang aman.
- Jangan kirim ulang `no_recipient` dan `invalid` dengan `id` yang sama berharap hasil berbeda. Untuk `invalid`, perbaiki isinya; `id` tidak dicatat sehingga boleh dipakai lagi.
- Mengganti API key (rotasi) memulai catatan idempotensi baru. Hindari rotasi saat masih ada batch yang sedang di-retry.

## 4. Bot resmi: `POST /integration/v1/bot/posts`

Untuk sistem otomatis (berita pasar, aksi korporasi) yang memposting atas nama **akun resmi**. Butuh API key dengan izin `bot_post`; key itu terikat ke satu akun resmi yang dipilih Super Admin. Postingan langsung terbit (tanpa persetujuan empat mata) dan diberi label **Bot** di feed.

```bash
curl -sS -X POST "https://api.contoh.co.id/integration/v1/bot/posts" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $BOT_KEY" -H "Content-Type: application/json" \
  -d '{"posts":[{"id":"ca-BBCA-20261103-dividen","body":"Aksi korporasi $BBCA: dividen tunai Rp 270/saham, cum date 10 Nov 2026."}]}'
```

| Field | Aturan |
|---|---|
| `id` | `^[A-Za-z0-9._:-]{1,100}$`, unik per key **selamanya** (bukan hanya 7 hari) |
| `body` | 1–2000 karakter. `$KODE` menautkan ke stream saham. Maks 3 link, 10 mention, 10 kode saham |

Maks 50 postingan per request dan `integration.bot_posts_per_hour` (default 30) postingan per key per jam.

| `status` | Arti |
|---|---|
| `published` | Terbit, `post_id` disertakan. `moderation_status` `visible` atau `held` (ditahan kebijakan konten untuk ditinjau) |
| `duplicate` | `id` ini sudah pernah diterbitkan; `post_id` yang sama dikembalikan |
| `rejected` | Ditolak kebijakan konten (`error`: mis. `content_blocked`, `too_many_links`). Tidak dicatat, boleh dikirim ulang setelah diperbaiki |
| `invalid` | `invalid_id` / `invalid_body` |
| `rate_limited` | Batas per jam tercapai; kirim ulang nanti |

Batch ditolak `409 official_inactive` bila akun resminya dinonaktifkan. Staf bisa menyematkan atau menghapus postingan bot dari menu Komunitas seperti postingan resmi lain.

## 5. Mengelola API key (Super Admin)

RPC untuk web CS (semua tercatat di Kepatuhan → Jejak Audit sebagai `integration.key_create`, `integration.key_update`, `integration.key_revoke`, tanpa isi key; pemberian/pencabutan `notify_broadcast` terlihat di perubahan `scopes`):

| RPC | Isi |
|---|---|
| `cs_api.integration_keys()` | Daftar key: nama, prefix (`oik_AbCdEfGh…`), izin, akun resmi, CIDR, batas, status, terakhir dipakai + IP |
| `cs_api.integration_key_create(name, scopes, official_account_id, allowed_cidrs, rate_limit_per_minute)` | Membuat key. `scopes` ⊂ {`notify`, `notify_broadcast`, `bot_post`}; `notify_broadcast` wajib disertai `notify`. Respons memuat `key` **sekali saja**; yang disimpan hanya hash SHA-256 |
| `cs_api.integration_key_update(id, name, scopes, official_account_id, allowed_cidrs, rate_limit_per_minute, enabled)` | Ubah atau nonaktifkan sementara (`enabled=false`) |
| `cs_api.integration_key_revoke(id, reason)` | Cabut permanen, alasan 5–500 karakter |
| `cs_api.integration_stats(days)` | Per key: diterima, masuk antrean, perangkat, tanpa penerima, duplikat, tidak valid, siaran diterima (`accepted`), kotak masuk (`inbox`), postingan bot, ringkasan siaran (`broadcasts`: total, aktif, selesai, gagal, penerima, perangkat, kotak masuk, `capped`, `pref_skipped`), serta hasil kirim FCM (terkirim, gagal, token mati, kedaluwarsa, menunggu). Juga total siaran semua key dan jumlah rekening/profil tertaut |
| `cs_api.integration_stats_daily(days, key_id)` | Statistik per hari per key, dipotong per tanggal WIB |
| `cs_api.integration_broadcasts(key_id = null, limit = 50)` | Daftar siaran terbaru (maks 200): key, `message_id`, `kind`, judul, kategori, kanal, ringkasan target (`olt_user_ids` + jumlah, `all`, `stock_watchers` + kode), status, penghitung, error, waktu dibuat/mulai/selesai |

**Rotasi:** buat key baru → pasang di notifEngine → pastikan "terakhir dipakai" key baru bergerak → cabut key lama. Key yang dicabut atau dinonaktifkan langsung ditolak (cache layanan paling lama 30 detik, dan database memeriksa ulang setiap batch).

Isi `allowed_cidrs` dengan IP server notifEngine sebagaimana terlihat dari server sosial (mis. `10.20.0.0/16`, `203.0.113.7`).

Beri `notify_broadcast` hanya ke key sistem OLT yang tepercaya dan dibatasi IP; key itu bisa mengirim notifikasi ke semua pengguna. Sebaiknya pisahkan key transaksi (`notify`) dari key siaran (`notify` + `notify_broadcast`).

## 6. Yang bisa dihapus dari notifEngine

Setelah klaim `accounts` dan API ini dipakai, notifEngine cukup: **deteksi order match → POST `cust_id` + pesan**. Bagian berikut tidak diperlukan lagi:

- **Registry perangkat di memori** (`UserDataManager` dan sejenisnya): pemetaan user/rekening → token FCM sekarang di server sosial (`private.push_devices`, didaftarkan app lewat `registerPushToken`).
- **Sinkronisasi `TUserDevices`**: tabel token perangkat di SQL Server dan job sinkronnya. App tidak perlu lagi mengirim token FCM ke OLT.
- **Kode Google OAuth / service account dan pengirim FCM** (pembuatan access token, HTTP v1 `messages:send`, penanganan token kedaluwarsa/`UNREGISTERED`, retry FCM). Kunci Firebase dikelola Super Admin di web CS; layanan notifier menangani retry, token mati, iOS/APNs, dan batas perangkat.
- **Pencarian login dari rekening** untuk menentukan penerima: server sosial memakai tautan dari klaim `accounts`.

Yang tetap di OLT: menerbitkan token sosial (dengan `accounts`), mendeteksi event, menyusun teks pesan, dan memberi `id` event yang stabil.

**Migrasi bertahap yang disarankan:** (1) terbitkan klaim `accounts` dan biarkan app berjalan ± 1 hari supaya tautan terisi; (2) kirim ke API ini paralel dengan jalur lama untuk sebagian kecil `cust_id`, bandingkan dengan `integration_stats`; (3) matikan jalur FCM lama.

## 7. Mencoba di lingkungan dev

OLT dummy sudah menerbitkan `accounts`: `budi_santoso` → `W137`, `C1626`; `sari_invest` → `S2001`; akun lain `[]` ([services/dummy-olt](../../services/dummy-olt/README.md)).

1. `make up DUMMY_OLT=1`, login budi di app contoh (atau `curl` ke dummy) lalu tukar token, dan daftarkan perangkat push.
2. Buat API key `notify` di web CS (Super Admin).
3. Kirim pesan `cust_id` `W137` dengan `curl` di atas ke `http://localhost:8000/integration/v1/notify/messages` (butuh layanan `integration` dan rute Kong `/integration/v1/`, lihat [services/integration](../../services/integration/README.md#pemasangan)).
4. Periksa hasilnya di `results`, statistik di web CS, atau `private.push_queue`.
5. Siaran: buat key dengan izin `notify` + `notify_broadcast`, kirim `{"target":{"olt_user_ids":["1001"]},"channels":["push","inbox"],...}`. Hasilnya `accepted`; dalam ≤ 15 detik budi menerima satu notifikasi kotak masuk dan satu push per HP (lihat Integrasi → key → Broadcast di web CS).

Detail teknis layanan: [services/integration](../../services/integration/README.md). Migrasi: `supabase/migrations/0068_integration.sql`, `0086_notify_targets.sql`; tes `supabase/tests/048_integration_test.sql`, `065_notify_targets_test.sql`.
