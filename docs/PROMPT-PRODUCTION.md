# Addendum: Production Readiness, Keamanan & Skalabilitas — OLT Social

> Addendum ini **melengkapi** `docs/PROMPT.md`. Simpan file ini sebagai `docs/PROMPT-PRODUCTION.md`.
> Jika ada yang bertentangan, **addendum ini yang berlaku**. Bagian bertanda `[...]` silakan disesuaikan.

---

## 0. Prinsip Utama

1. **Single-node dulu, multi-node siap.**
   - Sistem pertama kali dijalankan di **1 server**.
   - Arsitektur, kode, dan konfigurasinya harus bisa dipindah ke **banyak node** **tanpa mengubah kode aplikasi**. Yang berubah hanya profil deploy dan konfigurasi.
2. **Secure by default.** Konfigurasi bawaan harus aman. Apa pun yang longgar, misalnya Studio terbuka atau mode debug, hanya aktif di profil development secara eksplisit.
3. **Stateless.** Semua service aplikasi tidak boleh menyimpan state di memori proses atau disk lokal. State hanya boleh berada di:
   - Postgres
   - Valkey
   - Object storage
4. **Defense in depth.** Rate limit, validasi, dan otorisasi diterapkan di **beberapa lapisan**, tidak hanya di satu tempat.
5. **Semua di Docker**, versi image di-pin, dan **hanya lisensi permisif** (MIT, Apache 2.0, BSD, PostgreSQL). Tidak boleh AGPL atau GPL pada komponen yang melayani user.
6. **Observable & recoverable.** Setiap service punya health check, metrik, dan log terstruktur. Data punya backup yang **sudah diuji restore**.

---

## 1. Profil Deploy

Gunakan **image, nama service, dan nama environment variable yang sama** di ketiga profil:

| Profil | File | Kegunaan |
|---|---|---|
| `dev` | `docker/compose.dev.yml` | Laptop developer: Studio terbuka, seed data, log verbose, mock token OLT |
| `single` | `docker/compose.prod.yml` | **Produksi tahap awal**: 1 server, semua hardening aktif |
| `cluster` | `docker/stack.cluster.yml` | Produksi multi-node dengan Docker Swarm (lihat bagian 8 di PROMPT.md) |

Komponen yang **tetap ada walaupun single-node**, supaya jalur kode sama dengan cluster:
- **Traefik** sebagai edge / reverse proxy: TLS, rate limit, dan security headers.
- **Supavisor / PgBouncer** sebagai connection pooler. Aplikasi tidak pernah konek langsung ke Postgres.
- **Valkey** untuk rate limit, cache, dan lock terdistribusi. Di single-node cukup 1 instance.
- **Object storage**: di single-node memakai backend `file` (volume). Abstraksinya tetap S3-ready, jadi pindah ke SeaweedFS cukup lewat env.
- Postgres dengan **WAL archiving aktif**, sehingga kelak replica dan point-in-time recovery bisa ditambahkan tanpa migrasi data.

Perbedaan profil hanya diatur lewat konfigurasi:
- Realtime clustering: off di single, on di cluster.
- Jumlah replika.
- Storage backend.
- Target koneksi DB (primary saja, atau primary + replica).

Sediakan `docs/scaling.md` yang menjelaskan langkah **migrasi single → cluster** (termasuk pindah data storage dan menambah replica DB) dengan downtime minimal.

---

## 2. Stateless & Konsistensi

- **Tidak ada sesi di memori.** Sesi hanya JWT (stateless). Cache verifikasi token OLT disimpan di Valkey dengan TTL pendek.
- **Tidak ada file lokal.** Upload langsung ke Storage API. File sementara hanya di `tmpfs`, lalu dihapus.
- **Idempotensi.**
  - Setiap aksi tulis dari client (kirim pesan, buat post, buat komentar) membawa `client_id` (UUID dari client) dengan constraint unik. Retry atau double-tap tidak boleh menghasilkan data ganda.
  - Endpoint `auth-bridge` dan Edge Functions juga harus aman dipanggil ulang.
- **Job terjadwal** (pembersihan, agregasi trending, backup) dijalankan **sekali per cluster**, bukan per replika. Gunakan `pg_cron` atau lock Valkey / `pg_advisory_lock`.
- **Graceful shutdown.** Service menangani SIGTERM: berhenti menerima koneksi baru, menyelesaikan request berjalan, dan menutup WebSocket dengan kode yang membuat client reconnect.
- **Konfigurasi 12-factor.** Semua konfigurasi diambil dari environment / Docker secrets, dan aplikasi gagal start dengan pesan jelas kalau ada konfigurasi wajib yang kosong.
- **Waktu.** Semua timestamp disimpan dalam UTC (`timestamptz`) dan ditampilkan sesuai zona user (default WIB). Server memakai NTP.

