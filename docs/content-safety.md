# Keamanan Konten, DM, Banding, dan Integritas Pasar

Dokumen ini menjelaskan perilaku server (migrasi `0069`–`0072`) untuk keamanan konten komunitas OLT Social:
filter kata dan penyamaran, tautan dan kontak, pembatasan akun baru, permintaan pesan DM, banding,
deteksi manipulasi saham, slow mode room saham, serta prosedur CSAM. Semua aturan ditegakkan di database
sehingga berlaku untuk semua klien (Flutter, web, bot).

Tes: `supabase/tests/049_content_safety_test.sql`, `050_dm_requests_test.sql`, `051_appeals_test.sql`,
`052_market_integrity_test.sql`.

## 1. Alur pemeriksaan konten

Setiap postingan, komentar, dan pesan chat (kecuali chat CS) melewati trigger berurutan:

| Urutan | Trigger | Isi |
|---|---|---|
| `_10` | rate limit | batas kirim per menit/hari |
| `_20` | before write | rapikan teks, validasi lampiran |
| `_25` | integritas | mute/ban, persetujuan S&K, karakter kontrol, maks link/mention/kode saham, anti-duplikat |
| `_26` | slow mode (pesan room saham) | jeda antarpesan, 429 `slow_mode` |
| `_27` | permintaan pesan (DM) | kebijakan DM, batas 3 pesan sebelum diterima |
| `_30` | kata terlarang | sensor (`mask`) atau tolak (`block`), teks asli **dan** ternormalisasi |
| `_31` | keamanan konten | akun baru, tautan/domain, kontak, frasa promosi → `allow`/`censor`/`hold`/`block` |

Pemeriksaan `_25`–`_31` hanya untuk pengguna aplikasi yang menulis kontennya sendiri; staf yang
memoderasi, job server, dan seed tidak terkena.

### Kode error untuk klien

| HTTP | Kode | Arti | Detail |
|---|---|---|---|
| 422 | `content_blocked` | kata/frasa terlarang atau frasa promosi | pesan umum |
| 422 | `link_blocked` | tautan diblokir (judi, pornografi, phishing, dll.) | "Tautan ini tidak diizinkan." |
| 422 | `contact_blocked` | nomor HP/tautan grup chat diblokir | pesan umum |
| 403 | `new_account_restricted` | pembatasan akun baru | `image`, `link` |
| 403 | `dm_not_allowed` | penerima tidak menerima DM dari Anda | — |
| 403 | `dm_request_limit` | sudah 3 pesan, tunggu permintaan diterima | — |
| 429 | `slow_mode` | slow mode room saham | `details` = detik tunggu, header `Retry-After` |

Pesan error sengaja tidak menyebut kategori, kata, atau daftar yang cocok agar aturan tidak mudah diakali.
Konten yang **ditahan** (`hold`) tidak menghasilkan error: konten tersimpan dengan `moderation_status = 'held'`,
hanya terlihat oleh penulisnya, dan masuk antrean moderator.

## 2. Normalisasi teks (`private.normalize_for_policy`)

Dipakai untuk kata terlarang dan frasa promosi. Urutan:

1. NFKD + huruf kecil (fullwidth `ｂｏｋｅｐ`, huruf bulat `ⓑⓞⓚ`, huruf matematika, aksen `é` → huruf biasa);
   karakter tak terlihat (zero-width, soft hyphen) dan tanda aksen dibuang.
2. Homoglyph Cyrillic/Greek → Latin (`вокер` → `bokep`).
3. `$KODE` dan `@username` dibuang agar kode saham/username tidak memicu kata terlarang.
4. Huruf tunggal yang dipisah disatukan: `b.o.k.e.p`, `b-0-k-3-p`, `b o k e p`, `b . o . k` (pemisah
   harus konsisten dalam satu rangkaian).
5. Angka murni (`455`, `9.250`, `1.000`) dibuang; angka yang menempel huruf diproses leet
   (`0→o 1→i 3→e 4→a 5→s 7→t $→s @→a`), jadi `g0bl0k` tertangkap tetapi harga saham tidak berubah.
