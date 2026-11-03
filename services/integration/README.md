# integration

Gateway integrasi untuk sistem OLT (versi **0.2.0**). Menerima notifikasi transaksi dari notifEngine (`POST /notify/messages`) dan postingan bot resmi (`POST /bot/posts`), memeriksa API key integrasi, lalu meneruskan batch ke RPC database. Push dikirim lewat antrean yang sudah ada (`private.push_enqueue` → notifier → FCM). Kontrak untuk tim OLT: [docs/integration/README.md](../../docs/integration/README.md). Migrasi: `0068_integration.sql`, `0086_notify_targets.sql` (target siaran, kotak notifikasi, kategori).

Hanya Go standard library. Image distroless nonroot, subcommand `healthcheck`.

```
notifEngine ──HTTPS──▶ Traefik ──▶ Kong /integration/v1/* (apikey anon) ──▶ integration:8080
                                                                               │ 1. batas gagal-auth per IP
                                                                               │ 2. Bearer oik_… → SHA-256 → integration_authenticate (cache 30 dtk)
                                                                               │ 3. IP (CIDR key), scope, rate limit per key
                                                                               │ 4. body ≤ 2 MiB, 1–500 pesan / 1–50 postingan
                                                                               ▼ 5. integration_notify / integration_bot_post (service_role)
                                                                            PostgREST ──▶ Postgres
```

## Alur request

1. **IP klien** diambil seperti auth-bridge: `X-Forwarded-For` hanya dipercaya dari `TRUSTED_PROXIES` (Kong/Traefik). IP klien = hop paling kanan yang bukan proxy; bila semua hop privat (notifEngine di LAN), dipakai hop paling kiri. Traefik membuang XFF kiriman internet.
2. **Batas gagal-auth:** lebih dari `AUTH_FAILURES_PER_MINUTE` key salah/hilang dari satu IP → `429 too_many_auth_failures` tanpa menyentuh database.
3. **API key** dari `Authorization: Bearer oik_…`. Format diperiksa lokal (`oik_` + `[A-Za-z0-9_-]`, ≤ 200), lalu hanya **hash SHA-256**-nya yang dikirim ke `public.integration_authenticate(p_key_hash, p_ip)`. Hasilnya di-cache per (hash, IP) selama `KEY_CACHE_TTL`; key tidak dikenal di-cache maks 10 detik; error database tidak di-cache. Key tidak pernah ditulis ke log, metrik, atau database.
4. **IP** di luar `allowed_cidrs` key → `403 ip_not_allowed`. **Scope**: `/notify/messages` butuh `notify`, `/bot/posts` butuh `bot_post` → `403 scope_forbidden`. Pesan dengan `target` selain `cust_id` (siaran) butuh izin tambahan `notify_broadcast`; tanpa izin itu pesan tersebut dijawab per pesan `invalid` + `scope_forbidden` oleh database, pesan lain dalam batch tetap diproses.
5. **Rate limit** per key: `rate_limit_per_minute` request per menit (jendela tetap, per instance) → `429 rate_limited` + `Retry-After`.
6. **Body**: satu objek JSON (`MAX_BODY_BYTES`, default 2 MiB → `413 body_too_large`), `messages` array 1–500 atau `posts` array 1–50 (`400 invalid_batch`). Isi tiap item divalidasi di database (satu sumber aturan).
7. **Slot database**: maks `MAX_CONCURRENT` batch paralel; menunggu slot > 5 detik → `503 busy` (`Retry-After: 2`).
8. RPC dipanggil dengan JWT `service_role` 60 detik. Database memeriksa ulang key (aktif, scope, CIDR), jadi key yang dicabut langsung ditolak walau masih di cache; jawaban `401` dari database juga menghapus cache key itu.
9. Respons RPC (hasil per pesan) diteruskan apa adanya dengan `200`. Database tidak terjangkau → `503 unavailable` (`Retry-After: 5`).

