# Model klasifikasi gambar

## Model yang dipakai

| | |
|---|---|
| Nama | `taufiqdp/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier` (id di manifest: `mobilenetv4-conv-small-nsfw@504317a`) |
| Sumber | https://huggingface.co/taufiqdp/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier |
| Commit | `504317ad62086f357c9c5f70cf983726ff47efdb` (31 Jul 2024) |
| File | `mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier.onnx`, 9.974.311 byte |
| SHA-256 | `46995c000cb285d0c0a0e5b58cc618012ed2e649d326d4fddae910951848fc40` (sama dengan hash LFS di Hugging Face, dicek ulang setelah diunduh) |
| Lisensi | **Apache-2.0**, dinyatakan pembuatnya di metadata model card (`license: apache-2.0`, https://huggingface.co/taufiqdp/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier/blob/504317ad62086f357c9c5f70cf983726ff47efdb/README.md). Model dasar `timm/mobilenetv4_conv_small.e2400_r224_in1k` juga Apache-2.0 |
| Arsitektur | MobileNetV4 conv small (timm), 2,52 juta parameter, ONNX opset 11, CPU |
| Kelas | `drawings`, `hentai`, `neutral`, `porn`, `sexy` (urutan output) |
| Input | tensor float `[3, 224, 224]` RGB 0–1 (tanpa dimensi batch). Normalisasi ImageNet (mean 0.485/0.456/0.406, std 0.229/0.224/0.225) sudah ada di dalam graf ONNX, jadi manifest memakai mean 0 dan std 1 |
| Output | logit `[1, 5]`, classifier menghitung softmax |

File ONNX diunduh saat `docker build` dari URL commit di atas dan build gagal bila SHA-256 berbeda. Classifier menghitung ulang SHA-256 saat start dan menolak model bila tidak cocok dengan `model/manifest.json`.

Model card hanya berisi metadata (tanpa deskripsi dataset atau akurasi). Lima kelasnya sama dengan dataset NSFW publik yang umum dipakai (drawings/hentai/neutral/porn/sexy).

## Kalibrasi singkat

Skor maksimum dari dua tampilan (potongan tengah + gambar penuh) pada gambar aman, diukur dengan classifier ini (Go, 3 Nov 2026). Foto contoh dari `scikit-image` (domain publik), grafik candlestick dan screenshot teks dibuat sintetis:

| Gambar | drawings | hentai | neutral | porn | sexy |
|---|---|---|---|---|---|
| Astronaut (foto orang) | 0.006 | 0.000 | 0.999 | 0.000 | 0.000 |
| Roket | 0.192 | 0.001 | 0.978 | 0.000 | 0.001 |
| Kucing | 0.056 | 0.006 | 0.667 | **0.326** | 0.162 |
| Kopi | 0.337 | **0.274** | 0.532 | 0.023 | 0.153 |
| Grafik candlestick | 0.460 | 0.201 | 0.321 | 0.001 | **0.621** |
| Screenshot teks saham | 0.119 | 0.023 | 0.950 | 0.006 | 0.097 |

Model kecil ini cukup "berisik" pada grafik dan gambar sintetis (kelas `sexy` sampai 0.62 untuk grafik candlestick). Karena itu ambang bawaan di migrasi 0079 sengaja tidak terlalu rendah: porn tahan 0.50 / blokir 0.90, hentai tahan 0.60 / blokir 0.95, sexy tahan 0.85 (tanpa blokir otomatis). Kepatuhan sebaiknya memantau jumlah gambar tertahan di minggu-minggu pertama dan menyesuaikan ambang dari web. Tes tidak pernah memakai atau membuat konten seksual; kasus "positif" di tes memakai model palsu.

## Kandidat lain yang diperiksa

| Model | Lisensi (sumber asli) | Kenapa tidak dipakai sekarang |
|---|---|---|
| `GantMan/nsfw_model` (MobileNetV2, 5 kelas) | MIT untuk proyek, tetapi LICENSE menyebut ada materi pihak ketiga berlisensi lain | Hanya Keras/TF.js, perlu konversi sendiri ke ONNX |
| `Marqo/nsfw-image-detection-384` (ViT tiny, 2 kelas, 22 MB) | Apache-2.0 (model card), dataset 220 ribu gambar terdokumentasi | Hanya safetensors/timm; perlu konversi ke ONNX dan hosting file hasil konversi. Kandidat pengganti bila tingkat salah tahan terlalu tinggi |
| `Falconsai/nsfw_image_detection` (ViT base) | Apache-2.0 | ±340 MB, terlalu besar untuk CPU kecil |
| `expertskb/nsfwpy` (ONNX campuran) | Repo menyatakan MIT padahal salah satu basisnya Apache-2.0 | Asal-usul file hasil konversi pihak ketiga tidak jelas |
| NudeNet | Bukan lisensi permisif (AGPL/GPL) | Ditolak |

## Mengganti model

Classifier tidak terikat pada model ini. Buat folder berisi `manifest.json` + file ONNX, lalu pasang ke `MODEL_DIR` (atau ubah `ARG MODEL_URL`/`MODEL_SHA256` dan `model/manifest.json` lalu build ulang):

```json
{
  "id": "nama@versi",
  "file": "model.onnx",
  "sha256": "<sha-256 file ONNX>",
  "input": "input", "output": "output",
  "shape": [3, 224, 224],
  "crop_pct": 0.875,
  "mean": [0, 0, 0], "std": [1, 1, 1],
  "activation": "softmax",
  "labels": ["drawings", "hentai", "neutral", "porn", "sexy"],
  "source": "<url>", "license": "<spdx>"
}
```

`shape` boleh `[3,S,S]` atau `[1,3,S,S]`. `activation` `softmax` (output logit) atau `none` (output sudah probabilitas). Label baru harus juga ditambahkan ke `private.media_categories()` (migrasi baru) agar Kepatuhan bisa memberi ambang. Tanpa model yang valid, classifier tetap jalan tetapi menjawab 503 `model_missing`, heartbeat berstatus `error`, dan media menolak upload gambar (fail closed) kecuali `MODEL_MISSING_POLICY=allow`.

## Runtime

ONNX Runtime 1.31.0 (`microsoft/onnxruntime`, MIT), `onnxruntime-linux-x64-1.31.0.tgz` SHA-256 `cc5c72baf5ae5c8238a6841f0897227be2d02826b9cf98eaf02fdefaeeb03a57`, commit `402979ac1bef89dcd55add41eaa7277c407599eb`. `LICENSE` dan `ThirdPartyNotices.txt` ikut disalin ke `/usr/lib/onnxruntime/` di image. Binding Go `github.com/yalue/onnxruntime_go` v1.38.0 (MIT, Nathan Otterness; memakai header C API 1.31.0). Decoder WebP `golang.org/x/image` v0.47.0 (BSD-3-Clause), sudah memuat perbaikan WebP GO-2026-4961, GO-2026-5061, dan GO-2026-6222. Karena x/image ≥ 0.45 butuh Go 1.26, `go.mod` layanan ini memakai `go 1.26.0` (layanan lain `go 1.24.5`); toolchain build tetap 1.27.3.
