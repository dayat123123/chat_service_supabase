# finreport

Layanan riset laporan keuangan emiten (versi **0.1.0**). Menerima file XBRL `instance.zip` dari bursa lewat `POST /integration/v1/financial-reports` (API key izin `financial_report`) dan dari unggahan staf di Hub, lalu mengurainya satu per satu, menghitung angka dan rasio, menyusun ringkasan berbahasa Indonesia dengan template tetap (tanpa AI), dan membuat postingan resmi berstatus `pending` untuk disetujui staf. Desain dan keputusan: [docs/laporan-keuangan/README.md](../../docs/laporan-keuangan/README.md). Kontrak untuk pengirim: [docs/integration/laporan-keuangan.md](../../docs/integration/laporan-keuangan.md). Migrasi: `0197_financial_reports.sql`.

Hanya Go standard library. Image distroless nonroot, subcommand `healthcheck`.

```
Pengirim ──▶ Traefik (body ≤ 8 MiB) ──▶ Kong /integration/v1/financial-reports ──▶ finreport:8080
                                                                                   │ key, scope, rate limit, 2 slot unggah
                                                                                   │ cek direktori zip, SHA-256
                                                                                   ├─▶ storage: financial-reports/api/<sha>/report.zip
                                                                                   └─▶ finreport_submit ─▶ private.finreport_files (queued)
Hub ──▶ storage hub/<staf>/<uuid>/report.zip ──▶ cs_api.finreport_upload ───────────────┘
                                                                                   │
                         worker (1 file sekali jalan) ◀── finreport_claim ─────────┘
                         unduh ─ SHA-256 ─ ClamAV ─ buka zip ─ urai XBRL ─ finreport_related
                         hitung (analysis) ─ teks (summary) ─ finreport_complete / finreport_fail
```

Layanan `integration` tidak ikut menangani rute ini: Kong memilih prefix terpanjang, jadi hanya `/integration/v1/financial-reports*` yang diarahkan ke sini.

## API (port 8080)

| Metode dan path | Isi |
|---|---|
| `POST /financial-reports` | Body = isi `instance.zip` apa adanya, `Content-Type: application/zip` (juga `application/x-zip-compressed`, `application/octet-stream`). `202` bila masuk antrean, `200` bila file yang sama sudah pernah dikirim (`resubmitted: true`) atau isinya sudah ada (`status: duplicate`) |
| `GET /financial-reports/{id}` | Status file milik key yang sama: `queued`, `processing`, `done`, `duplicate`, `rejected`, plus `report` dan `error` |

Urutan pemeriksaan `POST`: batas gagal-auth per IP → API key (hash SHA-256 ke `integration_authenticate`, cache 30 detik) → IP/CIDR → izin `financial_report` → rate limit per key → `Content-Type` → `Content-Length` ≤ `MAX_FILE_BYTES` → slot unggah (`MAX_UPLOADS`, tunggu ≤ 3 detik lalu `503 busy`) → baca body → periksa direktori zip tanpa membuka isinya (maks 16 entri, satu `.xbrl`, ≤ 32 MiB setelah dibuka, rasio ≤ 200:1) → simpan ke storage → `public.finreport_submit`. Batas per jam per key (`finreport.files_per_hour`) dan deduplikasi diputuskan database. Kode error dan pesannya ada di `internal/api/errors.go`; format respons sama dengan layanan `integration` (`{"error": "...", "message": "..."}`).

## Worker

1. `public.finreport_claim(instance, lease)` mengambil satu file (`FOR UPDATE SKIP LOCKED`). File yang sudah `finreport.max_attempts` kali dicoba ditolak `too_many_attempts`.
2. Unduh dari storage (≤ `MAX_FILE_BYTES`), cocokkan SHA-256 dengan yang diterima API, pindai ClamAV (`zINSTREAM`).
3. `internal/xbrl`: buka zip dengan batas di atas, urai XML secara mengalir (`encoding/xml`, mode ketat, entitas eksternal tidak diproses). Konteks dikenali dari tanggal `idx-dei` (bukan nama konteks); konteks berdimensi diabaikan. Hasilnya angka per akun untuk `current`, `prior`, `current_end`, `prior_year_end`.
4. `public.finreport_related` mengambil laporan kumulatif sebelumnya di tahun buku yang sama dan laporan periode yang sama tahun lalu.
5. `internal/analysis`: pilih template (`bank` bila ada pos bunga dan kredit, `general` bila ada penjualan, selain itu `basic`), hitung kumulatif, kuartal tunggal, neraca YoY/QoQ, rasio, dan peringatan (`restated`, `template_basic`, `missing_lines`).
6. `internal/summary`: susun teks (maks 2.000 karakter) dengan cashtag `$KODE` di awal.
7. `public.finreport_complete` menyimpan laporan, menandai revisi, dan membuat postingan resmi dalam satu transaksi. Kegagalan memanggil `public.finreport_fail`: permanen (`not_zip`, `invalid_xbrl`, `infected`, …) langsung ditolak; sementara (`storage_unavailable`, `scanner_unavailable`, `store_unavailable`) dicoba lagi dengan jeda 1, 4, 9, 16 menit.

