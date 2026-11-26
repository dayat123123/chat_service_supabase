# API Kirim Laporan Keuangan

Panduan untuk tim yang mengirim laporan keuangan emiten ke Rendezvous, misalnya backend OLT, pengambil data dari vendor, atau skrip di PC kantor. Setiap file XBRL yang dikirim diurai otomatis, diringkas, lalu menjadi draf postingan resmi di Stream yang menunggu persetujuan staf di Hub.

| | |
|---|---|
| Endpoint | `POST /integration/v1/financial-reports` dan `GET /integration/v1/financial-reports/{id}` |
| Autentikasi | `Authorization: Bearer oik_…` (API key dengan izin **Kirim laporan keuangan**) |
| Isi | File `instance.zip` dari IDX apa adanya, `Content-Type: application/zip` |
| Sifat | Asinkron. File diterima dulu, diurai beberapa detik kemudian |
| Kontrak mesin | [laporan-keuangan.openapi.yaml](../api/laporan-keuangan.openapi.yaml) (OpenAPI 3.1) |
| Tersedia sejak | Server migrasi `0197`, layanan `finreport` 0.1.0 |
| Desain | [docs/laporan-keuangan/README.md](../laporan-keuangan/README.md) |

## 1. Mulai cepat

1. **Buat API key.** Super Admin membuka Hub, **Pengaturan → API Integrasi → Buat API key**, memberi nama (misalnya "Data laporan OLT"), mencentang hanya **Kirim laporan keuangan**, dan sebaiknya mengisi IP server pengirim di **IP atau CIDR yang diizinkan**. Key berawalan `oik_` hanya ditampilkan sekali.
2. **Pastikan akun resminya sudah dipilih.** Di Hub, **Komunitas → Laporan keuangan → Pengaturan posting**, Super Admin memilih akun resmi yang akan memposting ringkasan. Tanpa itu laporan tetap diurai, tetapi postingannya tidak dibuat.
3. **Kirim file:**

   Linux / macOS:
   ```bash
   curl -sS -X POST "https://<domain API>/integration/v1/financial-reports" \
     -H "Authorization: Bearer $FINREPORT_KEY" \
     -H "Content-Type: application/zip" \
     --data-binary @instance.zip
   ```

   Windows PowerShell (pakai `curl.exe`, bukan `curl`):
   ```powershell
   curl.exe -sS -X POST "https://<domain API>/integration/v1/financial-reports" `
     -H "Authorization: Bearer $env:FINREPORT_KEY" `
     -H "Content-Type: application/zip" `
     --data-binary "@instance.zip"
   ```

   Di server dev kantor, `<domain API>` adalah `192.168.0.235:8000` dengan `http://`.

4. **Cek hasilnya** dengan `id` dari respons:
   ```bash
   curl -sS "https://<domain API>/integration/v1/financial-reports/<id>" -H "Authorization: Bearer $FINREPORT_KEY"
   ```

Untuk mengirim banyak file dari satu folder di Windows, pakai skrip [scripts/finreport/kirim-laporan.ps1](../../scripts/finreport/kirim-laporan.ps1) (bagian 6).

## 2. Akses dan batasan

| Hal | Aturan |
|---|---|
| Header | `Authorization: Bearer <key>` dan `Content-Type: application/zip`. `application/x-zip-compressed` dan `application/octet-stream` juga diterima. Header `apikey` tidak diperlukan |
| Izin key | `financial_report`. Key notifikasi, bot, atau kesehatan sistem ditolak `403 scope_forbidden` |
| IP | Bila key dibatasi IP, request dari IP lain ditolak `403 ip_not_allowed` |
| Ukuran | Maksimal 8 MiB per file (`413 body_too_large`). File laporan IDX biasanya 80–150 KB |
| Isi zip | Harus berisi tepat satu file `.xbrl`, maksimal 16 file di dalam zip, maksimal 32 MiB setelah dibuka. Selain itu `400` |
| Bersamaan | Server memproses 2 unggahan sekaligus. Unggahan ketiga menunggu sampai 3 detik lalu dijawab `503 busy` dengan `Retry-After`. Kirim berurutan |
| Batas per menit | `rate_limit_per_minute` per key (diatur di Hub) → `429 rate_limited` |
| Batas per jam | 120 file per key per jam (`finreport.files_per_hour`) → `429 rate_limited`, `Retry-After: 60` |
| Key salah | Lebih dari 30 percobaan key salah per menit dari satu IP → `429 too_many_auth_failures` |
| Kirim ulang | Aman. File yang sama (sidik SHA-256 sama) dari key yang sama dijawab dengan `id` lama dan `resubmitted: true`. Isi yang sudah pernah diurai, dari key mana pun, ditandai `duplicate` |
| Dari mana | Selalu dari backend atau skrip di mesin tepercaya, jangan dari browser |

