# Customer Care C1: Fondasi Backend

> **Untuk:** pengembang aplikasi nasabah (C2), pengembang CS Console (C3), dan operator.
> **Status:** C1 selesai 30 Okt 2026. Belum diluncurkan ke nasabah; peluncuran menunggu C2–C3, tahap 6 produksi, dan jawaban kepatuhan.
> **Dasar:** [PROMPT-CUSTOMER-CARE.md](../PROMPT-CUSTOMER-CARE.md) bagian 1, 4, 5, 8–11, serta [design-proposal.md](design-proposal.md).

C1 membangun fondasi tanpa UI:
- schema `care` beserta API `care_api`;
- mesin tenggat hari kerja dan SLA;
- alur pengaduan sesuai regulasi;
- surat resmi PDF + email (`care-worker`);
- jembatan data nasabah ke OLT (`customer-adapter`, mode mock lewat OLT dummy);
- peran staf dan audit log.

Cara memeriksa:

| Perintah | Isi |
|---|---|
| `make test-db` | 233 asersi pgTAP customer care (`supabase/tests/018`–`022`), bersama 314 asersi lama |
| `make test-care` | Unit test Go kedua service |
| `make smoke-care` | 23 skenario end-to-end di stack dev + OLT dummy |

## 1. Keputusan yang dipakai

Pemilik produk menyerahkan keputusan kepada tim pengembang (30 Okt 2026). Kami memilih usulan di [design-proposal.md](design-proposal.md) bagian 5:

1. **Snapshot order hanya di schema `care`.**
   - Salinan order (termasuk harga dan lot) hanya disimpan untuk order yang dipilih nasabah.
   - Salinan itu diambil server dari OLT, bukan dikirim client.
   - Hanya staf yang berwenang yang bisa membukanya, dan setiap pembukaan tiket tercatat di audit.
   - Ringkasan portofolio tidak pernah disimpan.
   - Aturan "jangan simpan lot/nilai/harga" tetap berlaku penuh untuk fitur sosial.
2. **Login staf memakai GoTrue + TOTP (`aal2`).** Akun staf terpisah dari nasabah. Server menolak semua aksi staf tanpa 2FA.
3. **`customer-adapter` adalah service terpisah** dari `market-adapter`, dengan kredensial OLT sendiri (`olt_customer_service_token`).
4. **C1 dikerjakan sekarang.**
   - Semua nilai regulasi memakai default spesifikasi dan [jawaban usulan](compliance-questions.md), disimpan sebagai **konfigurasi berversi**.
   - Jawaban kepatuhan nanti cukup mengubah konfigurasi.

Default kepatuhan yang dipakai (semuanya bisa diubah tim kepatuhan, lihat bagian 9):
- Tenggat pengaduan lisan 5 hari kerja; tertulis 10 hari kerja sejak dokumen lengkap.
- Perpanjangan 10 hari kerja, maksimal 1 kali, sebelum tenggat lewat.
- Hari penerimaan = hari ke-0, tanpa batas jam, semua dalam WIB.
- Tenggat jatuh pukul 23.59 WIB pada hari kerja ke-N.
- Hari kerja = Senin–Jumat, dikurangi libur nasional, cuti bersama, dan libur bursa.
- Live chat, telepon, dan datang langsung = pengaduan **lisan**. Formulir aplikasi, email, surat, dan media sosial = **tertulis**.
- Nomor pengaduan `PGD-YYYY-NNNNNN`, urut per tahun tanpa celah.
- Pengaduan tidak pernah selesai atau ditutup otomatis.
- Data rahasia di percakapan disamarkan sebelum disimpan.
- Retensi: pengaduan 10 tahun, tiket lain 5 tahun, audit 10 tahun.

## 2. Komponen

