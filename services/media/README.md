# media

Pintu upload file untuk nasabah. Foto dari HP biasanya membawa metadata EXIF (lokasi GPS, merek dan seri HP, waktu pemotretan), XMP, IPTC, komentar, thumbnail, bahkan video *motion photo* di ujung file. Layanan media memeriksa isi file dari *magic bytes*, membuang metadata itu tanpa re-encode (piksel tidak berubah sedikit pun), memeriksa PDF, lalu meneruskan file ke Supabase Storage dengan JWT baru yang membawa klaim `"media_verified": true`. Kebijakan storage di database (migrasi `0063_media_uploads.sql`) mewajibkan klaim itu untuk upload nasabah, jadi upload langsung ke `/storage/v1` dari aplikasi ditolak RLS. Staf CS tidak terkena aturan ini.

Sejak 0.2.0 setiap gambar juga diperiksa classifier NSFW (`services/classifier`) sebelum disimpan: gambar yang jelas melanggar ditolak, gambar meragukan disimpan tetapi **ditahan** (hanya terlihat oleh pengunggah dan moderator) sampai ditinjau staf. Lihat bagian "Moderasi gambar".

Sejak 0.3.0 (migrasi `0131_cs_attachment_formats.sql` dan `0132_media_scanner_health.sql`) chat CS menerima dokumen Word/Excel/PowerPoint modern, teks/CSV, dan video pendek. Format, batas ukuran, dan durasi diatur Super Admin dari Hub; setiap dokumen dan video dipindai antivirus ClamAV (container `clamav`) sebelum disimpan. Lihat bagian "Lampiran chat CS".

Media hanya memakai standard library Go; video diperiksa dengan `ffprobe`/`ffmpeg` dari paket Alpine di image yang sama (karena itu image media bukan distroless lagi). Kong meneruskan `/media/v1/*` ke `http://media:8080/*` (strip path, plugin `cors` + `key-auth` apikey). Media langsung menghubungi container `storage` dan `rest` di jaringan internal.

## Alur `POST /object/{bucket}/{path}`

1. `Authorization: Bearer <JWT>` diverifikasi HS256 dengan `JWT_SECRET_FILE`. Wajib `alg` = `HS256`, `role` = `authenticated`, `sub` berupa UUID, dan `exp` belum lewat (toleransi jam 30 detik, begitu juga `nbf` bila ada). Token `anon` dan `service_role` ditolak. Gagal → 401 `invalid_token`.
2. Bucket harus salah satu dari tabel di bawah. Lainnya → 400 `bucket_not_allowed`.
3. Path 1–6 segmen, tiap segmen `[A-Za-z0-9._-]{1,128}` dan bukan `.`/`..`, total maksimal 400 karakter (tanpa nama bucket). Karakter ber-*percent-encoding* (`%2F`, spasi, huruf non-ASCII) ditolak. Gagal → 400 `invalid_path`.
4. Khusus `cs-documents` dan `cs-videos`: kebijakan lampiran dari database harus sudah termuat (kalau belum → 503 `policy_unavailable`) dan jenisnya (dokumen/video) harus aktif (kalau dimatikan Super Admin → 403 `kind_disabled`). Batas ukuran = yang lebih kecil antara batas bucket dan `max_bytes` kebijakan. `Content-Length` lebih besar dari batas itu langsung ditolak 413 tanpa membaca body.
5. Menunggu slot pemrosesan (`MAX_CONCURRENT`). Bila semua slot terpakai lebih dari 5 detik → 503 `busy` dengan header `Retry-After: 2`.
6. Body dibaca sampai batas + 1 byte. Kosong → 400 `empty_file`, melebihi batas → 413 `file_too_large`.
7. Jenis file ditentukan dari isi (magic bytes, struktur ZIP Office, header ISO BMFF/EBML). Header `Content-Type` dari klien diabaikan dan ekstensi tidak pernah dipercaya sendirian; satu-satunya peran ekstensi adalah membedakan teks: isi yang bukan format biner apa pun, UTF-8 valid tanpa byte NUL, dan bukan markup (HTML/SVG/XML), dianggap CSV bila nama berakhiran `.csv` dan teks biasa bila `.txt` atau `.log`. Jenis tidak dikenal, tidak diizinkan di bucket itu, atau formatnya dimatikan di kebijakan → 415 `unsupported_type`. Nama `.txt`/`.csv` yang isinya bukan teks UTF-8 → 422 `invalid_text`.
8. Pemeriksaan/sanitasi sesuai jenis (lihat di bawah). Gambar selalu menjadi file baru; PDF, Office, dan teks disimpan apa adanya bila lolos.
9. `cs-documents` dan `cs-videos`: file asli dipindai ClamAV (`INSTREAM`). Terdeteksi → 422 `malware_detected`; pemindai tidak bisa dipakai → 503 `scanner_unavailable` (fail closed). Video lalu diperiksa dan di-remux dengan ffmpeg (lihat "Video").
10. Ekstensi segmen terakhir diganti ekstensi kanonik jenis yang terdeteksi (`jpg`, `png`, `webp`, `gif`, `pdf`, `docx`, `xlsx`, `pptx`, `txt`, `csv`, `mp4`, `mov`, `webm`). Yang dianggap ekstensi adalah teks setelah titik terakhir, kecuali titik di awal nama. Contoh: `foto.jpeg` → `foto.jpg`, `my.photo.HEIC` → `my.photo.jpg`, `avatar` → `avatar.png`, `.hidden` → `.hidden.png`.

   **Moderasi (hanya gambar, bukan PDF).** Gambar hasil sanitasi dikirim ke classifier dan skornya dibandingkan dengan ambang dari database (lihat "Moderasi gambar"). Blokir → 422 `image_blocked`, tidak ada yang disimpan. Tahan → baris `private.media_reviews` dicatat lebih dulu lewat RPC `media_hold`, baru objek diunggah; bila upload ke storage gagal, catatan itu dibatalkan (`media_hold_cancel`). Izinkan → lanjut seperti biasa.
