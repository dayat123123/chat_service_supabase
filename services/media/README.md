# media

Pintu upload file untuk nasabah. Foto dari HP biasanya membawa metadata EXIF (lokasi GPS, merek dan seri HP, waktu pemotretan), XMP, IPTC, komentar, thumbnail, bahkan video *motion photo* di ujung file. Layanan media memeriksa isi file dari *magic bytes*, membuang metadata itu tanpa re-encode (piksel tidak berubah sedikit pun), memeriksa PDF, lalu meneruskan file ke Supabase Storage dengan JWT baru yang membawa klaim `"media_verified": true`. Kebijakan storage di database (migrasi `0063_media_uploads.sql`) mewajibkan klaim itu untuk upload nasabah, jadi upload langsung ke `/storage/v1` dari aplikasi ditolak RLS. Staf CS tidak terkena aturan ini.

Sejak 0.2.0 setiap gambar juga diperiksa classifier NSFW (`services/classifier`) sebelum disimpan: gambar yang jelas melanggar ditolak, gambar meragukan disimpan tetapi **ditahan** (hanya terlihat oleh pengunggah dan moderator) sampai ditinjau staf. Lihat bagian "Moderasi gambar".

Media hanya memakai standard library Go. Kong meneruskan `/media/v1/*` ke `http://media:8080/*` (strip path, plugin `cors` + `key-auth` apikey). Media langsung menghubungi container `storage` dan `rest` di jaringan internal.

## Alur `POST /object/{bucket}/{path}`

1. `Authorization: Bearer <JWT>` diverifikasi HS256 dengan `JWT_SECRET_FILE`. Wajib `alg` = `HS256`, `role` = `authenticated`, `sub` berupa UUID, dan `exp` belum lewat (toleransi jam 30 detik, begitu juga `nbf` bila ada). Token `anon` dan `service_role` ditolak. Gagal → 401 `invalid_token`.
2. Bucket harus salah satu dari tabel di bawah. Lainnya → 400 `bucket_not_allowed`.
3. Path 1–6 segmen, tiap segmen `[A-Za-z0-9._-]{1,128}` dan bukan `.`/`..`, total maksimal 400 karakter (tanpa nama bucket). Karakter ber-*percent-encoding* (`%2F`, spasi, huruf non-ASCII) ditolak. Gagal → 400 `invalid_path`.
4. `Content-Length` lebih besar dari batas bucket langsung ditolak 413 tanpa membaca body.
5. Menunggu slot pemrosesan (`MAX_CONCURRENT`). Bila semua slot terpakai lebih dari 5 detik → 503 `busy` dengan header `Retry-After: 2`.
6. Body dibaca sampai batas + 1 byte. Kosong → 400 `empty_file`, melebihi batas → 413 `file_too_large`.
7. Jenis file ditentukan dari magic bytes. Header `Content-Type` dari klien diabaikan. Jenis tidak dikenal atau tidak diizinkan di bucket itu → 415 `unsupported_type`.
8. Sanitasi sesuai jenis (lihat di bawah). Hasilnya selalu file baru, input tidak diubah.
9. Ekstensi segmen terakhir diganti ekstensi kanonik jenis yang terdeteksi (`jpg`, `png`, `webp`, `gif`, `pdf`). Yang dianggap ekstensi adalah teks setelah titik terakhir, kecuali titik di awal nama. Contoh: `foto.jpeg` → `foto.jpg`, `my.photo.HEIC` → `my.photo.jpg`, `avatar` → `avatar.png`, `.hidden` → `.hidden.png`.

   **Moderasi (hanya gambar, bukan PDF).** Gambar hasil sanitasi dikirim ke classifier dan skornya dibandingkan dengan ambang dari database (lihat "Moderasi gambar"). Blokir → 422 `image_blocked`, tidak ada yang disimpan. Tahan → baris `private.media_reviews` dicatat lebih dulu lewat RPC `media_hold`, baru objek diunggah; bila upload ke storage gagal, catatan itu dibatalkan (`media_hold_cancel`). Izinkan → lanjut seperti biasa.
10. Diteruskan ke `POST {STORAGE_URL}/object/{bucket}/{path-final}` dengan `Content-Type` hasil deteksi, `Cache-Control: max-age=3600`, dan `x-upsert: true` hanya bila klien mengirim `x-upsert: true` **dan** bucket `avatars`. `Authorization` berisi JWT baru: salinan semua klaim JWT nasabah + `"media_verified": true`, `iat` = sekarang, `exp` = min(`exp` asli, sekarang + 120 detik), HS256 dengan secret yang sama.
11. Respons sukses 200:

```json
{"bucket":"attachments","path":"posts/<uuid>/foto.jpg","mime":"image/jpeg","size":951,"width":48,"height":64}
```

`path` adalah path final (setelah ekstensi diganti) dan `size` ukuran file yang tersimpan. Bila gambar ditahan untuk ditinjau, respons memuat `"held": true` (field tidak ada untuk gambar biasa); klien boleh menampilkan "sedang ditinjau" kepada pengunggah. Klien wajib memakai `path` dan `mime` dari respons. `width`/`height` sesuai tampilan: bila Orientation EXIF 5–8 (foto HP diputar 90°), lebar dan tinggi ditukar. Untuk PDF, `width`/`height` tidak ada.

Port 8080 hanya melayani `POST /object/...`. Metode atau path lain → 404 `not_found`. Setiap respons membawa `X-Request-Id` (dari header klien bila aman, `[A-Za-z0-9._-]{1,64}`, atau dibuat acak).

## Bucket

| Bucket | Maks | Jenis | `x-upsert` |
|---|---|---|---|
| `avatars` | 2 MiB | JPEG, PNG, WebP | diteruskan |
| `attachments` | 5 MiB | JPEG, PNG, WebP, GIF | diabaikan |
| `cs-documents` | 10 MiB | PDF | diabaikan |

Siapa boleh menulis ke folder mana tetap diatur kebijakan RLS storage (folder milik sendiri, anggota room, tiket CS yang masih terbuka, tidak dibanned, batas upload harian).

## Sanitasi per format

Semua sanitasi *lossless*: data gambar disalin byte per byte, tidak di-decode lalu di-encode ulang.

**JPEG.** Segmen ditelusuri sampai SOS, data scan disalin sampai marker berikutnya (byte stuffing `FF00`, marker restart, dan fill byte dikenali), lalu penelusuran dilanjutkan sampai EOI supaya JPEG progresif juga tertangani. Disimpan: APP0 JFIF, APP2 `ICC_PROFILE`, APP14 Adobe, dan segmen tabel/frame (DQT, DHT, DAC, DRI, SOFn, DNL, DHP, EXP). Dibuang: APP1 (Exif dan XMP), APP12, APP13 (IPTC/Photoshop), COM, APP2 selain ICC (misalnya MPF yang menunjuk ke gambar tambahan di ujung file), APP3–APP11 dan APP15 (termasuk JUMBF/C2PA di APP11), APP0 non-JFIF (misalnya thumbnail JFXX), thumbnail di dalam APP0 JFIF (dimensi thumbnail dinolkan), dan semua data setelah EOI (motion photo, trailer vendor). Bila Exif asli punya Orientation ≠ 1 (dibaca dari IFD0, byte order `II` maupun `MM`), disisipkan APP1 Exif minimal 34 byte yang hanya berisi tag Orientation, tepat setelah SOI/APP0, agar foto HP tidak tampil terputar. Marker cadangan (`JPG`, `JPGn`, `RES`, `TEM`) ditolak. Hasil akhir harus lolos `image/jpeg.DecodeConfig`.

**PNG.** Signature dicek, setiap chunk dicek panjang, nama, dan CRC-nya. Chunk pertama wajib `IHDR`. Dibuang: `tEXt`, `zTXt`, `iTXt`, `eXIf`, `tIME`, dan semua data setelah `IEND`. Bila ada chunk yang dibuang, chunk `iDOT` (optimasi decoding paralel Apple yang berisi offset ke IDAT) ikut dibuang karena offset-nya tidak lagi benar. Wajib ada `IDAT`. Hasil akhir harus lolos `image/png.DecodeConfig`.

**WebP.** Header `RIFF....WEBP` dicek. Chunk `EXIF` dan `XMP ` dibuang, bit flag EXIF (`0x08`) dan XMP (`0x04`) di `VP8X` dibersihkan, ukuran RIFF dihitung ulang, dan data di luar ukuran RIFF dibuang. Chunk pertama wajib `VP8X`, `VP8 `, atau `VP8L`. Dimensi diambil dari kanvas `VP8X` atau header bitstream `VP8 `/`VP8L` (signature, start code, keyframe, versi dicek). Animasi (`ANMF`) wajib didahului `VP8X`. Go tidak punya decoder WebP di standard library, jadi validasi WebP bersifat struktural.