```text
App OLT (C2) ─┐                       ┌─ PostgREST (care_api) ─▶ Postgres schema care
CS Console(C3)┴─ Traefik ─ Kong ──────┤                            │  ▲ pg_cron: sapuan tenggat tiap menit
                                      └─ /care/v1 ─▶ customer-adapter ─▶ OLT (Protokol v1)
                                                         ▲   izin & audit lewat RPC
Postgres care.outbox ─▶ care-worker ─▶ Storage (care-documents) + SMTP (dev: Mailpit)
                     └▶ customer-adapter (snapshot, amankan akun)
```

- **Database = sumber kebenaran dan seluruh aturan bisnis.** Semua tabel `care.*` ber-RLS tanpa policy untuk user. Akses hanya lewat fungsi `care_api.*` (`security definer`) yang memeriksa peran di server.
- **Realtime hanya sinyal.** Klien mengambil ulang data lewat RPC setelah menerima broadcast. Lihat bagian 7.
- **Service Go** (`services/care`) hanya mengerjakan I/O luar. Service itu sudah dihapus; bagian yang dipakai ulang ada di [`services/cs`](../../../services/cs/README.md).
- **Profil compose `care`.** Di dev selalu aktif. Produksi menyalakannya dengan `make up PROFILE=single CARE=1` (Windows: `-Care`) setelah SMTP dan endpoint OLT nasabah siap.

## 3. Model data

| Tabel | Isi | Catatan |
|---|---|---|
| `tickets` | Tiket: nomor, jenis, kanal, nasabah, kategori, status, prioritas, tim, penanggung jawab, waktu SLA, akar masalah, ringkasan penyelesaian, retensi | `customer_id` → `public.profiles` (profil hanya dianonimkan saat akun dihapus, sehingga catatan pengaduan tetap tersimpan) |
| `complaints` | Data pengaduan 1:1 dengan tiket: nomor PGD, lisan/tertulis, dokumen, tenggat, jeda, perpanjangan, tanggapan akhir, keberatan, penurunan klasifikasi | Nomor tetap tercatat walau pengaduan diturunkan |
| `ticket_events` | Lini masa (publik/internal) | **Append-only**, partisi bulanan |
| `ticket_messages` | Pesan nasabah, balasan publik, catatan internal, pesan yang ditahan | **Append-only**, partisi bulanan, disamarkan oleh trigger sebelum disimpan |
| `audit_log` | Semua aksi staf, akses data nasabah, perubahan konfigurasi & kalender | **Append-only**, partisi bulanan |
| `ticket_field_values`, `ticket_context` | Isian formulir dinamis (label dibekukan) dan konteks perangkat (log disanitasi) | |
| `ticket_related_items` | Order/transaksi terkait + snapshot dari OLT | Status `pending` → `ok` / `not_found` / `unavailable` |
| `reclassification_requests` | Permintaan menurunkan pengaduan (pembuat ≠ penyetuju) | |
| `ticket_sla_pauses`, `sla_alerts` | Riwayat jeda SLA, dan peringatan yang sudah dikirim (agar tidak dobel) | |
| `official_letters`, `message_templates` | Surat resmi (isi dibekukan, hash SHA-256, kode verifikasi) dan template berversi ID/EN | Isi surat tidak bisa diubah (trigger) |
| `outbox`, `staff_notifications` | Antrean pekerjaan service, dan notifikasi staf | |
| `staff`, `staff_roles`, `teams`, `team_members` | Staf (akun GoTrue), peran, dan tim/antrean | |
| `categories`, `category_forms`, `form_fields` | Pohon kategori (bagian 5.2 spesifikasi) dan formulir dinamis | Anak mewarisi tim, prioritas, jenis, formulir, dan dokumen wajib dari induk |
| `holidays`, `business_hours`, `business_hours_overrides`, `sla_policies`, `settings`, `settings_history`, `counters` | Kalender, jam layanan, SLA, konfigurasi berversi, dan penghitung nomor | Riwayat konfigurasi append-only |

- **Append-only.** Diterapkan oleh trigger yang menolak `UPDATE`/`DELETE`/`TRUNCATE`. Satu-satunya pengecualian adalah job retensi (`set local care.retention = 'on'`).
- **Partisi.** Dibuat 3 bulan ke depan oleh `care.ensure_partitions` (pg_cron harian). Partisi `*_default` menampung data bila job itu mati; isinya harus tetap kosong (pantau).

