# Customer Care & Ticketing

> **DIBATALKAN DAN DIARSIPKAN (30 Okt 2026).** Pendekatan ticketing diganti CS lewat chat + matching engine ([PROMPT-CS-CHAT.md](../../PROMPT-CS-CHAT.md), dokumentasi aktif di [docs/cs-chat](../../cs-chat/README.md)). Schema `care`, `care-worker`, dan surat resmi sudah dihapus lewat migrasi `0026_care_cancel`. Dokumen di folder ini hanya untuk referensi; nasib tiap bagiannya ada di [audit pembersihan](../../cs-chat/audit-pembersihan.md).

Spesifikasi: [PROMPT-CUSTOMER-CARE.md](../PROMPT-CUSTOMER-CARE.md) (Addendum 3, dibatalkan).

**Status (30 Okt 2026):** **C1 (fondasi tiket & regulasi) selesai** dan menunggu konfirmasi sebelum C2. Belum ada UI, dan customer care belum dibuka untuk nasabah.

| Tahap | Isi | Status |
|---|---|---|
| Persiapan | Pertanyaan kepatuhan, kebutuhan data OLT, usulan desain | Selesai. Keputusan desain ditetapkan 30 Okt 2026 |
| **C1** | Schema `care` + API, state machine, mesin tenggat & kalender hari kerja, klasifikasi pengaduan, surat resmi PDF + email, `customer-adapter` (mode mock lewat OLT dummy), audit log, peran staf | **Selesai**, lihat [backend.md](backend.md). Demo: `make demo-care`, hasilnya di Mailpit `http://localhost:8025` |
| C2 | Aplikasi nasabah `olt_care` (Windows & Android) | Berikutnya |
| C3 | CS Console & live chat | |
| C4–C6 | Supervisor & kepatuhan, kanal tambahan, penyempurnaan | |

| Dokumen | Untuk | Isi |
|---|---|---|
| [backend.md](backend.md) | Pengembang C2/C3, operator | Referensi C1: keputusan, model data, aturan status & tenggat, peran, API `care_api`, realtime, surat resmi, konfigurasi, job terjadwal |
| [compliance-questions.md](compliance-questions.md) | Tim kepatuhan & legal | 54 pertanyaan dengan usulan default. Selama belum dijawab, sistem memakai usulan itu sebagai konfigurasi |
| [olt-data-requirements.md](olt-data-requirements.md) | Tim backend OLT | Kebutuhan data nasabah (hanya-baca), dua aksi, dan perluasan Protokol v1. OLT dummy sudah mengimplementasikannya sebagai referensi |
| [design-proposal.md](design-proposal.md) | Pemilik produk | Gambaran sistem, wireframe aplikasi nasabah (A1–A6) dan CS Console (B1–B6), alur status/tenggat/live chat, keputusan yang ditetapkan |
| `services/care` (dihapus, sisa yang dipakai ulang ada di [`services/cs`](../../../services/cs/README.md)) | Pengembang, operator | `care-worker` & `customer-adapter`: antrean pekerjaan, API adapter, konfigurasi |

## Keputusan (30 Okt 2026)

Pemilik produk meminta tim memilih yang terbaik sesuai standar customer care. Keempat usulan di [design-proposal.md](design-proposal.md) bagian 5 dipakai:
1. **Snapshot order hanya di schema `care`.**
   - Hanya order yang dipilih nasabah, dan salinannya diambil server dari OLT.
   - Hanya staf yang berwenang yang bisa membukanya, dan setiap pembukaan tercatat.
   - Ringkasan portofolio tidak pernah disimpan.
2. **Login staf GoTrue + TOTP (`aal2`)**, dipakai bersama panel admin F1.
3. **`customer-adapter` service terpisah** dengan kredensial OLT sendiri.
4. **C1 dikerjakan sekarang** dengan nilai regulasi sebagai konfigurasi.

Usulan default di [compliance-questions.md](compliance-questions.md) dipakai sampai tim kepatuhan menjawab.

## Sebelum diluncurkan ke nasabah

- C1–C3 selesai, plus tahap 6 produksi dan push notification (F1).
- Tim kepatuhan menjawab pertanyaan berlabel "Sebelum C1"–"Sebelum peluncuran", lalu:
  - mengisi `company.*`;
  - meninjau template surat (banner "DRAF" hilang);
  - memverifikasi kalender libur.
- Tim OLT menyediakan endpoint data nasabah (Protokol v1) dan kredensialnya.
- SMTP produksi dengan SPF, DKIM, dan DMARC.

Item ini juga ada di [checklist produksi](../../PRODUCTION.md#8-checklist-sebelum-rilis).