11. Diteruskan ke `POST {STORAGE_URL}/object/{bucket}/{path-final}` dengan `Content-Type` hasil deteksi, `Cache-Control: max-age=3600`, dan `x-upsert: true` hanya bila klien mengirim `x-upsert: true` **dan** bucket `avatars`. `Authorization` berisi JWT baru: salinan semua klaim JWT nasabah + `"media_verified": true`, `iat` = sekarang, `exp` = min(`exp` asli, sekarang + 120 detik), HS256 dengan secret yang sama. Header `X-Olt-Edge` dari request (dipasang Traefik di domain publik) ikut diteruskan apa adanya, sehingga RLS storage (migrasi `0105`) menolak JWT akun CS yang mengunggah lewat domain publik.
12. Respons sukses 200:

```json
{"bucket":"attachments","path":"posts/<uuid>/foto.jpg","mime":"image/jpeg","size":951,"width":48,"height":64}
```

`path` adalah path final (setelah ekstensi diganti) dan `size` ukuran file yang tersimpan. Bila gambar ditahan untuk ditinjau, respons memuat `"held": true` (field tidak ada untuk gambar biasa); klien boleh menampilkan "sedang ditinjau" kepada pengunggah. Klien wajib memakai `path` dan `mime` dari respons. `width`/`height` sesuai tampilan: bila Orientation EXIF 5–8 (foto HP diputar 90°), lebar dan tinggi ditukar. Untuk dokumen (PDF, Office, teks), `width`/`height` tidak ada. Untuk video, respons berisi `width`/`height` tampilan (rotasi 90° dari HP sudah diperhitungkan), `duration` (detik, desimal) dan `thumbnail` (path JPEG di bucket yang sama, nama sama dengan ekstensi `.jpg`). Pesan chat CS wajib menyertakan `duration` dan boleh menyertakan `thumbnail` di lampiran (dicek `private.check_message_media`):

```json
{"bucket":"cs-videos","path":"rooms/<room>/<uid>/layar.mp4","mime":"video/mp4","size":2019,"width":64,"height":64,"duration":1,"thumbnail":"rooms/<room>/<uid>/layar.jpg"}
```

