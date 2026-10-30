# Audit Pembersihan: Hasil Pendekatan Ticketing yang Dibatalkan

> **Untuk:** pemilik produk, untuk disetujui sebelum CS1.
> **Dasar:** [PROMPT-CS-CHAT.md](../PROMPT-CS-CHAT.md) bagian 9. Pendekatan lama ada di [archive/PROMPT-CUSTOMER-CARE.md](../archive/PROMPT-CUSTOMER-CARE.md).
> **Status (30 Okt 2026):** disetujui pemilik produk ("lakukan yang terbaik sesuai rekomendasi") dan **sudah dieksekusi**. Hasilnya ada di [bagian 4](#4-hasil-eksekusi).

## Ringkasan

- Semua hasil pendekatan ticketing ada di **lingkungan dev saja**. Tidak pernah dirilis ke produksi, dan belum di-commit.
- Datanya hanya data uji/demo: 7 tiket, 3 pengaduan, 5 surat PDF, 4 staf contoh, 52 baris audit.
- **Package `olt_care` belum pernah dibuat.**
- Kira-kira separuh pekerjaan bisa dipakai ulang di desain chat. Yang harus dibuang terutama sistem tiket itu sendiri, termasuk tabel pesan kedua (`care.ticket_messages`) yang bertentangan dengan prinsip "jangan membuat sistem pesan kedua".
- Migrasi 0021–0025 sudah dijalankan di database dev. Pembatalannya lewat **migrasi baru** di awal CS1, tanpa mengubah atau menghapus file migrasi lama.

## 1. Inventaris

| Kelompok | Yang ada |
|---|---|
| **Migrasi (sudah dijalankan di dev)** | `0021_care_foundation`, `0022_care_tickets`, `0023_care_api`, `0024_care_jobs`, `0025_care_extension_label` |
| **Schema `care`** | 29 tabel (3 di antaranya berpartisi bulanan) dan 88 fungsi. Tabel: `teams`, `staff`, `staff_roles`, `team_members`, `settings`, `settings_history`, `holidays`, `business_hours`, `business_hours_overrides`, `counters`, `categories`, `category_forms`, `form_fields`, `sla_policies`, `tickets`, `complaints`, `ticket_events`, `ticket_messages`, `audit_log`, `ticket_field_values`, `ticket_context`, `ticket_related_items`, `reclassification_requests`, `ticket_sla_pauses`, `staff_notifications`, `sla_alerts`, `message_templates`, `official_letters`, `outbox` |
| **Schema `care_api`** | 49 fungsi RPC (nasabah, staf, service), diekspos lewat PostgREST |
| **Perubahan pada objek bersama** | `private.can_access_topic` (cabang topik `care:*`), `private.check_request` (user yang di-ban tetap bisa memakai `care_api`), 2 baris `private.rate_limits` (`care_ticket`, `care_message`), bucket Storage `care-documents` (12 file PDF dev) + policy `olt_care_documents_select` + fungsi `private.can_read_care_document`, 3 job pg_cron (`care-sweep`, `care-partitions`, `care-retention`) |
| **Tes** | `supabase/tests/018`–`022` (234 asersi). Tes `009` diubah (jumlah policy storage 7 → 8). Helper tes baru: `tests.create_staff`, `tests.authenticate_staff`, `tests.authenticate_service` |
| **Service Go `services/care`** | Binary `care-worker` (PDF surat + email) dan `customer-adapter` (data OLT, snapshot order, amankan akun). Paket bersama: `env`, `token`, `postgrest`, `jobs`, `ops`, `metrics`, `breaker`, `olt`, `letter`, `mail`, `storage`, `worker`, `adapter`. Dockerfile, README, unit test |
| **OLT dummy** | Data nasabah tiruan (`internal/customers`), 10 pesan `customer_*` + `secure_account`, endpoint dev `/api/dev/customers/{id}`, token layanan `DUMMY_OLT_CUSTOMER_TOKEN`, tes. Image naik ke `0.2.0` |
| **Docker & konfigurasi** | `compose.yml` (service `care-worker` dan `customer-adapter` di profil `care`, 2 secret baru, `care_api` di `PGRST_DB_SCHEMAS`, `jwt_secret` untuk container tools), `compose.dev.yml` (Mailpit + override dev), `compose.dummy-olt.yml`, rute Kong `/care/v1`, rute Traefik dev `/care/v1`, bagian customer care di `.env.example`, secret `olt_customer_service_token` dan `smtp_password` (lokal, di `gen-secrets.sh`) |
| **Perintah** | Target Makefile/`make.ps1`: `test-care`, `smoke-care`, `demo-care`, `CARE=1`/`-Care`. Skrip `smoke-care.sh`, `demo-care.sh`, `care-lib.sh`, dan entri di `tools.sh` |
| **Dokumentasi** | `docs/customer-care/` (README, `backend.md`, `compliance-questions.md`, `olt-data-requirements.md`, `design-proposal.md`), README `services/care`, bagian customer care di README root, `docs/PRODUCTION.md` (§2 dan checklist §8), dan README OLT dummy |
| **Di luar repo** | Halaman web (artifact) **"Persiapan Customer Care"** (privat) yang berisi pertanyaan kepatuhan, kebutuhan data OLT, dan wireframe ticketing |
| **Data dev** | Tiket smoke/demo, PDF di bucket `care-documents`, email di Mailpit, staf contoh Nadia, Bima, Laras, dan "Smoke Agen" |

## 2. Pengelompokan

### A. Bisa dipakai ulang

| Bagian | Dipakai untuk di CS chat | Catatan |
|---|---|---|
| **Kalender hari kerja & jam layanan**: data libur 2026–2027 (SKB 3 Menteri + libur bursa), fungsi `is_business_day`, `add_business_days`, `business_days_between`, `regulatory_deadline`, `service_window`, `add_service_minutes`, beserta 31 tesnya | Jam layanan dan hari libur di `cs_settings` (§4.3), "CS akan membalas mulai [waktu buka berikutnya]" (§1.2), hitung mundur hari kerja pengaduan (§6) | Dipindah ke schema `cs` apa adanya |
| **Penyamaran data sensitif**: `mask_sensitive`, `mask_numbers`, `luhn_valid` (OTP, PIN, password, kartu, NIK, rekening; nomor HP tidak diubah) | Masking pesan nasabah dan agen sebelum disimpan (§1.3, §6) | Logika dan tesnya tetap. Pemasangannya berubah, lihat B |
| **Deteksi permintaan data rahasia** (`requests_secret`) | Pesan agen yang meminta OTP/PIN/password diblokir dan supervisor diberi tahu (§4.1) | Dipakai utuh |
| **Pola audit log append-only** (trigger penolak ubah/hapus, pengecualian khusus retensi, partisi bulanan + `ensure_partitions`) | `cs_audit_log` dan `session_events` | Strukturnya dipakai ulang, nama tabel menyesuaikan |
| **Konfigurasi berversi** (`settings` + `settings_history` + pembatasan per peran) | `cs_settings` berversi (§2, §4.3) | |
| **Pemeriksaan identitas staf** (akun GoTrue, wajib `aal2`, staf nonaktif langsung kehilangan akses) | Agen, supervisor, admin CS | Perannya berubah, lihat B |
| **Rate limit tanpa faktor trust** (`care.check_rate_limit`) | 5 sesi baru/jam per nasabah (§6) | |
| **`customer-adapter` (Go)** beserta klien Protokol v1, circuit breaker, verifikasi JWT, masking profil, *reveal* satu field, dan aksi "Amankan akun" | Kolom info nasabah di panel agen (§4.1) dan integrasi OLT (§5) | Otorisasinya berubah dari tiket ke sesi, lihat B |
| **Data nasabah di OLT dummy** (profil, order, transaksi RDN, portofolio, sesi, keamanan, `secure_account`) | Mode mock `customer-adapter` (§5) dan kartu order di chat (§1.1) | Dipakai utuh |
| **Paket Go bersama**: `token`, `postgrest`, `jobs` (antrean SKIP LOCKED + lease), `ops`, `metrics`, `env`, `breaker` | `customer-adapter` dan `cs-matcher` (CS2) | |
| **Pembuat PDF deterministik** (`internal/letter`: fpdf + font Go) dan **penomoran tanpa celah** (`counters`, `next_number`) | Ekspor transkrip PDF bernomor (§6, CS5) | Disimpan untuk CS5 |
| **`olt-data-requirements.md`** (kebutuhan data dan aksi untuk tim OLT) | Tetap relevan untuk §5 | Rujukan "tiket" diganti "sesi" |
| **Sebagian `compliance-questions.md`**: tenggat pengaduan (C1–C3), penyamaran (H1–H2), retensi (G1–G2), verifikasi identitas (I1–I3), kontak resmi & identitas agen (J1–J3), jam layanan (K2) | Hal yang masih perlu dikonfirmasi tim kepatuhan (§6) | Diringkas menjadi daftar pendek |

### B. Harus diubah

| Bagian | Perubahan |
|---|---|
| **Staf & peran** (`care.staff`, `staff_roles`, `teams`, `team_members`) | Menjadi `cs.agents`, `agent_skills` (level 1–3), dan `agent_status`. Peran menjadi `cs_agent`, `cs_supervisor`, `cs_admin`, `compliance`. Ditambah bahasa, `max_concurrent`, dan penanda VIP. **Catatan:** `chat_members` dan `messages` merujuk ke `public.profiles`, jadi agen perlu identitas di sana agar bisa ikut room. Ini diputuskan di CS1 |
| **Pemasangan masking** | Dari trigger di `care.ticket_messages` menjadi trigger di `public.messages`, **hanya untuk room `support`**, sehingga perilaku chat sosial tidak berubah |
| **Otorisasi `customer-adapter`** | `staff_customer_access(ticket)` menjadi akses berbasis sesi aktif. Audit masuk `cs_audit_log`. Rute Kong `/care/v1` menjadi `/cs/v1` |
| **Topik realtime** (`private.can_access_topic`) | `care:*` menjadi `cs:room:<id>`, `cs:agent:<id>`, `cs:queue` (§7) |
| **Pengecualian ban** (`private.check_request`) | Dari `care_api` ke API CS yang baru, agar nasabah yang di-ban dari fitur sosial tetap bisa chat CS |
| **Batas laju** | `care_ticket`/`care_message` menjadi `cs_session` (5/jam). Pesan memakai batas chat yang sudah ada atau 30/menit (§6) |
| **Kategori** (12 kategori + 52 subkategori + formulir dinamis) | Menjadi 6–8 `support_topics` (§1.1) dengan pemetaan topik → skill → prioritas |
| **Schema API** | `care_api` di `PGRST_DB_SCHEMAS` menjadi schema API CS (nama ditetapkan di CS1) |
| **Compose & perintah** | Profil `care` menjadi `cs`. `customer-adapter` tetap, `cs-matcher` ditambah di CS2. Target `test-care`/`smoke-care`/`demo-care` dan `CARE=1`/`-Care` diganti padanan CS |
| **Module Go** | `services/care` menjadi module CS berisi `customer-adapter` dan nantinya `cs-matcher` |
| **Tes** | Tes kalender (018) dan tes masking (sebagian 021) dipindah ke `cs`. Tes 009 menyesuaikan jumlah policy storage. Helper `create_staff`/`authenticate_staff` menjadi helper agen; `authenticate_service` tetap |
| **Dokumentasi** | README `services/care`, bagian customer care di README root dan `docs/PRODUCTION.md`, serta README OLT dummy ditulis ulang untuk CS chat |

### C. Harus dihapus

| Bagian | Alasan |
|---|---|
| **Tabel tiket**: `tickets`, `complaints`, `ticket_events`, `ticket_messages`, `ticket_field_values`, `ticket_context`, `ticket_related_items`, `reclassification_requests`, `ticket_sla_pauses`, `sla_alerts`, `staff_notifications`, `categories`, `category_forms`, `form_fields`, `sla_policies`, `outbox` | Sistem tiket dibatalkan. `ticket_messages` adalah sistem pesan kedua |
| **Surat resmi**: `message_templates`, `official_letters`, nomor `BT/PP/TA` | Diganti ekspor transkrip PDF (CS5) |
| **49 fungsi `care_api`**, mesin SLA tiket (`refresh_sla`, `set_status` tiket), pengecekan jatuh tempo tiket, retensi tiket | Sesi CS punya state machine sendiri |
| **Job pg_cron** `care-sweep`, `care-partitions`, `care-retention` | Diganti job CS bila perlu |
| **Bucket `care-documents`** (12 PDF dev), policy-nya, dan `private.can_read_care_document` | Tidak ada surat resmi lagi |
| **`care-worker`** (render surat + email), Mailpit, konfigurasi SMTP, secret `smtp_password` | Desain baru tidak mengirim email. Kode PDF tetap disimpan (lihat A) |
| **Tes 019, 020, 022** dan sebagian 021 | Menguji tiket, pengaduan, dan surat |
| **Skrip `smoke-care.sh`, `demo-care.sh`, `care-lib.sh`** | Diganti smoke/demo CS |
| **Dokumen ticketing**: `design-proposal.md`, `backend.md`, `docs/customer-care/README.md` | Usulan: dipindah ke `docs/archive/customer-care/`, bukan dihapus |
| **Halaman web "Persiapan Customer Care"** (artifact privat) | Isinya pendekatan ticketing |
| **Data dev** (tiket, PDF, email Mailpit, staf contoh) | Data uji saja |

## 3. Urutan eksekusi setelah disetujui

1. **Migrasi pembatalan** (`0026`):
   - drop schema `care` dan `care_api`;
   - kembalikan `private.can_access_topic` dan `private.check_request` ke versi tanpa `care`;
   - hapus baris rate limit, job pg_cron, policy, fungsi, dan bucket Storage.

   File PDF di Storage dihapus lewat Storage API lebih dulu, karena menghapus baris `storage.objects` tidak menghapus file fisiknya. Backup dibuat sebelum migrasi.
2. **Fondasi CS1** dibuat di migrasi berikutnya. Bagian yang dipakai ulang (kalender + data libur, masking, deteksi permintaan rahasia, pola audit, konfigurasi berversi) disalin ke schema `cs`.
3. **Kode & infrastruktur:**
   - hapus `care-worker`, Mailpit, SMTP, dan `smtp_password`;
   - susun ulang module Go;
   - ganti rute, profil, target, dan skrip.
4. **Dokumen:**
   - dokumen ticketing dipindah ke `docs/archive/customer-care/`;
   - `olt-data-requirements.md` dan daftar pertanyaan kepatuhan yang relevan dipindah ke `docs/cs-chat/`.
5. **Halaman web** dihapus, setelah Anda setujui.

Semua tes yang tersisa (pgTAP, Go, smoke chat yang sudah ada) dijalankan ulang sebelum CS1 dilaporkan.

## 4. Hasil eksekusi

Dikerjakan 30 Okt 2026, berurutan:

1. **Backup** database dan file storage (`backups/olt-20261030-072303.dump`, `backups/storage-20261030-072304.tar.gz`).
2. **12 PDF** di bucket `care-documents` dan bucket itu sendiri dihapus lewat Storage API, agar file fisiknya ikut terhapus.
3. **Migrasi `0026_care_cancel`:** job pg_cron `care-*`, policy dan fungsi dokumen, baris rate limit `care_*`, serta schema `care` dan `care_api` dihapus. `private.can_access_topic` dan `private.check_request` dikembalikan ke versi sebelum ticketing. Migrasi 0021–0025 tidak diubah.
4. **CS1 dibangun** di migrasi `0027`–`0031` dengan bagian yang dipakai ulang (kalender + data libur, masking, deteksi permintaan rahasia, pola audit append-only + partisi, pengaturan berversi, identitas staf `aal2`, rate limit tanpa faktor trust).
5. **Kode dan infrastruktur:**
   - `services/care` → `services/cs`. `care-worker`, `mail`, `worker`, `storage` dihapus. `customer-adapter` beralih ke otorisasi per sesi.
   - Container `care-worker` dan Mailpit, secret `smtp_password`, konfigurasi SMTP, dan target `test-care`/`smoke-care`/`demo-care` dihapus. Profil compose `care` → `cs`, rute Kong/Traefik `/care/v1` → `/cs/v1`, `PGRST_DB_SCHEMAS` memakai `cs_api`.
   - Tes pgTAP 019, 020, 022 dan skrip smoke/demo ticketing dihapus. Tes kalender dan masking dipindah ke `cs`.
6. **Dokumen:** dokumen ticketing dipindah ke [`docs/archive/customer-care/`](../archive/customer-care/README.md). Kebutuhan data OLT dan pertanyaan kepatuhan ditulis ulang untuk chat di folder ini.
7. **Halaman web "Persiapan Customer Care"** dihapus.

**Berbeda dari rencana di bagian 2:**
- Paket Go `jobs` (antrean outbox) ikut dihapus, tidak dipakai ulang. "Amankan akun" kini dijalankan langsung oleh adapter dengan kunci idempoten, jadi antrean pekerjaan tidak diperlukan. `cs-matcher` (CS2) memakai `LISTEN/NOTIFY` + sweep, bukan outbox.
- Paket `letter` (pembuat PDF) disimpan di `services/cs` untuk ekspor transkrip di CS5, sesuai rencana.
- Data uji dev ticketing (tiket, staf contoh) hilang bersama schema `care`. Salinannya tetap ada di backup.
