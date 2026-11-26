# API Kirim Riset

Panduan untuk tim yang mengirim data riset ke Rendezvous, misalnya backend OLT, pengambil data dari vendor, atau skrip di PC kantor. Setiap kiriman diurai otomatis, diringkas, lalu menjadi postingan resmi yang menunggu persetujuan staf di Hub dan tampil sebagai kartu riset di aplikasi. Jenis yang didukung saat ini: **laporan keuangan emiten** (file XBRL `instance.zip` dari IDX). Dokumen sumbernya (PDF atau XLSX laporan keuangan dari IDX) bisa ikut dikirim supaya nasabah bisa membaca laporan aslinya dari postingan.

| | |
|---|---|
| Endpoint | `POST /integration/v1/research`, `GET /integration/v1/research/{id}`, `POST /integration/v1/research/{id}/documents` |
| Autentikasi | `Authorization: Bearer oik_…` (API key dengan izin **Kirim riset**) |
| Isi | Laporan keuangan: file `instance.zip` dari IDX apa adanya, `Content-Type: application/zip`. Dokumen sumber: PDF atau XLSX apa adanya |
| Sifat | Asinkron. File diterima dulu, diurai beberapa detik kemudian |
| Kontrak mesin | [riset.openapi.yaml](../api/riset.openapi.yaml) (OpenAPI 3.1) |
| Tersedia sejak | Server migrasi `0199`, layanan `research` 0.2.0. Dokumen sumber: migrasi `0201`, layanan `research` 0.3.0 |
| Desain | [docs/riset/README.md](../riset/README.md) |

## 1. Mulai cepat

1. **Buat API key.** Super Admin membuka Hub, **Pengaturan → API Integrasi → Buat API key**, memberi nama (misalnya "Data riset OLT"), mencentang hanya **Kirim riset**, dan sebaiknya mengisi IP server pengirim di **IP atau CIDR yang diizinkan**. Key berawalan `oik_` hanya ditampilkan sekali.
2. **Pastikan akun resminya sudah dipilih.** Di Hub, **Komunitas → Riset → Pengaturan posting**, Super Admin memilih akun resmi yang akan memposting ringkasan. Tanpa itu laporan tetap diurai, tetapi postingannya tidak dibuat.
3. **Kirim file:**

   Linux / macOS:
   ```bash
   curl -sS -X POST "https://<domain API>/integration/v1/research" \
     -H "Authorization: Bearer $RESEARCH_KEY" \
     -H "Content-Type: application/zip" \
     --data-binary @instance.zip
   ```

   Windows PowerShell (pakai `curl.exe`, bukan `curl`):
   ```powershell
   curl.exe -sS -X POST "https://<domain API>/integration/v1/research" `
     -H "Authorization: Bearer $env:RESEARCH_KEY" `
     -H "Content-Type: application/zip" `
     --data-binary "@instance.zip"
   ```

   Di server dev kantor, `<domain API>` adalah `192.168.0.235:8000` dengan `http://`.

4. **Lampirkan dokumen sumber** (opsional) dengan `id` dari respons. Detailnya ada di bagian 4a:
   ```bash
   curl -sS -X POST "https://<domain API>/integration/v1/research/<id>/documents?name=Laporan%20Keuangan%20BBCA%20Q3%202026.pdf" \
     -H "Authorization: Bearer $RESEARCH_KEY" \
     -H "Content-Type: application/pdf" \
     --data-binary @FinancialStatement-2026-III-BBCA.pdf
   ```

5. **Cek hasilnya** dengan `id` yang sama:
   ```bash
   curl -sS "https://<domain API>/integration/v1/research/<id>" -H "Authorization: Bearer $RESEARCH_KEY"
   ```

Untuk mengirim banyak file dari satu folder di Windows, pakai skrip [scripts/research/kirim-riset.ps1](../../scripts/research/kirim-riset.ps1) (bagian 6).

## 2. Akses dan batasan

