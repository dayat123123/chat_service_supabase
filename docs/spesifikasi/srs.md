# Software Requirements Specification (SRS) Sistem Rendezvous

Spesifikasi kebutuhan perangkat lunak untuk Rendezvous: lapisan sosial dan layanan nasabah yang menempel di aplikasi trading OLT, beserta Rendezvous Hub untuk staf. Disusun mengikuti struktur ISO/IEC/IEEE 29148 (dengan penamaan bagian bergaya IEEE 830).

## Informasi dokumen

| Atribut | Isi |
|---|---|
| Judul | Software Requirements Specification (SRS) Sistem Rendezvous |
| Versi | 1.0 |
| Tanggal | 23 November 2026 |
| Status | Draf |
| Pemilik dokumen | Tim server sosial Rendezvous |
| Dasar kode | Server `chat_service_supabase` (migrasi `0001`…`0188`, 165 file tes pgTAP), Rendezvous Hub `rendezvous_hub`, library Flutter `rendezvous_community` v1.49.2 |
| Dokumen pasangan | BRD: `docs/spesifikasi/brd.md` (kebutuhan bisnis `BR-<MODUL>`) |
| Kerahasiaan | Internal. Dokumen ini tidak memuat kunci, password, atau token |

### Riwayat revisi

| Versi | Tanggal | Penyusun | Perubahan |
|---|---|---|---|
| 1.0 | 23 November 2026 | Tim server sosial | Draf pertama, disusun dari kode dan dokumen ketiga repo per migrasi `0188` dan library v1.49.2 |

### Daftar isi

1. Pendahuluan
2. Deskripsi umum
3. Arsitektur dan komponen
4. Kebutuhan fungsional (AKUN, KOM, CHAT, CS, BANTU, NOTIF, MOD, PATUH, HUB, INT, OPS, TRADE)
5. Kebutuhan antarmuka eksternal
6. Kebutuhan data
7. Kebutuhan non-fungsional
8. Kebutuhan keamanan rinci
9. Konfigurasi dan parameter
10. Verifikasi dan kriteria penerimaan
11. Lampiran (matriks keterlacakan, katalog kode error, daftar RPC, catatan perbedaan dan butir perlu konfirmasi)

## 1. Pendahuluan

### 1.1 Tujuan

Dokumen ini menetapkan kebutuhan fungsional, antarmuka, data, non-fungsional, dan keamanan sistem Rendezvous sehingga:

- tim pengembang server, Hub, dan library punya satu acuan perilaku yang bisa diuji;
- tim QA bisa menurunkan kasus uji dan kriteria penerimaan per modul;
- tim aplikasi OLT, tim IT/infrastruktur, Kepatuhan, dan manajemen teknis memahami batas tanggung jawab sistem;
- setiap kebutuhan bisa dilacak ke kebutuhan bisnis di BRD (`BR-<MODUL>`).

Pembaca utama: developer, QA, tim IT/operasional, tim aplikasi OLT, Kepatuhan, dan pemilik produk.

### 1.2 Ruang lingkup

Nama produk: **Rendezvous** (sebelumnya disebut OLT Social di sebagian dokumen lama). Produk terdiri dari tiga bagian yang dirilis dari tiga repo:

| Bagian | Repo | Isi |
|---|---|---|
| Server sosial | `chat_service_supabase` | Supabase self-hosted di Docker, logika bisnis di Postgres 17 (fungsi SQL, RLS, trigger, pg_cron), layanan Go buatan sendiri, konfigurasi Kong/Traefik, edge function `cs-admin` |
| Rendezvous Hub | `rendezvous_hub` | Web staf React 19 + TypeScript, dibangun menjadi image `cs-console` |
| Library Flutter | `rendezvous_community` | Layar dan logika fitur sosial yang dipasang di aplikasi OLT (Windows, web, Android, iOS) |

**Dalam lingkup rilis ini:**

- Komunitas: Stream (feed), postingan, komentar, suka, ikuti, pencarian, trending, bookmark, akun resmi, indeks.
- Chat: DM, permintaan pesan, grup, room saham, dengan realtime.
- Layanan nasabah: chat CS bermodel tiket yang diklaim agen, pengaduan tamu tanpa login dan tanpa OTP, Pusat Bantuan (FAQ).
- Notifikasi in-app dan push (FCM), notifikasi transaksi dari OLT, Banner & Popup, kampanye notifikasi.
- Moderasi dan keamanan konten, kepatuhan (kasus, audit, dokumen hukum, bukti).
- Rendezvous Hub untuk semua peran staf, dan integrasi dengan OLT (token sosial, `/integration/v1`, gateway Akun Nasabah).
- Operasional: pemantauan, alert, pemulihan otomatis, backup, pembersihan file, retensi.

**Di luar lingkup:**

- Data bisnis trading (harga, grafik, order book, order, mutasi dana, portofolio). Semua milik OLT dan tidak disimpan server.
- Login nasabah ke sistem OLT. Server tidak pernah memanggil OLT untuk login.
- Telepon CS ke nasabah (dibatalkan).
- **Berbagi Trade** (dijeda): kode ada, tetapi flag Hub `SHOW_TRADE_SHARE=false` dan `trade-relay` tidak dijalankan. Dicatat ringkas di 4.12 sebagai kemampuan masa depan.
- Klien non-Flutter. WebView ditolak; SDK headless (TypeScript dan Kotlin Multiplatform) direncanakan tetapi belum dimulai.
- Profil deploy `cluster` (masih kerangka) dan database cloud terkelola (tidak didukung).

### 1.3 Definisi, akronim, dan singkatan

| Istilah | Arti |
|---|---|
| OLT | Aplikasi dan sistem online trading milik broker; pemilik data bisnis trading |
| Nasabah | Pengguna aplikasi OLT yang memakai fitur Rendezvous |
| Tamu | Nasabah yang belum atau tidak bisa login, memakai pengaduan tamu (`profiles.is_guest`, 0145) |
| Staf | Pengguna Hub: CS, Super Admin, Kepatuhan, Komunitas, Fitur & Banner, Pusat Bantuan |
| Token sosial | JWT bertanda tangan OLT (EdDSA atau ES256) yang membuktikan nasabah sudah login di OLT |
| Sesi sosial | JWT 15 menit yang diterbitkan auth-bridge setelah token sosial terverifikasi |
| JWKS | JSON Web Key Set: daftar kunci publik OLT untuk verifikasi token sosial |
| RLS | Row Level Security Postgres |
| RPC | Fungsi SQL yang dipanggil lewat `/rest/v1/rpc/<nama>` (PostgREST) |
| Security definer | Fungsi SQL yang berjalan dengan hak pemiliknya; dipakai untuk aksi yang diperiksa ketat |
| pg_cron | Penjadwal job di dalam Postgres |
| pgTAP | Kerangka uji unit untuk Postgres |
| Migrasi | File SQL bernomor di `supabase/migrations`, dipasang berurutan oleh layanan `migrate`, dicatat dengan checksum di `olt_internal.schema_migrations` |
| Tiket | Unit layanan chat CS (`cs.tickets`), nomor `CS-YYYYMMDD-NNNN` |
| Klaim | Tindakan CS mengambil tiket `open` menjadi miliknya |
| Empat mata | Perubahan yang harus disetujui staf kedua sebelum berlaku |
| Kill switch | Saklar di Hub untuk mematikan fitur sosial seketika (chat CS tetap jalan) |
| Akun baru | Akun `trust_level` 0/1 yang umurnya kurang dari `safety.new_account_days` hari (0187) |
| `$KODE` | Cashtag kode saham atau indeks, mis. `$BBCA`, `$COMPOSITE` |
| CSAM | Materi eksploitasi seksual anak; ditangani dengan toleransi nol |
| NSFW | Konten tidak pantas; dinilai layanan `classifier` |
| WAL | Write-Ahead Log Postgres, dialirkan terus ke backup |
| RPO / RTO | Recovery Point Objective / Recovery Time Objective |
| FCM | Firebase Cloud Messaging |
| aal2 | Authenticator Assurance Level 2 (sesi GoTrue yang sudah lolos TOTP) |
| TOTP | Time-based One-Time Password (2FA) |
| WIB | Waktu Indonesia Barat (UTC+7), dasar perhitungan hari kerja dan laporan |
| VU | Virtual user pada uji beban |
| csAdmin | Layanan back-office OLT untuk mengelola Online ID nasabah, dipanggil lewat nasabah-gateway |
| notifEngine | Sistem OLT pengirim notifikasi transaksi ke `/integration/v1` |
| Hub | Rendezvous Hub, web staf |
| Library | Paket Flutter `rendezvous_community` |
| FR / NFR | Functional / Non-Functional Requirement |
| BR | Business Requirement (BRD) |
| Perlu konfirmasi | Penanda butir yang belum bisa diverifikasi dari kode atau dokumen |

### 1.4 Referensi

Semua path relatif terhadap repo server `chat_service_supabase` kecuali disebut lain.

| Dokumen | Isi |
|---|---|
| `docs/spesifikasi/brd.md` | Business Requirements Document (pasangan dokumen ini) |
| `docs/panduan/pengetahuan-sistem.md` | Gambaran sistem, node, teknologi dan versi |
| `docs/panduan/daftar-fitur.md` | Daftar fitur aplikasi, Hub, server, integrasi |
| `docs/panduan/produksi.md` | Arsitektur produksi, batas, rate limit, batas Realtime, perilaku saat gangguan |
| `docs/panduan/skalabilitas.md`, `docs/panduan/spesifikasi-server.md` | Replika, profil deploy, ukuran server |
| `docs/panduan/hub-untuk-staf.md` | Panduan pemakaian Hub per peran |
| `docs/panduan/catatan-rilis.md`, `docs/panduan/pembaruan-sistem.md` | Catatan per rilis, update dan rollback |
| `docs/panduan/operasional.md`, `docs/panduan/gangguan.md`, `docs/panduan/backup.md`, `docs/panduan/instalasi-server.md` | Operasional harian, penanganan gangguan, backup, instalasi |
| `docs/panduan/checklist-go-live.md` | Checklist sebelum go-live |
| `docs/olt-integration.md` | Kontrak token sosial OLT |
| `docs/content-safety.md` | Keamanan konten, DM, banding, integritas pasar, empat mata kebijakan |
| `docs/cs-chat/README.md`, `docs/cs-chat/kepatuhan.md` | Chat CS dan menu Kepatuhan |
| `docs/social/README.md`, `docs/community/README.md` | Fitur sosial dan menu Komunitas |
| `docs/nasabah/README.md`, `docs/integration/README.md`, `docs/push/README.md` | Gateway Akun Nasabah, API integrasi OLT, push |
| `docs/system-health/README.md`, `docs/backup/README.md`, `docs/evidence/README.md` | Kesehatan sistem, backup, karantina bukti |
| `docs/testing/README.md`, `docs/testing/report-2026-11-03.md` | Strategi uji dan hasil uji beban, keamanan, chaos |
| `docs/berbagi-trade/` | Rencana dan operasional Berbagi Trade (dijeda) |
| `docs/api/openapi.yaml`, `docs/api/asyncapi.yaml` | Kontrak HTTP dan Realtime |
| `services/*/README.md` | Dokumen tiap layanan Go |
| `supabase/migrations/`, `supabase/tests/` | Sumber kebenaran aturan bisnis dan tesnya |
| `rendezvous_hub` (`src/features/*`) | Kode Hub |
| `rendezvous_community` (`lib/rendezvous_community.dart`, `doc/*.md`) | API publik dan dokumen library |
| ISO/IEC/IEEE 29148:2018, IEEE 830-1998 | Acuan struktur SRS |

### 1.5 Konvensi dan ikhtisar dokumen

- **Bagian 2** memberi gambaran produk, pengguna, lingkungan, batasan, dan asumsi. **Bagian 3** menjelaskan setiap node dan alur utama. **Bagian 4** memuat kebutuhan fungsional per modul. **Bagian 5–9** memuat antarmuka, data, kebutuhan non-fungsional, keamanan rinci, dan parameter. **Bagian 10** memuat strategi verifikasi dan kriteria penerimaan. **Bagian 11** memuat lampiran.
- **Penomoran kebutuhan:** `FR-<MODUL>-<nn>` dan `NFR-<KATEGORI>-<nn>`. Kode modul: AKUN, KOM, CHAT, CS, BANTU, NOTIF, MOD, PATUH, HUB, INT, OPS, TRADE, sama dengan BRD. Setiap FR memuat baris **Lacak** ke modul BR (`BR-<MODUL>`).
- **Kata kerja:** "Sistem harus", "Hub harus", "Library harus" menyatakan kebutuhan wajib.
- **Sumber:** angka di dalam kurung seperti "(0187)" menunjuk migrasi `supabase/migrations/0187_*.sql`; path file menunjuk sumber lain. Bila dokumen dan kode berbeda, dokumen ini mengikuti kode, dan perbedaannya dicatat di 11.4.
- **Kode error** ditulis `<HTTP> <message>`, mis. `409 ticket_closed`. Error aplikasi di database berasal dari `private.api_error(status, code, detail)` yang me-raise SQLSTATE `PT<status>`; PostgREST memetakannya ke status HTTP, `message` berisi kode stabil, `details` berisi teks bahasa Indonesia.
- Identifier teknis ditulis apa adanya. Teks produk dan dokumen berbahasa Indonesia; log dan pesan error internal berbahasa Inggris.

## 2. Deskripsi umum

### 2.1 Perspektif produk

Rendezvous bukan aplikasi mandiri. Ia menambah fitur sosial dan layanan nasabah ke dalam aplikasi OLT lewat library Flutter, dan menyediakan web Hub untuk staf. Server berjalan self-hosted di Docker; satu-satunya hubungan masuk dari OLT adalah token sosial yang dibawa aplikasi, panggilan notifEngine ke `/integration/v1`, dan (keluar) panggilan nasabah-gateway ke csAdmin untuk menu Akun Nasabah.

```
Nasabah: Aplikasi OLT + library rendezvous_community
         (Flutter: Windows, web, Android, iOS)
    |  HTTPS + WebSocket ke domain API publik (PROXY_DOMAIN)
    |  /rest/v1  /realtime/v1  /storage/v1  /media/v1  /bridge/v1
    v
SERVER SOSIAL (Docker, self-hosted)  <-- HTTPS domain CS (hanya IP kantor) -- Staf: Rendezvous Hub
    |
    |- Pintu      traefik -> kong
    |- Layanan    rest (PostgREST) . realtime . storage . imgproxy . auth (GoTrue, staf)
    |             auth-bridge . media . classifier . clamav . integration
    |             nasabah-gateway . functions (cs-admin) . cs-console (Hub)
    |- Data       pgbouncer -> db (Postgres 17: data + aturan bisnis) . valkey
    |- Latar      notifier . sentinel . healer . backup . janitor . link-preview
    |
    |--> Google FCM            (push ke HP)
    |--> S3 / folder lokal     (backup terenkripsi restic)
    |--> Telegram / email      (alert)
    |--> database.clamav.net   (signature antivirus)

Sistem OLT (milik tim OLT):
  - menerbitkan token sosial bertanda tangan (EdDSA/ES256), dibawa aplikasi ke /bridge/v1
  - notifEngine memanggil /integration/v1 dengan API key (notifikasi transaksi, bot resmi)
  - csAdmin dipanggil nasabah-gateway (hanya /online/*) untuk menu Akun Nasabah di Hub
```

Prinsip desain yang mengikat seluruh kebutuhan:

1. **Data bisnis trading milik OLT.** Server hanya menyimpan kode saham sebagai label; nama, harga, dan layar saham diambil dari OLT lewat callback library (`stockSearch`, `stockInfo`, `onStockTap`).
2. **Logika bisnis di database.** Hak akses, batas kecepatan, moderasi, dan alur tiket ditegakkan oleh fungsi SQL, trigger, dan RLS sehingga berlaku sama untuk semua klien.
3. **Self-hosted.** Tidak ada layanan cloud wajib. Lalu lintas keluar hanya FCM, alert, backup S3, signature ClamAV, Let's Encrypt, dan (untuk Hub) csAdmin OLT.
4. **Pengaturan lewat Hub, bukan file.** Kredensial operasional dan kebijakan diatur dari Hub dan tercatat di Jejak Audit.

### 2.2 Fungsi produk

| Modul | Fungsi utama |
|---|---|
| AKUN | Tukar token sosial menjadi sesi 15 menit, profil sosial, persetujuan dokumen hukum, privasi, blokir, ekspor data, hapus akun dengan jeda bergabung lagi, cache offline terenkripsi, konfigurasi klien dan update paksa |
| KOM | Stream (Terbaru/Mengikuti/saham/hashtag/indeks, tab filter), postingan dengan gambar, polling, sentimen, komentar berantai dengan kontrol komentar, suka, ikuti, mention, pencarian, trending, bookmark, link preview, akun resmi, indeks, pantau saham, analitik |
| CHAT | DM dengan permintaan pesan, grup ala WhatsApp, room saham, centang terkirim/dibaca, mengetik, reaksi, balas, edit/hapus, info pesan, bagikan postingan, kartu saham, hapus chat/grup, pengisian celah pesan |
| CS | Tiket chat CS: pilih topik, antrean, klaim atomik, lepas/transfer/reassign, penugasan otomatis, lampiran dengan antivirus, catatan internal, label, quick reply, rating yang menutup tiket, tutup otomatis, pengaduan dengan tenggat, lapor CS palsu, pengaduan tamu, dashboard, laporan, pengaturan layanan, status gangguan |
| BANTU | Artikel FAQ dua bahasa dengan gambar dan lampiran, kategori, pencarian, umpan balik "membantu", saran artikel sebelum chat CS, topik chat CS |
| NOTIF | Kotak notifikasi, preferensi dan jam tenang, ringkasan watchlist, push FCM, kampanye notifikasi, Banner & Popup dengan notifikasi info |
| MOD | Rantai pemeriksaan konten, kata terlarang, kategori tautan/kontak/promosi, akun baru, NSFW, laporan, antrean moderasi, sanksi bertingkat, banding, toleransi nol, anti-manipulasi saham, slow mode dan moderator room |
| PATUH | Ringkasan dan register kasus, tinjauan, perpanjangan tenggat, transkrip bersidik, jejak audit, kebijakan tenggat dan retensi, dokumen hukum empat mata, karantina bukti dan legal hold, akses tiket hanya-baca 12 jam, versi dan empat mata kebijakan konten |
| HUB | Login staf dengan 2FA dan kunci akun, sesi per tab, akun dan peran staf, izin, aturan persetujuan, Fitur & versi, Tab Stream, Indeks, Akun resmi, Postingan resmi, analitik, command palette, ID/EN, mode gelap |
| INT | Kontrak token sosial, status integrasi aplikasi, API `/integration/v1` (notifikasi transaksi, siaran, bot), API key, gateway Akun Nasabah ke csAdmin |
| OPS | Profil deploy, migrasi, Kesehatan sistem dan alert, Peta layanan, healer, backup dan restore, janitor, retensi, jadwal pg_cron, log |
| TRADE | Berbagi Trade (dijeda, di luar lingkup rilis ini) |

### 2.3 Kelas dan karakteristik pengguna

**Pengguna aplikasi (library):**

| Kelas | Karakteristik | Akses |
|---|---|---|
| Nasabah | Login lewat OLT; identitas dari klaim token sosial (`sub`, `preferred_username`, `name`, `email` opsional, `accounts`) | Semua fitur sosial sesuai RLS; chat CS |
| Nasabah akun baru | `trust_level` 0/1 dan umur < `safety.new_account_days` (bawaan 3 hari, 0187) | Tanpa gambar dan tautan non-tepercaya, DM ke non-mutual lewat permintaan, rate limit × `rate_limit.new_account_factor` (0,5) |
| Nasabah disanksi | Mute atau ban (`private.user_sanctions`) | Ban: hanya banding dan melihat sanksi; lihat catatan CS di 11.4 |
| Tamu | Tidak bisa login; membuka pengaduan dari halaman login (`openCommunityGuestSupport`), tanpa OTP | Hanya RPC `cs_api.guest_*` |
| Akun resmi | Akun OLT bertanda resmi (`cs.official_accounts`), dikelola dari Hub | Bisa diikuti, tidak bisa di-DM pengguna biasa (0144) |
| Moderator room | Nasabah tepercaya yang ditunjuk staf di room saham (0093) | Sembunyikan pesan, bisu sementara, eskalasi di room yang ditugaskan |

**Peran staf (Hub)**, dari constraint `agents_roles_check` (0126). Satu akun boleh punya beberapa peran; menu adalah gabungan peran dan izin.

| Kode peran | Nama di Hub | Ringkasan hak |
|---|---|---|
| `cs_agent` | CS | Layanan Nasabah: ambil, balas, tunggu nasabah, lepas, transfer, selesaikan tiket; Kinerja saya; satu-satunya peran yang boleh diberi izin Akun Nasabah (0047) |
| `cs_super_admin` | Super Admin | Memantau tiket tanpa membalas, Dashboard, Laporan, Pengaturan (Akun CS, Layanan CS, Persetujuan, Integrasi, Sistem), Pusat Bantuan, Banner & Popup, Fitur & versi, Tab Stream, Analitik; wajib 2FA (0186) |
| `compliance` | Kepatuhan | Menu Kepatuhan: Ringkasan, Kasus, Kebijakan konten, Tenggat & retensi, Dokumen hukum, Jejak Audit, Bukti; tidak menangani tiket |
| `community` | Komunitas | Disimpan otomatis bila akun hanya diberi izin Komunitas; tab Komunitas sesuai izin |
| `product` | Fitur & Banner | Fitur & versi, Tab Stream, Banner & Popup (0121) |
| `cs_content` | Pusat Bantuan | Topik chat CS dan artikel FAQ (0126) |

Izin tambahan: **izin Komunitas** (`community.post`, `community.publish`, `community.moderate`, `community.sanction`, `community.accounts`, 0057) dan **izin Akun Nasabah** (`online_user.view`, `online_user.manage`, `online_user.demo`, `online_user.approve`, `online_user.approve_own`, `online_user.status`, `opening_account.send`, 0044–0047). Izin Berbagi Trade ada di database tetapi disembunyikan (0160). Rinciannya di 4.9.

**Pihak sistem:** aplikasi dan backend OLT (penerbit token, pemasang library), notifEngine OLT (klien `/integration/v1`), csAdmin OLT (tujuan nasabah-gateway), Google FCM, penyedia S3, Telegram/SMTP.

Karakteristik pengguna yang memengaruhi desain:

- Nasabah memakai aplikasi di HP dan Windows, sering dari balik NAT operator atau Wi-Fi kantor, dengan lonjakan saat bursa buka (09:00 WIB). Batas per IP dibuat longgar (±1.000 nasabah per IP) dan perlindungan utama per akun.
- Staf bekerja dari LAN kantor, kadang membuka beberapa akun di tab berbeda pada satu browser.
- Kepatuhan membutuhkan jejak yang tidak bisa diubah dan bukti bersidik.

### 2.4 Lingkungan operasi

| Aspek | Ketentuan |
|---|---|
| Server produksi | Linux, disarankan Ubuntu LTS; Docker Engine + Compose plugin; produksi awal disarankan 16 vCPU, 32 GB RAM, 500 GB NVMe (minimum 8 vCPU / 16 GB / 200 GB NVMe) (`docs/panduan/spesifikasi-server.md`) |
| Jaringan | IP publik dengan 80/443 untuk API nasabah, 22 hanya dari IP admin; LAN/VPN kantor untuk Hub (`VPN_SOURCE_RANGES`); HTTPS keluar untuk Let's Encrypt, FCM, ClamAV, S3, Telegram/SMTP, csAdmin |
| Profil deploy | `dev` (HTTP `:8000`, semua path terbuka), `single` (produksi satu server, siap pakai), `cluster` (Docker Swarm, kerangka) |
| Aplikasi nasabah | Aplikasi OLT dengan library `rendezvous_community` (Flutter ≥ 3.47, Dart ≥ 3.12 menurut `pubspec.yaml`; lihat 11.4), di Windows, web, Android, iOS |
| Hub | Browser desktop modern (diuji di Chromium lewat Playwright), dari IP yang diizinkan |
| Pengembangan | Windows didukung untuk dev lokal (Docker Desktop), dengan catatan port yang dicadangkan Hyper-V |
| GPU | Tidak diperlukan (classifier berjalan di CPU) |

### 2.5 Batasan desain dan implementasi

1. **Platform data:** image Supabase Postgres 17.11 dengan role, ekstensi (pg_cron, pgsodium/Vault, pg_trgm, pgTAP), dan Vault bawaan. Karena itu database cloud terkelola tidak didukung.
2. **Logika di database:** aturan bisnis wajib ditulis sebagai fungsi SQL, trigger, dan RLS; layanan lain hanya meneruskan dan menjaga batas.
3. **Migrasi tidak pernah diubah** setelah terpasang; perubahan selalu file baru bernomor berikutnya. File `.sql` wajib berakhiran LF karena checksum dicek `migrate`.
4. **Tanpa status 503 untuk penolakan aplikasi:** PostgREST v14 menganggap setiap 503 sebagai database putus. Fitur mati dijawab `403`, konflik `409`, rate limit `429` (0109, tes `089_kill_switch_status_test.sql`).
5. **Realtime:** pesan chat dikirim lewat Broadcast dari database ke topik privat, sekali per pesan (0098); `postgres_changes` tidak dipakai untuk pesan; Realtime satu replika di luar profil cluster.
6. **Rahasia** hanya dari Docker secrets dan Vault; `docker/.env` berisi konfigurasi, bukan kunci. Kunci publik OLT (JWKS) hanya bisa diganti di server, tidak dari Hub.
7. **Pengaturan operasional** dikelola dari Hub oleh Super Admin dan diaudit. Lokasi penyimpanannya: `cs.cs_settings` (pengaturan yang diubah lewat `admin_set_setting`), `private.settings` (parameter teknis, sebagian lewat RPC Kepatuhan, sisanya lewat migrasi/SQL), tabel `private.*` khusus plus Vault untuk kredensial (kunci Firebase, backup, kanal alert, API key integrasi yang disimpan sebagai hash + prefiks) (lihat bagian 9).
8. **Bahasa:** teks produk dan dokumentasi bahasa Indonesia (Hub dan library juga Inggris); log dan error internal bahasa Inggris; kode baru tanpa komentar kecuali yang penting.
9. **Kontainer dikunci:** read-only, non-root, `cap_drop: ALL`, `no-new-privileges`, batas CPU/memori/pids; image pihak ketiga dipin dengan tag dan digest.
10. **Layout milik OLT:** widget library tidak memakai `Scaffold`; tema mengikuti aplikasi OLT, dan bagian tampilan bisa diganti lewat builder/slot.
11. **Lisensi:** tanpa dependensi GPL/AGPL (`make license-audit`).

### 2.6 Asumsi dan ketergantungan

| No | Asumsi atau ketergantungan | Dampak bila tidak terpenuhi |
|---|---|---|
| A1 | OLT menerbitkan token sosial sesuai kontrak `docs/olt-integration.md` (maks 15 menit, ≤ 16 KB, `sub` stabil) dan menyerahkan JWKS produksi | Login sosial tidak mungkin; auth-bridge menolak start dengan kunci `dev-` di produksi |
| A2 | OLT berhenti menerbitkan token untuk akun yang disuspend atau logout | Akses sosial akun itu baru berakhir setelah token terakhir habis (≤ 15 menit) |
| A3 | Aplikasi OLT memasang library dengan tag rilis dan menaikkan versi minimum di Hub setelah rilis | Fitur baru tidak tampil; klien lama bisa dipaksa update lewat versi minimum |
| A4 | notifEngine OLT mengirim notifikasi transaksi dalam batch 100–500 per request dengan API key dari Hub | Rate limit per key (bawaan 3.000/menit, 0101) bisa tercapai |
| A5 | csAdmin OLT menerima token integrasi Ed25519 dan hanya membuka `/online/*` | Menu Akun Nasabah tidak aktif |
| A6 | Super Admin mengunggah kunci Firebase, mengisi tujuan backup dan kanal alert segera setelah deploy | Push tidak terkirim (notifikasi tetap masuk kotak in-app), alert "Backup belum diatur" |
| A7 | Jam server tersinkron NTP | TOTP (30 detik) dan validasi token (toleransi 30 detik) gagal |
| A8 | Kepatuhan menetapkan kebijakan (tenggat pengaduan, retensi, dokumen hukum, kanal pelaporan CSAM) sebelum go-live | Nilai bawaan dipakai; kanal pelaporan CSAM masih perlu konfirmasi |
| A9 | Server punya akses keluar ke `database.clamav.net` (atau mirror privat) | Upload dokumen/video CS ditolak `scanner_unavailable` (fail closed) |
| A10 | Kalender libur dan libur bursa diperiksa Kepatuhan (`cs.holidays.verified`) | Jam layanan dan tenggat hari kerja salah hitung |

## 3. Arsitektur dan komponen

### 3.1 Segmen jaringan

| Segmen | Isi | Akses internet |
|---|---|---|
| `edge` | Traefik ↔ Kong, `cs-console`, `nasabah-gateway` | Tidak (kecuali node yang juga di `egress`) |
| `app` | Layanan API dan layanan Go | Tidak |
| `data` | `db`, `pgbouncer`, `valkey` dan layanan yang butuh database langsung | Tidak |
| `egress` | Hanya node yang perlu keluar: `traefik`, `functions`, `notifier`, `sentinel`, `link-preview`, `backup`, `clamav`, `nasabah-gateway`, `trade-relay` (dijeda) | Ya |

`healer` tidak tersambung ke network mana pun (hanya Docker socket). Segmen diambil dari `docker/compose.yml`.

### 3.2 Node, tanggung jawab, teknologi, replika

Replika adalah nilai bawaan profil `dev`/`single` (`*_REPLICAS` di `docker/.env.example`).

| Node | Tanggung jawab | Teknologi / versi | Replika | Segmen |
|---|---|---|---|---|
| `traefik` | Satu-satunya penerima koneksi internet: TLS Let's Encrypt (TLS ≥ 1.2), redirect HTTP→HTTPS, rate limit per IP, batas body dan WebSocket, hanya meloloskan path API resmi, `ipAllowList` domain CS, header `X-Olt-Edge` | Traefik 3.7.16 | 1 | edge, egress |
| `kong` | Gerbang API: membagi ke REST, Realtime, Storage, functions, media, auth-bridge, integration; memeriksa `apikey` | Kong 3.9.4 | 1 | edge, app |
| `rest` | API data untuk aplikasi dan Hub; semua lewat RPC dan RLS | PostgREST 14.18 | 2 | app, data |
| `realtime` | Broadcast pesan, mengetik, presence, event dari trigger database | Supabase Realtime 2.148.6 | 1 | app, data |
| `auth` | Akun dan sesi staf Hub, 2FA TOTP, hook kunci akun; nasabah tidak login di sini | GoTrue 2.197.0 | 1 | app, data |
| `storage` | Bucket file dengan RLS (avatar, gambar postingan, lampiran chat dan CS, FAQ, banner, bukti) | Supabase Storage 1.84.32 | 1 | app, data |
| `imgproxy` | Mengecilkan dan memotong gambar | imgproxy 3.31.4 | 2 | app |
| `functions` | Edge function `cs-admin`: membuat akun staf, reset password staf (hanya di domain CS) | Supabase Edge Runtime 1.77.9 (Deno) | 1 | app, egress |
| `meta`, `studio` | Dashboard database untuk tim teknis; di produksi hanya lewat `127.0.0.1` dan mati secara default | postgres-meta 0.100.0, Studio | 1 | app, data / app |
| `auth-bridge` | Verifikasi token sosial dengan JWKS OLT, upsert profil, terbitkan sesi sosial 15 menit, rate limit per IP dan per user (Valkey), tahan login ulang selama jeda bergabung lagi | Go, olt-social/auth-bridge 0.7.0 | 2 | app, data |
| `media` | Pintu unggah nasabah: cek isi file, buang EXIF/GPS/XMP, minta classifier dan clamav, simpan ke Storage | Go, media 0.3.0 | 2 | app |
| `classifier` | Penilai NSFW lokal (MobileNetV4, CPU); fail closed | Go, classifier 0.1.1 | 2 | app |
| `clamav` | Antivirus dokumen dan video chat CS (clamd INSTREAM, freshclam 4×/hari) | ClamAV 1.5.4 | 1 | app, egress |
| `integration` | API `/integration/v1` untuk OLT: notifikasi transaksi per `cust_id`, siaran, bot resmi; API key + CIDR + rate limit | Go, integration 0.2.0 | 2 | app |
| `nasabah-gateway` | Jembatan menu Akun Nasabah ke csAdmin OLT (`/online/*`) dengan token Ed25519; cek izin dan aal2 | Go, nasabah-gateway 0.1.0 | 1 | edge, app, egress |
| `notifier` | Ambil antrean push dari database, kirim ke FCM; kunci Firebase dari Vault tanpa restart | Go, notifier 0.2.0 | 1 | app, egress |
| `link-preview` | Ambil judul/gambar pratinjau tautan dengan proteksi SSRF; gambar lewat classifier | Go, link-preview 0.2.0 | 1 | app, egress |
| `janitor` | Proses `private.storage_cleanup_queue`, salin bukti ke bucket `evidence` | Go, janitor 0.2.0 | 1 | app |
| `sentinel` | Pantau layanan, disk, database, antrean, metrik tiap 30 detik; kirim `health_report`; alert Telegram/email; isi Peta layanan | Go, sentinel 0.5.0 | 1 | app, data, egress |
| `healer` | Restart container berlabel `olt.autoheal=true` yang unhealthy ≥ 60 dtk, maks 3×/jam per layanan, 1 restart per 30 dtk | Go, healer 0.2.0 | 1 | tanpa network |
| `backup` | WAL terus-menerus (`pg_receivewal`), backup penuh (`pg_basebackup`) dan file storage, enkripsi restic ke S3 atau folder lokal, uji restore mingguan | Go, backup 0.2.0 | 1 | data, app, egress |
| `trade-relay` | Relay order/trade untuk Berbagi Trade. **Dijeda, tidak dijalankan** | Go, trade-relay 0.1.0 | 0 | app, egress |
| `db` | PostgreSQL: semua data dan aturan bisnis, pg_cron (±29 job aktif), Vault | Supabase Postgres 17.11.0.008 | 1 | data |
| `pgbouncer` | Pool koneksi mode `session`, pool bawaan 24, pantau IP `db` tiap 2 dtk | PgBouncer 1.24.0 | 1 | data |
| `valkey` | Penghitung rate limit auth-bridge; isinya boleh hilang | Valkey 9.0.7 | 1 | data |
| `cs-console` | Web Hub (build `rendezvous_hub`, nginx dengan CSP) | React 19, image cs-console 0.1.1 | 1 | edge |
| `migrate` | Pasang migrasi baru setiap `make up`, catat checksum, lalu selesai | olt-social/tools | sekali jalan | data |
| `volume-init` | Siapkan folder volume dan izinnya, lalu selesai | — | sekali jalan | — |
| `tools` | Alat operasional (backup sesaat, uji, data contoh) | olt-social/tools 0.1.0 | sesuai kebutuhan | app, data |
| `dummy-olt` | OLT tiruan penerbit token untuk dev; tidak dipakai di produksi | Go | dev saja | dev |

### 3.3 Alur utama

**A. Login nasabah**

```
App OLT --login--> Backend OLT --token sosial (EdDSA/ES256, <=15 mnt)--> App OLT
App (library) --POST /bridge/v1/exchange--> traefik --> kong --> auth-bridge
auth-bridge: cek ukuran <=16 KB, alg + kid, tanda tangan (JWKS), iss/aud/exp (+-30 dtk)
           : rate limit per IP 1.500/mnt dan per user 10/mnt (Valkey, fail open)
           : upsert_olt_profile (UUID stabil dari sub, klaim accounts) -> tolak bila ban / jeda bergabung
auth-bridge --JWT sosial 15 menit--> library
library: sebelum habis, minta token baru lewat tokenProvider lalu tukar lagi
```

Penolakan khas: token tidak valid, `403 user_banned`, `403 account_rejoin_cooldown` dengan `Retry-After` (0175). Rincian di FR-AKUN dan 8.1.

**B. Postingan dengan gambar**

```
library --upload--> /media/v1 --> media: sniff isi, buang EXIF/GPS/XMP
                                   --> classifier (NSFW): allow | hold | block (fail closed)
                                   --> storage (bucket attachments)
library --RPC create_post--> rest --> db: trigger rate limit, validasi, integritas,
                                          kata terlarang, keamanan konten, akun baru
db: simpan post (visible atau held), hashtag, mention -> notifikasi pengikut -> antrean push
notifier --> FCM (bila preferensi mengizinkan)
```

**C. Chat realtime**

```
library --RPC send_message--> rest --> db: trigger konten, DM request, slow mode, dsb.
db --realtime.send (sekali per pesan)--> realtime topik privat room:<id>
realtime --> semua anggota yang tersambung (RLS join kanal privat)
library: mark_rooms_delivered / mark_room_read -> centang; bila putus,
         gap-fill get_messages(p_after) saat tersambung, tiap 45 dtk, dan saat kembali ke app
room saham: daftar chat memoll get_room_previews (bawaan 15 dtk); typing_summary untuk room >= 50 anggota
```

**D. Tiket CS**

```
Nasabah pilih topik -> library tampilkan saran FAQ -> cs_api.open_ticket
db: nomor CS-YYYYMMDD-NNNN, prioritas awal (topik + flag + kata kunci), masuk antrean cs:queue
    mode claim: CS Online mengklik Ambil -> claim_ticket (FOR UPDATE, satu pemenang)
    mode auto_assign: penugasan langsung di akhir transaksi (skill, beban, giliran)
CS (Online) membalas lewat agent_send_message; permintaan OTP/PIN/password diblokir (status blocked)
lampiran nasabah lewat /media/v1 (+ clamav untuk dokumen/video)
CS menyelesaikan (hasil + ringkasan 5-500) -> nasabah diminta rating
rating -> closed (rated); atau cs-sweep menutup setelah ticket.auto_close_days (bawaan 3) -> closed
tiket closed tidak bisa dibalas (409 ticket_closed); nasabah membuat tiket baru
```

**E. Push notification**

```
db: private.notify -> public.notifications (in-app, realtime ke user:<uid>)
    -> cek preferensi per jenis, jam tenang, push_allowed -> antrean push
notifier: ambil antrean, muat kunci Firebase dari Vault -> FCM HTTP v1 -> HP
library: registerPushToken (android/ios/web); push olt.* dibuka layar OLT, push komunitas oleh library
```

**F. Notifikasi transaksi OLT**

```
notifEngine OLT --POST /integration/v1/notify/messages (API key, CIDR, batch 100-500)--> integration
integration --> db: petakan cust_id ke pemilik rekening (klaim accounts dari token sosial)
            --> public.notifications + antrean push
app: tampil di kotak notifikasi; notifier kirim push
```

**G. Akun Nasabah di Hub**

```
Staf CS (izin online_user.*, sesi aal2) --Hub--> nasabah-gateway (domain CS)
nasabah-gateway --> db: nasabah_access(user, aal) cek peran dan izin
nasabah-gateway --token integrasi Ed25519 (/integration/token)--> csAdmin OLT /online/*
alamat dan client id csAdmin diatur Super Admin di Hub; aktif hanya setelah tes koneksi berhasil (0055)
```

### 3.4 Penempatan dan profil

| Profil | File compose | Ciri |
|---|---|---|
| `dev` | `compose.yml` + `compose.dev.yml` | HTTP `:8000`, semua path terbuka (Studio), CORS `*`, bisa memakai `dummy-olt`, log debug |
| `single` | `compose.yml` + `compose.prod.yml` (+ `compose.cs.yml` bila `CS=1`) | HTTPS Let's Encrypt, hanya path API publik, Studio mati, `APP_ENV=production`, auth-bridge mode `jwt` wajib |
| `cluster` | `compose.yml` + `stack.cluster.yml` | Docker Swarm, replika antar-node, Realtime cluster, storage S3. Kerangka, belum teruji |

Server dan Hub diperbarui bersamaan (`git pull --ff-only` kedua repo lalu `make up`); library dirilis terpisah lewat tag Git.

## 4. Kebutuhan fungsional

Kebutuhan fungsional dikelompokkan per modul dengan kode yang sama dengan BRD. Setiap FR memuat deskripsi, aktor, prakondisi, proses dan aturan (batas dan nilai bawaan nyata dari kode atau pengaturan, dengan sumber migrasi), keluaran, kode error, antarmuka (RPC/endpoint, layar Hub, widget library), dan lacak ke modul BR. Rekap jumlah dan matriks keterlacakan ada di 11.1.

| Subbagian | Modul | Kode |
|---|---|---|
| 4.1 | Akun nasabah | AKUN |
| 4.2 | Komunitas | KOM |
| 4.3 | Chat | CHAT |
| 4.4 | Layanan nasabah dan chat CS | CS |
| 4.5 | Pusat Bantuan | BANTU |
| 4.6 | Notifikasi dan promosi | NOTIF |
| 4.7 | Moderasi dan keamanan konten | MOD |
| 4.8 | Kepatuhan | PATUH |
| 4.9 | Rendezvous Hub dan administrasi staf | HUB |
| 4.10 | Integrasi OLT | INT |
| 4.11 | Operasional | OPS |
| 4.12 | Berbagi Trade (dijeda) | TRADE |

### 4.1 Akun nasabah (AKUN)

Modul AKUN mencakup siklus hidup akun komunitas nasabah: penukaran token sosial OLT menjadi sesi sosial di auth-bridge, perpanjangan sesi lewat `tokenProvider`, profil sosial, persetujuan dokumen hukum dari sisi nasabah, pengaturan privasi (kebijakan DM, blokir, bisukan), ekspor data, hapus akun beserta jeda bergabung lagi, logout, cache offline terenkripsi, dan konfigurasi klien. Server tidak pernah memanggil OLT untuk login; kontrak token sosial dari sisi OLT dirinci di FR-INT, sedangkan pengaturan kebijakan dari sisi staf ada di FR-PATUH dan FR-HUB. Semua RPC di modul ini memakai role `authenticated` kecuali disebut lain.

#### FR-AKUN-01 Tukar token sosial OLT menjadi sesi sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menukar token sosial bertanda tangan dari OLT menjadi JWT sosial Supabase tanpa menghubungi sistem OLT. |
| Aktor | Aplikasi OLT (lewat library), auth-bridge |
| Prakondisi | Nasabah sudah login di aplikasi OLT dan `tokenProvider` mengembalikan token sosial yang masih berlaku; request membawa header `apikey: <ANON_KEY>`. |
| Proses dan aturan | 1) Endpoint `POST /bridge/v1/exchange` (Kong) menerima body `{"token": "..."}`; body maksimal 17 KB, token setelah trim tidak boleh kosong dan maksimal 16 KB (`olt.MaxTokenBytes`) (services/auth-bridge/internal/server/server.go). <br>2) Mode produksi `jwt`: verifikasi lokal dengan JWKS OLT dari `docker/secrets/olt_jwks`; mode `mock` ditolak saat `APP_ENV=production`; mode `websocket` hanya cara lama dan tidak dipasang di compose (services/auth-bridge/README.md). <br>3) Setelah verifikasi: upsert profil (FR-AKUN-04), penyimpanan klaim `accounts` bila ada (lihat FR-INT), cek ban (FR-AKUN-06), rate limit per user (FR-AKUN-05), lalu penerbitan JWT (FR-AKUN-03). <br>4) Respons sukses memakai header `Cache-Control: no-store`. <br>5) Token tidak pernah ditulis ke log, metrik, atau cache; cache memakai SHA-256 token sebagai kunci. |
| Keluaran | `200` dengan `access_token`, `token_type: bearer`, `expires_in`, `expires_at`, dan `user {id, olt_user_id, username, display_name, avatar_url, is_verified}`. |
| Kode error | `400 invalid_request`; `401 invalid_token`; `403 user_banned`; `403 account_rejoin_cooldown`; `429 rate_limited`; `500 internal_error`; `502 exchange_failed`; `503 olt_unavailable` (hanya mode `websocket`) |
| Antarmuka | Endpoint `POST /bridge/v1/exchange`; Library: `RendezvousCommunity.initialize(tokenProvider:)` (kelas internal `AuthBridgeClient`) |
| Lacak | BR-AKUN |

#### FR-AKUN-02 Verifikasi token sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima hanya token sosial yang tanda tangan, klaim, dan umurnya sah menurut kontrak OLT. |
| Aktor | auth-bridge |
| Prakondisi | Mode `jwt`; JWKS dibaca sekali saat start. |
| Proses dan aturan | 1) Algoritma hanya `EdDSA` (Ed25519) dan `ES256` (P-256) dan harus cocok dengan jenis kunci dari `kid`; `none`, `HS*`, `RS*` ditolak. <br>2) `kid` wajib bila JWKS berisi lebih dari satu kunci. <br>3) Klaim wajib: `iss` = `OLT_JWT_ISSUER` (bawaan `olt`), `aud` memuat `OLT_JWT_AUDIENCE` (bawaan `olt-social`), `sub` (string ID user OLT), `preferred_username`, `iat`, `exp`; `exp - iat` ≤ `OLT_JWT_MAX_TTL` (bawaan 900 detik); `nbf` dihormati bila ada. <br>4) Toleransi jam `OLT_JWT_LEEWAY` bawaan 30 detik. <br>5) Base64url tanda tangan wajib kanonik. <br>6) Kunci dengan `kid` berawalan `dev-` ditolak saat `APP_ENV=production` sehingga layanan tidak start (docs/olt-integration.md). <br>7) Alasan penolakan hanya dicatat di log (`reason`), tidak dikirim ke klien. |
| Keluaran | Identitas OLT terverifikasi (`sub`, `preferred_username`, `name`, `email`, `accounts`) atau penolakan. |
| Kode error | `401 invalid_token` |
| Antarmuka | Endpoint `POST /bridge/v1/exchange`; kontrak token: lihat FR-INT |
| Lacak | BR-AKUN |

#### FR-AKUN-03 ID user stabil dan isi JWT sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menurunkan ID user sosial yang stabil dari `sub` OLT dan menerbitkan JWT sosial berumur 15 menit dengan isi minimal. |
| Aktor | auth-bridge |
| Prakondisi | Token sosial lolos verifikasi. |
| Proses dan aturan | 1) ID = `UUIDv5(namespace 0b7f6c1e-5a2d-4c8e-9f3b-7d1a2e4c6f80, olt_user_id)`; namespace tidak boleh diubah; `sub` yang berubah dianggap user lain (services/auth-bridge/README.md). <br>2) JWT ditandatangani HS256 dengan `JWT_SECRET` Supabase, masa berlaku `JWT_TTL` bawaan 900 detik. <br>3) Klaim JWT hanya `sub` (UUID), `role: authenticated`, `aud: authenticated`, `iss: olt-auth-bridge`, `iat`, `exp`, `app_metadata.provider: olt`; email, username, dan `olt_user_id` tidak dimasukkan. |
| Keluaran | JWT sosial untuk PostgREST, Realtime, dan media gateway. |
| Kode error | `500 internal_error` (gagal menandatangani) |
| Antarmuka | Endpoint `POST /bridge/v1/exchange` |
| Lacak | BR-AKUN |

#### FR-AKUN-04 Pembuatan dan pembaruan profil saat login

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat profil sosial saat login pertama dan memperbarui data login pada setiap penukaran token yang tidak berasal dari cache. |
| Aktor | auth-bridge (JWT `service_role`), database |
| Prakondisi | Token sosial sah. |
| Proses dan aturan | 1) RPC `upsert_olt_profile(p_id, p_olt_user_id, p_username, p_display_name, p_email)` dipanggil lewat PostgREST internal; error jaringan dan `5xx` di-retry maksimal 3 kali dengan backoff 100 ms, 200 ms, `4xx` tidak di-retry. <br>2) Username OLT disanitasi ke `[A-Za-z0-9_]`, diawali `user_` bila kurang dari 3 karakter, dipotong 30; bila bentrok diberi akhiran `_` + 4 karakter hash, maksimal 5 percobaan (0175). <br>3) Profil baru mulai `trust_level` 0; nama tampilan dari klaim `name` dipotong 60 karakter dan hanya mengisi `display_name` yang masih kosong. <br>4) Email dan username OLT disimpan di `private.user_private` (tidak bisa dibaca user lain), `last_login_at` diperbarui. <br>5) Username profil lama ikut diperbarui bila username OLT berubah dan belum dipakai orang lain. |
| Keluaran | Objek profil `{id, olt_user_id, username, display_name, avatar_url, is_verified, banned, ban_ends_at}` (ditambah `rejoin_at` selama jeda, FR-AKUN-22). |
| Kode error | `400 invalid_profile`; `409 username_unavailable` (dipetakan auth-bridge ke `502 exchange_failed`) |
| Antarmuka | RPC `upsert_olt_profile` (service_role) |
| Lacak | BR-AKUN |

#### FR-AKUN-05 Batas laju dan cache penukaran token

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi laju penukaran token per IP dan per user OLT, serta menyimpan hasil penukaran sebentar agar login serentak tidak membebani database. |
| Aktor | auth-bridge, Valkey |
| Prakondisi | — |
| Proses dan aturan | 1) Batas per IP klien `RATE_LIMIT_PER_MINUTE` bawaan 1500 per menit (sliding window), dicek sebelum body dibaca. <br>2) Batas per user OLT `RATE_LIMIT_PER_USER_PER_MINUTE` bawaan 10 per menit, dicek setelah verifikasi. <br>3) IP klien diambil dari `X-Forwarded-For` hanya bila hop berasal dari `TRUSTED_PROXIES`. <br>4) Cache hasil penukaran per hash token `VERIFY_CACHE_TTL` bawaan 60 detik; user yang di-ban tidak di-cache; hasil tidak di-cache bila penyimpanan klaim `accounts` gagal. <br>5) Bila Valkey mati, rate limit jatuh ke limiter in-memory per instance dan cache dilewati; `APP_ENV=production` mewajibkan `VALKEY_ADDR` (services/auth-bridge/README.md). |
| Keluaran | Penolakan dengan header `Retry-After` (detik) atau hasil dari cache. |
| Kode error | `429 rate_limited` |
| Antarmuka | Endpoint `POST /bridge/v1/exchange` |
| Lacak | BR-AKUN |

#### FR-AKUN-06 Penolakan user yang di-ban

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak penerbitan sesi sosial dan setiap request sosial dari user yang sedang di-ban. |
| Aktor | auth-bridge, database |
| Prakondisi | User punya sanksi `ban` aktif di `private.user_sanctions` (lihat FR-MOD). |
| Proses dan aturan | 1) `upsert_olt_profile` mengembalikan `banned` dan `ban_ends_at`; auth-bridge menolak dengan `403` dan tidak meng-cache hasilnya. <br>2) Klaim `accounts` tetap disimpan untuk user yang di-ban karena notifikasi transaksi bukan fitur sosial (lihat FR-INT). <br>3) `private.check_request` menolak setiap request PostgREST user yang di-ban kecuali skema `cs_api` dan RPC `create_appeal`, `get_my_appeals`, `get_my_sanctions` (0177), sehingga JWT yang terbit sebelum ban tidak berguna. |
| Keluaran | Penolakan login sosial; chat CS tetap bisa lewat `cs_api` atau pengaduan tamu. |
| Kode error | `403 user_banned` |
| Antarmuka | Endpoint `POST /bridge/v1/exchange`; semua RPC `public` |
| Lacak | BR-AKUN |

#### FR-AKUN-07 Pemeriksaan sesi di setiap request

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memeriksa status akun pemegang JWT di setiap request PostgREST sebelum fungsi dijalankan. |
| Aktor | Database (`private.check_request`, pre-request PostgREST) |
| Prakondisi | Request ber-role `authenticated`. |
| Proses dan aturan | 1) Profil yang `deleted_at`-nya terisi ditolak untuk semua skema selain `cs_api` (0177). <br>2) Akun staf CS ditolak memakai skema `public` (fitur sosial). <br>3) Akun staf dari edge publik (`x-olt-edge: public`) ditolak. <br>4) JWT yang `iat`-nya lebih awal dari `private.user_sessions.revoked_before` ditolak, misalnya setelah hapus akun (0177). |
| Keluaran | Request diteruskan atau ditolak dengan kode stabil. |
| Kode error | `403 user_banned`; `403 account_rejoin_cooldown`; `403 cs_staff_social_forbidden`; `403 cs_staff_public_edge`; `401 session_revoked` |
| Antarmuka | Fungsi pre-request `private.check_request` |
| Lacak | BR-AKUN |

#### FR-AKUN-08 Perpanjangan sesi lewat tokenProvider

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus memperpanjang JWT sosial sebelum kedaluwarsa dengan meminta token sosial baru lewat `tokenProvider`, termasuk untuk koneksi realtime yang sedang berjalan. |
| Aktor | Library |
| Prakondisi | `RendezvousCommunity.initialize` sudah dipanggil setelah login OLT. |
| Proses dan aturan | 1) Refresh dijadwalkan 60 detik sebelum `expires_at` (`refreshMargin`); sesi dianggap hampir habis bila tersisa kurang dari 30 detik. <br>2) Refresh terjadwal yang gagal diulang setiap 15 detik (`retryDelay`). <br>3) Permintaan refresh bersamaan digabung menjadi satu penukaran. <br>4) `tokenProvider` yang mengembalikan `null` atau kosong dianggap user tidak login. <br>5) Setelah penolakan `account_rejoin_cooldown`, library tidak memanggil auth-bridge lagi untuk identitas OLT yang sama sampai yang lebih awal dari 30 detik (`cooldownRecheck`) atau `retry_at` (token_manager.dart). <br>6) Respons `401` dari media gateway memicu refresh lalu satu kali percobaan ulang. <br>7) `ensureSignedIn()` memaksa penukaran lebih awal agar error terlihat saat start. |
| Keluaran | Sesi sosial baru tanpa login ulang; token OLT dan token sosial tidak pernah disimpan library. |
| Kode error | `CommunityException(kind: unauthenticated)` untuk `401 invalid_token`; teks UI "Sesi berakhir. Silakan login ulang di OLT." |
| Antarmuka | Library: `initialize(tokenProvider:)`, `RendezvousCommunity.instance.ensureSignedIn()` (kelas internal `TokenManager`) |
| Lacak | BR-AKUN |

#### FR-AKUN-09 Logout dan pencabutan akses

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengakhiri akses sosial saat nasabah keluar dari OLT atau saat OLT berhenti menerbitkan token sosial. |
| Aktor | Aplikasi OLT, library |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) Aplikasi OLT memanggil `signOut()` saat user keluar. <br>2) `signOut()` mengirim sisa event analitik, melepas token push (lihat FR-NOTIF), menghentikan pelacak centang, mengosongkan outbox, menghapus cache gambar, unduhan sementara, dan database offline, lalu memutus semua channel realtime. <br>3) Server tidak punya endpoint logout; pencabutan terjadi karena OLT berhenti menerbitkan token sosial, sehingga akses berakhir paling lambat setelah token terakhir dan JWT sosial habis (≤ 15 menit) (docs/olt-integration.md). |
| Keluaran | Tidak ada data komunitas user itu yang tersisa di perangkat. |
| Kode error | — |
| Antarmuka | Library: `RendezvousCommunity.instance.signOut()` |
| Lacak | BR-AKUN |

#### FR-AKUN-10 Lihat profil sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan profil sosial pengguna berdasarkan ID atau username beserta hubungan dengan pembaca. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_profile(p_user_id, p_username)` mengembalikan `id, username, display_name, avatar_url, bio, is_verified, follower_count, following_count, post_count, created_at, is_me, is_following, follows_me, is_blocked, is_official` (0144). <br>2) Username dicocokkan tanpa memandang huruf besar/kecil (`citext`). <br>3) `olt_user_id` tidak bisa dibaca user lain (grant kolom, 0002). <br>4) Angka Pengikut/Mengikuti di halaman profil membuka daftar pengikut (FR-KOM). <br>5) Bila `onUserTap` tidak diisi, library membuka halaman profil bawaan. |
| Keluaran | Satu baris profil atau kosong bila tidak ditemukan. |
| Kode error | — |
| Antarmuka | RPC `get_profile`; Library: `CommunityUserProfile(userId:)`, `ProfileRepository.getProfile` |
| Lacak | BR-AKUN |

#### FR-AKUN-11 Edit profil sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah mengubah nama tampilan dan bio profilnya sendiri. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif; profil milik sendiri. |
| Proses dan aturan | 1) Pembaruan lewat REST `UPDATE public.profiles` hanya untuk kolom `display_name`, `bio`, `avatar_url` dan hanya baris `id = auth.uid()` (grant kolom + RLS, 0002). <br>2) `display_name` ≤ 60 karakter, `bio` ≤ 300 karakter (constraint `profiles_display_name_length`, `profiles_bio_length`). <br>3) Trigger `profiles_25_text` menolak karakter kontrol lewat `private.validate_text(..., 'profile')` (0014). <br>4) Username tidak bisa diubah nasabah; username mengikuti OLT (FR-AKUN-04). <br>5) Library menyediakan dialog "Edit profil" dengan batas input 60 dan 300 karakter, lalu memuat ulang profil sendiri. |
| Keluaran | Profil tersimpan dan tampil di sesi aktif. |
| Kode error | Pelanggaran constraint (PostgREST `400`); error validasi teks dari `private.validate_text` (perlu konfirmasi kode pastinya) |
| Antarmuka | REST `PATCH /rest/v1/profiles`; Library: `CommunityUserProfile` (tombol Edit profil), `ProfileRepository.updateMyProfile` |
| Lacak | BR-AKUN |

#### FR-AKUN-12 Foto profil

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah mengunggah dan memasang foto profil yang aman ditampilkan publik. |
| Aktor | Nasabah, layanan media |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) Unggah lewat media gateway `POST /media/v1/object/avatars/<user>/avatar-<ms>.<ext>` dengan `x-upsert: true`. <br>2) Bucket `avatars` publik, maksimal 2 MiB, hanya JPEG, PNG, WebP; GIF ditolak di library sebelum unggah (services/media/README.md). <br>3) Metadata (EXIF/GPS) dibuang; gambar yang skornya ≥ ambang tahan classifier langsung ditolak karena bucket publik tidak bisa menyembunyikan gambar (lihat FR-MOD). <br>4) URL publik hasil unggah dipasang ke `profiles.avatar_url` (≤ 500 karakter). <br>5) Foto lama dibersihkan janitor saat akun dihapus (lihat FR-OPS). |
| Keluaran | `avatar_url` baru di profil. |
| Kode error | `415 unsupported_type`; `413 file_too_large`; `422 invalid_image`; `422 image_too_large`; `422 image_blocked`; `429 too_many_uploads` (rate limit `upload` 50/hari, 0012); `503 classifier_unavailable`; `401 invalid_token` |
| Antarmuka | Endpoint `POST /media/v1/object/avatars/...`; Library: `ProfileRepository.uploadAvatar`, dialog Edit profil (Ganti foto) |
| Lacak | BR-AKUN |

#### FR-AKUN-13 Handle huruf kecil

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan dan mengirim handle `@username` dalam huruf kecil secara konsisten. |
| Aktor | Library |
| Prakondisi | — |
| Proses dan aturan | 1) Handle tampil sebagai `@` + username huruf kecil (`communityHandle`, `UserSummary.handle`). <br>2) Teks yang dikirim ke server (pesan, edit pesan, postingan, komentar) melewati `lowercaseMentions` sehingga `@Budi` disimpan `@budi`. <br>3) Server mencocokkan mention tanpa memandang huruf (`private.extract_mentions` memakai `lower`, username `citext`) (0004). |
| Keluaran | Handle seragam di UI dan data. |
| Kode error | — |
| Antarmuka | Library: `communityHandle`, `lowercaseMentions`, `UserSummary.handle` |
| Lacak | BR-AKUN |

#### FR-AKUN-14 Daftar dokumen hukum untuk nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan versi berlaku terbaru setiap dokumen hukum beserta status wajib dan status persetujuan nasabah. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_legal_documents()` mengembalikan satu versi terbaru per jenis (`terms`, `community_guidelines`, `privacy`) yang `effective_at <= now()`, berisi `id, kind, version, title, body, change_summary, effective_at, required, accepted` (0062). <br>2) Jenis wajib diatur `legal.required_kinds`, bawaan `["terms","community_guidelines"]`. <br>3) Dokumen Berbagi Trade tidak tampil di daftar umum (dijeda, lihat TRADE). <br>4) Library memuat daftar sekali per sesi saat login dan memuat ulang setelah menyetujui. <br>5) Penerbitan dokumen dengan empat mata ada di FR-PATUH. |
| Keluaran | Daftar dokumen; banner `CommunityConsentBanner` bila ada dokumen wajib yang belum disetujui. |
| Kode error | — |
| Antarmuka | RPC `get_legal_documents`; Library: `legalDocuments()`, `pendingLegalDocuments()`, `CommunityLegalDocumentReader`, `showCommunityLegalDocument`, `CommunityConsentBanner`, `CommunityAccountSettings` |
| Lacak | BR-AKUN |

#### FR-AKUN-15 Persetujuan dokumen hukum dan gerbang konten

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak konten sosial baru dari nasabah yang belum menyetujui dokumen wajib versi terbaru, dan library harus mengulang aksi setelah nasabah menyetujui. |
| Aktor | Nasabah, library, database |
| Prakondisi | Ada dokumen wajib versi berlaku yang belum disetujui. |
| Proses dan aturan | 1) Trigger integritas pada `posts`, `comments`, `messages` menolak INSERT oleh pengguna aplikasi bila `private.missing_consents` tidak kosong; pesan di room `support` dikecualikan (0062). <br>2) `accept_legal_document(p_document_id)` menyimpan persetujuan idempoten ke `public.user_consents`; dokumen harus ada dan sudah berlaku (0014). <br>3) Library membuka alur persetujuan (dialog di layar lebar, layar penuh di ponsel) dengan satu kotak centang untuk semua dokumen wajib, lalu mengulang aksi yang tertunda satu kali dengan draf yang sama. <br>4) Bila ditunda, draf composer tetap ada dan pesan chat menjadi "Gagal terkirim" yang bisa dikirim ulang. <br>5) Persetujuan ikut terhapus saat akun dihapus (FR-AKUN-20). |
| Keluaran | Konten terkirim setelah persetujuan; persetujuan tercatat dengan `accepted_at`. |
| Kode error | `403 consent_required` (detail: daftar jenis); `404 document_not_found`; `401 not_authenticated` |
| Antarmuka | RPC `accept_legal_document`; Library: `acceptLegalDocuments`, `showCommunityConsent`, `communityConsentGate`, `ConsentGate.run` |
| Lacak | BR-AKUN |

#### FR-AKUN-16 Pengaturan kebijakan DM

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah memilih siapa yang boleh memulai pesan langsung kepadanya. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_dm_policy()` mengembalikan `{policy, request_max_messages}`; `request_max_messages` dari `dm.request_max_messages` bawaan 3 (0070). <br>2) `set_dm_policy(p_policy)` menerima `everyone` (bawaan, orang asing lewat permintaan pesan), `following` (hanya yang saya ikuti), `none` (tidak menerima DM baru). <br>3) Percakapan yang sudah diterima tetap berjalan; akun resmi dan staf CS tidak terkena kebijakan ini (docs/content-safety.md). <br>4) Penegakan saat membuat DM dan permintaan pesan ada di FR-CHAT. <br>5) Nilai ikut `export_my_data` (`dm_policy`). |
| Keluaran | `{policy, request_max_messages}` terbaru. |
| Kode error | `400 invalid_policy`; `401 not_authenticated` |
| Antarmuka | RPC `get_dm_policy`, `set_dm_policy`; Library: `CommunityAccountSettings` bagian "Pesan langsung" |
| Lacak | BR-AKUN |

#### FR-AKUN-17 Blokir akun

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah memblokir dan membuka blokir pengguna lain, dengan efek dua arah pada visibilitas dan interaksi. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif; target bukan diri sendiri. |
| Proses dan aturan | 1) Blokir lewat REST `INSERT public.blocks (blocker_id = auth.uid(), blocked_id)`; buka blokir lewat `DELETE`; insert ganda diabaikan; blokir diri sendiri ditolak constraint `blocks_no_self` (0002). <br>2) Trigger `blocks_unfollow` memutus follow dua arah. <br>3) Postingan dari pasangan yang saling blokir tidak terlihat (RLS `posts_select`); komentar, suka, follow, mention, dan pencarian ikut menghormati blokir dua arah (FR-KOM, FR-CHAT). <br>4) Nasabah hanya bisa membaca baris blokir miliknya. <br>5) Blokir dari orang lain terhadap nasabah tetap berlaku walau nasabah menghapus akun (0174). |
| Keluaran | Status `is_blocked` di `get_profile`. |
| Kode error | Pelanggaran constraint/RLS (PostgREST `400`/`403`) |
| Antarmuka | REST `public.blocks`; Library: `ProfileRepository.block`, `ProfileRepository.unblock`, `CommunityUserProfile` |
| Lacak | BR-AKUN |

#### FR-AKUN-18 Bisukan akun dan kata

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah membisukan pengguna dan kata kunci sehingga kontennya tidak muncul di feed nasabah itu, tanpa memberi tahu pihak yang dibisukan. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) Bisukan pengguna lewat REST `public.mutes (muter_id, muted_id)`; tidak boleh diri sendiri (`mutes_no_self`) (0015). <br>2) Bisukan kata lewat `public.muted_keywords`, panjang 2–50 karakter, maksimal `mute.max_keywords` bawaan 50 per user. <br>3) Baris hanya bisa dibaca dan diubah pemiliknya (RLS). <br>4) Feed `global`, `following`, `stock`, dan pencarian menyaring penulis yang dibisukan dan postingan yang mengandung kata yang dibisukan; feed profil (`user`) tidak disaring (0143). <br>5) Pengguna yang membisukan pengirim tidak menerima notifikasi mention darinya (lihat FR-NOTIF). <br>6) UI bisukan akun dan kata di library: perlu konfirmasi (library tidak memanggil tabel ini). |
| Keluaran | Feed tanpa konten yang dibisukan. |
| Kode error | `422 too_many_muted_keywords`; pelanggaran constraint (PostgREST `400`) |
| Antarmuka | REST `public.mutes`, `public.muted_keywords` |
| Lacak | BR-AKUN |

#### FR-AKUN-19 Ekspor data pribadi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan ekspor seluruh data pribadi nasabah dalam satu dokumen JSON. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `export_my_data()` dibatasi rate limit `data_export` 3 per 86.400 detik (0012) dan dicatat di log akses data pribadi (`self_export`). <br>2) Isi (0172): `profile` (tanpa `olt_user_id`), `email`, `posts`, `polls`, `poll_votes`, `comments`, `messages`, `reactions`, `message_reactions`, `bookmarks`, `following`, `blocked`, `muted_users`, `muted_keywords`, `muted_stocks`, `watchlist`, `reports_made`, `consents`, `sanctions`, `support_tickets`, `push_devices`, `notification_preferences`, `dm_policy`, `mention_policy`, `comment_audience`, `comments_all_off`, `linked_accounts`, `appeals`, `analytics_events` (5000 terakhir), `post_drafts`, `notification_events` (5000 terakhir), `trade_share`. <br>3) Library menyimpan file `data-komunitas-<username>-<yyyyMMdd>.json`: dialog simpan di Windows/macOS/Linux, lembar berbagi di Android/iOS/web, unduhan browser bila Web Share API tidak ada. <br>4) Host bisa mengganti penyimpanan lewat `exportSaver`. |
| Keluaran | Objek JSON dengan `exported_at`. |
| Kode error | `401 not_authenticated`; `429 rate_limited` (header `Retry-After`) |
| Antarmuka | RPC `export_my_data`; Library: `exportMyData()` (`CommunityDataExport`), `CommunityAccountSettings` (Unduh data saya), `saveCommunityDataExport` |
| Lacak | BR-AKUN |

#### FR-AKUN-20 Hapus akun komunitas

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghapus akun komunitas nasabah atas permintaannya sendiri, menghilangkan kontennya dari tampilan, dan mengarsipkan salinannya untuk regulator. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif; profil belum terhapus. |
| Proses dan aturan | 1) `delete_my_account()` (0174) memasukkan file pengguna ke antrean pembersihan (`queue_user_files`, lihat FR-OPS). <br>2) Post, komentar, dan pesan milik nasabah diarsipkan ke `private.content_archive` (alasan `account_delete`) lalu dikosongkan dan ditandai terhapus. <br>3) Dihapus: reaksi, follow dua arah, blokir dan bisuan buatan nasabah, kata dan saham yang dibisukan, saham pantauan, keanggotaan chat, notifikasi (sebagai penerima atau pelaku), persetujuan dokumen hukum, dan `private.user_private`. <br>4) Trigger `profiles_40_social_forget` menghapus bookmark, reaksi pesan, preferensi notifikasi, event analitik, dan draf; event notifikasi dianonimkan (0076, 0090). <br>5) Profil dianonimkan: username `deleted_` + 12 karakter hash, nama/bio/foto dikosongkan, `is_verified = false`, `deleted_at = now()`. <br>6) Semua sesi dicabut (`revoke_sessions`) dan akses dicatat di log data pribadi. <br>7) Tidak disentuh: blokir/bisuan orang lain terhadap nasabah, sanksi, laporan, penghitung rate limit, permintaan DM yang ditolak, tiket CS, dan riwayat edit. <br>8) Tidak ada batas jumlah hapus akun. |
| Keluaran | Akun terhapus; login dan request berikutnya ditolak sampai jeda selesai (FR-AKUN-22, FR-AKUN-23), lalu profil bisa aktif lagi (FR-AKUN-24). |
| Kode error | `401 not_authenticated`; `404 user_not_found` |
| Antarmuka | RPC `delete_my_account`; Library: `deleteMyAccount()` |
| Lacak | BR-AKUN |

#### FR-AKUN-21 Konfirmasi dan pembersihan perangkat saat hapus akun

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus meminta konfirmasi eksplisit sebelum menghapus akun dan membersihkan sesi komunitas di perangkat setelahnya. |
| Aktor | Nasabah, library |
| Prakondisi | Halaman Privasi & akun terbuka. |
| Proses dan aturan | 1) Dialog menjelaskan dampak (konten hilang dari tampilan dan diarsipkan, pengikut/blokir/bisuan dihapus, riwayat CS tetap, akun trading tidak tersentuh) dan menyebut lama jeda dari `get_client_config().config.account_rejoin_cooldown_hours`. <br>2) Nasabah wajib mengetik `HAPUS`; proses ditampilkan selama berjalan. <br>3) Setelah berhasil, library membersihkan realtime, pelacak centang, cache dokumen, cache offline, outbox, dan cache gambar tanpa login ulang otomatis, lalu memanggil `onAccountDeleted` (tanpa callback: `Navigator.maybePop`). <br>4) Token push dilepas server; token terdaftar dipasang lagi otomatis di sesi berikutnya (lihat FR-NOTIF). |
| Keluaran | Pengguna diarahkan keluar dari layar komunitas. |
| Kode error | — |
| Antarmuka | Library: `CommunityAccountSettings(onAccountDeleted:)`, `openCommunityAccountSettings` |
| Lacak | BR-AKUN |

#### FR-AKUN-22 Jeda bergabung lagi setelah hapus akun

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak login sosial dari identitas OLT yang akun komunitasnya baru dihapus selama masa jeda. |
| Aktor | auth-bridge, database |
| Prakondisi | Profil `deleted_at + jeda > now()`. |
| Proses dan aturan | 1) Jeda = `account.rejoin_cooldown_hours`, bawaan 72 jam, `0` = tanpa jeda, rentang 0–720; diubah dari Hub lewat draf kebijakan empat mata (lihat FR-PATUH) (0175). <br>2) `upsert_olt_profile` tidak mengaktifkan profil dan mengembalikan `rejoin_at` tanpa menyimpan ulang email. <br>3) auth-bridge menolak dengan body `{error, message, retry_at}` (`retry_at` RFC 3339, `message` menyebut waktu WIB) dan header `Retry-After`; klaim `accounts` tidak ditautkan selama jeda. <br>4) Bila akun juga di-ban, yang dikembalikan `user_banned`. <br>5) Library menampilkan sisa waktu dan tombol Hubungi CS yang membuka pengaduan tamu (lihat FR-CS). <br>6) Chat CS dalam aplikasi ikut tertutup selama jeda. |
| Keluaran | Penolakan login dengan waktu boleh bergabung lagi. |
| Kode error | `403 account_rejoin_cooldown`; `403 user_banned` |
| Antarmuka | Endpoint `POST /bridge/v1/exchange`; RPC `get_client_config` (`config.account_rejoin_cooldown_hours`); Hub: Kepatuhan → Kebijakan konten → Kategori |
| Lacak | BR-AKUN |

#### FR-AKUN-23 Penolakan sesi dari cache setelah hapus akun

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak request dari profil terhapus walaupun auth-bridge masih menerbitkan JWT dari cache penukaran. |
| Aktor | Database |
| Prakondisi | Profil `deleted_at` terisi; JWT terbit dari cache `VERIFY_CACHE_TTL` (60 detik) atau sebelum hapus akun. |
| Proses dan aturan | 1) `private.check_request` menolak setiap request PostgREST selain skema `cs_api` dari profil yang `deleted_at`-nya terisi (0177). <br>2) JWT dengan `iat` sebelum pencabutan sesi ditolak `session_revoked` (FR-AKUN-07). |
| Keluaran | Tidak ada akses sosial dari profil terhapus. |
| Kode error | `403 account_rejoin_cooldown`; `401 session_revoked` |
| Antarmuka | Fungsi pre-request `private.check_request` |
| Lacak | BR-AKUN |

#### FR-AKUN-24 Bergabung lagi setelah jeda

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengaktifkan kembali profil yang sama saat login pertama setelah jeda selesai, dengan status akun baru. |
| Aktor | auth-bridge, database |
| Prakondisi | Profil terhapus dan jeda sudah lewat. |
| Proses dan aturan | 1) `upsert_olt_profile` mengosongkan `deleted_at`, mengatur `trust_level = 0`, `created_at = now()`, dan nama tampilan dari klaim `name` (0175). <br>2) Semua batasan akun baru berlaku lagi selama `safety.new_account_days` (bawaan 3 hari) (lihat FR-MOD, 0187). <br>3) Konten lama, follow, dan persetujuan tidak kembali; dokumen hukum harus disetujui lagi (0174). <br>4) Blokir dan bisuan dari orang lain, sanksi, dan permintaan DM yang ditolak tetap berlaku. |
| Keluaran | Profil aktif dengan ID yang sama (diturunkan dari `sub`). |
| Kode error | — |
| Antarmuka | RPC `upsert_olt_profile` |
| Lacak | BR-AKUN |

#### FR-AKUN-25 Cache offline per user

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menyimpan data komunitas terakhir di database lokal milik user yang sedang masuk agar layar bisa langsung tampil, dengan server tetap sebagai sumber kebenaran. |
| Aktor | Library |
| Prakondisi | `initialize(offlineCache: true)` (bawaan aktif). |
| Proses dan aturan | 1) Satu database per user komunitas di `<application support>/rendezvous_community/<user id>.sqlite`; di web cache dan outbox hanya di memori. <br>2) Yang disimpan: halaman pertama `get_my_rooms` (30 room, tanpa room CS), pesan per room maksimal `offlineMessageLimit` (bawaan 200), halaman pertama feed Terbaru, Mengikuti, dan 20 feed saham terakhir, outbox teks, dan respons FAQ terakhir per bahasa. <br>3) Chat CS tidak pernah di-cache. <br>4) Baris server menimpa cache; data yang tidak lagi dikembalikan server dihapus dari cache. <br>5) Database dibuka tanpa jaringan hanya bila token dari `tokenProvider` milik user OLT yang sama dengan sesi terakhir (hash SHA-256 `iss`+`sub`). <br>6) Database dihapus saat `signOut()`, `deleteMyAccount()`, `clearLocalCache()`, ganti user, dan saat aplikasi dibuka offline oleh user OLT lain. <br>7) Token sosial dan token OLT tidak pernah disimpan. |
| Keluaran | Tampilan instan dari cache, lalu diperbarui dari server. |
| Kode error | — |
| Antarmuka | Library: `initialize(offlineCache:, offlineMessageLimit:)`, `clearLocalCache()`, `connectivity.online`, `CommunityOfflineBanner` |
| Lacak | BR-AKUN |

#### FR-AKUN-26 Enkripsi cache offline

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus mengenkripsi database cache offline bila aplikasi host menyediakan kunci. |
| Aktor | Library, aplikasi OLT |
| Prakondisi | Host mengisi `offlineCacheKey` dan memilih SQLite3MultipleCiphers (`hooks.user_defines.sqlite3.source: sqlite3mc`). |
| Proses dan aturan | 1) `offlineCacheKey` mengembalikan kunci 256-bit acak dalam 64 karakter hex yang disimpan host di penyimpanan aman. <br>2) File lama yang polos atau tidak cocok dengan kunci dibuang lalu dibuat ulang. <br>3) Bila kunci tidak valid atau file tetap polos (mesin enkripsi tidak dipilih), library tidak menulis ke disk dan memakai cache memori. <br>4) Cache gambar tetap file biasa per user (bawaan 200 MB, 30 hari, `CommunityImageCacheConfig`) dan ikut terhapus bersama cache offline; sejak library 1.46.0 foto lampiran DM dan grup (gelembung, info pesan, permintaan pesan, viewer) hanya di cache memori, sedangkan gambar feed, avatar, banner, dan link preview tetap memakai cache disk; lampiran chat CS tidak pernah disimpan ke disk (CHANGELOG.md, doc/integration.md). |
| Keluaran | Database cache terenkripsi atau cache memori. |
| Kode error | — |
| Antarmuka | Library: `initialize(offlineCacheKey:)` |
| Lacak | BR-AKUN |

#### FR-AKUN-27 Konfigurasi klien

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan konfigurasi klien (status sosial, feature flag, versi minimum, banner, dan nilai konfigurasi) yang bisa dibaca sebelum maupun sesudah login. |
| Aktor | Library, aplikasi OLT |
| Prakondisi | — (boleh anon). |
| Proses dan aturan | 1) `get_client_config(p_platform, p_app_version)` (anon dan authenticated, 0183): `p_platform` salah satu `android, ios, web, windows, macos, linux`; `p_app_version` format angka seperti `2.4.1`, boleh akhiran build `+57`. <br>2) Isi: `social_enabled`, `flags` (delapan kunci tetap: `search`, `trending`, `bookmarks`, `post_edit`, `message_reactions`, `share_post_to_chat`, `notification_prefs`, `analytics`), `min_version` per platform, `update_required`, `banners` (lihat FR-NOTIF), dan `config` {`edit_minutes`, `message_reactions`, `search_min_length`, `notification_types`, `notification_aggregate_minutes`, `trending_windows`, `account_rejoin_cooldown_hours`, `viewer_id`, `server_time`}. <br>3) Flag aktif bila `enabled`, cocok platform, versi ≥ `min_app_version`, lalu persentase 100, user ada di `user_ids`, atau `md5(key:sub)` di bawah persentase; anon hanya flag 100% (docs/social/README.md). <br>4) Library memanggilnya saat `initialize`, saat login atau ganti akun, saat kembali ke foreground, dan tiap 5 menit; sebelum konfigurasi termuat semua flag dianggap aktif, setelahnya kunci yang tidak dikenal server dianggap mati. <br>5) Library mengabaikan respons yang `viewer_id`-nya bukan user aktif dan menghitung selisih jam server untuk jendela edit. <br>6) Pengelolaan flag dan versi ada di FR-HUB. |
| Keluaran | Objek `jsonb` konfigurasi. |
| Kode error | `400 invalid_platform`; `400 invalid_version` |
| Antarmuka | RPC `get_client_config`; Library: `clientConfig`, `clientConfigChanges`, `refreshClientConfig()`, `ClientConfig.feature(CommunityFlags.x)` |
| Lacak | BR-AKUN |

#### FR-AKUN-28 Kill switch sosial dari sisi aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghentikan penulisan konten sosial dan library harus menyembunyikan UI sosial saat kill switch aktif, sementara chat CS tetap berjalan. |
| Aktor | Library, database |
| Prakondisi | `social_enabled = false` (diatur di Hub, lihat FR-HUB). |
| Proses dan aturan | 1) Server menolak postingan, komentar, edit, dan pesan chat non-CS baru dari pengguna aplikasi; membaca, like, follow, dan reaksi tetap jalan; konten staf, akun resmi, dan bot tidak diblokir (0109). <br>2) Library menampilkan `CommunityUnavailableView` di feed, composer, detail post, pencarian, trending, bookmark, dan room non-CS; daftar chat hanya menampilkan room CS. <br>3) Error dikenali dari kodenya (`social_disabled`), bukan status HTTP; backend lama mengirim `503`. <br>4) Pesan chat yang ditolak `403 social_disabled` langsung gagal dan tidak dicoba ulang outbox. <br>5) Host bisa mengganti placeholder lewat `CommunityAvailabilityScope` atau `CommunitySocialGate`, dengan alasan `socialDisabled` atau `featureDisabled`. |
| Keluaran | UI sosial tersembunyi; chat CS tetap tersedia. |
| Kode error | `403 social_disabled` |
| Antarmuka | RPC `get_client_config`; Library: `CommunityAvailabilityScope`, `CommunitySocialGate`, `CommunityUnavailableView` |
| Lacak | BR-AKUN |

#### FR-AKUN-29 Versi minimum dan update paksa

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi tahu aplikasi bahwa versinya di bawah versi minimum platform agar aplikasi OLT mengarahkan nasabah untuk update. |
| Aktor | Library, aplikasi OLT |
| Prakondisi | Super Admin mengatur versi minimum per platform (lihat FR-HUB); aplikasi mengirim `appVersion` dan `platform` saat `initialize`. |
| Proses dan aturan | 1) `update_required = true` bila versi minimum platform ada, `p_app_version` dikirim, dan versi aplikasi lebih kecil dari versi minimum. <br>2) Perbandingan per angka (2.10.0 > 2.9.9); nomor build diabaikan. <br>3) Library memanggil `initialize(onUpdateRequired:)` dan `CommunityUpdateListener(onUpdateRequired:)` sekali per transisi; mekanisme update tetap milik OLT. |
| Keluaran | Callback update dipanggil di aplikasi host. |
| Kode error | `400 invalid_version` |
| Antarmuka | RPC `get_client_config`; Library: `initialize(appVersion:, platform:, onUpdateRequired:)`, `CommunityUpdateListener` |
| Lacak | BR-AKUN |

#### FR-AKUN-30 Profil tamu

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat profil tamu terpisah untuk pengaduan tanpa login dan menjauhkannya dari fitur sosial. |
| Aktor | Database |
| Prakondisi | Tamu memulai pengaduan tanpa login (alur di FR-CS). |
| Proses dan aturan | 1) `cs_api.guest_start` membuat baris `profiles` dengan `is_guest = true`, `olt_user_id = 'guest:<id>'`, username `tamu_` + 12 karakter ID, dan nama tampilan 2–60 karakter dari formulir (0140). <br>2) Profil tamu tidak muncul di `search`/`search_profiles` (0145), `get_follow_list` (0148), dan `get_suggested_users` (0143). <br>3) Panggilan tamu memakai anon key dan token tamu, tidak pernah token sosial, dan tidak memicu `tokenProvider`. |
| Keluaran | Profil tamu yang hanya dipakai untuk tiket pengaduan. |
| Kode error | `400 invalid_name` (lainnya lihat FR-CS) |
| Antarmuka | RPC `cs_api.guest_start`; Library: `CommunityGuestSupport`, `openCommunityGuestSupport` |
| Lacak | BR-AKUN |

### 4.2 Komunitas (KOM)

Modul KOM mencakup fitur komunitas di aplikasi nasabah: Stream (feed Terbaru, Mengikuti, saham, hashtag, indeks, dan tab filter), postingan dengan gambar, polling, sentimen, dan tag `$KODE`, komentar berantai beserta kontrol komentar, suka, ikuti, pengaturan mention, pencarian, trending dan sentimen, bookmark, tampilan link preview, akun resmi dan postingan resmi tersemat dari sisi aplikasi, indeks dan instrumen, pantau dan bisukan saham, halaman saham, serta analitik event klien. Data saham induk (nama, harga, grafik) tetap milik OLT; server hanya memakai kode sebagai label. Penegakan kebijakan konten (kata terlarang, tautan, akun baru, gambar) ada di FR-MOD, notifikasi yang dipicu aktivitas komunitas di FR-NOTIF, dan pengelolaan dari Hub di FR-HUB. Semua RPC di modul ini memakai role `authenticated` dan menolak `401 not_authenticated` tanpa sesi, kecuali disebut lain.

#### FR-KOM-01 Feed Terbaru

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan feed global postingan terbaru dengan paginasi keyset. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_feed(p_scope 'global', p_cursor, p_limit)` mengurutkan `created_at` lalu `id` menurun; `p_limit` dijepit 1–50, bawaan 20 (0149). <br>2) Cursor keyset diambil dari kolom `cursor` baris terakhir. <br>3) Baris berbentuk `feed_post` (penulis, isi, sentimen, lampiran, jumlah suka/komentar, `stock_codes`, `liked_by_me`, `edited_at`, `poll`, `is_bookmarked`, `hashtags`, `is_bot`, `author_is_official`, `moderation_status` khusus penulis, `top_comment`, kolom kontrol komentar). <br>4) Saringan feed berlaku (FR-KOM-09). <br>5) Library menampilkan skeleton, tampilan kosong, error dengan coba lagi, pull-to-refresh, dan infinite scroll; halaman pertama ikut cache offline (FR-AKUN-25). |
| Keluaran | `setof feed_post`. |
| Kode error | `400 invalid_scope`; `400 invalid_cursor`; `401 not_authenticated` |
| Antarmuka | RPC `get_feed`; Library: `CommunityStreamFeed` (tab `CommunityFeedTab.latest`), `CommunityFeedList` |
| Lacak | BR-KOM |

#### FR-KOM-02 Feed Mengikuti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan postingan dari akun yang diikuti nasabah beserta postingannya sendiri. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_feed(p_scope 'following')` hanya memuat postingan penulis yang ada di `follows` milik pemanggil atau pemanggil sendiri (0149). <br>2) Paginasi dan saringan sama dengan FR-KOM-01. |
| Keluaran | `setof feed_post`. |
| Kode error | `400 invalid_cursor` |
| Antarmuka | RPC `get_feed`; Library: `CommunityStreamFeed` (tab `CommunityFeedTab.following`) |
| Lacak | BR-KOM |

#### FR-KOM-03 Feed Untuk Anda

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan feed berperingkat yang menimbang interaksi, bobot penulis, dan akun yang diikuti. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_feed(p_scope 'for_you')` menilai postingan dalam `feed.for_you_days` (bawaan 7 hari) dengan skor `(like + 2×komentar + 1) × bobot penulis × 2 bila diikuti / (umur_jam + 2)^trending.post_gravity` (bawaan 1,5), tanpa postingan sendiri (0143, 0149). <br>2) Cursor offset `o:<n>`. <br>3) Bila tidak ada hasil berperingkat di halaman pertama, feed jatuh ke urutan terbaru. <br>4) Pemakaian di UI bawaan library: perlu konfirmasi (`ForYouFeedScope` tersedia untuk host). |
| Keluaran | `setof feed_post`. |
| Kode error | `400 invalid_cursor` |
| Antarmuka | RPC `get_feed`; Library: `CommunityFeedList(scope: ForYouFeedScope())` |
| Lacak | BR-KOM |

#### FR-KOM-04 Feed saham dan watchlist

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan postingan yang menandai satu kode saham/indeks atau sekumpulan kode. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_feed(p_scope 'stock', p_stock_code)` untuk satu kode, `get_feed(p_scope 'stocks', p_stock_codes)` untuk beberapa kode (0149). <br>2) Kode dinormalkan: `$` dan spasi dibuang, huruf besar, alias diarahkan ke kode utama (mis. `IHSG` ke `COMPOSITE`) (0150). <br>3) Maksimal `stock_stats.max_codes` (bawaan 50) kode per permintaan. <br>4) Feed saham tidak menyaring saham yang dibisukan karena dibuka sengaja (0143). |
| Keluaran | `setof feed_post`. |
| Kode error | `400 stock_code_required`; `400 too_many_stocks`; `400 invalid_cursor` |
| Antarmuka | RPC `get_feed`; Library: `CommunityStockFeed(stockCode:)`, `CommunityFeedList(scope: StocksFeedScope(...))` |
| Lacak | BR-KOM |

#### FR-KOM-05 Feed profil pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan postingan satu penulis di halaman profilnya. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_feed(p_scope 'user', p_author_id)` wajib membawa `p_author_id` (0149). <br>2) Penulis yang dibisukan, saham yang dibisukan, dan kata yang dibisukan tidak disaring karena profil dibuka sengaja; blokir tetap berlaku lewat RLS. |
| Keluaran | `setof feed_post`. |
| Kode error | `400 author_required` |
| Antarmuka | RPC `get_feed`; Library: `CommunityUserProfile` |
| Lacak | BR-KOM |

#### FR-KOM-06 Feed akun resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan postingan yang hanya berasal dari akun resmi aktif. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_feed(p_scope 'official')` menyaring `private.is_official_account(author_id)`, yaitu akun di `cs.official_accounts` yang `disabled_at` kosong (0149, 0144). |
| Keluaran | `setof feed_post`. |
| Kode error | `400 invalid_cursor` |
| Antarmuka | RPC `get_feed`; Library: `CommunityFeedList(scope: OfficialFeedScope())` |
| Lacak | BR-KOM |

#### FR-KOM-07 Urutan Teratas

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus bisa mengurutkan feed berdasarkan jumlah interaksi dalam jendela waktu tertentu. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `p_sort 'top'` menilai `like + 2×komentar` untuk postingan dalam `feed.top_days` (bawaan 30 hari); scope `user` tidak dibatasi waktu (0149). <br>2) Paginasi memakai cursor offset `o:<n>`; cursor keyset ditolak. <br>3) Nilai `p_sort` selain `latest`/`top` ditolak. |
| Keluaran | `setof feed_post` dengan cursor `o:<n>`. |
| Kode error | `400 invalid_sort`; `400 invalid_cursor` |
| Antarmuka | RPC `get_feed` (`p_sort`) |
| Lacak | BR-KOM |

#### FR-KOM-08 Tab filter Stream

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan tab filter Stream yang aktif dari server dan menerapkan urutan serta isinya ke feed. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) Empat tab bawaan tetap: `latest` (Terbaru), `top` (Teratas), `media` (Grafik & Media), `polls` (Polling) (0149, 0180). <br>2) `get_feed_filters()` mengembalikan tab aktif urut `position` dengan `key, label_en, label_id, sort, content, icon, position`. <br>3) `get_feed(..., p_filter)` mengambil urutan dan isi dari tab: `media` = postingan yang punya lampiran ber-`path`, `poll` = postingan berpolling; `p_sort` dan `p_media_only` diabaikan. <br>4) Tab nonaktif atau tidak dikenal ditolak. <br>5) Saklar nyala/mati tab ada di FR-HUB. <br>6) Event `feed_open` membawa properti `filter` (0152). |
| Keluaran | Daftar tab dan feed terfilter. |
| Kode error | `400 invalid_filter` |
| Antarmuka | RPC `get_feed_filters`, `get_feed`; Library: `CommunityFeedFilters.load`, `CommunityFeedFilterTabs`, `CommunityStreamFeed(showFilterTabs: true)`, `FeedFilter.label(locale)` |
| Lacak | BR-KOM |

#### FR-KOM-09 Saringan visibilitas feed

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyaring postingan di semua feed sesuai hapus, blokir, bisuan, dan status moderasi dari sudut pandang pembaca. |
| Aktor | Database |
| Prakondisi | — |
| Proses dan aturan | 1) Postingan terhapus tidak tampil (`private.feed_post_allowed`, 0143). <br>2) Postingan dari pasangan yang saling blokir tidak tampil (RLS `posts_select`, 0004). <br>3) Penulis yang dibisukan dan kata yang dibisukan disaring kecuali scope `user`; saham yang dibisukan disaring kecuali scope `user`, `stock`, `stocks`. <br>4) Postingan `held`/`hidden` hanya terlihat penulisnya, dengan `moderation_status` yang hanya diisi untuk penulis (0083, lihat FR-MOD). |
| Keluaran | Feed yang konsisten di semua scope. |
| Kode error | — |
| Antarmuka | Fungsi `private.feed_post_allowed`; RLS `public.posts` |
| Lacak | BR-KOM |

#### FR-KOM-10 Pembaruan realtime feed

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus memberi tahu adanya postingan baru dan memperbarui jumlah interaksi tanpa memuat ulang manual. |
| Aktor | Library |
| Prakondisi | Feed terbuka dan realtime tersambung. |
| Proses dan aturan | 1) Tabel `posts`, `comments`, dan `reactions` tetap di publikasi `supabase_realtime` (0098). <br>2) Library menampilkan banner "N post baru" di atas feed. <br>3) Suka, follow, dan pantau memakai optimistic update; bila server gagal, perubahan dibatalkan dan SnackBar ditampilkan (doc/features.md). |
| Keluaran | Feed mutakhir. |
| Kode error | — |
| Antarmuka | Realtime `postgres_changes` pada `posts`, `comments`, `reactions`; Library: `CommunityFeedList` |
| Lacak | BR-KOM |

#### FR-KOM-11 Buat postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah menerbitkan postingan teks secara idempoten. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif; dokumen wajib sudah disetujui (FR-AKUN-15); kill switch mati (FR-AKUN-28). |
| Proses dan aturan | 1) `create_post(p_body, p_sentiment, p_attachments, p_client_id, p_poll, p_comment_audience)` (0169). <br>2) Isi dirapikan (trim), panjang 1–2000 karakter (constraint `posts_body_length`, 0004). <br>3) `p_client_id` membuat penerbitan idempoten: pengiriman ulang mengembalikan postingan yang sama; bila sama dengan `client_draft_id`, draf terkait dihapus (FR-KOM-20). <br>4) Rate limit `post` 5 per menit dan 50 per hari, dikali `rate_limit.new_account_factor` 0,5 untuk akun baru dan `rate_limit.trusted_factor` 2 untuk trust ≥ 2 (0002, 0012, 0187). <br>5) Akun yang dibisukan sanksi ditolak `user_muted`; isi melewati validasi teks, duplikat, dan kebijakan konten (lihat FR-MOD). <br>6) Composer menampilkan disclaimer "Konten ini opini pengguna, bukan rekomendasi investasi."; Enter mengirim, Shift+Enter baris baru di desktop. |
| Keluaran | Satu baris `feed_post`; analitik `post_create`. |
| Kode error | `401 not_authenticated`; `403 consent_required`; `403 user_muted`; `403 social_disabled`; `422 content_blocked`; `429 rate_limited`; pelanggaran constraint isi (PostgREST `400`) |
| Antarmuka | RPC `create_post`; Library: `showCommunityComposer`, `CommunityComposePost`, `CommunityComposePromptCard` |
| Lacak | BR-KOM |

#### FR-KOM-12 Gambar di postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan sampai empat gambar per postingan yang diunggah lewat media gateway ke folder milik penulis. |
| Aktor | Nasabah, layanan media |
| Prakondisi | Sesi sosial aktif; bukan akun baru (lihat FR-MOD, 0187). |
| Proses dan aturan | 1) Unggah ke `POST /media/v1/object/attachments/posts/<user>/<uuid>.<ext>`: JPEG, PNG, WebP, GIF, maksimal 5 MB; HEIC/HEIF diubah ke JPEG di perangkat (doc/features.md). <br>2) `p_attachments` harus array maksimal 4 item, tiap item objek dengan `path` berawalan `posts/<author_id>/` tanpa `..` (`private.validate_attachments`, 0004). <br>3) Gambar yang perlu ditinjau tetap tersimpan dengan `"held": true` dan diberi label "Menunggu tinjauan" (lihat FR-MOD). <br>4) Polling tidak bisa digabung dengan lampiran (FR-KOM-16). <br>5) Rate limit `upload` 50 per hari (0012). |
| Keluaran | Postingan dengan lampiran gambar. |
| Kode error | `400 invalid_attachments`; `403 new_account_restricted`; `413 file_too_large`; `415 unsupported_type`; `422 image_blocked`; `429 too_many_uploads` |
| Antarmuka | Endpoint `POST /media/v1/object/attachments/...`; RPC `create_post`; Library: `CommunityComposePost` (`CommunityComposerAction.image`) |
| Lacak | BR-KOM |

#### FR-KOM-13 Sentimen postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan penulis menandai postingan dengan sentimen bullish, bearish, atau netral. |
| Aktor | Nasabah |
| Prakondisi | — |
| Proses dan aturan | 1) `p_sentiment` opsional, salah satu `bullish`, `bearish`, `neutral` (constraint `posts_sentiment`, 0004). <br>2) Sentimen tidak berubah saat postingan diedit (0075). <br>3) Sentimen dipakai agregat sentimen saham dan mood pasar (FR-KOM-42, FR-KOM-43). <br>4) Composer bisa dibuka langsung dengan `initialSentiment`. |
| Keluaran | Badge sentimen di kartu postingan. |
| Kode error | Pelanggaran constraint (PostgREST `400`) |
| Antarmuka | RPC `create_post`; Library: `showCommunityComposer(initialSentiment:)`, `SentimentBadge` |
| Lacak | BR-KOM |

#### FR-KOM-14 Tag `$KODE` dan mention di postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengekstrak kode saham/indeks dan mention dari isi postingan secara otomatis. |
| Aktor | Database |
| Prakondisi | Postingan dibuat atau isinya diubah. |
| Proses dan aturan | 1) Pola `$KODE`: huruf diikuti huruf/angka, boleh bersegmen strip, tidak didahului huruf/angka/`_`/`$` (`$100` dan `US$5` bukan kode) (0150). <br>2) Kode biasa `^[A-Z][A-Z0-9]{1,11}$`; kode berstrip hanya diakui bila terdaftar sebagai instrumen, selain itu jatuh ke bagian sebelum strip (`$BBCA-nya` menjadi `BBCA`); alias diarahkan ke kode utama. <br>3) Maksimal 10 kode dan 10 mention pertama per postingan disimpan di `post_stocks` dan `post_mentions` (0037). <br>4) Mention `@username` 3–30 karakter `[A-Za-z0-9_]`, tidak didahului huruf/angka/`_`/`@` (email bukan mention), tidak untuk diri sendiri (0004). <br>5) Edit menyinkronkan ulang tag. <br>6) Notifikasi mention ada di FR-NOTIF dan tunduk pada FR-KOM-35. <br>7) `$KODE` dan `@user` di UI bisa diketuk lewat `onStockTap`/`onUserTap` (bawaan: halaman library). |
| Keluaran | `stock_codes` di `feed_post`; baris `post_mentions`. |
| Kode error | — |
| Antarmuka | Trigger `posts_sync_tags`; Library: `onStockTap`, `onUserTap`, `onIndexTap` |
| Lacak | BR-KOM |

#### FR-KOM-15 Hashtag di postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengekstrak hashtag dari isi postingan untuk feed hashtag dan trending. |
| Aktor | Database |
| Prakondisi | Postingan dibuat atau diedit. |
| Proses dan aturan | 1) Trigger `posts_42_search` menyimpan hashtag huruf kecil berpola `^[a-z0-9_]{2,50}$`, maksimal 10 per postingan, ke `public.post_hashtags` (0073). <br>2) Fragmen URL (`/halaman#bagian`) dan entitas HTML (`&#39;`) bukan hashtag. <br>3) Edit menyinkronkan ulang hashtag. <br>4) `#hashtag` di UI membuka `CommunityHashtagFeed` atau `onHashtagTap`. |
| Keluaran | `hashtags` di `feed_post`. |
| Kode error | — |
| Antarmuka | Trigger `posts_42_search`; Library: `CommunityHashtagFeed`, `onHashtagTap` |
| Lacak | BR-KOM |

#### FR-KOM-16 Buat polling

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan penulis melampirkan satu polling ke postingan. |
| Aktor | Nasabah |
| Prakondisi | Postingan tanpa lampiran. |
| Proses dan aturan | 1) `p_poll` objek `{options: [...], duration_minutes}` (0019). <br>2) 2–4 pilihan berupa string, tiap pilihan 1–40 karakter setelah trim, tidak boleh sama (tanpa memandang huruf). <br>3) Durasi 5–10.080 menit (5 menit sampai 7 hari), bawaan 1.440 menit; UI library menawarkan 1 jam sampai 7 hari. <br>4) Label pilihan melewati validasi teks dan kebijakan konten. <br>5) Polling tidak bisa digabung dengan lampiran. |
| Keluaran | `poll` di `feed_post`. |
| Kode error | `400 invalid_poll`; `422 poll_with_attachments`; `422 invalid_poll_options`; `422 invalid_poll_option`; `422 duplicate_poll_option`; `422 invalid_poll_duration` |
| Antarmuka | RPC `create_post` (`p_poll`); Library: `CommunityComposePost` (`CommunityComposerAction.poll`) |
| Lacak | BR-KOM |

#### FR-KOM-17 Memilih di polling

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat satu suara per pengguna per polling dan menampilkan hasil sesuai aturan. |
| Aktor | Nasabah |
| Prakondisi | Polling masih berjalan; pemilih bukan pembuat. |
| Proses dan aturan | 1) `vote_poll(p_post_id, p_option_id)` (0019). <br>2) Pembuat tidak bisa memilih; satu suara per user dan tidak bisa diubah. <br>3) Rate limit `poll_vote` 30 per menit dan 500 per hari. <br>4) Hasil (persentase, pilihan sendiri, pilihan teratas) tampil setelah memilih, saat polling selesai, atau bagi pembuat. |
| Keluaran | Tampilan polling terbaru (`poll_view`). |
| Kode error | `404 poll_not_found`; `403 own_poll`; `422 poll_closed`; `422 invalid_poll_option`; `409 already_voted`; `429 rate_limited` |
| Antarmuka | RPC `vote_poll`; Library: `CommunityPollView`, `PollRepository` |
| Lacak | BR-KOM |

#### FR-KOM-18 Edit postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan penulis mengedit isi postingannya dalam jendela waktu terbatas dan menyimpan versi lama. |
| Aktor | Nasabah |
| Prakondisi | Postingan milik pemanggil; flag `post_edit` aktif di klien. |
| Proses dan aturan | 1) `edit_post(p_post_id, p_body)` hanya dalam `content.edit_minutes` (bawaan 15) menit sejak dibuat; trigger juga menegakkannya untuk `UPDATE` REST (0075). <br>2) Postingan berpolling tidak bisa diedit; lampiran dan sentimen tidak berubah. <br>3) Isi baru 1–2000 karakter dan melewati kebijakan konten yang sama. <br>4) Versi lama disimpan di `private.content_edits` (riwayat dibaca Hub, lihat FR-MOD). <br>5) Rate limit `content_edit` 20 per menit. <br>6) Library menampilkan menu Edit hanya selama jendela berlaku (memakai waktu server) dan label "(diedit)" dari `edited_at`. |
| Keluaran | `feed_post` terbaru dengan `edited_at`. |
| Kode error | `404 post_not_found`; `403 forbidden`; `403 edit_window_expired`; `409 poll_not_editable`; `400 empty_body`; `400 body_too_long`; `422 content_blocked`; `403 social_disabled`; `429 rate_limited` |
| Antarmuka | RPC `edit_post`; Library: `ContentEditRepository`, menu Edit di kartu postingan |
| Lacak | BR-KOM |

#### FR-KOM-19 Hapus postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan penulis menghapus postingannya dengan menyimpan salinan arsip. |
| Aktor | Nasabah |
| Prakondisi | Postingan milik pemanggil dan belum terhapus. |
| Proses dan aturan | 1) `delete_post(p_post_id)` menyalin isi dan lampiran ke `private.content_archive`, lalu mengosongkan isi, lampiran, dan mengisi `deleted_at` (0004). <br>2) Tag saham dan mention ikut dihapus; `post_count` profil berkurang. |
| Keluaran | Postingan hilang dari semua feed. |
| Kode error | `404 not_found`; `403 forbidden` |
| Antarmuka | RPC `delete_post`; Library: menu Hapus di kartu postingan |
| Lacak | BR-KOM |

#### FR-KOM-20 Draf postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan draf postingan per pengguna yang tersinkron antar perangkat. |
| Aktor | Nasabah, library |
| Prakondisi | `initialize(postDrafts: true)` (bawaan). |
| Proses dan aturan | 1) `save_post_draft(p_client_draft_id, p_body, p_sentiment, p_stocks, p_attachments, p_poll, p_base_updated_at)` upsert per `client_draft_id` (0150). <br>2) Isi ≤ 2000, sentimen `bullish/bearish/neutral`, ≤ 10 kode valid (alias dinormalkan), lampiran ≤ 4 di `posts/<uid>/`, `poll` objek ≤ 4000 byte; draf kosong tidak disimpan. <br>3) Maksimal `drafts.max_per_user` (bawaan 20) draf; rate limit `post_draft` 60 per menit (0090). <br>4) `p_base_updated_at` lebih lama dari versi server menghasilkan konflik; tanpa nilai ini tulis terakhir menang. <br>5) `get_post_drafts()` terbaru dulu; `delete_post_draft(p_client_draft_id)` mengembalikan `false` bila tidak ada. <br>6) Library menyimpan otomatis ke perangkat dan server; bila batas 20 tercapai atau offline, draf hanya di perangkat. |
| Keluaran | Baris draf `{id, client_draft_id, body, sentiment, stocks, attachments, poll, created_at, updated_at}`. |
| Kode error | `400 invalid_draft`; `400 empty_draft`; `400 body_too_long`; `400 invalid_sentiment`; `400 invalid_stocks`; `400 invalid_attachments`; `400 invalid_poll`; `409 draft_limit`; `409 draft_conflict`; `429 rate_limited` |
| Antarmuka | RPC `save_post_draft`, `get_post_drafts`, `delete_post_draft`; Library: `openCommunityPostDrafts`, `CommunityPostDrafts`, `showCommunityComposer(draft:)`, `clearPostDrafts()` |
| Lacak | BR-KOM |

#### FR-KOM-21 Detail postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan satu postingan beserta komentarnya, termasuk dari deep link. |
| Aktor | Nasabah |
| Prakondisi | Postingan terlihat oleh pembaca. |
| Proses dan aturan | 1) `get_post(p_post_id)` mengembalikan satu `feed_post` dengan aturan RLS yang sama dengan feed (0007). <br>2) Detail memuat disclaimer dan thread komentar (FR-KOM-24). <br>3) Stream bisa memakai mode komentar inline (`CommunityPostOpenMode.inlineComments`). |
| Keluaran | `feed_post` atau kosong bila tidak terlihat. |
| Kode error | — |
| Antarmuka | RPC `get_post`; Library: `CommunityPostDetail(postId:)`, `onPostTap` |
| Lacak | BR-KOM |

#### FR-KOM-22 Label dan status di kartu postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan label asal dan status moderasi postingan sesuai data dari server. |
| Aktor | Library |
| Prakondisi | — |
| Proses dan aturan | 1) "Bot" untuk `is_bot` (postingan dari API bot integrasi), "Resmi" untuk `author_is_official`. <br>2) Untuk konten sendiri: `held` = "Menunggu tinjauan", `hidden` = "Disembunyikan moderator" + "Ajukan banding" (lihat FR-MOD). <br>3) "(diedit)" bila `edited_at` terisi. <br>4) Badge dan kartu bisa diganti lewat `CommunityBuildersScope`. |
| Keluaran | Label di kartu postingan, profil, dan detail. |
| Kode error | — |
| Antarmuka | Library: `CommunityFeedBuilders`, `CommunityBadgeBuilders` |
| Lacak | BR-KOM |

#### FR-KOM-23 Buat komentar dan balasan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah mengomentari postingan dan membalas komentar secara berantai. |
| Aktor | Nasabah |
| Prakondisi | Postingan ada dan tidak terhapus; komentar diizinkan (FR-KOM-30). |
| Proses dan aturan | 1) `create_comment(p_post_id, p_parent_id, p_body, p_client_id)`; isi dirapikan, 1–1000 karakter (0014). <br>2) Induk harus komentar di postingan yang sama dan belum terhapus. <br>3) Pasangan yang saling blokir dengan penulis postingan atau penulis induk ditolak. <br>4) Rate limit `comment` 20 per menit (0002); gerbang persetujuan dokumen, kill switch, dan kebijakan konten berlaku. <br>5) `p_client_id` membuat pengiriman idempoten. |
| Keluaran | Baris `thread_comment`; analitik `comment_create`. |
| Kode error | `400 empty_body`; `400 body_too_long`; `404 post_not_found`; `400 invalid_parent`; `409 parent_deleted`; `403 blocked`; `403 comments_off`; `403 comments_restricted`; `403 consent_required`; `403 social_disabled`; `429 rate_limited` |
| Antarmuka | RPC `create_comment`; Library: `CommunityPostComments`, `CommentRepository` |
| Lacak | BR-KOM |

#### FR-KOM-24 Thread komentar dan urutannya

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan thread komentar berhalaman dengan pilihan urutan. |
| Aktor | Nasabah |
| Prakondisi | Postingan ada. |
| Proses dan aturan | 1) `get_comment_thread(p_post_id, p_root_comment_id, p_max_depth, p_cursor, p_limit, p_replies_limit, p_include_root, p_sort)` (0155). <br>2) `p_sort`: `oldest` (bawaan), `latest`, `top` (`like_count + reply_count`) (0142). <br>3) `p_max_depth` 0–20 (bawaan 3), `p_limit` 1–100 (bawaan 20), `p_replies_limit` 0–50 (bawaan 3). <br>4) Komentar terhapus tidak dikirim; membuka thread dari komentar terhapus ditolak. <br>5) Library: garis indentasi per level, mulai level 4 indentasi berhenti dan muncul "Lanjutkan thread" (`onThreadTap`), "Lihat N balasan lainnya", collapse/expand per cabang, urutan bisa diganti di detail. |
| Keluaran | `setof thread_comment`. |
| Kode error | `400 invalid_sort`; `400 invalid_cursor`; `404 post_not_found`; `404 comment_not_found` |
| Antarmuka | RPC `get_comment_thread`; Library: `CommunityPostComments`, `CommunityCommentSort`, `onThreadTap` |
| Lacak | BR-KOM |

#### FR-KOM-25 Edit komentar

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan penulis mengedit komentarnya dalam jendela waktu yang sama dengan postingan. |
| Aktor | Nasabah |
| Prakondisi | Komentar milik pemanggil. |
| Proses dan aturan | 1) `edit_comment(p_comment_id, p_body)` dalam `content.edit_minutes` (bawaan 15) menit; trigger menegakkan juga untuk `UPDATE` REST (0075). <br>2) Isi baru 1–1000 karakter dan melewati kebijakan konten. <br>3) Versi lama disimpan di `private.content_edits`; rate limit `content_edit` 20 per menit. |
| Keluaran | `thread_comment` terbaru dengan `edited_at`. |
| Kode error | `404 comment_not_found`; `403 forbidden`; `403 edit_window_expired`; `400 empty_body`; `400 body_too_long`; `422 content_blocked`; `429 rate_limited` |
| Antarmuka | RPC `edit_comment`; Library: menu Edit di komentar |
| Lacak | BR-KOM |

#### FR-KOM-26 Hapus komentar tanpa jejak

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghapus komentar tanpa menyisakan placeholder di thread dan merapikan balasannya. |
| Aktor | Nasabah |
| Prakondisi | Komentar milik pemanggil dan belum terhapus. |
| Proses dan aturan | 1) `delete_comment(p_comment_id)` mengarsipkan isi ke `private.content_archive` lalu mengosongkannya (0005). <br>2) Balasan langsung naik ke induk terdekat yang masih ada, atau menjadi komentar tingkat atas; `parent_id`, `path`, dan `depth` turunan disesuaikan (0155). <br>3) `comment_count` postingan dan `reply_count` induk tidak menghitung komentar terhapus. |
| Keluaran | Thread tanpa komentar yang dihapus. |
| Kode error | `404 not_found`; `403 forbidden` |
| Antarmuka | RPC `delete_comment`; Library: menu Hapus di komentar |
| Lacak | BR-KOM |

#### FR-KOM-27 Audiens komentar bawaan akun

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan pilihan akun tentang siapa yang boleh berkomentar sebagai nilai awal postingan baru. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_comment_settings()` mengembalikan `{audience, all_off}`; `set_comment_audience(p_audience)` menerima `everyone` (bawaan), `following`, `followers`, `following_and_followers`; `off` tidak boleh untuk pengaturan akun (0169, 0170). <br>2) Pengaturan dibaca `create_post` bila `p_comment_audience` kosong; mengubahnya tidak menyentuh postingan yang sudah terbit. <br>3) Nilai ikut `export_my_data`. |
| Keluaran | `{audience, all_off}`. |
| Kode error | `400 invalid_comment_audience` |
| Antarmuka | RPC `get_comment_settings`, `set_comment_audience`; Library: `CommunityCommentAudienceSettings`, `CommunityAccountSettings` (Izinkan komentar dari) |
| Lacak | BR-KOM |

#### FR-KOM-28 Audiens komentar per postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik mengatur atau mematikan komentar pada satu postingan, saat membuat maupun setelah terbit. |
| Aktor | Nasabah (pemilik postingan) |
| Prakondisi | Postingan milik pemanggil dan belum terhapus. |
| Proses dan aturan | 1) `create_post(..., p_comment_audience)` menerima lima nilai termasuk `off` (0169). <br>2) `set_post_comment_audience(p_post_id, p_audience)` mengubah audiens; kolom `comment_audience` tidak bisa diubah lewat REST. <br>3) Composer menampilkan baris "Siapa yang bisa berkomentar" dengan nilai awal dari akun; menu pemilik berisi "Matikan komentar"/"Nyalakan komentar" (menyalakan memakai `everyone`) dan "Atur siapa yang bisa berkomentar". |
| Keluaran | `feed_post` terbaru. |
| Kode error | `404 post_not_found`; `403 forbidden`; `400 invalid_comment_audience` |
| Antarmuka | RPC `create_post`, `set_post_comment_audience`; Library: `CommunityComposeCommentAudience`, `showCommentAudienceDialog`, `showCommentAudienceSheet`, `CommentControlRepository` |
| Lacak | BR-KOM |

#### FR-KOM-29 Matikan komentar di semua postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan saklar akun untuk mematikan komentar di semua postingan pemilik tanpa mengubah pengaturan per postingan. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `set_all_comments_off(p_off)` menyimpan `private.comment_preferences.all_off` (0170). <br>2) Selama aktif, audiens efektif semua postingan pemilik = `off`; saat dimatikan, setiap postingan kembali ke pengaturannya sendiri dan komentar lama muncul lagi. <br>3) Postingan baru selama saklar aktif tetap menyimpan audiens akun. <br>4) `feed_post.comments_off_by_account` hanya diisi untuk pemilik. <br>5) Library mengunci pilihan "Izinkan komentar dari", menampilkan "Dimatikan di pengaturan" di composer, dan memperbarui feed pemilik tanpa muat ulang. |
| Keluaran | `{audience, all_off}`. |
| Kode error | `400 invalid_comment_setting` |
| Antarmuka | RPC `set_all_comments_off`, `get_comment_settings`; Library: `CommentSettingsRepository.setAllCommentsOff`, `CommunityCommentAudienceSettings` |
| Lacak | BR-KOM |

#### FR-KOM-30 Penegakan dan tampilan kontrol komentar

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak komentar di luar audiens efektif dan menyembunyikan komentar postingan yang komentarnya mati. |
| Aktor | Database, library |
| Prakondisi | — |
| Proses dan aturan | 1) Trigger `comments_25_comment_audience` menolak komentar dan balasan di semua tingkat, lewat RPC maupun REST (0169, 0170). <br>2) `everyone` = semua yang tidak saling blokir; `following` = orang yang diikuti pemilik; `followers` = pengikut pemilik; `following_and_followers` = salah satunya; `off` = tidak ada, termasuk pemilik. <br>3) Policy RLS `comments_hidden_when_off` menyembunyikan semua komentar postingan `off` dari `authenticated`, termasuk `top_comment`; `comment_count` null untuk bukan pemilik. <br>4) `feed_post` membawa `can_comment` dan `comment_restriction` (`off`, nama audiens, atau `blocked`). <br>5) Library mengganti kolom balasan dengan "Komentar dinonaktifkan" atau misalnya "Hanya pengikut @nama yang bisa berkomentar", dan menyembunyikan komentar secara realtime saat pemilik mematikannya. |
| Keluaran | Komentar diterima atau ditolak dengan alasan jelas. |
| Kode error | `403 comments_off`; `403 comments_restricted`; `403 blocked` |
| Antarmuka | Trigger `comments_25_comment_audience`; Library: `CommentRestrictionNotice`, `commentRestrictionMessage`, `Post.canComment` |
| Lacak | BR-KOM |

#### FR-KOM-31 Suka postingan dan komentar

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah menyukai dan batal menyukai postingan atau komentar. |
| Aktor | Nasabah |
| Prakondisi | Konten ada, belum terhapus, dan tidak saling blokir. |
| Proses dan aturan | 1) Suka lewat REST `INSERT public.reactions (user_id, target_type 'post'/'comment', target_id)` dengan jenis tetap `like`; batal lewat `DELETE`; satu suka per user per konten (primary key) (0006). <br>2) Rate limit `reaction` 60 per menit (0012). <br>3) Penghitung `like_count` diperbarui trigger; `liked_by_me` ada di `feed_post`. <br>4) Library memakai optimistic update. <br>5) Kill switch tidak memblokir suka. <br>6) Sejak 0196 post bisa diberi reaksi emoji (👍 ❤️ 😂 😮 😢 🔥, satu per orang) lewat `set_post_reaction(p_post_id, p_emoji)`; `👍` = `like`. `feed_post` membawa `my_reaction` dan `reaction_summary`; `like_count` menghitung semua reaksi; `post_reactors` menampilkan siapa memberi reaksi. Komentar tetap hanya `like`. |
| Keluaran | Jumlah suka terbaru. |
| Kode error | `404 target_not_found`; `403 blocked`; `429 rate_limited` |
| Antarmuka | REST `public.reactions`; Library: tombol suka di kartu postingan dan komentar |
| Lacak | BR-KOM |

#### FR-KOM-32 Ikuti dan berhenti mengikuti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah mengikuti dan berhenti mengikuti pengguna lain. |
| Aktor | Nasabah |
| Prakondisi | Target bukan diri sendiri dan tidak saling blokir. |
| Proses dan aturan | 1) Ikuti lewat REST `INSERT public.follows (follower_id = auth.uid(), following_id)`; berhenti lewat `DELETE` (0002). <br>2) RLS menolak follow ke pasangan yang saling blokir; constraint `follows_no_self` menolak diri sendiri. <br>3) Rate limit `follow` 30 per jam (0012). <br>4) `follower_count`/`following_count` diperbarui trigger. <br>5) Akun resmi bisa diikuti tetapi tidak menerima DM (lihat FR-CHAT). <br>6) Notifikasi follow ada di FR-NOTIF. |
| Keluaran | Status `is_following` terbaru. |
| Kode error | `429 rate_limited`; pelanggaran RLS/constraint (PostgREST `403`/`400`) |
| Antarmuka | REST `public.follows`; Library: `ProfileRepository.follow`, `ProfileRepository.unfollow`, `SuggestedFollowButton`, `CommunityUserProfile` |
| Lacak | BR-KOM |

#### FR-KOM-33 Daftar pengikut dan yang diikuti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan daftar pengikut dan yang diikuti seorang pengguna dengan penanda hubungan dari sudut pandang pembaca. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_follow_list(p_user_id, p_kind, p_cursor, p_limit)`; `p_kind` `followers` atau `following`; terbaru mengikuti dulu; `p_limit` 1–50, bawaan 30; paginasi keyset (0148). <br>2) Baris: `id, username, display_name, avatar_url, is_verified, is_official, is_me, is_following, follows_me, followed_at, cursor`. <br>3) Disembunyikan: akun terhapus, tamu, staf CS, akun di-ban, dan akun yang saling blokir dengan pembaca, sehingga jumlah baris bisa lebih sedikit dari penghitung. <br>4) Library membuka daftar dari angka Pengikut/Mengikuti di profil; `kinds` bisa dibatasi ke satu jenis. |
| Keluaran | Daftar berhalaman. |
| Kode error | `400 invalid_kind`; `400 invalid_cursor`; `404 user_not_found` |
| Antarmuka | RPC `get_follow_list`; Library: `CommunityFollowList(userId:, initialKind:, kinds:)`, `CommunityNavigator.openFollowList`, `FollowListRepository` |
| Lacak | BR-KOM |

#### FR-KOM-34 Saran akun untuk diikuti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyarankan akun untuk diikuti berdasarkan teman bersama, akun resmi, dan penulis aktif. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_suggested_users(p_limit)` dijepit 1–20, bawaan 5 (0143). <br>2) Kandidat: akun yang diikuti oleh akun yang saya ikuti (`mutual_count`), akun resmi aktif, dan 200 penulis paling aktif dalam `suggestions.active_days` (bawaan 14 hari). <br>3) Dikecualikan: diri sendiri, terhapus, tamu, staf, di-ban, yang sudah diikuti, yang saling blokir, dan yang saya bisukan. <br>4) Urut `mutual_count`, akun resmi, `follower_count`, username. |
| Keluaran | Daftar `{id, username, display_name, avatar_url, is_verified, is_official, follower_count, mutual_count}`. |
| Kode error | `401 not_authenticated` |
| Antarmuka | RPC `get_suggested_users`; Library: `CommunitySuggestedUsers` |
| Lacak | BR-KOM |

#### FR-KOM-35 Pengaturan siapa yang bisa menyebut saya

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah membatasi siapa yang mention-nya memberi notifikasi. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_mention_policy()` dan `set_mention_policy(p_policy)` dengan nilai `everyone` (bawaan), `following` (orang yang saya ikuti), `none` (0172). <br>2) Penegakan di `private.notify`: notifikasi `mention` dibuang bila tidak diizinkan; berlaku untuk postingan, komentar, room saham, dan grup. Staf dan akun resmi selalu diizinkan. <br>3) Teks `@nama` dan baris `post_mentions` tidak diubah; mention di komentar untuk pemilik postingan atau penulis induk tetap sampai sebagai notifikasi `reply`. <br>4) Nilai ikut `export_my_data` (`mention_policy`). |
| Keluaran | `{policy}`. |
| Kode error | `400 invalid_policy`; `401 not_authenticated` |
| Antarmuka | RPC `get_mention_policy`, `set_mention_policy`; Library: `CommunityMentionPolicySettings`, `MentionPolicyRepository` |
| Lacak | BR-KOM |

#### FR-KOM-36 Saran `@` saat mengetik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyarankan pengguna saat nasabah mengetik `@` dan menyaring yang tidak bisa disebut. |
| Aktor | Nasabah |
| Prakondisi | Composer postingan, komentar, room saham, atau grup. |
| Proses dan aturan | 1) `search_profiles(p_query, p_limit)` dijepit 1–25, bawaan 10, mengembalikan `id, username, display_name, avatar_url, is_verified, is_official, can_mention` (0172). <br>2) Library menyaring baris `can_mention = false`; pengguna yang membatasi mention tetap muncul di pencarian lain. <br>3) Di grup saran hanya anggota grup; di DM dan chat CS tidak ada saran `@`/`$` (lihat FR-CHAT). <br>4) Autocomplete bisa dipilih dengan ↑/↓ dan Enter/Tab di desktop. |
| Keluaran | Daftar saran. |
| Kode error | `401 not_authenticated` |
| Antarmuka | RPC `search_profiles`; Library: `MentionPolicyRepository.searchMentionableUsers`, `ProfileRepository.searchUsers` |
| Lacak | BR-KOM |

#### FR-KOM-37 Pencarian gabungan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencari postingan, pengguna, saham, dan hashtag sekaligus untuk saran pencarian. |
| Aktor | Nasabah |
| Prakondisi | Flag `search` aktif. |
| Proses dan aturan | 1) `search(p_query, p_type 'all')` mengembalikan 5 teratas tiap jenis `posts`, `users`, `stocks`, `hashtags`; `next_cursor` selalu null dan cursor tidak boleh dikirim (0073). <br>2) Kata kunci minimal `search.min_query_length` (bawaan 2) karakter dan harus memuat huruf/angka, maksimal 100 karakter. <br>3) Postingan dicari dengan full-text `indonesian` (stemming) dan `simple`, kata terakhir sebagai awalan, dan trigram (`word_similarity` ≥ 0,6) bila kata kunci ≥ `search.typo_min_length` (bawaan 4). <br>4) Rate limit `search` 30 per menit dan 600 per jam, dikali faktor trust. <br>5) Hasil menghormati blokir dua arah, bisuan (postingan), status moderasi, akun terhapus, dan akun di-ban; staf dan tamu tidak bisa dicari (0145). <br>6) Library: debounce ±300 ms, kata kunci tidak dikirim ke analitik. |
| Keluaran | `{query, type, posts, users, stocks, hashtags, next_cursor}`. |
| Kode error | `400 invalid_type`; `400 query_too_short`; `400 query_too_long`; `400 invalid_cursor`; `429 rate_limited` |
| Antarmuka | RPC `search`; Library: `CommunitySearch`, `openCommunitySearch` |
| Lacak | BR-KOM |

#### FR-KOM-38 Pencarian per jenis

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan pencarian satu jenis hasil dengan paginasi. |
| Aktor | Nasabah |
| Prakondisi | Flag `search` aktif. |
| Proses dan aturan | 1) `search(p_query, p_type, p_cursor, p_limit)` dengan `p_type` `posts` (keyset, baris `feed_post`), `users`, `stocks`, `hashtags` (offset `o:<n>`); `p_limit` 1–50, bawaan 20; offset maksimal 1000 (0073). <br>2) `users`: `{id, username, display_name, avatar_url, is_verified, follower_count, is_official, is_following, is_me}`. <br>3) `stocks`: awalan kode, boleh diawali `$`, juga menemukan indeks lewat kode, alias, atau nama; item membawa `kind` dan `name` (0150). <br>4) `hashtags`: awalan, boleh diawali `#`, dengan `posts_7d`. <br>5) Direktori saham hanya mengenal kode yang pernah dibahas, dipantau, atau punya room. |
| Keluaran | `{query, type, <jenis>: [...], next_cursor}`. |
| Kode error | `400 invalid_type`; `400 query_too_short`; `400 query_too_long`; `400 invalid_cursor`; `429 rate_limited` |
| Antarmuka | RPC `search`; Library: `CommunitySearch`, `SearchRepository` |
| Lacak | BR-KOM |

#### FR-KOM-39 Feed hashtag

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan postingan yang memuat satu hashtag. |
| Aktor | Nasabah |
| Prakondisi | Flag `search` aktif. |
| Proses dan aturan | 1) `get_hashtag_feed(p_tag, p_cursor, p_limit)`; tag tanpa `#`, tidak peka huruf besar; keyset sama dengan `get_feed`; `p_limit` bawaan 20 (0073). <br>2) Menghormati RLS, bisuan pengguna, dan kata yang dibisukan. |
| Keluaran | `setof feed_post`. |
| Kode error | `400 invalid_hashtag`; `400 invalid_cursor` |
| Antarmuka | RPC `get_hashtag_feed`; Library: `CommunityHashtagFeed` |
| Lacak | BR-KOM |

#### FR-KOM-40 Hashtag trending

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan hashtag yang sedang ramai dalam jendela 24 jam atau 7 hari. |
| Aktor | Nasabah |
| Prakondisi | Flag `trending` aktif. |
| Proses dan aturan | 1) `get_trending_hashtags(p_window, p_limit)`: `p_window` `24h` (bawaan) atau `7d`, `p_limit` maksimal 50, bawaan 10 (0081). <br>2) Skor = jumlah bobot penulis berbeda; akun baru (< `trending.new_account_days` 7 hari) atau trust 0 berbobot `trending.new_account_weight` 0,2; minimal `trending.min_authors` 2 penulis (0073). <br>3) Dibaca dari snapshot job `social-trending` sehingga tertunda maksimal 5 menit (lihat FR-OPS). |
| Keluaran | `table(tag, post_count, author_count, score)`. |
| Kode error | `400 invalid_window` |
| Antarmuka | RPC `get_trending_hashtags`; Library: `CommunityTrending` |
| Lacak | BR-KOM |

#### FR-KOM-41 Trending saham dan postingan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan saham paling ramai, saham yang diskusinya naik, postingan populer, dan hashtag trending dengan perlindungan anti-manipulasi. |
| Aktor | Nasabah |
| Prakondisi | Flag `trending` aktif. |
| Proses dan aturan | 1) `get_trending(p_window)` mengembalikan `{window, computed_at, stocks, rising, posts, hashtags}`, masing-masing maksimal 10 (0074). <br>2) Satu penulis dihitung sekali per saham per 5 menit; akun baru berbobot 0,2; saham dengan alert manipulasi terbuka dikali `trending.manipulation_weight` 0,3; postingan `held`/`hidden`/terhapus tidak dihitung. <br>3) `rising` minimal `trending.rising_min_posts` (5) postingan. <br>4) Skor postingan populer memakai `trending.post_gravity` 1,5; 100 teratas disaring per pembaca (blokir, bisuan, saham dibisukan). |
| Keluaran | Objek `jsonb` trending. |
| Kode error | `400 invalid_window` |
| Antarmuka | RPC `get_trending`; Library: `CommunityTrending`, `CommunityTrendingTab` |
| Lacak | BR-KOM |

#### FR-KOM-42 Sentimen saham

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan ringkasan sentimen bullish/bearish/netral per kode saham atau indeks. |
| Aktor | Nasabah |
| Prakondisi | Flag `trending` aktif. |
| Proses dan aturan | 1) `get_stock_sentiment(p_code)` mengembalikan `{code, 24h, 7d, updated_at}` dengan `posts, bullish, bearish, neutral, unlabeled, bullish_pct, bearish_pct, neutral_pct` (0150). <br>2) Persentase dihitung dari postingan berlabel dengan bobot penulis; `*_pct` null bila belum ada label. <br>3) Alias diarahkan ke kode utama; data tertunda maksimal 5 menit. |
| Keluaran | Objek `jsonb` sentimen. |
| Kode error | `400 invalid_stock_code` |
| Antarmuka | RPC `get_stock_sentiment`; Library: `CommunityStockSentiment`, `SentimentBar` |
| Lacak | BR-KOM |

#### FR-KOM-43 Mood pasar

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan mood pasar keseluruhan dari sentimen postingan. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_market_sentiment(p_window)`, `p_window` `24h` (bawaan) atau `7d` (0143). <br>2) Menghitung jumlah postingan per sentimen dan bobot penulis per sentimen dalam jendela. |
| Keluaran | Objek `jsonb` mood pasar. |
| Kode error | `400 invalid_window` |
| Antarmuka | RPC `get_market_sentiment`; Library: `CommunityMarketSentiment` |
| Lacak | BR-KOM |

#### FR-KOM-44 Statistik saham harian

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan jumlah postingan hari ini dan persentase bullish untuk sekumpulan kode. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_stock_stats(p_codes)` maksimal `stock_stats.max_codes` (bawaan 50) kode; kode tidak valid diabaikan, alias dinormalkan (0150). <br>2) "Hari ini" dihitung dari tengah malam WIB; `bullish_pct` berbobot penulis, null bila belum ada label. |
| Keluaran | `table(code, posts_today, bullish_pct)`. |
| Kode error | `400 too_many_stocks` |
| Antarmuka | RPC `get_stock_stats`; Library: `CommunityStockStatsBuilder(codes:)` |
| Lacak | BR-KOM |

#### FR-KOM-45 Simpan postingan (bookmark)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah menyimpan dan melepas simpanan postingan untuk dibaca nanti. |
| Aktor | Nasabah |
| Prakondisi | Flag `bookmarks` aktif; postingan terlihat. |
| Proses dan aturan | 1) `toggle_bookmark(p_post_id, p_bookmarked)`: `null` = toggle, `true`/`false` = set idempoten (0075). <br>2) Rate limit `bookmark` 120 per menit. <br>3) Tabel `public.bookmarks` hanya bisa dibaca pemiliknya dan ditulis lewat RPC. |
| Keluaran | `boolean` status baru; `is_bookmarked` di `feed_post`. |
| Kode error | `404 post_not_found`; `429 rate_limited` |
| Antarmuka | RPC `toggle_bookmark`; Library: ikon simpan di kartu postingan, `BookmarkRepository` |
| Lacak | BR-KOM |

#### FR-KOM-46 Daftar postingan tersimpan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan daftar postingan yang disimpan nasabah. |
| Aktor | Nasabah |
| Prakondisi | Flag `bookmarks` aktif. |
| Proses dan aturan | 1) `get_bookmarks(p_cursor, p_limit)` urut waktu simpan terbaru, cursor memakai waktu bookmark, `p_limit` bawaan 20 (0075). <br>2) Postingan yang dihapus atau tidak lagi terlihat tidak ditampilkan. <br>3) Postingan yang dibatalkan simpanannya langsung hilang dari daftar di library. |
| Keluaran | `setof feed_post`. |
| Kode error | `400 invalid_cursor` |
| Antarmuka | RPC `get_bookmarks`; Library: `CommunityBookmarks` |
| Lacak | BR-KOM |

#### FR-KOM-47 Tampilan link preview

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan kartu pratinjau untuk URL pertama di postingan, komentar, dan pesan, dengan tautan berbahaya disaring. |
| Aktor | Nasabah, library |
| Prakondisi | Konten berisi URL `http(s)`. |
| Proses dan aturan | 1) `get_link_previews(p_urls)` maksimal 20 URL per panggilan (0080). <br>2) Status per URL: `ok` (judul, deskripsi, situs, gambar, ukuran gambar, `final_url`, `fetched_at`), `pending` (masih antre), atau `none`. <br>3) Host asal atau host akhir yang diblokir tidak pernah dikembalikan `ok`; pengambilan, NSFW, dan retensi ada di FR-OPS dan FR-MOD. <br>4) Library memanggil satu kali per batch layar dan mengulang `pending` paling banyak dua kali. |
| Keluaran | Kartu pratinjau di bawah konten. |
| Kode error | `400 too_many_urls` |
| Antarmuka | RPC `get_link_previews`; Library: `LinkPreviewCard`, `LinkPreviewLoader` |
| Lacak | BR-KOM |

#### FR-KOM-48 Membuka tautan dan hashtag

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus membuka tautan dengan aman dan menautkan hashtag ke feed hashtag. |
| Aktor | Library |
| Prakondisi | — |
| Proses dan aturan | 1) Tautan `http(s)` dibuka di browser setelah dialog yang menampilkan domain asli. <br>2) Skema lain (`javascript:`, `tel:`, `www.` tanpa skema) tetap teks biasa. <br>3) `#hashtag` membuka `CommunityHashtagFeed` atau `onHashtagTap` milik host (doc/features.md). |
| Keluaran | Navigasi aman. |
| Kode error | — |
| Antarmuka | Library: `parseSocialText`, `onHashtagTap` |
| Lacak | BR-KOM |

#### FR-KOM-49 Akun resmi di aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menandai akun resmi OLT di aplikasi dan membatasinya menjadi akun yang hanya bisa diikuti, bukan di-DM. |
| Aktor | Nasabah |
| Prakondisi | Akun terdaftar di `cs.official_accounts` (dikelola di FR-HUB). |
| Proses dan aturan | 1) `get_profile` dan `search_profiles` membawa `is_official`; `feed_post` membawa `author_is_official` (0144). <br>2) Akun resmi aktif = `disabled_at` kosong; akun yang hanya terverifikasi tidak dihitung resmi. <br>3) DM baru ke akun resmi ditolak (lihat FR-CHAT). <br>4) Library menampilkan badge "Resmi"; tombol "Hubungi CS" di profil akun resmi memanggil `onOfficialContact`. <br>5) `get_official_accounts()` mengembalikan `id, username, display_name, avatar_url` (0057). |
| Keluaran | Badge dan perilaku akun resmi di aplikasi. |
| Kode error | `403 official_no_dm` (dari jalur chat) |
| Antarmuka | RPC `get_official_accounts`, `get_profile`; Library: `initialize(onOfficialContact:)`, `OfficialBadge`, `ProfileRepository.officialAccountIds` |
| Lacak | BR-KOM |

#### FR-KOM-50 Postingan resmi tersemat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan postingan atau pengumuman resmi yang disematkan di atas Stream atau feed saham. |
| Aktor | Nasabah |
| Prakondisi | Postingan resmi terbit dan disematkan dari Hub (lihat FR-HUB). |
| Proses dan aturan | 1) `get_pinned_posts(p_scope, p_stock_code)`: `global` atau `stock` dengan kode saham (0057). <br>2) Hanya status `published`, belum dilepas, `pin_until` kosong atau belum lewat, postingan tidak terhapus dan `visible`. <br>3) Pengumuman didahulukan, lalu terbit terbaru; maksimal 3. |
| Keluaran | `table(kind, title, pinned_until, post)`. |
| Kode error | — |
| Antarmuka | RPC `get_pinned_posts`; Library: `CommunityStreamFeed`, `CommunityStockFeed` (penanda sematan di `CommunityFeedBuilders`) |
| Lacak | BR-KOM |

#### FR-KOM-51 Daftar indeks

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan daftar indeks aktif beserta alias untuk label, saran `$`, dan menu Indeks. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) `get_market_instruments()` mengembalikan `code, kind, name, description, aliases, position, room_enabled` untuk instrumen aktif (0150). <br>2) Daftar awal 46 indeks IDX dengan urutan OLT, mis. COMPOSITE, LQ45, JII (0153); alias seperti `IHSG`/`JCI` untuk COMPOSITE. <br>3) Instrumen nonaktif tidak tampil tetapi kodenya tetap dikenali untuk tag. <br>4) Pengelolaan instrumen ada di FR-HUB. |
| Keluaran | Daftar instrumen. |
| Kode error | `401 not_authenticated` |
| Antarmuka | RPC `get_market_instruments`; Library: `CommunityIndexList`, `CommunityInstruments.of(context)` |
| Lacak | BR-KOM |

#### FR-KOM-52 Stream indeks

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan stream satu indeks dengan header berlabel Indeks. |
| Aktor | Nasabah |
| Prakondisi | Indeks aktif. |
| Proses dan aturan | 1) `CommunityIndexFeed(indexCode:)` memakai feed saham dengan kode utama indeks (FR-KOM-04). <br>2) Header berisi label Indeks, alias, tombol Pantau, dan Diskusi (room indeks, lihat FR-CHAT). <br>3) Ketukan `$KODE` indeks memanggil `onIndexTap`, fallback `onStockTap`. |
| Keluaran | Stream indeks. |
| Kode error | — |
| Antarmuka | Library: `CommunityIndexFeed`, `onIndexTap` |
| Lacak | BR-KOM |

#### FR-KOM-53 Normalisasi kode saham dan indeks

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menormalkan semua kode saham dan indeks ke bentuk utama di setiap titik masuk. |
| Aktor | Database |
| Prakondisi | — |
| Proses dan aturan | 1) Format kode 2–24 karakter `^[A-Z][A-Z0-9]{0,19}(-[A-Z0-9]{1,19})*$` (`private.stock_code_format`, 0150). <br>2) `private.stock_code` membuang `$` dan spasi, mengubah ke huruf besar, memetakan alias ke kode utama, dan hanya menerima kode biasa `^[A-Z][A-Z0-9]{1,11}$` atau instrumen terdaftar. <br>3) Dipakai di tag postingan, feed, pantau, bisukan, room, kartu saham, sentimen, statistik, sematan, segmen kampanye, dan target push integrasi. <br>4) Server tidak memvalidasi keberadaan saham; validasi kode yang benar-benar ada tugas aplikasi OLT. |
| Keluaran | Kode utama yang konsisten. |
| Kode error | `400 invalid_stock_code` |
| Antarmuka | Fungsi `private.stock_code`; Library: `resolveCashtagToken`, `normalizeStockCode`, `CommunityInstruments.canonical` |
| Lacak | BR-KOM |

#### FR-KOM-54 Pantau saham

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah memantau dan berhenti memantau kode saham atau indeks. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) Pantau lewat REST `INSERT public.stock_watchers (user_id, stock_code)`; berhenti lewat `DELETE`; hanya baris milik sendiri (RLS, 0002). <br>2) Trigger `stock_watchers_05_canonical_code` menormalkan kode dan menolak kode tidak valid (0150). <br>3) Jumlah pemantau dihitung langsung dari tabel (`get_stock`). <br>4) Saham pantauan dipakai ringkasan harian (lihat FR-NOTIF) dan feed watchlist (FR-KOM-04). <br>5) Library memakai optimistic update. |
| Keluaran | Status `watching` terbaru. |
| Kode error | `400 invalid_stock_code` |
| Antarmuka | REST `public.stock_watchers`; Library: `StockRepository`, tombol Pantau/Watch di `CommunityStockFeed` dan `CommunityIndexFeed` |
| Lacak | BR-KOM |

#### FR-KOM-55 Bisukan saham

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah membisukan kode saham agar postingan yang menandainya tidak muncul di feed umum. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial aktif. |
| Proses dan aturan | 1) Bisukan lewat REST `public.muted_stocks (user_id, stock_code)`; hanya baris milik sendiri (RLS, 0015). <br>2) Kode dinormalkan trigger `muted_stocks_05_canonical_code` (0150). <br>3) Disaring di feed `global`, `following`, trending postingan, dan ringkasan watchlist; tidak di feed saham dan profil (0143). <br>4) UI bisukan saham di library: perlu konfirmasi (library tidak memanggil tabel ini). |
| Keluaran | Feed tanpa saham yang dibisukan. |
| Kode error | `400 invalid_stock_code` |
| Antarmuka | REST `public.muted_stocks` |
| Lacak | BR-KOM |

#### FR-KOM-56 Halaman saham di Stream

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menyediakan tab diskusi saham dengan composer, jumlah pemantau, dan tautan ke data OLT, tanpa server menyimpan data saham. |
| Aktor | Nasabah, aplikasi OLT |
| Prakondisi | — |
| Proses dan aturan | 1) `get_stock(p_code)` mengembalikan `code, watcher_count, watching` untuk kode valid (0150). <br>2) Nama saham di header berasal dari parameter `stockName` milik OLT; harga dan grafik tetap di halaman saham OLT yang dibuka lewat `onStockTap`. <br>3) Di tab "Diskusi" halaman saham OLT, header disembunyikan (`showHeader: false`). <br>4) Tombol Chat `$KODE` membuka room saham (lihat FR-CHAT). <br>5) Ketukan dari sosial ke layar order dicatat lewat `trackOrderTap` (FR-KOM-59). |
| Keluaran | Tab diskusi saham. |
| Kode error | — |
| Antarmuka | RPC `get_stock`; Library: `CommunityStockFeed(stockCode:, stockName:, showHeader:)`, `onStockTap`, `showCommunityComposer(initialStock:)` |
| Lacak | BR-KOM |

#### FR-KOM-57 Saran `$KODE` dari data OLT

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menyarankan kode saham saat nasabah mengetik `$` dengan data dari aplikasi OLT. |
| Aktor | Library, aplikasi OLT |
| Prakondisi | Host mengisi `stockSearch`. |
| Proses dan aturan | 1) `stockSearch(query)` mengembalikan `List<StockSuggestion>` (kode + nama) dari daftar saham OLT. <br>2) Tanpa callback, `$KODE` tetap bisa diketik tanpa saran. <br>3) Indeks diambil dari `get_market_instruments` sehingga `stockSearch` tidak perlu memuat indeks. |
| Keluaran | Daftar saran di composer. |
| Kode error | — |
| Antarmuka | Library: `initialize(stockSearch:)`, `StockSuggestion` |
| Lacak | BR-KOM |

#### FR-KOM-58 Penerimaan event analitik klien

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima event analitik anonim dari aplikasi tanpa teks bebas. |
| Aktor | Library |
| Prakondisi | Flag `analytics` aktif. |
| Proses dan aturan | 1) `track_events(p_events, p_platform, p_app_version)` menerima array maksimal `analytics.max_batch` (bawaan 50) objek `{event, ts, props}` (0078, 0085). <br>2) Event yang diizinkan: `feed_open`, `post_create`, `comment_create`, `message_send`, `stock_tap`, `order_tap`, `search`, `share_chart`, `hide_room`, `delete_group`, `edit_message` (0154); event lain dihitung `dropped`. <br>3) Properti hanya whitelist (kode saham, UUID, `hashtag`, `filter`, `source`, `scope`, `type`, `side`, `interval`, bilangan, boolean); lainnya dibuang diam-diam (0152). <br>4) `ts` dipakai bila dalam 7 hari terakhir sampai 5 menit ke depan, selain itu waktu server. <br>5) Rate limit `analytics` 30 per menit dan 2000 per hari. <br>6) Retensi `analytics.retention_months` 12 bulan (lihat FR-OPS); laporan ada di FR-HUB. |
| Keluaran | `{accepted, dropped}` atau `{..., disabled: true}` bila flag mati. |
| Kode error | `400 invalid_events`; `400 too_many_events`; `400 invalid_platform`; `429 rate_limited` |
| Antarmuka | RPC `track_events` |
| Lacak | BR-KOM |

#### FR-KOM-59 Pencatatan analitik di library

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus mencatat event pemakaian komunitas secara batch dan berhenti mencatat saat analitik dimatikan. |
| Aktor | Library, aplikasi OLT |
| Prakondisi | — |
| Proses dan aturan | 1) Library mencatat `feed_open`, `post_create`, `comment_create`, `message_send`, `stock_tap`, `search`, dan `share_chart`. <br>2) Batch dikirim maksimal 50 event, tiap 60 detik, saat 20 event terkumpul, atau saat aplikasi ke latar belakang; batch gagal dibuang. <br>3) Bila server menjawab `disabled` atau flag `analytics` mati, pencatatan berhenti. <br>4) Teks postingan, pesan, dan kata kunci pencarian tidak pernah dikirim. <br>5) Host memanggil `trackOrderTap(stockCode:, side:, source:)` saat nasabah berpindah dari fitur komunitas ke layar order. |
| Keluaran | Event terkirim ke `track_events`. |
| Kode error | — |
| Antarmuka | Library: `CommunityAnalytics`, `RendezvousCommunity.instance.trackOrderTap` |
| Lacak | BR-KOM |

### 4.3 Chat (CHAT)

Modul ini mencakup chat sosial nasabah di dalam aplikasi OLT: pesan langsung (DM) beserta permintaan pesan, grup dengan peran owner/admin/member, dan room diskusi per saham atau indeks. Di dalamnya ada mekanisme pesan yang juga dipakai ulang oleh chat CS: kirim, balas, lampiran, reaksi, edit, hapus, info pesan, tanda terima, mengetik, presence, pengiriman realtime lewat Broadcast, pengisian celah, pratinjau daftar chat, dan antrean offline di library. Logika tiket CS ditulis di modul CS; di modul ini room CS (`type = 'support'`) hanya disebut sebagai room yang terkunci di server. Moderasi isi pesan (kata terlarang, kategori tautan, akun baru, slow mode dari sisi staf) ditulis di modul MOD.

#### FR-CHAT-01 Daftar room milik pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan daftar room yang diikuti pengguna, berhalaman, dengan ringkasan pesan terakhir, jumlah belum dibaca, dan status centang pesan terakhir. |
| Aktor | Nasabah (authenticated) |
| Prakondisi | Sesi sosial valid. |
| Proses dan aturan | 1) `get_my_rooms(p_cursor, p_limit)`: `p_limit` bawaan 30, dijepit 1–100; cursor `"<0\|1>\|<waktu>\|<id>"` (0154). <br>2) Urutan: room CS di atas, lalu `coalesce(last_message_at, created_at)` terbaru (0154). <br>3) Room DM yang masih permintaan pesan tidak tampil bagi penerima (`dm_request_hidden`), dan room yang disembunyikan (`hidden_at`) tidak tampil sampai ada pesan baru (0154). <br>4) Baris memuat tipe, nama (room CS memakai nama layanan CS), lawan bicara DM, `role`, `muted`, `unread_count` (maks. 100 dihitung), jumlah anggota, `description`, `avatar_url`, `only_admins_send`, `only_admins_edit` (dua terakhir hanya grup) (0146). <br>5) Status pesan terakhir milik sendiri: `sent`/`delivered`/`read`; room saham selalu `sent` (0154). <br>6) `get_my_room(p_room_id)` mengembalikan satu baris dengan aturan yang sama. |
| Keluaran | `setof chat_room_summary` |
| Kode error | `400 invalid_cursor` |
| Antarmuka | RPC `get_my_rooms`, `get_my_room`; Library: `CommunityChatList` (30 room per halaman, multi-panel pada lebar ≥ 840 px) |
| Lacak | BR-CHAT |

#### FR-CHAT-02 Membuka atau membuat DM

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan satu room DM tetap untuk setiap pasangan pengguna, dibuat saat pertama kali dibuka dan dipakai ulang selamanya. |
| Aktor | Nasabah |
| Prakondisi | Lawan bicara ada dan tidak saling blokir. |
| Proses dan aturan | 1) `get_or_create_direct_room(p_other_user_id)` memakai `direct_key = "<uuid kecil>:<uuid besar>"` unik (0008, 0154). <br>2) Tidak boleh dengan diri sendiri; pasangan yang saling blokir ditolak. <br>3) DM baru ke akun resmi ditolak, DM lama tetap dikembalikan (0144). <br>4) Bila belum ada catatan permintaan, kebijakan DM penerima dievaluasi (FR-CHAT-03); hasil `denied` ditolak. <br>5) Memanggil ulang memunculkan lagi room yang disembunyikan pemanggil (`hidden_at = null`), tetapi riwayat sebelum `cleared_at` tetap kosong (0154). <br>6) Pembuatan room DM/grup dibatasi `room_create` 10/jam per pengguna (0012). |
| Keluaran | `uuid` room |
| Kode error | `401 not_authenticated`; `400 invalid_user`; `404 user_not_found`; `403 blocked`; `403 official_no_dm`; `403 dm_not_allowed`; `429 rate_limited` |
| Antarmuka | RPC `get_or_create_direct_room`; Library: tombol Kirim pesan di profil, `CommunityChatRoom` |
| Lacak | BR-CHAT |

#### FR-CHAT-03 Evaluasi kebijakan DM dan permintaan pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menentukan apakah DM pertama langsung diterima, menjadi permintaan pesan, atau ditolak, berdasarkan kebijakan DM penerima dan hubungan ikut. |
| Aktor | Sistem (trigger), Nasabah |
| Prakondisi | Room `direct`, pesan bukan chat CS (`session_id is null`). |
| Proses dan aturan | 1) `private.dm_evaluate`: pengirim atau penerima staf/akun resmi (`safety_exempt`) → `accepted` (0070). <br>2) Kebijakan penerima `none`, atau `following` sementara penerima tidak mengikuti pengirim → `denied`. <br>3) Penerima mengikuti pengirim → `accepted`, kecuali pengirim akun baru (`safety.new_account_days`, 0187) yang harus saling mengikuti. <br>4) Selain itu → `pending` di `private.dm_requests`. <br>5) Trigger `messages_27_dm_request` menegakkan hal yang sama untuk setiap pesan; balasan dari penerima otomatis menerima permintaan (0070). <br>6) DM yang sudah ada sebelum 0070 dianggap diterima. <br>7) Pengaturan kebijakan DM (`set_dm_policy`) ditulis di modul AKUN. |
| Keluaran | Status permintaan `pending`/`accepted`/`declined` |
| Kode error | `403 dm_not_allowed` |
| Antarmuka | Trigger `messages_27_dm_request`; RPC `get_dm_policy` (membawa `request_max_messages`) |
| Lacak | BR-CHAT |

#### FR-CHAT-04 Batas pesan sebelum permintaan diterima

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi jumlah pesan yang bisa dikirim pengirim permintaan pesan sebelum penerima menerimanya, dan memberi tahu status permintaan di dalam room. |
| Aktor | Nasabah (pengirim dan penerima) |
| Prakondisi | Permintaan berstatus `pending`. |
| Proses dan aturan | 1) Batas `dm.request_max_messages` bawaan 3 pesan (0070). <br>2) Pesan ke-4 ditolak sampai diterima; kirim ulang dengan `client_id` yang sama tetap idempoten. <br>3) `get_dm_request_state(p_room_id)` → `{is_request:false}` atau `{is_request, role: sender\|recipient, status, sent, max_messages}` (0085). <br>4) Library menampilkan "Pesan Anda masih berupa permintaan (n/3)" kepada pengirim dan tombol Terima kepada penerima. |
| Keluaran | Pesan diterima atau ditolak; status permintaan |
| Kode error | `403 dm_request_limit`; `404 room_not_found`; `401 not_authenticated` |
| Antarmuka | RPC `get_dm_request_state`; Library: `CommunityChatRoom` |
| Lacak | BR-CHAT |

#### FR-CHAT-05 Kotak permintaan pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan daftar dan jumlah permintaan pesan yang belum direspons, terpisah dari daftar chat. |
| Aktor | Nasabah (penerima) |
| Prakondisi | — |
| Proses dan aturan | 1) `get_message_requests(p_limit, p_before)`: bawaan 50, maks. 100, urut terbaru; berisi profil pengirim, `message_count`, `has_image`, cuplikan 120 karakter (`[lampiran]` bila tanpa teks) (0070). <br>2) Hanya pesan `visible` yang belum dihapus dihitung; pasangan yang saling blokir disembunyikan. <br>3) `get_message_request_count()` untuk badge. <br>4) Room permintaan tidak dihitung di `get_unread_counts` dan `get_unread_chat_count`. <br>5) Klien memburamkan gambar di room permintaan sampai diterima. |
| Keluaran | Daftar permintaan; jumlah |
| Kode error | — |
| Antarmuka | RPC `get_message_requests`, `get_message_request_count`; Library: `CommunityMessageRequests`, `MessageRequestsEntry`, `openCommunityMessageRequests` |
| Lacak | BR-CHAT |

#### FR-CHAT-06 Merespons permintaan pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan penerima menerima, menolak, atau memblokir dan melaporkan pengirim permintaan pesan. |
| Aktor | Nasabah (penerima) |
| Prakondisi | Permintaan `pending` atau `declined` milik pemanggil. |
| Proses dan aturan | 1) `respond_message_request(p_room_id, p_action)` dengan `accept`, `decline`, atau `block` (0070). <br>2) `decline`: permintaan disembunyikan, pengirim tidak diberi tahu. <br>3) `block`: status `declined`, baris `blocks` dibuat, dan laporan `user` beralasan `spam` masuk antrean moderator. <br>4) Permintaan yang pernah ditolak tetap ditolak walau pengirim menghapus akun lalu login lagi (0174). |
| Keluaran | `{room_id, status, blocked}` |
| Kode error | `401 not_authenticated`; `400 invalid_action`; `404 request_not_found` |
| Antarmuka | RPC `respond_message_request`; Library: aksi Terima / Tolak / Blokir & laporkan di `CommunityMessageRequests` |
| Lacak | BR-CHAT |

#### FR-CHAT-07 Akun resmi tidak menerima DM dari pengguna biasa

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak DM baru, keanggotaan grup, dan pesan dari pengguna biasa ke akun resmi aktif, sambil tetap mengizinkan akun resmi memulai percakapan. |
| Aktor | Nasabah, akun resmi |
| Prakondisi | Target adalah baris aktif `cs.official_accounts` (0144). |
| Proses dan aturan | 1) `get_or_create_direct_room` ke akun resmi tanpa room lama ditolak (0144). <br>2) `create_group_room` dan `add_room_members` yang menyertakan akun resmi ditolak seluruhnya. <br>3) Trigger `messages_26a_official_no_dm` menolak pesan ke DM dengan akun resmi; kirim ulang `client_id` lama tetap idempoten; riwayat tetap terbaca. <br>4) Dikecualikan: akun resmi itu sendiri, staf, `service_role`. Akun yang hanya terverifikasi tidak terpengaruh. Akun resmi nonaktif kembali bisa di-DM. |
| Keluaran | Penolakan dengan pesan "Akun resmi tidak menerima pesan langsung. Hubungi CS untuk bantuan." |
| Kode error | `403 official_no_dm` |
| Antarmuka | RPC `get_or_create_direct_room`, `create_group_room`, `add_room_members`; trigger `messages_26a_official_no_dm` |
| Lacak | BR-CHAT |

#### FR-CHAT-08 Membuat grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan nasabah membuat grup dengan dirinya sebagai owner dan anggota awal pilihannya. |
| Aktor | Nasabah |
| Prakondisi | Sesi valid. |
| Proses dan aturan | 1) `create_group_room(p_name, p_member_ids)`: nama 1–80 karakter setelah dirapikan (0008, 0144). <br>2) Pembuat menjadi `owner`; anggota yang saling blokir dengan pembuat dilewati diam-diam; maks. 99 anggota awal (total 100). <br>3) Akun resmi dalam daftar → seluruh panggilan ditolak (0144). <br>4) Bawaan pengaturan grup: `only_admins_send = false`, `only_admins_edit = true` (0146). <br>5) Rate limit `room_create` 10/jam. |
| Keluaran | `uuid` room grup |
| Kode error | `401 not_authenticated`; `400 invalid_name`; `403 official_no_dm`; `429 rate_limited` |
| Antarmuka | RPC `create_group_room`; Library: `CommunityChatList` |
| Lacak | BR-CHAT |

#### FR-CHAT-09 Menambah anggota grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan owner dan admin menambah anggota grup sampai batas ukuran grup. |
| Aktor | Owner, admin grup |
| Prakondisi | Room `group`, pemanggil berperan `owner` atau `admin`. |
| Proses dan aturan | 1) `add_room_members(p_room_id, p_user_ids)` (0146). <br>2) Pengguna yang saling blokir dengan pemanggil dilewati; akun resmi menolak seluruh panggilan. <br>3) Batas 100 anggota: syarat `count(*) < 100` dievaluasi terhadap jumlah anggota sebelum panggilan, sehingga satu panggilan berisi banyak pengguna bisa melewati 100 (perlu konfirmasi apakah batas keras 100 dikehendaki). <br>4) Bila ada yang ditambahkan, ditulis pesan sistem `added` dengan `targets` (maks. 20) dan `count`. |
| Keluaran | `integer` jumlah anggota yang benar-benar ditambahkan |
| Kode error | `404 room_not_found`; `403 forbidden`; `403 official_no_dm` |
| Antarmuka | RPC `add_room_members`; Library: `CommunityGroupInfo` (Tambah anggota) |
| Lacak | BR-CHAT |

#### FR-CHAT-10 Mengeluarkan anggota grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan owner mengeluarkan siapa pun selain dirinya dan admin mengeluarkan anggota biasa, dengan pencabutan akses seketika. |
| Aktor | Owner, admin grup |
| Prakondisi | Pemanggil dan target anggota grup. |
| Proses dan aturan | 1) `remove_room_member(p_room_id, p_user_id)` (0146). <br>2) Diri sendiri ditolak, harus lewat `leave_room`. <br>3) Member tidak bisa mengeluarkan siapa pun; admin hanya bisa mengeluarkan `member`. <br>4) Pesan sistem `removed` (`target_id`, `target_name`) ditulis sebelum keanggotaan dihapus. <br>5) Anggota yang dikeluarkan langsung kehilangan akses `get_messages` dan `send_message`. |
| Keluaran | — |
| Kode error | `401 not_authenticated`; `404 room_not_found`; `403 not_member`; `400 use_leave_room`; `404 member_not_found`; `403 forbidden` |
| Antarmuka | RPC `remove_room_member`; Library: menu anggota di `CommunityGroupInfo` |
| Lacak | BR-CHAT |

#### FR-CHAT-11 Mengubah peran admin dan member

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan owner dan admin menjadikan anggota admin, dan hanya owner yang mencabut status admin. |
| Aktor | Owner, admin grup |
| Prakondisi | Target anggota grup dan bukan owner. |
| Proses dan aturan | 1) `set_room_member_role(p_room_id, p_user_id, p_role)`; `p_role` hanya `admin` atau `member` (0146). <br>2) Jadikan `admin`: owner atau admin. Jadikan `member`: hanya owner. <br>3) Peran owner tidak bisa diubah lewat RPC ini. <br>4) Peran yang sama tidak menulis event; selain itu ditulis `promoted` atau `demoted`. |
| Keluaran | — |
| Kode error | `400 invalid_role`; `404 member_not_found`; `403 forbidden`; `403 not_member`; `404 room_not_found` |
| Antarmuka | RPC `set_room_member_role`; Library: `CommunityGroupInfo` |
| Lacak | BR-CHAT |

#### FR-CHAT-12 Memindahkan kepemilikan grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan owner memindahkan kepemilikan grup ke anggota lain. |
| Aktor | Owner grup |
| Prakondisi | Target anggota grup selain owner. |
| Proses dan aturan | 1) `transfer_room_ownership(p_room_id, p_user_id)` (0146). <br>2) Owner lama menjadi `admin`, target menjadi `owner`. <br>3) Ditulis pesan sistem `owner_changed`. |
| Keluaran | — |
| Kode error | `403 forbidden`; `400 invalid_target`; `404 member_not_found` |
| Antarmuka | RPC `transfer_room_ownership`; Library: `CommunityGroupInfo` |
| Lacak | BR-CHAT |

#### FR-CHAT-13 Mengubah info grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan perubahan nama, deskripsi, dan foto grup sesuai pengaturan siapa yang boleh mengubah info. |
| Aktor | Owner, admin; semua anggota bila `only_admins_edit = false` |
| Prakondisi | Pemanggil anggota grup. |
| Proses dan aturan | 1) `update_group_info(p_room_id, p_name, p_description, p_avatar_url)`; `null` = tidak diubah, `''` pada deskripsi/foto = hapus (0146). <br>2) Nama 1–80, deskripsi ≤ 500, foto `http(s)://` ≤ 500 karakter. <br>3) Setiap perubahan nyata menulis `renamed`, `description_changed`, atau `photo_changed` (`removed` boolean). <br>4) `update public.chat_rooms` langsung tidak lagi diizinkan (`grant update (name)` dicabut). |
| Keluaran | — |
| Kode error | `403 group_admins_only_edit`; `400 invalid_name`; `400 invalid_description`; `400 invalid_avatar` |
| Antarmuka | RPC `update_group_info`; Library: `CommunityGroupInfo`, slot `groupInfoPage` |
| Lacak | BR-CHAT |

#### FR-CHAT-14 Pengaturan grup hanya-admin

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan owner dan admin mengatur apakah hanya admin yang boleh mengirim pesan dan mengubah info grup, dan menegakkannya di server. |
| Aktor | Owner, admin grup |
| Prakondisi | Room `group`. |
| Proses dan aturan | 1) `update_group_settings(p_room_id, p_only_admins_send, p_only_admins_edit)`; `null` = tidak diubah (0146). <br>2) Setiap perubahan menulis `settings_changed` (`setting`, `value`). <br>3) Trigger `messages_26b_group_admins_only` menolak pesan anggota biasa di grup `only_admins_send`; kirim ulang `client_id` lama tetap idempoten. |
| Keluaran | — |
| Kode error | `403 forbidden`; `403 group_admins_only` |
| Antarmuka | RPC `update_group_settings`; trigger `messages_26b_group_admins_only`; Library: `CommunityGroupInfo` (Pengaturan) |
| Lacak | BR-CHAT |

#### FR-CHAT-15 Pesan sistem grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat setiap perubahan grup sebagai pesan sistem tanpa pengirim yang tampil di tengah chat dan tidak memicu notifikasi. |
| Aktor | Sistem |
| Prakondisi | Aksi kelola grup berhasil. |
| Proses dan aturan | 1) Baris `messages` dengan `kind = 'group_event'`, `sender_id = null`, `body` kalimat bahasa Indonesia (≤ 4000), `payload.event` salah satu `added`, `removed`, `promoted`, `demoted`, `owner_changed`, `left`, `renamed`, `description_changed`, `photo_changed`, `settings_changed`, beserta `actor_id`, `actor_name` (0146). <br>2) Dibuat dengan klaim JWT dikosongkan sementara, sehingga tidak terkena rate limit, persetujuan dokumen, dan filter pengirim. <br>3) Tetap disiarkan realtime dan dihitung belum dibaca, tetapi tidak membuat notifikasi atau push. <br>4) Library menerjemahkannya sesuai bahasa aplikasi. |
| Keluaran | Pesan `group_event` |
| Kode error | — |
| Antarmuka | `private.post_group_event`; Library: `GroupEventNotice`, `groupEventText`, `MessageKind.groupEvent` |
| Lacak | BR-CHAT |

#### FR-CHAT-16 Keluar room

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan anggota keluar dari grup atau room saham, mewariskan kepemilikan grup bila owner keluar, dan memberi tahu perangkat lain pengguna yang sama. |
| Aktor | Nasabah |
| Prakondisi | Pemanggil anggota room. |
| Proses dan aturan | 1) `leave_room(p_room_id)`; DM tidak bisa ditinggalkan, room CS ditolak (0157). <br>2) Owner yang keluar digantikan admin paling lama, lalu anggota paling lama; pesan sistem `left` membawa `new_owner_id`/`new_owner_name` bila kepemilikan pindah. <br>3) Owner yang merupakan anggota terakhir: room grup dihapus. <br>4) Event `room_removed` (`reason: left`) dikirim ke topik `user:<uid>` (0157). |
| Keluaran | — |
| Kode error | `404 not_member`; `400 cannot_leave_direct`; `400 cannot_leave_support` |
| Antarmuka | RPC `leave_room`; Library: Keluar grup di `CommunityGroupInfo` |
| Lacak | BR-CHAT |

#### FR-CHAT-17 Menghapus grup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan owner menghapus grup beserta seluruh pesannya dengan tetap menyimpan arsip untuk regulator. |
| Aktor | Owner grup |
| Prakondisi | Room `group`, pemanggil `owner`. |
| Proses dan aturan | 1) `delete_group(p_room_id)` (0154). <br>2) Pesan non-sistem yang belum dihapus diarsipkan ke `private.content_archive`. <br>3) Audit `chat.group_delete` dengan nama, jumlah anggota, dan jumlah pesan yang diarsipkan. <br>4) Event `room_deleted` ke `room:<id>` dan `room_removed` (`reason: group_deleted`, `actor_id`, `actor_name`) ke `user:<uid>` setiap anggota. <br>5) Notifikasi `message` room itu dihapus, lalu room dihapus. |
| Keluaran | — |
| Kode error | `401 not_authenticated`; `404 room_not_found`; `400 not_group`; `403 forbidden` |
| Antarmuka | RPC `delete_group`; Library: `CommunityGroupInfo` |
| Lacak | BR-CHAT |

#### FR-CHAT-18 Bergabung ke room saham atau indeks

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat room diskusi per kode saham atau indeks secara otomatis dan menambahkan pemanggil sebagai anggota. |
| Aktor | Nasabah |
| Prakondisi | Kode berformat valid. |
| Proses dan aturan | 1) `join_stock_room(p_stock_code)`; kode dinormalkan lewat `private.stock_code` (format saham atau instrumen berstrip, alias ke kode utama) (0150, 0154). <br>2) Instrumen dengan `room_enabled = false` ditolak. <br>3) Room baru dibatasi `stock_room_create` 20/jam per pengguna (0037). <br>4) Room yang disembunyikan pemanggil muncul lagi (`hidden_at = null`). <br>5) Room saham dapat ditemukan semua pengguna login (RLS `chat_rooms_select`). |
| Keluaran | `uuid` room |
| Kode error | `401 not_authenticated`; `400 invalid_stock_code`; `403 room_disabled`; `429 rate_limited` |
| Antarmuka | RPC `join_stock_room`; Library: `CommunityChatRoom` dari `CommunityStockFeed` |
| Lacak | BR-CHAT |

#### FR-CHAT-19 Status room saham dari sisi pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi pengguna status room saham: slow mode efektif, waktu tunggu miliknya, pesan tersemat, moderator room, dan bisu miliknya. |
| Aktor | Nasabah |
| Prakondisi | Kode valid. |
| Proses dan aturan | 1) `get_stock_room_state(p_code)` → `stock_code`, `room_id`, `room_enabled`, `slow_mode {seconds, until, source}`, `wait_seconds`, `pinned_message`, `pinned_at`, `moderators`, `is_moderator`, `muted_until` (0150). <br>2) Slow mode efektif = terbesar dari pengaturan moderator, slow mode alert manipulasi, dan jam ramai `rooms.busy_slow_mode` 10 dtk pada `rooms.busy_windows` WIB di hari bursa (content-safety.md §8). <br>3) Pesan terlalu cepat ditolak dengan detik tunggu dan header `Retry-After`; akun resmi tidak terkena. <br>4) `mutes` hanya dikirim ke moderator room; siaran `room_state` tidak pernah memuat bisu (0096). <br>5) Perubahan disiarkan sebagai event `room_state` ke `room:<id>`. Pengaturan slow mode, sematan, dan moderator oleh staf ditulis di modul MOD. |
| Keluaran | `jsonb` status room |
| Kode error | `401 not_authenticated`; `400 invalid_stock_code`; `429 slow_mode`; `403 room_muted` |
| Antarmuka | RPC `get_stock_room_state`; event `room_state`; Library: `CommunityChatRoom` (banner slow mode, hitung mundur tombol kirim, pesan tersemat), `RoomModerationBanner`, `RoomModeratorBadge` |
| Lacak | BR-CHAT |

#### FR-CHAT-20 Mengirim pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan pesan baru secara idempoten per `client_id` dan mengembalikan baris pesan lengkap untuk tampilan pengirim. |
| Aktor | Nasabah |
| Prakondisi | Pemanggil anggota room dan tidak saling blokir dengan lawan bicara DM (`private.can_send_message`). |
| Proses dan aturan | 1) `send_message(p_room_id, p_body, p_client_id, p_reply_to_id, p_attachments)` (0008). <br>2) Isi dirapikan; maks. 4000 karakter; pesan harus berisi teks atau minimal satu lampiran; maks. 4 lampiran (constraint `messages_content`, `messages_attachments`). <br>3) `(sender_id, client_id)` unik: kirim ulang mengembalikan pesan yang sama. <br>4) Urutan trigger: rate limit `message` 30/menit (dikali faktor akun baru) → rapikan dan validasi lampiran → integritas (mute/ban, persetujuan dokumen, batas tautan/mention) → slow mode → akun resmi → grup hanya-admin → permintaan DM → kata terlarang → keamanan konten (content-safety.md §1). <br>5) Kill switch sosial menolak pesan non-CS (0109); dokumen wajib yang belum disetujui menolak pesan non-CS. <br>6) Konten yang ditahan tersimpan `held` dan hanya terlihat pengirim; di DM/grup aksi `hold` diperlakukan sebagai `block`. |
| Keluaran | `setof chat_message` (termasuk `moderation_status` untuk pengirim) |
| Kode error | `401 not_authenticated`; `403 cannot_send`; `400 body_too_long`; `429 rate_limited`; `422 content_blocked`; `422 link_blocked`; `422 contact_blocked`; `403 consent_required`; `403 social_disabled`; `403 dm_not_allowed`; `403 dm_request_limit`; `403 group_admins_only`; `403 official_no_dm`; `429 slow_mode` |
| Antarmuka | RPC `send_message`; Library: `CommunityChatRoom`, `ChatRoomCubit` (optimistic send) |
| Lacak | BR-CHAT |

#### FR-CHAT-21 Membalas pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pesan membalas pesan lain di room yang sama dan menampilkan kutipannya. |
| Aktor | Nasabah |
| Prakondisi | Pesan yang dibalas ada di room yang sama. |
| Proses dan aturan | 1) `p_reply_to_id` pada `send_message`; pesan dari room lain ditolak (0090). <br>2) Baris pesan memuat `reply_to_body` (cuplikan 200 karakter) dan `reply_to_sender_username`; kutipan kosong bila pesan asal dihapus atau berada sebelum `cleared_at` pemanggil (0154). <br>3) Library: kartu "sedang membalas" di kolom input, geser untuk membalas, ketuk kutipan menggulir ke pesan asli. |
| Keluaran | Pesan dengan referensi balasan |
| Kode error | `400 invalid_reply` |
| Antarmuka | RPC `send_message`; Library: `CommunitySwipeToReplyScope`, `CommunitySwipeToReplySettings` |
| Lacak | BR-CHAT |

#### FR-CHAT-22 Lampiran gambar di chat global

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus hanya menerima lampiran gambar di DM, grup, dan room saham, diunggah lewat media gateway ke folder room pengirim. |
| Aktor | Nasabah |
| Prakondisi | File sudah diunggah lewat layanan `media` ke `attachments/rooms/<room>/<user>/`. |
| Proses dan aturan | 1) `private.check_message_media`: di room non-CS hanya bucket `attachments` dengan MIME JPEG, PNG, WebP, GIF, maks. 5 MB; selain itu ditolak (0053, 0138). <br>2) Path wajib berawalan `rooms/<room_id>/<sender_id>/` (`validate_attachments`). <br>3) Nama file maks. 200 karakter. <br>4) Akun baru tidak boleh melampirkan gambar (modul MOD, 0187). <br>5) Library: maks. 4 lampiran per pesan dalam antrean di atas kolom input, HEIC/HEIF diubah ke JPEG di perangkat, tempel gambar dengan Ctrl+V; lampiran tidak masuk outbox offline. <br>6) Lampiran chat CS (dokumen, video) ditulis di modul CS. |
| Keluaran | Pesan berlampiran gambar |
| Kode error | `400 attachment_not_allowed`; `400 attachment_too_large`; `400 invalid_attachments`; `403 new_account_restricted` |
| Antarmuka | `POST /media/v1/object/attachments/...`; RPC `send_message`; Library: composer `CommunityChatRoom` dengan `CommunityAttachmentPolicy.imagesOnly`, `showCommunityImageViewer` |
| Lacak | BR-CHAT |

#### FR-CHAT-23 Membagikan postingan ke chat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan postingan dibagikan ke DM, grup, atau room saham sebagai kartu yang dihitung ulang untuk setiap penonton. |
| Aktor | Nasabah |
| Prakondisi | Postingan terlihat oleh pengirim; flag `share_post_to_chat` aktif di klien. |
| Proses dan aturan | 1) Lampiran `{"type":"post","post_id"}` lewat `send_message` atau `share_post_to_chat(p_room_id, p_post_id, p_body, p_client_id)` (0075). <br>2) Maks. satu postingan per pesan, boleh digabung gambar dan kartu saham, total ≤ 4; dinormalkan menjadi persis `{type, post_id}`. <br>3) Postingan harus ada, belum dihapus, terlihat, tidak saling blokir dengan penulisnya; tidak bisa ke chat CS. <br>4) `shared_post` per penonton: `available:true` dengan cuplikan ≤ 280 karakter dan statistik, atau `available:false` bila dihapus/ditahan/disembunyikan/saling blokir; `comment_count` disembunyikan saat komentar mati (0169). |
| Keluaran | `setof chat_message` dengan `shared_post` |
| Kode error | `400 share_not_allowed`; `400 invalid_attachments`; `404 post_not_found` |
| Antarmuka | RPC `share_post_to_chat`, `send_message`; Library: `showSharePostToChat`, `SharedPostCard` |
| Lacak | BR-CHAT |

#### FR-CHAT-23a Membagikan postingan ke beberapa tujuan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan satu postingan dibagikan ke beberapa orang, grup, atau room saham sekaligus, dengan batas anti-spam yang ditegakkan server. |
| Aktor | Nasabah |
| Prakondisi | Postingan terlihat oleh pengirim |
| Proses dan aturan | 1) `search_share_targets` mencari orang (tanpa saling blokir, tamu, staf, akun resmi bagi pengguna biasa), grup yang diikuti, dan kode saham/indeks; setiap baris membawa `can_send` dan `reason` (0198). <br>2) `share_post_to_targets` menerima maks. 10 tujuan (konstanta server, `400 too_many_targets`), masing-masing dengan `client_id` untuk idempotensi. <br>3) Tujuan orang mengikuti aturan DM (kebijakan DM, permintaan pesan, akun resmi), tujuan saham mengikuti `join_stock_room`, tujuan room harus chat yang diikuti dan bukan chat CS. <br>4) Setiap tujuan diproses terpisah; kegagalan satu tujuan tidak membatalkan yang lain. <br>5) Kuota `post_share` 60 tujuan per jam per pengguna; cek konten berulang dilewati di dalam satu panggilan. <br>6) `get_share_limits` membuka batas ke klien. |
| Keluaran | Satu baris per tujuan: `status` `sent`/`failed`, `error_code`, `room_id`, `message_id` |
| Kode error | `400 too_many_targets`, `400 invalid_targets`; per tujuan `invalid_target`, `duplicate_target`, `not_member`, `blocked`, `dm_not_allowed`, `official_no_dm`, `room_disabled`, `group_admins_only`, `rate_limited` |
| Antarmuka | RPC `search_share_targets`, `share_post_to_targets`, `get_share_limits` |
| Lacak | BR-CHAT |

#### FR-CHAT-24 Kartu saham di chat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengiriman kartu saham atau indeks di chat non-CS tanpa menyimpan harga di server. |
| Aktor | Nasabah |
| Prakondisi | Room `direct`, `group`, atau `stock`. |
| Proses dan aturan | 1) Lampiran `{"type":"stock","code"}`; kode dinormalkan `private.stock_code` (alias ke kode utama), maks. 3 kode unik per pesan (0150). <br>2) Kunci lain (mis. harga) dibuang; urutan tersimpan: gambar, postingan, kartu saham (0090). <br>3) Ditolak di chat CS. <br>4) Nama dan harga diambil klien dari aplikasi OLT (`stockInfo`); `initialize(chatStockCards: false)` menyembunyikan tombolnya. |
| Keluaran | Pesan berlampiran kartu saham |
| Kode error | `400 share_not_allowed`; `400 invalid_attachments` |
| Antarmuka | RPC `send_message`; Library: `showStockCardPicker`, `StockCards`, `StockCardTile`, builder `CommunityChatBuilders(stockCard:)` |
| Lacak | BR-CHAT |

#### FR-CHAT-25 Mengedit pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengirim mengedit pesan teks miliknya dalam jendela waktu tertentu, dengan riwayat versi lama disimpan. |
| Aktor | Nasabah (pengirim) |
| Prakondisi | Pemanggil anggota room dan pengirim pesan. |
| Proses dan aturan | 1) `edit_message(p_message_id, p_body)` (0154). <br>2) Hanya pesan `kind = 'text'` tanpa lampiran yang belum dihapus; pesan CS terkunci. <br>3) Batas waktu `content.edit_minutes` bawaan 15 menit. <br>4) Isi baru: tidak kosong, ≤ 4000, melewati kata terlarang dan keamanan konten; rate limit `content_edit` 20/menit; mention baru tidak mengirim notifikasi. <br>5) Versi lama ke `private.content_edits` (`target_type = 'message'`, retensi `retention.archive_days` 1825). <br>6) Trigger `messages_22_edit` menegakkan aturan yang sama untuk `UPDATE` langsung. <br>7) Event `message` membawa isi baru dan `edited_at`; bila pesan terakhir, pratinjau berubah dan event `message_edited` dikirim. |
| Keluaran | `setof chat_message` terbaru |
| Kode error | `401 not_authenticated`; `404 not_found`; `403 forbidden`; `409 support_message_locked`; `400 not_editable`; `409 edit_window_closed`; `400 empty_body`; `400 body_too_long`; `429 rate_limited` |
| Antarmuka | RPC `edit_message`; Library: menu Edit pesan, label "(diedit)" |
| Lacak | BR-CHAT |

#### FR-CHAT-26 Menghapus pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengirim menghapus pesannya untuk semua anggota dengan isi asli tetap diarsipkan. |
| Aktor | Nasabah (pengirim) |
| Prakondisi | Pesan belum dihapus. |
| Proses dan aturan | 1) `delete_message(p_message_id)`: soft delete, `body = ''`, `attachments = '[]'` (0031). <br>2) Isi asli ke `private.content_archive`. <br>3) Pesan CS (`session_id` terisi) ditolak. <br>4) Event `message` disiarkan tanpa `body`, `attachments`, `payload`. <br>5) Bila pesan terakhir room, trigger `messages_62_delete_preview` mengganti pratinjau menjadi `[pesan dihapus]` dan mengirim `room_activity` ke anggota DM/grup (0179). |
| Keluaran | — |
| Kode error | `404 not_found`; `403 forbidden`; `409 support_message_locked` |
| Antarmuka | RPC `delete_message`; Library: menu Hapus pesan |
| Lacak | BR-CHAT |

#### FR-CHAT-27 Reaksi pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan satu reaksi emoji per orang per pesan dari daftar tetap dan menyiarkan total terbarunya. |
| Aktor | Nasabah |
| Prakondisi | Pesan terlihat oleh pemanggil; flag `message_reactions` aktif di klien. |
| Proses dan aturan | 1) `react_to_message(p_message_id, p_emoji)`; emoji tetap enam: U+1F44D (jempol), U+2764 U+FE0F (hati), U+1F602 (tertawa), U+1F62E (terkejut), U+1F622 (sedih), U+1F525 (api); U+2764 tanpa variation selector dinormalkan (0075). <br>2) Emoji sama dengan yang aktif = lepas; emoji lain = ganti; `null` = lepas. <br>3) Event `reaction` ke `room:<id>`: `{message_id, user_id, emoji, reactions:[{emoji, count}]}`. <br>4) Tidak tersedia di chat CS. Rate limit `message_reaction` 60/menit. |
| Keluaran | `{message_id, emoji, reactions:[{emoji, count, me}]}` |
| Kode error | `400 reactions_not_supported`; `400 invalid_emoji`; `404 message_not_found`; `429 rate_limited` |
| Antarmuka | RPC `react_to_message`; event `reaction`; Library: `ReactionPicker`, `ReactionChips` |
| Lacak | BR-CHAT |

#### FR-CHAT-28 Info pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan kepada pengirim kapan pesannya terkirim ke perangkat dan dibaca setiap penerima. |
| Aktor | Nasabah (pengirim) |
| Prakondisi | Pemanggil pengirim pesan dan masih anggota room. |
| Proses dan aturan | 1) `get_message_info(p_message_id)` → `{message_id, sent_at, room_type, recipients:[{user_id, username, display_name, avatar_url, delivered, read, delivered_at, read_at}]}`, urut pembaca terakhir dulu (0122). <br>2) Berlaku di DM, grup, dan chat CS; room saham mengembalikan `recipients: []`. <br>3) Waktu dicatat trigger saat watermark naik; satu pembaruan mencatat maks. 1.000 pesan dari 14 hari terakhir; retensi 30 hari. <br>4) `delivered`/`read` dari watermark, jadi tetap benar meski waktunya tidak tersimpan (`*_at = null`). <br>5) Super Admin yang memantau tiket tidak pernah muncul sebagai pembaca. |
| Keluaran | `jsonb` info pesan |
| Kode error | `401 not_authenticated`; `404 message_not_found` |
| Antarmuka | RPC `get_message_info`; Library: dialog/bottom sheet Info pesan, slot `chat.messageInfo` |
| Lacak | BR-CHAT |

#### FR-CHAT-29 Tanda terkirim dan dibaca

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat watermark terkirim dan dibaca per anggota dan menyiarkannya agar pengirim melihat centang ala WhatsApp. |
| Aktor | Nasabah, Sistem |
| Prakondisi | Pemanggil anggota room. |
| Proses dan aturan | 1) `mark_rooms_delivered(p_room_ids)` menaikkan `last_delivered_at` untuk room non-saham yang punya pesan lebih baru (0018). <br>2) `mark_room_read(p_room_id)` menaikkan `last_read_at` dan `last_delivered_at`, serta menandai notifikasi `message` room itu terbaca. <br>3) Event `receipt` ke `room:<id>`, tidak untuk room saham. <br>4) Pesan sendiri otomatis terbaca dan terkirim bagi pengirim (0173). <br>5) Library: jam (mengirim), centang satu (sampai server), centang dua abu-abu (diterima perangkat), centang dua biru (dibaca); di grup naik setelah semua anggota; room saham hanya centang satu. |
| Keluaran | `integer` jumlah room yang diperbarui (`mark_rooms_delivered`) |
| Kode error | `401 not_authenticated`; `404 not_member` |
| Antarmuka | RPC `mark_rooms_delivered`, `mark_room_read`; event `receipt`; Library: `ReceiptIcon` |
| Lacak | BR-CHAT |

#### FR-CHAT-30 Jumlah pesan belum dibaca

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghitung pesan belum dibaca per room dan jumlah chat DM/grup yang punya pesan belum dibaca untuk badge tab Chat. |
| Aktor | Nasabah |
| Prakondisi | — |
| Proses dan aturan | 1) `get_unread_counts()` → `(room_id, unread_count)`; per room dihitung maks. 100, tanpa pesan sendiri, pesan dihapus, dan pesan sebelum `cleared_at`; room permintaan pesan dikecualikan (0154). <br>2) `get_unread_chat_count()` → jumlah room `direct`/`group` yang tidak dibisukan dan punya pesan belum dibaca; room saham tidak dihitung. <br>3) Library menampilkan `99+` bila lebih. |
| Keluaran | Tabel jumlah per room; `integer` |
| Kode error | — |
| Antarmuka | RPC `get_unread_counts`, `get_unread_chat_count`; Library: `CommunityChatBadge` |
| Lacak | BR-CHAT |

#### FR-CHAT-31 Membisukan room

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan anggota membisukan room sehingga pesan room itu tidak memberi notifikasi dan tidak dihitung di badge tab Chat. |
| Aktor | Nasabah |
| Prakondisi | Pemanggil anggota room. |
| Proses dan aturan | 1) Klien mengubah kolom `chat_members.muted` milik sendiri lewat REST (grant `update (last_read_at, muted)`, policy `chat_members_update_own`) (0008). <br>2) Anggota yang membisukan DM/grup tidak menerima notifikasi `message`, tetapi tetap menerima notifikasi `mention` bila disebut di grup (0173). <br>3) Bisu room tidak menahan mention di room saham (0087). <br>4) Tidak ada RPC khusus. |
| Keluaran | Baris `chat_members` diperbarui |
| Kode error | — |
| Antarmuka | REST `PATCH /rest/v1/chat_members`; Library: `ChatRepository.setMuted`, `ChatRoomCubit.setMuted` |
| Lacak | BR-CHAT |

#### FR-CHAT-32 Hapus chat untuk saya

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengguna menyembunyikan room dan mengosongkan riwayatnya hanya untuk dirinya, tersinkron ke perangkat lain. |
| Aktor | Nasabah |
| Prakondisi | Pemanggil anggota room bukan CS. |
| Proses dan aturan | 1) `hide_room(p_room_id)` mengisi `hidden_at` dan `cleared_at` milik pemanggil; untuk room `direct`, `group`, `stock` (0154). <br>2) Room tersembunyi tidak tampil sampai ada pesan baru; pesan `created_at <= cleared_at` tidak dikirim ke pengguna itu di semua RPC baca, pratinjau, kutipan, dan hitungan belum dibaca. <br>3) Room saham hanya disembunyikan; keanggotaan tetap. <br>4) Notifikasi `message`/`mention` room itu ditandai terbaca; event `room_removed` (`reason: hidden`) ke `user:<uid>`. <br>5) Kolom tidak bisa diubah langsung lewat tabel. |
| Keluaran | — |
| Kode error | `401 not_authenticated`; `404 not_member`; `400 cannot_hide_support` |
| Antarmuka | RPC `hide_room`; Library: menu daftar chat |
| Lacak | BR-CHAT |

#### FR-CHAT-33 Riwayat pesan berhalaman

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengembalikan riwayat pesan room berhalaman dengan cursor keyset, baik mundur maupun maju. |
| Aktor | Nasabah |
| Prakondisi | Pemanggil anggota room. |
| Proses dan aturan | 1) `get_messages(p_room_id, p_cursor, p_limit, p_after)`: `p_limit` bawaan 30, maks. 100; `p_cursor` = lebih lama, `p_after` = lebih baru; hasil selalu terbaru ke terlama (0154). <br>2) Pesan sebelum `cleared_at` dan pesan dari pengguna yang saling blokir (RLS) tidak dikembalikan. <br>3) Baris memuat `reactions` (dengan `me`), `shared_post`, `moderation_status` (hanya untuk pengirim), `kind`, `payload`, `edited_at`. <br>4) Library memuat 30 per halaman dan halaman lama saat scroll mendekati pesan tertua. |
| Keluaran | `setof chat_message` |
| Kode error | `403 not_member`; `400 invalid_cursor` |
| Antarmuka | RPC `get_messages`; Library: `CommunityChatRoom` |
| Lacak | BR-CHAT |

#### FR-CHAT-34 Pengiriman pesan realtime lewat Broadcast

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyiarkan pesan baru, diubah, dan dihapus dari database ke topik privat room tanpa memeriksa RLS per penerima. |
| Aktor | Sistem |
| Prakondisi | Klien sudah join topik `room:<room_id>` sebagai anggota. |
| Proses dan aturan | 1) Trigger `messages_60_broadcast` mengirim event `message` berbentuk `chat_message` tanpa kolom per penonton (0098). <br>2) Tabel `messages` dikeluarkan dari publikasi `supabase_realtime`. <br>3) Pesan `held`/`hidden` tidak disiarkan; pesan dihapus tanpa isi. <br>4) Bila pengirim terlibat blokir dengan anggota mana pun, yang disiarkan hanya referensi `{id, room_id, created_at, cursor, ref: true}` dan klien mengambil isinya lewat RPC. <br>5) Di room CS profil pengirim tidak disertakan. <br>6) Event lain di topik room: `message_hidden`, `message_edited`, `reaction`, `receipt`, `typing`, `typing_summary`, `room_state`, `room_deleted` (asyncapi.yaml). |
| Keluaran | Event Broadcast |
| Kode error | — |
| Antarmuka | Realtime topik `room:<room_id>` (docs/api/asyncapi.yaml); Library: koneksi room di `ChatRoomCubit` |
| Lacak | BR-CHAT |

#### FR-CHAT-35 Otorisasi topik realtime

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi siapa yang boleh menerima tiap topik realtime dan melarang klien menyiarkan event selain presence. |
| Aktor | Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) `room:<id>`: hanya anggota (`chat_members`) (0098). <br>2) `user:<id>`: hanya pemilik. <br>3) `cs:room:<id>`: nasabah pemilik dan staf yang boleh membaca room (detail di modul CS). <br>4) Kebijakan `olt_realtime_send` hanya mengizinkan `extension = 'presence'`, sehingga broadcast buatan klien (WebSocket maupun `POST /realtime/v1/api/broadcast`) tidak sampai ke anggota lain (temuan T2). <br>5) Realtime hanya memeriksa izin saat join. |
| Keluaran | Join diterima atau ditolak |
| Kode error | — |
| Antarmuka | Kebijakan RLS `realtime.messages`; Realtime |
| Lacak | BR-CHAT |

#### FR-CHAT-36 Aktivitas daftar chat di topik pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim aktivitas room ke topik pribadi setiap anggota DM, grup, dan CS agar daftar chat dan penanda terkirim diperbarui tanpa membuka room. |
| Aktor | Sistem |
| Prakondisi | Klien join `user:<uid>`. |
| Proses dan aturan | 1) Event `room_activity` `{room_id, room_type, message_id, sender_id, created_at, preview}` untuk DM, grup, dan room CS (hanya ke nasabah), satu per anggota yang tidak terlibat blokir dengan pengirim (0098). <br>2) Room saham tidak mengirim aktivitas per anggota (lihat FR-CHAT-41). <br>3) Event `room_removed` dengan `reason` `hidden`, `left`, atau `group_deleted` memberi tahu perangkat lain untuk membuang room dari daftar (0154, 0157). |
| Keluaran | Event `room_activity`, `room_removed` |
| Kode error | — |
| Antarmuka | Realtime topik `user:<user_id>`; Library: `CommunityChatList` |
| Lacak | BR-CHAT |

#### FR-CHAT-37 Indikator mengetik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyiarkan status mengetik anggota lewat RPC dengan identitas dari JWT dan meredam pengulangan. |
| Aktor | Nasabah |
| Prakondisi | Pemanggil anggota room; room di bawah ambang ringkasan atau room CS. |
| Proses dan aturan | 1) `send_typing(p_room_id, p_typing)`; identitas dari JWT (0098, 0106). <br>2) Nilai sama dalam 3 detik dan mulai mengetik lagi dalam 1 detik tidak disiarkan (fungsi mengembalikan `false`). <br>3) Event `typing` `{user_id, username, display_name, typing}`; di room CS nama tampilan agen dipakai. <br>4) Library: "mengetik…" (DM) atau "Budi sedang mengetik…" (grup) di daftar chat dan room. |
| Keluaran | `boolean` disiarkan atau tidak |
| Kode error | `401 not_authenticated`; `404 not_member` |
| Antarmuka | RPC `send_typing`; event `typing` |
| Lacak | BR-CHAT |

#### FR-CHAT-38 Ringkasan mengetik di room besar

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengganti typing per orang dengan ringkasan tanpa identitas di room besar dan mematikannya di room sangat besar untuk menjaga beban realtime. |
| Aktor | Sistem |
| Prakondisi | Room non-CS. |
| Proses dan aturan | 1) Room dengan anggota ≥ `rooms.typing_aggregate_members` (50) memakai `typing_summary` `{room_id, count, ttl_ms}`, paling sering sekali per `rooms.typing_summary_seconds` (3) per room; `count` maks. 99 (0106). <br>2) Anggota ≥ `rooms.typing_off_members` (2000): typing tidak disiarkan. <br>3) Berhenti mengetik tidak disiarkan; ringkasan kedaluwarsa setelah `ttl_ms`. <br>4) Pengguna yang dibanned atau dibisukan di room tidak dihitung. <br>5) Pengirim ringkasan dipilih lewat `FOR UPDATE SKIP LOCKED` di `private.typing_rooms`. <br>6) Library: "Seseorang sedang mengetik…" / "Beberapa orang sedang mengetik…". |
| Keluaran | Event `typing_summary` |
| Kode error | — |
| Antarmuka | RPC `send_typing`; event `typing_summary` |
| Lacak | BR-CHAT |

#### FR-CHAT-39 Presence online di DM

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan presence hanya di room kecil sehingga indikator online lawan bicara DM tersedia tanpa membanjiri room besar. |
| Aktor | Nasabah |
| Prakondisi | Klien join topik room. |
| Proses dan aturan | 1) `private.can_track_presence(topic)` menolak `track` di DM/grup dengan anggota ≥ `rooms.presence_max_members` (50) dan di room saham dengan anggota ≥ `rooms.presence_stock_members` (0 = selalu ditolak) (0106). <br>2) `track` yang ditolak dijawab `error` dan channel tetap tersambung. <br>3) Room CS tidak dibatasi (dipakai Hub). <br>4) Kunci presence dipilih klien dan tidak diikat ke JWT; risiko ini diterima karena presence hanya dipakai di DM (0098). <br>5) Library 1.6.0 ke atas hanya memakai presence di DM: titik hijau dan teks "Online". |
| Keluaran | Presence diterima atau ditolak |
| Kode error | — |
| Antarmuka | Realtime presence `room:<id>`, topik `online` |
| Lacak | BR-CHAT |

#### FR-CHAT-40 Pengisian celah pesan (gap-fill)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan cara murah bagi klien untuk menambal pesan yang terlewat dari Realtime berdasarkan horizon yang sudah dikonfirmasi server. |
| Aktor | Library, Nasabah |
| Prakondisi | Pemanggil anggota room. |
| Proses dan aturan | 1) `get_message_ids(p_room_id, p_after, p_limit)` → `{ids, last, more}`; bawaan 500, maks. 1.000 id per halaman, urut maju (0154). <br>2) `get_messages_by_ids(p_room_id, p_ids)` maks. 100 id per panggilan. <br>3) Klien membaca maju dari `horizon − 10 detik`, maks. 5 halaman; lebih dari itu room dimuat ulang dari pesan terbaru (0103). <br>4) Pesan yang hanya datang lewat Realtime tidak memajukan horizon. <br>5) Chat CS memakai `get_messages(p_after)` per 100 baris. <br>6) Duplikat digabung lewat `id` dan `client_id`. |
| Keluaran | Daftar id; `setof chat_message` |
| Kode error | `403 not_member`; `400 invalid_cursor`; `400 too_many_ids` |
| Antarmuka | RPC `get_message_ids`, `get_messages_by_ids` |
| Lacak | BR-CHAT |

#### FR-CHAT-41 Jadwal gap-fill di klien

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menjalankan gap-fill pada saat-saat yang mencegah lubang pesan tanpa membuat ratusan klien memanggil server serentak. |
| Aktor | Library |
| Prakondisi | Room terbuka. |
| Proses dan aturan | 1) Saat channel room tersambung pertama kali: langsung (0103). <br>2) Saat tersambung ulang: setelah jeda acak 0–5 detik, lalu sekali lagi 5–10 detik kemudian. <br>3) Berkala 45 detik ± 25% selama room terbuka. <br>4) Saat aplikasi kembali ke depan (`AppLifecycleListener.onResume`): langsung. |
| Keluaran | Pesan yang hilang tampil |
| Kode error | — |
| Antarmuka | Library: `ChatRoomCubit` |
| Lacak | BR-CHAT |

#### FR-CHAT-42 Pratinjau room saham lewat polling

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan RPC ringan untuk pratinjau dan jumlah belum dibaca room saham di daftar chat, dengan interval polling yang diatur server. |
| Aktor | Library, Nasabah |
| Prakondisi | Daftar chat terlihat, aplikasi di depan, online. |
| Proses dan aturan | 1) `get_room_previews(p_room_ids)` maks. 50 id, read-only; hanya room saham yang diikuti pemanggil, id lain diabaikan (0107, 0154). <br>2) Respons `{poll_seconds, rooms:[{room_id, last_message_at, last_message_preview, last_message_sender_id, unread_count, cursor}]}`. <br>3) `rooms.preview_poll_seconds` bawaan 15; klien menjepit ke 5 dtk–5 mnt dan mengacak × 0,75–1,25. <br>4) Pratinjau room saham yang sedang ramai diperbarui lewat antrean `private.room_preview_queue` oleh job `chat-room-preview` tiap 10 detik bila kunci baris sedang dipegang (0102). |
| Keluaran | `jsonb` pratinjau |
| Kode error | `401 not_authenticated`; `400 too_many_rooms` |
| Antarmuka | RPC `get_room_previews`; Library: `CommunityChatList` (`TickerMode`) |
| Lacak | BR-CHAT |

#### FR-CHAT-43 Pratinjau pesan terakhir di daftar chat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menjaga pratinjau pesan terakhir setiap room tetap sesuai dengan pesan terbaru yang terlihat, termasuk saat pesan diedit atau dihapus. |
| Aktor | Sistem |
| Prakondisi | Pesan `visible`. |
| Proses dan aturan | 1) Pratinjau = cuplikan 120 karakter, atau `[lampiran]` bila tanpa teks (0173). <br>2) Pesan `held`/`hidden` tidak memperbarui pratinjau. <br>3) Edit pesan terakhir memperbarui pratinjau dan mengirim `message_edited` (0154). <br>4) Hapus pesan terakhir mengganti pratinjau menjadi `[pesan dihapus]` dan mengirim `room_activity` ke anggota DM/grup (0179). <br>5) Pratinjau dan waktu tidak ditampilkan kepada pengguna yang `cleared_at`-nya lebih baru (0154). |
| Keluaran | `chat_rooms.last_message_*` |
| Kode error | — |
| Antarmuka | Trigger `messages_after_insert`, `messages_61_edit_preview`, `messages_62_delete_preview` |
| Lacak | BR-CHAT |

#### FR-CHAT-44 Mention di grup dan room saham

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi notifikasi mention kepada pengguna yang disebut dengan `@username` di grup dan room saham, sesuai pengaturan mention dan bisu. |
| Aktor | Sistem |
| Prakondisi | Pesan `visible`, belum dihapus, pengirim bukan sistem. |
| Proses dan aturan | 1) Maks. `notifications.mention_room_max` (5) nama pertama per pesan (0087, 0173). <br>2) Grup: hanya anggota grup yang disebut, bukan pengirim, tidak terhapus, tidak membisukan pengirim, dan `private.mention_allowed` true; mereka menerima `mention` sebagai pengganti `message`, termasuk saat membisukan grup. <br>3) Room saham: pengguna disebut yang tidak terhapus, tidak di-ban, dan tidak membisukan pengirim; bisu room tidak menahan mention. <br>4) Payload `{room_id, room_type, room_name, message_id, snippet}` (+ `stock_code` untuk room saham); digabung per room `mention:room:<id>`. <br>5) DM dan chat CS tidak memberi saran `@`/`$` di klien. |
| Keluaran | Notifikasi `mention` |
| Kode error | — |
| Antarmuka | Trigger `messages_after_insert`; Library: autocomplete `@` (anggota grup saja), `CommunityChatRoom` |
| Lacak | BR-CHAT |

#### FR-CHAT-45 Antrean pesan offline dan cache chat

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menyimpan daftar chat dan pesan terakhir di perangkat serta mengantrekan pesan teks yang dikirim saat offline untuk dikirim ulang otomatis. |
| Aktor | Library |
| Prakondisi | `initialize(offlineCache: true)` (bawaan). |
| Proses dan aturan | 1) Cache: halaman pertama `get_my_rooms` (30 room, tanpa room CS) dan pesan yang pernah dimuat, maks. `offlineMessageLimit` (bawaan 200) per room (features.md). <br>2) Outbox: hanya pesan teks; status "Menunggu dikirim"; backoff 2 detik sampai 1 menit, langsung saat koneksi kembali, aplikasi ke depan, atau realtime tersambung; urutan per room dijaga; `client_id` mencegah duplikat. <br>3) Penolakan server (`content_blocked`, `dm_request_limit`, persetujuan dokumen, `slow_mode` setelah 3 percobaan, `social_disabled` 403) menjadikan pesan "Gagal terkirim" dengan Coba lagi / Hapus. <br>4) Lampiran tidak diantrekan: "Gambar dan dokumen hanya bisa dikirim saat online." <br>5) Chat CS tidak di-cache. Database lokal dihapus saat `signOut()`, `deleteMyAccount()`, `clearLocalCache()`, atau ganti user; dapat dienkripsi dengan `offlineCacheKey` (1.45.0). |
| Keluaran | Pesan terkirim tertunda; tampilan cache |
| Kode error | — |
| Antarmuka | Library: `OutboxQueued`, `OutboxSent`, `OutboxFailed`, `CommunityOfflineBanner`, `RendezvousCommunity.instance.clearLocalCache()` |
| Lacak | BR-CHAT |

#### FR-CHAT-46 Room CS terkunci untuk aksi chat generik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengunci room CS dan pesannya dari aksi chat generik nasabah agar riwayat layanan nasabah tetap utuh. |
| Aktor | Nasabah |
| Prakondisi | Room `type = 'support'` atau pesan dengan `session_id`. |
| Proses dan aturan | 1) `hide_room` ditolak (0154). <br>2) `leave_room` ditolak (0157). <br>3) `edit_message` dan `UPDATE` langsung isi pesan CS ditolak (0154). <br>4) `delete_message` pesan CS ditolak (0031). <br>5) Reaksi, bagikan postingan, dan kartu saham ditolak di chat CS (0075, 0090). <br>6) Kategori keamanan konten dan permintaan DM tidak berlaku untuk pesan CS. Alur tiket, balasan, dan penutupan ditulis di modul CS. |
| Keluaran | Penolakan |
| Kode error | `400 cannot_hide_support`; `400 cannot_leave_support`; `409 support_message_locked`; `400 reactions_not_supported`; `400 share_not_allowed` |
| Antarmuka | RPC `hide_room`, `leave_room`, `edit_message`, `delete_message`, `react_to_message`, `share_post_to_chat` |
| Lacak | BR-CHAT |

### 4.4 Layanan nasabah dan chat CS (CS)

Modul CS mencakup layanan nasabah lewat chat dengan model "ambil tiket": nasabah membuka tiket dari aplikasi OLT (library `rendezvous_community`, modul `support`) atau dari halaman login sebagai tamu, CS (peran `cs_agent`) mengambil dan menangani tiket di Rendezvous Hub menu **Layanan Nasabah**, dan Super Admin (`cs_super_admin`) hanya memantau, memindahkan tiket, dan mengelola pengaturan layanan. Semua aturan ditegakkan di database (skema internal `cs`, API `cs_api` lewat PostgREST, RLS, trigger, pg_cron `cs-sweep` tiap 10 detik).

Di luar modul ini: mekanisme chat umum (tanda terima, balas pesan, mengetik, realtime) di CHAT; menu Kepatuhan, tenggat pengaduan, perpanjangan, register kasus, dan akses hanya-baca 12 jam (0125) di PATUH; akun staf, peran, 2FA, kunci akun, dan Kinerja saya di HUB; menu Akun Nasabah dan gateway csAdmin di INT; push notifikasi balasan CS di NOTIF; topik chat CS (ikon, urutan, pertanyaan awal, saran balasan, SOP) dan artikel FAQ di BANTU; layanan media, ClamAV, dan job terjadwal sebagai layanan di OPS. Telepon CS tidak termasuk lingkup.

Nomor tiket berbentuk `CS-YYYYMMDD-NNNN` (urut per hari WIB, 0032). Setiap nasabah punya satu room `support` dan paling banyak satu tiket aktif (`open`, `claimed`, `waiting_customer`), dijamin indeks unik `tickets_active_room_idx` (0032).

**Transisi status tiket** (ditegakkan `cs.transition_allowed`, 0032; constraint menjamin `open` tanpa pemilik dan `claimed`/`waiting_customer` selalu punya pemilik):

| Dari | Ke | Pemicu |
|---|---|---|
| (baru) | `open` | `cs_api.open_ticket`, pesan pertama nasabah tanpa tiket (topik `ticket.default_topic`), `request_complaint`, `report_fake_cs`, atau `guest_start` |
| `open` | `claimed` | CS mengambil tiket (`claim_ticket`), penugasan otomatis (`assignment.mode = auto_assign`), atau reassign Super Admin |
| `claimed` | `waiting_customer` | Pemilik menekan **Tunggu nasabah** (`wait_customer`) |
| `waiting_customer` | `claimed` | Nasabah membalas (event `customer_replied`) |
| `claimed`, `waiting_customer` | `claimed` (pemilik baru) | Transfer diterima CS tujuan, atau reassign Super Admin |
| `claimed`, `waiting_customer` | `open` | Pemilik melepas tiket (alasan 3–300), lepas otomatis karena pemilik offline (bila `ticket.auto_release_offline_minutes` > 0), atau akun pemilik dinonaktifkan (HUB) |
| `claimed`, `waiting_customer` | `resolved` | Pemilik menyelesaikan (hasil + ringkasan 5–500 karakter); nasabah diminta rating |
| `resolved` | `claimed` | Nasabah membalas sebelum rating dan sebelum `reopen_until`; pemilik lama tidak away > `ticket.owner_away_minutes` (10) dan masih punya slot |
| `resolved` | `open` | Sama seperti di atas, tetapi pemilik lama away atau penuh |
| `resolved` | `closed` | Nasabah memberi rating (`rated`), batas `ticket.auto_close_days` terlewati tanpa rating (`reopen_window_passed`), nasabah membuka tiket baru (`superseded`), atau nasabah mengakhiri chat (`customer`) |
| `open`, `claimed`, `waiting_customer` | `closed` | Nasabah mengakhiri chat (`close_ticket`) atau tamu menekan **Akhiri** (`guest_end`, 0159); alasan `customer` |

Alasan tutup disimpan di `cs.tickets.close_reason` (`rated`, `reopen_window_passed`, `customer`, `superseded`) (0056). Status `closed` bersifat akhir.

#### FR-CS-01 Ringkasan layanan CS untuk nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan satu ringkasan keadaan layanan CS untuk nasabah yang masuk, sebagai sumber tampilan chat CS di aplikasi. |
| Aktor | Nasabah (library) |
| Prakondisi | Sesi sosial nasabah aktif (AKUN). |
| Proses dan aturan | 1) Mengembalikan `room_id`, `support_name` (pengaturan `brand.support_name`, bawaan "CS OLT"), tiket terbaru (tiket aktif diutamakan), `active`, `unread_count`, `service_open`, `next_open_at`, `topic_picker`, `incidents` aktif, dan `survey` dua bahasa (0135, 0158). <br>2) `unread_count` hanya menghitung pesan orang lain setelah `last_read_at` yang belum dihapus, `moderation_status = 'visible'`, bukan dari akun yang diblokir, dan setelah `cleared_at`; maksimal 99 (0158). <br>3) `service_open` dihitung dari jam layanan dan kalender libur (FR-CS-65). <br>4) Library memuat ulang ringkasan saat ada event tiket realtime `cs:room:<id>` dan setelah setiap aksi. |
| Keluaran | Objek JSON ringkasan layanan. |
| Kode error | `403 customer_required` |
| Antarmuka | RPC `cs_api.support_home`; Library: `CommunitySupportChat`, `openCommunitySupport` |
| Lacak | BR-CS |

#### FR-CS-02 Room CS tersemat dan resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan room CS nasabah tersemat paling atas di daftar chat dengan badge resmi, dan sistem harus mencegah room itu dibisukan atau ditinggalkan. |
| Aktor | Nasabah |
| Prakondisi | Nasabah masuk; room `support` dibuat otomatis saat tiket pertama (`cs.ensure_room`). |
| Proses dan aturan | 1) `CommunityChatList` menyematkan room CS paling atas dengan badge **CS Resmi**; mengetuknya membuka tampilan CS, bukan chat biasa. <br>2) Membisukan atau meninggalkan room `support` ditolak (`cs.support_room_guard`, 0032). <br>3) Badge "CS Resmi" pada pesan berasal dari `messages.sender_role = 'agent'` yang hanya bisa diisi server untuk akun di `cs.agents`. <br>4) Profil staf (`olt_user_id = 'cs-staff:<id>'`) tidak bisa memakai fitur sosial dan tidak muncul di pencarian (rincian di HUB/CHAT). |
| Keluaran | Room CS tampil tersemat; percobaan bisu/keluar ditolak. |
| Kode error | `400 cannot_mute_support`; `403 cs_staff_social_forbidden` |
| Antarmuka | Library: `CommunityChatList`, `OfficialBadge` |
| Lacak | BR-CS |

#### FR-CS-03 Daftar topik untuk nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengembalikan daftar topik chat CS yang aktif dalam bahasa nasabah sebagai isi halaman pilih topik. |
| Aktor | Nasabah (library) |
| Prakondisi | Topik dikelola di Hub (BANTU). |
| Proses dan aturan | 1) Hanya topik `active`, urut `sort_order` lalu `code` (0134). <br>2) Per topik: `code`, `name`, `description` sesuai `p_language` (`id`/`en`), `icon`, `style` (`normal`/`danger`), `help_url`, `urgent` (prioritas default P1), dan `intake` (pertanyaan awal beserta opsi, label sesuai bahasa). <br>3) Judul dan petunjuk halaman pilih topik dibaca dari `support_home.topic_picker`; kosong = teks bawaan library ("Apa yang bisa kami bantu?"). <br>4) Setelah topik dipilih, library dapat menampilkan saran artikel (BANTU) dan langkah di luar jam layanan (FR-CS-19). |
| Keluaran | Array topik. |
| Kode error | — |
| Antarmuka | RPC `cs_api.topics`; Library: halaman pilih topik di `CommunitySupportChat` |
| Lacak | BR-CS |

#### FR-CS-04 Membuka tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat tiket CS baru untuk nasabah dengan topik terpilih, atau mengembalikan tiket aktif yang sudah ada. |
| Aktor | Nasabah |
| Prakondisi | Topik aktif. |
| Proses dan aturan | 1) `p_language` wajib `id` atau `en`; `p_screen` (asal layar) opsional, pola `^[a-z][a-z0-9_]{1,31}$` (0134). <br>2) Bila nasabah sudah punya tiket aktif, tiket itu dikembalikan tanpa tiket baru; jawaban pertanyaan awal hanya divalidasi bila belum ada tiket aktif (FR-CS-05). <br>3) Rate limit `cs_ticket`: 5 tiket baru per 3.600 detik per nasabah (0027, 0032). <br>4) Tiket `resolved` lama di room yang sama ditutup dengan alasan `superseded` (0123). <br>5) Tiket menyimpan topik, bahasa, prioritas awal (FR-CS-06), flag, skill yang dibutuhkan, `context` (`screen`, `intake`), dan nomor `CS-YYYYMMDD-NNNN`. <br>6) `p_complaint = true` menandai tiket pengaduan (FR-CS-16). <br>7) Pesan sistem `ticket_opened` (dua bahasa) berisi salam dan pengingat bahwa CS tidak pernah meminta PIN/password/OTP; bila di luar jam layanan dan tidak ada CS yang bisa dijangkau, ditambah teks `out_of_hours` dengan jam buka berikutnya; bila pengaduan, ditambah waktu diterima dan tenggat (0123). <br>8) Chat CS tidak membutuhkan persetujuan dokumen hukum (0062). <br>9) Event `ticket_opened` dikirim ke `cs:queue`. |
| Keluaran | Tampilan tiket nasabah (FR-CS-11). |
| Kode error | `400 invalid_language`; `400 invalid_screen`; `400 invalid_topic`; `400 intake_required`; `400 invalid_intake_answers`; `429 rate_limited`; `403 customer_required` |
| Antarmuka | RPC `cs_api.open_ticket(p_topic, p_language, p_screen, p_complaint, p_intake)`; Library: `openCommunitySupport(topic:, screen:)` |
| Lacak | BR-CS |

#### FR-CS-05 Validasi jawaban pertanyaan awal

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memvalidasi jawaban nasabah atas pertanyaan awal topik sebelum tiket dibuat dan menyimpannya di tiket untuk dilihat CS. |
| Aktor | Nasabah |
| Prakondisi | Topik punya `intake` (maksimal 8 isian, dikelola di BANTU). |
| Proses dan aturan | 1) `p_intake` harus objek `{key: nilai}` (0134). <br>2) Isian wajib yang kosong ditolak `intake_required` dengan label isian. <br>3) Nilai maksimal 200 karakter; `number` sesuai `^-?[0-9]{1,15}([.,][0-9]{1,4})?$`; `date` tanggal ISO `YYYY-MM-DD` yang valid; `choice` harus salah satu nilai opsi. <br>4) Jawaban disimpan di `context.intake` (kunci, jenis, label, nilai, tampilan) dan tampil di Hub sebagai **Jawaban awal nasabah**. <br>5) Library menampilkan form **"Sebelum mulai chat"** dengan validasi yang sama; galat server tampil sebagai pesan dan form tetap terbuka. |
| Keluaran | Tiket dengan jawaban pertanyaan awal. |
| Kode error | `400 intake_required`; `400 invalid_intake_answers` |
| Antarmuka | RPC `cs_api.open_ticket`; Library: form pertanyaan awal di `CommunitySupportChat`; Hub: Layanan Nasabah → panel kanan tiket |
| Lacak | BR-CS |

#### FR-CS-06 Prioritas awal tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menentukan prioritas awal tiket (P1 paling mendesak sampai P4) dari topik, flag, dan isi pesan pertama nasabah. |
| Aktor | Sistem |
| Prakondisi | Tiket baru atau pesan pertama nasabah di tiket. |
| Proses dan aturan | 1) Dasar: prioritas default topik; flag topik (`complaint`/`fraud`, BANTU) ikut menjadi flag tiket (0028). <br>2) Flag `fraud` menaikkan ke P1 dan skill `fraud`; flag `complaint` menaikkan maksimal ke P2. <br>3) Nasabah di `cs.vip_customers` mendapat flag `vip`. <br>4) Aturan kata kunci `priority.rules` pada pesan pertama: mis. "dibobol", "penipuan", "cs palsu" → P1 + flag `fraud`; "tidak bisa order", "order gagal" → P1 hanya di jam bursa (`market.hours`, bawaan 09:00–16:00 WIB hari kerja) (0027). <br>5) Bila pesan pertama menaikkan prioritas atau menambah flag, event `priority_changed` dicatat dan `ticket_updated` disiarkan (0056). |
| Keluaran | Prioritas dan flag tiket. |
| Kode error | — |
| Antarmuka | Fungsi internal `cs.initial_priority` |
| Lacak | BR-CS |

#### FR-CS-07 Pesan nasabah ke chat CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima pesan teks dan lampiran nasabah di room CS miliknya dan mengaitkannya ke tiket yang tepat. |
| Aktor | Nasabah |
| Prakondisi | Room `support` milik nasabah. |
| Proses dan aturan | 1) Room harus berjenis `support` dan milik pemanggil (0029). <br>2) Nasabah hanya boleh mengirim `kind = 'text'` (teks dan/atau lampiran); body maksimal 4.000 karakter. <br>3) Rate limit `cs_message`: 30 pesan per 60 detik (0027). <br>4) `client_id` idempoten: pengiriman ulang dengan `client_id` sama tidak membuat pesan ganda. <br>5) Pesan di room tanpa tiket membuka tiket baru dengan topik `ticket.default_topic`; pesan bersamaan dilayani berurutan lewat kunci baris tiket terakhir. <br>6) Tiket `waiting_customer` kembali `claimed`; tiket `resolved` dibuka kembali bila masih sebelum `reopen_until` (FR-CS-38); selain itu ditolak `ticket_closed` (FR-CS-14) (0056). <br>7) Mengisi `last_customer_message_at`; data sensitif disamarkan (FR-CS-09). |
| Keluaran | Pesan tersimpan dan dikirim realtime ke CS penangan. |
| Kode error | `404 room_not_found`; `400 invalid_kind`; `409 ticket_closed`; `429 rate_limited`; `403 customer_required` |
| Antarmuka | RPC `cs_api.send_message`, `cs_api.get_messages`, `cs_api.mark_read`; Library: `CommunitySupportChat` |
| Lacak | BR-CS |

#### FR-CS-08 Pesan CS tidak bisa diubah nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencegah nasabah mengubah atau menghapus pesan chat CS dan mempertahankan riwayat CS saat akun dihapus. |
| Aktor | Nasabah, Sistem |
| Prakondisi | Pesan bertanda `session_id` (pesan chat CS). |
| Proses dan aturan | 1) Edit dan hapus pesan CS oleh pengguna akhir ditolak `support_message_locked` (0056); hapus lunak (`deleted_at`) dari nasabah diabaikan diam-diam. <br>2) Moderasi oleh service/admin tetap boleh menghapus konten ilegal. <br>3) Hapus akun komunitas tidak menghapus riwayat CS (transkrip adalah catatan pengaduan); lampiran dibersihkan lewat janitor (OPS). <br>4) Reaksi pesan tidak tersedia di chat CS (library). |
| Keluaran | Pesan CS tetap utuh. |
| Kode error | `409 support_message_locked` |
| Antarmuka | Trigger `cs.message_before_write` |
| Lacak | BR-CS |

#### FR-CS-09 Penyamaran data sensitif

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyamarkan data sensitif di pesan, catatan, ringkasan, dan komentar rating chat CS, dan library harus memperingatkan nasabah sebelum mengirim data sensitif. |
| Aktor | Nasabah, CS, Sistem |
| Prakondisi | Teks berisi pola OTP, password, nomor kartu, NIK, atau nomor rekening. |
| Proses dan aturan | 1) Pesan nasabah dan CS di room `support` disamarkan oleh `cs.mask_sensitive` sebelum disimpan; payload ditambah `masked` berisi jenis data (0056). <br>2) Penyamaran juga dipakai untuk catatan internal, ringkasan penyelesaian, catatan serah terima, dan komentar rating. <br>3) Hub menampilkan keterangan **Disamarkan otomatis** beserta jenis datanya. <br>4) `check_sensitive(p_text)` (maksimal 4.000 karakter) mengembalikan `masked`, `kinds`, `preview`, dan `requests_secret`; library memakainya untuk peringatan saat mengetik. |
| Keluaran | Teks tersamar; peringatan di aplikasi. |
| Kode error | — |
| Antarmuka | RPC `cs_api.check_sensitive`; Library: peringatan di composer `CommunitySupportChat` |
| Lacak | BR-CS |

#### FR-CS-10 Akses CS bagi akun yang dibatasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus tetap membuka jalur `cs_api` bagi nasabah yang di-ban dari fitur sosial atau saat kill switch sosial aktif. |
| Aktor | Nasabah |
| Prakondisi | Nasabah di-ban, profil dihapus dalam masa jeda, atau `social_enabled = false`. |
| Proses dan aturan | 1) `private.check_request` mengecualikan profil `cs_api` dari penolakan `user_banned` dan profil terhapus (0177); realtime room CS dan lampiran room CS juga dikecualikan (0054). <br>2) Kill switch sosial tidak menutup chat CS; daftar chat hanya menampilkan room CS (library). <br>3) Auth-bridge menolak penukaran token untuk user yang di-ban (`403 user_banned`, AKUN), sehingga nasabah tanpa sesi diarahkan ke pengaduan tamu (FR-CS-21); library menampilkan tombol **Hubungi CS** selama jeda bergabung lagi. <br>4) Apakah nasabah yang di-ban seharusnya tetap bisa membuka chat CS di dalam aplikasi (keputusan di docs/cs-chat/README.md) atau cukup lewat pengaduan tamu (perilaku auth-bridge dan catatan rilis 0175): perlu konfirmasi. |
| Keluaran | Chat CS tetap tersedia selama sesi ada; alternatif pengaduan tamu. |
| Kode error | `403 user_banned` (di luar `cs_api`) |
| Antarmuka | Fungsi `private.check_request`; Library: `openCommunityGuestSupport` |
| Lacak | BR-CS |

#### FR-CS-11 Tampilan status tiket untuk nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim tampilan tiket yang aman untuk nasabah, termasuk posisi antrean, perkiraan waktu tunggu, CS penangan, dan saran balasan. |
| Aktor | Nasabah (library) |
| Prakondisi | Nasabah pemilik tiket. |
| Proses dan aturan | 1) Field: `id`, `ticket_number`, `room_id`, `topic`, `topic_name`, `status`, `queue_ahead`, `eta_minutes`, `agent` (nama tampilan + kode, untuk `claimed`/`waiting_customer`/`resolved`), `complaint` (diterima, tenggat), waktu, `close_reason`, `reopen_until`, `rating`, `can_rate`, `quick_replies` (0134). <br>2) `queue_ahead` = jumlah tiket `open` lain dengan (prioritas, waktu antre) lebih awal. <br>3) `eta_minutes` = median menit klaim 7 hari terakhir × (antrean di depan + 1) ÷ jumlah CS online (minimal 1), dibatasi 1–240; `null` bila belum ada data. <br>4) `quick_replies` = saran balasan topik (BANTU) selama tiket aktif; library menampilkannya sebagai chip yang mengirim teks lewat composer biasa. <br>5) Label tiket, catatan internal, dan ringkasan penyelesaian tidak pernah ikut. <br>6) Header library menampilkan nomor, topik, dan status ("Menunggu CS", "Ditangani oleh [nama] – CS Resmi", "Menunggu balasan Anda", "Selesai"). |
| Keluaran | JSON tampilan tiket nasabah. |
| Kode error | — |
| Antarmuka | Fungsi `cs.ticket_customer_view`; Library: header `CommunitySupportChat` (slot `support.header`) |
| Lacak | BR-CS |

#### FR-CS-12 Tiket saya dan transkrip nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan riwayat tiket nasabah dan menyediakan transkrip tiket yang sudah selesai untuk diunduh. |
| Aktor | Nasabah |
| Prakondisi | Nasabah masuk. |
| Proses dan aturan | 1) `my_tickets` mengembalikan maksimal 50 tiket terbaru beserta `first_message_at` (0033). <br>2) `ticket_transcript` hanya untuk tiket milik pemanggil berstatus `resolved` atau `closed`; berisi tiket, pesan berurutan (pengirim `customer`/`agent`/`system`, nama CS, teks sesuai bahasa tiket, tanda terhapus, nama lampiran) (0136). <br>3) Library membuat file TXT UTF-8 `transkrip-<nomor>.txt` / `transcript-<nomor>.txt` (desktop: dialog simpan, Android/iOS: lembar bagikan, web: unduh); host dapat mengganti penyimpanan. |
| Keluaran | Daftar tiket; file transkrip. |
| Kode error | `404 ticket_not_found`; `409 ticket_active` |
| Antarmuka | RPC `cs_api.my_tickets`, `cs_api.ticket_messages`, `cs_api.ticket_transcript`; Library: `CommunitySupportTickets(transcriptSaver:)` |
| Lacak | BR-CS |

#### FR-CS-13 Nasabah mengakhiri chat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah menutup tiketnya sendiri. |
| Aktor | Nasabah |
| Prakondisi | Tiket milik pemanggil. |
| Proses dan aturan | 1) Tiket berstatus apa pun selain `closed` menjadi `closed` dengan alasan `customer`; outcome kosong diisi `customer_ended` (0056). <br>2) Transfer yang menunggu dibatalkan, staf dikeluarkan dari room, beban CS dihitung ulang, pesan sistem `ticket_closed`, event `ticket_closed`. <br>3) Library meminta konfirmasi (menu ⋯ **Akhiri chat**). |
| Keluaran | Tiket tertutup. |
| Kode error | `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.close_ticket`; Library: menu **Akhiri chat** |
| Lacak | BR-CS |

#### FR-CS-14 Tiket tertutup tidak bisa dibalas

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak pesan nasabah ke tiket yang sudah ditutup dan mengarahkan nasabah membuat tiket baru. |
| Aktor | Nasabah, CS |
| Prakondisi | Tiket terakhir room `closed`, atau `resolved` yang sudah dinilai atau lewat `reopen_until`. |
| Proses dan aturan | 1) Pesan nasabah ditolak `409 ticket_closed` dengan teks "Tiket #… sudah ditutup. Buat tiket baru untuk chat lagi" (0056). <br>2) Library mengganti kotak ketik dengan keterangan tiket ditutup dan tombol **Buat tiket baru** (pilih topik → `open_ticket`). <br>3) Hub menampilkan **Tiket ditutup dan tidak bisa dibalas lagi.** dan, bila nasabah sudah punya tiket aktif baru, tombol **Buka tiket aktif**. <br>4) Pesan CS ke tiket yang tidak aktif ditolak (FR-CS-41). |
| Keluaran | Penolakan terkendali dan jalan ke tiket baru. |
| Kode error | `409 ticket_closed` |
| Antarmuka | Trigger `cs.message_before_write`; Library: `CommunitySupportChat`; Hub: Layanan Nasabah → percakapan |
| Lacak | BR-CS |

#### FR-CS-15 Rating dan survei kepuasan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima rating nasabah atas tiket yang sudah ditangani sesuai konfigurasi survei, dan menutup tiket `resolved` begitu dinilai. |
| Aktor | Nasabah |
| Prakondisi | Tiket milik pemanggil, status `resolved` atau `closed`, pernah diklaim, belum dinilai (`can_rate`). |
| Proses dan aturan | 1) Rating 1–5; bila skala survei 3, hanya 1, 3, 5 yang sah (0135). <br>2) Komentar maksimal 500 karakter, disamarkan. <br>3) `p_reasons` hanya boleh bila rating ≤ `low_max` dan semua kode ada di daftar alasan survei. <br>4) Tiket `resolved` langsung ditutup dengan alasan `rated`; tiket yang sudah `closed` tetap ditutup dan hanya disiarkan `ticket_updated`. <br>5) Event `rated` dicatat beserta alasan. <br>6) Library menampilkan dialog sesuai `support_home.survey`: tiga wajah (1, 3, 5) atau bintang 1–5, chip alasan bila nilai rendah; tanpa `survey` memakai dialog bintang lama. |
| Keluaran | Rating tersimpan; tiket `closed`. |
| Kode error | `404 ticket_not_found`; `409 cannot_rate`; `400 invalid_rating`; `400 comment_too_long`; `400 invalid_reasons` |
| Antarmuka | RPC `cs_api.rate_ticket(p_ticket_id, p_rating, p_comment, p_reasons)`; Library: dialog rating di chat (slot `support.ratingDialog`) |
| Lacak | BR-CS |

#### FR-CS-16 Pengajuan pengaduan resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah mengajukan pengaduan resmi dan memberi tahu waktu diterima serta tenggatnya. |
| Aktor | Nasabah |
| Prakondisi | Nasabah masuk. |
| Proses dan aturan | 1) Bila ada tiket aktif, tiket itu diberi flag `complaint`; bila tidak, tiket baru dibuat dengan topik `ticket.default_topic` dan flag `complaint` (0033). <br>2) Flag `complaint` mencatat `complaint_received_at` dan `complaint_due_at` = `complaint.days` hari kerja (bawaan 5, kalender WIB; nilai dikonfirmasi Kepatuhan, PATUH), menaikkan prioritas maksimal P2, dan mengirim pesan sistem `complaint` berisi keduanya (0133). <br>3) Tiket tidak dipindah otomatis; tenggat tampil di kepala percakapan Hub. <br>4) Catatan `cs.compliance_notices` dan event `case_flagged` di `cs:compliance` (PATUH). <br>5) Audit `ticket.complaint_requested`. |
| Keluaran | Tiket bertanda pengaduan dengan tenggat. |
| Kode error | `409 ticket_not_active`; `403 customer_required` |
| Antarmuka | RPC `cs_api.request_complaint`; Library: menu ⋯ **Ajukan pengaduan** |
| Lacak | BR-CS |

#### FR-CS-17 Laporan CS palsu

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima laporan nasabah tentang pihak yang mengaku CS dan menjadikannya tiket penipuan prioritas tertinggi. |
| Aktor | Nasabah |
| Prakondisi | Nasabah masuk. |
| Proses dan aturan | 1) Deskripsi 5–2.000 karakter (0033). <br>2) Tiket aktif diberi flag `fraud` (P1); tanpa tiket aktif dibuat tiket topik `fraud` dengan `context.report = 'fake_cs'`. <br>3) Cerita nasabah masuk ke chat sebagai pesan "Laporan CS palsu: …". <br>4) Event `fake_cs_reported` dicatat, audit `ticket.fake_cs_reported`, dan peringatan `fake_cs_reported` di `cs:queue` (Super Admin menerima notifikasi **Laporan CS palsu**); kasus masuk register Kepatuhan (PATUH). <br>5) Library: dialog lapor dengan tombol kirim aktif mulai 5 huruf. |
| Keluaran | Tiket fraud P1. |
| Kode error | `400 invalid_description`; `403 customer_required` |
| Antarmuka | RPC `cs_api.report_fake_cs`; Library: menu ⋯ **Laporkan CS palsu** (slot `support.fakeCsWarning`) |
| Lacak | BR-CS |

#### FR-CS-18 Lencana belum dibaca dan notifikasi CS di aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan jumlah balasan CS yang belum dibaca dan mengalirkan pemberitahuan saat CS mengambil, membalas, atau menyelesaikan tiket. |
| Aktor | Nasabah |
| Prakondisi | Library terinisialisasi dan nasabah masuk. |
| Proses dan aturan | 1) `CommunitySupportBadge` membaca `unread_count` dari `support_home` (aturan hitung FR-CS-01, 0158). <br>2) `RendezvousCommunity.instance.support.notices()` mengalirkan `SupportNotice` (judul = nama CS, isi = cuplikan) selama aplikasi berjalan; host menampilkannya sebagai notifikasi lokal bila room CS tidak terbuka. <br>3) Push saat aplikasi tertutup dikirim notifier (NOTIF). <br>4) Pesan CS yang gagal karena offline dikirim ulang otomatis dengan `client_id` idempoten; riwayat chat CS tidak disimpan di cache lokal. |
| Keluaran | Badge dan pemberitahuan. |
| Kode error | — |
| Antarmuka | Library: `CommunitySupportBadge`, `support.notices()` |
| Lacak | BR-CS |

#### FR-CS-19 Di luar jam layanan

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus memberi tahu nasabah bila CS di luar jam layanan sebelum tiket dibuat, tanpa menghalangi nasabah meninggalkan pesan. |
| Aktor | Nasabah |
| Prakondisi | `support_home.service_open = false`. |
| Proses dan aturan | 1) Setelah topik dipilih, tampil langkah **"CS sedang di luar jam layanan"** berisi `next_open_at`, maksimal 3 artikel FAQ topik itu (`faq_for_topic`, BANTU), dan tombol **Tinggalkan pesan** yang tetap membuat tiket (lewat form pertanyaan awal bila ada). <br>2) Penugasan otomatis tetap berjalan di luar jam layanan selama ada CS yang bisa dijangkau (FR-CS-31); teks `out_of_hours` hanya ditambahkan ke pesan tiket dibuka bila tidak ada CS yang bisa dijangkau (0043, 0123). |
| Keluaran | Langkah informasi; tiket tetap bisa dibuat. |
| Kode error | — |
| Antarmuka | RPC `cs_api.support_home`, `cs_api.faq_for_topic`; Library: `CommunitySupportChat` |
| Lacak | BR-CS |

#### FR-CS-20 Pengingat tiket menunggu nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim pengingat ke nasabah bila tiket berstatus menunggu nasabah tidak dibalas melebihi batas jam. |
| Aktor | Sistem |
| Prakondisi | `ticket.reminder_hours` > 0 (bawaan 24, rentang 0–72, 0 = mati) (0136). |
| Proses dan aturan | 1) Job pg_cron `cs-waiting-reminder` tiap 5 menit memproses maksimal 100 tiket per putaran. <br>2) Syarat: status `waiting_customer`, pesan CS terakhir lebih tua dari batas, nasabah belum membalas sejak pesan CS itu, dan belum diingatkan sejak pesan CS terakhir. <br>3) Mengirim pesan sistem `messages.waiting_reminder` (teks diubah di Pesan otomatis), mengisi `reminded_at`, event `customer_reminded`. <br>4) Pengingat tidak menutup tiket. |
| Keluaran | Pesan pengingat di chat CS. |
| Kode error | — |
| Antarmuka | Fungsi `cs.remind_waiting_customers`; Hub: Pengaturan → Penugasan, tiket & alert → Pengingat tiket menunggu nasabah |
| Lacak | BR-CS |

#### FR-CS-21 Pengaduan tamu: konfigurasi dan mulai

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan nasabah yang tidak bisa login membuat pengaduan dari halaman login tanpa sesi dan tanpa OTP. |
| Aktor | Tamu (belum login) |
| Prakondisi | `guest.enabled = true` (bawaan); panggilan memakai anon key. |
| Proses dan aturan | 1) `guest_config` mengembalikan `enabled`, `session_hours` (bawaan 24), dan jenis masalah `password`, `pin`, `locked`, `other` dengan label sesuai bahasa (0140). <br>2) `guest_start`: nama 2–60, Login ID opsional (huruf besar, `^[A-Z0-9._@-]{1,50}$`), jenis masalah wajib, cerita 10–1.000 karakter, bahasa `id`/`en`. <br>3) Batas per perangkat (hash HMAC IP dengan pepper): 3 per jam dan 10 per 24 jam; per Login ID: 5 per 24 jam. <br>4) Membuat profil `is_guest = true` (`olt_user_id = 'guest:<uuid>'`), tiket dengan topik `guest.topic` (bawaan `account`, cadangan topik aktif pertama), `context.guest` (`login_id`, `problem`, `verified = false`), dan pesan pertama berisi cerita. <br>5) Token acak 32 byte dikembalikan sekali; server hanya menyimpan hash SHA-256; sesi berlaku `guest.session_hours` (dibatasi 1–72). <br>6) Audit `guest.start`; profil tamu tidak muncul di pencarian dan pencarian staf (0140, 0145). |
| Keluaran | Token sesi tamu, waktu kedaluwarsa, tampilan tiket. |
| Kode error | `403 guest_disabled`; `400 invalid_language`; `400 invalid_name`; `400 invalid_login_id`; `400 invalid_problem`; `400 invalid_description`; `429 rate_limited`; `429 guest_login_limit` |
| Antarmuka | RPC `cs_api.guest_config`, `cs_api.guest_start`; Library: `openCommunityGuestSupport`, `CommunityGuestSupport`, `CommunityGuestSupportPage` |
| Lacak | BR-CS |

#### FR-CS-22 Pengaduan tamu: percakapan dan akhir sesi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan percakapan teks bagi tamu di tiketnya sendiri selama sesi berlaku dan menutup tiket saat tamu mengakhiri pengaduan. |
| Aktor | Tamu |
| Prakondisi | Token sesi tamu valid (belum berakhir, belum kedaluwarsa). |
| Proses dan aturan | 1) Token 20–100 karakter dicocokkan dengan hash; tidak valid atau kedaluwarsa → `401 guest_session_expired` (0140). <br>2) `guest_poll` mengembalikan `expires_at`, tampilan tiket, dan pesan tiket; library memanggilnya tiap 4 detik selama halaman terlihat, jeda naik 8, 16, 32 sampai 60 detik saat gagal dengan banner koneksi. <br>3) `guest_send`: hanya tiket aktif, teks 1–2.000 karakter, rate limit `guest_message` 20 per 60 detik; tamu tidak bisa mengirim lampiran, dan lampiran dari CS ditampilkan sebagai keterangan. <br>4) `guest_end` menutup tiket yang belum `closed` dengan alasan `customer` lalu mengakhiri sesi (0159). <br>5) Token disimpan di memori (`MemoryGuestSessionStore`), bisa diganti host lewat `CommunityGuestSessionStore`; token tidak pernah ditulis ke log. |
| Keluaran | Pesan dan status tiket tamu; tiket tertutup saat diakhiri. |
| Kode error | `401 guest_session_expired`; `409 ticket_not_active`; `400 invalid_body`; `429 rate_limited` |
| Antarmuka | RPC `cs_api.guest_poll`, `cs_api.guest_send`, `cs_api.guest_end`; Library: `CommunityGuestSupport` |
| Lacak | BR-CS |

#### FR-CS-23 Penanganan tiket tamu di Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menandai tiket tamu sebagai belum terverifikasi dan menyembunyikan data akun dari CS selama menangani tiket tamu. |
| Aktor | CS, Super Admin |
| Prakondisi | Tiket dengan `context.guest`. |
| Proses dan aturan | 1) Baris dan percakapan menampilkan lencana **Tamu** dan banner kuning **belum terverifikasi** dengan jumlah pengaduan tamu untuk Login ID yang sama dalam 24 jam (`guest.recent_24h`, 0140). <br>2) `ticket_customer_login` mengembalikan `login_id = null` dan `source = 'guest'` untuk tiket tamu, sehingga data akun tidak dicari otomatis (0141). <br>3) Panel kanan hanya berisi bagian Akun Nasabah dengan keterangan data akun tidak ditampilkan; riwayat tiket dan catatan internal nasabah tidak ditampilkan. <br>4) Bantuan akun hanya lewat Reset password/PIN di menu Akun Nasabah (INT), yang selalu mengirim ke email terdaftar. |
| Keluaran | Tampilan tiket tamu yang dibatasi. |
| Kode error | `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.ticket_detail`, `cs_api.ticket_customer_login`; Hub: Layanan Nasabah → percakapan (`guest-banner`) |
| Lacak | BR-CS |

#### FR-CS-24 Status kerja CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan status kerja CS yang menentukan boleh tidaknya mengambil tiket dan membalas nasabah. |
| Aktor | CS |
| Prakondisi | Akun staf aktif (HUB). |
| Proses dan aturan | 1) Status `online`, `busy`, `break`, `offline`; alasan opsional maksimal 120 karakter (Hub: Makan siang, Rapat, Ibadah, Lainnya) (0033). <br>2) Hanya `online` dengan slot kosong yang boleh mengambil tiket dan menerima transfer; `busy`/`break` boleh membalas tiket berjalan; `offline` tidak boleh membalas (FR-CS-42). <br>3) Perubahan status diaudit (`agent.status`) dan disiarkan `agent_status` di `cs:queue`; beralih ke `offline` memicu pemberitahuan ke nasabah (FR-CS-35). <br>4) Hub memulai status **Offline** saat login, menampilkan **Aktif n/maks**, dan mengubah status ke `offline` saat tab terakhir ditutup bila CS tidak memegang tiket aktif; muat ulang halaman dalam 60 detik memulihkan status sebelumnya. <br>5) Tiket tetap milik CS walau Offline. |
| Keluaran | Status tersimpan dan disiarkan. |
| Kode error | `400 invalid_status`; `400 reason_too_long`; `403 agent_required`; `401 session_revoked` |
| Antarmuka | RPC `cs_api.agent_set_status`, `cs_api.agent_me`; Hub: kanan atas **Ubah status** (`status-menu`) |
| Lacak | BR-CS |

#### FR-CS-25 Heartbeat dan keterjangkauan CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat heartbeat web CS dan memakainya untuk menilai apakah CS terhubung dan bisa menerima tiket otomatis. |
| Aktor | Hub, Sistem |
| Prakondisi | CS masuk di Hub. |
| Proses dan aturan | 1) Hub mengirim heartbeat tiap 20 detik dari satu tab pemimpin; saat Offline hanya memeriksa sesi tiap 60 detik. <br>2) Server memperbarui `last_heartbeat_at` dan mengembalikan status, tiket aktif, dan batas. <br>3) Penugasan otomatis hanya ke CS yang heartbeat-nya lebih baru dari `assignment.heartbeat_seconds` (90 detik) (0043). <br>4) Dashboard menganggap CS terputus bila heartbeat lebih tua dari 4 × `agent.heartbeat_fresh_seconds` (30) = 120 detik (0038). <br>5) Sesi yang dicabut atau akun nonaktif membuat Hub keluar (`session_revoked`, `agent_required`). <br>6) Hub keluar otomatis setelah idle `ui.idle_logout_minutes` (bawaan 30). |
| Keluaran | Heartbeat tersimpan. |
| Kode error | `401 session_revoked`; `403 agent_required`; `403 mfa_required` |
| Antarmuka | RPC `cs_api.agent_heartbeat`; Hub: `useHeartbeat` |
| Lacak | BR-CS |

#### FR-CS-26 Daftar dan pencarian tiket CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan daftar tiket kerja CS dan pencarian tiket sesuai hak akses pemanggil. |
| Aktor | CS, Super Admin |
| Prakondisi | Akun `cs_agent` atau `cs_super_admin`. |
| Proses dan aturan | 1) `ticket_lists` berisi `open` (maksimal 200, urut prioritas lalu waktu antre), `mine` (tiket aktif milik pemanggil), `resolved_today` (diselesaikan/ditutup pemanggil sejak 00:00 WIB), `all_active` (hanya Super Admin), `transfers_in`, dan `transfers_out` (0033). <br>2) Hub menampilkan tab **Terbuka**, **Tiket saya**, **Selesai hari ini** (Super Admin: **Semua aktif**, **Terbuka**), filter Topik, Prioritas P1–P4, Tanda (Pengaduan, Fraud, VIP), dan Label; daftar dimuat ulang saat event `cs:queue`/`cs:agent:<id>` dan polling 30 detik. <br>3) `search_tickets`: minimal 2 karakter (dipotong 80), mencari nomor tiket, nama, username, `olt_user_id`, dan isi pesan; maksimal 30 hasil, hanya tiket yang boleh dibaca pemanggil. |
| Keluaran | Daftar kartu tiket. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.ticket_lists`, `cs_api.search_tickets`; Hub: Layanan Nasabah (kolom kiri), kotak **Cari nomor, nama, pesan**, Ctrl K |
| Lacak | BR-CS |

#### FR-CS-27 Hak baca tiket dan riwayat nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi siapa yang boleh membaca tiket, pesan, dan catatan CS. |
| Aktor | CS, Super Admin, Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) CS boleh pratinjau hanya-baca tiket `open` (hanya pesan tiket itu); Hub menampilkan **Ambil tiket ini untuk membalas** (0032). <br>2) Pemilik tiket aktif membaca seluruh riwayat room nasabah selama menangani dan sampai `agent.history_hours` (bawaan 24 jam) setelah tiket yang ia tangani selesai/ditutup; CS tujuan transfer yang menunggu juga boleh membaca. <br>3) Akses dicabut saat tiket dilepas atau ditransfer. <br>4) Super Admin membaca semua room dan tiket CS (hanya baca). <br>5) Kepatuhan hanya tiket berflag `complaint`/`fraud` (aturan lain di PATUH, termasuk akses 12 jam 0125). <br>6) Topik realtime `cs:room:<id>`, `cs:agent:<id>`, `cs:queue` diizinkan sesuai aturan yang sama (`cs.can_access_topic`, 0133); klien tidak bisa mengirim broadcast `cs:*`. |
| Keluaran | Data hanya untuk yang berwenang. |
| Kode error | `404 ticket_not_found` |
| Antarmuka | Fungsi `cs.can_read_room`, `cs.can_read_ticket`, `cs.can_read_notes`; RPC `cs_api.ticket_detail`, `cs_api.get_messages` |
| Lacak | BR-CS |

#### FR-CS-28 Mengambil tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberikan tiket `open` kepada tepat satu CS yang mengambilnya, walau diklik bersamaan dari banyak replika API. |
| Aktor | CS |
| Prakondisi | Peran `cs_agent`; status `online`; tiket aktif < `max_active_tickets` (bawaan 5, diatur 1–20 di HUB). |
| Proses dan aturan | 1) Baris status CS dikunci `FOR UPDATE`, lalu satu `UPDATE ... WHERE status = 'open' AND owner_agent_id IS NULL` (0038). <br>2) Yang kalah mendapat `ticket_taken` "Tiket sudah diambil oleh [nama]". <br>3) Berhasil: status `claimed`, `claimed_at`, `first_claimed_at`, versi naik, event `claimed`, audit `ticket.claim`, pesan sistem `ticket_claimed` ke nasabah, siaran `ticket_claimed` dengan nama pengambil. <br>4) Hub: tombol **Ambil** (pintasan A); bila bukan Online tampil "Ubah ke Online dulu" dengan tombol **Ubah ke Online**. <br>5) Super Admin tanpa peran CS ditolak. |
| Keluaran | Tiket milik pemanggil. |
| Kode error | `409 agent_not_online`; `409 ticket_limit`; `409 ticket_taken`; `409 ticket_not_open`; `404 ticket_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.claim_ticket`; Hub: Layanan Nasabah → **Ambil** |
| Lacak | BR-CS |

#### FR-CS-29 Transfer tiket: permintaan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik tiket meminta transfer ke CS lain dengan catatan serah terima, tanpa memindahkan kepemilikan sebelum diterima. |
| Aktor | CS pemilik |
| Prakondisi | Tiket `claimed`/`waiting_customer` milik pemanggil. |
| Proses dan aturan | 1) Tujuan wajib CS lain yang Online dan punya slot (`can_take_tickets`) (0038). <br>2) Catatan serah terima 3–1.000 karakter, disamarkan. <br>3) Hanya satu permintaan menunggu per tiket. <br>4) Kedaluwarsa `transfer.expire_minutes` (10 menit). <br>5) Event `transfer_requested`, audit `ticket.transfer_request`, siaran ke `cs:agent:<tujuan>`. <br>6) Hub memilih tujuan dari `online_agents` (hanya CS online, untuk CS) dan menampilkan **Menunggu diterima**. |
| Keluaran | Permintaan transfer (tanpa isi catatan di respons). |
| Kode error | `400 invalid_target`; `400 handover_note_required`; `409 agent_unavailable`; `409 transfer_pending`; `409 stale_ticket`; `403 not_ticket_owner`; `409 ticket_not_active` |
| Antarmuka | RPC `cs_api.request_transfer`, `cs_api.online_agents`; Hub: tombol **Transfer** |
| Lacak | BR-CS |

#### FR-CS-30 Transfer tiket: jawaban, pembatalan, kedaluwarsa

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memproses penerimaan, penolakan, pembatalan, dan kedaluwarsa permintaan transfer. |
| Aktor | CS tujuan, CS pengirim, Sistem |
| Prakondisi | Permintaan transfer menunggu. |
| Proses dan aturan | 1) Hanya CS tujuan yang bisa menjawab; permintaan yang lewat waktu, tiketnya tidak aktif, atau pemiliknya berubah ditandai `expired` (0038). <br>2) Terima: wajib Online dan punya slot; catatan serah terima disimpan sebagai catatan internal `handover`; kepemilikan pindah (event `transferred`, audit `ticket.transfer_accept`, pesan sistem `ticket_transferred`). <br>3) Tolak: alasan opsional maksimal 300 karakter; pengirim menerima `transfer_rejected`. <br>4) Pengirim bisa membatalkan permintaannya (`cancelled`). <br>5) `cs-sweep` mengedaluwarsakan permintaan yang lewat waktu dan mengirim `transfer_expired` ke pengirim. <br>6) Hub: **Transfer masuk** dengan **Terima**/**Tolak** dan batas waktu **berlaku sampai …**. |
| Keluaran | Transfer selesai dengan hasil `accepted`, `rejected`, `expired`, atau `cancelled`. |
| Kode error | `404 transfer_not_found`; `409 transfer_closed`; `409 agent_unavailable` |
| Antarmuka | RPC `cs_api.respond_transfer`, `cs_api.cancel_transfer`; Hub: **Transfer masuk**, **Menunggu diterima** |
| Lacak | BR-CS |

#### FR-CS-31 Penugasan otomatis

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membagikan tiket `open` secara otomatis ke CS yang memenuhi syarat bila mode penugasan otomatis aktif. |
| Aktor | Sistem |
| Prakondisi | `assignment.mode = 'auto_assign'` (bawaan `claim`). |
| Proses dan aturan | 1) Syarat CS: peran `cs_agent`, aktif, Online, slot kosong, menguasai bahasa tiket, heartbeat < 90 detik (`cs.is_reachable`, 0043); tidak dibatasi jam layanan. <br>2) Urutan tiket: prioritas lalu waktu antre; urutan CS: level skill topik tertinggi, lalu tiket aktif paling sedikit, lalu paling lama tidak mendapat tiket (0049). <br>3) Tiket yang dilepas tidak ditugaskan kembali ke CS yang melepas (`released_by`), kecuali diambil manual; pengecualian hilang saat status berubah (0049). <br>4) Dijalankan langsung lewat constraint trigger deferred saat tiket masuk antrean, CS menjadi Online atau punya slot, dan mode diubah ke `auto_assign` (0040); `cs-sweep` sebagai jaring pengaman. <br>5) Tercatat sebagai aksi `system` (event `assigned`); Hub memberi bunyi dan notifikasi **Tiket baru ditugaskan ke Anda**. <br>6) Super Admin tidak pernah menerima tiket otomatis. |
| Keluaran | Tiket `claimed` oleh CS terpilih. |
| Kode error | — |
| Antarmuka | Fungsi `cs.auto_assign_open`, `cs.assign_when_auto`; Hub: Pengaturan → Penugasan, tiket & alert → Mode penugasan |
| Lacak | BR-CS |

#### FR-CS-32 Melepas tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik mengembalikan tiket ke antrean dengan alasan. |
| Aktor | CS pemilik |
| Prakondisi | Tiket `claimed`/`waiting_customer` milik pemanggil. |
| Proses dan aturan | 1) Alasan 3–300 karakter, disimpan di `returned_reason` (0049). <br>2) Transfer menunggu dibatalkan; status `open`; `released_by` diisi pemanggil. <br>3) Audit `ticket.release`, pesan sistem `ticket_released` ke nasabah, siaran `ticket_released`. <br>4) Mendukung `p_version` (FR-CS-40). |
| Keluaran | Tiket kembali ke antrean Terbuka. |
| Kode error | `400 reason_required`; `403 not_ticket_owner`; `409 ticket_not_active`; `409 stale_ticket` |
| Antarmuka | RPC `cs_api.release_ticket`; Hub: tombol **Lepas** |
| Lacak | BR-CS |

#### FR-CS-33 Menunggu balasan nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik menandai tiket sedang menunggu balasan nasabah. |
| Aktor | CS pemilik |
| Prakondisi | Tiket `claimed` milik pemanggil. |
| Proses dan aturan | 1) Hanya dari `claimed`; tiket yang sudah `waiting_customer` ditolak `invalid_transition` (0038). <br>2) Status `waiting_customer`, siaran `ticket_updated`; kembali `claimed` saat nasabah membalas. <br>3) Pengingat otomatis mengikuti FR-CS-20. |
| Keluaran | Tiket `waiting_customer`. |
| Kode error | `409 invalid_transition`; `403 not_ticket_owner`; `409 stale_ticket` |
| Antarmuka | RPC `cs_api.wait_customer`; Hub: tombol **Tunggu nasabah** |
| Lacak | BR-CS |

#### FR-CS-34 Menyelesaikan tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik menyelesaikan tiket dengan hasil dan ringkasan internal, lalu meminta rating ke nasabah. |
| Aktor | CS pemilik |
| Prakondisi | Tiket `claimed`/`waiting_customer` milik pemanggil. |
| Proses dan aturan | 1) Hasil wajib dari `resolve.outcomes` (`answered`, `follow_up`, `complaint`, `other`) (0032). <br>2) Ringkasan 5–500 karakter, disamarkan, tidak terlihat nasabah; tag opsional maksimal 10, pola `^[a-z0-9_-]{1,32}$` (0038). <br>3) Transfer menunggu dibatalkan, status `resolved`, `resolved_by`, staf keluar dari room, beban CS dihitung ulang. <br>4) Pesan sistem `ticket_resolved` berjenis `csat` (permintaan rating), audit `ticket.resolve`, siaran `ticket_resolved`. <br>5) Hub: tombol **Selesaikan** (pintasan E). |
| Keluaran | Tiket `resolved`. |
| Kode error | `400 invalid_outcome`; `400 summary_required`; `400 invalid_tags`; `403 not_ticket_owner`; `409 stale_ticket` |
| Antarmuka | RPC `cs_api.resolve_ticket`; Hub: tombol **Selesaikan** |
| Lacak | BR-CS |

#### FR-CS-35 Pemilik offline: pemberitahuan dan lepas otomatis

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi tahu nasabah saat CS pemilik tiket Offline dan, bila diaktifkan, mengembalikan tiket CS yang terlalu lama tidak aktif ke antrean. |
| Aktor | Sistem |
| Prakondisi | CS pemilik beralih ke `offline` atau tidak aktif. |
| Proses dan aturan | 1) Saat status berubah ke `offline`, setiap tiket aktif miliknya menerima pesan sistem `agent_away` ("CS [nama] sedang tidak aktif…") dan event `owner_away` (0032). <br>2) Bila `ticket.auto_release_offline_minutes` > 0 (rentang 0–1.440, bawaan 0 = mati), `cs-sweep` melepas tiket milik CS yang offline, nonaktif, atau tanpa heartbeat lebih lama dari batas, dengan alasan "Pemilik offline lebih dari N menit" (0056). <br>3) Lepas otomatis tidak memakai pengecualian `released_by` (0049). <br>4) Tanpa lepas otomatis, tiket tetap milik CS; Super Admin dapat memindahkannya (FR-CS-56). |
| Keluaran | Pesan pemberitahuan; tiket kembali `open` bila diaktifkan. |
| Kode error | — |
| Antarmuka | Fungsi `cs.notify_owner_away`, `cs.release_owner_tickets`, `cs.run_sweep` |
| Lacak | BR-CS |

#### FR-CS-36 Tutup otomatis tiket selesai

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menutup otomatis tiket `resolved` yang sudah dinilai atau belum dinilai sampai batas hari. |
| Aktor | Sistem |
| Prakondisi | Tiket `resolved`. |
| Proses dan aturan | 1) `reopen_until` = `resolved_at` + `ticket.auto_close_days` hari (rentang 1–30, bawaan 3) selama belum dinilai (0056). <br>2) `cs-sweep` (pg_cron tiap 10 detik) menutup tiket `resolved` yang sudah dinilai (alasan `rated`) atau lewat `reopen_until` (alasan `reopen_window_passed`), memakai `FOR UPDATE SKIP LOCKED`. <br>3) Penutupan memicu pesan sistem `ticket_closed` dan siaran `ticket_closed`. |
| Keluaran | Tiket `closed`. |
| Kode error | — |
| Antarmuka | Fungsi `cs.run_sweep`; Hub: Pengaturan → Penugasan, tiket & alert → **Batas tanpa rating (hari, 1–30)** |
| Lacak | BR-CS |

#### FR-CS-37 Batas tiket aktif per CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menegakkan batas tiket aktif per CS pada setiap jalan masuk tiket ke CS. |
| Aktor | Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) Tiket aktif = tiket `claimed`/`waiting_customer` milik CS (`cs.active_ticket_count`). <br>2) Klaim, terima transfer, penugasan otomatis, dan buka kembali ke pemilik hanya bila tiket aktif < `max_active_tickets`. <br>3) Reassign Super Admin juga menolak tujuan yang penuh. <br>4) Kolom `agent_status.active_tickets` diperbarui setiap kepemilikan berubah. |
| Keluaran | Tidak ada CS melebihi batasnya. |
| Kode error | `409 ticket_limit`; `409 agent_unavailable` |
| Antarmuka | Fungsi `cs.can_take_tickets`, `cs.require_capacity`; Hub: angka **Aktif n/maks** |
| Lacak | BR-CS |

#### FR-CS-38 Membuka kembali tiket selesai

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuka kembali tiket `resolved` bila nasabah membalas sebelum rating dan sebelum batas tutup otomatis. |
| Aktor | Nasabah, Sistem |
| Prakondisi | Tiket `resolved`, belum dinilai, sekarang < `reopen_until`. |
| Proses dan aturan | 1) Bila pemilik lama tidak away lebih dari `ticket.owner_away_minutes` (10 menit) dan punya slot, tiket kembali `claimed` ke pemilik itu dengan pesan `ticket_reopened_owner` (0032). <br>2) Bila tidak, tiket kembali `open` dengan pesan `ticket_reopened`. <br>3) Event `reopened` dihitung di laporan per nasabah. |
| Keluaran | Tiket aktif kembali. |
| Kode error | — |
| Antarmuka | Fungsi `cs.reopen_ticket` (dipicu `cs_api.send_message`) |
| Lacak | BR-CS |

#### FR-CS-39 Jejak kejadian dan audit tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat setiap kejadian tiket dan setiap aksi staf secara append-only. |
| Aktor | Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) `cs.session_events` (partisi bulanan) mencatat kejadian seperti `opened`, `claimed`, `assigned`, `released`, `transfer_requested`, `transferred`, `reassigned`, `waiting_customer`, `customer_replied`, `resolved`, `reopened`, `closed`, `rated`, `flagged`, `priority_changed`, `label_added`, `label_removed`, `secret_request_blocked`, `owner_away`, `customer_reminded`. <br>2) `cs.cs_audit_log` (partisi bulanan) mencatat aksi CS, Super Admin, dan sistem (mis. `ticket.claim`, `ticket.reassign`, `setting.update`). <br>3) `ticket_detail` menampilkan kejadian berurutan dengan nama pelaku; Jejak Audit dibuka dari menu Kepatuhan (PATUH). |
| Keluaran | Log kejadian dan audit. |
| Kode error | — |
| Antarmuka | RPC `cs_api.ticket_detail`; Hub: riwayat tiket di percakapan |
| Lacak | BR-CS |

#### FR-CS-40 Kontrol konkurensi versi tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak aksi tiket yang didasarkan pada versi tiket yang sudah usang. |
| Aktor | CS, Super Admin |
| Prakondisi | Aksi mengirim `p_version`. |
| Proses dan aturan | 1) Setiap perubahan tiket menaikkan `cs.tickets.version` (0032). <br>2) Lepas, transfer, tunggu nasabah, selesai, dan prioritas menerima `p_version`; bila berbeda, ditolak `stale_ticket`. <br>3) Hub menampilkan **Tiket sudah berubah. Data terbaru dimuat ulang.** dan memuat ulang tiket. |
| Keluaran | Aksi ditolak tanpa perubahan. |
| Kode error | `409 stale_ticket` |
| Antarmuka | Fungsi `cs.lock_ticket`, `cs.owned_ticket` |
| Lacak | BR-CS |

#### FR-CS-41 Pesan teks CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan hanya pemilik tiket aktif mengirim pesan ke nasabah. |
| Aktor | CS pemilik |
| Prakondisi | Tiket `claimed`/`waiting_customer` milik pemanggil; status bukan Offline. |
| Proses dan aturan | 1) Body maksimal 4.000 karakter; wajib berisi teks kecuali `kind = 'text'` dengan lampiran (0038). <br>2) Mendukung `p_reply_to_id` dan `p_attachments` (FR-CS-52); `client_id` idempoten. <br>3) Pesan bertanda `sender_role = 'agent'`; Super Admin tidak mengirim pesan, pesan `supervisor` lama tetap tampil. <br>4) Pesan pertama mengisi `first_response_at`; setiap pesan mengisi `last_agent_message_at`. <br>5) Pemeriksaan permintaan rahasia (FR-CS-43) dan penyamaran (FR-CS-09). <br>6) Hub: Enter kirim, Shift+Enter baris baru, status **Mengirim…/Terkirim/Dibaca/Gagal terkirim** (CHAT). |
| Keluaran | `{status: 'sent', message}` atau `{status: 'blocked'}`. |
| Kode error | `409 ticket_not_active`; `403 not_ticket_owner`; `400 body_too_long`; `400 body_required`; `400 invalid_kind`; `409 agent_offline` |
| Antarmuka | RPC `cs_api.agent_send_message(p_ticket_id, p_body, p_client_id, p_kind, p_payload, p_reply_to_id, p_attachments)`; Hub: kotak balas mode **Balas** |
| Lacak | BR-CS |

#### FR-CS-42 Balasan ditolak saat CS Offline

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak pesan staf ke nasabah bila staf berstatus Offline, tanpa menghalangi aksi non-balasan. |
| Aktor | CS |
| Prakondisi | Status `offline`. |
| Proses dan aturan | 1) Trigger `messages_reject_offline_agent_reply` menolak setiap pesan ber-`session_id` dari staf Offline (0041). <br>2) Catatan internal, selesaikan, lepas, dan transfer keluar tetap boleh. <br>3) Hub mengunci kotak balas (teks, lampiran, pesan khusus, tombol Kirim) dengan keterangan Offline dan tombol **Ubah ke Online**, tanpa menghapus draf. |
| Keluaran | Pesan ditolak; draf tetap. |
| Kode error | `409 agent_offline` |
| Antarmuka | Trigger `cs.reject_offline_agent_reply`; Hub: `go-online-button` di kotak balas |
| Lacak | BR-CS |

#### FR-CS-43 Blokir permintaan OTP, PIN, dan password

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menahan pesan CS yang meminta OTP, PIN, password, atau data rahasia lain dan memberi tahu Super Admin, tanpa melempar error. |
| Aktor | CS, Sistem |
| Prakondisi | Teks pesan atau opsi pilihan cepat cocok dengan pola permintaan rahasia (`cs.requests_secret`). |
| Proses dan aturan | 1) Pesan tidak disimpan; respons `status: 'blocked'`, `code: 'secret_request_blocked'` (0038). <br>2) Event `secret_request_blocked`, audit `message.secret_request_blocked` dengan cuplikan tersamar maksimal 200 karakter, peringatan `secret_request_blocked` di `cs:queue` beserta kode CS; Super Admin menerima notifikasi **CS mencoba meminta data rahasia**; percobaan muncul di Ringkasan Kepatuhan (PATUH). <br>3) Hub memeriksa lebih dulu di browser (kata rahasia + kata perintah per kalimat, kecuali kalimat negasi seperti "jangan") dan menahan dengan peringatan **CS tidak boleh meminta OTP, PIN, password, atau nomor kartu. Ubah kalimat sebelum mengirim.** <br>4) Balasan cepat yang meminta rahasia ditolak saat disimpan (FR-CS-49, FR-CS-50). |
| Keluaran | Pesan ditahan, peringatan tercatat. |
| Kode error | — (respons `blocked`) |
| Antarmuka | RPC `cs_api.agent_send_message`; Hub: `requestsSecret` di composer |
| Lacak | BR-CS |

#### FR-CS-44 Pesan pilihan cepat dan tautan bantuan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan CS mengirim pesan berisi tombol pilihan dan tautan bantuan resmi. |
| Aktor | CS pemilik |
| Prakondisi | Seperti FR-CS-41. |
| Proses dan aturan | 1) `kind = 'quick_reply'`: payload `options` berisi 2–6 teks, masing-masing 1–40 karakter (0038); Hub membatasi 2–4 pilihan; nasabah mengetuk satu pilihan yang terkirim sebagai teks. <br>2) `kind = 'help_link'`: URL wajib `https://` ke host di `help.allowed_hosts` (bawaan `help.olt.co.id`) (0027, 0038). <br>3) Hub: tombol **Kirim lainnya** → **Tautan bantuan** (Judul, Alamat https) dan **Pilihan cepat** (Pertanyaan + pilihan). <br>4) Tautan dari nasabah ke luar situs resmi memunculkan konfirmasi **Buka tautan luar?** di Hub. |
| Keluaran | Pesan khusus terkirim. |
| Kode error | `400 invalid_options`; `400 invalid_help_link`; `400 invalid_kind` |
| Antarmuka | RPC `cs_api.agent_send_message`; Hub: `special-dialogs` |
| Lacak | BR-CS |

#### FR-CS-45 Catatan internal

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan catatan internal staf per tiket atau per nasabah yang tidak pernah terlihat nasabah. |
| Aktor | CS, Super Admin |
| Prakondisi | Pemanggil boleh membaca catatan nasabah itu (`cs.can_read_notes`). |
| Proses dan aturan | 1) Body 1–4.000 karakter, disamarkan (0033). <br>2) Catatan per tiket (`p_ticket_id`) atau per nasabah (`p_customer_id`, tampil di tiket berikutnya). <br>3) Append-only di `cs.agent_notes`, terpisah dari `messages`; tidak bisa diubah setelah disimpan. <br>4) Catatan serah terima transfer disimpan sebagai jenis `handover`. <br>5) Kepatuhan membaca catatan tiket berflag (PATUH). <br>6) Hub: mode **Catatan internal** (**Tidak terlihat nasabah**, pintasan N) dan **Tambah catatan** di Info nasabah (**Untuk tiket ini** / **Untuk nasabah (semua tiket)**). |
| Keluaran | Catatan tersimpan. |
| Kode error | `403 notes_forbidden`; `400 invalid_note` |
| Antarmuka | RPC `cs_api.add_note`, `cs_api.notes`; Hub: kotak balas mode Catatan internal, panel Info nasabah |
| Lacak | BR-CS |

#### FR-CS-46 Mengubah prioritas tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik tiket atau Super Admin mengubah prioritas tiket aktif. |
| Aktor | CS pemilik, Super Admin |
| Prakondisi | Tiket belum `resolved`/`closed`. |
| Proses dan aturan | 1) Prioritas `P1`–`P4` (0033). <br>2) Selain Super Admin, hanya pemilik tiket. <br>3) Versi naik, event `priority_changed`, audit `ticket.priority`, siaran `ticket_updated`. <br>4) Hub: **Aksi lainnya** → **Ubah prioritas**. |
| Keluaran | Prioritas baru. |
| Kode error | `400 invalid_priority`; `409 ticket_not_active`; `403 not_ticket_owner`; `409 stale_ticket` |
| Antarmuka | RPC `cs_api.set_ticket_priority`; Hub: **Aksi lainnya** |
| Lacak | BR-CS |

#### FR-CS-47 Menandai pengaduan atau penipuan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pemilik tiket atau Super Admin menandai tiket sebagai pengaduan atau penipuan dengan alasan. |
| Aktor | CS pemilik, Super Admin |
| Prakondisi | Tiket aktif; tanda belum terpasang. |
| Proses dan aturan | 1) Flag `complaint` atau `fraud`; alasan 5–300 karakter (0133). <br>2) Tanda yang sudah ada ditolak `already_flagged`; Hub menyembunyikan menu untuk tanda yang sudah terpasang. <br>3) `fraud` → P1; `complaint` → maksimal P2 dan tenggat pengaduan + pesan sistem ke nasabah (FR-CS-16). <br>4) Event `flagged` dengan alasan, audit `ticket.flag`, catatan `cs.compliance_notices` (`source = 'agent'`) dan event `case_flagged` di `cs:compliance` (PATUH). |
| Keluaran | Tiket bertanda. |
| Kode error | `400 reason_required`; `409 already_flagged`; `400 invalid_flag`; `409 ticket_not_active`; `403 not_ticket_owner` |
| Antarmuka | RPC `cs_api.flag_ticket(p_ticket_id, p_flag, p_reason)`; Hub: **Aksi lainnya** → **Tandai pengaduan** / **Tandai penipuan** (`flag-dialog`) |
| Lacak | BR-CS |

#### FR-CS-48 Label tiket pada tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf memasang dan melepas label internal pada tiket. |
| Aktor | CS pemilik, Super Admin |
| Prakondisi | Label aktif (FR-CS-63). |
| Proses dan aturan | 1) CS pemegang tiket aktif (`claimed`/`waiting_customer`) atau Super Admin (status apa pun); Kepatuhan hanya membaca (0118). <br>2) Maksimal 5 label per tiket; label nonaktif tidak bisa dipasang. <br>3) Event `label_added`/`label_removed`, audit `ticket.label_add`/`ticket.label_remove`, event `ticket_labels` di `cs:queue`, `cs:agent`, dan `cs:room`. <br>4) Label tampil di baris tiket, di bawah nama nasabah, dan filter Label; tidak pernah ikut di tampilan nasabah. |
| Keluaran | Label tiket diperbarui. |
| Kode error | `404 ticket_not_found`; `403 not_ticket_owner`; `404 label_not_found`; `409 label_inactive`; `409 ticket_label_limit` |
| Antarmuka | RPC `cs_api.ticket_labels`, `cs_api.add_ticket_label`, `cs_api.remove_ticket_label`; Hub: ikon label di kepala percakapan (`ticket-label-menu`) |
| Lacak | BR-CS |

#### FR-CS-49 Balasan cepat bersama

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan balasan cepat bersama yang dikelola Super Admin dan dapat disisipkan CS ke kotak balas. |
| Aktor | Super Admin, CS |
| Prakondisi | — |
| Proses dan aturan | 1) Pintasan `^[a-z0-9_-]{2,32}$` unik, judul 1–80, isi 1–2.000 karakter, bahasa `id`/`en` (0035). <br>2) Isi yang meminta OTP/PIN/password ditolak. <br>3) `quick_replies(p_language)` mengembalikan balasan pribadi pemanggil lebih dulu, lalu balasan bersama sesuai bahasa (0117). <br>4) Hub: ketik `/` atau **Sisipkan balasan cepat**, grup **Pribadi** dan **Bersama**, panah atas/bawah, Enter/Tab; isi hanya disisipkan, pengiriman tetap lewat FR-CS-41. |
| Keluaran | Daftar balasan cepat. |
| Kode error | `400 invalid_shortcut`; `400 invalid_title`; `400 invalid_body`; `400 invalid_language`; `400 secret_request_blocked`; `409 duplicate_shortcut`; `404 quick_reply_not_found` |
| Antarmuka | RPC `cs_api.admin_quick_replies`, `cs_api.admin_save_quick_reply`, `cs_api.quick_replies`; Hub: Pengaturan → Quick reply |
| Lacak | BR-CS |

#### FR-CS-50 Balasan cepat pribadi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan setiap CS mengelola balasan cepat pribadi yang hanya terlihat olehnya. |
| Aktor | CS |
| Prakondisi | Peran `cs_agent`. |
| Proses dan aturan | 1) `cs.quick_replies` dengan `scope = 'personal'` dan `owner_id`; RLS hanya pemilik (0117). <br>2) Batas sama dengan balasan bersama; pintasan kosong dibuat otomatis dari judul; maksimal 50 per staf. <br>3) Permintaan OTP/PIN/password ditolak; nomor rekening/kartu disamarkan saat disimpan. <br>4) Tidak ada jalur kirim langsung; pengiriman tetap lewat FR-CS-41. <br>5) Hub: **Kelola balasan pribadi** di bawah daftar balasan cepat. |
| Keluaran | Balasan pribadi tersimpan. |
| Kode error | `400 invalid_title`; `400 invalid_body`; `400 invalid_shortcut`; `400 secret_request_blocked`; `409 quick_reply_limit`; `409 duplicate_shortcut`; `404 quick_reply_not_found` |
| Antarmuka | RPC `cs_api.my_quick_replies`, `cs_api.save_my_quick_reply`, `cs_api.delete_my_quick_reply`; Hub: `personal-replies-dialog` |
| Lacak | BR-CS |

#### FR-CS-51 Panel info nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan konteks nasabah di samping percakapan: riwayat tiket, catatan internal, dan tautan ke data akun bila diizinkan. |
| Aktor | CS, Super Admin |
| Prakondisi | Pemanggil boleh membaca tiket. |
| Proses dan aturan | 1) `customer_history` mengembalikan semua tiket nasabah (nomor, topik, status, flag, waktu, hasil, rating, nama CS); Hub menampilkan **Nilai n/5** (0033). <br>2) Catatan per tiket dan per nasabah (FR-CS-45). <br>3) Panel kanan tiket juga menampilkan **Jawaban awal nasabah** dan **SOP topik** (BANTU). <br>4) `ticket_customer_login` mengembalikan LoginId dari token login atau profil, untuk bagian Akun Nasabah (INT); tidak ada data bisnis OLT di chat (0037). <br>5) Panel dapat diciutkan; untuk tiket tamu berlaku FR-CS-23. |
| Keluaran | Panel Info nasabah. |
| Kode error | `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.customer_history`, `cs_api.notes`, `cs_api.ticket_customer_login`; Hub: Layanan Nasabah → **Info nasabah** (`customer-panel`) |
| Lacak | BR-CS |

#### FR-CS-52 Lampiran CS: validasi saat kirim dan akses baca

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memvalidasi lampiran pesan chat CS terhadap kebijakan lampiran dan membatasi siapa yang boleh mengunggah dan membaca file CS. |
| Aktor | Nasabah, CS |
| Prakondisi | Room `support`; file sudah diunggah lewat layanan media (FR-CS-53). |
| Proses dan aturan | 1) Maksimal 4 lampiran per pesan (constraint `messages`, 0008). <br>2) Jenis dari bucket: `attachments` = gambar, `cs-documents` = dokumen, `cs-videos` = video; jenis harus aktif, MIME harus format aktif, ekstensi path dokumen/video harus cocok, ukuran ≤ `max_bytes` (0131, 0138). <br>3) Video wajib `duration` > 0 dan ≤ `max_seconds`; `thumbnail` opsional berpola `rooms/<room>/<uid>/<nama>.jpg`. <br>4) Nama file opsional maksimal 200 karakter. <br>5) Unggah ke `cs-documents`/`cs-videos` hanya ke folder `rooms/<room>/<uid pengunggah>/` oleh nasabah pemilik room atau staf anggota room, dengan klaim `media_verified` untuk nasabah (0053, 0063, 0131). <br>6) Baca: nasabah pemilik room dan staf yang boleh membaca room (FR-CS-27). <br>7) Chat global tetap hanya gambar (CHAT). |
| Keluaran | Pesan dengan lampiran sah. |
| Kode error | `400 attachment_not_allowed`; `400 attachment_too_large`; `400 attachment_too_long`; `400 invalid_attachments` |
| Antarmuka | Fungsi `private.check_message_media`; kebijakan storage `olt_cs_videos_*`, `cs-documents` |
| Lacak | BR-CS |

#### FR-CS-53 Lampiran CS: pemeriksaan file dan antivirus

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memeriksa isi setiap lampiran chat CS sebelum disimpan, termasuk pemindaian antivirus untuk dokumen dan video. |
| Aktor | Layanan media (OPS) |
| Prakondisi | Upload `POST /media/v1/object/{bucket}/{path}` dengan JWT `authenticated`. |
| Proses dan aturan | 1) Kebijakan lampiran harus termuat (refresh maksimal 30 detik); jenis yang dimatikan ditolak (services/media/README.md). <br>2) Jenis ditentukan dari isi (magic bytes, struktur ZIP Office, ISO BMFF/EBML); ekstensi hanya membedakan teks `.txt`/`.log`/`.csv`. <br>3) Gambar disanitasi lossless (EXIF/GPS dibuang) dan diperiksa classifier NSFW; PDF terenkripsi atau berkonten aktif ditolak; Office bermakro, ActiveX, OLE, relasi eksternal berbahaya, atau zip bomb ditolak; teks wajib UTF-8 tanpa NUL. <br>4) Semua upload `cs-documents` dan `cs-videos` dipindai ClamAV (`zINSTREAM`) sebelum disimpan; terdeteksi → `malware_detected`; pemindai tidak bisa dipakai → `scanner_unavailable` (fail closed). <br>5) Video di-remux `ffmpeg -c copy` tanpa metadata, codec H.264/HEVC/VP8/VP9/AV1, thumbnail JPEG dari detik ke-1 juga diperiksa classifier. <br>6) Batas bucket: gambar room CS sampai 10 MiB, dokumen 10 MiB, video 25 MiB dan 120 detik. <br>7) Hub dan library menampilkan **Memeriksa file…** selama proses. |
| Keluaran | Objek tersimpan dengan `path`, `mime`, `size` (dan `duration`, `thumbnail` untuk video). |
| Kode error | `403 kind_disabled`; `503 policy_unavailable`; `413 file_too_large`; `415 unsupported_type`; `422 malware_detected`; `503 scanner_unavailable`; `422 office_macro`; `422 office_unsafe`; `422 archive_bomb`; `422 pdf_encrypted`; `422 pdf_active_content`; `422 invalid_text`; `422 invalid_video`; `422 video_too_long`; `422 image_blocked`; `429 too_many_uploads` |
| Antarmuka | Endpoint `POST /media/v1/object/{bucket}/{path}` |
| Lacak | BR-CS |

#### FR-CS-54 Lampiran CS di Hub dan aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Hub dan library harus menyediakan cara memilih, memeriksa awal, dan menampilkan lampiran chat CS sesuai kebijakan server. |
| Aktor | CS, Nasabah |
| Prakondisi | Kebijakan lampiran dibaca lewat `cs_api.attachment_policy` (pengguna masuk). |
| Proses dan aturan | 1) Hub: tombol klip **Lampirkan file**, seret ke kotak balas, atau tempel Ctrl+V di percakapan; **Pratinjau lampiran** sebelum kirim; gambar tempel yang terlalu besar dikompres JPEG (sisi 2560 px kualitas 0,85, lalu 1920 px kualitas 0,75). <br>2) Library: pemilih file menampilkan grup Foto, Video, Dokumen hanya untuk jenis aktif; file dicek format dan `max_bytes` sebelum unggah; HEIC/HEIF diubah ke JPEG di perangkat; server lama tanpa RPC memakai kebijakan `legacy` (gambar + PDF 10 MB). <br>3) Dokumen tampil sebagai kartu dengan ikon per jenis, nama asli, dan unduh; video dengan thumbnail dan durasi. <br>4) Tamu tidak bisa mengunggah (FR-CS-22). |
| Keluaran | Lampiran terkirim dan tampil. |
| Kode error | `403 forbidden` |
| Antarmuka | RPC `cs_api.attachment_policy`; Hub: `composer`, `pending-attachments`, `attachment-file`, `attachment-video`; Library: `MessageComposer(attachmentPolicy:)`, `CommunityAttachmentPolicy` |
| Lacak | BR-CS |

#### FR-CS-55 Mode pantau Super Admin

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi Super Admin akses pantau ke semua tiket tanpa kemampuan menangani tiket. |
| Aktor | Super Admin |
| Prakondisi | Peran `cs_super_admin` tanpa `cs_agent` (Super Admin yang juga CS memakai hak CS). |
| Proses dan aturan | 1) Membaca semua tiket dan percakapan hanya-baca; tab **Semua aktif** dan **Terbuka** (0038). <br>2) Boleh: catatan internal, ubah prioritas, tandai pengaduan/penipuan, label, dan memindahkan tiket (FR-CS-56). <br>3) Ditolak: ambil, balas, selesaikan, lepas, transfer, tunggu nasabah; tidak pernah menerima tiket lewat transfer, pemindahan, atau penugasan otomatis. <br>4) Notifikasi khusus Super Admin: tiket terlambat (FR-CS-57), **Laporan CS palsu**, **CS mencoba meminta data rahasia**. |
| Keluaran | Tampilan pantau. |
| Kode error | `403 role_forbidden` |
| Antarmuka | Hub: Layanan Nasabah → **Mode pantau** (`read-only-bar`) |
| Lacak | BR-CS |

#### FR-CS-56 Memindahkan tiket oleh Super Admin

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin memindahkan tiket aktif langsung ke CS lain dengan alasan. |
| Aktor | Super Admin |
| Prakondisi | Tiket `open`, `claimed`, atau `waiting_customer`. |
| Proses dan aturan | 1) Alasan 3–300 karakter (0038). <br>2) Tujuan harus akun aktif berperan `cs_agent`, berbeda dari pemilik sekarang, dan belum penuh; tidak harus Online. <br>3) Transfer yang menunggu dibatalkan; kepemilikan pindah (event `reassigned`), audit `ticket.reassign` (dari, ke, alasan), pesan sistem `ticket_transferred` ke nasabah. <br>4) Dipakai antara lain untuk tiket milik CS yang offline. |
| Keluaran | Tiket milik CS tujuan. |
| Kode error | `400 reason_required`; `409 ticket_not_active`; `400 invalid_target`; `404 agent_not_found`; `409 agent_unavailable`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.reassign_ticket`, `cs_api.online_agents`; Hub: **Pindahkan ke…** |
| Lacak | BR-CS |

#### FR-CS-57 Dashboard supervisor dan alert tiket terlambat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan dashboard realtime keadaan antrean dan CS untuk Super Admin beserta peringatan tiket yang perlu perhatian. |
| Aktor | Super Admin |
| Prakondisi | Peran `cs_super_admin`. |
| Proses dan aturan | 1) Angka: tiket terbuka, waktu antre terlama, sedang ditangani, selesai hari ini (WIB), CS online (0038). <br>2) Perlu perhatian: tiket `open` melewati `alerts.unclaimed_minutes` (bawaan 10) atau P1 melewati `alerts.p1_unclaimed_minutes` (bawaan 2), rentang 1–240 menit; tiket fraud/pengaduan yang belum diambil; tiket milik CS offline atau tanpa heartbeat > 120 detik. <br>3) Tabel status CS: status, terhubung, tiket aktif/batas, selesai hari ini, sejak kapan statusnya; keterangan **Web CS tidak mengirim heartbeat**. <br>4) Hub memuat ulang saat event `cs:queue` dan tiap 30 detik; tiket terlambat baru memicu suara dan notifikasi browser sekali per tiket (lebih dari 3 sekaligus digabung); jumlah tiket perlu perhatian tampil sebagai badge menu Dashboard. <br>5) Mengklik tiket membukanya di Layanan Nasabah (mode pantau). |
| Keluaran | Data dashboard. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.supervisor_overview`; Hub: **Dashboard** (`dashboard-page`, `queue-chart`) |
| Lacak | BR-CS |

#### FR-CS-58 Notifikasi kerja di Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memberi tahu staf tentang tiket dan transfer yang relevan lewat suara, toast, dan notifikasi browser sesuai preferensi. |
| Aktor | CS, Super Admin |
| Prakondisi | Hub terbuka dan berlangganan realtime. |
| Proses dan aturan | 1) Tiket ditugaskan ke saya: suara + notifikasi **Tiket baru ditugaskan ke Anda** (toast bila halaman di depan). <br>2) Tiket baru (`ticket_opened`) mengikuti preferensi **Notifikasi tiket baru**: **Semua tiket**, **Prioritas tinggi saja** (P1/P2), atau **Mati**. <br>3) Pesan nasabah di tiket yang tidak sedang dibuka; permintaan transfer masuk (selalu notifikasi browser); transfer ditolak, kedaluwarsa, dibatalkan sebagai toast. <br>4) Super Admin: peringatan `fake_cs_reported` dan `secret_request_blocked`. <br>5) Notifikasi browser dikirim saat halaman di latar belakang; mengkliknya membuka tiket. Menu lonceng: **Izinkan notifikasi browser**, **Tes suara**. |
| Keluaran | Pemberitahuan di Hub. |
| Kode error | — |
| Antarmuka | Hub: `useConsoleAlerts`, ikon lonceng |
| Lacak | BR-CS |

#### FR-CS-59 Laporan ringkasan layanan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan laporan kinerja layanan CS untuk rentang tanggal yang dipilih Super Admin. |
| Aktor | Super Admin |
| Prakondisi | Rentang 1–93 hari, dihitung per hari WIB menurut tanggal tiket dibuat. |
| Proses dan aturan | 1) Total: tiket masuk, selesai, rata-rata menit sampai diambil, respons pertama, durasi sampai selesai (sejak dibuat), rating rata-rata dan jumlah rating (0035). <br>2) Per hari: angka yang sama per tanggal. <br>3) Per CS (pemilik terakhir): ditangani, diselesaikan, rata-rata respons pertama sejak diambil, rating rata-rata. <br>4) Topik terbanyak. <br>5) Hub: rentang **Hari ini**, **7 hari**, **30 hari**, **Pilih tanggal**. <br>6) Kinerja pribadi CS (**Kinerja saya**) memakai definisi yang sama (HUB). |
| Keluaran | JSON laporan. |
| Kode error | `400 invalid_range`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.report_summary`; Hub: **Laporan** (`reports-page`, `daily-chart`) |
| Lacak | BR-CS |

#### FR-CS-60 Laporan per nasabah dan jejak layanan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan performa layanan per nasabah dan jejak layanan rinci per nasabah, dengan pencatatan akses. |
| Aktor | Super Admin |
| Prakondisi | Rentang 1–93 hari. |
| Proses dan aturan | 1) `report_customers`: maksimal 200 nasabah, pencarian nama/username maksimal 100 karakter; per nasabah jumlah tiket, selesai, dibuka kembali, pengaduan, rata-rata respons pertama, durasi sampai selesai, rating rata-rata, jumlah rating, ditutup tanpa rating, tiket terakhir (0056). <br>2) `report_customer_trail`: maksimal 100 tiket dengan CS penangan, waktu diambil/respons/selesai/ditutup, menit, rating dan komentar, alasan tutup, jumlah dibuka kembali dan transfer, serta seluruh event. <br>3) Membuka jejak layanan diaudit `report.customer_trail`. <br>4) Hub mengingatkan bahwa akses tercatat. |
| Keluaran | Daftar nasabah; jejak layanan. |
| Kode error | `400 invalid_range`; `400 invalid_search`; `404 customer_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.report_customers`, `cs_api.report_customer_trail`; Hub: Laporan → **Per nasabah** → **Jejak layanan nasabah** |
| Lacak | BR-CS |

#### FR-CS-61 Laporan alasan nilai rendah dan label

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus melaporkan alasan nilai rendah per topik dan per CS, serta jumlah tiket per label. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) `admin_rating_reasons`: rentang maksimal 366 hari menurut `rated_at`, bawaan 30 hari terakhir; hasil `by_topic` dan `by_agent` (0135). <br>2) `report_ticket_labels(p_from, p_to)`: rentang 1–93 hari; tiket masuk per label, total, dan tanpa label (0118). <br>3) Hub: tabel **Alasan nilai rendah** dan **Tiket per label**. |
| Keluaran | Tabel laporan. |
| Kode error | `400 invalid_range`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_rating_reasons`, `cs_api.report_ticket_labels`; Hub: Laporan (`rating-reasons-section`, `labels-report`) |
| Lacak | BR-CS |

#### FR-CS-62 Ekspor CSV laporan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus mengekspor setiap bagian laporan ke CSV yang aman dibuka di spreadsheet. |
| Aktor | Super Admin |
| Prakondisi | Data laporan termuat. |
| Proses dan aturan | 1) Ekspor per bagian: harian, per CS, topik, per label, per nasabah, alasan nilai rendah, dan laporan bantuan (BANTU). <br>2) Sel teks yang diawali `=`, `+`, `-`, `@`, tab, atau CR diberi awalan `'` agar tidak dijalankan sebagai formula. <br>3) Hub mengingatkan bahwa file berisi data nasabah. |
| Keluaran | File CSV. |
| Kode error | — |
| Antarmuka | Hub: tombol **Ekspor CSV** (`csv-button`, `reports/csv.ts`) |
| Lacak | BR-CS |

#### FR-CS-63 Kelola label tiket

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengelola daftar label tiket. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Nama 1–30 karakter, unik tanpa beda huruf besar; warna `neutral`, `info`, `success`, `warning`, `danger` (Hub: abu-abu, biru, hijau, kuning, merah); aktif; urutan (0118). <br>2) Maksimal 50 label aktif; label nonaktif tetap tampil di tiket lama dan laporan. <br>3) Urutan ulang harus memuat semua label tepat sekali. <br>4) Audit `ticket_label.save` (sebelum/sesudah) dan `ticket_label.reorder`; kolom **Dipakai** menunjukkan jumlah tiket. |
| Keluaran | Daftar label. |
| Kode error | `400 invalid_label_name`; `400 invalid_label_color`; `404 label_not_found`; `409 duplicate_label`; `409 label_limit`; `400 invalid_label_order` |
| Antarmuka | RPC `cs_api.admin_ticket_labels`, `cs_api.admin_save_ticket_label`, `cs_api.admin_reorder_ticket_labels`; Hub: Pengaturan → Label tiket |
| Lacak | BR-CS |

#### FR-CS-64 Kebijakan lampiran chat CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengatur jenis, format, ukuran, dan durasi lampiran chat CS. |
| Aktor | Super Admin |
| Prakondisi | Form terkunci di Hub (**Ubah** → **Simpan** → konfirmasi). |
| Proses dan aturan | 1) Kebijakan `attachments.cs` berisi `documents`, `images`, `videos`, masing-masing `enabled`, `max_mb`, `formats` (0131). <br>2) Katalog: dokumen PDF, DOCX, XLSX, PPTX, TXT, CSV (plafon 10 MB); gambar JPEG, PNG, WebP, GIF (plafon 10 MB, 0138); video MP4, MOV, WebM (plafon 25 MB, 120 detik). <br>3) `max_mb` bilangan bulat 1–plafon; format harus dari katalog; jenis aktif wajib punya minimal satu format; video wajib `max_seconds` 5–120. <br>4) Bawaan: semua jenis aktif, dokumen 10 MB, gambar 10 MB, video 25 MB dan 120 detik. <br>5) Audit `attachments.policy` (sebelum/sesudah); layanan media dan aplikasi membaca kebijakan dari server. |
| Keluaran | Kebijakan tersimpan. |
| Kode error | `400 invalid_attachment_policy`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_attachment_policy`, `cs_api.admin_set_attachment_policy`, `public.media_attachment_policy`; Hub: Pengaturan → Lampiran chat CS (`attachments-section`) |
| Lacak | BR-CS |

#### FR-CS-65 Jam layanan dan hari libur

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengatur jam layanan CS per hari dan kalender libur yang menentukan status buka layanan. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) `service.hours`: objek hari ISO 1–7 (1 = Senin), tiap hari `null` (tutup) atau `[buka, tutup]` format `HH:MM` (tutup boleh `24:00`), buka sebelum tutup (0056); bawaan Senin–Jumat 08:00–22:00, Sabtu–Minggu 09:00–18:00 WIB (0027). <br>2) Hari libur: tanggal, nama 2–120 karakter, jenis `national`, `collective_leave`, atau `exchange` (0035). <br>3) Libur nasional dan cuti bersama menutup layanan CS; libur bursa hanya menutup pasar. <br>4) Audit `setting.update`, `holiday.save`, `holiday.delete`. |
| Keluaran | Jam layanan dan kalender libur. |
| Kode error | `400 invalid_setting`; `400 invalid_day`; `400 invalid_name`; `400 invalid_kind`; `404 holiday_not_found` |
| Antarmuka | RPC `cs_api.admin_set_setting('service.hours', …)`, `cs_api.admin_holidays`, `cs_api.admin_save_holiday`, `cs_api.admin_delete_holiday`; Hub: Pengaturan → Jam layanan & libur |
| Lacak | BR-CS |

#### FR-CS-66 Pesan otomatis

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengubah teks pesan sistem ke nasabah dalam dua bahasa. |
| Aktor | Super Admin |
| Prakondisi | Kunci `messages.*` sudah ada. |
| Proses dan aturan | 1) Nilai wajib objek dengan tepat `id` dan `en`, masing-masing 2–500 karakter (0056). <br>2) Variabel `{…}` hanya boleh yang sudah ada di teks lama. <br>3) Mencakup antara lain `ticket_opened`, `ticket_claimed`, `ticket_transferred`, `ticket_released`, `agent_away`, `ticket_resolved`, `ticket_reopened`, `ticket_reopened_owner`, `ticket_closed`, `out_of_hours`, `complaint`, `complaint_extended`, `waiting_reminder`. <br>4) Pesan sistem disimpan dalam kedua bahasa dan tampil sesuai bahasa aplikasi atau Hub (0123); perubahan berlaku untuk pesan baru. <br>5) Riwayat di `cs_settings_history`, audit `setting.update`. |
| Keluaran | Teks pesan tersimpan. |
| Kode error | `400 invalid_setting`; `403 setting_locked` |
| Antarmuka | RPC `cs_api.admin_settings`, `cs_api.admin_set_setting`; Hub: Pengaturan → Pesan otomatis |
| Lacak | BR-CS |

#### FR-CS-67 Pengaturan penugasan, tiket, dan alert

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengubah pengaturan alur kerja CS yang diizinkan dari Hub, dengan validasi dan riwayat. |
| Aktor | Super Admin |
| Prakondisi | Kunci termasuk `cs.admin_editable` (0186). |
| Proses dan aturan | 1) `assignment.mode`: `claim` (bawaan) atau `auto_assign`. <br>2) `ticket.auto_release_offline_minutes` 0–1.440 (bawaan 0 = mati); `ticket.auto_close_days` 1–30 (bawaan 3); `ticket.reminder_hours` 0–72 (bawaan 24); `alerts.unclaimed_minutes` dan `alerts.p1_unclaimed_minutes` 1–240 (bawaan 10 dan 2); `guest.enabled` boolean (bawaan `true`, **Pengaduan tanpa login**) (0140, 0182). <br>3) Kunci lain (mis. `complaint.days`, `retention.chat_years`, `agent.history_hours`, `priority.rules`, `help.allowed_hosts`, `brand.support_name`) tidak bisa diubah dari Hub; tiga kebijakan tenggat/retensi diatur Kepatuhan (PATUH). <br>4) Setiap simpan menaikkan versi, mencatat `cs_settings_history`, dan audit `setting.update`; form terkunci dengan konfirmasi. |
| Keluaran | Pengaturan baru beserta versi. |
| Kode error | `400 invalid_setting`; `403 setting_locked`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_settings`, `cs_api.admin_set_setting`; Hub: Pengaturan → Penugasan, tiket & alert (`assignment-section`) |
| Lacak | BR-CS |

#### FR-CS-68 Status layanan dan gangguan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengumumkan gangguan layanan yang tampil di aplikasi selama masa berlakunya. |
| Aktor | Super Admin; Nasabah (melihat) |
| Prakondisi | — |
| Proses dan aturan | 1) Judul 3–100 dan isi 3–1.000 karakter dalam dua bahasa; tingkat `info`, `warning`, `critical`; mulai (bawaan sekarang) dan selesai opsional yang harus setelah mulai; artikel FAQ terkait harus sudah terbit (0135). <br>2) **Akhiri sekarang** mengisi waktu selesai ke saat ini. <br>3) Daftar admin (maksimal 100 terbaru) menampilkan status aktif dan jumlah tiket yang masuk selama gangguan. <br>4) Audit `incident.save` (sebelum/sesudah) dan `incident.end`. <br>5) Nasabah menerima pengumuman aktif lewat `support_home.incidents` dan `service_status(p_language)`, urut `critical`, `warning`, `info`; library menampilkan banner di chat CS, halaman pilih topik, dan Pusat Bantuan (biru/jingga/merah), tombol **Selengkapnya** ke artikel terkait, dan tombol tutup per sesi aplikasi. |
| Keluaran | Pengumuman gangguan. |
| Kode error | `400 invalid_incident`; `404 incident_not_found`; `403 customer_required` |
| Antarmuka | RPC `cs_api.admin_incidents`, `cs_api.admin_save_incident`, `cs_api.admin_end_incident`, `cs_api.service_status`; Hub: Pengaturan → Status layanan / gangguan (`incidents-section`); Library: banner di `CommunitySupportChat` dan `CommunityHelpCenter` |
| Lacak | BR-CS |

#### FR-CS-69 Konfigurasi survei kepuasan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan Super Admin mengatur pertanyaan, skala, ambang nilai rendah, dan alasan survei kepuasan. |
| Aktor | Super Admin |
| Prakondisi | Form terkunci dengan konfirmasi. |
| Proses dan aturan | 1) Pertanyaan 5–120 karakter dalam dua bahasa (0135). <br>2) Skala 3 (wajah) atau 5 (bintang); `low_max` 1–4. <br>3) Maksimal 8 alasan; kode unik `^[a-z][a-z0-9_]{1,31}$`, label 2–60 karakter dua bahasa. <br>4) Bawaan: "Bagaimana layanan CS kami?", skala 5, `low_max` 2, alasan `slow`, `unresolved`, `unclear`, `attitude`. <br>5) Audit `survey.config` (sebelum/sesudah); hasil di Laporan → Alasan nilai rendah (FR-CS-61). |
| Keluaran | Konfigurasi survei. |
| Kode error | `400 invalid_survey`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_survey_config`, `cs_api.admin_set_survey_config`; Hub: Pengaturan → Survei kepuasan (`survey-section`) |
| Lacak | BR-CS |

#### FR-CS-70 Pintasan keyboard Layanan Nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menyediakan pintasan keyboard untuk aksi kerja CS yang sering dipakai. |
| Aktor | CS |
| Prakondisi | Fokus di layar Layanan Nasabah. |
| Proses dan aturan | 1) J/K tiket berikutnya/sebelumnya; A ambil tiket terpilih; R fokus kolom balas; N catatan internal; E selesaikan tiket; Ctrl Enter kirim; ? daftar pintasan; Ctrl K command palette (HUB). <br>2) Pintasan aksi mengikuti aturan aksi yang sama (status Online, kepemilikan). |
| Keluaran | Aksi dijalankan lewat keyboard. |
| Kode error | — |
| Antarmuka | Hub: Layanan Nasabah, avatar → **Pintasan keyboard** |
| Lacak | BR-CS |

### 4.5 Pusat Bantuan (BANTU)

Modul BANTU mencakup isi bantuan swalayan untuk nasabah dan konfigurasi topik chat CS. Nasabah membaca artikel FAQ dua bahasa di aplikasi OLT lewat library (`CommunityHelpCenter`), mendapat saran artikel sebelum chat CS, dan memberi umpan balik "Apakah ini membantu?". Staf berperan **Pusat Bantuan** (`cs_content`) atau Super Admin (`cs_super_admin`, sudah mencakup Pusat Bantuan) mengelola kategori, artikel (draf, terbit, arsip, versi, gambar, lampiran), dan topik chat CS (ikon, urutan, teks halaman pilih topik, pertanyaan awal, saran balasan, SOP) di Hub menu **Pusat Bantuan** dengan tab **Topik chat CS** dan **Artikel bantuan**. Data disimpan di skema `cs` (`faq_categories`, `faq_articles`, `faq_article_versions`, `faq_feedback`, `faq_reads`, `faq_search_misses`, `faq_flags`, `support_topics`), semuanya ber-RLS tanpa grant langsung; akses hanya lewat RPC `cs_api` (0129).

Di luar modul ini: pembuatan tiket, pengisian pertanyaan awal oleh nasabah, saran balasan saat chat, status gangguan, dan survei di CS; peran dan akun staf di HUB; audit log dibaca di PATUH. Semua perubahan konten bantuan tercatat di audit log dengan aksi `faq.*`, `topic.*`, dan `topic_picker.save`.

#### FR-BANTU-01 Daftar kategori dan artikel untuk nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengembalikan kategori aktif beserta artikel terbit dalam bahasa nasabah sebagai isi Pusat Bantuan. |
| Aktor | Nasabah |
| Prakondisi | Sesi sosial nasabah aktif (AKUN). |
| Proses dan aturan | 1) Hanya kategori `active` yang punya minimal satu artikel `published`, urut `sort_order` lalu `code` (0129). <br>2) Per kategori: `code`, `name` sesuai `p_language` (`id`/`en`), `icon`, dan artikel terbit urut `sort_order` lalu waktu dibuat. <br>3) Per artikel: `id`, kategori, `question`, `answer` sesuai bahasa, `topic`, `attachments`, `updated_at` (0188). <br>4) Respons memuat `updated_at` terbaru dari artikel terbit. <br>5) Library menampilkan kategori dengan ikon dan jumlah artikel; mengetuk kategori membuka daftar pertanyaannya. |
| Keluaran | Objek `categories` dan `updated_at`. |
| Kode error | `403 customer_required` |
| Antarmuka | RPC `cs_api.faq(p_language)`; Library: `CommunityHelpCenter`, `openCommunityHelpCenter` |
| Lacak | BR-BANTU |

#### FR-BANTU-02 Pencarian artikel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencari artikel terbit berdasarkan kata yang diketik nasabah dan mencatat pencarian tanpa hasil tanpa data pribadi. |
| Aktor | Nasabah |
| Prakondisi | Nasabah masuk. |
| Proses dan aturan | 1) Kata pencarian 2–100 karakter; rate limit `faq_search` 30 per 60 detik (0129). <br>2) Dipakai maksimal 6 kata (masing-masing ≥ 2 huruf); semua kata harus ada di pertanyaan, jawaban, atau kata kunci dalam bahasa yang diminta; hanya artikel terbit di kategori aktif. <br>3) Urutan: jumlah kata yang cocok di judul, nilai membantu (jumlah "Ya" dikurangi "Tidak"), lalu jumlah dilihat; maksimal 20 hasil. <br>4) Tanpa hasil: kata disimpan di `faq_search_misses` setelah email diganti `@`, angka ≥ 4 digit diganti `#`, dan dipotong 100 karakter; baris lebih dari 90 hari dihapus. <br>5) Library mengirim pencarian 350 ms setelah berhenti mengetik. |
| Keluaran | Array artikel. |
| Kode error | `400 invalid_query`; `429 rate_limited`; `403 customer_required` |
| Antarmuka | RPC `cs_api.faq_search(p_query, p_language)`; Library: kotak cari di `CommunityHelpCenter` |
| Lacak | BR-BANTU |

#### FR-BANTU-03 Membaca artikel dan statistik baca

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengembalikan satu artikel terbit dan mencatat pembacaannya untuk statistik. |
| Aktor | Nasabah |
| Prakondisi | Artikel `published` di kategori aktif. |
| Proses dan aturan | 1) Artikel arsip, draf, atau di kategori nonaktif → `article_not_found` (0129). <br>2) `views` bertambah 1 hanya bila nasabah yang sama belum membaca artikel itu dalam 1 jam terakhir. <br>3) `faq_reads` menyimpan satu baris per artikel per nasabah dengan `read_at` terbaru (dipakai untuk "Tetap buat tiket"). <br>4) Respons menyertakan umpan balik nasabah sebelumnya (`helpful`, `comment`) bila ada. |
| Keluaran | Artikel beserta `feedback`. |
| Kode error | `404 article_not_found`; `403 customer_required` |
| Antarmuka | RPC `cs_api.faq_article(p_id, p_language)`; Library: `CommunityHelpArticleView`, `openCommunityHelpArticle` |
| Lacak | BR-BANTU |

#### FR-BANTU-04 Umpan balik "Apakah ini membantu?"

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima penilaian membantu atau tidak beserta komentar opsional atas artikel terbit. |
| Aktor | Nasabah |
| Prakondisi | Artikel `published`. |
| Proses dan aturan | 1) `p_helpful` wajib; komentar opsional maksimal 500 karakter (0129). <br>2) Satu umpan balik per artikel per nasabah; pengiriman ulang menimpa nilai sebelumnya. <br>3) Rate limit `faq_feedback` 20 per 3.600 detik. <br>4) Offline: library tidak mengirim umpan balik baru sampai online. |
| Keluaran | Nilai umpan balik tersimpan. |
| Kode error | `400 invalid_feedback`; `404 article_not_found`; `429 rate_limited` |
| Antarmuka | RPC `cs_api.faq_feedback(p_article_id, p_helpful, p_comment)`; Library: bagian "Apakah ini membantu?" di `CommunityHelpArticleView` |
| Lacak | BR-BANTU |

#### FR-BANTU-05 Tampilan artikel di aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan jawaban artikel dengan Markdown terbatas yang aman, gambar resmi, lampiran, dan jalan ke chat CS. |
| Aktor | Nasabah |
| Prakondisi | Artikel termuat. |
| Proses dan aturan | 1) Markdown yang didukung: paragraf, tebal, miring, daftar berbutir dan bernomor, judul `#`, tautan `[teks](https://...)`, dan gambar `![alt](URL)` di baris sendiri; HTML tidak pernah ditafsirkan; tautan selain `https` tampil sebagai teks. <br>2) Tautan dibuka lewat dialog konfirmasi domain yang sama dengan tautan chat. <br>3) Gambar hanya dimuat dari bucket publik `faq-images` (`<uuid>.jpg/png/webp`), tinggi maksimal 360 px, label aksesibilitas = teks alt, diganti ikon gambar rusak bila gagal. <br>4) Lampiran tampil di bawah jawaban (library 1.49.0): gambar layar penuh, video diputar di aplikasi, PDF dibuka aplikasi bawaan perangkat; aplikasi lama tetap menampilkan artikel tanpa lampiran. <br>5) Tombol **"Masih butuh bantuan? Chat CS"** di bawah artikel, daftar kategori, dan hasil pencarian membuka `openCommunitySupport(topic: <topik artikel>, screen: 'help_center')` atau callback host `onContactSupport`. <br>6) Tampilan bisa diganti lewat `CommunityHelpBuilders`. |
| Keluaran | Halaman artikel. |
| Kode error | — |
| Antarmuka | Library: `CommunityHelpArticleView`, `CommunityHelpMarkdown`, `openHelpAttachment`, `CommunityHelpAttachmentOpener`, `CommunityHelpCenter(onContactSupport:)` |
| Lacak | BR-BANTU |

#### FR-BANTU-06 Saran artikel sebelum chat CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyarankan artikel terkait topik yang dipilih nasabah sebelum tiket CS dibuat. |
| Aktor | Nasabah |
| Prakondisi | Nasabah memilih topik di halaman pilih topik chat CS. |
| Proses dan aturan | 1) `faq_for_topic` mengembalikan artikel terbit dengan `topic_code` sama, di kategori aktif, urut nilai membantu lalu jumlah dilihat lalu `sort_order`; `p_limit` 1–5, bawaan 3 (0129). <br>2) Library menampilkan maksimal 3 artikel di bawah **"Mungkin ini membantu"** dengan tombol **Lanjut chat dengan CS** dan **Pilih topik lain**. <br>3) Bila topik tanpa artikel, permintaan gagal, atau server tidak menjawab dalam 4 detik, tiket langsung dibuat. <br>4) Topik yang dikirim host lewat `openCommunitySupport(topic: ...)` tidak melewati langkah ini. <br>5) Langkah di luar jam layanan memakai RPC yang sama (CS). |
| Keluaran | Array artikel saran. |
| Kode error | `403 customer_required` |
| Antarmuka | RPC `cs_api.faq_for_topic(p_topic, p_language, p_limit)`; Library: halaman pilih topik `CommunitySupportChat` |
| Lacak | BR-BANTU |

#### FR-BANTU-07 Pusat Bantuan offline

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus tetap menampilkan isi Pusat Bantuan terakhir saat server tidak terjangkau. |
| Aktor | Nasabah |
| Prakondisi | Pernah memuat `cs_api.faq` berhasil untuk bahasa itu. |
| Proses dan aturan | 1) Respons `cs_api.faq` terakhir disimpan satu salinan per bahasa di cache lokal terenkripsi milik user (AKUN), ditimpa setiap kali berhasil dimuat. <br>2) Saat dibuka, isi tersimpan tampil seketika lalu diganti data server. <br>3) Bila server tidak terjangkau: pemberitahuan "Anda sedang offline…" dengan tombol **Coba lagi**; pencarian dan artikel memakai isi tersimpan; umpan balik tidak dikirim. <br>4) Cache dihapus saat `signOut()`, hapus akun, atau pergantian user. |
| Keluaran | Isi bantuan dari cache. |
| Kode error | — |
| Antarmuka | Library: `CommunityHelpCenter`, `HelpRepository` |
| Lacak | BR-BANTU |

#### FR-BANTU-08 Privasi data Pusat Bantuan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi data pribadi yang tersimpan dari pemakaian Pusat Bantuan dan menghapusnya saat akun dihapus. |
| Aktor | Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) Saat profil diberi `deleted_at`, trigger `profiles_71_faq_forget` menghapus `faq_feedback` dan `faq_reads` nasabah itu (0129). <br>2) Pencarian tanpa hasil disimpan tanpa identitas nasabah, dengan email dan angka panjang disamarkan, dan dihapus setelah 90 hari (FR-BANTU-02). <br>3) Komentar umpan balik ditampilkan di Hub tanpa identitas nasabah (FR-BANTU-16). |
| Keluaran | Data pribadi minimal. |
| Kode error | — |
| Antarmuka | Trigger `private.faq_forget` |
| Lacak | BR-BANTU |

#### FR-BANTU-09 Kelola kategori FAQ

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf Pusat Bantuan membuat dan mengubah kategori artikel. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Peran `cs_content` atau `cs_super_admin`. |
| Proses dan aturan | 1) Kode `^[a-z][a-z0-9_]{1,31}$` unik; nama 2–60 karakter dua bahasa; ikon opsional dari 16 pilihan (`account`, `wallet`, `receipt`, `chart`, `tools`, `shield`, `help`, `document`, `phone`, `card`, `chat`, `star`, `bell`, `lock`, `globe`, `gift`); urutan; aktif (0129). <br>2) Kategori nonaktif beserta artikelnya tidak tampil di aplikasi. <br>3) Kategori bawaan: `account`, `transaction`, `security`. <br>4) Daftar admin menampilkan jumlah artikel bukan arsip per kategori. <br>5) Audit `faq.category_save` (sebelum/sesudah). |
| Keluaran | Baris kategori. |
| Kode error | `400 invalid_code`; `400 invalid_name`; `400 invalid_icon`; `409 code_taken`; `404 category_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_faq`, `cs_api.admin_faq_save_category`; Hub: Pusat Bantuan → Artikel bantuan → **Kategori** (`category-dialog`) |
| Lacak | BR-BANTU |

#### FR-BANTU-10 Menyimpan artikel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan artikel FAQ dua bahasa dengan validasi isi dan perlindungan dari simpanan bersamaan. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Kategori ada. |
| Proses dan aturan | 1) Pertanyaan 5–200 dan jawaban 1–8.000 karakter dalam dua bahasa (0188). <br>2) Jawaban tidak boleh memuat tag HTML; tautan wajib `https://`; gambar wajib dari bucket `faq-images` milik server (FR-BANTU-11) (0130). <br>3) Kata kunci dinormalisasi huruf kecil, unik, maksimal 20, masing-masing maksimal 40 karakter. <br>4) Topik chat terkait opsional dan harus ada (dipakai saran sebelum chat, FR-BANTU-06). <br>5) Artikel baru berstatus `draft`. <br>6) `p_version` berbeda dari versi tersimpan → `version_conflict`; Hub meminta memuat ulang. <br>7) Setiap simpan menaikkan versi dan menulis salinan ke `faq_article_versions`; audit dengan sebelum/sesudah. <br>8) Hub: **Pratinjau di aplikasi** ID/EN menampilkan artikel seperti di HP nasabah. |
| Keluaran | Baris artikel admin. |
| Kode error | `400 invalid_category`; `400 invalid_question`; `400 invalid_answer`; `400 invalid_keywords`; `400 invalid_topic`; `404 article_not_found`; `409 version_conflict` |
| Antarmuka | RPC `cs_api.admin_faq_save_article(p_id, p_category_id, p_question_id, p_question_en, p_answer_id, p_answer_en, p_keywords, p_topic_code, p_sort_order, p_version, p_attachments)`; Hub: Pusat Bantuan → Artikel bantuan → **Tambah artikel** (`article-dialog`) |
| Lacak | BR-BANTU |

#### FR-BANTU-11 Gambar di jawaban artikel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf Pusat Bantuan menyisipkan gambar yang diunggah dari Hub ke jawaban artikel, dan menolak gambar dari situs lain. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Peran `cs_content` atau `cs_super_admin` (`private.can_manage_faq`). |
| Proses dan aturan | 1) Bucket publik `faq-images`: JPEG, PNG, WebP, maksimal 2 MiB; nama objek `<uuid>.jpg/png/webp`; unggah hanya oleh pengelola FAQ (0130). <br>2) Markdown gambar `![alt](URL)` hanya diterima bila URL menunjuk `/storage/v1/object/public/faq-images/<uuid>.<ext>`; selain itu ditolak "Gambar di jawaban harus diunggah dari Hub". <br>3) Hub: **Sisipkan gambar (ID/EN)** menaruh gambar di posisi kursor dan memperkecil gambar yang terlalu besar sebelum unggah. |
| Keluaran | Jawaban berisi gambar resmi. |
| Kode error | `400 invalid_answer` (unggahan di luar kebijakan ditolak RLS storage) |
| Antarmuka | Storage bucket `faq-images`; Hub: editor artikel → **Sisipkan gambar** |
| Lacak | BR-BANTU |

#### FR-BANTU-12 Lampiran artikel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf Pusat Bantuan memasang file PDF, gambar, dan video sebagai lampiran artikel. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | File sudah diunggah ke bucket `faq-files` dari Hub. |
| Proses dan aturan | 1) Maksimal 10 lampiran per artikel, sama untuk kedua bahasa (0188). <br>2) Path wajib `<uuid>.(pdf, jpg, png, webp, mp4, webm, mov)` dan objeknya harus ada di `faq-files`; tidak boleh dipasang dua kali. <br>3) Batas ukuran: PDF 10 MB, gambar 5 MB, video 25 MB (plafon bucket 25 MiB). <br>4) Nama tampil 1–120 karakter tanpa karakter kontrol; server menyimpan `path`, `name`, `kind` (`document`/`image`/`video`), `mime`, `size`. <br>5) Bucket `faq-files` publik dengan nama acak; unggah hanya oleh pengelola FAQ. <br>6) `p_attachments = null` mempertahankan lampiran lama. <br>7) Hub: **Tambah lampiran** (boleh beberapa file sekaligus, gambar besar diperkecil), ubah nama, urutan dengan panah, hapus; lampiran ikut di **Pratinjau di aplikasi** dan dialog **Sisipkan artikel FAQ**. |
| Keluaran | Artikel dengan daftar lampiran. |
| Kode error | `400 invalid_attachments`; `400 too_many_attachments`; `400 duplicate_attachment`; `400 invalid_attachment_name`; `400 attachment_missing`; `400 attachment_too_large` |
| Antarmuka | RPC `cs_api.admin_faq_save_article(p_attachments)`; Storage bucket `faq-files`; Hub: editor artikel → **Lampiran** (`attachments-field`, `attachment-list`) |
| Lacak | BR-BANTU |

#### FR-BANTU-13 Status artikel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengatur siklus artikel draf, terbit, dan arsip yang menentukan tampil tidaknya artikel di aplikasi. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Artikel ada. |
| Proses dan aturan | 1) Status `draft`, `published`, `archived` (0129). <br>2) Hanya `published` yang tampil di aplikasi, pencarian, saran, dan dialog agen; terbit mengisi `published_at`. <br>3) Hub: menu baris **Terbitkan**, **Jadikan draf**, **Arsipkan**; artikel arsip disembunyikan dari daftar kecuali disaring status **Arsip**. <br>4) Audit `faq.article_status` (sebelum/sesudah). |
| Keluaran | Artikel dengan status baru. |
| Kode error | `400 invalid_status`; `404 article_not_found` |
| Antarmuka | RPC `cs_api.admin_faq_set_status`; Hub: Pusat Bantuan → Artikel bantuan → menu baris |
| Lacak | BR-BANTU |

#### FR-BANTU-14 Riwayat versi dan pemulihan artikel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan setiap versi artikel dan mengizinkan pemulihan versi lama sebagai versi baru. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Artikel punya riwayat versi. |
| Proses dan aturan | 1) `admin_faq_versions` mengembalikan semua versi (isi, waktu, nama pembuat) dari yang terbaru (0129). <br>2) Pulihkan menyalin isi versi lama (kategori dan topik hanya bila masih ada) sebagai versi baru tanpa mengubah status. <br>3) Lampiran versi lama ikut dipulihkan, kecuali file yang objeknya sudah tidak ada di `faq-files` (0188). <br>4) Audit `faq.article_restore` (dari versi, versi baru); Hub meminta konfirmasi. |
| Keluaran | Artikel versi baru. |
| Kode error | `404 version_not_found` |
| Antarmuka | RPC `cs_api.admin_faq_versions`, `cs_api.admin_faq_restore`; Hub: **Riwayat versi** → **Pulihkan** (`history-dialogs`) |
| Lacak | BR-BANTU |

#### FR-BANTU-15 Statistik artikel di Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan statistik pemakaian setiap artikel agar staf dapat menemukan artikel yang perlu diperbaiki. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Per artikel: `views`, `readers` (nasabah unik), `helpful`, `not_helpful`, `tickets_after` (pembaca yang membuat tiket CS dalam 24 jam setelah membaca), versi, waktu, nama pengubah terakhir, `published_at` (0129, 0136). <br>2) Hub: kolom **Dilihat**, **Membantu** (persen "Ya"), **Tetap buat tiket**, urutan **Paling kurang membantu**, dan lencana kuning jumlah catatan CS terbuka (FR-BANTU-18). |
| Keluaran | Daftar artikel admin dengan statistik. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_faq`; Hub: Pusat Bantuan → Artikel bantuan (`faq-section`) |
| Lacak | BR-BANTU |

#### FR-BANTU-16 Komentar nasabah dan pencarian tanpa hasil

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan komentar umpan balik tanpa identitas dan daftar kata pencarian tanpa hasil sebagai bahan artikel baru. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) `admin_faq_feedback`: maksimal 200 komentar terbaru per artikel berisi `helpful`, `comment`, `updated_at`, tanpa identitas nasabah (0129). <br>2) `admin_faq_misses(p_days)`: periode 1–90 hari (bawaan 30), dikelompokkan per kata dan bahasa, maksimal 100 baris, urut jumlah lalu waktu terakhir. <br>3) Hub: **Komentar nasabah** dan **Pencarian tanpa hasil (30 hari)**. |
| Keluaran | Daftar komentar; daftar kata tanpa hasil. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_faq_feedback`, `cs_api.admin_faq_misses`; Hub: Pusat Bantuan → Artikel bantuan |
| Lacak | BR-BANTU |

#### FR-BANTU-17 Sisipkan artikel FAQ oleh CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan CS mencari artikel terbit dan menyisipkan isinya ke kotak balas sebagai teks yang bisa diedit. |
| Aktor | CS, Super Admin |
| Prakondisi | Peran `cs_agent` atau `cs_super_admin`. |
| Proses dan aturan | 1) Pencarian memakai sampai 6 kata (≥ 2 huruf) di pertanyaan, jawaban, dan kata kunci sesuai bahasa; tanpa kata mengembalikan artikel terbit; maksimal 20 hasil urut `sort_order` (0136). <br>2) Hasil memuat jumlah catatan CS yang belum selesai (`open_flags`) dan lampiran. <br>3) Hub memasukkan pertanyaan dan jawaban ke kotak balas sebagai teks biasa (tautan ditulis lengkap); pengiriman tetap lewat `agent_send_message` dengan semua pemeriksaannya (CS). <br>4) Pencarian agen tidak dicatat sebagai pencarian tanpa hasil nasabah. |
| Keluaran | Daftar artikel untuk disisipkan. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.agent_faq_search(p_query, p_language)`; Hub: kotak balas menu ⋯ → **Sisipkan artikel FAQ** (`faq-insert-dialog`) |
| Lacak | BR-BANTU |

#### FR-BANTU-18 Catatan CS "perlu diperbarui"

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan CS menandai artikel yang sudah tidak sesuai, dan staf Pusat Bantuan menindaklanjuti serta menandai selesai. |
| Aktor | CS, Super Admin, Pusat Bantuan |
| Prakondisi | Artikel ada. |
| Proses dan aturan | 1) CS atau Super Admin menulis catatan 5–300 karakter (0136). <br>2) Catatan tersimpan di `cs.faq_flags` dengan nama CS dan waktu. <br>3) `admin_faq_flags` menampilkan maksimal 100 catatan per artikel, yang terbuka lebih dulu. <br>4) **Tandai selesai** menyelesaikan semua catatan terbuka artikel itu; audit `faq.flags_resolved` dengan jumlah. |
| Keluaran | Catatan terbuka/selesai. |
| Kode error | `400 reason_required`; `404 article_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.agent_flag_faq`, `cs_api.admin_faq_flags`, `cs_api.admin_faq_resolve_flags`; Hub: dialog Sisipkan artikel FAQ → **Tandai perlu diperbarui**; Pusat Bantuan → menu baris (`flags-dialog`) |
| Lacak | BR-BANTU |

#### FR-BANTU-19 Laporan bantuan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan laporan efektivitas bantuan per topik, per artikel, dan pencarian tanpa hasil untuk rentang tanggal. |
| Aktor | Super Admin |
| Prakondisi | Rentang 1 hari sampai 1 tahun (bawaan 30 hari terakhir). |
| Proses dan aturan | 1) Per topik: jumlah tiket, median menit respons pertama (sejak antre), median menit sampai selesai (0136). <br>2) Per artikel bukan arsip yang dibaca atau dinilai pada rentang: pembaca, membantu, tidak membantu, `helpful_percent`, tetap buat tiket dalam 24 jam, dan **tercegah** = pembaca − tetap buat tiket. <br>3) Pencarian tanpa hasil: maksimal 50 kata teratas. <br>4) Setiap tabel punya **Ekspor CSV** (aturan netralisasi formula di CS). |
| Keluaran | JSON laporan bantuan. |
| Kode error | `400 invalid_range`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_help_report(p_from, p_to)`; Hub: Laporan → **Laporan bantuan** (`help-report-section`) |
| Lacak | BR-BANTU |

#### FR-BANTU-20 Kelola topik chat CS

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf Pusat Bantuan membuat dan mengubah topik chat CS beserta tampilannya di aplikasi. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Peran `cs_content` atau `cs_super_admin`. |
| Proses dan aturan | 1) Kode `^[a-z][a-z0-9_]{1,31}$` (tidak bisa diubah setelah dibuat); nama 2–40 karakter dua bahasa; deskripsi opsional maksimal 120 karakter per bahasa (0127). <br>2) Ikon opsional dari 16 pilihan yang sama dengan kategori FAQ; tampilan `normal` atau `danger` (Hub: **Biasa**/**Merah**). <br>3) Skill CS harus ada di `cs.skills`; prioritas default `P1`–`P4`; urutan 0–999; tautan bantuan opsional `https://` ke host `help.allowed_hosts`. <br>4) Topik bawaan (`ticket.default_topic`) tidak bisa dinonaktifkan; topik nonaktif tidak tampil di aplikasi (**Tampilkan ke nasabah**). <br>5) Audit `topic.save` dengan sebelum/sesudah; daftar admin menampilkan jumlah tiket per topik. <br>6) Hub: **Pratinjau di aplikasi** menampilkan kartu topik seperti di HP nasabah. |
| Keluaran | Daftar topik admin. |
| Kode error | `400 invalid_code`; `400 invalid_name`; `400 invalid_description`; `400 invalid_icon`; `400 invalid_style`; `400 invalid_skill`; `400 invalid_priority`; `400 invalid_sort`; `400 invalid_help_link`; `400 default_topic` |
| Antarmuka | RPC `cs_api.admin_topics`, `cs_api.admin_options`, `cs_api.admin_save_topic`; Hub: Pusat Bantuan → Topik chat CS (`topics-section`) |
| Lacak | BR-BANTU |

#### FR-BANTU-21 Tanda pengaduan/penipuan pada topik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi perubahan tanda pengaduan dan penipuan pada topik hanya untuk Super Admin. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Tanda topik hanya `complaint` dan/atau `fraud` (0127). <br>2) Selain Super Admin, perubahan tanda ditolak `flags_forbidden`; `p_flags = null` mempertahankan tanda lama. <br>3) Tanda topik ikut menjadi flag tiket baru, sehingga tiketnya masuk register Kasus Kepatuhan (CS, PATUH). <br>4) Perubahan dicatat terpisah dengan audit `topic.flags` (sebelum/sesudah). |
| Keluaran | Tanda topik tersimpan. |
| Kode error | `400 invalid_flags`; `403 flags_forbidden` |
| Antarmuka | RPC `cs_api.admin_save_topic(p_flags)`; Hub: Pusat Bantuan → Topik chat CS → **Tanda tiket** |
| Lacak | BR-BANTU |

#### FR-BANTU-22 Urutan dan penghapusan topik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan pengurutan ulang semua topik dan penghapusan topik yang belum pernah dipakai tiket. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Urutan baru harus memuat setiap topik tepat sekali; `sort_order` diisi kelipatan 10; audit `topic.reorder` (0137). <br>2) Hapus hanya bila topik belum dipakai tiket mana pun; bila sudah dipakai, Hub menyarankan menonaktifkan (0139). <br>3) Minimal harus tersisa satu topik aktif. <br>4) Topik bertanda pengaduan/penipuan hanya bisa dihapus Super Admin. <br>5) Audit `topic.delete` dengan isi topik sebelumnya. |
| Keluaran | Daftar topik admin. |
| Kode error | `400 invalid_topic_order`; `404 topic_not_found`; `403 flags_forbidden`; `409 topic_in_use`; `409 last_active_topic` |
| Antarmuka | RPC `cs_api.admin_reorder_topics`, `cs_api.admin_delete_topic`; Hub: Pusat Bantuan → Topik chat CS |
| Lacak | BR-BANTU |

#### FR-BANTU-23 Teks halaman pilih topik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf Pusat Bantuan mengatur judul dan petunjuk halaman pilih topik chat CS dalam dua bahasa. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Form terkunci di Hub (**Ubah** → **Simpan** → konfirmasi). |
| Proses dan aturan | 1) Judul maksimal 80 dan petunjuk maksimal 160 karakter per bahasa; kolom kosong dihapus (0127). <br>2) Disimpan di pengaturan `topics.picker` dan dikirim ke aplikasi lewat `support_home.topic_picker`; kolom kosong memakai teks bawaan aplikasi ("Apa yang bisa kami bantu?" / "How can we help?"). <br>3) Audit `topic_picker.save` (sebelum/sesudah). <br>4) Hub: **Pratinjau di aplikasi** menampilkan judul, petunjuk, dan beberapa topik aktif (ID/EN), menandai teks **bawaan**. |
| Keluaran | Nilai `topics.picker`. |
| Kode error | `400 invalid_picker_text` |
| Antarmuka | RPC `cs_api.admin_topic_picker`, `cs_api.admin_set_topic_picker`; Hub: Pusat Bantuan → Topik chat CS → **Teks halaman pilih topik** |
| Lacak | BR-BANTU |

#### FR-BANTU-24 Isian, saran balasan, dan SOP topik

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengizinkan staf Pusat Bantuan mengatur pertanyaan awal, saran balasan nasabah, dan SOP CS per topik. |
| Aktor | Pusat Bantuan, Super Admin |
| Prakondisi | Topik ada. |
| Proses dan aturan | 1) Pertanyaan awal maksimal 8: kunci unik `^[a-z][a-z0-9_]{1,31}$`, jenis `text`, `number`, `date`, `choice`, label 2–80 karakter dua bahasa, wajib/opsional; `choice` berisi 2–10 opsi dengan nilai unik `^[a-z0-9_]{1,32}$` dan label 1–60 karakter dua bahasa (0134). <br>2) Saran balasan nasabah maksimal 6, masing-masing 1–40 karakter dua bahasa. <br>3) SOP untuk CS maksimal 4.000 karakter, hanya terlihat staf (**SOP topik** di panel kanan tiket). <br>4) Audit `topic.extras` dengan sebelum/sesudah. <br>5) Pemakaian di sisi nasabah dan CS diatur di modul CS (validasi jawaban, chip saran balasan). |
| Keluaran | Baris topik admin. |
| Kode error | `404 topic_not_found`; `400 invalid_intake`; `400 invalid_customer_replies`; `400 invalid_sop` |
| Antarmuka | RPC `cs_api.admin_set_topic_extras(p_code, p_intake, p_customer_replies, p_sop)`; Hub: Pusat Bantuan → Topik chat CS → **Isian & SOP** (`topic-extras-dialog`) |
| Lacak | BR-BANTU |

#### FR-BANTU-25 Peran Pusat Bantuan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan peran staf Pusat Bantuan yang hanya membuka pengelolaan isi bantuan. |
| Aktor | Super Admin (memberi peran), staf Pusat Bantuan |
| Prakondisi | Akun staf dibuat di HUB. |
| Proses dan aturan | 1) Peran `cs_content` diterima di semua RPC pengelolaan topik dan FAQ bersama `cs_super_admin` (0126, 0127, 0129); Super Admin sudah mencakup peran ini. <br>2) Staf `cs_content` tidak bisa membuka Pengaturan, Dashboard, Laporan, atau tiket; laporan bantuan hanya untuk Super Admin (FR-BANTU-19). <br>3) Hanya Super Admin yang mengubah atau menghapus topik bertanda (FR-BANTU-21, FR-BANTU-22). <br>4) Menu Hub **Pusat Bantuan** tampil untuk Super Admin dan peran Pusat Bantuan. |
| Keluaran | Akses menu sesuai peran. |
| Kode error | `403 role_forbidden` |
| Antarmuka | Hub: menu **Pusat Bantuan** (`content-page`); Pengaturan → Akun CS → kartu peran **Pusat Bantuan** (HUB) |
| Lacak | BR-BANTU |

### 4.6 Notifikasi dan promosi (NOTIF)

Modul ini mencakup kotak notifikasi di aplikasi nasabah beserta badge, jenis notifikasi dan penggabungannya, preferensi per jenis dan jam tenang, ringkasan saham pantauan, serta push ke HP lewat layanan notifier dan Firebase Cloud Messaging (FCM). Sisi Hub mencakup unggah kunci Firebase oleh Super Admin (disimpan di Vault), status push, kampanye notifikasi di Komunitas → Notifikasi, dan menu Banner & Popup (strip, popup, frekuensi, statistik, rasio gambar, notifikasi info `app_notices` dengan persetujuan empat mata opsional). Notifikasi transaksi dari OLT lewat `/integration/v1` ditulis di modul INT; di sini hanya pemetaan preferensinya. Jenis notifikasi Berbagi Trade (`trade_activity`, `trade_share`) ada di skema tetapi fiturnya dijeda.

#### FR-NOTIF-01 Pembuatan notifikasi in-app

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat baris notifikasi untuk penerima dari setiap peristiwa sosial, kecuali untuk diri sendiri dan pasangan yang saling blokir. |
| Aktor | Sistem (trigger) |
| Prakondisi | Peristiwa sumber terjadi (balasan, mention, like, follow, pesan, pengumuman, keputusan banding, postingan akun diikuti, ringkasan, moderasi). |
| Proses dan aturan | 1) `private.notify(user, actor, type, payload, group_key)`: diabaikan bila penerima = pelaku atau saling blokir (0003). <br>2) Jenis yang diizinkan constraint `notifications_type`: `reply`, `mention`, `like`, `follow`, `message`, `announcement`, `appeal`, `followed_post`, `watchlist_digest`, `moderation`, serta `trade_activity`, `trade_share` (dijeda) (0087, 0163). <br>3) Notifikasi `message` dibuat untuk anggota DM/grup yang tidak membisukan room, digabung per room (`message:room:<id>`); room saham tidak memberi notifikasi pesan; pesan sistem grup tidak memberi notifikasi (0173). <br>4) Konten yang ditahan (`held`) tidak memicu notifikasi mention, balasan, atau pesan (content-safety.md §3). <br>5) `private.notify` membuang `mention` bila `private.mention_allowed` false (0172). |
| Keluaran | Baris `public.notifications` |
| Kode error | — |
| Antarmuka | `private.notify`; tabel `public.notifications` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-02 Kotak notifikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan notifikasi milik pengguna berhalaman, terbaru dulu, dengan data pelaku untuk teks gabungan. |
| Aktor | Nasabah |
| Prakondisi | Sesi valid. |
| Proses dan aturan | 1) `get_notifications(p_cursor, p_limit)`: bawaan 30, maks. 100, keyset `"<created_at>\|<id>"` (0003, 0076). <br>2) Baris: `id`, `type`, profil pelaku, `payload`, `event_count`, `actor_count`, `actors` (≤ 3 pelaku terbaru), `read_at`, `created_at`, `cursor`. <br>3) Teks gabungan memakai `actor_count`, bukan `event_count` (mis. "Budi dan 4 lainnya menyukai konten Anda"). <br>4) Hanya pemilik yang bisa membaca (RLS `notifications_select_own`). <br>5) Library membuka tujuan per jenis: postingan, room, "Banding saya", feed saham, halaman info, atau `onOltNotificationTap` untuk pesan OLT. |
| Keluaran | Daftar notifikasi |
| Kode error | `401 not_authenticated`; `400 invalid_cursor` |
| Antarmuka | RPC `get_notifications`; Library: `CommunityNotificationList`, `openCommunityNotification`, `CommunityNotificationBuilders` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-03 Tandai dibaca, hapus, dan badge

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengguna menandai notifikasi dibaca, menghapusnya, dan melihat jumlah belum dibaca yang diperbarui realtime. |
| Aktor | Nasabah |
| Prakondisi | Notifikasi milik pemanggil. |
| Proses dan aturan | 1) `mark_notifications_read(p_ids)`; `null` = semua; mengembalikan jumlah baris yang berubah (0003). <br>2) `get_notification_unread_count()` untuk badge. <br>3) Pemilik boleh `DELETE` dan `UPDATE (read_at)` barisnya sendiri lewat REST (RLS). <br>4) Tabel `notifications` tetap di publikasi `supabase_realtime`, sehingga badge dan daftar berubah tanpa muat ulang (0098). <br>5) Membuka room (`mark_room_read`) menandai notifikasi `message` room itu terbaca; `hide_room` menandai `message` dan `mention` room itu terbaca (0018, 0154). |
| Keluaran | Jumlah baris; jumlah belum dibaca |
| Kode error | — |
| Antarmuka | RPC `mark_notifications_read`, `get_notification_unread_count`; Library: `CommunityNotificationBadge` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-04 Penggabungan notifikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menggabungkan notifikasi sejenis yang belum dibaca menjadi satu baris agar kotak notifikasi tidak dibanjiri. |
| Aktor | Sistem |
| Prakondisi | Notifikasi memiliki `group_key` atau berjenis `like`/`follow`. |
| Proses dan aturan | 1) Indeks unik `(user_id, group_key)` untuk baris belum dibaca: notifikasi berikutnya menaikkan `event_count`, mengganti pelaku dan payload, dan naik ke atas (0003). <br>2) Like: satu notifikasi per post/komentar selamanya; like baru menghidupkan lagi notifikasi yang sudah dibaca dan menaikkannya ke atas; unlike menghapus pelaku, notifikasi terhapus bila pelaku habis (0191). <br>3) Follow digabung ke notifikasi follow belum dibaca tanpa batas waktu (0191). <br>4) Komentar digabung per post (`comments:post:<id>`, `payload.scope = post`) dan balasan per komentar induk (`replies:comment:<id>`, `payload.scope = comment`) selama belum dibaca; mention satu per kejadian (0191). <br>5) Push: like/follow/followed_post yang masuk ke notifikasi belum dibaca tidak mengirim push lagi; like yang menghidupkan lagi notifikasi terbaca mengirim push; judul "N lainnya" memakai jumlah pelaku; push memakai `collapse_key` = `group_key`. <br>6) `get_notifications` menambahkan `payload.post_attachment` (gambar pertama post yang masih terlihat) untuk like, reply, mention, followed_post (0191) dan pengumuman kampanye ber-`post_id` (0192). <br>7) Kunci gabung lain: `message:room:<id>`, `mention:room:<id>`, `followed_post` per penulis per hari WIB (0087, 0173, 0191). |
| Keluaran | Satu baris gabungan |
| Kode error | — |
| Antarmuka | Trigger `notifications_40_preferences` / `notifications_before_insert` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-05 Notifikasi postingan dari akun yang diikuti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi tahu pengikut saat akun yang mereka ikuti menerbitkan postingan yang langsung terlihat. |
| Aktor | Sistem (pg_cron) |
| Prakondisi | Postingan `visible`, umur ≤ 1 hari, penulis bukan akun resmi, staf, atau bot integrasi. |
| Proses dan aturan | 1) Job `social-followed-posts` tiap 30 detik, `notifications.followed_post_batch` 5000 pengikut per putaran (0087). <br>2) Dilewati: pengikut yang membisukan/saling blokir dengan penulis, profil terhapus, postingan ditahan/dihapus sebelum job berjalan. <br>3) Payload `{post_id, author_id, snippet}`; digabung per penulis per hari WIB (0191), `payload.post_id` = postingan terbaru. <br>4) Bawaan in-app aktif, push mati; push hanya untuk postingan pertama hari itu. |
| Keluaran | Notifikasi `followed_post` |
| Kode error | — |
| Antarmuka | Job `social-followed-posts`; Library: ketuk membuka postingan |
| Lacak | BR-NOTIF |

#### FR-NOTIF-06 Ringkasan saham pantauan harian

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim satu ringkasan harian kepada pengguna yang saham pantauannya punya postingan baru, pada jam yang diatur Super Admin. |
| Aktor | Sistem (pg_cron), Super Admin |
| Prakondisi | Pengguna memantau saham (`stock_watchers`). |
| Proses dan aturan | 1) Job `social-watchlist-digest` pada `notifications.watchlist_digest_time` (bawaan 17.05 WIB), sekali per tanggal WIB (`private.watchlist_digest_runs`) (0087, 0147). <br>2) Rentang sejak ringkasan sebelumnya; pertama kali `notifications.digest_lookback_hours` 24 jam; maks. 7 hari. <br>3) Tidak termasuk postingan sendiri, penulis yang dibisukan/saling blokir, dan saham yang dibisukan; pengguna tanpa postingan baru tidak diberi notifikasi. <br>4) Payload `{date, post_count, stock_count, stocks (3 teratas), since, until}`, tanpa `actor_id`. <br>5) Super Admin mengubah jam (format `HH:MM`, 00:00–23:59 WIB) di Hub; trigger di `cs.cs_settings` menjadwalkan ulang job; tercatat di riwayat pengaturan dan audit. Jam yang diubah setelah ringkasan hari itu terkirim berlaku besok. |
| Keluaran | Notifikasi `watchlist_digest` |
| Kode error | `400 invalid_setting` |
| Antarmuka | Job `social-watchlist-digest`; RPC `cs_api.admin_set_setting`; Hub: Pengaturan → Push notification; `get_notification_prefs().watchlist_digest.time` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-07 Notifikasi moderasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi tahu penulis saat konten miliknya disembunyikan atau dihapus moderator, tanpa mengungkap identitas moderator. |
| Aktor | Sistem |
| Prakondisi | Status konten berubah ke `hidden` atau diarsipkan dengan alasan `moderator_remove`. |
| Proses dan aturan | 1) Payload `{target_type, target_id, state: hidden\|removed, excerpt (≤ 140), appealable}` + `post_id` atau `room_id`; tanpa `actor_id` (0087). <br>2) Tidak dikirim untuk penahanan otomatis, konten staf/akun resmi, chat CS, atau sanksi toleransi nol. <br>3) `appealable = false` bila konten sudah pernah dibanding. <br>4) Notifikasi bisu room saham memakai jenis yang sama dengan `target_type: room` dan `state: muted\|unmuted` (0096). <br>5) In-app selalu aktif (`in_app_locked`), push bawaan aktif. Data push tanpa `excerpt`. |
| Keluaran | Notifikasi `moderation` |
| Kode error | — |
| Antarmuka | Library: ketuk membuka "Banding saya" (`openCommunityAppeals`) |
| Lacak | BR-NOTIF |

#### FR-NOTIF-08 Preferensi notifikasi per jenis

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengguna menyalakan atau mematikan notifikasi in-app dan push per jenis, dan menegakkannya untuk semua jalur pembuatan notifikasi dan push. |
| Aktor | Nasabah |
| Prakondisi | Flag `notification_prefs` aktif di klien. |
| Proses dan aturan | 1) Jenis berurutan: `reply`, `mention`, `like`, `follow`, `message`, `announcement`, `appeal`, `followed_post`, `watchlist_digest`, `moderation`, `olt.trade`, `olt.funds`, `olt.market`, `olt.info`, `olt.promo` (0087). <br>2) Bawaan semua aktif, kecuali push `olt.promo` dan push `followed_post` mati. <br>3) `in_app` `moderation` terkunci aktif; nilai `false` diabaikan. <br>4) `set_notification_prefs(p_prefs)` parsial: `types` berupa objek per jenis atau array `[{type, in_app?, push?}]`; nilai sama dengan bawaan menghapus baris. Rate limit `notification_prefs` 30/menit. <br>5) `in_app = false` + `push = true`: notifikasi tidak masuk kotak, push tetap dikirim; `push = false`: push tidak diantrekan (trigger `notifications_40_preferences`, `push_queue_40_preferences`, 0076). |
| Keluaran | `{types:[{type, in_app, push, in_app_locked}], quiet_hours, aggregate_minutes, watchlist_digest}` |
| Kode error | `401 not_authenticated`; `400 invalid_preferences`; `400 invalid_notification_type`; `429 rate_limited` |
| Antarmuka | RPC `get_notification_prefs`, `set_notification_prefs`; Library: `CommunityNotificationSettings`, `openCommunityNotificationSettings` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-09 Jam tenang

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menunda push yang dibuat di dalam jam tenang pengguna sampai jam tenang selesai, sementara notifikasi in-app tetap masuk seketika. |
| Aktor | Nasabah |
| Prakondisi | Jam tenang aktif (bawaan mati). |
| Proses dan aturan | 1) `quiet_hours {enabled, start "HH:MM", end "HH:MM"}` zona `Asia/Jakarta`; start ≠ end; mendukung lintas tengah malam (0087). <br>2) Push dalam jam tenang diberi `available_at` = akhir jam tenang, masa berlaku ikut digeser (0076). <br>3) Push tertunda dengan `collapse_key` sama hanya menyisakan yang terbaru. <br>4) `enabled = false` menghapus pengaturan. |
| Keluaran | Pengaturan jam tenang |
| Kode error | `400 invalid_quiet_hours` |
| Antarmuka | RPC `set_notification_prefs`; Library: `CommunityNotificationSettings` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-10 Pengecualian preferensi dan kategori OLT

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memetakan pesan OLT ke kategori preferensi dan memastikan notifikasi layanan penting tetap sampai walau preferensi dimatikan. |
| Aktor | Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) Pemetaan `private.notification_pref_type(kind, category)`: `olt.trade*`/`olt.order*` → `olt.trade`; `olt.deposit*`/`olt.withdrawal*`/`olt.rdn*` → `olt.funds`; `olt.price_alert*`/`olt.ipo*`/`olt.corporate_action*` → `olt.market`; `olt.*` lain → `olt.info`; kategori `promo` → `olt.promo` (0087). <br>2) Kategori `important` menembus preferensi per jenis dan jam tenang, tetapi tetap hanya ke perangkat terdaftar (0076). <br>3) Notifikasi `message` dari room `support` selalu masuk dan selalu di-push. <br>4) Push uji (`kind = 'test'`) tidak terkena preferensi dan jam tenang. <br>5) `private.push_allowed_for(profile, kind, category)` dipakai layanan internal. |
| Keluaran | Keputusan kirim |
| Kode error | — |
| Antarmuka | `private.notification_pref_type`, `private.push_allowed_for`; Library: bagian "Notifikasi OLT" di pengaturan |
| Lacak | BR-NOTIF |

#### FR-NOTIF-11 Registrasi token push perangkat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mendaftarkan token FCM perangkat ke akun yang sedang login dan memindahkannya bila perangkat berganti akun. |
| Aktor | Aplikasi OLT (lewat library) |
| Prakondisi | Profil aktif (belum dihapus); aplikasi host memasang `firebase_messaging`. |
| Proses dan aturan | 1) `register_push_device(p_token, p_platform, p_locale, p_app_version)`: token 20–4096 karakter tanpa spasi; platform `android`, `ios`, `web`; locale `en` atau `id` (lainnya `id`) (0058). <br>2) Token milik akun lain: push antre akun lama dibatalkan ("Perangkat berganti akun"), token dipindah. <br>3) Maks. `push.max_devices_per_user` (10) perangkat; yang paling lama tidak terlihat dihapus. <br>4) Library: `registerPushToken` dipanggil sekali setelah `initialize` dan setiap token berganti; saat akun berganti di perangkat yang sama, token didaftarkan ulang otomatis. Paket tidak bergantung pada Firebase. |
| Keluaran | `{id, platform, locale}` |
| Kode error | `401 not_authenticated`; `400 invalid_push_token`; `400 invalid_platform` |
| Antarmuka | RPC `register_push_device`; Library: `RendezvousCommunity.instance.registerPushToken`, `CommunityPushPlatform` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-12 Melepas token push

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus melepas token perangkat dari akun saat pengguna keluar, mematikan push, atau menghapus akun, sehingga push akun lama tidak muncul lagi. |
| Aktor | Nasabah, Library, Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) `unregister_push_device(p_token)`: membatalkan push antre perangkat itu lalu menghapus perangkat; token tidak dikenal diabaikan (0058). <br>2) `signOut()` di library melepas token tanpa mencabut izin push; `unregisterPushToken()` untuk pengguna yang mematikan push di aplikasi OLT. <br>3) Hapus akun (`deleted_at`) langsung menghapus perangkat dan antrean push pengguna. <br>4) Token perangkat di `private.push_devices` tidak bisa dibaca aplikasi. |
| Keluaran | — |
| Kode error | `401 not_authenticated` |
| Antarmuka | RPC `unregister_push_device`; Library: `unregisterPushToken`, `signOut` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-13 Antrean push dan isi push

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengubah setiap notifikasi menjadi satu baris antrean push per perangkat penerima, dengan teks dalam bahasa perangkat. |
| Aktor | Sistem (trigger) |
| Prakondisi | Penerima punya perangkat terdaftar; preferensi push mengizinkan. |
| Proses dan aturan | 1) Trigger `notifications_push` → `private.notification_push` → `private.push_enqueue` (0058). <br>2) Judul dan isi per locale `id`/`en` mengikuti kotak notifikasi (mis. "Budi membalas Anda", nama pengirim/grup/CS untuk `message`, judul kampanye untuk `announcement`). <br>3) Data push (semua string): `source=rendezvous_community`, `type`, `kind`, `notification_id`, `push_id`, id dari payload, `actor_id`, `actor_username`; array/boolean diserialisasi JSON (0087). <br>4) `collapse_key` dipakai sebagai tag Android dan `apns-collapse-id`; badge iOS = jumlah notifikasi belum dibaca. <br>5) `push_enqueue` juga dipakai langsung untuk push tanpa entri kotak notifikasi, dengan opsi `collapse_key`, `priority` (bawaan `high`), `ttl_seconds`, `ref`, `badge`. |
| Keluaran | Baris `private.push_queue`; jumlah perangkat yang diantrekan |
| Kode error | — |
| Antarmuka | `private.push_enqueue`; docs/push/README.md |
| Lacak | BR-NOTIF |

#### FR-NOTIF-14 Pengiriman push oleh notifier

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim antrean push ke FCM HTTP v1 secara at-least-once dengan lease, retry, dan penghapusan token mati, aman dijalankan beberapa replika. |
| Aktor | Layanan notifier |
| Prakondisi | Kunci Firebase terpasang (FR-NOTIF-16). |
| Proses dan aturan | 1) `push_claim` memakai `FOR UPDATE SKIP LOCKED` dengan lease (`LEASE` bawaan 60 dtk, `BATCH_SIZE` 100, `CONCURRENCY` 20); hasil dilaporkan sekaligus lewat `push_report` (services/notifier/README.md). <br>2) Hasil: `sent` (2xx), `invalid` (`UNREGISTERED`/token tidak valid, perangkat dihapus), `failed` (payload salah, `THIRD_PARTY_AUTH_ERROR`, `SENDER_ID_MISMATCH` tanpa menghapus perangkat), `retry` (429/5xx, patuhi `Retry-After`), `release` (gangguan sistemik, shutdown, lease hampir habis). <br>3) Backoff 30 detik digandakan sampai 30 menit plus jitter; setelah `push.max_attempts` (6) ditandai gagal; gangguan sistemik tidak menghabiskan jatah dan menjeda claim 15 detik sampai 5 menit. <br>4) Job `push-maintenance` tiap menit: menutup push yang belum terkirim setelah `push.ttl_hours` (24), menghapus riwayat > `push.retention_days` (7) dan perangkat yang tidak aktif > `push.device_stale_days` (270). <br>5) RPC notifier hanya untuk `service_role`; token perangkat di log hanya 6 karakter terakhir. |
| Keluaran | Push terkirim ke HP |
| Kode error | — |
| Antarmuka | RPC `push_claim`, `push_report`; FCM HTTP v1; metrik `notifier_push_total{outcome}` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-15 Status push di Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan status kanal push dari heartbeat notifier beserta statistik pengiriman. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Notifier mengirim `push_heartbeat` tiap 30 detik, saat start, saat kunci berubah, dan saat status error berubah (services/notifier/README.md). <br>2) Status: Aktif, Belum dipasang (`configured=false`), Bermasalah (kunci salah/dicabut, ditolak Google/FCM, APNs ditolak, tidak bisa dibuka), Layanan mati (tanpa heartbeat 90 detik). <br>3) "Sedang memuat kunci" bila `credentials_revision` heartbeat lebih lama dari revisi terbaru. <br>4) Halaman menampilkan jumlah perangkat per platform, terkirim dan gagal 24 jam (termasuk token mati dan kedaluwarsa), antrean dan umur push tertua, kegagalan terakhir. <br>5) Status ringkas juga tampil di Komunitas → Notifikasi. |
| Keluaran | Panel status push |
| Kode error | — |
| Antarmuka | RPC `cs_api.push_status`, `push_heartbeat`; Hub: Pengaturan → Push notification |
| Lacak | BR-NOTIF |

#### FR-NOTIF-16 Unggah kunci Firebase

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin mengunggah file JSON service account Firebase yang divalidasi, disimpan terenkripsi di Vault, dan dimuat notifier tanpa restart. |
| Aktor | Super Admin |
| Prakondisi | Peran `cs_super_admin`. |
| Proses dan aturan | 1) Browser memeriksa file sebelum dikirim; server memeriksa ulang lewat `private.push_credentials_problem`: bukan JSON, `google-services.json` (`project_info`), bukan `service_account`, `project_id`, `client_email` (`*.gserviceaccount.com`), `private_key_id`, atau `private_key` (200–10.000 karakter PEM) tidak valid (0059). <br>2) Disimpan di `vault.secrets` (`push.firebase_service_account`); revisi dinaikkan. <br>3) Kunci dari project lain ditolak kecuali dikonfirmasi `p_replace_project = true` ("Ganti project dan simpan"). <br>4) Notifier memeriksa revisi tiap `CREDENTIALS_RELOAD` (5 dtk), memuat kunci baru, lalu memvalidasi dengan token OAuth dan pesan `validate_only`. <br>5) Web hanya menampilkan project, email akun layanan, ID kunci, pengunggah, dan waktunya; kunci tidak bisa diunduh lagi. Audit `push.credentials_set` tanpa isi kunci. |
| Keluaran | `{revision, project_id, client_email, key_id, updated_at, updated_by}` |
| Kode error | `400 invalid_push_credentials`; `409 push_project_changed`; `403 role_forbidden`; `401 mfa_required` |
| Antarmuka | RPC `cs_api.push_set_credentials`, `push_credentials` (service_role); Hub: Pengaturan → Push notification → Kunci Firebase |
| Lacak | BR-NOTIF |

#### FR-NOTIF-17 Hapus dan ganti kunci Firebase

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin menghapus atau mengganti kunci Firebase, dengan push berhenti atau beralih dalam beberapa detik. |
| Aktor | Super Admin |
| Prakondisi | Kunci sudah terpasang (untuk hapus). |
| Proses dan aturan | 1) `cs_api.push_remove_credentials()` menghapus secret Vault dan menaikkan revisi; notifier melepas kunci dan berhenti claim (`configured=false`) (0059). <br>2) Notifikasi tetap masuk kotak aplikasi; push antre kedaluwarsa setelah `push.ttl_hours`. <br>3) Rotasi: unggah kunci baru lewat Ganti kunci, tunggu status Aktif, lalu hapus kunci lama di Google Cloud Console (docs/push/README.md). <br>4) Restore ke server tanpa volume kunci enkripsi Vault: status "Kredensial Firebase tersimpan tidak bisa dibuka", unggah ulang dari Hub. <br>5) Audit `push.credentials_removed`. |
| Keluaran | `{removed: true}` |
| Kode error | `404 push_credentials_missing` |
| Antarmuka | RPC `cs_api.push_remove_credentials`; Hub: Pengaturan → Push notification |
| Lacak | BR-NOTIF |

#### FR-NOTIF-18 Push uji

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin mengirim push uji ke perangkat seorang pengguna untuk memastikan kanal push berjalan. |
| Aktor | Super Admin |
| Prakondisi | Pengguna target punya perangkat terdaftar. |
| Proses dan aturan | 1) `cs_api.push_find_users(p_query)`: 2–60 karakter, maks. 10 profil yang punya perangkat, beserta daftar perangkatnya (0058). <br>2) `cs_api.push_test(p_user_id)` mengantrekan push "Tes push notification" dua bahasa, `ttl_seconds` 600, tanpa badge, `ref: test`. <br>3) Tidak terkena preferensi dan jam tenang. <br>4) Audit `push.test` dengan jumlah perangkat. |
| Keluaran | `{queued}` |
| Kode error | `400 invalid_query`; `404 no_push_devices` |
| Antarmuka | RPC `cs_api.push_find_users`, `cs_api.push_test`; Hub: Pengaturan → Push notification |
| Lacak | BR-NOTIF |

#### FR-NOTIF-19 Membuka push di aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus membuka layar tujuan dari data push komunitas dan meneruskan push OLT ke aplikasi host. |
| Aktor | Aplikasi OLT, Library |
| Prakondisi | Aplikasi host menerima pesan FCM. |
| Proses dan aturan | 1) `openCommunityPush(context, data)` membuka postingan, chat, chat CS, profil pengikut, halaman info (`notice_id`), atau tautan pengumuman, dan menandai notifikasi terbaca (docs/push/README.md, features.md). <br>2) Mengembalikan `false` bila `data['source'] != 'rendezvous_community'`; `isCommunityPush`/`isOltPush` membantu host memilih jalur. <br>3) Push OLT diteruskan ke `onOltNotificationTap` bila didaftarkan, lalu dihitung `tapped`. <br>4) Saat aplikasi di depan, badge dan daftar sudah diperbarui realtime; notifikasi lokal opsional. |
| Keluaran | Navigasi ke tujuan |
| Kode error | — |
| Antarmuka | Library: `openCommunityPush`, `isCommunityPush`, `isOltPush`, `reportNotificationTapped`, `initialize(onOltNotificationTap:)` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-20 Statistik dibuka dan diketuk

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat kapan pengguna membuka notifikasi dan mengikuti tujuannya, dengan atribusi ke kampanye, siaran OLT, atau notifikasi itu sendiri. |
| Aktor | Nasabah (lewat library) |
| Prakondisi | — |
| Proses dan aturan | 1) `report_notification_event(p_event, p_notification_id, p_campaign_id, p_broadcast_id)`; `p_event` `opened` atau `tapped` (`tapped` juga mencatat `opened`) (0088). <br>2) Prioritas atribusi: kampanye → siaran OLT → notifikasi. Id milik orang lain atau tidak dikenal → `recorded: false` tanpa error. <br>3) Dedupe per (pengguna, sumber, event); `read = true` bila notifikasi milik pemanggil baru ditandai dibaca. <br>4) Rate limit `notification_event` 120/menit. Klien mengirim tanpa menahan UI dan mengantrekan di memori saat offline. <br>5) Saat akun dihapus `user_id` dikosongkan agar statistik tetap. |
| Keluaran | `{recorded, source, source_id, read}` |
| Kode error | `400 invalid_event`; `400 missing_source`; `401 not_authenticated`; `429 rate_limited` |
| Antarmuka | RPC `report_notification_event`; Library: `NotificationReporter` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-21 Kampanye notifikasi: draf

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan staf dengan izin tulis membuat dan mengubah draf kampanye notifikasi atas nama akun resmi. |
| Aktor | Staf dengan izin `community.post` |
| Prakondisi | Akun resmi pengirim aktif. |
| Proses dan aturan | 1) `cs_api.community_save_campaign(p_id, p_account_id, p_title, p_body, p_link_post_id, p_link_url, p_audience, p_audience_stock, p_send_at, p_version, p_audience_days, p_audience_platform, p_audience_account_id)` (0184). <br>2) Judul 3–120 dan isi 3–500 karakter; melewati validasi teks dan kebijakan konten (kata terlarang). <br>3) Tujuan saat diketuk: kotak notifikasi, satu postingan resmi yang sudah terbit, atau tautan `https://` ≤ 500; tidak boleh keduanya. <br>4) Hanya pembuat yang bisa mengubah, dan hanya status `draft`/`rejected`; ubah mengembalikan status ke `draft`. <br>5) Konkurensi optimistik lewat `p_version`. Audit `community.campaign_save` beserta `audience`. |
| Keluaran | Objek kampanye |
| Kode error | `400 official_inactive`; `400 invalid_title`; `400 invalid_body`; `400 invalid_link`; `400 invalid_audience`; `404 campaign_not_found`; `403 not_campaign_owner`; `409 invalid_status`; `409 stale_version`; `422 content_blocked`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_save_campaign`, `cs_api.community_campaigns`; Hub: Komunitas → Notifikasi |
| Lacak | BR-NOTIF |

#### FR-NOTIF-22 Kampanye notifikasi: segmen penerima

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mendukung segmen penerima kampanye dan menampilkan perkiraan jumlah penerima sebelum dikirim. |
| Aktor | Staf dengan izin `community.post` atau `community.publish` |
| Prakondisi | — |
| Proses dan aturan | 1) Segmen: `all`, `stock` (pemantau saham, kode dinormalkan), `new_users` (dibuat < N hari, 1–365), `inactive` (aktivitas terakhir ≥ N hari, 1–365; aktivitas = maks. login terakhir, `last_seen_at` perangkat push, event analitik terakhir), `platform` (android, ios, web, windows, macos, linux), `followers` (pengikut akun resmi aktif) (0088). <br>2) Semua segmen mengecualikan profil terhapus, akun resmi, dan staf. <br>3) Parameter yang tidak relevan dengan segmen dibersihkan. <br>4) `cs_api.community_audience_size(...)` mengembalikan perkiraan jumlah. |
| Keluaran | `integer` perkiraan penerima |
| Kode error | `400 invalid_audience` |
| Antarmuka | RPC `cs_api.community_audience_size`; Hub: Komunitas → Notifikasi |
| Lacak | BR-NOTIF |

#### FR-NOTIF-23 Kampanye notifikasi: persetujuan empat mata

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mewajibkan kampanye diajukan dan disetujui staf lain sebelum dikirim bila aturan empat mata aktif. |
| Aktor | Pembuat (`community.post`), penyetuju (`community.publish`) |
| Prakondisi | Kampanye `draft` (ajukan) atau `pending` (tinjau). |
| Proses dan aturan | 1) `community_submit_campaign(p_id, p_version)`: hanya pembuat, hanya `draft` → `pending` (0057). <br>2) `community_review_campaign(p_id, p_approve, p_note, p_version)`: `community.four_eyes` (bawaan aktif, diatur di Pengaturan → Aturan persetujuan) melarang pembuat menyetujui miliknya; bila mati, pembuat dengan izin terbit boleh menyetujui draf sendiri. <br>3) Penolakan wajib alasan 5–500 karakter dan status menjadi `rejected`. <br>4) Disetujui: `scheduled` bila `send_at` di masa depan, selain itu `sending` dan batch pertama langsung dikirim. Akun resmi yang sudah nonaktif menggagalkan persetujuan. <br>5) Audit `community.campaign_submit`, `community.campaign_approve`, `community.campaign_reject`. |
| Keluaran | Objek kampanye |
| Kode error | `403 not_campaign_owner`; `409 invalid_status`; `403 four_eyes`; `400 note_required`; `400 official_inactive`; `409 stale_version` |
| Antarmuka | RPC `cs_api.community_submit_campaign`, `cs_api.community_review_campaign`; Hub: Komunitas → Notifikasi |
| Lacak | BR-NOTIF |

#### FR-NOTIF-24 Kampanye notifikasi: pengiriman, jadwal, dan pembatalan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim kampanye yang disetujui secara bertahap sebagai notifikasi `announcement`, menjalankan jadwal, dan mengizinkan pembatalan sebelum terkirim. |
| Aktor | Sistem (pg_cron), staf |
| Prakondisi | Kampanye `sending` atau `scheduled`. |
| Proses dan aturan | 1) `cs.community_send_batch` 5.000 penerima per putaran, urut id profil; status `sent` setelah batch terakhir; audit `community.campaign_sent` (0088). <br>2) Job `cs-community` tiap 15 detik memindahkan kampanye terjadwal yang jatuh tempo ke `sending` dan melanjutkan batch (docs/community/README.md). <br>3) Payload `{campaign_id, title, body, post_id?, url?}`, pelaku = akun resmi; preferensi `announcement` penerima tetap berlaku; push lewat jalur notifikasi biasa. <br>4) `community_cancel_campaign`: pembuat untuk `draft`/`pending`/`scheduled`/`rejected`, penyetuju untuk `pending`/`scheduled`; audit `community.campaign_cancel`. <br>5) Opsi "Kirim notifikasi saat terbit" pada postingan resmi membuat kampanye otomatis (sisi postingan ditulis di modul HUB). |
| Keluaran | Notifikasi `announcement` di kotak penerima |
| Kode error | `404 campaign_not_found`; `409 invalid_status`; `409 stale_version` |
| Antarmuka | RPC `cs_api.community_cancel_campaign`; job `cs-community`; Library: notifikasi `announcement` membuka postingan atau tautan `https` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-25 Kampanye notifikasi: statistik

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan jumlah penerima, push terkirim/menunggu/gagal, serta tingkat dibuka dan diketuk setiap kampanye. |
| Aktor | Staf dengan izin `community.post` atau `community.publish` |
| Prakondisi | — |
| Proses dan aturan | 1) Baris `community_campaigns()` memuat `recipients`, `opened`, `tapped` (pengguna unik), `open_rate`, `tap_rate` (persen 1 desimal, `null` bila `recipients = 0`) (0088). <br>2) `community_campaign_push(p_id)` memuat statistik push dari `private.push_ref_stats` (`ref = campaign:<id>`) dan status kanal push (0058, 0088). |
| Keluaran | Statistik kampanye |
| Kode error | `404 campaign_not_found` |
| Antarmuka | RPC `cs_api.community_campaigns`, `cs_api.community_campaign_push`; Hub: Komunitas → Notifikasi (detail kampanye) |
| Lacak | BR-NOTIF |

#### FR-NOTIF-26 Kelola banner strip dan popup

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin dan peran Fitur & Banner membuat dan mengubah banner strip atau popup dengan jadwal, sasaran, platform, versi, dan prioritas. |
| Aktor | Super Admin, peran `product` |
| Prakondisi | — |
| Proses dan aturan | 1) `cs_api.admin_save_banner(p_id, p_title, p_body, p_link_url, p_level, p_starts_at, p_ends_at, p_platforms, p_min_app_version, p_max_app_version, p_dismissible, p_priority, p_display, p_image_url, p_cta_label, p_frequency, p_audience, p_audience_days, p_notify, p_image_ratio)`; `p_id = null` membuat baru (0184). <br>2) Judul 1–120; isi strip ≤ 300, popup ≤ 5000; `display` `strip`/`popup`; `level` `info`/`warning`/`critical`. <br>3) Tautan `https://` atau deep link berskema terdaftar, ≤ 500; label tombol ≤ 24 dan hanya bila ada tautan. <br>4) `frequency` `once`/`daily`/`every_open` (juga untuk strip sejak 0181); sasaran `all` atau `new_users` 1–90 hari. <br>5) Platform android, ios, web, windows, macos, linux; versi `2.4.0`, min ≤ maks; prioritas 0–1000; `ends_at` setelah `starts_at`; `p_starts_at = null` = sekarang (baru) atau tetap (ubah). <br>6) Audit `banner.save` dengan isi sebelum/sesudah. |
| Keluaran | Objek banner (termasuk `status` active/scheduled/ended dan `stats`) |
| Kode error | `400 invalid_display`; `400 invalid_title`; `400 invalid_body`; `400 invalid_link`; `400 invalid_cta`; `400 invalid_frequency`; `400 invalid_audience`; `400 invalid_image`; `400 invalid_image_ratio`; `400 invalid_level`; `400 invalid_platform`; `400 invalid_version`; `400 invalid_priority`; `400 invalid_schedule`; `404 banner_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_save_banner`, `cs_api.admin_banners`; Hub: Banner & Popup (`/features`) |
| Lacak | BR-NOTIF |

#### FR-NOTIF-27 Gambar popup dan hapus banner

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan unggah gambar popup dengan rasio tetap dan penghapusan banner, dengan file yatim dibersihkan otomatis. |
| Aktor | Super Admin, peran `product` |
| Prakondisi | Sesi staf aal2 untuk unggah (`private.can_manage_banners`). |
| Proses dan aturan | 1) Bucket publik `app-banners`, maks. 2 MB, JPEG/PNG/WebP, nama `<uuid>.<jpg\|png\|webp>`; hanya untuk popup; objek harus ada saat disimpan (0119, 0184). <br>2) Hub memotong ke 4:5 (960×1200) atau 1:1 (960×960) dan mengecilkan di bawah 2 MB; `image_ratio` `portrait`/`square` disimpan bila ada gambar, dan dipertahankan bila gambar tidak berubah (0183). <br>3) `admin_delete_banner(p_id)` menghapus banner, membatalkan notifikasi info yang belum terkirim, audit `banner.delete`. <br>4) Gambar yang diganti, dilepas, atau milik banner terhapus masuk `private.storage_cleanup_queue`; job `app-banner-maintenance` (03:47 UTC) mengantrekan gambar yatim > 1 hari. |
| Keluaran | `{id, deleted: true}` untuk hapus |
| Kode error | `400 invalid_image`; `400 invalid_image_ratio`; `404 banner_not_found` |
| Antarmuka | Upload Storage `app-banners`; RPC `cs_api.admin_delete_banner`; Hub: Banner & Popup |
| Lacak | BR-NOTIF |

#### FR-NOTIF-28 Penyajian banner ke aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim banner yang aktif untuk platform, versi, dan sasaran pemanggil di dalam konfigurasi klien, termasuk riwayat tayang dan tutup milik akun. |
| Aktor | Aplikasi (anon dan authenticated) |
| Prakondisi | — |
| Proses dan aturan | 1) `get_client_config(p_platform, p_app_version).banners`: maks. 10 banner aktif (`starts_at ≤ now`, `ends_at` kosong atau > now), urut `priority` turun lalu `starts_at` terbaru (0185). <br>2) `platforms` kosong = semua; batas versi hanya terpenuhi bila versi dikirim; nomor build `+54` diabaikan (0183). <br>3) Sasaran `new_users` hanya untuk pemanggil login yang profilnya ≤ `audience_days`; field sasaran tidak dikirim. <br>4) `link_url` dan `cta_label` dikirim `null` bila skema deep link sudah dicabut. <br>5) Untuk pemanggil login: `seen_at` (terbaru antara impression dan `opened`/`tapped` notifikasi banner itu) dan `dismissed_at`; `config.viewer_id` menyebut user penyusun respons (0183, 0185). |
| Keluaran | Array `banners` |
| Kode error | `400 invalid_platform`; `400 invalid_version` |
| Antarmuka | RPC `get_client_config` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-29 Tampilan banner strip di library

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan banner strip sesuai level, frekuensi, dan status tutup per akun di halaman host. |
| Aktor | Library |
| Prakondisi | Konfigurasi klien termuat. |
| Proses dan aturan | 1) `CommunityBannerHost` menampilkan maks. 3 strip (`maxVisible`), urut prioritas; feed Terbaru/Mengikuti menampilkannya otomatis (features.md). <br>2) Frekuensi: `once` sekali per pengguna, `daily` sekali per hari kalender lokal, `every_open` setiap sesi; strip yang sudah muncul tetap tampil sampai sesi berakhir; yang tidak jatuh tempo tidak memakan jatah `maxVisible`. <br>3) Strip `dismissible` yang punya `dismissed_at` tidak tampil; strip tidak bisa ditutup selalu tampil. <br>4) Setelah login, banner menunggu konfigurasi dengan `viewer_id` milik user itu. <br>5) Tautan dibuka setelah dialog konfirmasi; `onBannerLink` host dipanggil lebih dulu. Banner `popup` tidak tampil sebagai strip. Kill switch tidak berpengaruh. |
| Keluaran | Strip banner |
| Kode error | — |
| Antarmuka | Library: `CommunityBannerHost`, `CommunityStripViews`, `BannerDismissals` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-30 Popup promo di library

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus menampilkan paling banyak satu popup promo per sesi aplikasi per user, sesuai prioritas dan frekuensi, tanpa menutupi dialog lain. |
| Aktor | Library |
| Prakondisi | User sudah login; `CommunityPromoPopupHost` dipasang di bawah `Navigator`. |
| Proses dan aturan | 1) Dipilih banner `popup` aktif dengan prioritas tertinggi yang lolos frekuensi; sama → `starts_at` terbaru; jadwal dicek ulang dengan jam server (features.md). <br>2) Tidak tampil saat belum login, `update_required`, `enabled: false`, atau ada route/dialog lain di atas host (ditunda). <br>3) Tampilan: overlay 60%, kartu maks. 360, gambar dengan rasio `image_ratio` (4:5 atau 1:1), tombol utama (`cta_label`, bawaan "Lihat"), "Nanti", tombol tutup (X) bila `dismissible`; target sentuh ≥ 48. <br>4) Event: tampil → `impression`, tombol/gambar → `click`, tombol tutup (X)/Nanti/overlay → `dismiss`. <br>5) Frekuensi memakai yang terbaru antara catatan lokal (`promo_popups:<user>`, maks. 100) dan `seen_at` server. |
| Keluaran | Popup |
| Kode error | — |
| Antarmuka | Library: `CommunityPromoPopupHost`, `showCommunityPromoPopup`, `CommunityPromoPopupCard`, slot `system.popup` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-31 Event dan statistik banner

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat tayang, klik, dan tutup banner per nasabah dan menampilkan statistiknya di Hub. |
| Aktor | Nasabah (lewat library), Super Admin, peran `product` |
| Prakondisi | Pemanggil nasabah login (bukan akun CS). |
| Proses dan aturan | 1) `record_banner_event(p_banner_id, p_event)` dengan `impression`, `click`, `dismiss` (0185). <br>2) Dedupe per (banner, pengguna, event, hari WIB); banner tidak ada, belum mulai, selesai, atau di luar sasaran → `recorded: false` tanpa membocorkan keberadaannya. <br>3) Rate limit `banner_event` 120/menit. <br>4) `admin_banners()` memuat `stats {impressions, clicks, dismissals, unique_viewers, ctr}`; `admin_banner_stats(p_id)` menambah rincian 7 hari WIB (0119). <br>5) Retensi event `banners.events_retention_days` (180), kecuali `impression`/`dismiss` terakhir per user pada banner yang belum berakhir (0183). |
| Keluaran | `{recorded}`; statistik banner |
| Kode error | `401 not_authenticated`; `403 customer_required`; `400 invalid_event`; `429 rate_limited`; `404 banner_not_found` |
| Antarmuka | RPC `record_banner_event`, `cs_api.admin_banner_stats`; Hub: Banner & Popup |
| Lacak | BR-NOTIF |

#### FR-NOTIF-32 Skema deep link banner

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin mengatur skema deep link yang boleh dipakai banner, sambil selalu menolak skema berbahaya. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) `banners.deep_link_schemes` bawaan `["olt"]`, maks. 5, pola `^[a-z][a-z0-9+.-]{0,31}$`, dinormalkan huruf kecil dan unik (0119, 0124). <br>2) Selalu ditolak: `http`, `https`, `javascript`, `vbscript`, `data`, `file`, `filesystem`, `blob`, `about`, `intent`, `content`; constraint `app_banners_link_url_check` menolak skema berbahaya walau lewat SQL langsung. <br>3) Banner dengan skema yang dicabut dikirim ke klien dengan `link_url = null`. <br>4) Audit `banner.link_schemes` sebelum/sesudah. |
| Keluaran | `{deep_link_schemes, forbidden_schemes, max_schemes, updated_at, updated_by}` |
| Kode error | `400 invalid_link_schemes` |
| Antarmuka | RPC `cs_api.admin_banner_settings`, `cs_api.admin_set_banner_link_schemes`; Hub: Pengaturan → Integrasi → Integrasi aplikasi |
| Lacak | BR-NOTIF |

#### FR-NOTIF-33 Notifikasi info dari Banner & Popup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan banner baru dikirim juga sebagai notifikasi info ke semua nasabah sasarannya, dengan persetujuan empat mata opsional. |
| Aktor | Super Admin, peran `product` |
| Prakondisi | Banner baru disimpan dengan `p_notify = true`. |
| Proses dan aturan | 1) Baris `private.app_notices` dibuat dari banner: judul ≤ 120, isi ≤ 5000, tautan, label tombol, gambar, level, sasaran (0182, 0184). <br>2) Status awal `pending` bila `banners.notice_four_eyes` = true (bawaan false), `scheduled` bila banner belum mulai, selain itu `queued`. <br>3) `admin_review_banner_notice(p_id, p_approve, p_note)`: hanya `pending`, bukan pembuatnya; penolakan wajib alasan 5–500. <br>4) `admin_cancel_banner_notice(p_id)` untuk status `pending`/`scheduled`/`queued`/`sending`. <br>5) `admin_banner_notice_preview(p_audience, p_audience_days)` → `{recipients, four_eyes}`; `admin_banner_notices(p_limit)` (maks. 200) dengan `recipients`, `opened`, `tapped`. <br>6) `banners.notice_four_eyes` diubah Super Admin lewat `admin_set_setting`. Audit `banner.notice_create`, `banner.notice_approve`, `banner.notice_reject`, `banner.notice_cancel`. |
| Keluaran | Objek notifikasi info |
| Kode error | `404 notice_not_found`; `409 invalid_status`; `403 four_eyes`; `400 note_required`; `400 invalid_audience` |
| Antarmuka | RPC `cs_api.admin_save_banner`, `cs_api.admin_review_banner_notice`, `cs_api.admin_cancel_banner_notice`, `cs_api.admin_banner_notice_preview`, `cs_api.admin_banner_notices`; Hub: Banner & Popup |
| Lacak | BR-NOTIF |

#### FR-NOTIF-34 Pengiriman dan halaman notifikasi info

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim notifikasi info secara bertahap sebagai notifikasi `announcement` dan menyediakan isi lengkapnya hanya bagi penerima. |
| Aktor | Sistem (pg_cron), Nasabah |
| Prakondisi | Notifikasi info `queued`, atau `scheduled` yang jatuh tempo. |
| Proses dan aturan | 1) Cron `app-notices` tiap 15 detik, `integration.broadcast_batch_size` (2000) profil per putaran, ke profil aktif sesuai sasaran, tanpa akun `official:%` dan `cs-staff:%` (0182). <br>2) Payload `{notice_id, banner_id, title, body (cuplikan ≤ 280 diakhiri …), body_truncated, level, link_url, cta_label, image_url, sent_at}` (0184). <br>3) Push lewat pemicu notifikasi biasa (data membawa `notice_id`); preferensi `announcement` penerima tetap berlaku. <br>4) `get_app_notice(p_id)` mengembalikan judul dan isi lengkap hanya bila pemanggil menerima notifikasinya. <br>5) Library menampilkan cuplikan di daftar dan memuat isi lengkap di halaman info; tombol CTA memanggil `onBannerLink`, `https` lewat konfirmasi tautan luar, skema lain diabaikan. |
| Keluaran | Notifikasi `announcement`; isi notifikasi info |
| Kode error | `401 not_authenticated`; `404 notice_not_found` |
| Antarmuka | Cron `app-notices`; RPC `get_app_notice`; Library: `CommunityNoticePage`, `openCommunityNotice`, `CommunitySystemBuilders(notice:, noticeHeader:)` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-35 Sinkron popup dan notifikasi info

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menandai notifikasi info terbaca saat banner yang sama sudah dilihat sebagai popup atau diklik, dan sebaliknya mencatat banner terlihat saat notifikasinya dibuka. |
| Aktor | Sistem |
| Prakondisi | Notifikasi `announcement` membawa `banner_id`. |
| Proses dan aturan | 1) `record_banner_event` `click` pada banner apa pun, atau `impression` pada banner `popup`, mengisi `read_at` notifikasi `announcement` milik pengguna yang payload-nya membawa `banner_id` itu (0185). <br>2) Perubahan sampai ke klien lewat realtime (UPDATE `public.notifications`). <br>3) `seen_at` banner memakai waktu terbaru antara impression dan event `opened`/`tapped` notifikasi banner itu, sehingga popup "sekali per pengguna" tidak muncul lagi setelah notifikasinya dibuka. |
| Keluaran | `read_at` dan `seen_at` tersinkron |
| Kode error | — |
| Antarmuka | RPC `record_banner_event`, `report_notification_event`, `get_client_config` |
| Lacak | BR-NOTIF |

#### FR-NOTIF-36 Retensi notifikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghapus notifikasi lama dan data terkait secara berkala sesuai pengaturan retensi. |
| Aktor | Sistem (job retensi, modul OPS) |
| Prakondisi | — |
| Proses dan aturan | 1) Notifikasi lebih tua dari `retention.notifications_days` (bawaan 90 hari) dihapus (0015). <br>2) Riwayat antrean push > `push.retention_days` (7) dihapus job `push-maintenance` (0058). <br>3) Tanda terima pesan `private.message_receipts` > 30 hari dihapus harian (0122). <br>4) Hapus akun menghapus preferensi, jam tenang, jejak pelaku notifikasi, perangkat dan antrean push; event dibuka/diketuk dianonimkan (0090). |
| Keluaran | Data lama terhapus |
| Kode error | — |
| Antarmuka | `private.settings` `retention.notifications_days`; job `push-maintenance` |
| Lacak | BR-NOTIF |

### 4.7 Moderasi dan keamanan konten (MOD)

Modul MOD mencakup semua aturan yang menjaga konten komunitas tetap aman: laporan pengguna, rantai trigger pemeriksaan konten (kata terlarang, normalisasi, kategori tautan/kontak/promosi, pembatasan akun baru), moderasi gambar NSFW, antrean dan keputusan moderator di Hub, sanksi bertingkat, banding, toleransi nol (CSAM), anti-manipulasi saham, alat staf untuk room saham (slow mode, pin, moderator room), riwayat edit, dan aturan membuka konten privat. Semua aturan ditegakkan di database sehingga berlaku untuk semua klien (docs/content-safety.md). Pengelolaan isi kebijakan (versi, draf, empat mata, ambang, daftar kata) ada di modul PATUH (4.8). Penanganan tiket CS ada di modul CS, permintaan pesan DM di CHAT, blokir/mute akun dan hapus akun dari sisi pengguna di AKUN, kill switch dan izin staf di HUB, sisi Kepatuhan Berbagi Trade di TRADE (dijeda).

Izin staf yang dipakai modul ini (diberikan per akun oleh Super Admin, lihat HUB): `community.moderate` (antrean laporan, konten dan gambar ditahan, alert manipulasi, banding konten, room saham) dan `community.sanction` (sanksi, cabut sesi, banding sanksi, toleransi nol). Tanpa izin, RPC menolak `403 community_forbidden` (0057).

**Rantai trigger konten.** Postingan (`posts`), komentar (`comments`), dan pesan chat (`messages`) melewati trigger berikut. Postgres menjalankan trigger BEFORE berurutan menurut nama, lalu trigger AFTER. Pemeriksaan `_25`–`_31` hanya berlaku untuk pengguna aplikasi yang menulis kontennya sendiri (`private.is_end_user()`); staf yang memoderasi, job server, dan seed tidak terkena.

| Urutan | Trigger | Tujuan |
|---|---|---|
| 1 | `messages_05_support` (BEFORE, pesan) | Aturan khusus chat CS (`cs.message_before_write`); milik modul CS (0028) |
| 2 | `messages_08_room_mute` (BEFORE INSERT, pesan) | Anggota yang dibisukan moderator room ditolak `403 room_muted` (0093) |
| 3 | `*_10_rate_limit` (BEFORE INSERT) | Batas kirim per jendela waktu dari `private.rate_limits`, dikali faktor trust/akun baru (0012, 0187) |
| 4 | `*_20_before_write` / `comments_20_before_insert` / `comments_20_before_update` (BEFORE) | Merapikan teks, validasi panjang dan lampiran (0004, 0005, 0008) |
| 5 | `messages_22_edit` (BEFORE UPDATE body) | Aturan edit pesan: hanya pengirim, jendela `content.edit_minutes`, simpan versi lama (0154); milik CHAT |
| 6 | `comments_25_comment_audience` (BEFORE INSERT) | Kontrol komentar per postingan/akun (0169, 0170); milik KOM |
| 7 | `*_25_integrity` (BEFORE INSERT/UPDATE body) | Mute/ban, persetujuan dokumen hukum, karakter kontrol, maks link/mention/`$KODE`, anti-duplikat (0014, 0062) |
| 8 | `messages_26_slow_mode` (BEFORE INSERT) | Slow mode room saham, `429 slow_mode` (0072) |
| 9 | `messages_26a_official_no_dm` (BEFORE INSERT) | User biasa tidak bisa DM akun resmi, `403 official_no_dm` (0144); milik CHAT |
| 10 | `messages_26b_group_admins_only` (BEFORE INSERT) | Grup hanya-admin, `403 group_admins_only` (0146); milik CHAT |
| 11 | `messages_27_dm_request` (BEFORE INSERT) | Kebijakan DM dan batas 3 pesan permintaan (0070); milik CHAT |
| 12 | `*_30_content_policy` (BEFORE INSERT/UPDATE body) | Kata terlarang: sensor (`mask`) atau tolak (`block`) pada teks asli dan ternormalisasi (0004, 0005, 0008, fungsi 0069) |
| 13 | `*_31_safety` (BEFORE INSERT/UPDATE body) | Keamanan konten: akun baru, tautan/domain, kontak, frasa promosi → `allow`/`censor`/`hold`/`block` (0069, 0187) |
| 14 | `*_40_edit` (BEFORE UPDATE body, post/komentar) | Jendela edit dan simpan versi lama ke `private.content_edits` (0075); milik KOM |
| 15 | `*_41_kill_switch` (BEFORE) | Kill switch fitur sosial, `503 social_disabled` (0077); milik HUB |
| 16 | `*_32_moderation_log` (AFTER UPDATE status/deleted_at) | Catat perubahan status ke `private.moderation_events` untuk banding (0071) |
| 17 | `*_33_moderation_notice` (AFTER UPDATE status) | Notifikasi `moderation` ke penulis saat konten disembunyikan/dihapus moderator (0087); tipe notifikasi milik NOTIF |
| 18 | `posts_42_search`, `*_50_link_preview` (AFTER) | Indeks pencarian (0073) dan antrean pratinjau link (0080); pratinjau tidak dibuat untuk konten ditahan |

#### FR-MOD-01 Laporan konten dan akun oleh pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengguna melaporkan postingan, komentar, pesan, atau akun pengguna lain ke antrean moderasi. |
| Aktor | Nasabah (authenticated) |
| Prakondisi | Pengguna login sosial, tidak di-ban. |
| Proses dan aturan | 1) Baris baru di `public.reports` dengan `target_type` `post`/`comment`/`message`/`user` dan `reason` `spam`/`abuse`/`scam`/`pump_and_dump`/`misinformation`/`other` (0009). <br>2) `details` opsional, dipangkas, maksimal 1.000 karakter. <br>3) Satu laporan per pelapor per target (unique `reporter_id, target_type, target_id`); library memperlakukan duplikat sebagai sukses (`insertIgnoringDuplicate`). <br>4) Target harus ada; laporan pesan hanya dari anggota room pesan itu. <br>5) Rate limit `report` 10 per jam per pengguna (0002), dikali faktor trust. <br>6) RLS: pengguna hanya membaca laporannya sendiri. <br>7) Setiap laporan merekam bukti di karantina bukti (0095, lihat FR-PATUH-19). |
| Keluaran | Laporan status `open` masuk antrean `cs_api.community_reports`. |
| Kode error | `404 target_not_found`; `429 rate_limited`; `403 user_banned` |
| Antarmuka | REST `POST /rest/v1/reports`; Library: `ModerationRepository.report`, `ReportReason`, menu "Laporkan" di pesan/profil, `CommunityReportDetails` |
| Lacak | BR-MOD |

#### FR-MOD-02 Laporan otomatis dari blokir permintaan pesan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat laporan `spam` terhadap pengirim saat penerima memilih "Blokir" pada permintaan pesan DM. |
| Aktor | Nasabah penerima permintaan pesan |
| Prakondisi | Ada permintaan pesan berstatus `pending` (alur permintaan pesan milik CHAT). |
| Proses dan aturan | 1) `respond_message_request(p_room_id, 'block')` menyisipkan blokir ke `public.blocks` dan laporan `target_type = 'user'`, `reason = 'spam'`, detail "Permintaan pesan yang tidak diinginkan" (0070). <br>2) Bila pelapor sudah pernah melaporkan akun itu, laporan tidak digandakan (`on conflict do nothing`). <br>3) Pengirim tidak diberi tahu. |
| Keluaran | `{room_id, status: "declined", blocked: true}`; laporan masuk antrean moderasi. |
| Kode error | — |
| Antarmuka | RPC `respond_message_request`; Library: aksi "Blokir & laporkan" di Permintaan pesan |
| Lacak | BR-MOD |

#### FR-MOD-03 Cakupan dan pengecualian pemeriksaan konten

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menjalankan pemeriksaan integritas, kata terlarang, dan keamanan konten pada setiap postingan, komentar, dan pesan non-CS yang ditulis pengguna aplikasi, dengan pengecualian yang ditetapkan. |
| Aktor | Sistem (trigger database) |
| Prakondisi | Konten ditulis lewat INSERT atau UPDATE kolom `body`. |
| Proses dan aturan | 1) Urutan pemeriksaan mengikuti tabel rantai trigger di atas. <br>2) Pemeriksaan `_25`–`_31` dilewati bila penulis bukan pengguna akhir (staf yang memoderasi, job, seed) atau bila baris sudah dihapus. <br>3) Kiriman ulang dengan `client_id` yang sama tidak diperiksa ulang (idempoten). <br>4) Chat CS (room `support`, pesan ber-`session_id`) tidak terkena kategori keamanan konten. <br>5) Staf CS dan akun resmi dikecualikan dari kategori tautan/kontak/promosi dan pembatasan akun baru (`private.safety_exempt`), tetapi kata terlarang tetap berlaku (0069). <br>6) Pesan error tidak menyebut kategori, kata, atau daftar yang cocok. |
| Keluaran | Konten diterima apa adanya, disensor, ditahan, atau ditolak. |
| Kode error | Lihat FR-MOD-04 s.d. FR-MOD-12 |
| Antarmuka | Trigger `posts/comments/messages_*`; semua klien (Flutter, web, bot) |
| Lacak | BR-MOD |

#### FR-MOD-04 Integritas konten

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak konten dari akun yang dibisukan, akun yang belum menyetujui dokumen hukum wajib, serta konten berkarakter kontrol, berlebihan tautan/mention/kode saham, atau duplikat. |
| Aktor | Sistem (`*_25_integrity`) |
| Prakondisi | Penulis pengguna akhir. |
| Proses dan aturan | 1) INSERT oleh akun dengan sanksi `mute` atau `ban` aktif ditolak. <br>2) INSERT ditolak bila ada dokumen hukum wajib (`legal.required_kinds`, bawaan `terms`, `community_guidelines`) yang belum disetujui; detail berisi jenis yang kurang. Pesan di room `support` dikecualikan (0062). <br>3) Karakter kontrol selain tab/LF/CR ditolak. <br>4) Maks `content.max_links` 3 tautan, `content.max_mentions` 10 mention, `content.max_stock_tags` 10 `$KODE` per konten (0014). <br>5) Kiriman ke-`content.duplicate_max` (3) dengan isi sama dalam `content.duplicate_window_seconds` (300 dtk) ditolak; teks < `content.duplicate_min_length` (10) tidak dicek. |
| Keluaran | Konten lolos ke pemeriksaan berikutnya atau ditolak. |
| Kode error | `403 user_muted`; `403 consent_required`; `422 invalid_characters`; `422 too_many_links`; `422 too_many_mentions`; `422 too_many_stock_tags`; `422 duplicate_content` |
| Antarmuka | Trigger `posts_25_integrity`, `comments_25_integrity`, `messages_25_integrity`; Library: layar persetujuan dokumen hukum muncul lalu aksi diulang (AKUN) |
| Lacak | BR-MOD |

#### FR-MOD-05 Penegakan kata terlarang

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyensor atau menolak konten yang memuat kata/frasa terlarang menurut aksi tiap kata. |
| Aktor | Sistem (`*_30_content_policy`) |
| Prakondisi | Daftar `public.banned_words` dikelola Kepatuhan (FR-PATUH-27). |
| Proses dan aturan | 1) Aksi per kata: `mask` (bagian cocok diganti `*` sepanjang kata) atau `block` (konten ditolak). <br>2) Cocok hanya kata utuh, tidak peka huruf besar/kecil. <br>3) Pencocokan dilakukan pada teks asli dan teks ternormalisasi (FR-MOD-06) memakai token kata dan n-gram, termasuk versi frasa tanpa spasi. <br>4) Kata yang hanya ditemukan lewat normalisasi disensor di posisi aslinya; bila posisi tidak bisa dipetakan, konten ditolak. <br>5) Berlaku juga untuk staf dan akun resmi; postingan resmi dicek sejak draf (0057). |
| Keluaran | Teks tersimpan dengan sensor, atau penolakan. |
| Kode error | `422 content_blocked` |
| Antarmuka | Fungsi `private.apply_content_policy` (0069); trigger `*_30_content_policy` |
| Lacak | BR-MOD |

#### FR-MOD-06 Normalisasi teks dan istilah pengecualian

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menormalkan teks sebelum mencocokkan kata terlarang dan frasa promosi agar penyamaran umum tertangkap tanpa mengubah teks saham yang wajar. |
| Aktor | Sistem (`private.normalize_for_policy`) |
| Prakondisi | — |
| Proses dan aturan | 1) NFKD + huruf kecil; karakter tak terlihat dan tanda aksen dibuang. <br>2) Homoglyph Cyrillic/Greek dipetakan ke Latin. <br>3) `$KODE` dan `@username` dibuang. <br>4) Huruf tunggal berpemisah konsisten disatukan (`b.o.k.e.p`, `b o k e p`). <br>5) Angka murni dibuang; angka yang menempel huruf diproses leet (`0→o 1→i 3→e 4→a 5→s 7→t $→s @→a`). <br>6) Huruf berulang diringkas. <br>7) Istilah pengecualian (`cs.policy_allowlist`) dibuang sebelum pencocokan. <br>8) Pola dibangun ulang otomatis saat daftar berubah (`private.rebuild_policy_patterns`, dengan advisory lock sejak 0176; dibangun ulang sekali di 0178). |
| Keluaran | Teks ternormalisasi untuk pencocokan; teks asli tidak berubah kecuali disensor. |
| Kode error | — |
| Antarmuka | Fungsi `private.normalize_for_policy`; hasilnya terlihat di Hub: Kepatuhan → Kebijakan konten → Uji teks (FR-PATUH-33) |
| Lacak | BR-MOD |

#### FR-MOD-07 Kategori tautan dan domain

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengenali tautan di teks dan menerapkan aksi kategori domain (judi, pornografi, phishing, diblokir, pemendek, messenger, tautan lain). |
| Aktor | Sistem (`*_31_safety`) |
| Prakondisi | Daftar `cs.blocked_domains` dan `cs.allowed_domains` dikelola Kepatuhan (FR-PATUH-25). |
| Proses dan aturan | 1) Ekstraksi domain menangkap tautan dengan/tanpa skema, `www.`, penyamaran `[dot]`, `(.)`, ` dot `, titik fullwidth, dan subdomain; domain tanpa skema hanya untuk TLD umum atau domain terdaftar (`BBCA.JK` tidak dianggap tautan). <br>2) Domain tepercaya (seed idx.co.id, ojk.go.id, ksei.co.id, kpei.co.id, bi.go.id) selalu lolos dan tidak dihitung tautan untuk akun baru. <br>3) Domain dapat dicocokkan per domain atau kata kunci domain (mis. `togel`, `gacor`, `slot88`, `bokep`). <br>4) Aksi default: `gambling`, `porn`, `phishing`, `blocked` = block (cakupan all); `shortener`, `messenger` = hold (public); `other_link` = allow (public) (0069). <br>5) Aksi `censor` mengganti tautan dengan `[tautan disensor]`; bila penggantian gagal, aksi naik ke `hold`. |
| Keluaran | Hasil `allow`/`censor`/`hold`/`block` beserta kategori. |
| Kode error | `422 link_blocked` ("Tautan ini tidak diizinkan."); `422 contact_blocked` untuk kategori messenger |
| Antarmuka | Fungsi `private.extract_hosts`, `private.host_rule`, `private.evaluate_content` |
| Lacak | BR-MOD |

#### FR-MOD-08 Deteksi nomor kontak

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mendeteksi nomor HP Indonesia di teks dan menerapkan aksi kategori `phone`. |
| Aktor | Sistem (`*_31_safety`) |
| Prakondisi | — |
| Proses dan aturan | 1) Pola `+62`/`62`/`08` dengan spasi, titik, strip, atau kurung, pada teks asli dan bentuk NFKC (`private.policy_phone_pattern`). <br>2) Aksi default `hold`, cakupan `public` (0069). <br>3) Aksi `censor` mengganti nomor dengan `[nomor disensor]`; bila penggantian gagal, aksi naik ke `hold`. |
| Keluaran | Konten ditahan, disensor, atau ditolak sesuai aturan. |
| Kode error | `422 contact_blocked` ("Nomor kontak atau tautan grup chat tidak boleh dibagikan di sini.") |
| Antarmuka | Fungsi `private.evaluate_content` |
| Lacak | BR-MOD |

#### FR-MOD-09 Frasa promosi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mendeteksi frasa promosi berbayar (mis. `grup vip`, `sinyal berbayar`) dan menerapkan aksi kategori `promotion`. |
| Aktor | Sistem (`*_31_safety`) |
| Prakondisi | Daftar `cs.promo_phrases` dikelola Kepatuhan (FR-PATUH-26). |
| Proses dan aturan | 1) Pencocokan n-gram pada teks asli (setelah istilah pengecualian dibuang) dan teks ternormalisasi. <br>2) Aksi default `block`, cakupan `all` (0069). <br>3) Aksi `censor` mengganti frasa dengan `*` bila frasa cocok di teks asli; bila hanya cocok lewat normalisasi, aksi naik ke `hold`. |
| Keluaran | Konten ditolak, disensor, atau ditahan. |
| Kode error | `422 content_blocked` |
| Antarmuka | Fungsi `private.evaluate_content` |
| Lacak | BR-MOD |

#### FR-MOD-10 Penggabungan aksi dan cakupan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menggabungkan hasil semua kategori menjadi satu aksi terketat dan menerapkan cakupan per permukaan. |
| Aktor | Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) Tingkat aksi: `allow` < `censor` < `hold` < `block`; aksi akhir = tingkat tertinggi. <br>2) Cakupan `public` = postingan, komentar, pesan room saham; `all` = juga DM dan grup. Kategori bercakupan `public` dianggap `allow` di DM/grup. <br>3) Di DM/grup, `hold` dinaikkan menjadi `block` agar pesan pribadi tidak ditahan diam-diam (0069). <br>4) Penolakan dipetakan: kategori `phone`/`messenger` → `contact_blocked`; kategori tautan → `link_blocked`; lainnya → `content_blocked`. <br>5) Konten `hold` tidak menghasilkan error: tersimpan `moderation_status = 'held'` dan ditandai di `private.content_flags` (sumber `policy`). |
| Keluaran | Baris tersimpan (dengan teks tersensor/status `held`) atau error. |
| Kode error | `422 content_blocked`; `422 link_blocked`; `422 contact_blocked` |
| Antarmuka | Fungsi `private.enforce_content_safety` |
| Lacak | BR-MOD |

#### FR-MOD-11 Pembatasan akun baru

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi akun baru selama `safety.new_account_days` hari sejak daftar atau bergabung lagi. |
| Aktor | Sistem |
| Prakondisi | Penulis bukan staf/akun resmi. |
| Proses dan aturan | 1) Akun baru = `trust_level` ≤ 1 dan waktu terbaru antara `profiles.created_at` (khusus trust 0) dan `private.account_signups.signed_up_at` masih dalam `safety.new_account_days` hari (bawaan 3). Trust ≥ 2 tidak pernah baru; nilai 0 berarti tanpa batasan (0187). <br>2) INSERT berlampiran gambar di bucket `attachments` (termasuk kartu bergambar seperti Share P/L) ditolak. <br>3) Konten bertautan selain domain tepercaya ditolak. <br>4) DM ke non-mutual selalu lewat permintaan pesan (CHAT). <br>5) Rate limit dikali `rate_limit.new_account_factor` (0,5). <br>6) Job `olt-promote-new-accounts` (tiap 15 menit) menaikkan trust 0 → 1 setelah masa yang sama, kecuali akun dengan mute/ban aktif. <br>7) Pengaturan diubah Kepatuhan (FR-PATUH-29). |
| Keluaran | Penolakan dengan detail jenis pembatasan. |
| Kode error | `403 new_account_restricted` (detail `image` atau `link`) |
| Antarmuka | Fungsi `private.is_new_account`, `private.rate_limit_factor`, `private.promote_new_accounts` |
| Lacak | BR-MOD |

#### FR-MOD-12 Perlakuan konten ditahan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyembunyikan konten berstatus `held` dari semua orang selain penulisnya dan menahan efek sampingnya sampai diputus moderator. |
| Aktor | Sistem |
| Prakondisi | Konten berstatus `held` (kebijakan konten, deteksi manipulasi, atau staf). |
| Proses dan aturan | 1) RLS hanya menampilkan konten `held`/`hidden` kepada penulisnya (0013). <br>2) Notifikasi balasan, mention, dan pesan untuk konten yang tidak `visible` tidak dibuat (`notifications_31_hidden_content`). <br>3) Cuplikan room tidak memakai pesan yang tidak `visible` (`chat_rooms_31_visible_preview`). <br>4) Link preview tidak dibuat. <br>5) Notifikasi tidak dikirim ulang setelah konten diloloskan. <br>6) Baris milik penulis membawa `moderation_status` sehingga klien menampilkan "Menunggu tinjauan" (0083). |
| Keluaran | Konten hanya terlihat oleh penulis dan moderator. |
| Kode error | — |
| Antarmuka | Library: label "Menunggu tinjauan" pada konten sendiri (`ModerationStatus`, `moderation_notice`) |
| Lacak | BR-MOD |

#### FR-MOD-13 Antrean konten ditahan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan antrean konten ditahan beserta alasan dan memungkinkan moderator meloloskan, menyembunyikan, atau menghapusnya. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Ada konten `held` yang belum dihapus. |
| Proses dan aturan | 1) `community_held_content(p_limit)` (bawaan 100, maks 500) memuat postingan, komentar, dan pesan non-CS, urut dari yang terlama, dengan cuplikan 280 karakter, jumlah lampiran, kode saham room, kategori, sumber (`policy`, `manipulation`, atau `staff`), `alert_id`, dan profil penulis (trust, akun baru) (0069). <br>2) Putusan memakai `community_resolve_report` (FR-MOD-19) dengan aksi `approve`, `hide`, atau `remove`. |
| Keluaran | Daftar konten ditahan; setelah diputus, konten tampil, tersembunyi, atau terhapus. |
| Kode error | `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_held_content`; Hub: Komunitas → Moderasi → Konten ditahan (Loloskan, Sembunyikan, Hapus) |
| Lacak | BR-MOD |

#### FR-MOD-14 Moderasi gambar NSFW saat upload

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengklasifikasi setiap gambar yang diunggah nasabah dan menolak, menahan, atau mengizinkannya berdasarkan ambang dari database. |
| Aktor | Layanan media, layanan classifier |
| Prakondisi | Upload lewat `POST /media/v1/object/{bucket}/{path}`; ambang sudah termuat. |
| Proses dan aturan | 1) Gambar hasil sanitasi dikirim ke classifier `POST /classify`; skor kategori `drawings`, `hentai`, `neutral`, `porn`, `sexy` = maksimum dari semua tampilan/frame (services/classifier/README.md). <br>2) Untuk setiap kategori berambang: skor ≥ `block` → blokir; skor ≥ `hold` → tahan; selain itu izinkan; kategori tercatat = skor tertinggi. <br>3) Tahan: `public.media_hold` mencatat `private.media_reviews` sebelum objek diunggah; respons memuat `"held": true`; objek `pending` hanya terbaca pengunggah dan moderator (`private.media_visible`) (0079). <br>4) Fail closed: classifier mati/timeout/sibuk → 503; ambang belum termuat → 503. <br>5) Thumbnail video diperiksa sama; video ditolak bila thumbnail ditahan/diblokir. PDF dan dokumen tidak diperiksa classifier. <br>6) Ambang diatur Kepatuhan (FR-PATUH-31). |
| Keluaran | Objek tersimpan (biasa atau ditahan) atau upload ditolak tanpa menyimpan apa pun. |
| Kode error | `422 image_blocked`; `503 classifier_unavailable`; `503 moderation_unavailable`; `422 invalid_image` |
| Antarmuka | Endpoint media `POST /media/v1/object/...`; RPC `public.media_moderation_config`, `public.media_hold`, `public.media_hold_cancel`; Library: label "sedang ditinjau" pada gambar ditahan |
| Lacak | BR-MOD |

#### FR-MOD-15 Avatar NSFW

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak avatar yang skornya mencapai ambang tahan karena bucket `avatars` publik tidak bisa menyembunyikan objek. |
| Aktor | Layanan media |
| Prakondisi | Upload ke bucket `avatars`. |
| Proses dan aturan | 1) Skor ≥ ambang `hold` atau `block` → ditolak (services/media/README.md). <br>2) `public.media_hold` menolak bucket selain lampiran (`bucket_not_holdable`) (0079). |
| Keluaran | Avatar tidak tersimpan. |
| Kode error | `422 image_blocked` |
| Antarmuka | Endpoint media; Library: edit profil (AKUN) |
| Lacak | BR-MOD |

#### FR-MOD-16 Antrean gambar ditahan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan gambar yang ditahan dan memungkinkan moderator meloloskan atau menghapusnya. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Ada baris `private.media_reviews`. |
| Proses dan aturan | 1) `community_media_reviews(p_status, p_cursor, p_limit)`, status `pending`/`approved`/`removed`; `pending` urut dari terlama, lainnya terbaru; item memuat path, skor, pengunggah, dan konten yang memakai gambar (`used_in`) (0079). <br>2) Hub menampilkan gambar buram; staf klik "Tampilkan" bila perlu. <br>3) `community_media_review_decide(p_id, 'approve'/'remove', p_note)`; catatan maks 500, alasan 5–500 wajib untuk `remove`. <br>4) Hapus: lampiran dilepas dari `posts.attachments` dan `messages.attachments` (non-CS), objek langsung tidak terbaca, folder masuk `private.storage_cleanup_queue` untuk janitor (OPS), dan bukti `media_removed` direkam (0095). <br>5) Job `media-reviews-purge` harian 03:53 UTC membersihkan baris lama. |
| Keluaran | Gambar tampil normal atau dihapus; audit `community.media_approve`/`community.media_remove`. |
| Kode error | `400 invalid_decision`; `400 invalid_note`; `400 reason_required`; `404 media_review_not_found`; `409 media_review_decided`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_media_reviews`, `cs_api.community_media_review_decide`; Hub: Komunitas → Moderasi → Gambar ditahan |
| Lacak | BR-MOD |

#### FR-MOD-17 Gambar pratinjau link NSFW

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengklasifikasi gambar pratinjau link (og:image) sebelum disimpan, memakai ambang yang sama dengan upload media. |
| Aktor | Layanan link-preview, layanan classifier |
| Prakondisi | Link dari postingan, komentar, atau chat yang tidak ditahan (layanan link-preview milik OPS). |
| Proses dan aturan | 1) `allow` → gambar disimpan dan tampil; `block` atau `unreadable` → gambar dibuang, judul/deskripsi tetap; `hold` → gambar tidak ditampilkan dan tidak masuk antrean tinjauan (0094). <br>2) `unavailable` (classifier/ambang tidak tersedia) → fail closed: pratinjau tanpa gambar, dicoba lagi sampai `link_preview.max_attempts` (3); pratinjau tanpa gambar di-cache `link_preview.failed_cache_hours` (24 jam) (0080). <br>3) Verdict, kategori, skor, revisi ambang, dan SHA-256 dicatat di `public.link_previews`; skor di-cache per SHA-256, keputusan dihitung ulang dengan ambang terbaru. <br>4) Constraint menolak `image_path` tanpa verdict `allow`. |
| Keluaran | Pratinjau dengan atau tanpa gambar. |
| Kode error | — |
| Antarmuka | Layanan `link-preview` 0.2.0; tabel `public.link_previews` |
| Lacak | BR-MOD |

#### FR-MOD-18 Antrean laporan berprioritas

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan antrean laporan yang dikelompokkan per target dan diurutkan menurut prioritas. |
| Aktor | Staf dengan izin `community.moderate` atau `community.sanction` |
| Prakondisi | — |
| Proses dan aturan | 1) `community_reports(p_status, p_limit)`, status `open` (termasuk `reviewing`), `resolved`, atau `dismissed`; bawaan 100 baris, dibatasi 1–200 oleh `private.report_queue_rows` (0057). <br>2) Prioritas = jumlah `(1 + trust pelapor) × bobot alasan` (`scam`/`pump_and_dump` 2,0; `abuse` 1,5; lainnya 1,0) dibagi `(1 + umur laporan terakhir dalam hari)`, dibulatkan 2 desimal. <br>3) Setiap baris memuat jumlah laporan, alasan, waktu pertama/terakhir, penulis (nama, akun resmi atau bukan), cuplikan 280 karakter, dan status target (`visible`/`held`/`hidden`/`removed`). |
| Keluaran | Daftar target terlapor. |
| Kode error | `400 invalid_status`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_reports`; Hub: Komunitas → Moderasi → Laporan |
| Lacak | BR-MOD |

#### FR-MOD-19 Keputusan moderasi konten

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan moderator menyembunyikan, menghapus, memulihkan, meloloskan, atau mengabaikan target laporan atau konten ditahan, dengan alasan wajib. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Target ada. |
| Proses dan aturan | 1) `community_resolve_report(p_target_type, p_target_id, p_action, p_reason)`; aksi `remove`/`hide`/`approve`/`restore`/`dismiss`; alasan 5–500 karakter (0057). <br>2) `remove`: isi diarsipkan ke `private.content_archive` (alasan `moderator_remove`), lalu `body` dikosongkan, lampiran dilepas, `deleted_at` diisi. <br>3) `hide` → `moderation_status = 'hidden'`; `approve`/`restore` → `visible`. <br>4) Target `user` hanya bisa `dismiss`; tindakan terhadap akun lewat sanksi (FR-MOD-24). <br>5) Semua laporan terbuka atas target itu menjadi `resolved` (atau `dismissed`) dengan catatan. <br>6) Penulis menerima notifikasi `moderation` (`state` `hidden`/`removed`, `appealable`) tanpa identitas moderator; tidak untuk penahanan otomatis, konten staf/akun resmi, chat CS, atau toleransi nol (0087). <br>7) Penghapusan merekam bukti `moderator_remove` (0095). |
| Keluaran | Status konten berubah; audit `community.report_resolve`. |
| Kode error | `400 reason_required`; `400 invalid_action`; `400 invalid_target`; `400 use_sanctions`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_resolve_report`; Hub: Komunitas → Moderasi (Sembunyikan, Hapus, Pulihkan, Setujui, Abaikan) |
| Lacak | BR-MOD |

#### FR-MOD-20 Membuka konten untuk ditinjau dan aturan pesan privat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampilkan isi lengkap konten kepada moderator, dan hanya membuka pesan DM/grup bila pesan itu dilaporkan, ditandai sistem, atau tidak tampil. |
| Aktor | Staf dengan izin `community.moderate` atau `community.sanction` |
| Prakondisi | — |
| Proses dan aturan | 1) `community_content(p_type, p_id)` untuk `post`/`comment`/`message`; pesan CS tidak pernah dikembalikan (0084). <br>2) Pesan di room `direct`/`group` hanya bisa dibuka bila ada laporan, ada `private.content_flags`, atau `moderation_status <> 'visible'`. <br>3) Setiap pembukaan pesan privat dicatat audit `community.private_message_view`. <br>4) `community_content_meta(p_targets)` mengembalikan metadata maks 200 target. |
| Keluaran | Isi, lampiran, status, room, dan penulis konten. |
| Kode error | `403 private_message_forbidden`; `404 content_not_found`; `400 invalid_target_type`; `400 invalid_targets` |
| Antarmuka | RPC `cs_api.community_content`, `cs_api.community_content_meta`; Hub: panel konten di Komunitas → Moderasi |
| Lacak | BR-MOD |

#### FR-MOD-21 Riwayat edit untuk moderator

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan moderator membaca versi lama postingan, komentar, dan pesan yang diedit, dengan aturan pesan privat yang sama seperti membuka isi pesan. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Konten pernah diedit (edit oleh pengguna diatur di KOM dan CHAT). |
| Proses dan aturan | 1) `community_edit_history(p_target_type, p_target_id)` → `[{body, edited_at, edited_by}]` urut waktu dari `private.content_edits` (0075, 0156). <br>2) Pesan CS ditolak; pesan DM/grup yang tidak dilaporkan, tidak ditandai, dan tidak dimoderasi ditolak. <br>3) Setiap pembukaan riwayat pesan privat dicatat audit `community.private_message_edits_view` (0156). <br>4) Riwayat edit disimpan sebagai arsip regulator, retensi `retention.archive_days` (1825 hari), mendukung `legal_hold`; dibersihkan job `social-content-edits-retention` (OPS). |
| Keluaran | Daftar versi lama. |
| Kode error | `400 invalid_target`; `404 content_not_found`; `403 private_message_forbidden`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_edit_history`; Hub: komponen riwayat edit di panel konten |
| Lacak | BR-MOD |

#### FR-MOD-22 Konten termoderasi milik pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberi pengguna daftar kontennya yang disembunyikan atau dihapus moderator beserta status bandingnya. |
| Aktor | Nasabah |
| Prakondisi | Login sosial. |
| Proses dan aturan | 1) `get_my_moderated_content(p_limit)` (bawaan 50, maks 100) memuat postingan/komentar/pesan non-CS berstatus `hidden` dan konten yang dihapus moderator (arsip `moderator_remove`) dalam 90 hari terakhir, urut terbaru (0085). <br>2) Tiap item memuat cuplikan 280 karakter, waktu keputusan, dan banding terakhir bila ada. <br>3) Konten `hidden` milik sendiri tetap tampil bagi penulis dengan label "Disembunyikan moderator". |
| Keluaran | Daftar konten termoderasi. |
| Kode error | `401 not_authenticated` |
| Antarmuka | RPC `get_my_moderated_content`; Library: `openCommunityAppeals` ("Banding saya"), `AppealRepository` |
| Lacak | BR-MOD |

#### FR-MOD-23 Detail pengguna untuk moderator

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan moderator mencari pengguna dan melihat ringkasan aktivitas serta riwayat sanksinya. |
| Aktor | Staf dengan izin `community.moderate`, `community.sanction`, atau `community.accounts` |
| Prakondisi | — |
| Proses dan aturan | 1) `community_find_users(p_query)` dengan kata kunci 2–60 karakter (0057). <br>2) `community_user(p_user_id)` mengembalikan profil + bio, jumlah postingan, komentar, laporan terhadap pengguna dan kontennya, laporan yang dibuat, 10 postingan dan 10 komentar terbaru (cuplikan 280), serta riwayat sanksi lengkap dengan status aktif. <br>3) Akun staf CS tidak bisa dibuka. |
| Keluaran | Detail pengguna. |
| Kode error | `400 invalid_query`; `404 user_not_found`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_find_users`, `cs_api.community_user`; Hub: Komunitas → Moderasi → Cari pengguna → Detail pengguna |
| Lacak | BR-MOD |

#### FR-MOD-24 Sanksi bertingkat dan manual

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf memberi sanksi peringatan, bisu, atau blokir, baik otomatis mengikuti tangga sanksi maupun dipilih manual. |
| Aktor | Staf dengan izin `community.sanction` |
| Prakondisi | Target bukan akun staf CS atau akun resmi. |
| Proses dan aturan | 1) `community_sanction_user(p_user_id, p_reason, p_kind, p_duration_hours)`; alasan 5–500 karakter; durasi > 0 sampai 8.760 jam (365 hari) (0057). <br>2) Tanpa `p_kind`, tangga `moderation.sanction_ladder` dipakai: langkah ke-n untuk sanksi ke-n yang belum dicabut (termasuk yang sudah berakhir): peringatan → bisu 1 jam → bisu 24 jam → blokir 7 hari → blokir permanen; langkah terakhir berulang (0013). <br>3) Pilihan Hub: tangga, peringatan, bisu 24 jam, bisu 7 hari, blokir 7 hari, blokir permanen. <br>4) Peringatan tidak berdurasi; durasi kosong = permanen. <br>5) Blokir (`ban`) langsung mencabut semua sesi. <br>6) Moderator room yang disanksi otomatis dicopot (FR-MOD-35). |
| Keluaran | Baris `private.user_sanctions` kategori `community`; audit `community.sanction`; detail pengguna terbaru. |
| Kode error | `400 reason_required`; `400 invalid_duration`; `400 invalid_kind`; `400 protected_account`; `404 user_not_found`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_sanction_user`; Hub: Detail pengguna → Beri sanksi |
| Lacak | BR-MOD |

#### FR-MOD-25 Penegakan sanksi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menegakkan sanksi aktif di setiap request: akun dibisukan tidak bisa membuat konten, akun diblokir tidak bisa memakai fitur sosial selain banding. |
| Aktor | Sistem (pre-request PostgREST, trigger) |
| Prakondisi | Sanksi aktif: belum dicabut, sudah mulai, dan belum berakhir. |
| Proses dan aturan | 1) `mute` atau `ban` aktif → INSERT postingan/komentar/pesan ditolak (FR-MOD-04). <br>2) `ban` aktif → semua request skema `public` ditolak oleh `private.check_request`, kecuali `/rpc/create_appeal`, `/rpc/get_my_appeals`, dan `/rpc/get_my_sanctions` (0071, 0177). <br>3) JWT dengan `iat` sebelum `private.user_sessions.revoked_before` ditolak. <br>4) Akun diblokir juga tidak bisa bergabung ke channel privat Realtime atau upload (0013). <br>5) `get_my_sanctions()` mengembalikan sanksi aktif milik sendiri agar klien bisa menjelaskan pembatasan. |
| Keluaran | Penolakan dengan kode yang menjelaskan sebabnya. |
| Kode error | `403 user_muted`; `403 user_banned`; `401 session_revoked` |
| Antarmuka | Pre-request `private.check_request`; RPC `get_my_sanctions`; Library: `AppealRepository` (sanksi aktif di "Banding saya") |
| Lacak | BR-MOD |

#### FR-MOD-26 Cabut sanksi dan cabut sesi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf mencabut sanksi yang keliru dan memaksa pengguna keluar dari semua perangkat. |
| Aktor | Staf dengan izin `community.sanction` |
| Prakondisi | Sanksi aktif ada (untuk cabut sanksi); target bukan staf/akun resmi (untuk cabut sesi). |
| Proses dan aturan | 1) `community_revoke_sanction(p_sanction_id, p_reason)`, alasan 5–500 karakter; mengisi `revoked_at`, `revoked_by`, `revoke_reason` (0057). <br>2) `community_revoke_sessions(p_user_id, p_reason)`, alasan 5–500; `private.revoke_sessions` menolak semua JWT yang terbit sebelum saat itu (dibulatkan ke detik). |
| Keluaran | Audit `community.sanction_revoke` atau `community.sessions_revoke`; detail pengguna terbaru. |
| Kode error | `400 reason_required`; `404 not_found`; `400 protected_account`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_revoke_sanction`, `cs_api.community_revoke_sessions`; Hub: Detail pengguna → Cabut, Keluarkan dari semua perangkat |
| Lacak | BR-MOD |

#### FR-MOD-27 Pengajuan banding

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan pengguna membanding sanksinya atau kontennya yang disembunyikan/dihapus moderator, satu kali per target, dalam batas waktu. |
| Aktor | Nasabah (termasuk yang sedang diblokir) |
| Prakondisi | Target milik pengguna. |
| Proses dan aturan | 1) `create_appeal(p_target_type, p_target_id, p_reason)`, jenis `sanction`/`post`/`comment`/`message` (non-CS), alasan 10–1.000 karakter (0071). <br>2) Target harus berstatus `active` (sanksi), `hidden`, atau `removed`; konten `held` tidak bisa dibanding karena sudah dalam antrean. <br>3) Maks `appeals.window_days` (30) hari sejak penindakan. <br>4) Satu banding per target (unique). <br>5) Sanksi kategori `zero_tolerance`, dan konten milik akun dengan sanksi toleransi nol aktif, tidak bisa dibanding. <br>6) Rate limit `appeal` 10 per hari. <br>7) `get_my_appeals()` mengembalikan maks 100 banding terbaru. |
| Keluaran | Banding status `pending` dengan `original_decider` dari keputusan awal. |
| Kode error | `400 invalid_target`; `400 invalid_reason`; `404 target_not_found`; `403 appeal_not_allowed`; `409 appeal_not_allowed`; `400 appeal_window_closed`; `409 appeal_exists`; `429 rate_limited` |
| Antarmuka | RPC `create_appeal`, `get_my_appeals`; Library: `showCommunityAppealDialog`, `openCommunityAppeals`, `CommunityAppeals` |
| Lacak | BR-MOD |

#### FR-MOD-28 Peninjauan banding

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan staf berwenang menerima atau menolak banding, dengan peninjau berbeda dari pemberi keputusan awal bila memungkinkan. |
| Aktor | Staf dengan izin `community.moderate` (banding konten) atau `community.sanction` (banding sanksi) |
| Prakondisi | Banding `pending`. |
| Proses dan aturan | 1) `community_appeals(p_status, p_limit)` status `pending`/`accepted`/`rejected`, bawaan 100, maks 500; `pending` urut terlama (0071). <br>2) `community_appeal_decide(p_id, p_accept, p_note)`, catatan 5–1.000 karakter, dikirim ke pengguna. <br>3) Pemberi keputusan awal ditolak bila ada staf aktif lain yang punya izin yang sama. <br>4) Diterima: sanksi dicabut ("Banding diterima: ..."), konten `hidden` tampil lagi, konten `removed` dipulihkan dari arsip. <br>5) Diterima atau ditolak → notifikasi tipe `appeal` ke pengguna (in-app + push). |
| Keluaran | Banding `accepted`/`rejected`; audit `community.appeal_decide`. |
| Kode error | `400 invalid_decision`; `400 note_required`; `404 appeal_not_found`; `409 appeal_decided`; `403 appeal_reviewer_conflict`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_appeals`, `cs_api.community_appeal_decide`; Hub: Komunitas → Moderasi → Banding (Terima, Tolak) |
| Lacak | BR-MOD |

#### FR-MOD-29 Toleransi nol (CSAM)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan tindakan toleransi nol yang memblokir akun permanen, mencabut semua sesi, dan menyembunyikan seluruh kontennya sebagai bukti tanpa bisa dibanding. |
| Aktor | Staf dengan izin `community.sanction` |
| Prakondisi | Target bukan akun staf/akun resmi. |
| Proses dan aturan | 1) `community_zero_tolerance(p_user_id, p_reason)`, alasan 5–500 karakter (0071). <br>2) Sanksi `ban` permanen kategori `zero_tolerance`; sesi dicabut. <br>3) Semua postingan, komentar, dan pesan non-CS akun menjadi `hidden` (bukan dihapus). <br>4) Sanksi dan konten tidak bisa dibanding (FR-MOD-27). <br>5) Bukti `zero_tolerance` direkam: profil + maks 500 postingan, 500 komentar, 500 pesan terbaru (0095). <br>6) Hub mewajibkan alasan faktual, centang pernyataan, dan mengetik username sebelum menerapkan. <br>7) Notifikasi moderasi tidak dikirim. <br>8) Kanal pelaporan ke pihak berwenang belum ditetapkan tim legal (perlu konfirmasi). |
| Keluaran | Audit `community.zero_tolerance` berisi jumlah konten yang disembunyikan; detail pengguna + `hidden {posts, comments, messages}`. |
| Kode error | `400 reason_required`; `400 protected_account`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_zero_tolerance`; Hub: Detail pengguna → Toleransi nol → Terapkan toleransi nol |
| Lacak | BR-MOD |

#### FR-MOD-30 Deteksi manipulasi saham

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mendeteksi indikasi manipulasi saham dari postingan yang menyebut `$KODE` dan membuat alert per saham per jenis. |
| Aktor | Sistem (job pg_cron `safety-manipulation`, tiap 5 menit) |
| Prakondisi | — |
| Proses dan aturan | 1) Mention = postingan dengan `$KODE` (komentar dan pesan room tidak dihitung) (0072). <br>2) `mention_spike`: mention 1 jam terakhir ≥ `manipulation.spike_min_mentions` (20) dan > `manipulation.spike_factor` (5) × rata-rata per jam selama `manipulation.baseline_days` (7). <br>3) `new_account_concentration`: mention ≥ `manipulation.new_account_min_mentions` (10) dan porsi dari akun < `manipulation.new_account_age_days` (7) hari atau trust 0 > `manipulation.new_account_share` (0,6). <br>4) `coordinated_posts`: postingan mirip (`pg_trgm` similarity ≥ `manipulation.similarity` 0,8) dari ≥ `manipulation.similar_min_authors` (5) penulis dalam `manipulation.similar_window_minutes` (30), maks 300 postingan terbaru per saham. <br>5) Satu alert terbuka per saham + jenis; deteksi ulang memperbarui bukti. |
| Keluaran | Baris `cs.manipulation_alerts` (`stock`, `kind`, `score`, `evidence`, `status`, `auto_actions`). |
| Kode error | — |
| Antarmuka | Fungsi `cs.detect_manipulation(p_at)` |
| Lacak | BR-MOD |

#### FR-MOD-31 Aksi otomatis alert manipulasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyalakan slow mode sementara di room saham yang terkena alert dan menahan postingan mirip terkoordinasi. |
| Aktor | Sistem |
| Prakondisi | Alert terbuat atau diperbarui. |
| Proses dan aturan | 1) Bila `manipulation.auto_slow_mode` aktif: jeda `manipulation.auto_slow_mode_seconds` (10 dtk) selama `manipulation.auto_slow_mode_minutes` (60 menit), dibatasi paling ketat sama dengan `rooms.busy_slow_mode` (10 dtk bila jam ramai dimatikan) (0110). <br>2) Slow mode manual dari moderator yang masih berlaku tidak ditimpa. <br>3) Bila `manipulation.auto_hold_similar` aktif: postingan `coordinated_posts` yang masih `visible` menjadi `held` dan ditandai `content_flags` sumber `manipulation` dengan `alert_id`. <br>4) Aksi dicatat di `auto_actions`; perubahan slow mode disiarkan `room_state`. |
| Keluaran | Slow mode alert dan postingan ditahan. |
| Kode error | — |
| Antarmuka | Fungsi `cs.manipulation_slow_mode`; pengaturan diatur Kepatuhan (FR-PATUH-32) |
| Lacak | BR-MOD |

#### FR-MOD-32 Tinjauan alert manipulasi

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan moderator meninjau alert manipulasi dan menandainya ditinjau atau menolaknya. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Alert berstatus `open`. |
| Proses dan aturan | 1) `community_manipulation_alerts(p_status, p_stock, p_limit)`, status `open`/`reviewed`/`dismissed`, bawaan 100, maks 500 (0072). <br>2) `community_manipulation_review(p_id, p_status, p_note)`, status `reviewed`/`dismissed`, catatan 5–500. <br>3) `reviewed`: aksi otomatis tetap berjalan. <br>4) `dismissed`: postingan yang ditahan otomatis oleh alert itu kembali `visible` dan slow mode dari alert dimatikan. |
| Keluaran | Alert diperbarui + `released_posts`; audit `community.manipulation_review`. |
| Kode error | `400 invalid_status`; `400 note_required`; `404 alert_not_found`; `409 alert_reviewed`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_manipulation_alerts`, `cs_api.community_manipulation_review`; Hub: Komunitas → Moderasi → Indikasi manipulasi (Tandai ditinjau, Tolak alert) |
| Lacak | BR-MOD |

#### FR-MOD-33 Slow mode room saham dari sisi staf

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan moderator mengatur slow mode room saham dan melihat slow mode efektif beserta sumbernya. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Kode saham/indeks valid. |
| Proses dan aturan | 1) `community_room_settings(p_code, p_slow_mode_seconds, p_until)`: 0–3.600 detik (0 = mati), `p_until` di masa depan maks 30 hari, kosong = permanen; room dibuat bila belum ada (0072). <br>2) Slow mode efektif = nilai terbesar dari pengaturan moderator, slow mode alert, dan `rooms.busy_slow_mode` (10 dtk) pada `rooms.busy_windows` WIB (`08:55–09:30`, `15:50–16:15`) di hari bursa. <br>3) Akun resmi tidak terkena. <br>4) `community_room_state(p_code)` menampilkan status, override, dan alert terbuka. <br>5) Perubahan disiarkan event `room_state` ke `room:<id>`. Sisi pengguna (penolakan `429 slow_mode`, `get_stock_room_state`) milik CHAT. |
| Keluaran | Audit `community.room_settings` dengan nilai sebelumnya. |
| Kode error | `400 invalid_slow_mode`; `400 invalid_until`; `404 room_not_found`; `400 invalid_stock_code` |
| Antarmuka | RPC `cs_api.community_room_state`, `cs_api.community_room_settings`, `cs_api.community_room_messages`; Hub: Komunitas → Room saham → Slow mode moderator |
| Lacak | BR-MOD |

#### FR-MOD-34 Pesan disematkan di room saham

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan moderator menyematkan atau melepas satu pesan per room saham. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Room bertipe `stock`. |
| Proses dan aturan | 1) `community_pin_message(p_room, p_message)`; `p_message` null = lepas sematan (0072). <br>2) Pesan harus milik room itu, belum dihapus, dan `visible`. <br>3) Satu room hanya punya satu sematan. <br>4) Disiarkan `room_state`; pengguna membacanya di `get_stock_room_state.pinned_message`. |
| Keluaran | Audit `community.room_pin` atau `community.room_unpin`. |
| Kode error | `404 room_not_found`; `400 invalid_message` |
| Antarmuka | RPC `cs_api.community_pin_message`; Hub: Komunitas → Room saham → Pesan disematkan (Pilih dari pesan terbaru, Sematkan dengan ID pesan, Lepas sematan) |
| Lacak | BR-MOD |

#### FR-MOD-35 Penunjukan dan pencopotan moderator room

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan staf menunjuk nasabah tepercaya menjadi moderator room saham dan mencopotnya, sesuai syarat yang bisa diatur. |
| Aktor | Staf dengan izin `community.moderate`; pengaturan oleh peran `compliance` atau `cs_super_admin` |
| Prakondisi | Kandidat memenuhi syarat. |
| Proses dan aturan | 1) Syarat bawaan (0093): `room_mods.min_trust_level` 2 (1–3), `room_mods.sanction_free_days` 90 (0–365; toleransi nol selalu menolak), `room_mods.max_per_room` 10 (1–50), `room_mods.max_rooms_per_user` 3 (1–20), `room_mods.max_mute_hours` 24 (1–24). <br>2) Akun staf, akun resmi, dan agen tidak bisa ditunjuk. <br>3) `community_room_moderator_candidates(p_code, p_query)` (2–60 karakter) menandai kelayakan dan masalah. <br>4) `community_appoint_room_moderator(p_code, p_user_id, p_note)`: room dibuat bila belum ada, nasabah otomatis anggota. <br>5) `community_remove_room_moderator(p_code, p_user_id, p_reason)`, alasan 5–500. <br>6) Moderator yang dikenai sanksi apa pun otomatis dicopot (`community.room_moderator_auto_remove`); trust yang turun menangguhkan hak. <br>7) `community_set_room_moderator_settings(p_values)` hanya untuk `compliance`/`cs_super_admin`. |
| Keluaran | Daftar moderator (`community_room_moderators`) dengan `problems`, `actions_7d`, `undone_7d`; audit di `cs.cs_audit_log`. |
| Kode error | `400 not_eligible`; `409 already_moderator`; `409 room_moderator_limit`; `409 user_moderator_limit`; `404 moderator_not_found`; `400 reason_required`; `400 invalid_setting`; `400 invalid_query` |
| Antarmuka | RPC `cs_api.community_room_moderators`, `cs_api.community_room_moderator_candidates`, `cs_api.community_appoint_room_moderator`, `cs_api.community_remove_room_moderator`, `cs_api.community_room_moderator_settings`, `cs_api.community_set_room_moderator_settings`; Hub: Komunitas → Room saham → Moderator room |
| Lacak | BR-MOD |

#### FR-MOD-36 Aksi moderator room oleh nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan moderator room menyembunyikan pesan, membisukan anggota sementara, dan mengeskalasi pesan ke staf, terbatas pada room yang ia moderasi. |
| Aktor | Nasabah yang ditunjuk moderator room |
| Prakondisi | Hak moderator aktif di room itu. |
| Proses dan aturan | 1) `room_mod_hide_message(p_message_id, p_reason, p_note)`: pesan menjadi `hidden`, pengirim menerima notifikasi `moderation` dan bisa banding; disiarkan `message_hidden` (0093). <br>2) `room_mod_mute_user(p_room_id, p_user_id, p_minutes, p_reason, p_note, p_message_id)`: 5 menit sampai `room_mods.max_mute_hours`; anggota yang dibisukan ditolak saat mengirim, tetap bisa membaca. <br>3) `room_mod_escalate(p_message_id, p_reason, p_note)`: membuat laporan berawalan `[Moderator room $KODE]`; tidak untuk pesan sendiri. <br>4) Alasan `spam`/`abuse`/`scam`/`pump_and_dump`/`misinformation`/`other`; catatan ≤ 500. <br>5) Tidak bisa menindak akun resmi, staf, atau moderator lain; tidak bisa melihat DM, mengubah sematan/slow mode, atau menghapus akun. <br>6) Rate limit `room_mod_action` 15/jam dan 50/hari, dikali faktor trust. |
| Keluaran | Baris aksi di `private.room_mod_actions` dengan hasil (`mute_until`, `report_id`). |
| Kode error | `403 not_room_moderator`; `403 room_moderator_suspended`; `403 protected_account`; `403 moderator_target`; `403 self_target`; `404 message_not_found`; `409 already_moderated`; `409 already_muted`; `409 already_escalated`; `400 invalid_mod_reason`; `400 invalid_note`; `400 invalid_duration`; `429 rate_limited`; `403 room_muted` |
| Antarmuka | RPC `room_mod_hide_message`, `room_mod_mute_user`, `room_mod_escalate`; Library: `ChatExtrasRepository.hideMessage/muteMember/escalateMessage`, `ChatRoomCubit`, `RoomModerationBanner`, `RoomModeratorBadge`, `CommunityRoomModerationDetails` |
| Lacak | BR-MOD |

#### FR-MOD-37 Privasi bisu room saham

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus merahasiakan siapa yang sedang dibisukan dari anggota room, sambil memberi tahu anggota yang dibisukan secara pribadi. |
| Aktor | Sistem |
| Prakondisi | Ada bisu moderator room. |
| Proses dan aturan | 1) Siaran `room_state` tidak pernah memuat `mutes`, `muted_until`, atau `is_moderator`; bisu dan cabut bisu tidak memicu siaran `room_state` (0096). <br>2) `get_stock_room_state` memuat `mutes` hanya untuk moderator room itu; anggota hanya menerima `muted_until` miliknya. <br>3) Anggota yang dibisukan menerima notifikasi `moderation` (`target_type: room`, `state: muted/unmuted`, `until`, `reason`, `appealable: false`) tanpa identitas moderator; in-app tidak bisa dimatikan, push mengikuti preferensi. <br>4) Bisu yang habis tidak dikirimi notifikasi. <br>5) Staf melihat daftar bisu di `community_room_state`. |
| Keluaran | Notifikasi pribadi; state room tanpa data bisu orang lain. |
| Kode error | `403 room_muted` (detail = batas waktu ISO UTC) |
| Antarmuka | RPC `get_stock_room_state`; Library: `StockRoomState.viewerMutedUntil`, `OwnRoomMuteChanged`, banner bisu di `CommunityChatRoom` |
| Lacak | BR-MOD |

#### FR-MOD-38 Log dan pembatalan aksi moderator room

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan log aksi moderator room dan memungkinkan staf membatalkan aksi yang keliru. |
| Aktor | Staf dengan izin `community.moderate` |
| Prakondisi | Ada aksi moderator room. |
| Proses dan aturan | 1) `community_room_moderator_actions(p_code, p_limit, p_before, p_before_id)` (bawaan 50; semua room bila `p_code` kosong) memuat cuplikan pesan, status laporan/banding, dan `can_undo` (0093). <br>2) `community_undo_room_moderator_action(p_id, p_note)`, catatan 5–500: memulihkan pesan tersembunyi (banding yang menunggu ikut diterima dan pengirim diberi tahu) atau mencabut bisu (notifikasi `unmuted`). <br>3) Eskalasi tidak bisa dibatalkan; diselesaikan dari antrean laporan. |
| Keluaran | Audit `community.room_moderator_undo`. |
| Kode error | `400 note_required`; `404 action_not_found`; `409 action_undone`; `400 undo_not_supported`; `409 nothing_to_undo` |
| Antarmuka | RPC `cs_api.community_room_moderator_actions`, `cs_api.community_undo_room_moderator_action`; Hub: Komunitas → Room saham → Log aksi moderator (Batalkan) |
| Lacak | BR-MOD |

#### FR-MOD-39 API admin moderasi (admin_api)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan skema `admin_api` untuk moderasi oleh akun admin terpisah berperan, dengan 2FA wajib dan audit yang tidak bisa diubah. |
| Aktor | Admin `viewer`, `room_moderator`, `moderator`, `compliance_admin`, `super_admin` |
| Prakondisi | Akun GoTrue terdaftar di `private.admin_users`, aktif, dan JWT berklaim `aal2`. |
| Proses dan aturan | 1) `viewer`: lihat antrean dan detail user tanpa data pribadi; `room_moderator`: tindak laporan pesan di room yang ditugaskan (`private.admin_room_scopes`); `moderator`: semua laporan, sanksi, cabut sesi; `compliance_admin`: + kata terlarang, trust, verifikasi, S&K, menunjuk moderator, audit, pengaturan; `super_admin`: + menunjuk admin, arsip regulator, legal hold (docs/panduan/produksi.md bagian 5). <br>2) Fungsi: `report_queue`, `resolve_target`, `sanction_user`, `revoke_sanction`, `revoke_user_sessions`, `user_detail` (email hanya untuk compliance/super, akses dicatat di `private.personal_data_access_log`), `set_trust_level` (0–3), `set_verified`, `upsert_banned_word`, `delete_banned_word`, `update_setting`, `archive`, `set_legal_hold`, `audit_log` (0013, 0057). <br>3) `private.admin_audit_log` hanya bisa ditambah; UPDATE/DELETE/TRUNCATE ditolak kecuali job retensi. <br>4) Logika keputusan sama dengan Hub (`private.resolve_report`, `private.apply_sanction`). |
| Keluaran | Hasil tindakan + baris audit admin. |
| Kode error | `403 admin_required`; `403 admin_forbidden`; `400 invalid_action`; `400 reason_required`; `400 use_sanctions`; `400 invalid_kind`; `404 user_not_found` |
| Antarmuka | RPC `admin_api.*`; panel admin web F1 (perlu konfirmasi: status F1 terhadap Hub) |
| Lacak | BR-MOD |

### 4.8 Kepatuhan (PATUH)

Modul PATUH melayani peran **Kepatuhan** (`compliance`) di Rendezvous Hub. Kepatuhan **mengawasi**, tidak menangani tiket: tidak mengambil, membalas, atau menyelesaikan tiket CS (docs/cs-chat/kepatuhan.md). Cakupannya: Ringkasan, register kasus pengaduan/penipuan, tinjauan, perpanjangan tenggat, transkrip bersidik SHA-256, Jejak Audit, kebijakan tenggat dan retensi, dokumen hukum dengan persetujuan empat mata, karantina bukti dengan legal hold, akses hanya-baca 12 jam ke tiket biasa (0125), serta pengelolaan kebijakan konten (versi, draf, simulasi, empat mata, pemulihan, ambang gambar, kata terlarang + import Excel, masa akun baru, jeda bergabung lagi). Penegakan kebijakan konten di aplikasi ada di modul MOD (4.7); penanganan tiket, penandaan pengaduan/penipuan, dan lapor CS palsu di CS; persetujuan dokumen hukum dari sisi nasabah dan efek jeda bergabung lagi di AKUN; 2FA staf, akun staf, dan saklar aturan persetujuan di HUB; sisi Kepatuhan Berbagi Trade (`/compliance/trade-share`) di TRADE (dijeda); job retensi dan janitor di OPS.

Semua RPC Kepatuhan memakai `cs.require_agent`: sesi dicabut `401 session_revoked`, 2FA belum lengkap `401 mfa_required`, bukan akun CS aktif `403 agent_required`, peran kurang `403 role_forbidden`. Semua aksi tercatat di `cs.cs_audit_log`.

#### FR-PATUH-01 Akses dan navigasi peran Kepatuhan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus membatasi menu dan RPC Kepatuhan untuk peran `compliance`, dengan akses hanya-baca terbatas bagi Super Admin pada fitur yang ditentukan. |
| Aktor | Staf Kepatuhan; Super Admin (`cs_super_admin`) |
| Prakondisi | Login staf Hub (HUB). |
| Proses dan aturan | 1) Menu: Ringkasan (`/compliance`), Kasus (`/compliance/cases`), Jejak Audit (`/compliance/audit`), Tenggat & retensi (`/compliance/policy`), Kebijakan konten (`/compliance/content`; alamat lama `/compliance/words` dialihkan), Dokumen hukum (`/compliance/legal`), Bukti (`/compliance/evidence`). <br>2) Akun yang hanya berperan Kepatuhan langsung diarahkan ke Ringkasan. <br>3) Super Admin hanya bisa membaca status kebijakan, notifikasi kasus, dan bukti (tanpa legal hold dan ekspor). <br>4) Kepatuhan tidak punya status kerja; login/keluar tidak mencatat `agent.status`. <br>5) Command palette (Ctrl K) berisi navigasi menu Kepatuhan. |
| Keluaran | Menu sesuai peran. |
| Kode error | `403 role_forbidden`; `403 agent_required`; `401 mfa_required` |
| Antarmuka | Hub: menu Kepatuhan, `src/features/compliance`, `src/features/content-policy`, `src/features/legal` |
| Lacak | BR-PATUH |

#### FR-PATUH-02 Ringkasan Kepatuhan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan ringkasan angka dan daftar kasus yang perlu perhatian Kepatuhan. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `compliance_overview()` menghitung dari tiket bertanda `complaint`/`fraud`: pengaduan aktif, jatuh tempo ≤ 1 hari kerja, lewat tenggat, ketepatan waktu 30 hari (`met`/total), penipuan aktif, laporan CS palsu 30 hari, permintaan data rahasia yang diblokir 30 hari (audit `message.secret_request_blocked`), kasus selesai belum ditinjau, dan jumlah kebijakan belum dikonfirmasi (0042). <br>2) Daftar: 8 tenggat terdekat, 8 penipuan aktif, 8 kasus selesai belum ditinjau. <br>3) Tabel maks 10 CS yang mencoba meminta PIN/OTP/password (30 hari). <br>4) Hub memuat ulang tiap 60 detik dan saat jendela kembali aktif. <br>5) Spanduk mengarah ke Tenggat & retensi bila ada kebijakan belum dikonfirmasi. |
| Keluaran | Objek ringkasan dengan `generated_at`. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.compliance_overview`; Hub: Kepatuhan → Ringkasan |
| Lacak | BR-PATUH |

#### FR-PATUH-03 Notifikasi kasus baru

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memberi tahu Kepatuhan dan Super Admin tentang kasus pengaduan atau penipuan baru, termasuk yang ditandai CS beserta alasannya. |
| Aktor | Staf Kepatuhan; Super Admin |
| Prakondisi | Tiket dibuat dengan flag `complaint`/`fraud` atau ditandai kemudian (penandaan milik CS). |
| Proses dan aturan | 1) Setiap flag baru menulis `cs.compliance_notices` (flag, alasan 1–300 karakter, sumber `agent`/`customer`/`system`) dan disiarkan event `case_flagged` di topik Realtime `cs:compliance` (0133). <br>2) `compliance_notices()` mengembalikan jumlah belum dilihat dan 30 item terbaru; `compliance_notices_seen()` menandai semuanya sudah dilihat per staf. <br>3) Hub memuat ulang daftar tiap 120 detik selain saat menerima siaran. |
| Keluaran | Ikon perisai di bilah atas dengan angka belum dilihat; daftar kasus yang bisa dibuka. |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.compliance_notices`, `cs_api.compliance_notices_seen`; Realtime `cs:compliance`; Hub: ikon perisai bilah atas |
| Lacak | BR-PATUH |

#### FR-PATUH-04 Register kasus

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan register pengaduan dan penipuan yang bisa disaring, dicari, dan diekspor. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `compliance_cases(p_kind, p_state, p_from, p_to, p_query)`; `p_kind` `all`/`complaint`/`fraud`, atau `tickets` untuk semua tiket (0125). <br>2) `p_state` `all`/`active`/`attention` (`overdue` atau `due_soon`)/`done`/`unreviewed`. <br>3) Periode menurut tanggal tiket dibuat (WIB), kedua tanggal wajib bila salah satu diisi, maks 366 hari. <br>4) Pencarian nomor tiket, nama, atau username nasabah. <br>5) Urutan: aktif dulu, tenggat terdekat, terbaru; maks 1.000 baris (`truncated`). <br>6) Hub: ekspor CSV untuk laporan berkala; angka merah di menu = pengaduan lewat tenggat atau jatuh tempo ≤ 1 hari kerja. |
| Keluaran | `{rows, total, truncated}`; tiap baris memuat status, prioritas, flag, topik, nasabah, agen, tenggat, hasil, rating, dan tinjauan terakhir. |
| Kode error | `400 invalid_kind`; `400 invalid_state`; `400 invalid_range` |
| Antarmuka | RPC `cs_api.compliance_cases`; Hub: Kepatuhan → Kasus (Jenis kasus, Keadaan, Periode tiket dibuat, Ekspor CSV) |
| Lacak | BR-PATUH |

#### FR-PATUH-05 Detail kasus

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan detail kasus pengaduan/penipuan berisi transkrip, riwayat kejadian, catatan internal, tinjauan, dan info perpanjangan, serta mencatat setiap pembukaan sebagai akses data nasabah. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Tiket bertanda `complaint` atau `fraud`. |
| Proses dan aturan | 1) `compliance_case(p_ticket_id)` mengembalikan baris kasus + ringkasan penyelesaian, alasan pengembalian, komentar rating, konteks, alasan perpanjangan, `extension_days`, `can_extend`, kejadian (`cs.session_events`), catatan internal, dan semua tinjauan (0125). <br>2) Pesan dibaca lewat `ticket_messages` (izin baca `cs.can_read_ticket`). <br>3) Setiap pembukaan dicatat audit `compliance.case_view`. <br>4) Kepatuhan tidak mengubah percakapan selain pesan sistem perpanjangan tenggat. |
| Keluaran | Panel detail dengan tab Transkrip, Riwayat, Tinjauan. |
| Kode error | `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.compliance_case`, `ticket_messages`; Hub: Kepatuhan → Kasus → panel kasus |
| Lacak | BR-PATUH |

#### FR-PATUH-06 Akses hanya-baca 12 jam ke tiket biasa

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan membuka tiket biasa (bukan pengaduan/penipuan) secara hanya-baca selama 12 jam sejak dibuka, dengan setiap pembukaan tercatat. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Tiket ada; Kepatuhan memilih Semua tiket di Kasus atau mengklik nomor tiket di Jejak Audit. |
| Proses dan aturan | 1) `compliance_case` untuk tiket non-kasus menyisipkan atau memperbarui `cs.compliance_ticket_access (agent_id, ticket_id, opened_at)` dan menghapus akses milik staf itu yang berumur > 12 jam (0125). <br>2) Selama `opened_at` > now − 12 jam, `cs.can_read_room`, `cs.can_read_ticket`, dan `cs.can_read_notes` mengizinkan Kepatuhan membaca chat, catatan internal, dan lampiran tiket itu. <br>3) Setiap pembukaan dicatat audit `compliance.ticket_view` (label Hub "Buka tiket biasa"); membuka ulang memperpanjang jendela 12 jam. <br>4) Tiket biasa hanya menampilkan tab Transkrip dan Riwayat; tinjauan dan perpanjangan tenggat ditolak. <br>5) Unduh transkrip tetap boleh selama akses berlaku. |
| Keluaran | Detail tiket hanya-baca. |
| Kode error | `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.compliance_case`, `cs_api.compliance_cases` (`p_kind = 'tickets'`); Hub: Kepatuhan → Kasus → Semua tiket; Jejak Audit → nomor tiket |
| Lacak | BR-PATUH |

#### FR-PATUH-07 Status tenggat pengaduan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghitung status tenggat setiap pengaduan dalam hari kerja WIB. |
| Aktor | Sistem |
| Prakondisi | Tiket punya `complaint_due_at`. |
| Proses dan aturan | 1) `cs.complaint_deadline(t)` (0042): `running` sisa > 1 hari kerja; `due_soon` jatuh tempo hari ini atau hari kerja berikutnya; `overdue` aktif dan lewat tenggat; `met` selesai (diselesaikan, atau ditutup bila tidak pernah diselesaikan) sebelum tenggat; `missed` selesai setelah tenggat. <br>2) Jumlah hari kerja dihitung dengan kalender hari kerja yang sama dengan tenggat (`cs.business_days_between`). |
| Keluaran | `{state, business_days}` di setiap baris kasus. |
| Kode error | — |
| Antarmuka | Hub: lencana Berjalan, Segera jatuh tempo, Lewat tenggat, Tepat waktu, Terlambat |
| Lacak | BR-PATUH |

#### FR-PATUH-08 Tinjauan kepatuhan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan menambah tinjauan pada kasus, tersimpan append-only, dengan tinjauan terbaru menjadi status kasus. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Tiket bertanda `complaint`/`fraud`. |
| Proses dan aturan | 1) `compliance_review(p_ticket_id, p_verdict, p_note)`; putusan `compliant` (Sesuai), `needs_action` (Perlu tindak lanjut), `violation` (Pelanggaran); catatan 5–1.000 karakter (0042). <br>2) `cs.compliance_reviews` menolak UPDATE, DELETE, dan TRUNCATE. <br>3) Tiket biasa tidak bisa ditinjau. |
| Keluaran | Baris tinjauan; audit `compliance.review`. |
| Kode error | `400 invalid_verdict`; `400 invalid_note`; `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.compliance_review`; Hub: panel kasus → Tinjauan baru → Simpan tinjauan |
| Lacak | BR-PATUH |

#### FR-PATUH-09 Perpanjangan tenggat pengaduan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan memperpanjang tenggat pengaduan aktif satu kali sebelum tenggat lewat dan memberi tahu nasabah tenggat barunya. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Tiket `complaint` berstatus `open`/`claimed`/`waiting_customer`, belum pernah diperpanjang. |
| Proses dan aturan | 1) `compliance_extend_deadline(p_ticket_id, p_reason, p_version)`; alasan 10–500 karakter (internal) (0042). <br>2) Tenggat baru = tenggat lama + `complaint.extension_days` hari kerja (bawaan 10; 0 = perpanjangan dimatikan). <br>3) Ditolak bila tenggat sudah lewat. <br>4) Optimistic lock lewat `p_version`. <br>5) Nasabah menerima pesan sistem `messages.complaint_extended` berisi tenggat baru; alasan tidak dikirim ke nasabah. <br>6) Kejadian `complaint_extended` dicatat dan tiket disiarkan `ticket_updated`. |
| Keluaran | Baris kasus terbaru; audit `compliance.deadline_extended` (dari, ke, hari). |
| Kode error | `400 invalid_reason`; `404 ticket_not_found`; `409 not_complaint`; `409 ticket_not_active`; `409 already_extended`; `409 extension_disabled`; `409 deadline_passed` |
| Antarmuka | RPC `cs_api.compliance_extend_deadline`; Hub: panel kasus → Perpanjang tenggat (Alasan perpanjangan) |
| Lacak | BR-PATUH |

#### FR-PATUH-10 Transkrip bersidik SHA-256

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus membuat transkrip teks tiket di browser dan sistem harus mencatat sidik SHA-256-nya saat diunduh agar salinan bisa dicocokkan kemudian. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Tiket kasus, atau tiket biasa yang aksesnya masih berlaku (FR-PATUH-06). |
| Proses dan aturan | 1) Hub membentuk file teks UTF-8 berisi identitas tiket, pesan, dan catatan internal, lalu menghitung SHA-256 di browser (tanpa server PDF). <br>2) `compliance_transcript_exported(p_ticket_id, p_sha256, p_messages)`; sidik wajib 64 karakter hex huruf kecil (0042, 0125). <br>3) Jumlah pesan negatif dicatat 0. |
| Keluaran | `{ticket_id, sha256, exported_at}`; audit `compliance.transcript_export` (sidik + jumlah pesan). |
| Kode error | `400 invalid_hash`; `404 ticket_not_found` |
| Antarmuka | RPC `cs_api.compliance_transcript_exported`; Hub: panel kasus → Unduh transkrip |
| Lacak | BR-PATUH |

#### FR-PATUH-11 Jejak Audit

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan audit log CS yang append-only dengan filter, pencarian, halaman bertahap, dan ekspor CSV. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `compliance_audit(p_from, p_to, p_action, p_query, p_before_at, p_before_id, p_limit)`; periode wajib, maks 366 hari (WIB); bawaan 100, maks 200 baris per halaman (0042). <br>2) Keyset `(created_at, id)`; kedua penanda wajib diisi bersama. <br>3) Pencarian pada aksi, nama/kode CS, nama/username nasabah, nomor tiket. <br>4) Halaman pertama juga mengembalikan daftar aksi + jumlahnya untuk filter. <br>5) `cs.cs_audit_log` menolak UPDATE, DELETE, dan TRUNCATE (0028). <br>6) Hub: periode Hari ini / 7 hari / 30 hari; klik nomor tiket membuka kasus atau tiket biasa hanya-baca. |
| Keluaran | `{rows, next, actions}`; tiap baris memuat pelaku, peran, tiket, nasabah, dan detail. |
| Kode error | `400 invalid_range`; `400 invalid_cursor` |
| Antarmuka | RPC `cs_api.compliance_audit`; Hub: Kepatuhan → Jejak Audit (Ekspor CSV) |
| Lacak | BR-PATUH |

#### FR-PATUH-12 Kebijakan tenggat dan retensi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengonfirmasi atau mengubah tenggat pengaduan, perpanjangan tenggat, dan retensi chat CS, dengan riwayat konfirmasi per versi. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) Kebijakan: `complaint.days` 1–20 hari kerja (bawaan 5), `complaint.extension_days` 0–20 hari kerja (bawaan 10) (0027, 0042). Sejak 0195 `retention.chat_years` keluar dari daftar ini dan diatur lewat Retensi data dengan persetujuan staf lain. <br>2) `compliance_confirm_policy(p_key, p_value, p_note)`; nilai bilangan bulat dalam rentang; catatan dasar ketentuan ≤ 500. <br>3) Konfirmasi tercatat di `cs.policy_confirmations` (unik per versi pengaturan, append-only) dan perubahan di `cs_settings_history`. <br>4) Perubahan hanya berlaku untuk pengaduan baru. <br>5) Super Admin tidak bisa mengubah kedua nilai ini. <br>6) `compliance_policies()` mengembalikan status konfirmasi versi terkini dan 30 riwayat perubahan terakhir. |
| Keluaran | Tampilan kebijakan; audit `compliance.policy_confirm` (`changed` true/false). |
| Kode error | `403 policy_locked`; `400 invalid_policy`; `400 invalid_note` |
| Antarmuka | RPC `cs_api.compliance_policies`, `cs_api.compliance_confirm_policy`; Hub: Kepatuhan → Tenggat & retensi (Konfirmasi nilai ini, Simpan & konfirmasi) |
| Lacak | BR-PATUH |

#### FR-PATUH-13 Draf dokumen hukum

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan menyusun draf Syarat & Ketentuan, Pedoman Komunitas, dan Kebijakan Privasi. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `legal_draft_save(p_id, p_kind, p_title, p_body, p_change_summary, p_effective_at)`; `p_id` null = draf baru (0062). <br>2) Jenis `terms`, `community_guidelines`, `privacy` (jenis Berbagi Trade milik TRADE). <br>3) Judul 3–150 karakter; isi teks biasa 50–100.000 karakter (baris baru dipertahankan); ringkasan perubahan ≤ 2.000; tanggal berlaku opsional, tidak boleh lewat. <br>4) Hanya draf berstatus `draft` atau `rejected` yang bisa diubah; draf ditolak bisa diperbaiki. <br>5) Hub: Draf baru atau Buat dari versi berlaku, dengan Pratinjau. |
| Keluaran | Tampilan draf; audit `legal.draft_created` untuk draf baru. |
| Kode error | `400 invalid_legal_kind`; `400 invalid_legal_title`; `400 invalid_legal_body`; `400 invalid_legal_summary`; `400 legal_effective_past`; `404 legal_draft_not_found`; `409 legal_draft_locked` |
| Antarmuka | RPC `cs_api.legal_draft_save`, `cs_api.legal_draft`; Hub: Kepatuhan → Dokumen hukum |
| Lacak | BR-PATUH |

#### FR-PATUH-14 Pengajuan, penarikan, dan penolakan draf dokumen hukum

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengelola alur draf dokumen hukum dari diajukan sampai ditolak atau ditarik kembali. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Draf ada. |
| Proses dan aturan | 1) `legal_draft_submit(p_id)`: draf atau draf ditolak → `pending`; draf yang diajukan terkunci (0062). <br>2) `legal_draft_withdraw(p_id)`: draf `pending` kembali menjadi draf. <br>3) `legal_draft_reject(p_id, p_note)`: alasan 5–1.000 karakter, tampil di draf. <br>4) Pengaju tercatat (`submitted_by`) untuk aturan empat mata (0066). |
| Keluaran | Audit `legal.submitted`, `legal.withdrawn`, `legal.rejected`. |
| Kode error | `404 legal_draft_not_found`; `409 legal_draft_locked`; `409 legal_draft_not_pending`; `400 legal_note_required` |
| Antarmuka | RPC `cs_api.legal_draft_submit`, `cs_api.legal_draft_withdraw`, `cs_api.legal_draft_reject`; Hub: Dokumen hukum (Ajukan untuk persetujuan, Tarik kembali, Tolak) |
| Lacak | BR-PATUH |

#### FR-PATUH-15 Persetujuan dan penerbitan dokumen hukum (empat mata)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerbitkan dokumen hukum hanya setelah disetujui staf Kepatuhan lain, dengan versi bernomor dan tanggal berlaku. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Draf `pending`. |
| Proses dan aturan | 1) `legal_draft_approve(p_id)` (0062). <br>2) Penyusun, pengubah terakhir, dan pengaju tidak bisa menyetujui bila ada ≥ 2 staf Kepatuhan aktif; bila hanya satu, ia boleh menyetujui sendiri dan audit menandai `self_approved`. <br>3) Ditolak bila sudah ada versi terjadwal untuk jenis yang sama. <br>4) Versi baru = versi terakhir jenis itu + 1; berlaku pada `max(tanggal berlaku, sekarang)` (langsung atau terjadwal). <br>5) Versi yang terbit tidak bisa diubah; persetujuan nasabah tersimpan per versi (`public.user_consents`) (sisi nasabah di AKUN). |
| Keluaran | Dokumen terbit; audit `legal.published` (versi, tanggal berlaku, `self_approved`). |
| Kode error | `409 legal_draft_not_pending`; `403 four_eyes`; `409 legal_scheduled_exists` |
| Antarmuka | RPC `cs_api.legal_draft_approve`; Hub: Dokumen hukum → Tinjau → Setujui & terbitkan / Setujui & jadwalkan |
| Lacak | BR-PATUH |

#### FR-PATUH-16 Pembatalan jadwal dan penghapusan draf dokumen hukum

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan membatalkan versi terjadwal yang belum berlaku dan menghapus draf yang belum diajukan. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Versi belum berlaku (pembatalan); draf `draft`/`rejected` (penghapusan). |
| Proses dan aturan | 1) `legal_cancel_scheduled(p_document_id)`: hanya versi dengan `effective_at` di masa depan; drafnya kembali menjadi draf (0062). <br>2) `legal_draft_delete(p_id)`: hanya draf atau draf ditolak. |
| Keluaran | Audit `legal.schedule_cancelled` atau `legal.draft_deleted`. |
| Kode error | `404 document_not_found`; `409 legal_already_effective`; `404 legal_draft_not_found`; `409 legal_draft_locked` |
| Antarmuka | RPC `cs_api.legal_cancel_scheduled`, `cs_api.legal_draft_delete`; Hub: Dokumen hukum (Batalkan jadwal, Hapus draf) |
| Lacak | BR-PATUH |

#### FR-PATUH-17 Jenis dokumen hukum wajib

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan menentukan jenis dokumen hukum yang wajib disetujui nasabah sebelum membuat konten komunitas. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `legal_set_required(p_kinds)` menyimpan `legal.required_kinds` (bawaan `terms`, `community_guidelines`) (0014, 0165). <br>2) Jenis harus dikenal; jenis Berbagi Trade (`trade_share_terms`, `trade_share_risk`) ditolak karena disetujui di alurnya sendiri. <br>3) Dokumen wajib menahan postingan, komentar, dan pesan sampai versi terbaru disetujui (`403 consent_required`, FR-MOD-04); chat CS tidak butuh persetujuan. |
| Keluaran | Daftar jenis wajib; audit `legal.required_changed` (lama, baru). |
| Kode error | `400 invalid_legal_kind`; `400 legal_kind_not_global` |
| Antarmuka | RPC `cs_api.legal_set_required`; Hub: Dokumen hukum (Wajibkan, Jadikan tidak wajib) |
| Lacak | BR-PATUH |

#### FR-PATUH-18 Ringkasan dokumen hukum

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan versi berlaku, versi terjadwal, riwayat, draf, dan jumlah persetujuan nasabah per jenis dokumen. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `legal_overview()` mengembalikan jumlah pengguna aktif (profil tidak terhapus), jumlah peninjau Kepatuhan aktif, status empat mata (≥ 2 peninjau), jenis wajib, dan per jenis: versi berlaku, versi terjadwal, 20 versi terakhir, serta draf `draft`/`pending`/`rejected` (0062). <br>2) Setiap versi memuat jumlah persetujuan dari profil yang tidak terhapus; Hub menampilkan persentase terhadap pengguna aktif. <br>3) `legal_document(p_id)` mengembalikan isi lengkap versi. |
| Keluaran | Halaman Dokumen hukum. |
| Kode error | `404 document_not_found` |
| Antarmuka | RPC `cs_api.legal_overview`, `cs_api.legal_document`; Hub: Kepatuhan → Dokumen hukum |
| Lacak | BR-PATUH |

#### FR-PATUH-19 Perekaman bukti otomatis

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyalin konten yang dilaporkan atau dihapus, beserta file-nya, ke karantina bukti yang terpisah dari data hidup. |
| Aktor | Sistem; layanan janitor (penyalin file) |
| Prakondisi | Salah satu pemicu terjadi. |
| Proses dan aturan | 1) Pemicu dan sumber (0095): laporan pengguna (`report`: teks, lampiran, metadata, profil penulis; untuk akun: username, nama, bio, foto); moderator menghapus konten (`moderator_remove`); sistem menghapus konten (`system_remove`, arsip `policy_block`); moderator menghapus gambar ditahan (`media_removed`: file + skor); toleransi nol (`zero_tolerance`: profil + maks 500 postingan, 500 komentar, 500 pesan terbaru). <br>2) Isi sama (target + sidik isi) tidak digandakan: ditautkan (jejak `linked`) dan masa simpan diperpanjang; isi berbeda membuat bukti baru. <br>3) File disalin ke bucket privat `evidence` sebagai `<id bukti>/<urutan>-<nama file>`; janitor mencocokkan SHA-256 sumber dan salinan sebelum mencatat `copied`; sumber hilang → `missing`; gagal dicoba ulang sampai 6 jam, setelah 30 kali → `failed`. <br>4) Selama file `pending`, folder sumber tidak dibersihkan dan pemilik tidak bisa menghapus/menimpanya. <br>5) Tanpa FK ke `profiles`/`posts`, sehingga hapus akun tidak menyentuh bukti. |
| Keluaran | Baris `private.evidence`, `private.evidence_files`, `private.evidence_custody`. |
| Kode error | `409 evidence_pending` (pemilik mengubah file sumber yang sedang diamankan) |
| Antarmuka | Trigger pada `public.reports`, `private.content_archive`, `private.media_reviews`, sanksi; layanan janitor 0.2.0 (OPS) |
| Lacak | BR-PATUH |

#### FR-PATUH-20 Imutabilitas, sidik, dan pemeriksaan integritas bukti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menjaga bukti tambah-saja dengan sidik SHA-256 berlapis dan memungkinkan Kepatuhan memeriksa ulang integritasnya. |
| Aktor | Staf Kepatuhan; Super Admin (hanya baca) |
| Prakondisi | Bukti ada. |
| Proses dan aturan | 1) Trigger menolak UPDATE, DELETE, dan TRUNCATE; yang boleh berubah hanya legal hold dan perpanjangan masa simpan; baris hanya terhapus bila masa simpan habis tanpa legal hold; file `copied` tidak bisa diubah (0095). <br>2) Sidik: `content_sha256`, `body_sha256`, `record_sha256`, `sha256` per file, dan `entry_sha256` per jejak penanganan yang berantai ke `prev_sha256`. <br>3) `evidence_verify(p_id)` menghitung ulang semua sidik. <br>4) `evidence_file_checked(p_file_id, p_sha256)`: web mengunduh file, menghitung SHA-256 di browser, server membandingkan; file harus sudah `copied`. <br>5) Objek bucket `evidence` tidak bisa dihapus selama buktinya ada. |
| Keluaran | Hasil "Utuh: semua sidik cocok" atau "Ditemukan ketidaksesuaian"; jejak `verified`/`file_verified`; audit `evidence.verify`/`evidence.file_verify`. |
| Kode error | `409 evidence_immutable`; `409 evidence_retained`; `400 invalid_hash`; `404 evidence_file_not_found`; `409 evidence_file_not_copied` |
| Antarmuka | RPC `cs_api.evidence_verify`, `cs_api.evidence_file_checked`; Hub: Bukti → detail → Periksa integritas |
| Lacak | BR-PATUH |

#### FR-PATUH-21 Daftar dan detail bukti

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan daftar bukti yang bisa dicari dan disaring, serta detail bukti dengan akses file yang selalu didahului catatan jejak penanganan. |
| Aktor | Staf Kepatuhan; Super Admin (hanya baca) |
| Prakondisi | — |
| Proses dan aturan | 1) `evidence_list(p_query, p_filter, p_source, p_before_seq, p_limit)`: bawaan 50, maks 100; filter `held`/`pending`/`problem`/`expiring`; sumber `report`/`moderator_remove`/`system_remove`/`media_removed`/`zero_tolerance`; cari kode `EV-000123`, ID bukti/konten/akun/laporan, atau username; daftar tidak berisi teks konten (0095). <br>2) Ringkasan Hub: total, legal hold, habis ≤ 30 hari, file menunggu, file hilang/gagal, masa simpan. <br>3) `evidence_detail(p_id)` mencatat jejak `viewed` + audit `evidence.view`. <br>4) File di bucket `evidence` hanya bisa dibaca/ditandatangani (policy `evidence_quarantine_read`) oleh Kepatuhan/Super Admin yang dalam 15 menit terakhir membuka, memeriksa, atau mengekspor bukti itu; Hub memakai URL bertanda tangan 2 menit untuk melihat file. |
| Keluaran | Daftar bukti; detail berisi isi asli, file, sidik, laporan terkait, konteks JSON, dan jejak penanganan. |
| Kode error | `400 invalid_filter`; `400 invalid_source`; `404 evidence_not_found` |
| Antarmuka | RPC `cs_api.evidence_list`, `cs_api.evidence_detail`; Hub: Kepatuhan → Bukti |
| Lacak | BR-PATUH |

#### FR-PATUH-22 Legal hold dan masa simpan bukti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan bukti selama masa simpan dan memungkinkan Kepatuhan memasang atau melepas legal hold yang menangguhkan penghapusan. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Bukti ada. |
| Proses dan aturan | 1) Masa simpan `retention.evidence_days` 730 hari sejak bukti terakhir direkam atau ditautkan (0095). <br>2) `evidence_set_hold(p_id, p_hold, p_reason)`; alasan 10–500 karakter (mis. nomor surat penyidik). <br>3) Saat dilepas, masa simpan menjadi paling sedikit 30 hari lagi. <br>4) Job `evidence-purge` (harian 03:33 UTC, OPS) menghapus bukti lewat masa simpan tanpa legal hold, memasukkan foldernya ke antrean janitor (`evidence_expired`), dan mencatat audit `evidence.purged`. <br>5) Super Admin tidak bisa memasang/melepas legal hold. |
| Keluaran | Status bukti; jejak `hold_set`/`hold_released`; audit `evidence.legal_hold`. |
| Kode error | `400 invalid_hold`; `400 reason_required`; `409 hold_unchanged`; `404 evidence_not_found` |
| Antarmuka | RPC `cs_api.evidence_set_hold`; Hub: Bukti → detail → Pasang legal hold / Lepas legal hold |
| Lacak | BR-PATUH |

#### FR-PATUH-23 Ekspor paket bukti

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghasilkan paket bukti JSON bersidik untuk diserahkan sesuai prosedur legal. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Bukti ada. |
| Proses dan aturan | 1) `evidence_export(p_id, p_purpose)`; tujuan 5–500 karakter (0095). <br>2) Manifest `olt-evidence-bundle/1`: isi, konteks, semua sidik, daftar file (bucket, nama objek, SHA-256, ukuran), jejak penanganan berantai, dan laporan terkait. <br>3) `manifest_sha256` = SHA-256 teks JSON manifest (tanpa `manifest_sha256` dan tautan unduh), dicatat di jejak penanganan. <br>4) Hub menambahkan `download_links` (URL bertanda tangan 1 jam) dan mengunduh `bukti-EV-000123-<12 karakter sidik>.json`; penerima memverifikasi file dengan `sha256sum`. <br>5) Super Admin tidak bisa mengekspor. |
| Keluaran | Manifest + `manifest_sha256`; jejak `exported`; audit `evidence.export`. |
| Kode error | `400 purpose_required`; `404 evidence_not_found` |
| Antarmuka | RPC `cs_api.evidence_export`; Hub: Bukti → detail → Ekspor paket bukti |
| Lacak | BR-PATUH |

#### FR-PATUH-24 Aksi dan cakupan kategori konten

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengubah aksi dan cakupan setiap kategori keamanan konten. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan (FR-PATUH-34). |
| Proses dan aturan | 1) Kategori: `gambling`, `porn`, `phishing`, `blocked`, `shortener`, `messenger`, `phone`, `promotion`, `other_link` (0069). <br>2) Aksi `allow`/`censor`/`hold`/`block` (Izinkan, Sensor, Tahan, Blokir); cakupan `public` (Publik saja) atau `all` (Publik + DM & grup). <br>3) `compliance_content_rules()` membaca aturan; `compliance_set_content_rule(p_category, p_action, p_scope)` mengubahnya. <br>4) Penegakan di FR-MOD-07 s.d. FR-MOD-10. |
| Keluaran | Tampilan aturan; audit `content_rule.update` saat berlaku. |
| Kode error | `404 category_not_found`; `400 invalid_action`; `400 invalid_scope`; `409 policy_review_required` |
| Antarmuka | RPC `cs_api.compliance_content_rules`, `cs_api.compliance_set_content_rule` (lewat `compliance_policy_call`); Hub: Kebijakan konten → Kategori |
| Lacak | BR-PATUH |

#### FR-PATUH-25 Domain diblokir dan domain tepercaya

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengelola daftar domain/kata kunci domain yang diblokir dan domain tepercaya. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) `compliance_save_blocked_domain(p_domain, p_category, p_action, p_note, p_match)`: `p_match` `domain` (format domain valid, ≤ 253 karakter) atau `keyword` (3–30 karakter); kategori `gambling`/`porn`/`phishing`/`blocked`/`shortener`/`messenger`; aksi opsional menimpa aksi kategori; catatan ≤ 200; maks 5.000 entri (0069). <br>2) `compliance_save_allowed_domain(p_domain, p_note)`: maks 1.000 entri; domain tepercaya selalu lolos. <br>3) `compliance_delete_blocked_domain`, `compliance_delete_allowed_domain`. <br>4) Pola domain dibangun ulang otomatis. |
| Keluaran | Audit `blocked_domain.save`/`.delete`, `allowed_domain.save`/`.delete` saat berlaku. |
| Kode error | `400 invalid_match`; `400 invalid_domain`; `400 invalid_category`; `400 invalid_action`; `400 invalid_note`; `400 domain_limit`; `404 domain_not_found`; `400 policy_limit` |
| Antarmuka | RPC `cs_api.compliance_save_blocked_domain`, `cs_api.compliance_delete_blocked_domain`, `cs_api.compliance_save_allowed_domain`, `cs_api.compliance_delete_allowed_domain`; Hub: Kebijakan konten → Domain |
| Lacak | BR-PATUH |

#### FR-PATUH-26 Istilah pengecualian dan frasa promosi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengelola istilah pengecualian (dibuang sebelum pencocokan) dan frasa promosi. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) Istilah pengecualian: huruf kecil, huruf/angka/spasi, 2–50 karakter, maks 500 (`compliance_add_allowlist_term`, `compliance_delete_allowlist_term`) (0069). <br>2) Frasa promosi: 3–50 karakter, maks 500 (`compliance_add_promo_phrase`, `compliance_delete_promo_phrase`). <br>3) Istilah/frasa yang sudah ada ditolak. |
| Keluaran | Audit `policy_allowlist.add`/`.delete`, `promo_phrase.add`/`.delete` saat berlaku. |
| Kode error | `400 invalid_term`; `409 term_exists`; `400 term_limit`; `404 term_not_found` |
| Antarmuka | RPC `cs_api.compliance_add_allowlist_term`, `cs_api.compliance_delete_allowlist_term`, `cs_api.compliance_add_promo_phrase`, `cs_api.compliance_delete_promo_phrase`; Hub: Kebijakan konten → Frasa & pengecualian |
| Lacak | BR-PATUH |

#### FR-PATUH-27 Kelola kata terlarang

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan menambah, mengubah aksi, dan menghapus kata terlarang. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) Kata dinormalkan huruf kecil dan spasi tunggal; 2–50 karakter, hanya huruf/angka/spasi (0051). <br>2) Aksi `mask` (Sensor) atau `block` (Blokir). <br>3) Batas daftar 2.000 kata (`cs.banned_word_limit`). <br>4) `compliance_banned_words()` membaca daftar beserta batasnya. <br>5) Hub: perubahan masuk draf dan baru berlaku setelah disetujui bila empat mata aktif. |
| Keluaran | Audit `banned_word.add`, `banned_word.update`, `banned_word.delete` saat berlaku. |
| Kode error | `400 invalid_banned_word`; `400 invalid_banned_action`; `409 banned_word_exists`; `400 banned_word_limit`; `404 banned_word_not_found` |
| Antarmuka | RPC `cs_api.compliance_banned_words`, `cs_api.compliance_add_banned_word`, `cs_api.compliance_set_banned_word_action`, `cs_api.compliance_delete_banned_word`; Hub: Kebijakan konten → Kata terlarang |
| Lacak | BR-PATUH |

#### FR-PATUH-28 Import dan ekspor Excel kata terlarang

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Kepatuhan mengimpor kata terlarang dari file Excel dengan pratinjau, serta mengunduh daftar sebagai Excel. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) Template: kolom A kata/frasa, kolom B aksi `sensor`/`blokir` (kosong = sensor). <br>2) Pratinjau Hub: Baru, Aksi berubah, Sudah ada, Duplikat, Tidak valid. <br>3) `compliance_import_banned_words(p_rows)`: maks 1.000 baris per import; kata yang muncul lebih dari sekali dengan aksi berbeda ditolak; hanya menambah atau mengubah aksi, tidak menghapus kata yang ada; total tetap ≤ 2.000 (0051). <br>4) Unduh Excel mengekspor daftar berlaku. |
| Keluaran | Ringkasan import; audit `banned_word.import` saat berlaku. |
| Kode error | `400 invalid_import`; `400 import_too_large`; `400 import_conflict`; `400 banned_word_limit` |
| Antarmuka | RPC `cs_api.compliance_import_banned_words`; Hub: Kebijakan konten → Kata terlarang (Unduh template, Import Excel, Unduh Excel) |
| Lacak | BR-PATUH |

#### FR-PATUH-29 Masa akun baru

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengatur satu angka masa akun baru yang mengendalikan semua batasan akun baru. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) `compliance_set_new_account_days(p_days)`: 0–30 hari, bawaan 3; 0 = akun baru langsung bebas (0069, 0187). <br>2) Mengatur larangan gambar (termasuk Share P/L), larangan tautan, DM lewat permintaan pesan, dan rate limit dikali 0,5 (penegakan FR-MOD-11). <br>3) Pengaturan lama `trust.new_account_hours` dihapus (0187); `trending.new_account_days` dan `manipulation.new_account_age_days` tetap terpisah. <br>4) Lewat gerbang draf, argumen harus bertipe angka. |
| Keluaran | Tampilan aturan kategori; audit `content_rule.new_account_days`. |
| Kode error | `400 invalid_setting` |
| Antarmuka | RPC `cs_api.compliance_set_new_account_days`; Hub: Kebijakan konten → Kategori → Masa akun baru |
| Lacak | BR-PATUH |

#### FR-PATUH-30 Jeda bergabung lagi setelah hapus akun

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengatur jeda sebelum akun yang dihapus bisa bergabung lagi ke komunitas. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) `compliance_set_rejoin_cooldown_hours(p_hours)`: 0–720 jam, bawaan 72 (`account.rejoin_cooldown_hours`); 0 = bisa langsung bergabung lagi (0175). <br>2) Nilai ikut snapshot kebijakan berversi (`private.policy_setting_key`). <br>3) Efek ke nasabah (penolakan `403 account_rejoin_cooldown`, nilai di `get_client_config`) milik AKUN. |
| Keluaran | Tampilan aturan kategori; audit `content_rule.rejoin_cooldown_hours`. |
| Kode error | `400 invalid_setting` |
| Antarmuka | RPC `cs_api.compliance_set_rejoin_cooldown_hours`; Hub: Kebijakan konten → Kategori (kartu jeda bergabung lagi) |
| Lacak | BR-PATUH |

#### FR-PATUH-31 Ambang gambar NSFW

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengatur ambang tahan dan blokir classifier per kategori untuk upload media dan gambar pratinjau link. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) Bentuk `{"<kategori>": {"hold": 0–1, "block": 0–1}}`, kategori dari `private.media_categories()` (`drawings`, `hentai`, `neutral`, `porn`, `sexy`); `hold` ≤ `block`; `porn` wajib punya minimal satu ambang (0079). <br>2) Bawaan: porn tahan 0,50 / blokir 0,90; hentai 0,60 / 0,95; sexy tahan 0,85 (services/media/README.md). <br>3) `compliance_set_image_thresholds(p_thresholds, p_note)`, catatan ≤ 500; `revision` naik setiap perubahan; layanan media membaca ulang tiap `MODERATION_REFRESH` (30 dtk). <br>4) Penegakan di FR-MOD-14 dan FR-MOD-17. |
| Keluaran | Ambang terbaru; audit `media.thresholds_set` (nilai lama dan baru). |
| Kode error | `400 invalid_image_thresholds`; `400 invalid_note` |
| Antarmuka | RPC `cs_api.compliance_image_thresholds`, `cs_api.compliance_set_image_thresholds`; Hub: Kebijakan konten → Ambang gambar (Tahan ≥, Blokir ≥) |
| Lacak | BR-PATUH |

#### FR-PATUH-32 Pengaturan anti-manipulasi dan jam ramai

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan mengatur ambang deteksi manipulasi, aksi otomatis, dan slow mode jam ramai. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Perubahan lewat draf kebijakan. |
| Proses dan aturan | 1) `compliance_set_manipulation_settings(p_values)` menerima objek kunci yang dikenal; rentang (0072): `spike_factor` 1,5–100; `spike_min_mentions` 1–100.000; `baseline_days` 1–60; `new_account_share` 0,1–1; `new_account_min_mentions` 1–100.000; `new_account_age_days` 1–90; `similarity` 0,3–1; `similar_min_authors` 2–1.000; `similar_window_minutes` 5–1.440; `auto_slow_mode_seconds` 0–3.600; `auto_slow_mode_minutes` 1–1.440; `rooms.busy_slow_mode` 0–300 (semua `manipulation.*` kecuali yang terakhir). <br>2) `manipulation.auto_slow_mode` dan `manipulation.auto_hold_similar` boolean. <br>3) `rooms.busy_windows` maks 6 rentang `HH:MM`, jam mulai sebelum jam selesai. <br>4) Slow mode otomatis dibatasi paling ketat sama dengan jam ramai (0110). |
| Keluaran | Pengaturan terbaru; audit `manipulation.settings` (dari, ke). |
| Kode error | `400 invalid_setting` |
| Antarmuka | RPC `cs_api.compliance_manipulation_settings`, `cs_api.compliance_set_manipulation_settings`; Hub: Kebijakan konten → Anti-manipulasi |
| Lacak | BR-PATUH |

#### FR-PATUH-33 Uji teks terhadap kebijakan berlaku

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Kepatuhan menguji perlakuan kebijakan berlaku terhadap sebuah teks tanpa menyimpan apa pun. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) `compliance_test_content(p_text, p_surface)`; tempat `post`/`comment`/`stock`/`group`/`direct`; teks 1–4.000 karakter (0176). <br>2) Kata terlarang dinilai lebih dulu (`allow`/`censor`/`block`), lalu kategori keamanan konten pada teks hasil sensor. <br>3) Hasil memuat aksi, kategori, ada tautan atau tidak, teks hasil, teks ternormalisasi, serta jumlah kata terlarang dan frasa promosi yang termuat. <br>4) Tidak menulis audit. |
| Keluaran | Hasil evaluasi. |
| Kode error | `400 invalid_surface`; `400 invalid_text` |
| Antarmuka | RPC `cs_api.compliance_test_content`; Hub: Kebijakan konten → Uji teks |
| Lacak | BR-PATUH |

#### FR-PATUH-34 Draf kebijakan per staf

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menampung perubahan kebijakan konten sebagai draf milik masing-masing staf Kepatuhan, tanpa mengubah kebijakan berlaku sampai diajukan dan disetujui. |
| Aktor | Staf Kepatuhan |
| Prakondisi | — |
| Proses dan aturan | 1) Isi kebijakan berversi: kata terlarang, aturan kategori, domain diblokir/tepercaya, istilah pengecualian, frasa promosi, `safety.new_account_days`, `account.rejoin_cooldown_hours`, `manipulation.*`, `rooms.busy_slow_mode`, `rooms.busy_windows`, dan ambang gambar (0092, 0175). Kebijakan kasus (FR-PATUH-12) tidak ikut. <br>2) Semua tab Kebijakan konten memanggil `compliance_policy_call(p_fn, p_args)` dengan nama RPC lama yang di-whitelist; satu draf (`cs.policy_changes` status `draft`) per staf. <br>3) Gerbang memuat draf ke tabel di subtransaksi, menjalankan RPC asli (validasi sama), mengambil snapshot, lalu membatalkan subtransaksi; tabel aktif dan audit RPC lama ikut dibatalkan. <br>4) Draf di-rebase ke versi terbaru: hanya butir yang diubah staf yang menimpa kebijakan berlaku. <br>5) Saat empat mata aktif, staf yang memanggil RPC ubah lama secara langsung ditolak. <br>6) `compliance_policy_state()` (Kepatuhan dan Super Admin) menampilkan status empat mata, versi berlaku, draf + diff, dan jumlah permintaan tertunda; `compliance_policy_discard()` membuang draf. |
| Keluaran | Hasil RPC + `policy_draft {id, changes}`. |
| Kode error | `400 invalid_policy_call`; `409 policy_review_required` |
| Antarmuka | RPC `cs_api.compliance_policy_call`, `cs_api.compliance_policy_state`, `cs_api.compliance_policy_discard`; Hub: Kebijakan konten → Draf perubahan Anda, Buang draf |
| Lacak | BR-PATUH |

#### FR-PATUH-35 Pengajuan dan persetujuan empat mata kebijakan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memberlakukan draf kebijakan hanya setelah disetujui staf Kepatuhan lain bila empat mata aktif, atau langsung bila empat mata dimatikan. |
| Aktor | Staf Kepatuhan (pengaju dan pemeriksa); Super Admin hanya melihat |
| Prakondisi | Draf berisi perubahan. |
| Proses dan aturan | 1) `compliance_policy_submit(p_reason)`: alasan 5–500 karakter; batas daftar diperiksa (kata terlarang 2.000, domain diblokir 5.000, domain tepercaya 1.000, pengecualian 500, frasa promosi 500) (0092). <br>2) Empat mata aktif → `pending`; nonaktif → langsung berlaku (tombol Hub "Aktifkan sekarang"). <br>3) `compliance_policy_changes(p_status)` (`pending`/`decided`) dan `compliance_policy_change(p_id)` menampilkan diff yang diajukan dan efeknya bila disetujui sekarang. <br>4) `compliance_policy_decide(p_id, p_approve, p_note)`: pembuat ≠ pemeriksa saat empat mata aktif; tolak wajib alasan 5–500; catatan ≤ 500. <br>5) `compliance_policy_withdraw(p_id)` hanya oleh pembuat. <br>6) Saklar empat mata (`compliance.policy_four_eyes`, bawaan aktif) diatur Super Admin di Pengaturan → Aturan persetujuan (HUB). |
| Keluaran | Audit `policy_change.submit`, `policy_change.apply`, `policy_change.approve`, `policy_change.reject`, `policy_change.withdraw`. |
| Kode error | `400 invalid_reason`; `404 policy_draft_not_found`; `400 policy_no_change`; `400 policy_limit`; `400 invalid_status`; `400 invalid_decision`; `400 note_required`; `400 invalid_note`; `404 policy_change_not_found`; `409 policy_change_decided`; `403 four_eyes`; `409 policy_stale`; `409 policy_no_change` |
| Antarmuka | RPC `cs_api.compliance_policy_submit`, `cs_api.compliance_policy_changes`, `cs_api.compliance_policy_change`, `cs_api.compliance_policy_decide`, `cs_api.compliance_policy_withdraw`; Hub: Kebijakan konten → Versi & persetujuan (Ajukan untuk persetujuan, Menunggu persetujuan, Setujui, Tolak, Tarik) |
| Lacak | BR-PATUH |

#### FR-PATUH-36 Versi kebijakan dan pemulihan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencatat setiap perubahan kebijakan konten sebagai versi bernomor append-only dan memungkinkan pemulihan versi lama lewat alur persetujuan. |
| Aktor | Staf Kepatuhan; Sistem |
| Prakondisi | — |
| Proses dan aturan | 1) `cs.policy_versions`: nomor naik, snapshot penuh, ringkasan diff per bagian (maks 200 butir per bagian), sumber `baseline`/`direct`/`change`/`rollback`/`system`, alasan, permintaan asal, versi yang dipulihkan, pembuat, waktu (0092). <br>2) Tabel menolak UPDATE, DELETE, dan TRUNCATE; versi dibuat sekali per transaksi oleh constraint trigger deferred, sehingga perubahan dari migrasi/operasional tetap tercatat sebagai `system`. <br>3) `compliance_policy_versions(p_before, p_limit)` (bawaan 30) dan `compliance_policy_version(p_version)` (diff versi + diff pemulihan terhadap kebijakan berlaku). <br>4) `compliance_policy_rollback(p_version, p_reason)` membuat permintaan `rollback` berisi snapshot lama; setelah disetujui terbentuk versi baru berisi identik. <br>5) Kebijakan berubah sebelum persetujuan → ditolak. |
| Keluaran | Riwayat versi; audit `policy.rollback`. |
| Kode error | `404 policy_version_not_found`; `400 policy_no_change`; `409 policy_stale` |
| Antarmuka | RPC `cs_api.compliance_policy_versions`, `cs_api.compliance_policy_version`, `cs_api.compliance_policy_rollback`; Hub: Kebijakan konten → Versi & persetujuan → Riwayat versi (Pulihkan) |
| Lacak | BR-PATUH |

#### FR-PATUH-37 Simulasi kebijakan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mensimulasikan dampak draf, permintaan tertunda, atau versi lama terhadap konten nyata sebelum diberlakukan, tanpa menyimpan apa pun. |
| Aktor | Staf Kepatuhan |
| Prakondisi | Ada draf milik sendiri, permintaan `pending`, atau versi yang dipilih. |
| Proses dan aturan | 1) `compliance_policy_simulate(p_change_id, p_version, p_text, p_surface, p_days, p_limit)`; tanpa target = draf sendiri (0092). <br>2) `p_days` 1–30 (bawaan 7); `p_limit` 1–1.000 (bawaan 300) konten terbaru: postingan, komentar, dan pesan room saham; DM, grup, chat CS, akun staf, dan akun resmi tidak ikut. <br>3) Contoh teks opsional ≤ 4.000 karakter; tempat `post`/`comment`/`stock`/`group`/`direct`. <br>4) Setiap konten dinilai seperti `compliance_test_content` dengan kebijakan berlaku dan dengan target di subtransaksi yang dibatalkan. <br>5) Hasil: jumlah per aksi, jumlah yang lebih ketat/longgar, maks 100 konten yang berubah, dan simulasi ambang gambar terhadap skor `private.media_reviews` (hanya gambar yang pernah ditahan). <br>6) Tidak menulis audit. |
| Keluaran | Ringkasan dampak. |
| Kode error | `400 invalid_surface`; `400 invalid_text`; `404 policy_change_not_found`; `404 policy_version_not_found`; `404 policy_draft_not_found` |
| Antarmuka | RPC `cs_api.compliance_policy_simulate`; Hub: Kebijakan konten → Versi & persetujuan → Simulasi → Jalankan simulasi (Lebih ketat, Lebih longgar) |
| Lacak | BR-PATUH |

### 4.9 Rendezvous Hub dan administrasi staf (HUB)

Rendezvous Hub (repo `rendezvous_hub`, React 19 + TypeScript, dibangun menjadi image `cs-console` saat `make up`) adalah aplikasi web internal untuk staf. Hub hanya dilayani di domain CS yang dibatasi ke IP kantor (`VPN_SOURCE_RANGES`, Traefik), sedangkan RPC staf ditolak di domain API publik (0100). Login staf memakai GoTrue (email + password), sementara nasabah tidak pernah login di GoTrue. Semua aksi staf lewat RPC `cs_api.*` yang memanggil `cs.require_agent(...)` atau `cs.require_community(...)`, dan perubahan penting dicatat di `cs.cs_audit_log` (Kepatuhan → Jejak Audit). Bagian ini mencakup kemampuan umum Hub: autentikasi dan keamanan login staf, swalayan akun staf, administrasi akun staf, peran dan izin, aturan empat mata, Fitur & versi, Tab Stream, Indeks, Akun resmi, Postingan resmi, analitik, command palette, dan preferensi tampilan. Fungsi Hub yang milik modul lain (tiket CS, Pusat Bantuan, notifikasi dan Banner & Popup, moderasi, kepatuhan, integrasi, operasional) dispesifikasikan di modul masing-masing.

**Peran staf.** Kolom `cs.agents.roles` dibatasi ke enam kode (constraint `agents_roles_check`, 0126). Satu akun boleh punya beberapa peran; menu di bilah atas adalah gabungan semua peran dan izin. RPC yang mengizinkan `product` atau `cs_content` selalu juga mengizinkan `cs_super_admin` (mis. `cs.require_agent('{cs_super_admin,product}')`, 0121), sehingga Super Admin otomatis mencakup kedua peran itu.

| Kode peran | Nama di Hub | Yang bisa dilakukan |
|---|---|---|
| `cs_agent` | CS | Menu **Layanan Nasabah**: ambil, balas, tunggu nasabah, lepas, transfer, dan selesaikan tiket; **Kinerja saya**. Punya Tim dan Batas tiket aktif (1–20). Satu-satunya peran yang boleh diberi Akses Akun Nasabah (0047) |
| `cs_super_admin` | Super Admin | Memantau tiket (mode pantau, tidak membalas kecuali juga `cs_agent`), **Dashboard**, **Laporan**, **Pengaturan** (Akun CS, layanan CS, Persetujuan, Integrasi, Sistem), **Pusat Bantuan**, **Banner & Popup**, tab **Fitur & versi**, **Tab Stream**, dan **Analitik** di Komunitas, Bukti hanya-baca lewat Ctrl K. Wajib 2FA (0186). Tidak bisa menonaktifkan diri atau melepas peran Super Admin sendiri |
| `compliance` | Kepatuhan | Menu **Kepatuhan**: Ringkasan, Kasus, Kebijakan konten, Tenggat & retensi, Dokumen hukum, Jejak Audit, Bukti |
| `community` | Komunitas | Tidak dipilih manual: Hub menyimpan peran ini bila akun hanya diberi Izin Komunitas tanpa peran lain. Menu **Komunitas** dengan tab sesuai izin |
| `product` | Fitur & Banner | Komunitas → **Fitur & versi** dan **Tab Stream**, menu **Banner & Popup**; melihat daftar skema deep link. Tidak membuka Pengaturan, Dashboard, Laporan, atau tiket (0121) |
| `cs_content` | Pusat Bantuan | Menu **Pusat Bantuan**: topik chat CS dan artikel FAQ. Tidak membuka Pengaturan, Dashboard, Laporan, atau tiket (0126) |

**Izin Komunitas (5 izin).** Kolom `cs.agents.community_permissions` (0057), bisa diberikan ke peran apa pun. Tab Komunitas yang tampil ditentukan `communityTabsFor` di Hub.

| Kode izin | Nama di Hub | Tab Komunitas |
|---|---|---|
| `community.post` | Tulis postingan resmi | Postingan resmi, Notifikasi |
| `community.publish` | Setujui & terbitkan | Postingan resmi, Notifikasi |
| `community.moderate` | Moderasi konten | Moderasi, Room saham, Indeks |
| `community.sanction` | Sanksi pengguna | Moderasi |
| `community.accounts` | Kelola akun resmi | Akun resmi |

**Izin Akun Nasabah (7 izin).** Kolom `cs.agents.nasabah_permissions` (0044–0047), hanya untuk akun berperan `cs_agent`; dicabut otomatis bila peran CS dilepas (trigger `agents_nasabah_scope`). Penegakannya di nasabah-gateway (lihat INT).

| Kode izin | Nama di Hub |
|---|---|
| `online_user.view` | Lihat nasabah online |
| `online_user.manage` | Kelola Online ID (pengajuan, rekening tertaut, reset password/PIN) |
| `online_user.demo` | Kelola akun demo saja |
| `online_user.approve` | Approval pengajuan Online ID dari CS lain |
| `online_user.approve_own` | Approve pengajuan sendiri tanpa menunggu CS lain |
| `online_user.status` | Ubah status Online ID langsung (wajib alasan, tanpa approval) |
| `opening_account.send` | Kirim email pembukaan rekening |

Izin Berbagi Trade (`trade_share.review`, `trade_share.manage`, `trade_relay.operate`, kolom `trade_permissions`, 0160) ada di database tetapi disembunyikan di Hub selama `SHOW_TRADE_SHARE = false` (lihat TRADE).

#### FR-HUB-01 Login staf dengan email dan password

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus mengautentikasi staf dengan email kerja dan password lewat GoTrue sebelum menampilkan menu apa pun. |
| Aktor | Staf (semua peran) |
| Prakondisi | Akun staf ada di `auth.users` dan `cs.agents`; browser berada di jaringan yang diizinkan `VPN_SOURCE_RANGES` |
| Proses dan aturan | 1) Halaman **Masuk ke Rendezvous Hub** meminta Email dan Password, lalu memanggil `signInWithPassword`. <br>2) Password minimal 12 karakter (`GOTRUE_PASSWORD_MIN_LENGTH`, docker/compose.yml). <br>3) Tidak ada reset password mandiri lewat email; reset hanya oleh Super Admin (FR-HUB-16). <br>4) Setelah login, Hub memanggil `cs_api.agent_me`; akun yang tidak aktif atau tidak ada di `cs.agents` ditolak. <br>5) Bila akun tidak punya menu sama sekali, Hub menampilkan "Peran akun ini belum punya menu di web CS. Hubungi Super Admin." |
| Keluaran | Sesi staf GoTrue dan profil staf (`agent_me`) termuat |
| Kode error | `400 invalid_credentials` (pesan "Email atau password salah."); `429` rate limit GoTrue ("Terlalu banyak percobaan. Tunggu sebentar."); `403 agent_required` |
| Antarmuka | GoTrue `/auth/v1/token`; RPC `cs_api.agent_me`; Hub: halaman Masuk |
| Lacak | BR-HUB |

#### FR-HUB-02 Ganti password wajib pada login pertama

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memaksa staf mengganti password sementara sebelum memakai Hub pada login pertama atau setelah password direset. |
| Aktor | Staf |
| Prakondisi | `user_metadata.must_change_password = true` (diisi edge function `cs-admin` saat akun dibuat atau password direset) |
| Proses dan aturan | 1) Hub menampilkan halaman **Ganti password** (Password baru, Ulangi password baru). <br>2) Password baru minimal 12 karakter dan harus berbeda dari password sementara. <br>3) Hub memanggil `auth.updateUser` dengan password baru dan `must_change_password = false`. |
| Keluaran | Password baru berlaku; staf masuk ke Hub |
| Kode error | `400` (password ditolak kebijakan GoTrue) |
| Antarmuka | GoTrue `auth.updateUser`; Hub: halaman Ganti password |
| Lacak | BR-HUB |

#### FR-HUB-03 Verifikasi kode 2FA (TOTP) saat masuk

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak semua RPC staf dari sesi yang belum berlevel `aal2` bila staf itu wajib 2FA atau sudah mendaftarkan 2FA. |
| Aktor | Staf dengan peran wajib 2FA atau faktor TOTP terverifikasi |
| Prakondisi | Login password berhasil |
| Proses dan aturan | 1) Staf wajib 2FA bila salah satu perannya ada di `security.mfa_required_roles` (bawaan `["cs_super_admin"]`) atau ia punya faktor TOTP berstatus `verified` (`cs.agent_needs_mfa`, 0186). <br>2) `cs.current_agent_id` hanya mengembalikan staf bila JWT `aal = aal2` atau staf tidak wajib 2FA. <br>3) Hub meminta **Masukkan kode 2FA** (6 digit, berganti tiap 30 detik) dan memanggil `mfa.challengeAndVerify`. <br>4) Status dibaca lewat `cs_api.agent_security_status` (`mfa_required`, `mfa_enrolled`, `aal`). |
| Keluaran | Sesi naik ke `aal2`; RPC staf dapat dipakai |
| Kode error | `401 mfa_required`; pesan Hub "Kode 2FA salah atau sudah kedaluwarsa." |
| Antarmuka | RPC `cs_api.agent_security_status`; GoTrue MFA (`GOTRUE_MFA_TOTP_VERIFY_ENABLED`); Hub: halaman kode 2FA |
| Lacak | BR-HUB |

#### FR-HUB-04 Pendaftaran 2FA

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memaksa staf yang wajib 2FA tetapi belum punya faktor TOTP untuk mendaftarkannya sebelum memakai Hub. |
| Aktor | Staf wajib 2FA yang belum mendaftar |
| Prakondisi | `agent_security_status` mengembalikan `mfa_required = true` dan `mfa_enrolled = false` |
| Proses dan aturan | 1) Hub menampilkan **Aktifkan 2FA** dengan kode QR dan kunci manual (`mfa.enroll`, jenis `totp`). <br>2) Faktor lama yang belum terverifikasi di-unenroll dulu. <br>3) Staf memasukkan 6 digit kode; setelah terverifikasi, setiap login berikutnya meminta kode. <br>4) Staf yang perannya baru diwajibkan langsung diminta mendaftar, termasuk yang sedang masuk. |
| Keluaran | Faktor TOTP `verified`; sesi `aal2` |
| Kode error | `401 mfa_required` |
| Antarmuka | GoTrue MFA (`GOTRUE_MFA_TOTP_ENROLL_ENABLED`); Hub: halaman Aktifkan 2FA |
| Lacak | BR-HUB |

#### FR-HUB-05 Kunci akun setelah password salah berulang

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengunci sementara akun staf setelah jumlah password salah mencapai ambang dalam jendela waktu tertentu. |
| Aktor | Sistem (hook GoTrue) |
| Prakondisi | Hook `private.hook_password_verification_attempt` aktif (`GOTRUE_HOOK_PASSWORD_VERIFICATION_ATTEMPT_ENABLED`) |
| Proses dan aturan | 1) Setiap percobaan password dicatat di `private.staff_login_guard` (0186). <br>2) Kegagalan dihitung dalam jendela sepanjang `security.login_lock_minutes` (bawaan 15); mencapai `security.login_max_failures` (bawaan 5) mengunci akun selama `security.login_lock_minutes`. <br>3) Selama terkunci, password yang benar pun ditolak. <br>4) Password benar saat tidak terkunci menghapus hitungan. <br>5) Penguncian diaudit `security.login_locked` (email, jumlah gagal, `locked_until`). <br>6) Hub menampilkan "Akun dikunci sementara…" beserta jam kunci dibuka. |
| Keluaran | `locked_until` terisi; login ditolak sampai waktu itu |
| Kode error | Pesan hook `account_locked:<waktu UTC>` (status HTTP dari GoTrue perlu konfirmasi) |
| Antarmuka | Hook GoTrue `pg-functions://postgres/private/hook_password_verification_attempt`; Hub: halaman Masuk |
| Lacak | BR-HUB |

#### FR-HUB-06 Pengaturan Keamanan login

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin mengatur peran wajib 2FA, batas password salah, dan lama kunci akun. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin `aal2` |
| Proses dan aturan | 1) Dua kartu terkunci (**Ubah** → **Simpan** → konfirmasi). <br>2) `security.mfa_required_roles`: daftar unik dari enam kode peran dan wajib memuat `cs_super_admin`. <br>3) `security.login_max_failures` 3–20; `security.login_lock_minutes` 1–1440 (`cs.check_security_setting`, 0186). <br>4) Disimpan lewat `admin_set_setting`, diaudit `setting.update`. |
| Keluaran | Nilai baru berlaku pada login dan RPC berikutnya |
| Kode error | `400 invalid_setting`; `403 setting_locked`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_set_setting`; Hub: Pengaturan → Sistem → Keamanan login |
| Lacak | BR-HUB |

#### FR-HUB-07 Buka kunci akun staf

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin membuka kunci akun staf sebelum lama kunci habis. |
| Aktor | Super Admin |
| Prakondisi | Akun target ada; kolom status menampilkan "Terkunci sampai …" |
| Proses dan aturan | 1) **Buka kunci** menghapus baris `private.staff_login_guard` akun itu. <br>2) Diaudit `security.login_unlocked`. |
| Keluaran | Staf bisa langsung login lagi; tampilan akun diperbarui (`agent_admin_view`) |
| Kode error | `404 agent_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_unlock_agent`; Hub: Pengaturan → Akun CS |
| Lacak | BR-HUB |

#### FR-HUB-08 Reset 2FA staf dan pemulihan darurat

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin lain menghapus faktor 2FA staf yang kehilangan perangkat, dan tim IT memulihkan Super Admin terakhir dari server. |
| Aktor | Super Admin lain; tim IT (perintah server) |
| Prakondisi | Identitas staf sudah diverifikasi lewat jalur kantor |
| Proses dan aturan | 1) **Reset 2FA** menghapus `auth.mfa_factors` dan semua `auth.sessions` akun target, diaudit `security.mfa_reset` beserta jumlah faktor dan sesi. <br>2) Super Admin tidak bisa mereset 2FA miliknya sendiri. <br>3) Bila Super Admin terakhir kehilangan HP, tim IT menjalankan `make cs-mfa-reset EMAIL=...` yang memanggil `private.staff_security_recover`: hapus faktor, sesi, dan kunci akun, diaudit `security.mfa_recovered`. |
| Keluaran | Staf keluar dari semua perangkat dan wajib mendaftar 2FA lagi saat masuk |
| Kode error | `400 cannot_reset_self`; `404 agent_not_found` |
| Antarmuka | RPC `cs_api.admin_reset_agent_mfa`; `make cs-mfa-reset`; Hub: Pengaturan → Akun CS |
| Lacak | BR-HUB |

#### FR-HUB-09 Sesi per tab dan keluar otomatis saat idle

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menyimpan sesi staf per tab browser dan mengeluarkan staf yang idle melewati batas. |
| Aktor | Staf |
| Prakondisi | Staf sudah login |
| Proses dan aturan | 1) Sesi Supabase disimpan di `sessionStorage` dengan kunci `cs-console.auth.<id tab>`, sehingga beberapa akun berbeda bisa dibuka di tab berbeda pada satu browser. <br>2) Batas idle dari `ui.idle_logout_minutes` (bawaan 30) lewat `agent_me.settings.idle_logout_minutes`. <br>3) Menjelang batas, Hub menampilkan **Masih di sana?** dengan tombol **Tetap masuk**; tanpa respons, Hub keluar otomatis. |
| Keluaran | Sesi tab berakhir dan Hub kembali ke halaman masuk |
| Kode error | — |
| Antarmuka | Hub: `IdleGuard`, `initSupabase` |
| Lacak | BR-HUB |

#### FR-HUB-10 Ganti password sendiri

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan staf mengganti password sendiri setelah memverifikasi password saat ini. |
| Aktor | Staf |
| Prakondisi | Staf sudah login |
| Proses dan aturan | 1) Dialog **Ganti password**: Password saat ini, Password baru, Ulangi password baru; aturan minimal 12 karakter dan berbeda dari password saat ini. <br>2) Password saat ini diverifikasi dengan login ulang; bila salah, staf tetap masuk dan muncul "Password saat ini salah." <br>3) Setelah berhasil, sesi akun ini di perangkat dan tab lain dikeluarkan (`signOut` scope `others`); tab ini tetap masuk. <br>4) Diaudit `agent.password_changed` tanpa isi password (maksimal satu catatan per 30 detik, `cs.audit_self`, 0116). |
| Keluaran | Password baru berlaku; `password_changed_at` tampil di Profil saya |
| Kode error | `400 wrong_current_password` (Hub) |
| Antarmuka | GoTrue `updateUser`; RPC `cs_api.agent_password_changed`; Hub: avatar → Ganti password |
| Lacak | BR-HUB |

#### FR-HUB-11 Keluar dari semua perangkat

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan staf mencabut semua sesi akunnya sendiri. |
| Aktor | Staf |
| Prakondisi | Staf sudah login |
| Proses dan aturan | 1) Setelah konfirmasi, Hub mencatat audit `agent.signed_out_everywhere` lalu memanggil `signOut` scope `global`. <br>2) RPC berikutnya dari sesi yang dicabut ditolak karena `cs.session_alive` tidak menemukan `session_id` di `auth.sessions` (0116). <br>3) Akun lain yang terbuka di tab lain pada browser yang sama tidak ikut keluar. |
| Keluaran | Semua sesi akun ini berakhir; Hub kembali ke halaman masuk |
| Kode error | `401 session_revoked` |
| Antarmuka | RPC `cs_api.agent_signed_out_everywhere`; Hub: avatar → Keluar dari semua perangkat |
| Lacak | BR-HUB |

#### FR-HUB-12 Profil saya

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan profil akun staf yang sedang login secara hanya-baca. |
| Aktor | Staf |
| Prakondisi | Staf sudah login |
| Proses dan aturan | 1) Isi: email login, nama tampilan, kode staf, peran, tim, batas tiket aktif, bahasa layanan, izin Komunitas dan Akun Nasabah, tanggal dibuat, `password_changed_at` (dari audit `agent.password_changed`; "Belum tercatat" bila kosong). <br>2) Perubahan data hanya lewat Super Admin. |
| Keluaran | Dialog Profil saya |
| Kode error | `403 agent_required` |
| Antarmuka | RPC `cs_api.agent_my_profile`; Hub: avatar → Profil saya |
| Lacak | BR-HUB |

#### FR-HUB-13 Kinerja saya

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan angka kinerja agen CS untuk dirinya sendiri dengan definisi yang sama dengan Laporan Super Admin. |
| Aktor | CS (`cs_agent`) |
| Prakondisi | Akun berperan `cs_agent` |
| Proses dan aturan | 1) Periode `today`, `7d`, atau `30d` (WIB, menurut tanggal tiket dibuat). <br>2) Isi: tiket diselesaikan dari tiket yang ditangani, sedang ditangani, rata-rata respons pertama, rata-rata waktu selesai, rating rata-rata dan distribusi 1–5, jumlah pengaduan. <br>3) Hanya angka milik pemanggil. |
| Keluaran | Dialog Kinerja saya |
| Kode error | `400 invalid_period`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.agent_my_stats`; Hub: avatar → Kinerja saya |
| Lacak | BR-HUB |

#### FR-HUB-14 Membuat akun staf

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin membuat akun staf baru dengan password sementara yang hanya ditampilkan sekali. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin aktif |
| Proses dan aturan | 1) Edge function `cs-admin` memeriksa pemanggil Super Admin lewat `agent_me`. <br>2) Email divalidasi pola email dan diubah huruf kecil. <br>3) Password sementara 20 karakter acak dibuat di server; user GoTrue dibuat dengan `email_confirm`, `app_metadata.cs_staff = true`, `user_metadata.must_change_password = true`. <br>4) `cs_api.service_create_agent` (khusus service_role) menyimpan agen; nama tampilan 2–40 karakter, peran dari enam kode, tim aktif, batas tiket 1–20 (`cs.check_agent_input`, 0126). <br>5) Bila penyimpanan agen gagal, user GoTrue dihapus lagi. <br>6) Hub: minimal satu peran atau satu Izin Komunitas; Pengaturan CS (Tim, Batas tiket, Akses Akun Nasabah) hanya untuk peran CS. |
| Keluaran | `201` berisi agen dan `temporary_password` (sekali tampil) |
| Kode error | `400 invalid_email`; `409 email_exists`; `400 invalid_name`; `400 invalid_roles`; `400 invalid_team`; `400 invalid_limit`; `403 role_forbidden`; `401 session_expired` |
| Antarmuka | Edge function `cs-admin` `POST /agents`; RPC `cs_api.service_create_agent`; Hub: Pengaturan → Layanan CS → Akun CS → Tambah akun |
| Lacak | BR-HUB |

#### FR-HUB-15 Mengubah dan menonaktifkan akun staf

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin mengubah nama, peran, tim, dan batas tiket staf, serta menonaktifkan akun. |
| Aktor | Super Admin |
| Prakondisi | Akun target ada |
| Proses dan aturan | 1) Validasi sama dengan FR-HUB-14. <br>2) Super Admin tidak bisa menonaktifkan akun sendiri atau melepas peran Super Admin sendiri. <br>3) Nonaktif: `disabled_at` diisi, status agen menjadi offline, tiket aktif kembali ke antrean dengan alasan "Akun CS dinonaktifkan", transfer yang menunggu dibatalkan (`cs.retire_agent_work`), dan user GoTrue di-ban (`ban_duration` 876000h). <br>4) Melepas peran CS juga mengembalikan pekerjaan agen ("Peran CS diubah") dan mengosongkan izin Akun Nasabah. <br>5) Nama tampilan disalin ke profil sosial agen. Diaudit `agent.update`. |
| Keluaran | Tampilan akun diperbarui; akun nonaktif tidak bisa login |
| Kode error | `400 cannot_change_self`; `404 agent_not_found`; `400 invalid_roles`; `403 role_forbidden` |
| Antarmuka | Edge function `cs-admin` `PATCH /agents/{id}`; RPC `cs_api.admin_update_agent`; Hub: Pengaturan → Akun CS |
| Lacak | BR-HUB |

#### FR-HUB-16 Reset password staf

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin mereset password staf menjadi password sementara baru. |
| Aktor | Super Admin |
| Prakondisi | Akun target ada |
| Proses dan aturan | 1) Password sementara 20 karakter dibuat di server dan `must_change_password` diset `true`. <br>2) Password lama langsung tidak berlaku. <br>3) Password sementara hanya ditampilkan sekali dan diserahkan lewat jalur aman. |
| Keluaran | `temporary_password` (sekali tampil) |
| Kode error | `400 invalid_agent`; `404 agent_not_found`; `403 role_forbidden` |
| Antarmuka | Edge function `cs-admin` `POST /agents/{id}/reset-password`; RPC `cs_api.admin_reset_password`; Hub: Pengaturan → Akun CS → Reset password |
| Lacak | BR-HUB |

#### FR-HUB-17 Menu mengikuti peran dan izin

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan menu bilah atas sebagai gabungan peran dan izin akun, dan sistem harus menegakkan hak yang sama di RPC. |
| Aktor | Staf |
| Prakondisi | Staf sudah login |
| Proses dan aturan | 1) Pemetaan menu mengikuti tabel peran di atas; RPC menolak peran yang tidak cukup. <br>2) Akun Kepatuhan yang juga punya menu lain melihat menu bertingkat **Kepatuhan ▾**; akun yang hanya Kepatuhan melihat itemnya berjajar. <br>3) Menu **Akun Nasabah** hanya tampil bila akun punya izin Akun Nasabah dan integrasi aktif (`settings.nasabah_ready`); Hub memuat ulang izin setiap 60 detik tanpa login ulang. <br>4) Kesehatan sistem tidak tampil sebagai menu atas (`SHOW_SYSTEM_HEALTH_NAV = false`), tetapi di Pengaturan → Sistem. |
| Keluaran | Bilah atas sesuai hak akun |
| Kode error | `403 role_forbidden`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.agent_me`; Hub: `TopBar` |
| Lacak | BR-HUB |

#### FR-HUB-18 Mengatur Izin Komunitas

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin memberi atau mencabut lima izin Komunitas pada akun staf mana pun. |
| Aktor | Super Admin |
| Prakondisi | Akun target ada |
| Proses dan aturan | 1) Izin harus subset dari `cs.community_permission_codes()` (0057); duplikat dirapikan. <br>2) Hub menyediakan **Pilih semua** dan **Kosongkan** per grup izin. <br>3) Akun tanpa peran lain yang hanya diberi izin ini disimpan dengan peran `community`. <br>4) Diaudit `agent.community_permissions`. |
| Keluaran | Tab Komunitas akun target berubah |
| Kode error | `400 invalid_permission`; `404 agent_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_set_community_permissions`; Hub: Pengaturan → Akun CS |
| Lacak | BR-HUB |

#### FR-HUB-19 Mengatur Akses Akun Nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin mengatur tujuh izin Akun Nasabah hanya untuk akun berperan CS. |
| Aktor | Super Admin |
| Prakondisi | Akun target berperan `cs_agent` |
| Proses dan aturan | 1) Kotak centang hanya tampil untuk akun CS. <br>2) Database menolak izin untuk akun non-CS (constraint `agents_nasabah_permissions_check`, 0047). <br>3) Izin dikosongkan otomatis bila peran CS dicabut; akun nonaktif langsung kehilangan akses. <br>4) Diaudit `agent.nasabah_permissions`. |
| Keluaran | Hak menu Akun Nasabah akun target berubah tanpa login ulang |
| Kode error | `400 not_cs_agent`; `400 invalid_permission`; `404 agent_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_set_nasabah_permissions`; Hub: Pengaturan → Akun CS → Akses Akun Nasabah |
| Lacak | BR-HUB |

#### FR-HUB-20 Aturan empat mata

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin menyalakan atau mematikan tiga saklar persetujuan empat mata. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin |
| Proses dan aturan | 1) **Empat mata Komunitas** `community.four_eyes` (bawaan `true`): postingan dan notifikasi resmi Komunitas wajib disetujui staf lain (0057). <br>2) **Empat mata kebijakan konten** `compliance.policy_four_eyes` (bawaan `true`): perubahan kebijakan konten wajib disetujui staf Kepatuhan lain (0092). <br>3) **Empat mata notifikasi info Banner & Popup** `banners.notice_four_eyes` (bawaan `false`) (0182). <br>4) Setiap perubahan meminta konfirmasi yang menjelaskan risikonya dan diaudit `setting.update`. |
| Keluaran | Alur persetujuan modul terkait berubah seketika |
| Kode error | `400 invalid_setting`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_set_setting`, `cs_api.admin_set_policy_four_eyes`; Hub: Pengaturan → Persetujuan → Aturan empat mata |
| Lacak | BR-HUB |

#### FR-HUB-21 Kill switch fitur sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin atau peran Fitur & Banner mematikan dan menyalakan kembali seluruh fitur sosial untuk semua pengguna. |
| Aktor | Super Admin, Fitur & Banner |
| Prakondisi | Sesi staf berperan `cs_super_admin` atau `product` |
| Proses dan aturan | 1) Alasan 10–500 karakter wajib; Hub meminta mengetik **MATIKAN** atau **NYALAKAN** lalu konfirmasi akhir. <br>2) `private.kill_switch.social_enabled` diubah; diaudit `kill_switch.set` dengan nilai sebelumnya dan alasan. <br>3) Selama mati: postingan, komentar, edit, dan pesan chat non-CS baru ditolak; membaca, like, follow, dan reaksi tetap jalan; chat CS dan postingan staf, akun resmi, serta bot tetap berjalan. <br>4) Kill switch tidak mati sendiri. |
| Keluaran | Status kill switch di `feature_flags_view` |
| Kode error | `400 reason_required`; `400 invalid_kill_switch`; ke aplikasi: `403 social_disabled` (0109) |
| Antarmuka | RPC `cs_api.admin_set_kill_switch`; Hub: Komunitas → Fitur & versi → Kill switch fitur sosial |
| Lacak | BR-HUB |

#### FR-HUB-22 Saklar fitur aplikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin atau peran Fitur & Banner menyalakan dan mematikan delapan fitur aplikasi yang tetap. |
| Aktor | Super Admin, Fitur & Banner |
| Prakondisi | Sesi staf berperan `cs_super_admin` atau `product` |
| Proses dan aturan | 1) Daftar tetap (`private.known_feature_flags`, 0091): `search`, `trending`, `bookmarks`, `post_edit`, `message_reactions`, `share_post_to_chat`, `notification_prefs`, `analytics`. <br>2) Flag tidak bisa ditambah atau dihapus; `social.enabled` hanya lewat kill switch. <br>3) Hub membuka kunci dengan **Ubah**, setiap saklar meminta konfirmasi, lalu **Selesai**. <br>4) Diaudit `feature_flag.set` dengan nilai sebelum dan sesudah. <br>5) Berlaku saat aplikasi membaca konfigurasi klien berikutnya. |
| Keluaran | Daftar flag terbaru (`feature_flags_view`) |
| Kode error | `400 unknown_flag`; `400 invalid_flag`; `400 flag_not_deletable`; `400 use_kill_switch`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_feature_flags`, `cs_api.admin_toggle_feature_flag`; Hub: Komunitas → Fitur & versi |
| Lacak | BR-HUB |

#### FR-HUB-23 Versi minimum aplikasi per platform

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin atau peran Fitur & Banner mengatur versi minimum aplikasi per platform. |
| Aktor | Super Admin, Fitur & Banner |
| Prakondisi | Versi tersebut sudah tersedia di toko aplikasi |
| Proses dan aturan | 1) Platform: `android`, `ios`, `web`, `windows`, `macos`, `linux`. <br>2) Format versi `^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$`; kosong menghapus batas. <br>3) Form terkunci per baris (**Ubah** → **Simpan** → konfirmasi berisi risiko). <br>4) Diaudit `client.min_version_set` (sebelum, sesudah). <br>5) Penegakan di aplikasi dispesifikasikan di AKUN. |
| Keluaran | `private.client_versions` diperbarui |
| Kode error | `400 invalid_platform`; `400 invalid_version`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_set_min_version`; Hub: Komunitas → Fitur & versi |
| Lacak | BR-HUB |

#### FR-HUB-24 Tab Stream

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin atau peran Fitur & Banner menyalakan atau mematikan empat tab bawaan Stream. |
| Aktor | Super Admin, Fitur & Banner |
| Prakondisi | Sesi staf berperan `cs_super_admin` atau `product` |
| Proses dan aturan | 1) Hanya empat tab tetap dengan urutan tetap: `latest` (Terbaru), `top` (Teratas), `media` (Grafik & Media), `polls` (Polling) (constraint `feed_filters_builtin`, 0180). <br>2) Tab tidak bisa ditambah, dihapus, diubah, atau diurutkan ulang; RPC simpan, hapus, dan urut sudah dihapus (0180). <br>3) Tab mati disembunyikan dari aplikasi tanpa dihapus; bila semua mati, aplikasi tidak menampilkan pilihan tab. <br>4) Hub menampilkan **Pratinjau tab di aplikasi**. <br>5) Perubahan diaudit `feed_filter.enabled`. |
| Keluaran | Daftar tab terbaru |
| Kode error | `404 filter_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_feed_filters`, `cs_api.admin_set_feed_filter_enabled`; Hub: Komunitas → Tab Stream |
| Lacak | BR-HUB |

#### FR-HUB-25 Kelola Indeks

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf berizin Moderasi konten menambah, mengubah, mengurutkan, dan menghapus indeks pasar beserta aliasnya. |
| Aktor | Staf dengan `community.moderate` |
| Prakondisi | Izin `community.moderate` |
| Proses dan aturan | 1) Kode 2–24 karakter, huruf/angka, diawali huruf, boleh dipisah strip (mis. `SRI-KEHATI`); tidak bisa diubah setelah dibuat. <br>2) Nama 1–80 karakter; deskripsi maksimal 300; alias maksimal 10 dengan format sama, tidak boleh dipakai kode atau alias lain. <br>3) Saklar **Aktif** dan **Room diskusi dibuka**. <br>4) Sebelum simpan, `community_instrument_check` memeriksa dampak ke postingan, pemantau, dan room; simpan menandai ulang postingan lama dan memindahkan pemantau, mute, dan room alias ke kode utama. <br>5) Hapus menandai ulang postingan seperti kode biasa tanpa menghapus pemantau dan room. <br>6) Semua perubahan diaudit (0150). |
| Keluaran | Daftar indeks dengan pemakaian (postingan, pemantau, anggota room) |
| Kode error | `400 invalid_instrument_code`; `409 instrument_code_taken`; `400 invalid_instrument_name`; `400 invalid_instrument_description`; `400 invalid_instrument_alias`; `409 instrument_alias_taken`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_instruments`, `community_instrument_check`, `community_save_instrument`, `community_reorder_instruments`, `community_delete_instrument`; Hub: Komunitas → Indeks |
| Lacak | BR-HUB |

#### FR-HUB-26 Kelola akun resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf berizin Kelola akun resmi membuat, mengubah, menonaktifkan, dan mengaktifkan akun resmi perusahaan. |
| Aktor | Staf dengan `community.accounts` |
| Prakondisi | Izin `community.accounts` |
| Proses dan aturan | 1) Username 3–30 karakter (huruf, angka, garis bawah), unik; nama akun 2–60 karakter; bio maksimal 300 karakter (0058). <br>2) Foto diunggah lewat Hub setelah akun dibuat, dipotong di **Atur foto akun**, dengan pratinjau **Tampilan di aplikasi**. <br>3) Mengganti username membuat mention lama tidak lagi mengarah ke akun ini. <br>4) Nonaktif: akun tidak bisa dipakai untuk postingan atau notifikasi baru; postingan lama tetap tampil. <br>5) Akun resmi tidak bisa login dari aplikasi. Diaudit `community.account_create`, `community.account_update`, `community.account_disable`, `community.account_enable`. |
| Keluaran | Daftar akun resmi terbaru |
| Kode error | `400 invalid_username`; `409 username_taken`; `400 invalid_name`; `400 invalid_bio`; `400 invalid_avatar`; `404 account_not_found`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_accounts`, `community_save_account`, `community_set_account_disabled`; Hub: Komunitas → Akun resmi |
| Lacak | BR-HUB |

#### FR-HUB-27 Badge verifikasi pengguna

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf berizin Kelola akun resmi memberi atau mencabut badge verifikasi pengguna. |
| Aktor | Staf dengan `community.accounts` |
| Prakondisi | Identitas pengguna sudah diperiksa |
| Proses dan aturan | 1) Alasan 5–300 karakter wajib. <br>2) Akun resmi selalu terverifikasi dan tidak bisa diubah. <br>3) Diaudit `community.verify_user`. |
| Keluaran | Status `is_verified` pengguna berubah |
| Kode error | `400 reason_required`; `404 user_not_found`; `400 official_account`; `403 community_forbidden` |
| Antarmuka | RPC `cs_api.community_set_verified`; Hub: Komunitas → Akun resmi → Verifikasi / Cabut verifikasi |
| Lacak | BR-HUB |

#### FR-HUB-28 Menyusun postingan resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf berizin Tulis postingan resmi membuat draf postingan atau pengumuman atas nama akun resmi aktif. |
| Aktor | Staf dengan `community.post` |
| Prakondisi | Ada akun resmi aktif |
| Proses dan aturan | 1) Jenis **Postingan** atau **Pengumuman**; pengumuman wajib berjudul 3–80 karakter dan selalu disematkan. <br>2) Isi 1–2000 karakter; `$KODE` menautkan saham atau indeks; kata terlarang ditolak; lampiran gambar divalidasi di folder `posts/<akun>/`. <br>3) Sematan: tidak disematkan, stream umum, atau stream saham/indeks; **Sematkan sampai** harus setelah waktu terbit. <br>4) Opsional **Kirim notifikasi saat terbit**; waktu terbit segera setelah disetujui atau dijadwalkan. <br>5) Hanya pembuat yang bisa mengubah draf berstatus draft, rejected, atau failed; **Simpan & ajukan** mengubah status ke pending (audit `community.post_submit`). |
| Keluaran | Draf atau pengajuan postingan resmi |
| Kode error | `400 official_inactive`; `400 invalid_kind`; `400 invalid_title`; `400 invalid_body`; `400 invalid_pin`; `400 invalid_stock`; `400 invalid_pin_until`; `403 not_post_owner`; `409 invalid_status`; `404 post_not_found` |
| Antarmuka | RPC `cs_api.community_save_post`, `cs_api.community_submit_post`; Hub: Komunitas → Postingan resmi → Buat postingan |
| Lacak | BR-HUB |

#### FR-HUB-29 Persetujuan postingan resmi (empat mata)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mewajibkan persetujuan staf lain berizin Setujui & terbitkan sebelum postingan resmi terbit selama empat mata Komunitas aktif. |
| Aktor | Staf dengan `community.publish` |
| Prakondisi | Postingan berstatus pending |
| Proses dan aturan | 1) **Setujui & terbitkan** atau **Setujui & jadwalkan**; penerbitan terjadwal dijalankan job `cs-community` (tiap 15 detik). <br>2) Pembuat tidak bisa menyetujui buatannya sendiri bila `community.four_eyes` aktif. <br>3) Bila empat mata mati, pembuat yang juga berizin publish boleh memutuskan drafnya sendiri. <br>4) **Tolak** wajib catatan 5–500 karakter; draf kembali ke pembuat. <br>5) Akun resmi yang sudah nonaktif membatalkan persetujuan. Diaudit `community.post_approve` atau `community.post_reject`. |
| Keluaran | Postingan terbit, terjadwal, atau ditolak |
| Kode error | `403 four_eyes`; `409 invalid_status`; `400 note_required`; `400 official_inactive`; `404 post_not_found` |
| Antarmuka | RPC `cs_api.community_review_post`; Hub: Komunitas → Postingan resmi → Perlu ditinjau |
| Lacak | BR-HUB |

#### FR-HUB-30 Sematan, pembatalan, dan penghapusan postingan resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan staf berizin mengatur sematan postingan resmi yang sudah terbit, membatalkan postingan yang belum terbit, dan menghapusnya dari stream. |
| Aktor | Staf dengan `community.publish`; pembuat (pembatalan) |
| Prakondisi | Postingan ada |
| Proses dan aturan | 1) **Lepas sematan** dan **Sematkan lagi** hanya untuk postingan terbit; batas sematan harus di masa depan (audit `community.post_pin`, `community.post_unpin`). <br>2) **Batalkan**: pembuat untuk draf, pending, terjadwal, ditolak, atau gagal; staf publish untuk pending atau terjadwal (audit `community.post_cancel`). <br>3) **Hapus dari stream** hanya untuk postingan terbit, alasan 5–500 karakter, konten diarsipkan untuk audit (audit `community.post_delete`). <br>4) Status **Gagal terbit** menampilkan alasan dan bisa diajukan lagi. |
| Keluaran | Status postingan dan sematan diperbarui |
| Kode error | `409 invalid_status`; `400 invalid_pin`; `400 invalid_pin_until`; `400 reason_required`; `404 post_not_found` |
| Antarmuka | RPC `cs_api.community_pin_post`, `community_cancel_post`, `community_delete_post`, `community_posts`; Hub: Komunitas → Postingan resmi |
| Lacak | BR-HUB |

#### FR-HUB-31 Analitik komunitas

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan analitik komunitas agregat kepada Super Admin tanpa memuat teks pengguna. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin |
| Proses dan aturan | 1) Rentang tanggal maksimal 366 hari dan tanggal awal tidak lebih besar dari tanggal akhir. <br>2) Isi: DAU, WAU, MAU, konten, retensi mingguan, **Saham paling dibahas**, **Dari sosial ke order**. <br>3) Sumber event klien dispesifikasikan di KOM; retensi data analitik di OPS. |
| Keluaran | Tab Analitik |
| Kode error | `400 invalid_range`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_analytics`; Hub: Komunitas → Analitik |
| Lacak | BR-HUB |

#### FR-HUB-32 Command palette dan pintasan keyboard

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menyediakan command palette untuk mencari tiket, nasabah, menu, dan perintah, serta pintasan keyboard. |
| Aktor | Staf |
| Prakondisi | Staf sudah login |
| Proses dan aturan | 1) Dibuka dengan Ctrl K atau kotak cari di bilah atas. <br>2) Hasil dibatasi hak akun (menu dan perintah yang tidak boleh diakses tidak muncul). <br>3) Pintasan: J/K tiket berikutnya/sebelumnya, A ambil, R kotak balas, N catatan internal, E selesaikan, Ctrl Enter kirim, ? daftar pintasan. |
| Keluaran | Navigasi atau aksi terpilih dijalankan |
| Kode error | — |
| Antarmuka | Hub: `CommandPalette`, `ShortcutsDialog` |
| Lacak | BR-HUB |

#### FR-HUB-33 Bahasa, tema, dan kepadatan tampilan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan staf memilih bahasa tampilan Indonesia atau Inggris, tema, dan kepadatan. |
| Aktor | Staf |
| Prakondisi | — |
| Proses dan aturan | 1) Bahasa: Indonesia atau English (teks UI di file i18n Hub). <br>2) Tema: Terang, Gelap, atau Ikuti sistem. <br>3) Kepadatan: Nyaman atau Padat. <br>4) Waktu di Hub selalu WIB. <br>5) Pesan sistem tiket ditampilkan sesuai bahasa yang dipilih (rincian di CS). |
| Keluaran | Tampilan Hub berubah tanpa memuat ulang |
| Kode error | — |
| Antarmuka | Hub: avatar → Tema, Kepadatan, Bahasa |
| Lacak | BR-HUB |

### 4.10 Integrasi OLT (INT)

Modul ini mengatur semua titik temu antara Rendezvous dan sistem OLT. Prinsipnya: data bisnis trading (harga, order, dana, portofolio, data akun) tetap milik OLT, dan arah panggilan selalu dari OLT ke server sosial, kecuali satu jalur staf ke csAdmin lewat nasabah-gateway. Ada lima permukaan integrasi:

1. **Kontrak token sosial**: backend OLT menandatangani JWT (EdDSA atau ES256), auth-bridge memverifikasinya secara lokal dengan JWKS OLT di `docker/secrets/olt_jwks` (docs/olt-integration.md). Penukaran token menjadi sesi sosial 15 menit dan pembuatan profil dispesifikasikan di AKUN; modul ini mencakup isi dan aturan token, kunci, tautan rekening, dan status integrasi di Hub.
2. **API `/integration/v1`** (layanan `integration` 0.2.0): notifEngine dan sistem OLT lain mengirim notifikasi transaksi per `cust_id`, notifikasi per login, siaran, dan postingan bot resmi memakai API key `oik_…` yang dibuat Super Admin di Hub (0068, 0086, 0101, 0171).
3. **Gateway Akun Nasabah** (`nasabah-gateway`): menu Akun Nasabah di Hub diteruskan ke rute staf `/online/*` csAdmin dengan token integrasi Ed25519 (docs/nasabah/README.md, 0044–0050, 0055, 0186).
4. **Data saham dan navigasi** di library: daftar dan nama saham disediakan aplikasi OLT lewat callback (`stockSearch`, `stockInfo`, `onStockTap`), dan tautan dibuka router OLT (`onBannerLink`, `onOltNotificationTap`).
5. **OLT tiruan** (`dummy-olt`) khusus pengembangan.

#### FR-INT-01 Tanpa panggilan ke OLT saat login

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memverifikasi login nasabah tanpa membuka koneksi apa pun ke sistem OLT. |
| Aktor | auth-bridge |
| Prakondisi | `AUTH_BRIDGE_OLT_MODE=jwt` (bawaan) |
| Proses dan aturan | 1) Mode `jwt` memverifikasi token sosial dengan JWKS lokal; auth-bridge tidak tersambung ke network `egress`. <br>2) Mode `mock` (format `mock:<id>:<username>`) ditolak saat `APP_ENV=production`. <br>3) Mode `websocket` (cara lama, bertanya ke WebSocket OLT) masih ada di kode tetapi tidak dipasang di compose; hanya bisa dipakai dengan override compose sendiri. <br>4) Bila OLT lambat atau mati, sesi sosial yang sudah ada tetap berjalan sampai habis. |
| Keluaran | Login sosial tidak bergantung pada ketersediaan OLT |
| Kode error | `503 olt_unavailable` (hanya mode `websocket`) |
| Antarmuka | `POST /bridge/v1/exchange`; konfigurasi `AUTH_BRIDGE_OLT_MODE` |
| Lacak | BR-INT |

#### FR-INT-02 Format token sosial dan identitas stabil

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima token sosial OLT hanya bila memuat klaim wajib, dan menurunkan ID sosial yang stabil dari `sub`. |
| Aktor | Backend OLT (penerbit); auth-bridge |
| Prakondisi | OLT menerbitkan token saat login dan setiap kali aplikasi meminta token baru |
| Proses dan aturan | 1) Klaim wajib: `iss` (= `OLT_JWT_ISSUER`, bawaan `olt`), `aud` string atau array yang memuat `OLT_JWT_AUDIENCE` (bawaan `olt-social`), `sub` (string, ID user OLT yang tidak pernah berubah), `preferred_username`, `iat`, `exp`. <br>2) Klaim opsional: `name`, `email`, `jti`, `nbf`, `accounts`. <br>3) Panjang token maksimal 16 KB; body exchange maksimal 17 KB. <br>4) ID sosial = UUIDv5(namespace `0b7f6c1e-5a2d-4c8e-9f3b-7d1a2e4c6f80`, `sub`); namespace tidak boleh diubah; `sub` yang berubah dianggap user lain. <br>5) JWT sosial yang diterbitkan tidak memuat email, username, atau `olt_user_id`. |
| Keluaran | Klaim tervalidasi diteruskan ke penukaran sesi (AKUN) |
| Kode error | `400 invalid_request`; `401 invalid_token` |
| Antarmuka | `POST /bridge/v1/exchange`; docs/olt-integration.md bagian 3 |
| Lacak | BR-INT |

#### FR-INT-03 Verifikasi tanda tangan dan waktu token

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menolak token sosial yang algoritma, tanda tangan, atau masa berlakunya tidak memenuhi kontrak. |
| Aktor | auth-bridge |
| Prakondisi | JWKS termuat saat start |
| Proses dan aturan | 1) Hanya `EdDSA` (Ed25519) dan `ES256` (P-256), dan harus cocok dengan jenis kunci dari `kid`; `none`, `HS*`, `RS*` ditolak. <br>2) `kid` wajib bila JWKS berisi lebih dari satu kunci. <br>3) Base64url tanda tangan wajib kanonik. <br>4) `exp - iat` ≤ `OLT_JWT_MAX_TTL` (bawaan 900 detik); toleransi jam `OLT_JWT_LEEWAY` (bawaan 30 detik). <br>5) Alasan penolakan hanya dicatat di log (`reason`); token tidak pernah ditulis ke log, metrik, atau cache (cache memakai SHA-256 token). |
| Keluaran | Token diterima atau ditolak |
| Kode error | `401 invalid_token` |
| Antarmuka | `POST /bridge/v1/exchange` |
| Lacak | BR-INT |

#### FR-INT-04 Pengelolaan JWKS, rotasi, dan pencabutan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memakai kunci publik OLT dari file JWKS server, menolak kunci dev di produksi, dan mendukung rotasi kunci tanpa henti layanan. |
| Aktor | Tim server sosial; tim OLT |
| Prakondisi | Tim OLT menyerahkan JWKS (tidak rahasia) |
| Proses dan aturan | 1) JWKS disimpan di `docker/secrets/olt_jwks` dan dibaca sekali saat start auth-bridge. <br>2) `kid` berawalan `dev-` ditolak saat `APP_ENV=production` sehingga auth-bridge tidak mau start dengan kunci dev. <br>3) Rotasi: OLT membuat kunci dengan `kid` baru, tim server menambahkannya ke JWKS lalu restart auth-bridge, OLT mulai menandatangani dengan kunci baru, kunci lama dihapus setelah token lama habis (≤ 15 menit). <br>4) Pencabutan: OLT berhenti menerbitkan token untuk akun yang disuspend atau logout; akses sosial berakhir paling lambat setelah token terakhir dan sesi sosial habis (≤ 15 menit). <br>5) Kunci tidak bisa diganti dari Hub. |
| Keluaran | auth-bridge memakai set kunci terbaru setelah restart |
| Kode error | — |
| Antarmuka | `docker/secrets/olt_jwks`; `make up` |
| Lacak | BR-INT |

#### FR-INT-05 Klaim `accounts` dan tautan rekening

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan rekening (cust id) milik login OLT dari klaim `accounts` token sosial sebagai dasar notifikasi transaksi. |
| Aktor | auth-bridge; Super Admin (batas) |
| Prakondisi | Token sosial sah |
| Proses dan aturan | 1) Klaim tidak ada atau `null`: tautan tidak diubah; array: tautan diganti persis isinya; `[]`: semua tautan dilepas; bukan array: diabaikan (metrik `malformed`), token tetap diterima. <br>2) Item `^[A-Za-z0-9._-]{1,32}$`, disimpan huruf besar; item tidak valid dan duplikat diabaikan; maksimal 200 item. <br>3) Database membatasi lagi dengan `accounts.max_per_customer` (bawaan 200, 1–200, diatur Super Admin di Hub, 0128); kelebihan dihitung `accounts_ignored`. <br>4) Disimpan di `private.account_links` dengan `seen_at` setelah upsert profil; tautan yang tidak diperbarui `integration.account_link_days` (30) hari tidak dipakai dan dibersihkan. <br>5) Gagal simpan tidak menggagalkan exchange; hasil exchange tidak di-cache agar dicoba lagi. <br>6) Tidak ditautkan selama jeda bergabung lagi (0175); dihapus saat akun dihapus. Log hanya memuat jumlah rekening. |
| Keluaran | Pemetaan `cust_id` ke profil |
| Kode error | `400 invalid_setting` (batas di Hub) |
| Antarmuka | RPC `public.set_olt_account_links` (service_role); RPC `cs_api.admin_set_setting` key `accounts.max_per_customer`; Hub: Pengaturan → Integrasi → Integrasi aplikasi → Batas rekening per nasabah |
| Lacak | BR-INT |

#### FR-INT-06 Status integrasi aplikasi di Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan data koneksi untuk tim aplikasi OLT dan status login OLT secara hanya-baca kepada Super Admin. |
| Aktor | Super Admin |
| Prakondisi | auth-bridge mengirim heartbeat |
| Proses dan aturan | 1) auth-bridge memanggil `service_heartbeat` saat start dan tiap 30 detik (`HEARTBEAT_INTERVAL`, 5–60) dengan mode OLT, daftar `kid` + `alg` (maks 20), issuer, audience, max TTL; isi kunci tidak pernah dikirim. <br>2) Instance dianggap aktif bila heartbeat ≤ 3 menit; status **Aktif**, **Peringatan**, atau **Tidak ada heartbeat**. <br>3) Peringatan bila ada `kid` berawalan `dev-`, mode bukan `jwt` di luar development, atau instance memakai kunci berbeda. <br>4) Data koneksi (URL API, anon key, contoh `config/prod.json`, versi library minimum, versi minimum aplikasi per platform) bisa disalin. <br>5) Login nasabah terakhir (WIB) dan jumlah nasabah login 24 jam tanpa data pribadi. |
| Keluaran | Halaman Integrasi aplikasi |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.app_integration_overview` (0114); Hub: Pengaturan → Integrasi → Integrasi aplikasi |
| Lacak | BR-INT |

#### FR-INT-07 Membuat API key integrasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin membuat API key integrasi berizin terbatas yang hanya ditampilkan sekali. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin |
| Proses dan aturan | 1) Nama key 3–80 karakter. <br>2) Izin subset `notify` (Notifikasi per rekening), `notify_broadcast` (Notifikasi massal, wajib disertai `notify`), `bot_post` (Postingan bot, wajib memilih akun resmi aktif). <br>3) Daftar IP/CIDR yang diizinkan (kosong = tanpa batas IP). <br>4) Batas request per menit 1–100000, bawaan 3000 (0101). <br>5) Key berbentuk `oik_` + 32 byte acak base64url; yang disimpan hanya hash SHA-256 dan prefix 8 karakter. <br>6) Diaudit `integration.key_create` tanpa isi key. |
| Keluaran | Key penuh di respons sekali saja beserta tampilan key |
| Kode error | `400 invalid_name`; `400 invalid_rate_limit`; `400 official_required`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.integration_key_create`; Hub: Pengaturan → Integrasi → API Notifikasi → Buat API key |
| Lacak | BR-INT |

#### FR-INT-08 Mengubah, menonaktifkan, mencabut, dan merotasi API key

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin mengubah, menonaktifkan sementara, dan mencabut permanen API key integrasi. |
| Aktor | Super Admin |
| Prakondisi | Key ada |
| Proses dan aturan | 1) Ubah nama, izin, akun resmi, CIDR, batas, atau `enabled`; key yang sudah dicabut tidak bisa diubah. <br>2) Cabut permanen wajib alasan 5–500 karakter. <br>3) Key dicabut atau nonaktif langsung ditolak: cache layanan paling lama 30 detik dan database memeriksa ulang setiap batch. <br>4) Rotasi: buat key baru, pasang di sistem pengirim, pastikan **Terakhir dipakai** bergerak, baru cabut key lama; rotasi memulai catatan idempotensi baru. <br>5) Diaudit `integration.key_update`, `integration.key_revoke`. |
| Keluaran | Daftar key (`integration_keys`) dengan status, terakhir dipakai, dan IP |
| Kode error | `404 key_not_found`; `409 key_revoked`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.integration_keys`, `integration_key_update`, `integration_key_revoke`; Hub: Pengaturan → Integrasi → API Notifikasi |
| Lacak | BR-INT |

#### FR-INT-09 Autentikasi dan batas request `/integration/v1`

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memeriksa API key, IP, izin, dan batas ukuran sebelum batch integrasi diteruskan ke database. |
| Aktor | Layanan `integration` |
| Prakondisi | Header `apikey` (anon) dan `Authorization: Bearer oik_…` |
| Proses dan aturan | 1) Lebih dari `AUTH_FAILURES_PER_MINUTE` (30) key salah atau hilang dari satu IP ditolak tanpa menyentuh database. <br>2) Hanya hash SHA-256 key yang dikirim ke `integration_authenticate`; hasil di-cache per (hash, IP) selama `KEY_CACHE_TTL` (30 detik). <br>3) IP di luar `allowed_cidrs` ditolak; `/notify/messages` butuh `notify`, `/bot/posts` butuh `bot_post`. <br>4) Rate limit per key per menit (per instance; dengan N replika batas efektif N kali). <br>5) Body maksimal 2 MiB; `messages` 1–500 atau `posts` 1–50. <br>6) Maksimal `MAX_CONCURRENT` (8) batch paralel; menunggu slot > 5 detik ditolak. <br>7) Setiap respons membawa `X-Request-Id`; isi pesan dan cust id tidak dicatat di log. |
| Keluaran | Batch diproses atau ditolak dengan format `{"error","message"}` |
| Kode error | `400 invalid_json`; `400 invalid_batch`; `401 missing_key`; `401 invalid_key`; `403 ip_not_allowed`; `403 scope_forbidden`; `413 body_too_large`; `429 rate_limited`; `429 too_many_auth_failures`; `503 unavailable`; `503 busy` |
| Antarmuka | `POST /integration/v1/notify/messages`, `POST /integration/v1/bot/posts`; RPC `public.integration_authenticate` |
| Lacak | BR-INT |

#### FR-INT-10 Notifikasi transaksi per rekening (`cust_id`)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengantarkan notifikasi transaksi dari notifEngine ke semua perangkat pemilik rekening yang tertaut. |
| Aktor | notifEngine OLT |
| Prakondisi | Key berizin `notify`; rekening tertaut lewat klaim `accounts` |
| Proses dan aturan | 1) Field: `id` `^[A-Za-z0-9._:-]{1,100}$` (wajib), `cust_id`, `kind` (berawalan `olt.`, maks 40, bawaan `olt.trade`), `title` 1–200 atau `{id,en}` (wajib), `body` ≤ 1000, `data` ≤ 2 KB, `ttl_seconds` 60–2419200 (bawaan 24 jam), `collapse_key` 1–64, `priority` `high`/`normal`, `channels` subset `push`/`inbox` (bawaan `["push"]`), `category` `important`/`info`/`promo`. <br>2) Diproses sinkron dalam satu transaksi per batch. <br>3) Satu rekening boleh tertaut ke beberapa login; semua menerima. <br>4) Server menambahkan `kind`, `source: "olt"`, `message_id`, `cust_id`, `category`, `notification_id` ke data push. <br>5) Pengiriman FCM oleh notifier (NOTIF). |
| Keluaran | `200` dengan `results` per pesan: `queued` (+`devices`, `inbox`), `no_recipient`, `duplicate`, `invalid` (+`error`) |
| Kode error | Per pesan: `invalid_message`, `invalid_id`, `invalid_cust_id`, `invalid_target`, `invalid_kind`, `invalid_title`, `invalid_body`, `invalid_data`, `invalid_ttl`, `invalid_collapse_key`, `invalid_priority`, `invalid_channels`, `invalid_category` |
| Antarmuka | `POST /integration/v1/notify/messages`; RPC `public.integration_notify` |
| Lacak | BR-INT |

#### FR-INT-11 Notifikasi per login (`olt_user_id`)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengantarkan notifikasi pribadi yang terikat ke satu login OLT, misalnya alert harga, secara sinkron. |
| Aktor | Sistem OLT (mesin alert harga) |
| Prakondisi | Key berizin `notify` |
| Proses dan aturan | 1) `target: {"olt_user_id": "<sub>"}`, string atau angka `^[A-Za-z0-9._-]{1,64}$` (0171). <br>2) Tidak boleh digabung dengan `cust_id` atau target lain. <br>3) Login tanpa profil sosial aktif atau sudah dihapus dijawab `no_recipient`. <br>4) Tidak dihitung batas siaran harian dan tidak tercatat di daftar siaran Hub. <br>5) Bawaan `channels` `["push","inbox"]`; data push tidak memuat `cust_id`. |
| Keluaran | `queued` + `devices` (+ `inbox`) atau `no_recipient` |
| Kode error | Per pesan: `invalid_target` |
| Antarmuka | `POST /integration/v1/notify/messages` |
| Lacak | BR-INT |

#### FR-INT-12 Siaran ke banyak nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima siaran ke daftar login, semua pengguna, atau pemantau satu saham secara asinkron dengan batas frekuensi per nasabah. |
| Aktor | Sistem OLT tepercaya |
| Prakondisi | Key berizin `notify` dan `notify_broadcast` |
| Proses dan aturan | 1) Target `{"olt_user_ids": [...]}` (1–500 id), `{"audience": "all"}` (profil aktif, bukan akun resmi atau staf), `{"audience": "stock_watchers", "stock": "BBCA"}` (kode `^[A-Z][A-Z0-9]{1,11}$`). <br>2) Tiap pesan menjadi satu job `private.integration_broadcasts` dan langsung dijawab `accepted` + `broadcast_id`. <br>3) Job `integration-broadcasts` (tiap 15 detik) memproses `integration.broadcast_batch_size` (2000) profil per putaran. <br>4) Selain `important`, maksimal `integration.broadcast_daily_cap` (3) siaran per nasabah per hari WIB gabungan semua key; yang melewati batas dihitung `capped`. <br>5) Status `queued` → `sending` → `done`, atau `failed` (`key_inactive` bila key dinonaktifkan atau izin dicabut). <br>6) Push dan kotak masuk memuat `broadcast_id` (0088). Key tanpa `notify_broadcast` mendapat `invalid` + `scope_forbidden` per pesan. |
| Keluaran | `accepted` + `broadcast_id`; penghitung `targeted`, `recipients`, `devices`, `inbox`, `capped`, `pref_skipped` |
| Kode error | Per pesan: `scope_forbidden`, `invalid_target` |
| Antarmuka | `POST /integration/v1/notify/messages`; cron `integration-broadcasts` |
| Lacak | BR-INT |

#### FR-INT-13 Kategori pesan dan jenis preferensi OLT

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memetakan `kind` dan `category` pesan OLT ke jenis preferensi nasabah sebelum mengantarkannya. |
| Aktor | Database (`private.push_allowed_for`) |
| Prakondisi | Pesan valid |
| Proses dan aturan | 1) `olt.trade*` dan `olt.order*` → Transaksi; `olt.deposit*`, `olt.withdrawal*`, `olt.rdn*` → Dana; `olt.price_alert*`, `olt.ipo*`, `olt.corporate_action*` → Pasar; `olt.*` lain → Info; `category: "promo"` → Promo (push opt-in). <br>2) `important` menembus preferensi per jenis dan jam tenang serta tidak dihitung batas siaran; `info` (bawaan) dan `promo` mengikuti preferensi dan jam tenang. <br>3) Pengaturan preferensi oleh nasabah dispesifikasikan di NOTIF. |
| Keluaran | Pesan diantarkan, ditunda jam tenang, atau dilewati (`no_recipient`, `pref_skipped`) |
| Kode error | Per pesan: `invalid_category` |
| Antarmuka | RPC `public.integration_notify` |
| Lacak | BR-INT |

#### FR-INT-14 Idempotensi dan kirim ulang

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menjamin pesan dengan `id` yang sama dari key yang sama dalam 7 hari tidak menimbulkan notifikasi kedua. |
| Aktor | Database |
| Prakondisi | — |
| Proses dan aturan | 1) `id` diingat per key selama `integration.receipt_days` (7) di `private.integration_receipts`. <br>2) Kiriman ulang dijawab `duplicate`; untuk siaran menyertakan `broadcast_id` pertama. <br>3) Satu batch satu transaksi: gagal di tengah berarti tidak ada yang tersimpan, sehingga kirim ulang batch yang sama aman. <br>4) Pesan `invalid` tidak dicatat sehingga `id` boleh dipakai lagi setelah diperbaiki. <br>5) Job `integration-maintenance` (menit ke-23 tiap jam) membersihkan id lama, tautan kedaluwarsa, statistik > 400 hari, batas harian, dan siaran selesai > `integration.broadcast_days` (90). |
| Keluaran | Status `duplicate` |
| Kode error | — |
| Antarmuka | `POST /integration/v1/notify/messages` |
| Lacak | BR-INT |

#### FR-INT-15 Postingan bot resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan sistem otomatis memposting atas nama satu akun resmi tanpa persetujuan empat mata, tetap melalui kebijakan konten. |
| Aktor | Sistem berita atau aksi korporasi |
| Prakondisi | Key berizin `bot_post` yang terikat ke akun resmi aktif |
| Proses dan aturan | 1) `id` `^[A-Za-z0-9._:-]{1,100}$`, unik per key selamanya; `body` 1–2000 karakter, maks 3 link, 10 mention, 10 kode saham. <br>2) Maks 50 postingan per request dan `integration.bot_posts_per_hour` (30) per key per jam (dihitung di database, berlaku global). <br>3) Teks melewati `private.validate_text` dan `private.apply_content_policy`; penolakan dibatalkan per postingan (savepoint). <br>4) Postingan langsung diterbitkan dan diberi label **Bot** di feed (`private.post_is_bot`). |
| Keluaran | Per postingan: `published` (+`post_id`, `moderation_status` `visible`/`held`), `duplicate`, `rejected` (+`error`), `invalid`, `rate_limited` |
| Kode error | `409 official_inactive` (batch); per postingan: `invalid_id`, `invalid_body`, `content_blocked`, `too_many_links` |
| Antarmuka | `POST /integration/v1/bot/posts`; RPC `public.integration_bot_post` |
| Lacak | BR-INT |

#### FR-INT-16 Statistik integrasi dan daftar siaran

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan statistik penggunaan per API key dan daftar siaran terbaru kepada Super Admin. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin |
| Proses dan aturan | 1) Per key: diterima, masuk antrean, perangkat, tanpa penerima, duplikat, tidak valid, siaran diterima, kotak masuk, postingan bot, ringkasan siaran, dan hasil kirim FCM (terkirim, gagal, token mati, kedaluwarsa, menunggu). <br>2) Statistik harian dipotong per tanggal WIB; `private.integration_daily` disimpan 400 hari. <br>3) Daftar siaran maksimal 200 baris berisi target, status, penghitung, `opened`/`tapped` pengguna unik dan `open_rate`/`tap_rate` (persen dari `recipients`, `null` bila 0). |
| Keluaran | Kartu statistik dan dialog Broadcast |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.integration_stats`, `integration_stats_daily`, `integration_broadcasts`; Hub: Pengaturan → Integrasi → API Notifikasi |
| Lacak | BR-INT |

#### FR-INT-17 Konfigurasi integrasi API Nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin mengatur alamat dan client id CS Admin service dari Hub, dan hanya menyimpannya setelah tes koneksi berhasil. |
| Aktor | Super Admin (sesi `aal2`) |
| Prakondisi | Kunci privat `docker/secrets/csadmin_signing_key` ada (dibuat `make gen-secrets`) |
| Proses dan aturan | 1) Alamat hanya `http(s)://host[:port][/path]` tanpa login, query, atau fragment, divalidasi di database dan gateway. <br>2) **Simpan & aktifkan** menjalankan tes; bila gagal, tidak ada yang disimpan (`saved = false`). Penyimpanan lewat `admin_set_setting` ditolak (0055). <br>3) Hasil tes: `ok`, `refused`, `ip_not_allowed`, `disabled`, `unexpected`, `unreachable`, `not_configured`, `no_key`. <br>4) **Putuskan** menonaktifkan integrasi dan menyembunyikan menu Akun Nasabah. <br>5) Gateway membaca konfigurasi paling lama tiap 15 detik dan tetap memakai nilai terakhir bila database tidak terbaca. <br>6) Halaman menampilkan blok config siap tempel berisi kunci publik. Diaudit `setting.nasabah_integration`, `setting.nasabah_integration_cleared`. |
| Keluaran | `{saved, check, status}`; badge "Belum diatur" sampai aktif |
| Kode error | `403 permission_denied` (bukan Super Admin `aal2`); `403 setting_locked`; `503 not_configured` |
| Antarmuka | `GET/PUT/DELETE /api-nasabah/integration`, `POST /api-nasabah/integration/test`; RPC `cs_api.nasabah_save_integration`, `cs_api.nasabah_integration`, `cs_api.nasabah_is_super_admin`; Hub: Pengaturan → Integrasi → Integrasi API Nasabah |
| Lacak | BR-INT |

#### FR-INT-18 Token integrasi Ed25519 ke csAdmin

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memperoleh token csAdmin dengan assertion Ed25519 tanpa memakai akun staf csAdmin. |
| Aktor | nasabah-gateway |
| Prakondisi | Kunci publik terpasang di blok `integration` config csAdmin |
| Proses dan aturan | 1) Assertion JWT `EdDSA` berumur 60 detik dengan `iss` = `sub` = client id, `aud` = `csAdminEL`, `iat`, `exp`, `jti` acak, dikirim ke `POST /integration/token`. <br>2) csAdmin memeriksa tanda tangan, client id, audience, umur (maks 120 detik, toleransi 30 detik), `jti` belum dipakai, dan IP (`allowed_ips` opsional). <br>3) csAdmin menerbitkan token HS256 berumur `duration_token_minutes` (1–60, bawaan 15). <br>4) Gateway meminta token baru satu menit sebelum habis atau segera setelah csAdmin menjawab 401. <br>5) Batas waktu panggilan `CSADMIN_TIMEOUT` (bawaan 15s). |
| Keluaran | Token csAdmin tersimpan di memori gateway |
| Kode error | `503 not_configured`; `503 integration_refused` |
| Antarmuka | csAdmin `POST /integration/token` |
| Lacak | BR-INT |

#### FR-INT-19 Penegakan izin dan rute gateway Akun Nasabah

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus meneruskan permintaan menu Akun Nasabah ke csAdmin hanya untuk rute yang diizinkan, sesuai izin akun CS, dan mencatat setiap aksi tulis. |
| Aktor | nasabah-gateway; CS berizin |
| Prakondisi | Integrasi aktif; akun berperan `cs_agent` dengan izin Akun Nasabah |
| Proses dan aturan | 1) Token sesi Hub diverifikasi; izin dibaca lewat `cs_api.nasabah_access(user, aal)` (service_role, cache 30 detik, penolakan 5 detik) dan staf yang wajib 2FA harus `aal2` (0186). <br>2) Hanya rute `/online/*` dalam daftar; `/cs/*`, `/auto-update/*`, `/otp/*`, `/integration/token`, rute publik nasabah, dan pengirim kredensial tanpa login tidak dibuka. <br>3) Query dibatasi parameter dikenal: `page` 1–999999, `size` 1–100, LoginId `[A-Za-z0-9._@-]` maks 50, email maks 100. <br>4) Guard: demo-only, email penerima reset dari data csAdmin, status 0–3 dengan alasan 10–200, pengajuan sendiri butuh `online_user.approve_own` dan pengajuan CS lain butuh `online_user.approve`, daftar tautan rekening maks 255 karakter. <br>5) Kolom pelaku (`CreatedBy`, `ApprovedBy`, `ModifiedBy`, `CSLoginId`) ditimpa kode CS. <br>6) Aksi tulis diaudit (`nasabah.*`) dengan nama field tanpa nilai. <br>7) `GET /online/duplicates` dihitung di gateway dengan cache 5 menit. |
| Keluaran | Respons csAdmin diteruskan ke Hub |
| Kode error | `403 no_access`; `404 route_not_found`; `400 invalid_query`; `400 invalid_login_id`; `400 invalid_account_link`; `400 too_many_accounts`; `400 links_client_only`; `502 upstream_outdated`; `503 not_configured`; `503 integration_refused` |
| Antarmuka | `/api-nasabah/online/...`; RPC `cs_api.nasabah_access`, `cs_api.ticket_customer_login`; Hub: menu Akun Nasabah, panel Info nasabah |
| Lacak | BR-INT |

#### FR-INT-20 Data saham dari aplikasi OLT

| Atribut | Isi |
|---|---|
| Deskripsi | Library harus mengambil saran, nama, dan info saham dari callback aplikasi OLT dan membuka halaman saham OLT, tanpa menyimpan data pasar di server. |
| Aktor | Aplikasi OLT; library |
| Prakondisi | `RendezvousCommunity.initialize` dipanggil setelah login OLT |
| Proses dan aturan | 1) `stockSearch(query)` mengembalikan `List<StockSuggestion>` (kode + nama) untuk saran saat nasabah mengetik `$`; tanpa callback, `$KODE` tetap bisa diketik tanpa saran. <br>2) `stockInfo(code)` memberi nama dan harga untuk kartu saham di chat; harga tidak dikirim ke server. <br>3) `onStockTap(context, code)` membuka halaman saham OLT; `onIndexTap` untuk indeks (fallback `onStockTap`). <br>4) Kode berformat `$KODE` (huruf di depan, 2–12 huruf/angka) diterima sebagai label; validasi keberadaan kode tugas aplikasi OLT. <br>5) Nama saham di header `CommunityStockFeed` dari parameter `stockName`. |
| Keluaran | Saran, kartu, dan navigasi saham memakai data OLT |
| Kode error | — |
| Antarmuka | Library: `RendezvousCommunity.initialize(stockSearch:, stockInfo:, onStockTap:)`, `CommunityStockFeed`, `CommunityIndexFeed` |
| Lacak | BR-INT |

#### FR-INT-21 Deep link dan ketukan notifikasi OLT

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi skema deep link aplikasi yang boleh dipakai tautan banner, dan library harus menyerahkan deep link serta ketukan notifikasi OLT ke router aplikasi OLT. |
| Aktor | Super Admin (skema); aplikasi OLT (router) |
| Prakondisi | — |
| Proses dan aturan | 1) Skema deep link `banners.deep_link_schemes` (bawaan `olt`) maksimal 5, pola `^[a-z][a-z0-9+.-]{0,31}$`, hanya Super Admin yang mengubah (0124). <br>2) Skema web dan berbahaya (javascript, data, file, intent, content, dan sejenisnya) selalu ditolak; daftar kosong berarti tautan hanya `https://`. Diaudit `banner.link_schemes`. <br>3) `onBannerLink(context, uri, banner)` mengembalikan `true` bila OLT menangani; `false` membuat library membuka `https`/`http` lewat dialog konfirmasi dan mengabaikan skema lain. <br>4) Ketukan notifikasi berasal OLT (`isOltPush(data)`) diteruskan ke `onOltNotificationTap`. |
| Keluaran | Tautan dibuka di halaman aplikasi OLT |
| Kode error | `400 invalid_link_schemes`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.admin_banner_settings`, `cs_api.admin_set_banner_link_schemes`; Hub: Pengaturan → Integrasi → Integrasi aplikasi → Skema deep link aplikasi; Library: `onBannerLink`, `onOltNotificationTap` |
| Lacak | BR-INT |

#### FR-INT-22 OLT tiruan untuk pengembangan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan OLT tiruan yang menerbitkan token sosial dengan kunci dev hanya di profil pengembangan, sebagai implementasi referensi kontrak. |
| Aktor | Developer, penguji |
| Prakondisi | Profil `dev` |
| Proses dan aturan | 1) `make up DUMMY_OLT=1` menjalankan `dummy-olt` dan auth-bridge mode `jwt` dengan kunci publik dummy (`kid` `dev-olt-1`), jalur yang sama dengan produksi. <br>2) Makefile menolak `DUMMY_OLT` di luar profil dev; auth-bridge produksi menolak `kid` `dev-`. <br>3) Token sosial dummy EdDSA berumur 10 menit (`DUMMY_OLT_SOCIAL_TTL`) membawa klaim `accounts` sesuai akun uji. <br>4) Akun uji mencakup akun ditangguhkan (permintaan token ditolak) dan akun lambat 8 detik. <br>5) `make smoke-dummy` menguji 22 skenario (login, perpanjangan, token diubah, kedaluwarsa, audience lain, akun ditangguhkan, logout). |
| Keluaran | Lingkungan uji login tanpa OLT asli |
| Kode error | — |
| Antarmuka | `services/dummy-olt` (WebSocket pesan `social_token`, `POST /api/social-token`, `GET /api/users`); `make smoke-dummy` |
| Lacak | BR-INT |

#### FR-INT-23 Penerimaan laporan keuangan emiten (XBRL)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima file XBRL laporan keuangan emiten dari IDX lewat API atau unggahan Hub, lalu memprosesnya secara asinkron di layanan terpisah tanpa membebani layanan lain. |
| Aktor | Sistem pengirim (backend OLT, vendor data, skrip kantor); staf berizin Komunitas **Buat postingan** |
| Prakondisi | Key berizin `financial_report`, atau staf dengan izin `community.post` |
| Proses dan aturan | 1) Body = isi `instance.zip` apa adanya, `Content-Type` zip, maks 8 MiB; zip maks 16 entri, tepat satu `.xbrl`, maks 32 MiB setelah dibuka, rasio kompresi maks 200:1 (services/finreport/README.md). <br>2) Maks 2 unggahan bersamaan (`503 busy`), `rate_limit_per_minute` per key, dan `finreport.files_per_hour` (120) per key per jam. <br>3) Kiriman ulang file yang sama oleh key yang sama dijawab dengan `id` lama (`resubmitted`); isi yang sudah pernah diurai ditandai `duplicate` (0197). <br>4) Worker memproses satu file sekali jalan: SHA-256, ClamAV, urai XBRL mengalir; gagal sementara dicoba ulang dengan jeda 1, 4, 9, 16 menit lalu ditolak `too_many_attempts`. <br>5) Layanan `finreport` dibatasi CPU 0,25, memori 128 MB, `cpu_shares` 256; Kong dan Traefik hanya memindahkan rute `/integration/v1/financial-reports`. <br>6) File terinfeksi dan file yatim dihapus lewat janitor; file ditolak disimpan `finreport.rejected_keep_days` (30) hari untuk diproses ulang. |
| Keluaran | `202` (antre) / `200` (`resubmitted` atau `duplicate`); status `queued`, `processing`, `done`, `duplicate`, `rejected` + `error` |
| Kode error | `400 not_zip`, `400 no_instance`, `400 zip_unsafe`, `403 scope_forbidden`, `404 file_not_found`, `413 body_too_large`, `415 unsupported_media_type`, `429 rate_limited`, `503 busy`; penolakan: `invalid_xbrl`, `unknown_entity`, `infected`, `checksum_mismatch`, `too_many_attempts` |
| Antarmuka | `POST /integration/v1/financial-reports`, `GET /integration/v1/financial-reports/{id}`; RPC `public.finreport_submit`, `public.finreport_file`, `public.finreport_claim`, `public.finreport_complete`, `public.finreport_fail`, `cs_api.finreport_upload`, `cs_api.finreport_retry`; docs/integration/laporan-keuangan.md |
| Lacak | BR-INT |

#### FR-INT-24 Ringkasan laporan keuangan menjadi postingan resmi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghitung angka dan rasio laporan, menyusun ringkasan berbahasa Indonesia dengan template tetap (tanpa AI), dan menjadikannya postingan resmi yang menunggu persetujuan empat mata. |
| Aktor | Layanan `finreport`; staf Komunitas; Super Admin (pengaturan) |
| Prakondisi | Laporan berhasil diurai; akun resmi aktif dipilih di pengaturan riset |
| Proses dan aturan | 1) Template `bank` bila ada pos bunga dan kredit, `general` bila ada penjualan, selain itu `basic` + peringatan `template_basic`. <br>2) Pembanding: laporan kumulatif sebelumnya di tahun buku yang sama (kuartal tunggal, QoQ) dan laporan periode yang sama tahun lalu (neraca YoY, rasio tahun lalu); laba rugi YoY dari angka pembanding di laporan terbaru. <br>3) Selisih > 0,5% antara angka tahun lalu di laporan baru dan laporan tahun lalu yang tersimpan diberi peringatan `restated`. <br>4) Laporan baru untuk emiten dan periode yang sama menggantikan versi lama (`revision`) dan membatalkan postingannya yang belum terbit. <br>5) Teks maks 2000 karakter, diawali `$KODE`, melewati `private.validate_text` dan `private.apply_content_policy`. <br>6) Postingan `pending` dibuat atas nama akun resmi oleh pembuat key atau pengunggah; posting otomatis (`auto_publish`) hanya untuk laporan tanpa peringatan. <br>7) Pengaturan hanya Super Admin dan tercatat `finreport.config` di jejak audit. |
| Keluaran | `private.finreport_reports` (angka, metrik, ringkasan, peringatan) dan `cs.community_posts` `pending` atau `published` |
| Kode error | `409 post_exists`, `409 superseded`, `400 official_inactive`; peringatan `no_official_account`, `post_rejected` |
| Antarmuka | Hub **Komunitas → Laporan keuangan**; RPC `cs_api.finreport_files`, `cs_api.finreport_report`, `cs_api.finreport_create_post`, `cs_api.finreport_config`, `cs_api.finreport_save_config`; docs/laporan-keuangan/README.md |
| Lacak | BR-INT, BR-KOM |

### 4.11 Operasional (OPS)

Modul ini mencakup cara server dipasang, diperbarui, dipantau, dipulihkan, dan dibersihkan. Server berjalan di Docker dengan tiga profil (`dev`, `single`, `cluster`) yang memakai image dan nama layanan yang sama; perbedaan hanya di file override compose (docs/panduan/skalabilitas.md). Profil `single` siap produksi, profil `cluster` (Docker Swarm) masih kerangka, dan database cloud terkelola tidak didukung karena sistem memakai role, ekstensi, dan Vault milik image Supabase. Logika bisnis dan aturan pemantauan berada di Postgres (fungsi SQL dan pg_cron); layanan Go buatan sendiri (sentinel, healer, backup, janitor, media, classifier, link-preview) hanya mengumpulkan data, menjalankan pekerjaan, dan melapor lewat RPC `service_role`. Kredensial operasional (tujuan dan password backup, kanal alert) dikelola Super Admin di Hub, disimpan di Vault, dan diaudit; kunci dasar infrastruktur tetap di `docker/secrets/`.

**Jadwal pg_cron penting.** Ekspresi cron ditulis dalam UTC (zona bawaan pg_cron; terbukti dari `private.watchlist_digest_cron` yang mengurangi 7 jam dari WIB, 0147). Kolom WIB adalah padanannya. Job `care-*` dari 0024 sudah dihapus jadwalnya di 0026. Kegagalan job mana pun membuka alert `cron:<job>` (0064).

| Job | Jadwal (UTC) | WIB | Fungsi | Migrasi |
|---|---|---|---|---|
| `cs-sweep` | tiap 10 detik | — | `cs.run_sweep()`: alur tiket berkala (kedaluwarsa transfer, penutupan tiket, dan lain-lain; rincian di CS) | 0032 (definisi terakhir 0056) |
| `chat-room-preview` | tiap 10 detik | — | `private.room_preview_worker()`: memproses antrean pratinjau room | 0102 |
| `cs-community` | tiap 15 detik | — | `cs.community_tick()`: menerbitkan postingan dan kampanye Komunitas terjadwal | 0057 |
| `integration-broadcasts` | tiap 15 detik | — | `private.integration_broadcast_tick()`: mengirim siaran integrasi bertahap | 0086 |
| `app-notices` | tiap 15 detik | — | `private.app_notice_tick()`: mengirim notifikasi info dari Banner & Popup | 0182 |
| `social-followed-posts` | tiap 30 detik | — | `private.followed_post_tick()`: notifikasi postingan akun yang diikuti | 0087 |
| `trade-share-tick` | tiap 30 detik | — | `private.trade_share_tick()`: pengiriman Berbagi Trade (fitur dijeda, job tetap terjadwal) | 0163 |
| `health-evaluate` | `* * * * *` | tiap menit | `private.health_evaluate()`: evaluasi aturan alert | 0064 |
| `push-maintenance` | `* * * * *` | tiap menit | `private.push_maintenance()`: pemeliharaan antrean push | 0058 |
| `olt-promote-new-accounts` | `*/15 * * * *` | tiap 15 menit | `private.promote_new_accounts()`: mengakhiri status akun baru sesuai `safety.new_account_days` | 0015 (definisi terakhir 0187) |
| `trade-share-maintenance` | `*/15 * * * *` | tiap 15 menit | `private.trade_share_maintenance()` (fitur dijeda) | 0164 |
| `safety-manipulation` | `*/5 * * * *` | tiap 5 menit | `cs.detect_manipulation()`: deteksi manipulasi saham | 0072 |
| `social-trending` | `*/5 * * * *` | tiap 5 menit | `private.trending_tick()`: pembaruan trending | 0074 |
| `cs-waiting-reminder` | `*/5 * * * *` | tiap 5 menit | `cs.remind_waiting_customers()`: pengingat tiket menunggu nasabah | 0136 |
| `integration-maintenance` | `23 * * * *` | menit ke-23 tiap jam | `private.integration_maintenance()`: bersihkan id pesan, tautan kedaluwarsa, statistik, batas siaran | 0068 |
| `cs-partitions` | `10 2 * * *` | 09.10 | `cs.ensure_partitions(3)`: partisi bulanan `cs.session_events` dan `cs.cs_audit_log` | 0028 |
| `social-analytics` | `25 2 * * *` | 09.25 | `private.analytics_maintenance()`: partisi dan retensi event analitik | 0078 |
| `social-trending-rebuild` | `40 2 * * *` | 09.40 | `private.trending_rebuild()` | 0074 |
| `olt-retention` | `17 3 * * *` | 10.17 | `private.run_retention()`: retensi data sosial | 0015 |
| `storage-cleanup-purge` | `27 3 * * *` | 10.27 | `private.storage_cleanup_purge()`: hapus baris antrean selesai > 90 hari | 0060 |
| `evidence-purge` | `33 3 * * *` | 10.33 | `private.evidence_purge()`: hapus bukti kedaluwarsa tanpa legal hold | 0095 |
| `social-content-edits-retention` | `35 3 * * *` | 10.35 | `private.content_edits_purge()`: retensi riwayat edit | 0081 |
| `link-preview-purge` | `37 3 * * *` | 10.37 | `private.link_preview_purge()` | 0080 |
| `health-purge` | `41 3 * * *` | 10.41 | `private.health_purge()`: riwayat alert dan pengiriman > 90 hari | 0064 |
| `message-receipts-retention` | `43 3 * * *` | 10.43 | `private.message_receipts_retention()` | 0122 |
| `backup-purge` | `47 3 * * *` | 10.47 | `private.backup_purge()`: riwayat backup > 180 hari, permintaan > 30 hari | 0065 |
| `app-banner-maintenance` | `47 3 * * *` | 10.47 | `private.app_banner_maintenance()`: retensi event banner | 0119 |
| `media-reviews-purge` | `53 3 * * *` | 10.53 | `private.media_reviews_purge()` | 0079 |
| `social-watchlist-digest` | dari `notifications.watchlist_digest_time` (bawaan 17.05 WIB = `5 10 * * *`) | 17.05 | `private.watchlist_digest()`: ringkasan watchlist harian; dijadwal ulang saat setting berubah | 0087, 0147 |

#### FR-OPS-01 Profil deploy

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus bisa dijalankan dengan profil `dev`, `single`, atau `cluster` memakai image dan nama layanan yang sama. |
| Aktor | Tim IT |
| Prakondisi | Docker Engine + Compose (Swarm untuk cluster) |
| Proses dan aturan | 1) `dev`: HTTP `:8000`, semua path terbuka (Studio), log debug, bisa memakai OLT tiruan. <br>2) `single`: HTTPS Let's Encrypt, hanya path API publik, Studio mati; profil produksi yang didukung. <br>3) `cluster`: replika antar-node, Realtime cluster, storage S3; masih kerangka; healer `replicas: 0`. <br>4) `PROFILE` bawaan Makefile `dev`; server produksi mengekspor `PROFILE=single`. <br>5) Database cloud terkelola tidak didukung. |
| Keluaran | Stack berjalan sesuai profil |
| Kode error | — |
| Antarmuka | `docker/compose.yml` + `compose.dev.yml`, `compose.prod.yml`, `compose.cs.yml`, `stack.cluster.yml`; `make up PROFILE=...` |
| Lacak | BR-OPS |

#### FR-OPS-02 Instalasi server baru

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan skrip instalasi yang menyiapkan server Ubuntu baru sampai stack berjalan. |
| Aktor | Tim IT |
| Prakondisi | Server Ubuntu LTS, DNS A record domain API, port 80/443 terbuka, 22 hanya IP admin |
| Proses dan aturan | 1) `scripts/server-install.sh` memasang Docker, meng-clone `~/chat_service_supabase` dan `~/rendezvous_hub` (deploy key), membuat rahasia, lalu menjalankan stack. <br>2) Domain, email ACME, domain Hub, dan `VPN_SOURCE_RANGES` diisi di `docker/.env`. <br>3) JWKS OLT diisi di `docker/secrets/olt_jwks`. <br>4) Ukuran minimum 8 vCPU / 16 GB / 200 GB NVMe; disarankan produksi awal 16 vCPU / 32 GB / 500 GB NVMe. |
| Keluaran | Server siap dipakai |
| Kode error | — |
| Antarmuka | `scripts/server-install.sh`; docs/panduan/instalasi-server.md |
| Lacak | BR-OPS |

#### FR-OPS-03 Menjalankan dan menerapkan perubahan dengan `make up`

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan satu perintah yang membangun image yang berubah, menjalankan migrasi, dan menunggu semua layanan sehat. |
| Aktor | Tim IT |
| Prakondisi | Repo server dan Hub ada berdampingan (`HUB_DIR`, bawaan `../../rendezvous_hub`) |
| Proses dan aturan | 1) `make up` (Windows `.\make.ps1 up`) membangun image yang berubah termasuk `cs-console` dari repo Hub, menjalankan container `migrate`, lalu menyalakan layanan dan menunggu healthy. <br>2) Profil `single`/`cluster` gagal bila `EDGE_WS_PER_IP` < 1000 atau `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` < 1000 (`check-config`). <br>3) `DUMMY_OLT` ditolak di luar profil dev. <br>4) Container `migrate` dan `volume-init` selesai dengan `Exited (0)`. <br>5) `make reset` dan `docker volume rm` dilarang di produksi karena menghapus database dan file. |
| Keluaran | Stack berjalan; `make ps` semua healthy |
| Kode error | — |
| Antarmuka | `make up`, `make ps`, `make logs s=<layanan>`, `make psql` |
| Lacak | BR-OPS |

#### FR-OPS-04 Migrasi bernomor dengan checksum

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memasang migrasi SQL bernomor sekali saja, berurutan, dan menolak migrasi yang isinya berubah setelah terpasang. |
| Aktor | Container `migrate` |
| Prakondisi | Database berjalan |
| Proses dan aturan | 1) Setiap file `[0-9]*.sql` di `supabase/migrations` dijalankan dalam satu transaksi (`--single-transaction`). <br>2) Versi dan SHA-256 file dicatat di `olt_internal.schema_migrations`; file terpasang yang checksum-nya berbeda menghentikan migrasi. <br>3) Penanda `-- olt:run-as=supabase_admin` di 5 baris pertama menjalankan file sebagai superuser. <br>4) Password role `olt_backup` diambil dari Docker secret (minimal 32 heksadesimal) dan tidak pernah ditulis di migrasi. <br>5) Bila ada migrasi baru, PostgREST dimuat ulang (`notify pgrst, 'reload schema'`). <br>6) File migrasi wajib berakhiran LF. |
| Keluaran | Log `migrate: done (N new, M total)` |
| Kode error | `migrate: FAILED - <versi> was already applied but its content changed.` |
| Antarmuka | `scripts/migrate.sh`; container `migrate` |
| Lacak | BR-OPS |

#### FR-OPS-05 Pembaruan versi dan rollback

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus bisa diperbarui dari Git dan dikembalikan ke versi sebelumnya bila rilis bermasalah. |
| Aktor | Tim IT, Super Admin |
| Prakondisi | Tidak ada perubahan lokal di kedua repo; backup sehat |
| Proses dan aturan | 1) Sebelum update: pilih jam sepi di luar jam bursa, baca catatan rilis, pastikan Kesehatan sistem tanpa alert kritis dan backup penuh < 24 jam, jalankan `make backup`, catat commit kedua repo. <br>2) Update: `git -C ~/rendezvous_hub pull --ff-only`, `git pull --ff-only`, `make up`. <br>3) Rollback Hub saja: checkout commit Hub sebelumnya lalu `make up`. <br>4) Rollback server tanpa kerusakan data: checkout commit sebelumnya lalu `make up`. <br>5) Migrasi merusak data: checkout kedua repo dan `make restore-pitr AT=<sebelum update>`. <br>6) Kode hanya dari Git; file di server tidak diedit langsung; migrasi lama tidak pernah diubah. |
| Keluaran | Versi baru atau versi sebelumnya berjalan |
| Kode error | — |
| Antarmuka | docs/panduan/pembaruan-sistem.md; `make up`, `make backup`, `make restore-pitr` |
| Lacak | BR-OPS |

#### FR-OPS-06 Pemisahan jaringan, domain, dan pengerasan container

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membatasi jalur jaringan dan hak setiap container sehingga hanya komponen yang perlu yang bisa menjangkau internet. |
| Aktor | Sistem |
| Prakondisi | Profil `single` |
| Proses dan aturan | 1) Domain API publik hanya meloloskan `/rest/v1`, `/realtime/v1`, `/storage/v1`, `/media/v1`, `/integration/v1`, `/bridge/v1`; path lain 404, termasuk `/auth/v1`, `/functions/v1`, dan Studio. <br>2) Domain CS hanya dari `VPN_SOURCE_RANGES`. <br>3) Network `edge`, `app`, `data` tanpa internet; hanya Traefik, functions, notifier, sentinel, link-preview, backup, dan clamav di `egress`. <br>4) Container read-only, non-root (kecuali entrypoint Postgres), `cap_drop: ALL`, `no-new-privileges`, batas CPU/memori/pids. <br>5) Port ops (`/metrics`, `/livez`, `/readyz`) hanya di jaringan Docker; `make test-security` memeriksa konfigurasi statis. <br>6) Studio di produksi hanya lewat `127.0.0.1:8000` (SSH tunnel). |
| Keluaran | Permukaan serangan minimal |
| Kode error | `404` untuk path di luar daftar |
| Antarmuka | `docker/volumes/traefik/*.yml`, `docker/volumes/api` (Kong); `make test-security` |
| Lacak | BR-OPS |

#### FR-OPS-07 Rahasia infrastruktur dan pengaturan lewat Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memisahkan rahasia infrastruktur di Docker secrets dari kredensial operasional yang dikelola di Hub dan disimpan di Vault. |
| Aktor | Tim IT, Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) `docker/secrets/` berisi password database, JWT secret, anon key, service role key, `olt_jwks`, kunci csAdmin, password statistik PgBouncer; dibuat `make gen-secrets` dan tidak di-commit. <br>2) `docker/.env` berisi konfigurasi (domain, kapasitas, folder backup lokal, IP Hub), bukan kunci. <br>3) Tujuan dan password backup, kanal alert, kunci Firebase, alamat csAdmin, API key integrasi, dan feature flag diatur di Hub, disimpan di `private.settings`/Vault, dan diaudit tanpa isi rahasia. <br>4) Rotasi `jwt_secret` membatalkan anon key, service role key, dan semua JWT; `postgres_password` tidak dibuat ulang tanpa `ALTER ROLE` manual. |
| Keluaran | Rahasia tidak pernah tersimpan di repo atau log |
| Kode error | — |
| Antarmuka | `make gen-secrets`; Vault (`vault.secrets`) |
| Lacak | BR-OPS |

#### FR-OPS-08 Heartbeat layanan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima heartbeat berkala dari layanan Go dan menandai layanan wajib yang berhenti melapor. |
| Aktor | Layanan Go (media, backup, notifier, sentinel, auth-bridge, integration, classifier, dan lainnya) |
| Prakondisi | — |
| Proses dan aturan | 1) Layanan memanggil `public.service_heartbeat` (service_role) dengan nama layanan, instance, status `ok`/`degraded`/`error`, dan detail; tersimpan di `private.service_instances`. <br>2) Layanan wajib `health.expected_services` (media, sentinel, backup, notifier) tanpa heartbeat 90 detik membuka alert kritis `service:<nama>`. <br>3) Status `error` atau `degraded` membuka `service:<nama>:status` (kritis/peringatan). |
| Keluaran | Status layanan di Kesehatan sistem |
| Kode error | `400 invalid_heartbeat` |
| Antarmuka | RPC `public.service_heartbeat` (0064) |
| Lacak | BR-OPS |

#### FR-OPS-09 Pengumpulan data pemantauan oleh sentinel

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memeriksa layanan internal, disk, dan metrik kapasitas secara berkala dan melaporkannya ke database. |
| Aktor | Sentinel |
| Prakondisi | `PROBES`, `DISKS`, `METRICS_SOURCES` terisi di compose |
| Proses dan aturan | 1) Setiap `REPORT_INTERVAL` (30 detik): probe HTTP (hidup bila status < 500) dan TCP (maks 100), `statfs` disk read-only (maks 20), metrik PostgREST, Realtime, dan PgBouncer (`SHOW POOLS`). <br>2) Laporan dikirim lewat `health_report`; database mencatat heartbeat sentinel lalu langsung mengevaluasi aturan. <br>3) Laporan yang gagal dibawa ke laporan berikutnya sebagai hitungan `missed` dan `sentinel_reports_lost` (0108). <br>4) Status healer dari `state.json` dikirim sebagai `p_healer` (0113). <br>5) URL dengan kredensial ditolak saat start. |
| Keluaran | Data probe, disk, metrik di database |
| Kode error | `400 invalid_health_report` |
| Antarmuka | RPC `public.health_report`; `services/sentinel` |
| Lacak | BR-OPS |

#### FR-OPS-10 Evaluasi dan siklus alert

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghitung aturan alert di database dan mengelola siklus buka, memburuk, dan pulih secara deterministik. |
| Aktor | Database (`private.health_evaluate`) |
| Prakondisi | — |
| Proses dan aturan | 1) Aturan di `private.health_current()` mencakup layanan, probe, disk (peringatan ≥ 80 %, kritis ≥ 90 %), koneksi DB, slot replikasi, transaksi > 15 menit, cron gagal, antrean push > 10 menit, janitor gagal ≥ 3 kali, pengiriman alert gagal, backup, rahasia Vault, `rest:pool`, `realtime:events`, `pgbouncer:queue`, `db:lock_waits`, `queue:room_preview`, `metrics:*`, `healer:*`. <br>2) Dievaluasi setiap laporan sentinel dan setiap menit (`health-evaluate`). <br>3) Alert dibuka bila masalah bertahan `health.alert_after_seconds` (120 detik; 25 detik untuk kunci kapasitas, 0 untuk `healer:gave_up`) dan pulih setelah bersih `health.resolve_after_seconds` (60 detik). <br>4) Ambang `health.*` di `private.settings` bisa diubah tanpa deploy. <br>5) Riwayat alert dan pengiriman disimpan 90 hari. |
| Keluaran | Alert terbuka, memburuk, atau pulih beserta antrean pesan |
| Kode error | — |
| Antarmuka | `private.health_current`, `private.health_evaluate`; cron `health-evaluate` |
| Lacak | BR-OPS |

#### FR-OPS-11 Pengiriman alert ke Telegram dan email

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim pesan alert yang disusun database ke kanal Telegram dan email yang aktif dengan pengiriman minimal sekali. |
| Aktor | Sentinel |
| Prakondisi | Kanal diatur di Hub |
| Proses dan aturan | 1) Setiap `ALERT_POLL` (5 detik) sentinel memeriksa revisi kanal (`alert_channels`; tanpa rahasia bila revisi sama), lalu `alert_claim` maksimal `BATCH_SIZE` (20) pesan dengan lease `LEASE` (60 detik). <br>2) Hasil dilaporkan lewat `alert_report`; `retry` dijadwalkan ulang 30 detik × 2^(percobaan−1) sampai maks 1 jam, paling banyak 8 percobaan, dan pesan > 6 jam dianggap gagal. <br>3) Telegram: teks biasa maks 4096 karakter, per chat id, chat yang sudah menerima tidak dikirimi ulang (24 jam), migrasi supergroup diikuti. <br>4) Email: `tls`, `starttls`, atau `none` (tanpa username), sertifikat diverifikasi TLS 1.2+, satu penerima ditolak membatalkan seluruh email. <br>5) Token dan password tidak pernah masuk log. |
| Keluaran | Pesan alert terkirim; status kiriman terakhir tampil di Hub |
| Kode error | `400 invalid_alert_report`; `400 invalid_instance` |
| Antarmuka | RPC `public.alert_channels`, `public.alert_claim`, `public.alert_report` |
| Lacak | BR-OPS |

#### FR-OPS-12 Pengaturan kanal alert di Hub

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin mengatur label, alamat Hub, kanal Telegram, dan kanal email untuk alert, serta mengirim pesan uji. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin |
| Proses dan aturan | 1) Label 1–40 karakter; alamat web CS diawali `http://` atau `https://`. <br>2) Telegram: token bot dan 1–5 chat ID; token disimpan di Vault dan tidak bisa ditampilkan lagi. <br>3) Email: host, port 1–65535, keamanan `tls`/`starttls`/`none`, username, password (kosong = pertahankan), pengirim, 1–10 penerima. <br>4) Kirim uji maksimal satu per 20 detik per kanal; kanal harus aktif dan tersimpan. <br>5) Form terkunci (**Ubah** → **Simpan** → konfirmasi); diaudit `alerts.*` tanpa token atau password. |
| Keluaran | Revisi kanal baru dipakai sentinel tanpa restart |
| Kode error | `400 invalid_telegram_token`; `400 invalid_telegram_chat`; `400 telegram_incomplete`; `400 invalid_smtp`; `400 invalid_email_address`; `400 email_incomplete`; `400 invalid_alert_label`; `400 invalid_console_url`; `409 alert_channel_disabled`; `400 invalid_alert_channel`; `429 too_many_requests` |
| Antarmuka | RPC `cs_api.alert_channels_view`, `alert_set_telegram`, `alert_set_email`, `alert_set_options`, `alert_send_test`; Hub: Pengaturan → Sistem → Alert |
| Lacak | BR-OPS |

#### FR-OPS-13 Alert saat API atau database tidak bisa dihubungi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus tetap mengirim alert ketika database atau API tidak bisa mengevaluasi aturan. |
| Aktor | Sentinel |
| Prakondisi | Kanal pernah dimuat ke memori sentinel |
| Proses dan aturan | 1) Hanya error jaringan, timeout, dan 5xx yang dihitung gagal; satu panggilan berhasil mengakhiri hitungan. <br>2) Bila semua panggilan gagal selama `DB_DOWN_AFTER` (2 menit), sentinel mengirim sekali "API/database tidak bisa dihubungi" berisi waktu mulai (WIB), instance, error terakhir, dan probe yang gagal. <br>3) Saat pulih, sentinel mengirim sekali "API/database pulih" dengan lama gangguan (dicoba maks 1 jam). <br>4) Pemantau dari luar server (mis. Uptime Kuma) disarankan memeriksa `https://<domain>/bridge/v1/health` untuk kasus seluruh server mati. |
| Keluaran | Pesan langsung ke kanal terakhir |
| Kode error | — |
| Antarmuka | `services/sentinel` |
| Lacak | BR-OPS |

#### FR-OPS-14 Halaman Kesehatan sistem

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menampilkan status kesehatan sistem kepada Super Admin dan angka alert terbuka di menu Pengaturan. |
| Aktor | Super Admin |
| Prakondisi | Sesi Super Admin |
| Proses dan aturan | 1) Tab **Status**: alert terbuka dan riwayat, layanan dan instance, probe, disk, database (ukuran, koneksi, slot), antrean (push, storage cleanup, alert), dan status job cron. <br>2) Lencana di menu **Pengaturan** menghitung alert terbuka per tingkat. <br>3) **Tandai sudah ditangani** membuat alert tidak dihitung di lencana, tetapi tetap terbuka sampai pulih. <br>4) Halaman hanya untuk melihat; perbaikan dilakukan IT (docs/panduan/gangguan.md). |
| Keluaran | Ringkasan kesehatan sistem |
| Kode error | `404 alert_not_found`; `403 role_forbidden` |
| Antarmuka | RPC `cs_api.system_health`, `cs_api.system_health_badge`, `cs_api.health_acknowledge`; Hub: Pengaturan → Sistem → Kesehatan sistem → Status |
| Lacak | BR-OPS |

#### FR-OPS-15 Peta layanan

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus menggambar semua container proyek beserta status, replika, CPU, dan RAM yang diperbarui hampir seketika. |
| Aktor | Super Admin |
| Prakondisi | Healer dan sentinel berjalan (profil dev/single) |
| Proses dan aturan | 1) Healer membaca daftar container dari Docker (hanya baca) setiap `HEALER_NODES_SECONDS` (10) ke `nodes.json`; sentinel meneruskan snapshot baru ke `nodes_report` setiap `NODES_INTERVAL` (10s) (0168). <br>2) `cs_api.system_nodes` menggabungkan snapshot dengan probe, restart 24 jam, dan versi layanan; Hub memuat ulang setiap 5 detik. <br>3) Lajur: Gerbang, API & layanan, Data, Pekerja, Operasional; hijau sehat, kuning perlu dicek, merah bermasalah, abu-abu bergaris putus sengaja dimatikan; klik kartu untuk detail. <br>4) Snapshot lebih tua dari `health.nodes_stale_seconds` (45) menampilkan "Data terlambat". <br>5) Profil cluster belum didukung. |
| Keluaran | Tab Peta layanan dengan penanda **Live** |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `public.nodes_report`, `cs_api.system_nodes`; Hub: Pengaturan → Sistem → Kesehatan sistem → Peta layanan |
| Lacak | BR-OPS |

#### FR-OPS-16 Restart otomatis layanan macet (healer)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus me-restart container berlabel autoheal yang hidup tetapi unhealthy terus-menerus, dengan batas agar restart tidak beruntun. |
| Aktor | Healer |
| Prakondisi | Profil dev/single; `HEALER_ENABLED=true` |
| Proses dan aturan | 1) Hanya container project sendiri berlabel `olt.autoheal=true` (antara lain traefik, kong, auth, rest, realtime, storage, imgproxy, functions, pgbouncer, auth-bridge, notifier, janitor, classifier, media, backup, integration, link-preview, cs-console, nasabah-gateway); `db`, `valkey`, `sentinel`, `healer`, dan one-shot tidak pernah di-restart. <br>2) Syarat: unhealthy terus-menerus ≥ 60 detik dan berjalan ≥ 120 detik sejak start terakhir. <br>3) Maksimal 3 restart per layanan per jam dan 1 restart per 30 detik untuk seluruh stack; yang paling lama unhealthy didahulukan. <br>4) `HEALER_ENABLED=false` = mode laporan saja. <br>5) Healer satu-satunya pemegang Docker socket, tanpa jaringan (`network_mode: none`), non-root, read-only, hanya memakai endpoint list, inspect, restart. |
| Keluaran | Container dipulihkan; event tercatat di `state.json` |
| Kode error | — |
| Antarmuka | `services/healer`; env `HEALER_*` |
| Lacak | BR-OPS |

#### FR-OPS-17 Penahanan restart, menyerah, dan riwayat restart

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menahan restart saat gangguan bersifat sistemik, berhenti mencoba layanan yang terus gagal, dan menampilkan riwayatnya di Hub. |
| Aktor | Healer; database; Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Bila `db` tidak sehat, tidak ada restart (`db_unhealthy`); bila `pgbouncer` tidak sehat, hanya pgbouncer yang boleh di-restart (`pgbouncer_unhealthy`); bila ≥ 2 layanan dan ≥ 50 % layanan berlabel unhealthy, tidak ada restart (`systemic`). <br>2) Penahanan bertahan 120 detik membuka peringatan `healer:systemic`. <br>3) Setelah 3 restart dalam 1 jam dan layanan tetap unhealthy, healer menyerah dan alert kritis `healer:gave_up:<layanan>` terbuka tanpa tunda; dicoba lagi setelah jendela 1 jam lewat. <br>4) Status healer tidak diperbarui > `health.healer_stale_seconds` (120) membuka `healer:stale`. <br>5) Event disimpan 30 hari di `private.healer_events`; tab menampilkan 50 kejadian terakhir. |
| Keluaran | Tab Restart otomatis: status healer, aturan, layanan unhealthy, penahanan, layanan ditinggalkan, kejadian |
| Kode error | `403 role_forbidden` |
| Antarmuka | RPC `cs_api.healer_overview` (0113); Hub: Pengaturan → Sistem → Kesehatan sistem → Restart otomatis |
| Lacak | BR-OPS |

#### FR-OPS-18 Backup berkelanjutan database dan file

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mencadangkan database secara terus-menerus untuk pemulihan ke titik waktu dan mencadangkan file Storage ke repositori terenkripsi. |
| Aktor | Layanan backup |
| Prakondisi | Tujuan backup diatur (FR-OPS-19) |
| Proses dan aturan | 1) `pg_receivewal` mengalirkan WAL lewat slot fisik `olt_backup` (role `olt_backup` LOGIN REPLICATION, maks 6 koneksi) tanpa mengubah image database. <br>2) Backup penuh harian `pg_basebackup` dengan manifest SHA-256, diverifikasi `pg_verifybackup`, ditambah backup file storage (read-only). <br>3) restic mengenkripsi AES-256 di sisi server, deduplikasi, kompresi; WAL dikirim tiap `offsite_minutes`. <br>4) `max_slot_wal_keep_size = 512MB`: slot yang tertinggal menjadi `lost`, layanan membuat slot dan backup penuh baru (alert `backup:slot`), sehingga disk database tidak penuh karena backup. <br>5) Hanya satu pekerjaan berjalan sekaligus selain streaming WAL; pekerjaan gagal dicoba ulang 15 menit lalu berlipat sampai 6 jam. <br>6) Base tidak dijalankan bila ruang staging kurang dari perkiraan ukuran database × 1,2. |
| Keluaran | Snapshot restic bertag `base`, `files`, `wal` |
| Kode error | `400 invalid_backup_run` |
| Antarmuka | `services/backup`; RPC `public.backup_config`, `public.backup_record` |
| Lacak | BR-OPS |

#### FR-OPS-19 Tujuan backup dan password enkripsi

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin memilih tujuan backup S3 atau folder lokal dan menetapkan password enkripsi yang tidak bisa dibaca atau diganti untuk repositori yang sama. |
| Aktor | Super Admin |
| Prakondisi | Password enkripsi sudah disimpan di luar server |
| Proses dan aturan | 1) S3: endpoint `https://host[:port]`, bucket, prefix (maks 5 segmen), region, access key ID 3–200 karakter, secret access key. <br>2) Folder lokal: hanya password; repositori di `BACKUP_LOCAL_REPO_DIR` (disarankan disk terpisah), dengan peringatan risiko di halaman (0112). <br>3) Password minimal 16 karakter (maks 200) dan wajib dikonfirmasi pernyataan penyimpanan di luar server. <br>4) Password repositori yang sudah ada tidak bisa diganti; pindah bucket/folder/jenis berarti repositori baru dan wajib password baru. <br>5) Rahasia disimpan di Vault (`cs.vault_store_secret`); diaudit `backup.target_set` tanpa isi rahasia. <br>6) Rotasi access key S3 tanpa mengganti password. |
| Keluaran | Layanan backup membuat repositori, mulai streaming WAL, dan membuat backup penuh pertama |
| Kode error | `400 invalid_backup_kind`; `400 invalid_backup_endpoint`; `400 invalid_backup_bucket`; `400 invalid_backup_prefix`; `400 invalid_backup_region`; `400 invalid_backup_credentials`; `400 weak_backup_password`; `409 backup_password_locked` |
| Antarmuka | RPC `cs_api.backup_set_target`, `cs_api.backup_overview`; Hub: Pengaturan → Sistem → Backup → Tujuan backup |
| Lacak | BR-OPS |

#### FR-OPS-20 Jadwal dan retensi backup

| Atribut | Isi |
|---|---|
| Deskripsi | Hub harus memungkinkan Super Admin mengatur jadwal backup penuh, interval kirim WAL, retensi, dan uji restore mingguan dalam batas aman. |
| Aktor | Super Admin |
| Prakondisi | — |
| Proses dan aturan | 1) Jam backup penuh `HH:MM` (bawaan 02:00 WIB). <br>2) Interval kirim WAL 1–60 menit (bawaan 5). <br>3) Retensi harian 1–60 (7), mingguan 0–52 (4), bulanan 0–36 (6), WAL 1–35 hari (7). <br>4) Uji restore otomatis aktif/mati, hari 0–6 (0 = Minggu), jam `HH:MM` (bawaan Minggu 04:00). <br>5) Mingguan: prune → `restic check --read-data-subset=2%` → uji restore. <br>6) Diaudit `backup.schedule_set` dengan nilai lama dan baru. |
| Keluaran | Konfigurasi backup baru dipakai layanan backup |
| Kode error | `400 invalid_backup_schedule` |
| Antarmuka | RPC `cs_api.backup_set_schedule`; Hub: Pengaturan → Sistem → Backup → Jadwal & retensi |
| Lacak | BR-OPS |

#### FR-OPS-21 Backup penuh dan uji restore sesuai permintaan

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan Super Admin meminta backup penuh atau uji restore segera, dan menjalankan uji restore mingguan yang membuktikan backup bisa dipakai. |
| Aktor | Super Admin; layanan backup |
| Prakondisi | Tujuan backup sudah diatur |
| Proses dan aturan | 1) **Backup penuh sekarang** dan **Uji restore sekarang** meminta konfirmasi dan masuk antrean yang sama; permintaan sejenis yang belum diambil tidak digandakan. <br>2) Uji restore memulihkan backup terbaru ke data dir sementara, menjalankan Postgres sementara sampai WAL terakhir, menghitung baris tabel utama, lalu menghapus data sementara; database produksi tidak disentuh. <br>3) Durasi uji (`duration_s`) menjadi patokan RTO. <br>4) Diaudit `backup.requested`. |
| Keluaran | Riwayat `backup_runs` (base, files, wal, prune, check, restore_test) di halaman Backup |
| Kode error | `400 invalid_backup_request`; `409 backup_not_configured` |
| Antarmuka | RPC `cs_api.backup_request`; Hub: Pengaturan → Sistem → Backup → Jalankan sekarang |
| Lacak | BR-OPS |

#### FR-OPS-22 Alert backup

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuka alert ketika backup tidak diatur, terhenti, terlambat, atau gagal diuji. |
| Aktor | Database |
| Prakondisi | — |
| Proses dan aturan | 1) `backup:config` (peringatan) tujuan belum diatur. <br>2) `backup:repository` (kritis) repositori tidak bisa dibuka 5 menit setelah diatur. <br>3) `backup:wal` (kritis) `pg_receivewal` tidak berjalan; `backup:slot` (kritis) slot hilang. <br>4) `backup:base` (kritis) backup penuh berhasil terakhir > 26 jam lalu atau belum ada 2 jam setelah diatur; `backup:base_failed` (peringatan). <br>5) `backup:offsite` (kritis) WAL belum terkirim > 30 menit (atau 3× interval). <br>6) `backup:restore_test` (peringatan) uji terakhir gagal atau tidak ada yang berhasil selama 8 hari. <br>7) `backup:disk` staging < 10 %; `backup:repository_disk` folder lokal < 10 % (kritis < 5 %). <br>8) `db:slot:olt_backup:retained` (peringatan) slot tidak aktif menahan WAL > 256 MB. |
| Keluaran | Alert di Kesehatan sistem dan kanal alert |
| Kode error | — |
| Antarmuka | `private.health_checks_backup` (0065, 0112) |
| Lacak | BR-OPS |

#### FR-OPS-23 Pemulihan ke titik waktu

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan tim IT memulihkan seluruh database ke waktu tertentu dalam jendela retensi WAL, serta memulihkan file storage. |
| Aktor | Tim IT |
| Prakondisi | Akses ke repositori dan password enkripsi; restore tidak dilakukan dari Hub |
| Proses dan aturan | 1) `make backup-snapshots` menampilkan snapshot dan rentang waktu yang bisa dipulihkan. <br>2) `make restore-pitr AT=<waktu dengan zona> CONFIRM=yes` (atau `AT=latest`) menghentikan semua container termasuk healer, memulihkan backup penuh + WAL ke volume database, lalu hanya menyalakan database; layanan lain dinyalakan `make up` setelah data diperiksa. <br>3) File storage dipulihkan dengan `restic restore --tag files`. <br>4) Target: RPO ≤ interval kirim WAL (bawaan 5 menit) bila server hilang total; RTO ≤ 1 jam untuk database puluhan GB. <br>5) `make backup` (pg_dump + arsip file) tersedia untuk salinan sesaat, bukan pengganti backup berkelanjutan. |
| Keluaran | Database kembali ke titik waktu yang dipilih; data setelahnya hilang |
| Kode error | — |
| Antarmuka | `make backup-snapshots`, `make restore-pitr`, `make backup`, `make restore`; docs/panduan/backup.md |
| Lacak | BR-OPS |

#### FR-OPS-24 Pemulihan rahasia Vault setelah pindah server

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mendeteksi rahasia Vault yang tidak bisa dibuka setelah pemulihan ke server baru dan mengizinkan pengisian ulang dari Hub. |
| Aktor | Database; Super Admin |
| Prakondisi | Database dipulihkan tanpa `pgsodium_root.key` yang sama |
| Proses dan aturan | 1) `cs.vault_read` mengembalikan `null` bila rahasia tidak bisa didekripsi (0067). <br>2) Alert `backup:secret` (kritis) bila rahasia backup tidak terbaca; `alerts:secret` (peringatan) bila token Telegram atau password SMTP tidak terbaca. <br>3) `backup_config` menjawab `configured: false`, `problem: secret_unreadable`; kanal alert yang tidak terbaca tidak dikirim ke sentinel. <br>4) Selama rahasia lama tidak terbaca, password repositori yang sama boleh diisi ulang (audit `password_recovered`). <br>5) Kunci Firebase diisi ulang di Pengaturan → Integrasi → Push notification. <br>6) `pgsodium_root.key`, `docker/.env`, `docker/secrets/`, dan password backup wajib disimpan di luar server. |
| Keluaran | Rahasia baru tersimpan dan alert pulih |
| Kode error | `400 weak_backup_password`; `400 invalid_backup_credentials` |
| Antarmuka | `private.health_checks_secrets`; RPC `cs_api.backup_set_target`; Hub: Pengaturan → Sistem → Backup, Alert |
| Lacak | BR-OPS |

#### FR-OPS-25 Pembersihan file tak terpakai (janitor)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghapus isi folder Storage yang masuk antrean pembersihan secara bertahap, aman diulang, dan terkendali dari database. |
| Aktor | Janitor; database |
| Prakondisi | Baris di `private.storage_cleanup_queue` |
| Proses dan aturan | 1) Sumber antrean: penghapusan akun (avatar `avatars`, lampiran postingan dan chat `attachments`, dokumen chat CS `cs-documents`), gambar banner yang diganti atau dihapus, dan folder bukti kedaluwarsa (`evidence_expired`). <br>2) `storage_cleanup_claim` mengunci folder selama `LEASE` (5 menit) dan memberi maksimal `OBJECTS_PER_ENTRY` (1000) nama objek yang dibuat sebelum folder diantrekan. <br>3) Janitor menghapus per `DELETE_CHUNK` (100), `CONCURRENCY` (4) folder paralel, lalu melapor lewat `storage_cleanup_report`. <br>4) Gagal dijadwal ulang dengan jeda berlipat maks 6 jam; gagal ≥ 3 kali membuka alert `queue:storage_cleanup`. <br>5) Folder sumber bukti tidak diberikan selama salinan bukti belum selesai. <br>6) Baris selesai > 90 hari dihapus (`storage-cleanup-purge`). |
| Keluaran | Objek Storage terhapus; metrik `janitor_objects_deleted_total` |
| Kode error | — |
| Antarmuka | RPC `public.storage_cleanup_claim`, `public.storage_cleanup_report` (0060); `services/janitor` |
| Lacak | BR-OPS |

#### FR-OPS-26 Salinan file bukti terverifikasi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyalin file konten yang dilaporkan atau dihapus ke bucket privat `evidence` dan memverifikasi sidik SHA-256 sebelum file asli boleh dihapus. |
| Aktor | Janitor |
| Prakondisi | Baris di `private.evidence_files` (0095) |
| Proses dan aturan | 1) Unduh file sumber dan hitung SHA-256, salin lewat `POST /object/copy` ke `evidence` (`x-upsert: true`), unduh salinan dan hitung ulang. <br>2) Hasil `copied` (sha256 + size), `missing`, `error` (dicoba lagi sampai 6 jam, `failed` setelah 30 kali), atau `release`. <br>3) Database memeriksa salinan ada di `storage.objects` dan ukurannya cocok sebelum menandai `copied`. <br>4) Pengelolaan bukti dan legal hold dispesifikasikan di PATUH. |
| Keluaran | Salinan bukti utuh di bucket `evidence` |
| Kode error | — |
| Antarmuka | RPC `evidence_copy_claim`, `evidence_copy_report`; `services/janitor` |
| Lacak | BR-OPS |

#### FR-OPS-27 Retensi data sosial

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghapus data sosial yang melewati masa simpan secara terjadwal, kecuali arsip yang berada dalam legal hold. |
| Aktor | Job `olt-retention` |
| Prakondisi | — |
| Proses dan aturan | 1) Notifikasi > `retention.notifications_days` (90). <br>2) Pesan yang sudah dihapus > `retention.deleted_messages_days` (30). <br>3) Arsip konten dengan `retain_until` lewat dan `legal_hold = false`. <br>4) Audit log admin (`private.admin_audit_log`) > `retention.audit_log_days` (1825 sejak 0195). <br>5) Log akses data pribadi > `retention.access_log_days` (730). <br>6) Event rate limit > `retention.rate_limit_events_days` (2). <br>7) Hasil hitungan per jenis dicatat di log (`olt.retention`). <br>8) Retensi konten aktif dan chat CS dijalankan penjaga retensi (0195, lihat 6.3). |
| Keluaran | Objek JSON jumlah baris terhapus per jenis |
| Kode error | — |
| Antarmuka | `private.run_retention()` (0015); cron `olt-retention` |
| Lacak | BR-OPS |

#### FR-OPS-28 Arsip konten dan legal hold pada job

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyimpan konten yang dihapus selama masa arsip dan tidak pernah menghapus arsip atau bukti yang ditandai legal hold. |
| Aktor | Database (trigger dan job) |
| Prakondisi | — |
| Proses dan aturan | 1) Konten yang dihapus masuk `private.content_archive` dengan `retain_until = deleted_at + retention.archive_days` (bawaan 1825 hari) bila belum diisi (0013). <br>2) `run_retention` hanya menghapus arsip dengan `retain_until` lewat dan tanpa legal hold. <br>3) `evidence-purge` menghapus maksimal 1000 bukti per putaran yang `retain_until` lewat dan tanpa legal hold, mengantrekan folder filenya ke janitor, dan mengaudit `evidence.purged` (kode `EV-…`, sidik). <br>4) Pemasangan dan pelepasan legal hold oleh Kepatuhan dispesifikasikan di PATUH. |
| Keluaran | Arsip dan bukti tersimpan sesuai masa simpan |
| Kode error | — |
| Antarmuka | `private.content_archive`, `private.evidence_purge()`; cron `olt-retention`, `evidence-purge` |
| Lacak | BR-OPS |

#### FR-OPS-29 Partisi tabel bervolume tinggi

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus membuat partisi bulanan untuk tabel log bervolume tinggi lebih awal dan membuang partisi analitik yang melewati retensi. |
| Aktor | Job pg_cron |
| Prakondisi | — |
| Proses dan aturan | 1) `cs.ensure_partitions(3)` membuat partisi bulanan `cs.session_events` dan `cs.cs_audit_log` sampai 3 bulan ke depan dengan RLS aktif; partisi yang bentrok dengan isi partisi default dilewati dengan peringatan (0028). <br>2) `private.analytics_maintenance()` membuat partisi `private.analytics_events` 3 bulan ke depan dan menghapus partisi serta baris default yang lebih tua dari `analytics.retention_months` (12) (0078). |
| Keluaran | Partisi tersedia sebelum data bulan berjalan masuk |
| Kode error | — |
| Antarmuka | Cron `cs-partitions`, `social-analytics` |
| Lacak | BR-OPS |

#### FR-OPS-30 Jadwal job database dan pemantauannya

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menjalankan semua pekerjaan berkala di dalam database lewat pg_cron dan memperlihatkan status setiap job kepada Super Admin. |
| Aktor | pg_cron; Super Admin |
| Prakondisi | Ekstensi `pg_cron` |
| Proses dan aturan | 1) Daftar job dan jadwal mengikuti tabel di awal bagian ini. <br>2) Job terakhir yang gagal membuka alert `cron:<job>`. <br>3) Tab Status menampilkan job, jadwal, aktif, status dan pesan jalannya terakhir dari `cron.job_run_details`. <br>4) Job dimatikan sementara hanya di staging (`cron.alter_job ... active := false`) untuk uji. |
| Keluaran | Daftar job di Kesehatan sistem |
| Kode error | — |
| Antarmuka | `cron.job`, `cron.job_run_details`; RPC `cs_api.system_health` |
| Lacak | BR-OPS |

#### FR-OPS-31 Log dan endpoint ops

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menghasilkan log terstruktur tanpa rahasia dengan rotasi otomatis, dan menyediakan endpoint ops internal per layanan. |
| Aktor | Semua layanan |
| Prakondisi | — |
| Proses dan aturan | 1) Semua container memakai rotasi json-file 10 MB × 5 file. <br>2) Log layanan Go berformat JSON (slog) berbahasa Inggris dengan `request_id`; token, password, header rahasia, isi pesan, dan cust id tidak pernah ditulis. <br>3) Endpoint `/livez`, `/readyz`, `/metrics` (Prometheus) hanya di jaringan Docker; `readyz` bernilai `degraded` saat dependensi opsional bermasalah. <br>4) Log dibaca dengan `make logs s=<layanan>` atau `docker logs olt-social-<layanan>-1 --since 15m`. |
| Keluaran | Log dan metrik yang bisa dipakai saat gangguan |
| Kode error | — |
| Antarmuka | `make logs`; port ops internal (mis. auth-bridge 9100) |
| Lacak | BR-OPS |

#### FR-OPS-32 Gerbang unggah file (media)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mewajibkan setiap unggahan file nasabah melewati layanan media yang memeriksa jenis file dari isinya dan membuang metadata sebelum disimpan. |
| Aktor | Layanan media |
| Prakondisi | JWT nasabah `authenticated` (HS256) |
| Proses dan aturan | 1) Bucket yang diizinkan: `avatars` (2 MiB; JPEG, PNG, WebP), `attachments` (5 MiB; room CS sampai batas kebijakan, bawaan 10 MiB), `cs-documents` (10 MiB), `cs-videos` (25 MiB, maks 120 detik). <br>2) Path 1–6 segmen `[A-Za-z0-9._-]{1,128}`, total ≤ 400 karakter. <br>3) Jenis ditentukan dari magic bytes; `Content-Type` klien diabaikan; ekstensi diganti ekstensi kanonik. <br>4) Sanitasi lossless: EXIF/GPS, XMP, IPTC, komentar, dan data setelah akhir file dibuang; PDF terenkripsi atau berkonten aktif ditolak; Office bermakro atau berbahaya ditolak; video di-remux tanpa metadata. <br>5) File diteruskan ke Storage dengan JWT baru berklaim `media_verified: true`; RLS storage menolak unggahan nasabah tanpa klaim itu (0063). <br>6) Maks `MAX_CONCURRENT` slot; menunggu > 5 detik ditolak. <br>7) Kebijakan lampiran CS dan keputusan moderasi gambar dispesifikasikan di CS dan MOD. |
| Keluaran | `{bucket, path, mime, size, width, height}` (video: `duration`, `thumbnail`; gambar ditahan: `held`) |
| Kode error | `401 invalid_token`; `400 bucket_not_allowed`; `400 invalid_path`; `400 empty_file`; `413 file_too_large`; `415 unsupported_type`; `422 invalid_text`; `422 invalid_pdf`; `422 pdf_encrypted`; `422 pdf_active_content`; `422 office_macro`; `422 office_unsafe`; `422 archive_bomb`; `422 invalid_video`; `422 video_too_long`; `422 image_blocked`; `403 kind_disabled`; `503 policy_unavailable`; `503 busy` |
| Antarmuka | `POST /media/v1/object/{bucket}/{path}`; `services/media` |
| Lacak | BR-OPS |

#### FR-OPS-33 Pemindaian antivirus fail-closed

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memindai setiap dokumen dan video chat CS dengan ClamAV sebelum disimpan dan menolak unggahan bila pemindai tidak tersedia. |
| Aktor | Layanan media; container `clamav` |
| Prakondisi | Unggahan ke `cs-documents` atau `cs-videos` |
| Proses dan aturan | 1) File asli dikirim ke clamd (`INSTREAM`). <br>2) Terdeteksi malware: ditolak, tidak ada yang disimpan. <br>3) Pemindai tidak bisa dipakai: unggahan ditolak dan bisa dicoba lagi nanti. <br>4) Signature diperbarui otomatis (clamav di network `egress`). <br>5) Kesehatan pemindai dilaporkan ke Kesehatan sistem (0132). |
| Keluaran | File bersih diteruskan ke langkah berikutnya |
| Kode error | `422 malware_detected`; `503 scanner_unavailable` |
| Antarmuka | `services/media`; container `clamav` (ClamAV 1.5.4) |
| Lacak | BR-OPS |

#### FR-OPS-34 Layanan klasifikasi gambar (classifier)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan skor NSFW per kategori untuk gambar dengan model lokal tanpa mengirim gambar ke pihak luar. |
| Aktor | Layanan classifier; dipanggil media dan link-preview |
| Prakondisi | Model termuat |
| Proses dan aturan | 1) Body byte gambar JPEG, PNG, WebP, GIF maksimal 10 MiB; jenis dari magic bytes; dimensi ≤ 10000 px per sisi dan ≤ 40 MP. <br>2) GIF animasi diambil 4 frame bila kanvas ≤ 4 MP; setiap frame dinilai dua tampilan (potongan tengah dan gambar penuh). <br>3) Skor kategori `drawings`, `hentai`, `neutral`, `porn`, `sexy` = maksimum semua tampilan/frame, dibulatkan 4 desimal. <br>4) Classifier tidak memutuskan dan tidak menyimpan apa pun; ambang dibaca pemanggil dari database (MOD). <br>5) Hanya di network `app`, tidak lewat Kong/Traefik. |
| Keluaran | `200 {model, labels, scores, kind, width, height, frames, sampled, views}` |
| Kode error | `400 empty_file`; `400 invalid_request`; `408 request_timeout`; `413 file_too_large`; `415 unsupported_type`; `422 image_too_large`; `422 invalid_image`; `500 inference_failed`; `503 model_missing`; `503 busy` |
| Antarmuka | `POST /classify`, `GET /status`; `services/classifier` |
| Lacak | BR-OPS |

#### FR-OPS-35 Layanan pratinjau tautan aman SSRF

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengambil judul, deskripsi, dan gambar tautan dari internet tanpa bisa diarahkan ke jaringan internal. |
| Aktor | Layanan link-preview |
| Prakondisi | URL diantrekan trigger konten yang terlihat (bukan chat CS) |
| Proses dan aturan | 1) Maksimal 3 URL http/https unik per konten; URL dinormalisasi dan di-hash; pratinjau segar 7 hari tidak diambil ulang (0080). <br>2) Pemeriksaan tiga lapis: URL dan setiap redirect, setiap alamat hasil DNS, dan alamat socket saat connect; rentang privat, loopback, link-local, CGNAT, metadata cloud, dan nama internal ditolak; hanya port 80 dan 443. <br>3) HTML maks 1 MiB setelah dekompresi, gambar maks 5 MiB, batas 5 detik per request, maks 3 redirect; proxy dari env diabaikan. <br>4) Gambar dibersihkan metadatanya dan dinilai classifier sebelum diunggah ke bucket publik `link-previews` (0094). <br>5) Domain diblokir dicek saat antre, claim, laporan (domain akhir), dan baca; gagal query = semua diblokir. <br>6) `public.link_previews` hanya dibaca lewat RPC dengan URL persis. |
| Keluaran | Pratinjau di `public.link_previews` |
| Kode error | — |
| Antarmuka | RPC `link_preview_claim`, `link_preview_report`, `get_link_previews`; `services/link-preview` |
| Lacak | BR-OPS |

### 4.12 Berbagi Trade (TRADE)

Berbagi Trade adalah fitur yang memungkinkan nasabah yang disetujui Kepatuhan (trader) membagikan trade yang sudah match di rekeningnya kepada pelanggan, hanya sebagai informasi tanpa order otomatis (docs/berbagi-trade/rencana.md). Fitur ini **DIJEDA sejak 15 November 2026 dan berada di luar lingkup rilis ini**. Kondisinya: flag Hub `SHOW_TRADE_SHARE = false` (`src/lib/nav-config.ts`) menyembunyikan menu Berbagi Trade, Pengaturan → Relay Trade, tab Sistem → Relay Trade, dan izin Berbagi Trade di akun staf; container `trade-relay` dan `dummy-iproxy` hanya ada di profil compose `trade-relay` sehingga `make up` tidak menjalankannya; `Makefile` dan `make.ps1` tidak punya perintah relay apa pun; di cluster `trade-relay` berjalan `replicas: 0`. Kode tetap disimpan: migrasi 0160–0166 (beserta job `trade-share-tick` dan `trade-share-maintenance` yang tetap terjadwal), `services/trade-relay`, kolom `cs.agents.trade_permissions`, dan modul library. Tombol darurat `trade_share.enabled` dan `trade_notify.enabled` bernilai `false`, sehingga aplikasi nasabah tidak menampilkan fitur ini dan tidak ada data trade yang diproses (docs/berbagi-trade/operasional.md). FR di bawah hanya mencatat kemampuan yang dimaksud sebagai pekerjaan masa depan; semuanya berstatus **Ditunda** dan tidak diuji pada rilis ini.

#### FR-TRADE-01 Pengajuan dan peninjauan trader (Ditunda)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan nasabah mengajukan diri sebagai trader dan staf Kepatuhan berizin meninjaunya (status: Ditunda). |
| Aktor | Nasabah; staf dengan `trade_share.review` atau `trade_share.manage` |
| Prakondisi | Fitur diaktifkan kembali; dokumen S&K Berbagi Trade dan Pernyataan Risiko Berbagi Trade terbit |
| Proses dan aturan | 1) Pengajuan dari aplikasi; bawaan hanya profil undangan pilot (`trade_share.pilot_only`), umur profil minimal 30 hari (`trade_share.min_account_age_days`), masa tunggu 30 hari setelah ditolak atau dicabut (0160). <br>2) Staf dapat menyetujui, menolak, menangguhkan, atau mencabut; empat mata opsional (`trade_share.four_eyes`, bawaan `false`). |
| Keluaran | Status trader tercatat dan diaudit |
| Kode error | — |
| Antarmuka | Hub: Kepatuhan → Berbagi Trade (tersembunyi); migrasi 0160, 0164 |
| Lacak | BR-TRADE |

#### FR-TRADE-02 Langganan pelanggan (Ditunda)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus memungkinkan nasabah berlangganan notifikasi trade dari trader dengan mode otomatis atau perlu persetujuan trader (status: Ditunda). |
| Aktor | Pelanggan; trader |
| Prakondisi | Fitur diaktifkan kembali; trader berstatus disetujui |
| Proses dan aturan | 1) Langganan satu arah, bukan grup. <br>2) Maksimal 20 trader per pelanggan (`trade_share.max_subscriptions`); permintaan tak dijawab kedaluwarsa 14 hari (`trade_share.request_expiry_days`) (0160, 0161). |
| Keluaran | Langganan aktif atau permintaan menunggu |
| Kode error | — |
| Antarmuka | Library modul Berbagi Trade (1.28.0); migrasi 0161 |
| Lacak | BR-TRADE |

#### FR-TRADE-03 Relay pasif dari iProxy OLT (Ditunda)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menerima update order dan trade realtime dari iProxy OLT secara pasif dan hanya-baca untuk rekening trader yang disetujui (status: Ditunda). |
| Aktor | Layanan `trade-relay`; staf dengan `trade_relay.operate` |
| Prakondisi | OLT membuka port iProxy untuk server sosial; konfigurasi relay diisi Super Admin di Hub |
| Proses dan aturan | 1) Relay terhubung seperti proses OLT `clientOrdersRealtimeMME`, menyaring paket order dan trade, lalu meneruskan ke database (0162). <br>2) Pemetaan rekening memakai `private.account_links`. <br>3) Relay bisa disambung ulang atau di-restart dari Hub oleh staf berizin. |
| Keluaran | Update order dan fill tersimpan di database |
| Kode error | — |
| Antarmuka | `services/trade-relay`; Hub: Pengaturan → Integrasi → Relay Trade (tersembunyi) |
| Lacak | BR-TRADE |

#### FR-TRADE-04 Notifikasi aktivitas trade ke pelanggan (Ditunda)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus mengirim satu notifikasi per order trader yang selesai kepada pelanggannya setelah jeda minimum (status: Ditunda). |
| Aktor | Database (job `trade-share-tick`) |
| Prakondisi | Fitur dan tombol darurat dinyalakan |
| Proses dan aturan | 1) Beli dan jual selalu dibagikan; harga dan lot tampil bawaan, trader boleh menyembunyikan masing-masing, Kepatuhan bisa memaksa tersembunyi (`trade_share.force_hide_price`, `trade_share.force_hide_lot`). <br>2) Jeda minimum 15 menit (`trade_share.min_delay_minutes`), maksimum pilihan trader 240 menit. <br>3) Batas 50 push per pelanggan per hari (`trade_share.daily_push_cap`); sapuan akhir hari 16.30 WIB untuk order terisi sebagian (0163). |
| Keluaran | Notifikasi aktivitas trade di kotak notifikasi dan push |
| Kode error | — |
| Antarmuka | Cron `trade-share-tick`; migrasi 0163 |
| Lacak | BR-TRADE |

#### FR-TRADE-05 Tombol darurat dan pemantauan Kepatuhan (Ditunda)

| Atribut | Isi |
|---|---|
| Deskripsi | Sistem harus menyediakan tombol darurat yang mematikan seluruh fitur seketika beserta pemantauan Kepatuhan (status: Ditunda). |
| Aktor | Staf Kepatuhan dengan `trade_share.manage`; Super Admin |
| Prakondisi | Fitur diaktifkan kembali |
| Proses dan aturan | 1) `trade_share.enabled` mati: UI di library tersembunyi dan tidak ada data trade yang diproses. <br>2) `trade_notify.enabled` mengatur push trade match milik nasabah sendiri lewat relay. <br>3) Trader dengan pelanggan aktif ≥ 1000 masuk daftar tinjauan (`trade_share.review_subscriber_threshold`, 0160); status order, aktivitas, dan job pengiriman disimpan 30 hari (`trade_share.retention_days`, 0163); pemantauan dan pemeliharaan di 0164. |
| Keluaran | Fitur mati atau hidup tanpa rilis ulang aplikasi |
| Kode error | — |
| Antarmuka | Hub: Kepatuhan → Berbagi Trade (tersembunyi); cron `trade-share-maintenance` |
| Lacak | BR-TRADE |

## 5. Kebutuhan antarmuka eksternal

Bagian ini menetapkan antarmuka yang dilihat pengguna (aplikasi nasabah lewat library dan Rendezvous Hub), antarmuka perangkat lunak (API, realtime, layanan pendukung, sistem eksternal), dan antarmuka komunikasi (protokol, port, jaringan). Kode error setiap antarmuka dirangkum di 11.2, daftar RPC lengkap di 11.3.

### 5.1 Antarmuka pengguna

#### 5.1.1 Aplikasi nasabah (library `rendezvous_community` v1.49.2)

Rendezvous tidak punya aplikasi nasabah sendiri. UI nasabah adalah library Flutter `rendezvous_community` v1.49.2 (pubspec.yaml) yang dipasang tim OLT di aplikasi trading OLT. Library harus memenuhi ketentuan umum berikut:

| Ketentuan | Isi | Sumber |
|---|---|---|
| Widget tanpa `Scaffold` | Semua widget adalah konten tanpa `Scaffold`, sehingga OLT tetap memegang AppBar, navigasi, dan tata letak halaman. Fungsi `open*`/`show*` membuka halaman atau dialog bawaan bila host tidak punya halaman sendiri | doc/integration.md bagian 5 |
| Platform | Windows dan Android (target utama), juga iOS, macOS, dan web. Windows membuka video dan dokumen CS lewat aplikasi bawaan sistem karena `video_player` belum mendukung Windows; web membuka dokumen di tab baru | doc/integration.md bagian 2 |
| Kompatibilitas | Flutter ≥ 3.44, Dart ≥ 3.12, `flutter_bloc` 9, `supabase_flutter` 2.x, Material 3. Dependensi dipasang lewat git dengan `ref` tag rilis (`v1.49.2`) | doc/integration.md bagian 1 |
| Versi server | Server dengan migrasi 0098 (pesan lewat Broadcast) butuh library ≥ 1.5.0. Fitur lain menyebut migrasi minimum masing-masing (mis. Info grup 0146, pengaduan tamu 0140, kontrol komentar 0169) | doc/integration.md |
| Bahasa | Indonesia (bawaan, juga tanpa delegate) dan Inggris lewat `CommunityLocalizations.delegate`; teks push dan notifikasi dibuat server sesuai `locale` perangkat | doc/integration.md bagian 4, docs/push/README.md |
| Tema | Warna diturunkan dari `ThemeData` host (terang dan gelap). Penyesuaian lewat `ThemeExtension` `CommunityTheme` (warna bullish/bearish, indentasi thread) dan `CommunityStyle` (latar, kartu, teks, spasi, radius, tipografi, ikon `CommunityIcons`, `menuItemHeight` bawaan 36, warna `danger`) | doc/customization.md bagian Tema |
| Builder / slot | Tampilan bisa diganti per bagian tanpa menulis ulang logika lewat `CommunityBuildersScope` + `CommunityBuilders` dengan set `chat`, `feed`, `notifications`, `profile`, `badges`, `shared`, `discovery`, `support`, `settings`, `system`, `help`, `tradeShare`. Setiap builder menerima `details` (data + handler), `fallback` (tampilan bawaan), dan `context`. Scope boleh bersarang | doc/customization.md, doc/builders.md |
| Tata letak | Kolom konten maksimal 720 px; `CommunityChatList` multi-panel pada lebar ≥ 840 px; dialog di layar lebar, bottom sheet di ponsel | doc/features.md Fitur UI |
| Desktop | Enter mengirim, Shift+Enter baris baru, tempel gambar Ctrl+V, seleksi teks dengan mouse, scroll seret mouse (`CommunityScrollSettings`, `CommunityMouseDragScrollBehavior`) | doc/features.md, doc/integration.md |
| Data saham | Library tidak menyimpan daftar, nama, harga saham, order, atau portofolio. Saran `$KODE` dari callback `stockSearch` milik OLT; ketukan `$KODE` memanggil `onStockTap` | doc/integration.md bagian 3 |
| Galat | Semua method repository melempar `CommunityException` dengan `kind` `network`, `unauthenticated`, `rateLimited`, `contentBlocked`, `invalidInput`, `forbidden`, `notFound`, `unavailable`, `unknown`; widget bawaan menampilkan pesan terlokalisasi | doc/integration.md bagian 6 |
| Log | Library tidak mencetak ke konsol; log berbahasa Inggris lewat `logHandler`, data sensitif disamarkan | doc/logging.md |

API publik utama (diekspor dari `lib/rendezvous_community.dart`):

| Kelompok | API publik | Fungsi | Modul |
|---|---|---|---|
| Inisialisasi dan sesi | `RendezvousCommunity.initialize(supabaseUrl, anonKey, authBridgeUrl, tokenProvider, ...)` | Menyiapkan library setelah login OLT. `authBridgeUrl` bawaan `<supabaseUrl>/bridge/v1`; `tokenProvider` mengembalikan token sosial OLT yang masih berlaku. Parameter opsional: `onStockTap`, `onIndexTap`, `onUserTap`, `onPostTap`, `onThreadTap`, `onRoomTap`, `stockSearch`, `stockInfo`, `onHashtagTap`, `onOltNotificationTap`, `onBannerLink`, `chatStockCards`, `postDrafts`, `onOfficialContact`, `appVersion`, `platform` (`android`, `ios`, `web`, `windows`, `macos`, `linux`), `onUpdateRequired`, `signInEagerly`, `trackDelivery`, `offlineCache`, `offlineMessageLimit` (bawaan 200), `offlineCacheKey`, `imageCache`, `scroll`, `guestSessionStore`, `logHandler`, `logLevel` | AKUN |
| Sesi | `ensureSignedIn()`, `signOut()`, `dispose()`, `currentUser`, `clearLocalCache()` | Memastikan sesi, keluar (menutup realtime, melepas token push, menghapus cache), membersihkan cache lokal | AKUN |
| Konfigurasi klien | `clientConfig`, `clientConfigChanges`, `refreshClientConfig()`, `CommunitySocialGate`, `CommunityAvailabilityScope` | Kill switch, feature flag, versi minimum (`update_required`), placeholder saat fitur sosial dimatikan | AKUN |
| Privasi dan akun | `CommunityAccountSettings`, `openCommunityAccountSettings`, `exportMyData()`, `deleteMyAccount()`, `CommunityDmPolicySettings`, `CommunityMentionPolicySettings`, `CommunityCommentAudienceSettings` | Dokumen hukum, unduh data saya, hapus akun komunitas, kebijakan DM, mention, dan audiens komentar | AKUN, KOM |
| Dokumen hukum | `legalDocuments()`, `pendingLegalDocuments()`, `acceptLegalDocuments()`, `CommunityConsentBanner`, `showCommunityConsent`, `communityConsentGate`, `CommunityLegalDocumentReader` | Persetujuan dokumen wajib; aksi yang ditolak `consent_required` diulang otomatis setelah setuju | AKUN |
| Stream dan feed | `CommunityStreamFeed`, `CommunityFeedList`, `CommunityFeedFilterTabs`, `CommunityFeedFilters`, `FeedScope`, `CommunityFeedSort`, `CommunityPostOpenMode` | Feed Terbaru/Mengikuti/akun resmi/watchlist/saham, tab filter Stream, komentar inline | KOM |
| Saham dan indeks | `CommunityStockFeed`, `CommunityIndexList`, `CommunityIndexFeed`, `CommunityInstruments`, `StockCards`, `showStockCardPicker` | Stream per saham/indeks, daftar indeks dari Hub, kartu saham | KOM, CHAT |
| Postingan dan komentar | `CommunityComposePost`, `showCommunityComposer`, `CommunityComposePromptCard`, `CommunityPostDetail`, `CommunityPostComments`, `CommunityPollView`, `CommunityPostDrafts`, `CommunityBookmarks`, `LinkPreviewCard` | Tulis post (gambar, polling, sentimen, `$KODE`), detail dan thread komentar, draf, bookmark, link preview | KOM |
| Profil dan penemuan | `CommunityUserProfile`, `CommunityFollowList`, `CommunitySuggestedUsers`, `CommunitySearch`, `openCommunitySearch`, `CommunityHashtagFeed`, `CommunityTrending`, `CommunityMarketSentiment`, `CommunityStockSentiment`, `CommunityStockStatsBuilder` | Profil, pengikut/diikuti, saran akun, pencarian, hashtag, trending, sentimen | KOM |
| Chat | `CommunityChatList`, `CommunityChatRoom`, `CommunityChatBadge`, `CommunityGroupInfo`, `CommunityMessageRequests`, `openCommunityMessageRequests`, `showSharePostToChat`, `CommunityNavigator` | Daftar chat (room CS disematkan teratas), room DM/grup/saham, info grup, permintaan pesan, bagikan post | CHAT |
| Chat CS | `CommunitySupportChat`, `CommunitySupportPage`, `openCommunitySupport(context, topic, screen)`, `CommunitySupportTickets`, `CommunitySupportBadge`, `saveSupportTranscript` | Pilih topik, tiket, rating, pengaduan, lapor CS palsu, riwayat tiket, transkrip | CS |
| Pengaduan tamu | `CommunityGuestSupport`, `CommunityGuestSupportPage`, `openCommunityGuestSupport`, `CommunityGuestSupportClient.anonymous`, `CommunityGuestSupportScope`, `CommunityGuestSessionStore` | Pengaduan dari halaman login OLT tanpa sesi (RPC `guest_*` dengan anon key) | CS |
| Pusat Bantuan | `CommunityHelpCenter`, `openCommunityHelpCenter`, `CommunityHelpArticleView`, `openCommunityHelpArticle`, `openHelpAttachment` | Artikel FAQ dua bahasa, kategori, pencarian, lampiran artikel | BANTU |
| Notifikasi | `CommunityNotificationList`, `CommunityNotificationBadge`, `CommunityNotificationSettings`, `openCommunityNotificationSettings`, `CommunityNoticePage`, `openCommunityNotice` | Kotak notifikasi, badge, preferensi per jenis, halaman notifikasi info | NOTIF |
| Push | `registerPushToken(token, platform, locale, appVersion)`, `unregisterPushToken()`, `openCommunityPush(context, data)`, `isCommunityPush`, `isOltPush`, `reportNotificationOpened/Tapped` | Mendaftarkan token FCM milik host, membuka push milik library; push `olt.*` dikembalikan ke host | NOTIF |
| Banner dan popup | `CommunityBannerHost`, `CommunityBannerScope`, `CommunityPromoPopupHost`, `showCommunityPromoPopup`, `CommunityOfflineBanner` | Strip, popup tengah (sekali per sesi, aturan frekuensi), banner offline | NOTIF |
| Moderasi dari sisi pengguna | `CommunityAppeals`, `openCommunityAppeals`, `showCommunityAppealDialog`, `RoomModerationBanner`, `RoomModeratorBadge` | Banding, status sanksi, slow mode/pin room saham | MOD |
| Analitik | `trackOrderTap()`, `CommunityAnalytics` | Mencatat perpindahan dari komunitas ke layar order | KOM |
| Repository | `RendezvousCommunity.instance.feed`, `chat`, `comments`, `polls`, `profiles`, `stocks`, `notifications`, `support`, `help`, `groups`, dll. | API tanpa UI bawaan untuk host yang membangun UI sendiri | semua |
| Berbagi Trade (dijeda) | `CommunityTradeShareGate`, `openCommunityTradeShare`, `CommunityTradeSharePage`, dll. | Tersembunyi otomatis karena `trade_share.enabled` mati; di luar lingkup rilis ini | TRADE |

#### 5.1.2 Rendezvous Hub (web staf)

Rendezvous Hub adalah aplikasi web staf (React 19.3.1, TypeScript 6.0.3, TanStack Router 1.170.46, Tailwind 4.3.3; rendezvous_hub/package.json), disajikan container `cs-console` di domain CS. Menu bar atas dan rute didefinisikan di `src/app/top-bar.tsx` dan `src/app/router.tsx`; label dari `src/i18n/id.ts`.

Ketentuan umum Hub:

| Ketentuan | Isi | Sumber |
|---|---|---|
| Akses jaringan | Hanya dari LAN kantor atau VPN (`VPN_SOURCE_RANGES`, ipAllowList Traefik); IP lain mendapat 403 | docker/volumes/traefik/cs.yml, docs/panduan/produksi.md |
| Login | Email + password GoTrue (minimal 12 karakter, wajib ganti saat login pertama/setelah reset), 2FA TOTP wajib untuk Super Admin dan peran lain yang diwajibkan, kunci akun setelah 5 kali salah selama 15 menit (bawaan, 0186) | docs/panduan/hub-untuk-staf.md 1.2 |
| Sesi per tab | Sesi disimpan di `sessionStorage` (`initSupabase(env, storage = window.sessionStorage)`), sehingga setiap tab memegang sesi staf sendiri dan beberapa akun bisa dibuka bersamaan di satu browser; ganti password dan "Keluar dari semua perangkat" hanya memengaruhi akun sendiri | src/lib/supabase.ts, hub-untuk-staf.md 1.4 |
| Keluar otomatis | Dialog **Masih di sana?** setelah tidak aktif (bawaan 30 menit) | hub-untuk-staf.md 1.2 |
| Bahasa | Indonesia dan Inggris (`src/i18n/id.ts`, `en.ts`), dipilih dari menu akun **Bahasa** | rendezvous_hub/src/i18n |
| Tema dan kepadatan | **Tema**: **Terang**, **Gelap**, **Ikuti sistem**; **Kepadatan**: **Nyaman**, **Padat** | hub-untuk-staf.md 1.4 |
| Palet perintah | Kotak cari di tengah bar atas (Ctrl K): cari tiket, nasabah, menu, atau perintah. Bukti untuk Super Admin dibuka lewat palet ini | hub-untuk-staf.md 1.3–1.4 |
| Indikator | Status koneksi (**Terhubung**, **Menyambung ulang…**, **Offline**), lonceng notifikasi tiket baru (**Semua tiket**, **Prioritas tinggi saja**, **Mati**, notifikasi browser, tes suara), badge angka di menu yang perlu tindakan | hub-untuk-staf.md 1.4, top-bar.tsx |
| Menu akun | **Profil saya**, **Kinerja saya** (staf yang menangani tiket), **Ganti password**, **Tema**, **Kepadatan**, **Bahasa**, **Pintasan keyboard**, **Keluar dari semua perangkat**, **Keluar** | hub-untuk-staf.md 1.4 |
| Waktu | Semua waktu dalam WIB | hub-untuk-staf.md 1.4 |
| Tanpa menu | Akun tanpa menu melihat "Peran akun ini belum punya menu di web CS. Hubungi Super Admin." | i18n `nav.noAccess` |

Peran staf (`staffRoles`): `cs_agent` (**CS**), `cs_super_admin` (**Super Admin**), `compliance` (**Kepatuhan**), `community` (**Komunitas**, otomatis bila akun hanya punya Izin Komunitas), `product` (**Fitur & Banner**), `cs_content` (**Pusat Bantuan**). Izin tambahan: 5 Izin Komunitas (`community.post` Tulis postingan resmi, `community.publish` Setujui & terbitkan, `community.moderate` Moderasi konten, `community.sanction` Sanksi pengguna, `community.accounts` Kelola akun resmi) dan Akses Akun Nasabah (7 izin, khusus akun CS).

Menu bar atas, rute, dan peran yang melihatnya:

| Menu | Rute | Tab / bagian | Terlihat oleh | Sumber |
|---|---|---|---|---|
| **Layanan Nasabah** | `/` | Daftar tiket dengan tampilan **Terbuka**, **Tiket saya**, **Selesai hari ini**, **Semua aktif**; panel percakapan dan info nasabah | CS (`cs_agent`); Super Admin dalam mode pantau (tidak membalas) | router.tsx `canViewTickets`, i18n `tickets` |
| **Dashboard** | `/dashboard` | Dashboard supervisor | Super Admin | router.tsx `superAdminOnly` |
| **Laporan** | `/reports` | Laporan dan ekspor | Super Admin | router.tsx |
| **Akun Nasabah** | `/nasabah` | **Online ID**, **Approval**, **Pembukaan rekening**; tampil hanya bila integrasi API Nasabah aktif | Akun CS yang punya Akses Akun Nasabah (`hasNasabah`) | router.tsx, docs/nasabah/README.md |
| **Komunitas** | `/community` | **Postingan resmi** dan **Notifikasi** (izin `community.post` atau `community.publish`); **Moderasi** dengan antrean **Laporan**, **Konten ditahan**, **Gambar ditahan**, **Indikasi manipulasi**, **Banding** (izin `community.moderate` atau `community.sanction`); **Room saham** dan **Indeks** (izin `community.moderate`); **Akun resmi** (izin `community.accounts`); **Fitur & versi** dan **Tab Stream** (Super Admin, Fitur & Banner); **Analitik** (Super Admin) | Pemegang Izin Komunitas, Super Admin, Fitur & Banner (`canOpenCommunity`) | community/logic.ts `communityPageTabs`, i18n `community.tabs` |
| **Pusat Bantuan** | `/content` | **Topik chat CS**, **Artikel bantuan** | Super Admin, Pusat Bantuan (`cs_content`) | router.tsx `contentOnly`, i18n `content.tabs` |
| **Banner & Popup** | `/features` | Daftar banner (strip atas dan popup tengah), statistik, notifikasi info | Super Admin, Fitur & Banner (`product`) | router.tsx `featuresOnly`, features-campaigns-page.tsx |
| **Kepatuhan** (berjajar, atau menu bertingkat **Kepatuhan ▾** bila akun punya menu lain) | `/compliance` | **Ringkasan** | Kepatuhan | top-bar.tsx `complianceItems` |
| | `/compliance/cases` | **Kasus** | Kepatuhan | |
| | `/compliance/content` | **Kebijakan konten** dengan tab **Kata terlarang**, **Kategori**, **Domain**, **Frasa & pengecualian**, **Ambang gambar**, **Anti-manipulasi**, **Uji teks**, **Versi & persetujuan** | Kepatuhan | content-policy/types.ts, i18n/policy/id.ts |
| | `/compliance/policy` | **Tenggat & retensi** | Kepatuhan | |
| | `/compliance/legal` | **Dokumen hukum** | Kepatuhan | |
| | `/compliance/audit` | **Jejak Audit** | Kepatuhan | |
| | `/compliance/evidence` | **Bukti** | Kepatuhan; Super Admin hanya-baca lewat Ctrl K | router.tsx |
| **Pengaturan** | `/settings` | Grup **Layanan CS**: **Akun CS**, **Quick reply**, **Label tiket**, **Jam layanan & libur**, **Pesan otomatis**, **Lampiran chat CS**, **Penugasan, tiket & alert**, **Status layanan / gangguan**, **Survei kepuasan**. Grup **Persetujuan**: **Aturan empat mata**. Grup **Integrasi**: **Integrasi API Nasabah**, **Integrasi aplikasi**, **API Notifikasi**, **Push notification**. Grup **Sistem**: **Keamanan login**, **Kesehatan sistem** (tab **Peta layanan**, **Status**, **Restart otomatis**), **Backup**, **Alert** | Super Admin | settings/types.ts `settingsGroups`, system/types.ts, i18n `settings` |

Menu tersembunyi pada rilis ini: **Berbagi Trade** (`/compliance/trade-share`) dan **Relay Trade** (`/system`, bagian Pengaturan `tradeRelay`) karena `SHOW_TRADE_SHARE = false`; menu **Kesehatan sistem** tersendiri di bar atas karena `SHOW_SYSTEM_HEALTH_NAV = false` (kesehatan sistem dibuka dari Pengaturan) (src/lib/nav-config.ts). Rute lama `/analytics`, `/app`, `/compliance/words`, dan tab lama `/features?tab=features|stream` dialihkan otomatis (router.tsx). Rute `/__perf` hanya di luar produksi.

### 5.2 Antarmuka perangkat lunak

#### 5.2.1 Path publik dan pembagian domain

Server memakai dua nama domain di port 443 yang sama: domain API (`PROXY_DOMAIN`) untuk aplikasi OLT dan sistem OLT, dan domain CS (`CS_CONSOLE_DOMAIN`) untuk Hub. Traefik meneruskan ke Kong (`kong:8000`), Kong meneruskan ke layanan. Rute Kong `/rest/v1`, `/realtime/v1`, `/bridge/v1`, `/media/v1`, dan `/integration/v1` mewajibkan header `apikey` (plugin `key-auth` + `acl`, consumer `anon` atau admin); rute `/storage/v1` dan `/functions/v1` tidak memakai `key-auth` dan mengandalkan JWT yang diperiksa layanan tujuan (docker/volumes/api/kong.yml).

| Path | Tujuan | Domain API | Domain CS | Keterangan |
|---|---|---|---|---|
| `/rest/v1/` | PostgREST (`rest:3000`), skema `public`, `graphql_public`, `cs_api` | Ya, hanya skema `public` (header `Accept-Profile`/`Content-Profile` dibuang) + 27 RPC `cs_api` nasabah | Ya, semua skema | Body maks 256 KiB (`body-api`) |
| `/realtime/v1/` | Supabase Realtime (WebSocket) | Ya | Ya | Maks 1500 koneksi bersamaan per IP (`ws-limit`) |
| `/storage/v1/` | Supabase Storage | Ya (unggah `POST`/`PUT` maks 26 MiB) | Ya | Unggah nasabah wajib lewat `/media/v1` (klaim `media_verified`, 0063) |
| `/media/v1/` | Layanan `media` (`media:8080`) | Ya | Ya (`POST`) | Body maks 26 MiB (`body-upload`) |
| `/bridge/v1/` | `auth-bridge` (`auth-bridge:8080`) | Ya | – | Tukar token sosial |
| `/integration/v1/` | Layanan `integration` (`integration:8080`) | Ya | – | Server ke server, API key integrasi, body maks 2 MiB (`body-integration`) |
| `/auth/v1/` | GoTrue | Tidak dipublikasikan | Ya | Login staf |
| `/functions/v1/` | Edge function `cs-admin` | Tidak | Ya | Kelola akun staf |
| `/api-nasabah/` | `nasabah-gateway:8080` (langsung dari Traefik) | Tidak | Ya | Menu Akun Nasabah |
| `/` | `cs-console:8080` (Hub) | – | Ya | Halaman web Hub |
| `/graphql/v1`, `/pg`, Studio | – | Tidak dipublikasikan (404) | Tidak | Hanya lewat entrypoint admin `127.0.0.1:8000` (SSH tunnel/WireGuard) |

Sumber: docker/volumes/traefik/prod.yml, cs.yml, common.yml.

Aturan antarmuka domain:

1. **Allowlist `cs_api` di domain API.** Router `api-cs-customer` hanya meneruskan `/rest/v1/rpc/<nama>` untuk 27 RPC nasabah: `support_home`, `topics`, `open_ticket`, `my_tickets`, `ticket_messages`, `close_ticket`, `rate_ticket`, `request_complaint`, `report_fake_cs`, `check_sensitive`, `get_messages`, `send_message`, `mark_read`, `room_members`, `faq`, `faq_search`, `faq_article`, `faq_feedback`, `faq_for_topic`, `attachment_policy`, `service_status`, `ticket_transcript`, `guest_config`, `guest_start`, `guest_poll`, `guest_send`, `guest_end`. Permintaan lain ke profil `cs_api` di domain API ditolak 403 (`api-cs-staff-block`) (prod.yml).
2. **Header `X-Olt-Edge`.** Router publik REST, Realtime, Storage, dan media memasang `X-Olt-Edge: public` (menimpa nilai dari klien). Database menolak JWT akun staf yang membawa header ini: REST lewat `private.check_request` (0100) dengan `403 cs_staff_public_edge`, Realtime (join/presence) dan Storage lewat RLS (0105); media meneruskan header ini ke Storage. Domain CS membuang header ini (`cs-edge`) sehingga JWT staf diterima. `postgres_changes` ditolak untuk akun CS di domain mana pun (0105).
3. **Batas per IP di tepi.** Rate limit rata-rata 600 permintaan/detik dengan burst 1200 per IP (`EDGE_RATE_AVERAGE`, `EDGE_RATE_BURST`), WebSocket 1500 per IP (`EDGE_WS_PER_IP`) (common.yml). Batas per akun ditegakkan di database (`private.rate_limits`) dan auth-bridge.
4. **CORS.** Di profil single, `CORS_ALLOWED_ORIGINS` kosong (tidak ada origin web yang diizinkan; aplikasi native tidak butuh CORS) (docker/compose.prod.yml).
5. **Header keamanan.** HSTS 1 tahun dengan subdomain, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: no-referrer`, CSP `default-src 'none'` untuk API (common.yml); CSP halaman Hub diatur nginx `cs-console`.

#### 5.2.2 RPC utama per modul

RPC dipanggil lewat `POST /rest/v1/rpc/<fungsi>` dengan `apikey` + `Authorization: Bearer <JWT>`; RPC `cs_api` memakai header `Content-Profile: cs_api`. Tabel berikut memuat RPC yang paling menentukan perilaku tiap modul; daftar lengkap (482 fungsi) ada di 11.3. Kolom Pemanggil: **Nasabah** = JWT `authenticated` dari auth-bridge; **Staf** = JWT staf GoTrue dari Hub (peran diperiksa di dalam fungsi); **Tamu** = `anon`; **Layanan** = JWT `service_role` milik layanan internal.

| Modul | Skema.fungsi | Kegunaan | Pemanggil | Migrasi |
|---|---|---|---|---|
| AKUN | `public.upsert_olt_profile` | Buat/perbarui profil sosial saat tukar token; menolak profil terhapus selama jeda bergabung lagi | Layanan (auth-bridge) | 0175 |
| AKUN | `public.get_client_config` | Kill switch, feature flag, versi minimum, banner | Nasabah, Tamu | 0183 |
| AKUN | `public.get_profile` | Profil sosial | Nasabah | 0144 |
| AKUN | `public.get_legal_documents`, `get_pending_consents`, `accept_legal_document` | Dokumen hukum dan persetujuan | Nasabah | 0062, 0014, 0014 |
| AKUN | `public.get_dm_policy`, `set_dm_policy` | Kebijakan pesan langsung | Nasabah | 0070 |
| AKUN | `public.export_my_data` | Unduh data saya (JSON) | Nasabah | 0172 |
| AKUN | `public.delete_my_account` | Hapus akun komunitas | Nasabah | 0174 |
| KOM | `public.get_feed`, `get_feed_filters`, `get_post`, `get_pinned_posts` | Feed per cakupan, tab filter Stream, detail post, post tersemat | Nasabah | 0149, 0149, 0007, 0057 |
| KOM | `public.create_post`, `edit_post`, `delete_post`, `save_post_draft` | Tulis, ubah (jendela edit), hapus post, draf | Nasabah | 0169, 0075, 0004, 0150 |
| KOM | `public.create_comment`, `get_comment_thread`, `set_post_comment_audience`, `set_all_comments_off` | Komentar, thread, kontrol komentar | Nasabah | 0014, 0155, 0169, 0170 |
| KOM | `public.vote_poll`, `toggle_bookmark`, `search`, `get_trending`, `get_market_sentiment`, `get_follow_list` | Polling, bookmark, pencarian, trending, sentimen, daftar pengikut | Nasabah | 0019, 0075, 0073, 0074, 0143, 0148 |
| KOM | `public.get_mention_policy`, `set_mention_policy`, `get_market_instruments`, `get_stock`, `get_link_previews`, `track_events` | Pengaturan mention, indeks, saham, link preview, analitik klien | Nasabah | 0172, 0150, 0150, 0080, 0085 |
| CHAT | `public.get_my_rooms`, `get_messages`, `get_message_ids`, `get_messages_by_ids` | Daftar room, pesan berhalaman cursor, pengisian celah | Nasabah | 0154 |
| CHAT | `public.send_message`, `edit_message`, `delete_message`, `react_to_message`, `get_message_info` | Kirim, ubah, hapus pesan, reaksi, info pesan | Nasabah | 0008, 0154, 0031, 0075, 0122 |
| CHAT | `public.mark_rooms_delivered`, `mark_room_read`, `send_typing` | Centang terkirim/dibaca, mengetik | Nasabah | 0018, 0018, 0098 |
| CHAT | `public.get_or_create_direct_room`, `respond_message_request`, `create_group_room`, `update_group_settings`, `delete_group`, `leave_room`, `hide_room` | DM, permintaan pesan, grup, keluar/hapus chat | Nasabah | 0154, 0070, 0144, 0146, 0154, 0157, 0154 |
| CHAT | `public.join_stock_room`, `get_room_previews`, `share_post_to_chat` | Room saham, pratinjau room (polling), bagikan post | Nasabah | 0154, 0154, 0075 |
| CS | `cs_api.support_home`, `topics`, `open_ticket`, `my_tickets`, `ticket_messages` | Beranda chat CS, topik, buka tiket, riwayat | Nasabah | 0158, 0134, 0134, 0033, 0033 |
| CS | `cs_api.send_message`, `get_messages`, `mark_read`, `check_sensitive`, `attachment_policy` | Pesan chat CS, peringatan OTP/PIN, kebijakan lampiran | Nasabah | 0029, 0029, 0029, 0029, 0131 |
| CS | `cs_api.rate_ticket`, `close_ticket`, `request_complaint`, `report_fake_cs`, `service_status`, `ticket_transcript` | Rating (menutup tiket), tutup, pengaduan, lapor CS palsu, status gangguan, transkrip | Nasabah | 0135, 0033, 0033, 0033, 0135, 0136 |
| CS | `cs_api.guest_config`, `guest_start`, `guest_send`, `guest_poll`, `guest_end` | Pengaduan tamu tanpa login | Tamu | 0140 (`guest_end` 0159) |
| CS | `cs_api.agent_me`, `agent_set_status`, `agent_heartbeat` | Profil kerja agen, status, presence | Staf | 0165, 0033, 0033 |
| CS | `cs_api.ticket_lists`, `ticket_detail`, `claim_ticket`, `release_ticket`, `request_transfer`, `reassign_ticket`, `agent_send_message`, `add_note`, `resolve_ticket` | Antrean dan penanganan tiket | Staf (CS; Super Admin pantau) | 0033 (`agent_send_message` 0038) |
| CS | `cs_api.supervisor_overview`, `report_summary`, `admin_set_setting` | Dashboard, laporan, pengaturan layanan | Staf (Super Admin) | 0038, 0035, 0186 |
| BANTU | `cs_api.faq`, `faq_search`, `faq_article`, `faq_feedback`, `faq_for_topic` | Pusat Bantuan sisi nasabah | Nasabah | 0129 |
| BANTU | `cs_api.admin_faq_save_article`, `admin_faq_set_status`, `admin_faq_restore`, `admin_save_topic` | Kelola artikel dan topik | Staf (Super Admin, Pusat Bantuan) | 0188, 0129, 0188, 0127 |
| NOTIF | `public.get_notifications`, `mark_notifications_read`, `get_notification_prefs`, `set_notification_prefs` | Kotak notifikasi dan preferensi | Nasabah | 0076, 0003, 0076, 0087 |
| NOTIF | `public.register_push_device`, `unregister_push_device`, `get_app_notice`, `record_banner_event`, `report_notification_event` | Token push, notifikasi info, event banner, statistik dibuka/diketuk | Nasabah | 0058, 0058, 0184, 0185, 0088 |
| NOTIF | `public.push_claim`, `push_report`, `push_credentials` | Antrean push dan kunci Firebase untuk notifier | Layanan (notifier) | 0058, 0058, 0059 |
| NOTIF | `cs_api.push_set_credentials`, `push_test`, `community_save_campaign`, `admin_save_banner`, `admin_review_banner_notice` | Kunci Firebase, push uji, kampanye, banner, persetujuan notifikasi info | Staf | 0059, 0058, 0184, 0184, 0182 |
| MOD | `public.create_appeal`, `get_my_sanctions`, `room_mod_hide_message`, `room_mod_mute_user` | Banding, sanksi saya, aksi moderator room saham | Nasabah | 0071, 0013, 0093, 0096 |
| MOD | `cs_api.community_reports`, `community_resolve_report`, `community_held_content`, `community_media_review_decide`, `community_sanction_user`, `community_appeal_decide`, `community_zero_tolerance`, `community_manipulation_alerts`, `community_room_settings` | Antrean dan keputusan moderasi | Staf (Izin Komunitas) | 0057, 0057, 0069, 0079, 0057, 0071, 0071, 0072, 0072 |
| MOD | `public.media_hold` | Catat gambar ditahan | Layanan (media) | 0079 |
| PATUH | `cs_api.compliance_overview`, `compliance_cases`, `compliance_review`, `compliance_extend_deadline`, `compliance_audit`, `compliance_transcript_exported` | Ringkasan, kasus, tinjauan, perpanjangan tenggat, jejak audit, transkrip | Staf (Kepatuhan) | 0042, 0125, 0042, 0042, 0042, 0125 |
| PATUH | `cs_api.compliance_policy_submit`, `compliance_policy_decide`, `compliance_policy_simulate`, `compliance_policy_rollback`, `compliance_import_banned_words`, `compliance_set_new_account_days` | Kebijakan konten (draf, empat mata, simulasi, rollback, import kata terlarang, masa akun baru) | Staf (Kepatuhan) | 0092, 0092, 0092, 0092, 0051, 0069 |
| PATUH | `cs_api.legal_draft_save`, `legal_draft_approve`, `evidence_list`, `evidence_set_hold`, `evidence_export` | Dokumen hukum (empat mata), karantina bukti, legal hold | Staf (Kepatuhan) | 0062, 0062, 0095, 0095, 0095 |
| HUB | `cs_api.agent_my_profile`, `agent_security_status`, `agent_signed_out_everywhere` | Profil saya, status keamanan login, keluar semua perangkat | Staf | 0165, 0186, 0116 |
| HUB | `cs_api.admin_agents`, `admin_update_agent`, `admin_unlock_agent`, `admin_reset_agent_mfa`, `admin_set_community_permissions`, `admin_set_nasabah_permissions`, `admin_set_policy_four_eyes` | Akun staf, peran dan izin, buka kunci, reset 2FA, aturan empat mata | Staf (Super Admin) | 0035, 0038, 0186, 0186, 0057, 0047, 0092 |
| HUB | `cs_api.service_create_agent` | Membuat baris agen untuk akun GoTrue baru | Layanan (edge function `cs-admin`) | 0035 |
| HUB | `cs_api.admin_set_kill_switch`, `admin_set_feature_flag`, `admin_set_min_version`, `admin_set_feed_filter_enabled` | Fitur & versi, Tab Stream | Staf (Super Admin, Fitur & Banner) | 0121, 0121, 0121, 0180 |
| HUB | `cs_api.community_save_post`, `community_review_post`, `community_save_account`, `community_save_instrument`, `admin_analytics` | Postingan resmi, akun resmi, indeks, analitik | Staf | 0150, 0057, 0058, 0150, 0078 |
| INT | `public.integration_authenticate`, `integration_notify`, `integration_bot_post`, `set_olt_account_links` | API integrasi OLT dan tautan rekening dari klaim `accounts` | Layanan (integration, auth-bridge) | 0068, 0171, 0068, 0128 |
| INT | `cs_api.integration_key_create`, `integration_stats`, `app_integration_overview`, `ticket_customer_login` | API key, statistik, status integrasi aplikasi, LoginId nasabah tiket | Staf (Super Admin; `ticket_customer_login` untuk CS) | 0101, 0086, 0114, 0141 |
| INT | `cs_api.nasabah_access`, `nasabah_is_super_admin`, `nasabah_save_integration` | Izin Akun Nasabah dengan cek `aal`, simpan alamat csAdmin | Layanan (nasabah-gateway) | 0186, 0186, 0055 |
| OPS | `public.service_heartbeat`, `health_report`, `nodes_report`, `storage_cleanup_claim`, `storage_cleanup_report`, `backup_config`, `backup_record`, `alert_claim`, `media_attachment_policy`, `link_preview_claim` | Heartbeat, laporan kesehatan dan peta layanan, janitor, backup, alert, kebijakan lampiran, link preview | Layanan | 0064, 0113, 0168, 0095, 0060, 0112, 0065, 0064, 0131, 0080 |
| OPS | `cs_api.system_health`, `system_nodes`, `healer_overview`, `health_acknowledge`, `backup_set_target`, `backup_request`, `alert_set_telegram` | Kesehatan sistem, peta layanan, backup, alert | Staf (Super Admin) | 0064, 0168, 0113, 0064, 0112, 0065, 0064 |

Kolom Migrasi menyebut migrasi terakhir yang mendefinisikan fungsi itu. Beberapa RPC lama (mis. `public.send_message` 0008) tidak didefinisikan ulang karena aturannya ditegakkan trigger dan fungsi `private.*` yang diperbarui di migrasi lain.

#### 5.2.3 Realtime

Kanal realtime memakai Supabase Realtime (protokol Phoenix `vsn=1.0.0`) di `wss://<host>/realtime/v1/websocket?apikey=<ANON_KEY>&vsn=1.0.0`. Klien hanya mendengarkan; semua event dikirim database (`realtime.send`) setelah aksi lewat RPC. Setiap topik di-join dengan `config.private = true` dan `access_token` dari `/bridge/v1/exchange`; token baru dikirim lewat event `access_token` sebelum kedaluwarsa. Heartbeat ke topik `phoenix` tiap ±25 detik. Realtime tidak menyimpan event yang terlewat; klien mengisi celah lewat `get_message_ids` dan `get_messages_by_ids` (docs/api/asyncapi.yaml versi 2026.11.18). Hak join topik privat diatur RLS `realtime.messages` (0098, 0105, 0106).

| Topik | Privat | Event | Pengirim | Ringkasan payload | Pengguna |
|---|---|---|---|---|---|
| `room:{roomId}` | Ya | `message` | Database | Pesan lengkap (`id`, `room_id`, `sender_*`, `body`, `is_deleted`, `reply_to_*`, `attachments`, `client_id`, `edited_at`, `created_at`, `cursor`, `kind`, `payload`); `ref: true` = hanya penanda karena aturan blokir | Nasabah, staf CS |
| `room:{roomId}` | Ya | `message_edited` | Database | `room_id`, `message_id`, `preview`, `edited_at` | Nasabah |
| `room:{roomId}` | Ya | `message_hidden` | Database | `room_id`, `message_id`, `user_id` | Nasabah |
| `room:{roomId}` | Ya | `reaction` | Database | `message_id`, `user_id`, `emoji` (`null` = dihapus), ringkasan `reactions` | Nasabah |
| `room:{roomId}` | Ya | `receipt` | Database | `user_id`, `last_delivered_at`, `last_read_at` | Nasabah, staf CS |
| `room:{roomId}` | Ya | `typing` | Database | `user_id`, `username`, `display_name`, `typing` (room < 50 anggota dan chat CS) | Nasabah, staf CS |
| `room:{roomId}` | Ya | `typing_summary` | Database | `room_id`, `count` (1–99), `ttl_ms` (room 50–1.999 anggota) | Nasabah |
| `room:{roomId}` | Ya | `room_state` | Database | Bentuk sama dengan `get_stock_room_state` (slow mode, pesan tersemat, moderator) | Nasabah |
| `room:{roomId}` | Ya | `room_deleted` | Database | `room_id`, `reason`, `actor_id`, `actor_name` | Nasabah |
| `room:{roomId}` | Ya | presence | Klien | `presence.key` = id sendiri; hanya untuk status online di DM | Nasabah |
| `user:{userId}` | Ya | `room_activity` | Database | `id`, `room_id`, `room_type` (`direct`, `group`, `support`), `message_id`, `sender_id`, `created_at`, `preview` (≤ 120 karakter); room saham tidak mengirim event ini | Nasabah |
| `user:{userId}` | Ya | `room_removed` | Database | `room_id`, `reason` (`hidden`, `left`, `group_deleted`), `actor_*` | Nasabah |
| `cs:room:{roomId}` | Ya | `message` | Database | Sinyal ringan `id`, `room_id`, `ticket_id`, `client_id`; isi lengkap di `room:{roomId}` | Nasabah (chat CS), staf |
| `cs:queue` | Ya | `ticket`, `agent_status`, `alert` (perlu konfirmasi daftar lengkap) | Database | Perubahan antrean tiket dan status agen | Staf CS dan Super Admin (0028–0038) |
| `cs:agent:{agentId}` | Ya | `ticket`, `transfer`, `status`, `message` (perlu konfirmasi daftar lengkap) | Database | Tiket ditugaskan, transfer, status, pesan untuk agen tertentu | Staf (0032–0056) |
| `cs:compliance` | Ya | `case_flagged` | Database | `id`, `ticket_id`, `flag` (`complaint`, `fraud`) | Kepatuhan, Super Admin (0133) |

Topik staf (`cs:*` selain `cs:room`) tidak terdokumentasi di asyncapi.yaml; daftarnya diturunkan dari panggilan `realtime.send` di migrasi.

#### 5.2.4 auth-bridge (`/bridge/v1`)

| Endpoint | Metode | Isi | Sumber |
|---|---|---|---|
| `/bridge/v1/exchange` (internal `POST /exchange`) | POST | Header `apikey: <ANON_KEY>`. Body `{"token": "<token sosial OLT>"}` (maks 17 KB; token maks 16 KB). Jawaban 200: `access_token` (JWT HS256, `role` `authenticated`, `aud` `authenticated`, `iss` `olt-auth-bridge`, berlaku 900 detik), `token_type` `bearer`, `expires_in`, `expires_at`, `user` (`id`, `olt_user_id`, `username`, `display_name`, `avatar_url`, `is_verified`). Error: `400 invalid_request`, `401 invalid_token`, `403 user_banned`, `403 account_rejoin_cooldown` (dengan `retry_at` dan `Retry-After`), `429 rate_limited`, `502 exchange_failed`, `503 olt_unavailable` (mode websocket) | services/auth-bridge/README.md, docs/api/openapi.yaml |
| `/bridge/v1/health` (internal `GET /health`) | GET | `{"status": "ok", "olt_mode": "..."}` | services/auth-bridge/README.md |
| `GET /metrics`, `GET /livez`, `GET /readyz` | GET | Port ops 9100, tidak diteruskan Kong. `readyz`: `200 ready`, `200 degraded`, atau `503 not_ready` | services/auth-bridge/README.md |

Kontrak token sosial (mode `jwt`, produksi): algoritma `EdDSA` (Ed25519) atau `ES256` (P-256) dengan kunci publik dari JWKS OLT (`docker/secrets/olt_jwks`, dibaca saat start); klaim wajib `iss`, `aud`, `sub` (ID user OLT), `preferred_username`, `iat`, `exp` dengan `exp - iat ≤ OLT_JWT_MAX_TTL`; klaim opsional `name`, `email`, `accounts` (maks 200 item `^[A-Za-z0-9._-]{1,32}$`). `kid` berawalan `dev-` ditolak di produksi. auth-bridge tidak memanggil OLT. Rate limit per IP dan per user OLT memakai Valkey (fallback in-memory). ID profil = UUIDv5 tetap dari `olt_user_id` (services/auth-bridge/README.md, docs/olt-integration.md).

#### 5.2.5 Layanan media (`/media/v1`)

| Endpoint | Isi | Sumber |
|---|---|---|
| `POST /media/v1/object/{bucket}/{path}` | Header `Authorization: Bearer <JWT nasabah atau staf>`, `apikey`, opsional `x-upsert: true` (hanya `avatars`), `X-Request-Id`. Bucket: `avatars`, `attachments`, `cs-documents`, `cs-videos`. Path 1–6 segmen `[A-Za-z0-9._-]{1,128}`, maks 400 karakter. Jenis file dari isi (magic bytes), bukan `Content-Type`. Gambar disanitasi lossless (EXIF/GPS dibuang) dan diperiksa classifier NSFW; dokumen dan video CS dipindai ClamAV; video di-remux ffmpeg + thumbnail. Diteruskan ke Storage dengan JWT baru berklaim `media_verified: true` (maks 120 detik). Jawaban 200: `bucket`, `path` final, `mime`, `size`, `width`/`height` (gambar/video), `duration` dan `thumbnail` (video), `held: true` bila gambar ditahan. Kode error: 11.2.4 | services/media/README.md |
| `GET /storage/v1/object/authenticated/{bucket}/{path}` | Unduh file privat dengan JWT (RLS storage) | docs/api/openapi.yaml |
| Port ops 9100 | `/livez`, `/readyz`, `/metrics`, tidak dirutekan | docker/compose.yml |

Batas ukuran per bucket di media: `avatars` 2 MiB, `attachments` 5 MiB (room chat CS sampai 10 MiB sesuai kebijakan gambar), `cs-documents` 10 MiB, `cs-videos` 25 MiB dan maks 120 detik; dokumen dan video CS bisa diturunkan Super Admin (services/media/README.md, 0131, 0138).

#### 5.2.6 API integrasi OLT (`/integration/v1`)

| Item | Ketentuan | Sumber |
|---|---|---|
| Endpoint | `POST /integration/v1/notify/messages` (notifikasi transaksi per `cust_id`, per `olt_user_id`, atau siaran) dan `POST /integration/v1/bot/posts` (postingan bot akun resmi). Metode lain `405`, path lain `404` | docs/integration/README.md, services/integration/README.md |
| Header | `apikey: <ANON_KEY>`, `Authorization: Bearer <API key integrasi>` (awalan `oik_`, hanya ditampilkan sekali saat dibuat; yang disimpan hanya hash SHA-256), `Content-Type: application/json`, opsional `X-Request-Id` (`[A-Za-z0-9._-]{1,64}`) | docs/integration/README.md |
| Izin (scope) | `notify`, `notify_broadcast` (wajib disertai `notify`, untuk target `olt_user_ids`, `audience: all`, `audience: stock_watchers`), `bot_post` (terikat satu akun resmi) | docs/integration/README.md |
| Batch | Maks 500 pesan atau 50 postingan per request, body maks 2 MiB | docs/integration/README.md |
| Rate limit | `rate_limit_per_minute` per key, bawaan 3000 sejak 0101 (rentang 1–100000), dihitung per instance; > `AUTH_FAILURES_PER_MINUTE` (bawaan 30) key salah per IP → `429 too_many_auth_failures`; postingan bot `integration.bot_posts_per_hour` (bawaan 30) per key; siaran non-`important` maks `integration.broadcast_daily_cap` (bawaan 3) per nasabah per hari WIB | 0101, services/integration/README.md, docs/integration/README.md |
| IP | Maks 20 alamat IP/CIDR per key (`allowed_cidrs`); di luar daftar → `403 ip_not_allowed` | 0068, docs/integration/README.md |
| Idempotensi | `id` pesan diingat 7 hari per key (`integration.receipt_days`); `id` postingan bot unik selamanya; batch diproses dalam satu transaksi | docs/integration/README.md |
| Jawaban | `200` dengan `results` per item: `queued` (+`devices`, `inbox`), `accepted` (+`broadcast_id`, siaran asinkron tiap 15 detik), `no_recipient`, `duplicate`, `invalid` (+`error`); postingan bot `published`, `duplicate`, `rejected`, `invalid`, `rate_limited`. Error batch: 11.2.4 | docs/integration/README.md |
| Pengelolaan | Super Admin di Hub (**Pengaturan → API Notifikasi**), RPC `cs_api.integration_key_create/update/revoke`, statistik `integration_stats`, `integration_stats_daily`, `integration_broadcasts`; semua tercatat di Jejak Audit | docs/integration/README.md |

#### 5.2.7 Gateway Akun Nasabah ke csAdmin OLT

| Item | Ketentuan | Sumber |
|---|---|---|
| Endpoint ke Hub | `/api-nasabah/online/...` (rute dalam daftar izin), `GET/PUT/DELETE /api-nasabah/integration` dan `POST /api-nasabah/integration/test` (khusus Super Admin), `GET /healthz`, `GET /readyz` | services/nasabah-gateway/README.md |
| Autentikasi staf | Token sesi console (HS256, `jwt_secret`); izin dibaca lewat `cs_api.nasabah_access(p_user_id, p_aal)` dengan cache 30 detik. Bila peran akun wajib 2FA, izin hanya diberikan untuk sesi `aal2` (0186) | docs/nasabah/README.md, 0186 |
| Rute yang dibuka | Hanya rute staf `/online/*` dalam daftar izin (mis. `get-list-online-user`, `get-online-user`, `create-approval-login`, `approve-approval-login`, `update-status-online-user`, `change-password-and-pin-online-user`, `get-list-opening-rekening-online-user`, `send-email-opening-account-with-rekening`) plus `GET /online/duplicates` yang dihitung gateway. `/cs/*`, `/auto-update/*`, `/otp/*`, rute publik nasabah, dan `/integration/token` tidak dibuka (`404 route_not_found`) | docs/nasabah/README.md |
| Validasi query | `page` 1–999999, `size` 1–100, LoginId `[A-Za-z0-9._@-]` maks 50, email `[A-Za-z0-9._@+-]` maks 100; lainnya dibuang, nilai tak lolos `400 invalid_query` | docs/nasabah/README.md |
| Token ke csAdmin | Gateway membuat assertion JWT `EdDSA` (Ed25519, kunci privat `docker/secrets/csadmin_signing_key`) berumur 60 detik dengan `iss` = `sub` = client id, `aud` = `csAdminEL`, `jti` acak, lalu `POST /integration/token` `{"Assertion": "..."}`. csAdmin menerbitkan token HS256 berumur `duration_token_minutes` (1–60, bawaan 15); gateway memperbarui satu menit sebelum habis atau saat 401 | docs/nasabah/README.md |
| Izin | `online_user.view`, `online_user.manage`, `online_user.demo`, `online_user.approve`, `online_user.approve_own`, `online_user.status`, `opening_account.send`; khusus akun berperan CS | docs/nasabah/README.md |
| Audit | Kolom pelaku ditimpa kode CS console; aksi tulis dicatat (nama field tanpa nilai) dan tampil di Jejak Audit | docs/nasabah/README.md |
| Konfigurasi | Alamat dan client id csAdmin diisi Super Admin di **Pengaturan → Integrasi API Nasabah**, disimpan hanya bila tes koneksi berhasil (`cs_api.nasabah_save_integration`, 0055); `CSADMIN_TIMEOUT` bawaan 15 detik | docs/nasabah/README.md |

#### 5.2.8 Edge function `cs-admin`

Dipanggil Hub di domain CS: `POST /functions/v1/cs-admin/agents` (buat akun staf), `PATCH /functions/v1/cs-admin/agents/{id}` (ubah), `POST /functions/v1/cs-admin/agents/{id}/reset-password`. Wajib `Authorization: Bearer <JWT Super Admin>`; error `{code, message}`: `401 session_expired`, `400 invalid_body`, `404 not_found`, `405 method_not_allowed`, `500 internal` (docker/volumes/functions/cs-admin/index.ts).

#### 5.2.9 Firebase Cloud Messaging

| Item | Ketentuan | Sumber |
|---|---|---|
| Arah | `public.notifications` → trigger → `private.push_queue` (satu baris per perangkat) → notifier (`push_claim`) → FCM HTTP v1 → HP. Satu-satunya egress notifier: Google OAuth (`https://oauth2.googleapis.com/token`) dan FCM (`https://fcm.googleapis.com`) | docs/push/README.md, services/notifier/README.md |
| Kredensial | File JSON service account Firebase diunggah Super Admin di **Pengaturan → Push notification**, disimpan terenkripsi di Supabase Vault, dibaca notifier lewat `push_credentials(p_revision)` (khusus `service_role`) tiap `CREDENTIALS_RELOAD` (bawaan 5 detik); token OAuth2 dari assertion RS256 scope `firebase.messaging`; kunci baru divalidasi dengan pesan `validate_only` | docs/push/README.md, services/notifier/README.md |
| Payload data | Semua nilai string: `source=rendezvous_community`, `type`, `notification_id`, `push_id`, id dari payload notifikasi (`post_id`, `comment_id`, `room_id`, `room_type`, `ticket_id`, `campaign_id`, `url`), `actor_id`, `actor_username`. Push dari API integrasi memuat `data` OLT + `kind`, `source: "olt"`, `message_id`, `cust_id` (target rekening), `category`, `notification_id`, `broadcast_id` (siaran) | docs/push/README.md, docs/integration/README.md |
| Opsi | `collapse_key` (tag Android dan `apns-collapse-id`), `priority` `high`/`normal`, `ttl_seconds` (bawaan `push.ttl_hours` 24), badge iOS = jumlah belum dibaca, `ANDROID_CHANNEL_ID` opsional | docs/push/README.md |
| Keandalan | At-least-once, lease `FOR UPDATE SKIP LOCKED`, retry 30 detik digandakan sampai 30 menit, `push.max_attempts` 6, token `UNREGISTERED` menghapus perangkat, `SENDER_ID_MISMATCH` hanya menggagalkan push itu; maks `push.max_devices_per_user` 10 | docs/push/README.md |
| Platform | `CommunityPushPlatform` `android`, `ios`, `web`; iOS butuh APNs Authentication Key di Firebase Console | docs/push/README.md |

#### 5.2.10 Antarmuka keluar lain

| Tujuan | Layanan | Keterangan | Sumber |
|---|---|---|---|
| Telegram Bot API dan server SMTP | sentinel (alert) | Alert Kesehatan sistem dikirim ke Telegram dan email; kanal diatur Super Admin di **Pengaturan → Alert** (token bot Telegram dan password SMTP di Vault) | 0064, docs/system-health/README.md |
| Penyimpanan S3-compatible atau lokal | backup | Tujuan dan password enkripsi backup diatur di **Pengaturan → Backup**; jenis tujuan `s3` atau `local` | 0065, 0112, docs/backup |
| Situs web publik | link-preview | Mengambil metadata URL untuk kartu link preview (jaringan `egress`) | docker/compose.yml, services/link-preview/README.md |
| Server signature ClamAV | clamav (freshclam) | Unduh database signature harian | services/media/README.md |
| Let's Encrypt | Traefik | Sertifikat TLS lewat HTTP-01 | docker/compose.prod.yml |

### 5.3 Antarmuka komunikasi

| Aspek | Ketentuan | Sumber |
|---|---|---|
| Transport publik | HTTPS (HTTP/1.1, TLS) dan WebSocket aman (`wss`) di port 443. Port 80 hanya untuk redirect ke HTTPS dan tantangan HTTP-01 Let's Encrypt | docker/compose.prod.yml |
| TLS | Minimal TLS 1.2, `sniStrict` (bawaan true), cipher ECDHE AES-GCM/ChaCha20-Poly1305, kurva X25519/P-256/P-384, HSTS `max-age=31536000; includeSubDomains`; sertifikat otomatis Let's Encrypt (`certResolver: le`) | docker/volumes/traefik/prod.yml, common.yml |
| Firewall server | Hanya 22 (SSH dengan key, dari kantor), 80, dan 443 terbuka | docs/panduan/produksi.md |
| Admin | Entrypoint `admin` (Traefik `:9000`) terikat `127.0.0.1:8000` di server; Studio dan semua path hanya lewat SSH tunnel atau WireGuard. Studio dan meta mati secara bawaan (profil `admin`) | docker/compose.prod.yml |
| Pembatasan domain CS | Semua router di `CS_CONSOLE_DOMAIN` dibatasi `VPN_SOURCE_RANGES` (LAN kantor/VPN) | docker/volumes/traefik/cs.yml |
| Batas waktu tepi | Read timeout 60 detik, idle 180 detik, grace 20 detik; header maks 32 KiB; karakter path ter-encode berbahaya ditolak; access log tanpa header (bisa memuat token) | docker/compose.yml, compose.prod.yml |
| WebSocket realtime | Protokol Phoenix `vsn=1.0.0` di `/realtime/v1/websocket`; maks 1500 koneksi per IP | docs/api/asyncapi.yaml, common.yml |
| Jaringan Docker | `edge` (internal, subnet tetap `10.250.250.0/24` agar Kong hanya memercayai `X-Forwarded-For` dari Traefik): Traefik, Kong, cs-console, nasabah-gateway. `app` (internal): Kong, auth, rest, realtime, storage, imgproxy, functions, auth-bridge, notifier, janitor, classifier, clamav, media, backup, integration, link-preview, sentinel, nasabah-gateway. `data` (internal): db, pgbouncer, valkey, migrate, auth, rest, realtime, storage, meta, auth-bridge, backup, sentinel. `egress` (akses internet): Traefik (ACME), functions, notifier (FCM), clamav (freshclam), backup (S3), link-preview, sentinel (alert), nasabah-gateway (csAdmin). healer berjalan tanpa jaringan (`network_mode: none`) | docker/compose.yml |
| Port internal | Kong 8000; PostgREST 3000 dan admin server 3001 (`/live`, `/ready`, `/metrics`); GoTrue 9999; Realtime 4000; Storage 5000; imgproxy 5001; functions 9000; db 5432; pgbouncer 6432; valkey 6379; clamd 3310; port ops 9100 untuk auth-bridge, media, integration, classifier (`/livez`, `/readyz`, `/metrics`); 8080 untuk API auth-bridge/media/integration/nasabah-gateway/cs-console dan health notifier/janitor/backup/link-preview; Traefik ping dan metrik 8082. Tidak ada yang dipublikasikan ke internet | docker/compose.yml (PROBES sentinel) |
| Pengembangan | Profil dev memakai HTTP di `127.0.0.1:8000` (API) dan `127.0.0.1:8085` (Hub) | docker/compose.dev.yml |
| Hubungan dengan OLT | Tidak ada panggilan dari server sosial ke OLT untuk login; arah panggilan integrasi selalu OLT → server sosial. Pengecualian: nasabah-gateway memanggil csAdmin (HTTP, jaringan internal/VPN OLT) untuk menu Akun Nasabah | docs/integration/README.md, docs/nasabah/README.md |

## 6. Kebutuhan data

Semua data Rendezvous disimpan di satu database Postgres 17 (Supabase self-hosted) dan Supabase Storage di server yang sama. Data bisnis trading (order, transaksi, harga, portofolio, data nasabah OLT) tidak disimpan; pemiliknya adalah OLT (6.4). Struktur data hanya diubah lewat migrasi baru di `supabase/migrations`; migrasi yang sudah terpasang dicatat dengan checksum dan tidak boleh diubah (scripts/migrate.sh).

### 6.1 Entitas utama per skema

Skema yang dapat dipanggil lewat PostgREST hanya `public`, `graphql_public`, dan `cs_api` (`PGRST_DB_SCHEMAS`, docker/compose.yml). Skema `cs`, `private`, `admin_api`, `olt_internal`, dan `vault` tidak terbuka ke API REST. Jumlah tabel hidup hasil pemindaian migrasi (create/rename/drop): `public` 30, `cs` 45, `private` 105.

Aturan umum:

1. Setiap tabel `public` memakai RLS; penulisan penting dilakukan lewat RPC `security definer` yang memeriksa peran, batas, dan input lalu mencatat audit (docs/panduan/pengetahuan-sistem.md).
2. Hak kolom dibatasi: `public.profiles` hanya bisa dibaca kolom `id`, `username`, `display_name`, `avatar_url`, `bio`, `is_verified`, `follower_count`, `following_count`, `post_count`, `created_at`, `updated_at`, dan hanya `display_name`, `bio`, `avatar_url` yang bisa diubah langsung; `olt_user_id` sengaja tidak bisa dibaca pengguna lain (0002).
3. Tabel `cs` dan `private` hanya diakses lewat fungsi `cs_api`/`public` yang `security definer`; hak langsung dicabut dari `anon` dan `authenticated` (mis. 0150 `revoke all on private.market_instruments ...`).

#### 6.1.1 Skema `public` (data komunitas dan chat)

| Entitas | Isi | Aturan kunci / RLS | Migrasi |
|---|---|---|---|
| `profiles` | Profil sosial: `id` (UUIDv5 dari `olt_user_id`), `olt_user_id` (unik), `username` (unik), `display_name`, `bio`, `avatar_url`, `is_verified`, penghitung, `deleted_at` | Baca: semua pengguna login (kolom terbatas). Ubah: hanya pemilik. Dibuat/diperbarui hanya oleh auth-bridge lewat `upsert_olt_profile` (`service_role`) | 0002 (0048, 0175) |
| `follows`, `blocks`, `mutes`, `muted_keywords`, `muted_stocks` | Ikuti, blokir, bisukan akun, kata, dan saham | `follows` dibaca semua, ditulis pemilik bila tidak saling blokir; `blocks` hanya milik sendiri | 0002, 0015 |
| `stock_watchers` | Pantauan saham (watchlist sosial) per kode | Milik sendiri | 0002 |
| `posts` | Postingan: penulis, teks, lampiran, sentimen, status moderasi, `deleted_at` | Tampil bila tidak terhapus, penulis tidak diblokir, dan `moderation_status = 'visible'` atau milik sendiri | 0004 (0013) |
| `post_stocks`, `post_mentions`, `post_hashtags` | Relasi post ke `$KODE`, `@user`, `#hashtag` | Diisi trigger konten | 0004, 0073 |
| `post_polls`, `post_poll_options`, `post_poll_votes` | Polling 2–4 pilihan dan suara | Satu suara per pengguna, pembuat tidak ikut memilih | 0019 |
| `post_drafts` | Draf post per pengguna (maks 20) | Milik sendiri | 0090 |
| `comments` | Komentar bertingkat | Tunduk pada kontrol komentar pemilik post | 0005 (0169) |
| `reactions` | Suka pada post/komentar | Milik sendiri | 0006 |
| `bookmarks` | Simpan postingan | Milik sendiri | 0075 |
| `chat_rooms` | Room `direct`, `group`, `stock`, `support` (chat CS) dengan pengaturan grup | Hanya anggota; staf CS hanya room tiket yang boleh dibaca | 0008 (0146) |
| `chat_members` | Anggota room, peran owner/admin/member, horizon baca | Anggota; staf CS lewat `cs.can_read_room` | 0008 (0028) |
| `messages` | Pesan: pengirim, isi, lampiran, `kind` (`text`, `system`, `quick_reply`, `help_link`, `identity_request`, `csat`, `group_event`), `client_id`, `edited_at`, `deleted_at`, `session_id` (tiket CS) | Anggota room; staf CS hanya pesan tiket yang boleh dibaca dan berstatus `visible` | 0008 (0032, 0037, 0146) |
| `message_reactions` | Reaksi emoji pesan | Anggota room | 0075 |
| `notifications` | Kotak notifikasi per pengguna (`type`, `payload`, `read_at`) | Hanya milik sendiri (baca, ubah, hapus) | 0003 |
| `reports`, `appeals` | Laporan konten dan banding | Pelapor/pemohon melihat miliknya | 0009, 0071 |
| `legal_documents`, `user_consents` | Versi dokumen hukum dan persetujuan pengguna | Dokumen tampil bila `effective_at <= now()`; persetujuan milik sendiri | 0014 |
| `banned_words` | Kata terlarang (versi awal; pengelolaan lewat kebijakan konten) | Hanya lewat fungsi | 0002 (0051) |
| `feed_filters` | Tab filter Stream (empat tab tetap, saklar aktif) | Dikelola Hub | 0149 (0180) |
| `link_previews` | Hasil link preview per hash URL | Dibaca lewat `get_link_previews` | 0080 |

#### 6.1.2 Skema `cs` (layanan nasabah, Hub, kepatuhan)

| Entitas | Isi | Aturan kunci | Migrasi |
|---|---|---|---|
| `agents`, `teams`, `skills`, `agent_skills`, `agent_status` | Akun staf (peran, kode staf, batas tiket aktif, izin Komunitas, izin Akun Nasabah, izin Trade), tim, skill, status kerja dan heartbeat | Dibuat lewat edge function `cs-admin` + `service_create_agent`; izin Akun Nasabah hanya untuk peran CS (trigger `agents_nasabah_scope`) | 0027 (0035, 0047, 0057) |
| `tickets` (semula `support_sessions`) | Tiket chat CS: nasabah, topik, status, prioritas, tanda (`complaint`, `fraud`), pemegang, tenggat, rating | Hanya lewat `cs_api`; tiket tertutup tidak bisa dibalas | 0028, rename 0032 |
| `ticket_counters`, `ticket_transfers`, `session_events` | Nomor tiket harian, permintaan transfer, riwayat event tiket (dipartisi per `created_at`) | Lewat fungsi | 0032, 0028 |
| `support_topics` | Topik chat CS: ikon, urutan, pertanyaan awal, saran balasan, SOP, tanda | Dikelola Pusat Bantuan | 0027 (0127, 0134) |
| `quick_replies`, `ticket_labels`, `ticket_label_links`, `agent_notes` | Balasan cepat pribadi/bersama, label tiket (maks 50 aktif, 5 per tiket), catatan internal | Lewat fungsi | 0028, 0118 |
| `guest_sessions` | Sesi pengaduan tamu tanpa login (token, Login ID, masa berlaku) | Diakses hanya lewat RPC `guest_*` | 0140 |
| `cs_settings`, `cs_settings_history` | Pengaturan layanan CS beserta riwayat perubahan | Sebagian kunci terkunci (`setting_locked`) | 0027 |
| `holidays`, `service_incidents`, `vip_customers` | Hari libur, pengumuman gangguan, daftar nasabah prioritas | Lewat fungsi | 0027, 0135 |
| `cs_audit_log` | Jejak audit staf (dipartisi per `created_at`) | Tidak bisa dihapus dari Hub | 0028 |
| `faq_categories`, `faq_articles`, `faq_article_versions`, `faq_feedback`, `faq_reads`, `faq_search_misses`, `faq_flags` | Pusat Bantuan dua bahasa: kategori, artikel + versi, umpan balik, statistik baca, pencarian tanpa hasil, tanda dari agen | Kunci versi (`version_conflict`); lampiran maks 10 per artikel | 0129, 0136, 0188 |
| `compliance_reviews`, `policy_confirmations`, `compliance_notices`, `compliance_notice_reads`, `compliance_ticket_access` | Tinjauan kasus, konfirmasi kebijakan tenggat/retensi, pemberitahuan kasus, akses tiket biasa hanya-baca 12 jam | Konfirmasi kebijakan tidak bisa diubah/truncate | 0042, 0125, 0133 |
| `policy_versions`, `policy_changes` | Versi kebijakan konten, draf perubahan, persetujuan empat mata, rollback | Lewat `compliance_policy_*` | 0092 |
| `content_rules`, `allowed_domains`, `blocked_domains`, `promo_phrases`, `policy_allowlist` | Aksi kategori konten, domain tepercaya/diblokir, frasa promosi, pengecualian | Batas jumlah (mis. domain 5.000) | 0069 |
| `legal_drafts` | Draf dokumen hukum dengan persetujuan empat mata | Draf terkunci saat ditinjau | 0062 |
| `official_accounts`, `community_posts`, `community_campaigns` | Akun resmi, postingan/pengumuman resmi (empat mata, jadwal, sematan), kampanye notifikasi | Izin Komunitas per staf | 0057 |
| `manipulation_alerts` | Indikasi manipulasi saham | Ditinjau moderator | 0072 |

#### 6.1.3 Skema `cs_api` dan `admin_api`

Kedua skema tidak berisi tabel. `cs_api` berisi fungsi RPC untuk Hub dan RPC chat CS nasabah (315 fungsi, 11.3.2); `admin_api` berisi API moderasi lama dari 0013 (19 fungsi, 11.3.3) dan tidak termasuk `PGRST_DB_SCHEMAS`.

#### 6.1.4 Skema `private` (data internal)

| Kelompok | Entitas | Isi | Migrasi |
|---|---|---|---|
| Identitas dan sesi | `user_private`, `user_sessions`, `user_sanctions`, `account_signups`, `staff_login_guard` | Email opsional, waktu login terakhir, `olt_username`; batas pencabutan sesi (`revoked_before`); sanksi bertingkat; waktu daftar akun (untuk masa akun baru); penjaga kunci login staf | 0002, 0013, 0048, 0069, 0186 |
| Pengaturan dan batas | `settings`, `rate_limits`, `rate_limit_events`, `kill_switch`, `feature_flags`, `client_versions` | Pengaturan kunci–nilai (dikelola Hub), batas laju per aksi, kill switch, feature flag, versi minimum per platform | 0012, 0002, 0077 |
| Moderasi konten | `content_archive`, `content_edits`, `content_flags`, `moderation_events`, `policy_forms`, `policy_patterns`, `policy_pending`, `media_moderation`, `media_reviews`, `room_moderation`, `room_moderators`, `room_mod_actions` | Arsip konten terhapus (dengan `legal_hold`), riwayat edit, penanda kebijakan, ambang gambar, gambar ditahan, slow mode dan moderator room | 0002, 0069, 0071, 0075, 0079, 0092, 0093 |
| Bukti | `evidence`, `evidence_files`, `evidence_custody` | Karantina bukti, salinan file (SHA-256), rantai penguasaan | 0095 |
| Privasi dan preferensi | `dm_preferences`, `dm_requests`, `mention_preferences`, `comment_preferences`, `notification_prefs`, `notification_settings`, `notification_actors`, `notification_events` | Kebijakan DM, permintaan pesan, pengaturan mention dan komentar, preferensi notifikasi, statistik dibuka/diketuk | 0070, 0076, 0088, 0169, 0172 |
| Push | `push_devices`, `push_queue`, `push_credentials`, `push_instances`, `push_ref_stats` | Token perangkat (tidak terbaca aplikasi), antrean per perangkat, metadata kunci Firebase (isi di Vault), heartbeat notifier, statistik | 0058, 0059 |
| Banner | `app_banners`, `app_banner_events`, `app_notices` | Banner strip/popup, event tayang/klik/tutup, notifikasi info | 0089, 0119, 0182 |
| Integrasi | `account_links`, `integration_keys`, `integration_receipts`, `integration_posts`, `integration_daily`, `integration_broadcasts`, `integration_broadcast_caps` | Tautan `cust_id` ↔ profil, API key (hash SHA-256), idempotensi, postingan bot, statistik harian, siaran | 0068, 0086 |
| Chat | `message_receipts`, `room_preview_queue`, `followed_post_queue` | Waktu terkirim/dibaca per penerima, antrean pratinjau room saham, antrean postingan yang diikuti | 0087, 0102, 0122 |
| Penemuan | `hashtags`, `post_search`, `stock_codes`, `stock_mention_buckets`, `trending_state`, `trending_snapshot`, `market_instruments`, `market_instrument_aliases`, `watchlist_digest_runs` | Indeks pencarian, trending, daftar indeks (dikelola Hub), ringkasan watchlist | 0073, 0074, 0087, 0150 |
| Analitik | `analytics_events` | Event klien (dipartisi per bulan) | 0078 |
| Operasional | `service_instances`, `health_*` (`health_checks`, `health_probes`, `health_disks`, `health_meta`, `health_alerts`, `health_metric_sources`, `health_metric_samples`, `health_report_misses`), `alert_channels`, `alert_deliveries`, `healer_state`, `healer_events`, `system_nodes`, `backup_config`, `backup_requests`, `backup_runs`, `backup_state`, `storage_cleanup_queue`, `link_preview_queue`, `link_preview_image_scores` | Heartbeat layanan, kesehatan sistem, alert, restart otomatis, peta layanan, backup, antrean pembersihan file dan link preview | 0015, 0064, 0065, 0080, 0094, 0104, 0113, 0168 |
| Admin lama | `admin_users`, `admin_room_scopes`, `admin_audit_log`, `personal_data_access_log` | Admin moderasi lama (0013), audit, log akses data pribadi | 0013 |
| Tamu | `guest_pepper` | Pepper untuk hash pengaduan tamu | 0140 |
| Berbagi Trade (dijeda) | `trade_*` (17 tabel) | Data fitur Berbagi Trade; tetap terpasang tetapi tidak dipakai rilis ini | 0160–0164 |

#### 6.1.5 Skema `olt_internal` dan `vault`

| Skema | Entitas | Isi | Sumber |
|---|---|---|---|
| `olt_internal` | `schema_migrations` (`version`, `checksum`, `applied_at`) | Catatan migrasi terpasang; file yang berubah setelah terpasang ditolak. Dibuat skrip migrate, bukan migrasi | scripts/migrate.sh |
| `vault` | `vault.secrets` (dibaca lewat `vault.decrypted_secrets`) | Rahasia terenkripsi yang dikelola dari Hub: `push.firebase_service_account`, `alerts.telegram_bot_token`, `alerts.smtp_password`, `backup.s3_secret_access_key`, `backup.restic_password`, serta `trade_relay.aes_key`/`aes_iv` (dijeda). Kunci enkripsi Vault ada di volume `db-config`, bukan di dump database; pemulihan rahasia diatur 0067 | 0059, 0064, 0065, 0067, 0162, docs/push/README.md |

### 6.2 Bucket penyimpanan

Nilai di bawah adalah nilai terakhir di migrasi (`storage.buckets`). Unggahan nasabah wajib lewat layanan media (klaim `media_verified`, 0063), yang menerapkan batas tambahan per jenis (5.2.5).

| Bucket | Publik | Batas ukuran (storage) | Jenis MIME | Kegunaan dan aturan | Migrasi |
|---|---|---|---|---|---|
| `avatars` | Ya | 2 MiB | `image/jpeg`, `image/png`, `image/webp` | Foto profil dan foto grup; `x-upsert` diizinkan | 0011 |
| `attachments` | Tidak | 10 MiB | `image/jpeg`, `image/png`, `image/webp`, `image/gif` | Gambar post dan chat. Media membatasi 5 MiB kecuali room chat CS (sesuai kebijakan gambar, bawaan 10 MiB) | 0011, 0138 |
| `cs-documents` | Tidak | 10 MiB | PDF, DOCX, XLSX, PPTX, `text/plain`, `text/csv` | Dokumen chat CS; dipindai ClamAV; path `rooms/<room>/<uid>/<file>` | 0053, 0131 |
| `cs-videos` | Tidak | 25 MiB | `video/mp4`, `video/quicktime`, `video/webm`, `image/jpeg` (thumbnail) | Video chat CS maks 120 detik; dipindai ClamAV | 0131 |
| `link-previews` | Ya | 5 MiB | `image/jpeg`, `image/png`, `image/webp`, `image/gif` | Gambar link preview | 0080 |
| `evidence` | Tidak | 50 MiB | Semua jenis | Salinan bukti karantina (janitor), masa simpan 730 hari, legal hold | 0095 |
| `app-banners` | Ya | 2 MiB | `image/jpeg`, `image/png`, `image/webp` | Gambar popup banner (Hub mengecilkan sampai < 2 MB) | 0119 |
| `faq-images` | Ya | 2 MiB | `image/jpeg`, `image/png`, `image/webp` | Gambar di badan artikel bantuan | 0130 |
| `faq-files` | Ya | 25 MiB | `application/pdf`, `image/jpeg`, `image/png`, `image/webp`, `video/mp4`, `video/webm`, `video/quicktime` | Lampiran artikel bantuan: maks 10 per artikel, PDF 10 MB, gambar 5 MB, video 25 MB | 0188 |

Bucket `care-documents` (0022) sudah dihapus di 0026.

### 6.3 Retensi dan pembersihan

Sejak 0195 semua kunci `retention.*` di bawah dijaga trigger `settings_05_retention_guard` / `cs_settings_05_retention_guard`: nilai di luar rentang `private.retention_rules()` ditolak `400 invalid_retention`, dan perubahan tanpa permintaan yang disetujui ditolak `409 retention_locked`. Perubahan lewat `cs_api.retention_request_change` → `retention_decide_change` (staf lain, aal2); yang mempercepat penghapusan berlaku 7 hari setelah disetujui (`retention-apply-due` tiap jam). Riwayat di `private.retention_history` (append-only). Panduan: docs/panduan/retensi-data.md.

| Data | Aturan | Pengaturan (bawaan) | Pelaksana | Sumber |
|---|---|---|---|---|
| Post aktif | Dihapus N tahun setelah dibuat beserta komentar, reaksi, dan lampiran; dilewati bila ditahan, dilaporkan, dibanding, legal hold, atau post resmi | `retention.posts_years` (5; 0 = tidak pernah) | `private.retention_guard_run`, cron `retention-guard` 19:41 UTC (02.41 WIB) | 0195 |
| Komentar aktif | Dihapus N tahun setelah dibuat; komentar yang masih punya balasan menunggu | `retention.comments_years` (5) | `retention-guard` | 0195 |
| Chat DM & grup | Pesan dihapus N tahun setelah dikirim; pratinjau room dikosongkan bila semua pesan habis | `retention.direct_chat_years` (5) | `retention-guard` | 0195 |
| Chat room saham | Sama seperti DM | `retention.stock_chat_years` (5) | `retention-guard` | 0195 |
| Chat CS | Pesan room support dihapus bila tidak ada tiket aktif dan tiket terakhir ditutup lebih dari N tahun | `retention.chat_years` (10, 5–30, di `cs.cs_settings`) | `retention-guard` | 0027, 0195 |
| Batas per run | Maksimal N baris per jenis per run, sisanya run berikutnya; penjaga bisa dihentikan | `retention.max_rows_per_run` (20000), `retention.purge_enabled` (1) | `retention-guard` | 0195 |
| Notifikasi | Dihapus setelah N hari | `retention.notifications_days` (90) | `private.run_retention`, cron `olt-retention` 03:17 | 0015 |
| Pesan yang dihapus | Baris dengan `deleted_at` dihapus permanen setelah N hari | `retention.deleted_messages_days` (30) | `run_retention` | 0015 |
| Arsip konten (`content_archive`) | Salinan post/komentar/pesan yang dihapus atau dari akun yang dihapus, disimpan sampai `retain_until`; tidak dihapus selama `legal_hold` | `retention.archive_days` (1825) | `run_retention` | 0013, 0015 |
| Riwayat edit konten | Disimpan sampai `retain_until` (sama dengan masa arsip); dikecualikan bila `legal_hold` | `retention.archive_days` (1825) | cron `social-content-edits-retention` | 0075, 0081 |
| Audit admin lama | Dihapus setelah N hari | `retention.audit_log_days` (1825 sejak 0195; sebelumnya 365) | `run_retention` | 0015, 0195 |
| Log akses data pribadi | Dihapus setelah N hari | `retention.access_log_days` (730) | `run_retention` | 0015 |
| Event rate limit | Dihapus setelah N hari | `retention.rate_limit_events_days` (2) | `run_retention` | 0015 |
| Tanda terima pesan (`message_receipts`) | Dihapus setelah 30 hari; status tetap tampil dengan "Waktu tidak tercatat" | tetap 30 hari | cron `message-receipts-retention` 03:43 | 0122, doc/features.md |
| Event banner | Dihapus setelah N hari, kecuali tayang/tutup terakhir tiap pengguna selama banner aktif (agar frekuensi berlaku) | `banners.events_retention_days` (180) | cron `app-banner-maintenance` 03:47 | 0183 |
| Bukti karantina | Dihapus N hari sejak bukti terakhir direkam; legal hold menangguhkan; folder `evidence` masuk antrean janitor (`evidence_expired`) | `retention.evidence_days` (730) | cron `evidence-purge` 03:33 | 0095 |
| Gambar ditinjau (`media_reviews`) | Dihapus 90 hari setelah objek dihapus, 180 hari setelah disetujui; antrean tertunda > 1 hari dibersihkan | tetap | cron `media-reviews-purge` 03:53 | 0079 |
| Push | Antrean kedaluwarsa setelah `push.ttl_hours` (24); riwayat setelah `push.retention_days` (7); perangkat tidak aktif `push.device_stale_days` (270) | lihat kolom aturan | cron `push-maintenance` tiap menit | docs/push/README.md |
| Integrasi | `id` pesan 7 hari (`integration.receipt_days`), tautan rekening 30 hari tanpa pembaruan (`integration.account_link_days`), statistik harian 400 hari, siaran selesai `integration.broadcast_days` (90) | lihat kolom aturan | cron `integration-maintenance` tiap jam menit 23 | services/integration/README.md |
| Link preview | Dihapus setelah N hari | `link_preview.retention_days` (30) | cron `link-preview-purge` 03:37 | 0080, 0094 |
| Analitik | Partisi bulanan disimpan N bulan | `analytics.retention_months` (12) | cron `social-analytics` 02:25 | 0078 |
| Trending | Bucket sebutan saham disimpan N hari | `trending.bucket_retention_days` (35) | cron trending | 0074 |
| Kesehatan sistem | Riwayat kirim alert dan alert yang pulih dihapus setelah 90 hari | tetap | cron `health-purge` 03:41 | 0064 |
| Antrean pembersihan storage | Baris selesai dihapus setelah 90 hari | tetap | cron `storage-cleanup-purge` 03:27 | 0060 |
| Riwayat chat CS | Masa simpan riwayat chat CS dikonfirmasi Kepatuhan di **Tenggat & retensi** (rentang 5–30 tahun) | `retention.chat_years` (10) | Perlu konfirmasi: tidak ditemukan job yang menghapus berdasarkan pengaturan ini | 0027, 0042 |

Pembersihan file Storage (`storage_cleanup_queue` + janitor):

1. Penghapusan akun dan retensi bukti memasukkan folder (`bucket` + `prefix`) ke `private.storage_cleanup_queue`; penghapusan akun mencakup avatar, lampiran post/chat (`attachments`), dan dokumen chat CS (`cs-documents`) milik akun itu (services/janitor/README.md, 0060).
2. Layanan janitor mengambil antrean lewat `storage_cleanup_claim` dengan lease, menghapus objek lewat API Storage per potongan, dan melaporkan lewat `storage_cleanup_report`. Folder gagal dicoba lagi dengan jeda yang makin panjang sampai 6 jam. Hanya objek yang sudah ada sebelum folder masuk antrean yang dihapus, sehingga akun yang dibuat ulang tetap menyimpan file barunya.
3. Janitor juga menyalin file konten yang dilaporkan/dihapus ke bucket `evidence` dengan verifikasi SHA-256 (`evidence_copy_claim`/`evidence_copy_report`); file sumber tidak dihapus sebelum salinan tercatat `copied` (0095).

Partisi: `cs.session_events` dan `cs.cs_audit_log` dipartisi per `created_at` dengan partisi dibuat 3 periode ke depan oleh cron `cs-partitions` 02:10 (`cs.ensure_partitions(3)`, 0028); `private.analytics_events` dipartisi per bulan (0078).

### 6.4 Penanganan data pribadi

| Aspek | Ketentuan | Sumber |
|---|---|---|
| Data pribadi yang disimpan | `olt_user_id` (dari `sub` token sosial), `username` dan `display_name`, `bio` dan `avatar_url` opsional, email opsional dari klaim `email` (di `private.user_private`, tidak dimasukkan ke JWT), `olt_username` asli untuk mencocokkan tiket dengan LoginId csAdmin, daftar `cust_id` dari klaim `accounts` (huruf besar, di `private.account_links`), token perangkat push, isi konten dan pesan yang dibuat pengguna, tiket CS | services/auth-bridge/README.md, 0002, 0048, 0068 |
| Data yang tidak disimpan | Password OLT (login tetap langsung ke OLT), order, transaksi, harga, daftar dan nama saham, portofolio, data nasabah OLT; kode `$KODE` hanya label. Tabel `public.stocks` dan fungsi data nasabah CS lama dihapus di 0037. Menu Akun Nasabah tidak menyimpan data csAdmin di database (gateway meneruskan saja) | rendezvous_community doc/integration.md, 0037, docs/nasabah/README.md |
| Kerahasiaan `olt_user_id` | Kolom tidak diberi hak `select` untuk pengguna; JWT sosial hanya memuat `sub` (UUID), `role`, `aud`, `iss`, `iat`/`exp`, `app_metadata.provider` tanpa email, username, atau `olt_user_id` | 0002, services/auth-bridge/README.md |
| Ekspor data (`export_my_data`) | JSON berisi profil, email, posts, komentar, pesan, reaksi, polling, bookmark, draf, follow, blokir/bisukan, watchlist, persetujuan, laporan, banding, sanksi, preferensi (DM, mention, komentar, notifikasi), perangkat push, event analitik, tiket CS, rekening tertaut, dan data Berbagi Trade; maks 3 kali per 86.400 detik (`rate_limits` aksi `data_export`); setiap ekspor dicatat di log akses data pribadi | 0172, 0012, doc/features.md |
| Hapus akun (`delete_my_account`) | File akun masuk antrean janitor; post, komentar, dan pesan disalin ke `content_archive` lalu dikosongkan dan ditandai terhapus; reaksi, follow, blokir yang dibuat sendiri (blokir oleh orang lain tetap, 0174), bisukan, watchlist, keanggotaan room, notifikasi, persetujuan, dan `user_private` dihapus; profil dianonimkan (`deleted_<hash>`); sesi dicabut; tindakan dicatat. Riwayat CS tetap; akun trading tidak tersentuh. Login berikutnya membuat profil baru setelah jeda `account.rejoin_cooldown_hours` (bawaan 72 jam) | 0174, 0175, doc/features.md |
| Penyamaran di chat CS | `cs.mask_sensitive` menyamarkan OTP/PIN/CVV/kode verifikasi, password, nomor kartu, NIK, dan nomor rekening pada teks tiket; nasabah mendapat peringatan saat mengetiknya (`check_sensitive`); quick reply tidak boleh meminta OTP/PIN (`400 secret_request_blocked`) | 0027, 0029, 0035 |
| Log tanpa rahasia | Token sosial, JWT, API key integrasi, token push lengkap, path dan isi file tidak ditulis ke log; Traefik membuang header dari access log; auth-bridge dan integration hanya mencatat jumlah rekening, bukan `cust_id`; gateway Akun Nasabah mencatat nama field tanpa nilai; library menyamarkan data sensitif | services/auth-bridge/README.md, services/media/README.md, services/integration/README.md, docs/push/README.md, docs/nasabah/README.md, docker/compose.yml |
| Akses staf ke data | Staf CS hanya membaca tiket yang boleh dibaca; Kepatuhan membuka tiket biasa hanya-baca selama 12 jam dan tercatat (0125); akses kasus, transkrip, dan bukti tercatat di Jejak Audit | 0032, 0125, docs/panduan/hub-untuk-staf.md |
| Penyimpanan rahasia | Kredensial operasional di Vault (6.1.5), hanya dikirim ke layanan yang membutuhkannya dan tidak pernah ditampilkan ulang di Hub | docs/push/README.md, 0064, 0065 |

## 7. Kebutuhan non-fungsional

Bagian ini menetapkan atribut mutu sistem. Angka kinerja dan ketahanan berasal dari uji 3–4 November 2026 di stack dev dengan batas CPU/memori produksi (`docs/testing/report-2026-11-03.md`, selanjutnya "laporan uji"), kecuali disebut lain. Laporan uji menyatakan angka itu berasal dari komputer uji; kapasitas server produksi wajib diukur ulang di server itu dengan `make load-test P=step` sebelum dibuka ke nasabah (`docs/panduan/spesifikasi-server.md` bagian 5). Kebutuhan keamanan dirinci di bagian 8, dan parameter yang dirujuk di sini didaftar di bagian 9.

Konvensi kolom "Sumber dan cara verifikasi": sumber dokumen atau kode dalam kurung, lalu alat uji yang membuktikannya. "VU" = pengguna virtual k6 (satu nasabah yang membuka aplikasi tepat setelah bel pembukaan, skenario `tests/load/market-open.js`).

### 7.1 Kinerja

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-PERF-01 | Sistem harus menjawab RPC aplikasi nasabah dengan cepat saat bel pembukaan. | p95 ≤ 25 ms pada 400 VU (±55 req/dtk), error HTTP 0%. Terukur p95: `send_message` 22 ms, `create_post` 15 ms, `get_feed` 6 ms, `get_feed_stock` 4 ms, `get_trending` 5 ms, `join_stock_room` 4 ms, `get_notifications` 3 ms | (laporan uji 4.2, 4.4) `make load-test P=step` |
| NFR-PERF-02 | Penukaran token sosial di auth-bridge harus cepat. | p95 exchange ≤ 16 ms dari 50 sampai 400 VU | (laporan uji 4.2, 7.3) `make load-test P=step`, metrik `olt_auth_bridge_http_request_duration_seconds` |
| NFR-PERF-03 | Sistem harus menahan lonjakan pembukaan pasar tanpa error. | Spike 0 → 300 VU dalam 10 dtk: error HTTP 0%, 100% pesan sampai lewat Realtime, Realtime p95 30 ms, `send_message` p95 28 ms | (laporan uji 10.2) `make load-test P=spike` |
| NFR-PERF-04 | Pesan chat room saham harus sampai ke penerima lewat Realtime. | 100% sampai lewat Realtime sampai 400 penerima aktif per room dengan typing aktif, Realtime p95 ≤ 32 ms, 0 log rate limit Realtime | (laporan uji 11.1, mode cap `0106`) `make load-test P=step TYPING=1` |
| NFR-PERF-05 | Pesan yang dibuang batas tenant Realtime harus tetap sampai lewat isi celah (gap-fill). | Eventual 100% pada 500 penerima per room (tenant 10.000/dtk, 24% event dibuang) dan setelah `kill -9` Realtime pada 400 VU | (laporan uji 10.4, 10.5; `0103`) `make load-test`, `make chaos-test E=realtime` |
| NFR-PERF-06 | Room saham ramai 600 penerima harus bersih pada batas tenant bawaan. | Tenant 20.000 event/dtk: 100% lewat Realtime, error 0%, `PGRST003` 0, `send_message` p95 97 ms, Realtime p95 124 ms, CPU db 70% | (laporan uji 11.3) `make load-test P=step LOAD_STEPS="600"` |
| NFR-PERF-07 | Isi celah setelah sambung ulang massal tidak boleh membebani API. | 400 VU sambung ulang tersebar ±15 dtk; `get_message_ids` p95 7,9 ms, `get_messages_by_ids` p95 20 ms, CPU `rest` puncak ≤ 22% | (laporan uji 10.4, T19) `make load-test` + `kill -9` Realtime |
| NFR-PERF-08 | Pratinjau room di daftar chat harus segar tanpa memakai anggaran Realtime. | `get_room_previews` p95 3,3 ms dengan 200 penonton daftar memoll tiap 15 dtk; pratinjau tertinggal ≤ 0,7 dtk; 0 lock wait sampai 800 penerima | (laporan uji 10.2, 11.2; `0102`, `0107`) `make load-test LIST_VUS=200` |
| NFR-PERF-09 | Typing dan presence di room besar tidak boleh menghabiskan anggaran event. | Room non-CS ≥ 50 anggota hanya menerima `typing_summary` maks 1 per 3 dtk; presence room saham ditolak. Room 500 penerima: typing ±25.000 → ±167 event/dtk | (`docs/panduan/produksi.md` Batas Realtime; `0106`) tes `086_room_typing_presence_cap_test.sql`, `make load-test TYPING=1` |
| NFR-PERF-10 | Pemeriksaan kebijakan konten tidak boleh memperlambat tulis konten secara berarti. | ±2,6 ms per insert untuk pemeriksaan kata + keamanan konten (2.000 kata terlarang, postingan 1.000 karakter); total insert ±3,6 ms | (`docs/content-safety.md`) perlu konfirmasi alat ukur yang dipakai |
| NFR-PERF-11 | API integrasi OLT harus melayani notifikasi transaksi dalam batch. | 5 req/dtk × 100 pesan (500 pesan/dtk): p50 42 ms, p95 55 ms, p99 444 ms. Satu pesan: p95 17 ms. Siaran `stock_watchers` 400 pemantau selesai ±9 dtk (cron 15 dtk) | (laporan uji 4.6) `make load-integration` |
| NFR-PERF-12 | Klaim tiket CS harus benar di bawah rebutan. | 50 CS mengklaim 1 tiket: tepat 1 berhasil, 49 ditolak. 200 tiket × 30 CS acak: tidak ada tiket ganda, tidak ada CS > 5 tiket aktif, respons sama dengan pemilik di DB; langsung ke DB dan lewat 3 replika PostgREST | (`docs/cs-chat/README.md`) `make cs-race`, E2E `claim-race.spec.ts` |
| NFR-PERF-13 | Bundle awal Hub harus kecil. | JavaScript awal ≤ 300 KB gzip (terukur 286,2 KB, 4 Nov) | (`rendezvous_hub/scripts/bundle-size.mjs`, laporan uji 12.9) `npm run size:check` di `npm run ci` |
| NFR-PERF-14 | Daftar tiket dan percakapan Hub harus tetap mulus pada data besar. | 1.000 tiket + 5.000 pesan digulir: ≥ 60 fps dan p95 frame ≤ 16,7 ms | (`rendezvous_hub/e2e/perf.spec.ts`) `make e2e-cs-console` |
| NFR-PERF-15 | Pool PostgREST yang habis harus gagal cepat, bukan menumpuk. | Request tanpa koneksi pool dalam 2 dtk dijawab `504 PGRST003` | (`PGRST_DB_POOL_ACQUISITION_TIMEOUT=2`, `docs/panduan/produksi.md`) alert `rest:pool`, `make load-test` |

### 7.2 Kapasitas dan skalabilitas

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-KAP-01 | Layanan tanpa state yang paling sibuk harus berjalan lebih dari satu replika di profil dev dan single. | `rest`, `auth-bridge`, `media`, `classifier`, `imgproxy`, `integration` masing-masing 2 replika (`*_REPLICAS`), setiap replika mendapat batas CPU/memori penuh. Tetap 1: Realtime, storage (backend `file`), janitor, sentinel, backup, healer, migrate, notifier, link-preview, db, pgbouncer, valkey | (`docs/panduan/skalabilitas.md`, `docker/compose.yml`) `make ps` |
| NFR-KAP-02 | Ukuran pool PostgREST harus muat di PgBouncer. | `replika × (PGRST_DB_POOL + 1) ≤ PGBOUNCER_DEFAULT_POOL_SIZE`; bawaan 2 × (10 + 1) = 22 ≤ 24. Total koneksi server < batas role `authenticator` 60 dan `max_connections` 100; PgBouncer maks 80 koneksi server, 500 klien | (`docs/panduan/skalabilitas.md`) alert `pgbouncer:queue`; `make cs-race` memakai `PGRST_DB_POOL=3` untuk replika uji |
| NFR-KAP-03 | Realtime harus dibatasi per tenant agar satu sumber beban tidak menjatuhkan semuanya. | `REALTIME_MAX_CONCURRENT_USERS` 10.000, `REALTIME_MAX_JOINS_PER_SECOND` 500, `REALTIME_MAX_CHANNELS_PER_CLIENT` 100, `REALTIME_MAX_EVENTS_PER_SECOND` 20.000 | (`docker/compose.yml`, `docs/panduan/produksi.md` Batas & rate limit) alert `realtime:events` (peringatan ≥ 70%, kritis ≥ 90%) |
| NFR-KAP-04 | Kapasitas fan-out room saham harus diketahui dan dipantau. | Fan-out ≈ penerima × pesan/dtk ≈ N²/20 pada room ramai: 10.000/dtk habis di ±450 penerima aktif, 20.000/dtk cukup untuk ±630 (butuh `realtime` 2 vCPU). Di atas batas, event dibuang dan klien mengisi celah; batas desain isi celah 5 halaman / 500 id (T21, terbuka) | (`docs/panduan/produksi.md` Batas Realtime, laporan uji 10.8) `make load-test` |
| NFR-KAP-05 | Edge harus melayani ±1.000 nasabah di balik satu IP (CGNAT/Wi-Fi kantor). | `EDGE_RATE_AVERAGE`/`EDGE_RATE_BURST` 600/1.200 req/dtk per IP, `EDGE_WS_PER_IP` 1.500, exchange auth-bridge 1.500/menit per IP. Terverifikasi 800 VU dari 1 IP lewat Traefik: 0 × 429, semua WebSocket terbuka | (laporan uji 12.1) `make load-test LOAD_VIA=traefik`; `make up` profil single/cluster menolak `.env` dengan `EDGE_WS_PER_IP` atau `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` < 1.000 (`check-config`) |
| NFR-KAP-06 | Memori Traefik harus cukup untuk WebSocket satu IP besar. | Batas 768M (±0,26 MiB per WebSocket; 800 WebSocket ±287 MiB) | (laporan uji 12.1, `docker/compose.yml` traefik) `make test-security` (`static-config` memeriksa ≥ 512M) |
| NFR-KAP-07 | Runtime PostgREST harus sesuai kuota CPU. | `GHCRTS=-N1` (`PGRST_GHCRTS`) sama dengan batas CPU `rest` 1 vCPU; tanpa itu `rest` runtuh pada ±90 req/dtk (T20) | (`docker/compose.yml`, laporan uji 10.3, 11.3) `make load-test` 500/600 penerima: 0% error |
| NFR-KAP-08 | Server produksi harus berukuran cukup. | Minimum (UAT/pilot) 8 vCPU / 16 GB / 200 GB NVMe; produksi awal disarankan 16 vCPU / 32 GB / 500 GB NVMe; tumbuh besar: server DB terpisah. Batas semua container ±25 vCPU / 15 GB; pemakaian sepi ±4 GB RAM | (`docs/panduan/spesifikasi-server.md`) `nproc`, `free -h`, `df -h`, Peta layanan. Lihat catatan perbedaan di 10.3 |
| NFR-KAP-09 | Ukuran request harus dibatasi di edge. | Body API 256 KB (`EDGE_BODY_MAX_API`), unggah 26 MiB (`EDGE_BODY_MAX_UPLOAD`), integrasi 2 MiB (`EDGE_BODY_MAX_INTEGRATION`); melebihi → 413 | (`docker/volumes/traefik/common.yml`) `make test-security` (`prod-routing`: body > 256 KB → 413) |
| NFR-KAP-10 | Tabel bervolume tinggi harus dipartisi. | `cs.session_events` dan `cs.cs_audit_log` dipartisi bulanan, dibuat 3 bulan ke depan oleh job `cs-partitions` (02:10 setiap hari); partisi `_default` harus kosong. Event analitik dipartisi bulanan dan disimpan 12 bulan (`analytics.retention_months`) | (`0028`, `0078`; `docs/panduan/produksi.md` bagian 8) `cron.job_run_details`, tes `058_analytics_test.sql` |
| NFR-KAP-11 | Disk harus direncanakan untuk log dan backup. | Log container ±1–2 GB (10 MB × 5 file per container); staging backup ±1× ukuran DB + WAL beberapa jam; repositori backup lokal beberapa kali ukuran DB + file, sebaiknya di disk terpisah | (`docs/panduan/spesifikasi-server.md` bagian 3) alert `disk:*`, `backup:disk`, `backup:repository_disk` |
| NFR-KAP-12 | Jalur pertumbuhan ke banyak node harus tersedia tanpa mengubah kode. | Profil `cluster` (Swarm) memakai image, nama service, dan env yang sama; storage S3 (SeaweedFS). Status: kerangka, belum siap produksi (Tahap 7) | (`docs/panduan/skalabilitas.md`) perlu konfirmasi jadwal uji cluster |

### 7.3 Ketersediaan dan pemulihan

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-AVAIL-01 | Kehilangan data database saat pemulihan harus kecil. | RPO ≤ interval kirim WAL, bawaan 5 menit (`offsite_minutes` 1–60) | (`docs/backup/README.md`, `0065`) kartu "Kiriman WAL terakhir" di Hub; alert `backup:offsite` |
| NFR-AVAIL-02 | Pemulihan database harus selesai dalam waktu wajar. | RTO ≤ 1 jam untuk database sampai puluhan GB; durasi uji restore mingguan menjadi perkiraan nyata | (`docs/backup/README.md`) `make restore-pitr AT=<waktu> CONFIRM=yes`, durasi uji restore di Hub |
| NFR-AVAIL-03 | Backup harus berkelanjutan dan terenkripsi. | WAL dialirkan terus (`pg_receivewal`, slot `olt_backup`), backup penuh + file storage setiap hari 02:00 WIB (diverifikasi `pg_verifybackup`), restic AES-256; retensi 7 harian, 4 mingguan, 6 bulanan; jendela PITR (WAL) 7 hari; `restic prune` + `restic check` (sampel 2%) mingguan | (`docs/backup/README.md`, `docs/panduan/backup.md`, `0065`, `0112`) `make backup-snapshots`, tes `046_backups_test.sql`, `092_backup_local_destination_test.sql` |
| NFR-AVAIL-04 | Backup harus terbukti bisa dipulihkan. | Uji restore otomatis setiap Minggu 04:00 WIB (Postgres sementara diputar sampai WAL terakhir, jumlah baris tabel utama diperiksa); alert `backup:restore_test` bila gagal atau tidak ada uji berhasil selama 8 hari | (`docs/backup/README.md`) Hub Pengaturan → Sistem → Backup, tombol **Uji restore sekarang** |
| NFR-AVAIL-05 | Kegagalan backup harus terdeteksi. | `backup:base` kritis bila backup penuh terakhir > 26 jam; `backup:offsite` kritis bila WAL belum terkirim > 30 menit (atau 3× interval); `backup:wal`, `backup:slot`, `backup:repository` kritis; `backup:disk` dan `backup:repository_disk` saat sisa < 10% (kritis < 5% untuk repositori lokal) | (`docs/backup/README.md` Alert) Hub Kesehatan sistem |
| NFR-AVAIL-06 | Backup tidak boleh memenuhi disk database. | WAL yang ditahan slot dibatasi `max_slot_wal_keep_size` 512 MB; bila terlampaui slot dilepas (alert kritis) dan backup penuh baru dibuat otomatis | (`docs/backup/README.md`) alert `backup:slot` |
| NFR-AVAIL-07 | API harus cepat pulih setelah Postgres restart. | `docker restart db`: jendela gagal REST ±1,2 dtk; DB mati 5 dtk: REST pulih ≤ 2,2 dtk setelah DB menerima koneksi; IP `db` berubah: PgBouncer pindah ≤ 0,5 dtk setelah DB siap (`PGBOUNCER_DB_WATCH_SECONDS` 2, `PGBOUNCER_SERVER_LOGIN_RETRY` 0,25) | (laporan uji 12.2, T6) `make chaos-test E=db`; `migrate` tidak berjalan ulang |
| NFR-AVAIL-08 | Crash proses layanan harus pulih tanpa tindakan manual dan tanpa kehilangan pesan. | Layanan Go, PostgREST, PgBouncer, Realtime pulih lewat restart policy dalam 5–8 dtk; semua `send_message` yang dijawab 200 tersimpan; 9 eksperimen chaos pulih sendiri | (laporan uji 1, 5, 10.5) `make chaos-test` |
| NFR-AVAIL-09 | Login nasabah harus tetap jalan saat Valkey mati (fail open). | auth-bridge tetap menukar token dengan limiter lokal per instance (batas efektif × jumlah replika), `/readyz` = `degraded`; restart Valkey mengosongkan jendela rate limit | (`services/auth-bridge/README.md` Ketahanan, laporan uji T8) `make chaos-test E=valkey` |
| NFR-AVAIL-10 | Komponen keamanan konten harus fail closed. | Classifier mati: unggah gambar ditolak `503 classifier_unavailable`, alert `probe:classifier` terbuka ±12 dtk. ClamAV mati: unggah dokumen/video CS ditolak `503 scanner_unavailable`, chat teks dan gambar tetap jalan. Link-preview: pratinjau tanpa gambar | (`docs/panduan/produksi.md`, `services/media/README.md`, `services/link-preview/README.md`) `make chaos-test E=classifier`, tes `112_media_scanner_health_test.sql` |
| NFR-AVAIL-11 | Container yang macet (unhealthy) harus di-restart otomatis dengan pengaman. | Healer me-restart container berlabel `olt.autoheal=true` yang unhealthy ≥ 60 dtk dan berjalan ≥ 120 dtk, maks 3 kali per layanan per jam (lalu alert kritis `healer:gave_up:<layanan>`), maks 1 restart per 30 dtk untuk seluruh stack; ditahan bila `db` tidak sehat atau ≥ 50% layanan unhealthy (`healer:systemic`) | (`docs/panduan/produksi.md` bagian 7, `0113`) tes `093_healer_test.sql`, `make test-healer` |
| NFR-AVAIL-12 | Gangguan harus memunculkan alert tepat waktu dan pulih otomatis. | Alert dibuka setelah masalah bertahan `health.alert_after_seconds` 120 dtk; kunci kapasitas (`rest:pool`, `realtime:events`, `pgbouncer:queue`, `db:lock_waits`, `metrics:*`) 25 dtk; pulih setelah bersih 60 dtk. `realtime:events` terbuka ≤ 64 dtk setelah pelanggaran; laporan sentinel yang hilang dibawa ke laporan berikutnya | (`0064`, `0104`, `0108`; laporan uji 12.3) tes `045_system_health_test.sql`, `084_health_metrics_test.sql`, `088_health_alert_latency_test.sql` |
| NFR-AVAIL-13 | Kegagalan seluruh server harus terdeteksi dari luar. | Pemantau uptime di server lain memeriksa `https://<PROXY_DOMAIN>/bridge/v1/health` | (`docs/panduan/produksi.md` bagian 7, checklist go-live D) inspeksi go-live |
| NFR-AVAIL-14 | Koneksi API ke database yang menggantung harus terdeteksi. | Keepalive + `tcp_user_timeout` libpq: `/ready` 503 ±8,7 dtk setelah putus, container `unhealthy`; REST pulih ±2 dtk setelah tersambung | (`docker/volumes/rest/pg_service.conf`, laporan uji 10.5, T9) `make chaos-test E=partition` |
| NFR-AVAIL-15 | Fitur sosial harus bisa dimatikan tanpa menjatuhkan API. | Kill switch: tulis konten dan chat non-CS ditolak `403 social_disabled`; chat CS tetap jalan; tidak memicu flush pool PostgREST (tidak ada `api_error(503, …)` di aplikasi) | (`0109`, laporan uji T24) tes `089_kill_switch_status_test.sql`, `057_client_config_test.sql` |
| NFR-AVAIL-16 | Rahasia Vault harus bisa dipulihkan setelah pindah server. | `pgsodium_root.key` tidak ikut backup dan disimpan di luar server; tanpa itu Hub menampilkan alert `backup:secret`/`alerts:secret` dan Super Admin mengisi ulang kunci Firebase, kredensial backup, dan kanal alert | (`0067`, `docs/backup/README.md` Pemulihan) tes `047_vault_secret_recovery_test.sql` |

### 7.4 Keamanan

Ringkasan; rincian di bagian 8.

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-SEC-01 | Login nasabah harus diverifikasi lokal tanpa memanggil OLT. | Token sosial EdDSA/ES256 diverifikasi dengan JWKS OLT; sesi sosial HS256 15 menit; `kid` `dev-` ditolak di produksi | (8.1) `make smoke-dummy`, `make test-bridge` |
| NFR-SEC-02 | Login staf harus memakai password kuat dan 2FA untuk peran sensitif. | Password ≥ 12 karakter; TOTP (`aal2`) wajib untuk Super Admin; kunci akun setelah 5 password salah selama 15 menit (bawaan) | (8.2, `0186`) tes `164_staff_login_security_test.sql`, E2E `auth.spec.ts` |
| NFR-SEC-03 | Setiap tabel harus dilindungi RLS dan akses data harus lewat fungsi yang memeriksa peran. | RLS aktif di semua tabel; anon tanpa akses; 0 kebocoran dari 1.077 probe otorisasi | (8.3) tes `001_schema_test.sql`, `014_roles_privileges_test.sql`, `make test-security` (`authz-probe`) |
| NFR-SEC-04 | Jaringan harus tersegmentasi dan Hub hanya dari LAN/VPN kantor. | Network `edge`/`app`/`data` internal; hanya layanan tertentu di `egress`; domain CS dengan `ipAllowList` `VPN_SOURCE_RANGES` (IP lain 403) | (8.4) `make test-security` (`static-config`, `prod-routing`) |
| NFR-SEC-05 | Container harus dikeraskan. | Read-only, non-root (kecuali entrypoint Postgres), `cap_drop: ALL`, `no-new-privileges`, batas CPU/memori/pids | (8.5) `make test-security` (`static-config`), inspeksi `docker/compose.yml` |
| NFR-SEC-06 | Rahasia tidak boleh berada di `.env`, image, atau log. | Docker secrets untuk rahasia infrastruktur; kredensial operasional di Vault | (8.6) `make secrets-scan`, gitleaks di CI |
| NFR-SEC-07 | Unggahan nasabah harus diperiksa isinya sebelum disimpan. | Deteksi magic bytes, buang EXIF/GPS/XMP, tolak PDF terenkripsi/berisi JavaScript, NSFW dan antivirus fail closed; Storage menolak unggahan yang tidak lewat media | (8.7, `0063`) tes `044_media_uploads_test.sql`, `make test-media` |
| NFR-SEC-08 | JWT staf yang bocor tidak boleh berguna dari internet. | JWT akun CS di domain publik ditolak `403 cs_staff_public_edge` (REST), "Unauthorized" (Realtime), dan ditolak Storage/media | (8.10, `0100`, `0105`) tes `080_cs_staff_public_edge_test.sql`, `085_cs_staff_public_edge_realtime_storage_test.sql` |
| NFR-SEC-09 | Transport harus terenkripsi kuat. | TLS ≥ 1.2, hanya ECDHE + AEAD, kurva X25519/P-256/P-384, HSTS 1 tahun + includeSubdomains, HTTP → HTTPS 308 | (`docker/volumes/traefik/prod.yml`, `common.yml`; laporan uji 3.2) `make test-security` (`prod-routing`) |
| NFR-SEC-10 | Dependensi dan image milik sendiri harus bebas kerentanan tinggi. | Image `olt-social/*` yang dipakai: 0 CRITICAL / 0 HIGH; govulncheck 0; `npm audit --omit=dev` 0 | (laporan uji 10.7) `make scan-deps`, Trivy di CI ketiga repo |

### 7.5 Privasi

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-PRIV-01 | JWT sesi nasabah harus memuat klaim minimal. | Hanya `sub` (UUID), `role`, `aud`, `iss: olt-auth-bridge`, `iat`/`exp`, `app_metadata.provider: olt`; tanpa email, username, atau `olt_user_id` | (`services/auth-bridge/README.md` API) `make test-bridge` |
| NFR-PRIV-02 | Identitas OLT nasabah tidak boleh terbaca pengguna lain. | Kolom `public.profiles.olt_user_id` tanpa hak `SELECT` untuk `authenticated`; `get_profile` tidak memuat `olt_user_id`/email; email di `private.user_private` | (`docs/panduan/produksi.md` bagian 8) tes `001_schema_test.sql`, `make test-security` (`authz-probe`) |
| NFR-PRIV-03 | Metadata lokasi dan perangkat di foto harus dibuang. | EXIF/GPS, XMP, IPTC, komentar, thumbnail, dan data setelah EOI dibuang tanpa re-encode untuk JPEG, PNG, WebP, GIF; Orientation dipertahankan | (`services/media/README.md`) `make test-media` |
| NFR-PRIV-04 | Nasabah harus bisa mengekspor data dan menghapus akun. | Ekspor data dibatasi 3 per 24 jam (`data_export`); hapus akun menghapus file milik akun lewat `private.storage_cleanup_queue` (janitor, coba ulang dengan jeda sampai 6 jam); login yang sama baru bisa bergabung lagi setelah `account.rejoin_cooldown_hours` 72 jam | (`0012`, `0060`, `0175`) tes `013_privacy_test.sql`, `042_storage_cleanup_test.sql`, `152_account_rejoin_cooldown_test.sql` |
| NFR-PRIV-05 | Data pribadi tidak boleh masuk log. | Token, header, dan password tidak pernah ditulis ke log; log auth-bridge hanya memuat jumlah rekening (`accounts`, `accounts_ignored`), tidak pernah cust id; token tamu tidak ditulis ke log library | (`docs/panduan/produksi.md` bagian 7, `services/auth-bridge/README.md`, `rendezvous_community/doc/features.md`) inspeksi log, `dart run tool/check_logging.dart` |
| NFR-PRIV-06 | Data harus dihapus setelah masa simpan. | Notifikasi 90 hari, pesan terhapus dibersihkan permanen 30 hari, event rate limit 2 hari, log akses data pribadi 730 hari, audit log admin 365 hari, bukti karantina 730 hari (kecuali legal hold), arsip regulator 1.825 hari (sementara, wajib ditetapkan tim legal), riwayat chat CS 10 tahun (usulan, wajib dikonfirmasi Kepatuhan), event analitik 12 bulan, push 7 hari | (`private.settings` `retention.*`, `cs.cs_settings` `retention.chat_years`; bagian 9) tes `013_privacy_test.sql`, `075_evidence_quarantine_test.sql` |
| NFR-PRIV-07 | Kata pencarian bantuan tanpa hasil harus disamarkan. | Angka panjang dan email disamarkan sebelum disimpan; data > 90 hari dihapus otomatis | (`docs/panduan/hub-untuk-staf.md` 3.4) tes `116_help_reports_agent_faq_reminders_test.sql` (perlu konfirmasi cakupan tes) |
| NFR-PRIV-08 | Akses staf ke konten privat harus dibatasi dan tercatat. | Kepatuhan membuka tiket biasa hanya-baca dengan akses 12 jam yang tercatat; buka/periksa/ekspor bukti tercatat; email nasabah hanya untuk peran tertentu dan setiap aksesnya dicatat | (`0125`, `0095`) tes `105_compliance_ticket_access_test.sql`, `075_evidence_quarantine_test.sql` |
| NFR-PRIV-09 | Lokasi backup harus sesuai kebijakan lokasi data. | Bucket S3 di penyedia di Indonesia; repositori terenkripsi di sisi server | (`docs/backup/README.md`) perlu konfirmasi kebijakan lokasi data resmi |
| NFR-PRIV-10 | Penghapusan data harus memperhitungkan salinan backup. | Bukti yang lewat masa simpan masih ada di backup lama sampai terpangkas (retensi bulanan 6 bulan); disampaikan ke tim legal saat menjawab permintaan penghapusan | (`docs/panduan/produksi.md` bagian 3) prosedur legal |

### 7.6 Audit

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-AUD-01 | Jejak audit staf harus append-only. | `cs.cs_audit_log` menolak `UPDATE`, `DELETE`, dan `TRUNCATE` (trigger `cs.reject_change`); dipartisi bulanan berdasarkan `created_at` | (`0028`) tes `020_cs_security_test.sql` |
| NFR-AUD-02 | Audit admin dan riwayat pengaturan harus tidak bisa diubah. | `private.admin_audit_log` menolak update/delete (`0013`); `cs.cs_settings_history` append-only dengan versi (`0027`) | tes `012_moderation_admin_test.sql`, `023_cs_supervisor_admin_test.sql` |
| NFR-AUD-03 | Setiap perubahan pengaturan dan kredensial di Hub harus tercatat tanpa isi rahasia. | Aksi antara lain `setting.update`, `backup.target_set`, `backup.schedule_set`, `alerts.telegram_set`, `alerts.email_set`, `push.credentials_set`, `push.credentials_removed`, `integration.key_create`, `kill_switch.set`, `client.min_version_set`, `banner.link_schemes`, `attachments.policy`, `security.mfa_reset` | (`0035`, `0059`, `0064`, `0065`, `0068`, `0077`, `0124`, `0131`, `0186`) Hub Kepatuhan → Jejak Audit; tes `041_push_credentials_test.sql`, `046_backups_test.sql`, `164_staff_login_security_test.sql` |
| NFR-AUD-04 | Aksi tulis menu Akun Nasabah harus tercatat. | nasabah-gateway menulis aksi tulis ke `cs_audit_log` dengan aksi `nasabah.<rute>` dan menimpa kolom pelaku dengan kode CS | (`services/nasabah-gateway/README.md`) tes `032_cs_nasabah_access_test.sql`, `make test-nasabah-gateway` |
| NFR-AUD-05 | Kebijakan konten harus berversi dan bisa diaudit. | Setiap versi menyimpan snapshot + diff, sumber (`baseline`, `direct`, `change`, `rollback`, `system`), alasan, dan pembuat; perubahan lewat draf dan persetujuan empat mata (`compliance.policy_four_eyes`, bawaan aktif) | (`0092`) tes `072_policy_versions_test.sql` |
| NFR-AUD-06 | Bukti moderasi harus utuh dan aksesnya tercatat. | Konten yang dilaporkan/dihapus disimpan dengan sidik SHA-256, append-only (`409 evidence_immutable`), disimpan 730 hari kecuali legal hold | (`0095`) tes `075_evidence_quarantine_test.sql` |
| NFR-AUD-07 | Peristiwa keamanan login staf harus tercatat. | `security.login_locked`, `security.login_unlocked`, `security.mfa_reset`, `security.mfa_recovered` (termasuk `make cs-mfa-reset`) | (`0186`) tes `164_staff_login_security_test.sql` |
| NFR-AUD-08 | Masa simpan audit log harus jelas. | `retention.audit_log_days` 365 untuk audit log admin; masa simpan `cs.cs_audit_log` mengikuti kebijakan retensi Kepatuhan | perlu konfirmasi: mekanisme pemangkasan `private.admin_audit_log` dan `cs.cs_audit_log` yang append-only belum ditemukan |

### 7.7 Keterpeliharaan

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-MAINT-01 | Migrasi yang sudah dijalankan tidak boleh diubah. | Runner menyimpan SHA-256 tiap file di `olt_internal.schema_migrations` dan menolak file yang berubah; perubahan skema selalu file baru bernomor berikutnya | (`scripts/migrate.sh`, `docs/panduan/produksi.md` bagian 4) `make migrate` |
| NFR-MAINT-02 | File yang dijalankan di container Linux harus berakhiran baris LF. | `*.sql`, `*.sh`, `*.yml`, `Makefile`, `Dockerfile`, `.env.example` `eol=lf`; `*.ps1` CRLF | (`.gitattributes`) checksum migrasi konsisten lintas OS |
| NFR-MAINT-03 | Logika database harus diuji otomatis. | 165 file pgTAP (`supabase/tests/001`–`166`, tanpa `079`), ±4.300 asersi (jumlah `plan(...)` 4.299) | (`supabase/tests`) `make test-db`; CI `backend.yml` job `database` |
| NFR-MAINT-04 | Hub harus lolos pemeriksaan otomatis sebelum rilis. | `npm run ci`: lint (0 warning), lint token, format, typecheck, unit test (±890 tes di 146 file, hitungan statis), build, ukuran bundle, lisensi; CI juga Trivy image + fs dan gitleaks | (`rendezvous_hub/package.json`, `.github/workflows/ci.yml`) `make test-cs-console` |
| NFR-MAINT-05 | Library harus lolos pemeriksaan otomatis sebelum rilis. | CI: `check_comments`, `check_logging`, `dart format --line-length 120`, `flutter analyze` (paket + example), `flutter test` (±1.450 tes di 170 file, hitungan statis), `license_audit` | (`rendezvous_community/.github/workflows/ci.yml`) `make test-flutter`, `make license-audit` |
| NFR-MAINT-06 | Layanan Go harus lolos pemeriksaan otomatis. | Per layanan (13): `gofmt`, `go vet`, `go test -race`, `check-go-comments`, build image, Trivy CRITICAL/HIGH; pgTAP + `smoke-dummy` terhadap stack dev; gitleaks riwayat git | (`.github/workflows/backend.yml`) `make test`, `make check-go-comments`, `make secrets-scan` |
| NFR-MAINT-07 | Kode baru tidak boleh berisi komentar kecuali yang penting. | Go dan Dart diperiksa otomatis (`scripts/check-go-comments`, `tool/check_comments.dart`); komentar penting berbahasa Inggris; migrasi lama tidak diubah | CI ketiga repo |
| NFR-MAINT-08 | Kode harus tersusun per fitur. | Hub: satu folder per fitur di `src/features/*`; library: per fitur dengan Bloc | inspeksi struktur repo |
| NFR-MAINT-09 | Versi image harus terkunci. | Image pihak ketiga memakai tag + digest, tidak pernah `latest`; image sendiri `olt-social/<layanan>:<versi>` | (`docker/compose.yml`, `docs/panduan/produksi.md` bagian 4) inspeksi compose, `make scan-deps` |
| NFR-MAINT-10 | Perubahan operasional harus terdokumentasi per rilis. | Catatan rilis di `docs/panduan/catatan-rilis.md`; panduan operator di `docs/panduan` | inspeksi dokumen saat rilis |

### 7.8 Portabilitas

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-PORT-01 | Pindah profil deploy tidak boleh mengubah kode aplikasi. | Profil `dev` (`compose.dev.yml`), `single` (`compose.prod.yml`), `cluster` (`stack.cluster.yml`) memakai image, nama service, dan nama env yang sama | (`docs/panduan/skalabilitas.md`) `make up PROFILE=dev\|single\|cluster` |
| NFR-PORT-02 | Produksi harus berjalan di Linux. | Linux, disarankan Ubuntu LTS (checklist go-live: Ubuntu 24.04), Docker Engine + compose plugin; Windows (Docker Desktop) untuk development, dengan `make.ps1` setara Makefile | (`docs/panduan/spesifikasi-server.md` bagian 4, `docs/panduan/instalasi-server.md`) `server-install.sh` |
| NFR-PORT-03 | Database harus self-hosted. | Postgres 17 (`supabase/postgres:17.11.0.008`) di container; database cloud terkelola tidak didukung | (`docker/compose.yml`, keputusan arsitektur) inspeksi compose |
| NFR-PORT-04 | Penyimpanan file harus bisa dipindah ke S3 tanpa ubah kode. | `STORAGE_BACKEND=file` (single) atau `s3` + `GLOBAL_S3_*` (SeaweedFS, cluster) | (`docs/panduan/skalabilitas.md`) perlu konfirmasi uji S3 di cluster |
| NFR-PORT-05 | Sistem tidak boleh membutuhkan perangkat khusus. | Tanpa GPU (classifier NSFW berjalan di CPU) | (`docs/panduan/spesifikasi-server.md` bagian 4) — |
| NFR-PORT-06 | Akses internet keluar harus minimal dan bisa diganti mirror. | Keluar hanya untuk Let's Encrypt, Firebase (FCM), signature ClamAV, S3 backup, alert Telegram/SMTP, pratinjau link, dan csAdmin di LAN; ClamAV bisa memakai `PrivateMirror` | (`docs/panduan/spesifikasi-server.md`, `docs/panduan/produksi.md` bagian 1 dan 2) inspeksi network `egress` |

### 7.9 Kegunaan dan aksesibilitas

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-USAB-01 | Hub harus memenuhi kontras dan aksesibilitas WCAG 2.1 AA. | Pemeriksaan axe dengan tag `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa` tanpa pelanggaran di halaman login, ruang kerja tiket, dashboard, laporan, pengaturan, dan Kepatuhan, untuk tema terang dan gelap | (`rendezvous_hub/e2e/a11y.spec.ts`, `e2e/support/quality.ts`) `make e2e-cs-console` |
| NFR-USAB-02 | Hub harus menyediakan tema terang dan gelap. | Dua tema; pilihan disimpan per browser (`cs-console.theme`) | (`rendezvous_hub/e2e/a11y.spec.ts`, `visual.spec.ts`) E2E visual |
| NFR-USAB-03 | Tata letak Hub harus muat di resolusi desktop umum. | Tanpa scroll horizontal atau teks terpotong pada 1366×768, 1920×1080, dan 2560×1440 untuk login, ruang kerja, dashboard, laporan, pengaturan, dan Fitur & versi | (`rendezvous_hub/e2e/layout.spec.ts`) `make e2e-cs-console`; perlu konfirmasi apakah lebar ponsel menjadi target Hub |
| NFR-USAB-04 | Pengaturan berdampak besar harus dilindungi dari salah klik. | Form terkunci (**Ubah** → **Simpan** → konfirmasi berisi dampak); **Batal**/**Esc** mengembalikan nilai | (`docs/panduan/hub-untuk-staf.md` 3.4) E2E `super-admin.spec.ts` |
| NFR-USAB-05 | Staf harus bisa bekerja cepat dengan keyboard. | Pintasan keyboard dan command palette | (`docs/panduan/hub-untuk-staf.md` 2.11, fitur `command`) uji manual |
| NFR-USAB-06 | Sesi staf yang ditinggal harus berakhir otomatis. | Keluar otomatis setelah idle `ui.idle_logout_minutes` 30 menit; cache, draf, dan data tampilan dibersihkan saat keluar | (`cs.cs_settings`, `rendezvous_hub/README.md`) perlu konfirmasi tes otomatis |
| NFR-USAB-07 | Library harus bisa disesuaikan dengan tampilan aplikasi OLT. | Builder/slot dan `CommunityStyle` untuk mengganti tampilan tanpa fork; label semantik pada elemen seperti lampiran (`semanticLabel`) | (`rendezvous_community/doc/builders.md`, `customization.md`) `flutter test`; perlu konfirmasi target aksesibilitas formal untuk aplikasi |

### 7.10 Internasionalisasi

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-I18N-01 | Hub harus tersedia dalam Bahasa Indonesia dan Inggris. | Kamus `src/i18n/id.ts` dan `en.ts`; tanggal diformat sesuai bahasa | (`rendezvous_hub/src/i18n`) `src/i18n/index.test.ts` di `npm run ci` |
| NFR-I18N-02 | Library harus tersedia dalam Bahasa Indonesia dan Inggris. | ARB `community_id.arb` dan `community_en.arb` | (`rendezvous_community/lib/src/shared/presentation/l10n/arb`) `flutter test` |
| NFR-I18N-03 | Konten bantuan dan topik CS harus dua bahasa. | Artikel FAQ (pertanyaan, jawaban), kategori, topik, pertanyaan awal, teks halaman pilih topik, status gangguan, dan survei disimpan ID/EN | (`0127`, `0129`, `0135`) tes `107_topic_presentation_test.sql`, `109_help_center_test.sql`, `115_service_incidents_survey_test.sql` |
| NFR-I18N-04 | Pesan otomatis sistem harus disimpan dalam dua bahasa. | Setiap `messages.*` berbentuk `{"id": …, "en": …}`; pesan sistem tampil mengikuti bahasa aplikasi/Hub (pesan sebelum 6 Nov 2026 tetap bahasa tiketnya) | (`0123`, `cs.cs_settings`) tes `103_system_message_translations_test.sql` |
| NFR-I18N-05 | Waktu operasional harus memakai WIB. | Jam layanan, jam ramai (`rooms.busy_windows` 08:55–09:30 dan 15:50–16:15), ringkasan pantauan 17:05, backup 02:00, uji restore Minggu 04:00 dalam WIB; data disimpan `timestamptz` | (`0072`, `0147`, `0065`) tes `071_console_pagination_wib_test.sql`, `126_watchlist_digest_time_test.sql` |
| NFR-I18N-06 | Klien harus mengenali error dari kode, bukan dari teks. | Error aplikasi `private.api_error(status, code, detail)`; teks `detail` Bahasa Indonesia, klien memetakan `code` | (konvensi API; library memetakan `social_disabled` dari kode, `0109`) tes per modul |

### 7.11 Logging

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-LOG-01 | Layanan Go harus menulis log terstruktur. | JSON (`slog.NewJSONHandler`) ke stdout di semua layanan; auth-bridge memuat `request_id`, `user_id`, `status`, `duration_ms`; log akses Traefik JSON | (`docs/panduan/produksi.md` bagian 7, kode `services/*/cmd`) `make logs s=<layanan>` |
| NFR-LOG-02 | Log tidak boleh memuat rahasia. | Header, token, dan password tidak pernah ditulis; log akses Traefik membuang header; token tidak masuk metrik atau cache (cache memakai SHA-256 token) | (`docs/panduan/produksi.md` bagian 7, `services/auth-bridge/README.md`) `make test-security` (`static-config`) |
| NFR-LOG-03 | Log container harus dirotasi. | `json-file` 10 MB × 5 file per container | (`docker/compose.yml` `x-base.logging`) inspeksi compose |
| NFR-LOG-04 | Log, error internal, dan keluaran skrip harus berbahasa Inggris. | Teks UI dan dokumen produk tetap Bahasa Indonesia | (aturan proyek) review kode |
| NFR-LOG-05 | Library tidak boleh mencetak log sendiri di build rilis. | Logger terpusat `package:logging`; tanpa `logHandler` log hanya `debugPrint` di mode debug; level bawaan `INFO` (rilis) / `FINE` (debug); error disamarkan | (`rendezvous_community/doc/logging.md`) `dart run tool/check_logging.dart` di CI |
| NFR-LOG-06 | Error berulang tidak boleh membanjiri log. | Error Valkey di auth-bridge dicatat maks sekali per menit; gagal heartbeat dicatat sekali saat mulai gagal dan sekali saat pulih | (`services/auth-bridge/README.md`) `make test-bridge` |
| NFR-LOG-07 | Metrik internal tidak boleh terekspos ke luar. | Port ops (`9100` auth-bridge, admin PostgREST `3001`, `/metrics` Realtime, konsol PgBouncer) hanya di network Docker | (`docs/panduan/produksi.md` bagian 7) `make test-security` (`static-config`) |

### 7.12 Kompatibilitas

| ID | Kebutuhan | Target/ukuran | Sumber dan cara verifikasi |
|---|---|---|---|
| NFR-COMP-01 | Aplikasi OLT harus memakai library minimum yang didukung server. | Server dengan migrasi `0098` butuh `rendezvous_community` ≥ 1.5.0; klien 1.4.x tetap login tetapi tidak menerima pesan realtime | (`rendezvous_community/doc/integration.md`, `docs/panduan/produksi.md` bagian 8) checklist rilis klien |
| NFR-COMP-02 | Library baru harus tetap bekerja di server lama. | Fitur yang butuh migrasi baru disembunyikan atau kembali ke perilaku lama bila RPC/kolomnya belum ada (contoh: urutan komentar butuh `0142`, kontrol komentar `0169`/`0170`, format lampiran CS `0131`, pengaduan tamu `0140`, lampiran artikel `0188`); parameter baru hanya dikirim bila berisi | (`rendezvous_community/doc/features.md`, `customization.md`) tes library mode mock |
| NFR-COMP-03 | Fitur yang butuh dua sisi baru tampil setelah keduanya selaras. | Contoh: lampiran artikel bantuan tampil bila server `0188` dan library ≥ 1.49.0 | (`rendezvous_community/doc/customization.md`) tes `166_faq_attachments_test.sql` + tes library |
| NFR-COMP-04 | Server harus bisa memaksa update aplikasi lama. | Versi minimum per platform (`android`, `ios`, `web`, `windows`, `macos`, `linux`); `get_client_config` menjawab `update_required: true`; yang dibandingkan `appVersion` aplikasi OLT, bukan versi library | (`0077`, `0085`) tes `057_client_config_test.sql`, `064_client_gaps_test.sql` |
| NFR-COMP-05 | Toolchain library harus jelas. | `pubspec.yaml`: Flutter ≥ 3.47.0, Dart `^3.12.1`; versi saat ini 1.49.2, aplikasi mem-pin tag rilis | (`rendezvous_community/pubspec.yaml`) perlu konfirmasi: `doc/integration.md` menulis Flutter ≥ 3.44 dan CI memakai Flutter 3.44.1 |
| NFR-COMP-06 | Toolchain dan browser Hub harus jelas. | Node ≥ 24.12.0 (`engines`), CI Node 24.22.2; build target `es2022`; E2E memakai Chromium/Chrome desktop | (`rendezvous_hub/package.json`, `vite.config.ts`, `playwright.config.ts`) perlu konfirmasi daftar browser resmi selain Chrome/Chromium |
| NFR-COMP-07 | Perubahan status HTTP tidak boleh memutus klien. | Klien membaca `code`; contoh kill switch berubah 503 → 403 (`0109`) tanpa rilis library | (`0109`) tes `089_kill_switch_status_test.sql` |
| NFR-COMP-08 | Layanan versi lama harus tetap diterima saat database diperbarui. | Tanda tangan RPC yang dipakai layanan tidak diubah (contoh: `health_report` tetap menerima sentinel 0.2.0 setelah `0108`) | (laporan uji 12.3) tes `088_health_alert_latency_test.sql` |

Jumlah kebutuhan non-fungsional: PERF 15, KAP 12, AVAIL 16, SEC 10, PRIV 10, AUD 8, MAINT 10, PORT 6, USAB 7, I18N 6, LOG 7, COMP 8 (total 115).

## 8. Kebutuhan keamanan rinci

Bagian ini merinci NFR-SEC (7.4). Setiap butir menyebut sumbernya dan cara verifikasinya. Alat uji utama: `make test-security` (`tests/security/authz-probe.sh`, `realtime-authz.js`, `static-config.sh`, `prod-routing.sh`), `make scan-deps`, `make secrets-scan`, dan pgTAP `make test-db`. Verifikasi akhir 4 Nov: `authz-probe` 1.077 ok, `static-config` 155 ok, `prod-routing` 70 ok, 0 temuan (laporan uji 12.9).

### 8.1 Autentikasi nasabah

Nasabah tidak pernah login ke server sosial dengan password. Aplikasi OLT login ke OLT, OLT menerbitkan token sosial (JWT) bertanda tangan, lalu aplikasi menukarnya di `POST /bridge/v1/exchange` (header `apikey: <ANON_KEY>`). auth-bridge memverifikasi token secara lokal dan tidak memiliki akses jaringan keluar (`docs/olt-integration.md`, `services/auth-bridge/README.md`).

| Aturan | Nilai | Sumber |
|---|---|---|
| Algoritma token sosial | Hanya `EdDSA` (Ed25519) dan `ES256` (P-256); algoritma header harus cocok dengan jenis kunci `kid`; `none`, `HS*`, `RS*` ditolak | `services/auth-bridge/README.md` Mode `jwt` |
| Kunci publik | JWKS di Docker secret `olt_jwks`, dibaca sekali saat start; kunci tidak bisa diganti dari Hub | `docs/olt-integration.md` bagian 2, 5 |
| `kid` | Wajib bila JWKS berisi lebih dari satu kunci; `kid` berawalan `dev-` ditolak saat `APP_ENV=production` sehingga auth-bridge tidak mau start dengan JWKS dev | `docs/olt-integration.md` bagian 3 |
| Klaim wajib | `iss` = `OLT_JWT_ISSUER` (bawaan `olt`), `aud` memuat `OLT_JWT_AUDIENCE` (bawaan `olt-social`), `sub` (string, ID user OLT, tidak pernah berubah), `preferred_username`, `iat`, `exp`; `nbf` dihormati bila ada | `services/auth-bridge/README.md` |
| Umur token | `exp - iat` ≤ `OLT_JWT_MAX_TTL` 900 dtk; toleransi jam `OLT_JWT_LEEWAY` 30 dtk | `services/auth-bridge/README.md` Konfigurasi |
| Ukuran | Token maks 16 KB (`olt.MaxTokenBytes`), body exchange maks 17 KB; token lebih panjang ditolak `invalid_request` | `docs/olt-integration.md` bagian 3 |
| Tanda tangan | base64url wajib kanonik; token yang tulisannya diubah walau maknanya sama ditolak | `docs/olt-integration.md` bagian 3 |
| ID sosial | `UUIDv5(namespace tetap, olt_user_id)`; namespace tidak boleh diubah | `services/auth-bridge/README.md` |
| Sesi sosial | JWT HS256 `role: authenticated`, `iss: olt-auth-bridge`, berlaku 15 menit (`AUTH_BRIDGE_JWT_TTL` 900); diperpanjang aplikasi lewat `tokenProvider` dengan token sosial baru | `services/auth-bridge/README.md`, `docker/.env.example` |
| Pencabutan | OLT berhenti menerbitkan token; akses sosial berakhir paling lambat ±15 menit. User di-ban ditolak `403 user_banned` di exchange dan di setiap request (`private.check_request`); sesi yang dicabut ditolak `401 session_revoked` | `docs/olt-integration.md`, `0177` (`private.check_request`) |
| Akun yang baru dihapus | Exchange ditolak `403 account_rejoin_cooldown` dengan `retry_at` dan `Retry-After` selama `account.rejoin_cooldown_hours` (72 jam) | `0175`, auth-bridge 0.7.0 |
| Rate limit per IP | `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` 1.500/menit (sliding window Valkey, bersama semua replika); profil single/cluster menolak nilai < 1.000 | `docker/.env.example`, `Makefile` `check-config` |
| Rate limit per user OLT | `AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE` 10/menit (dev 60) setelah token terverifikasi; melebihi → `429 rate_limited` + `Retry-After` | `services/auth-bridge/README.md` |
| IP klien | `X-Forwarded-For` hanya dipercaya dari proxy (`TRUSTED_PROXIES`, Kong hanya dari subnet `edge`); XFF dari internet dibuang Traefik | `services/auth-bridge/README.md`, `docker/compose.yml` (`KONG_TRUSTED_IPS`) |
| Valkey mati | Fail open ke limiter in-memory per instance, cache dilewati, `/readyz` = `degraded` | `services/auth-bridge/README.md` Ketahanan |
| Cache verifikasi | Kunci = SHA-256 token, TTL `AUTH_BRIDGE_CACHE_TTL` 60 dtk, hanya profil publik; user di-ban tidak di-cache | `services/auth-bridge/README.md` |
| Mode lain | `mock` ditolak saat `APP_ENV=production`; `websocket` (lama) tidak dipasang di compose | `docs/panduan/produksi.md` bagian 2 |

Verifikasi: `make smoke-dummy` (login, perpanjangan, token diubah, kedaluwarsa, audience lain, akun ditangguhkan, logout), `make test-bridge`, Hub **Pengaturan → Integrasi → Integrasi aplikasi** (status *Aktif* tanpa peringatan kunci dev).

### 8.2 Autentikasi staf

| Aturan | Nilai | Sumber |
|---|---|---|
| Penyedia | GoTrue email + password; pendaftaran publik mati (`GOTRUE_DISABLE_SIGNUP=true`); telepon dan anonim mati | `docker/compose.yml` service `auth` |
| Password | Minimal 12 karakter (`GOTRUE_PASSWORD_MIN_LENGTH`); password sementara akun baru/reset ditampilkan sekali dan wajib diganti saat login pertama | `docker/compose.yml`, `docs/panduan/hub-untuk-staf.md` 3.4 |
| Pembuatan akun | Super Admin pertama dengan `make cs-bootstrap-admin` (menolak bila sudah ada Super Admin aktif kecuali `FORCE=1`); akun berikutnya dari Hub **Pengaturan → Akun CS** lewat Edge Function `cs-admin` (hanya di domain CS) | `docs/panduan/produksi.md` bagian 8 |
| 2FA | TOTP (`aal2`) wajib untuk peran di `security.mfa_required_roles` (bawaan `["cs_super_admin"]`, Super Admin tidak bisa dilepas; peran lain yang bisa dipilih: `cs_agent`, `compliance`, `community`, `product`, `cs_content`); staf yang sudah mendaftar 2FA tetap diminta kodenya. Tanpa kode → `401 mfa_required` | `0186` (`cs.check_security_setting`), tes `164_staff_login_security_test.sql` |
| Kunci akun | Hook GoTrue `private.hook_password_verification_attempt` menghitung password salah dalam jendela `security.login_lock_minutes`; setelah `security.login_max_failures` kali akun dikunci selama `security.login_lock_minutes`. Bawaan 5 kali / 15 menit; rentang 3–20 kali dan 1–1.440 menit | `0186`, `docker/compose.yml` (`GOTRUE_HOOK_PASSWORD_VERIFICATION_ATTEMPT_*`) |
| Pemulihan | Super Admin: **Buka kunci** dan **Reset 2FA** di Akun CS (tidak bisa mereset diri sendiri; reset mengeluarkan staf dari semua perangkat). Super Admin terakhir kehilangan HP: `make cs-mfa-reset EMAIL=...` di server (menghapus 2FA dan membuka kunci, tercatat di audit) | `docs/panduan/hub-untuk-staf.md` 3.4, `Makefile` |
| Sesi | JWT GoTrue berlaku `JWT_EXPIRY` 3.600 dtk; setiap tab browser memegang sesi sendiri (`sessionStorage` dengan kunci per tab), sehingga beberapa akun bisa dibuka bersamaan; keluar otomatis setelah idle `ui.idle_logout_minutes` 30 menit | `docker/.env.example`, `rendezvous_hub/README.md`, `src/lib/supabase.ts` |
| Akses jaringan | `/auth/v1` dan `/functions/v1` hanya di `CS_CONSOLE_DOMAIN` dengan `ipAllowList` `VPN_SOURCE_RANGES` | `docker/volumes/traefik/cs.yml` |
| Akun Nasabah | nasabah-gateway memeriksa izin per akun CS dan `aal` (Super Admin wajib `aal2`) | `cs_api.nasabah_access(p_user_id, p_aal)`, tes `032_cs_nasabah_access_test.sql` |
| Jam server | NTP wajib karena kode TOTP berganti setiap 30 dtk | `docs/panduan/produksi.md` bagian 8 |

Verifikasi: tes `164_staff_login_security_test.sql`, `023_cs_supervisor_admin_test.sql`, E2E `auth.spec.ts` (login tanpa TOTP untuk CS, Super Admin wajib kode 2FA), `multi-tab.spec.ts` (akun lain di tab lain tidak memutus sesi).

### 8.3 Otorisasi

- **RLS di setiap tabel.** Semua tabel di skema aplikasi mengaktifkan row level security; anon tidak punya akses. Partisi baru ikut diberi RLS (`cs.ensure_partitions`). Tes `001_schema_test.sql` dan `014_roles_privileges_test.sql` gagal bila ada tabel tanpa RLS atau hak berlebih (`docs/panduan/produksi.md` bagian 8).
- **Skema terekspos.** PostgREST hanya membuka `public`, `graphql_public`, dan `cs_api` (`PGRST_DB_SCHEMAS`). Skema `private`, `cs`, `auth`, `vault`, `storage`, `olt_internal`, `admin_api`, `realtime`, `_realtime`, `cron`, `net`, `extensions`, `supabase_functions` dijawab 406 untuk anon, nasabah, dan agen (laporan uji 3.1).
- **Fungsi `security definer`.** Logika bisnis berada di fungsi SQL `security definer` dengan `set search_path = ''`; hak eksekusi dicabut dari `public` dan diberikan eksplisit ke `authenticated` atau `service_role`. 27 RPC khusus `service_role` (mis. `push_claim`, `upsert_olt_profile`, `integration_notify`, `media_hold`) menolak anon/nasabah/agen (laporan uji 3.1).
- **Peran staf.** `cs_agent`, `cs_super_admin`, `compliance`, `community` (lewat izin Komunitas), `product` (Fitur & Banner, `0121`), `cs_content` (Pusat Bantuan, `0126`); izin Akun Nasabah per akun. Setiap RPC staf memanggil `cs.require_agent('{peran}')` dan memakai identitas dari `cs.current_agent_id`; agen nonaktif ditolak. Semua 208 fungsi `cs_api` yang diprobe dengan argumen null tidak pernah menjawab 2xx untuk aktor yang tidak berhak.
- **Pemeriksaan per request.** `private.check_request` (PostgREST `db-pre-request`, definisi terbaru `0177`) menolak: user di-ban (`403 user_banned`, kecuali RPC banding), profil terhapus (`403 account_rejoin_cooldown`), akun CS yang memakai skema `public` (`403 cs_staff_social_forbidden`), JWT akun CS dari domain publik (`403 cs_staff_public_edge`), dan JWT yang terbit sebelum sesi dicabut (`401 session_revoked`).
- **Data identitas.** Kolom `profiles.olt_user_id` tidak bisa dibaca `authenticated`; email di `private.user_private`.
- **Realtime.** Kanal privat `room:<id>` dan `user:<id>`; klien hanya boleh menulis presence, sinyal server dikirim dari database, typing lewat RPC (`0098`). Join kanal milik orang lain ditolak (`realtime-authz.js` 15/15).
- **Storage.** Bucket `evidence` dan `cs-documents` privat; lampiran room hanya untuk anggota; avatar orang lain tidak bisa ditimpa/dihapus; pembuatan/ubah bucket ditolak (laporan uji 3.1, tes `009_realtime_storage_test.sql`).

### 8.4 Segmentasi jaringan

| Network | Sifat | Isi |
|---|---|---|
| `edge` | `internal`, subnet tetap `EDGE_SUBNET` (bawaan `10.250.250.0/24`) | Traefik ↔ Kong, cs-console, nasabah-gateway. Kong hanya mempercayai `X-Forwarded-For` dari subnet ini |
| `app` | `internal` | Kong ↔ PostgREST, Storage, Realtime, layanan Go |
| `data` | `internal` | Postgres, PgBouncer, Valkey dan kliennya |
| `egress` | akses keluar | Traefik (Let's Encrypt), Edge Functions (impor Deno pertama), notifier (FCM), sentinel (Telegram/SMTP), link-preview (halaman yang dipratinjau), backup (S3), clamav (`database.clamav.net`), nasabah-gateway (csAdmin di LAN), trade-relay (dijeda) |
| tanpa network | `network_mode: none` | healer |

Sumber: `docker/compose.yml` (networks dan service). auth-bridge, media, classifier, janitor, dan integration tidak tersambung ke `egress`.

- **Pemisahan domain.** `PROXY_DOMAIN` (publik) hanya membuka `/rest/v1`, `/realtime/v1`, `/storage/v1`, `/media/v1`, `/integration/v1`, `/bridge/v1`; path lain 404, termasuk `/auth/v1`, `/functions/v1`, `/pg`, `/graphql/v1`, dan Studio (`docker/volumes/traefik/prod.yml`). `CS_CONSOLE_DOMAIN` menyajikan Hub dan API staf (`/auth/v1`, `/functions/v1`, `/rest/v1`, `/realtime/v1`, `/storage/v1`, `/media/v1`, `/api-nasabah`) dengan middleware `vpn-only` (`ipAllowList` `VPN_SOURCE_RANGES`); IP lain 403 (`cs.yml`). VPN tidak wajib: isi dengan LAN kantor atau IP publik kantor.
- **Firewall.** Hanya 22/80/443 dibuka; SSH hanya dari IP admin dengan key. Firewall tidak bisa membedakan domain di port 443, karena itu pembatasan per domain dilakukan `ipAllowList`.
- **Studio dan admin.** Entrypoint `admin` (semua path, termasuk Studio) hanya terikat ke `127.0.0.1` server dan dibuka lewat SSH tunnel/WireGuard; Studio mati bawaan (`make admin-up`/`admin-down`).
- **Endpoint internal.** Port ops auth-bridge 9100, admin PostgREST 3001, `/metrics` Realtime, dan konsol PgBouncer tidak dipublikasikan dan tidak di-route Kong/Traefik.

Verifikasi: `make test-security` (`static-config`: Host wajib, path terlarang, entrypoint admin; `prod-routing`: path publik vs 404, 403 dari luar `VPN_SOURCE_RANGES`), checklist go-live D (Hub dari jaringan lain mendapat 403).

### 8.5 Pengerasan container

| Kontrol | Penerapan | Sumber |
|---|---|---|
| Root filesystem | `read_only: true` untuk semua service (anchor `x-base`), direktori tulis lewat `tmpfs` atau volume | `docker/compose.yml` |
| Pengguna | Non-root (mis. Traefik `65532`, storage `1000`, valkey `999`, cs-console `101`, healer `65532`); pengecualian entrypoint Postgres (`cap_add` terbatas `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETGID`, `SETUID`) | `docker/compose.yml`, `docs/panduan/produksi.md` bagian 1 |
| Capability | `cap_drop: [ALL]`, `security_opt: no-new-privileges:true` | `docker/compose.yml` `x-base` |
| Batas sumber daya | Setiap service punya batas CPU, memori, dan pids (mis. db 2 CPU / `DB_MEMORY` 2G / 512 pids; rest 1 CPU / 512M / 256 pids) | `docker/compose.yml` `deploy.resources.limits` |
| Healer (Docker socket) | Satu-satunya container dengan `/var/run/docker.sock` (setara root host): `network_mode: none`, tanpa port, read-only, non-root, `group_add` `HEALER_DOCKER_GID`, batas 0,25 CPU / 48M / 32 pids; hanya me-restart container berlabel `olt.autoheal=true`; tidak dijalankan di cluster | `docker/compose.yml`, `docs/panduan/produksi.md` bagian 7 |
| Versi image | Image pihak ketiga di-pin tag + digest (mis. `traefik:v3.7.16@sha256:…`, `postgrest/postgrest:v14.18@sha256:…`), tidak pernah `latest`; image sendiri `olt-social/<layanan>:<versi>` dipindai Trivy | `docker/compose.yml`, `.github/workflows/backend.yml` |
| Dependensi | Image kita yang dipakai 0 CRITICAL / 0 HIGH (4 Nov); image pihak ketiga dinaikkan ke rilis stabil vendor ≥ 1 minggu | laporan uji 10.7, 12.7 |

### 8.6 Rahasia

- **Docker secrets.** Rahasia infrastruktur hanya dari `docker/secrets/` (dibuat `make gen-secrets`): `postgres_password`, `backup_db_password`, `jwt_secret`, `anon_key`, `service_role_key`, `dashboard_password`, `secret_key_base`, `realtime_db_enc_key`, `realtime_erlang_cookie`, `pg_meta_crypto_key`, `valkey_password`, `postgrest_db_uri`, `pgbouncer_stats_password`, `olt_jwks` (publik, tetapi tetap file secret), `csadmin_signing_key`. Folder `chmod 700`, dimiliki deployer, tidak di-commit. Nilai env compose berisi placeholder `{{secret:nama}}` yang diisi `volumes/olt/with-secrets.sh`, sehingga rahasia tidak muncul di `.env`, image, atau `docker inspect` (`docker/compose.yml`, `docs/panduan/produksi.md` bagian 2).
- **`docker/.env` bukan rahasia.** File ini hanya konfigurasi; `check-config` menolak nilai `CHANGE_ME`.
- **Vault.** Kredensial operasional yang dikelola dari Hub (kunci Firebase, secret access key dan password backup, token bot Telegram, password SMTP) disimpan terenkripsi di Supabase Vault dan hanya dibaca layanan terkait lewat RPC `service_role`; nilainya tidak pernah ditampilkan lagi di Hub (bagian 9.5).
- **Kunci Vault.** `pgsodium_root.key` ada di volume `db-config`, tidak ikut backup mana pun; salinannya wajib disimpan di luar server bersama password backup. Pemulihan ke server baru tanpa kunci ini memicu alert `backup:secret`/`alerts:secret` dan pengisian ulang dari Hub (`0067`).
- **Rotasi `jwt_secret`.** Membatalkan `anon_key`, `service_role_key`, dan semua JWT user. Prosedur: buat ulang ketiganya di staging dengan `make gen-secrets`, salin ke produksi tanpa membuat ulang `postgres_password`, `make up`, lalu rilis aplikasi dengan `ANON_KEY` baru dengan masa transisi (`docs/panduan/produksi.md` bagian 6). Prosedur lengkap dengan masa transisi: perlu konfirmasi (dirujuk ke `docs/panduan/operasional.md`).
- **Rotasi kunci OLT.** Tambah kunci baru ke JWKS, restart auth-bridge, OLT mulai memakai kunci baru, hapus kunci lama setelah ≤ 15 menit (`docs/olt-integration.md` bagian 3).
- **Klien.** `SERVICE_ROLE_KEY` tidak pernah ada di aplikasi Flutter atau browser Hub; klien hanya memakai `ANON_KEY` (publik).

### 8.7 Pipeline unggah

Nasabah mengunggah lewat `POST /media/v1/object/{bucket}/{path}`; Storage menolak unggahan nasabah yang tidak membawa klaim `media_verified` (`0063`). Staf di domain CS mengunggah langsung ke Storage (`services/media/README.md`).

| Tahap | Aturan | Kode error |
|---|---|---|
| Autentikasi | JWT HS256 `role = authenticated`, `sub` UUID, `exp` (toleransi 30 dtk); `anon`/`service_role` ditolak | `401 invalid_token` |
| Bucket dan path | Hanya `avatars` (2 MiB), `attachments` (5 MiB; room chat CS sampai 10 MiB sesuai kebijakan), `cs-documents` (10 MiB), `cs-videos` (25 MiB, maks 120 dtk); path 1–6 segmen `[A-Za-z0-9._-]{1,128}`, tanpa percent-encoding | `400 bucket_not_allowed`, `400 invalid_path`, `413 file_too_large` |
| Deteksi jenis | Dari isi (magic bytes, struktur ZIP Office, header ISO BMFF/EBML); `Content-Type` klien diabaikan; ekstensi diganti ekstensi kanonik | `415 unsupported_type`, `422 invalid_text` |
| Sanitasi gambar | JPEG/PNG/WebP/GIF: EXIF/GPS, XMP, IPTC, komentar, thumbnail, dan data di luar akhir file dibuang tanpa re-encode | — |
| PDF | Tidak diubah; ditolak bila terenkripsi atau berisi `/JavaScript`, `/JS` aktif, `/Launch`, `/EmbeddedFile`, `/RichMedia`, `/XFA` (termasuk di object stream) | `422 pdf_encrypted`, `422 pdf_active_content`, `422 invalid_pdf` |
| Office | DOCX/XLSX/PPTX modern saja; makro, ActiveX, OLE, file program, relasi eksternal berbahaya, dan zip bomb ditolak | `422 office_macro`, `422 office_unsafe`, `422 archive_bomb` |
| NSFW | Setiap gambar (dan thumbnail video) dinilai classifier (MobileNetV4, CPU); ambang dari Kepatuhan → Ambang gambar: blokir, tahan (hanya pengunggah dan moderator, antrean Gambar ditahan), atau izinkan. Classifier mati → fail closed | `422 image_blocked`, `503 classifier_unavailable` |
| Antivirus | `cs-documents` dan `cs-videos` dipindai ClamAV (`INSTREAM`); clamd mati → fail closed (chat teks dan gambar tetap jalan); signature > 3 hari memicu peringatan | `422 malware_detected`, `503 scanner_unavailable` |
| Penyimpanan | Diteruskan ke Storage dengan JWT baru berklaim `media_verified: true` (berlaku ≤ 120 dtk); header `X-Olt-Edge` diteruskan agar staf di domain publik tetap ditolak | `403 upload_forbidden` (staf di domain publik) |

Verifikasi: tes `044_media_uploads_test.sql`, `059_media_moderation_test.sql`, `111_cs_attachment_formats_test.sql`, `112_media_scanner_health_test.sql`; `make test-media`, `make test-classifier`; `make chaos-test E=classifier`.

### 8.8 Rate limit

| Lapisan | Batas | Sumber |
|---|---|---|
| Edge per IP (Traefik) | `EDGE_RATE_AVERAGE` 600 req/dtk, `EDGE_RATE_BURST` 1.200; melebihi → 429 | `docker/volumes/traefik/common.yml` |
| WebSocket per IP | `EDGE_WS_PER_IP` 1.500 koneksi bersamaan | `common.yml` (`ws-limit`) |
| Exchange auth-bridge | 1.500/menit per IP, 10/menit per user OLT | 8.1 |
| Realtime per tenant | 10.000 pengguna, 500 join/dtk, 100 kanal per klien, 20.000 event/dtk | `docker/compose.yml` |
| Aksi per user | Tabel `private.rate_limits` (beberapa jendela per aksi, bagian 9.3); selama masa akun baru batas dikali `rate_limit.new_account_factor` 0,5, akun tepercaya (`trust_level` ≥ 2) dikali `rate_limit.trusted_factor` 2; 429 membawa `Retry-After` | `0012`, `0187` |
| API key integrasi | `rate_limit_per_minute` per key, bawaan key baru 3.000/menit (rentang 1–100.000); pengirim wajib batch 100–500 pesan per request; CIDR sumber per key (maks 20) | `0068`, `0101` |
| Bot posts | `integration.bot_posts_per_hour` 30 per key | `0068` |

Catatan: `ipStrategy depth: 0` (alamat koneksi langsung). Bila server nanti di belakang load balancer/CDN, strategi IP wajib disesuaikan sebelum pindah (`docs/panduan/produksi.md` Batas & rate limit). Verifikasi: tes `010_rate_limits_test.sql`, `081_integration_rate_default_test.sql`; `make test-security` (`prod-routing`: 429 edge, batas WebSocket).

### 8.9 Proteksi SSRF

`link-preview` satu-satunya layanan yang mengambil URL internet sembarang (`services/link-preview/README.md`):

- URL dicek sebelum request dan di setiap redirect; setiap alamat hasil DNS dicek sebelum dial (satu jawaban privat cukup untuk menolak host); `net.Dialer.Control` mengecek IP dan port socket yang benar-benar di-connect.
- Rentang privat, loopback, link-local (termasuk metadata cloud `169.254.169.254`), CGNAT, jaringan Docker, multicast, dan rentang dokumentasi IPv4/IPv6 ditolak; nama internal (`localhost`, host satu label, `*.local`, `*.internal`, dsb.) ditolak sebelum DNS.
- Hanya port 80 dan 443; proxy dari env diabaikan; maksimal 3 redirect; batas total 5 dtk per request; HTML maks 1 MiB setelah dekompresi, gambar maks 5 MiB, header maks 64 KiB; keep-alive mati (resolve + cek ulang setiap request, menutup DNS rebinding).
- Hanya trigger konten (yang sudah kena rate limit dan kebijakan konten) yang bisa mengantre URL; maks 3 URL unik per konten; chat CS dilewati; domain di `cs.blocked_domains` dicek saat antre, claim, laporan (termasuk domain akhir setelah redirect), dan baca, fail closed bila query gagal.
- Gambar pratinjau disanitasi dan dinilai classifier NSFW; classifier mati → pratinjau tanpa gambar.

Verifikasi: `make test-link-preview`, tes `060_link_previews_test.sql`, `074_link_preview_nsfw_test.sql`.

### 8.10 Penolakan JWT akun CS di domain publik

Tujuannya: JWT staf yang bocor (berlaku 1 jam) tidak bisa dipakai dari internet (temuan T4, laporan uji).

1. Di domain publik, skema `cs_api` hanya dibuka untuk RPC chat CS dan Pusat Bantuan yang dipanggil aplikasi nasabah (router `api-cs-customer`): `support_home`, `topics`, `open_ticket`, `my_tickets`, `ticket_messages`, `close_ticket`, `rate_ticket`, `request_complaint`, `report_fake_cs`, `check_sensitive`, `get_messages`, `send_message`, `mark_read`, `room_members`, `faq`, `faq_search`, `faq_article`, `faq_feedback`, `faq_for_topic`, `attachment_policy`, `service_status`, `ticket_transcript`, `guest_config`, `guest_start`, `guest_poll`, `guest_send`, `guest_end` (27 RPC, `docker/volumes/traefik/prod.yml`). Request `cs_api` lain (`Accept-Profile`/`Content-Profile`) dijawab 403 (`api-cs-staff-block`); router `api` membuang kedua header sehingga hanya skema `public` yang terjangkau.
2. Router REST, Realtime, Storage, dan `/media/v1` publik memasang `X-Olt-Edge: public` (menimpa nilai dari klien); router domain CS membuangnya (`cs-edge`).
3. `private.check_request` menolak JWT akun CS yang membawa penanda: `403 cs_staff_public_edge` (`0100`).
4. `0105`: kebijakan `olt_realtime_receive`/`olt_realtime_send` menolak join kanal privat (`cs:*`, `room:*`) dan presence oleh JWT staf ("Unauthorized"); policy restrictive `cs_staff_public_edge` di `storage.objects` menolak semua operasi staf di semua bucket (termasuk signed URL dan list); media meneruskan penanda sehingga unggah staf di domain publik ditolak `403 upload_forbidden`; trigger `cs_staff_postgres_changes` menolak `postgres_changes` akun CS di semua domain; topik `online` ditutup.
5. `/functions/v1` (Edge Function `cs-admin`) tidak dipublikasikan di domain publik.

Bila aplikasi nasabah menambah pemanggilan RPC `cs_api`, namanya wajib ditambahkan ke regex `api-cs-customer`; `static-config` mencocokkan allowlist dengan pemanggilan `cs_api` di `lib/` library dan gagal bila ada yang terlewat. Verifikasi: tes `080_cs_staff_public_edge_test.sql`, `085_cs_staff_public_edge_realtime_storage_test.sql`; `make test-security` (`prod-routing`, `realtime-edge.js`); checklist: `https://<PROXY_DOMAIN>/functions/v1/cs-admin/agents` = 404 dan `/rest/v1/rpc/agent_me` dengan `Accept-Profile: cs_api` = 403.

### 8.11 Header keamanan web

| Permukaan | Header | Sumber |
|---|---|---|
| API publik (Traefik `security-headers`) | `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'`, `X-Frame-Options` (frameDeny), `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, header `Server` dan `X-Powered-By` dikosongkan; HSTS `max-age=31536000; includeSubDomains` (profil HTTPS) | `docker/volumes/traefik/common.yml` |
| Hub (nginx cs-console) | CSP `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'`, `connect-src` hanya origin API CS (HTTP + WebSocket), `img-src`/`media-src` origin API, `object-src 'none'`, `base-uri 'none'`, `form-action 'self'`, `frame-ancestors 'none'`; `Strict-Transport-Security`; `X-Frame-Options: DENY`; `X-Content-Type-Options: nosniff`; `Referrer-Policy: no-referrer`; `Permissions-Policy` mematikan kamera, mikrofon, geolokasi, pembayaran, USB, serial, Bluetooth; tanpa cache untuk `index.html` | `rendezvous_hub/docker/templates/security-headers.inc.template`, `docs/panduan/produksi.md` bagian 8 |
| CORS | Produksi bawaan kosong (`CORS_ALLOWED_ORIGINS`), Hub satu origin dengan API CS sehingga tidak butuh CORS; dev `*` | `docker/compose.prod.yml`, laporan uji 3.2 |
| TLS | ≥ TLS 1.2, cipher ECDHE + AEAD (AES-GCM, ChaCha20-Poly1305), `sniStrict` bawaan `true` | `docker/volumes/traefik/prod.yml` |

Catatan: HSTS tanpa `preload`; `style-src 'unsafe-inline'` di Hub dicatat sebagai info oleh ZAP baseline (laporan uji T14). Verifikasi: `make test-security` (`static-config`, `prod-routing`), opsional `make test-zap`.

### 8.12 Keamanan rantai pasok

- **Pemindaian rahasia.** gitleaks pada seluruh riwayat git (`.gitleaks.toml`, `--redact`) di CI ketiga repo dan `make secrets-scan`.
- **Kerentanan.** `make scan-deps`: govulncheck (semua modul Go), `npm audit --omit=dev`, osv-scanner (semua lockfile), Trivy HIGH/CRITICAL; `STRICT=1` gagal bila ada temuan penghalang. CI: Trivy image setiap layanan Go dan image Hub (`ignore-unfixed`, gagal pada CRITICAL/HIGH), Trivy fs Hub (vuln, secret, misconfig).
- **Lisensi.** Tanpa GPL/AGPL: `make license-audit` (library, `tool/license_audit.dart`), `npm run license:check` (Hub, bagian `npm run ci`). Layanan Go mencantumkan lisensi dependensinya di README (mis. auth-bridge: BSD-2-Clause, BSD-3-Clause, MIT); pemeriksaan lisensi otomatis untuk modul Go: perlu konfirmasi.
- **Pin versi.** GitHub Actions di-pin ke SHA commit; image alat (gitleaks, Go, k6 testkit) di-pin digest; image pihak ketiga tag + digest.
- **Distribusi library.** Repo library privat; aplikasi mem-pin tag rilis (`ref: v1.49.2`); token GitHub tidak boleh berada di URL `pubspec.yaml` (`rendezvous_community/doc/integration.md`).
- **Uji independen.** Pentest independen dan review kode senior (auth-bridge, RLS, chat CS) sebelum go-live; temuan kritis dan tinggi wajib ditutup (checklist go-live G). Hasilnya: perlu konfirmasi.

## 9. Konfigurasi dan parameter

Sistem memakai empat tempat konfigurasi. Nilai di bawah adalah default dari migrasi dan file contoh; nilai yang berlaku di server bisa sudah diubah staf atau operator.

| Tempat | Isi | Cara mengubah |
|---|---|---|
| `private.settings` (`key` text, `value` jsonb, `description`) | Parameter fitur sosial, keamanan konten, retensi, notifikasi, integrasi, Kesehatan sistem (9.1) | RPC Hub tertentu (dicatat di Jejak Audit) atau SQL operasional; dibaca fungsi lewat `private.setting_num`/`private.setting_json` dengan default di kode |
| `cs.cs_settings` (`key`, `value`, `version`, `updated_by`) dengan riwayat append-only `cs.cs_settings_history` | Parameter layanan CS, keamanan login staf, empat mata, integrasi (9.2) | `cs_api.admin_set_setting(p_key, p_value)` khusus Super Admin, hanya untuk kunci di `cs.admin_editable` (selain itu `403 setting_locked`), nilai divalidasi (`400 invalid_setting`), audit `setting.update`; beberapa kunci punya RPC sendiri |
| `private.rate_limits` (`action`, `window_seconds`, `max_count`) | Batas aksi per user (9.3) | SQL operasional (`docs/panduan/produksi.md` bagian 5.2); tidak ada RPC Hub |
| `docker/.env` (dari `docker/.env.example`) | Konfigurasi stack non-rahasia (9.4) | Edit file lalu `make up`; rahasia tidak pernah di sini |

Kredensial operasional yang dikelola di Hub dirangkum di 9.5.

Catatan pemetaan: sebagian kunci yang kerap disebut sebagai "pengaturan sistem" sebenarnya berada di `cs.cs_settings`, bukan `private.settings`: `security.*`, `compliance.policy_four_eyes`, `brand.support_name`, `banners.deep_link_schemes`, `banners.notice_four_eyes`, `accounts.max_per_customer`, `notifications.watchlist_digest_time`, `guest.*`. Kunci `trust.new_account_hours` dihapus di `0187` dan digantikan `safety.new_account_days`.

### 9.1 Kunci `private.settings`

Diurutkan per kelompok. "Migrasi" = migrasi yang membuat kunci, diikuti migrasi yang mengubah nilai atau artinya. Kunci yang dikelola lewat Kebijakan konten masuk versi kebijakan dan perubahan dari Hub mengikuti draf + persetujuan empat mata bila `compliance.policy_four_eyes` aktif (`0092`, `0175`).

| Kunci | Default | Arti | Dikelola di | Migrasi |
|---|---|---|---|---|
| `account.rejoin_cooldown_hours` | `72` | Jam tunggu setelah akun komunitas dihapus sebelum login yang sama bisa bergabung lagi (0 = tanpa jeda) | Hub Kepatuhan → Kebijakan konten; RPC `compliance_set_rejoin_cooldown_hours` lewat draf + empat mata | 0175 |
| `safety.new_account_days` | `3` | Masa akun baru (hari sejak daftar atau bergabung lagi): tanpa gambar, tanpa tautan, DM ke non-mutual lewat permintaan pesan, batas kecepatan dikali `rate_limit.new_account_factor`. 0 = tanpa batasan | Hub Kepatuhan → Kebijakan konten (masa akun baru, 0–30 hari); RPC `compliance_set_new_account_days` lewat draf + empat mata | 0069, 0187 |
| `rate_limit.new_account_factor` | `0.5` | Pengali batas rate limit selama masa akun baru (`safety.new_account_days`) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0012, 0187 |
| `rate_limit.trusted_factor` | `2` | Pengali batas rate limit untuk trust_level >= 2 (tepercaya / resmi) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0012 |
| `content.duplicate_max` | `3` | Kiriman ke-n dengan isi sama dalam jendela ditolak | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0014 |
| `content.duplicate_min_length` | `10` | Teks lebih pendek dari ini tidak dicek duplikat (mis. "ok") | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0014 |
| `content.duplicate_window_seconds` | `300` | Jendela deteksi konten sama (detik) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0014 |
| `content.edit_minutes` | `15` | Post dan komentar bisa diedit penulisnya selama sekian menit setelah dibuat | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0075 |
| `content.max_links` | `3` | Maks link per post/komentar/pesan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0014 |
| `content.max_mentions` | `10` | Maks @mention per konten | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0014 |
| `content.max_stock_tags` | `10` | Maks $KODE per konten | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0014 |
| `dm.request_max_messages` | `3` | Pesan maksimal dari pengirim sebelum permintaan pesan DM diterima penerima | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0070 |
| `drafts.max_per_user` | `20` | Maksimal draf postingan tersimpan per pengguna | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0090 |
| `mute.max_keywords` | `50` | Maks kata yang bisa di-mute per user | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0015 |
| `appeals.window_days` | `30` | Batas hari sejak sanksi/penindakan konten untuk mengajukan banding | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0071 |
| `moderation.sanction_ladder` | `[{"kind":"warning"},{"kind":"mute","hours":1},{"kind":"mu…` | Sanksi bertingkat: langkah ke-n dipakai untuk pelanggaran ke-n (langkah terakhir berulang) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0013 |
| `legal.required_kinds` | `["terms","community_guidelines"]` | Dokumen yang wajib disetujui sebelum menulis | Hub Kepatuhan → Dokumen hukum; RPC `legal_set_required` (audit `legal.required_changed`) | 0014 |
| `feed.for_you_days` | `7` | Feed Untuk Anda menimbang postingan dalam sekian hari terakhir | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0143 |
| `feed.top_days` | `30` | Feed urutan Top menimbang postingan dalam sekian hari terakhir | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0143 |
| `suggestions.active_days` | `14` | Saran akun untuk diikuti diambil dari penulis aktif dalam sekian hari terakhir | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0143 |
| `stock_stats.max_codes` | `50` | Maks kode saham per permintaan statistik saham dan feed watchlist | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0143 |
| `search.min_query_length` | `2` | Panjang minimum kata kunci pencarian (karakter) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0073 |
| `search.typo_min_length` | `4` | Pencarian toleran salah ketik (trigram) dipakai bila kata kunci minimal sekian karakter | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0073 |
| `trending.bucket_retention_days` | `35` | Agregat 5 menit disimpan selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0074 |
| `trending.manipulation_weight` | `0.3` | Pengali skor trending untuk saham yang punya alert manipulasi terbuka dan post yang membahasnya (0-1) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0074 |
| `trending.min_authors` | `2` | Hashtag/saham baru masuk trending bila dibahas minimal sekian penulis berbeda | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0073 |
| `trending.new_account_days` | `7` | Akun yang lebih muda dari sekian hari berbobot rendah di trending | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0073 |
| `trending.new_account_weight` | `0.2` | Bobot akun baru atau trust_level 0 di trending (0-1) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0073 |
| `trending.post_gravity` | `1.5` | Laju peluruhan skor post populer terhadap umur (jam) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0074 |
| `trending.rising_min_posts` | `5` | Saham masuk daftar "diskusi naik" bila minimal sekian post di jendela berjalan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0074 |
| `manipulation.auto_hold_similar` | `true` | Aksi otomatis: tahan (held) posting mirip terkoordinasi | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.auto_slow_mode` | `true` | Aksi otomatis: slow mode di room saham saat ada alert | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.auto_slow_mode_minutes` | `60` | Aksi otomatis: lama slow mode (menit) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.auto_slow_mode_seconds` | `10` | Aksi otomatis: jeda slow mode (detik), paling ketat sama dengan slow mode jam ramai | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072, 0110 |
| `manipulation.baseline_days` | `7` | Lonjakan: panjang periode dasar (hari) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.new_account_age_days` | `7` | Konsentrasi akun baru: umur akun yang dianggap baru (hari) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.new_account_min_mentions` | `10` | Konsentrasi akun baru: minimal mention dalam 1 jam terakhir | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.new_account_share` | `0.6` | Konsentrasi akun baru: porsi mention dari akun baru (0–1) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.similar_min_authors` | `5` | Posting terkoordinasi: minimal penulis berbeda | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.similar_window_minutes` | `30` | Posting terkoordinasi: jendela waktu (menit) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.similarity` | `0.8` | Posting terkoordinasi: kemiripan teks minimal (pg_trgm, 0–1) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.spike_factor` | `5` | Lonjakan: mention 1 jam terakhir > faktor × rata-rata per jam periode dasar | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `manipulation.spike_min_mentions` | `20` | Lonjakan: minimal mention dalam 1 jam terakhir | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `rooms.busy_slow_mode` | `10` | Slow mode otomatis room saham pada jam ramai hari bursa (detik, 0 = mati) | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `rooms.busy_windows` | `[["08:55", "09:30"], ["15:50", "16:15"]]` | Jam ramai (WIB) untuk slow mode otomatis | Hub Kepatuhan → Kebijakan konten → Anti-manipulasi; RPC `compliance_set_manipulation_settings` (lewat draf kebijakan) | 0072 |
| `rooms.presence_max_members` | `50` | Presence ditolak di DM dan grup dengan anggota sebanyak ini atau lebih | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0106 |
| `rooms.presence_stock_members` | `0` | Presence ditolak di room saham dengan anggota sebanyak ini atau lebih (0 = selalu ditolak) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0106 |
| `rooms.preview_poll_seconds` | `15` | Jarak polling pratinjau room saham di daftar chat aplikasi (detik, sebelum jitter) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0107 |
| `rooms.typing_aggregate_members` | `50` | Room non-CS dengan anggota sebanyak ini atau lebih menyiarkan ringkasan typing (typing_summary), bukan typing per orang | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0106 |
| `rooms.typing_off_members` | `2000` | Room non-CS dengan anggota sebanyak ini atau lebih tidak menyiarkan typing sama sekali | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0106 |
| `rooms.typing_summary_seconds` | `3` | Jarak minimal antar ringkasan typing per room (detik) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0106 |
| `room_mods.max_mute_hours` | `24` | Moderator room: lama bisu maksimal yang boleh diberikan moderator (jam, 1–24) | Hub Komunitas → Room saham (moderator room); RPC `community_set_room_moderator_settings` | 0093 |
| `room_mods.max_per_room` | `10` | Moderator room: jumlah moderator aktif maksimal per room saham (1–50) | Hub Komunitas → Room saham (moderator room); RPC `community_set_room_moderator_settings` | 0093 |
| `room_mods.max_rooms_per_user` | `3` | Moderator room: jumlah room maksimal yang dimoderasi satu nasabah (1–20) | Hub Komunitas → Room saham (moderator room); RPC `community_set_room_moderator_settings` | 0093 |
| `room_mods.min_trust_level` | `2` | Moderator room: trust level minimal nasabah yang bisa ditunjuk (1–3) | Hub Komunitas → Room saham (moderator room); RPC `community_set_room_moderator_settings` | 0093 |
| `room_mods.sanction_free_days` | `90` | Moderator room: tanpa sanksi dalam sekian hari terakhir (0–365) | Hub Komunitas → Room saham (moderator room); RPC `community_set_room_moderator_settings` | 0093 |
| `notifications.aggregate_minutes` | `60` | Tidak dipakai lagi sejak 0191 (like digabung per konten tanpa batas waktu, follow selama belum dibaca); nilainya tetap dikirim ke klien lama | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0076, 0191 |
| `notifications.digest_lookback_hours` | `24` | Rentang ringkasan saham pantauan pertama (jam) bila belum ada ringkasan sebelumnya | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0087 |
| `notifications.followed_post_batch` | `5000` | Jumlah pengikut yang diberi notifikasi postingan baru per putaran job social-followed-posts | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0087 |
| `notifications.mention_room_max` | `5` | Maksimal pengguna yang diberi notifikasi mention per pesan room saham | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0087 |
| `push.device_stale_days` | `270` | Perangkat yang tidak membuka aplikasi selama sekian hari dilepas dari push | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0058 |
| `push.max_attempts` | `6` | Batas percobaan kirim satu push sebelum dianggap gagal | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0058 |
| `push.max_devices_per_user` | `10` | Batas perangkat push per pengguna; yang paling lama tidak aktif dilepas | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0058 |
| `push.retention_days` | `7` | Riwayat antrean push disimpan selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0058 |
| `push.ttl_hours` | `24` | Push yang belum terkirim setelah sekian jam dibatalkan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0058 |
| `analytics.max_batch` | `50` | Maksimal event per panggilan track_events | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0078 |
| `analytics.retention_months` | `12` | Event analitik disimpan selama sekian bulan (partisi bulanan dihapus otomatis) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0078 |
| `integration.account_link_days` | `30` | Tautan rekening OLT tidak dipakai lagi bila pemiliknya tidak login fitur sosial selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0068 |
| `integration.bot_posts_per_hour` | `30` | Batas postingan bot per API key integrasi per jam | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0068 |
| `integration.broadcast_batch_size` | `2000` | Jumlah profil yang diproses per putaran siaran notifikasi OLT | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0086 |
| `integration.broadcast_daily_cap` | `3` | Batas notifikasi siaran OLT (selain kategori important) per nasabah per hari WIB | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0086 |
| `integration.broadcast_days` | `90` | Riwayat siaran notifikasi OLT disimpan selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0086 |
| `integration.receipt_days` | `7` | Id pesan notifikasi OLT diingat selama sekian hari agar kiriman ulang tidak dobel | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0068 |
| `link_preview.cache_days` | `7` | Umur pratinjau sebelum link diambil ulang saat muncul lagi di konten (hari) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0080 |
| `link_preview.enabled` | `true` | Buat pratinjau link untuk postingan, komentar, dan chat (false = berhenti mengantre link baru) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0080 |
| `link_preview.failed_cache_hours` | `24` | Lama link yang gagal diambil tidak dicoba lagi (jam) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0080 |
| `link_preview.max_attempts` | `3` | Percobaan maksimal per link sebelum dianggap gagal | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0080 |
| `link_preview.retention_days` | `30` | Pratinjau yang kedaluwarsa lebih lama dari ini dihapus beserta gambarnya (hari) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0080 |
| `retention.access_log_days` | `730` | Log akses data pribadi disimpan selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0015 |
| `retention.archive_days` | `1825` | Lama arsip konten untuk regulator (hari). DEFAULT SEMENTARA: tetapkan bersama tim legal. | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0013 |
| `retention.audit_log_days` | `365` | Audit log admin disimpan selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0015 |
| `retention.deleted_messages_days` | `30` | Pesan yang sudah dihapus dibersihkan permanen setelah sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0015 |
| `retention.evidence_days` | `730` | Masa simpan bukti karantina (hari) sejak bukti terakhir direkam. Legal hold menangguhkan penghapusan. | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0095 |
| `retention.notifications_days` | `90` | Notifikasi lebih tua dari ini dihapus | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0015 |
| `retention.rate_limit_events_days` | `2` | Event rate limit disimpan selama sekian hari | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0015 |
| `health.alert_after_seconds` | `120` | Lama masalah bertahan sebelum alert dibuka (detik) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0064 |
| `health.alert_after_seconds.db:lock_waits` | `25` | Tunda maksimum sebelum alert db:lock_waits dibuka (detik, tidak melebihi health.alert_after_seconds) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.alert_after_seconds.healer:*` | `0` | Tunda sebelum alert healer:<...> dibuka (detik); healer sudah menunggu sendiri sebelum menyerah | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0113 |
| `health.alert_after_seconds.healer:stale` | `60` | Tunda sebelum alert healer:stale dibuka (detik), agar start ulang healer/sentinel tidak memicu alert | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0113 |
| `health.alert_after_seconds.healer:systemic` | `120` | Tunda sebelum alert healer:systemic dibuka (detik, tidak melebihi health.alert_after_seconds) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0113 |
| `health.alert_after_seconds.metrics:*` | `25` | Tunda maksimum sebelum alert metrics:<sumber> dibuka (detik, tidak melebihi health.alert_after_seconds) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.alert_after_seconds.pgbouncer:queue` | `25` | Tunda maksimum sebelum alert pgbouncer:queue dibuka (detik, tidak melebihi health.alert_after_seconds) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.alert_after_seconds.realtime:events` | `25` | Tunda maksimum sebelum alert realtime:events dibuka (detik, tidak melebihi health.alert_after_seconds) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.alert_after_seconds.rest:pool` | `25` | Tunda maksimum sebelum alert rest:pool dibuka (detik, tidak melebihi health.alert_after_seconds) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.disk_critical_ratio` | `0.9` | Pemakaian disk yang memicu alert kritis (0–1) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0064 |
| `health.disk_warn_ratio` | `0.8` | Pemakaian disk yang memicu peringatan (0–1) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0064 |
| `health.expected_services` | `["auth-bridge","backup","classifier","integration","link-preview","media","notifier","sentinel"]` | Layanan yang wajib mengirim heartbeat; hilang lebih dari 90 detik dianggap tidak aktif | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0064, 0082, 0115 |
| `health.healer_stale_seconds` | `120` | Status healer (restart otomatis) yang tidak diperbarui lebih lama dari ini (detik) memicu healer:stale | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0113 |
| `health.lock_wait_critical_seconds` | `30` | Tunggu lock terlama (detik) yang memicu alert kritis | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.lock_wait_warn_seconds` | `5` | Tunggu lock terlama (detik) yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.lock_waiters_critical` | `20` | Jumlah proses database yang menunggu lock yang memicu alert kritis | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.lock_waiters_warn` | `5` | Jumlah proses database yang menunggu lock yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.metrics_missed_warn` | `2` | Sampel metrik yang gagal dibaca dalam jendela (termasuk dari laporan sentinel yang tidak terkirim) yang memicu metrics:<sumber> | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.metrics_missed_window_seconds` | `300` | Jendela hitung sampel metrik yang gagal dibaca (detik) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.nodes_stale_seconds` | `45` | Peta layanan dianggap terlambat bila laporan container terakhir lebih tua dari ini (detik) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0168 |
| `health.pgbouncer_maxwait_critical_seconds` | `5` | Tunggu terlama klien PgBouncer (maxwait, detik) yang memicu alert kritis | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.pgbouncer_maxwait_warn_seconds` | `1` | Tunggu terlama klien PgBouncer (maxwait, detik) yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.pgbouncer_waiting_warn` | `1` | Klien PgBouncer yang mengantre koneksi server (cl_waiting) yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.realtime_events_critical_ratio` | `0.9` | Laju event Realtime dibanding batas tenant yang memicu alert kritis (0–1) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.realtime_events_limit` | `10000` | Batas event/dtk tenant Realtime yang dipakai bila _realtime.tenants tidak terbaca | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.realtime_events_warn_ratio` | `0.7` | Laju event Realtime dibanding batas tenant (max_events_per_second) yang memicu peringatan (0–1) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.realtime_events_window_seconds` | `45` | Jendela rata-rata laju event Realtime (detik), dihitung mundur dari sampel terakhir | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.resolve_after_seconds` | `60` | Lama masalah hilang sebelum alert dinyatakan pulih (detik) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0064 |
| `health.rest_blind_warn` | `2` | Laporan sentinel yang tidak terkirim ditambah sampel metrik rest yang gagal dalam 5 menit yang memicu rest:pool | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0108 |
| `health.rest_pool_timeouts_critical` | `20` | Timeout pool PostgREST (PGRST003, HTTP 504) dalam 5 menit yang memicu alert kritis | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.rest_pool_timeouts_warn` | `1` | Timeout pool PostgREST (PGRST003, HTTP 504) dalam 5 menit yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.rest_pool_waiting_warn` | `1` | Request yang menunggu koneksi saat pool PostgREST kosong (available 0, sampel terakhir) yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.room_preview_lag_critical_seconds` | `300` | Umur antrean pratinjau room (chat-room-preview, detik) yang memicu alert kritis | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.room_preview_lag_warn_seconds` | `60` | Umur antrean pratinjau room (chat-room-preview, detik) yang memicu peringatan | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0104 |
| `health.trade_relay_silent_minutes` | `30` | Relay trade dianggap diam bila tidak ada paket realtime selama sekian menit di jam bursa | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0164 |
| `health.trade_relay_stale_seconds` | `120` | Relay trade dianggap mati bila tidak melapor selama sekian detik | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0164 |
| `banners.events_retention_days` | `180` (default di kode, tidak di-seed) | Masa simpan event banner/popup (hari) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0119, 0183 |

Catatan:

- Kunci yang tercatat "Migrasi/SQL operasional saja" diubah dengan `update private.settings set value = '<json>', updated_at = now() where key = '<kunci>';` lewat Studio/psql (bagian 5.2 `docs/panduan/produksi.md`), dan wajib dicatat manual. `admin_api.update_setting` ada di skema `admin_api`, tetapi skema itu tidak diekspos PostgREST (`PGRST_DB_SCHEMAS` = `public,graphql_public,cs_api`), jadi tidak bisa dipanggil dari luar.
- Perlu konfirmasi: apakah `rooms.busy_slow_mode` dan `rooms.busy_windows` ikut tercatat di versi kebijakan; `private.policy_setting_key` (`0175`) hanya mencakup `safety.new_account_days`, `account.rejoin_cooldown_hours`, dan `manipulation.*`.
- `retention.archive_days` (1.825 hari) adalah default sementara dan wajib ditetapkan bersama tim legal sebelum go-live (`docs/panduan/produksi.md` bagian 8).

### 9.2 Kunci `cs.cs_settings`

Tidak termasuk 18 kunci `trade_share.*` dan `trade_notify.enabled` milik Berbagi Trade yang dijeda (`0160`–`0163`; bawaan `trade_share.enabled = false`, `trade_notify.enabled = false`).

| Kunci | Default | Arti | Dikelola di | Migrasi |
|---|---|---|---|---|
| `accounts.max_per_customer` | `200` | Batas rekening per nasabah dari klaim accounts token sosial (1–200); kelebihan diabaikan | Hub Pengaturan → Integrasi → Integrasi aplikasi (1–200) | 0128 |
| `agent.heartbeat_fresh_seconds` | `30` | Agen dianggap terhubung bila heartbeat terakhir lebih baru dari ini | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027 |
| `agent.history_hours` | `24` | Agen bisa membaca riwayat room nasabah selama menangani sesinya, dan sekian jam setelah sesi yang ia tangani ditutup | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027, 0032 |
| `alerts.p1_unclaimed_minutes` | `2` | Peringatan supervisor bila tiket P1 belum diambil sekian menit | Hub Pengaturan → Penugasan, tiket & alert (1–240 menit) | 0032 |
| `alerts.unclaimed_minutes` | `10` | Peringatan supervisor bila tiket terbuka belum diambil sekian menit | Hub Pengaturan → Penugasan, tiket & alert (1–240 menit) | 0032 |
| `assignment.heartbeat_seconds` | `90` | Penugasan otomatis hanya ke CS Online yang heartbeat web CS-nya lebih baru dari sekian detik. Browser memperlambat tab di latar belakang hingga sekitar satu heartbeat per menit, jadi nilainya harus di atas 60 | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0043 |
| `assignment.mode` | `"claim"` | Mode penugasan: claim (CS mengambil tiket sendiri) atau auto_assign (sistem menugaskan otomatis) | Hub Pengaturan → Penugasan, tiket & alert (`claim` atau `auto_assign`) | 0032 |
| `attachments.cs` | objek per jenis: gambar maks 10 MB, dokumen maks 10 MB, video maks 25 MB dan 120 dtk | Format dan batas lampiran chat CS per jenis (dokumen, gambar, video); diatur Super Admin dari Hub | Hub Pengaturan → Lampiran chat CS; RPC `admin_set_attachment_policy` (audit `attachments.policy`) | 0131, 0138 |
| `banners.deep_link_schemes` | `["olt"]` | Skema deep link aplikasi yang boleh dipakai sebagai tautan banner, mis. olt untuk olt://promo/akhir-tahun | Hub Pengaturan → Integrasi → Integrasi aplikasi (maks 5 skema); RPC `admin_set_banner_link_schemes` (audit `banner.link_schemes`) | 0119 |
| `banners.notice_four_eyes` | `false` | Notifikasi info dari Banner & Popup wajib disetujui staf lain (Super Admin atau Fitur & Banner) sebelum dikirim | Hub Pengaturan → Persetujuan → Aturan empat mata | 0182 |
| `brand.support_name` | `"CS OLT"` | Nama room CS di aplikasi nasabah | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0032 |
| `community.four_eyes` | `true` | Postingan dan notifikasi resmi wajib disetujui staf lain (bukan pembuatnya) sebelum terbit | Hub Pengaturan → Persetujuan → Aturan empat mata | 0057 |
| `complaint.days` | `5` | Tenggat penyelesaian pengaduan lewat chat (hari kerja sejak diterima). Usulan default, wajib dikonfirmasi kepatuhan | Hub Kepatuhan → Tenggat & retensi (1–20 hari kerja); RPC `compliance_confirm_policy` | 0027 |
| `complaint.extension_days` | `10` | Perpanjangan tenggat pengaduan (hari kerja), paling banyak satu kali per pengaduan. 0 = tidak bisa diperpanjang. Usulan default, wajib dikonfirmasi kepatuhan | Hub Kepatuhan → Tenggat & retensi (0–20 hari kerja); RPC `compliance_confirm_policy` | 0042 |
| `compliance.policy_four_eyes` | `true` | Perubahan kebijakan konten wajib disetujui staf Kepatuhan lain (bukan pembuatnya) sebelum berlaku | Hub Pengaturan → Persetujuan → Aturan empat mata; RPC `admin_set_policy_four_eyes` | 0092 |
| `guest.enabled` | `true` | Pengaduan tamu (nasabah yang tidak bisa login) bisa dibuka dari halaman login aplikasi | Hub Pengaturan → Penugasan, tiket & alert → Pengaduan tanpa login | 0140 |
| `guest.session_hours` | `24` | Lama sesi chat pengaduan tamu (jam) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0140 |
| `guest.topic` | `"account"` | Topik chat CS untuk pengaduan tamu | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0140 |
| `help.allowed_hosts` | `["help.olt.co.id"]` | Host yang boleh dipakai untuk tautan bantuan dari agen | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027 |
| `market.hours` | `{"opens": "09:00", "closes": "16:00"}` | Jam bursa (WIB) di hari kerja, untuk prioritas masalah transaksi | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027 |
| `messages.agent_away` | teks `{"id": …, "en": …}` | Pesan saat CS pemilik tiket berstatus offline | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.complaint` | teks `{"id": …, "en": …}` | Pesan saat sesi ditandai pengaduan | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0027 |
| `messages.complaint_extended` | teks `{"id": …, "en": …}` | Pesan saat tenggat pengaduan diperpanjang | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0042 |
| `messages.out_of_hours` | teks `{"id": …, "en": …}` | Pesan saat sesi dibuat di luar jam layanan | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0027 |
| `messages.secured` | teks `{"id": …, "en": …}` | Pesan setelah aksi "Amankan akun" berhasil | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0027 |
| `messages.ticket_claimed` | teks `{"id": …, "en": …}` | Pesan saat CS mengambil tiket | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_closed` | teks `{"id": …, "en": …}` | Pemisah di chat saat tiket ditutup | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_opened` | teks `{"id": …, "en": …}` | Pesan saat tiket dibuat: salam dan pengingat keamanan dalam satu pesan | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_released` | teks `{"id": …, "en": …}` | Pesan saat CS melepas tiket ke antrean | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_reopened` | teks `{"id": …, "en": …}` | Pesan saat tiket dibuka kembali dan menunggu CS | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_reopened_owner` | teks `{"id": …, "en": …}` | Pesan saat tiket dibuka kembali ke CS pemilik | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_resolved` | teks `{"id": …, "en": …}` | Pesan saat tiket diselesaikan, sekaligus permintaan rating | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.ticket_transferred` | teks `{"id": …, "en": …}` | Pesan saat tiket dipindahkan ke CS lain | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0032 |
| `messages.waiting_reminder` | teks `{"id": …, "en": …}` | Pesan pengingat saat tiket menunggu balasan nasabah | Hub Pengaturan → Pesan otomatis (ID/EN, hanya variabel yang ada) | 0136 |
| `nasabah.csadmin_client_id` | `""` | Client id integrasi csAdmin, harus sama dengan `client_id` di blok `integration` config CS Admin service | Hub Pengaturan → Integrasi API Nasabah | 0050 |
| `nasabah.csadmin_connected` | `{}` | Waktu integrasi API Nasabah terakhir disimpan setelah tes koneksi berhasil. Kosong berarti belum aktif | Diisi sistem saat simpan integrasi berhasil | 0055 |
| `nasabah.csadmin_url` | `""` | Alamat csAdmin untuk menu Akun Nasabah, termasuk prefix path (mis. alamat LAN server csAdmin) | Hub Pengaturan → Integrasi API Nasabah (lewat nasabah-gateway, disimpan hanya bila tes koneksi berhasil) | 0050 |
| `notifications.watchlist_digest_time` | `"17:05"` | Jam kirim ringkasan saham pantauan harian (WIB, HH:MM); maksimal sekali per hari | Hub Pengaturan → Push notification (HH:MM WIB) | 0147 |
| `priority.rules` | `[{"words": ["dibobol", "diretas", "dihac …` | Kata kunci di pesan pertama yang menaikkan prioritas (dan menambah flag) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027 |
| `resolve.outcomes` | `answered`, `follow_up`, `complaint`, `other` (label ID/EN) | Hasil yang wajib dipilih CS saat menyelesaikan tiket (dulu `close.outcomes`) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027, 0032 |
| `retention.chat_years` | `10` | Lama penyimpanan riwayat chat CS (tahun). Usulan default, wajib dikonfirmasi kepatuhan | Hub Kepatuhan → Tenggat & retensi (5–30 tahun); RPC `compliance_confirm_policy` | 0027 |
| `security.login_lock_minutes` | `15` | Lama akun staf dikunci setelah terlalu banyak password salah, sekaligus jendela hitungan gagal (menit) | Hub Pengaturan → Sistem → Keamanan login (1–1.440) | 0186 |
| `security.login_max_failures` | `5` | Jumlah password salah berturut-turut sebelum akun staf dikunci sementara | Hub Pengaturan → Sistem → Keamanan login (3–20) | 0186 |
| `security.mfa_required_roles` | `["cs_super_admin"]` | Peran staf yang wajib memasukkan kode 2FA (TOTP) saat masuk Hub; Super Admin selalu wajib | Hub Pengaturan → Sistem → Keamanan login (Super Admin selalu wajib) | 0186 |
| `service.hours` | `{"1": ["08:00", "22:00"], "2": ["08:00", …` | Jam layanan CS per hari ISO (1 = Senin) dalam WIB. Hari tanpa entri = tutup. Libur nasional dan cuti bersama tutup | Hub Pengaturan → Jam layanan & libur (hari 1–7, HH:MM WIB) | 0027 |
| `survey.config` | `{"question": {"id": "Bagaimana layanan C …` | Pertanyaan survei kepuasan, skala (3 atau 5), batas nilai rendah, dan pilihan alasan nilai rendah | Hub Pengaturan → Survei kepuasan; RPC `admin_set_survey_config` (audit `survey.config`) | 0135 |
| `ticket.auto_close_days` | `3` | Tiket selesai yang belum dinilai nasabah ditutup otomatis setelah sekian hari (1–30). Tiket yang sudah dinilai langsung ditutup | Hub Pengaturan → Penugasan, tiket & alert (1–30 hari) | 0056 |
| `ticket.auto_release_offline_minutes` | `0` | Lepas tiket ke antrean bila pemilik offline lebih dari sekian menit. 0 = mati (default) | Hub Pengaturan → Penugasan, tiket & alert (0–1.440 menit, 0 = mati) | 0032 |
| `ticket.default_topic` | `"other"` | Topik tiket baru yang dibuat dari pesan nasabah tanpa memilih topik (dulu `session.default_topic`) | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0027, 0032 |
| `ticket.owner_away_minutes` | `10` | Saat tiket dibuka kembali, tiket kembali ke CS pemilik kecuali pemilik offline lebih dari sekian menit | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0032 |
| `ticket.reminder_hours` | `24` | Kirim pengingat ke nasabah bila tiket menunggu balasan nasabah lebih dari N jam (0 = mati), sebelum tutup otomatis | Hub Pengaturan → Penugasan, tiket & alert (0–72 jam, 0 = mati) | 0136 |
| `topics.picker` | `{}` | Judul dan petunjuk halaman pilih topik chat CS (ID/EN); kosong = teks bawaan aplikasi | Hub Pusat Bantuan → Topik chat CS (teks halaman pilih topik); RPC `admin_set_topic_picker` | 0127 |
| `transfer.expire_minutes` | `10` | Batas waktu CS tujuan menerima transfer tiket | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0032 |
| `ui.idle_logout_minutes` | `30` | Web CS keluar otomatis setelah idle sekian menit | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0032 |
| `ui.wait_late_minutes` | `15` | Lama menunggu berwarna merah mulai sekian menit | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0032 |
| `ui.wait_warn_minutes` | `5` | Lama menunggu berwarna kuning mulai sekian menit | Migrasi/SQL operasional saja (tidak ada RPC Hub) | 0032 |

Catatan:

- `complaint.days`, `complaint.extension_days`, dan `retention.chat_years` adalah usulan default yang wajib dikonfirmasi Kepatuhan (`docs/cs-chat/compliance-questions.md`, checklist produksi bagian 8). Rentang di Hub dibatasi `cs.policy_rules()` (`0042`).
- `nasabah.csadmin_url` dan `nasabah.csadmin_client_id` diisi dari Hub saja; deskripsi di migrasi `0050` masih menyebut cadangan `CSADMIN_URL`/`CSADMIN_CLIENT_ID` di `docker/.env`, sedangkan `services/nasabah-gateway/README.md` menyatakan alamat tidak diatur lewat env (perbedaan dokumen dan kode, perlu konfirmasi).
- `ui.idle_logout_minutes`, `agent.history_hours`, `transfer.expire_minutes`, dan `brand.support_name` tidak bisa diubah dari Hub (tidak termasuk `cs.admin_editable`).

### 9.3 Rate limit per aksi (`private.rate_limits`)

Setiap aksi bisa punya beberapa jendela; semua jendela harus lolos. Batas dikali `rate_limit.new_account_factor` (0,5) selama masa akun baru dan `rate_limit.trusted_factor` (2) untuk `trust_level` ≥ 2 (`0012`, `0187`). Pelanggaran dijawab `429 rate_limited` dengan header `Retry-After`.

| Aksi | Jendela | Maks | Migrasi |
|---|---|---|---|
| `post` | 60 dtk | 5 | 0002 |
| `post` | 24 jam | 50 | 0012 |
| `comment` | 60 dtk | 20 | 0002 |
| `message` | 60 dtk | 30 | 0002 |
| `reaction` | 60 dtk | 60 | 0002, 0012 (dari 120) |
| `follow` | 1 jam | 30 | 0012 (jendela 60 dtk dihapus) |
| `report` | 1 jam | 10 | 0002 |
| `room_create` | 1 jam | 10 | 0012 |
| `stock_room_create` | 1 jam | 20 | 0037 |
| `upload` | 24 jam | 50 | 0012 |
| `data_export` | 24 jam | 3 | 0012 |
| `poll_vote` | 60 dtk / 24 jam | 30 / 500 | 0019 |
| `cs_ticket` | 1 jam | 5 | 0027, 0032 (dulu `cs_session`) |
| `cs_message` | 60 dtk | 30 | 0027 |
| `appeal` | 24 jam | 10 | 0071 |
| `search` | 60 dtk / 1 jam | 30 / 600 | 0073 |
| `content_edit` | 60 dtk | 20 | 0075 |
| `bookmark` | 60 dtk | 120 | 0075 |
| `message_reaction` | 60 dtk | 60 | 0075 |
| `notification_prefs` | 60 dtk | 30 | 0076 |
| `analytics` | 60 dtk / 24 jam | 30 / 2.000 | 0078 |
| `notification_event` | 60 dtk | 120 | 0088 |
| `post_draft` | 60 dtk | 60 | 0090 |
| `room_mod_action` | 1 jam / 24 jam | 15 / 50 | 0093 |
| `banner_event` | 60 dtk | 120 | 0119 |
| `faq_search` | 60 dtk | 30 | 0129 |
| `faq_feedback` | 1 jam | 20 | 0129 |
| `guest_message` | 60 dtk | 20 | 0140 |

Contoh dampak faktor akun baru: `message` menjadi 15 per menit selama masa akun baru (laporan uji 4.2). Batas lain di luar tabel ini: exchange auth-bridge (8.1), edge Traefik (8.8), API key integrasi (8.8), `integration.bot_posts_per_hour` (9.1), dan batas tiket aktif per CS (1–20, diatur per akun di Akun CS). Perlu konfirmasi: apakah tabel ini memuat batas tambahan yang dibuat di luar migrasi (perubahan SQL operasional di server).

### 9.4 Variabel `docker/.env`

Sumber: `docker/.env.example`, default di `docker/compose*.yml`, dan `docs/panduan/produksi.md`. Nilai rahasia tidak pernah diletakkan di file ini. Variabel yang dikomentari di contoh memakai default compose.

| Variabel | Default | Arti |
|---|---|---|
| `PROXY_DOMAIN` | kosong (wajib di single/cluster) | Domain API publik; A record harus mengarah ke server |
| `ACME_EMAIL` | kosong (wajib di single/cluster) | Email akun Let's Encrypt |
| `ACME_CA_SERVER` | Let's Encrypt produksi | Diganti ke staging saat uji sertifikat |
| `SUPABASE_PUBLIC_URL` / `API_EXTERNAL_URL` | `http://localhost:8000` / `…/auth/v1` | Single: `https://<PROXY_DOMAIN>`; dipakai juga untuk URL foto akun resmi |
| `SITE_URL`, `ADDITIONAL_REDIRECT_URLS` | `http://localhost:3000`, kosong | URL GoTrue |
| `CORS_ALLOWED_ORIGINS` | dev `*`, single kosong | Origin web yang boleh memanggil API (aplikasi native tidak butuh) |
| `EDGE_HTTP_BIND` / `EDGE_HTTP_PORT` | `127.0.0.1` / `8000` | Port HTTP dev |
| `ADMIN_PORT` | `8000` | Entrypoint admin di `127.0.0.1` server (Studio, SSH tunnel) |
| `EDGE_SUBNET` | `10.250.250.0/24` | Subnet `edge`; Kong hanya mempercayai `X-Forwarded-For` dari sini |
| `EDGE_RATE_AVERAGE` / `EDGE_RATE_BURST` | `600` / `1200` | Request per detik per IP di Traefik |
| `EDGE_WS_PER_IP` | `1500` | WebSocket bersamaan per IP; produksi minimal 1.000 (`check-config`) |
| `EDGE_BODY_MAX_API` / `EDGE_BODY_MAX_UPLOAD` / `EDGE_BODY_MAX_INTEGRATION` | `262144` / `27262976` / `2097152` | Batas body (byte) |
| `TLS_SNI_STRICT` | `true` | Tolak TLS tanpa SNI yang cocok |
| `CS_CONSOLE_DOMAIN` | kosong (wajib bila `CS=1`) | Domain Hub + API staf |
| `VPN_SOURCE_RANGES` | kosong (wajib bila `CS=1`) | Rentang IP (LAN kantor/VPN, dipisah koma) yang boleh membuka domain CS |
| `CS_CONSOLE_PORT` | `8085` | Port Hub di dev |
| `HUB_DIR` | `../../rendezvous_hub` | Checkout repo Hub untuk build image `cs-console` |
| `POSTGRES_HOST` / `POSTGRES_DB` / `POSTGRES_PORT` | `db` / `postgres` / `5432` | Koneksi database |
| `PGBOUNCER_POOL_MODE` | `session` | Mode PgBouncer |
| `PGBOUNCER_MAX_CLIENT_CONN` | `500` | Koneksi klien maks |
| `PGBOUNCER_DEFAULT_POOL_SIZE` | `24` | Harus ≥ `REST_REPLICAS × (PGRST_DB_POOL + 1)` |
| `PGBOUNCER_MAX_DB_CONNECTIONS` | `80` | Koneksi server maks |
| `PGBOUNCER_SERVER_LOGIN_RETRY` | `0.25` | Detik sebelum mencoba ulang login Postgres yang gagal |
| `PGBOUNCER_DB_WATCH_SECONDS` | `2` | Interval cek IP host database (0 = mati) |
| `PGRST_DB_SCHEMAS` | `public,graphql_public,cs_api` | Skema yang diekspos PostgREST |
| `PGRST_DB_POOL` | `10` | Pool koneksi per replika PostgREST |
| `PGRST_DB_MAX_ROWS` | `1000` | Baris maks per respons |
| `PGRST_DB_EXTRA_SEARCH_PATH` | `public,extensions` | Search path tambahan |
| `PGRST_DB_POOL_ACQUISITION_TIMEOUT` | `2` | Detik menunggu koneksi pool sebelum `504 PGRST003` |
| `PGRST_GHCRTS` | `-N1` | Thread runtime PostgREST, harus sama dengan batas CPU `rest` |
| `JWT_EXPIRY` | `3600` | Umur JWT GoTrue (staf), detik |
| `FUNCTIONS_VERIFY_JWT` | `true` | Edge Functions memverifikasi JWT |
| `STORAGE_BACKEND` | `file` | `file` (single) atau `s3` (`GLOBAL_S3_*`, cluster) |
| `IMGPROXY_AUTO_WEBP` | `true` | Konversi WebP otomatis imgproxy |
| `REALTIME_MAX_CONCURRENT_USERS` | `10000` | Batas tenant Realtime |
| `REALTIME_MAX_EVENTS_PER_SECOND` | `20000` | Batas event/dtk tenant (fan-out ±630 penerima aktif per room) |
| `REALTIME_MAX_CHANNELS_PER_CLIENT` | `100` | Kanal per klien |
| `REALTIME_MAX_JOINS_PER_SECOND` | `500` | Join per detik |
| `REALTIME_MAX_BYTES_PER_SECOND` | `1000000` | Tidak ditegakkan Realtime v2.143–v2.148 |
| `AUTH_BRIDGE_OLT_MODE` | `jwt` (dev tanpa dummy: `mock`) | Mode verifikasi token sosial |
| `OLT_JWT_ISSUER` / `OLT_JWT_AUDIENCE` | `olt` / `olt-social` | Nilai `iss`/`aud` yang diterima |
| `OLT_JWT_MAX_TTL` | `900` | Umur token sosial maks (detik) |
| `AUTH_BRIDGE_JWT_TTL` | `900` | Umur sesi sosial (detik) |
| `AUTH_BRIDGE_CACHE_TTL` | `60` | Cache verifikasi per hash token (detik) |
| `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` | `1500` | Exchange per IP per menit; produksi minimal 1.000 (`check-config`) |
| `AUTH_BRIDGE_RATE_LIMIT_PER_USER_PER_MINUTE` | `10` (dev `60`) | Exchange per user OLT per menit |
| `AUTH_BRIDGE_BREAKER_FAILURE_THRESHOLD` / `AUTH_BRIDGE_BREAKER_COOLDOWN` | `5` / `30` | Circuit breaker (hanya bermakna di mode `websocket`) |
| `AUTH_BRIDGE_LOG_LEVEL` | `info` (dev `debug`) | Level log |
| `REST_REPLICAS`, `AUTH_BRIDGE_REPLICAS`, `MEDIA_REPLICAS`, `CLASSIFIER_REPLICAS`, `IMGPROXY_REPLICAS`, `INTEGRATION_REPLICAS` | `2` masing-masing | Replika layanan sibuk (dev/single) |
| `DB_MEMORY` | `2G` | Batas memori database (naikkan bersama RAM server) |
| `KONG_MEMORY` / `KONG_WORKER_PROCESSES` | `1G` / `2` | Kong |
| `REALTIME_MEMORY` | `1G` | Realtime |
| `VALKEY_MAXMEMORY` | `192mb` | Valkey |
| `BACKUP_MEMORY` | `1G` | Layanan backup |
| `CLAMAV_MEMORY` | `2G` | clamd memuat signature ±1,1 GB |
| `CLAMAV_FRESHCLAM_CHECKS` | `4` | Cek signature per hari |
| `BACKUP_LOCAL_REPO_DIR` | `../backups/restic` (relatif `docker/`) | Folder repositori restic bila tujuan "Folder lokal di server"; produksi di disk terpisah, milik uid 10001 |
| `HEALER_ENABLED` | `true` | `false` = hanya mencatat |
| `HEALER_DOCKER_GID` | `0` | GID grup pemilik `docker.sock` (Linux: grup `docker`) |
| `HEALER_INTERVAL_SECONDS` / `HEALER_UNHEALTHY_SECONDS` / `HEALER_MIN_UPTIME_SECONDS` | `10` / `60` / `120` | Jadwal dan ambang restart |
| `HEALER_MAX_RESTARTS_PER_HOUR` / `HEALER_GLOBAL_COOLDOWN_SECONDS` / `HEALER_SYSTEMIC_FRACTION` | `3` / `30` / `0.5` | Pengaman restart |
| `HEALER_NODES_FILE` / `HEALER_NODES_SECONDS` | `/var/lib/olt-healer/nodes.json` / `10` | Daftar container untuk Peta layanan (kosong = mati) |
| `CSADMIN_TIMEOUT` | `15s` | Timeout nasabah-gateway ke csAdmin |
| `DASHBOARD_USERNAME`, `STUDIO_DEFAULT_ORGANIZATION`, `STUDIO_DEFAULT_PROJECT` | `supabase`, `Rendezvous`, `OLT Social` | Studio (password di Docker secret) |
| `TRADE_RELAY_*` | lihat contoh | Relay Berbagi Trade (dijeda) |
| `DUMMY_OLT_*`, `DUMMY_IPROXY_*` | lihat contoh | Khusus dev (OLT dummy); `DUMMY_OLT_SECRET` adalah nilai dev, bukan rahasia produksi, dan tidak dikutip di sini |

`check-config` (`make up`) menolak `.env` yang hilang, secret yang kosong, nilai `CHANGE_ME`, `PROXY_DOMAIN`/`ACME_EMAIL` kosong di profil non-dev, serta `AUTH_BRIDGE_RATE_LIMIT_PER_MINUTE` atau `EDGE_WS_PER_IP` < 1.000 di profil single/cluster (`Makefile`). `OLT_JWT_LEEWAY` (30 dtk) adalah default auth-bridge dan tidak diteruskan dari `.env` oleh compose.

### 9.5 Kredensial dan pengaturan operasional di Hub

Semua dikelola Super Admin (kecuali disebut), tidak ada nilainya di `docker/.env`, dan setiap perubahan tercatat di Jejak Audit tanpa isi rahasia (`docs/panduan/hub-untuk-staf.md` 3.4).

| Kredensial/pengaturan | Menu Hub | Disimpan di | Aksi audit | Sumber |
|---|---|---|---|---|
| Kunci service account Firebase (FCM) | Pengaturan → Integrasi → Push notification | Vault (`push.firebase_service_account`) + `private.push_credentials`; notifier memuat dan memeriksa ke Google tanpa restart; tidak bisa diunduh lagi | `push.credentials_set`, `push.credentials_removed`, `push.test` | `0058`, `0059` |
| Tujuan backup S3 (endpoint, bucket, prefix, region, access key ID) atau folder lokal; secret access key; password enkripsi (≥ 16 karakter); jadwal & retensi | Pengaturan → Sistem → Backup | `private.backup_config` (non-rahasia) + Vault (`secret_id`, `password_secret_id`); dibaca layanan backup lewat RPC `backup_config` (`service_role`); password tidak bisa ditampilkan atau diganti untuk repositori yang sama | `backup.target_set`, `backup.schedule_set`, `backup.requested` | `0065`, `0112` |
| Kanal alert: label, alamat web CS, Telegram (token bot, chat ID), email (SMTP host, port, keamanan, username, password, pengirim, penerima) | Pengaturan → Sistem → Alert | `private.alert_channels` + Vault (`telegram_secret_id`, `smtp_secret_id`) | `alerts.options_set`, `alerts.telegram_set`, `alerts.email_set`, `alerts.test_sent` | `0064` |
| Alamat dan client id csAdmin (menu Akun Nasabah) | Pengaturan → Integrasi API Nasabah | `cs.cs_settings` `nasabah.csadmin_url`, `nasabah.csadmin_client_id`, `nasabah.csadmin_connected`; kunci tanda tangan Ed25519 tetap Docker secret `csadmin_signing_key` (tidak dari Hub) | `setting.nasabah_integration`, `setting.nasabah_integration_cleared` | `0050`, `0055` |
| API key integrasi OLT (nama, scope `notify`/`notify_broadcast`/`bot_post`, CIDR maks 20, batas per menit bawaan 3.000, akun resmi untuk bot) | Pengaturan → Integrasi → API Notifikasi | `private.integration_keys` (hanya prefix + SHA-256 key; key ditampilkan sekali) | `integration.key_create`, `integration.key_update`, `integration.key_revoke` | `0068`, `0086`, `0101` |
| Kill switch fitur sosial (wajib alasan), feature flag (persentase, user, platform, versi aplikasi minimum), versi minimum aplikasi per platform | Komunitas → Fitur & versi (Super Admin atau peran Fitur & Banner) | `private.kill_switch`, `private.feature_flags`, `private.client_versions` | `kill_switch.set`, `feature_flag.set`, `feature_flag.delete`, `client.min_version_set` | `0077`, `0085`, `0121` |
| Skema deep link banner, batas rekening per nasabah | Pengaturan → Integrasi → Integrasi aplikasi | `cs.cs_settings` (`banners.deep_link_schemes`, `accounts.max_per_customer`) | `banner.link_schemes`, `setting.update` | `0119`, `0124`, `0128` |
| Keamanan login staf (peran wajib 2FA, batas password salah, lama kunci) | Pengaturan → Sistem → Keamanan login | `cs.cs_settings` `security.*` | `setting.update`; peristiwa `security.login_locked`, `security.login_unlocked`, `security.mfa_reset` | `0186` |
| Lampiran chat CS (format, ukuran, durasi) | Pengaturan → Lampiran chat CS | `cs.cs_settings` `attachments.cs` | `attachments.policy` | `0131`, `0138` |

Di luar Hub (sengaja): JWKS OLT (`docker/secrets/olt_jwks`, siapa pun yang bisa menggantinya bisa membuat token atas nama nasabah), `jwt_secret` dan kunci turunannya, password database, dan rahasia infrastruktur lain (8.6). Relay Berbagi Trade (alamat iProxy, kunci AES di Vault) dijeda dan di luar lingkup rilis ini.

## 10. Verifikasi dan kriteria penerimaan

### 10.1 Strategi uji

Pengujian berlapis: logika bisnis di database diuji pgTAP, layanan Go diuji unit di container, Hub dan library diuji di repo masing-masing, lalu seluruh stack diuji smoke, E2E, beban, keamanan, dan chaos. Semua alat beban, keamanan, dan chaos hanya menyasar stack dev dengan OLT dummy; skrip menolak berjalan bila `PROFILE` bukan `dev`, auth-bridge bukan `APP_ENV=development` + mode `jwt`, atau `dummy-olt` tidak berjalan (`docs/testing/README.md`).

| Lapisan | Alat dan perintah | Cakupan | Bukti lulus |
|---|---|---|---|
| Database | pgTAP, `make test-db` (`supabase/tests`, 165 file, ±4.300 asersi) | RLS, hak akses, RPC, trigger, job, kontrak Hub ↔ aplikasi | Semua file `PASS`. Untuk perubahan skema, praktik tim menjalankan migrasi + `test-db` di database sekali pakai (basebackup ke Postgres terpisah tanpa jaringan) agar DB dev tidak ikut termigrasi |
| Migrasi | `make migrate` (`scripts/migrate.sh`) | Checksum SHA-256 per file di `olt_internal.schema_migrations`; file yang berubah ditolak | `migrate` Exited 0 dan tidak berjalan ulang setelah restart DB |
| Layanan Go | `make test` (= `test-db` + `test-bridge`, `test-dummy-olt`, `test-nasabah-gateway`, `test-notifier`, `test-janitor`, `test-media`, `test-sentinel`, `test-healer`, `test-backup`, `test-integration`, `test-link-preview`, `test-classifier`, `check-go-comments`) | Unit test per layanan di container Go; CI juga `gofmt`, `go vet`, `go test -race`, Trivy | Semua paket ok |
| Smoke stack | `make smoke` (lewat Kong, butuh seed + mode mock), `make smoke-dummy` (auth-bridge mode `jwt` dengan token OLT dummy + upload media), `make smoke-cs` (chat CS end-to-end lewat API nyata) | Alur utama melewati Kong | `smoke-dummy` 26/26 (laporan uji 12.9) |
| Rebutan CS | `make cs-race` | 50 CS × 1 tiket dan 200 tiket × 30 CS, langsung ke DB dan lewat 3 replika PostgREST khusus tes (`PGRST_DB_POOL=3`) | Tepat 1 pemenang per tiket, tidak ada CS > 5 tiket aktif |
| Hub | `make test-cs-console` (= `npm run ci` di container Node: lint, lint token, format, typecheck, unit ±890 tes, build, ukuran bundle ≤ 300 KB gzip, lisensi) | Komponen, hook, i18n, kontrak tipe | Semua langkah lulus |
| Hub E2E | `make e2e-cs-console` (Playwright vs stack dev, butuh `up DUMMY_OLT=1`, Node 24 + Chromium) | Login + 2FA, dua akun di dua tab, rebutan klaim, chat + lampiran + tanda dibaca, lepas/transfer/selesai, non-pemilik hanya-baca, putus-sambung tanpa duplikat, supervisor memantau dan memindahkan tiket, Kepatuhan, tema terang/gelap + WCAG AA, tata letak 3 resolusi, kinerja 1.000 tiket + 5.000 pesan | Semua tes lulus; jumlah tes lihat catatan di bawah |
| Library | `make test-flutter` (`flutter analyze` + `flutter test`, ±1.450 tes), `make test-flutter-it` / `test-flutter-it-dummy` (integrasi terhadap stack lokal), `make e2e-windows` / `e2e-windows-dummy` (E2E app example), `make perf-flutter` (scroll tanpa backend), `make license-audit` | Bloc, repository, widget, integrasi backend | Semua lulus; `license-audit` tanpa GPL/AGPL |
| Beban | `make load-test P=smoke\|step\|spike\|light` (k6 `tests/load/market-open.js`, `LOAD_STEPS`, `TYPING=1`, `LIST_VUS=n`, `LOAD_VIA=traefik`), `make load-integration` | Bel pembukaan, room saham ramai, typing/presence, daftar chat, API integrasi | Target 7.1 dan 7.2; `step` berhenti otomatis bila error > 1% atau p95 Realtime melonjak |
| Keamanan | `make test-security` (`authz-probe` ±1.077 probe, `realtime-authz`, `static-config`, `prod-routing`), `make scan-deps` (`STRICT=1`), `make test-zap` (opsional), `make secrets-scan` | Otorisasi, edge produksi, TLS, header, dependensi, rahasia di git | 0 temuan |
| Chaos | `make chaos-test [E="realtime valkey"]` (9 eksperimen di bawah 30 VU: classifier, realtime, pgbouncer, valkey, storage, notifier, rest, db, partition) | Pulih otomatis, fail open/closed sesuai desain, tidak ada pesan 200 yang hilang | Semua eksperimen pulih tanpa tindakan manual |
| Pembersihan | `make loadtest-cleanup [DRY=1]` | Hapus data `lt_*`; audit, bukti, dan log tidak disentuh | Sisa profil `lt_*` 0; lalu `smoke-dummy` dan `test-db` lulus |

Target Makefile lain yang dipakai operasional dan verifikasi: `help`, `check-config`, `check-hub`, `up`, `down`, `logs`, `ps`, `reset`, `seed`, `backup`, `restore`, `backup-snapshots`, `restore-pitr`, `gen-secrets`, `gen-keys`, `anon-key`, `admin-up`, `admin-down`, `psql`, `web-example`, `dummy-token`, `cs-bootstrap-admin`, `cs-mfa-reset`, `cs-staff`, `cs-console-react`, `cs-demo`, `testkit`. Windows memakai `make.ps1` dengan nama target yang sama.

CI otomatis: `chat_service_supabase/.github/workflows/backend.yml` (Go per layanan, pgTAP + `smoke-dummy` terhadap stack dev, gitleaks), `rendezvous_hub/.github/workflows/ci.yml` (`npm run ci`, image + Trivy, gitleaks, E2E opsional lewat `workflow_dispatch`), `rendezvous_community/.github/workflows/ci.yml` (komentar, logging, format, analyze, test, lisensi).

Catatan: `docs/cs-chat/README.md` menyebut 22 tes E2E Hub, sedangkan `rendezvous_hub/e2e/*.spec.ts` saat ini berisi 28 deklarasi `test(...)` di 16 file, sebagian di dalam perulangan tema (jumlah eksekusi lebih banyak); angka resmi perlu konfirmasi. Angka tes Hub dan library adalah hitungan statis deklarasi, bukan hasil eksekusi.

### 10.2 Kriteria penerimaan per modul

Sebuah modul diterima bila semua kriteria berikut lulus di staging pada commit yang akan dirilis (server, Hub, dan tag library). Kode error ditulis `<HTTP> <code>`.

| Modul | Kriteria penerimaan (teruji) | Diverifikasi oleh |
|---|---|---|
| AKUN | 1) Token sosial sah ditukar menjadi sesi 15 menit; token diubah, kedaluwarsa, audience lain, atau `kid` tak dikenal ditolak `401 invalid_token`; akun ditangguhkan ditolak. 2) Profil dibuat saat exchange pertama dengan UUID stabil dari `sub`; `olt_user_id` dan email tidak terbaca pengguna lain. 3) Hapus akun lalu login ulang dalam 72 jam ditolak `403 account_rejoin_cooldown`; blokir yang dibuat orang lain tetap berlaku. 4) Kill switch aktif: tulis konten dan chat non-CS `403 social_disabled`, chat CS tetap jalan; versi aplikasi di bawah minimum mendapat `update_required: true`. 5) Persetujuan dokumen hukum wajib sebelum menulis bila ada dokumen terbit. 6) Ekspor data dan privasi (blokir, mute) bekerja | `make smoke-dummy`, `make test-bridge`; tes `002_profiles_social_test.sql`, `013_privacy_test.sql`, `043_legal_documents_test.sql`, `057_client_config_test.sql`, `064_client_gaps_test.sql`, `089_kill_switch_status_test.sql`, `151_delete_account_keeps_others_blocks_test.sql`, `152_account_rejoin_cooldown_test.sql`, `154_deleted_profile_requests_test.sql` |
| KOM | 1) Postingan, komentar (thread, urutan), suka, polling, `$KODE`, hashtag, bookmark berjalan dengan RLS. 2) Edit postingan/komentar hanya dalam `content.edit_minutes` (15 menit), setelahnya `403 edit_window_expired`. 3) Kontrol komentar: postingan dengan komentar mati menolak komentar `403 comments_off`, termasuk pemilik. 4) Pengaturan mention dan mention grup ditegakkan. 5) Feed (Terbaru, Mengikuti, saham, indeks, tab filter), pencarian (min 2 karakter), trending, daftar pengikut sesuai data. 6) Pratinjau link aman dan gambar pratinjau lolos NSFW | tes `003_posts_test.sql`, `004_comments_test.sql`, `005_reactions_test.sql`, `006_feed_test.sql`, `015_polls_test.sql`, `053_search_test.sql`, `054_trending_test.sql`, `055_post_extras_test.sql`, `060_link_previews_test.sql`, `069_post_drafts_stock_cards_test.sql`, `121_comment_thread_sort_test.sql`, `122_stream_discovery_test.sql`, `127_follow_lists_test.sql`, `128_feed_filters_test.sql`, `129_market_instruments_test.sql`, `131_idx_index_list_test.sql`, `146_comment_controls_test.sql`, `147_comment_controls_account_off_test.sql`, `149_mention_policy_test.sql`; `flutter test` |
| CHAT | 1) DM ke non-mutual lewat permintaan pesan; pesan ke-4 sebelum diterima ditolak `403 dm_request_limit`. 2) Grup owner/admin/member, hanya-admin, info grup, mention grup hanya anggota. 3) Pesan baru sampai lewat Broadcast privat; event palsu dari anggota tidak sampai; isi celah lewat indeks id. 4) Edit/hapus pesan, riwayat edit, hapus chat/grup, keluar room dengan event. 5) Typing/presence dibatasi di room besar; pratinjau room tanpa kunci baris. 6) Target kinerja NFR-PERF-04 sampai -08 | tes `007_chat_test.sql`, `016_chat_receipts_test.sql`, `017_chat_unread_badge_test.sql`, `024_chat_room_paging_test.sql`, `050_dm_requests_test.sql`, `078_realtime_broadcast_delivery_test.sql`, `082_room_preview_without_hot_lock_test.sql`, `083_message_gap_index_test.sql`, `086_room_typing_presence_cap_test.sql`, `087_stock_room_previews_test.sql`, `102_message_receipts_test.sql`, `125_group_admin_test.sql`, `132_chat_hide_edit_delete_test.sql`, `134_message_edit_history_audit_test.sql`, `135_leave_room_removal_event_test.sql`, `150_group_mentions_test.sql`, `156_deleted_message_preview_test.sql`; `make test-security` (`realtime-authz` 15/15); `make load-test` |
| CS | 1) Klaim tiket yang sudah diambil ditolak `409 ticket_taken`; batas tiket aktif `409 ticket_limit`; rebutan menghasilkan tepat satu pemilik. 2) Rating menutup tiket; tiket selesai tanpa rating tutup otomatis setelah `ticket.auto_close_days` (3); tiket tertutup tidak bisa dibalas `409 ticket_closed`. 3) Penugasan otomatis hanya ke CS Online dengan heartbeat segar. 4) Lampiran CS sesuai kebijakan (gambar, PDF/Office, video + ClamAV). 5) Pengaduan tamu tanpa OTP: sesi 24 jam, dimatikan → `403 guest_disabled`, sesi habis `401 guest_session_expired`. 6) Catatan internal, label, quick reply, survei, status gangguan, laporan, dan transkrip sesuai peran | tes `019_cs_tickets_test.sql`, `020_cs_security_test.sql`, `021_cs_masking_test.sql`, `022_cs_room_members_test.sql`, `026_cs_supervisor_monitor_test.sql`, `028_cs_auto_assign_immediate_test.sql`, `031_cs_auto_assign_reachable_test.sql`, `034_cs_release_requeue_test.sql`, `037_cs_chat_media_test.sql`, `038_cs_ticket_close_test.sql`, `097_agent_quick_replies_test.sql`, `098_ticket_labels_test.sql`, `111_cs_attachment_formats_test.sql`, `113_cs_flag_reason_notices_test.sql`, `114_topic_intake_replies_sop_test.sql`, `115_service_incidents_survey_test.sql`, `120_guest_support_test.sql`, `136_cs_closed_ticket_unread_test.sql`; `make cs-race`, `make smoke-cs`; E2E `claim-race`, `chat`, `ticket-actions`, `read-only`, `reconnect`, `auto-assign`, `offline-guard`, `perf` |
| BANTU | 1) Artikel FAQ dua bahasa dengan draf/terbit/arsip dan riwayat versi; kategori nonaktif tidak tampil. 2) Gambar artikel hanya dari unggahan sendiri. 3) Lampiran artikel maks 10 (PDF 10 MB, gambar 5 MB, video 25 MB): lebih → `400 too_many_attachments`, terlalu besar → `400 attachment_too_large`, duplikat → `400 duplicate_attachment`. 4) Pencarian, "Apakah ini membantu?", statistik, dan saran artikel per topik bekerja. 5) Topik chat CS (ikon, urutan, hapus, pertanyaan awal, saran balasan, SOP) dikelola peran `cs_content` | tes `107_topic_presentation_test.sql`, `109_help_center_test.sql`, `110_faq_images_test.sql`, `116_help_reports_agent_faq_reminders_test.sql`, `117_topic_reorder_test.sql`, `119_topic_delete_test.sql`, `106_content_role_test.sql`, `166_faq_attachments_test.sql` |
| NOTIF | 1) Notifikasi masuk kotak + badge, digabung (`notifications.aggregate_minutes` 60), mengikuti preferensi dan jam tenang. 2) Push diklaim dengan lease, at-least-once, tanpa klaim ganda; kunci Firebase dari Hub tersimpan di Vault. 3) Ringkasan pantauan sekali sehari pada jam yang diatur. 4) Banner & Popup: frekuensi, statistik, riwayat per akun, rasio gambar, notifikasi info (`app_notices`) dengan empat mata opsional, batas teks | tes `040_push_notifications_test.sql`, `041_push_credentials_test.sql`, `056_notification_prefs_test.sql`, `065_notify_targets_test.sql`, `066_notification_types_test.sql`, `067_notification_stats_segments_test.sql`, `068_app_banners_test.sql`, `099_banner_popup_test.sql`, `126_watchlist_digest_time_test.sql`, `157_banner_notification_fixed_feed_tabs_test.sql` s.d. `163_banner_notice_read_link_test.sql`; `make chaos-test E=notifier`; `make test-notifier` |
| MOD | 1) Kata terlarang ternormalisasi (`mask`/`block`), tautan, kontak, promosi, duplikat ditegakkan. 2) Masa akun baru `safety.new_account_days` membatasi gambar, tautan, DM, dan rate limit; 0 = tanpa batasan. 3) Gambar NSFW diblokir/ditahan sesuai ambang. 4) Laporan, antrean moderasi, sanksi bertingkat, banding dalam 30 hari. 5) Deteksi manipulasi membuka alert; slow mode otomatis paling ketat sama dengan jam ramai (10 dtk). 6) Moderator room dibatasi `room_mods.*` | tes `008_moderation_test.sql`, `011_content_integrity_test.sql`, `012_moderation_admin_test.sql`, `036_cs_banned_words_test.sql`, `049_content_safety_test.sql`, `051_appeals_test.sql`, `052_market_integrity_test.sql`, `059_media_moderation_test.sql`, `062_moderation_status_rows_test.sql`, `073_room_moderators_test.sql`, `074_link_preview_nsfw_test.sql`, `090_auto_slow_mode_cap_test.sql`, `155_policy_patterns_consistent_test.sql`, `165_new_account_period_test.sql` |
| PATUH | 1) Register kasus, tinjauan, perpanjangan tenggat (maks satu kali), transkrip bersidik SHA-256, jejak audit. 2) Kebijakan konten berversi: draf, simulasi, persetujuan staf Kepatuhan lain, rollback. 3) Bukti karantina append-only (`409 evidence_immutable`), legal hold, akses tercatat. 4) Akses tiket biasa hanya-baca 12 jam, tercatat. 5) Dokumen hukum terbit dengan empat mata | tes `030_cs_compliance_test.sql`, `043_legal_documents_test.sql`, `072_policy_versions_test.sql`, `075_evidence_quarantine_test.sql`, `105_compliance_ticket_access_test.sql`; E2E `compliance.spec.ts` |
| HUB | 1) Login email + password ≥ 12; Super Admin tanpa kode 2FA ditolak `401 mfa_required`; akun dikunci setelah 5 kali password salah selama 15 menit. 2) Dua akun di dua tab tidak saling memutus sesi atau realtime. 3) Pengaturan di luar `cs.admin_editable` ditolak `403 setting_locked`; nilai tidak sah `400 invalid_setting`. 4) Peran dan izin membatasi menu dan RPC (`cs_agent`, `cs_super_admin`, `compliance`, `community`, `product`, `cs_content`). 5) Kontras WCAG AA terang/gelap, tata letak 3 resolusi, bundle awal ≤ 300 KB gzip | tes `023_cs_supervisor_admin_test.sql`, `027_cs_super_admin_test.sql`, `039_cs_community_test.sql`, `096_agent_self_service_test.sql`, `101_product_role_test.sql`, `106_content_role_test.sql`, `164_staff_login_security_test.sql`; `make test-cs-console`; E2E `auth`, `multi-tab`, `super-admin`, `a11y`, `layout`, `visual` |
| INT | 1) Kontrak token sosial (8.1) dan heartbeat auth-bridge tampil di Integrasi aplikasi; `kid` `dev-` memicu peringatan. 2) `/integration/v1`: key tanpa/salah ditolak, CIDR dan scope ditegakkan, key baru 3.000/menit, kiriman ulang dengan id sama tidak dobel, notifikasi per `cust_id` sampai ke pemilik rekening dari klaim `accounts` (maks `accounts.max_per_customer`). 3) Akun Nasabah: hanya rute `/online/*` yang diizinkan, izin per akun CS, Super Admin wajib `aal2`, aksi tulis tercatat. 4) Data saham tetap milik OLT (server hanya menyimpan kode sebagai label) | tes `032_cs_nasabah_access_test.sql`, `035_cs_nasabah_integration_test.sql`, `048_integration_test.sql`, `081_integration_rate_default_test.sql`, `094_app_integration_overview_test.sql`, `095_auth_bridge_expected_test.sql`, `108_account_limit_setting_test.sql`, `148_notify_olt_user_target_test.sql`; `make load-integration`, `make smoke-dummy`, `make test-integration`, `make test-nasabah-gateway` |
| OPS | 1) `make up PROFILE=single` sehat; `migrate` dan `volume-init` Exited 0. 2) Kesehatan sistem membuka dan menutup alert sesuai ambang; laporan sentinel yang hilang terdeteksi; Peta layanan terbarui. 3) Healer me-restart layanan unhealthy dengan batas dan menyerah dengan alert. 4) Backup penuh, kiriman WAL, dan uji restore berhasil; folder lokal berfungsi; rahasia Vault bisa dipulihkan. 5) Janitor membersihkan file akun terhapus. 6) Fungsi DB lolos pemindai `safeupdate`. 7) Semua eksperimen chaos pulih sendiri | tes `042_storage_cleanup_test.sql`, `045_system_health_test.sql`, `046_backups_test.sql`, `047_vault_secret_recovery_test.sql`, `084_health_metrics_test.sql`, `088_health_alert_latency_test.sql`, `091_trending_job_lock_test.sql`, `092_backup_local_destination_test.sql`, `093_healer_test.sql`, `112_media_scanner_health_test.sql`, `145_system_nodes_test.sql`, `153_functions_safeupdate_test.sql`; `make chaos-test`, `make test-sentinel`, `make test-healer`, `make test-backup`, `make test-janitor` |
| TRADE | Di luar lingkup rilis ini (DIJEDA, `SHOW_TRADE_SHARE=false`, `trade-relay` tidak dijalankan). Kriteria saat ini hanya: tes yang ada tetap lulus dan menu tidak tampil untuk staf tanpa izin | tes `137_trade_share_core_test.sql` s.d. `144_trade_share_hidden_prefs_test.sql`; E2E `trade-share.spec.ts` |

Kriteria lintas modul: `make test-security` 0 temuan; `make scan-deps STRICT=1` tanpa temuan penghalang untuk image kita; `make test-db` lulus penuh; target NFR bagian 7 terpenuhi di server produksi yang diukur dengan `make load-test P=step`.

### 10.3 Referensi checklist go-live

Pegangan rapat go-live ada di `docs/panduan/checklist-go-live.md` (butir dicentang setelah bukti dilihat bersama); rincian teknisnya di `docs/panduan/produksi.md` bagian 8.

| Kelompok | Penanggung jawab | Butir utama |
|---|---|---|
| A. Server & jaringan | Vendor IT | Ubuntu 24.04 dengan disk backup terpisah; A record API dan Hub; firewall 80/443 publik, 22 hanya IP admin; SSH key; jam tersinkron (NTP); konfirmasi ada/tidaknya proxy/load balancer/CDN di depan server (bila ada, atur proxy tepercaya dan `ipStrategy`) |
| B. Login OLT | Tim backend OLT | JWKS diserahkan (kunci privat hanya di OLT); token sosial dengan `iss`, `aud`, `sub` tetap dan `exp` ≤ 15 menit; login dengan token OLT asli berhasil dan Integrasi aplikasi berstatus Aktif tanpa peringatan kunci dev |
| C. Server sosial | Tim IT | `server-install.sh` selesai dan `make ps` sehat; HTTPS valid, `http://` dialihkan, `https://<domain>/` dan `/auth/v1/health` 404; OLT dummy dan Studio tidak berjalan; salinan `docker/.env`, `docker/secrets/`, `pgsodium_root.key` di luar server; restart otomatis aktif; `docker/.env` tidak menurunkan batas per IP < 1.000; `/bridge/v1/health` menunjukkan `olt_mode: jwt` |
| D. Hub & staf | Super Admin | Super Admin pertama dibuat (`make cs-bootstrap-admin`) dan password sementara diganti; Hub hanya dari IP kantor/VPN (403 dari luar); akun staf dengan password ≥ 12; 2FA Super Admin; kanal alert diisi dan **Kirim uji** diterima; pemantau uptime luar; backup ke disk terpisah atau S3 dengan backup penuh dan uji restore berhasil; kunci Firebase diunggah bila push dipakai |
| E. Aplikasi OLT | Tim aplikasi | Library di-pin ke tag rilis (minimal ≥ 1.5.0 sejak `0098`); URL HTTPS produksi dan anon key; build Android tanpa cleartext dan tanpa `service_role` key; uji manual Android dan Windows (login, feed, chat dua akun, chat CS, unggah gambar); versi minimum aplikasi diset per platform dan versi lama mendapat "Perbarui aplikasi" |
| F. Kepatuhan & legal | Kepatuhan | Dokumen hukum terbit dan jenis wajib setuju ditentukan; kata terlarang dan kebijakan konten ditinjau; kalender libur bursa tahun ini dan depan diverifikasi (`cs.holidays.verified`); retensi arsip regulator (`retention.archive_days`) ditetapkan; jam layanan, pesan otomatis, tenggat pengaduan, dan retensi chat CS disetujui; staf dilatih dengan Panduan Hub |
| G. Uji sebelum dibuka | Pengembang / manajemen | Uji beban di server setara produksi (hasil dicatat); pentest independen dengan temuan kritis/tinggi ditutup; review kode senior (auth-bridge, RLS, chat CS); `make test-db`, `make cs-race`, `make smoke-cs`, `make test-cs-console`, dan `make e2e-cs-console` lulus di staging dari commit yang dirilis; `make license-audit` lulus; `make e2e-windows` dan uji manual Android lulus |
| H. Hari-H | Semua | Rilis di luar jam bursa; `make backup` sebelum rilis; penanggung jawab kill switch siaga (**Komunitas → Fitur & versi**); kontak darurat dibagikan dan runbook gangguan dicetak |

Tambahan dari `docs/panduan/produksi.md` bagian 8 yang wajib dicek: Edge Function `cs-admin` di domain publik 404 dan RPC agen `cs_api` di domain publik 403; header keamanan Hub (CSP `connect-src` terbatas, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, tanpa cache `index.html`); halaman demo `scripts/cs-demo` tidak ter-deploy; partisi `cs.*_default` kosong dan job `cs-partitions` sukses; Halaman Kesehatan sistem tanpa masalah kritis dan semua sumber metrik (`rest`, `realtime`, `pgbouncer`) terbaca; secret `pgbouncer_stats_password` ada.

Perbedaan yang perlu diputuskan sebelum rapat go-live (perlu konfirmasi):

- Ukuran server: checklist go-live A menulis 4 vCPU / 8 GB / 100 GB SSD, sedangkan `docs/panduan/spesifikasi-server.md` menetapkan minimum 8 vCPU / 16 GB / 200 GB NVMe dan produksi awal 16 vCPU / 32 GB / 500 GB NVMe (NFR-KAP-08).
- Versi library: checklist go-live E menulis `rendezvous_community` v1.17.0, sedangkan rilis terbaru 1.49.2 dan fitur seperti lampiran artikel (`0188`) butuh ≥ 1.49.0.

## 11. Lampiran

### 11.1 Matriks keterlacakan

Rekap jumlah kebutuhan fungsional per modul dan modul BR yang dilacak. Pelacakan dilakukan di tingkat modul (`BR-<MODUL>`); pemetaan ke butir BR bernomor dilakukan bersama BRD.

| Modul | Subbagian | Rentang FR | Jumlah FR | Lacak |
|---|---|---|---|---|
| AKUN | 4.1 | FR-AKUN-01 … FR-AKUN-30 | 30 | BR-AKUN |
| KOM | 4.2 | FR-KOM-01 … FR-KOM-59 | 59 | BR-KOM |
| CHAT | 4.3 | FR-CHAT-01 … FR-CHAT-46 | 46 | BR-CHAT |
| CS | 4.4 | FR-CS-01 … FR-CS-70 | 70 | BR-CS |
| BANTU | 4.5 | FR-BANTU-01 … FR-BANTU-25 | 25 | BR-BANTU |
| NOTIF | 4.6 | FR-NOTIF-01 … FR-NOTIF-36 | 36 | BR-NOTIF |
| MOD | 4.7 | FR-MOD-01 … FR-MOD-39 | 39 | BR-MOD |
| PATUH | 4.8 | FR-PATUH-01 … FR-PATUH-37 | 37 | BR-PATUH |
| HUB | 4.9 | FR-HUB-01 … FR-HUB-33 | 33 | BR-HUB |
| INT | 4.10 | FR-INT-01 … FR-INT-22 | 22 | BR-INT |
| OPS | 4.11 | FR-OPS-01 … FR-OPS-35 | 35 | BR-OPS |
| TRADE | 4.12 | FR-TRADE-01 … FR-TRADE-05 | 5 | BR-TRADE |
| **Total** | | | **437** | |

Daftar lengkap FR dan lacaknya:

| FR | Judul | Lacak |
|---|---|---|
| FR-AKUN-01 | Tukar token sosial OLT menjadi sesi sosial | BR-AKUN |
| FR-AKUN-02 | Verifikasi token sosial | BR-AKUN |
| FR-AKUN-03 | ID user stabil dan isi JWT sosial | BR-AKUN |
| FR-AKUN-04 | Pembuatan dan pembaruan profil saat login | BR-AKUN |
| FR-AKUN-05 | Batas laju dan cache penukaran token | BR-AKUN |
| FR-AKUN-06 | Penolakan user yang di-ban | BR-AKUN |
| FR-AKUN-07 | Pemeriksaan sesi di setiap request | BR-AKUN |
| FR-AKUN-08 | Perpanjangan sesi lewat tokenProvider | BR-AKUN |
| FR-AKUN-09 | Logout dan pencabutan akses | BR-AKUN |
| FR-AKUN-10 | Lihat profil sosial | BR-AKUN |
| FR-AKUN-11 | Edit profil sosial | BR-AKUN |
| FR-AKUN-12 | Foto profil | BR-AKUN |
| FR-AKUN-13 | Handle huruf kecil | BR-AKUN |
| FR-AKUN-14 | Daftar dokumen hukum untuk nasabah | BR-AKUN |
| FR-AKUN-15 | Persetujuan dokumen hukum dan gerbang konten | BR-AKUN |
| FR-AKUN-16 | Pengaturan kebijakan DM | BR-AKUN |
| FR-AKUN-17 | Blokir akun | BR-AKUN |
| FR-AKUN-18 | Bisukan akun dan kata | BR-AKUN |
| FR-AKUN-19 | Ekspor data pribadi | BR-AKUN |
| FR-AKUN-20 | Hapus akun komunitas | BR-AKUN |
| FR-AKUN-21 | Konfirmasi dan pembersihan perangkat saat hapus akun | BR-AKUN |
| FR-AKUN-22 | Jeda bergabung lagi setelah hapus akun | BR-AKUN |
| FR-AKUN-23 | Penolakan sesi dari cache setelah hapus akun | BR-AKUN |
| FR-AKUN-24 | Bergabung lagi setelah jeda | BR-AKUN |
| FR-AKUN-25 | Cache offline per user | BR-AKUN |
| FR-AKUN-26 | Enkripsi cache offline | BR-AKUN |
| FR-AKUN-27 | Konfigurasi klien | BR-AKUN |
| FR-AKUN-28 | Kill switch sosial dari sisi aplikasi | BR-AKUN |
| FR-AKUN-29 | Versi minimum dan update paksa | BR-AKUN |
| FR-AKUN-30 | Profil tamu | BR-AKUN |
| FR-KOM-01 | Feed Terbaru | BR-KOM |
| FR-KOM-02 | Feed Mengikuti | BR-KOM |
| FR-KOM-03 | Feed Untuk Anda | BR-KOM |
| FR-KOM-04 | Feed saham dan watchlist | BR-KOM |
| FR-KOM-05 | Feed profil pengguna | BR-KOM |
| FR-KOM-06 | Feed akun resmi | BR-KOM |
| FR-KOM-07 | Urutan Teratas | BR-KOM |
| FR-KOM-08 | Tab filter Stream | BR-KOM |
| FR-KOM-09 | Saringan visibilitas feed | BR-KOM |
| FR-KOM-10 | Pembaruan realtime feed | BR-KOM |
| FR-KOM-11 | Buat postingan | BR-KOM |
| FR-KOM-12 | Gambar di postingan | BR-KOM |
| FR-KOM-13 | Sentimen postingan | BR-KOM |
| FR-KOM-14 | Tag `$KODE` dan mention di postingan | BR-KOM |
| FR-KOM-15 | Hashtag di postingan | BR-KOM |
| FR-KOM-16 | Buat polling | BR-KOM |
| FR-KOM-17 | Memilih di polling | BR-KOM |
| FR-KOM-18 | Edit postingan | BR-KOM |
| FR-KOM-19 | Hapus postingan | BR-KOM |
| FR-KOM-20 | Draf postingan | BR-KOM |
| FR-KOM-21 | Detail postingan | BR-KOM |
| FR-KOM-22 | Label dan status di kartu postingan | BR-KOM |
| FR-KOM-23 | Buat komentar dan balasan | BR-KOM |
| FR-KOM-24 | Thread komentar dan urutannya | BR-KOM |
| FR-KOM-25 | Edit komentar | BR-KOM |
| FR-KOM-26 | Hapus komentar tanpa jejak | BR-KOM |
| FR-KOM-27 | Audiens komentar bawaan akun | BR-KOM |
| FR-KOM-28 | Audiens komentar per postingan | BR-KOM |
| FR-KOM-29 | Matikan komentar di semua postingan | BR-KOM |
| FR-KOM-30 | Penegakan dan tampilan kontrol komentar | BR-KOM |
| FR-KOM-31 | Suka postingan dan komentar | BR-KOM |
| FR-KOM-32 | Ikuti dan berhenti mengikuti | BR-KOM |
| FR-KOM-33 | Daftar pengikut dan yang diikuti | BR-KOM |
| FR-KOM-34 | Saran akun untuk diikuti | BR-KOM |
| FR-KOM-35 | Pengaturan siapa yang bisa menyebut saya | BR-KOM |
| FR-KOM-36 | Saran `@` saat mengetik | BR-KOM |
| FR-KOM-37 | Pencarian gabungan | BR-KOM |
| FR-KOM-38 | Pencarian per jenis | BR-KOM |
| FR-KOM-39 | Feed hashtag | BR-KOM |
| FR-KOM-40 | Hashtag trending | BR-KOM |
| FR-KOM-41 | Trending saham dan postingan | BR-KOM |
| FR-KOM-42 | Sentimen saham | BR-KOM |
| FR-KOM-43 | Mood pasar | BR-KOM |
| FR-KOM-44 | Statistik saham harian | BR-KOM |
| FR-KOM-45 | Simpan postingan (bookmark) | BR-KOM |
| FR-KOM-46 | Daftar postingan tersimpan | BR-KOM |
| FR-KOM-47 | Tampilan link preview | BR-KOM |
| FR-KOM-48 | Membuka tautan dan hashtag | BR-KOM |
| FR-KOM-49 | Akun resmi di aplikasi | BR-KOM |
| FR-KOM-50 | Postingan resmi tersemat | BR-KOM |
| FR-KOM-51 | Daftar indeks | BR-KOM |
| FR-KOM-52 | Stream indeks | BR-KOM |
| FR-KOM-53 | Normalisasi kode saham dan indeks | BR-KOM |
| FR-KOM-54 | Pantau saham | BR-KOM |
| FR-KOM-55 | Bisukan saham | BR-KOM |
| FR-KOM-56 | Halaman saham di Stream | BR-KOM |
| FR-KOM-57 | Saran `$KODE` dari data OLT | BR-KOM |
| FR-KOM-58 | Penerimaan event analitik klien | BR-KOM |
| FR-KOM-59 | Pencatatan analitik di library | BR-KOM |
| FR-CHAT-01 | Daftar room milik pengguna | BR-CHAT |
| FR-CHAT-02 | Membuka atau membuat DM | BR-CHAT |
| FR-CHAT-03 | Evaluasi kebijakan DM dan permintaan pesan | BR-CHAT |
| FR-CHAT-04 | Batas pesan sebelum permintaan diterima | BR-CHAT |
| FR-CHAT-05 | Kotak permintaan pesan | BR-CHAT |
| FR-CHAT-06 | Merespons permintaan pesan | BR-CHAT |
| FR-CHAT-07 | Akun resmi tidak menerima DM dari pengguna biasa | BR-CHAT |
| FR-CHAT-08 | Membuat grup | BR-CHAT |
| FR-CHAT-09 | Menambah anggota grup | BR-CHAT |
| FR-CHAT-10 | Mengeluarkan anggota grup | BR-CHAT |
| FR-CHAT-11 | Mengubah peran admin dan member | BR-CHAT |
| FR-CHAT-12 | Memindahkan kepemilikan grup | BR-CHAT |
| FR-CHAT-13 | Mengubah info grup | BR-CHAT |
| FR-CHAT-14 | Pengaturan grup hanya-admin | BR-CHAT |
| FR-CHAT-15 | Pesan sistem grup | BR-CHAT |
| FR-CHAT-16 | Keluar room | BR-CHAT |
| FR-CHAT-17 | Menghapus grup | BR-CHAT |
| FR-CHAT-18 | Bergabung ke room saham atau indeks | BR-CHAT |
| FR-CHAT-19 | Status room saham dari sisi pengguna | BR-CHAT |
| FR-CHAT-20 | Mengirim pesan | BR-CHAT |
| FR-CHAT-21 | Membalas pesan | BR-CHAT |
| FR-CHAT-22 | Lampiran gambar di chat global | BR-CHAT |
| FR-CHAT-23 | Membagikan postingan ke chat | BR-CHAT |
| FR-CHAT-24 | Kartu saham di chat | BR-CHAT |
| FR-CHAT-25 | Mengedit pesan | BR-CHAT |
| FR-CHAT-26 | Menghapus pesan | BR-CHAT |
| FR-CHAT-27 | Reaksi pesan | BR-CHAT |
| FR-CHAT-28 | Info pesan | BR-CHAT |
| FR-CHAT-29 | Tanda terkirim dan dibaca | BR-CHAT |
| FR-CHAT-30 | Jumlah pesan belum dibaca | BR-CHAT |
| FR-CHAT-31 | Membisukan room | BR-CHAT |
| FR-CHAT-32 | Hapus chat untuk saya | BR-CHAT |
| FR-CHAT-33 | Riwayat pesan berhalaman | BR-CHAT |
| FR-CHAT-34 | Pengiriman pesan realtime lewat Broadcast | BR-CHAT |
| FR-CHAT-35 | Otorisasi topik realtime | BR-CHAT |
| FR-CHAT-36 | Aktivitas daftar chat di topik pengguna | BR-CHAT |
| FR-CHAT-37 | Indikator mengetik | BR-CHAT |
| FR-CHAT-38 | Ringkasan mengetik di room besar | BR-CHAT |
| FR-CHAT-39 | Presence online di DM | BR-CHAT |
| FR-CHAT-40 | Pengisian celah pesan (gap-fill) | BR-CHAT |
| FR-CHAT-41 | Jadwal gap-fill di klien | BR-CHAT |
| FR-CHAT-42 | Pratinjau room saham lewat polling | BR-CHAT |
| FR-CHAT-43 | Pratinjau pesan terakhir di daftar chat | BR-CHAT |
| FR-CHAT-44 | Mention di grup dan room saham | BR-CHAT |
| FR-CHAT-45 | Antrean pesan offline dan cache chat | BR-CHAT |
| FR-CHAT-46 | Room CS terkunci untuk aksi chat generik | BR-CHAT |
| FR-CS-01 | Ringkasan layanan CS untuk nasabah | BR-CS |
| FR-CS-02 | Room CS tersemat dan resmi | BR-CS |
| FR-CS-03 | Daftar topik untuk nasabah | BR-CS |
| FR-CS-04 | Membuka tiket | BR-CS |
| FR-CS-05 | Validasi jawaban pertanyaan awal | BR-CS |
| FR-CS-06 | Prioritas awal tiket | BR-CS |
| FR-CS-07 | Pesan nasabah ke chat CS | BR-CS |
| FR-CS-08 | Pesan CS tidak bisa diubah nasabah | BR-CS |
| FR-CS-09 | Penyamaran data sensitif | BR-CS |
| FR-CS-10 | Akses CS bagi akun yang dibatasi | BR-CS |
| FR-CS-11 | Tampilan status tiket untuk nasabah | BR-CS |
| FR-CS-12 | Tiket saya dan transkrip nasabah | BR-CS |
| FR-CS-13 | Nasabah mengakhiri chat | BR-CS |
| FR-CS-14 | Tiket tertutup tidak bisa dibalas | BR-CS |
| FR-CS-15 | Rating dan survei kepuasan | BR-CS |
| FR-CS-16 | Pengajuan pengaduan resmi | BR-CS |
| FR-CS-17 | Laporan CS palsu | BR-CS |
| FR-CS-18 | Lencana belum dibaca dan notifikasi CS di aplikasi | BR-CS |
| FR-CS-19 | Di luar jam layanan | BR-CS |
| FR-CS-20 | Pengingat tiket menunggu nasabah | BR-CS |
| FR-CS-21 | Pengaduan tamu: konfigurasi dan mulai | BR-CS |
| FR-CS-22 | Pengaduan tamu: percakapan dan akhir sesi | BR-CS |
| FR-CS-23 | Penanganan tiket tamu di Hub | BR-CS |
| FR-CS-24 | Status kerja CS | BR-CS |
| FR-CS-25 | Heartbeat dan keterjangkauan CS | BR-CS |
| FR-CS-26 | Daftar dan pencarian tiket CS | BR-CS |
| FR-CS-27 | Hak baca tiket dan riwayat nasabah | BR-CS |
| FR-CS-28 | Mengambil tiket | BR-CS |
| FR-CS-29 | Transfer tiket: permintaan | BR-CS |
| FR-CS-30 | Transfer tiket: jawaban, pembatalan, kedaluwarsa | BR-CS |
| FR-CS-31 | Penugasan otomatis | BR-CS |
| FR-CS-32 | Melepas tiket | BR-CS |
| FR-CS-33 | Menunggu balasan nasabah | BR-CS |
| FR-CS-34 | Menyelesaikan tiket | BR-CS |
| FR-CS-35 | Pemilik offline: pemberitahuan dan lepas otomatis | BR-CS |
| FR-CS-36 | Tutup otomatis tiket selesai | BR-CS |
| FR-CS-37 | Batas tiket aktif per CS | BR-CS |
| FR-CS-38 | Membuka kembali tiket selesai | BR-CS |
| FR-CS-39 | Jejak kejadian dan audit tiket | BR-CS |
| FR-CS-40 | Kontrol konkurensi versi tiket | BR-CS |
| FR-CS-41 | Pesan teks CS | BR-CS |
| FR-CS-42 | Balasan ditolak saat CS Offline | BR-CS |
| FR-CS-43 | Blokir permintaan OTP, PIN, dan password | BR-CS |
| FR-CS-44 | Pesan pilihan cepat dan tautan bantuan | BR-CS |
| FR-CS-45 | Catatan internal | BR-CS |
| FR-CS-46 | Mengubah prioritas tiket | BR-CS |
| FR-CS-47 | Menandai pengaduan atau penipuan | BR-CS |
| FR-CS-48 | Label tiket pada tiket | BR-CS |
| FR-CS-49 | Balasan cepat bersama | BR-CS |
| FR-CS-50 | Balasan cepat pribadi | BR-CS |
| FR-CS-51 | Panel info nasabah | BR-CS |
| FR-CS-52 | Lampiran CS: validasi saat kirim dan akses baca | BR-CS |
| FR-CS-53 | Lampiran CS: pemeriksaan file dan antivirus | BR-CS |
| FR-CS-54 | Lampiran CS di Hub dan aplikasi | BR-CS |
| FR-CS-55 | Mode pantau Super Admin | BR-CS |
| FR-CS-56 | Memindahkan tiket oleh Super Admin | BR-CS |
| FR-CS-57 | Dashboard supervisor dan alert tiket terlambat | BR-CS |
| FR-CS-58 | Notifikasi kerja di Hub | BR-CS |
| FR-CS-59 | Laporan ringkasan layanan | BR-CS |
| FR-CS-60 | Laporan per nasabah dan jejak layanan | BR-CS |
| FR-CS-61 | Laporan alasan nilai rendah dan label | BR-CS |
| FR-CS-62 | Ekspor CSV laporan | BR-CS |
| FR-CS-63 | Kelola label tiket | BR-CS |
| FR-CS-64 | Kebijakan lampiran chat CS | BR-CS |
| FR-CS-65 | Jam layanan dan hari libur | BR-CS |
| FR-CS-66 | Pesan otomatis | BR-CS |
| FR-CS-67 | Pengaturan penugasan, tiket, dan alert | BR-CS |
| FR-CS-68 | Status layanan dan gangguan | BR-CS |
| FR-CS-69 | Konfigurasi survei kepuasan | BR-CS |
| FR-CS-70 | Pintasan keyboard Layanan Nasabah | BR-CS |
| FR-BANTU-01 | Daftar kategori dan artikel untuk nasabah | BR-BANTU |
| FR-BANTU-02 | Pencarian artikel | BR-BANTU |
| FR-BANTU-03 | Membaca artikel dan statistik baca | BR-BANTU |
| FR-BANTU-04 | Umpan balik "Apakah ini membantu?" | BR-BANTU |
| FR-BANTU-05 | Tampilan artikel di aplikasi | BR-BANTU |
| FR-BANTU-06 | Saran artikel sebelum chat CS | BR-BANTU |
| FR-BANTU-07 | Pusat Bantuan offline | BR-BANTU |
| FR-BANTU-08 | Privasi data Pusat Bantuan | BR-BANTU |
| FR-BANTU-09 | Kelola kategori FAQ | BR-BANTU |
| FR-BANTU-10 | Menyimpan artikel | BR-BANTU |
| FR-BANTU-11 | Gambar di jawaban artikel | BR-BANTU |
| FR-BANTU-12 | Lampiran artikel | BR-BANTU |
| FR-BANTU-13 | Status artikel | BR-BANTU |
| FR-BANTU-14 | Riwayat versi dan pemulihan artikel | BR-BANTU |
| FR-BANTU-15 | Statistik artikel di Hub | BR-BANTU |
| FR-BANTU-16 | Komentar nasabah dan pencarian tanpa hasil | BR-BANTU |
| FR-BANTU-17 | Sisipkan artikel FAQ oleh CS | BR-BANTU |
| FR-BANTU-18 | Catatan CS "perlu diperbarui" | BR-BANTU |
| FR-BANTU-19 | Laporan bantuan | BR-BANTU |
| FR-BANTU-20 | Kelola topik chat CS | BR-BANTU |
| FR-BANTU-21 | Tanda pengaduan/penipuan pada topik | BR-BANTU |
| FR-BANTU-22 | Urutan dan penghapusan topik | BR-BANTU |
| FR-BANTU-23 | Teks halaman pilih topik | BR-BANTU |
| FR-BANTU-24 | Isian, saran balasan, dan SOP topik | BR-BANTU |
| FR-BANTU-25 | Peran Pusat Bantuan | BR-BANTU |
| FR-NOTIF-01 | Pembuatan notifikasi in-app | BR-NOTIF |
| FR-NOTIF-02 | Kotak notifikasi | BR-NOTIF |
| FR-NOTIF-03 | Tandai dibaca, hapus, dan badge | BR-NOTIF |
| FR-NOTIF-04 | Penggabungan notifikasi | BR-NOTIF |
| FR-NOTIF-05 | Notifikasi postingan dari akun yang diikuti | BR-NOTIF |
| FR-NOTIF-06 | Ringkasan saham pantauan harian | BR-NOTIF |
| FR-NOTIF-07 | Notifikasi moderasi | BR-NOTIF |
| FR-NOTIF-08 | Preferensi notifikasi per jenis | BR-NOTIF |
| FR-NOTIF-09 | Jam tenang | BR-NOTIF |
| FR-NOTIF-10 | Pengecualian preferensi dan kategori OLT | BR-NOTIF |
| FR-NOTIF-11 | Registrasi token push perangkat | BR-NOTIF |
| FR-NOTIF-12 | Melepas token push | BR-NOTIF |
| FR-NOTIF-13 | Antrean push dan isi push | BR-NOTIF |
| FR-NOTIF-14 | Pengiriman push oleh notifier | BR-NOTIF |
| FR-NOTIF-15 | Status push di Hub | BR-NOTIF |
| FR-NOTIF-16 | Unggah kunci Firebase | BR-NOTIF |
| FR-NOTIF-17 | Hapus dan ganti kunci Firebase | BR-NOTIF |
| FR-NOTIF-18 | Push uji | BR-NOTIF |
| FR-NOTIF-19 | Membuka push di aplikasi | BR-NOTIF |
| FR-NOTIF-20 | Statistik dibuka dan diketuk | BR-NOTIF |
| FR-NOTIF-21 | Kampanye notifikasi: draf | BR-NOTIF |
| FR-NOTIF-22 | Kampanye notifikasi: segmen penerima | BR-NOTIF |
| FR-NOTIF-23 | Kampanye notifikasi: persetujuan empat mata | BR-NOTIF |
| FR-NOTIF-24 | Kampanye notifikasi: pengiriman, jadwal, dan pembatalan | BR-NOTIF |
| FR-NOTIF-25 | Kampanye notifikasi: statistik | BR-NOTIF |
| FR-NOTIF-26 | Kelola banner strip dan popup | BR-NOTIF |
| FR-NOTIF-27 | Gambar popup dan hapus banner | BR-NOTIF |
| FR-NOTIF-28 | Penyajian banner ke aplikasi | BR-NOTIF |
| FR-NOTIF-29 | Tampilan banner strip di library | BR-NOTIF |
| FR-NOTIF-30 | Popup promo di library | BR-NOTIF |
| FR-NOTIF-31 | Event dan statistik banner | BR-NOTIF |
| FR-NOTIF-32 | Skema deep link banner | BR-NOTIF |
| FR-NOTIF-33 | Notifikasi info dari Banner & Popup | BR-NOTIF |
| FR-NOTIF-34 | Pengiriman dan halaman notifikasi info | BR-NOTIF |
| FR-NOTIF-35 | Sinkron popup dan notifikasi info | BR-NOTIF |
| FR-NOTIF-36 | Retensi notifikasi | BR-NOTIF |
| FR-MOD-01 | Laporan konten dan akun oleh pengguna | BR-MOD |
| FR-MOD-02 | Laporan otomatis dari blokir permintaan pesan | BR-MOD |
| FR-MOD-03 | Cakupan dan pengecualian pemeriksaan konten | BR-MOD |
| FR-MOD-04 | Integritas konten | BR-MOD |
| FR-MOD-05 | Penegakan kata terlarang | BR-MOD |
| FR-MOD-06 | Normalisasi teks dan istilah pengecualian | BR-MOD |
| FR-MOD-07 | Kategori tautan dan domain | BR-MOD |
| FR-MOD-08 | Deteksi nomor kontak | BR-MOD |
| FR-MOD-09 | Frasa promosi | BR-MOD |
| FR-MOD-10 | Penggabungan aksi dan cakupan | BR-MOD |
| FR-MOD-11 | Pembatasan akun baru | BR-MOD |
| FR-MOD-12 | Perlakuan konten ditahan | BR-MOD |
| FR-MOD-13 | Antrean konten ditahan | BR-MOD |
| FR-MOD-14 | Moderasi gambar NSFW saat upload | BR-MOD |
| FR-MOD-15 | Avatar NSFW | BR-MOD |
| FR-MOD-16 | Antrean gambar ditahan | BR-MOD |
| FR-MOD-17 | Gambar pratinjau link NSFW | BR-MOD |
| FR-MOD-18 | Antrean laporan berprioritas | BR-MOD |
| FR-MOD-19 | Keputusan moderasi konten | BR-MOD |
| FR-MOD-20 | Membuka konten untuk ditinjau dan aturan pesan privat | BR-MOD |
| FR-MOD-21 | Riwayat edit untuk moderator | BR-MOD |
| FR-MOD-22 | Konten termoderasi milik pengguna | BR-MOD |
| FR-MOD-23 | Detail pengguna untuk moderator | BR-MOD |
| FR-MOD-24 | Sanksi bertingkat dan manual | BR-MOD |
| FR-MOD-25 | Penegakan sanksi | BR-MOD |
| FR-MOD-26 | Cabut sanksi dan cabut sesi | BR-MOD |
| FR-MOD-27 | Pengajuan banding | BR-MOD |
| FR-MOD-28 | Peninjauan banding | BR-MOD |
| FR-MOD-29 | Toleransi nol (CSAM) | BR-MOD |
| FR-MOD-30 | Deteksi manipulasi saham | BR-MOD |
| FR-MOD-31 | Aksi otomatis alert manipulasi | BR-MOD |
| FR-MOD-32 | Tinjauan alert manipulasi | BR-MOD |
| FR-MOD-33 | Slow mode room saham dari sisi staf | BR-MOD |
| FR-MOD-34 | Pesan disematkan di room saham | BR-MOD |
| FR-MOD-35 | Penunjukan dan pencopotan moderator room | BR-MOD |
| FR-MOD-36 | Aksi moderator room oleh nasabah | BR-MOD |
| FR-MOD-37 | Privasi bisu room saham | BR-MOD |
| FR-MOD-38 | Log dan pembatalan aksi moderator room | BR-MOD |
| FR-MOD-39 | API admin moderasi (admin_api) | BR-MOD |
| FR-PATUH-01 | Akses dan navigasi peran Kepatuhan | BR-PATUH |
| FR-PATUH-02 | Ringkasan Kepatuhan | BR-PATUH |
| FR-PATUH-03 | Notifikasi kasus baru | BR-PATUH |
| FR-PATUH-04 | Register kasus | BR-PATUH |
| FR-PATUH-05 | Detail kasus | BR-PATUH |
| FR-PATUH-06 | Akses hanya-baca 12 jam ke tiket biasa | BR-PATUH |
| FR-PATUH-07 | Status tenggat pengaduan | BR-PATUH |
| FR-PATUH-08 | Tinjauan kepatuhan | BR-PATUH |
| FR-PATUH-09 | Perpanjangan tenggat pengaduan | BR-PATUH |
| FR-PATUH-10 | Transkrip bersidik SHA-256 | BR-PATUH |
| FR-PATUH-11 | Jejak Audit | BR-PATUH |
| FR-PATUH-12 | Kebijakan tenggat dan retensi | BR-PATUH |
| FR-PATUH-13 | Draf dokumen hukum | BR-PATUH |
| FR-PATUH-14 | Pengajuan, penarikan, dan penolakan draf dokumen hukum | BR-PATUH |
| FR-PATUH-15 | Persetujuan dan penerbitan dokumen hukum (empat mata) | BR-PATUH |
| FR-PATUH-16 | Pembatalan jadwal dan penghapusan draf dokumen hukum | BR-PATUH |
| FR-PATUH-17 | Jenis dokumen hukum wajib | BR-PATUH |
| FR-PATUH-18 | Ringkasan dokumen hukum | BR-PATUH |
| FR-PATUH-19 | Perekaman bukti otomatis | BR-PATUH |
| FR-PATUH-20 | Imutabilitas, sidik, dan pemeriksaan integritas bukti | BR-PATUH |
| FR-PATUH-21 | Daftar dan detail bukti | BR-PATUH |
| FR-PATUH-22 | Legal hold dan masa simpan bukti | BR-PATUH |
| FR-PATUH-23 | Ekspor paket bukti | BR-PATUH |
| FR-PATUH-24 | Aksi dan cakupan kategori konten | BR-PATUH |
| FR-PATUH-25 | Domain diblokir dan domain tepercaya | BR-PATUH |
| FR-PATUH-26 | Istilah pengecualian dan frasa promosi | BR-PATUH |
| FR-PATUH-27 | Kelola kata terlarang | BR-PATUH |
| FR-PATUH-28 | Import dan ekspor Excel kata terlarang | BR-PATUH |
| FR-PATUH-29 | Masa akun baru | BR-PATUH |
| FR-PATUH-30 | Jeda bergabung lagi setelah hapus akun | BR-PATUH |
| FR-PATUH-31 | Ambang gambar NSFW | BR-PATUH |
| FR-PATUH-32 | Pengaturan anti-manipulasi dan jam ramai | BR-PATUH |
| FR-PATUH-33 | Uji teks terhadap kebijakan berlaku | BR-PATUH |
| FR-PATUH-34 | Draf kebijakan per staf | BR-PATUH |
| FR-PATUH-35 | Pengajuan dan persetujuan empat mata kebijakan | BR-PATUH |
| FR-PATUH-36 | Versi kebijakan dan pemulihan | BR-PATUH |
| FR-PATUH-37 | Simulasi kebijakan | BR-PATUH |
| FR-HUB-01 | Login staf dengan email dan password | BR-HUB |
| FR-HUB-02 | Ganti password wajib pada login pertama | BR-HUB |
| FR-HUB-03 | Verifikasi kode 2FA (TOTP) saat masuk | BR-HUB |
| FR-HUB-04 | Pendaftaran 2FA | BR-HUB |
| FR-HUB-05 | Kunci akun setelah password salah berulang | BR-HUB |
| FR-HUB-06 | Pengaturan Keamanan login | BR-HUB |
| FR-HUB-07 | Buka kunci akun staf | BR-HUB |
| FR-HUB-08 | Reset 2FA staf dan pemulihan darurat | BR-HUB |
| FR-HUB-09 | Sesi per tab dan keluar otomatis saat idle | BR-HUB |
| FR-HUB-10 | Ganti password sendiri | BR-HUB |
| FR-HUB-11 | Keluar dari semua perangkat | BR-HUB |
| FR-HUB-12 | Profil saya | BR-HUB |
| FR-HUB-13 | Kinerja saya | BR-HUB |
| FR-HUB-14 | Membuat akun staf | BR-HUB |
| FR-HUB-15 | Mengubah dan menonaktifkan akun staf | BR-HUB |
| FR-HUB-16 | Reset password staf | BR-HUB |
| FR-HUB-17 | Menu mengikuti peran dan izin | BR-HUB |
| FR-HUB-18 | Mengatur Izin Komunitas | BR-HUB |
| FR-HUB-19 | Mengatur Akses Akun Nasabah | BR-HUB |
| FR-HUB-20 | Aturan empat mata | BR-HUB |
| FR-HUB-21 | Kill switch fitur sosial | BR-HUB |
| FR-HUB-22 | Saklar fitur aplikasi | BR-HUB |
| FR-HUB-23 | Versi minimum aplikasi per platform | BR-HUB |
| FR-HUB-24 | Tab Stream | BR-HUB |
| FR-HUB-25 | Kelola Indeks | BR-HUB |
| FR-HUB-26 | Kelola akun resmi | BR-HUB |
| FR-HUB-27 | Badge verifikasi pengguna | BR-HUB |
| FR-HUB-28 | Menyusun postingan resmi | BR-HUB |
| FR-HUB-29 | Persetujuan postingan resmi (empat mata) | BR-HUB |
| FR-HUB-30 | Sematan, pembatalan, dan penghapusan postingan resmi | BR-HUB |
| FR-HUB-31 | Analitik komunitas | BR-HUB |
| FR-HUB-32 | Command palette dan pintasan keyboard | BR-HUB |
| FR-HUB-33 | Bahasa, tema, dan kepadatan tampilan | BR-HUB |
| FR-INT-01 | Tanpa panggilan ke OLT saat login | BR-INT |
| FR-INT-02 | Format token sosial dan identitas stabil | BR-INT |
| FR-INT-03 | Verifikasi tanda tangan dan waktu token | BR-INT |
| FR-INT-04 | Pengelolaan JWKS, rotasi, dan pencabutan | BR-INT |
| FR-INT-05 | Klaim `accounts` dan tautan rekening | BR-INT |
| FR-INT-06 | Status integrasi aplikasi di Hub | BR-INT |
| FR-INT-07 | Membuat API key integrasi | BR-INT |
| FR-INT-08 | Mengubah, menonaktifkan, mencabut, dan merotasi API key | BR-INT |
| FR-INT-09 | Autentikasi dan batas request `/integration/v1` | BR-INT |
| FR-INT-10 | Notifikasi transaksi per rekening (`cust_id`) | BR-INT |
| FR-INT-11 | Notifikasi per login (`olt_user_id`) | BR-INT |
| FR-INT-12 | Siaran ke banyak nasabah | BR-INT |
| FR-INT-13 | Kategori pesan dan jenis preferensi OLT | BR-INT |
| FR-INT-14 | Idempotensi dan kirim ulang | BR-INT |
| FR-INT-15 | Postingan bot resmi | BR-INT |
| FR-INT-16 | Statistik integrasi dan daftar siaran | BR-INT |
| FR-INT-17 | Konfigurasi integrasi API Nasabah | BR-INT |
| FR-INT-18 | Token integrasi Ed25519 ke csAdmin | BR-INT |
| FR-INT-19 | Penegakan izin dan rute gateway Akun Nasabah | BR-INT |
| FR-INT-20 | Data saham dari aplikasi OLT | BR-INT |
| FR-INT-21 | Deep link dan ketukan notifikasi OLT | BR-INT |
| FR-INT-22 | OLT tiruan untuk pengembangan | BR-INT |
| FR-OPS-01 | Profil deploy | BR-OPS |
| FR-OPS-02 | Instalasi server baru | BR-OPS |
| FR-OPS-03 | Menjalankan dan menerapkan perubahan dengan `make up` | BR-OPS |
| FR-OPS-04 | Migrasi bernomor dengan checksum | BR-OPS |
| FR-OPS-05 | Pembaruan versi dan rollback | BR-OPS |
| FR-OPS-06 | Pemisahan jaringan, domain, dan pengerasan container | BR-OPS |
| FR-OPS-07 | Rahasia infrastruktur dan pengaturan lewat Hub | BR-OPS |
| FR-OPS-08 | Heartbeat layanan | BR-OPS |
| FR-OPS-09 | Pengumpulan data pemantauan oleh sentinel | BR-OPS |
| FR-OPS-10 | Evaluasi dan siklus alert | BR-OPS |
| FR-OPS-11 | Pengiriman alert ke Telegram dan email | BR-OPS |
| FR-OPS-12 | Pengaturan kanal alert di Hub | BR-OPS |
| FR-OPS-13 | Alert saat API atau database tidak bisa dihubungi | BR-OPS |
| FR-OPS-14 | Halaman Kesehatan sistem | BR-OPS |
| FR-OPS-15 | Peta layanan | BR-OPS |
| FR-OPS-16 | Restart otomatis layanan macet (healer) | BR-OPS |
| FR-OPS-17 | Penahanan restart, menyerah, dan riwayat restart | BR-OPS |
| FR-OPS-18 | Backup berkelanjutan database dan file | BR-OPS |
| FR-OPS-19 | Tujuan backup dan password enkripsi | BR-OPS |
| FR-OPS-20 | Jadwal dan retensi backup | BR-OPS |
| FR-OPS-21 | Backup penuh dan uji restore sesuai permintaan | BR-OPS |
| FR-OPS-22 | Alert backup | BR-OPS |
| FR-OPS-23 | Pemulihan ke titik waktu | BR-OPS |
| FR-OPS-24 | Pemulihan rahasia Vault setelah pindah server | BR-OPS |
| FR-OPS-25 | Pembersihan file tak terpakai (janitor) | BR-OPS |
| FR-OPS-26 | Salinan file bukti terverifikasi | BR-OPS |
| FR-OPS-27 | Retensi data sosial | BR-OPS |
| FR-OPS-28 | Arsip konten dan legal hold pada job | BR-OPS |
| FR-OPS-29 | Partisi tabel bervolume tinggi | BR-OPS |
| FR-OPS-30 | Jadwal job database dan pemantauannya | BR-OPS |
| FR-OPS-31 | Log dan endpoint ops | BR-OPS |
| FR-OPS-32 | Gerbang unggah file (media) | BR-OPS |
| FR-OPS-33 | Pemindaian antivirus fail-closed | BR-OPS |
| FR-OPS-34 | Layanan klasifikasi gambar (classifier) | BR-OPS |
| FR-OPS-35 | Layanan pratinjau tautan aman SSRF | BR-OPS |
| FR-TRADE-01 | Pengajuan dan peninjauan trader (Ditunda) | BR-TRADE |
| FR-TRADE-02 | Langganan pelanggan (Ditunda) | BR-TRADE |
| FR-TRADE-03 | Relay pasif dari iProxy OLT (Ditunda) | BR-TRADE |
| FR-TRADE-04 | Notifikasi aktivitas trade ke pelanggan (Ditunda) | BR-TRADE |
| FR-TRADE-05 | Tombol darurat dan pemantauan Kepatuhan (Ditunda) | BR-TRADE |

Kebutuhan non-fungsional (bagian 7) berlaku lintas modul:

| Kategori | Kode | Jumlah NFR |
|---|---|---|
| PERF | NFR-PERF | 15 |
| KAP | NFR-KAP | 12 |
| AVAIL | NFR-AVAIL | 16 |
| SEC | NFR-SEC | 10 |
| PRIV | NFR-PRIV | 10 |
| AUD | NFR-AUD | 8 |
| MAINT | NFR-MAINT | 10 |
| PORT | NFR-PORT | 6 |
| USAB | NFR-USAB | 7 |
| I18N | NFR-I18N | 6 |
| LOG | NFR-LOG | 7 |
| COMP | NFR-COMP | 8 |

### 11.2 Katalog kode error

#### 11.2.1 Konvensi

- Error aplikasi di database dilempar lewat `private.api_error(p_status, p_code, p_detail)` (0002). Fungsi ini me-raise SQLSTATE `PT<status>` dengan `message = <kode>` dan `detail = <penjelasan>`; PostgREST meneruskannya sebagai status HTTP `<status>` dengan body JSON berisi `code`, `message`, dan `details`.
- Klien wajib bercabang pada `message` (kode stabil, huruf kecil + garis bawah), bukan pada teks `detail` (teks bahasa Indonesia untuk ditampilkan, bisa berubah). Library memetakan kode ke `CommunityException.kind` (`network`, `unauthenticated`, `rateLimited`, `contentBlocked`, `invalidInput`, `forbidden`, `notFound`, `unavailable`, `unknown`) (rendezvous_community `doc/integration.md` bagian 6).
- Satu kode bisa muncul dengan beberapa status (mis. `400 invalid_status` dan `409 invalid_status`) dan beberapa teks detail. Katalog di bawah memuat setiap pasangan (status, kode) yang berbeda.

#### 11.2.2 Cara katalog dibuat

Katalog dibuat otomatis dengan skrip yang memindai semua panggilan `private.api_error(<status>, '<kode>'` (tidak peka huruf besar/kecil) di `supabase/migrations/0001…0188`, ditambah kode dinamis yang diteruskan lewat fungsi pembantu (`care.require_text`, `cs.policy_reason`, `private.room_mod_target_problem`). Kolom:

- **Arti singkat** diambil dari teks `detail` pada migrasi terbaru yang memakai kode itu (dipendekkan; `N` = angka dari pengaturan). Awalan "Mis." berarti kode yang sama dipakai di beberapa konteks dengan teks berbeda; yang ditampilkan adalah salah satu contohnya.
- **Migrasi** = migrasi pertama–terakhir yang memuat panggilan dengan pasangan itu.
- Tanda **(historis: tidak lagi dipakai fungsi aktif)** berarti kode itu tidak lagi ada di definisi terbaru fungsi mana pun yang masih hidup (fungsinya sudah diganti, di-drop, atau skemanya dihapus, mis. skema `care`/`care_api` yang dihapus 0026, atau alur sesi CS lama 0028–0031). Kode ini tidak akan dikirim server saat ini, tetapi dicantumkan demi kelengkapan.
- Tanda **(TRADE, dijeda)** berarti kode hanya dipakai fitur Berbagi Trade (0160–0167) yang dijeda pada rilis ini.

Ringkasan: 547 pasangan (status, kode) dari 536 kode berbeda; per status: 400 = 283, 401 = 5, 403 = 64, 404 = 61, 409 = 112, 422 = 16, 429 = 4, 500 = 1, 503 = 1. Sebanyak 60 pasangan bertanda historis dan 37 bertanda TRADE.

#### 11.2.3 Kode error database (PostgREST)

| Status | Kode `message` | Arti singkat | Migrasi |
|---|---|---|---|
| 400 | `account_not_eligible` | Rekening tidak memenuhi syarat Berbagi Trade (detail = daftar rekening) (TRADE, dijeda) | 0160 |
| 400 | `accounts_required` | Pilih minimal satu rekening (TRADE, dijeda) | 0160 |
| 400 | `appeal_window_closed` | Batas waktu pengajuan banding sudah lewat | 0071 |
| 400 | `attachment_missing` | File lampiran tidak ditemukan, unggah ulang | 0188 |
| 400 | `attachment_not_allowed` | Mis. chat ini hanya menerima gambar (JPEG, PNG, WebP, GIF) | 0053–0138 |
| 400 | `attachment_too_large` | Lampiran melebihi batas ukuran jenisnya (mis. PDF 10 MB, gambar 5 MB, video 25 MB) | 0053–0188 |
| 400 | `attachment_too_long` | Durasi video melebihi batas detik kebijakan lampiran | 0131–0138 |
| 400 | `author_required` | author_id wajib diisi untuk scope user | 0007–0149 |
| 400 | `banned_word_limit` | Mis. daftar kata terlarang sudah mencapai batas | 0051 |
| 400 | `body_required` | Isi teks pesan wajib diisi | 0029–0038 |
| 400 | `body_too_long` | Mis. pesan maksimal 4000 karakter | 0007–0154 |
| 400 | `bucket_not_holdable` | Hanya lampiran yang bisa ditahan untuk ditinjau | 0079 |
| 400 | `cannot_change_self` | Tidak bisa menonaktifkan atau melepas peran admin akun sendiri | 0035–0038 |
| 400 | `cannot_hide_support` | Chat CS tidak bisa dihapus | 0154 |
| 400 | `cannot_leave_direct` | Room DM tidak bisa ditinggalkan | 0008–0157 |
| 400 | `cannot_leave_support` | Chat CS tidak bisa ditinggalkan | 0028–0157 |
| 400 | `cannot_mute_support` | Chat CS tidak bisa dibisukan | 0032 |
| 400 | `cannot_reset_self` | Reset 2FA milik sendiri harus dilakukan Super Admin lain | 0186 |
| 400 | `category_not_leaf` | Pilih subkategori yang paling sesuai (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `comment_too_long` | Komentar maksimal 500 karakter | 0029–0135 |
| 400 | `default_topic` | Topik bawaan tidak bisa dinonaktifkan | 0035–0127 |
| 400 | `domain_limit` | Mis. daftar domain sudah mencapai batas 5.000 | 0069 |
| 400 | `duplicate_attachment` | Lampiran yang sama dipasang dua kali | 0188 |
| 400 | `email_incomplete` | Isi host, port, keamanan, pengirim, dan minimal satu penerima | 0064 |
| 400 | `empty_body` | Mis. pesan tidak boleh kosong | 0007–0154 |
| 400 | `empty_draft` | Draf kosong tidak disimpan | 0090–0150 |
| 400 | `field_required` | Isian wajib kategori belum diisi (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `flag_not_deletable` | Daftar fitur tetap; matikan fitur alih-alih menghapusnya | 0091–0121 |
| 400 | `handover_note_required` | Mis. tulis catatan serah terima (3–1000 karakter) | 0028–0038 |
| 400 | `import_conflict` | Kata yang sama muncul lebih dari sekali dengan aksi berbeda di file import | 0051 |
| 400 | `import_too_large` | Maksimal 1.000 baris per import | 0051 |
| 400 | `intake_required` | Pertanyaan awal topik wajib dijawab | 0134 |
| 400 | `invalid_accounts` | Mis. accounts harus berupa array | 0068–0128 |
| 400 | `invalid_action` | Mis. perintah harus reconnect atau restart | 0013–0162 |
| 400 | `invalid_aes_iv` | Mis. IV harus 16 karakter ASCII untuk mode CBC (TRADE, dijeda) | 0162 |
| 400 | `invalid_aes_key` | Kunci harus 16, 24, atau 32 karakter ASCII (TRADE, dijeda) | 0162 |
| 400 | `invalid_aes_mode` | Mode harus ecb atau cbc (TRADE, dijeda) | 0162 |
| 400 | `invalid_alert_channel` | Kanal harus telegram atau email | 0064 |
| 400 | `invalid_alert_label` | Label 1–40 karakter | 0064 |
| 400 | `invalid_alert_report` | Hasil harus berupa array | 0064 |
| 400 | `invalid_answer` | Mis. jawaban 1–8.000 karakter dalam dua bahasa | 0129–0188 |
| 400 | `invalid_assignee` | Staf tujuan tidak aktif atau bukan anggota tim (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_attachment_name` | Nama lampiran 1–120 karakter | 0188 |
| 400 | `invalid_attachment_policy` | Mis. kebijakan harus berisi documents, images, dan videos | 0131 |
| 400 | `invalid_attachments` | Mis. lampiran tidak valid | 0004–0188 |
| 400 | `invalid_audience` | Mis. sasaran: all atau new_users | 0057–0184 |
| 400 | `invalid_avatar` | Mis. alamat foto grup tidak valid | 0057–0146 |
| 400 | `invalid_backup_bucket` | Nama bucket tidak valid | 0065–0112 |
| 400 | `invalid_backup_credentials` | Mis. access key tidak valid | 0065–0112 |
| 400 | `invalid_backup_endpoint` | Endpoint S3 harus berupa https://host[:port] | 0065–0112 |
| 400 | `invalid_backup_kind` | Jenis tujuan backup harus s3 atau local | 0112 |
| 400 | `invalid_backup_prefix` | Folder (prefix) tidak valid | 0065–0112 |
| 400 | `invalid_backup_region` | Region tidak valid | 0065–0112 |
| 400 | `invalid_backup_request` | Permintaan harus base atau restore_test | 0065 |
| 400 | `invalid_backup_run` | Jenis atau status backup tidak valid | 0065 |
| 400 | `invalid_backup_schedule` | Jadwal atau retensi di luar batas | 0065 |
| 400 | `invalid_banned_action` | Aksi kata terlarang harus mask atau block | 0051 |
| 400 | `invalid_banned_word` | Kata terlarang 2–50 karakter, hanya huruf, angka, dan spasi | 0051 |
| 400 | `invalid_batch` | Mis. messages harus array berisi 1–500 pesan | 0068–0171 |
| 400 | `invalid_bio` | Bio maksimal 300 karakter | 0057–0058 |
| 400 | `invalid_body` | Mis. isi strip maksimal 300 karakter | 0023–0184 |
| 400 | `invalid_card` | Kartu harus berisi order atau transaksi dana yang valid (historis: tidak lagi dipakai fungsi aktif) | 0029–0033 |
| 400 | `invalid_category` | Mis. kategori tidak ditemukan | 0069–0188 |
| 400 | `invalid_channel` | Kanal manual: phone, email, letter, walk_in, atau social_media (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_cidr` | Mis. alamat IP atau CIDR tidak valid: N | 0068 |
| 400 | `invalid_claim` | Batas claim di luar rentang | 0060–0095 |
| 400 | `invalid_code` | Mis. kode 2–32 huruf kecil, angka, atau garis bawah, diawali huruf | 0035–0129 |
| 400 | `invalid_comment_audience` | Audiens komentar tidak dikenal (everyone, following, followers, following_and_followers, off) | 0169 |
| 400 | `invalid_comment_setting` | Pilihan matikan semua komentar wajib diisi | 0170 |
| 400 | `invalid_console_url` | Alamat web CS harus diawali http:// atau https:// | 0064 |
| 400 | `invalid_csadmin_client_id` | Mis. client id wajib diisi | 0050–0055 |
| 400 | `invalid_csadmin_url` | Mis. alamat API Nasabah wajib diisi | 0050–0055 |
| 400 | `invalid_cta` | Mis. label tombol maksimal 24 karakter | 0119–0184 |
| 400 | `invalid_cursor` | Mis. cursor tidak valid | 0003–0155 |
| 400 | `invalid_cust_id` | Nomor rekening tidak valid (TRADE, dijeda) | 0160 |
| 400 | `invalid_customer_replies` | Mis. maksimal 6 saran balasan | 0134 |
| 400 | `invalid_day` | Tanggal wajib diisi | 0035 |
| 400 | `invalid_decision` | Mis. keputusan tidak dikenal | 0071–0160 |
| 400 | `invalid_delay` | Jeda di luar rentang menit yang diizinkan (TRADE, dijeda) | 0160 |
| 400 | `invalid_description` | Mis. deskripsi grup maksimal 500 karakter | 0023–0146 |
| 400 | `invalid_details` | Detail audit Nasabah harus objek maksimal 4 KB | 0044 |
| 400 | `invalid_display` | Tampilan banner: strip atau popup | 0119–0184 |
| 400 | `invalid_documents` | Sebutkan 1–10 dokumen, masing-masing 2–100 karakter (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_domain` | Mis. domain tidak valid (contoh: contoh.com) atau kata kunci 3–30 karakter | 0069 |
| 400 | `invalid_draft` | client_draft_id wajib diisi | 0090–0150 |
| 400 | `invalid_duplicate` | Tiket duplikat harus milik nasabah yang sama (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_duration` | Durasi di luar rentang (bisu room mulai 5 menit; sanksi 1 jam–365 hari) | 0057–0096 |
| 400 | `invalid_email_address` | Alamat email tidak valid (maks 10 penerima) | 0064 |
| 400 | `invalid_emoji` | Reaksi harus salah satu emoji yang diizinkan | 0075 |
| 400 | `invalid_event` | Mis. event harus impression, click, atau dismiss | 0088–0185 |
| 400 | `invalid_events` | Event harus berupa array | 0078–0085 |
| 400 | `invalid_explanation` | Penjelasan 10–2000 karakter (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_feedback` | Mis. pilih membantu atau tidak | 0129 |
| 400 | `invalid_field` | Mis. field tidak bisa dibuka (historis: tidak lagi dipakai fungsi aktif) | 0023–0033 |
| 400 | `invalid_fields` | Isian formulir harus berupa objek (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_filter` | Mis. filter feed tidak dikenal atau sedang nonaktif | 0023–0149 |
| 400 | `invalid_filter_content` | Isi filter harus media, poll, atau kosong (historis: tidak lagi dipakai fungsi aktif) | 0149 |
| 400 | `invalid_filter_icon` | Ikon filter berupa nama huruf kecil tanpa spasi (historis: tidak lagi dipakai fungsi aktif) | 0149 |
| 400 | `invalid_filter_key` | Kunci filter 2-32 huruf kecil, angka, atau garis bawah (historis: tidak lagi dipakai fungsi aktif) | 0149 |
| 400 | `invalid_filter_label` | Label filter wajib diisi, maksimal 40 karakter (historis: tidak lagi dipakai fungsi aktif) | 0149 |
| 400 | `invalid_filter_order` | Urutan harus memuat setiap filter tepat satu kali (historis: tidak lagi dipakai fungsi aktif) | 0149 |
| 400 | `invalid_flag` | Mis. tanda tiket tidak dikenal | 0028–0133 |
| 400 | `invalid_flag_key` | Kunci flag: huruf kecil, angka, titik, garis bawah (2-50) | 0077–0121 |
| 400 | `invalid_flags` | Tanda topik hanya pengaduan atau penipuan | 0127 |
| 400 | `invalid_frequency` | Frekuensi: once, daily, atau every_open | 0119–0184 |
| 400 | `invalid_hash` | Mis. sidik transkrip harus SHA-256 (64 karakter hex) | 0042–0125 |
| 400 | `invalid_hashtag` | Hashtag tidak valid | 0073 |
| 400 | `invalid_health_report` | Mis. probe dan disk harus berupa array (maks 100/20) | 0064–0113 |
| 400 | `invalid_heartbeat` | Mis. interval heartbeat 1–60 detik | 0064–0162 |
| 400 | `invalid_help_link` | Tautan bantuan harus https ke situs bantuan resmi | 0029–0127 |
| 400 | `invalid_hold` | Pilih pasang atau lepas legal hold | 0095 |
| 400 | `invalid_icon` | Mis. ikon tidak dikenal | 0127–0129 |
| 400 | `invalid_identity` | Identity 3–63 karakter huruf, angka, titik, garis bawah, atau strip (TRADE, dijeda) | 0162 |
| 400 | `invalid_image` | Mis. gambar hanya untuk banner popup | 0119–0184 |
| 400 | `invalid_image_ratio` | Rasio gambar: portrait (4:5) atau square (1:1) | 0183–0184 |
| 400 | `invalid_image_thresholds` | Ambang klasifikasi gambar tidak valid | 0079 |
| 400 | `invalid_import` | File tidak berisi kata | 0051 |
| 400 | `invalid_incident` | Mis. judul 3–100 karakter dalam dua bahasa | 0135 |
| 400 | `invalid_instance` | Mis. nama instance tidak valid | 0058–0162 |
| 400 | `invalid_instrument_alias` | Mis. maksimal 10 alias | 0150 |
| 400 | `invalid_instrument_code` | Kode 2–24 karakter: huruf/angka, boleh dipisah tanda strip, diawali huruf | 0150 |
| 400 | `invalid_instrument_description` | Deskripsi maksimal 300 karakter | 0150 |
| 400 | `invalid_instrument_kind` | Jenis instrumen harus index | 0150 |
| 400 | `invalid_instrument_name` | Nama wajib diisi, maksimal 80 karakter | 0150 |
| 400 | `invalid_instrument_order` | Urutan harus memuat setiap instrumen tepat satu kali | 0150 |
| 400 | `invalid_intake` | Mis. maksimal 8 pertanyaan awal | 0134 |
| 400 | `invalid_intake_answers` | Mis. jawaban pertanyaan awal harus objek | 0134 |
| 400 | `invalid_iproxy_addr` | Mis. alamat harus berbentuk tcp://host:port (TRADE, dijeda) | 0162 |
| 400 | `invalid_keywords` | Maksimal 20 kata kunci, masing-masing 40 karakter | 0129–0188 |
| 400 | `invalid_kill_switch` | Status fitur komunitas wajib diisi | 0077–0121 |
| 400 | `invalid_kind` | Mis. jenis harus postingan atau pengumuman | 0013–0150 |
| 400 | `invalid_label_color` | Warna label tidak dikenal | 0118 |
| 400 | `invalid_label_name` | Nama label 1–30 karakter | 0118 |
| 400 | `invalid_label_order` | Urutan harus memuat semua label tepat satu kali | 0118 |
| 400 | `invalid_language` | Bahasa harus id atau en | 0029–0140 |
| 400 | `invalid_legal_body` | Isi dokumen 50–100.000 karakter | 0062 |
| 400 | `invalid_legal_kind` | Jenis dokumen tidak dikenal | 0062–0165 |
| 400 | `invalid_legal_summary` | Ringkasan perubahan maksimal 2.000 karakter | 0062 |
| 400 | `invalid_legal_title` | Judul 3–150 karakter | 0062 |
| 400 | `invalid_level` | Level banner: info, warning, atau critical | 0089–0184 |
| 400 | `invalid_limit` | Batas tiket aktif 1–20 | 0035–0126 |
| 400 | `invalid_link` | Tautan tidak valid (https:// atau deep link dengan skema terdaftar, maks 500 karakter; pilih satu tujuan) | 0057–0184 |
| 400 | `invalid_link_schemes` | Mis. maksimal 5 skema deep link | 0119–0124 |
| 400 | `invalid_login_id` | Login ID tidak valid | 0140 |
| 400 | `invalid_match` | Jenis: domain atau keyword | 0069 |
| 400 | `invalid_message` | Mis. pesan harus milik pengguna ini di room yang sama | 0028–0096 |
| 400 | `invalid_mod_reason` | Alasan: spam, abuse, scam, pump_and_dump, misinformation, atau other | 0093 |
| 400 | `invalid_name` | Mis. nama grup 1-80 karakter | 0008–0146 |
| 400 | `invalid_nodes_report` | Mis. laporan container harus objek dengan maks 200 container | 0168 |
| 400 | `invalid_note` | Mis. catatan maksimal 500 karakter | 0023–0093 |
| 400 | `invalid_notification_type` | Jenis notifikasi tidak dikenal | 0076–0087 |
| 400 | `invalid_options` | Tombol pilihan berisi 2–6 teks, masing-masing 1–40 karakter | 0029–0038 |
| 400 | `invalid_outcome` | Mis. pilih hasil penyelesaian dari daftar | 0028–0038 |
| 400 | `invalid_parent` | Komentar induk tidak valid | 0005 |
| 400 | `invalid_percentage` | Persentase harus 0-100 | 0077–0121 |
| 400 | `invalid_period` | Periode harus today, 7d, atau 30d | 0116 |
| 400 | `invalid_permission` | Mis. izin Berbagi Trade tidak dikenal | 0044–0160 |
| 400 | `invalid_picker_text` | Judul maksimal 80 karakter, petunjuk maksimal 160 karakter | 0127 |
| 400 | `invalid_pin` | Mis. sematkan di stream umum atau stream saham/indeks dengan kode valid | 0057–0150 |
| 400 | `invalid_pin_until` | Mis. batas sematan harus di masa depan | 0057–0150 |
| 400 | `invalid_platform` | Mis. platform harus android, ios, web, windows, macos, atau linux | 0058–0184 |
| 400 | `invalid_policy` | Nilai pengaturan tidak dikenal atau di luar rentang (mis. everyone, following, none) | 0042–0172 |
| 400 | `invalid_policy_call` | Aksi kebijakan tidak dikenal | 0092–0175 |
| 400 | `invalid_poll` | Mis. polling draf harus berupa objek maksimal 4000 byte | 0019–0150 |
| 400 | `invalid_preferences` | Mis. format preferensi notifikasi tidak valid | 0076–0087 |
| 400 | `invalid_priority` | Mis. prioritas 0–1000 | 0023–0184 |
| 400 | `invalid_problem` | Pilih jenis masalah | 0140 |
| 400 | `invalid_profile` | id dan olt_user_id wajib diisi | 0002–0175 |
| 400 | `invalid_push_credentials` | File kredensial Firebase (service account) tidak valid | 0059 |
| 400 | `invalid_push_token` | Token push tidak valid | 0058 |
| 400 | `invalid_query` | Mis. ketik 2–60 karakter | 0057–0165 |
| 400 | `invalid_question` | Pertanyaan 5–200 karakter dalam dua bahasa | 0129–0188 |
| 400 | `invalid_quiet_hours` | Mis. quiet_hours butuh enabled, start, dan end | 0076–0087 |
| 400 | `invalid_range` | Mis. rentang tanggal maksimal 93 hari | 0023–0164 |
| 400 | `invalid_rate_limit` | Batas per menit 1–100000 | 0068 |
| 400 | `invalid_rating` | Mis. nilai tidak sesuai skala survei | 0029–0135 |
| 400 | `invalid_reason` | Mis. alasan banding 10–1000 karakter | 0023–0092 |
| 400 | `invalid_reasons` | Alasan tidak sesuai survei | 0135 |
| 400 | `invalid_received_at` | Waktu terima tidak boleh di masa depan atau terlalu lama (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_reply` | Pesan yang dibalas tidak ada di room ini | 0008–0090 |
| 400 | `invalid_resolution` | Ringkasan penyelesaian 10–4000 karakter (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_result` | Hasil amankan akun tidak valid (historis: tidak lagi dipakai fungsi aktif) | 0029–0033 |
| 400 | `invalid_results` | Mis. hasil janitor harus berupa array | 0058–0095 |
| 400 | `invalid_review` | Hasil klasifikasi tidak valid | 0079 |
| 400 | `invalid_role` | Mis. peran harus admin atau member | 0013–0146 |
| 400 | `invalid_roles` | Mis. peran harus cs_agent, cs_super_admin, compliance, community, product, atau cs_content | 0023–0126 |
| 400 | `invalid_root_cause` | Kategori akar masalah tidak dikenal (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_schedule` | Waktu selesai harus setelah waktu mulai | 0089–0184 |
| 400 | `invalid_scope` | Mis. scope harus global, following, stock, stocks, user, official, atau for_you | 0007–0149 |
| 400 | `invalid_scopes` | Mis. pilih izin notify, notify_broadcast, bot_post, atau gabungannya | 0068–0086 |
| 400 | `invalid_screen` | Asal layar tidak valid | 0029–0134 |
| 400 | `invalid_search` | Pencarian maksimal 100 karakter | 0056 |
| 400 | `invalid_sentiment` | Sentimen: bullish, bearish, atau neutral | 0090–0150 |
| 400 | `invalid_session` | Sesi tidak sesuai dengan room (historis: tidak lagi dipakai fungsi aktif) | 0028–0031 |
| 400 | `invalid_setting` | Mis. peran wajib 2FA harus berupa daftar | 0027–0186 |
| 400 | `invalid_shortcut` | Pintasan 2–32 huruf kecil, angka, - atau _ | 0035–0117 |
| 400 | `invalid_skill` | Skill tidak dikenal | 0035–0127 |
| 400 | `invalid_slow_mode` | Slow mode 0–3600 detik | 0072 |
| 400 | `invalid_smtp` | Mis. host SMTP tidak valid | 0064 |
| 400 | `invalid_snapshot` | Snapshot wajib berupa objek (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_sop` | SOP maksimal 4.000 karakter | 0134 |
| 400 | `invalid_sort` | Urutan tidak valid (feed latest/top, urutan komentar, angka urutan 0–999) | 0035–0155 |
| 400 | `invalid_source` | Sumber bukti tidak dikenal | 0095 |
| 400 | `invalid_state` | Keadaan kasus tidak dikenal | 0042–0125 |
| 400 | `invalid_status` | Mis. status harus open atau reviewed | 0023–0165 |
| 400 | `invalid_stock` | Mis. kode saham tidak valid | 0057–0162 |
| 400 | `invalid_stock_code` | Mis. kode saham atau indeks tidak valid | 0037–0154 |
| 400 | `invalid_stocks` | Maksimal 10 kode saham dengan format valid | 0090–0150 |
| 400 | `invalid_style` | Gaya topik harus normal atau danger | 0127 |
| 400 | `invalid_subject` | Judul 3–200 karakter (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_subscribe_mode` | Mode langganan tidak dikenal (TRADE, dijeda) | 0160 |
| 400 | `invalid_surface` | Tempat: post, comment, stock, group, atau direct | 0069–0176 |
| 400 | `invalid_survey` | Mis. pertanyaan 5–120 karakter dalam dua bahasa | 0135 |
| 400 | `invalid_tags` | Maksimal 10 tag, huruf kecil/angka/-/_ | 0029–0038 |
| 400 | `invalid_target` | Mis. jenis konten harus post, comment, atau message | 0013–0156 |
| 400 | `invalid_target_type` | Jenis konten harus post, comment, atau message | 0084 |
| 400 | `invalid_targets` | Daftar konten harus array, maksimal 200 | 0084 |
| 400 | `invalid_team` | Mis. tim tidak dikenal | 0023–0126 |
| 400 | `invalid_telegram_chat` | Chat ID Telegram tidak valid (maks 5) | 0064 |
| 400 | `invalid_telegram_token` | Token bot Telegram tidak valid | 0064 |
| 400 | `invalid_term` | Istilah N–50 karakter, hanya huruf, angka, dan spasi | 0069 |
| 400 | `invalid_text` | Teks 1–4000 karakter | 0069–0176 |
| 400 | `invalid_ticket` | Tiket tidak sesuai dengan room | 0032–0056 |
| 400 | `invalid_title` | Mis. judul banner 1–120 karakter | 0035–0184 |
| 400 | `invalid_topic` | Mis. topik chat tidak ditemukan | 0028–0188 |
| 400 | `invalid_topic_order` | Urutan harus memuat setiap topik tepat satu kali | 0137 |
| 400 | `invalid_type` | type harus all, posts, users, stocks, atau hashtags | 0073 |
| 400 | `invalid_until` | Mis. batas waktu harus di masa depan | 0072–0162 |
| 400 | `invalid_user` | Tidak bisa membuat DM dengan diri sendiri | 0008–0154 |
| 400 | `invalid_username` | Username 3–30 karakter: huruf, angka, atau garis bawah | 0057–0058 |
| 400 | `invalid_value` | Mis. nilai harus bertipe N (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_verdict` | Pilih putusan: sesuai, perlu tindak lanjut, atau pelanggaran | 0042 |
| 400 | `invalid_version` | Mis. versi harus berformat angka, mis. 2.4.0 | 0077–0184 |
| 400 | `invalid_view` | Tampilan: mine, unassigned, team, complaints, near_deadline, atau pending_customer (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `invalid_window` | window harus 24h atau 7d | 0073–0143 |
| 400 | `invalid_worker` | Nama worker wajib diisi (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `legal_effective_past` | Tanggal berlaku tidak boleh di masa lalu | 0062 |
| 400 | `legal_kind_not_global` | Dokumen Berbagi Trade hanya disetujui di alur Berbagi Trade (TRADE, dijeda) | 0165 |
| 400 | `legal_note_required` | Tulis alasan penolakan (5–1.000 karakter) | 0062 |
| 400 | `missing_source` | Sertakan notification_id, campaign_id, atau broadcast_id | 0088 |
| 400 | `no_official_account` | Belum ada akun resmi aktif untuk mengirim notifikasi. Buat akun resmi di Komunitas → Akun resmi, atau matikan … (historis: tidak lagi dipakai fungsi aktif) | 0180 |
| 400 | `not_cs_agent` | Akses Nasabah hanya untuk akun yang berperan CS | 0047 |
| 400 | `not_editable` | Hanya pesan teks yang bisa diedit | 0154 |
| 400 | `not_eligible` | Pengguna tidak memenuhi syarat moderator room (detail = daftar masalah) | 0093 |
| 400 | `not_group` | Hanya grup yang bisa dihapus | 0154 |
| 400 | `not_room_moderator` | User bukan room_moderator | 0013 |
| 400 | `note_required` | Mis. alasan penolakan 5–500 karakter | 0023–0182 |
| 400 | `notification_title_short` | Judul minimal 3 karakter bila banner dikirim juga sebagai notifikasi (historis: tidak lagi dipakai fungsi aktif) | 0180 |
| 400 | `official_account` | Akun resmi selalu terverifikasi | 0057 |
| 400 | `official_inactive` | Mis. pilih akun resmi yang aktif | 0057–0184 |
| 400 | `official_required` | Izin bot_post wajib memilih akun resmi yang aktif | 0068 |
| 400 | `policy_limit` | Daftar pada kebijakan konten melebihi batas jumlah | 0092 |
| 400 | `policy_no_change` | Mis. draf belum berisi perubahan | 0092 |
| 400 | `protected_account` | Akun staf dan akun resmi tidak bisa diberi sanksi | 0057 |
| 400 | `purpose_required` | Tujuan ekspor 5–500 karakter | 0095 |
| 400 | `query_too_long` | Kata kunci maksimal 100 karakter | 0073 |
| 400 | `query_too_short` | Kata kunci di bawah panjang minimum (search.min_query_length, default 2) | 0073 |
| 400 | `reactions_not_supported` | Reaksi tidak tersedia di chat CS | 0075 |
| 400 | `reason_required` | Mis. alasan wajib diisi (minimal 3 karakter) | 0013–0160 |
| 400 | `reason_too_long` | Mis. alasan maksimal 500 karakter | 0029–0160 |
| 400 | `same_agent` | Sesi sudah ditangani agen ini (historis: tidak lagi dipakai fungsi aktif) | 0028 |
| 400 | `secret_request_blocked` | Balasan cepat tidak boleh meminta OTP, PIN, atau password | 0035–0117 |
| 400 | `share_not_allowed` | Mis. kartu saham tidak bisa dikirim ke chat CS | 0075–0150 |
| 400 | `stock_code_required` | stock_code wajib diisi untuk scope stock | 0007–0149 |
| 400 | `summary_required` | Tulis ringkasan singkat penyelesaian (5–500 karakter) | 0032–0038 |
| 400 | `telegram_incomplete` | Isi token bot dan minimal satu chat ID | 0064 |
| 400 | `term_limit` | Mis. daftar pengecualian sudah mencapai batas 500 | 0069 |
| 400 | `too_many_accounts` | Rekening terlalu banyak (TRADE, dijeda) | 0160 |
| 400 | `too_many_attachments` | Maksimal 10 lampiran per artikel | 0188 |
| 400 | `too_many_events` | Batch event analitik melebihi analytics.max_batch (default 50) | 0078–0085 |
| 400 | `too_many_ids` | Maksimal 100 pesan sekaligus | 0103–0154 |
| 400 | `too_many_rooms` | Maksimal 50 room sekaligus | 0107–0154 |
| 400 | `too_many_stocks` | Terlalu banyak kode saham | 0143–0150 |
| 400 | `too_many_urls` | Maksimal 20 link per permintaan | 0080 |
| 400 | `too_many_users` | Maksimal 1000 pengguna per flag | 0077–0121 |
| 400 | `transfer_target_required` | Pilih tim, topik, atau agen tujuan (historis: tidak lagi dipakai fungsi aktif) | 0028 |
| 400 | `undo_not_supported` | Eskalasi ditindaklanjuti dari antrean laporan | 0093–0096 |
| 400 | `unknown_field` | Ada isian yang tidak dikenal untuk kategori ini (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 400 | `unknown_flag` | Flag tidak dikenal aplikasi | 0091–0121 |
| 400 | `use_kill_switch` | Gunakan kill switch untuk mematikan fitur komunitas | 0077–0121 |
| 400 | `use_leave_room` | Gunakan keluar grup untuk diri sendiri | 0146 |
| 400 | `use_sanctions` | Tindak user lewat admin_api.sanction_user | 0013–0057 |
| 400 | `weak_backup_password` | Mis. password enkripsi minimal 16 karakter | 0065–0112 |
| 401 | `guest_session_expired` | Sesi pengaduan sudah berakhir. Silakan buat pengaduan baru | 0140 |
| 401 | `invalid_key` | API key tidak dikenal, nonaktif, atau sudah dicabut | 0068 |
| 401 | `mfa_required` | Masukkan kode 2FA untuk melanjutkan | 0186 |
| 401 | `not_authenticated` | Butuh sesi login (JWT role authenticated) | 0003–0185 |
| 401 | `session_revoked` | Mis. sesi ini sudah dikeluarkan, silakan masuk lagi | 0013–0186 |
| 403 | `account_rejoin_cooldown` | Akun komunitas ini sudah dihapus | 0177 |
| 403 | `admin_forbidden` | Mis. hanya untuk pesan di room yang Anda moderasi | 0013–0057 |
| 403 | `admin_required` | Mis. pembuat akun harus admin CS aktif | 0013–0035 |
| 403 | `agent_required` | Mis. butuh akun CS aktif | 0027–0186 |
| 403 | `appeal_not_allowed` | Penindakan ini tidak bisa diajukan banding | 0071 |
| 403 | `appeal_reviewer_conflict` | Banding harus ditinjau staf lain, bukan pemberi keputusan awal | 0071 |
| 403 | `blocked` | Mis. tidak bisa berkomentar di post ini | 0005–0170 |
| 403 | `cannot_send` | Tidak bisa mengirim pesan ke room ini | 0008 |
| 403 | `cannot_subscribe` | Tidak bisa berlangganan trader ini (detail = alasan) (TRADE, dijeda) | 0161 |
| 403 | `comments_off` | Komentar untuk postingan ini dinonaktifkan | 0169–0170 |
| 403 | `comments_restricted` | Anda tidak termasuk yang boleh berkomentar di postingan ini | 0169–0170 |
| 403 | `community_forbidden` | Izin komunitas Anda tidak cukup untuk aksi ini | 0057–0071 |
| 403 | `consent_required` | Dokumen hukum wajib belum disetujui (detail = daftar jenis dokumen) | 0014–0062 |
| 403 | `cs_staff_public_edge` | Akun CS hanya bisa dipakai dari domain web CS | 0100–0177 |
| 403 | `cs_staff_room` | Akun CS hanya bisa berada di chat CS | 0028 |
| 403 | `cs_staff_social_forbidden` | Akun CS tidak bisa memakai fitur sosial | 0028–0177 |
| 403 | `customer_data_forbidden` | Mis. anda tidak berwenang membuka data nasabah untuk tiket ini (historis: tidak lagi dipakai fungsi aktif) | 0023–0032 |
| 403 | `customer_required` | Mis. hanya nasabah yang mencatat tayangan banner | 0021–0185 |
| 403 | `dm_not_allowed` | Pengguna ini tidak menerima pesan langsung dari Anda | 0070–0154 |
| 403 | `dm_request_limit` | Tunggu sampai penerima menerima permintaan pesan Anda sebelum mengirim pesan lagi | 0070 |
| 403 | `edit_window_expired` | Konten hanya bisa diedit N menit setelah dibuat (content.edit_minutes, default 15) | 0075 |
| 403 | `evidence_protected` | File bukti karantina hanya dihapus setelah masa simpannya habis | 0095 |
| 403 | `flags_forbidden` | Mis. topik bertanda pengaduan/penipuan hanya bisa dihapus Super Admin | 0127–0139 |
| 403 | `forbidden` | Mis. hanya pemilik yang bisa mengatur komentar postingan ini | 0004–0169 |
| 403 | `four_eyes` | Mis. notifikasi harus disetujui staf lain, bukan pembuatnya | 0023–0182 |
| 403 | `group_admins_only` | Hanya admin yang bisa mengirim pesan di grup ini | 0146 |
| 403 | `group_admins_only_edit` | Hanya admin yang bisa mengubah info grup | 0146 |
| 403 | `guest_disabled` | Pengaduan tanpa login sedang tidak tersedia | 0140 |
| 403 | `ip_not_allowed` | Alamat IP pengirim tidak diizinkan untuk API key ini | 0068 |
| 403 | `moderator_target` | Target adalah moderator room, tidak bisa dimoderasi moderator room | 0093–0096 |
| 403 | `new_account_restricted` | Akun baru belum boleh memakai fitur ini (detail = image atau link) | 0069 |
| 403 | `not_campaign_owner` | Mis. hanya pembuat yang bisa mengubah draf ini | 0057–0184 |
| 403 | `not_eligible` | Tidak memenuhi syarat Berbagi Trade (detail = kode alasan) (TRADE, dijeda) | 0160 |
| 403 | `not_handling` | Anda tidak sedang menangani sesi ini (historis: tidak lagi dipakai fungsi aktif) | 0029 |
| 403 | `not_joined` | Supervisor harus bergabung ke tiket aktif sebelum membalas (historis: tidak lagi dipakai fungsi aktif) | 0032–0037 |
| 403 | `not_member` | Mis. anda bukan anggota room ini | 0008–0154 |
| 403 | `not_owner` | Lokasi file bukan milik pengunggah | 0079 |
| 403 | `not_post_owner` | Mis. hanya pembuat yang bisa mengubah draf ini | 0057–0150 |
| 403 | `not_room_moderator` | Anda bukan moderator room ini | 0093 |
| 403 | `not_ticket_owner` | Mis. label hanya bisa diubah CS pemegang tiket atau Super Admin | 0032–0118 |
| 403 | `not_trader` | Hanya trader yang bisa melihat pelanggannya (TRADE, dijeda) | 0161 |
| 403 | `notes_forbidden` | Anda tidak berwenang menulis catatan untuk nasabah ini | 0029–0033 |
| 403 | `official_no_dm` | Akun resmi tidak menerima pesan langsung. Hubungi CS untuk bantuan | 0144 |
| 403 | `own_poll` | Anda tidak bisa memilih di polling sendiri | 0019 |
| 403 | `policy_locked` | Kepatuhan hanya mengatur tenggat pengaduan, perpanjangan tenggat, dan retensi chat | 0042 |
| 403 | `private_message_forbidden` | Pesan pribadi hanya bisa dibuka bila dilaporkan atau ditandai sistem | 0084–0156 |
| 403 | `protected_account` | Akun staf atau akun resmi tidak bisa dimoderasi moderator room | 0093–0096 |
| 403 | `role_forbidden` | Mis. peran Anda tidak cukup untuk aksi ini | 0027–0186 |
| 403 | `room_disabled` | Room diskusi untuk kode ini sedang ditutup | 0150–0154 |
| 403 | `room_moderator_suspended` | Hak moderator Anda sedang ditangguhkan | 0093 |
| 403 | `room_muted` | Pengguna sedang dibisukan di room (detail = batas waktu UTC) | 0093 |
| 403 | `scope_forbidden` | API key tidak punya izin (scope) yang diminta | 0068 |
| 403 | `self_target` | Pesan sendiri tidak bisa dieskalasi | 0093–0096 |
| 403 | `service_only` | Hanya layanan admin yang bisa membuat akun CS | 0035 |
| 403 | `setting_locked` | Pengaturan ini tidak bisa diubah dari console | 0035–0186 |
| 403 | `social_disabled` | Fitur komunitas sedang dinonaktifkan sementara | 0109 |
| 403 | `staff_forbidden` | Mis. hanya supervisor tim yang bisa menugaskan ulang atau memindahkan tiket (historis: tidak lagi dipakai fungsi aktif) | 0021–0023 |
| 403 | `staff_required` | Butuh akun staf aktif dengan 2FA (historis: tidak lagi dipakai fungsi aktif) | 0021 |
| 403 | `support_room_private` | Chat CS hanya untuk nasabah dan CS | 0028 |
| 403 | `trade_forbidden` | Tidak punya izin Berbagi Trade (TRADE, dijeda) | 0160 |
| 403 | `use_cs_api` | Pesan CS hanya bisa dikirim lewat panel CS | 0028–0056 |
| 403 | `user_banned` | Akun Anda diblokir dari fitur sosial | 0013–0177 |
| 403 | `user_muted` | Akun Anda sedang dibatasi dan belum bisa mengirim konten | 0014–0062 |
| 403 | `user_not_found` | Pengguna target moderasi room tidak ditemukan | 0093–0096 |
| 404 | `account_not_found` | Akun resmi tidak ditemukan | 0057–0058 |
| 404 | `action_not_found` | Aksi moderator tidak ditemukan | 0093–0096 |
| 404 | `activity_not_found` | Aktivitas tidak ditemukan (TRADE, dijeda) | 0163 |
| 404 | `aes_not_configured` | Kunci AES belum diatur (TRADE, dijeda) | 0162 |
| 404 | `agent_not_found` | Mis. akun CS tidak ditemukan | 0032–0186 |
| 404 | `alert_not_found` | Mis. alert tidak ditemukan | 0064–0072 |
| 404 | `appeal_not_found` | Banding tidak ditemukan | 0071 |
| 404 | `article_not_found` | Artikel tidak ditemukan | 0129–0188 |
| 404 | `banned_word_not_found` | Kata tidak ada di daftar | 0051 |
| 404 | `banner_not_found` | Banner tidak ditemukan | 0089–0184 |
| 404 | `campaign_not_found` | Notifikasi tidak ditemukan | 0057–0184 |
| 404 | `category_not_found` | Mis. kategori tidak ditemukan | 0023–0129 |
| 404 | `comment_not_found` | Komentar tidak ditemukan | 0007–0155 |
| 404 | `content_not_found` | Konten tidak ditemukan | 0084–0156 |
| 404 | `customer_not_found` | Nasabah tidak ditemukan | 0023–0056 |
| 404 | `document_not_found` | Dokumen tidak ditemukan | 0014–0062 |
| 404 | `domain_not_found` | Domain tidak ada di daftar | 0069 |
| 404 | `evidence_file_not_found` | File bukti tidak ditemukan | 0095 |
| 404 | `evidence_not_found` | Bukti tidak ditemukan | 0095 |
| 404 | `filter_not_found` | Filter feed tidak ditemukan | 0149–0180 |
| 404 | `flag_not_found` | Mis. penanda tidak ditemukan atau sudah ditinjau | 0077–0164 |
| 404 | `holiday_not_found` | Hari libur tidak ditemukan | 0023–0035 |
| 404 | `incident_not_found` | Mis. pengumuman tidak ditemukan | 0135 |
| 404 | `instrument_not_found` | Instrumen tidak ditemukan | 0150 |
| 404 | `key_not_found` | API key tidak ditemukan | 0068–0101 |
| 404 | `label_not_found` | Label tidak ditemukan | 0118 |
| 404 | `legal_draft_not_found` | Draf tidak ditemukan | 0062 |
| 404 | `letter_not_found` | Surat tidak ditemukan (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 404 | `media_review_not_found` | Gambar tidak ada di antrean | 0079 |
| 404 | `member_not_found` | Orang ini bukan anggota grup | 0146 |
| 404 | `message_not_found` | Mis. pesan tidak ditemukan | 0075–0122 |
| 404 | `moderator_not_found` | Moderator room tidak ditemukan | 0093 |
| 404 | `no_push_devices` | Pengguna ini belum punya perangkat terdaftar untuk push | 0058 |
| 404 | `not_excluded` | Mis. saham tidak ada di daftar dikecualikan (TRADE, dijeda) | 0160–0162 |
| 404 | `not_found` | Mis. pesan tidak ditemukan | 0004–0154 |
| 404 | `not_member` | Anda bukan anggota room ini | 0008–0157 |
| 404 | `notice_not_found` | Mis. informasi ini tidak tersedia | 0182–0184 |
| 404 | `offer_not_found` | Penawaran tidak ditemukan (historis: tidak lagi dipakai fungsi aktif) | 0029 |
| 404 | `policy_change_not_found` | Permintaan perubahan kebijakan tidak ditemukan | 0092 |
| 404 | `policy_draft_not_found` | Belum ada draf perubahan kebijakan | 0092 |
| 404 | `policy_version_not_found` | Versi kebijakan tidak ditemukan | 0092 |
| 404 | `poll_not_found` | Polling tidak ditemukan | 0019 |
| 404 | `post_not_found` | Mis. post tidak ditemukan | 0005–0169 |
| 404 | `profile_not_found` | Profil tidak ditemukan | 0068–0160 |
| 404 | `push_credentials_missing` | Belum ada kredensial Firebase | 0059 |
| 404 | `quick_reply_not_found` | Balasan cepat tidak ditemukan | 0035–0117 |
| 404 | `request_not_found` | Mis. permintaan tidak ditemukan | 0023–0161 |
| 404 | `room_not_found` | Mis. room tidak ditemukan | 0008–0154 |
| 404 | `session_not_found` | Sesi tidak ditemukan (historis: tidak lagi dipakai fungsi aktif) | 0028–0030 |
| 404 | `setting_not_found` | Pengaturan tidak dikenal | 0013–0160 |
| 404 | `staff_not_found` | Staf aktif tidak ditemukan (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 404 | `stock_not_found` | Kode saham tidak dikenal (historis: tidak lagi dipakai fungsi aktif) | 0008 |
| 404 | `subscription_not_found` | Langganan tidak ditemukan (TRADE, dijeda) | 0161 |
| 404 | `target_not_found` | Mis. sanksi atau konten tidak ditemukan | 0006–0071 |
| 404 | `term_not_found` | Mis. istilah tidak ada di daftar | 0069 |
| 404 | `ticket_not_found` | Tiket tidak ditemukan | 0022–0141 |
| 404 | `topic_not_found` | Topik tidak ditemukan | 0134–0139 |
| 404 | `trader_not_found` | Trader tidak ditemukan (TRADE, dijeda) | 0160–0165 |
| 404 | `transfer_not_found` | Permintaan transfer tidak ditemukan | 0032–0038 |
| 404 | `user_not_found` | Mis. akun tidak ditemukan | 0008–0174 |
| 404 | `version_not_found` | Versi tidak ditemukan | 0129–0188 |
| 409 | `action_undone` | Aksi ini sudah dibatalkan | 0093–0096 |
| 409 | `agent_disabled` | Aktifkan akun dulu sebelum mereset password | 0039 |
| 409 | `agent_not_online` | Ubah status Anda ke Online untuk mengambil tiket | 0032–0038 |
| 409 | `agent_offline` | Anda sedang Offline. Ubah ke Online dulu untuk membalas nasabah | 0041 |
| 409 | `agent_unavailable` | Mis. CS tujuan tidak Online atau batas tiketnya penuh | 0028–0038 |
| 409 | `alert_channel_disabled` | Mis. aktifkan dan simpan kanal Telegram dulu | 0064 |
| 409 | `alert_reviewed` | Alert ini sudah ditinjau | 0072 |
| 409 | `already_applied` | Pengajuan atau keikutsertaan masih berjalan (TRADE, dijeda) | 0160 |
| 409 | `already_decided` | Permintaan sudah diputuskan (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `already_escalated` | Pesan ini sudah dieskalasi ke staf | 0093 |
| 409 | `already_exists` | File dengan nama yang sama sudah ada | 0079 |
| 409 | `already_extended` | Tenggat pengaduan ini sudah pernah diperpanjang | 0042 |
| 409 | `already_flagged` | Tiket sudah bertanda ini | 0133 |
| 409 | `already_moderated` | Pesan ini sudah dimoderasi | 0093 |
| 409 | `already_moderator` | Pengguna ini sudah menjadi moderator room ini | 0093 |
| 409 | `already_muted` | Pengguna ini sudah dibisukan lebih lama | 0093–0096 |
| 409 | `already_subscribed` | Langganan sudah ada (TRADE, dijeda) | 0161 |
| 409 | `already_voted` | Anda sudah memilih di polling ini | 0019 |
| 409 | `appeal_decided` | Banding ini sudah diputuskan | 0071 |
| 409 | `appeal_exists` | Banding untuk ini sudah pernah diajukan | 0071 |
| 409 | `appeal_not_allowed` | Sanksi atau konten ini tidak sedang dibatasi | 0071 |
| 409 | `backup_not_configured` | Atur tujuan backup dulu | 0065 |
| 409 | `backup_password_locked` | Password enkripsi repositori yang sudah ada tidak bisa diganti. Pakai folder atau bucket baru | 0065–0112 |
| 409 | `banned_word_exists` | Kata ini sudah ada di daftar | 0051 |
| 409 | `cannot_rate` | Mis. tiket ini tidak bisa diberi nilai | 0029–0135 |
| 409 | `cannot_subscribe` | Langganan ke trader tidak bisa dibuat (detail = alasan) (TRADE, dijeda) | 0161 |
| 409 | `code_taken` | Kode kategori sudah dipakai | 0129 |
| 409 | `complaint_needs_response` | Mis. pengaduan diselesaikan dengan tanggapan resmi (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `complaint_priority` | Pengaduan minimal berprioritas P2 (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `confirmation_required` | Perubahan cakupan data perlu dikonfirmasi (TRADE, dijeda) | 0160 |
| 409 | `deadline_not_running` | Tenggat belum berjalan atau sedang dijeda (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `deadline_passed` | Mis. tenggat sudah lewat. Perpanjangan harus diberitahukan sebelum tenggat | 0023–0042 |
| 409 | `documents_already_complete` | Dokumen sudah dinyatakan lengkap (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `documents_not_requested` | Dokumen belum pernah diminta untuk pengaduan lisan ini (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `draft_conflict` | Draf sudah diubah di perangkat lain. Muat ulang draf | 0090–0150 |
| 409 | `draft_limit` | Maksimal 20 draf. Hapus draf lama terlebih dahulu | 0090–0150 |
| 409 | `duplicate_label` | Nama label sudah dipakai | 0118 |
| 409 | `duplicate_shortcut` | Pintasan sudah dipakai balasan lain | 0035–0117 |
| 409 | `edit_window_closed` | Pesan hanya bisa diedit N menit setelah dikirim (content.edit_minutes, default 15) | 0154 |
| 409 | `evidence_file_not_copied` | File bukti belum tersalin | 0095 |
| 409 | `evidence_immutable` | Mis. bukti karantina tidak bisa dihapus massal | 0095 |
| 409 | `evidence_pending` | File sedang diamankan sebagai bukti, coba lagi sebentar | 0095 |
| 409 | `evidence_retained` | Mis. bukti masih dalam masa simpan atau legal hold | 0095 |
| 409 | `extension_disabled` | Perpanjangan tenggat sedang dimatikan di Kebijakan | 0042 |
| 409 | `extension_limit` | Batas perpanjangan sudah tercapai (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `four_eyes_same_agent` | Persetujuan kedua harus dari staf lain (TRADE, dijeda) | 0160 |
| 409 | `hold_unchanged` | Status legal hold bukti sudah sama dengan yang diminta | 0095 |
| 409 | `instrument_alias_taken` | Alias sudah dipakai sebagai kode atau alias instrumen lain | 0150 |
| 409 | `instrument_code_taken` | Kode ini sudah dipakai sebagai alias instrumen lain | 0150 |
| 409 | `invalid_status` | Mis. notifikasi ini tidak bisa diubah lagi | 0057–0184 |
| 409 | `invalid_transition` | Mis. tiket berstatus N tidak bisa menjadi N | 0022–0049 |
| 409 | `key_revoked` | API key yang sudah dicabut tidak bisa diubah | 0068–0101 |
| 409 | `label_inactive` | Label sudah tidak aktif | 0118 |
| 409 | `label_limit` | Maksimal 50 label aktif | 0118 |
| 409 | `last_active_topic` | Minimal harus ada satu topik aktif | 0139 |
| 409 | `legal_already_effective` | Dokumen sudah berlaku dan tidak bisa dibatalkan | 0062 |
| 409 | `legal_draft_locked` | Mis. draf yang sedang ditinjau atau sudah terbit tidak bisa diubah | 0062 |
| 409 | `legal_draft_not_pending` | Draf tidak sedang menunggu persetujuan | 0062 |
| 409 | `legal_scheduled_exists` | Sudah ada versi terjadwal untuk dokumen ini. Batalkan jadwalnya dulu | 0062 |
| 409 | `media_review_decided` | Gambar ini sudah diputuskan | 0079 |
| 409 | `no_active_accounts` | Mis. tidak ada rekening aktif yang bisa dibagikan (TRADE, dijeda) | 0160 |
| 409 | `no_change` | Jenis tiket sudah sama (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `not_a_complaint` | Mis. tiket ini bukan pengaduan (historis: tidak lagi dipakai fungsi aktif) | 0022–0023 |
| 409 | `not_active` | Mis. berbagi trade tidak sedang aktif (TRADE, dijeda) | 0160 |
| 409 | `not_complaint` | Hanya pengaduan yang punya tenggat | 0042 |
| 409 | `not_paused` | Berbagi trade tidak sedang dijeda (TRADE, dijeda) | 0160 |
| 409 | `not_pending` | Pengajuan tidak sedang menunggu peninjauan (TRADE, dijeda) | 0160 |
| 409 | `not_sharing` | Mis. belum terdaftar sebagai trader (TRADE, dijeda) | 0160 |
| 409 | `not_suspended` | Trader tidak sedang ditangguhkan (TRADE, dijeda) | 0160 |
| 409 | `nothing_to_undo` | Tidak ada yang perlu dibatalkan | 0093–0096 |
| 409 | `objection_window_passed` | Keberatan hanya bisa diajukan dalam batas waktu setelah tanggapan akhir (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `offer_closed` | Penawaran sudah tidak berlaku (historis: tidak lagi dipakai fungsi aktif) | 0029 |
| 409 | `offer_expired` | Waktu menerima penawaran sudah habis (historis: tidak lagi dipakai fungsi aktif) | 0029 |
| 409 | `official_inactive` | Akun resmi untuk bot ini nonaktif | 0068 |
| 409 | `parent_deleted` | Komentar yang dibalas sudah dihapus | 0005 |
| 409 | `policy_change_decided` | Permintaan ini sudah diputuskan | 0092 |
| 409 | `policy_no_change` | Isi perubahan ini sudah berlaku. Tarik atau tolak permintaannya | 0092 |
| 409 | `policy_review_required` | Perubahan kebijakan konten harus lewat draf dan disetujui staf Kepatuhan lain | 0092 |
| 409 | `policy_stale` | Kebijakan sudah berubah sejak pemulihan ini diajukan. Ajukan ulang pemulihan dari riwayat versi | 0092 |
| 409 | `poll_not_editable` | Postingan berisi polling tidak bisa diedit | 0075 |
| 409 | `profile_exists` | Akun ini sudah punya profil nasabah, pakai akun staf terpisah | 0027–0120 |
| 409 | `push_project_changed` | project_id kredensial Firebase berbeda dari yang tersimpan | 0059 |
| 409 | `quick_reply_limit` | Maksimal 50 balasan cepat pribadi | 0117 |
| 409 | `reclassification_pending` | Masih ada permintaan ubah klasifikasi yang menunggu (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `reopen_window_passed` | Tiket tidak bisa dibuka kembali. Buat tiket baru (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `risk_outdated` | Pernyataan risiko sudah berubah, baca ulang (TRADE, dijeda) | 0161 |
| 409 | `risk_unavailable` | Pernyataan risiko belum tersedia (TRADE, dijeda) | 0161 |
| 409 | `room_moderator_limit` | Jumlah moderator room ini sudah maksimal | 0093 |
| 409 | `session_closed` | Sesi sudah selesai (historis: tidak lagi dipakai fungsi aktif) | 0028 |
| 409 | `session_not_active` | Hanya sesi aktif yang bisa ditransfer (historis: tidak lagi dipakai fungsi aktif) | 0028 |
| 409 | `session_not_waiting` | Sesi tidak sedang menunggu agen (historis: tidak lagi dipakai fungsi aktif) | 0028 |
| 409 | `stale_ticket` | Tiket sudah berubah. Muat ulang lalu coba lagi | 0032 |
| 409 | `stale_version` | Data sudah diubah staf lain. Muat ulang lalu coba lagi | 0057 |
| 409 | `subscription_limit` | Jumlah trader yang diikuti sudah maksimum (TRADE, dijeda) | 0161 |
| 409 | `support_message_locked` | Mis. pesan di chat CS tidak bisa diubah | 0028–0154 |
| 409 | `term_exists` | Mis. istilah ini sudah ada di daftar | 0069 |
| 409 | `terms_outdated` | Syarat & Ketentuan sudah berubah, baca ulang (TRADE, dijeda) | 0160 |
| 409 | `ticket_active` | Transkrip tersedia setelah tiket selesai | 0136 |
| 409 | `ticket_closed` | Tiket sudah selesai; tidak bisa dibalas atau diubah | 0023–0056 |
| 409 | `ticket_label_limit` | Maksimal 5 label per tiket | 0118 |
| 409 | `ticket_limit` | Batas tiket aktif agen sudah penuh | 0032–0038 |
| 409 | `ticket_not_active` | Mis. pengaduan ini sudah selesai. Buat pengaduan baru bila masih perlu bantuan | 0032–0140 |
| 409 | `ticket_not_open` | Tiket ini tidak lagi terbuka | 0032–0038 |
| 409 | `ticket_taken` | Tiket sudah diambil CS lain | 0032–0038 |
| 409 | `topic_in_use` | Topik sudah dipakai tiket sehingga tidak bisa dihapus; nonaktifkan saja | 0139 |
| 409 | `transfer_closed` | Permintaan transfer sudah tidak berlaku | 0032–0038 |
| 409 | `transfer_pending` | Masih ada permintaan transfer yang menunggu jawaban | 0032–0038 |
| 409 | `use_objection` | Untuk pengaduan, ajukan keberatan atas tanggapan (historis: tidak lagi dipakai fungsi aktif) | 0023 |
| 409 | `user_moderator_limit` | Pengguna ini sudah memoderasi jumlah room maksimal | 0093 |
| 409 | `username_taken` | Username sudah dipakai | 0057–0058 |
| 409 | `username_unavailable` | Gagal menentukan username unik | 0002–0175 |
| 409 | `version_conflict` | Artikel sudah diubah orang lain, muat ulang dulu | 0129–0188 |
| 422 | `contact_blocked` | Nomor kontak atau tautan grup chat tidak boleh dibagikan di sini | 0069 |
| 422 | `content_blocked` | Konten mengandung kata atau frasa yang tidak diizinkan | 0002–0069 |
| 422 | `duplicate_content` | Konten yang sama sudah dikirim berulang kali. Coba lagi beberapa menit lagi | 0014 |
| 422 | `duplicate_poll_option` | Pilihan polling tidak boleh sama | 0019 |
| 422 | `invalid_characters` | Teks mengandung karakter yang tidak diizinkan | 0014 |
| 422 | `invalid_poll_duration` | Durasi polling 5 menit sampai 7 hari | 0019 |
| 422 | `invalid_poll_option` | Mis. setiap pilihan polling berisi 1 sampai 40 karakter | 0019 |
| 422 | `invalid_poll_options` | Polling harus punya 2 sampai 4 pilihan | 0019 |
| 422 | `link_blocked` | Tautan ini tidak diizinkan | 0069 |
| 422 | `poll_closed` | Polling sudah berakhir | 0019 |
| 422 | `poll_with_attachments` | Polling tidak bisa digabung dengan lampiran | 0019 |
| 422 | `publish_failed` | Postingan gagal diterbitkan | 0068 |
| 422 | `too_many_links` | Tautan melebihi content.max_links per konten (default 3) | 0014 |
| 422 | `too_many_mentions` | Mention melebihi content.max_mentions per konten (default 10) | 0014 |
| 422 | `too_many_muted_keywords` | Batas kata yang di-mute sudah tercapai | 0015 |
| 422 | `too_many_stock_tags` | Kode saham melebihi content.max_stock_tags per konten (default 10) | 0014 |
| 429 | `command_rate_limited` | Tunggu satu menit sebelum perintah berikutnya (TRADE, dijeda) | 0162 |
| 429 | `guest_login_limit` | Pengaduan untuk Login ID ini sudah banyak hari ini. Coba lagi besok atau hubungi kantor cabang | 0140 |
| 429 | `rate_limited` | Batas laju aksi terlampaui (private.rate_limits; detail menyebut batas dan jendela) | 0002–0140 |
| 429 | `too_many_requests` | Tunggu sebentar sebelum mengirim uji lagi | 0064 |
| 500 | `template_missing` | Template surat resmi belum tersedia (historis: tidak lagi dipakai fungsi aktif) | 0022 |
| 503 | `social_disabled` | Fitur komunitas sedang dinonaktifkan sementara (historis: tidak lagi dipakai fungsi aktif) | 0077 |

#### 11.2.4 Kode error layanan Go (non-database)

Layanan Go menjawab error dengan body JSON sendiri. auth-bridge, integration, dan nasabah-gateway memakai `{"error": "<kode>", "message": "..."}`; media memakai `{"code": "<kode>", "message": "..."}`. Kolom "Kirim ulang" hanya diisi bila sumber menyatakannya.

| Layanan | Status | Kode | Arti singkat | Sumber |
|---|---|---|---|---|
| auth-bridge | 400 | `invalid_request` | Body bukan `{"token": "..."}` atau token kosong | services/auth-bridge/README.md |
| auth-bridge | 401 | `invalid_token` | Token sosial tidak sah (tanda tangan, `iss`/`aud`, kedaluwarsa, umur > `OLT_JWT_MAX_TTL`) | services/auth-bridge/README.md |
| auth-bridge | 403 | `user_banned` | User sedang di-ban dari fitur sosial | services/auth-bridge/README.md |
| auth-bridge | 403 | `account_rejoin_cooldown` | Akun komunitas baru dihapus dan masih dalam jeda bergabung lagi (`account.rejoin_cooldown_hours`, bawaan 72 jam); body memuat `retry_at`, header `Retry-After` (0175) | services/auth-bridge/README.md, server.go |
| auth-bridge | 429 | `rate_limited` | Melebihi batas per IP atau per user OLT; header `Retry-After` | services/auth-bridge/README.md |
| auth-bridge | 500 | `internal_error` | Kesalahan internal | services/auth-bridge/internal/server/server.go |
| auth-bridge | 502 | `exchange_failed` | Gagal upsert profil setelah retry | services/auth-bridge/README.md |
| auth-bridge | 503 | `olt_unavailable` | Hanya mode `websocket` (lama): OLT tidak menjawab atau circuit breaker terbuka | services/auth-bridge/README.md |
| media | 400 | `bucket_not_allowed` | Bucket bukan `avatars`, `attachments`, `cs-documents`, atau `cs-videos` | services/media/README.md |
| media | 400 | `invalid_path` | Path tidak memenuhi aturan (1–6 segmen, `[A-Za-z0-9._-]{1,128}`, maks 400 karakter) | services/media/README.md |
| media | 400 | `empty_file` | Body kosong | services/media/README.md |
| media | 400 | `invalid_request` | Body tidak bisa dibaca | services/media/README.md |
| media | 401 | `invalid_token` | JWT tidak ada/salah/kedaluwarsa/bukan `authenticated` | services/media/README.md |
| media | 403 | `kind_disabled` | Dokumen atau video chat CS sedang dimatikan Super Admin | services/media/README.md |
| media | 403 | `upload_forbidden` | Ditolak RLS storage | services/media/README.md |
| media | 404 | `not_found` | Metode/path selain `POST /object/...` | services/media/README.md |
| media | 408 | `request_timeout` | Body tidak selesai dikirim dalam `REQUEST_TIMEOUT` | services/media/README.md |
| media | 409 | `already_exists` | Objek dengan path itu sudah ada | services/media/README.md |
| media | 413 | `file_too_large` | Melebihi batas bucket atau kebijakan lampiran | services/media/README.md |
| media | 415 | `unsupported_type` | Isi file tidak dikenal, tidak diizinkan di bucket, atau formatnya dimatikan | services/media/README.md |
| media | 422 | `invalid_image` | Struktur gambar rusak | services/media/README.md |
| media | 422 | `image_too_large` | Sisi > 10000 px, > 40 MP, atau GIF > 500 frame | services/media/README.md |
| media | 422 | `invalid_pdf` | Header/`%%EOF` tidak ada atau object stream tidak bisa diperiksa | services/media/README.md |
| media | 422 | `pdf_encrypted` | PDF terenkripsi atau berpassword | services/media/README.md |
| media | 422 | `pdf_active_content` | PDF berisi JavaScript, Launch, file tertanam, RichMedia, atau XFA | services/media/README.md |
| media | 422 | `office_macro` | Dokumen Office berisi makro | services/media/README.md |
| media | 422 | `office_unsafe` | Dokumen Office berisi ActiveX, OLE, file program, atau relasi eksternal berbahaya | services/media/README.md |
| media | 422 | `archive_bomb` | Dokumen Office melewati batas entri, ukuran terurai, atau rasio kompresi | services/media/README.md |
| media | 422 | `invalid_text` | Nama `.txt`/`.csv` tetapi isinya bukan teks UTF-8 | services/media/README.md |
| media | 422 | `invalid_video` | Container/codec/stream video tidak didukung, rusak, atau thumbnail gagal | services/media/README.md |
| media | 422 | `video_too_long` | Durasi melewati `max_seconds` kebijakan (bawaan dan maks 120 detik) | services/media/README.md |
| media | 422 | `malware_detected` | ClamAV mendeteksi malware (termasuk EICAR) | services/media/README.md |
| media | 422 | `image_blocked` | Classifier menilai gambar melanggar, atau gambar perlu ditinjau tetapi tujuannya bucket publik `avatars` | services/media/README.md |
| media | 429 | `too_many_uploads` | Batas upload harian dari database | services/media/README.md |
| media | 499 | `canceled` | Klien memutus koneksi (hanya tercatat di log/metrik) | services/media/internal/server/errors.go |
| media | 500 | `internal_error` | Gagal membuat JWT, atau `ffmpeg`/`ffprobe` tidak ada/timeout | services/media/README.md |
| media | 502 | `storage_error` | Error lain dari storage | services/media/README.md |
| media | 502 | `storage_unavailable` | Storage tidak bisa dihubungi atau timeout | services/media/README.md |
| media | 503 | `busy` | Semua slot pemrosesan terpakai > 5 detik; `Retry-After: 2` | services/media/README.md |
| media | 503 | `classifier_unavailable` | Classifier NSFW tidak bisa dipakai (fail closed); `Retry-After: 2` | services/media/README.md |
| media | 503 | `moderation_unavailable` | Ambang moderasi gambar belum termuat atau catatan penahanan gagal disimpan | services/media/README.md |
| media | 503 | `policy_unavailable` | Kebijakan lampiran chat CS belum termuat | services/media/README.md |
| media | 503 | `scanner_unavailable` | clamd tidak bisa dihubungi/timeout/error (fail closed); `Retry-After: 2` | services/media/README.md |
| integration | 400 | `invalid_json` | Body bukan JSON. Kirim ulang: tidak | docs/integration/README.md |
| integration | 400 | `invalid_batch` | `messages` bukan array 1–500 atau `posts` bukan array 1–50. Kirim ulang: tidak | docs/integration/README.md |
| integration | 401 | `missing_key` | API key integrasi tidak ada | docs/integration/README.md |
| integration | 401 | `invalid_key` | Key salah, nonaktif, atau dicabut | docs/integration/README.md |
| integration | 403 | `ip_not_allowed` | IP pengirim di luar `allowed_cidrs` key | docs/integration/README.md |
| integration | 403 | `scope_forbidden` | Key tanpa izin `notify` (untuk `/notify/messages`) atau `bot_post` (untuk `/bot/posts`) | docs/integration/README.md |
| integration | 404 | `not_found` | Path lain | services/integration/README.md |
| integration | 405 | `method_not_allowed` | Metode lain | services/integration/README.md |
| integration | 413 | `body_too_large` | Body > 2 MiB. Pecah batch | docs/integration/README.md |
| integration | 429 | `rate_limited` | Batas `rate_limit_per_minute` key tercapai; `Retry-After`. Kirim ulang: ya | docs/integration/README.md |
| integration | 429 | `too_many_auth_failures` | Terlalu banyak key salah/hilang dari satu IP (`AUTH_FAILURES_PER_MINUTE`, bawaan 30). Kirim ulang: ya | docs/integration/README.md |
| integration | 500 | `internal_error` | Kesalahan internal | services/integration |
| integration | 502 | kode lain | Respons tak terduga dari database. Kirim ulang: ya, dengan backoff | docs/integration/README.md |
| integration | 503 | `unavailable` | Database tidak terjangkau; `Retry-After: 5`. Kirim ulang batch yang sama | docs/integration/README.md |
| integration | 503 | `busy` | Slot database penuh > 5 detik; `Retry-After: 2` | services/integration/README.md |
| integration (per pesan) | 200 | `invalid_message`, `invalid_id`, `invalid_cust_id`, `invalid_target`, `invalid_kind`, `invalid_title`, `invalid_body`, `invalid_data`, `invalid_ttl`, `invalid_collapse_key`, `invalid_priority`, `invalid_channels`, `invalid_category`, `scope_forbidden` | Isi `error` pada hasil per pesan berstatus `invalid` (batch tetap 200) | docs/integration/README.md |
| integration (per postingan bot) | 200 | `invalid_id`, `invalid_body`, kode kebijakan konten (mis. `content_blocked`, `too_many_links`) | Hasil per postingan berstatus `invalid`/`rejected` | docs/integration/README.md |
| nasabah-gateway | 400 | `invalid_query` | Parameter query tidak dikenal atau tidak lolos validasi | docs/nasabah/README.md |
| nasabah-gateway | 400 | `invalid_body`, `invalid_login_id`, `invalid_account_link`, `too_many_accounts`, `links_client_only`, `invalid_user_status`, `status_reason_required`, `invalid_decision`, `invalid_approval`, `invalid_opening` | Guard isi permintaan (LoginId, tautan rekening maks 255 karakter, status 0–3, alasan 10–200 karakter, dll.) | docs/nasabah/README.md, services/nasabah-gateway |
| nasabah-gateway | 401 | `unauthorized` | Token sesi console tidak ada atau kedaluwarsa | services/nasabah-gateway/internal/gateway/gateway.go |
| nasabah-gateway | 403 | `no_access` | Akun console tidak punya izin Akun Nasabah (termasuk bila 2FA wajib tetapi sesi belum `aal2`, 0186) | services/nasabah-gateway, 0186 |
| nasabah-gateway | 403 | `permission_denied` | Izin akun tidak mencakup aksi itu | services/nasabah-gateway |
| nasabah-gateway | 403 | `demo_only`, `self_approval` | Izin demo hanya untuk akun demo; pengajuan sendiri butuh `online_user.approve_own` | services/nasabah-gateway |
| nasabah-gateway | 404 | `route_not_found` | Rute di luar daftar izin `/online/*` | docs/nasabah/README.md |
| nasabah-gateway | 404 | `customer_not_found`, `approval_not_found`, `opening_account_not_found` | Data yang dirujuk tidak ada di csAdmin | services/nasabah-gateway |
| nasabah-gateway | 409 | `customer_email_missing` | Reset password/PIN ditolak karena nasabah belum punya email | docs/nasabah/README.md |
| nasabah-gateway | 500 | `encode_failed` | Respons tidak bisa di-encode | services/nasabah-gateway |
| nasabah-gateway | 502 | `upstream_outdated` | csAdmin menjawab 404 tanpa JSON (rute belum ada di csAdmin) | docs/nasabah/README.md |
| nasabah-gateway | 502 | `upstream_unavailable` | csAdmin tidak terjangkau | services/nasabah-gateway |
| nasabah-gateway | 503 | `not_configured` | Alamat/client id csAdmin atau kunci integrasi belum ada | docs/nasabah/README.md |
| nasabah-gateway | 503 | `integration_refused` | csAdmin menolak kunci integrasi gateway | docs/nasabah/README.md |
| nasabah-gateway | 503 | `access_unavailable` | Pemeriksaan izin ke database tidak bisa dilakukan | services/nasabah-gateway |

### 11.3 Daftar RPC

#### 11.3.0 Cara daftar dibuat dan cara membacanya

Daftar ini dibuat otomatis dengan skrip yang membaca `supabase/migrations/0001…0188` berurutan (tidak peka huruf besar/kecil) dan mensimulasikan:

- `create function` / `create or replace function <skema>.<nama>(...)` per tanda tangan (tipe argumen dinormalkan, parameter `out` diabaikan); `drop function` dan `drop schema ... cascade` menghapus fungsi;
- `grant`/`revoke execute on function ...` dan `grant`/`revoke ... on all functions in schema ...`, ditambah hak bawaan saat fungsi dibuat: skema `public` = `PUBLIC` + `authenticated` + `service_role` (default privileges Supabase; `anon` dicabut lewat `alter default privileges` di 0002), `cs_api` = `PUBLIC` (bawaan Postgres), `admin_api` = tanpa hak sejak 0013.

Yang dicantumkan: fungsi yang masih ada di skema `public`, `cs_api`, dan `admin_api`, bukan fungsi trigger (`returns trigger`), dan masih punya `execute` untuk minimal satu dari `authenticated`, `anon`, `service_role`. Hasil akhir tidak ada fungsi yang masih memberi `execute` ke `PUBLIC`.

| Kolom | Isi |
|---|---|
| Migrasi terakhir | Migrasi bernomor tertinggi yang mendefinisikan fungsi itu (yang berlaku) |
| Grant | Peran yang punya `execute` menurut simulasi. `service_role` saja = hanya dipanggil layanan internal (notifier, media, janitor, sentinel, backup, integration, auth-bridge, nasabah-gateway, link-preview) dengan JWT `service_role`. Untuk `cs_api`, hak `authenticated` tidak berarti semua pengguna boleh: fungsi memeriksa peran staf di dalamnya (mis. `cs.has_role`, `cs.current_agent_id`) dan di domain publik hanya 27 RPC nasabah yang dirutekan (bagian 5.2) |
| Modul | Pemetaan perkiraan ke kode modul SRS berdasarkan nama fungsi; perlu konfirmasi bila dipakai untuk penelusuran formal |

Ringkasan: 482 fungsi (public 148, cs_api 315, admin_api 19). Sebaran grant: `cs_api` 302 hanya `authenticated`, 8 hanya `service_role`, 5 `authenticated` + `anon` (RPC pengaduan tamu `guest_*`); `public` 114 `authenticated` + `service_role`, 33 hanya `service_role`, 1 juga `anon` (`get_client_config`); `admin_api` 19 `authenticated`.

Catatan:

- `admin_api` (API moderasi lama, 0013) tidak termasuk `PGRST_DB_SCHEMAS` (`public,graphql_public,cs_api`, docker/compose.yml), sehingga fungsinya tidak bisa dipanggil lewat `/rest/v1`. Dicantumkan karena masih punya grant (perlu konfirmasi apakah masih dipakai).
- Fungsi bermodul TRADE milik fitur Berbagi Trade yang dijeda; RPC-nya tetap terpasang di database.
- Tanda tangan ditulis hanya untuk nama yang punya lebih dari satu overload.

#### 11.3.1 Skema `public` (148 fungsi)

| Skema | Fungsi | Migrasi terakhir | Grant | Modul |
|---|---|---|---|---|
| public | `accept_legal_document` | 0014 | authenticated, service_role | AKUN |
| public | `add_room_members` | 0146 | authenticated, service_role | CHAT |
| public | `alert_channels` | 0067 | service_role | OPS |
| public | `alert_claim` | 0064 | service_role | OPS |
| public | `alert_report` | 0064 | service_role | OPS |
| public | `backup_config` | 0112 | service_role | OPS |
| public | `backup_heartbeat` | 0065 | service_role | OPS |
| public | `backup_record` | 0065 | service_role | OPS |
| public | `cancel_trade_subscription` | 0161 | authenticated, service_role | TRADE |
| public | `create_appeal` | 0071 | authenticated, service_role | MOD |
| public | `create_comment` | 0014 | authenticated, service_role | KOM |
| public | `create_group_room` | 0144 | authenticated, service_role | CHAT |
| public | `create_post` | 0169 | authenticated, service_role | KOM |
| public | `decide_trade_subscription` | 0161 | authenticated, service_role | TRADE |
| public | `delete_comment` | 0005 | authenticated, service_role | KOM |
| public | `delete_group` | 0154 | authenticated, service_role | CHAT |
| public | `delete_message` | 0031 | authenticated, service_role | CHAT |
| public | `delete_my_account` | 0174 | authenticated, service_role | AKUN |
| public | `delete_post` | 0004 | authenticated, service_role | KOM |
| public | `delete_post_draft` | 0090 | authenticated, service_role | KOM |
| public | `edit_comment` | 0075 | authenticated, service_role | KOM |
| public | `edit_message` | 0154 | authenticated, service_role | CHAT |
| public | `edit_post` | 0075 | authenticated, service_role | KOM |
| public | `evidence_copy_claim` | 0095 | service_role | OPS |
| public | `evidence_copy_report` | 0095 | service_role | OPS |
| public | `export_my_data` | 0172 | authenticated, service_role | AKUN |
| public | `get_app_notice` | 0184 | authenticated, service_role | NOTIF |
| public | `get_bookmarks` | 0075 | authenticated, service_role | KOM |
| public | `get_client_config` | 0183 | authenticated, anon, service_role | AKUN |
| public | `get_comment_settings` | 0170 | authenticated, service_role | KOM |
| public | `get_comment_thread` | 0155 | authenticated, service_role | KOM |
| public | `get_dm_policy` | 0070 | authenticated, service_role | AKUN |
| public | `get_dm_request_state` | 0085 | authenticated, service_role | CHAT |
| public | `get_feed` | 0149 | authenticated, service_role | KOM |
| public | `get_feed_filters` | 0149 | authenticated, service_role | KOM |
| public | `get_follow_list` | 0148 | authenticated, service_role | KOM |
| public | `get_hashtag_feed` | 0073 | authenticated, service_role | KOM |
| public | `get_legal_documents` | 0062 | authenticated, service_role | AKUN |
| public | `get_link_previews` | 0080 | authenticated, service_role | KOM |
| public | `get_market_instruments` | 0150 | authenticated, service_role | KOM |
| public | `get_market_sentiment` | 0143 | authenticated, service_role | KOM |
| public | `get_mention_policy` | 0172 | authenticated, service_role | KOM |
| public | `get_message_ids` | 0154 | authenticated, service_role | CHAT |
| public | `get_message_info` | 0122 | authenticated, service_role | CHAT |
| public | `get_message_request_count` | 0070 | authenticated, service_role | CHAT |
| public | `get_message_requests` | 0070 | authenticated, service_role | CHAT |
| public | `get_messages` | 0154 | authenticated, service_role | CHAT |
| public | `get_messages_by_ids` | 0154 | authenticated, service_role | CHAT |
| public | `get_my_appeals` | 0071 | authenticated, service_role | MOD |
| public | `get_my_moderated_content` | 0085 | authenticated, service_role | MOD |
| public | `get_my_room` | 0154 | authenticated, service_role | CHAT |
| public | `get_my_rooms` | 0154 | authenticated, service_role | CHAT |
| public | `get_my_sanctions` | 0013 | authenticated, service_role | MOD |
| public | `get_notification_prefs` | 0076 | authenticated, service_role | NOTIF |
| public | `get_notification_unread_count` | 0003 | authenticated, service_role | NOTIF |
| public | `get_notifications` | 0076 | authenticated, service_role | NOTIF |
| public | `get_official_accounts` | 0057 | authenticated, service_role | KOM |
| public | `get_or_create_direct_room` | 0154 | authenticated, service_role | CHAT |
| public | `get_pending_consents` | 0014 | authenticated, service_role | AKUN |
| public | `get_pinned_posts` | 0057 | authenticated, service_role | KOM |
| public | `get_post` | 0007 | authenticated, service_role | KOM |
| public | `get_post_drafts` | 0090 | authenticated, service_role | KOM |
| public | `get_profile` | 0144 | authenticated, service_role | KOM |
| public | `get_room_members` | 0018 | authenticated, service_role | CHAT |
| public | `get_room_previews` | 0154 | authenticated, service_role | CHAT |
| public | `get_stock` | 0150 | authenticated, service_role | KOM |
| public | `get_stock_room_state` | 0150 | authenticated, service_role | CHAT |
| public | `get_stock_sentiment` | 0150 | authenticated, service_role | KOM |
| public | `get_stock_stats` | 0150 | authenticated, service_role | KOM |
| public | `get_suggested_users` | 0143 | authenticated, service_role | KOM |
| public | `get_trade_share_profile` | 0161 | authenticated, service_role | TRADE |
| public | `get_trade_share_status` | 0160 | authenticated, service_role | TRADE |
| public | `get_trending` | 0074 | authenticated, service_role | KOM |
| public | `get_trending_hashtags` | 0081 | authenticated, service_role | KOM |
| public | `get_unread_chat_count` | 0154 | authenticated, service_role | CHAT |
| public | `get_unread_counts` | 0154 | authenticated, service_role | CHAT |
| public | `health_report` | 0113 | service_role | OPS |
| public | `hide_room` | 0154 | authenticated, service_role | CHAT |
| public | `integration_authenticate` | 0068 | service_role | INT |
| public | `integration_bot_post` | 0068 | service_role | INT |
| public | `integration_notify` | 0171 | service_role | INT |
| public | `join_stock_room` | 0154 | authenticated, service_role | CHAT |
| public | `leave_room` | 0157 | authenticated, service_role | CHAT |
| public | `link_preview_claim` | 0080 | service_role | OPS |
| public | `link_preview_image_scores` | 0094 | service_role | OPS |
| public | `link_preview_report` | 0094 | service_role | OPS |
| public | `mark_notifications_read` | 0003 | authenticated, service_role | NOTIF |
| public | `mark_room_read` | 0018 | authenticated, service_role | CHAT |
| public | `mark_rooms_delivered` | 0018 | authenticated, service_role | CHAT |
| public | `media_attachment_policy` | 0131 | service_role | OPS |
| public | `media_hold` | 0079 | service_role | OPS |
| public | `media_hold_cancel` | 0079 | service_role | OPS |
| public | `media_moderation_config` | 0079 | service_role | OPS |
| public | `media_room_kind` | 0138 | service_role | OPS |
| public | `mute_trade_subscription` | 0161 | authenticated, service_role | TRADE |
| public | `my_trade_subscribers` | 0161 | authenticated, service_role | TRADE |
| public | `my_trade_subscriptions` | 0161 | authenticated, service_role | TRADE |
| public | `nodes_report` | 0168 | service_role | OPS |
| public | `pause_trade_share` | 0160 | authenticated, service_role | TRADE |
| public | `push_claim` | 0058 | service_role | NOTIF |
| public | `push_credentials` | 0059 | service_role | NOTIF |
| public | `push_heartbeat` | 0059 | service_role | NOTIF |
| public | `push_report` | 0058 | service_role | NOTIF |
| public | `react_to_message` | 0075 | authenticated, service_role | CHAT |
| public | `record_banner_event` | 0185 | authenticated, service_role | NOTIF |
| public | `register_push_device` | 0058 | authenticated, service_role | NOTIF |
| public | `remove_room_member` | 0146 | authenticated, service_role | CHAT |
| public | `remove_trade_subscriber` | 0161 | authenticated, service_role | TRADE |
| public | `report_notification_event` | 0088 | authenticated, service_role | NOTIF |
| public | `request_trade_subscription` | 0161 | authenticated, service_role | TRADE |
| public | `respond_message_request` | 0070 | authenticated, service_role | CHAT |
| public | `resume_trade_share` | 0160 | authenticated, service_role | TRADE |
| public | `room_mod_escalate` | 0093 | authenticated, service_role | MOD |
| public | `room_mod_hide_message` | 0093 | authenticated, service_role | MOD |
| public | `room_mod_mute_user` | 0096 | authenticated, service_role | MOD |
| public | `save_post_draft` | 0150 | authenticated, service_role | KOM |
| public | `search` | 0073 | authenticated, service_role | KOM |
| public | `search_profiles` | 0172 | authenticated, service_role | CHAT |
| public | `send_message` | 0008 | authenticated, service_role | CHAT |
| public | `send_typing` | 0098 | authenticated, service_role | CHAT |
| public | `service_heartbeat` | 0064 | service_role | OPS |
| public | `set_all_comments_off` | 0170 | authenticated, service_role | KOM |
| public | `set_comment_audience` | 0169 | authenticated, service_role | KOM |
| public | `set_dm_policy` | 0070 | authenticated, service_role | AKUN |
| public | `set_mention_policy` | 0172 | authenticated, service_role | KOM |
| public | `set_notification_prefs` | 0087 | authenticated, service_role | NOTIF |
| public | `set_olt_account_links` | 0128 | service_role | INT |
| public | `set_post_comment_audience` | 0169 | authenticated, service_role | KOM |
| public | `set_room_member_role` | 0146 | authenticated, service_role | CHAT |
| public | `share_post_to_chat` | 0075 | authenticated, service_role | CHAT |
| public | `storage_cleanup_claim` | 0095 | service_role | OPS |
| public | `storage_cleanup_report` | 0060 | service_role | OPS |
| public | `submit_trade_share_application` | 0160 | authenticated, service_role | TRADE |
| public | `toggle_bookmark` | 0075 | authenticated, service_role | KOM |
| public | `track_events` | 0085 | authenticated, service_role | KOM |
| public | `trade_activity_detail` | 0163 | authenticated, service_role | TRADE |
| public | `trade_activity_feed` | 0163 | authenticated, service_role | TRADE |
| public | `trade_relay_config` | 0162 | service_role | TRADE |
| public | `trade_relay_events` | 0162 | service_role | TRADE |
| public | `trade_relay_status` | 0162 | service_role | TRADE |
| public | `transfer_room_ownership` | 0146 | authenticated, service_role | CHAT |
| public | `unregister_push_device` | 0058 | authenticated, service_role | NOTIF |
| public | `update_group_info` | 0146 | authenticated, service_role | CHAT |
| public | `update_group_settings` | 0146 | authenticated, service_role | CHAT |
| public | `update_trade_share_settings` | 0160 | authenticated, service_role | TRADE |
| public | `upsert_olt_profile` | 0175 | service_role | AKUN |
| public | `vote_poll` | 0019 | authenticated, service_role | KOM |
| public | `withdraw_trade_share` | 0160 | authenticated, service_role | TRADE |

#### 11.3.2 Skema `cs_api` (315 fungsi)

| Skema | Fungsi | Migrasi terakhir | Grant | Modul |
|---|---|---|---|---|
| cs_api | `add_note` | 0033 | authenticated | CS |
| cs_api | `add_ticket_label` | 0118 | authenticated | CS |
| cs_api | `admin_agents` | 0035 | authenticated | HUB |
| cs_api | `admin_analytics` | 0078 | authenticated | HUB |
| cs_api | `admin_attachment_policy` | 0131 | authenticated | CS |
| cs_api | `admin_banner_notice_preview` | 0182 | authenticated | NOTIF |
| cs_api | `admin_banner_notices` | 0182 | authenticated | NOTIF |
| cs_api | `admin_banner_settings` | 0121 | authenticated | NOTIF |
| cs_api | `admin_banner_stats` | 0121 | authenticated | NOTIF |
| cs_api | `admin_banners` | 0121 | authenticated | NOTIF |
| cs_api | `admin_cancel_banner_notice` | 0182 | authenticated | NOTIF |
| cs_api | `admin_delete_banner` | 0121 | authenticated | NOTIF |
| cs_api | `admin_delete_feature_flag` | 0121 | authenticated | HUB |
| cs_api | `admin_delete_holiday` | 0035 | authenticated | CS |
| cs_api | `admin_delete_topic` | 0139 | authenticated | BANTU |
| cs_api | `admin_end_incident` | 0135 | authenticated | CS |
| cs_api | `admin_faq` | 0129 | authenticated | BANTU |
| cs_api | `admin_faq_feedback` | 0129 | authenticated | BANTU |
| cs_api | `admin_faq_flags` | 0136 | authenticated | BANTU |
| cs_api | `admin_faq_misses` | 0129 | authenticated | BANTU |
| cs_api | `admin_faq_resolve_flags` | 0136 | authenticated | BANTU |
| cs_api | `admin_faq_restore` | 0188 | authenticated | BANTU |
| cs_api | `admin_faq_save_article` | 0188 | authenticated | BANTU |
| cs_api | `admin_faq_save_category` | 0129 | authenticated | BANTU |
| cs_api | `admin_faq_set_status` | 0129 | authenticated | BANTU |
| cs_api | `admin_faq_versions` | 0129 | authenticated | BANTU |
| cs_api | `admin_feature_flags` | 0121 | authenticated | HUB |
| cs_api | `admin_feed_filters` | 0149 | authenticated | HUB |
| cs_api | `admin_help_report` | 0136 | authenticated | BANTU |
| cs_api | `admin_holidays` | 0035 | authenticated | CS |
| cs_api | `admin_incidents` | 0135 | authenticated | CS |
| cs_api | `admin_options` | 0126 | authenticated | HUB |
| cs_api | `admin_policy_four_eyes` | 0092 | authenticated | HUB |
| cs_api | `admin_quick_replies` | 0035 | authenticated | CS |
| cs_api | `admin_rating_reasons` | 0135 | authenticated | CS |
| cs_api | `admin_reorder_ticket_labels` | 0118 | authenticated | CS |
| cs_api | `admin_reorder_topics` | 0137 | authenticated | BANTU |
| cs_api | `admin_reset_agent_mfa` | 0186 | authenticated | HUB |
| cs_api | `admin_reset_password` | 0039 | authenticated | HUB |
| cs_api | `admin_review_banner_notice` | 0182 | authenticated | NOTIF |
| cs_api | `admin_save_banner` | 0184 | authenticated | NOTIF |
| cs_api | `admin_save_holiday` | 0035 | authenticated | CS |
| cs_api | `admin_save_incident` | 0135 | authenticated | CS |
| cs_api | `admin_save_quick_reply` | 0035 | authenticated | CS |
| cs_api | `admin_save_ticket_label` | 0118 | authenticated | CS |
| cs_api | `admin_save_topic` | 0127 | authenticated | BANTU |
| cs_api | `admin_set_attachment_policy` | 0131 | authenticated | CS |
| cs_api | `admin_set_banner_link_schemes` | 0124 | authenticated | NOTIF |
| cs_api | `admin_set_community_permissions` | 0057 | authenticated | HUB |
| cs_api | `admin_set_feature_flag` | 0121 | authenticated | HUB |
| cs_api | `admin_set_feed_filter_enabled` | 0180 | authenticated | HUB |
| cs_api | `admin_set_kill_switch` | 0121 | authenticated | HUB |
| cs_api | `admin_set_min_version` | 0121 | authenticated | HUB |
| cs_api | `admin_set_nasabah_permissions` | 0047 | authenticated | HUB |
| cs_api | `admin_set_policy_four_eyes` | 0092 | authenticated | HUB |
| cs_api | `admin_set_setting` | 0186 | authenticated | CS |
| cs_api | `admin_set_survey_config` | 0135 | authenticated | CS |
| cs_api | `admin_set_topic_extras` | 0134 | authenticated | BANTU |
| cs_api | `admin_set_topic_picker` | 0127 | authenticated | BANTU |
| cs_api | `admin_set_trade_permissions` | 0160 | authenticated | TRADE |
| cs_api | `admin_settings` | 0035 | authenticated | CS |
| cs_api | `admin_survey_config` | 0135 | authenticated | CS |
| cs_api | `admin_ticket_labels` | 0118 | authenticated | CS |
| cs_api | `admin_toggle_feature_flag` | 0121 | authenticated | HUB |
| cs_api | `admin_topic_picker` | 0127 | authenticated | BANTU |
| cs_api | `admin_topics` | 0127 | authenticated | BANTU |
| cs_api | `admin_unlock_agent` | 0186 | authenticated | HUB |
| cs_api | `admin_update_agent` | 0038 | authenticated | HUB |
| cs_api | `agent_faq_search` | 0136 | authenticated | BANTU |
| cs_api | `agent_flag_faq` | 0136 | authenticated | BANTU |
| cs_api | `agent_heartbeat` | 0033 | authenticated | CS |
| cs_api | `agent_me` | 0165 | authenticated | CS |
| cs_api | `agent_my_profile` | 0165 | authenticated | HUB |
| cs_api | `agent_my_stats` | 0116 | authenticated | HUB |
| cs_api | `agent_password_changed` | 0116 | authenticated | HUB |
| cs_api | `agent_security_status` | 0186 | authenticated | HUB |
| cs_api | `agent_send_message` | 0038 | authenticated | CS |
| cs_api | `agent_set_status` | 0033 | authenticated | CS |
| cs_api | `agent_signed_out_everywhere` | 0116 | authenticated | HUB |
| cs_api | `agent_typing` | 0098 | authenticated | CS |
| cs_api | `alert_channels_view` | 0064 | authenticated | OPS |
| cs_api | `alert_send_test` | 0064 | authenticated | OPS |
| cs_api | `alert_set_email` | 0064 | authenticated | OPS |
| cs_api | `alert_set_options` | 0064 | authenticated | OPS |
| cs_api | `alert_set_telegram` | 0064 | authenticated | OPS |
| cs_api | `app_integration_overview` | 0114 | authenticated | INT |
| cs_api | `attachment_policy` | 0131 | authenticated | CS |
| cs_api | `backup_overview` | 0065 | authenticated | OPS |
| cs_api | `backup_request` | 0065 | authenticated | OPS |
| cs_api | `backup_set_schedule` | 0065 | authenticated | OPS |
| cs_api | `backup_set_target` | 0112 | authenticated | OPS |
| cs_api | `cancel_transfer` | 0033 | authenticated | CS |
| cs_api | `check_sensitive` | 0029 | authenticated | CS |
| cs_api | `claim_ticket` | 0033 | authenticated | CS |
| cs_api | `close_ticket` | 0033 | authenticated | CS |
| cs_api | `community_accounts` | 0057 | authenticated | HUB |
| cs_api | `community_appeal_decide` | 0071 | authenticated | MOD |
| cs_api | `community_appeals` | 0071 | authenticated | MOD |
| cs_api | `community_appoint_room_moderator` | 0093 | authenticated | MOD |
| cs_api | `community_audience_size` | 0088 | authenticated | NOTIF |
| cs_api | `community_campaign_push` | 0088 | authenticated | NOTIF |
| cs_api | `community_campaigns` | 0057 | authenticated | NOTIF |
| cs_api | `community_cancel_campaign` | 0057 | authenticated | NOTIF |
| cs_api | `community_cancel_post` | 0057 | authenticated | HUB |
| cs_api | `community_content` | 0084 | authenticated | MOD |
| cs_api | `community_content_meta` | 0084 | authenticated | MOD |
| cs_api | `community_delete_instrument` | 0150 | authenticated | HUB |
| cs_api | `community_delete_post` | 0057 | authenticated | HUB |
| cs_api | `community_edit_history` | 0156 | authenticated | MOD |
| cs_api | `community_find_users` | 0140 | authenticated | NOTIF |
| cs_api | `community_held_content` | 0069 | authenticated | MOD |
| cs_api | `community_instrument_check` | 0150 | authenticated | HUB |
| cs_api | `community_instruments` | 0150 | authenticated | HUB |
| cs_api | `community_manipulation_alerts` | 0072 | authenticated | MOD |
| cs_api | `community_manipulation_review` | 0072 | authenticated | MOD |
| cs_api | `community_media_review_decide` | 0079 | authenticated | MOD |
| cs_api | `community_media_reviews` | 0079 | authenticated | MOD |
| cs_api | `community_overview` | 0058 | authenticated | HUB |
| cs_api | `community_pin_message` | 0072 | authenticated | MOD |
| cs_api | `community_pin_post` | 0150 | authenticated | HUB |
| cs_api | `community_posts` | 0057 | authenticated | HUB |
| cs_api | `community_remove_room_moderator` | 0093 | authenticated | MOD |
| cs_api | `community_reorder_instruments` | 0150 | authenticated | HUB |
| cs_api | `community_reports` | 0057 | authenticated | MOD |
| cs_api | `community_resolve_report` | 0057 | authenticated | MOD |
| cs_api | `community_review_campaign` | 0057 | authenticated | NOTIF |
| cs_api | `community_review_post` | 0057 | authenticated | HUB |
| cs_api | `community_revoke_sanction` | 0057 | authenticated | MOD |
| cs_api | `community_revoke_sessions` | 0057 | authenticated | MOD |
| cs_api | `community_room_messages` | 0086 | authenticated | MOD |
| cs_api | `community_room_moderator_actions` | 0093 | authenticated | MOD |
| cs_api | `community_room_moderator_candidates` | 0140 | authenticated | MOD |
| cs_api | `community_room_moderator_settings` | 0093 | authenticated | MOD |
| cs_api | `community_room_moderators` | 0150 | authenticated | MOD |
| cs_api | `community_room_settings` | 0072 | authenticated | MOD |
| cs_api | `community_room_state` | 0072 | authenticated | MOD |
| cs_api | `community_sanction_user` | 0057 | authenticated | MOD |
| cs_api | `community_save_account` | 0058 | authenticated | HUB |
| cs_api | `community_save_campaign` | 0184 | authenticated | NOTIF |
| cs_api | `community_save_instrument` | 0150 | authenticated | HUB |
| cs_api | `community_save_post` | 0150 | authenticated | HUB |
| cs_api | `community_set_account_disabled` | 0057 | authenticated | HUB |
| cs_api | `community_set_room_moderator_settings` | 0093 | authenticated | MOD |
| cs_api | `community_set_verified` | 0057 | authenticated | HUB |
| cs_api | `community_submit_campaign` | 0057 | authenticated | NOTIF |
| cs_api | `community_submit_post` | 0057 | authenticated | HUB |
| cs_api | `community_undo_room_moderator_action` | 0096 | authenticated | MOD |
| cs_api | `community_user` | 0057 | authenticated | MOD |
| cs_api | `community_zero_tolerance` | 0071 | authenticated | MOD |
| cs_api | `compliance_add_allowlist_term` | 0069 | authenticated | PATUH |
| cs_api | `compliance_add_banned_word` | 0051 | authenticated | PATUH |
| cs_api | `compliance_add_promo_phrase` | 0069 | authenticated | PATUH |
| cs_api | `compliance_audit` | 0042 | authenticated | PATUH |
| cs_api | `compliance_banned_words` | 0051 | authenticated | PATUH |
| cs_api | `compliance_case` | 0125 | authenticated | PATUH |
| cs_api | `compliance_cases` | 0125 | authenticated | PATUH |
| cs_api | `compliance_confirm_policy` | 0042 | authenticated | PATUH |
| cs_api | `compliance_content_rules` | 0069 | authenticated | PATUH |
| cs_api | `compliance_delete_allowed_domain` | 0069 | authenticated | PATUH |
| cs_api | `compliance_delete_allowlist_term` | 0069 | authenticated | PATUH |
| cs_api | `compliance_delete_banned_word` | 0051 | authenticated | PATUH |
| cs_api | `compliance_delete_blocked_domain` | 0069 | authenticated | PATUH |
| cs_api | `compliance_delete_promo_phrase` | 0069 | authenticated | PATUH |
| cs_api | `compliance_extend_deadline` | 0042 | authenticated | PATUH |
| cs_api | `compliance_image_thresholds` | 0079 | authenticated | PATUH |
| cs_api | `compliance_import_banned_words` | 0051 | authenticated | PATUH |
| cs_api | `compliance_manipulation_settings` | 0072 | authenticated | PATUH |
| cs_api | `compliance_notices` | 0133 | authenticated | PATUH |
| cs_api | `compliance_notices_seen` | 0133 | authenticated | PATUH |
| cs_api | `compliance_overview` | 0042 | authenticated | PATUH |
| cs_api | `compliance_policies` | 0042 | authenticated | PATUH |
| cs_api | `compliance_policy_call` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_change` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_changes` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_decide` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_discard` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_rollback` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_simulate` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_state` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_submit` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_version` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_versions` | 0092 | authenticated | PATUH |
| cs_api | `compliance_policy_withdraw` | 0092 | authenticated | PATUH |
| cs_api | `compliance_review` | 0042 | authenticated | PATUH |
| cs_api | `compliance_save_allowed_domain` | 0069 | authenticated | PATUH |
| cs_api | `compliance_save_blocked_domain` | 0069 | authenticated | PATUH |
| cs_api | `compliance_set_banned_word_action` | 0051 | authenticated | PATUH |
| cs_api | `compliance_set_content_rule` | 0069 | authenticated | PATUH |
| cs_api | `compliance_set_image_thresholds` | 0079 | authenticated | PATUH |
| cs_api | `compliance_set_manipulation_settings` | 0072 | authenticated | PATUH |
| cs_api | `compliance_set_new_account_days` | 0069 | authenticated | PATUH |
| cs_api | `compliance_set_rejoin_cooldown_hours` | 0175 | authenticated | PATUH |
| cs_api | `compliance_test_content` | 0176 | authenticated | PATUH |
| cs_api | `compliance_transcript_exported` | 0125 | authenticated | PATUH |
| cs_api | `customer_history` | 0033 | authenticated | CS |
| cs_api | `delete_my_quick_reply` | 0117 | authenticated | CS |
| cs_api | `evidence_detail` | 0095 | authenticated | PATUH |
| cs_api | `evidence_export` | 0095 | authenticated | PATUH |
| cs_api | `evidence_file_checked` | 0095 | authenticated | PATUH |
| cs_api | `evidence_list` | 0095 | authenticated | PATUH |
| cs_api | `evidence_set_hold` | 0095 | authenticated | PATUH |
| cs_api | `evidence_verify` | 0095 | authenticated | PATUH |
| cs_api | `faq` | 0129 | authenticated | BANTU |
| cs_api | `faq_article` | 0129 | authenticated | BANTU |
| cs_api | `faq_feedback` | 0129 | authenticated | BANTU |
| cs_api | `faq_for_topic` | 0129 | authenticated | BANTU |
| cs_api | `faq_search` | 0129 | authenticated | BANTU |
| cs_api | `flag_ticket` | 0133 | authenticated | CS |
| cs_api | `get_messages` | 0029 | authenticated | CS |
| cs_api | `guest_config` | 0140 | authenticated, anon | CS |
| cs_api | `guest_end` | 0159 | authenticated, anon | CS |
| cs_api | `guest_poll` | 0140 | authenticated, anon | CS |
| cs_api | `guest_send` | 0140 | authenticated, anon | CS |
| cs_api | `guest_start` | 0140 | authenticated, anon | CS |
| cs_api | `healer_overview` | 0113 | authenticated | OPS |
| cs_api | `health_acknowledge` | 0064 | authenticated | OPS |
| cs_api | `integration_broadcasts` | 0086 | authenticated | INT |
| cs_api | `integration_key_create` | 0101 | authenticated | INT |
| cs_api | `integration_key_revoke` | 0068 | authenticated | INT |
| cs_api | `integration_key_update` | 0101 | authenticated | INT |
| cs_api | `integration_keys` | 0068 | authenticated | INT |
| cs_api | `integration_official_accounts` | 0084 | authenticated | INT |
| cs_api | `integration_stats` | 0086 | authenticated | INT |
| cs_api | `integration_stats_daily` | 0086 | authenticated | INT |
| cs_api | `legal_cancel_scheduled` | 0062 | authenticated | PATUH |
| cs_api | `legal_document` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft_approve` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft_delete` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft_reject` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft_save` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft_submit` | 0062 | authenticated | PATUH |
| cs_api | `legal_draft_withdraw` | 0062 | authenticated | PATUH |
| cs_api | `legal_overview` | 0062 | authenticated | PATUH |
| cs_api | `legal_set_required` | 0165 | authenticated | PATUH |
| cs_api | `mark_read` | 0029 | authenticated | CS |
| cs_api | `my_quick_replies` | 0117 | authenticated | CS |
| cs_api | `my_tickets` | 0033 | authenticated | CS |
| cs_api | `nasabah_access` | 0186 | service_role | INT |
| cs_api | `nasabah_audit` | 0044 | service_role | INT |
| cs_api | `nasabah_clear_integration` | 0055 | service_role | INT |
| cs_api | `nasabah_integration` | 0055 | service_role | INT |
| cs_api | `nasabah_is_super_admin(uuid)` | 0050 | service_role | INT |
| cs_api | `nasabah_is_super_admin(uuid, text)` | 0186 | service_role | INT |
| cs_api | `nasabah_save_integration` | 0055 | service_role | INT |
| cs_api | `notes` | 0029 | authenticated | CS |
| cs_api | `online_agents` | 0038 | authenticated | CS |
| cs_api | `open_ticket` | 0134 | authenticated | CS |
| cs_api | `push_find_users` | 0140 | authenticated | NOTIF |
| cs_api | `push_remove_credentials` | 0059 | authenticated | NOTIF |
| cs_api | `push_set_credentials` | 0059 | authenticated | NOTIF |
| cs_api | `push_status` | 0059 | authenticated | NOTIF |
| cs_api | `push_test` | 0058 | authenticated | NOTIF |
| cs_api | `quick_replies` | 0117 | authenticated | CS |
| cs_api | `rate_ticket` | 0135 | authenticated | CS |
| cs_api | `reassign_ticket` | 0033 | authenticated | CS |
| cs_api | `release_ticket` | 0033 | authenticated | CS |
| cs_api | `remove_ticket_label` | 0118 | authenticated | CS |
| cs_api | `report_customer_trail` | 0056 | authenticated | CS |
| cs_api | `report_customers` | 0056 | authenticated | CS |
| cs_api | `report_fake_cs` | 0033 | authenticated | CS |
| cs_api | `report_summary` | 0035 | authenticated | CS |
| cs_api | `report_ticket_labels` | 0118 | authenticated | CS |
| cs_api | `request_complaint` | 0033 | authenticated | CS |
| cs_api | `request_transfer` | 0033 | authenticated | CS |
| cs_api | `resolve_ticket` | 0033 | authenticated | CS |
| cs_api | `respond_transfer` | 0033 | authenticated | CS |
| cs_api | `room_members` | 0034 | authenticated | CS |
| cs_api | `save_my_quick_reply` | 0117 | authenticated | CS |
| cs_api | `search_tickets` | 0033 | authenticated | CS |
| cs_api | `send_message` | 0029 | authenticated | CS |
| cs_api | `service_create_agent` | 0035 | service_role | HUB |
| cs_api | `service_status` | 0135 | authenticated | CS |
| cs_api | `set_ticket_priority` | 0033 | authenticated | CS |
| cs_api | `supervisor_overview` | 0038 | authenticated | CS |
| cs_api | `support_home` | 0158 | authenticated | CS |
| cs_api | `system_health` | 0064 | authenticated | OPS |
| cs_api | `system_health_badge` | 0064 | authenticated | OPS |
| cs_api | `system_nodes` | 0168 | authenticated | OPS |
| cs_api | `ticket_customer_login` | 0141 | authenticated | INT |
| cs_api | `ticket_detail` | 0033 | authenticated | CS |
| cs_api | `ticket_labels` | 0118 | authenticated | CS |
| cs_api | `ticket_lists` | 0033 | authenticated | CS |
| cs_api | `ticket_messages` | 0033 | authenticated | CS |
| cs_api | `ticket_transcript` | 0136 | authenticated | CS |
| cs_api | `topics` | 0134 | authenticated | CS |
| cs_api | `trade_notify_set_enabled` | 0162 | authenticated | TRADE |
| cs_api | `trade_relay_clear_aes` | 0162 | authenticated | TRADE |
| cs_api | `trade_relay_command` | 0162 | authenticated | TRADE |
| cs_api | `trade_relay_get` | 0162 | authenticated | TRADE |
| cs_api | `trade_relay_set_aes` | 0162 | authenticated | TRADE |
| cs_api | `trade_relay_update` | 0162 | authenticated | TRADE |
| cs_api | `trade_share_dashboard` | 0164 | authenticated | TRADE |
| cs_api | `trade_share_decide` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_detail` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_exclude_account` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_exclude_stock` | 0162 | authenticated | TRADE |
| cs_api | `trade_share_excluded_accounts` | 0166 | authenticated | TRADE |
| cs_api | `trade_share_excluded_stocks` | 0166 | authenticated | TRADE |
| cs_api | `trade_share_export` | 0164 | authenticated | TRADE |
| cs_api | `trade_share_find_profiles` | 0165 | authenticated | TRADE |
| cs_api | `trade_share_flags` | 0165 | authenticated | TRADE |
| cs_api | `trade_share_list` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_pilot_invites` | 0166 | authenticated | TRADE |
| cs_api | `trade_share_reinstate` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_review_flag` | 0164 | authenticated | TRADE |
| cs_api | `trade_share_revoke` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_set_pilot_invite` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_settings` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_subscribers` | 0161 | authenticated | TRADE |
| cs_api | `trade_share_suspend` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_unexclude_account` | 0160 | authenticated | TRADE |
| cs_api | `trade_share_unexclude_stock` | 0162 | authenticated | TRADE |
| cs_api | `trade_share_update_setting` | 0160 | authenticated | TRADE |
| cs_api | `wait_customer` | 0038 | authenticated | CS |

#### 11.3.3 Skema `admin_api` (19 fungsi)

| Skema | Fungsi | Migrasi terakhir | Grant | Modul |
|---|---|---|---|---|
| admin_api | `archive` | 0013 | authenticated | PATUH |
| admin_api | `audit_log` | 0013 | authenticated | PATUH |
| admin_api | `delete_banned_word` | 0013 | authenticated | MOD |
| admin_api | `disable_admin` | 0013 | authenticated | HUB |
| admin_api | `publish_legal_document` | 0014 | authenticated | PATUH |
| admin_api | `report_queue` | 0057 | authenticated | MOD |
| admin_api | `resolve_target` | 0057 | authenticated | MOD |
| admin_api | `revoke_sanction` | 0013 | authenticated | MOD |
| admin_api | `revoke_user_sessions` | 0013 | authenticated | MOD |
| admin_api | `sanction_user` | 0057 | authenticated | MOD |
| admin_api | `set_admin` | 0013 | authenticated | HUB |
| admin_api | `set_legal_hold` | 0013 | authenticated | PATUH |
| admin_api | `set_room_scope` | 0013 | authenticated | MOD |
| admin_api | `set_trust_level` | 0013 | authenticated | MOD |
| admin_api | `set_verified` | 0013 | authenticated | HUB |
| admin_api | `update_setting` | 0013 | authenticated | HUB |
| admin_api | `upsert_banned_word` | 0013 | authenticated | MOD |
| admin_api | `user_detail` | 0013 | authenticated | MOD |
| admin_api | `whoami` | 0013 | authenticated | HUB |

### 11.4 Catatan perbedaan dan butir perlu konfirmasi

#### 11.4.1 Butir perlu konfirmasi

| No | Lokasi | Butir |
|---|---|---|
| K1 | FR-CS-10 | Apakah nasabah yang di-ban tetap boleh membuka chat CS di dalam aplikasi. Database mengecualikan `cs_api` dari ban (`private.check_request`, 0177) dan `docs/cs-chat/README.md` menyatakan boleh, tetapi auth-bridge menolak penukaran token (`403 user_banned`) sehingga dalam praktik hanya pengaduan tamu yang tersedia |
| K2 | FR-MOD-29 | Kanal pelaporan CSAM ke pihak berwenang belum ditetapkan tim legal (`docs/content-safety.md` bagian 9) |
| K3 | FR-MOD-39 | Apakah panel admin lama "F1" (`admin_api`, peran `viewer`…`super_admin`) masih dipakai. Skema `admin_api` punya grant tetapi tidak ada di `PGRST_DB_SCHEMAS`, sehingga tidak bisa dipanggil lewat `/rest/v1` |
| K4 | FR-HUB-05 | Status HTTP yang dikembalikan GoTrue untuk balasan hook `account_locked:<waktu UTC>` |
| K5 | FR-AKUN-11 | Kode error pasti dari `private.validate_text(..., 'profile')` untuk karakter kontrol di nama atau bio |
| K6 | FR-AKUN-18, FR-KOM-55 | Library belum punya UI untuk membisukan pengguna, kata kunci, dan saham, walau tabel `public.mutes`, `public.muted_keywords`, `public.muted_stocks` tersedia |
| K7 | FR-KOM-03 | Apakah UI bawaan library memakai feed `for_you` (`ForYouFeedScope` hanya tersedia untuk host) |
| K8 | FR-CHAT-09 | `add_room_members` (0146) memeriksa jumlah anggota sebelum statement, sehingga satu panggilan yang menambah banyak anggota bisa melewati 100; `create_group_room` adalah batas keras (99 + owner) |
| K9 | 5.2.3 | Daftar event lengkap topik staf `cs:queue` dan `cs:agent:<id>` tidak ada di `asyncapi.yaml`; diturunkan dari pemanggilan `realtime.send` |
| K10 | 6.3, 9.2 | `retention.chat_years` (bawaan 10, Kepatuhan 5–30) hanya disimpan; belum ada job yang menegakkannya |
| K11 | NFR-AUD-08 | Mekanisme pemangkasan `admin_audit_log` dan `cs_audit_log` yang append-only terhadap `retention.audit_log_days` (365) belum ditemukan |
| K12 | NFR-PERF-10 | Metode pengukuran ±2,6 ms pemeriksaan kebijakan konten |
| K13 | NFR-KAP-12, NFR-PORT-04 | Jadwal pengujian profil cluster dan storage S3 |
| K14 | NFR-PRIV-07, NFR-PRIV-09 | Tes yang mencakup penyamaran pencarian FAQ yang gagal; kebijakan resmi lokasi data |
| K15 | NFR-USAB-03, NFR-USAB-06, NFR-USAB-07 | Apakah lebar HP menjadi target Hub (E2E hanya 1366/1920/2560); tes otomatis logout karena idle; target aksesibilitas formal library |
| K16 | NFR-COMP-05, NFR-COMP-06 | Versi Flutter minimum resmi (`pubspec.yaml` ≥ 3.47.0, `doc/integration.md` ≥ 3.44, CI library 3.44.1); daftar browser resmi Hub (hanya Chromium diuji) |
| K17 | 8.6, 8.12 | Prosedur lengkap rotasi `jwt_secret`; pemeriksaan lisensi otomatis modul Go; hasil pentest |
| K18 | 9.1 | Apakah `rooms.busy_slow_mode` dan `rooms.busy_windows` ikut tercatat di versi kebijakan (`policy_setting_key` hanya mencakup `safety.*`, `account.rejoin_cooldown_hours`, `manipulation.*`) |
| K19 | 9.2, 9.3 | Fallback `.env` untuk `nasabah.*`; rate limit yang diubah langsung lewat SQL di server |
| K20 | 10.1, 10.3 | Jumlah resmi tes E2E Hub; ukuran server dan versi library di checklist go-live |
| K21 | 4.11 | Jadwal pg_cron berjalan dalam UTC, sehingga sebagian besar job pemeliharaan malam (retensi, purge, partisi, analitik, rebuild trending) jatuh sekitar 09.10–10.53 WIB, yaitu jam bursa. Perlu keputusan apakah jadwal ini disengaja |
| K22 | 11.3 | Pemetaan modul pada daftar RPC bersifat perkiraan dari nama fungsi |

#### 11.4.2 Perbedaan dokumen dan kode (SRS mengikuti kode)

| No | Topik | Dokumen | Kode |
|---|---|---|---|
| D1 | Allowlist `cs_api` publik | `produksi.md` dan dokumen uji: 14 RPC | `docker/volumes/traefik/prod.yml` membuka 27 RPC (tambahan `faq_*`, `guest_*`, `attachment_policy`, `service_status`, `ticket_transcript`) |
| D2 | Lampiran chat CS | `docs/cs-chat/README.md`: gambar 5 MB + PDF saja, video/Office ditolak; library `features.md`: gambar CS 5 MB | Sejak 0131/0138: DOCX/XLSX/PPTX/TXT/CSV dan video ≤ 25 MB / 120 detik dengan ClamAV, gambar CS ≤ 10 MB |
| D3 | Pilihan cepat CS | Panduan staf: 2–4 opsi | Server 2–6 opsi, 1–40 karakter (0038); Hub mengizinkan 2–4 opsi hingga 60 karakter, sehingga opsi 41–60 karakter ditolak server `invalid_options` |
| D4 | Teks kampanye notifikasi | `docs/community/README.md`: judul 3–80, isi 3–240 | `community_save_campaign` (0184): judul 3–120, isi 3–500 |
| D5 | Ukuran grup | `docs/social/README.md`: maks 100 anggota | Bisa terlampaui lewat `add_room_members` (K8) |
| D6 | Format kode di kartu saham | `^[A-Z][A-Z0-9]{1,11}$` | Sejak 0150 `private.stock_code` menerima kode indeks berstrip 2–24 karakter dan alias |
| D7 | Kode error watch/mute saham | `23514 invalid_stock_code` | `400 invalid_stock_code` (0150) |
| D8 | Kode error edit/hapus pesan | `message_not_found` | `404 not_found` (0154, 0031); edit post/komentar lewat batas `403 edit_window_expired` (0075) sedangkan pesan `409 edit_window_closed` (0154) |
| D9 | Kepatuhan dan realtime | `kepatuhan.md`: tanpa realtime | Sejak 0133 kasus baru dikirim sebagai `case_flagged` di topik `cs:compliance` |
| D10 | Ukuran simulasi kebijakan | maks 1.000 konten | Bawaan 300, maks 1.000 (0092) |
| D11 | Akses dokumen hukum | — | `cs_api.legal_*` hanya untuk `compliance`; Super Admin tidak bisa membaca |
| D12 | Polling | Library: 1 jam–7 hari | Server: 5 menit–7 hari (bawaan 1.440 menit), tidak boleh berlampiran `422 poll_with_attachments` (0019) |
| D13 | Teks hapus akun di library | "profil baru yang kosong dibuat saat masuk lagi" | Profil yang sama diaktifkan lagi dengan `trust_level` 0 dan `created_at` baru (0174/0175) |
| D14 | Cek ulang jeda bergabung | Library mengingat penolakan sampai `retry_at` | `token_manager.dart` mengecek ulang setelah 30 detik atau `retry_at`, mana yang lebih dulu |
| D15 | Akun resmi nonaktif | `get_official_accounts` sama dengan sumber akun resmi aktif | `get_official_accounts()` (0057) tidak menyaring `disabled_at` |
| D16 | Lokasi pengaturan | Diasumsikan semua di `private.settings` | `security.*`, `compliance.policy_four_eyes`, `brand.support_name`, `banners.*`, `guest.*` ada di `cs.cs_settings`; kredensial di tabel `private.*` khusus plus Vault |
| D17 | Daftar egress | `produksi.md` tidak menyebut `nasabah-gateway` dan `trade-relay` | Keduanya di network `egress`; `healer` tanpa network |
| D18 | Versi dan dokumen layanan | Header README auth-bridge 0.6.0; README integration "belum dipasang", batas `set_olt_account_links` 50; README janitor menyebut bucket `care-documents` | auth-bridge 0.7.0; integration sudah di compose/Kong/Traefik, batas `accounts.max_per_customer` (maks 200, 0128); bucket `care-documents` dihapus di 0026 |
| D19 | Checklist go-live | 4 vCPU / 8 GB / 100 GB; library v1.17.0 | `spesifikasi-server.md`: minimum 8/16/200, disarankan 16/32/500; library saat ini v1.49.2 |
| D20 | Rate limit auth-bridge per IP | `docs/testing/README.md`: 30/menit | Bawaan 1.500/menit, `check-config` menolak < 1.000 |
| D21 | Jumlah tes | smoke-dummy 22 skenario; E2E Hub 22 tes | Laporan uji 26/26; 28 deklarasi `test(...)` di 16 file Hub |
| D22 | Nama menu | Library `doc/integration.md`: "Fitur & Kampanye → Fitur & versi"; panduan staf menyebut kelompok "Komunitas" di Pengaturan | Hub: "Komunitas → Fitur & versi"; kelompok Pengaturan Layanan CS / Persetujuan / Integrasi / Sistem; izin Moderasi konten juga membuka tab Indeks |
| D23 | Feature flag | — | `admin_set_feature_flag` mendukung rollout per persen, user, platform, versi, tetapi Hub hanya memanggil `admin_toggle_feature_flag` (nyala/mati) |
| D24 | Interval sentinel dan Peta layanan | 30 dtk / ±30 dtk / ±45 dtk; Peta layanan 5 dtk atau ±10 dtk | README sentinel: 30 dtk; Hub memuat ulang Peta layanan tiap 5 dtk |
| D25 | Tangga sanksi di Hub | — | Tangga otomatis peringatan → mute 1 jam → mute 24 jam → ban 7 hari → ban permanen (0013/0057), sedangkan opsi manual Hub: mute 24 jam, mute 7 hari, ban 7 hari, permanen |
| D26 | Job Berbagi Trade | Fitur dijeda | `trade-share-tick` (30 dtk) dan `trade-share-maintenance` (15 menit) tetap terjadwal |
| D27 | Penomoran | — | Migrasi `0099` dan tes `079` tidak ada; `cs_api.nasabah_is_super_admin` punya dua overload (0050 dan 0186) |

