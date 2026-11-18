# Modul 8: Infrastruktur

**Tujuan:** mengerti bagaimana ±30 container dijalankan, saling terhubung, dijaga tetap hidup, dan dicadangkan. Modul ini tidak mengubah apa pun. Latihannya hanya melihat dan membaca.

---

## 8.1 Docker dalam satu halaman

| Istilah | Arti | Contoh kita |
|---|---|---|
| **Image** | Paket siap jalan: OS minimal + program + dependensinya | `postgrest/postgrest:v14.18@sha256:…` |
| **Container** | Image yang sedang berjalan | `olt-social-rest-1`, `olt-social-rest-2` |
| **Volume** | Penyimpanan yang tetap ada walau container dibuat ulang | `db-data` (isi database), `storage-data` (file) |
| **Network** | Jaringan virtual antar container. Nama service menjadi nama host | PostgREST memanggil `pgbouncer:6432`, bukan IP |
| **Docker Compose** | Satu file YAML yang mendefinisikan semua container | [docker/compose.yml](../../docker/compose.yml) |

**Image dikunci dengan digest** (`@sha256:…`), bukan hanya tag (`v14.18`). Tag bisa dipindah pemiliknya ke isi lain, sedangkan digest adalah sidik jari isi yang pasti. Kita selalu tahu persis apa yang berjalan.

### Perintah sehari-hari

```powershell
.\make.ps1 ps                      # status semua service
.\make.ps1 logs -Service rest      # log satu service (Linux: make logs s=rest)
docker compose -f docker/compose.yml ps --format "table {{.Name}}\t{{.Status}}"
docker inspect olt-social-rest-1 --format "{{json .State.Health}}"
```

## 8.2 Profil deployment

| Profil | Untuk | File tambahan |
|---|---|---|
| `dev` | Laptop pengembang | [compose.dev.yml](../../docker/compose.dev.yml) |
| `single` | Satu server produksi | [compose.prod.yml](../../docker/compose.prod.yml) |
| `cluster` | Beberapa server (Docker Swarm) | [stack.cluster.yml](../../docker/stack.cluster.yml) |

Ada juga **compose profiles** untuk service yang tidak ikut `make up` bawaan: `cs` (Hub), `tools`, dan `trade-relay` (fitur yang dijeda).

## 8.3 Jalan sebuah request

```
Internet
   │ HTTPS :443
   ▼
Traefik ── TLS (Let's Encrypt), batas per IP, header X-Olt-Edge untuk domain publik
   ▼
Kong ── cek apikey, CORS, rute per awalan path
   ├─ /rest/v1        → rest ×2 (PostgREST) ─┐
   ├─ /realtime/v1    → realtime             ├─► PgBouncer ─► Postgres (db)
   ├─ /storage/v1     → storage              ─┘
   ├─ /bridge/v1      → auth-bridge ×2 ─► Valkey (rate limit, cache)
   ├─ /media/v1       → media ×2 ─► classifier ×2, clamav, storage
   └─ /integration/v1 → integration ×2
```

| Komponen | Peran | Kenapa ada |
|---|---|---|
| **Traefik** | Reverse proxy di tepi | Satu-satunya yang membuka port ke internet; mengurus sertifikat HTTPS otomatis |
| **Kong** | API gateway | Satu pintu untuk semua layanan, dengan aturan yang seragam |
| **Valkey** | Database di memori (fork open source dari Redis) | Penghitung rate limit dan cache yang dibagi beberapa replika auth-bridge |

Rute Kong: [docker/volumes/api/kong.yml](../../docker/volumes/api/kong.yml).

## 8.4 Replika dan skala

Layanan yang sibuk berjalan dua salinan: `rest`, `auth-bridge`, `media`, `classifier`, `imgproxy`, `integration`. Jumlahnya diatur variabel `*_REPLICAS`. Docker membagi request ke semua replika, jadi bila satu mati, yang lain tetap melayani.

Realtime tetap **satu** di profil dev/single, karena pelanggan WebSocket dan statusnya ada di memori satu proses. Menambah replika Realtime butuh mode cluster.

Menambah replika juga menambah kebutuhan koneksi database (modul 5.6) dan RAM. Lihat [docs/panduan/spesifikasi-server.md](../panduan/spesifikasi-server.md).

## 8.5 Rahasia (secrets)

Kunci dan password tidak ditaruh di variabel environment atau di dalam image, melainkan sebagai **file** di `docker/secrets/` yang dipasang ke container di `/run/secrets/<nama>`:

```powershell
Get-ChildItem docker/secrets | Select-Object Name    # lihat NAMA saja, jangan buka isinya
```

| Secret | Dipakai |
|---|---|
| `jwt_secret` | Menandatangani/memeriksa token Rendezvous (auth-bridge, PostgREST, Realtime, media, Storage) |
| `anon_key`, `service_role_key` | JWT siap pakai untuk `anon` dan `service_role` |
| `olt_jwks` | Kunci **publik** OLT untuk memeriksa token sosial |
| `postgres_password`, `postgrest_db_uri`, `valkey_password`, … | Koneksi antar layanan |

