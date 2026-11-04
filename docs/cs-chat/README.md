# Customer Service lewat Chat

Spesifikasi: [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) dan revisinya [PROMPT-CS-REVISI-2.md](../PROMPT-CS-REVISI-2.md). Bila keduanya bertentangan, yang berlaku Revisi CS-2. Rencana perubahannya ada di [revisi-2-rencana.md](revisi-2-rencana.md). Pendekatan ticketing lama dibatalkan ([arsip](../archive/customer-care/README.md), [audit pembersihan](audit-pembersihan.md)).

**Status (30 Okt 2026):** semua tahap Revisi CS-2 (R1–R4) sudah berjalan: backend model "ambil tiket", web CS, integrasi aplikasi nasabah, serta dashboard supervisor, laporan, dan pengaturan admin.

**Pembaruan 31 Okt 2026: satu dependensi keluar.** Server hanya memverifikasi token sosial yang ditandatangani OLT, secara lokal tanpa memanggil OLT ([olt-integration.md](../olt-integration.md)). `customer-adapter`, kartu order/transaksi dana, panel data nasabah (profil, order, dana, sesi, buka data tersamar, "Amankan akun"), dan web CS Flutter dihapus lewat migrasi `0037_client_owned_business_data`. Web CS kini hanya versi React.

**Pembaruan 31 Okt 2026: super admin hanya memantau dan mengelola.** Peran supervisor dan admin CS digabung menjadi **super admin** (`cs_super_admin`), dan login web CS cukup email + password tanpa TOTP (migrasi `0038_cs_supervisor_monitor_only` dan `0039_cs_super_admin_without_totp`). Super admin:
- tidak mengambil, membalas, menyelesaikan, melepas, atau mentransfer tiket, dan tidak pernah menerima tiket lewat transfer, pemindahan, atau pembagian otomatis;
- memantau dashboard, laporan, serta semua tiket dan percakapan (hanya baca), menulis catatan internal, mengubah prioritas dan tanda, dan memindahkan tiket ke CS lain agar tiket CS yang offline tidak tertahan;
- mengelola akun CS (membuat akun, mengubah peran dan batas tiket, menonaktifkan, mereset password yang lupa) serta semua pengaturan admin.

**Pembaruan 31 Okt 2026: menu Kepatuhan.** Peran `compliance` kini punya menu sendiri di web CS ([kepatuhan.md](kepatuhan.md), migrasi `0042_cs_compliance`): ringkasan pengaduan dan penipuan, register kasus dengan transkrip dan tinjauan, perpanjangan tenggat pengaduan (sekali, nasabah diberi tahu), unduh transkrip bersidik SHA-256, jejak audit, serta konfirmasi kebijakan tenggat pengaduan, perpanjangan, dan retensi chat. Kepatuhan tetap tidak menangani tiket.

| Tahap | Isi | Status |
|---|---|---|
| CS1 | Fondasi: perluasan chat, schema `cs`, RLS, catatan internal, audit log (`customer-adapter` dihapus 31 Okt 2026) | Selesai |
| **R1** | Backend model ambil tiket: `cs.tickets`, klaim atomik, transfer dengan persetujuan, `cs-sweep`, API tiket, tes rebutan | **Selesai** |
| **R2** | Web CS khusus (versi Flutter, dihapus 31 Okt 2026 setelah cutover ke React): login + TOTP, 3 kolom, ambil tiket, chat, catatan internal, balasan cepat, notifikasi | **Selesai** |
| **R3** | Integrasi aplikasi nasabah: modul `support` di `rendezvous_community` (room CS disematkan, pilih topik, header status, aksi, rating di chat, tiket saya, notifikasi lokal, antrean offline, peringatan data sensitif). Windows: panel samping. Android: layar penuh | **Selesai** |
| **R4** | Dashboard supervisor realtime + alert tiket terlambat, laporan + ekspor CSV, pengaturan admin (akun CS, topik, quick reply global, jam layanan & libur, pesan otomatis, lepas otomatis, mode penugasan), halaman demo dev dipindah ke model tiket (bagian 5) | **Selesai** |
| React | Web CS ditulis ulang dengan React + TypeScript ([`apps/cs-console-react`](../../apps/cs-console-react/README.md), [prompt](../PROMPT-CS-CONSOLE-REACT.md), [paritas](../cs-console-parity.md)). M1–M5 selesai; console Flutter dihapus 31 Okt 2026 | **Selesai** |

| Dokumen | Untuk |
|---|---|
| [olt-integration.md](../olt-integration.md) | Tim OLT: satu-satunya kebutuhan server, yaitu token sosial bertanda tangan saat login |
| [compliance-questions.md](compliance-questions.md) | Tim kepatuhan: 19 pertanyaan dengan usulan yang sudah dipakai sebagai pengaturan |
| [kepatuhan.md](kepatuhan.md) | Menu Kepatuhan di web CS: halaman, status tenggat, aksi, API, dan keputusan |

## Keputusan

Pemilik produk mendelegasikan pilihan ke tim. Yang dipilih beserta alasannya:

