# Rencana Perubahan Revisi CS-2 (model "ambil tiket")

> **Catatan 31 Okt 2026:** dokumen historis. `customer-adapter`, kartu order, dan panel data nasabah sudah dihapus karena server hanya boleh memvalidasi token ke OLT ([olt-integration.md](../olt-integration.md)).

> **Dasar:** [PROMPT-CS-REVISI-2.md](../PROMPT-CS-REVISI-2.md), yang berlaku bila bertentangan dengan [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md).
> **Status (30 Okt 2026):** disetujui pemilik produk ("gak perlu nanya lagi, approve aja, sesuaikan yang recommended"). Dikerjakan berurutan R1 → R4.

## 1. Dipakai ulang tanpa perubahan berarti

| Bagian CS1 | Dipakai untuk |
|---|---|
| Room `support` permanen per nasabah, kolom `messages.kind/session_id/sender_role/payload`, tipe `chat_message` | Riwayat chat tetap satu room. `session_id` kini menunjuk tiket |
| Masking, deteksi permintaan OTP/PIN dari agen (pesan ditahan + peringatan supervisor), deteksi data sensitif sebelum kirim | Tidak berubah |
| Kalender libur, jam layanan, tenggat pengaduan hari kerja | Tidak berubah |
| `agent_notes` (tabel terpisah), `quick_replies`, `cs_settings` berversi, `cs_audit_log` & `session_events` append-only + partisi | Tidak berubah. Event baru: `claimed`, `released`, `transfer_requested`, `transferred`, `reassigned`, `waiting_customer`, `resolved`, `reopened`, `closed` |
| Identitas agen (akun staf + profil chat terkunci, `aal2`), akun CS ditolak di API sosial, nasabah ter-ban tetap bisa ke CS | Tidak berubah |
| `customer-adapter` (data OLT, buka field dengan alasan, amankan akun) dan OLT dummy | Tidak berubah, hanya rute & parameter ke tiket |
| Rate limit (5 tiket baru/jam, 30 pesan/menit), batas buka data nasabah per jam | Tidak berubah |

## 2. Diubah

| Bagian | Perubahan |
|---|---|
| **`cs.support_sessions` → `cs.tickets`** | Tabel di-*rename* lewat migrasi baru (data dan relasi pesan tetap). Kolom baru: `ticket_number` (`CS-YYYYMMDD-NNNN`, urut per hari WIB tanpa celah), `version`, `claimed_at`, `resolved_at`, `resolved_by`, `resolution_summary`, `returned_reason`. `current_agent_id` → `owner_agent_id`, `last_agent_id` → `last_owner_id`, `accepted_at` → `first_claimed_at`, `close_outcome` → `outcome` |
| **Status** | `queued/offered/active/transferring/reopened/closed` → `open/claimed/waiting_customer/resolved/closed`. State machine baru di server. Satu tiket aktif per nasabah (partial unique index). `claimed`/`waiting_customer` wajib punya pemilik, `open` wajib tanpa pemilik (constraint) |
| **Penugasan** | `cs.claim_ticket()`: satu `UPDATE ... WHERE status = 'open' AND owner IS NULL` atomik, setelah mengunci baris status agen (`FOR UPDATE`) untuk cek Online + batas tiket aktif di transaksi yang sama. Lepas (wajib alasan), transfer ke CS (penerima harus menerima, tiket tetap milik pengirim sampai diterima), dan reassign supervisor (wajib alasan, diaudit). Aksi ubah tiket memakai `version` (*optimistic concurrency*) |
| **Batas tiket aktif** | `agents.max_concurrent` → `max_active_tickets`, default 5, bisa diatur per CS |
| **Trigger pesan** | Pesan `sender_role = 'agent'` hanya diterima dari **pemilik tiket aktif**. Pesan `supervisor` hanya dari supervisor yang sudah bergabung. Pesan nasabah saat `waiting_customer` mengembalikan tiket ke `claimed` |
| **Pesan sistem** | Dirapikan menjadi satu pesan per kejadian: tiket dibuka (salam + pengingat keamanan + info jam layanan), diambil, dialihkan, dikembalikan ke antrean, CS tidak aktif, diselesaikan (+ rating), dibuka kembali, ditutup. Pesan "Koneksi CS terputus…" dihapus |
| **Agen offline** | Tiket **tetap milik** agen. Nasabah mendapat pesan "CS [nama] sedang tidak aktif…". Lepas otomatis hanya bila `ticket.auto_release_offline_minutes` > 0 (default 0 = mati) |
| **Akses baca agen** | Semua CS bisa **pratinjau** pesan tiket `open` (hanya pesan tiket itu, hanya-baca). Pemilik membaca seluruh riwayat room. Riwayat tetap terbaca 24 jam setelah tiket yang ia tangani selesai. Supervisor membaca semua |
| **Realtime** | `cs:queue` kini untuk semua CS (daftar tiket terbuka). Event: `ticket_opened`, `ticket_claimed` (+ nama pengambil), `ticket_released`, `ticket_transferred`, `ticket_reassigned`, `ticket_resolved`, `ticket_reopened`, `ticket_closed`, `ticket_updated`, `ticket_message` |
| **API `cs_api`** | Istilah sesi → tiket: `open_ticket`, `support_home`, `my_tickets`, `close_ticket`, `rate_ticket`, `ticket_lists`, `search_tickets`, `claim_ticket`, `release_ticket`, `request_transfer`/`respond_transfer`/`cancel_transfer`, `reassign_ticket`, `join_ticket`, `wait_customer`, `resolve_ticket`, `set_ticket_priority`, `flag_ticket`, `ticket_detail`, `online_agents`, `room_members`, plus API supervisor & admin di R4 |
| **`customer-adapter`** | Rute `/v1/agent/sessions/{session}/…` → `/v1/agent/tickets/{ticket}/…` |
| **Pengaduan** | Tanda pengaduan tidak lagi memindahkan tiket otomatis. Prioritas naik ke P2 dan tiket terlihat dengan tanda di daftar |
| **Halaman demo** (`scripts/cs-demo`) | Tetap khusus profil `dev`. Disesuaikan ke model ambil tiket dan perbaikan bagian 5 |
| **GoTrue** | Login email + password dinyalakan **hanya untuk akun staf yang dibuat admin** (pendaftaran publik tetap mati). TOTP wajib, karena API CS menuntut `aal2` |