**GIF.** Header `GIF87a`/`GIF89a`, logical screen descriptor, dan color table dicek, lalu blok ditelusuri sampai trailer `0x3B`. Dibuang: Comment Extension, Application Extension selain `NETSCAPE2.0` dan `ANIMEXTS1.0` (misalnya XMP dan ICC), dan data setelah trailer. Graphic Control dan Plain Text Extension disimpan. Maksimal 500 frame. Hasil akhir harus lolos `image/gif.DecodeConfig`.

**PDF.** File tidak diubah, hanya diperiksa:

- Harus diawali `%PDF-1.` atau `%PDF-2.` dan ada `%%EOF` di 2 KiB terakhir. Kalau tidak → 422 `invalid_pdf`.
- Semua nama PDF (`/Nama`) di seluruh file dipindai setelah escape `#xx` diurai, jadi `/J#61vaScript` atau `/#4A#53` tetap terdeteksi.
- `/Encrypt` → 422 `pdf_encrypted`.
- `/JavaScript…`, `/Launch`, `/EmbeddedFile…` (termasuk `/EmbeddedFiles`), `/RichMedia…`, `/XFA` → 422 `pdf_active_content`. `/JS` dihitung konten aktif bila diikuti nilai yang bisa dijalankan (string `(`, hex string `<`, atau referensi objek). Pengecualian ini mencegah penolakan palsu dari byte acak di data gambar terkompresi, yang kebetulan berisi `/JS`.
- Object stream (`/Type /ObjStm`, PDF 1.5+) di-inflate (Flate) lalu dipindai dengan aturan yang sama, karena kamus objek bisa disembunyikan di dalamnya. Object stream yang bukan Flate atau rusak → 422 `invalid_pdf` (tidak bisa diperiksa, jadi ditolak). Total hasil inflate maksimal 16 MiB per file.

Pemindaian ini sengaja konservatif: nama yang muncul di mana pun dihitung, termasuk di dalam stream yang tidak terkompresi.

## Batas

| Batas | Nilai | Kode |
|---|---|---|
| Ukuran file | per bucket (2/5/10 MiB) | 413 `file_too_large` |
| Sisi gambar | ≤ 10000 px | 422 `image_too_large` |
| Total piksel | ≤ 40 MP (40.000.000) | 422 `image_too_large` |
| Frame GIF | ≤ 500 | 422 `image_too_large` |
| Upload paralel | `MAX_CONCURRENT`, antre maks 5 detik | 503 `busy` |
| Waktu per request | `REQUEST_TIMEOUT` (baca body + kirim ke storage) | 408 `request_timeout` / 502 `storage_unavailable` |
| JWT ke storage | maks 120 detik dan tidak melewati `exp` asli | |

## Kode error

Format error: `{"code":"<kode>","message":"<penjelasan singkat Bahasa Indonesia>"}`.

| HTTP | Kode | Kondisi |
|---|---|---|
| 400 | `bucket_not_allowed` | Bucket bukan `avatars`, `attachments`, atau `cs-documents` |
| 400 | `invalid_path` | Path tidak memenuhi aturan |
| 400 | `empty_file` | Body kosong |
| 400 | `invalid_request` | Body tidak bisa dibaca (misalnya chunked encoding rusak) |
| 401 | `invalid_token` | JWT tidak ada, salah tanda tangan, kedaluwarsa, bukan `authenticated`, `sub` bukan UUID. Juga bila storage menolak JWT baru karena `exp` sudah lewat (token nasabah habis dalam masa toleransi 30 detik) |
| 403 | `upload_forbidden` | Ditolak RLS storage (pesan `row-level security`, atau statusCode 403 lain yang bukan masalah tanda tangan JWT) |
| 404 | `not_found` | Metode atau path selain `POST /object/...` |
| 408 | `request_timeout` | Body tidak selesai dikirim dalam `REQUEST_TIMEOUT` |
| 409 | `already_exists` | Objek dengan path itu sudah ada (storage statusCode 409) |
| 413 | `file_too_large` | Melebihi batas bucket (dari media atau storage) |
| 415 | `unsupported_type` | Magic bytes tidak dikenal atau jenisnya tidak diizinkan di bucket |
| 422 | `invalid_image` | Struktur gambar rusak |
| 422 | `image_too_large` | Dimensi atau jumlah frame melebihi batas |
| 422 | `invalid_pdf` | Header/`%%EOF` tidak ada, object stream rusak atau tidak bisa diperiksa |
| 422 | `pdf_encrypted` | PDF terenkripsi atau berpassword |
| 422 | `pdf_active_content` | PDF berisi JavaScript, Launch, file lampiran, RichMedia, atau XFA |
| 422 | `image_blocked` | Classifier menilai gambar melanggar (skor ≥ ambang blokir), atau gambar perlu ditinjau tetapi tujuannya bucket publik `avatars` |
| 429 | `too_many_uploads` | Batas upload harian dari database (HTTP/statusCode 429, atau pesan memuat `too_many`, `429`, `rate_limited`) |
| 502 | `storage_error` | Error lain dari storage, termasuk tanda tangan JWT ditolak (salah konfigurasi `JWT_SECRET`) |
| 502 | `storage_unavailable` | Storage tidak bisa dihubungi atau tidak menjawab sebelum `REQUEST_TIMEOUT` |
| 503 | `busy` | Semua slot terpakai lebih dari 5 detik |
| 503 | `classifier_unavailable` | Classifier tidak bisa dihubungi, timeout, sibuk, atau belum punya model (fail closed). Header `Retry-After: 2` |
| 503 | `moderation_unavailable` | Ambang belum termuat dari database atau catatan penahanan gagal disimpan |
| 500 | `internal_error` | Gagal membuat JWT (seharusnya tidak pernah terjadi) |