Port 8080 hanya melayani `POST /object/...`. Metode atau path lain → 404 `not_found`. Setiap respons membawa `X-Request-Id` (dari header klien bila aman, `[A-Za-z0-9._-]{1,64}`, atau dibuat acak).

## Bucket

| Bucket | Maks | Jenis | `x-upsert` |
|---|---|---|---|
| `avatars` | 2 MiB | JPEG, PNG, WebP | diteruskan |
| `attachments` | 5 MiB | JPEG, PNG, WebP, GIF | diabaikan |
| `cs-documents` | 10 MiB (atau lebih kecil dari kebijakan) | PDF, DOCX, XLSX, PPTX, TXT, CSV (sesuai kebijakan) | diabaikan |
| `cs-videos` | 25 MiB (atau lebih kecil dari kebijakan) | MP4, MOV, WebM (sesuai kebijakan), maks. 120 detik | diabaikan |

Path `cs-documents`/`cs-videos`: `rooms/<room uuid>/<uid pengunggah>/<file>`. Siapa boleh menulis ke folder mana tetap diatur kebijakan RLS storage (folder milik sendiri, anggota room, tiket CS yang masih terbuka, tidak dibanned, batas upload harian).

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

**Office (DOCX, XLSX, PPTX).** Dikenali sebagai ZIP yang `[Content_Types].xml`-nya mendeklarasikan tepat satu bagian utama Word, Excel, atau PowerPoint (`...wordprocessingml.document.main+xml` dan seterusnya). ZIP biasa, template, dan dokumen dengan dua bagian utama → `unsupported_type`. File Office lama (`.doc`, `.xls`, `.ppt`) dan dokumen terenkripsi berformat OLE, bukan ZIP, jadi ikut ditolak `unsupported_type`. File tidak diubah (tidak di-zip ulang), hanya diperiksa:

- Makro → 422 `office_macro`: entri `vbaProject.bin`/`vbaData.xml`, content type yang memuat `macroEnabled` atau `vbaProject`, relasi `vbaProject`, atau dokumen bermakro tertanam (`.docm`, `.xlsm`, `.pptm`, `.xlsb`, dan sejenisnya). Dokumen `.docm` yang diganti namanya menjadi `.docx` tetap dikenali sebagai Word lalu ditolak di sini.
- Konten berbahaya → 422 `office_unsafe`: kontrol ActiveX (`activeX/`), objek OLE di `embeddings/` (`*.bin`, `oleObject*`), file program/skrip (`.exe`, `.dll`, `.js`, `.vbs`, `.ps1`, `.bat`, ...) atau Office lama di mana pun dalam arsip, entri terenkripsi, path `../`, relasi eksternal ke `file:`, path UNC `\\server`, atau skema selain `http`/`https`/`mailto` (misalnya `ms-msdt:`), dan relasi eksternal yang dimuat otomatis (`attachedTemplate`, `oleObject`, `frame`, `subDocument`, `control`) apa pun alamatnya. Hyperlink `https://` biasa tetap boleh. XML relasi atau content type yang tidak bisa dibaca juga ditolak di sini.
- Zip bomb → 422 `archive_bomb`: lebih dari 1000 entri, total ukuran terurai > 100 MiB, atau entri ≥ 1 MiB dengan rasio kompresi > 100.

**TXT dan CSV.** Harus UTF-8 valid (BOM boleh) tanpa byte NUL; UTF-16 dari Notepad lama ditolak `invalid_text`. Disimpan apa adanya dengan `text/plain` atau `text/csv`. Hanya nama `.txt`, `.log` (disimpan sebagai `.txt`), dan `.csv` yang dianggap teks, jadi skrip seperti `.js`, `.bat`, `.sh`, HTML, dan SVG tidak pernah lolos sebagai teks.

**Video (MP4, MOV, WebM).** MP4/MOV dikenali dari kotak `ftyp` (MOV = brand `qt  `; brand foto/audio seperti HEIC, AVIF, M4A ditolak), WebM dari header EBML dengan DocType `webm` (Matroska lain ditolak). File ditulis ke `/tmp` (tmpfs) lalu:

