# Customer Service lewat Chat

Spesifikasi: [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) dan revisinya [PROMPT-CS-REVISI-2.md](../PROMPT-CS-REVISI-2.md). Bila keduanya bertentangan, yang berlaku Revisi CS-2. Rencana perubahannya ada di [revisi-2-rencana.md](revisi-2-rencana.md). Pendekatan ticketing lama dibatalkan ([arsip](../archive/customer-care/README.md), [audit pembersihan](audit-pembersihan.md)).

**Status (30 Okt 2026):** semua tahap Revisi CS-2 (R1–R4) sudah berjalan: backend model "ambil tiket", web CS, integrasi aplikasi nasabah, serta dashboard supervisor, laporan, dan pengaturan admin.

| Tahap | Isi | Status |
|---|---|---|
| CS1 | Fondasi: perluasan chat, schema `cs`, RLS, catatan internal, audit log, `customer-adapter` | Selesai |
| **R1** | Backend model ambil tiket: `cs.tickets`, klaim atomik, transfer dengan persetujuan, `cs-sweep`, API tiket, tes rebutan | **Selesai** |
| **R2** | Web CS khusus ([`apps/cs-console`](../../apps/cs-console/README.md)): login + TOTP, 3 kolom, ambil tiket, chat, catatan internal, balasan cepat, info nasabah, notifikasi | **Selesai** |
| **R3** | Integrasi aplikasi nasabah: modul `support` di `olt_social` (room CS disematkan, pilih topik + kartu order, header status, aksi, rating di chat, tiket saya, notifikasi lokal, antrean offline, peringatan data sensitif). Windows: panel samping. Android: layar penuh | **Selesai** |
| **R4** | Dashboard supervisor realtime + alert tiket terlambat, laporan + ekspor CSV, pengaturan admin (akun CS, topik, quick reply global, jam layanan & libur, pesan otomatis, lepas otomatis, mode penugasan), halaman demo dev dipindah ke model tiket (bagian 5) | **Selesai** |
| React | Web CS ditulis ulang dengan React + TypeScript ([`apps/cs-console-react`](../../apps/cs-console-react/README.md), [prompt](../PROMPT-CS-CONSOLE-REACT.md), [paritas](../cs-console-parity.md)). Backend tidak berubah. M1–M4 selesai; console Flutter tetap ada sampai cutover M5 disetujui | **M1–M4 selesai** |

| Dokumen | Untuk |
|---|---|
| [olt-data-requirements.md](olt-data-requirements.md) | Tim OLT: data nasabah dan dua aksi yang dibutuhkan `customer-adapter` |
| [compliance-questions.md](compliance-questions.md) | Tim kepatuhan: 19 pertanyaan dengan usulan yang sudah dipakai sebagai pengaturan |
| [services/cs](../../services/cs/README.md) | Pengembang & operator `customer-adapter` |

## Keputusan

Pemilik produk mendelegasikan pilihan ke tim. Yang dipilih beserta alasannya:

1. **CS = akun staf GoTrue + TOTP (`aal2`) dengan profil chat khusus.**
   - `chat_members` dan `messages` merujuk `profiles`, jadi CS perlu baris profil agar bisa ikut room dan memakai widget chat yang sama.
   - Profil itu bertanda `olt_user_id = 'cs-staff:<id>'` dan dikunci dari fitur sosial: akun CS ditolak di API sosial, tidak muncul di pencarian, dan tidak bisa diajak DM atau dimasukkan ke grup.
   - Badge "CS Resmi" berasal dari `messages.sender_role`, yang hanya bisa diisi server untuk akun di `cs.agents`.
2. **Schema `cs` internal, `cs_api` diekspos lewat PostgREST.**
   - Nasabah mengirim dan membaca pesan lewat `cs_api.send_message`/`get_messages`, yaitu pembungkus tipis atas fungsi chat yang sama. Tidak ada sistem pesan kedua.
   - Nasabah yang di-ban dari fitur sosial tetap bisa menghubungi CS (pengecualian ban hanya untuk `cs_api`, realtime room CS, dan lampiran room CS).
