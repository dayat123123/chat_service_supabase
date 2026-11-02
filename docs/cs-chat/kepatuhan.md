# Menu Kepatuhan di Web CS

Peran **Kepatuhan** (`compliance`) mengawasi penanganan pengaduan dan kasus penipuan di chat CS. Peran ini tidak menangani tiket: tidak mengambil, membalas, atau menyelesaikan. Semua aksinya tercatat di audit log.

Migrasi: `0042_cs_compliance`. Tes: `supabase/tests/030_cs_compliance_test.sql`. Web CS: `apps/cs-console-react/src/features/compliance`.

## Halaman

| Menu | Isi |
|---|---|
| **Ringkasan** (`/compliance`) | Angka utama: pengaduan aktif, jatuh tempo ≤ 1 hari kerja, lewat tenggat, ketepatan waktu 30 hari terakhir, penipuan aktif, laporan CS palsu, dan permintaan data rahasia yang diblokir. Daftar tenggat terdekat, penipuan aktif, dan kasus selesai yang belum ditinjau. Tabel CS yang mencoba meminta PIN/OTP/password (30 hari). Peringatan bila ada kebijakan yang belum dikonfirmasi |
| **Kasus** (`/compliance/cases`) | Register pengaduan dan penipuan: filter jenis, keadaan, periode, dan pencarian; ekspor CSV untuk laporan berkala. Panel detail berisi transkrip (pesan + catatan internal), riwayat kejadian, tinjauan kepatuhan, perpanjangan tenggat, dan unduh transkrip bersidik SHA-256 |
| **Jejak Audit** (`/compliance/audit`) | Audit log CS (append-only): filter periode, jenis aksi, dan pencarian pelaku/tiket/nasabah; halaman bertahap; ekspor CSV |
| **Kebijakan** (`/compliance/policy`) | Nilai yang wajib dikonfirmasi kepatuhan: tenggat pengaduan, perpanjangan tenggat, dan retensi chat. Kepatuhan mengonfirmasi atau mengubah nilainya, beserta riwayat perubahan |

Akun yang hanya berperan Kepatuhan langsung diarahkan ke Ringkasan. Menu **Kasus** memberi angka merah sejumlah pengaduan yang lewat tenggat atau jatuh tempo ≤ 1 hari kerja. Command palette (Ctrl K) untuk Kepatuhan berisi navigasi ke keempat menu dan preferensi tampilan; pencarian tiket ada di halaman Kasus. Kepatuhan tidak punya status kerja, jadi login dan keluar tidak mengubah status (tidak ada catatan `agent.status` yang tidak berarti).

Akun dev: `make cs-staff` membuat **Kirana** (`kirana@cs.olt.local`, peran Kepatuhan); passwordnya ada di `scripts/cs-demo/runtime/staff.json` (tidak di-commit).

## Status tenggat pengaduan

Dihitung server (`cs.complaint_deadline`) dengan kalender hari kerja WIB yang sama dengan tenggat:

| Status | Arti |
|---|---|
| `running` | Pengaduan aktif, sisa lebih dari 1 hari kerja |
| `due_soon` | Pengaduan aktif, jatuh tempo hari ini atau hari kerja berikutnya |
| `overdue` | Pengaduan aktif yang sudah melewati tenggat |
| `met` | Selesai (diselesaikan, atau ditutup bila tidak pernah diselesaikan) sebelum tenggat |
| `missed` | Selesai setelah tenggat |

## Aksi Kepatuhan

