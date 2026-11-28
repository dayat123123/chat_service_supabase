# share-link

Halaman publik untuk tautan berbagi post (versi **0.1.2**). Setiap post yang dibagikan mendapat kode pendek 10 karakter. Tautannya berbentuk `https://<domain tautan>/p/<kode>`. Layanan ini hanya memakai Go standard library, berjalan di image distroless nonroot, dan punya subcommand `healthcheck`. Migrasi: `0207_post_share_links.sql`, `0208_share_links_macos.sql` (tautan unduh Mac), dan `0209_app_identity.sql` (identitas aplikasi dipindah ke Integrasi aplikasi), tes `184_post_share_links_test.sql` dan `185_app_identity_test.sql`.

```
Tautan diklik ──▶ HP dengan aplikasi terpasang: Android App Links / iOS Universal Links langsung membuka aplikasi
             └──▶ selain itu: browser ──HTTPS──▶ Traefik (SHARE_DOMAIN, /p/*, /.well-known/…) ──▶ share-link:8080
                                                                         │ share_link_config (cache 30 dtk)
                                                                         │ share_post_preview (cache 30 dtk per kode)
                                                                         ▼ gambar: Storage /render/image (imgproxy)
                                                                 PostgREST (service_role) ──▶ Postgres
```

## Yang dilayani

| Path | Isi |
|---|---|
| `GET /p/<kode>` | Halaman HTML berbahasa Indonesia. Isinya kartu post (nama, @username, label Resmi/Terverifikasi, tanggal WIB, cuplikan teks maks. 300 karakter, gambar pertama, jumlah suka/komentar), tombol **Buka di aplikasi** (`<skema>://p/<kode>`), dan tombol unduh (Play Store, App Store, Windows, Mac) yang diisi di Hub. Tag Open Graph dan Twitter Card dipakai untuk kartu pratinjau di WhatsApp, Telegram, X, dan lainnya. Di Windows dan Mac (Chrome, Edge, Firefox), halaman langsung mencoba membuka aplikasi lewat skema itu, lalu browser menanyakan "Buka aplikasi?". Di Safari Mac pengguna mengetuk tombolnya sendiri, karena Safari menampilkan error bila aplikasinya belum terpasang. HP dan iPad tidak dibuka otomatis |
| `GET /p/<kode>/image` | Gambar pertama post. Diambil dari bucket privat `attachments` lewat `render/image/authenticated` dengan lebar maks. `IMAGE_WIDTH`, lalu di-cache 1 jam |
| `GET /p/<kode>/avatar` | Avatar penulis 160×160 dari bucket publik `avatars` |
| `GET /.well-known/assetlinks.json` | Digital Asset Links Android (package + fingerprint SHA-256). Jawabannya 404 bila belum ada aplikasi Android |
| `GET /.well-known/apple-app-site-association` | Universal Links iOS (`appIDs`, path `/p/*`, format lama dan baru). Jawabannya 404 bila belum ada App ID |

File `.well-known` tetap dilayani walau tautan dimatikan, supaya verifikasi aplikasi yang sudah terpasang tidak gagal. Metode selain `GET`/`HEAD` dijawab 405, path lain 404.

## Privasi

- **Isi yang tidak tampil.** Post yang dihapus, ditahan moderasi, milik akun terhapus, akun tamu, atau akun yang sedang di-ban hanya menampilkan "Postingan tidak tersedia" (404), tanpa nama dan tanpa isi. Kode tidak dikenal dan tautan yang dimatikan juga dijawab 404.
- **Saklar pratinjau isi** (Hub). Bila dimatikan, halaman tidak membawa isi post sama sekali, hanya tombol buka aplikasi dan tombol unduh.
- **Indeks mesin pencari.** Halaman mengirim `X-Robots-Tag: noindex, nofollow, noarchive` dan meta robots, jadi tidak diindeks. `robots.txt` tidak memblokir apa pun, karena crawler pratinjau X mematuhi robots.txt.
- **Escape dan CSP.** Semua teks di-escape oleh `html/template`. CSP berbasis hash: hanya satu blok style dan satu script bawaan, gambar hanya dari host sendiri, tanpa form, frame, maupun base. Skema aplikasi divalidasi ulang di layanan sebelum dijadikan link.
- **Yang tidak dibuka di sini.** Kode di tautan tidak membocorkan ID post. Membuka post di aplikasi tetap butuh login, dan RLS (blokir, moderasi) berlaku seperti biasa.
- **Pembuatan kode** (`post_share_link`) hanya untuk pengguna login, dengan batas `post_share_link` 120 kode baru per jam. Post yang sama selalu mendapat kode yang sama.

## Database (0207)