1. `ffprobe` dengan demuxer dipaksa (`mov` atau `matroska`, tidak ada probing format lain): container harus cocok, stream video pertama (cover art `attached_pic` dilewati) wajib H.264, HEVC, VP8, VP9, atau AV1 dengan sisi ≤ 8192 px; audio pertama boleh tidak ada atau AAC, Opus, Vorbis, MP3; maks. 16 stream. Selain itu → 422 `invalid_video`. Durasi > `max_seconds` kebijakan → 422 `video_too_long`.
2. `ffmpeg -c copy` (tanpa re-encode) hanya stream video dan audio terpilih, `-map_metadata -1` untuk metadata global dan per stream, tanpa chapter, `+bitexact`, dan `+faststart` untuk MP4/MOV. Metadata lokasi QuickTime (`©xyz`, `com.apple.quicktime.location.ISO6709`), judul, perangkat, dan stream data (timecode, metadata Apple) ikut terbuang.
3. Hasil remux di-probe ulang; durasi wajib diketahui (WebM dari browser sering tanpa durasi di header) dan ≤ `max_seconds`.
4. Thumbnail JPEG dari detik ke-1 (atau tengah video bila lebih pendek dari 2 detik), lebar maks. 480 px, rotasi diterapkan, lalu dilewatkan sanitasi JPEG di atas. Thumbnail diunggah lebih dulu ke `<nama>.jpg`, baru videonya. Gagal membuat thumbnail → 422 `invalid_video`.

Setiap langkah dibatasi `VIDEO_STEP_TIMEOUT`; video yang diproses bersamaan dibatasi `VIDEO_CONCURRENT` (antre maks. 5 detik, lalu 503 `busy`). Video tidak diperiksa classifier NSFW.

## Lampiran chat CS

**Kebijakan.** Media membaca `public.media_attachment_policy()` (service_role) saat start dan setiap `ATTACHMENT_REFRESH`; isinya per jenis (`documents`, `images`, `videos`): `enabled`, `bucket`, `max_bytes`, `max_seconds` (video), dan daftar `formats` (`code`, `mime`, `ext`). Super Admin mengubahnya dari Hub (`cs_api.admin_set_attachment_policy`), perubahan berlaku paling lambat 30 detik kemudian. Bila database tidak bisa dihubungi, kebijakan terakhir tetap dipakai; sebelum kebijakan pertama termuat, upload `cs-documents` dan `cs-videos` ditolak 503 `policy_unavailable`. Bagian `images` tidak dipakai media: bucket `attachments` dipakai bersama chat sosial, jadi gambar tetap mengikuti aturan bucket di atas dan pembatasan gambar khusus chat CS dicek database saat pesan dikirim.

**Pemindai antivirus.** Container `clamav` (image resmi `clamav/clamav`, clamd + freshclam) di jaringan `app` (untuk media) dan `egress` (unduh signature), tanpa port yang dipublikasikan. Media mengirim file dengan perintah clamd `zINSTREAM` lewat TCP (`CLAMD_ADDR`) dalam potongan 64 KiB, batas waktu `SCAN_TIMEOUT`. Jawaban `FOUND` → 422 `malware_detected` (nama signature dicatat di log, misalnya `Eicar-Test-Signature`). Koneksi gagal, timeout, atau jawaban error (termasuk batas `StreamMaxLength`) → 503 `scanner_unavailable` dan file tidak disimpan. Yang dipindai: semua upload `cs-documents` (termasuk PDF) dan `cs-videos`, sebelum ffmpeg menyentuh video. Gambar tidak dipindai (sudah disanitasi ulang dan diperiksa classifier).

Konfigurasi clamd/freshclam ada di `docker/volumes/clamav/`: `StreamMaxLength 30M`, `ConcurrentDatabaseReload no` (signature hanya satu salinan di RAM; saat reload harian scan tertahan beberapa detik), signature di volume `clamav-db`. Lihat `docs/PRODUCTION.md` untuk kebutuhan RAM dan internet.

## Batas

