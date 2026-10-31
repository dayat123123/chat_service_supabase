# Kebutuhan Data & Aksi dari OLT untuk `customer-adapter`

> **Untuk:** tim backend dan infrastruktur OLT.
> **Dari:** tim pengembang OLT Social / Customer Care.
> **Dasar:** [PROMPT-CUSTOMER-CARE.md](../PROMPT-CUSTOMER-CARE.md) bagian 3.3, 4.2, 4.3, 4.6, dan 8. Protokol yang dipakai: [market-integration.md](../../market-integration.md) (Protokol v1).

## Ringkasan

- Agen CS perlu **membaca** data nasabah dari OLT supaya nasabah tidak perlu mengulang cerita: profil, order, transaksi dana, ringkasan portofolio, perangkat/sesi, dan status keamanan.
- Hanya ada **dua aksi** ke OLT:
  - "Amankan akun";
  - "Permintaan verifikasi identitas".

  Tidak ada aksi transaksi dan tidak ada perubahan data nasabah.
- Data **tidak disalin** ke database customer care. Satu-satunya pengecualian adalah snapshot yang dilampirkan secara sadar ke tiket, misalnya order yang dipilih nasabah saat mengadu.
- Setiap akses tercatat: agen, tiket, data apa, dan kapan. Kami bisa mengirim ID korelasi (tiket + agen) di setiap request bila OLT juga ingin mencatatnya.
- **Usulan:** pakai Protokol v1 yang sudah disepakati untuk login, harga, daftar saham, dan portofolio. Usulan tipe pesannya ada di lampiran.
  - Bila OLT punya API lain (gRPC ClientEngine, REST internal), mohon dokumentasinya. Adapter akan menyesuaikan.
- **Development:** OLT dummy di repo kami akan diperluas dengan nasabah, order, dan transaksi tiruan sebagai implementasi referensi.

Bila sebagian data belum tersedia, customer care tetap jalan. Bagian panel yang datanya belum ada akan menampilkan "tidak tersedia".

## 1. Koneksi dan keamanan

1. **Endpoint.**
   - Apakah pesan-pesan di lampiran bisa dilayani endpoint WebSocket Protokol v1 yang sama?
   - Atau perlu endpoint atau protokol terpisah?
   - Mohon URL untuk development/UAT dan produksi.
2. **Autentikasi antar-service.** Data nasabah lebih sensitif dari harga. Kami mengusulkan **kredensial terpisah** dengan cakupan hanya-baca data nasabah plus dua aksi.
   - Bentuknya bisa token service berbeda dari `olt_service_token`, mTLS, atau mekanisme lain yang Anda pakai.
   - Bagaimana rotasi kredensialnya?
3. **Jaringan.** Dari mana adapter boleh terhubung: IP allowlist, VPN site-to-site, atau jaringan privat? Mohon port dan aturan firewall-nya.
4. **Batas dan isolasi.** Customer care tidak boleh mengganggu trading. Mohon informasi berikut:
   - rate limit untuk request data nasabah;
   - latensi tipikal dan p95;
   - jendela maintenance;
   - perilaku saat jam bursa ramai;
   - apakah request customer care bisa diarahkan ke instance/replika terpisah, misalnya replika baca.
5. **Jejak audit di sisi OLT.** Apakah OLT mencatat akses data oleh service? Field apa yang perlu kami kirim, misalnya `correlation_id` berisi ID tiket dan ID agen?
6. **Lingkungan uji.** Apakah ada UAT/sandbox dengan akun nasabah tiruan untuk uji integrasi?

## 2. Identitas nasabah

1. **ID yang stabil.** ID mana yang unik dan tidak pernah berubah?
   - `user.id` (sudah dipakai login/auth-bridge);
   - kode nasabah (client code);
   - SID;
   - nomor RDN.

   Apakah satu user bisa punya beberapa akun (reguler, margin, syariah)? Bila ya, bagaimana relasinya?