3. **Pengambilan tiket diputuskan database.** `cs.claim_ticket` mengunci baris status CS (`FOR UPDATE`), memeriksa status Online dan batas tiket aktif, lalu menjalankan satu `UPDATE ... WHERE status = 'open' AND owner_agent_id IS NULL`. Dua CS yang mengklik bersamaan tidak mungkin sama-sama berhasil, berapa pun replika API-nya. Yang kalah mendapat "Tiket sudah diambil oleh [nama]".
4. **Pemilik tetap pemilik.** Tiket hanya berpindah lewat tiga jalan: dilepas pemiliknya (wajib alasan), transfer yang **diterima** CS tujuan, atau reassign supervisor (wajib alasan, diaudit). CS yang offline tetap memiliki tiketnya. Nasabah diberi tahu "CS [nama] sedang tidak aktif". Lepas otomatis hanya bila `ticket.auto_release_offline_minutes` > 0 (default mati).
5. **Optimistic concurrency.** Aksi yang mengubah tiket (lepas, transfer, selesai, prioritas) bisa mengirim `version`. Bila tiket sudah berubah, aksi ditolak `stale_ticket` dan layar CS memuat ulang tiket.
6. **Akses CS ke riwayat:** semua CS bisa **pratinjau** pesan tiket `open` (hanya pesan tiket itu, hanya-baca). Pemilik membaca seluruh riwayat room nasabah selama menangani, dan sampai 24 jam setelah tiketnya selesai (`agent.history_hours`). Akses langsung dicabut saat tiket dilepas atau ditransfer.
7. **Pesan CS tidak bisa diubah nasabah.** Edit dan hapus pesan ditolak (`support_message_locked`), dan hapus akun tidak menghapus riwayat CS, karena transkrip adalah catatan pengaduan. Moderasi (service/admin) tetap bisa menghapus konten ilegal.
8. **Kartu order/transaksi hanya menyimpan ID.** Isinya diambil langsung dari OLT lewat adapter setiap kali ditampilkan. Aturan "jangan menyimpan lot, nilai, atau harga" tetap berlaku.
9. **Pesan CS yang meminta OTP/PIN/password diblokir tanpa melempar error.** Panggilan mengembalikan `status: blocked`, sehingga audit log dan peringatan ke supervisor tetap tersimpan.
10. **Room CS disematkan paling atas di daftar chat nasabah**, dengan nama dari pengaturan `brand.support_name` (default "CS OLT") dan badge resmi. Tidak bisa dibisukan atau ditinggalkan.
11. **"Amankan akun" dijalankan sinkron oleh adapter** dengan `idempotency_key` per tiket. Tidak perlu antrean pekerjaan.

## Model data

Migrasi: `0026_care_cancel` (pembersihan), `0027_cs_foundation`, `0028_cs_sessions`, `0029_cs_api`, `0030_cs_session_detail`, `0031_cs_concurrency`, `0032_cs_tickets` (model ambil tiket), `0033_cs_tickets_api`, `0034_cs_room_members`, `0035_cs_supervisor_admin` (dashboard, laporan, pengaturan admin). RLS aktif di semua tabel `cs` (termasuk partisi).

**Perluasan chat yang ada:**
- `chat_rooms.type` + `support`, kolom `customer_id`, satu room `support` per nasabah (unique index). Semua tiket nasabah ada di room yang sama.
- `messages` + `kind` (`text`, `system`, `card`, `quick_reply`, `help_link`, `identity_request`, `csat`), `session_id` (menunjuk tiket), `sender_role` (`customer`/`agent`/`supervisor`/`system`), `payload`. Tipe `chat_message` ikut diperluas (kompatibel dengan client lama).

**Schema `cs`:**