## 4. Aturan tiket

### 4.1 Status

| Dari | Ke |
|---|---|
| `new` | `open`, `cancelled` |
| `open` | `pending_customer`, `pending_internal`, `pending_third_party`, `escalated`, `extended`¹, `resolved`, `cancelled` |
| `pending_*` | `open`, `pending_*` lain, `escalated`, `extended`¹, `resolved`, `cancelled` |
| `escalated` | `open`, `pending_*`, `extended`¹, `resolved`, `cancelled` |
| `extended` | `open`, `pending_*`, `escalated`, `resolved`, `cancelled` |
| `resolved` | `open` (dibuka kembali / keberatan), `closed` |
| `closed`, `cancelled` | – (final) |

¹ Hanya pengaduan, lewat aksi perpanjangan.

Transisi lain ditolak dengan `409 invalid_transition`.

**Aturan tambahan:**
- **Penyelesaian.** Hanya lewat `staff_resolve`, dengan akar masalah dari daftar dan ringkasan wajib.
- **Pembatalan oleh staf.** Hanya untuk tiket `new`/`open` yang bukan pengaduan (duplikat atau tidak valid).
- **Pembatalan oleh nasabah.**
  - Tiket biasa: saat `new`/`open`.
  - Pengaduan: kapan saja sebelum selesai, dan dicatat sebagai penarikan.
- **Jeda SLA.** Saat `pending_customer`, SLA internal dijeda. Balasan nasabah otomatis membuka kembali tiket.
- **Label untuk nasabah.**

  | Status | Label |
  |---|---|
  | `new` | Diterima |
  | `pending_customer` | Menunggu tanggapan Anda |
  | `resolved` | Selesai |
  | `closed` | Ditutup |
  | `cancelled` | Dibatalkan |
  | status lain | Sedang diproses, atau Diproses (diperpanjang) bila tenggat periode penanganan saat ini diperpanjang. Setelah keberatan, label kembali "Sedang diproses" |

  Perubahan status yang tidak mengubah label dicatat sebagai event internal.

### 4.2 Klasifikasi

- **Menjadi pengaduan saat dibuat.** Tiket langsung menjadi pengaduan bila nasabah memilih "pengaduan resmi" atau kategorinya berjenis pengaduan (transaksi tidak dikenal, peretasan akun).
- **Saat pengaduan terdaftar**, sistem otomatis:
  - memberi nomor PGD;
  - menetapkan lisan/tertulis menurut kanal;
  - menaikkan prioritas minimal P2;
  - memindahkan tiket ke tim Pengaduan (kecuali P1, yang tetap di tim keamanan);
  - menerbitkan bukti penerimaan PDF + email.
- **Nasabah** bisa menaikkan tiket menjadi pengaduan kapan saja (`escalate_to_complaint`). Pilihan ini tidak bisa ditolak.
- **Agen** bisa mengubah tiket biasa menjadi pengaduan. Tanggal terima pengaduan = tanggal tiket diterima, sehingga tenggat tidak "mundur" karena klasifikasi terlambat.
- **Menurunkan pengaduan:**
  1. Staf mengajukan permintaan (`staff_change_kind`).
  2. **Supervisor tim atau kepatuhan lain** menyetujui (`staff_decide_reclassification`). Pembuat permintaan tidak bisa menyetujui sendiri.
  3. Kepatuhan diberi tahu, dan nasabah melihat perubahannya di riwayat.

### 4.3 Tenggat regulasi (`complaints.due_at`)

- **Lisan:** `regulatory_deadline(diterima, 5)`.
- **Tertulis tanpa dokumen wajib:** `regulatory_deadline(diterima, 10)`.
- **Tertulis dengan dokumen wajib** (mis. "Deposit belum masuk" → bukti transfer):
  - tenggat belum berjalan;
  - nasabah diberi 10 hari kerja (`documents_due_at`);
  - agen menyatakan lengkap lewat `staff_mark_documents_complete`, lalu tenggat = `regulatory_deadline(lengkap, 10)`.