| Batas | Nilai | Kode |
|---|---|---|
| Ukuran file | per bucket (2/5/10/25 MiB), dokumen dan video CS bisa diturunkan dari Hub | 413 `file_too_large` |
| Durasi video | `max_seconds` kebijakan (bawaan dan maks. 120 detik) | 422 `video_too_long` |
| Arsip Office | ≤ 1000 entri, ≤ 100 MiB terurai, rasio ≤ 100 per entri ≥ 1 MiB | 422 `archive_bomb` |
| Video paralel | `VIDEO_CONCURRENT`, antre maks 5 detik | 503 `busy` |
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
| 400 | `bucket_not_allowed` | Bucket bukan `avatars`, `attachments`, `cs-documents`, atau `cs-videos` |
| 400 | `invalid_path` | Path tidak memenuhi aturan |
| 400 | `empty_file` | Body kosong |
| 400 | `invalid_request` | Body tidak bisa dibaca (misalnya chunked encoding rusak) |
| 401 | `invalid_token` | JWT tidak ada, salah tanda tangan, kedaluwarsa, bukan `authenticated`, `sub` bukan UUID. Juga bila storage menolak JWT baru karena `exp` sudah lewat (token nasabah habis dalam masa toleransi 30 detik) |
| 403 | `kind_disabled` | Dokumen atau video chat CS sedang dimatikan Super Admin di Hub |
| 403 | `upload_forbidden` | Ditolak RLS storage (pesan `row-level security`, atau statusCode 403 lain yang bukan masalah tanda tangan JWT) |
| 404 | `not_found` | Metode atau path selain `POST /object/...` |
| 408 | `request_timeout` | Body tidak selesai dikirim dalam `REQUEST_TIMEOUT` |
| 409 | `already_exists` | Objek dengan path itu sudah ada (storage statusCode 409) |
| 413 | `file_too_large` | Melebihi batas bucket (dari media atau storage) |
| 415 | `unsupported_type` | Isi tidak dikenal, jenisnya tidak diizinkan di bucket, atau formatnya dimatikan di kebijakan (misalnya hanya PDF yang aktif) |
| 422 | `invalid_image` | Struktur gambar rusak |
| 422 | `image_too_large` | Dimensi atau jumlah frame melebihi batas |
| 422 | `invalid_pdf` | Header/`%%EOF` tidak ada, object stream rusak atau tidak bisa diperiksa |
| 422 | `pdf_encrypted` | PDF terenkripsi atau berpassword |
| 422 | `pdf_active_content` | PDF berisi JavaScript, Launch, file lampiran, RichMedia, atau XFA |
| 422 | `office_macro` | Dokumen Office berisi makro VBA atau dokumen bermakro tertanam |
| 422 | `office_unsafe` | Dokumen Office berisi ActiveX, objek OLE, file program, relasi eksternal berbahaya, atau tidak bisa diperiksa |
| 422 | `archive_bomb` | Dokumen Office melewati batas entri, ukuran terurai, atau rasio kompresi |
| 422 | `invalid_text` | Nama `.txt`/`.csv` tetapi isinya bukan teks UTF-8 (byte tidak valid atau NUL) |
| 422 | `invalid_video` | Container, codec, dimensi, atau stream video tidak didukung, file rusak, atau thumbnail tidak bisa dibuat |
| 422 | `video_too_long` | Durasi melewati `max_seconds` kebijakan |
| 422 | `malware_detected` | ClamAV mendeteksi virus/malware (termasuk file uji EICAR) |
| 422 | `image_blocked` | Classifier menilai gambar melanggar (skor ≥ ambang blokir), atau gambar perlu ditinjau tetapi tujuannya bucket publik `avatars` |
| 429 | `too_many_uploads` | Batas upload harian dari database (HTTP/statusCode 429, atau pesan memuat `too_many`, `429`, `rate_limited`) |
| 502 | `storage_error` | Error lain dari storage, termasuk tanda tangan JWT ditolak (salah konfigurasi `JWT_SECRET`) |
| 502 | `storage_unavailable` | Storage tidak bisa dihubungi atau tidak menjawab sebelum `REQUEST_TIMEOUT` |
| 503 | `busy` | Semua slot terpakai lebih dari 5 detik |
| 503 | `classifier_unavailable` | Classifier tidak bisa dihubungi, timeout, sibuk, atau belum punya model (fail closed). Header `Retry-After: 2` |
| 503 | `moderation_unavailable` | Ambang belum termuat dari database atau catatan penahanan gagal disimpan |
| 503 | `policy_unavailable` | Kebijakan lampiran chat CS belum termuat dari database |
| 503 | `scanner_unavailable` | clamd tidak bisa dihubungi, timeout, atau menjawab error (fail closed). Header `Retry-After: 2` |
| 500 | `internal_error` | Gagal membuat JWT, atau `ffmpeg`/`ffprobe` tidak ada atau melewati `VIDEO_STEP_TIMEOUT` |

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
| `MAX_CONCURRENT` | `8` | Upload yang diproses bersamaan (1–256). Memori puncak kira-kira `MAX_CONCURRENT` × 30 MiB (PDF 10 MiB + object stream yang di-inflate maks. 16 MiB) ditambah `VIDEO_CONCURRENT` × ~120 MiB (video 25 MiB di memori dan di tmpfs `/tmp`, hasil remux, proses ffmpeg). Compose memberi 768 MiB dan tmpfs `/tmp` 192 MiB untuk nilai default |
| `REQUEST_TIMEOUT` | `30s` | Batas baca body, pemindaian, ffmpeg, dan kirim ke storage per request (5s–5m). Compose memakai `MEDIA_REQUEST_TIMEOUT` (bawaan `50s`, di bawah batas 60 detik Kong) |
| `HEARTBEAT_INTERVAL` | `30s` | 5s–60s |
| `SHUTDOWN_TIMEOUT` | `20s` | Waktu menyelesaikan upload yang sedang jalan saat SIGTERM (1s–5m) |
| `CLASSIFIER_URL` | `http://classifier:8080` | Layanan classifier (network `app`) |
| `CLASSIFIER_TIMEOUT` | `10s` | Batas satu panggilan classifier (1s–60s); lewat batas → 503 `classifier_unavailable` |
| `MODERATION_REFRESH` | `30s` | Interval cek revisi ambang di database (5s–10m) |
| `CLAMD_ADDR` | `clamav:3310` | Alamat TCP clamd (`host:port`) |
| `SCAN_TIMEOUT` | `60s` | Batas satu pemindaian (1s–5m); compose memakai `MEDIA_SCAN_TIMEOUT` (bawaan `40s`) |
| `ATTACHMENT_REFRESH` | `30s` | Interval membaca kebijakan lampiran chat CS (5s–10m) |
| `FFMPEG_PATH` / `FFPROBE_PATH` | `ffmpeg` / `ffprobe` | Program video (paket Alpine di image) |
| `VIDEO_CONCURRENT` | `2` | Video yang diproses ffmpeg bersamaan (1–32); compose memakai `MEDIA_VIDEO_CONCURRENT` |
| `VIDEO_STEP_TIMEOUT` | `20s` | Batas tiap langkah ffprobe/ffmpeg (1s–2m) |
| `MODEL_MISSING_POLICY` | `reject` | `reject`: classifier tanpa model = 503 untuk semua gambar. `allow`: gambar disimpan tanpa pemeriksaan (dicatat `decision=unclassified`, peringatan saat start). Classifier yang mati selalu fail closed |