Port 8080 hanya melayani dua path itu (metode lain `405`, path lain `404`). Setiap respons membawa `X-Request-Id` (dari klien bila `[A-Za-z0-9._-]{1,64}`). Log JSON per request: endpoint, status, kode, IP, `key_id`, `key_prefix`, jumlah item, ringkasan hasil, durasi. Isi pesan dan cust id tidak dicatat.

## Database (migrasi 0068, 0086)

| Objek | Isi |
|---|---|
| `private.account_links` | `cust_id` (huruf besar) ↔ `profile_id`, `seen_at`. Diisi auth-bridge dari klaim `accounts` lewat `public.set_olt_account_links(p_profile_id, p_accounts)` (service_role, ganti seluruh set, maks 50). Dihapus trigger `profiles_70_account_links_forget` saat akun dihapus; kedaluwarsa setelah `integration.account_link_days` |
| `private.integration_keys` | Nama, prefix 8 karakter, hash SHA-256, `scopes` ⊂ {`notify`, `notify_broadcast`, `bot_post`} (`notify_broadcast` wajib disertai `notify`), akun resmi (wajib untuk `bot_post`), `allowed_cidrs`, `rate_limit_per_minute`, nonaktif/cabut, terakhir dipakai + IP |
| `private.integration_receipts` | Id pesan per key untuk idempotensi (status `queued`, `no_recipient`, `accepted` + `broadcast_id`), dibersihkan setelah `integration.receipt_days` (7) |
| `private.integration_posts` | Penanda postingan **bot** (key, id pesan, `community_post_id`, `post_id`); id unik selamanya |
| `private.integration_daily` | Statistik harian per key (WIB), disimpan 400 hari |
| `public.integration_notify(p_key_id, p_messages, p_ip)` | Validasi per pesan (termasuk `target`, `channels`, `category`), idempotensi. Target `cust_id`: sinkron, profil tertaut aktif → `private.integration_deliver` (kotak notifikasi `announcement` dan/atau `private.push_enqueue(...)` dengan `ref` `olt:<key>:<YYYYMMDD>`). Target lain: satu baris `private.integration_broadcasts` (`accepted` + `broadcast_id`) |
| `private.integration_broadcasts` | Job siaran: pesan, target, channels, category, status `queued`/`sending`/`done`/`failed`, kursor profil, penghitung `targeted`, `recipients`, `devices`, `inbox`, `capped`, `pref_skipped`. Diproses cron `integration-broadcasts` (tiap 15 detik, `integration.broadcast_batch_size` profil per putaran) |
| `private.integration_broadcast_caps` | Jumlah siaran non-`important` per profil per hari WIB (`integration.broadcast_daily_cap`) |
| `public.integration_bot_post(p_key_id, p_posts, p_ip)` | `private.validate_text` + `private.apply_content_policy`, lalu baris `cs.community_posts` (dibuat atas nama pembuat key) yang langsung diterbitkan `cs.community_publish` sebagai akun resmi. Penolakan kebijakan konten dibatalkan per postingan (savepoint) |
| `private.post_is_bot(post_id)` | Untuk label **Bot** di feed |
| `private.account_links_export(profile)` | Untuk `export_my_data` (`linked_accounts`) |
| `private.push_allowed(uuid, text)` / `private.push_allowed_for(uuid, text, text)` | Preferensi push per jenis (`0076`, pemetaan `olt.*` di `0086`); versi tiga argumen menambahkan `category` (`important` menembus preferensi dan jam tenang, `promo` memakai `olt.promo`) |
| Cron `integration-maintenance` | Tiap jam menit ke-23: bersihkan id pesan lama, tautan kedaluwarsa, statistik > 400 hari, batas harian siaran yang lewat, siaran selesai > `integration.broadcast_days` |

Setting (`private.settings`): `integration.account_link_days` (30), `integration.receipt_days` (7), `integration.bot_posts_per_hour` (30), `integration.broadcast_daily_cap` (3), `integration.broadcast_batch_size` (2000), `integration.broadcast_days` (90).