2. **Pencarian nasabah.** CS mencatat pengaduan dari telepon, email, atau surat. Bisakah mencari nasabah dari nama + kode nasabah, email, atau nomor HP? Apakah tersedia endpoint pencarian (dengan hasil disamarkan)?
3. **Status akun.** Status apa saja yang mungkin (aktif, dibekukan, dorman, ditutup, KYC tertunda), dan apa arti masing-masing?

## 3. Data yang dibutuhkan (hanya-baca)

Untuk setiap kelompok data, mohon informasi berikut:
- apakah tersedia;
- nama dan format field;
- seberapa jauh riwayatnya;
- dukungan filter dan pagination.

Tanda **(S)** = data sensitif.

**Usulan kami:** OLT mengirim data sensitif dalam bentuk **sudah disamarkan** secara default, dan menyediakan permintaan terpisah untuk membuka **satu field** (`customer_reveal`). Dengan begitu, data lengkap hanya keluar saat agen membukanya dengan alasan. Bila ini tidak memungkinkan, adapter yang menyamarkan sebelum data sampai ke panel.

| Kelompok | Field yang dibutuhkan | Dipakai untuk |
|---|---|---|
| **Profil** | Nama lengkap, nama panggilan, kode nasabah, SID (S), NIK (S), email (S), nomor HP (S), tanggal lahir (S), alamat (S), status akun dan KYC, tanggal bergabung, tipe akun/segmen, bank dan nomor RDN (S), rekening penarikan (S), bahasa | Panel Customer 360, verifikasi saat telepon |
| **Order** | ID order, waktu masuk/ubah/batal, kode saham, beli/jual, tipe (limit, market, dsb.), harga, lot, lot terisi, status, **kode dan alasan penolakan**, kanal (Windows/Android), jenis (biasa, auto order, trailing), sesi pasar, riwayat amend/cancel, eksekusi (harga dan lot per trade) | Formulir "masalah order" (nasabah memilih order), kartu order di chat, analisis agen |
| **Transaksi dana (RDN)** | ID, waktu, jenis (deposit, penarikan, biaya, dividen tunai), nominal, bank, status (diproses, berhasil, gagal), referensi bank, alasan gagal | Formulir "deposit/tarik dana", analisis agen |
| **Ringkasan portofolio** | Saldo kas (tersedia, T+1, T+2), daftar saham dengan lot dan harga rata-rata | Hanya untuk role tertentu dan bila relevan (kategori Portofolio & Settlement) |
| **Aksi korporasi** | Hak dividen, right issue, warrant, tender offer, e-IPO per nasabah (bila ada) | Kategori Aksi Korporasi |
| **Perangkat dan sesi** | Sesi aktif, riwayat login (waktu, perangkat, OS, versi aplikasi, perkiraan lokasi/IP (S)), perangkat terdaftar | Kategori Login & Keamanan, investigasi peretasan |
| **Status keamanan** | Akun/transaksi terkunci beserta penyebabnya, percobaan login gagal terakhir, perubahan password/PIN terakhir, status OTP/2FA, penanda aktivitas mencurigakan | Kategori Login & Keamanan, tiket P1 |
| **Dokumen** | Trade confirmation, laporan bulanan, bukti potong pajak (PDF, atau cukup ID/tautan) | Kategori Biaya, Pajak & Laporan |

Pertanyaan tambahan:
- **Riwayat order:** berapa hari ke belakang yang tersedia (usulan kami minimal 90 hari)?
- **Snapshot order:** saat nasabah memilih order untuk pengaduan, kami menyimpan salinan order itu di tiket sebagai bukti, karena data di OLT bisa berubah. Apakah ada keberatan dari sisi OLT?

## 4. Aksi ke OLT (hanya dua)

### 4.1 Amankan akun (tombol darurat 24 jam)
1. **Kemampuan.** Tindakan apa yang tersedia di OLT?
   - keluarkan semua perangkat/sesi;
   - kunci transaksi sementara;
   - kunci akun;
   - lainnya.