| Tabel | Isi |
|---|---|
| `agents`, `agent_skills`, `agent_status` | Akun CS (peran `cs_agent`, `cs_supervisor`, `cs_admin`, `compliance`), skill level 1–3, batas tiket aktif (default 5), status, jumlah tiket aktif, heartbeat |
| `teams`, `skills`, `support_topics`, `vip_customers` | 6 tim, 8 skill, 7 topik (topik → skill → prioritas default) |
| `tickets` | Tiket: nomor `CS-YYYYMMDD-NNNN` (urut per hari WIB), topik, prioritas, flag, status, pemilik, `version`, semua waktu, hasil + ringkasan, tag, rating, tenggat pengaduan. Maksimal satu tiket aktif per nasabah |
| `ticket_transfers` | Permintaan transfer: pengirim, tujuan, catatan serah terima, kedaluwarsa 10 menit, hasil |
| `ticket_counters` | Penghitung nomor tiket per hari |
| `session_events` | Log append-only perjalanan tiket (partisi bulanan) |
| `agent_notes` | Catatan internal per tiket atau per nasabah, append-only, **terpisah dari `messages`**. Catatan serah terima transfer ikut disimpan di sini |
| `quick_replies` | Balasan cepat pribadi/tim/global |
| `cs_settings`, `cs_settings_history` | Pengaturan berversi (jam layanan, mode penugasan, batas, pesan otomatis ID/EN) |
| `holidays` | Kalender libur 2026–2027 (nasional, cuti bersama, libur bursa) |
| `cs_audit_log` | Audit append-only semua aksi CS/supervisor/admin, termasuk membuka data nasabah (partisi bulanan) |

## Status tiket

| Dari | Ke | Pemicu |
|---|---|---|
| `open` | `claimed` | CS mengambil tiket. Atau penugasan otomatis bila `assignment.mode = auto_assign` |
| `claimed` | `waiting_customer` | CS menandai sedang menunggu balasan nasabah |
| `waiting_customer` | `claimed` | Nasabah membalas |
| `claimed`, `waiting_customer` | `claimed` (pemilik baru) | Transfer diterima CS tujuan, atau reassign supervisor |
| `claimed`, `waiting_customer` | `open` | Pemilik melepas tiket (wajib alasan), atau lepas otomatis saat offline (bila diaktifkan) |
| `claimed`, `waiting_customer` | `resolved` | Pemilik menyelesaikan: hasil + ringkasan 5–500 karakter. Nasabah diminta rating |
| `resolved` | `claimed` | Nasabah membalas dalam 24 jam (`ticket.reopen_hours`) dan pemilik lama masih aktif dan punya kapasitas |
| `resolved` | `open` | Nasabah membalas dalam 24 jam, tetapi pemilik lama tidak aktif > 10 menit atau penuh |
| `resolved` | `closed` | 24 jam tanpa balasan (`cs-sweep`), atau digantikan tiket baru |
| `open`, `claimed`, `waiting_customer` | `closed` | Nasabah mengakhiri chat |

- Transisi yang sah ditegakkan `cs.transition_allowed`. Constraint menjamin `open` tanpa pemilik dan `claimed`/`waiting_customer` selalu punya pemilik.
- Pesan nasabah tanpa tiket aktif membuka tiket baru dengan topik default di room yang sama. Pesan yang datang bersamaan dilayani berurutan lewat kunci baris tiket terakhir: selalu tepat satu tiket aktif per nasabah.
- Pesan `agent` hanya diterima dari pemilik tiket aktif. Pesan `supervisor` hanya dari supervisor yang sudah bergabung ke tiket.
- Job pg_cron `cs-sweep` (tiap 10 detik): kedaluwarsakan transfer, tutup tiket `resolved` yang lewat 24 jam, lepas otomatis (bila diaktifkan), penugasan otomatis (bila mode `auto_assign`).

**Prioritas awal:** prioritas default topik, dinaikkan oleh flag (`fraud` → P1, `complaint` → maks P2) dan kata kunci di pesan pertama (`priority.rules`, mis. "dibobol", "penipuan" → P1 + fraud; "tidak bisa order" di jam bursa → P1).