| Hal | Aturan |
|---|---|
| Header | `Authorization: Bearer <key>` dan `Content-Type: application/zip`. `application/x-zip-compressed` dan `application/octet-stream` juga diterima. Header `apikey` tidak diperlukan |
| Izin key | `research`. Key notifikasi, bot, atau kesehatan sistem ditolak `403 scope_forbidden` |
| IP | Bila key dibatasi IP, request dari IP lain ditolak `403 ip_not_allowed` |
| Ukuran | Zip maksimal 8 MiB (`413 body_too_large`); file laporan IDX biasanya 80–150 KB. Dokumen sumber maksimal 20 MiB |
| Isi zip | Harus berisi tepat satu file `.xbrl`, maksimal 16 file di dalam zip, maksimal 32 MiB setelah dibuka. Selain itu `400` |
| Bersamaan | Server memproses 2 unggahan sekaligus. Unggahan ketiga menunggu sampai 3 detik lalu dijawab `503 busy` dengan `Retry-After`. Kirim berurutan |
| Batas per menit | `rate_limit_per_minute` per key (diatur di Hub) → `429 rate_limited` |
| Batas per jam | 120 file per key per jam (`research.files_per_hour`) → `429 rate_limited`, `Retry-After: 60` |
| Key salah | Lebih dari 30 percobaan key salah per menit dari satu IP → `429 too_many_auth_failures` |
| Kirim ulang | Aman. File yang sama (sidik SHA-256 sama) dari key yang sama dijawab dengan `id` lama dan `resubmitted: true`. Isi yang sudah pernah diurai, dari key mana pun, ditandai `duplicate` |
| Dari mana | Selalu dari backend atau skrip di mesin tepercaya, jangan dari browser |

## 3. `POST /integration/v1/research`

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

## 4. `GET /integration/v1/research/{id}`

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
    "kind": "financial_report",
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
| `kind` | Jenis riset, saat ini `financial_report` |
| `entity_code` | Kode emiten, misalnya `BBCA` |
| `entity_name` | Nama emiten dari XBRL |
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

Respons `GET` juga memuat `documents`: daftar dokumen sumber file ini (bagian 4a).

## 4a. `POST /integration/v1/research/{id}/documents`

Melampirkan dokumen sumber ke file laporan `{id}` yang dikirim dengan key yang sama. Body adalah isi file apa adanya (bukan JSON, bukan form upload).

| Hal | Aturan |
|---|---|
| Jenis | PDF (`Content-Type: application/pdf`) atau XLSX (`Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`). Format lama (`.xls`, `.xlsm`, `.doc`) ditolak |
| Ukuran | Maksimal 20 MiB, header `Content-Length` wajib |
| Nama | Query `name` opsional, maksimal 120 karakter tanpa garis miring (URL-encode). Bila kosong, nama dibuat dari emiten dan periode, misalnya `BBCA Laporan Keuangan Kuartal III 2026.pdf` |
| Jumlah | Maksimal 3 dokumen per laporan (`409 too_many_documents`) |
| Waktu | Boleh dikirim kapan saja setelah zip diterima, termasuk sebelum zip selesai diurai atau setelah postingannya terbit |
| Kirim ulang | Aman. Dokumen yang sama (SHA-256 sama) untuk file yang sama dijawab dengan `id` lama dan `resubmitted: true` |
| Batas per jam | 120 dokumen per key per jam (`research.documents_per_hour`) |

Setiap dokumen diperiksa dulu sebelum ditampilkan:
- isinya harus benar-benar PDF atau XLSX;
- PDF tidak boleh berisi JavaScript atau perintah peluncuran program;
- XLSX tidak boleh berisi makro;
- lolos pemindaian antivirus.

Dokumen yang lolos (`status: "ready"`) dilampirkan ke postingan riset. Bila postingannya sudah terbit, dokumen ditambahkan ke postingan yang sama. Nasabah membuka dokumen dari aplikasi.

| Status | Arti |
|---|---|
| `202 Accepted` | Dokumen baru, masuk antrean pemeriksaan |
| `200 OK` | Dokumen ini sudah pernah dikirim untuk file yang sama |

Contoh respons `202`:

```json
{
  "id": "5d0b1f62-8f0e-4a1b-9c33-2f6d7c1e9a10",
  "status": "queued",
  "name": "Laporan Keuangan BBCA Q3 2026.pdf",
  "mime": "application/pdf",
  "size_bytes": 4182733,
  "sha256": "…",
  "received_at": "2026-11-26T02:00:09.120+00:00",
  "finished_at": null,
  "error": null,
  "resubmitted": false
}
```

| `status` dokumen | Arti |
|---|---|
| `queued` / `processing` | Menunggu atau sedang diperiksa |
| `ready` | Lolos pemeriksaan dan ikut tampil di postingan |
| `rejected` | Ditolak; `error.code` menjelaskan alasannya |

## 5. Kode error

