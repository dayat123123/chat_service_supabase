# Panduan Operasional

Pegangan sehari-hari untuk tim yang menjalankan server sosial: apa saja yang berjalan, di mana mengatur apa, perintah yang dipakai, dan rutinitas. Pemasangan server baru: [instalasi-server.md](instalasi-server.md). Detail produksi: [produksi.md](produksi.md). Update dan rollback: [pembaruan-sistem.md](pembaruan-sistem.md). Backup dan pemulihan: [backup.md](backup.md). Bila ada gangguan, buka [gangguan.md](gangguan.md). Daftar semua panduan: [README](README.md).

## 1. Gambaran sistem

```
Aplikasi OLT (nasabah)            Rendezvous Hub (staf, jaringan internal)
        │ HTTPS                            │
        ▼                                  ▼
[ PINTU ]    Traefik (HTTPS, batas per IP) → Kong (gerbang API)
        │
[ LAYANAN ]  REST (PostgREST) · Realtime (chat live) · Storage + media (upload, cek NSFW)
             auth-bridge (tukar token OLT) · integration (API notifEngine) · link-preview
        │
[ DATA ]     PgBouncer → Postgres (aturan bisnis: migrasi SQL di supabase/migrations)
             Valkey (penghitung rate limit) · volume file storage
        │
[ PENJAGA ]  sentinel (cek kesehatan + alert) · backup (restic) · janitor (bersih file)
             notifier (push FCM)
```

- Hampir semua logika bisnis ada di database. Layanan lain meneruskan request dan menjaga batas. Data database adalah satu-satunya yang tidak boleh hilang; karena itu backup paling penting.
- Semua layanan memakai `restart: unless-stopped`: layanan yang mati dinyalakan ulang Docker dalam hitungan detik. Container `migrate` dan `volume-init` memang berjalan sekali lalu keluar dengan kode 0.
- Aplikasi nasabah menyambung ulang sendiri dan menambal pesan yang tertinggal setelah gangguan singkat.

### Kenali setiap layanan

Setiap kartu di **Pengaturan → Sistem → Kesehatan sistem → Peta layanan** adalah satu layanan berikut. Penjelasan yang sama tampil saat kartu diklik.