1. **CS = akun staf GoTrue (email + password) dengan profil chat khusus.**
   - `chat_members` dan `messages` merujuk `profiles`, jadi CS perlu baris profil agar bisa ikut room dan memakai widget chat yang sama.
   - Profil itu bertanda `olt_user_id = 'cs-staff:<id>'` dan dikunci dari fitur sosial: akun CS ditolak di API sosial, tidak muncul di pencarian, dan tidak bisa diajak DM atau dimasukkan ke grup.
   - Badge "CS Resmi" berasal dari `messages.sender_role`, yang hanya bisa diisi server untuk akun di `cs.agents`.
2. **Schema `cs` internal, `cs_api` diekspos lewat PostgREST.**
   - Nasabah mengirim dan membaca pesan lewat `cs_api.send_message`/`get_messages`, yaitu pembungkus tipis atas fungsi chat yang sama. Tidak ada sistem pesan kedua.
   - Nasabah yang di-ban dari fitur sosial tetap bisa menghubungi CS (pengecualian ban hanya untuk `cs_api`, realtime room CS, dan lampiran room CS).
   - **Lampiran chat CS, dua arah:**
     - Gambar (JPEG, PNG, WebP, GIF, maksimal 5 MB, bucket `attachments`) untuk screenshot dan foto bukti.
     - PDF (maksimal 10 MB, bucket privat `cs-documents`) untuk bukti transfer dari internet banking, formulir, dan surat.
     - Maksimal 4 lampiran per pesan.
     - Di web CS, lampiran bisa dipilih lewat tombol klip, diseret ke kotak balas, atau ditempel seperti di WhatsApp: tekan Print Screen (atau Win+Shift+S), lalu Ctrl+V di mana saja pada percakapan. Klik thumbnail untuk melihat pratinjau besar sebelum dikirim. Gambar di atas 5 MB otomatis dikecilkan menjadi JPEG (sisi terpanjang 2560 px, lalu 1920 px bila masih terlalu besar) sebelum diunggah.
     - Video, voice note, file Office, arsip, dan HEIC ditolak database (`attachment_not_allowed`): berat, sulit ditinjau Kepatuhan, dan file Office bisa membawa makro. Nasabah diminta mengirim screenshot atau PDF.
     - PDF hanya bisa diunggah dan dibaca nasabah pemilik room dan CS yang menangani tiketnya; Kepatuhan bisa membaca untuk tiket berflag.
     - Chat global tetap hanya gambar (migrasi `0053`, `0054`).
3. **Pengambilan tiket diputuskan database.** `cs.claim_ticket` mengunci baris status CS (`FOR UPDATE`), memeriksa status Online dan batas tiket aktif, lalu menjalankan satu `UPDATE ... WHERE status = 'open' AND owner_agent_id IS NULL`. Dua CS yang mengklik bersamaan tidak mungkin sama-sama berhasil, berapa pun replika API-nya. Yang kalah mendapat "Tiket sudah diambil oleh [nama]".
4. **Pemilik tetap pemilik.** Tiket hanya berpindah lewat tiga jalan: dilepas pemiliknya (wajib alasan), transfer yang **diterima** CS tujuan, atau reassign supervisor (wajib alasan, diaudit). CS yang offline tetap memiliki tiketnya. Nasabah diberi tahu "CS [nama] sedang tidak aktif". Lepas otomatis hanya bila `ticket.auto_release_offline_minutes` > 0 (default mati).
5. **CS Offline tidak membalas nasabah.** Mengambil tiket dan menerima transfer wajib berstatus Online dengan slot kosong. Membalas nasabah (teks, gambar, pilihan cepat, tautan bantuan) ditolak bila status Offline: database menolak pesan staf yang sedang Offline (`agent_offline`, migrasi `0041`), sementara status Sibuk/Istirahat tetap boleh menyelesaikan percakapan. Catatan internal, selesaikan, lepas, dan transfer keluar tetap boleh. Di web CS, tombol Ambil/Terima tidak mati diam-diam: saat diklik muncul notifikasi "Ubah ke Online dulu" dengan tombol **Ubah ke Online**, dan kotak balas (teks, lampiran, pesan khusus, tombol Kirim) dikunci dengan keterangan Offline dan tombol **Ubah ke Online**, tanpa menghapus draf. Tiket yang sudah selesai/ditutup menunjuk ke tiket aktif nasabah yang sama ("Buka tiket aktif"), supaya CS tidak tertinggal di tiket lama.
6. **Optimistic concurrency.** Aksi yang mengubah tiket (lepas, transfer, selesai, prioritas) bisa mengirim `version`. Bila tiket sudah berubah, aksi ditolak `stale_ticket` dan layar CS memuat ulang tiket.
7. **Akses CS ke riwayat:** semua CS bisa **pratinjau** pesan tiket `open` (hanya pesan tiket itu, hanya-baca). Pemilik membaca seluruh riwayat room nasabah selama menangani, dan sampai 24 jam setelah tiketnya selesai (`agent.history_hours`). Akses langsung dicabut saat tiket dilepas atau ditransfer.
8. **Pesan CS tidak bisa diubah nasabah.** Edit dan hapus pesan ditolak (`support_message_locked`), dan hapus akun tidak menghapus riwayat CS, karena transkrip adalah catatan pengaduan. Moderasi (service/admin) tetap bisa menghapus konten ilegal.
9. **Tidak ada data bisnis OLT di chat CS** (31 Okt 2026). Kartu order/transaksi dihapus. Nasabah menjelaskan masalah lewat teks atau gambar; topik dan asal layar tetap tercatat di tiket.
10. **Pesan CS yang meminta OTP/PIN/password diblokir tanpa melempar error.** Panggilan mengembalikan `status: blocked`, sehingga audit log dan peringatan ke supervisor tetap tersimpan.
11. **Room CS disematkan paling atas di daftar chat nasabah**, dengan nama dari pengaturan `brand.support_name` (default "CS OLT") dan badge resmi. Tidak bisa dibisukan atau ditinggalkan.
12. **Data dan aksi akun ada di back-office OLT** (31 Okt 2026). Web CS hanya menampilkan identitas dari token login, riwayat tiket, dan catatan internal; agen membuka back-office OLT untuk data akun atau aksi seperti logout paksa.