**Pengaduan:** flag `complaint` mencatat waktu diterima dan tenggat (`complaint.days` hari kerja, kalender WIB). Nasabah langsung mendapat pesan berisi keduanya. Tiket tidak dipindah otomatis: prioritasnya naik dan tandanya terlihat di daftar.

## Akses

| | Nasabah | `cs_agent` | `cs_supervisor` | `compliance` | `cs_admin` |
|---|---|---|---|---|---|
| Room & pesan CS | Miliknya | Pratinjau tiket `open`. Pemilik: seluruh room selama menangani (+24 jam) | Semua | Tiket berflag pengaduan/fraud | – |
| Catatan internal | **Tidak pernah** | Nasabah yang sedang ditangani | Semua | Tiket berflag | – |
| Tiket & log kejadian | Ringkasan aman (`support_home`, `my_tickets`) | Tiket `open` + miliknya | Semua | Tiket berflag | – |
| Data OLT nasabah (adapter) | Order & transaksi miliknya | Tiket aktif miliknya | Semua tiket | Tiket berflag | – |
| Dashboard supervisor | – | – | Ya | – | – |
| Laporan + ekspor CSV | – | – | Ya | – | Ya |
| Pengaturan admin | – | – | – | – | Ya |
| Audit log | – | – | – | Ya | Ya |
| Channel realtime | `cs:room:<room miliknya>` | `cs:queue`, `cs:agent:<diri>`, `cs:room:<yang ditangani>` | Sama | `cs:room` berflag | – |

Semua dicek di server (RLS + fungsi). Akun CS wajib `aal2`. Akun nonaktif langsung kehilangan akses. Client tidak bisa mengirim broadcast ke channel `cs:*` (hanya server), sehingga event status tidak bisa dipalsukan.

## API `cs_api`

| Untuk | Fungsi |
|---|---|
| Nasabah | `topics`, `support_home`, `open_ticket`, `my_tickets`, `ticket_messages`, `send_message`, `send_card`, `get_messages`, `mark_read`, `close_ticket`, `rate_ticket`, `request_complaint`, `report_fake_cs`, `check_sensitive`, `customer_data_access` (adapter) |
| CS | `agent_me`, `agent_set_status`, `agent_heartbeat`, `ticket_lists` (Terbuka / Saya / Selesai hari ini / transfer masuk & keluar), `search_tickets`, `claim_ticket`, `release_ticket`, `request_transfer`, `respond_transfer`, `cancel_transfer`, `wait_customer`, `resolve_ticket`, `set_ticket_priority`, `flag_ticket`, `agent_send_message` (`text`, `quick_reply`, `help_link`, `card`), `add_note`, `notes`, `ticket_detail`, `customer_history`, `online_agents`, `room_members`, `quick_replies` |
| Supervisor | Semua fungsi CS, plus tab "Semua aktif" di `ticket_lists`, `reassign_ticket`, `join_ticket`, `supervisor_overview`, `report_summary` |
| Admin (`cs_admin`) | `report_summary`, `admin_agents`, `admin_options`, `admin_update_agent`, `admin_topics`, `admin_save_topic`, `admin_quick_replies`, `admin_save_quick_reply`, `admin_settings`, `admin_set_setting`, `admin_holidays`, `admin_save_holiday`, `admin_delete_holiday`. Akun baru dibuat lewat Edge Function `cs-admin` |
| Layanan (service role) | `service_create_agent`, hanya dipanggil Edge Function `cs-admin` |
| Adapter (dengan JWT CS) | `agent_customer_access`, `agent_reveal_access`, `agent_secure_account`, `agent_secure_account_result` |

Topik realtime (event dikirim server):
- `cs:queue`: `ticket_opened`, `ticket_claimed` (+ nama pengambil), `ticket_released`, `ticket_transferred`, `ticket_reassigned`, `ticket_resolved`, `ticket_reopened`, `ticket_closed`, `ticket_updated`, `ticket_message`, serta peringatan supervisor.
- `cs:agent:<id>`: event tiket miliknya dan permintaan transfer masuk.
- `cs:room:<room_id>`: status tiket untuk nasabah.