Log berformat JSON. Setiap upload menghasilkan satu baris (`Upload stored`, `Upload rejected`, atau `Upload failed` untuk 5xx) berisi `request_id`, `bucket`, `code`, `status`, `size_in`, `size_out`, `metadata_removed` (jumlah blok yang dibuang), `took_ms`, `decision` (`allow`/`hold`/`block`/`unclassified`) beserta `category` dan `score` tertinggi untuk gambar, `duration` untuk video, dan `reason` teknis singkat untuk error (misalnya `signature Eicar-Test-Signature`, `office document has macros: vbaproject.bin`). Token, isi JWT, `sub`, path file, dan isi file tidak pernah ditulis ke log.

## Heartbeat

Media memanggil `public.service_heartbeat('media', instance, version, started_at, status, error, detail)` saat start, setiap `HEARTBEAT_INTERVAL`, dan langsung saat status berubah. `detail` = `{"accepted","rejected","metadata_removed","allowed","held","blocked","unclassified","classifier_failures","thresholds_revision","scanned","malware_detected","scanner_failures","scanner_version","attachment_policy_loaded"}` sejak start: upload yang tersimpan, upload yang ditolak (semua kode error), upload tersimpan yang metadatanya dibuang, keputusan moderasi per jenis, kegagalan classifier berturut-turut, revisi ambang yang dipakai (null bila belum termuat), file yang dipindai ClamAV dan yang terdeteksi malware, kegagalan pemindai berturut-turut, versi clamd beserta versi dan tanggal database signature (jawaban `VERSION`, null sebelum probe pertama berhasil), dan apakah kebijakan lampiran CS sudah termuat.