2. **Perilaku request.**
   - Apakah aman diulang (idempoten)?
   - Berapa lama prosesnya?
   - Bisakah berhasil sebagian, misalnya logout berhasil tetapi kunci gagal?
3. **Membuka kunci.** Siapa yang membuka kunci, lewat proses apa? Apakah OLT sendiri yang memberi tahu nasabah?

### 4.2 Permintaan verifikasi identitas
Agen meminta verifikasi untuk permintaan berisiko tinggi. Nasabah menyetujuinya **di dalam aplikasi OLT** memakai PIN atau biometrik yang diproses OLT. Customer care hanya menerima hasilnya: disetujui, ditolak, atau kedaluwarsa. PIN tidak pernah dikirim ke kami.

Pertanyaannya: mekanisme mana yang paling cocok dengan OLT?
- **(a) Lewat backend OLT.** Adapter mengirim `identity_verification` ke backend OLT. OLT menampilkan layar verifikasi di aplikasinya (push atau koneksi yang sedang aktif), lalu mengirim hasilnya ke adapter.
- **(b) Lewat aplikasi.** Package `olt_care` di aplikasi menerima permintaan, lalu memanggil layar PIN/biometrik milik OLT lewat callback host. Backend OLT memverifikasi dan mengirim hasil yang ditandatangani ke adapter.

Mohon juga informasi masa berlaku permintaan dan batas percobaan.

## 5. Kode error dan event (opsional, sangat membantu)

1. **Katalog kode error** order dan sistem: kode, pesan, dan artinya. Dipakai untuk tombol "Butuh bantuan?" saat order ditolak, dan untuk memetakan artikel bantuan per kode error.
2. **Event dari OLT.** Bisakah OLT mengirim event seperti order ditolak, penarikan gagal, atau akun terkunci?
   - Event ini membantu mendeteksi lonjakan masalah (insiden massal) lebih awal.
   - Bila tidak tersedia, cukup diambil saat dibutuhkan.
3. **Status gangguan.** Apakah OLT punya sumber status gangguan (misalnya "penarikan via Bank X tertunda") yang bisa dipakai untuk banner status layanan?

## 6. Integrasi di aplikasi OLT (Flutter)

Package `olt_care` dipasang di aplikasi OLT dengan pola yang sama seperti `rendezvous_community`: aplikasi host menyuplai kemampuan lewat interface.

1. **Deep link.** Mohon skema/rute layar OLT di Windows dan Android untuk:
   - detail order;
   - deposit dan tarik dana;
   - portofolio;
   - aksi korporasi;
   - keamanan akun.

   Dipakai dari artikel bantuan dan tiket.
2. **Konteks perangkat.** Bagaimana aplikasi bisa memberi data berikut?
   - versi aplikasi, platform/OS, model perangkat;
   - layar terakhir, kode error terakhir;
   - status koneksi.
3. **Log teknis.** Apakah aplikasi OLT punya log lokal yang bisa disanitasi lalu dilampirkan ke tiket (tanpa token, password, atau data sensitif)? Formatnya seperti apa?
4. **Screenshot.**
   - Di Windows: bolehkah package menangkap jendela OLT?
   - Di Android: kami hanya menyediakan pilih dari galeri/tangkapan layar milik sistem.
5. **Notifikasi.**
   - Apakah OLT sudah memakai Firebase Cloud Messaging di Android, dan bisa berbagi token? Atau service `notifier` kami mengelola token sendiri?
   - Apakah sudah ada mekanisme notifikasi Windows (toast) di OLT?
6. **Login staf CS (opsional).** Apakah perusahaan punya SSO internal (Azure AD, LDAP, atau OIDC) yang ingin dipakai CS Console? Default kami: akun staf terpisah dengan 2FA (TOTP).

## 7. Volume

Mohon perkiraan angka berikut untuk menentukan ukuran antrean, partisi tabel, dan uji beban:
- jumlah nasabah aktif;
- order per hari (rata-rata dan puncak);
- jumlah kontak CS per hari saat ini, termasuk saat gangguan massal.