6. Huruf berulang diringkas; pencocokan memakai versi satu huruf (`anjjjing`, `goooblok`).

Pencocokan memakai token kata dan n-gram (bukan regex raksasa), terhadap teks asli **dan** teks
ternormalisasi, termasuk versi frasa tanpa spasi (`g r u p v i p` → `grupvip`). Kata yang hanya
ditemukan lewat normalisasi disensor di posisi aslinya (`kamu a.s.u` → `kamu *.*.*`); bila posisi tidak
bisa dipetakan (karakter sangat eksotis), konten ditolak.

**Allowlist** (`cs.policy_allowlist`): istilah yang dibuang sebelum pencocokan, mis. `bandar saham` bila
`bandar` disensor. Teks saham wajar seperti `$BBCA naik 5%`, `TP 9.250`, `cut loss`, `ARA`, `ARB`,
`PT Asuransi …`, `TF 15m 4h` diuji tidak berubah (tes 049).

Kinerja (2.000 kata terlarang, postingan 1.000 karakter): pemeriksaan kata + keamanan konten ±2,6 ms
per insert (total insert ±3,6 ms termasuk trigger lain).

## 3. Kategori dan aksi default

Aksi: `allow` (lolos), `censor` (bagian yang cocok diganti `[tautan disensor]` / `[nomor disensor]` / `***`),
`hold` (ditahan untuk ditinjau), `block` (ditolak). Cakupan: `public` = postingan, komentar, pesan room
saham; `all` = juga DM dan grup. Di DM/grup, `hold` diperlakukan sebagai `block` (pesan pribadi tidak
ditahan diam-diam dan tidak bocor lewat notifikasi).

| Kategori | Sumber | Aksi default | Cakupan |
|---|---|---|---|
| `gambling` | domain judi + kata kunci domain (`togel`, `gacor`, `slot88`, …) | block | all |
| `porn` | domain pornografi + kata kunci `bokep` | block | all |
| `phishing` | IP logger/phishing (`grabify.link`, `iplogger.org`, …) | block | all |
| `blocked` | domain lain yang diblokir Kepatuhan | block | all |
| `shortener` | pemendek: `bit.ly`, `s.id`, `tinyurl.com`, `cutt.ly`, `shorturl.at`, `t.co`, … | hold | public |
| `messenger` | `wa.me`, `chat.whatsapp.com`, `t.me`, `telegram.me`, `discord.gg`, `line.me`, … | hold | public |
| `phone` | nomor HP Indonesia `+62`/`62`/`08` dengan spasi, titik, strip, kurung | hold | public |
| `promotion` | frasa promosi: `grup vip`, `grup premium`, `sinyal berbayar`, `sinyal vip`, `join premium` | block | all |
| `other_link` | tautan lain yang tidak terdaftar | allow | public |

Ekstraksi domain menangkap tautan dengan/tanpa skema, `www.`, penyamaran `[dot]`, `(.)`, ` dot `,
titik fullwidth, dan subdomain. Domain tanpa skema hanya dikenali untuk TLD umum (com, net, xyz, vip, co.id, …)
atau domain yang ada di daftar, sehingga `BBCA.JK` atau `nah.in` tidak dianggap tautan.
**Domain tepercaya** (`cs.allowed_domains`, seed: idx.co.id, ojk.go.id, ksei.co.id, kpei.co.id, bi.go.id)
selalu lolos dan tidak dihitung sebagai tautan untuk akun baru.

Staf CS dan akun resmi dikecualikan dari kategori di atas dan dari pembatasan akun baru
(kata terlarang tetap berlaku). Chat CS (room `support`) tidak terkena kategori ini.

Konten yang ditahan: notifikasi mention/balasan/pesan untuk konten itu tidak dikirim, cuplikan room
saham tidak memuat pesan yang ditahan, link preview tidak dibuat. Moderator melihatnya di
`cs_api.community_held_content` beserta alasannya, lalu memutus lewat `cs_api.community_resolve_report`
(`approve`/`hide`/`remove`). Notifikasi tidak dikirim ulang setelah konten diloloskan.

## 4. Akun baru