Storage-api v1.81 menjawab hampir semua error dengan HTTP 400 dan kode aslinya di field `statusCode` (string), misalnya `{"statusCode":"403","error":"Unauthorized","message":"new row violates row-level security policy","code":"AccessDenied"}`. Media memetakan dari `statusCode` lebih dulu, baru dari status HTTP.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | API upload (lewat Kong) |
| `OPS_PORT` | `9100` | `/livez`, `/readyz`, `/metrics`; tidak lewat Kong. Harus berbeda dari `PORT` |
| `LOG_LEVEL` | `info` | `debug` mencatat juga probe storage yang gagal |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter. Untuk verifikasi JWT nasabah, JWT baru ke storage, dan token `service_role` 1 menit untuk heartbeat |
| `JWT_ISSUER` | `supabase` | `iss` token `service_role` |
| `STORAGE_URL` | `http://storage:5000` | Langsung ke container storage-api |
| `POSTGREST_URL` | `http://rest:3000` | Untuk RPC heartbeat |
| `INSTANCE_ID` | hostname + akhiran acak | Nama instance di heartbeat (maks. 100 karakter) |
| `MAX_CONCURRENT` | `8` | Upload yang diproses bersamaan (1–256). Memori puncak kira-kira `MAX_CONCURRENT` × 30 MiB (PDF 10 MiB + object stream yang di-inflate maks. 16 MiB), jadi batasi memori container sekitar 384 MiB untuk nilai default |
| `REQUEST_TIMEOUT` | `30s` | Batas baca body + kirim ke storage per request (5s–5m) |
| `HEARTBEAT_INTERVAL` | `30s` | 5s–60s |
| `SHUTDOWN_TIMEOUT` | `20s` | Waktu menyelesaikan upload yang sedang jalan saat SIGTERM (1s–5m) |
| `CLASSIFIER_URL` | `http://classifier:8080` | Layanan classifier (network `app`) |
| `CLASSIFIER_TIMEOUT` | `10s` | Batas satu panggilan classifier (1s–60s); lewat batas → 503 `classifier_unavailable` |
| `MODERATION_REFRESH` | `30s` | Interval cek revisi ambang di database (5s–10m) |
| `MODEL_MISSING_POLICY` | `reject` | `reject`: classifier tanpa model = 503 untuk semua gambar. `allow`: gambar disimpan tanpa pemeriksaan (dicatat `decision=unclassified`, peringatan saat start). Classifier yang mati selalu fail closed |

Log berformat JSON. Setiap upload menghasilkan satu baris (`Upload stored`, `Upload rejected`, atau `Upload failed` untuk 5xx) berisi `request_id`, `bucket`, `code`, `status`, `size_in`, `size_out`, `metadata_removed` (jumlah blok yang dibuang), `took_ms`, `decision` (`allow`/`hold`/`block`/`unclassified`) beserta `category` dan `score` tertinggi untuk gambar, dan `reason` teknis singkat untuk error. Token, isi JWT, `sub`, path file, dan isi file tidak pernah ditulis ke log.

