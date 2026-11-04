# Audit Web CS Flutter → React

> **Catatan 31 Okt 2026:** dokumen historis. Cutover M5 selesai: `apps/cs-console` (Flutter) dihapus, dan panel data nasabah dari OLT ikut dihapus karena server hanya boleh memvalidasi token ke OLT ([olt-integration.md](olt-integration.md)).

Dasar migrasi [PROMPT-CS-CONSOLE-REACT.md](PROMPT-CS-CONSOLE-REACT.md). Checklist paritas ada di [cs-console-parity.md](cs-console-parity.md).

Keputusan pemilik produk (30 Okt 2026): **hanya frontend yang dibuat ulang**, backend (Supabase + layanan Go) tidak diubah, dan setiap pilihan memakai opsi yang direkomendasikan tanpa menunggu persetujuan per tahap.

## 1. Yang dipakai console Flutter (`apps/cs-console`)

### Fitur

| Area | Fitur |
|---|---|
| Masuk | Email + password GoTrue, TOTP (verifikasi dan pendaftaran dengan QR), ganti password sementara, logout manual, logout idle 30 menit dengan peringatan 60 detik, keluar otomatis bila akun dicabut |
| Status CS | Online / Sibuk / Istirahat / Offline, heartbeat 20 detik, tiket aktif `n/batas`, default Offline setelah login |
| Daftar tiket | Tab Terbuka, Tiket saya, Selesai hari ini, Semua aktif (supervisor). Filter topik, prioritas, tanda. Cari nomor tiket, nama, kode nasabah, isi pesan. Transfer masuk (terima/tolak) dan keluar (batalkan). Tanda "dikembalikan ke antrean" |
| Ambil tiket | Atomik di server, tombol loading, pesan "sudah diambil oleh …", pratinjau hanya-baca |
| Percakapan | Riwayat room, pesan sistem ringkas, badge CS Resmi, gambar, kartu order/transaksi, tautan bantuan, mengetik, tanda dibaca, balas (quote) |
| Composer | Balas / Catatan internal, `/` balasan cepat dengan variabel, lampiran gambar, kartu order, tautan bantuan, Enter kirim |
| Aksi tiket | Tunggu nasabah, Lepas (alasan), Transfer (CS online + catatan), Selesaikan (hasil + ringkasan), ubah prioritas. Supervisor: Gabung, Pindahkan (alasan) |
| Info nasabah | Profil tersamar, Tampilkan (alasan, berlaku sementara, diaudit), order, transaksi dana, perangkat & sesi, keamanan, amankan akun, riwayat tiket, catatan per nasabah |
| Supervisor | Dashboard (ringkasan, perlu perhatian, status CS), alert tiket terlambat, laporan + ekspor CSV |
| Admin | Akun CS (tambah lewat `cs-admin`, ubah, nonaktifkan), topik, quick reply global, jam layanan & libur, pesan otomatis, penugasan & alert |
| Notifikasi | Suara + notifikasi browser (tiket baru: semua / prioritas tinggi / mati, pesan nasabah, transfer, peringatan supervisor, tiket terlambat) |

### RPC `cs_api`

| Kelompok | Fungsi |
|---|---|
| Profil & status | `agent_me`, `agent_set_status`, `agent_heartbeat`, `online_agents` |
| Tiket | `ticket_lists`, `search_tickets`, `ticket_detail`, `claim_ticket`, `release_ticket`, `request_transfer`, `respond_transfer`, `cancel_transfer`, `wait_customer`, `resolve_ticket`, `set_ticket_priority`, `topics` |
| Supervisor | `join_ticket`, `reassign_ticket`, `supervisor_overview`, `report_summary` |
| Chat | `get_messages` (cursor mundur dan `p_after`), `agent_send_message` (`text`, `card`, `help_link`, `quick_reply`), `mark_read`, `room_members`, `quick_replies` |
| Nasabah | `customer_history`, `notes`, `add_note` (per tiket atau per nasabah) |
| Admin | `admin_agents`, `admin_options`, `admin_update_agent`, `admin_topics`, `admin_save_topic`, `admin_quick_replies`, `admin_save_quick_reply`, `admin_settings`, `admin_set_setting`, `admin_holidays`, `admin_save_holiday`, `admin_delete_holiday` |

Tabel tidak dibaca langsung: semua lewat RPC di atas (RLS tetap berlaku di belakangnya). Satu-satunya akses tabel dari client adalah Storage. Pesan baru datang sebagai sinyal broadcast server di `cs:room:<room>` (`0098`), lalu isinya diambil lewat `get_messages(p_after)`.

### Layanan lain

| Layanan | Pemakaian |
|---|---|
| `customer-adapter` (`/cs/v1/agent/tickets/{id}/customer/…`) | `profile`, `orders`, `orders/{ref}`, `cash-transactions`, `cash-transactions/{ref}`, `sessions`, `security`, `POST reveal`, `POST secure-account` |
| Edge Function `cs-admin` | `POST /cs-admin/agents` (buat akun + password sementara), `PATCH /cs-admin/agents/{id}` (ubah / nonaktifkan + blokir login) |
| Storage bucket `attachments` (privat) | Unggah gambar CS ke `rooms/<room>/<user>/<uuid>.<ext>` (JPEG/PNG/WebP/GIF ≤ 5 MB, maks 4 per pesan), dibaca dengan sesi CS |
| GoTrue | `token?grant_type=password`, `factors` (enroll, challenge, verify), `user` (ganti password, `user_metadata.must_change_password`) |

### Topik realtime