Mengetik dan tanda dibaca tetap memakai channel `room:<id>` milik widget chat.

## Pengaturan dan batas

- Pengaturan di `cs.cs_settings` (berversi, riwayat di `cs_settings_history`):
  - Jam layanan dan jam bursa.
  - Mode penugasan (`claim` / `auto_assign`).
  - Waktu: jendela buka kembali 24 jam, riwayat CS, ambang CS dianggap tidak aktif (10 menit), lepas otomatis saat offline (default mati), kedaluwarsa transfer (10 menit).
  - Penyelesaian: aturan prioritas, tenggat pengaduan, hasil penyelesaian.
  - Data nasabah: batas akses data nasabah, alasan membuka data, aksi amankan akun.
  - Lainnya: host tautan bantuan dan pesan otomatis ID/EN.
- Rate limit (`private.rate_limits`, tanpa faktor trust): `cs_ticket` 5 tiket baru/jam, `cs_message` 30 pesan/menit. CS: 30 pembukaan profil dan 10 pembukaan data tersamar per jam.

## Supervisor dan admin (R4)

**Dashboard supervisor** (`supervisor_overview`, dimuat ulang setiap ada event `cs:queue` dan tiap 30 detik):
- Jumlah tiket terbuka, waktu tunggu terlama, tiket yang sedang ditangani, selesai hari ini, dan CS online.
- Tiga daftar "Perlu perhatian":
  - tiket terbuka yang belum diambil melewati `alerts.unclaimed_minutes` (10 menit) atau P1 melewati `alerts.p1_unclaimed_minutes` (2 menit);
  - tiket fraud/pengaduan yang belum diambil;
  - tiket milik CS yang offline atau tidak mengirim heartbeat.
- Tabel status CS: status, koneksi, tiket aktif/batas, selesai hari ini.
- Tiket terlambat memicu suara + notifikasi browser untuk supervisor (sekali per tiket). Jumlah tiket yang perlu perhatian tampil sebagai badge di menu Dashboard. Mengetuk tiket membukanya di tab Tiket, tempat supervisor bisa gabung, memindahkan, atau mengubah prioritas.

**Laporan** (`report_summary`, maksimal 93 hari, hari dihitung WIB): tiket per hari, waktu sampai diambil, waktu respons pertama, durasi sampai selesai, rating per CS, dan topik terbanyak. Ekspor CSV per bagian (harian, per CS, topik). Sel teks dinetralkan dari formula spreadsheet (`=`, `+`, `-`, `@`).

**Pengaturan admin:**
- **Akun CS.** Admin menambah akun lewat Edge Function `cs-admin` (`docker/volumes/functions/cs-admin`). Fungsi ini:
  - memeriksa bahwa pemanggil adalah admin CS `aal2`;
  - membuat user GoTrue dengan password sementara acak 20 karakter yang hanya ditampilkan sekali;
  - memanggil `cs_api.service_create_agent`, dan menghapus user GoTrue lagi bila langkah ini gagal.

  Saat login pertama, CS wajib mengganti password lalu mendaftarkan TOTP. Kunci service role hanya ada di container functions, tidak pernah di Flutter.
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
- Hanya kunci pengaturan di atas yang bisa diubah dari console. Retensi, batas akses data nasabah, dan pengaturan lain tetap lewat migrasi. Setiap perubahan tercatat di `cs_settings_history` dan `cs_audit_log`.

## Tes