- **Lisan yang butuh dokumen:**
  - agen meminta dokumen; tenggat lisan tetap berjalan;
  - saat dokumen lengkap, pengaduan **berubah menjadi tertulis** dengan tenggat 10 hari kerja sejak lengkap.
- **Minta dokumen tambahan setelah lengkap:** jam tenggat dijeda, lalu digeser sebanyak hari kerja yang terlewat saat dokumen lengkap lagi.
- **Perpanjangan (`staff_extend_deadline`):**
  - hanya supervisor tim atau kepatuhan;
  - alasan dari daftar `complaint.extension_reasons`;
  - sebelum tenggat lewat, maksimal 1 kali;
  - tenggat baru = tenggat lama + 10 hari kerja;
  - surat pemberitahuan PDF + email terbit dalam transaksi yang sama.
- **Tanggapan akhir (`staff_resolve`):** menerbitkan surat tanggapan, yang memuat batas keberatan dan hak menempuh LAPS SJK/OJK.
- **Keberatan (`object_to_response`):**
  - hanya dalam 7 hari kerja setelah tanggapan;
  - tenggat baru 10 hari kerja (dengan dokumen baru) atau 5 hari kerja (peninjauan);
  - status kembali `open`.
- **Penutupan otomatis:**
  - Pengaduan tidak pernah diselesaikan otomatis.
  - Pengaduan yang sudah selesai ditutup setelah masa keberatan lewat.
  - Tiket biasa: pengingat ke nasabah setelah 3 hari kerja menunggu, diselesaikan otomatis setelah 7 hari kerja, ditutup 7 hari setelah selesai.
- **Peringatan:** H-3, H-1, hari H, dan terlambat, ke penanggung jawab dan supervisor tim. Kepatuhan ikut menerima di hari H dan saat terlambat. Dikirim sekali per tenggat, dan perpanjangan memulai siklus baru.

Fungsi kalender bisa dipakai langsung untuk laporan: `care.is_business_day`, `care.add_business_days`, `care.business_days_between`, `care.regulatory_deadline`. Contoh yang dites:
- diterima Jumat 30 Okt 2026 → tenggat lisan Jumat 6 Nov 23.59 WIB;
- diterima Sabtu → dihitung dari Senin;
- 17 Mar 2026 + 1 hari kerja → 25 Mar (melewati Nyepi, Idulfitri, dan cuti bersama);
- diterima 25 Des 2026 → 7 Jan 2027.

### 4.4 SLA internal

| Prioritas | Respons pertama | Penyelesaian | Jam |
|---|---|---|---|
| P1 | 15 menit | 4 jam | 24/7 |
| P2 | 60 menit | 1 hari kerja | Jam layanan |
| P3 | 4 jam | 3 hari kerja | Jam layanan |
| P4 | 1 hari kerja | 5 hari kerja | Hari kerja |

- **Jam layanan:** `business_hours` (Sen–Jum 08–22, Sab–Min 09–18 WIB).
- **Hari libur nasional dan cuti bersama:** CS dianggap tutup, kecuali ada `business_hours_overrides`.
- **Respons pertama** = balasan publik staf pertama.
- **Jeda:** jeda `pending_customer` menggeser tenggat SLA sesuai satuannya.
- **Target internal** tidak pernah melonggarkan tenggat regulasi.

### 4.5 Penomoran

| Nomor | Format | Penghitung |
|---|---|---|
| Tiket | `CC-YYYY-MM-NNNNNN` | Per bulan |
| Pengaduan | `PGD-YYYY-NNNNNN` | Per tahun |
| Surat | `<nomor PGD>/BT|PP|TA/<urutan>` | Bukti terima, pemberitahuan perpanjangan, tanggapan akhir |
| Kode agen | `CS-NNNN` | |