---

## 3. Rate Limit Berlapis

Semua batas di bawah dibuat **dapat dikonfigurasi lewat env atau tabel**, bukan hardcode. Respons limit memakai **HTTP 429** dengan header `Retry-After`, dan client Flutter menampilkan pesan yang ramah.

| Lapisan | Mekanisme | Batas awal (dapat diubah) |
|---|---|---|
| **Edge (Traefik)** | Rate limit per IP + batas ukuran body + batas koneksi | `[100]` req/detik per IP (burst `[200]`), body maks `[10 MB]` untuk upload dan `[256 KB]` untuk API lain |
| **Edge (Traefik)** | Batas koneksi WebSocket per IP | `[20]` koneksi per IP |
| **auth-bridge** | Rate limit per IP dan per `olt_user_id` (Valkey, sliding window) | `/exchange`: `[10]`/menit per user, `[30]`/menit per IP |
| **Auth (GoTrue)** | Rate limit bawaan GoTrue, diaktifkan dan diatur | Sesuai kebutuhan, nonaktifkan endpoint signup publik |
| **Database (per user)** | Fungsi `check_rate_limit(user_id, action)` dipanggil di RPC dan trigger | Post `[5]`/menit & `[50]`/hari, komentar `[20]`/menit, pesan chat `[30]`/menit, like `[60]`/menit, report `[10]`/jam, follow `[30]`/jam, buat room `[10]`/jam |
| **Realtime** | Limit tenant: maks koneksi, channel per koneksi, event per detik, ukuran payload | Koneksi bersamaan `[sesuai kapasitas]`, `[10]` event/detik per client, payload maks `[64 KB]` |
| **Storage** | Batas ukuran dan jenis file per bucket, plus kuota per user | Gambar maks `[5 MB]`, `[50]` upload/hari per user |
| **Anti-spam konten** | Deteksi duplikat (post atau pesan identik dalam waktu singkat), batas link per post, filter kata | Konten sama `[3]`x dalam `[5]` menit ditolak, maks `[3]` link per post |

Ketentuan tambahan:
- User baru (umur akun < `[24 jam]`) mendapat batas lebih ketat.
- User yang terverifikasi atau tepercaya bisa mendapat batas lebih longgar lewat kolom `trust_level`.
- Semua pelanggaran rate limit dicatat ke log dan metrik, supaya serangan atau spam terdeteksi.

---

## 4. Keamanan

### 4.1 Jaringan & Server
- Hanya port **80/443** (Traefik) yang terbuka ke publik. Postgres, Valkey, Kong internal, Realtime internal, dan Studio **tidak pernah** di-expose ke publik.
- **Studio** dan dashboard monitoring hanya bisa diakses lewat **VPN (WireGuard)** atau SSH tunnel, plus basic auth / IP allowlist sebagai lapisan kedua. Di profil `single` dan `cluster`, Studio default **mati**.
- Docker network dipisah per lapisan:
  - `edge`: Traefik ↔ Kong
  - `app`: service aplikasi
  - `data`: DB, Valkey, storage

  Service hanya tergabung ke network yang benar-benar diperlukan. Di cluster, overlay network dienkripsi.
- Sertakan panduan dan script hardening host (Ubuntu LTS):
  - Firewall UFW dengan default deny.
  - SSH hanya dengan key: password login dan root login dimatikan, dan port bisa diganti.
  - `unattended-upgrades` untuk update keamanan otomatis.
  - Proteksi brute-force SSH dengan fail2ban atau CrowdSec (MIT).
  - Sinkronisasi waktu.
- Docker daemon tidak di-expose lewat TCP, dan log rotation diaktifkan.

