# Customer Service lewat Chat

Spesifikasi: [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) (Addendum 3 revisi). Menggantikan pendekatan ticketing yang dibatalkan ([arsip](../archive/customer-care/README.md), [audit pembersihan](audit-pembersihan.md)).

**Status (30 Okt 2026):** **CS1 (fondasi) selesai**, menunggu konfirmasi sebelum CS2. Belum ada UI. Chat CS belum dibuka untuk nasabah.

| Tahap | Isi | Status |
|---|---|---|
| Pembersihan | Hasil ticketing dibatalkan lewat migrasi `0026`, bagian yang berguna dipindah ke `cs` | **Selesai** |
| **CS1** | Perluasan chat + schema `cs`, state machine sesi, RLS, catatan internal terpisah, audit log, `customer-adapter` mode mock | **Selesai** |
| CS2 | `cs-matcher`: antrean berprioritas + aging, skor agen, offer–accept, pelebaran, transfer, agen putus, ETA, simulator | Berikutnya |
| CS3 | Aplikasi nasabah (Windows & Android) | |
| CS4 | Panel agen | |
| CS5 | Supervisor & admin, laporan, transkrip PDF | |

| Dokumen | Untuk |
|---|---|
| [olt-data-requirements.md](olt-data-requirements.md) | Tim OLT: data nasabah dan dua aksi yang dibutuhkan `customer-adapter` |
| [compliance-questions.md](compliance-questions.md) | Tim kepatuhan: 19 pertanyaan dengan usulan yang sudah dipakai sebagai pengaturan |
| [services/cs](../../services/cs/README.md) | Pengembang & operator `customer-adapter` |
| [audit-pembersihan.md](audit-pembersihan.md) | Apa yang dipakai ulang, diubah, dan dihapus dari pendekatan ticketing |

## Keputusan CS1

Pemilik produk mendelegasikan pilihan ke tim. Yang dipilih beserta alasannya:

1. **Agen = akun staf GoTrue + TOTP (`aal2`) dengan profil chat khusus.**
   - `chat_members` dan `messages` merujuk `profiles`, jadi agen perlu baris profil agar bisa ikut room dan memakai widget chat yang sama.
   - Profil itu bertanda `olt_user_id = 'cs-staff:<id>'` dan dikunci dari fitur sosial: akun CS ditolak di API sosial, tidak muncul di pencarian, dan tidak bisa diajak DM atau dimasukkan ke grup.
   - Badge "CS Resmi" berasal dari `messages.sender_role`, yang hanya bisa diisi server untuk akun di `cs.agents`.
2. **Schema `cs` internal, `cs_api` diekspos lewat PostgREST.**
   - Nasabah mengirim dan membaca pesan lewat `cs_api.send_message`/`get_messages`, yaitu pembungkus tipis atas fungsi chat yang sama. Tidak ada sistem pesan kedua.
   - Nasabah yang di-ban dari fitur sosial tetap bisa menghubungi CS (pengecualian ban hanya untuk `cs_api`, realtime room CS, dan lampiran room CS).
3. **Akses agen ke riwayat:** seluruh riwayat room nasabah **selama** menangani sesinya, dan sampai 24 jam setelah sesi yang ia tangani ditutup (`agent.history_hours`). Akses dicabut saat sesi ditransfer. Alasannya: agen butuh konteks penuh, tetapi tidak perlu akses permanen ke semua nasabah yang pernah ia layani.
4. **Pesan CS tidak bisa diubah nasabah.** Edit dan hapus pesan ditolak (`support_message_locked`), dan hapus akun tidak menghapus riwayat CS, karena transkrip adalah catatan pengaduan. Moderasi (service/admin) tetap bisa menghapus konten ilegal.
5. **State machine dan primitif penugasan di SQL.** `cs.offer`, `cs.assign`, `cs.close_offer`, `cs.expire_offers`, `cs.requeue_session`, dan `cs.release_agent` mengunci baris sesi dan `agent_status` di satu transaksi. `cs-matcher` (CS2) tinggal memilih agen lalu memanggilnya.
6. **Kartu order/transaksi hanya menyimpan ID.** Isinya diambil langsung dari OLT lewat adapter setiap kali ditampilkan. Aturan "jangan menyimpan lot, nilai, atau harga" tetap berlaku.
7. **Pesan agen yang meminta OTP/PIN/password diblokir tanpa melempar error.** Panggilan mengembalikan `status: blocked`, sehingga audit log dan peringatan ke supervisor tetap tersimpan.
8. **Room CS tidak muncul di daftar chat sosial.** Pintu masuknya tombol "Chat CS" (CS3).
9. **"Amankan akun" dijalankan sinkron oleh adapter** dengan `idempotency_key` per sesi. Tidak perlu antrean pekerjaan.