- **Tanpa celah.** Penghitung memakai satu baris per periode dengan row lock (`care.next_number`), bukan sequence, sehingga transaksi yang batal tidak menghabiskan nomor.
- **Lebar nomor** bertambah otomatis bila melewati 999.999.

### 4.6 Penyamaran dan larangan meminta data rahasia

- **Penyamaran (`care.mask_sensitive`).** Dijalankan oleh trigger sebelum pesan disimpan, untuk nasabah maupun staf. Juga berlaku untuk judul, deskripsi, isian teks, log teknis, dan alasan.

  | Pola | Hasil |
  |---|---|
  | OTP/PIN/CVV/kode verifikasi diikuti angka | `******` |
  | Pesan yang hanya berisi 4–8 digit | `******` |
  | Password berisi angka/simbol | `********` |
  | Nomor kartu valid Luhn | `**** **** **** 1234` |
  | NIK 16 digit | `3174********0001` |
  | Rekening 9–18 digit | `******7890` |

  Nomor HP (`08…`/`628…`) dan kalimat biasa ("password saya lupa") tidak diubah. Jenis penyamaran dicatat di `masked_kinds`.
- **Larangan meminta data rahasia (`care.requests_secret`).**
  - Balasan publik staf yang **meminta** OTP/PIN/password/kartu (mis. "mohon kirimkan kode OTP") disimpan sebagai pesan **ditahan**.
  - Pesan yang ditahan tidak terlihat nasabah, dan supervisor tim diberi tahu.
  - Kalimat edukasi ("jangan berikan OTP kepada siapa pun") tidak ditahan.

## 5. Peran dan akses

| Peran | Tiket | Data OLT nasabah | Lain-lain |
|---|---|---|---|
| `agent_l1` | Tiket di timnya + yang ditugaskan | Hanya tiket yang ditugaskan kepadanya; tanpa portofolio | |
| `agent_l2`, `specialist` | Sama | Sama + portofolio | |
| `supervisor` | Semua tiket timnya | Tiket timnya | Menugaskan ulang, memindah tim, perpanjangan, menyetujui penurunan pengaduan |
| `compliance` | Semua, termasuk nasabah yang sudah menghapus akun | Semua | Kalender, konfigurasi regulasi, persetujuan |
| `cc_admin` | – | – | Staf (tambah/ubah peran/nonaktif), konfigurasi operasional |
| `kb_editor` | – | – | Pusat Bantuan (C2) |

- **Syarat staf.** Akun di `care.staff` aktif + JWT `aal2`. Token nasabah (auth-bridge) tidak punya `aal`, jadi tidak pernah lolos.
- **Staf dinonaktifkan:** akses hilang seketika dan tiket aktifnya kembali ke antrean.
- **Akses data nasabah** lewat adapter tercatat di `audit_log` (`customer_data.<jenis>`). Batas anomali: 30 profil per jam, 10 *reveal* per jam per staf.
- **Membuka field tersamar:**
  - per field;
  - dengan alasan dari `customer_data.reveal_reasons`;
  - berlaku 5 menit di tampilan.
- **User yang di-ban dari fitur sosial tetap bisa menghubungi CS.** `private.check_request` hanya menerapkan ban di luar `care_api`.

## 6. API (`care_api`, PostgREST)

Panggil sebagai RPC dengan header `Content-Profile: care_api`. Contoh Dart: `client.schema('care_api').rpc('create_ticket', params: {...})`. Error memakai format yang sama dengan API sosial: `PT4xx` + kode, misalnya `staff_required`, `invalid_transition`, `field_required`.

**Nasabah:**