Aturannya:
- `docker/secrets/` dan `docker/.env` tidak pernah di-commit.
- Setiap commit dipindai **gitleaks** supaya tidak ada kunci yang bocor.
- Dibuat dengan `make gen-secrets`; secret yang sudah ada tidak ditimpa.
- Kredensial yang diatur operator (kunci Firebase, tujuan backup) disimpan terenkripsi di database (Vault) lewat Hub, bukan di file server.

## 8.6 Healthcheck, sentinel, healer

```yaml
healthcheck:
  test: [...]          # perintah yang harus sukses
  interval: 10s
  retries: 3
labels: ["olt.autoheal=true"]
```

| Lapis | Tugas |
|---|---|
| **Healthcheck** | Docker menjalankan perintah cek berkala, lalu menandai container `healthy` atau `unhealthy` |
| **healer** | Container berlabel `olt.autoheal=true` yang `unhealthy` terlalu lama di-restart otomatis (ada batas supaya tidak berputar terus). Juga menulis peta container untuk Hub |
| **sentinel** | Membaca `/metrics` setiap layanan (gaya Prometheus) dan statistik PgBouncer, lalu menulis ke database dan menyalakan alert (Telegram/email) |
| **Hub** | Menampilkan semuanya di Pengaturan → Sistem → Kesehatan sistem (Peta layanan, Status, Restart otomatis) |

Ini **self-healing**: gangguan kecil seperti layanan macet pulih sendiri, sedangkan gangguan besar memicu alert ke manusia.

## 8.7 Backup dan pemulihan

| Bagian | Cara | Bisa memulihkan |
|---|---|---|
| **Base backup** | `pg_basebackup`: salinan penuh file database | Kondisi saat backup dibuat |
| **WAL archive** | `pg_receivewal` menyimpan WAL terus-menerus | **Titik waktu mana pun** di antara backup (PITR, *point-in-time recovery*) |
| **restic** | Mengarsip base backup, WAL, dan file storage: terenkripsi, deduplikasi, retensi harian/mingguan/bulanan | Tujuan S3 atau folder lokal (diatur di Hub) |

Ingat modul 5.1: Postgres menulis setiap perubahan ke WAL sebelum ke file tabel. Dengan menyimpan base backup + semua WAL sesudahnya, database bisa "diputar ulang" sampai detik tertentu. Misalnya pukul 10:41:59, tepat sebelum seseorang menghapus data secara tidak sengaja.

Operasional: `make backup`, `make backup-snapshots`, `make restore-pitr AT=…`. Panduan lengkap ada di [docs/backup](../backup/README.md) dan [docs/panduan](../panduan/README.md).

## 8.8 Migrasi dan deploy

```
git pull → make up
           ├─ build image layanan yang berubah
           ├─ container migrate: jalankan migrasi baru berurutan (checksum dicek, file lama tidak boleh berubah)
           ├─ notify pgrst 'reload schema'
           └─ tunggu semua service healthy
```

File `.sql` wajib berakhiran baris LF. Checksum dihitung dari isi file, jadi mengubah CRLF ↔ LF di migrasi lama membuat migrate menolak berjalan.

---

## Latihan

1. Jalankan `.\make.ps1 ps`. Container mana yang punya dua replika? Mana yang tidak punya healthcheck?
2. Buka [docker/compose.yml](../../docker/compose.yml), cari service `rest`. Tulis: image, batas memori, healthcheck, secret yang dipakai, dan service apa yang harus hidup dulu (`depends_on`).
3. Buka [kong.yml](../../docker/volumes/api/kong.yml). Plugin apa yang dipasang di rute `/media/v1`?
4. Lihat log auth-bridge saat menjalankan latihan modul 4.3. Apa yang tercatat? Apakah token ikut tercatat? (Seharusnya tidak.)
5. Buka Hub → Pengaturan → Sistem → Kesehatan sistem → Peta layanan. Cocokkan dengan hasil `make ps`.
6. Jelaskan dengan kata-kata Anda sendiri: bila database rusak pukul 14:00 dan backup terakhir pukul 03:00, data jam berapa yang masih bisa diselamatkan, dan kenapa?

## Cek pemahaman

- Kenapa image dikunci dengan digest?
- Kenapa Realtime tidak dibuat dua replika di profil single?
- Apa bedanya healer dan sentinel?
- Apa itu PITR, dan apa peran WAL di dalamnya?

**Bacaan:** Docker docs *Compose file reference* (healthcheck, secrets, deploy.replicas); Traefik docs *Routers & TLS*; Kong docs *DB-less declarative config*; PostgreSQL docs *Continuous Archiving and Point-in-Time Recovery*; restic docs.