Satu file maksimal `JOB_TIMEOUT`. Lease (`LEASE`) lebih panjang dari itu, jadi worker yang mati di tengah jalan membuat file diambil lagi setelah lease habis. File yang baru diterima API instance ini membangunkan worker langsung; selain itu antrean dicek tiap `POLL_INTERVAL`.

## Batas beban

| Batas | Nilai |
|---|---|
| Container | 1 replika, CPU `FINREPORT_CPUS` (0,25), memori 128 MB, 64 proses, `cpu_shares` 256, `GOMAXPROCS=1`, `GOMEMLIMIT=96MiB`, jaringan `app` saja |
| Unggahan | `MAX_UPLOADS` (2) bersamaan, `MAX_FILE_BYTES` (8 MiB), Traefik `EDGE_BODY_MAX_FINREPORT` (8 MiB) |
| Database | Lewat PostgREST yang sudah ada, tidak menambah koneksi PgBouncer |

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `PORT` / `OPS_PORT` | `8080` / `9100` | API (lewat Kong) / ops internal (`/livez`, `/readyz`, `/metrics`) |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Secret JWT Supabase (≥ 32 karakter) untuk JWT `service_role` |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` / `STORAGE_URL` | `http://rest:3000` / `http://storage:5000` | |
| `CLAMD_ADDR` | `clamav:3310` | |
| `INSTANCE_ID` | hostname + acak | Nama instance di heartbeat dan lease |
| `TRUSTED_PROXIES` | jaringan privat | `X-Forwarded-For` hanya dipercaya dari sini |
| `KEY_CACHE_TTL` | `30s` | |
| `MAX_FILE_BYTES` | `8388608` | 64 KiB–8 MiB |
| `MAX_UPLOADS` | `2` | 1–16 |
| `AUTH_FAILURES_PER_MINUTE` | `30` | Per IP |
| `REQUEST_TIMEOUT` / `SCAN_TIMEOUT` | `30s` / `30s` | |
| `POLL_INTERVAL` | `15s` | |
| `JOB_TIMEOUT` / `LEASE` | `1m` / `2m` | `LEASE` harus lebih panjang dari `JOB_TIMEOUT` |
| `HEARTBEAT_INTERVAL` | `30s` | Heartbeat ke `service_heartbeat`, layanan `finreport` di Kesehatan sistem |
| `SHUTDOWN_TIMEOUT` | `20s` | |
| `LOG_LEVEL` | `info` | |

## Metrik (`GET :9100/metrics`)

`finreport_requests_total{endpoint,code}`, `finreport_uploaded_bytes_total`, `finreport_reports_total{result}` (`done`, `duplicate`, `retry`, `rejected`, `lease_lost`), `finreport_inflight_uploads`, `finreport_max_uploads`, `finreport_worker_busy`, `finreport_key_cache_entries`, `finreport_store_consecutive_failures`, `finreport_last_heartbeat_timestamp_seconds`.

Heartbeat `degraded` bila PostgREST atau storage gagal 3 kali berturut-turut.

## Tes

```
make test-finreport        # atau .\make.ps1 test-finreport
```

Fixture XBRL di `internal/xbrltest` dibuat dari kode dengan emiten fiktif `ABCD` dan `WXYZ`, jadi repo tidak menyimpan data emiten sungguhan. Template `bank` juga sudah dicocokkan secara manual dengan laporan BBCA Q2 2026, Q3 2025, dan Q3 2026.
