# Kebutuhan Data & Aksi dari OLT untuk `customer-adapter`

> **Untuk:** tim backend dan infrastruktur OLT.
> **Dari:** tim pengembang OLT Social, fitur customer service lewat chat.
> **Dasar:** [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) bagian 1.1, 4.1, dan 5. Protokol yang dipakai: [market-integration.md](../market-integration.md) (Protokol v1).

## Ringkasan

- Saat menangani chat, agen CS perlu **membaca** data nasabah dari OLT supaya nasabah tidak perlu mengulang cerita: profil, order terakhir, transaksi dana terakhir, perangkat/sesi login, dan status keamanan akun.
- Hanya ada **dua aksi** ke OLT:
  - "Amankan akun" (untuk laporan peretasan);
  - "Permintaan konfirmasi identitas" (disetujui nasabah di aplikasi OLT).

  Tidak ada aksi transaksi dan tidak ada perubahan data nasabah dari panel CS.
- Data **tidak disalin** ke database CS. Kartu order di chat hanya menyimpan ID order. Isinya diambil langsung dari OLT setiap kali ditampilkan.
- Setiap akses tercatat di audit log: agen, sesi chat, data apa, dan kapan. Setiap request ke OLT membawa `correlation_id` (ID sesi + kode agen) bila OLT juga ingin mencatatnya.
- **Usulan:** pakai Protokol v1 yang sudah disepakati untuk login, harga, daftar saham, dan portofolio. Usulan tipe pesannya ada di lampiran.
  - Bila OLT punya API lain (gRPC ClientEngine, REST internal), mohon dokumentasinya. Adapter akan menyesuaikan.
- **Development:** OLT dummy di repo kami sudah mengimplementasikan semua pesan di lampiran sebagai referensi ([`services/dummy-olt`](../../services/dummy-olt/README.md)).

Bila sebagian data belum tersedia, chat CS tetap jalan. Bagian panel yang datanya belum ada akan menampilkan "tidak tersedia".

## 1. Koneksi dan keamanan

1. **Endpoint.**
   - Apakah pesan-pesan di lampiran bisa dilayani endpoint WebSocket Protokol v1 yang sama?
   - Atau perlu endpoint atau protokol terpisah?
   - Mohon URL untuk development/UAT dan produksi.
2. **Autentikasi antar-service.** Data nasabah lebih sensitif dari harga. Kami mengusulkan **kredensial terpisah** dengan cakupan hanya-baca data nasabah plus dua aksi.
   - Bentuknya bisa token service berbeda dari `olt_service_token`, mTLS, atau mekanisme lain yang Anda pakai.
   - Bagaimana rotasi kredensialnya?
3. **Jaringan.** Dari mana adapter boleh terhubung: IP allowlist, VPN site-to-site, atau jaringan privat? Mohon port dan aturan firewall-nya.
4. **Batas dan isolasi.** CS tidak boleh mengganggu trading. Mohon informasi berikut:
   - rate limit untuk request data nasabah;
   - latensi tipikal dan p95;
   - jendela maintenance;
   - perilaku saat jam bursa ramai;
   - apakah request CS bisa diarahkan ke instance/replika terpisah, misalnya replika baca.
5. **Jejak audit di sisi OLT.** Apakah OLT mencatat akses data oleh service? Apakah `correlation_id` (ID sesi + kode agen) cukup?
6. **Lingkungan uji.** Apakah ada UAT/sandbox dengan akun nasabah tiruan untuk uji integrasi?

## 2. Identitas nasabah

1. **ID yang stabil.** ID mana yang unik dan tidak pernah berubah?
   - `user.id` (sudah dipakai login/auth-bridge, dan dipakai adapter);
   - kode nasabah (client code);
   - SID;
   - nomor RDN.

   Apakah satu user bisa punya beberapa akun (reguler, margin, syariah)? Bila ya, bagaimana relasinya?
2. **Status akun.** Status apa saja yang mungkin (aktif, dibekukan, dorman, ditutup, KYC tertunda), dan apa arti masing-masing?
3. **Nasabah prioritas (VIP).** Matching engine mengutamakan agen khusus untuk nasabah prioritas. Apakah OLT punya penanda segmen/tier nasabah yang bisa kami baca?

## 3. Data yang dibutuhkan (hanya-baca)

Untuk setiap kelompok data, mohon informasi berikut:
- apakah tersedia;
- nama dan format field;
- seberapa jauh riwayatnya;
- dukungan filter dan pagination.

Tanda **(S)** = data sensitif.

**Usulan kami:** OLT mengirim data sensitif dalam bentuk **sudah disamarkan** secara default, dan menyediakan permintaan terpisah untuk membuka **satu field** (`customer_reveal`). Dengan begitu, data lengkap hanya keluar saat agen membukanya dengan alasan. Adapter juga menyamarkan sekali lagi sebagai pengaman.