Akun baru = `trust_level = 0`, **atau** `trust_level = 1` yang mendaftar (profil dibuat dengan trust 0
oleh auth-bridge) kurang dari `safety.new_account_days` hari (default 3). Akun yang dibuat staf/seed
dengan trust ≥ 1 tidak dihitung dari umur. Akun baru:

- tidak boleh melampirkan gambar (`new_account_restricted`, detail `image`);
- tidak boleh membagikan tautan selain domain tepercaya (detail `link`);
- DM ke orang yang tidak saling mengikuti selalu lewat permintaan pesan.

## 5. Permintaan pesan DM

- DM dari orang yang **tidak diikuti penerima** menjadi permintaan pesan (`private.dm_requests`, status
  `pending`). Untuk akun baru, syaratnya saling mengikuti.
- Pengirim maksimal `dm.request_max_messages` (3) pesan sampai diterima (`dm_request_limit`).
- Penerima: `accept`, `decline` (permintaan disembunyikan; pengirim tidak diberi tahu), atau `block`
  (blokir + laporan `spam` ke moderator). Membalas pesan juga berarti menerima.
- Kebijakan per pengguna: `everyone` (default, lewat permintaan), `following` (hanya yang saya ikuti;
  lainnya `dm_not_allowed`), `none` (tidak menerima DM baru). Percakapan yang sudah diterima tetap berjalan.
- Akun resmi dan staf CS tidak terkena kebijakan ini. DM yang sudah ada sebelum `0070` dianggap diterima.
- Room permintaan tidak tampil di `get_my_rooms`, tidak dihitung di `get_unread_counts` /
  `get_unread_chat_count`; jumlahnya lewat `get_message_request_count()`. Gambar di permintaan diburamkan
  oleh klien (`has_image` di `get_message_requests`).

RPC pengguna: `get_message_requests(p_limit, p_before)`, `get_message_request_count()`,
`respond_message_request(p_room_id, p_action)`, `get_dm_policy()`, `set_dm_policy(p_policy)`.

## 6. Banding

- Pengguna dapat membanding sanksi miliknya atau konten miliknya yang **disembunyikan** atau **dihapus
  moderator** (`create_appeal(p_target_type, p_target_id, p_reason)`, alasan 10–1000 karakter,
  maksimal 30 hari sejak penindakan — `appeals.window_days`, 10 banding/hari). Satu banding per target.
  Konten yang masih ditahan (`held`) sudah dalam antrean tinjauan sehingga tidak bisa dibanding.
- Akun yang di-ban tetap bisa memanggil `create_appeal`, `get_my_appeals`, dan `get_my_sanctions`
  (pengecualian di `private.check_request`); fitur lain tetap ditolak `user_banned`.
- Staf: `cs_api.community_appeals`, `cs_api.community_appeal_decide(id, accept, note)`. Banding sanksi
  butuh izin `community.sanction`, banding konten butuh `community.moderate`. Peninjau harus berbeda dari
  pemberi keputusan awal bila ada staf lain yang berwenang (`appeal_reviewer_conflict`).
- Diterima → sanksi dicabut / konten disembunyikan tampil lagi / konten yang dihapus dipulihkan dari
  arsip. Diterima atau ditolak → notifikasi tipe `appeal` ke pengguna (in-app + push lewat jalur yang ada).
  Semua keputusan tercatat di audit (`community.appeal_decide`).

## 7. Anti-manipulasi saham

Job `cs.detect_manipulation(p_at)` dijalankan pg_cron tiap 5 menit (`safety-manipulation`). Mention =
postingan yang memuat `$KODE` (komentar dan pesan room tidak dihitung). Sinyal (semua angka bisa diatur):

| Sinyal | Aturan default |
|---|---|
| `mention_spike` | mention 1 jam terakhir > 5× rata-rata per jam 7 hari sebelumnya, minimal 20 |
| `new_account_concentration` | > 60% mention 1 jam terakhir dari akun < 7 hari (atau trust 0), minimal 10 |
| `coordinated_posts` | posting mirip (`pg_trgm` similarity ≥ 0,8) dari ≥ 5 penulis berbeda dalam 30 menit |