---

## Lampiran: usulan tipe pesan (perluasan Protokol v1)

Aturan umum Protokol v1 tetap berlaku:
- amplop `v`/`type`/`request_id`;
- respons `<tipe>_result` dengan `status` `OK`/`ERROR`;
- harga dalam rupiah bulat, lot dalam bilangan bulat, waktu RFC 3339 UTC.

Semua request membawa `correlation_id` (tiket + agen) untuk audit. Nama field di bawah hanyalah usulan. Bila OLT memakai nama lain, adapter bisa dipetakan lewat konfigurasi.

**Status (30 Okt 2026):** pesan-pesan ini sudah diimplementasikan di OLT dummy kami ([`services/dummy-olt`](../../../services/dummy-olt/README.md)) sebagai implementasi referensi, dan dipakai `customer-adapter`.
- Ada satu pesan tambahan: `customer_cash_transaction`, yaitu detail satu transaksi untuk snapshot pengaduan dana.
- Koneksi untuk pesan nasabah wajib membawa `Authorization: Bearer <token layanan data nasabah>`. Tanpa header itu, OLT dummy membalas `UNAUTHORIZED`.

```jsonc
// Profil (data sensitif sudah disamarkan)
{ "v": 1, "type": "customer_profile", "request_id": "…",
  "payload": { "user_id": "1001", "correlation_id": "CC-2026-10-000123/agent-17" } }
// → data: { "user_id": "1001", "client_code": "****1001", "name": "Budi Santoso",
//           "email": "bu***@gmail.com", "phone": "0812****789", "nik": "3174********0001",
//           "account_status": "active", "kyc_status": "verified", "joined_at": "2021-03-02T00:00:00Z",
//           "rdn": { "bank": "BCA", "number": "****1234" } }

// Membuka satu field (agen sudah memilih alasan; tercatat di kedua sisi)
{ "v": 1, "type": "customer_reveal", "request_id": "…",
  "payload": { "user_id": "1001", "field": "phone", "reason": "callback_verification",
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

// Detail satu order + riwayat + eksekusi
{ "v": 1, "type": "customer_order", "request_id": "…",
  "payload": { "user_id": "1001", "order_id": "O-778812", "correlation_id": "…" } }

// Transaksi dana RDN
{ "v": 1, "type": "customer_cash_transactions", "request_id": "…",
  "payload": { "user_id": "1001", "from": "…", "to": "…", "cursor": null, "limit": 20, "correlation_id": "…" } }
// → data: { "transactions": [ { "id": "T-5521", "time": "…", "kind": "deposit", "amount": 5000000,
//           "bank": "BCA", "status": "processing", "bank_ref": "…" } ], "next_cursor": null }

// Detail satu transaksi (snapshot pengaduan dana)
{ "v": 1, "type": "customer_cash_transaction", "request_id": "…",
  "payload": { "user_id": "1001", "transaction_id": "T-5521", "correlation_id": "…" } }

// Ringkasan portofolio (hanya dipanggil untuk role yang berwenang)
{ "v": 1, "type": "customer_portfolio", "request_id": "…", "payload": { "user_id": "1001", "correlation_id": "…" } }

// Sesi/perangkat dan status keamanan
{ "v": 1, "type": "customer_sessions", "request_id": "…", "payload": { "user_id": "1001", "correlation_id": "…" } }
{ "v": 1, "type": "customer_security", "request_id": "…", "payload": { "user_id": "1001", "correlation_id": "…" } }

// Aksi: amankan akun (idempoten lewat idempotency_key)
{ "v": 1, "type": "secure_account", "request_id": "…",
  "payload": { "user_id": "1001", "actions": ["logout_all", "lock_trading"],
               "reason": "customer_emergency", "idempotency_key": "…", "correlation_id": "…" } }
// → data: { "results": { "logout_all": "OK", "lock_trading": "OK" } }

// Aksi: minta verifikasi identitas (hasil menyusul)
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
