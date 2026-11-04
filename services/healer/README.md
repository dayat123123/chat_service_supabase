# healer

Restart otomatis untuk container yang **unhealthy** di profil `dev` dan `single` (docker compose).

Semua service memakai `restart: unless-stopped`, jadi Docker sudah me-restart container yang **mati**. Docker tidak me-restart container yang hanya unhealthy: prosesnya hidup tetapi macet, misalnya PostgREST yang `/ready`-nya 503 terus atau Realtime yang tidak menjawab healthcheck. Healer mengisi celah itu. Di profil `cluster`, Swarm sudah mengganti task unhealthy, jadi healer tidak dijalankan (`replicas: 0` di `docker/stack.cluster.yml`).

Image `olt-social/healer:0.1.0`. Status dan riwayatnya tampil di web CS: **Kesehatan sistem → Restart otomatis** (Super Admin). Alert `healer:*` dikirim lewat kanal alert yang sama ([docs/system-health](../../docs/system-health/README.md#restart-otomatis-healer)).

## Cara kerja

```
healer ──(10 dtk) Docker Engine API lewat /var/run/docker.sock
   │                GET  /containers/json?filters=label=com.docker.compose.project=<project>
   │                GET  /containers/{id}/json
   │                POST /containers/{id}/restart
   └─ tulis atomik ─▶ /var/lib/olt-healer/state.json (volume healer-state)
                          │ dibaca (read-only) setiap 30 dtk
                    sentinel ──health_report(p_healer)──▶ database ──▶ alert + web CS
```

1. Healer menentukan compose project dari label `com.docker.compose.project` container-nya sendiri (hostname = id container). `HEALER_PROJECT` bisa menimpanya. Tanpa project, healer tidak menyentuh apa pun dan melaporkan error.
2. Setiap `HEALER_INTERVAL_SECONDS`, healer membaca container yang **sedang berjalan** dengan label project itu. Yang diawasi hanya container berlabel `olt.autoheal=true`. Container `db` dan `pgbouncer` dibaca juga sebagai penjaga (lihat aturan).
3. Hasilnya ditulis ke `state.json`: tulis ke file sementara di folder yang sama, `fsync`, lalu `rename`. Sentinel tidak pernah membaca file setengah jadi.
4. Sentinel 0.4.0 membaca file itu (`HEALER_STATE_FILE`) dan menyertakannya di laporan kesehatan. Aturan alert dihitung di database (migrasi `0113_healer.sql`).

Healer hanya memakai `net/http` bawaan Go (tanpa Docker SDK) dan hanya tiga endpoint di atas. Restart memakai `stop_grace_period` container (timeout bawaan Docker), jadi layanan tetap mendapat SIGTERM dan waktu berhenti yang sama seperti `docker compose restart`.

## Layanan yang diawasi

Label `olt.autoheal=true` ada di service stateless yang punya healthcheck (`docker/compose.yml`): `traefik`, `kong`, `auth`, `rest`, `realtime`, `storage`, `imgproxy`, `functions`, `pgbouncer`, `auth-bridge`, `notifier`, `janitor`, `classifier`, `media`, `backup`, `integration`, `link-preview`, `cs-console`, `nasabah-gateway`.

Sengaja **tanpa** label: `db` (restart database lebih berbahaya daripada menunggu operator), `valkey` (Docker sudah me-restart bila mati; isinya hilang saat restart), `sentinel` (pemantau tidak boleh di-restart oleh yang dipantau), `healer`, serta one-shot `migrate`, `tools`, `volume-init`, dan `studio`/`meta` (admin). Container project lain di host yang sama (mis. stack lain di Docker Desktop) tidak pernah disentuh, walau berlabel `olt.autoheal`.

Label container baru berlaku setelah container dibuat ulang (`make up`). Container yang dibuat sebelum label ditambahkan tidak diawasi sampai itu.

## Aturan restart

Semua nilai lewat env (default aman di `docker/compose.yml`, contoh di `docker/.env.example`).

| Aturan | Env | Default |
|---|---|---|
| Interval cek | `HEALER_INTERVAL_SECONDS` | 10 |
| Container harus unhealthy **terus-menerus** minimal | `HEALER_UNHEALTHY_SECONDS` | 60 |
| Container harus sudah berjalan sejak start terakhir minimal | `HEALER_MIN_UPTIME_SECONDS` | 120 |
| Restart per layanan per jam, lalu **menyerah** | `HEALER_MAX_RESTARTS_PER_HOUR` | 3 |
| Jeda minimal antar restart di seluruh stack | `HEALER_GLOBAL_COOLDOWN_SECONDS` | 30 |
| Bagian layanan berlabel yang unhealthy bersamaan = gangguan sistemik | `HEALER_SYSTEMIC_FRACTION` | 0,5 |
| Aksi restart (false = mode laporan saja) | `HEALER_ENABLED` | true |

- **Unhealthy terus-menerus.** Waktu unhealthy dihitung dari pertama kali healer melihat status `unhealthy`. Sekali saja `healthy`/`starting`, hitungan mulai dari nol. Status `unhealthy` dari Docker sendiri baru muncul setelah `retries` healthcheck gagal berturut-turut, jadi total waktu sebelum restart ≈ `retries × interval` healthcheck + 60 dtk.
- **Uptime.** Mencegah restart beruntun: setelah restart, container baru boleh di-restart lagi 120 dtk kemudian.
- **Batas per jam.** Restart yang gagal juga dihitung. Bila layanan masih unhealthy setelah 3 restart dalam 1 jam, healer **menyerah** untuk layanan itu: satu event `give_up`, layanan masuk daftar `gave_up`, dan alert kritis `healer:gave_up:<layanan>` terbuka tanpa tunda. Healer mencoba lagi setelah restart tertua keluar dari jendela 1 jam. Daftar `gave_up` hilang lebih awal bila layanan sehat kembali atau container-nya hilang.
- **Jeda global.** Maksimal satu restart per 30 dtk untuk seluruh stack, dan satu restart per putaran. Container yang paling lama unhealthy didahulukan.
- **Penjaga database.** Bila container `db` project ini tidak berjalan atau tidak `healthy`, **tidak ada** yang di-restart (alasan `db_unhealthy`). Bila `pgbouncer` tidak sehat sementara `db` sehat, **hanya pgbouncer** yang boleh di-restart (alasan `pgbouncer_unhealthy`): layanan lain unhealthy karena pgbouncer, me-restart mereka tidak menolong. Aturan ini didahulukan dari aturan sistemik, supaya pgbouncer yang macet tetap bisa dipulihkan walau banyak layanan ikut unhealthy.
- **Gangguan sistemik.** Bila minimal 2 layanan dan ≥ 50% layanan berlabel unhealthy bersamaan, tidak ada yang di-restart (alasan `systemic`). Penyebabnya biasanya bersama (host kehabisan memori/CPU/disk, jaringan Docker), dan restart beruntun memperparahnya.
- Penahanan dicatat sebagai **satu** event `skip` saat mulai (atau alasannya berubah), bukan setiap putaran. Alert peringatan `healer:systemic` terbuka bila penahanan bertahan 120 dtk.
- **Mode laporan saja** (`HEALER_ENABLED=false`): healer tetap mengamati dan mencatat satu event `report` per episode unhealthy, tetapi tidak me-restart apa pun. Cocok untuk mengamati dulu sebelum mengaktifkan di server baru.

## File status

`/var/lib/olt-healer/state.json` (volume `healer-state`, mode 0644, dibaca sentinel read-only):

```json
{
  "version": "0.1.0", "project": "olt-social", "enabled": true,
  "started_at": "...", "checked_at": "...",
  "rules": {"unhealthy_seconds": 60, "min_uptime_seconds": 120, "max_restarts_per_hour": 3,
            "global_cooldown_seconds": 30, "systemic_fraction": 0.5, "interval_seconds": 10},
  "watched": 19,
  "unhealthy": [{"service": "rest", "container": "olt-social-rest-1", "since": "..."}],
  "skip": {"reason": "systemic", "since": "...", "services": ["auth", "rest"]},
  "gave_up": [{"service": "rest", "since": "...", "until": "...", "restarts": 3}],
  "events": [{"id": "...", "at": "...", "service": "rest", "container": "olt-social-rest-1",
              "action": "restart", "reason": "unhealthy", "result": "ok",
              "detail": "unhealthy 75s, uptime 900s: <keluaran healthcheck terakhir>"}],
  "error": "docker list: ... (hanya bila Docker tidak bisa dibaca)"
}
```

- `action`: `restart` (`result` `ok`/`failed`, `error` berisi pesan Docker), `report` (mode laporan saja), `give_up`, `skip`.
- `reason`: `unhealthy`, `restart_limit`, `db_unhealthy`, `pgbouncer_unhealthy`, `systemic`.
- Riwayat dibatasi 200 event dan 7 hari. File ini juga ingatan healer: setelah healer restart, hitungan restart per jam dan daftar `gave_up` tetap berlaku.
- Database menyimpan event (tanpa duplikat, berdasarkan `id`) selama 30 hari di `private.healer_events` dan status terakhir di `private.healer_state`.

Isi yang ditulis hanya nama service/container, waktu, dan keluaran healthcheck terakhir (dipotong 300 karakter). Healer tidak membaca env, secret, atau log container. Log ke stdout berupa JSON (slog), tanpa rahasia.

## Keamanan Docker socket

Akses ke `/var/run/docker.sock` **setara root di host**: siapa pun yang menguasai proses healer bisa membuat container privileged. Mitigasinya:

- **Satu-satunya container dengan socket.** `make test-security` (static-config) gagal bila socket di-mount ke service lain, bila healer punya `ports`/`expose`/`networks`, atau bila healer berjalan di profil cluster.
- **Tanpa jaringan sama sekali** (`network_mode: none`): healer tidak bisa dijangkau dari container lain dan tidak bisa menghubungi apa pun selain socket. Tidak ada listener HTTP; healthcheck hanya membaca umur `state.json` (`/healer healthcheck`).
- **Permukaan kecil.** Binary statis di image distroless (tanpa shell), user non-root `65532`, rootfs read-only, `cap_drop: [ALL]`, `no-new-privileges`, batas 0,1 CPU / 32 MB / 32 pids. Tidak ada dependency di luar standard library Go.
- **Hanya tiga endpoint.** Kode hanya memanggil list, inspect, dan restart. Restart hanya menerima id container heksadesimal penuh dari hasil list; nama/id lain ditolak sebelum request dibuat.
- **Cakupan dibatasi label.** Hanya container project sendiri dan berlabel `olt.autoheal=true`.
- Mount `:ro` pada socket **tidak** membatasi API Docker, jadi tidak dipakai (agar tidak memberi rasa aman palsu).

Akses ke socket memakai grup pemiliknya lewat `group_add`. Docker Desktop: socket milik `root:root` (`HEALER_DOCKER_GID=0`, default). Linux: socket milik grup `docker`; isi `HEALER_DOCKER_GID=$(getent group docker | cut -d: -f3)` di `docker/.env`. Bila salah, healer berjalan tetapi melaporkan `permission denied`, web CS menampilkan "Docker tidak terbaca", dan alert `healer:stale` terbuka.

## Mematikan

- **Mode laporan saja:** `HEALER_ENABLED=false` di `docker/.env`, lalu `make up` (atau `docker compose ... up -d --no-deps healer`).
- **Berhenti sementara** (mis. saat perawatan atau `make chaos-test`, yang sengaja membuat layanan unhealthy): `docker compose -f docker/compose.yml -f docker/compose.prod.yml stop healer`. `make up` berikutnya menyalakannya lagi. Selama mati, Kesehatan sistem menampilkan "Tidak berjalan" dan alert `healer:stale` terbuka setelah ±3 menit.
- **Satu layanan saja:** hapus label `olt.autoheal=true` dari service itu di compose lalu `make up`.
- `make restore-pitr` menghentikan semua container (termasuk healer) selama restore.

## Konfigurasi lain

| Env | Default | Keterangan |
|---|---|---|
| `HEALER_PROJECT` | kosong | Compose project; kosong = dari label container healer |
| `HEALER_DOCKER_SOCKET` | `/var/run/docker.sock` | Path socket di dalam container |
| `HEALER_STATE_FILE` | `/var/lib/olt-healer/state.json` | Harus absolut dan berakhiran `.json` |
| `LOG_LEVEL` | `info` | Dari `HEALER_LOG_LEVEL` di `docker/.env` |

Nilai di luar batas aman (interval 2–300 dtk, unhealthy/uptime 5–3600 dtk, restart 1–20/jam, jeda 0–3600 dtk, pecahan > 0 dan ≤ 1) ditolak saat start.

## Tes

```
make test-healer            # Windows: .\make.ps1 test-healer
```

CI (`.github/workflows/backend.yml`) menjalankan `gofmt`, `go vet`, `go test -race`, cek tanpa komentar, build image, dan Trivy.
