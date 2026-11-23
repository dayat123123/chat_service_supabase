# API Kesehatan Sistem

Panduan untuk tim aplikasi internal yang ingin menampilkan kesehatan server Rendezvous di aplikasinya sendiri, misalnya dasbor monitoring kantor. Isinya sama dengan halaman **Kesehatan sistem** dan **Peta layanan** di Rendezvous Hub, karena keduanya dibuat oleh fungsi database yang sama.

| | |
|---|---|
| Endpoint | `GET /integration/v1/system/health` dan `GET /integration/v1/system/nodes` |
| Autentikasi | `Authorization: Bearer oik_…` (API key dengan izin **Baca kesehatan sistem**) |
| Sifat | Hanya baca. Tidak bisa menandai alert, me-restart layanan, atau mengubah pengaturan |
| Format | JSON, `api_version: 1` |
| Kontrak mesin | [kesehatan-sistem.openapi.yaml](../api/kesehatan-sistem.openapi.yaml) (OpenAPI 3.1) |
| Tersedia sejak | Server migrasi `0189`, layanan `integration` 0.3.0 (23 November 2026) |

## 1. Mulai cepat

1. **Buat API key.** Super Admin membuka Hub, **Pengaturan → API Integrasi → Buat API key**, memberi nama (misalnya "Dasbor monitoring"), mencentang hanya **Baca kesehatan sistem**, dan sebaiknya mengisi IP server aplikasi Anda di **IP atau CIDR yang diizinkan**. Key berawalan `oik_` hanya ditampilkan sekali. Dialognya langsung menampilkan alamat endpoint dan contoh perintah dengan key itu.
2. **Simpan key sebagai rahasia** di backend aplikasi Anda (variabel lingkungan atau secret manager). Jangan ditaruh di kode, frontend, atau log.
3. **Panggil dari backend:**

   Linux / macOS:
   ```bash
   curl -sS "https://<domain API>/integration/v1/system/health" -H "Authorization: Bearer $HEALTH_KEY"
   ```

   Windows PowerShell (pakai `curl.exe`, bukan `curl`):
   ```powershell
   curl.exe -sS "https://<domain API>/integration/v1/system/health" -H "Authorization: Bearer $env:HEALTH_KEY"
   ```

   Di server dev kantor, `<domain API>` adalah `192.168.0.235:8000` dengan `http://`. Alamat persisnya juga tertulis di Hub, di kartu **API kesehatan sistem**.

Respons berhasil berupa JSON yang diawali `"api_version": 1` dan `"status": "ok"`, `"warning"`, atau `"critical"`.

## 2. Akses dan batasan

| Hal | Aturan |
|---|---|
| Header | Hanya `Authorization: Bearer <key>`. Header `apikey` (anon key) **tidak** diperlukan; bila dikirim, diabaikan |
| Metode | `GET` tanpa body. Metode lain dijawab `405` dengan header `Allow: GET` |
| Izin key | `health_read`. Key notifikasi atau bot ditolak `403 scope_forbidden`. Buat key tersendiri untuk keperluan ini |
| IP | Bila key dibatasi IP, request dari IP lain ditolak `403 ip_not_allowed`. IP yang dicek adalah IP yang terlihat dari server Rendezvous |
| Batas | `rate_limit_per_minute` per key (bawaan 3.000 per menit), dihitung bersama untuk kedua endpoint |
| Key salah | Lebih dari 30 percobaan key salah per menit dari satu IP dijawab `429 too_many_auth_failures` |
| Cabut | Key yang dicabut atau dinonaktifkan di Hub langsung ditolak (cache paling lama 30 detik) |
| Dari mana | **Selalu dari backend.** Jangan memanggil dari browser: key akan terlihat siapa pun yang membuka halaman |
| Frekuensi | Kesehatan dievaluasi ±30 detik sekali, peta layanan ±10 detik sekali. Polling setiap **15–30 detik** sudah cukup |
| Cache | Respons membawa `Cache-Control: no-store`. Simpan hasil terakhir di backend Anda, lalu sajikan ke pengguna dari sana |
| Audit | Setiap pemakaian memperbarui **Terakhir dipakai** dan IP-nya di daftar key Hub |