## 3. `POST /integration/v1/financial-reports`

Body adalah isi file zip, bukan JSON dan bukan form upload.

| Status | Arti |
|---|---|
| `202 Accepted` | File baru, masuk antrean |
| `200 OK` | File ini sudah pernah dikirim (`resubmitted: true`), atau isinya sudah pernah diurai (`status: "duplicate"`). Tidak ada yang diproses ulang |

Contoh respons `202`:

```json
{
  "api_version": 1,
  "id": "0b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b",
  "status": "queued",
  "sha256": "7a7ba1a2ed82d298f2d672505dc001ca2fd6ebf9e483c440f5f30ac92f9ce76a",
  "size_bytes": 80710,
  "received_at": "2026-11-26T02:00:04.358+00:00",
  "finished_at": null,
  "retry_at": null,
  "error": null,
  "report": null,
  "resubmitted": false
}
```

## 4. `GET /integration/v1/financial-reports/{id}`

Hanya file yang dikirim dengan key yang sama yang bisa dibaca; selain itu `404 file_not_found`. Polling setiap 5–10 detik sudah cukup; biasanya selesai dalam beberapa detik.

| `status` | Arti |
|---|---|
| `queued` | Menunggu diproses. Bila `retry_at` terisi, percobaan sebelumnya gagal sementara (storage, antivirus, atau database tidak terjangkau) dan akan dicoba lagi pada waktu itu |
| `processing` | Sedang diurai |
| `done` | Berhasil. `report` berisi hasilnya |
| `duplicate` | Isi file sama dengan laporan yang sudah ada. `report` menunjuk laporan itu |
| `rejected` | Ditolak. `error.code` dan `error.detail` menjelaskan alasannya. Mengirim ulang file yang sama tidak membantu; perbaiki filenya dulu |

Contoh `done`:

```json
{
  "api_version": 1,
  "id": "0b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b",
  "status": "done",
  "error": null,
  "report": {
    "id": "df497513-5946-4669-886a-a0c91656c236",
    "entity_code": "BBCA",
    "entity_name": "PT Bank Central Asia Tbk.",
    "period": "Q3",
    "period_start": "2026-01-01",
    "period_end": "2026-09-30",
    "audit": "unaudited",
    "currency": "IDR",
    "template": "bank",
    "superseded": false,
    "warnings": ["restated"],
    "post": { "id": "67ab7ad8-7400-44e9-a96e-e2d929a90c91", "status": "pending", "post_id": null, "published_at": null }
  }
}
```

| Field `report` | Isi |
|---|---|
| `period` | `Q1`, `Q2`, `Q3`, atau `FY` (tahunan) |
| `audit` | `audited`, `unaudited` (termasuk reviu terbatas), atau `unknown` |
| `template` | `bank`, `general`, atau `basic` (jenis industri tidak dikenali) |
| `superseded` | `true` bila sudah digantikan laporan revisi untuk periode yang sama |
| `warnings` | Kode peringatan (lihat di bawah). Laporan berperingatan selalu menunggu persetujuan staf |
| `post.status` | `pending` (menunggu persetujuan), `scheduled`, `published`, `rejected`, `cancelled`, atau `null` bila postingan tidak dibuat |

| Peringatan | Arti |
|---|---|
| `restated` | Angka tahun lalu di laporan ini berbeda lebih dari 0,5% dari laporan tahun lalu yang tersimpan (reklasifikasi atau penyajian ulang) |
| `revision` | Laporan ini menggantikan versi sebelumnya untuk periode yang sama |
| `template_basic` | Jenis industri tidak dikenali, hanya ringkasan dasar |
| `missing_lines` | Pos utama tidak ditemukan di file |
| `no_official_account` | Akun resmi belum dipilih atau nonaktif, jadi postingan tidak dibuat |
| `post_rejected` | Teks ringkasan ditolak pemeriksaan konten |