| Aksi | Aturan | Jejak |
|---|---|---|
| Membuka detail kasus | Hanya tiket bertanda `complaint`/`fraud` | Audit `compliance.case_view` (akses data nasabah) |
| Tinjauan | Putusan `compliant` (Sesuai), `needs_action` (Perlu tindak lanjut), atau `violation` (Pelanggaran) + catatan 5–1000 karakter. Append-only; tinjauan terbaru menjadi status kasus | Tabel `cs.compliance_reviews`, audit `compliance.review` |
| Perpanjang tenggat | Hanya pengaduan aktif, satu kali, **sebelum** tenggat lewat, alasan 10–500 karakter. Tenggat baru = tenggat lama + `complaint.extension_days` hari kerja (0 = perpanjangan dimatikan). Nasabah menerima pesan sistem `messages.complaint_extended` berisi tenggat baru (alasan tidak dikirim ke nasabah) | Kolom `complaint_extended_at` dan `complaint_extension_reason`, event `complaint_extended`, audit `compliance.deadline_extended` |
| Unduh transkrip | File teks berisi identitas tiket, pesan, dan catatan internal. Sidik SHA-256 dihitung di browser dan dicatat di server saat unduh, sehingga salinan bisa dicocokkan kemudian | Audit `compliance.transcript_export` (sidik + jumlah pesan) |
| Konfirmasi/ubah kebijakan | `complaint.days` 1–20 hari kerja, `complaint.extension_days` 0–20 hari kerja, `retention.chat_years` 5–30 tahun. Perubahan hanya berlaku untuk pengaduan baru | Tabel `cs.policy_confirmations` (per versi pengaturan), `cs_settings_history`, audit `compliance.policy_confirm` |

Super admin tetap tidak bisa mengubah ketiga kebijakan itu (`cs.admin_editable` tidak berubah). Teks pesan `messages.complaint_extended` bisa diubah super admin seperti pesan otomatis lain.

## API

Semua fungsi menuntut peran `compliance` (selain itu `403 role_forbidden`):

| Fungsi | Isi |
|---|---|
| `compliance_overview()` | Angka dan daftar Ringkasan |
| `compliance_cases(p_kind, p_state, p_from, p_to, p_query)` | Register kasus. `p_kind`: `all`/`complaint`/`fraud`. `p_state`: `all`/`active`/`attention`/`done`/`unreviewed`. Periode menurut tanggal tiket dibuat (WIB), maksimal 366 hari. Maksimal 1000 baris (`truncated`) |
| `compliance_case(p_ticket_id)` | Detail kasus: tiket, kejadian, catatan internal tiket, tinjauan, dan info perpanjangan. Pesan dibaca lewat `ticket_messages` |
| `compliance_review(p_ticket_id, p_verdict, p_note)` | Menambah tinjauan |
| `compliance_extend_deadline(p_ticket_id, p_reason, p_version)` | Memperpanjang tenggat sekali |
| `compliance_transcript_exported(p_ticket_id, p_sha256, p_messages)` | Mencatat unduhan transkrip |
| `compliance_audit(p_from, p_to, p_action, p_query, p_before_at, p_before_id, p_limit)` | Audit log, halaman bertahap (keyset `created_at`, `id`), maksimal 200 baris per halaman dan periode 366 hari. Halaman pertama juga mengembalikan daftar aksi + jumlahnya |
| `compliance_policies()` | Kebijakan, status konfirmasi versi terkini, dan riwayat perubahan |
| `compliance_confirm_policy(p_key, p_value, p_note)` | Mengonfirmasi atau mengubah kebijakan |

## Keputusan

1. **Kepatuhan hanya mengawasi.** Tidak ada aksi yang mengubah percakapan selain pesan sistem perpanjangan tenggat, karena perpanjangan wajib diberitahukan ke nasabah sebelum tenggat lewat (usulan A5 di [compliance-questions.md](compliance-questions.md)).
2. **Akses kasus dicatat.** Membuka detail kasus dicatat sebagai akses data nasabah, sama seperti admin moderasi.
3. **Tinjauan dan konfirmasi append-only.** Riwayat penilaian tidak bisa diubah. Penilaian baru menggantikan status, bukan menimpa catatan lama.
4. **Sidik transkrip tanpa server PDF.** Transkrip dibuat di browser sebagai teks UTF-8. Sidik SHA-256 dicatat di audit log, cukup untuk membuktikan salinan tidak berubah tanpa menambah layanan pembuat PDF.
5. **Aksesibel.** Halaman Kepatuhan ikut diaudit axe (kontras WCAG AA, tema terang dan gelap) di `e2e/a11y.spec.ts`; alurnya diuji di `e2e/compliance.spec.ts` (tinjauan, perpanjangan, unduh transkrip yang sidiknya dicocokkan, jejak audit).
6. **Tanpa realtime.** Kepatuhan tidak berlangganan `cs:queue`. Ringkasan dimuat ulang tiap 60 detik dan saat jendela kembali aktif.