## 3. `GET /integration/v1/system/health`

Isi halaman **Pengaturan → Sistem → Kesehatan sistem** di Hub.

### 3.1 Field tingkat atas

| Field | Tipe | Isi |
|---|---|---|
| `api_version` | integer | Saat ini `1` |
| `status` | `ok` / `warning` / `critical` | `critical` bila ada pemeriksaan kritis yang gagal, `warning` bila ada yang gagal tetapi tidak kritis, `ok` bila semua sehat |
| `now` | waktu | Waktu server saat menjawab |
| `evaluated_at` | waktu / null | Kapan pemeriksaan terakhir dievaluasi. Bila jauh lebih tua dari `now` (lebih dari 2 menit), evaluator berhenti; anggap data basi |
| `checks` | array | Pemeriksaan yang **sedang gagal** (lihat 3.2). Kosong berarti semua sehat |
| `alerts.open` | array | Alert yang belum selesai, terbaru dulu |
| `alerts.recent` | array | Alert yang selesai dalam 7 hari terakhir (maks. 30) |
| `services` | array | Layanan yang melapor (heartbeat) beserta setiap instance-nya |
| `probes` | array | Hasil cek endpoint tiap layanan oleh pemantau |
| `disks` | array | Kapasitas disk server |
| `database` | objek | Ukuran, koneksi, replication slot |
| `queues` | objek | Antrean push, pembersihan file, dan pengiriman alert |
| `cron` | array | Jadwal pekerjaan database dan hasil terakhirnya |
| `backup` | objek | Status backup tanpa lokasi penyimpanan |
| `channels` | objek | Ringkasan kanal alert (Telegram, email) |

Waktu berformat ISO-8601 dengan zona waktu, contoh `2026-11-23T08:30:00.123+00:00`.

### 3.2 `checks[]` dan `alerts`

| Field | Isi |
|---|---|
| `key` | Kunci stabil pemeriksaan, cocok untuk dipakai program (lihat tabel di bawah) |
| `severity` | `warning` atau `critical` |
| `title` | Judul berbahasa Indonesia, sama dengan yang tampil di Hub |
| `detail` | Penjelasan tambahan, bisa null |
| `failing_since` | Sejak kapan gagal |

`alerts.open[]` dan `alerts.recent[]` berisi `id`, `key`, `severity`, `title`, `detail`, `opened_at`, `resolved_at` (khusus `recent`), serta `acknowledged_by` dan `acknowledged_at` bila staf sudah menandai alert itu sedang ditangani.

Awalan `key` yang dipakai sekarang:

| Awalan | Arti |
|---|---|
| `service:<nama>` | Layanan berhenti mengirim heartbeat atau melaporkan error |
| `probe:<nama>` | Endpoint layanan tidak menjawab dengan benar |
| `disk:<nama>` | Disk hampir penuh (peringatan 80%, kritis 90%, bawaan) |
| `db:connections`, `db:lock_waits`, `db:long_transaction`, `db:slot:<nama>` | Masalah database |
| `pgbouncer:queue`, `rest:pool`, `realtime:events` | Antrean koneksi atau beban berlebih |
| `queue:push`, `queue:storage_cleanup`, `queue:room_preview` | Antrean menumpuk |
| `cron:<job>` | Pekerjaan terjadwal gagal |
| `backup:<…>` | Backup belum diatur, tertinggal, gagal, atau uji restore gagal |
| `alerts:delivery`, `alerts:secret` | Alert gagal terkirim atau kunci kanal alert tidak terbaca |
| `healer:<…>` | Restart otomatis bermasalah atau berhenti melapor |
| `metrics:<…>` | Metrik layanan melewati ambang |

Daftar ini bisa bertambah. Tampilkan `title` apa adanya untuk awalan yang belum Anda kenal.

### 3.3 Detail lain