| HTTP | `error` | Arti |
|---|---|---|
| 400 | `not_zip` | Body bukan zip yang valid |
| 400 | `no_instance` | Tidak ada file `.xbrl` di dalam zip |
| 400 | `zip_unsafe` | Terlalu banyak file, lebih dari satu `.xbrl`, terlalu besar setelah dibuka, atau rasio kompresi mencurigakan |
| 400 | `empty_body` | Body kosong |
| 400 | `invalid_id` | `{id}` bukan UUID |
| 400 | `invalid_document` | Isi dokumen tidak sesuai `Content-Type` (misalnya HTML dikirim sebagai PDF) |
| 400 | `invalid_document_name` | Query `name` terlalu panjang atau berisi garis miring |
| 400 | `incomplete_body` | Body dokumen terputus sebelum selesai. Kirim ulang |
| 401 | `missing_key` / `invalid_key` | Header Authorization tidak ada, salah format, tidak dikenal, nonaktif, atau dicabut |
| 403 | `ip_not_allowed` / `scope_forbidden` | IP tidak diizinkan / key tidak punya izin Kirim riset |
| 404 | `file_not_found` | Id tidak ada atau milik key lain |
| 409 | `file_rejected` / `too_many_documents` | Dokumen untuk file laporan yang ditolak / sudah 3 dokumen |
| 411 | `length_required` | Dokumen dikirim tanpa `Content-Length` |
| 405 | `method_not_allowed` | Metode lain; lihat header `Allow` |
| 413 | `body_too_large` | Zip lebih dari 8 MiB atau dokumen lebih dari 20 MiB |
| 415 | `unsupported_media_type` / `unsupported_document_type` | `Content-Type` bukan zip / bukan PDF atau XLSX |
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

Kode penolakan dokumen sumber (`documents[].error.code`):

| Kode | Arti |
|---|---|
| `invalid_document` | Bukan PDF/XLSX yang utuh (misalnya PDF terpotong, XLSX yang sebenarnya dokumen Word) |
| `active_content` | PDF berisi JavaScript atau perintah peluncuran program |
| `macro_not_allowed` | XLSX berisi makro |
| `infected` | Ditandai antivirus. File langsung dihapus |
| `checksum_mismatch`, `object_missing`, `file_too_large`, `too_many_attempts` | Sama artinya seperti untuk file laporan |

## 6. Mengirim satu folder dari Windows

Skrip `scripts/research/kirim-riset.ps1` mengirim semua `*.zip` di satu folder berurutan, mencatat hasilnya, dan memindahkan file yang sudah diterima ke subfolder `terkirim`.

Dokumen sumber ikut terkirim bila namanya diawali nama zip-nya. Misalnya `BBCA-2026-Q3.zip` membawa `BBCA-2026-Q3.pdf` dan `BBCA-2026-Q3 data.xlsx`. Nama file dokumen dipakai sebagai nama yang tampil di aplikasi. Zip baru dipindah ke `terkirim` setelah semua dokumennya diterima, jadi skrip aman dijalankan ulang. Cocok untuk staf yang mengunduh laporan dari situs IDX lewat browser, atau dijalankan berkala lewat Task Scheduler.

```powershell
$env:RESEARCH_KEY = '<API key>'
.\scripts\research\kirim-riset.ps1 -Folder 'D:\Laporan IDX' -ApiBase 'http://192.168.0.235:8000'
```

Key dibaca dari variabel lingkungan `RESEARCH_KEY`, tidak pernah ditulis ke file atau log. Emiten dan periode dibaca dari isi XBRL, jadi nama zip bebas. Bila ingin melampirkan dokumen, beri nama unik per laporan. Unduhan IDX bernama `instance.zip`, jadi ganti namanya dulu.

## 7. Mendapatkan file XBRL

File `instance.zip` ada di halaman Laporan Keuangan dan Tahunan situs IDX (kolom lampiran setiap laporan), bersama dokumen PDF laporan keuangannya dan file `FinancialStatement-….xlsx`. Situs IDX memblokir pengambilan otomatis oleh skrip, jadi server Rendezvous tidak mengunduh sendiri. Sumber yang bisa dipakai:

- **Unduh lewat browser** lalu kirim dengan skrip di atas, atau unggah di Hub (**Komunitas → Riset → Unggah laporan**).
- **Sistem yang sudah berlangganan data** (backend OLT atau vendor data) memanggil API ini setiap ada laporan baru.

Untuk ringkasan yang lengkap, kirim juga laporan kuartal sebelumnya dan laporan periode yang sama tahun lalu satu kali di awal. Setelah itu pembanding tersimpan dengan sendirinya.