| Fungsi | Isi |
|---|---|
| `categories(p_language)` | Pohon kategori + formulir dinamis (juga untuk anon) |
| `create_ticket(p_category_id, p_subject, p_description, p_fields, p_context, p_as_complaint, p_language, p_client_id)` | Buat tiket. Maks 5/jam. Kirim ulang dengan `p_client_id` sama tidak membuat tiket baru |
| `my_tickets(p_filter, p_cursor, p_limit)` | `all`/`open`/`waiting`/`done`, kursor `{updated_at, id}` |
| `ticket_detail(p_ticket_id)` | Lini masa publik, isian, order terkait, surat, flag `can.*` untuk tombol UI |
| `post_message(p_ticket_id, p_body, p_client_id)` | Maks 30/menit |
| `escalate_to_complaint`, `cancel_ticket`, `confirm_resolved`, `reopen_ticket`, `object_to_response` | Aksi nasabah (bagian 4) |
| `request_secure_account(p_note)` | Tombol darurat: tiket P1 + aksi OLT lewat adapter. Ditekan ulang dalam 30 menit = tiket yang sama |
| `verify_letter(p_number, p_code)` | Cek keaslian surat (juga untuk anon) |

**Staf (wajib 2FA):**
- `staff_whoami`;
- `staff_tickets(p_view: mine | unassigned | team | complaints | near_deadline | pending_customer)`;
- `staff_ticket` (tercatat di audit);
- `staff_create_ticket` (telepon/email/surat/datang langsung/media sosial; waktu terima bisa mundur maks 30 hari);
- `staff_assign`, `staff_set_status`, `staff_set_priority`;
- `staff_post_message` (publik atau `p_internal`);
- `staff_change_kind`, `staff_decide_reclassification`;
- `staff_request_documents`, `staff_mark_documents_complete`;
- `staff_extend_deadline`, `staff_resolve`, `staff_cancel`;
- `staff_notifications`, `staff_mark_notifications_read`;
- `calendar`;
- `compliance_upsert_holiday`, `compliance_delete_holiday`;
- `staff_settings`, `admin_update_setting`;
- `admin_upsert_staff`, `admin_disable_staff`.

**Service (`service_role`):**
- `service_claim_jobs`, `service_complete_job`, `service_fail_job`;
- `service_letter*`;
- `service_snapshot_target`, `service_store_snapshot`;
- `service_secure_account_result`.

Dipakai `customer-adapter` dengan JWT pemanggil: `staff_customer_access`, `staff_reveal_access`, `customer_data_access`.

## 7. Realtime

Broadcast privat dari database. Payload hanya berisi ID dan jenis, sehingga klien mengambil ulang lewat RPC.

| Topik | Siapa yang boleh bergabung | Event |
|---|---|---|
| `care:ticket:<id>` | Nasabah pemilik + staf berwenang | `ticket_event` untuk event & pesan **publik** |
| `care:ticket:<id>:staff` | Staf berwenang saja | Semua event & pesan, termasuk catatan internal |
| `care:customer:<user_id>` | Nasabah itu | `ticket_updated` untuk daftar "Tiket saya" |
| `care:agent:<staff_id>` | Staf itu | `notification` |
| `care:queue:<kode_tim>` | Anggota tim | Disiapkan untuk C3 |

Catatan internal **tidak pernah** dikirim ke topik yang bisa diikuti nasabah. Ini dites di `019` dan `021`.

## 8. Surat resmi

- **Isi dibekukan saat terbit.** Isi surat dirender di database dari template aktif sesuai bahasa nasabah (fallback Indonesia), lalu disimpan di `official_letters.content` dan tidak bisa diubah lagi.
- **Kode verifikasi** terdiri dari 10 karakter, ditampilkan sebagai `XXXXX-XXXXX`.
- **PDF.** `care-worker` merender PDF ke `care-documents/letters/<tiket>/<surat>.pdf` dan mencatat SHA-256.
- **Unduh.** Nasabah dan staf yang berwenang mengunduh lewat signed URL Storage (policy RLS `olt_care_documents_select`).
- **Template berversi.**
  - Template awal adalah **draf** (`reviewed = false`), sehingga PDF diberi banner "DRAF".
  - Kepatuhan wajib meninjau isi template, mengisi `company.*`, lalu menandai `reviewed` sebelum peluncuran. Editor dan alur persetujuan template ada di C4.

## 9. Konfigurasi (`care.settings`)

Diubah lewat `admin_update_setting`. Kunci **regulasi** hanya boleh diubah kepatuhan; kunci **operasional** juga boleh diubah `cc_admin`. Setiap perubahan tercatat di `settings_history` dan audit log.