| Kelompok | Field yang dibutuhkan | Dipakai untuk |
|---|---|---|
| **Profil** | Nama lengkap, nama panggilan, kode nasabah, SID (S), NIK (S), email (S), nomor HP (S), tanggal lahir (S), alamat (S), status akun dan KYC, tanggal bergabung, tipe akun/segmen, bank dan nomor RDN (S), rekening penarikan (S), bahasa | Kolom info nasabah di panel agen |
| **Order** | ID order, waktu masuk/ubah/batal, kode saham, beli/jual, tipe, harga, lot, lot terisi, status, **kode dan alasan penolakan**, kanal (Windows/Android), sesi pasar, riwayat amend/cancel, eksekusi | Kartu order di chat (nasabah memilih order), order terakhir di panel agen |
| **Transaksi dana (RDN)** | ID, waktu, jenis (deposit, penarikan, biaya, dividen tunai), nominal, bank, status, referensi bank, alasan gagal | Kartu transaksi di chat, transaksi terakhir di panel agen |
| **Perangkat dan sesi** | Sesi aktif, riwayat login (waktu, perangkat, OS, versi aplikasi, perkiraan lokasi/IP (S)), perangkat terdaftar | Investigasi peretasan |
| **Status keamanan** | Akun/transaksi terkunci beserta penyebabnya, percobaan login gagal terakhir, perubahan password/PIN terakhir, status OTP/2FA, penanda aktivitas mencurigakan | Sesi prioritas P1 (fraud/peretasan) |

Pertanyaan tambahan: **riwayat order** berapa hari ke belakang yang tersedia (usulan kami minimal 90 hari)?

## 4. Aksi ke OLT (hanya dua)

### 4.1 Amankan akun
1. **Kemampuan.** Tindakan apa yang tersedia di OLT?
   - keluarkan semua perangkat/sesi;
   - kunci transaksi sementara;
   - kunci akun;
   - lainnya.
2. **Perilaku request.**
   - Apakah aman diulang (idempoten)? Adapter mengirim `idempotency_key` per sesi chat.
   - Berapa lama prosesnya?
   - Bisakah berhasil sebagian, misalnya logout berhasil tetapi kunci gagal?
3. **Membuka kunci.** Siapa yang membuka kunci, lewat proses apa? Apakah OLT sendiri yang memberi tahu nasabah?

### 4.2 Permintaan konfirmasi identitas
Agen mengirim permintaan konfirmasi di chat untuk permintaan berisiko tinggi. Nasabah menyetujuinya **di dalam aplikasi OLT** memakai PIN atau biometrik yang diproses OLT. CS hanya menerima hasilnya: disetujui, ditolak, atau kedaluwarsa. PIN tidak pernah diketik di chat dan tidak pernah dikirim ke kami.

Pertanyaannya: mekanisme mana yang paling cocok dengan OLT?
- **(a) Lewat backend OLT.** Adapter mengirim `identity_verification` ke backend OLT. OLT menampilkan layar verifikasi di aplikasinya (push atau koneksi yang sedang aktif), lalu mengirim hasilnya ke adapter.
- **(b) Lewat aplikasi.** Widget chat CS di aplikasi menerima permintaan, lalu memanggil layar PIN/biometrik milik OLT lewat callback host. Backend OLT memverifikasi dan mengirim hasil yang ditandatangani ke adapter.

Mohon juga informasi masa berlaku permintaan dan batas percobaan.

## 5. Kode error dan event (opsional, sangat membantu)

1. **Katalog kode error** order dan sistem: kode, pesan, dan artinya. Dipakai untuk tombol "Chat CS" saat order ditolak (topik dan konteks terisi otomatis).
2. **Event dari OLT.** Bisakah OLT mengirim event seperti order ditolak, penarikan gagal, atau akun terkunci? Event ini membantu mendeteksi lonjakan masalah lebih awal.
3. **Status gangguan.** Apakah OLT punya sumber status gangguan (misalnya "penarikan via Bank X tertunda") yang bisa ditampilkan sebelum nasabah masuk antrean?

## 6. Integrasi di aplikasi OLT (Flutter)

Chat CS memakai package `olt_social` yang sudah terpasang. Aplikasi host menyuplai kemampuan lewat interface.

1. **Tombol "Chat CS" dari layar penting.** Mohon skema/rute layar OLT di Windows dan Android untuk detail order, deposit dan tarik dana, portofolio, dan keamanan akun, agar topik dan konteks bisa terisi otomatis.
2. **Konteks perangkat.** Bagaimana aplikasi bisa memberi versi aplikasi, platform/OS, model perangkat, layar terakhir, dan kode error terakhir?
3. **Notifikasi.**
   - Apakah OLT sudah memakai Firebase Cloud Messaging di Android, dan bisa berbagi token? Atau service `notifier` kami mengelola token sendiri?
   - Apakah sudah ada mekanisme notifikasi Windows (toast) di OLT?
4. **Login staf CS (opsional).** Apakah perusahaan punya SSO internal (Azure AD, LDAP, atau OIDC) yang ingin dipakai panel CS? Default kami: akun staf terpisah dengan 2FA (TOTP).

## 7. Volume

Mohon perkiraan angka berikut untuk menentukan kapasitas matching engine, partisi tabel, dan uji beban:
- jumlah nasabah aktif;
- jumlah chat CS per hari (rata-rata dan puncak), termasuk saat gangguan massal;
- jumlah agen CS per shift.