| Bagian | Field |
|---|---|
| `services[]` | `service`, `label`, `instances[]`: `instance`, `version`, `started_at`, `last_seen_at`, `status` (`ok`, `degraded`, `error`), `error`, `detail`, `live` (heartbeat dalam 90 detik terakhir) |
| `probes[]` | `name`, `label`, `ok`, `status` (kode HTTP), `latency_ms`, `error`, `checked_at`, `last_ok_at`, `stale` (lebih tua dari 90 detik) |
| `disks[]` | `name`, `total_bytes`, `avail_bytes`, `used_ratio` (0–1), `checked_at` |
| `database` | `size_bytes`, `connections`, `max_connections`, `slots[]`: `name`, `type`, `active`, `wal_status`, `retained_bytes` |
| `queues` | `push.queued`, `push.oldest_at`, `storage_cleanup.pending`, `storage_cleanup.failing`, `storage_cleanup.oldest_at`, `alerts.pending`, `alerts.failed_24h` |
| `cron[]` | `job`, `schedule` (ekspresi cron dalam **UTC**), `active`, `last_status`, `last_start`, `last_message` |
| `backup` | `configured`, `kind` (`s3` atau `local`), `live`, `state`, `last_base`, `last_files`, `last_restore_test` |
| `channels.telegram`, `channels.email` | `enabled`, `configured`, `last` (`kind`, `status`, `at`, `error` pengiriman terakhir) |

## 4. `GET /integration/v1/system/nodes`

Isi **Peta layanan** di Hub: setiap container yang berjalan beserta pemakaian CPU dan memorinya.

### 4.1 Field tingkat atas

| Field | Isi |
|---|---|
| `api_version` | `1` |
| `now` | Waktu server saat menjawab |
| `reported_at` | Kapan laporan container terakhir diterima |
| `stale` | `true` bila laporan lebih tua dari 45 detik (bawaan). Artinya pemantau berhenti melapor; tampilkan data sebagai "tidak terbaru" |
| `report` | Laporan container (lihat 4.2) |
| `probes[]` | `name`, `ok`, `latency_ms`, `checked_at`, `failing_since` |
| `restarts[]` | Restart otomatis oleh healer dalam 24 jam terakhir: `service`, `count`, `last_at` |
| `versions` | Objek `{ "<layanan>": "<versi>" }` versi terakhir yang dilaporkan |

### 4.2 `report`

| Field | Isi |
|---|---|
| `version` | Versi healer yang membuat laporan |
| `project` | Nama proyek Docker Compose |
| `checked_at` | Waktu laporan dibuat |
| `host` | `name`, `cpus`, `memory_bytes`, `os`, `docker_version` |
| `containers[]` | Satu baris per container (lihat bawah) |
| `error` / `read_error` | Muncul bila pembuatan atau pembacaan laporan gagal |

`containers[]`:

| Field | Isi |
|---|---|
| `service` | Nama layanan, misalnya `rest`, `realtime`, `db` |
| `name` | Nama container |
| `replica` | Nomor replika (1, 2, …) |
| `host` | Nama server |
| `state` | `running`, `exited`, `restarting`, `created`, `paused`, `dead` |
| `health` | `healthy`, `unhealthy`, `starting`, atau kosong bila layanan tidak punya healthcheck |
| `started_at`, `finished_at` | Waktu start dan berhenti terakhir |
| `exit_code` | Kode keluar terakhir (penting untuk container yang `exited`) |
| `restarts` | Jumlah restart oleh Docker sejak container dibuat |
| `image` | Image dan versinya |
| `autoheal` | `true` bila healer boleh me-restart otomatis bila macet |
| `cpu_percent` | Pemakaian CPU. **100 = satu core penuh** (seperti `docker stats`), bisa lebih dari 100 pada server multi-core. Null pada laporan pertama setelah start |
| `memory_bytes` | Memori terpakai |
| `memory_limit_bytes` | Batas memori container, null bila tidak dibatasi |

Container yang **wajar berstatus `exited`** dengan `exit_code` 0: `migrate`, `volume-init`, dan `tools`. Ketiganya berjalan sekali lalu selesai.

## 5. Error

Format error: `{"error": "<kode>", "message": "<penjelasan>"}` plus header `X-Request-Id`. Kirim header `X-Request-Id` sendiri (huruf, angka, `.`, `_`, `-`, maks. 64) bila ingin melacak request di log server.