## Model data

Migrasi: `0026_care_cancel` (pembersihan), `0027_cs_foundation`, `0028_cs_sessions`, `0029_cs_api`, `0030_cs_session_detail`, `0031_cs_concurrency`. RLS aktif di semua tabel `cs` (termasuk partisi).

**Perluasan chat yang ada:**
- `chat_rooms.type` + `support`, kolom `customer_id`, satu room `support` per nasabah (unique index).
- `messages` + `kind` (`text`, `system`, `card`, `quick_reply`, `help_link`, `identity_request`, `csat`), `session_id`, `sender_role` (`customer`/`agent`/`supervisor`/`system`), `payload`. Tipe `chat_message` ikut diperluas (kompatibel dengan client lama).

**Schema `cs`:**

| Tabel | Isi |
|---|---|
| `agents`, `agent_skills`, `agent_status` | Akun CS (peran `cs_agent`, `cs_supervisor`, `cs_admin`, `compliance`), skill level 1–3, status + beban + heartbeat |
| `teams`, `skills`, `support_topics`, `vip_customers` | 6 tim, 8 skill, 7 topik (topik → skill → tim → prioritas default) |
| `support_sessions` | Sesi per room: topik, prioritas, flag, status, agen, semua waktu, transfer, hasil, tag, rating, tenggat pengaduan |
| `session_events` | Log append-only perjalanan sesi (partisi bulanan) |
| `match_offers` | Penawaran ke agen: kedaluwarsa, hasil `accepted`/`rejected`/`expired`/`cancelled` |
| `agent_notes` | Catatan internal per sesi atau per nasabah, append-only, **terpisah dari `messages`** |
| `quick_replies` | Balasan cepat pribadi/tim/global |
| `cs_settings`, `cs_settings_history` | Pengaturan berversi (jam layanan, bobot, timeout, pesan otomatis ID/EN) |
| `holidays` | Kalender libur 2026–2027 (nasional, cuti bersama, libur bursa) |
| `cs_audit_log` | Audit append-only semua aksi agen/supervisor/admin, termasuk membuka data nasabah (partisi bulanan) |

## Status sesi

| Dari | Ke | Pemicu |
|---|---|---|
| `queued` | `offered` | Matcher menawarkan sesi ke agen |
| `queued` | `active` | Auto-assign (tim bermode `auto`) |
| `offered` | `active` | Agen menerima dalam 30 detik |
| `offered` | `queued` | Agen menolak, atau waktu habis |
| `active` | `closed` | Agen, supervisor, atau nasabah menutup sesi |
| `active` | `transferring` | Transfer ke tim/topik/agen lain (wajib catatan serah terima) |
| `active` | `queued` | Agen offline, putus, atau dinonaktifkan |
| `transferring` | `offered`, `active`, `queued` | Penawaran ke tujuan, auto-assign, atau tujuan tidak tersedia |
| `closed` | `reopened` | Nasabah mengetik lagi dalam 30 menit |
| `reopened` | `active` | Agen sebelumnya masih online dan punya kapasitas |
| `reopened` | `offered`, `queued` | Dilanjutkan agen lain lewat matcher |
| status menunggu | `closed` | Nasabah mengakhiri sesi |

- Transisi yang sah ditegakkan `cs.transition_allowed`. Transisi lain ditolak (`invalid_transition`).
- Sesi tertutup lebih dari 30 menit (`session.reopen_minutes`) final: pesan berikutnya membuat sesi baru di room yang sama.
- Pesan nasabah tanpa sesi terbuka otomatis membuka kembali sesi terakhir (≤30 menit) atau membuat sesi baru. Pesan yang datang bersamaan dilayani berurutan lewat kunci baris sesi terakhir: selalu tepat satu sesi terbuka per room, tanpa pesan yang gagal.

**Prioritas awal:** prioritas default topik, dinaikkan oleh flag (`fraud` → P1, `complaint` → maks P2) dan kata kunci di pesan pertama (`priority.rules`, mis. "dibobol", "penipuan" → P1 + fraud; "tidak bisa order" di jam bursa → P1). Sesi yang kembali ke antrean karena agen putus naik ke maks P2.