## Heartbeat

Media memanggil `public.service_heartbeat('media', instance, version, started_at, status, error, detail)` saat start, setiap `HEARTBEAT_INTERVAL`, dan langsung saat status berubah. `detail` = `{"accepted","rejected","metadata_removed","allowed","held","blocked","unclassified","classifier_failures","thresholds_revision"}` sejak start: upload yang tersimpan, upload yang ditolak (semua kode error), upload tersimpan yang metadatanya dibuang, keputusan moderasi per jenis, kegagalan classifier berturut-turut, dan revisi ambang yang dipakai (null bila belum termuat).

Sebelum tiap heartbeat terjadwal, media mengecek `GET {STORAGE_URL}/status`. Kegagalan menghubungi storage (cek ini maupun upload yang gagal tersambung atau timeout) dihitung berturut-turut. Cek `/status` yang tidak menjawab 200 juga dihitung gagal. Mulai 3 kali, status menjadi `degraded` dengan error "Storage tidak bisa dihubungi (n kali berturut-turut)". Upload yang dijawab storage (apa pun statusnya) atau cek `/status` yang menjawab 200 mengembalikan status ke `ok`. Status ini tidak memengaruhi `/readyz`. Status juga `degraded` bila classifier gagal dipakai 3 kali berturut-turut (upload maupun probe `GET /status` tiap heartbeat; pesan menyebut "Model classifier belum tersedia" bila classifier jalan tanpa model) atau ambang belum termuat.

Heartbeat yang gagal tidak menghentikan layanan. Kegagalan dicatat sekali saat mulai gagal dan sekali saat pulih, bukan di setiap interval.

## Endpoint ops dan metrik

`GET /livez` (liveness), `GET /readyz` (200 setelah konfigurasi dimuat, 503 saat shutdown), `GET /metrics` (format teks Prometheus) di `OPS_PORT`, dan subcommand `media healthcheck` (cek `/livez`) untuk image distroless.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `media_uploads_total{bucket,code}` | counter | `code` = `ok` atau kode error. Bucket tidak dikenal dicatat sebagai `other`. `canceled` = klien memutus koneksi |
| `media_metadata_removed_total` | counter | Upload tersimpan yang metadatanya dibuang |
| `media_received_bytes_total` | counter | Byte body yang dibaca |
| `media_stored_bytes_total` | counter | Byte hasil sanitasi yang diterima storage |
| `media_upload_duration_seconds` | summary | `_sum` dan `_count` |
| `media_inflight_uploads` | gauge | Slot yang sedang dipakai |
| `media_max_concurrent_uploads` | gauge | Nilai `MAX_CONCURRENT` |
| `media_storage_consecutive_failures` | gauge | Kegagalan menghubungi storage berturut-turut |
| `media_moderation_total{decision}` | counter | Keputusan moderasi gambar |
| `media_classifier_duration_seconds` | summary | Waktu menunggu classifier (yang menjawab) |
| `media_classifier_consecutive_failures` | gauge | Kegagalan classifier berturut-turut |
| `media_thresholds_revision` | gauge | Revisi ambang yang dipakai, -1 sebelum termuat |
| `media_last_heartbeat_timestamp_seconds` | gauge | Waktu Unix heartbeat terakhir yang berhasil (0 jika belum ada) |

Saat SIGTERM, `/readyz` menjadi 503, media berhenti menerima koneksi baru, menyelesaikan upload yang sedang jalan dalam batas `SHUTDOWN_TIMEOUT`, lalu keluar dengan kode 0. Atur `stop_grace_period` container lebih panjang dari `SHUTDOWN_TIMEOUT` (misalnya 30s).



## Moderasi gambar

Diperkenalkan di 0.2.0 bersama migrasi `0079_media_moderation.sql` dan layanan `services/classifier`.