---

## Lampiran: usulan tipe pesan (perluasan Protokol v1)

Aturan umum Protokol v1 tetap berlaku:
- amplop `v`/`type`/`request_id`;
- respons `<tipe>_result` dengan `status` `OK`/`ERROR`;
- harga dalam rupiah bulat, lot dalam bilangan bulat, waktu RFC 3339 UTC.

Semua request membawa `correlation_id` (ID sesi chat + kode agen) untuk audit. Nama field di bawah hanyalah usulan. Bila OLT memakai nama lain, adapter bisa dipetakan lewat konfigurasi.

**Status (30 Okt 2026):** sudah diimplementasikan di OLT dummy dan dipakai `customer-adapter`, kecuali `identity_verification` (menyusul bersama panel agen di CS4). Koneksi untuk pesan nasabah wajib membawa `Authorization: Bearer <token layanan data nasabah>`. Tanpa header itu, OLT dummy membalas `UNAUTHORIZED`.

```jsonc
// Profil (data sensitif sudah disamarkan)
{ "v": 1, "type": "customer_profile", "request_id": "…",
  "payload": { "user_id": "1001", "correlation_id": "6f1c…/CS-0007" } }
// → data: { "user_id": "1001", "client_code": "****1001", "name": "Budi Santoso",
//           "email": "bu***@gmail.com", "phone": "0812****789", "nik": "3174********0001",
//           "account_status": "active", "kyc_status": "verified", "joined_at": "2021-03-02T00:00:00Z",
//           "rdn": { "bank": "BCA", "number": "****1234" } }

// Membuka satu field (agen sudah memilih alasan; tercatat di kedua sisi)
{ "v": 1, "type": "customer_reveal", "request_id": "…",
  "payload": { "user_id": "1001", "field": "phone", "reason": "identity_verification",
               "correlation_id": "…" } }
// → data: { "field": "phone", "value": "081234567789" }

// Daftar order (terbaru dulu, berhalaman)
{ "v": 1, "type": "customer_orders", "request_id": "…",
  "payload": { "user_id": "1001", "from": "2026-10-01T00:00:00Z", "to": "2026-10-30T00:00:00Z",
               "status": ["rejected", "open"], "code": "BBCA", "cursor": null, "limit": 20,
               "correlation_id": "…" } }
// → data: { "orders": [ { "order_id": "O-778812", "time": "2026-10-29T03:12:05Z", "code": "BBCA",
//           "side": "buy", "type": "limit", "price": 9250, "lot": 10, "filled_lot": 0,
//           "status": "rejected", "reject_code": "E-1021", "reject_reason": "Saldo tidak cukup",
//           "channel": "android" } ], "next_cursor": "…" }

// Detail satu order + riwayat + eksekusi (kartu order di chat)
{ "v": 1, "type": "customer_order", "request_id": "…",
  "payload": { "user_id": "1001", "order_id": "O-778812", "correlation_id": "…" } }

// Transaksi dana RDN, dan detail satu transaksi
{ "v": 1, "type": "customer_cash_transactions", "request_id": "…",
  "payload": { "user_id": "1001", "from": "…", "to": "…", "cursor": null, "limit": 20, "correlation_id": "…" } }
{ "v": 1, "type": "customer_cash_transaction", "request_id": "…",
  "payload": { "user_id": "1001", "transaction_id": "T-5521", "correlation_id": "…" } }

// Sesi/perangkat dan status keamanan
{ "v": 1, "type": "customer_sessions", "request_id": "…", "payload": { "user_id": "1001", "correlation_id": "…" } }
{ "v": 1, "type": "customer_security", "request_id": "…", "payload": { "user_id": "1001", "correlation_id": "…" } }

// Aksi: amankan akun (idempoten lewat idempotency_key)
{ "v": 1, "type": "secure_account", "request_id": "…",
  "payload": { "user_id": "1001", "actions": ["logout_all", "lock_trading"],
               "reason": "customer_emergency", "idempotency_key": "cs-secure:6f1c…", "correlation_id": "…" } }
// → data: { "results": { "logout_all": "OK", "lock_trading": "OK" } }

// Aksi: minta konfirmasi identitas (hasil menyusul)
{ "v": 1, "type": "identity_verification", "request_id": "…",
  "payload": { "user_id": "1001", "verification_id": "…", "purpose": "change_bank_account",
               "expires_at": "2026-10-30T03:20:00Z", "correlation_id": "…" } }
// → data: { "accepted": true }
// Hasil dikirim OLT sebagai pesan di koneksi yang sama (atau ditanyakan lewat identity_verification_status):
// { "v": 1, "type": "identity_verification_result",
//   "data": { "verification_id": "…", "status": "approved", "decided_at": "…" } }
```

Kode error tambahan yang mungkin perlu, selain `UNAUTHORIZED`, `INVALID_REQUEST`, `NOT_FOUND`, `RATE_LIMITED`, dan `INTERNAL`:
- `FORBIDDEN`: kredensial tidak mencakup data itu;
- `UNAVAILABLE`: sistem sumber sedang maintenance.