| Layanan | Fungsinya | Bila bermasalah |
|---|---|---|
| `traefik` | Pintu masuk dari internet. Menerima semua koneksi HTTPS dari aplikasi nasabah dan Hub, mengurus sertifikat keamanan, dan membatasi permintaan berlebihan dari satu alamat. | Aplikasi dan Hub tidak bisa dibuka sama sekali. |
| `kong` | Gerbang API. Meneruskan setiap permintaan ke layanan yang tepat (data, login, chat langsung, file) dan memeriksa kunci aksesnya. | Semua fitur di aplikasi dan Hub berhenti. |
| `cs-console` | Web Rendezvous Hub yang dipakai staf: tiket CS, komunitas, kepatuhan, dan pengaturan. | Staf tidak bisa membuka Hub. Aplikasi nasabah tetap berjalan. |
| `rest` | API utama. Melayani hampir semua permintaan aplikasi dan Hub (feed, chat, profil, tiket) langsung ke database, dengan aturan siapa boleh melihat apa. | Sebagian besar fitur gagal dimuat. |
| `auth` | Akun dan sesi login. Membuat dan memperpanjang sesi, termasuk login staf ke Hub. | Staf tidak bisa masuk ke Hub dan sesi yang habis tidak bisa diperpanjang. |
| `auth-bridge` | Jembatan login dari aplikasi OLT. Menukar token dari OLT menjadi sesi fitur sosial, sehingga nasabah tidak perlu login dua kali. | Nasabah tidak bisa masuk ke fitur sosial. Yang sudah masuk tetap bisa memakai sampai sesinya habis. |
| `realtime` | Pengantar pesan langsung. Mengirim chat baru, status mengetik, dan pembaruan secara seketika ke aplikasi dan Hub. | Chat tetap tersimpan, tetapi baru muncul setelah halaman dimuat ulang. |
| `storage` | Penyimpanan file: foto profil, gambar postingan, dan lampiran chat CS. | Gambar dan lampiran tidak tampil dan tidak bisa diunggah. |
| `functions` | Fungsi tambahan untuk Hub, misalnya membuat akun staf dan reset password. | Pengelolaan akun staf di Hub gagal. Fitur lain tetap berjalan. |
| `integration` | Pintu untuk sistem OLT mengirim notifikasi transaksi ke nasabah dan postingan dari akun bot resmi. | Notifikasi dari OLT tidak masuk ke aplikasi. |
| `nasabah-gateway` | Jembatan menu Akun Nasabah di Hub ke csAdmin OLT, untuk melihat dan membantu akun nasabah. | Menu Akun Nasabah di Hub tidak bisa dipakai. |
| `media` | Penerima unggahan. Memeriksa setiap file dari nasabah (jenis file, virus, konten tidak pantas) dan membuang data lokasi foto sebelum disimpan. | Unggah gambar dan dokumen gagal. |
| `classifier` | Pemindai gambar dengan model AI lokal di server sendiri. Menilai apakah gambar mengandung konten tidak senonoh sebelum boleh tampil. | Unggahan gambar ditolak demi keamanan. |
| `clamav` | Pemindai virus untuk dokumen dan file yang dikirim di chat CS. | Unggahan dokumen ditolak. |
| `imgproxy` | Pengolah gambar. Mengecilkan dan menyesuaikan ukuran gambar supaya cepat dimuat di HP. | Gambar lambat atau gagal tampil. |
| `notifier` | Pengirim push notification ke HP nasabah lewat Firebase. | Push ke HP tertunda. Notifikasi tetap ada di kotak notifikasi aplikasi dan dikirim setelah layanan menyala. |
| `janitor` | Pembersih file. Menghapus file yang sudah tidak dipakai, misalnya lampiran dari akun yang dihapus. | Tidak terasa langsung; file sisa menumpuk sampai layanan menyala lagi. |
| `link-preview` | Pembuat pratinjau tautan. Menampilkan judul dan gambar saat nasabah membagikan link, dengan pengamanan dari link berbahaya. | Tautan tampil tanpa pratinjau. |
| `trade-relay` | Relay Berbagi Trade. Mendengarkan order dan trade realtime dari OLT. Saat ini sengaja dimatikan karena fitur dijeda. | Tidak ada dampak selama Berbagi Trade dijeda. |
| `pgbouncer` | Pengatur antrean koneksi database. Membagi koneksi supaya database tidak kewalahan saat ramai. | Layanan tidak bisa menghubungi database; sebagian besar fitur gagal. |
| `db` | Database. Menyimpan semua data (akun, chat, tiket, postingan) beserta aturan bisnisnya. Bagian paling penting di sistem. | Seluruh sistem berhenti. Data tetap aman di disk dan di backup. |
| `valkey` | Penyimpanan cepat untuk hitungan batas permintaan login, supaya serangan coba-coba password bisa dibatasi. | Login tetap berjalan dengan pembatas sementara di masing-masing layanan. |
| `sentinel` | Pemantau. Memeriksa semua layanan, disk, dan database setiap ±30 detik, membuat alert, mengirimnya ke Telegram/email, dan mengirim data peta ini. | Alert dan peta ini berhenti diperbarui. |
| `healer` | Restart otomatis. Menyalakan ulang layanan yang hidup tetapi macet, dan membaca daftar container untuk peta ini. | Tidak ada restart otomatis dan peta ini berhenti diperbarui. |
| `backup` | Backup. Menyalin database dan file ke repositori terenkripsi secara terus-menerus, dan menjalankan uji restore mingguan. | Backup berhenti dan alert muncul. Sistem yang sedang berjalan tidak terganggu. |
| `migrate` | Pemasang perubahan database. Berjalan sekali setiap update lalu selesai; status "Selesai" itu normal. | Bila gagal saat update, perubahan database tidak terpasang dan update perlu diulang. |
| `volume-init` | Penyiap folder penyimpanan. Berjalan sekali saat sistem dinyalakan lalu selesai; status "Selesai" itu normal. | Bila gagal, beberapa layanan tidak bisa menulis file. |
| `tools` | Alat operasional (backup sesaat, uji, data contoh) yang dijalankan tim IT sesekali lalu selesai. | Tidak berdampak ke sistem yang berjalan. |
| `meta` | Pendukung Supabase Studio untuk membaca struktur database. Hanya untuk tim teknis. | Studio tidak bisa dipakai. Tidak berdampak ke nasabah atau staf. |
| `studio` | Supabase Studio, dashboard database untuk tim teknis. Di server produksi sebaiknya dimatikan kecuali sedang dipakai. | Tidak berdampak ke nasabah atau staf. |
| `dummy-olt` | Server OLT tiruan untuk pengembangan dan uji login. Tidak dipakai di produksi. | Hanya berdampak ke uji di lingkungan development. |
| `dummy-iproxy` | Simulator iProxy OLT untuk uji Berbagi Trade. Dijeda bersama fiturnya. | Tidak ada dampak. |

