# research

Layanan riset (versi **0.2.0**). Jenis pertama: laporan keuangan emiten. Menerima file XBRL `instance.zip` dari bursa lewat `POST /integration/v1/research` (API key izin `research`) dan dari unggahan staf di Hub, lalu mengurainya satu per satu, menghitung angka dan rasio, menyusun ringkasan teks polos dan dokumen kartu riset berbahasa Indonesia dengan template tetap (tanpa AI), dan membuat postingan resmi berstatus `pending` untuk disetujui staf. Desain dan keputusan: [docs/riset/README.md](../../docs/riset/README.md). Kontrak untuk pengirim: [docs/integration/riset.md](../../docs/integration/riset.md). Migrasi: `0197_financial_reports.sql`, `0199_research.sql`.

Hanya Go standard library. Image distroless nonroot, subcommand `healthcheck`.

```
Pengirim ──▶ Traefik (body ≤ 8 MiB) ──▶ Kong /integration/v1/research ──▶ research:8080
                                                                                   │ key, scope, rate limit, 2 slot unggah
                                                                                   │ cek direktori zip, SHA-256
                                                                                   ├─▶ storage: financial-reports/api/<sha>/report.zip
                                                                                   └─▶ research_submit ─▶ private.research_files (queued)
Hub ──▶ storage hub/<staf>/<uuid>/report.zip ──▶ cs_api.research_upload ───────────────┘
                                                                                   │
                         worker (1 file sekali jalan) ◀── research_claim ─────────┘
                         unduh ─ SHA-256 ─ ClamAV ─ buka zip ─ urai XBRL ─ research_related
                         hitung (analysis) ─ teks (summary) ─ research_complete / research_fail
```

Layanan `integration` tidak ikut menangani rute ini: Kong memilih prefix terpanjang, jadi hanya `/integration/v1/research*` yang diarahkan ke sini.

## API (port 8080)

| Metode dan path | Isi |
|---|---|
| `POST /research` | Body = isi `instance.zip` apa adanya, `Content-Type: application/zip` (juga `application/x-zip-compressed`, `application/octet-stream`). `202` bila masuk antrean, `200` bila file yang sama sudah pernah dikirim (`resubmitted: true`) atau isinya sudah ada (`status: duplicate`) |
| `GET /research/{id}` | Status file milik key yang sama: `queued`, `processing`, `done`, `duplicate`, `rejected`, plus `report` dan `error` |

Urutan pemeriksaan `POST`: batas gagal-auth per IP → API key (hash SHA-256 ke `integration_authenticate`, cache 30 detik) → IP/CIDR → izin `financial_report` → rate limit per key → `Content-Type` → `Content-Length` ≤ `MAX_FILE_BYTES` → slot unggah (`MAX_UPLOADS`, tunggu ≤ 3 detik lalu `503 busy`) → baca body → periksa direktori zip tanpa membuka isinya (maks 16 entri, satu `.xbrl`, ≤ 32 MiB setelah dibuka, rasio ≤ 200:1) → simpan ke storage → `public.research_submit`. Batas per jam per key (`research.files_per_hour`) dan deduplikasi diputuskan database. Kode error dan pesannya ada di `internal/api/errors.go`; format respons sama dengan layanan `integration` (`{"error": "...", "message": "..."}`).

## Worker

1. `public.research_claim(instance, lease)` mengambil satu file (`FOR UPDATE SKIP LOCKED`). File yang sudah `research.max_attempts` kali dicoba ditolak `too_many_attempts`.
2. Unduh dari storage (≤ `MAX_FILE_BYTES`), cocokkan SHA-256 dengan yang diterima API, pindai ClamAV (`zINSTREAM`).
3. `internal/xbrl`: buka zip dengan batas di atas, urai XML secara mengalir (`encoding/xml`, mode ketat, entitas eksternal tidak diproses). Konteks dikenali dari tanggal `idx-dei` (bukan nama konteks); konteks berdimensi diabaikan. Hasilnya angka per akun untuk `current`, `prior`, `current_end`, `prior_year_end`.
4. `public.research_related` mengambil laporan kumulatif sebelumnya di tahun buku yang sama dan laporan periode yang sama tahun lalu.
5. `internal/analysis`: pilih template (`bank` bila ada pos bunga dan kredit, `general` bila ada penjualan, selain itu `basic`), hitung kumulatif, kuartal tunggal, neraca YoY/QoQ, rasio, dan peringatan (`restated`, `template_basic`, `missing_lines`).
6. `internal/summary`: susun teks polos (maks 2.000 karakter) dengan cashtag `$KODE` di awal, dan dokumen kartu versi 1 (`Build`: badge, judul, headline, paragraf, angka kunci, poin bernomor, poin utama, disclaimer). Format dokumen: [docs/riset/README.md](../../docs/riset/README.md#2-kartu-riset-dokumen-versi-1).
7. `public.research_complete` menyimpan laporan, menandai revisi, dan membuat postingan resmi dalam satu transaksi. Kegagalan memanggil `public.research_fail`: permanen (`not_zip`, `invalid_xbrl`, `infected`, …) langsung ditolak; sementara (`storage_unavailable`, `scanner_unavailable`, `store_unavailable`) dicoba lagi dengan jeda 1, 4, 9, 16 menit.

Satu file maksimal `JOB_TIMEOUT`. Lease (`LEASE`) lebih panjang dari itu, jadi worker yang mati di tengah jalan membuat file diambil lagi setelah lease habis. File yang baru diterima API instance ini membangunkan worker langsung; selain itu antrean dicek tiap `POLL_INTERVAL`.

## Batas beban

| Batas | Nilai |
|---|---|
| Container | 1 replika, CPU `RESEARCH_CPUS` (0,25), memori 128 MB, 64 proses, `cpu_shares` 256, `GOMAXPROCS=1`, `GOMEMLIMIT=96MiB`, jaringan `app` saja |
| Unggahan | `MAX_UPLOADS` (2) bersamaan, `MAX_FILE_BYTES` (8 MiB), Traefik `EDGE_BODY_MAX_RESEARCH` (8 MiB) |
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
| `HEARTBEAT_INTERVAL` | `30s` | Heartbeat ke `service_heartbeat`, layanan `research` (Riset) di Kesehatan sistem |
| `SHUTDOWN_TIMEOUT` | `20s` | |
| `LOG_LEVEL` | `info` | |

## Metrik (`GET :9100/metrics`)

`research_requests_total{endpoint,code}`, `research_uploaded_bytes_total`, `research_reports_total{result}` (`done`, `duplicate`, `retry`, `rejected`, `lease_lost`), `research_inflight_uploads`, `research_max_uploads`, `research_worker_busy`, `research_key_cache_entries`, `research_store_consecutive_failures`, `research_last_heartbeat_timestamp_seconds`.

Heartbeat `degraded` bila PostgREST atau storage gagal 3 kali berturut-turut.

## Tes

```
make test-research         # atau .\make.ps1 test-research
```

Fixture XBRL di `internal/xbrltest` dibuat dari kode dengan emiten fiktif `ABCD` dan `WXYZ`, jadi repo tidak menyimpan data emiten sungguhan. Template `bank` juga sudah dicocokkan secara manual dengan laporan BBCA Q2 2026, Q3 2025, dan Q3 2026.