| Perintah | Isi |
|---|---|
| `make test-db` | pgTAP 018–023 untuk CS: kalender, alur tiket (83 tes), keamanan & akses (67 tes), masking, anggota room, supervisor & admin (69 tes: dashboard, laporan, nonaktifkan akun, validasi pengaturan, hak akses) |
| `make cs-race` | Tes rebutan (Revisi CS-2 bagian 2.3). 50 CS mengambil 1 tiket bersamaan: tepat 1 berhasil, 49 mendapat "Tiket sudah diambil oleh …". 200 tiket × 30 CS acak bersamaan: tidak ada tiket ganda, tidak ada CS melebihi 5 tiket aktif, respons yang diterima CS sama persis dengan pemilik di database. Dijalankan langsung ke fungsi database dan lewat 3 replika PostgREST khusus tes. Data uji dihapus setelahnya |
| `make test-cs` | Unit test `customer-adapter` |
| `make smoke-cs` | End-to-end lewat Kong + OLT dummy (40 skenario): buka tiket, ambil, rebutan, balas, OTP diblokir, catatan, lampiran gambar dari CS, data nasabah, transfer, versi kedaluwarsa, selesai, rating |
| `cd apps/cs-console && flutter test` | Web CS (29 tes): urutan dan filter tiket, kalah rebutan, auth + TOTP, ganti password sementara, akun dicabut saat bekerja, versi tiket kedaluwarsa, dashboard & laporan, CSV aman, akun admin lewat `cs-admin` |
| `make test-cs-console` | Web CS React: lint, typecheck, 64 unit test, build, bundle awal ≤ 300 KB gzip, lisensi |
| `make e2e-cs-console` | Web CS React, Playwright vs stack dev (13 tes): login + TOTP, rebutan klaim, chat + lampiran + tanda dibaca, lepas/transfer/selesai, non-pemilik hanya-baca, putus-sambung tanpa duplikat, supervisor gabung + pindahkan, tampilan terang/gelap, kinerja 1000 tiket + 5000 pesan |

## Menjalankan

```bash
make up DUMMY_OLT=1          # Windows: .\make.ps1 up -DummyOlt
make test-db && make cs-race && make smoke-cs
make cs-console              # web CS Flutter di http://localhost:8084 (akun dev: scripts/cs-demo/runtime/staff.json)
make cs-console-react        # web CS React di http://localhost:8085 (akun yang sama, kode TOTP: make cs-totp)
make cs-demo                 # halaman demo (dev) di http://localhost:8082
```

## Web CS dan akun staf

- **GoTrue:** login email + password dinyalakan khusus akun staf yang dibuat admin. Pendaftaran publik tetap mati. Password minimal 12 karakter, dan TOTP wajib karena API CS menuntut `aal2`.
- **Akun staf dev:** dibuat `scripts/cs-staff-setup.sh` lewat API admin GoTrue (UUID akun = UUID agen), lengkap dengan faktor TOTP terverifikasi: Nadia, Bima, Laras (CS), Sinta (supervisor), Adi (admin). Akun baru di luar itu dibuat admin dari menu Pengaturan → Akun CS.
- **Widget bersama:** web CS memakai widget chat `olt_social` lewat `OltSupportStaff`, yaitu dependensi dengan sesi GoTrue staf. Repository chat-nya `SupportChatRepository` berbasis `cs_api`. Pesan sistem tampil ringkas di tengah, pesan CS/supervisor bertanda "CS Resmi", dan kartu, pilihan cepat, serta tautan bantuan dirender sesuai `kind`.
- **Realtime:** daftar tiket dimuat ulang saat ada event `cs:queue`/`cs:agent:<id>`, ditambah polling 30 detik sebagai cadangan.

**Halaman demo** (`scripts/cs-demo`) hanya alat pengembangan dan khusus profil `dev`. UI resminya adalah web CS (R2) dan aplikasi nasabah (R3).
- Nasabah login dengan token OLT tiruan.
- Tiga CS demo (Nadia, Bima, Laras) memakai token uji `aal2` berlaku 8 jam, disimpan di `scripts/cs-demo/runtime/` (di-gitignore).

Halaman ini sudah memakai model tiket dan perbaikan bagian 5:
- header nasabah selalu mengikuti status tiket dari server;
- satu pesan sistem ringkas per kejadian;
- CS offline tetap memiliki tiketnya ("CS [nama] sedang tidak aktif…");
- membalas setelah `resolved` membuka tiket kembali ke CS pemilik;
- jam `HH.mm` dengan pemisah tanggal;
- panel CS: ambil tiket, pratinjau hanya-baca, tunggu nasabah, lepas, selesaikan.