Hasil di `cs.manipulation_alerts` (`stock`, `kind`, `score`, `evidence`, `status` open/reviewed/dismissed,
`auto_actions`); satu alert terbuka per saham + jenis (deteksi ulang memperbarui bukti). Aksi otomatis:

- slow mode room saham `manipulation.auto_slow_mode_seconds` (10 dtk) selama
  `manipulation.auto_slow_mode_minutes` (60 menit), tidak menimpa slow mode manual. Sejak `0110` slow mode
  otomatis paling ketat sama dengan `rooms.busy_slow_mode` (10 dtk bila jam ramai dimatikan), agar saham yang ramai
  secara wajar tidak tertahan lebih ketat dari jam ramai. Slow mode yang lebih ketat dinyalakan moderator secara manual;
- posting mirip terkoordinasi ditahan (`held`) dan tercatat dengan id alert.

Moderator meninjau (`reviewed`) atau menolak (`dismissed`). Menolak alert melepas posting yang ditahan
otomatis dan mematikan slow mode dari alert itu.

## 8. Room saham: slow mode dan pesan disematkan

Slow mode efektif = nilai terbesar dari:

- pengaturan moderator (`community_room_settings(code, detik, until)`; `until` kosong = permanen, 0 = mati);
- slow mode dari alert (sementara, `slow_mode_until`);
- jadwal jam ramai `rooms.busy_slow_mode` (10 dtk) pada `rooms.busy_windows` WIB
  (`08:55–09:30`, `15:50–16:15`) di hari bursa (`cs.is_business_day`, termasuk libur bursa).

Pesan yang terlalu cepat ditolak `429 slow_mode` dengan detik tunggu. Akun resmi tidak terkena. Moderator
menyematkan satu pesan per room (`community_pin_message(room, message|null)`). Pengguna membaca semuanya
lewat `get_stock_room_state(code)`: `slow_mode {seconds, until, source}`, `wait_seconds` milik pengguna,
`pinned_message` (bentuk baris pesan chat). Perubahan disiarkan ke channel Realtime `room:<id>` dengan
event `room_state`.

## 9. CSAM (materi eksploitasi seksual anak) — toleransi nol

1. Jangan membuka, mengunduh, atau meneruskan materi. Jangan menghapus bukti.
2. Staf dengan izin `community.sanction` menjalankan **`cs_api.community_zero_tolerance(user, alasan)`**:
   ban permanen (kategori `zero_tolerance`), semua sesi dicabut, semua postingan/komentar/pesan akun
   disembunyikan (bukan dihapus, sebagai bukti). Sanksi dan konten ini tidak bisa dibanding.