| Kunci | Default | Lingkup |
|---|---|---|
| `complaint.oral_days` / `written_days` / `extension_days` / `document_wait_days` | 5 / 10 / 10 / 10 | Regulasi |
| `complaint.max_extensions`, `objection_days`, `objection_review_days` | 1, 7, 5 | Regulasi |
| `complaint.warning_stages` | `[3, 1, 0]` | Regulasi |
| `complaint.channel_forms` | lisan: chat/telepon/datang langsung; tertulis: lainnya | Regulasi |
| `complaint.extension_reasons`, `complaint.team` | 3 alasan, `complaints` | Regulasi |
| `numbering.ticket_prefix`, `numbering.complaint_prefix` | `CC`, `PGD` | Regulasi |
| `retention.complaint_years` / `ticket_years` / `audit_years` | 10 / 5 / 10 | Regulasi |
| `company.name` / `address` / `complaint_contact` | placeholder **wajib diisi** | Regulasi |
| `ticket.reopen_days`, `pending_reminder_business_days`, `pending_autoresolve_business_days`, `max_backdate_days` | 7, 3, 7, 30 | Operasional |
| `ticket.root_causes`, `customer_data.reveal_reasons` | daftar kode + label ID/EN | Operasional |
| `customer_data.profile_views_per_hour`, `reveals_per_hour` | 30, 10 | Operasional |
| `secure_account.actions` | `["logout_all", "lock_trading"]` | Operasional |

**Kalender.**
- Libur nasional dan cuti bersama 2026–2027 sudah diisi sesuai SKB 3 Menteri (sumber setneg.go.id), ditambah libur bursa 31 Desember.
- Semua baris bertanda `verified = false` sampai tim kepatuhan memeriksa.
- Perubahan kalender berlaku untuk tenggat yang dihitung sesudahnya. Tenggat yang sudah tercatat tidak berubah diam-diam.

Rate limit nasabah ada di `private.rate_limits`:
- `care_ticket` 5/jam;
- `care_message` 30/menit;
- tidak dipengaruhi trust level akun.

## 10. Pekerjaan terjadwal (pg_cron, sekali per cluster)

| Job | Jadwal | Isi |
|---|---|---|
| `care-sweep` | Tiap menit | Peringatan tenggat, dokumen kedaluwarsa, pelanggaran SLA, pengingat & penyelesaian otomatis tiket biasa, penutupan setelah masa buka kembali/keberatan. Maks 500 tiket per jenis per putaran |
| `care-partitions` | 02.10 UTC | Partisi bulanan 3 bulan ke depan |
| `care-retention` | 03.40 UTC | Hapus tiket lewat masa retensi (kecuali `legal_hold`), audit lewat 10 tahun, antrean selesai > 30 hari. File surat masuk `private.storage_cleanup_queue` |

## 11. Yang dikerjakan di tahap berikutnya

**C2 (aplikasi nasabah):**
- package `olt_care`;
- lampiran (bucket privat terpisah, sanitasi gambar/PDF);
- Pusat Bantuan;
- notifikasi push.

**C3 (CS Console):**
- login staf GoTrue email + TOTP: aktifkan `GOTRUE_EXTERNAL_EMAIL_ENABLED` dengan signup tetap mati, staf diundang `cc_admin`;
- `olt_staff_kit`;
- entrypoint internal/VPN untuk API staf;
- live chat;
- verifikasi agen & verifikasi identitas nasabah (pesan `identity_verification`).

**C4 (supervisor & kepatuhan):**
- editor & persetujuan template;
- laporan regulasi;
- QA;
- insiden & banner.

**Lainnya:**
- **Route publik `/care/v1` di profil produksi** baru dibuka saat C2. Untuk API staf, saat C3 lewat VPN.
- **Konsumen `private.storage_cleanup_queue`** (sudah ada sejak tahap privasi) belum dibuat. File surat lama dihapus saat konsumen itu dibuat.
