# Panduan Operasional

Pegangan sehari-hari untuk tim yang menjalankan server sosial: apa saja yang berjalan, di mana mengatur apa, perintah yang dipakai, dan rutinitas. Pemasangan server baru: [server-install.md](server-install.md). Detail produksi: [PRODUCTION.md](PRODUCTION.md). Bila ada gangguan, buka [runbook-gangguan.md](runbook-gangguan.md).

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
- Kode Hub ada di repo terpisah [`rendezvous_hub`](https://github.com/dayat123123/rendezvous_hub), di-clone di `~/rendezvous_hub` (sebelah `~/chat_service_supabase`) oleh [server-install.sh](server-install.md). Image `cs-console` dibangun dari sana saat `make up`.
- Jangan mengedit file di dalam container (`docker exec`). Container dibuat ulang saat update dan perubahannya hilang.
- Kode dari Git, rahasia di luar server, pengaturan dari Hub, kesehatan dari alert, data dari backup.

### Nilai `docker/.env` yang paling sering disentuh

| Kunci | Fungsi | Bawaan |
|---|---|---|
| `PROXY_DOMAIN`, `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL` | Domain API (`https://<domain>`, `API_EXTERNAL_URL` diakhiri `/auth/v1`) | — |
| `ACME_EMAIL` | Notifikasi sertifikat Let's Encrypt | — |
| `CS_CONSOLE_DOMAIN`, `VPN_SOURCE_RANGES` | Domain Hub dan IP/rentang yang boleh membukanya, dipisah koma (`203.0.113.10/32,10.8.0.0/24`) | — |
| `HUB_DIR` | Lokasi checkout `rendezvous_hub`, absolut atau relatif terhadap `docker/` | `../../rendezvous_hub` |
| `EDGE_WS_PER_IP`, `EDGE_RATE_AVERAGE`, `EDGE_RATE_BURST` | Batas WebSocket dan request per IP | 1.500, 600, 1.200 |
| `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` | Login (tukar token) per IP per menit | 1.500 |
| `REALTIME_MAX_EVENTS_PER_SECOND` | Batas event chat live seluruh server | 20.000 |
| `DB_MEMORY` | Batas memori Postgres | 2G |
| `BACKUP_LOCAL_REPO_DIR` | Folder backup bila tujuan "Folder lokal" (produksi: disk terpisah) | `../backups/restic` |

Daftar lengkap dengan penjelasan ada di `docker/.env.example` dan [PRODUCTION.md](PRODUCTION.md) bagian 7.

## 3. Perintah

`PROFILE` bawaan Makefile adalah `dev`. Di server produksi, ekspor sekali agar setiap perintah memakai profil yang benar:

```bash
echo 'export PROFILE=single' >> ~/.bashrc && source ~/.bashrc
```

```bash
make up                 # nyalakan / terapkan perubahan .env; migrasi baru berjalan otomatis
make ps                 # semua harus healthy
make logs s=rest        # ikuti log satu layanan
git pull && make up     # update versi
git -C ~/rendezvous_hub pull --ff-only && make up   # update Hub (bila dipasang)
make backup             # salinan sesaat (pg_dump + file) sebelum update besar
make psql               # konsol SQL sebagai postgres (hati-hati)
```

Log beberapa menit terakhir tanpa mengikuti: `docker logs olt-social-<layanan>-1 --since 15m`.

Jangan pernah menjalankan `make reset` atau `docker volume rm` di server produksi: keduanya menghapus database dan file.

## 4. Pemantauan

Sentinel memeriksa semua layanan, disk, dan metrik kapasitas setiap ±45 detik. Masalah muncul sebagai alert di **Hub → Kesehatan sistem** dan dikirim ke Telegram/email setelah kanalnya diisi di **Pengaturan → Alert** (lalu **Kirim uji**).

Menu Kesehatan sistem saat ini disembunyikan dari navigasi Hub (`SHOW_SYSTEM_HEALTH_NAV`). Halamannya tetap bisa dibuka Super Admin lewat alamat `/system` di Hub (mis. `https://<domain Hub>/system`). Pengaturan yang sering dipakai ada di menu Pengaturan: **Backup** dan **Alert**.

**Restart otomatis (healer).** Docker menyalakan ulang layanan yang mati. Layanan yang masih hidup tetapi macet (`unhealthy`) di-restart layanan `healer` bila unhealthy terus-menerus ≥ 60 detik, maksimal 3 kali per layanan per jam. Database dan Valkey tidak pernah di-restart otomatis. Restart ditahan bila database/PgBouncer sendiri tidak sehat atau separuh layanan sakit bersamaan (gangguan sistemik). Riwayatnya ada di Kesehatan sistem → Restart otomatis; bila healer menyerah, alert kritis `healer:gave_up:<layanan>` terbuka. Detail: [services/healer](../services/healer/README.md).

| Kelompok alert | Artinya |
|---|---|
| `probe:<layanan>`, `service:*` | Layanan tidak menjawab |
| `rest:pool`, `pgbouncer:queue`, `db:lock_waits` | Database kewalahan |
| `realtime:events` | Chat live mendekati batas `REALTIME_MAX_EVENTS_PER_SECOND` |
| `backup:*` | Backup bermasalah (prioritas tinggi) |
| `disk:*`, `backup:repository_disk` | Disk hampir penuh |
| `cron:*` | Job terjadwal di database gagal |
| `healer:gave_up:*`, `healer:systemic`, `healer:stale` | Restart otomatis menyerah, ditahan karena gangguan sistemik, atau healer tidak berjalan |

Rincian setiap alert: [system-health](system-health/README.md) dan [PRODUCTION.md](PRODUCTION.md) bagian 7. Tindakan per gejala: [runbook-gangguan.md](runbook-gangguan.md).

## 5. Rutinitas

| Kapan | Apa |
|---|---|
| Harian | Tidak ada; tanggapi alert yang masuk |
| Mingguan | Hub → Pengaturan → Backup: uji restore otomatis terakhir berhasil |
| Bulanan | `git pull` (dan `git -C ~/rendezvous_hub pull --ff-only` bila Hub dipasang) lalu `make up` untuk patch, di luar jam bursa, setelah `make backup` |
| Sebelum restart database terencana | Di luar jam bursa; `make psql` lalu `CHECKPOINT;` agar shutdown singkat |
| Sekali, simpan di luar server | `docker/.env`, `docker/secrets/`, password backup, salinan `pgsodium_root.key` ([backup](backup/README.md#pemulihan)) |

Bila server hilang total, yang dibutuhkan untuk bangkit lagi: repo dari GitHub (`chat_service_supabase`, dan `rendezvous_hub` bila Hub dipasang), empat salinan di baris terakhir, dan backup.

## 6. Domain dan akses publik

1. Server mendapat IP publik (VPS), atau tim jaringan meneruskan port 80/443 dari IP publik kantor ke server (NAT).
2. A record `social-api.<domain>` mengarah ke IP itu, dan port 80/443 dibuka.
3. Isi domain di `docker/.env`, lalu `make up` (dengan `PROFILE=single`). Traefik meminta dan memperpanjang sertifikat HTTPS sendiri; DNS harus sudah benar sebelum langkah ini.

Port forwarding biasa (NAT) tidak mengubah IP klien. Bila di depan server dipasang proxy yang mengakhiri koneksi (Cloudflare, HAProxy, load balancer), batas per IP dan pembatasan Hub akan melihat IP proxy. Konfigurasi proxy tepercaya belum dibuat; jangan pasang proxy seperti itu sebelum konfigurasinya tersedia ([PRODUCTION.md](PRODUCTION.md) bagian 7, "Batas & rate limit").

## 7. Integrasi aplikasi OLT

| Pihak | Yang dikerjakan | Rujukan |
|---|---|---|
| Server sosial | Domain di `.env`, JWKS OLT di `docker/secrets/olt_jwks`, `make anon-key` | [olt-integration.md](olt-integration.md) |
| Backend OLT | Kunci Ed25519, endpoint token sosial (`iss`, `aud`, `sub`, `exp` ≤ 15 menit) | [olt-integration.md](olt-integration.md) |
| Aplikasi Flutter OLT | Dependency `rendezvous_community`, `supabaseUrl` + `anonKey` lewat `--dart-define-from-file`, `tokenProvider` | [panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md) |

Data untuk tim aplikasi (URL API, anon key, contoh `config/prod.json`, versi library minimum) dan status login OLT (heartbeat auth-bridge, `kid` terpasang, login nasabah terakhir) ada di Hub: **Pengaturan → Integrasi aplikasi** (Super Admin, hanya-baca). Kunci OLT tetap diganti lewat server (`docker/secrets/olt_jwks` lalu `make up`), bukan dari Hub.

Anon key aman berada di aplikasi: tanpa token sosial yang sah, anon key tidak bisa membaca atau menulis data. Yang tidak boleh ada di aplikasi: kunci privat OLT, `service_role` key, isi `docker/secrets/`, dan API key notifikasi.