## 2. Di mana mengatur apa

| Tempat | Isi | Cara mengubah |
|---|---|---|
| **Rendezvous Hub** | Tujuan dan password backup, kunci Firebase, kanal alert (Telegram/email), alamat gateway csAdmin, API key notifikasi, kill switch, fitur aplikasi dan versi minimum, kebijakan konten, slow mode dan jam ramai, dokumen hukum, akun staf | Dari browser, langsung berlaku, tercatat di **Kepatuhan → Jejak Audit** |
| **`docker/.env`** | Domain dan URL publik, email Let's Encrypt, alamat DB, pool PgBouncer, batas kapasitas, memori/CPU, folder backup lokal, IP yang boleh membuka Hub | SSH ke server, edit, lalu `make up` |
| **`docker/secrets/`** | Password database, JWT secret, anon key, kunci publik OLT (`olt_jwks`) | Dibuat sekali dengan `make gen-secrets`; `olt_jwks` diisi JWKS dari tim OLT |
| **Firewall penyedia server** | Port 80/443 publik, 22 hanya IP admin | Panel penyedia atau firewall kantor |
| **DNS** | A record domain API (dan domain Hub bila dipakai) | Pengelola domain |

Aturan:

- File compose (`docker/compose*.yml`) dan kode datang dari Git lewat `git pull`. Jangan diedit langsung di server.
- Kode Hub ada di repo terpisah [`rendezvous_hub`](https://github.com/dayat123123/rendezvous_hub), di-clone di `~/rendezvous_hub` (sebelah `~/chat_service_supabase`) oleh [server-install.sh](instalasi-server.md). Image `cs-console` dibangun dari sana saat `make up`.
- Jangan mengedit file di dalam container (`docker exec`). Container dibuat ulang saat update dan perubahannya hilang.
- Kode dari Git, rahasia di luar server, pengaturan dari Hub, kesehatan dari alert, data dari backup.

### Nilai `docker/.env` yang paling sering disentuh

| Kunci | Fungsi | Bawaan |
|---|---|---|
| `PROXY_DOMAIN`, `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL` | Domain API (`https://<domain>`, `API_EXTERNAL_URL` diakhiri `/auth/v1`) | — |
| `ACME_EMAIL` | Notifikasi sertifikat Let's Encrypt | — |
| `CS_CONSOLE_DOMAIN`, `VPN_SOURCE_RANGES` | Domain Hub dan IP/rentang yang boleh membukanya, dipisah koma (`203.0.113.10/32,10.8.0.0/24`); `VPN_SOURCE_RANGES` kosong = hanya jaringan internal (IP privat LAN kantor dan VPN), internet 403 | — |
| `HUB_DIR` | Lokasi checkout `rendezvous_hub`, absolut atau relatif terhadap `docker/` | `../../rendezvous_hub` |
| `EDGE_WS_PER_IP`, `EDGE_RATE_AVERAGE`, `EDGE_RATE_BURST` | Batas WebSocket dan request per IP | 1.500, 600, 1.200 |
| `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` | Login (tukar token) per IP per menit | 1.500 |
| `REALTIME_MAX_EVENTS_PER_SECOND` | Batas event chat live seluruh server | 20.000 |
| `DB_MEMORY` | Batas memori Postgres | 2G |
| `BACKUP_LOCAL_REPO_DIR` | Folder backup bila tujuan "Folder lokal" (produksi: disk terpisah) | `../backups/restic` |

Daftar lengkap dengan penjelasan ada di `docker/.env.example` dan [produksi.md](produksi.md) bagian 7.

## 3. Perintah

`PROFILE` bawaan Makefile adalah `dev`. Di server produksi, ekspor sekali agar setiap perintah memakai profil yang benar:

```bash
echo 'export PROFILE=single' >> ~/.bashrc && source ~/.bashrc
```

```bash
make up                 # nyalakan / terapkan perubahan .env; migrasi baru berjalan otomatis
make ps                 # semua harus healthy
make logs s=rest        # ikuti log satu layanan
git pull && make up     # update versi (langkah lengkap dan rollback: pembaruan-sistem.md)
git -C ~/rendezvous_hub pull --ff-only && make up   # update Hub (bila dipasang)
make backup             # salinan sesaat (pg_dump + file) sebelum update besar
make psql               # konsol SQL sebagai postgres (hati-hati)
make prune-images DRY_RUN=1   # lihat image Docker versi lama yang akan dibuang
```

`make up` (dan `.\make.ps1 up`) membuang image versi lama milik stack ini setelah semua layanan sehat: tag `olt-social/*` yang sudah tidak dipakai, versi lama image upstream yang tercantum di `docker/*.yml`, sisa build tanpa tag, dan build cache yang tidak dipakai 7 hari. Image yang masih dipakai container, image proyek lain, dan image dasar seperti `golang` atau `node` tidak disentuh. Lewati dengan `NO_PRUNE=1` (Makefile) atau `-NoPrune` (make.ps1).

Log beberapa menit terakhir tanpa mengikuti: `docker logs olt-social-<layanan>-1 --since 15m`.

Jangan pernah menjalankan `make reset` atau `docker volume rm` di server produksi: keduanya menghapus database dan file.

## 4. Pemantauan

Sentinel memeriksa semua layanan, disk, dan metrik kapasitas setiap ±45 detik. Masalah muncul sebagai alert di **Hub → Pengaturan → Sistem → Kesehatan sistem**, sebagai angka merah pada menu **Pengaturan**, dan dikirim ke Telegram/email setelah kanalnya diisi di **Pengaturan → Sistem → Alert** (lalu **Kirim uji**).

**Kesehatan sistem** (Super Admin) punya tiga tab:

| Tab | Isi |
|---|---|
| **Peta layanan** | Semua container di server dan statusnya, diperbarui ±10 detik: lajur Gerbang, API & layanan, Data, Pekerja, Operasional; jumlah replika; CPU, RAM, dan tren CPU per layanan; klik kartu untuk detail replika (uptime, restart, image, probe). Container yang sengaja dimatikan tampil abu-abu bergaris putus |
| **Status** | Alert terbuka dan riwayat, probe layanan, disk, database, antrean, cron |
| **Restart otomatis** | Riwayat dan aturan healer |

Peta layanan dibaca healer langsung dari Docker (hanya baca) dan diteruskan sentinel. Bila tertulis "Data terlambat", periksa container `healer` dan `sentinel`. Alamat lama `/system` dialihkan ke halaman ini.

**Restart otomatis (healer).** Docker menyalakan ulang layanan yang mati. Layanan yang masih hidup tetapi macet (`unhealthy`) di-restart layanan `healer` bila unhealthy terus-menerus ≥ 60 detik, maksimal 3 kali per layanan per jam. Database dan Valkey tidak pernah di-restart otomatis. Restart ditahan bila database/PgBouncer sendiri tidak sehat atau separuh layanan sakit bersamaan (gangguan sistemik). Riwayatnya ada di Kesehatan sistem → Restart otomatis; bila healer menyerah, alert kritis `healer:gave_up:<layanan>` terbuka. Detail: [services/healer](../../services/healer/README.md).

| Kelompok alert | Artinya |
|---|---|
| `probe:<layanan>`, `service:*` | Layanan tidak menjawab |
| `rest:pool`, `pgbouncer:queue`, `db:lock_waits` | Database kewalahan |
| `realtime:events` | Chat live mendekati batas `REALTIME_MAX_EVENTS_PER_SECOND` |
| `backup:*` | Backup bermasalah (prioritas tinggi) |
| `disk:*`, `backup:repository_disk` | Disk hampir penuh |
| `cron:*` | Job terjadwal di database gagal |
| `healer:gave_up:*`, `healer:systemic`, `healer:stale` | Restart otomatis menyerah, ditahan karena gangguan sistemik, atau healer tidak berjalan |

Rincian setiap alert: [system-health](../system-health/README.md) dan [produksi.md](produksi.md) bagian 7. Tindakan per gejala: [gangguan.md](gangguan.md).

## 5. Rutinitas

| Kapan | Apa |
|---|---|
| Harian | Tidak ada; tanggapi alert yang masuk |
| Mingguan | Hub → Pengaturan → Sistem → Backup: uji restore otomatis terakhir berhasil; salin repositori backup ke luar server bila memakai folder lokal ([backup.md](backup.md#4-pemeriksaan-rutin)) |
| Bulanan | Update versi di luar jam bursa sesuai [pembaruan-sistem.md](pembaruan-sistem.md) |
| Sebelum restart database terencana | Di luar jam bursa; `make psql` lalu `CHECKPOINT;` agar shutdown singkat |
| Sekali, simpan di luar server | `docker/.env`, `docker/secrets/`, password backup, salinan `pgsodium_root.key` ([backup](../backup/README.md#pemulihan)) |

Bila server hilang total, yang dibutuhkan untuk bangkit lagi: repo dari GitHub (`chat_service_supabase`, dan `rendezvous_hub` bila Hub dipasang), empat salinan di baris terakhir, dan backup.

## 6. Domain dan akses publik

1. Server mendapat IP publik (VPS), atau tim jaringan meneruskan port 80/443 dari IP publik kantor ke server (NAT).
2. A record `social-api.<domain>` mengarah ke IP itu, dan port 80/443 dibuka.
3. Isi domain di `docker/.env`, lalu `make up` (dengan `PROFILE=single`). Traefik meminta dan memperpanjang sertifikat HTTPS sendiri; DNS harus sudah benar sebelum langkah ini.

Port forwarding biasa (NAT) tidak mengubah IP klien. Bila di depan server dipasang proxy yang mengakhiri koneksi (Cloudflare, HAProxy, load balancer), batas per IP dan pembatasan Hub akan melihat IP proxy. Konfigurasi proxy tepercaya belum dibuat; jangan pasang proxy seperti itu sebelum konfigurasinya tersedia ([produksi.md](produksi.md) bagian 7, "Batas & rate limit").

## 7. Integrasi aplikasi OLT

| Pihak | Yang dikerjakan | Rujukan |
|---|---|---|
| Server sosial | Domain di `.env`, JWKS OLT di `docker/secrets/olt_jwks`, `make anon-key` | [olt-integration.md](../olt-integration.md) |
| Backend OLT | Kunci Ed25519, endpoint token sosial (`iss`, `aud`, `sub`, `exp` ≤ 15 menit) | [olt-integration.md](../olt-integration.md) |
| Aplikasi Flutter OLT | Dependency `rendezvous_community`, `supabaseUrl` + `anonKey` lewat `--dart-define-from-file`, `tokenProvider` | [panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md) |

Data untuk tim aplikasi (URL API, anon key, contoh `config/prod.json`, versi library minimum) dan status login OLT (heartbeat auth-bridge, `kid` terpasang, login nasabah terakhir) ada di Hub: **Pengaturan → Integrasi → Integrasi aplikasi** (Super Admin, hanya-baca). Kunci OLT tetap diganti lewat server (`docker/secrets/olt_jwks` lalu `make up`), bukan dari Hub.

Anon key aman berada di aplikasi: tanpa token sosial yang sah, anon key tidak bisa membaca atau menulis data. Yang tidak boleh ada di aplikasi: kunci privat OLT, `service_role` key, isi `docker/secrets/`, dan API key notifikasi.