| Objek | Isi |
|---|---|
| `cs.cs_settings` `share.links` | `enabled`, `base_url` (http/https + host [+ port], tanpa path), `preview`. Diatur di Hub **Tautan berbagi** |
| `cs.cs_settings` `app.identity` | `app_name`, `android` (maks. 5 × package + 1–5 fingerprint), `ios_app_ids` (maks. 5 × `TEAMID.bundle`, untuk app iOS dan Mac), `android_store_url`, `ios_store_url`, `windows_download_url`, `macos_download_url` (https). Diatur di Hub **Integrasi aplikasi → Identitas aplikasi** (`cs_api.app_identity` / `cs_api.admin_save_app_identity`, audit `setting.app_identity`) |
| Skema aplikasi | Skema pertama di `banners.deep_link_schemes` (Hub **Integrasi aplikasi → Skema aplikasi**; urutan dipertahankan). Kosong = tanpa tombol **Buka di aplikasi** dan `app_url` `null` |
| `private.post_share_codes` | `code` (10 alfanumerik) ↔ `post_id` (unik), `created_by`, `created_at`. Ikut terhapus bila post dihapus permanen |
| `public.post_share_link(p_post_id)` | Untuk pengguna login. Mengembalikan `{code, url, app_url}`. Error `share_links_disabled` (403) atau `post_not_found` (404) |
| `public.resolve_post_share(p_code)` | Untuk pengguna login. Mengembalikan `post_id`, atau `null` bila post tidak tersedia |
| `public.share_link_config()` / `public.share_post_preview(p_code)` | Khusus `service_role` (layanan ini) |
| `cs_api.share_links()` / `cs_api.admin_save_share_links(p_config)` | Khusus Super Admin (Hub), divalidasi dan tercatat di audit `setting.share_links` (sebelum/sesudah) |
| `get_client_config` | Flag `post_links` = tautan aktif dan domain sudah diisi. Library hanya menampilkan menu tautan bila flag ini menyala |

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `PORT` / `OPS_PORT` | `8080` / `9100` | Halaman (lewat Traefik) / ops internal (`/livez`, `/readyz`, `/metrics`) |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Untuk JWT `service_role` 1 menit ke PostgREST dan Storage |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` / `STORAGE_URL` | `http://rest:3000` / `http://storage:5000` | |
| `CONFIG_TTL` | `30s` | Cache pengaturan. Bila database mati, pengaturan lama tetap dipakai sampai 10 menit |
| `PREVIEW_TTL` / `PREVIEW_CACHE_SIZE` | `30s` / `2000` | Cache pratinjau per kode, untuk menahan lonjakan saat tautan viral |
| `IMAGE_WIDTH` | `1200` | Lebar gambar post (200–2400) |
| `MAX_IMAGE_BYTES` | `5242880` | Gambar yang lebih besar dijawab 404 |
| `REQUEST_TIMEOUT` | `10s` | |
| `HEARTBEAT_INTERVAL` / `SHUTDOWN_TIMEOUT` | `30s` / `15s` | Heartbeat `share-link`. Statusnya `degraded` setelah 3 kegagalan database berturut-turut |
| `LOG_LEVEL` | `info` | |

Gambar diambil paling banyak 16 sekaligus per instance. Replika diatur lewat `SHARE_LINK_REPLICAS` (dev/single) atau `stack.cluster.yml` (2).

## Routing

- **dev**: semua host di port web dev, mis. `http://192.168.0.235:8000/p/<kode>`.
- **single/cluster**: hanya `Host(SHARE_DOMAIN)`. Bila `SHARE_DOMAIN` kosong, dipakai `PROXY_DOMAIN`. Path yang dilayani hanya `/p/` dan dua file `.well-known`. Middleware: `rate-limit`, `body-api`, `hsts`, `security-headers-share` (tanpa CSP, karena layanan memasang CSP sendiri). Sertifikat Let's Encrypt untuk `SHARE_DOMAIN` diambil otomatis lewat TLS-ALPN di port 443.

Isi **Domain tautan** di Hub dengan alamat yang sama, mis. `https://share.perusahaan.co.id`. Di dev, isi dengan `http://192.168.0.235:8000`.

## Metrik

`share_link_requests_total{route,status}` (`page`, `image`, `avatar`, `assetlinks`, `apple_app_site_association`, `other`), `share_link_preview_cache_entries`, `share_link_store_consecutive_failures`, `share_link_last_heartbeat_timestamp_seconds`.

## Tes

`make test-share-link`, atau di Windows `.\make.ps1 test-share-link`. Tes halaman memeriksa escape, CSP hash yang cocok dengan blok yang dirender, kode/post tidak tersedia (404 tanpa isi), saklar pratinjau, skema tidak valid, cache, database mati (pengaturan lama tetap dipakai, heartbeat `degraded`), gambar (bukan gambar, terlalu besar, redirect tidak diikuti), `assetlinks.json`, dan AASA. Tes database: `supabase/tests/184_post_share_links_test.sql` dan `185_app_identity_test.sql`.