### 4.2 TLS & HTTP
- HTTPS wajib dengan sertifikat otomatis Let's Encrypt via Traefik. Minimum **TLS 1.2** (utamakan 1.3), dan HTTP di-redirect ke HTTPS.
- Security headers wajib:
  - `Strict-Transport-Security`
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Referrer-Policy`
  - `Content-Security-Policy` untuk Studio dan halaman web
- **CORS** hanya untuk origin yang diizinkan. Aplikasi native tidak membutuhkan origin web.
- Timeout yang wajar di edge: request timeout, idle timeout WebSocket yang panjang tetapi terbatas, dan batas header.

### 4.3 Container Hardening
Terapkan di semua service jika didukung image:
- Image di-pin dengan **tag versi + digest** (`image@sha256:...`). Jangan `latest`.
- Jalankan sebagai **non-root user**.
- `read_only: true` + `tmpfs` untuk folder sementara.
- `cap_drop: [ALL]` (tambahkan kembali hanya kapabilitas yang perlu) dan `security_opt: [no-new-privileges:true]`.
- **Resource limits** (CPU dan memori) serta `pids_limit` untuk setiap service.
- Healthcheck dan `restart: unless-stopped`.
- Scan image dengan **Trivy** (Apache 2.0) di CI, dan **build gagal** kalau ditemukan kerentanan Critical atau High yang bisa diperbaiki.
- Buat **SBOM** untuk image buatan sendiri (`auth-bridge`) dan daftar lisensi semua dependensi.

### 4.4 Secrets
- Tidak ada secret di repo, image, atau log.
  - **Dev**: `.env`, yang di-gitignore.
  - **Produksi**: **Docker secrets**, dibaca dari file seperti `*_FILE`.
- Script `make gen-secrets` membuat semua secret acak yang kuat: password DB, JWT secret ≥ 64 karakter, anon key, service key, Erlang cookie, dan password Valkey.
- `service_role key` **hanya** dipakai service internal, tidak pernah ada di aplikasi Flutter.
- Dokumentasikan **prosedur rotasi**: JWT secret (dengan masa transisi), password DB, dan key lainnya.
- Siapkan pre-commit hook dengan gitleaks (MIT) untuk mencegah secret ikut ter-commit.

### 4.5 Database
- **RLS aktif di semua tabel** di schema publik. Tambahkan tes otomatis yang **gagal** kalau ada tabel baru tanpa RLS.
- Role terpisah:
  - `anon`: hampir tanpa akses.
  - `authenticated`
  - `service_role`
  - Role migrasi
  - Role read-only untuk monitoring

  Terapkan *least privilege*, dan cabut hak default `PUBLIC` yang tidak perlu.
- Fungsi `SECURITY DEFINER` wajib menetapkan `search_path` eksplisit, memvalidasi input, dan memeriksa `auth.uid()`.
- Atur `statement_timeout`, `idle_in_transaction_session_timeout`, dan batas koneksi per role, supaya query berat tidak menjatuhkan database.
- Semua query memakai parameter. Tidak ada SQL dinamis dari input user tanpa `format()` yang aman.
- Kolom sensitif (email, `olt_user_id`) tidak boleh terekspos lewat API publik. Gunakan view atau kolom yang dibatasi.
- Sediakan **audit log** untuk aksi penting: hapus konten, ban user, perubahan role, dan aksi moderator.

### 4.6 Auth & Token
- JWT Supabase dari `auth-bridge` berumur pendek (`[15 menit]`) dengan mekanisme refresh. Klaim minimal saja, tanpa data sensitif.
- Verifikasi token OLT ke WebSocket OLT dilakukan dengan:
  - Timeout
  - Circuit breaker, supaya kalau server OLT lambat, auth-bridge tidak ikut tumbang
  - Cache singkat di Valkey
- `auth-bridge` **tidak pernah menerima atau menyimpan password**, dan tidak mencatat token di log.
- Sediakan fitur **revoke** untuk mencabut sesi user tertentu (misalnya user di-ban atau akun OLT dinonaktifkan). Sesi yang dicabut langsung ditolak walaupun JWT belum expired, misalnya lewat tabel `revoked_sessions` atau versi token per user.
- Signup publik GoTrue **dimatikan**. Satu-satunya jalan masuk adalah lewat `auth-bridge`.

### 4.7 Validasi Konten & Upload
- Validasi di **client dan server** (database constraint dan fungsi):
  - Panjang teks
  - Karakter kontrol
  - Jumlah mention atau tag saham
  - URL
- Konten dirender sebagai **teks biasa** di Flutter. Tidak ada HTML atau markdown mentah yang dieksekusi. Link dibuka dengan konfirmasi, dan skema non-http(s) diblokir.
- Upload gambar dibatasi:
  - Hanya jenis tertentu (JPEG, PNG, WebP), dicek dari **isi file (magic bytes)**, bukan hanya ekstensi.
  - Ukuran maksimum.
  - Metadata **EXIF dihapus**, misalnya lokasi GPS.
  - Gambar disajikan lewat imgproxy dengan ukuran terbatas.
- Nama file di storage memakai UUID, bukan nama asli dari user.
- Bucket `attachments` untuk chat bersifat **privat** dan diakses dengan signed URL berumur pendek. Bucket `avatars` boleh publik.

### 4.8 Moderasi & Kepatuhan
- Fitur report, block, mute, hapus konten oleh moderator, ban sementara atau permanen, dan antrean moderasi untuk admin.
- Filter kata dan deteksi spam bisa diatur tanpa deploy ulang (tabel konfigurasi).
- Disclaimer "Konten ini opini pengguna, bukan rekomendasi investasi." di composer dan detail post.
- Siapkan dasar kepatuhan **UU Pelindungan Data Pribadi (UU PDP)**:
  - Kebijakan retensi data (misalnya pesan dan log disimpan `[X]` hari/bulan)
  - Fitur **hapus akun dan data user**
  - Ekspor data user
  - Log akses ke data pribadi
- Data disimpan di server `[lokasi: Indonesia]`.

### 4.9 Keamanan Client Flutter
- Token disimpan di secure storage (`flutter_secure_storage`, Windows Credential Manager / Android Keystore), bukan di shared preferences biasa.
- Hanya HTTPS / WSS. Pertimbangkan certificate pinning yang opsional dan bisa dikonfigurasi.
- Tidak ada `service_role key`, secret, atau URL internal di dalam build aplikasi.
- Log di build release tidak mencetak token atau isi pesan.

---

## 5. Keandalan

- Health check:
  - **Liveness**: proses hidup.
  - **Readiness**: dependensi seperti DB dan Valkey siap.

  Load balancer hanya mengirim trafik ke instance yang ready.
- **Retry dengan backoff + jitter** untuk panggilan antar service. Untuk dependensi eksternal (WebSocket OLT), gunakan timeout dan circuit breaker.
- **Degradasi yang anggun.**
  - Kalau Realtime terputus, client tetap bisa membaca feed dan mengirim pesan lewat REST, lalu sinkron saat tersambung lagi.
  - Kalau fitur sosial bermasalah, **fitur trading OLT tidak boleh terpengaruh sama sekali** (isolasi penuh, termasuk timeout di sisi Flutter).
- Batas koneksi dan antrean dihitung supaya beban puncak (misalnya saat pembukaan pasar 09:00 WIB) tidak menjatuhkan service.

---

## 6. Observabilitas

- **Log terstruktur (JSON)** dengan `request_id` / `trace_id` yang diteruskan antar service. Tidak boleh ada token, password, atau isi pesan pribadi di log.
- **Metrik (Prometheus)** dengan **dashboard Grafana** siap pakai, mencakup:
  - Request rate, error rate, latensi p50/p95/p99
  - Koneksi WebSocket aktif, pesan per detik
  - Koneksi DB, query lambat, replication lag
  - Hit rate limit
  - Penggunaan disk, CPU, memori
- **Log terpusat** dengan Loki (Apache 2.0, untuk log) dan Promtail / Grafana Alloy.
- **Alert** (Alertmanager ke email / Telegram `[pilih]`) untuk:
  - Service down
  - Error rate tinggi
  - Disk > 80%
  - Backup gagal
  - Sertifikat hampir expired
  - Lonjakan rate limit
  - Replication lag tinggi
- **Uptime monitoring** dari luar server, misalnya Uptime Kuma (MIT) di server terpisah.

---

## 7. Backup & Disaster Recovery

- **Postgres**: backup penuh harian dan WAL archiving kontinu untuk point-in-time recovery, memakai **pgBackRest** (MIT) atau WAL-G (Apache 2.0).
- **Object storage**: backup atau replikasi harian.
- Backup disimpan **di luar server utama** (server lain atau object storage terpisah) dan **dienkripsi**.
- Kebijakan retensi: harian `[7]`, mingguan `[4]`, bulanan `[6]`.
- Script `make restore` dan **uji restore otomatis** berkala ke lingkungan terpisah. Backup yang belum pernah diuji restore dianggap tidak ada.
- Target: **RPO** ≤ `[5 menit]`, **RTO** ≤ `[1 jam]`. Dokumentasikan langkah DR di `docs/operations.md`.

---

## 8. CI/CD & Rilis

- Pipeline CI (`[GitHub Actions / GitLab CI]`) berisi:
  - Lint dan format
  - `dart analyze`, unit test, dan widget test
  - Tes SQL / RLS (pgTAP)
  - Build image dan scan Trivy
  - Cek lisensi dependensi (gagal kalau ada AGPL/GPL)
  - Gitleaks
- Migrasi database:
  - Berurutan dan dilacak versinya.
  - Harus **backward-compatible** (pola *expand → migrate → contract*), supaya rolling update tanpa downtime aman.
  - Migrasi destruktif tidak boleh dijalankan otomatis.
- Deploy dengan **rolling update**:
  - Single-node: `docker compose up -d --no-deps` per service.
  - Cluster: Swarm `update_config` dengan `order: start-first`.
  - Sediakan **rollback** satu perintah.
- Lingkungan **staging** dengan konfigurasi yang sama seperti produksi.
- **Versioning** API dan RPC: perubahan yang tidak kompatibel memakai fungsi atau versi baru, supaya aplikasi Flutter versi lama yang masih terpasang di HP user tetap berfungsi.

---

## 9. Pengujian Produksi

- **Uji keamanan**:
  - Tes RLS untuk semua skenario akses silang antar user.
  - Tes bahwa endpoint internal tidak bisa diakses dari luar.
  - Scan OWASP ZAP (Apache 2.0) terhadap API.
  - Tes upload file berbahaya.
- **Uji rate limit**: setiap lapisan di bagian 3 benar-benar menolak dengan 429 saat batas terlewati, dan pulih setelah jendela waktu habis.
- **Uji beban di profil `single`** untuk mengetahui kapasitas 1 server, misalnya jumlah koneksi WebSocket dan pesan per detik maksimum sebelum latensi p95 > `[500 ms]`. Hasilnya menjadi acuan kapan harus naik ke cluster.
- **Uji chaos ringan**: restart DB, restart Valkey, matikan Realtime. Sistem harus pulih otomatis tanpa kehilangan data tersimpan.

---

## 10. Checklist Production Readiness

Buat `docs/production-checklist.md` dan **centang semuanya sebelum go-live**:

- [ ] Semua secret default sudah diganti dan disimpan sebagai Docker secrets
- [ ] Hanya port 80/443 terbuka, Studio dan dashboard hanya lewat VPN
- [ ] HTTPS aktif, security headers lolos pengecekan
- [ ] RLS aktif di semua tabel dan tes RLS lulus
- [ ] Signup publik dimatikan, hanya lewat auth-bridge
- [ ] Rate limit di semua lapisan aktif dan teruji
- [ ] Container berjalan non-root, read-only, dengan resource limits
- [ ] Scan Trivy bersih dari Critical/High yang bisa diperbaiki
- [ ] Cek lisensi lulus (tanpa AGPL/GPL di komponen layanan)
- [ ] Backup berjalan, tersimpan di luar server, dan **uji restore berhasil**
- [ ] Monitoring, dashboard, dan alert aktif dan sudah diuji
- [ ] Uji beban profil single selesai, kapasitas terdokumentasi
- [ ] Runbook insiden dan prosedur rollback terdokumentasi
- [ ] Fitur hapus akun dan ekspor data (UU PDP) berfungsi
- [ ] Gangguan fitur sosial terbukti tidak memengaruhi fitur trading OLT

---

## 11. Penyesuaian Tahapan

Gabungkan addendum ini ke tahapan di `docs/PROMPT.md`:
- **Tahap 1 (Infrastruktur)**:
  - Tiga profil (`dev`, `single`, `cluster`, dengan cluster boleh berupa kerangka dulu), Traefik, pooler, Valkey, Docker secrets, network terpisah, container hardening, `make gen-secrets`.
- **Tahap 2 (Database)**:
  - Rate limit di DB, `client_id` idempoten, role & privilege, timeout, audit log, dan tes "semua tabel ber-RLS".
- **Tahap 3 (auth-bridge)**:
  - Rate limit Valkey, circuit breaker, revoke sesi, dan log tanpa data sensitif.
- **Tahap 4–5 (Flutter)**:
  - Secure storage, penanganan 429, idempotensi `client_id`, degradasi anggun, dan isolasi dari fitur trading.
- **Tahap 6 (Hardening)**:
  - Seluruh bagian 4–10 addendum ini.
  - Kriteria selesai: **checklist bagian 10 tercentang di profil `single`**.
- **Tahap 7 (Multi-node)**:
  - Mengaktifkan profil `cluster` sesuai bagian 8 PROMPT.md.
  - Kriteria selesai: semua skenario uji multi-node lulus **tanpa perubahan kode aplikasi**.

Sebelum melanjutkan, **audit pekerjaan yang sudah selesai** terhadap addendum ini. Daftar apa saja yang perlu diubah beserta perkiraan effort-nya, lalu tunggu konfirmasi saya.