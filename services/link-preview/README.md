# link-preview

Pembuat pratinjau link (judul, deskripsi, nama situs, gambar) untuk postingan, komentar, dan chat. Ini satu-satunya komponen OLT Social yang menghubungi host internet sembarang, jadi seluruh desainnya berpusat pada proteksi SSRF. Hanya memakai standard library Go (tanpa dependensi luar; parser HTML ditulis sendiri, paket `sanitize` dan `moderation` disalin dari `services/media`).

## Alur

1. Trigger `posts_50_link_preview`, `comments_50_link_preview`, `messages_50_link_preview` (migrasi `0080`) mengambil maksimal **3 URL http/https unik** per konten yang **terlihat** (`moderation_status = 'visible'`, tidak dihapus). Pesan di room `support` (chat CS) dan pesan non-teks dilewati. Konten yang ditahan moderasi baru diantrekan saat dilepas; edit isi ikut diantrekan.
2. URL dinormalisasi di database (skema + host huruf kecil, port bawaan dan fragmen dibuang, tanda baca penutup dibuang, URL dengan userinfo / `%` / `\` di host ditolak), di-hash SHA-256, lalu masuk `private.link_preview_queue` bila belum ada pratinjau yang masih segar (7 hari). Domain di `cs.blocked_domains` (bila tabel itu ada) langsung dicatat `blocked` tanpa diambil.
3. Worker memanggil `link_preview_claim` (lease, percobaan dihitung saat claim), mengambil halaman lewat klien HTTP aman, mem-parse meta tag, mengunduh gambar dengan aturan yang sama, membersihkan metadata gambar, **mengklasifikasi gambar NSFW** (lihat [Klasifikasi gambar](#klasifikasi-gambar-nsfw)), mengunggah hanya gambar yang lolos ke bucket publik `link-previews`, lalu melaporkan setiap link lewat `link_preview_report`.
4. Database mengecek ulang domain asal **dan** domain akhir setelah redirect terhadap daftar blokir, lalu menyimpan hasil di `public.link_previews`.
5. Aplikasi membaca lewat RPC `get_link_previews(p_urls)`.

## Model ancaman

| Ancaman | Mitigasi |
|---|---|
| SSRF ke layanan internal (PostgREST, Storage, Kong, Postgres, Valkey, metadata cloud) | Pemeriksaan di **tiga lapis**: (a) URL sebelum request dan di **setiap redirect** (`CheckRedirect`); (b) setiap alamat hasil DNS sebelum dial — bila **satu saja** jawaban DNS privat, host ditolak; (c) `net.Dialer.Control` memeriksa alamat IP dan port **socket yang benar-benar di-connect**. Lapis (c) menutup celah yang lolos dari dua lapis pertama. |
| Rentang yang ditolak | IPv4: `0/8`, `10/8`, `100.64/10` (CGNAT), `127/8`, `169.254/16` (termasuk metadata cloud `169.254.169.254`), `172.16/12` (jaringan Docker), `192.0.0/24`, `192.0.2/24`, `192.31.196/24`, `192.52.193/24`, `192.88.99/24`, `192.168/16`, `192.175.48/24`, `198.18/15`, `198.51.100/24`, `203.0.113/24`, `224/4`, `240/4` (termasuk broadcast). IPv6: semua di luar `2000::/3` (loopback, `::`, ULA `fc00::/7`, link-local `fe80::/10`, site-local, multicast, NAT64 `64:ff9b::/96`, IPv4-compatible `::/96`), plus `2001::/23` (Teredo dll.), `2001:db8::/32`, `2002::/16` (6to4), `3fff::/20`. Alamat IPv4-mapped (`::ffff:a.b.c.d`) dibuka dulu lalu dicek sebagai IPv4. Alamat dengan zone (`%eth0`) ditolak. |
| DNS rebinding | Tidak ada resolusi kedua: alamat yang sudah dicek adalah alamat yang di-dial, dan `Control` mengecek lagi saat connect. Keep-alive dimatikan, jadi setiap request resolve + cek ulang. |
| Trik penulisan IP | Host yang label terakhirnya angka/heksadesimal tetapi bukan IPv4 desimal kanonik ditolak (`2130706433`, `0x7f.1`, `0177.0.0.1`, `127.1`, `017700000001`, `0`). Host non-ASCII ditolak (menutup trik titik Unicode `127。0。0。1` dan homoglyph; domain IDN tetap bisa lewat bentuk `xn--`). |
| Trik userinfo | URL dengan userinfo (`http://evil@127.0.0.1/`, `http://bank.com@evil.com/`) ditolak di database dan di worker. |
| Nama internal | Host satu label (`storage`, `rest`, `kong`), `localhost`, `*.localhost`, `*.local`, `*.internal`, `*.lan`, `*.home.arpa`, `metadata.google.internal`, dll. ditolak sebelum DNS. |
| Port lain | Hanya port **80 dan 443**, dicek di URL, di redirect, dan di socket. |
| Proxy dari env | `Transport.Proxy = nil`: `HTTP_PROXY`/`HTTPS_PROXY` diabaikan. |
| Respons raksasa / bom gzip | HTML dibaca maksimal 1 MiB **setelah** dekompresi (sisanya dipotong, head biasanya sudah termuat); gambar maksimal 5 MiB (lebih → gambar dibuang, `Content-Length` yang terlalu besar ditolak sebelum dibaca); header maksimal 64 KiB. |
| Server lambat (slowloris) | Batas total 5 detik per request (DNS + connect + TLS + header + body), terpisah untuk halaman dan gambar. |
| Redirect berantai | Maksimal 3 redirect. |
| Gambar berbahaya | Jenis gambar ditentukan dari magic bytes, hanya JPEG/PNG/WebP/GIF (SVG ditolak). Metadata (EXIF/GPS, XMP, komentar, teks PNG) dibuang tanpa re-encode, struktur file divalidasi, maks 10000 px per sisi / 40 MP / 500 frame. Gambar lebih kecil dari 32×32 (piksel pelacak) dibuang. |
| Teks berbahaya | Judul/deskripsi adalah teks biasa (entitas HTML di-decode, spasi/kontrol diringkas, karakter bidi override dan zero-width dibuang, dipotong 300/1000/100 karakter). Klien wajib menampilkannya sebagai teks, bukan HTML. |
| Bocornya link dari DM | Tabel `public.link_previews` **tidak** bisa dibaca langsung (RLS aktif tanpa policy, hak tabel dicabut) sehingga daftar URL yang pernah dibagikan di DM tidak bisa di-enumerasi. Pratinjau hanya bisa dibaca dengan menyebut URL persisnya lewat RPC. Worker tidak mencatat path/query URL di log (hanya host + hash). |
| Penyalahgunaan sebagai proxy pengambil URL | Hanya trigger konten (yang sudah kena rate limit dan kebijakan konten) yang bisa mengantre URL. `get_link_previews` tidak pernah memicu pengambilan. |
| Domain terlarang | `cs.blocked_domains` (milik agen S) dicek saat antre, saat claim, saat laporan (domain akhir setelah redirect), dan saat dibaca. Cocok untuk domain itu dan subdomainnya; baris `action = 'allow'` dan `cs.allowed_domains` dihormati. Bila tabel ada tetapi query gagal, semua host dianggap diblokir (fail closed). |

Risiko yang diterima (dicatat):

- Link sekali pakai (link reset password, magic link) di chat bisa "terpakai" karena server melakukan GET, seperti pembuat pratinjau di aplikasi chat lain.
- Situs tujuan melihat IP server dan User-Agent pratinjau. Isi `USER_AGENT` dengan URL halaman penjelasan resmi sebelum produksi.
- `robots.txt` tidak dibaca (hanya satu GET halaman + satu GET gambar per link per 7 hari).
- Classifier hanya memberi skor NSFW (porn/hentai/sexy). Gambar kekerasan, gore, atau teks di dalam gambar tidak terdeteksi; sumber gambar tetap dibatasi lewat daftar domain terlarang.

## Klasifikasi gambar NSFW

Sejak 0.2.0 (migrasi `0094_link_preview_nsfw`) setiap gambar pratinjau, baik og:image maupun link gambar langsung, dikirim ke `services/classifier` (`POST /classify`) **setelah** dibersihkan dan **sebelum** diunggah. Panggilan ke classifier memakai klien HTTP internal terpisah (jaringan `app`), bukan klien `safehttp`, sehingga proteksi SSRF untuk internet tidak berubah.

- **Ambang** sama dengan layanan media: dibaca dari RPC `media_moderation_config` (diatur Kepatuhan → Ambang gambar), disegarkan setiap `MODERATION_REFRESH`. Keputusan memakai fungsi yang sama dengan media (kategori dengan skor tertinggi yang melewati `block`, lalu `hold`).
- **`block`** (mis. pornografi): gambar dibuang, judul/deskripsi tetap. **`hold`** (ragu-ragu): gambar tidak ditampilkan. Tidak ada antrean tinjauan untuk thumbnail karena gambar milik situs luar (tidak ada pengunggah untuk ditinjau/dibanding) dan link akan diambil ulang setelah cache habis. **`unreadable`** (classifier tidak bisa membaca): gambar dibuang.
- **Classifier mati / model belum ada / ambang belum termuat** (`unavailable`): fail closed, pratinjau tanpa gambar. Database langsung menyimpan pratinjau teks (klien tetap melihat judul) lalu mengantrekan link lagi dengan jeda 1, 2, 4 … menit sampai `link_preview.max_attempts`; setelah itu pratinjau tanpa gambar hanya di-cache `link_preview.failed_cache_hours`. Setelah 3 kegagalan classifier berturut-turut heartbeat menjadi `degraded` ("classifier: …") sehingga terlihat di Kesehatan sistem (classifier sendiri juga di-probe sentinel); selama itu worker mengecek `GET /status` classifier setiap putaran dan kembali `ok` begitu classifier menjawab.
- **Cache per hash**: skor (model + skor per kategori) disimpan di `private.link_preview_image_scores` per SHA-256 gambar bersih, plus cache di memori (maks 2048 entri). Thumbnail yang sama (mis. logo situs di semua artikel) hanya diklasifikasi sekali; verdict dihitung ulang dari skor dengan ambang terbaru, jadi perubahan ambang langsung berlaku tanpa klasifikasi ulang. Cache yang tidak dipakai lebih dari `link_preview.retention_days` dihapus job purge harian. RPC baca: `link_preview_image_scores(p_sha256)` (khusus `service_role`).
- **Pencatatan**: `public.link_previews` menyimpan `image_sha256`, `image_verdict` (`allow`/`hold`/`block`/`unreadable`/`unavailable`), `image_category`, `image_score`, `image_thresholds_revision`. Constraint `link_previews_image_checked` menolak `image_path` tanpa verdict `allow` + hash, dan `link_preview_report` membuang path gambar yang tidak berverdict `allow`. Migrasi 0094 melepas gambar pratinjau lama yang belum diklasifikasi (file dibersihkan job purge) dan membuat pratinjau itu diambil ulang saat link muncul lagi.

## Status dan cache

| Status (`link_previews.status`) | Arti | Umur cache |
|---|---|---|
| `ok` | Ada judul, deskripsi, atau gambar | `link_preview.cache_days` (7 hari) |
| `empty` | Halaman bisa diambil tetapi tanpa metadata, atau bukan HTML/gambar | 7 hari |
| `blocked` | Ditolak proteksi SSRF (`error` = alasan) atau domain terlarang (`blocked_domain`) | 7 hari |
| `failed` | 4xx, DNS tidak ditemukan, sertifikat TLS salah, redirect > 3, atau gagal 3× berturut-turut | `link_preview.failed_cache_hours` (24 jam) |

Kegagalan sementara (timeout, 5xx, 408/425/429, DNS sementara) dilaporkan `retry` dan dicoba lagi dengan jeda 1, 2, 4 … menit (maks 1 jam, ±20%) sampai `link_preview.max_attempts` (3). Link yang lease-nya habis karena worker mati tetap dihitung percobaannya, jadi URL yang membuat worker crash tidak berputar selamanya. Link yang belum sempat dimulai sebelum lease habis atau saat shutdown dilaporkan `release` (kembali ke antrean tanpa menghabiskan percobaan).

Pratinjau yang kedaluwarsa tetap ditampilkan sampai link itu muncul lagi di konten baru (lalu diambil ulang) atau sampai job harian `link-preview-purge` (03:37) menghapusnya `link_preview.retention_days` (30) hari setelah kedaluwarsa. Job yang sama memasukkan folder gambar yang tidak lagi dipakai (lebih tua dari 1 hari) ke antrean `private.storage_cleanup_queue`, lalu `services/janitor` menghapus filenya lewat API Storage. Path gambar `<url_hash>/<nonce acak>/preview.<ext>` unik per pengambilan, jadi pembersihan tidak pernah mengenai gambar yang lebih baru.

Setting di `private.settings`: `link_preview.enabled` (`false` = berhenti mengantre link baru), `link_preview.cache_days`, `link_preview.failed_cache_hours`, `link_preview.max_attempts`, `link_preview.retention_days`.

## Kontrak RPC untuk aplikasi

`POST /rest/v1/rpc/get_link_previews` dengan body `{"p_urls": ["https://…", …]}` — hanya user login (`authenticated`), maksimal 20 URL (lebih → 400 `too_many_urls`). URL boleh dikirim apa adanya seperti yang ditemukan di teks; server menormalisasi sendiri. Hasil satu baris per URL masukan, urut sesuai masukan:

| Kolom | Isi |
|---|---|
| `url` | URL persis seperti yang dikirim (untuk mencocokkan) |
| `status` | `ok` (tampilkan kartu), `pending` (sedang/akan diambil), `none` (tampilkan link biasa) |
| `title`, `description`, `site_name` | Teks biasa, bisa `null` |
| `image_path` | Path di bucket publik `link-previews`, bisa `null`. URL gambar: `{SUPABASE_URL}/storage/v1/object/public/link-previews/{image_path}` |
| `image_width`, `image_height` | Ukuran gambar (px) untuk placeholder |
| `final_url` | URL akhir setelah redirect (tampilkan domainnya agar pengguna tahu tujuan sebenarnya) |
| `fetched_at` | Waktu diambil |

Saran klien: ekstrak URL `https?://…` dari teks (maks 3 per konten), panggil RPC sekali per layar untuk semua URL yang tampil; bila `pending`, ulangi paling banyak dua kali (mis. setelah 3 dan 10 detik), lalu anggap `none`.

## Konfigurasi

| Env | Default | Keterangan |
|---|---|---|
| `PORT` | `8080` | HTTP ops (`/livez`, `/readyz`, `/metrics`), tidak untuk publik |
| `LOG_LEVEL` | `info` | `debug` mencatat setiap link (hash, host, status) |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Minimal 32 karakter; untuk token `service_role` 1 menit ke PostgREST dan Storage |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `STORAGE_URL` | `http://storage:5000` | |
| `INSTANCE_ID` | hostname + acak | Pemegang lease (maks 100 karakter) |
| `USER_AGENT` | `OLTSocialLinkPreview/1.0 (+https://olt-social.invalid/link-preview)` | Placeholder: ganti URL dengan halaman penjelasan resmi |
| `BATCH_SIZE` | `8` | Link per claim (1–100) |
| `CONCURRENCY` | `4` | Link yang diambil paralel (1–32) |
| `LEASE` | `2m` | 30s–1h, minimal 2 × `FETCH_TIMEOUT` + `CLASSIFIER_TIMEOUT` + `REQUEST_TIMEOUT` + 10s |
| `POLL_INTERVAL` | `5s` | Jeda claim saat antrean tidak penuh |
| `FETCH_TIMEOUT` | `5s` | Batas total per request ke internet (1s–10s) |
| `REQUEST_TIMEOUT` | `15s` | Batas request ke PostgREST/Storage |
| `HEARTBEAT_INTERVAL` | `30s` | `public.service_heartbeat` dengan nama layanan `link-preview` |
| `SHUTDOWN_TIMEOUT` | `20s` | Waktu menyelesaikan link yang sedang jalan saat SIGTERM; sisanya dilepas |
| `MAX_HTML_BYTES` | `1048576` | 64 KiB–2 MiB |
| `MAX_IMAGE_BYTES` | `5242880` | 256 KiB–5 MiB (batas bucket 5 MB) |
| `CLASSIFIER_URL` | `http://classifier:8080` | Layanan classifier NSFW (jaringan internal) |
| `CLASSIFIER_TIMEOUT` | `10s` | 1s–60s per gambar |
| `MODERATION_REFRESH` | `30s` | 5s–10m, interval membaca ulang ambang gambar |

Daftar rentang IP dan port **tidak bisa** diubah lewat env; pengecualian hanya ada di tes (`safehttp.Policy.Allow`).

Jaringan Docker: `app` (PostgREST, Storage, classifier) dan `egress` (internet). Container lain di kedua jaringan itu tidak terjangkau karena semua alamat privat ditolak.

## Endpoint dan metrik

`GET /livez`, `GET /readyz` (503 bila PostgREST atau Storage tidak terjangkau atau sedang shutdown), `GET /metrics`, subcommand `link-preview healthcheck` untuk image distroless.

| Metrik | Jenis | Keterangan |
|---|---|---|
| `link_preview_fetch_total{result}` | counter | `ok`, `empty`, `blocked`, `failed`, `retry`, `release` |
| `link_preview_blocked_total{reason}` | counter | Alasan SSRF (`private_address`, `port`, `numeric_host`, `internal_host`, `userinfo`, `scheme`, `non_ascii_host`, `invalid_host`; awalan `image_` untuk gambar) |
| `link_preview_images_total{outcome}` | counter | `stored`, `skipped` (terlalu kecil), `rejected` (bukan gambar valid), `blocked`, `failed`, `unsafe` (tidak lolos classifier) |
| `link_preview_image_verdicts_total{verdict}` | counter | `allow`, `hold`, `block`, `unreadable`, `unavailable` |
| `link_preview_image_cache_hits_total` | counter | Verdict dari skor yang sudah di-cache |
| `link_preview_classify_duration_seconds` | summary | Waktu menunggu classifier |
| `link_preview_classifier_consecutive_failures` | gauge | Kegagalan classifier berturut-turut |
| `link_preview_thresholds_loaded` | gauge | 1 bila ambang gambar sudah termuat |
| `link_preview_image_bytes_total` | counter | Byte gambar bersih yang diunggah |
| `link_preview_fetch_duration_seconds` | summary | Waktu per link termasuk gambar |
| `link_preview_claim_errors_total`, `link_preview_report_errors_total` | counter | |
| `link_preview_inflight`, `link_preview_concurrency` | gauge | |
| `link_preview_last_claim_timestamp_seconds`, `link_preview_last_heartbeat_timestamp_seconds` | gauge | |

Heartbeat berstatus `degraded` setelah 3 claim gagal berturut-turut atau 3 panggilan classifier gagal berturut-turut. `detail` memuat juga `images_allowed`, `images_held`, `images_blocked`, `images_unchecked`, `classifier_failures`, `thresholds_loaded`.

## Tes

`go test ./...`; `-race` butuh cgo, jalankan di `golang:1.27.3-bookworm` dengan `CGO_ENABLED=1 go test -race ./...` (CI: `gofmt`, `go vet`, `go test -race`, `scripts/check-go-comments`). Tes SSRF memakai `httptest` di `127.0.0.1` dengan resolver palsu dan allow list sempit yang hanya ada di tes; tes terpisah memastikan kebijakan bawaan menolak server tes itu. Tes klasifikasi memakai classifier palsu (porn, ragu-ragu, aman, mati, model hilang, tidak terbaca, ambang belum termuat, cache memori dan database). Tes database: `supabase/tests/060_link_previews_test.sql`, `074_link_preview_nsfw_test.sql`.