## Model data

Migrasi: `0026_care_cancel` (pembersihan), `0027_cs_foundation`, `0028_cs_sessions`, `0029_cs_api`, `0030_cs_session_detail`, `0031_cs_concurrency`, `0032_cs_tickets` (model ambil tiket), `0033_cs_tickets_api`, `0034_cs_room_members`, `0035_cs_supervisor_admin` (dashboard, laporan, pengaturan admin), `0037_client_owned_business_data` (hapus kartu order dan fungsi data nasabah), `0038_cs_supervisor_monitor_only`, `0039_cs_super_admin_without_totp`, `0040_cs_auto_assign_immediate`, `0041_cs_offline_agent_reply`, `0042_cs_compliance` (menu Kepatuhan), `0043_cs_auto_assign_reachable` (penugasan otomatis di luar jam layanan), `0044_cs_nasabah_access`–`0047_cs_nasabah_cs_only` (izin menu Akun Nasabah khusus akun CS, termasuk approve sendiri, [docs/nasabah](../nasabah/README.md)), `0048_cs_ticket_customer_login` (LoginId csAdmin nasabah tiket untuk panel info nasabah), `0049_cs_release_skips_releaser` (tiket yang dilepas tidak ditugaskan kembali ke CS yang melepas), `0050_cs_nasabah_integration_settings` (alamat csAdmin diatur Super Admin dari web), `0051_cs_banned_words` (kelola kata terlarang dari menu Kepatuhan, termasuk import), `0052_content_policy_prefilter` (filter kata terlarang memakai satu regex gabungan, sehingga daftar 2.000 kata tetap sekitar 1 ms per konten), `0053_cs_chat_documents` dan `0054_cs_documents_ban_exception` (PDF di chat CS, chat global hanya gambar), `0055_cs_nasabah_integration_verified` (integrasi API Nasabah aktif hanya setelah tes koneksi berhasil, tanpa nilai bawaan), `0056_cs_ticket_close_after_rating` (tiket ditutup setelah dinilai atau setelah batas hari tanpa rating, tiket tertutup tidak bisa dibalas, laporan per nasabah), `0057_cs_community` (menu Komunitas: akun resmi, postingan/pengumuman resmi dengan persetujuan dan jadwal, sematan, kampanye notifikasi, moderasi dan sanksi dari web CS; [docs/community](../community/README.md)), `0058_push_notifications` (push ke HP lewat layanan notifier + FCM untuk semua notifikasi, termasuk balasan CS; status dan push uji di Pengaturan → Push notification; [docs/push](../push/README.md)), `0059_push_credentials` (kunci Firebase diunggah Super Admin dari web, disimpan terenkripsi di Vault), `0060_storage_cleanup` (antrean pembersihan file storage diproses layanan janitor; hapus akun ikut membersihkan lampiran chat dan dokumen CS), `0061_backup_role` dan `0065_backups` (backup berkelanjutan ke S3, diatur Super Admin dari web; [docs/backup](../backup/README.md)), `0062_legal_documents` (dokumen hukum dikelola Kepatuhan dengan empat mata, chat CS tidak butuh persetujuan, ekspor data memuat tiket CS; [kepatuhan.md](kepatuhan.md#dokumen-hukum)), `0063_media_uploads` (upload nasabah wajib lewat layanan media yang memeriksa isi file dan membuang EXIF/GPS), `0064_system_health` (Kesehatan sistem dan alert Telegram/email; [docs/system-health](../system-health/README.md)), `0066_legal_draft_submitter` (ID pengaju draf dokumen hukum untuk tombol empat mata di web), `0067_vault_secret_recovery` (rahasia Vault yang tidak terbaca setelah restore ke server baru: alert + boleh diisi ulang dari web), `0068_integration` (gateway integrasi OLT: push transaksi per cust id dari klaim `accounts` token sosial dan posting bot resmi dengan API key dari web; [docs/integration](../integration/README.md)), `0069_content_safety`–`0072_market_integrity` (normalisasi filter, link/kontak, akun baru, permintaan pesan DM, banding, anti goreng saham, slow mode dan sematan room saham; [docs/content-safety.md](../content-safety.md)), `0073_search`–`0078_analytics`, `0081_trending_snapshot`, `0083_moderation_status_rows` (pencarian, hashtag, trending, sentimen, edit, bookmark, reaksi chat, share postingan, preferensi notifikasi, kill switch, feature flag, versi minimum, analitik; [docs/social](../social/README.md)), `0079_media_moderation` (moderasi gambar NSFW sebelum tampil), `0080_link_previews` (pratinjau link aman SSRF), `0094_link_preview_nsfw` (gambar pratinjau link lewat classifier NSFW dengan ambang yang sama seperti media, verdict dicatat dan skor di-cache per hash), `0093_room_moderators` (moderator room saham dari nasabah tepercaya: sembunyikan pesan, bisu sementara, eskalasi; diatur dan dibatalkan staf dari menu Komunitas; [docs/social](../social/README.md#moderator-room-0093)), `0082_health_new_services`, `0084_console_gaps`, `0085_client_gaps` (pelengkap web CS dan aplikasi: pemilih pesan sematan, buka konten per ID dengan pembatasan DM, statistik per key, platform desktop, status permintaan DM pengirim, konten yang dimoderasi untuk banding), `0092_policy_versions` (versi kebijakan konten bernomor dan append-only, draf per staf, simulasi terhadap konten nyata, pemulihan versi, dan empat mata kebijakan default aktif; [docs/content-safety.md](../content-safety.md#11-versi-draf-simulasi-dan-empat-mata-kebijakan-0092)), `0095_evidence_quarantine` (karantina bukti: konten yang dilaporkan/dihapus disalin utuh beserta file ke bucket privat `evidence` sebelum dibersihkan, append-only dengan sidik SHA-256 dan jejak penanganan berantai, masa simpan 730 hari + legal hold, menu **Kepatuhan → Bukti** dengan ekspor paket; [docs/evidence](../evidence/README.md)), `0096_room_mute_privacy` (daftar bisu room saham tidak lagi disiarkan ke anggota: hanya moderator room itu dan staf yang melihatnya, anggota yang dibisukan diberi tahu lewat notifikasi `moderation` pribadinya; [docs/social](../social/README.md#privasi-bisu-0096)), `0098_realtime_broadcast_delivery` (pesan chat, termasuk chat CS, dikirim lewat Broadcast dari database ke topik privat; web CS menerima sinyal `message` di `cs:room:<id>` dan typing CS lewat `cs_api.agent_typing`; klien tidak bisa lagi mengirim event server palsu; [docs/social](../social/README.md#pengiriman-pesan-realtime-0098)). RLS aktif di semua tabel `cs` (termasuk partisi).

**Perluasan chat yang ada:**
- `chat_rooms.type` + `support`, kolom `customer_id`, satu room `support` per nasabah (unique index). Semua tiket nasabah ada di room yang sama.
- `messages` + `kind` (`text`, `system`, `quick_reply`, `help_link`, `identity_request`, `csat`), `session_id` (menunjuk tiket), `sender_role` (`customer`/`agent`/`supervisor`/`system`), `payload`. Tipe `chat_message` ikut diperluas (kompatibel dengan client lama).

**Schema `cs`:**

| Tabel | Isi |
|---|---|
| `agents`, `agent_skills`, `agent_status` | Akun CS (peran `cs_agent`, `cs_super_admin`, `compliance`), skill level 1–3, batas tiket aktif (default 5), status, jumlah tiket aktif, heartbeat |
| `teams`, `skills`, `support_topics`, `vip_customers` | 6 tim, 8 skill, 7 topik (topik → skill → prioritas default) |
| `tickets` | Tiket: nomor `CS-YYYYMMDD-NNNN` (urut per hari WIB), topik, prioritas, flag, status, pemilik, `version`, semua waktu, hasil + ringkasan, tag, rating, tenggat pengaduan. Maksimal satu tiket aktif per nasabah |
| `ticket_transfers` | Permintaan transfer: pengirim, tujuan, catatan serah terima, kedaluwarsa 10 menit, hasil |
| `ticket_counters` | Penghitung nomor tiket per hari |
| `session_events` | Log append-only perjalanan tiket (partisi bulanan) |
| `agent_notes` | Catatan internal per tiket atau per nasabah, append-only, **terpisah dari `messages`**. Catatan serah terima transfer ikut disimpan di sini |
| `quick_replies` | Balasan cepat pribadi/tim/global |
| `cs_settings`, `cs_settings_history` | Pengaturan berversi (jam layanan, mode penugasan, batas, pesan otomatis ID/EN) |
| `holidays` | Kalender libur 2026–2027 (nasional, cuti bersama, libur bursa) |
| `cs_audit_log` | Audit append-only semua aksi CS, super admin, dan kepatuhan (partisi bulanan) |
| `compliance_reviews` | Tinjauan kepatuhan per kasus (putusan + catatan), append-only |
| `policy_confirmations` | Konfirmasi kepatuhan per versi pengaturan kebijakan, append-only |

## Status tiket

| Dari | Ke | Pemicu |
|---|---|---|
| `open` | `claimed` | CS mengambil tiket. Atau penugasan otomatis bila `assignment.mode = auto_assign` |
| `claimed` | `waiting_customer` | CS menandai sedang menunggu balasan nasabah |
| `waiting_customer` | `claimed` | Nasabah membalas |
| `claimed`, `waiting_customer` | `claimed` (pemilik baru) | Transfer diterima CS tujuan, atau reassign super admin |
| `claimed`, `waiting_customer` | `open` | Pemilik melepas tiket (wajib alasan), atau lepas otomatis saat offline (bila diaktifkan) |
| `claimed`, `waiting_customer` | `resolved` | Pemilik menyelesaikan: hasil + ringkasan 5–500 karakter. Nasabah diminta rating |
| `resolved` | `claimed` | Nasabah membalas sebelum memberi rating dan sebelum batas tutup otomatis (`ticket.auto_close_days`, default 3 hari), dan pemilik lama masih aktif dan punya kapasitas |
| `resolved` | `open` | Sama seperti di atas, tetapi pemilik lama tidak aktif > 10 menit atau penuh |
| `resolved` | `closed` | Nasabah memberi rating (langsung ditutup, alasan `rated`), batas hari terlewati tanpa rating (`cs-sweep`, alasan `reopen_window_passed`), atau digantikan tiket baru |
| `open`, `claimed`, `waiting_customer` | `closed` | Nasabah mengakhiri chat |

- Transisi yang sah ditegakkan `cs.transition_allowed`. Constraint menjamin `open` tanpa pemilik dan `claimed`/`waiting_customer` selalu punya pemilik.
- **Tiket yang sudah ditutup tidak bisa dibalas** (migrasi `0056`). Pesan nasabah ke room yang tiket terakhirnya `closed`, atau `resolved` tetapi sudah dinilai/lewat batas hari, ditolak `409 ticket_closed`. Aplikasi nasabah mengganti kotak ketik dengan keterangan "Tiket #… sudah ditutup" dan tombol **Buat tiket baru** (pilih topik → `open_ticket`). Alasan tutup tersimpan di `tickets.close_reason` (`rated`, `reopen_window_passed`, `customer`, `superseded`).
- Pesan nasabah di room tanpa tiket sama sekali membuka tiket baru dengan topik default. Pesan yang datang bersamaan dilayani berurutan lewat kunci baris tiket terakhir: selalu tepat satu tiket aktif per nasabah.
- Pesan `agent` hanya diterima dari pemilik tiket aktif. Super admin tidak mengirim pesan; pesan `supervisor` lama tetap tampil di riwayat.
- Job pg_cron `cs-sweep` (tiap 10 detik): kedaluwarsakan transfer, tutup tiket `resolved` yang sudah dinilai atau lewat batas hari tanpa rating, lepas otomatis (bila diaktifkan), penugasan otomatis (bila mode `auto_assign`).
- Penugasan otomatis berjalan **langsung** di akhir transaksi (constraint trigger deferred, migrasi `0040`) saat tiket masuk antrean, CS menjadi Online atau punya slot kosong, dan saat mode diubah ke `auto_assign`. Penugasan tercatat sebagai aksi `system`. `cs-sweep` tetap menjadi jaring pengaman, misalnya untuk CS yang heartbeat-nya baru segar lagi. CS yang mendapat tiket diberi bunyi dan notifikasi "Tiket baru ditugaskan ke Anda" di web CS.
- Penugasan otomatis tidak dibatasi jam layanan (migrasi `0043_cs_auto_assign_reachable`): selama ada CS yang Online, punya slot kosong, menguasai bahasa tiket, dan heartbeat web CS-nya lebih baru dari `assignment.heartbeat_seconds` (90 detik), tiket langsung dibagikan, termasuk di luar jam layanan. Urutannya: level skill topik tertinggi, lalu tiket aktif paling sedikit, lalu yang paling lama tidak mendapat tiket. Batas 90 detik dipilih karena browser memperlambat tab di latar belakang hingga sekitar satu heartbeat per menit. Pesan "Saat ini di luar jam layanan" hanya ditambahkan ke pesan tiket dibuka bila tidak ada CS yang bisa melayani.
- Tiket yang dilepas pemiliknya tidak ditugaskan otomatis kembali ke CS yang melepas (migrasi `0049_cs_release_skips_releaser`, kolom `cs.tickets.released_by`). Tiket langsung diberikan ke CS lain yang memenuhi syarat di atas walau level skill-nya lebih rendah. Bila tidak ada, tiket menunggu di antrean Terbuka sampai ada CS lain yang Online. CS yang melepas tetap boleh mengambilnya kembali secara manual. Pengecualian ini hanya untuk pelepas terakhir dan hilang begitu status tiket berubah. Lepas otomatis karena pemilik offline tidak memakai pengecualian ini.

**Prioritas awal:** prioritas default topik, dinaikkan oleh flag (`fraud` → P1, `complaint` → maks P2) dan kata kunci di pesan pertama (`priority.rules`, mis. "dibobol", "penipuan" → P1 + fraud; "tidak bisa order" di jam bursa → P1).

**Pengaduan:** flag `complaint` mencatat waktu diterima dan tenggat (`complaint.days` hari kerja, kalender WIB). Nasabah langsung mendapat pesan berisi keduanya. Tiket tidak dipindah otomatis: prioritasnya naik dan tandanya terlihat di daftar.

## Akses

| | Nasabah | `cs_agent` | `cs_super_admin` | `compliance` |
|---|---|---|---|---|
| Room & pesan CS | Miliknya | Pratinjau tiket `open`. Pemilik: seluruh room selama menangani (+24 jam) | Semua (hanya baca) | Tiket berflag pengaduan/fraud |
| Catatan internal | **Tidak pernah** | Nasabah yang sedang ditangani | Semua | Tiket berflag |
| Tiket & log kejadian | Ringkasan aman (`support_home`, `my_tickets`) | Tiket `open` + miliknya | Semua | Tiket berflag |
| Menangani tiket (ambil, balas, selesaikan, lepas, transfer) | – | Tiket miliknya | – (hanya memantau) | – |
| Memindahkan tiket ke CS lain | – | – | Ya | – |
| Dashboard | – | – | Ya | – |
| Laporan + ekspor CSV | – | – | Ya | – |
| Akun CS (buat, ubah, nonaktifkan, reset password) dan pengaturan admin | – | – | Ya | – |
| Audit log | – | – | Ya | Ya (menu Jejak Audit) |
| Ringkasan kepatuhan, register kasus + ekspor CSV, tinjauan, perpanjang tenggat pengaduan, unduh transkrip | – | – | – | Ya (tiket berflag) |
| Kebijakan tenggat pengaduan, perpanjangan, dan retensi chat | – | – | – | Ya |
| Kata terlarang aplikasi nasabah (tambah, ubah aksi, hapus, import/unduh Excel) | – | – | – | Ya |
| Channel realtime | `cs:room:<room miliknya>` | `cs:queue`, `cs:agent:<diri>`, `cs:room:<yang ditangani>` | Sama | `cs:room` berflag |

Semua dicek di server (RLS + fungsi). Login web CS cukup email + password (tanpa TOTP); di produksi web CS hanya bisa diakses dari IP yang diizinkan (LAN kantor atau VPN). Akun nonaktif langsung kehilangan akses. Client tidak bisa mengirim broadcast ke channel `cs:*` (hanya server), sehingga event status tidak bisa dipalsukan.

## API `cs_api`

| Untuk | Fungsi |
|---|---|
| Nasabah | `topics`, `support_home`, `open_ticket`, `my_tickets`, `ticket_messages`, `send_message`, `get_messages`, `mark_read`, `close_ticket`, `rate_ticket`, `request_complaint`, `report_fake_cs`, `check_sensitive` |
| CS | `agent_me`, `agent_set_status`, `agent_heartbeat`, `ticket_lists` (Terbuka / Saya / Selesai hari ini / transfer masuk & keluar), `search_tickets`, `claim_ticket`, `release_ticket`, `request_transfer`, `respond_transfer`, `cancel_transfer`, `wait_customer`, `resolve_ticket`, `set_ticket_priority`, `flag_ticket`, `agent_send_message` (`text`, `quick_reply`, `help_link`), `add_note`, `notes`, `ticket_detail`, `customer_history`, `online_agents`, `room_members`, `quick_replies` |
| Super admin (`cs_super_admin`) | Memantau: `ticket_lists` (termasuk tab "Semua aktif"), `ticket_detail`, `get_messages`, `notes`, `add_note`, `customer_history`, `set_ticket_priority`, `flag_ticket`, `reassign_ticket` (ke akun `cs_agent`), `online_agents`, `supervisor_overview`, `report_summary`. Mengelola: `admin_agents`, `admin_options`, `admin_update_agent`, `admin_reset_password`, `admin_topics`, `admin_save_topic`, `admin_quick_replies`, `admin_save_quick_reply`, `admin_settings`, `admin_set_setting`, `admin_holidays`, `admin_save_holiday`, `admin_delete_holiday`. Akun baru dan reset password lewat Edge Function `cs-admin`. Aksi menangani tiket ditolak `role_forbidden` |
| Kepatuhan (`compliance`) | `compliance_overview`, `compliance_cases`, `compliance_case`, `compliance_review`, `compliance_extend_deadline`, `compliance_transcript_exported`, `compliance_audit`, `compliance_policies`, `compliance_confirm_policy`, serta `ticket_messages` untuk transkrip tiket berflag. Detail di [kepatuhan.md](kepatuhan.md) |
| Layanan (service role) | `service_create_agent`, hanya dipanggil Edge Function `cs-admin` |

Topik realtime (event dikirim server):
- `cs:queue`: `ticket_opened`, `ticket_claimed` (+ nama pengambil), `ticket_released`, `ticket_transferred`, `ticket_reassigned`, `ticket_resolved`, `ticket_reopened`, `ticket_closed`, `ticket_updated`, `ticket_message`, serta peringatan supervisor.
- `cs:agent:<id>`: event tiket miliknya dan permintaan transfer masuk.
- `cs:room:<room_id>`: status tiket untuk nasabah.

Mengetik dan tanda dibaca tetap memakai channel `room:<id>` milik widget chat.

## Pengaturan dan batas

- Pengaturan di `cs.cs_settings` (berversi, riwayat di `cs_settings_history`):
  - Jam layanan dan jam bursa.
  - Mode penugasan (`claim` / `auto_assign`).
  - Waktu: tutup otomatis tiket selesai tanpa rating (`ticket.auto_close_days`, 1–30 hari, default 3; diatur Super Admin di Pengaturan → Penugasan, tiket & alert), riwayat CS, ambang CS dianggap tidak aktif (10 menit), lepas otomatis saat offline (default mati), kedaluwarsa transfer (10 menit).
  - Penyelesaian: aturan prioritas, tenggat pengaduan, hasil penyelesaian.
  - Lainnya: host tautan bantuan dan pesan otomatis ID/EN.
- Rate limit (`private.rate_limits`, tanpa faktor trust): `cs_ticket` 5 tiket baru/jam, `cs_message` 30 pesan/menit.

## Super admin (R4, digabung 31 Okt 2026)

**Dashboard** (`supervisor_overview`, dimuat ulang setiap ada event `cs:queue` dan tiap 30 detik):
- Jumlah tiket terbuka, waktu tunggu terlama, tiket yang sedang ditangani, selesai hari ini, dan CS online.
- Tiga daftar "Perlu perhatian":
  - tiket terbuka yang belum diambil melewati `alerts.unclaimed_minutes` (10 menit) atau P1 melewati `alerts.p1_unclaimed_minutes` (2 menit);
  - tiket fraud/pengaduan yang belum diambil;
  - tiket milik CS yang offline atau tidak mengirim heartbeat.
- Tabel status CS: status, koneksi, tiket aktif/batas, selesai hari ini.
- Tiket terlambat memicu suara + notifikasi browser untuk super admin (sekali per tiket). Jumlah tiket yang perlu perhatian tampil sebagai badge di menu Dashboard. Mengetuk tiket membukanya di menu **Layanan Nasabah** (hanya baca), tempat super admin bisa memindahkan tiket atau mengubah prioritas.

**Laporan** (`report_summary`, maksimal 93 hari, hari dihitung WIB): tiket per hari, waktu sampai diambil, waktu respons pertama, durasi sampai selesai, rating per CS, dan topik terbanyak. Ekspor CSV per bagian (harian, per CS, topik, per nasabah).

**Per nasabah** (`report_customers`, `report_customer_trail`, migrasi `0056`): performa layanan tiap nasabah pada rentang laporan, yaitu jumlah tiket, selesai, dibuka kembali, pengaduan, respons pertama, durasi sampai selesai, rating rata-rata, dan tiket yang ditutup otomatis tanpa rating. Bisa dicari menurut nama/username, maksimal 200 nasabah. Klik nama nasabah untuk membuka **jejak layanan**: tiap tiket (maksimal 100) dengan CS penangan, waktu diambil/respons/selesai, rating dan komentarnya, alasan tutup, serta seluruh event tiket. Membuka jejak layanan tercatat di audit log (`report.customer_trail`). Sel teks dinetralkan dari formula spreadsheet (`=`, `+`, `-`, `@`).

**Pengaturan admin:**
- **Akun CS.** Super admin menambah akun dan mereset password lewat Edge Function `cs-admin` (`docker/volumes/functions/cs-admin`). Fungsi ini:
  - memeriksa bahwa pemanggil adalah super admin;
  - membuat user GoTrue dengan password sementara acak 20 karakter yang hanya ditampilkan sekali;
  - memanggil `cs_api.service_create_agent`, dan menghapus user GoTrue lagi bila langkah ini gagal.

  Reset password (`POST /functions/v1/cs-admin/agents/<id>/reset-password`) membuat password sementara baru yang hanya ditampilkan sekali dan tercatat di audit log. Saat login pertama atau setelah reset, CS wajib mengganti password. Kunci service role hanya ada di container functions, tidak pernah di client.
- **Menonaktifkan akun:**
  - login GoTrue diblokir;
  - akses `cs_api` langsung dicabut;
  - tiket aktif CS tersebut kembali `open` dengan tanda "Akun CS dinonaktifkan";
  - transfer yang menunggu CS itu dibatalkan.

  Admin tidak bisa menonaktifkan diri sendiri atau melepas peran adminnya sendiri.
- **Topik dan prioritas default, serta quick reply global.** Tautan bantuan wajib `https` ke host di `help.allowed_hosts`. Quick reply yang meminta OTP/PIN/password ditolak.
- **Jam layanan (WIB) dan hari libur.** Libur nasional dan cuti bersama menutup layanan. Libur bursa hanya menutup pasar.
- **Pesan otomatis ID/EN.** Hanya variabel yang sudah ada yang boleh dipakai.
- **Lepas otomatis bila pemilik offline** (default mati), mode penugasan `claim` (default) atau `auto_assign`, dan batas alert supervisor.
- Hanya kunci pengaturan di atas yang bisa diubah dari console. Retensi dan pengaturan lain tetap lewat migrasi. Setiap perubahan tercatat di `cs_settings_history` dan `cs_audit_log`.

## Tes

| Perintah | Isi |
|---|---|
| `make test-db` | pgTAP CS (018–023, 026–027): kalender, alur tiket (82 tes), keamanan & akses (61 tes), masking, anggota room, super admin hanya memantau (17 tes), super admin & tanpa TOTP (11 tes), dashboard & pengaturan (69 tes: dashboard, laporan, nonaktifkan akun, validasi pengaturan, hak akses) |
| `make cs-race` | Tes rebutan (Revisi CS-2 bagian 2.3). 50 CS mengambil 1 tiket bersamaan: tepat 1 berhasil, 49 mendapat "Tiket sudah diambil oleh …". 200 tiket × 30 CS acak bersamaan: tidak ada tiket ganda, tidak ada CS melebihi 5 tiket aktif, respons yang diterima CS sama persis dengan pemilik di database. Dijalankan langsung ke fungsi database dan lewat 3 replika PostgREST khusus tes. Data uji dihapus setelahnya |
| `make smoke-cs` | End-to-end lewat Kong + OLT dummy (30 pemeriksaan): buka tiket, ambil, rebutan, balas, OTP diblokir, catatan, lampiran gambar dari CS, transfer, versi kedaluwarsa, selesai, rating |
| `make test-cs-console` | Web CS React: lint, typecheck, 74 unit test, build, bundle awal ≤ 300 KB gzip, lisensi |
| `make e2e-cs-console` | Web CS React, Playwright vs stack dev (22 tes): login email + password, dua akun di dua tab tanpa saling memutus, rebutan klaim, chat + lampiran + tanda dibaca, lepas/transfer/selesai, non-pemilik hanya-baca, putus-sambung tanpa duplikat, supervisor memantau + memindahkan tiket, tampilan terang/gelap, kinerja 1000 tiket + 5000 pesan |

## Menjalankan

```bash
make up DUMMY_OLT=1          # Windows: .\make.ps1 up -DummyOlt
make test-db && make cs-race && make smoke-cs
make cs-console-react        # web CS React di http://localhost:8085 (akun dev: scripts/cs-demo/runtime/staff.json)
make cs-demo                 # halaman demo (dev) di http://localhost:8082
```

## Web CS dan akun staf

- **GoTrue:** login email + password dinyalakan khusus akun staf yang dibuat super admin. Pendaftaran publik tetap mati, password minimal 12 karakter, dan web CS tidak memakai TOTP.
- **Super admin pertama:** `make cs-bootstrap-admin EMAIL=... NAME="..."` (Windows: `.\make.ps1 cs-bootstrap-admin -Email ... -Name "..."`) dari server, di lingkungan mana pun. Password sementara dicetak sekali dan wajib diganti saat login pertama. Akun berikutnya dibuat super admin dari Pengaturan → Akun CS.
- **Akun staf dev:** dibuat `scripts/cs-staff-setup.sh` lewat API admin GoTrue (UUID akun = UUID agen), tanpa TOTP: Nadia, Bima, Laras (CS), Sinta dan Adi (super admin). Akun baru di luar itu dibuat super admin dari menu Pengaturan → Akun CS.
- **Realtime:** daftar tiket dimuat ulang saat ada event `cs:queue`/`cs:agent:<id>`, ditambah polling 30 detik sebagai cadangan.

**Halaman demo** (`scripts/cs-demo`) hanya alat pengembangan dan khusus profil `dev`. UI resminya adalah web CS React dan aplikasi nasabah (R3).
- Nasabah login dengan token OLT tiruan.
- Tiga CS demo (Nadia, Bima, Laras) memakai token uji berlaku 8 jam, disimpan di `scripts/cs-demo/runtime/` (di-gitignore).

Halaman ini sudah memakai model tiket dan perbaikan bagian 5:
- header nasabah selalu mengikuti status tiket dari server;
- satu pesan sistem ringkas per kejadian;
- CS offline tetap memiliki tiketnya ("CS [nama] sedang tidak aktif…");
- membalas setelah `resolved` membuka tiket kembali ke CS pemilik;
- jam `HH.mm` dengan pemisah tanggal;
- panel CS: ambil tiket, pratinjau hanya-baca, tunggu nasabah, lepas, selesaikan.