## Konfigurasi

| Variabel | Default | Keterangan |
|---|---|---|
| `PORT` / `OPS_PORT` | `8080` / `9100` | API (lewat Kong) / ops internal |
| `JWT_SECRET` / `JWT_SECRET_FILE` | wajib | Secret JWT Supabase (≥ 32 karakter), untuk menandatangani JWT `service_role` ke PostgREST |
| `JWT_ISSUER` | `supabase` | |
| `POSTGREST_URL` | `http://rest:3000` | |
| `INSTANCE_ID` | hostname + acak | Nama instance di heartbeat |
| `TRUSTED_PROXIES` | jaringan privat | Sama dengan auth-bridge |
| `KEY_CACHE_TTL` | `30s` | 1 dtk – 5 mnt |
| `MAX_BODY_BYTES` | `2097152` | 64 KiB – 16 MiB. Samakan dengan middleware Traefik |
| `MAX_CONCURRENT` | `8` | Batch paralel ke database |
| `AUTH_FAILURES_PER_MINUTE` | `30` | Per IP |
| `REQUEST_TIMEOUT` | `30s` | Batas panggilan PostgREST |
| `HEARTBEAT_INTERVAL` | `30s` | `public.service_heartbeat('integration', …)` |
| `SHUTDOWN_TIMEOUT` | `20s` | |
| `LOG_LEVEL` | `info` | |

## Ops (port 9100, tidak dirutekan)

`GET /livez`, `GET /readyz` (503 saat shutdown), `GET /metrics`:

| Metrik | Isi |
|---|---|
| `integration_requests_total{endpoint,code}` | Request per endpoint (`notify`, `bot_posts`) dan kode hasil (`ok` atau kode error) |
| `integration_messages_total{result}` | `queued`, `accepted`, `no_recipient`, `duplicate`, `invalid` |
| `integration_push_devices_total` | Baris push yang diantrekan |
| `integration_inbox_notifications_total` | Notifikasi kotak masuk yang dibuat pesan `cust_id` (siaran dihitung di `cs_api.integration_broadcasts`) |
| `integration_bot_posts_total{result}` | `published`, `rejected`, `duplicate`, `invalid`, `rate_limited` |
| `integration_request_duration_seconds` | Summary durasi request ber-key valid |
| `integration_inflight_requests`, `integration_max_concurrent_requests` | Slot database |
| `integration_key_cache_entries` | Entri cache key |
| `integration_store_consecutive_failures` | ≥ 3 → heartbeat `degraded` |
| `integration_last_heartbeat_timestamp_seconds` | |

Heartbeat `detail`: `notify_messages`, `bot_posts`, `keys_cached`, `inflight`.

**Batas per instance.** Rate limit per key dan batas gagal-auth disimpan di memori tiap instance. Dengan N replika, batas efektif N kali. Batas postingan bot per jam dihitung di database (berlaku global).

## Pemasangan

Layanan ini belum dipasang di compose/Kong/Traefik (fase berikutnya). Yang dibutuhkan:
- service compose `integration` (jaringan `app`, secret `jwt_secret`, healthcheck `/integration healthcheck`);
- rute Kong `/integration/v1/` → `http://integration:8080/` (strip path, `key-auth` + `acl` anon/admin, tanpa CORS);
- router Traefik `PathPrefix(/integration/v1)` dengan batas body 2 MiB (`body-api` 256 KiB terlalu kecil untuk 500 pesan);
- probe sentinel `integration=http://integration:9100/livez` dan label `health_service_label('integration')` bila ingin tampil di Kesehatan sistem.

## Development

```bash
docker run --rm -v "$PWD:/repo" -w /repo/services/integration golang:1.27.3-alpine3.24 \
  sh -c 'apk add --no-cache gcc musl-dev >/dev/null && go vet ./... && CGO_ENABLED=1 go test -race ./...'
```

Tes database: `supabase/tests/048_integration_test.sql` (81 assertion).