## 3. Dinonaktifkan / dihapus

| Bagian | Alasan |
|---|---|
| Penawaran ke agen dengan hitung mundur (`match_offers`, `cs.offer`, `accept/reject_offer`, timeout beruntun → istirahat otomatis) | Diganti model ambil tiket. Tabel diganti `cs.ticket_transfers` untuk transfer yang perlu diterima |
| Pengembalian otomatis sesi ke antrean saat agen offline (`cs.release_agent`, `requeue_session`) | Bertentangan dengan aturan "pemilik tetap pemilik" |
| Pengganti sementara matcher di halaman demo (`cs-demo-matcher`) | Tidak diperlukan. Tugas berkala dikerjakan job pg_cron `cs-sweep` (tiap 10 detik): transfer kedaluwarsa, tutup otomatis tiket `resolved` setelah 24 jam, lepas otomatis (bila diaktifkan), dan penugasan otomatis (bila mode `auto_assign`) |
| Mode `auto_assign` | **Disimpan sebagai opsi** di pengaturan (`assignment.mode`, default `claim`). Saat aktif, sweep menugaskan tiket langsung ke agen Online dengan skill paling cocok, lalu beban paling ringan |

## 4. Yang baru

| Bagian | Isi |
|---|---|
| **Web CS** `apps/cs-console` | Flutter web (Bloc, struktur per fitur seperti `rendezvous_community`). Login + TOTP, tata letak 3 kolom, tab tiket, ambil/pratinjau, chat + catatan internal + quick reply `/`, info nasabah, notifikasi browser + suara, idle logout 30 menit. Widget chat diambil dari modul `support` di `rendezvous_community` (widget yang sama dengan aplikasi nasabah). Dev: `http://localhost:8084`. Produksi: hanya lewat VPN |
| **Modul `support` di `rendezvous_community`** | Entri "Bantuan / Chat CS" + badge, room CS disematkan di daftar chat, pilih topik, kartu order, header tiket, aksi (akhiri, pengaduan, laporkan CS palsu, lampirkan order), rating di chat, "Tiket saya", antrean pesan offline, peringatan data sensitif. Windows: panel samping. Android: layar penuh |
| **Notifikasi** | Notifikasi lokal (Windows toast & Android) saat CS mengambil, membalas, atau menyelesaikan tiket, selama aplikasi berjalan. Push saat aplikasi tertutup butuh service notifier + FCM (tahap F1 produksi) |
| **Edge Function `cs-admin`** | Membuat akun CS (GoTrue + profil agen) dari panel admin. `service_role` hanya ada di server |
| **Tes 2.3** | pgTAP untuk aturan & alur, plus `scripts/cs-claim-race.sh`: 50 CS berebut 1 tiket, dan 200 tiket × 30 CS. Dijalankan langsung ke database **dan** lewat API dengan beberapa replika PostgREST |