3. Gambar ditolak/ditahan oleh moderasi gambar (layanan classifier) bila terdeteksi; laporan pengguna
   masuk antrean moderasi dengan prioritas. Gambar pratinjau link (og:image dari situs luar) juga melewati
   classifier sebelum disimpan, lihat [Gambar pratinjau link](#gambar-pratinjau-link).
4. Pelaporan ke pihak berwenang (mis. aparat penegak hukum / kanal resmi pemerintah) dan penyimpanan
   bukti **ditentukan tim legal** — kanal pelaporan belum ditetapkan dan harus dilengkapi sebelum produksi.
5. Semua tindakan tercatat di audit (`community.zero_tolerance`).

### Gambar pratinjau link

Layanan `link-preview` 0.2.0 (migrasi `0094_link_preview_nsfw`) mengirim setiap gambar pratinjau yang
sudah dibersihkan ke classifier sebelum diunggah ke bucket publik `link-previews`, memakai **ambang yang
sama** dengan upload media (Kepatuhan → Ambang gambar, `media_moderation_config`).

| Verdict | Hasil pratinjau |
|---|---|
| `allow` | Gambar disimpan dan tampil |
| `block` (mis. pornografi) | Gambar dibuang, judul/deskripsi tetap tampil |
| `hold` (ragu-ragu) | Gambar tidak ditampilkan; **tidak** masuk antrean tinjauan (gambar milik situs luar, tidak ada pengunggah yang bisa ditinjau atau dibanding) |
| `unreadable` | Gambar dibuang |
| `unavailable` (classifier/ambang tidak tersedia) | Fail closed: pratinjau tanpa gambar, link dicoba lagi dengan jeda sampai `link_preview.max_attempts`; pratinjau tanpa gambar hanya di-cache `link_preview.failed_cache_hours` |

Verdict, kategori, skor, dan revisi ambang dicatat di `public.link_previews` (`image_verdict`,
`image_category`, `image_score`, `image_thresholds_revision`, `image_sha256`). Skor classifier di-cache per
SHA-256 gambar bersih di `private.link_preview_image_scores`, sehingga thumbnail yang sama (mis. logo situs)
tidak diklasifikasi ulang; keputusan selalu dihitung ulang dengan ambang terbaru. Constraint tabel
menolak `image_path` tanpa verdict `allow`. Gambar pratinjau lama (sebelum 0.2.0) dilepas saat migrasi dan
diklasifikasi saat link muncul lagi.

## 10. Yang bisa diatur dari web CS

| Pengaturan | Siapa | RPC |
|---|---|---|
| Aksi & cakupan per kategori | Kepatuhan (`compliance`) | `compliance_content_rules`, `compliance_set_content_rule` |
| Domain diblokir / kata kunci domain | Kepatuhan | `compliance_save_blocked_domain`, `compliance_delete_blocked_domain` |
| Domain tepercaya | Kepatuhan | `compliance_save_allowed_domain`, `compliance_delete_allowed_domain` |
| Allowlist istilah | Kepatuhan | `compliance_add_allowlist_term`, `compliance_delete_allowlist_term` |
| Frasa promosi | Kepatuhan | `compliance_add_promo_phrase`, `compliance_delete_promo_phrase` |
| Masa akun baru (0–30 hari) | Kepatuhan | `compliance_set_new_account_days` |
| Uji teks terhadap aturan | Kepatuhan | `compliance_test_content` |
| Kata terlarang + import Excel | Kepatuhan | `compliance_*_banned_word*` (0051) |
| Ambang gambar NSFW (upload media dan gambar pratinjau link) | Kepatuhan | `compliance_image_thresholds`, `compliance_set_image_thresholds` (0079) |
| Ambang deteksi manipulasi, aksi otomatis, jam ramai | Kepatuhan | `compliance_manipulation_settings`, `compliance_set_manipulation_settings` |
| Antrean konten ditahan | `community.moderate` | `community_held_content` + `community_resolve_report` |
| Alert manipulasi | `community.moderate` | `community_manipulation_alerts`, `community_manipulation_review` |
| Slow mode & pin room saham | `community.moderate` | `community_room_state`, `community_room_settings`, `community_pin_message` |
| Banding konten / sanksi | `community.moderate` / `community.sanction` | `community_appeals`, `community_appeal_decide` |
| Toleransi nol (CSAM) | `community.sanction` | `community_zero_tolerance` |

Semua perubahan tercatat di `cs.cs_audit_log`. Pengaturan lain (`dm.request_max_messages`,
`appeals.window_days`) ada di `private.settings` dan diubah lewat migrasi/operasional.

Sejak 0092 semua RPC ubah di tabel ini dipanggil web lewat gerbang draf `compliance_policy_call` (bagian 11).
RPC lama tetap ada; saat empat mata kebijakan aktif, memanggilnya langsung sebagai staf ditolak
`409 policy_review_required`.

## 11. Versi, draf, simulasi, dan empat mata kebijakan (0092)

**Isi kebijakan yang diversikan** (snapshot `private.policy_snapshot()`): kata terlarang (`public.banned_words`),
aksi & cakupan kategori (`cs.content_rules`), domain diblokir/tepercaya, istilah pengecualian, frasa promosi,
pengaturan `safety.new_account_days`, `manipulation.*`, `rooms.busy_slow_mode`, `rooms.busy_windows`
(`private.settings`), dan ambang gambar (`private.media_moderation`). Kebijakan kasus 0042 (tenggat pengaduan,
retensi) punya riwayat konfirmasi sendiri dan tidak ikut.

**Versi** (`cs.policy_versions`): nomor naik, snapshot penuh, ringkasan diff terhadap versi sebelumnya (per
bagian: tambah/hapus/ubah, maksimal 200 butir per bagian), sumber (`baseline`, `direct`, `change`, `rollback`,
`system`), alasan, permintaan asal, versi yang dipulihkan, pembuat, waktu. Tabel append-only
(`cs.reject_change`, termasuk TRUNCATE). Versi dibuat sekali per transaksi oleh constraint trigger deferred di
`private.policy_pending` yang ditandai trigger statement pada tiap tabel kebijakan, sehingga perubahan dari mana
pun (web, migrasi, operasional) tetap tercatat; perubahan tanpa staf tercatat sebagai `system`.

**Draf per staf** (`cs.policy_changes` status `draft`, satu per staf): tab di Kebijakan konten dan halaman Kata
terlarang memanggil `compliance_policy_call(p_fn, p_args)` dengan nama RPC lama yang di-whitelist. Gerbang
memuat draf ke tabel di dalam subtransaksi, menjalankan RPC asli (validasi sama persis), mengambil snapshot
baru, lalu membatalkan subtransaksi. Tabel aktif tidak berubah dan jejak audit RPC lama ikut dibatalkan. Draf
otomatis di-rebase ke versi terbaru: hanya butir yang diubah staf yang menimpa kebijakan berlaku.

| Aksi | RPC | Catatan |
|---|---|---|
| Status (empat mata, versi berlaku, draf + diff, jumlah tertunda) | `compliance_policy_state` | Kepatuhan dan Super Admin |
| Buang draf | `compliance_policy_discard` | |
| Ajukan/aktifkan draf | `compliance_policy_submit(p_reason)` | Alasan 5–500 karakter. Empat mata aktif: `pending`; nonaktif: langsung berlaku |
| Daftar & detail permintaan | `compliance_policy_changes`, `compliance_policy_change` | Detail memuat diff yang diajukan dan efeknya bila disetujui sekarang |
| Putuskan | `compliance_policy_decide(p_id, p_approve, p_note)` | Pembuat ≠ pemeriksa (`403 four_eyes`); tolak wajib alasan; Super Admin hanya melihat |
| Tarik | `compliance_policy_withdraw` | Hanya pembuat |
| Riwayat & detail versi | `compliance_policy_versions`, `compliance_policy_version` | Detail memuat diff versi dan diff pemulihan terhadap kebijakan berlaku |
| Pulihkan versi | `compliance_policy_rollback(p_version, p_reason)` | Membuat permintaan `rollback` berisi snapshot versi lama; setelah disetujui terbentuk versi baru dengan isi identik. Bila kebijakan berubah sebelum disetujui: `409 policy_stale` |
| Simulasi | `compliance_policy_simulate` | Lihat di bawah |
| Saklar empat mata | `admin_policy_four_eyes`, `admin_set_policy_four_eyes` | Super Admin, Pengaturan → Komunitas. Default aktif (`compliance.policy_four_eyes`) |

Audit: `policy_change.submit`, `policy_change.apply` (empat mata nonaktif), `policy_change.approve`,
`policy_change.reject`, `policy_change.withdraw`, `policy.rollback`, dan `setting.update` untuk saklar.

**Simulasi** hanya membaca (tanpa audit): target draf sendiri, permintaan tertunda, atau versi lama. Contoh teks
opsional plus konten nyata N hari terakhir (1–30, default 7, maksimal 1.000 terbaru): postingan, komentar, dan
pesan room saham; DM, grup, chat CS, akun staf, dan akun resmi tidak ikut. Setiap konten dinilai seperti
`compliance_test_content` (kata terlarang + kategori) dengan kebijakan berlaku dan dengan target di dalam
subtransaksi yang dibatalkan. Hasil: jumlah per aksi, berapa yang jadi lebih ketat/longgar, maksimal 100 konten
yang berubah, serta simulasi ambang gambar terhadap skor `private.media_reviews` (hanya gambar yang pernah ditahan
punya skor).
