# classifier

Klasifikasi NSFW untuk gambar yang diunggah nasabah. Layanan `media` mengirim setiap gambar (setelah metadata dibuang) ke `POST /classify` sebelum menyimpannya, lalu memutuskan izinkan / tahan / blokir berdasarkan ambang dari database (lihat `services/media/README.md`). Classifier sendiri tidak memutuskan apa pun, hanya memberi skor per kategori.

Model, lisensi, hash, dan kalibrasi: [MODEL.md](MODEL.md). Inferensi CPU dengan ONNX Runtime lewat cgo (`github.com/yalue/onnxruntime_go`); ini satu-satunya layanan Go di repo yang memakai cgo dan dependensi luar, karena tidak ada runtime ONNX murni Go yang layak. Image: build di `golang:1.27.3-bookworm`, runtime `gcr.io/distroless/cc-debian13:nonroot` (glibc + libstdc++ untuk ONNX Runtime; sejak 0.1.1, karena cc-debian12 masih membawa CVE libssl3), user nonroot, hanya `linux/amd64`. Model dan ONNX Runtime diunduh saat build dengan SHA-256 yang di-pin, jadi `docker build` butuh internet.

Tidak lewat Kong/Traefik: hanya dipanggil `media` di network `app`. Tidak ada autentikasi antarlayanan; classifier tidak menyimpan apa pun dan tidak memegang rahasia selain JWT secret untuk heartbeat.

## `POST /classify`

Body = byte gambar (JPEG, PNG, WebP, GIF), maksimal 10 MiB. `Content-Type` diabaikan, jenis ditentukan dari magic bytes. `X-Request-Id` dipakai ulang bila aman.

1. Model belum termuat → 503 `model_missing`.
2. Menunggu slot (`MAX_CONCURRENT`, antre maks `QUEUE_WAIT`) → 503 `busy` dengan `Retry-After: 2`.
3. Decode: dimensi dicek dulu (≤ 10000 px per sisi, ≤ 40 MP). GIF: struktur dipindai tanpa decode; bila animasi dengan kanvas ≤ 4 MP dan total piksel frame ≤ 16 juta, semua frame di-composite (disposal background/previous dihormati) dan 4 frame diambil merata (pertama, ⅓, ⅔, terakhir); selain itu hanya frame pertama. WebP animasi: hanya frame pertama (chunk `ANMF` pertama dibungkus ulang menjadi WebP diam, termasuk `ALPH`). Panic dari decoder ditangkap menjadi 422.
4. Tiap frame menghasilkan dua tampilan: potongan tengah persegi (`crop_pct` × sisi pendek, seperti evaluasi timm) dan gambar penuh yang di-squash ke persegi, supaya konten di tepi gambar panjang tetap terlihat. Resize memakai rata-rata blok (box filter). Transparansi digabung di atas latar putih.
5. Model dijalankan per tampilan, logit → softmax, dan skor tiap kategori = **maksimum** dari semua tampilan/frame (konservatif).

Respons 200:

```json
{"model":"mobilenetv4-conv-small-nsfw@504317a","labels":["drawings","hentai","neutral","porn","sexy"],
 "scores":{"drawings":0.0059,"hentai":0,"neutral":0.9992,"porn":0.0002,"sexy":0.0001},
 "kind":"jpeg","width":512,"height":512,"frames":1,"sampled":1,"views":2}
```

Skor dibulatkan 4 desimal. Karena memakai maksimum, jumlah skor bisa lebih dari 1.

| HTTP | Kode | Kondisi |
|---|---|---|
| 400 | `empty_file` / `invalid_request` | Body kosong / tidak bisa dibaca |
| 404 | `not_found` | Metode atau path lain |
| 408 | `request_timeout` | Body tidak selesai dalam `REQUEST_TIMEOUT` |
| 413 | `file_too_large` | Lebih dari 10 MiB |
| 415 | `unsupported_type` | Bukan JPEG/PNG/WebP/GIF |
| 422 | `image_too_large` / `invalid_image` | Dimensi terlalu besar / gambar rusak atau tidak bisa di-decode |
| 500 | `inference_failed` | ONNX Runtime gagal |
| 503 | `model_missing` / `busy` | Model tidak termuat / slot penuh |

`GET /status` → 200 `{"model","labels","sha256"}` atau 503 `model_missing`. Dipakai media sebagai probe.

## Ops

`OPS_PORT`: `/livez`, `/readyz` (503 bila model tidak termuat atau sedang shutdown), `/metrics` (`classifier_requests_total{code}`, `classifier_inferences_total`, `classifier_duration_seconds`, `classifier_inflight_requests`, `classifier_max_concurrent_requests`, `classifier_model_loaded`, `classifier_consecutive_failures`, `classifier_last_heartbeat_timestamp_seconds`). Subcommand `classifier healthcheck` mengecek `/livez`.

Heartbeat `public.service_heartbeat('classifier', …)` setiap `HEARTBEAT_INTERVAL`: status `ok`; `error` bila model tidak termuat (pesan memuat alasannya); `degraded` setelah 3 kegagalan inferensi berturut-turut. `detail` = `{model, model_sha256 (12 hex), labels, classified, rejected, busy, failed, avg_ms}`.

Log JSON satu baris per permintaan (`request_id`, `code`, `took_ms`, `kind`, `frames`, `views`). Isi gambar dan skor tidak ditulis ke log.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` / `OPS_PORT` | `8080` / `9100` | |
| `LOG_LEVEL` | `info` | |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Token `service_role` 1 menit untuk heartbeat |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `INSTANCE_ID` | hostname + akhiran acak | |
| `MODEL_DIR` | `/model` | Berisi `manifest.json` + file ONNX |
| `ONNXRUNTIME_LIBRARY` | `/usr/lib/onnxruntime/libonnxruntime.so` | |
| `MAX_CONCURRENT` | `2` | 1–64 permintaan bersamaan |
| `THREADS_PER_INFERENCE` | `1` | Thread intra-op ONNX Runtime per inferensi (1–16) |
| `QUEUE_WAIT` | `5s` | 100ms–30s |
| `REQUEST_TIMEOUT` | `30s` | 5s–5m |
| `HEARTBEAT_INTERVAL` | `30s` | 5s–60s |
| `SHUTDOWN_TIMEOUT` | `20s` | 1s–5m |

Kebutuhan sumber daya: satu inferensi ±5–15 ms per tampilan di satu core; decode foto 12 MP butuh ±20 MB. Batasi container ±512 MiB dan 1 CPU untuk `MAX_CONCURRENT=2`.

## Tes

`go test ./...` (dengan `-race` lewat container Go + gcc). Tes ONNX Runtime asli (`internal/onnx`) dilewati kecuali `ONNXRUNTIME_LIBRARY` dan `MODEL_DIR` diisi, misalnya di container `golang:1.27.3-bookworm` dengan `libonnxruntime.so.1.31.0` dan folder model. Gambar tes dibuat sintetis; kasus NSFW memakai model palsu.