| HTTP | `error` | Arti | Tindakan |
|---|---|---|---|
| 401 | `missing_key` | Header Authorization tidak ada | Perbaiki konfigurasi |
| 401 | `invalid_key` | Key salah, nonaktif, atau dicabut | Periksa key di Hub |
| 403 | `scope_forbidden` | Key tanpa izin Baca kesehatan sistem | Pakai key yang benar |
| 403 | `ip_not_allowed` | IP pemanggil tidak diizinkan | Tambahkan IP di key, atau panggil dari server yang diizinkan |
| 404 | `not_found` | Alamat salah, atau server belum memasang versi ini | Periksa URL dan versi server |
| 405 | `method_not_allowed` | Bukan `GET` | Pakai `GET` |
| 429 | `rate_limited`, `too_many_auth_failures` | Terlalu sering | Tunggu sesuai `Retry-After` |
| 503 | `unavailable`, `busy` | Database tidak terjangkau atau server sibuk | Coba lagi setelah `Retry-After` |

Bila API sendiri tidak bisa dihubungi (timeout, koneksi ditolak), itu juga tanda penting: tampilkan "Server tidak terjangkau", jangan menampilkan data terakhir seolah masih sehat.

## 6. Saran tampilan

- **Lampu status:** hijau untuk `ok`, kuning untuk `warning`, merah untuk `critical`. Abu-abu bila data basi (`stale` di peta layanan, `evaluated_at` lebih tua dari 2 menit, atau request gagal).
- **Daftar masalah:** tampilkan `checks[]` sebagai daftar utama (judul + detail + "sejak"), lalu `alerts.open` bila ingin menampilkan siapa yang sedang menangani (`acknowledged_by`).
- **Kartu container:** kelompokkan `report.containers` per `service`. Tampilkan `state`/`health`, CPU dan memori (memori dibandingkan `memory_limit_bytes` bila ada), dan jumlah restart.
- **Waktu:** semua waktu dalam UTC; tampilkan dalam WIB di aplikasi Anda.
- **Jangan mengandalkan urutan field** dan abaikan field yang tidak dikenal.

## 7. Contoh kode

### Node.js (18+)

```js
const res = await fetch(`${process.env.RENDEZVOUS_API}/integration/v1/system/health`, {
  headers: { Authorization: `Bearer ${process.env.HEALTH_KEY}` },
  signal: AbortSignal.timeout(10_000),
})
if (!res.ok) throw new Error(`health ${res.status}: ${(await res.json()).error}`)
const health = await res.json()
console.log(health.status, health.checks.map((c) => `${c.severity} ${c.title}`))
```

### Python 3

```python
import json, os, urllib.request

req = urllib.request.Request(
    os.environ["RENDEZVOUS_API"] + "/integration/v1/system/nodes",
    headers={"Authorization": "Bearer " + os.environ["HEALTH_KEY"]},
)
with urllib.request.urlopen(req, timeout=10) as resp:
    nodes = json.load(resp)
for c in nodes["report"]["containers"]:
    print(c["service"], c["replica"], c["state"], c.get("health"), c.get("cpu_percent"))
```

### Go

```go
req, _ := http.NewRequestWithContext(ctx, http.MethodGet, api+"/integration/v1/system/health", nil)
req.Header.Set("Authorization", "Bearer "+os.Getenv("HEALTH_KEY"))
resp, err := http.DefaultClient.Do(req)
if err != nil {
	return err
}
defer resp.Body.Close()
var health struct {
	Status string `json:"status"`
	Checks []struct {
		Key, Severity, Title string
	} `json:"checks"`
}
if err := json.NewDecoder(resp.Body).Decode(&health); err != nil {
	return err
}
```

## 8. Contoh respons

`GET /system/health` (dipersingkat):