## 5. Kode error

| HTTP | `error` | Arti |
|---|---|---|
| 400 | `not_zip` | Body bukan zip yang valid |
| 400 | `no_instance` | Tidak ada file `.xbrl` di dalam zip |
| 400 | `zip_unsafe` | Terlalu banyak file, lebih dari satu `.xbrl`, terlalu besar setelah dibuka, atau rasio kompresi mencurigakan |
| 400 | `empty_body` | Body kosong |
| 400 | `invalid_id` | `{id}` bukan UUID |
| 401 | `missing_key` / `invalid_key` | Header Authorization tidak ada, salah format, tidak dikenal, nonaktif, atau dicabut |
| 403 | `ip_not_allowed` / `scope_forbidden` | IP tidak diizinkan / key tidak punya izin Kirim laporan keuangan |
| 404 | `file_not_found` | Id tidak ada atau milik key lain |
| 405 | `method_not_allowed` | Metode lain; lihat header `Allow` |
| 413 | `body_too_large` | Lebih dari 8 MiB |
| 415 | `unsupported_media_type` | `Content-Type` bukan zip |
| 429 | `rate_limited` / `too_many_auth_failures` | Lihat `Retry-After` |
| 503 | `busy` / `unavailable` | Server sibuk atau storage/database sementara tidak terjangkau. Kirim ulang file yang sama setelah `Retry-After` |

Kode penolakan yang bisa muncul di `error.code` saat `status` = `rejected`:

| Kode | Arti |
|---|---|
| `not_zip`, `no_instance`, `zip_unsafe` | Sama seperti di atas, terdeteksi saat dibuka penuh |
| `invalid_xbrl` | XML rusak, bukan XBRL IDX, atau identitas laporan (`idx-dei`) tidak lengkap |
| `unknown_entity` | Kode emiten tidak valid |
| `infected` | Ditandai antivirus. File langsung dihapus |
| `checksum_mismatch` | File di penyimpanan berubah setelah diterima |
| `object_missing` | File di penyimpanan hilang sebelum diproses |
| `too_many_attempts` | Gagal sementara 5 kali berturut-turut |
| `invalid_report` | Hasil urai tidak lolos pemeriksaan database |

Staf bisa memproses ulang file yang ditolak (kecuali `infected`) dari Hub tanpa Anda mengirim ulang.

## 6. Mengirim satu folder dari Windows

Skrip `scripts/finreport/kirim-laporan.ps1` mengirim semua `*.zip` di satu folder berurutan, mencatat hasilnya, dan memindahkan file yang sudah diterima ke subfolder `terkirim`. Cocok untuk staf yang mengunduh laporan dari situs IDX lewat browser, atau dijalankan berkala lewat Task Scheduler.

```powershell
$env:FINREPORT_KEY = '<API key>'
.\scripts\finreport\kirim-laporan.ps1 -Folder 'D:\Laporan IDX' -ApiBase 'http://192.168.0.235:8000'
```

Key dibaca dari variabel lingkungan `FINREPORT_KEY`, tidak pernah ditulis ke file atau log. Nama file tidak penting; emiten dan periode dibaca dari isi XBRL.

## 7. Mendapatkan file XBRL

File `instance.zip` ada di halaman Laporan Keuangan dan Tahunan situs IDX (kolom lampiran setiap laporan). Situs IDX memblokir pengambilan otomatis oleh skrip, jadi server Rendezvous tidak mengunduh sendiri. Sumber yang bisa dipakai:

- **Unduh lewat browser** lalu kirim dengan skrip di atas, atau unggah di Hub (**Komunitas → Laporan keuangan → Unggah**).
- **Sistem yang sudah berlangganan data** (backend OLT atau vendor data) memanggil API ini setiap ada laporan baru.

Untuk ringkasan yang lengkap, kirim juga laporan kuartal sebelumnya dan laporan periode yang sama tahun lalu satu kali di awal. Setelah itu pembanding tersimpan dengan sendirinya.