**Pengaduan:** flag `complaint` mencatat waktu diterima dan tenggat (`complaint.days` hari kerja, kalender WIB). Nasabah langsung mendapat pesan berisi keduanya. Bila agen yang menangani tidak punya skill `complaint`, sesi dialihkan otomatis ke tim Pengaduan.

## Akses

| | Nasabah | `cs_agent` | `cs_supervisor` | `compliance` | `cs_admin` |
|---|---|---|---|---|---|
| Room & pesan CS | Miliknya | Selama menangani (+24 jam) | Semua | Sesi berflag pengaduan/fraud | – |
| Catatan internal | **Tidak pernah** | Nasabah yang sedang ditangani | Semua | Sesi berflag | – |
| Sesi & log kejadian | Ringkasan aman lewat `my_support` | Seperti room | Semua | Sesi berflag | – |
| Data OLT nasabah (adapter) | Order & transaksi miliknya | Sesi aktif miliknya | Semua sesi | Sesi berflag | – |
| Audit log | – | – | – | Ya | Ya |
| Channel realtime | `cs:room:<room miliknya>` | `cs:agent:<diri>`, `cs:room:<yang ditangani>` | + `cs:queue` | `cs:room` berflag | – |

Semua dicek di server (RLS + fungsi). Akun CS wajib `aal2`. Akun nonaktif langsung kehilangan akses. Client tidak bisa mengirim broadcast ke channel `cs:*` (hanya server), sehingga event status tidak bisa dipalsukan.

## API `cs_api`

| Untuk | Fungsi |
|---|---|
| Nasabah | `topics`, `start_session`, `my_support`, `send_message`, `send_card`, `get_messages`, `mark_read`, `end_session`, `rate_session`, `request_complaint`, `report_fake_cs`, `check_sensitive`, `customer_data_access` (adapter) |
| Agen | `agent_me`, `agent_set_status`, `agent_heartbeat`, `agent_inbox`, `accept_offer`, `reject_offer`, `agent_send_message` (`text`, `quick_reply`, `help_link`, `card`), `close_session`, `transfer_session`, `flag_session`, `add_note`, `notes`, `session_detail`, `customer_history`, `quick_replies` |
| Adapter (dengan JWT agen) | `agent_customer_access`, `agent_reveal_access`, `agent_secure_account`, `agent_secure_account_result` |

Topik realtime: `cs:room:<room_id>` (status sesi untuk nasabah & agen), `cs:agent:<agent_id>` (penawaran, pesan nasabah, status), `cs:queue` (dasbor & peringatan supervisor). Mengetik dan tanda dibaca tetap memakai channel `room:<id>` milik widget chat.

## Pengaturan dan batas

- Pengaturan di `cs.cs_settings` (berversi, riwayat di `cs_settings_history`): jam layanan, jam bursa, jendela buka kembali, riwayat agen, heartbeat, timeout penawaran (30 detik), batas timeout beruntun (2 → istirahat otomatis), aturan prioritas, tenggat pengaduan, retensi, hasil penutupan, batas akses data nasabah, alasan membuka data, aksi amankan akun, host tautan bantuan, dan 13 pesan otomatis ID/EN.
- Rate limit (`private.rate_limits`, tanpa faktor trust): `cs_session` 5 sesi baru/jam, `cs_message` 30 pesan/menit. Agen: 30 pembukaan profil dan 10 pembukaan data tersamar per jam.

## Menyusul di tahap berikutnya

- **CS2:** pemilihan agen (skor, sticky, VIP, pelebaran), sweep penawaran kedaluwarsa dan agen putus (fungsinya sudah ada di CS1), ETA, metrik, simulator, tes konkurensi multi-replika.
- **CS3:** aplikasi nasabah. Termasuk lampiran untuk nasabah yang di-ban (policy storage sudah ada).
- **CS4:** panel agen dan konfirmasi identitas lewat OLT.
- **CS5:** API supervisor/admin (pindahkan, ambil alih, pengaturan, kelola agen), laporan, ekspor transkrip PDF, job retensi.

## Menjalankan

```bash
make test-db                 # pgTAP: 018–021 untuk CS (Windows: .\make.ps1 test-db)
make test-cs                 # unit test customer-adapter
make up DUMMY_OLT=1 && make smoke-cs   # end-to-end lewat Kong + OLT dummy
```