```json
{
  "api_version": 1,
  "status": "warning",
  "now": "2026-11-23T08:30:00.120+00:00",
  "evaluated_at": "2026-11-23T08:29:45.010+00:00",
  "checks": [
    {"key": "disk:data", "severity": "warning", "title": "Disk data hampir penuh",
     "detail": "Terpakai 86%, sisa 69 GB dari 500 GB", "failing_since": "2026-11-23T07:10:00+00:00"}
  ],
  "alerts": {"open": [], "recent": []},
  "services": [{"service": "rest", "label": "REST API", "instances": [{"instance": "rest-1", "status": "ok", "live": true}]}],
  "probes": [{"name": "rest", "label": "REST API", "ok": true, "status": 200, "latency_ms": 4}],
  "disks": [{"name": "data", "total_bytes": 536870912000, "avail_bytes": 74088185856, "used_ratio": 0.862}],
  "database": {"size_bytes": 2147483648, "connections": 41, "max_connections": 100, "slots": []},
  "queues": {"push": {"queued": 0, "oldest_at": null}, "storage_cleanup": {"pending": 0, "failing": 0, "oldest_at": null}, "alerts": {"pending": 0, "failed_24h": 0}},
  "cron": [{"job": "olt-promote-new-accounts", "schedule": "*/15 * * * *", "active": true, "last_status": "succeeded"}],
  "backup": {"configured": true, "kind": "s3", "live": true},
  "channels": {"telegram": {"enabled": true, "configured": true, "last": null}, "email": {"enabled": false, "configured": false, "last": null}}
}
```

`GET /system/nodes` (dipersingkat):

```json
{
  "api_version": 1,
  "now": "2026-11-23T08:30:01.500+00:00",
  "reported_at": "2026-11-23T08:29:55.000+00:00",
  "stale": false,
  "report": {
    "version": "0.2.0",
    "project": "olt-social",
    "checked_at": "2026-11-23T08:29:55.000+00:00",
    "host": {"name": "srv-235", "cpus": 16, "memory_bytes": 34359738368, "os": "Ubuntu 24.04 LTS", "docker_version": "28.1.1"},
    "containers": [
      {"service": "rest", "name": "olt-social-rest-1", "replica": 1, "state": "running", "health": "healthy",
       "restarts": 0, "image": "postgrest/postgrest:v14.18", "autoheal": true,
       "cpu_percent": 3.4, "memory_bytes": 52428800, "memory_limit_bytes": 536870912},
      {"service": "migrate", "name": "olt-social-migrate-1", "replica": 1, "state": "exited", "exit_code": 0}
    ]
  },
  "probes": [{"name": "rest", "ok": true, "latency_ms": 4}],
  "restarts": [],
  "versions": {"integration": "0.3.0", "sentinel": "0.5.0"}
}
```

Angka dan nama di atas hanya contoh.

## 9. Yang sengaja tidak dikirim

Demi keamanan, tiga bagian yang tampil di Hub tidak ikut dikirim ke aplikasi lain:

- **Alamat internal probe** (`probes[].target`, misalnya `http://rest:3000/ready`), karena memperlihatkan struktur jaringan internal.
- **Lokasi backup** (`backup.target`: endpoint dan bucket S3 atau folder lokal).
- **Detail kanal alert:** alamat email, host dan username SMTP, serta chat ID Telegram. Yang dikirim hanya `enabled`, `configured`, dan hasil pengiriman terakhir.

Respons tidak pernah memuat password, token, atau kunci.

## 10. Versi dan kompatibilitas

- Field baru bisa ditambah kapan saja tanpa menaikkan `api_version`. Abaikan field yang tidak dikenal.
- `api_version` naik bila ada perubahan yang tidak kompatibel (field dihapus atau berganti arti). Perubahan seperti itu diumumkan di [catatan rilis](../panduan/catatan-rilis.md).
- Server yang belum memasang migrasi `0189` menjawab `404`.

## 11. Pertanyaan umum

**Kenapa `status` merah padahal semua container `running`?** `status` juga mencakup pemeriksaan di luar container: disk, antrean, backup, cron, dan kanal alert. Lihat `checks[]` untuk penyebabnya.

**Apakah aplikasi saya bisa menandai alert sudah ditangani?** Tidak. API ini hanya baca. Penandaan dilakukan staf di Hub.

**Apakah key ini bisa dipakai untuk mengirim notifikasi?** Tidak, kecuali Super Admin juga mencentang izin notifikasi. Sebaiknya tetap dipisah: satu key per sistem, satu tujuan per key.

**Key saya bocor, apa yang harus dilakukan?** Super Admin mencabut key itu di Hub (**Cabut**, isi alasan), lalu membuat key baru dan memasangnya di aplikasi Anda.