| Topik | Event | Dipakai untuk |
|---|---|---|
| `cs:queue` (privat) | `ticket` (`ticket_opened`, `ticket_claimed`, `ticket_released`, `ticket_transferred`, `ticket_reassigned`, `ticket_resolved`, `ticket_reopened`, `ticket_closed`, `ticket_updated`, `ticket_message`), `alert` (`secret_request_blocked`, `fake_cs_reported`), `agent` (status rekan) | Daftar tiket, alert supervisor, dashboard |
| `cs:agent:<id>` (privat) | `ticket`, `transfer` (`transfer_requested`, `transfer_rejected`, `transfer_expired`, `transfer_cancelled`) | Tiket milik sendiri, transfer |
| `cs:room:<room>` (privat) | `ticket` (status tiket), `message` `{id, room_id, ticket_id, client_id}` (`0098`) | Tiket yang sedang dibuka; pesan baru memicu `get_messages(p_after)` dengan kursor mundur 3 detik, plus isi celah tiap 45 detik dan saat tab kembali aktif |
| `room:<room>` (privat) | broadcast server `typing`, `receipt`; presence `{user_id}`. Typing CS dikirim lewat `cs_api.agent_typing`; klien tidak bisa broadcast | Mengetik, tanda dibaca, nasabah online |

## 2. Kebutuhan backend baru

Tidak ada perubahan backend yang dibutuhkan untuk paritas penuh dengan console Flutter. Beberapa permintaan di PROMPT-CS-CONSOLE-REACT memang **belum didukung backend**. Semuanya **tidak dikerjakan** karena keputusan "frontend saja", dan dicatat di bawah ini untuk diputuskan:

| # | Kebutuhan | Alasan | Usulan bila disetujui |
|---|---|---|---|
| B1 | **Kode pemulihan 2FA** | GoTrue tidak punya recovery code. Saat ini CS yang kehilangan authenticator tidak bisa masuk | Endpoint `cs-admin` "reset 2FA" (hapus faktor TOTP, wajib daftar ulang), diaudit |
| B2 | **"Terakhir aktif" nasabah** | Presence `room:<id>` hanya memberi status online saat ini | Kolom `last_seen_at` per anggota room |
| B3 | **Permintaan konfirmasi identitas** | `agent_send_message` belum menerima `kind = identity_request`, dan persetujuan nasabah butuh API OLT | Ikut tahap integrasi OLT |
| B4 | **Status saat tab ditutup** | `agent_set_status('offline')` langsung mengirim "CS [nama] sedang tidak aktif" ke semua nasabah yang ditangani. Bila dipanggil saat tab ditutup, setiap reload halaman akan mengirim pesan itu | Ditangani di frontend tanpa backend baru (lihat [cs-console-parity.md](cs-console-parity.md) bagian status). Untuk solusi penuh, perlu jeda sebelum pesan "tidak aktif" dikirim |

## 3. Palet dan tampilan

Warna utama memakai biru OLT `#0B57D0` (sama dengan seed console Flutter dan aplikasi contoh), dengan permukaan netral slate. Semua warna teks memenuhi kontras WCAG AA (≥ 4,5:1) di tema terang dan gelap.

| Token | Terang | Gelap | Pemakaian |
|---|---|---|---|
| `primary` | `#0B57D0` | `#7AB0FF` | Tombol utama, fokus, tab aktif |
| `background` / `card` | `#F6F8FB` / `#FFFFFF` | `#0B1220` / `#111A2C` | Latar aplikasi / kolom |
| `foreground` / `muted-foreground` | `#0F172A` / `#526075` | `#E6EBF3` / `#9AA6BA` | Teks utama / sekunder |
| `border` | `#DDE3EC` | `#25324A` | Garis kolom dan kartu |
| P1 / P2 / P3 / P4 | `#C62828` / `#C2410C` / `#1D5FD1` / `#536477` | `#FF8A80` / `#FDBA74` / `#93BBFF` / `#A9B6C8` | Badge prioritas |
| SLA hijau / kuning / merah | `#18794E` / `#A15C00` / `#C62828` | `#4ADE80` / `#FBBF24` / `#F87171` | Lama menunggu (< 5 m, < 15 m, ≥ 15 m dari pengaturan) |
| `complaint` / `fraud` / VIP | `#7B1FA2` / `#C62828` / `#A15C00` | `#D8A6FF` / `#FF8A80` / `#FBBF24` | Tanda tiket |
| Online / Sibuk / Istirahat / Offline | `#18794E` / `#C2410C` / `#5B4FD6` / `#7A8599` | `#4ADE80` / `#FDBA74` / `#A5A0FF` / `#8B96AA` | Status CS |
| Catatan internal | latar `#FFF6D6`, teks `#5C4300` | latar `#3A2F0B`, teks `#FFE08A` | Composer dan catatan internal |
| Grafik seri 1 / seri 2 / track meter | `#2A78D6` / `#EB6834` / `#86B6EF` | `#3987E5` / `#D95926` / `#184F95` | Dashboard dan laporan; kedua seri divalidasi aman buta warna (ΔE ≥ 9) dengan kontras ≥ 3:1, track meter memakai langkah lebih terang dari biru yang sama |

Tampilan mengikuti tata letak 3 kolom di prompt bagian 3.2: header 56 px dengan cari (Ctrl+K), status, tiket aktif, indikator koneksi, notifikasi, dan akun; kolom tiket 340 px; percakapan; panel nasabah 340 px yang bisa diciutkan. Font Inter variable di-self-host. Ukuran dasar 14 px, mode Padat mengurangi tinggi baris dan jarak antar elemen sekitar 20%. Screenshot tema terang dan gelap ada di laporan tiap tahap.