**Ambang.** Tabel `private.media_moderation` (satu baris, `revision` naik setiap perubahan). Bentuknya `{"<kategori>": {"hold": 0–1, "block": 0–1}}`, kategori dari `private.media_categories()` (`drawings`, `hentai`, `neutral`, `porn`, `sexy`), `hold` ≤ `block`, dan `porn` wajib punya minimal satu ambang. Bawaan: porn tahan 0.50 / blokir 0.90, hentai tahan 0.60 / blokir 0.95, sexy tahan 0.85 (alasan di `services/classifier/MODEL.md`). Media membaca lewat RPC `service_role` `public.media_moderation_config(p_revision)` saat start dan setiap `MODERATION_REFRESH`; bila revisi sama, database hanya menjawab `{"revision":n,"unchanged":true}`. Bila database tidak bisa dihubungi, ambang terakhir tetap dipakai. Sebelum ambang pertama termuat, semua gambar ditolak 503 `moderation_unavailable`. Kepatuhan mengubahnya dari web lewat `cs_api.compliance_image_thresholds()` / `cs_api.compliance_set_image_thresholds(p_thresholds, p_note)` (peran `compliance`, audit `media.thresholds_set` berisi nilai lama dan baru).

**Keputusan.** Untuk setiap kategori yang punya ambang: skor ≥ `block` → blokir; selain itu skor ≥ `hold` → tahan; selain itu izinkan. Bila beberapa kategori lewat ambang, yang dicatat adalah kategori dengan skor tertinggi.

**Gambar ditahan.** `public.media_hold` (service_role) mencatat bucket, path, pengunggah (`sub`), model, skor, kategori, dan revisi ambang di `private.media_reviews`. RPC ini menolak path di luar folder pengunggah (403 → `upload_forbidden`) dan path yang objeknya sudah ada (409 → `already_exists`). Kebijakan SELECT storage untuk `attachments` (`olt_attachments_read`, `olt_cs_attachments_read`) ditambah `private.media_visible(bucket_id, name)`: objek berstatus `pending` hanya terlihat oleh pengunggah, objek `removed` tidak terlihat siapa pun, dan staf dengan izin `community.moderate` selalu bisa membaca. Kebijakan baru `olt_media_review_read` memberi moderator akses baca ke semua objek yang ada di antrean (termasuk di room yang bukan miliknya) tanpa signed URL. Karena tidak bisa dibaca, orang lain juga tidak bisa membuat signed URL atau melihatnya di listing folder.

**Avatar.** Bucket `avatars` publik (`/storage/v1/object/public/...` tidak melewati RLS), jadi gambar yang perlu ditinjau tidak bisa disembunyikan di sana. Avatar yang skornya ≥ ambang tahan langsung ditolak 422 `image_blocked`.

**Antrean staf** (izin `community.moderate`): `cs_api.community_media_reviews(p_status 'pending'|'approved'|'removed', p_cursor, p_limit)` → `{items, next_cursor, pending}`; item memuat path, skor, pengunggah, dan konten yang memakai gambar itu (`used_in`: postingan/pesan). Antrean `pending` urut dari yang terlama, lainnya dari yang terbaru. `cs_api.community_media_review_decide(p_id, 'approve'|'remove', p_note)` (alasan 5–500 karakter wajib untuk `remove`, audit `community.media_approve`/`community.media_remove`). Hapus: lampiran dilepas dari `posts.attachments` dan `messages.attachments` (room non-CS) milik pengunggah, objek langsung tidak terbaca, lalu dimasukkan ke `private.storage_cleanup_queue` (prefix = path + `/`; `private.storage_folder_objects` kini juga mencocokkan objek tunggal dengan nama itu) dan dihapus janitor. Pesan chat CS tidak diubah (pesan CS dikunci trigger), gambarnya tetap tidak terbaca lalu terhapus. Trigger `_60_media_review_object_deleted` mencatat `object_deleted_at` saat objeknya dihapus (oleh pengguna, janitor, atau hapus akun). Pembersihan harian `media-reviews-purge`: baris yang objeknya sudah terhapus > 90 hari, disetujui > 180 hari, dan catatan penahanan tanpa objek > 1 hari.

**Fail closed.** Classifier tidak bisa dihubungi, timeout (`CLASSIFIER_TIMEOUT`), sibuk, atau error → 503 `classifier_unavailable` dan tidak ada yang disimpan. Classifier tanpa model → sama, kecuali `MODEL_MISSING_POLICY=allow`. Gambar yang tidak bisa di-decode classifier → 422 `invalid_image`. PDF (`cs-documents`) tidak diperiksa classifier.

Batas yang diketahui: GIF animasi besar dan WebP animasi hanya dinilai dari frame pertama (lihat README classifier); pengunggah sendiri masih bisa membuat signed URL untuk gambarnya yang ditahan dan membagikannya di luar aplikasi.

Tes: `go test ./...` (dengan `-race` lewat container Go, butuh cgo).