Sebelum tiap heartbeat terjadwal, media mengecek `GET {STORAGE_URL}/status`. Kegagalan menghubungi storage (cek ini maupun upload yang gagal tersambung atau timeout) dihitung berturut-turut. Cek `/status` yang tidak menjawab 200 juga dihitung gagal. Mulai 3 kali, status menjadi `degraded` dengan error "Storage tidak bisa dihubungi (n kali berturut-turut)". Upload yang dijawab storage (apa pun statusnya) atau cek `/status` yang menjawab 200 mengembalikan status ke `ok`. Status ini tidak memengaruhi `/readyz`. Status juga `degraded` bila classifier gagal dipakai 3 kali berturut-turut (upload maupun probe `GET /status` tiap heartbeat; pesan menyebut "Model classifier belum tersedia" bila classifier jalan tanpa model) atau ambang belum termuat.

Pemindai antivirus diperlakukan sama: sebelum tiap heartbeat terjadwal media mengirim `zVERSION` ke clamd; kegagalan probe maupun pemindaian dihitung berturut-turut, dan mulai 3 kali status menjadi `degraded` dengan error "Pemindai antivirus tidak bisa dihubungi (n kali berturut-turut); upload dokumen dan video chat CS ditolak". Bila clamd menjawab tetapi database signature lebih tua dari 3 hari (freshclam tidak bisa mengunduh), error menjadi "Database virus pemindai antivirus belum diperbarui sejak <tanggal>; periksa akses internet container clamav (freshclam)". Kebijakan lampiran yang belum termuat juga membuat status `degraded` ("Kebijakan lampiran chat CS belum termuat; ..."). Pesan ini tampil di Kesehatan sistem sebagai "Layanan Upload media bermasalah", persis seperti masalah classifier. Selain itu sentinel memprobe `clamav=tcp://clamav:3310`; probe yang gagal tampil sebagai "Pemindai antivirus tidak merespons" (label dari migrasi `0132_media_scanner_health.sql`).

Heartbeat yang gagal tidak menghentikan layanan. Kegagalan dicatat sekali saat mulai gagal dan sekali saat pulih, bukan di setiap interval.

## Endpoint ops dan metrik

`GET /livez` (liveness), `GET /readyz` (200 setelah konfigurasi dimuat, 503 saat shutdown), `GET /metrics` (format teks Prometheus) di `OPS_PORT`, dan subcommand `media healthcheck` (cek `/livez`) untuk healthcheck container.

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
| `media_scans_total{result}` | counter | File yang dipindai ClamAV, `clean` atau `infected` |
| `media_scanner_consecutive_failures` | gauge | Kegagalan pemindai berturut-turut |
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

Tes: `go test ./...` (dengan `-race` lewat container Go, butuh cgo). Tes unit tidak butuh ffmpeg maupun clamd (keduanya di belakang interface dengan tiruan). Uji ujung ke ujung dengan clamd dan ffmpeg asli ada di `.\make.ps1 smoke-dummy` / `make smoke-dummy`: DOCX dan CSV tersimpan, DOCX bermakro dan file uji EICAR ditolak, MP4 tersimpan tanpa metadata lokasi beserta thumbnail.
