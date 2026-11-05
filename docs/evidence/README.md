# Karantina Bukti

Konten yang dilaporkan atau dihapus disimpan utuh sebagai **bukti** untuk keperluan hukum (permintaan penyidik, OJK, sengketa). Bukti terpisah dari data hidup: saat akun dihapus atau file dibersihkan, salinan aslinya tetap dihapus seperti biasa (privasi), tetapi bukti tetap ada sampai masa simpannya habis atau selama ada legal hold.

Migrasi: `0095_evidence_quarantine`. Tes: `supabase/tests/075_evidence_quarantine_test.sql`. Penyalin file: [services/janitor](../../services/janitor/README.md) (versi 0.2.0). Web CS: **Kepatuhan → Bukti** (`/compliance/evidence`, `src/features/compliance/evidence` di repo `rendezvous_hub`).

## Kapan bukti direkam

| Pemicu | Sumber (`source`) | Yang direkam |
|---|---|---|
| Laporan pengguna (`public.reports`) atas postingan, komentar, pesan (grup, room saham, DM), atau akun | `report` | Teks asli, lampiran, metadata baris, profil penulis saat itu. Untuk akun: username, nama tampilan, bio, dan foto profil |
| Moderator menghapus konten (`content_archive` alasan `moderator_remove`) | `moderator_remove` | Isi dari arsip + konteks baris |
| Sistem menghapus konten (`content_archive` alasan `policy_block`) | `system_remove` | Sama |
| Moderator menghapus gambar yang ditahan (moderasi gambar) | `media_removed` | File gambar + skor klasifikasi |
| Sanksi toleransi nol (CSAM) | `zero_tolerance` | Profil + paling banyak 500 postingan, 500 komentar, dan 500 pesan terbaru akun |

Isi yang sama (target + sidik isi sama) tidak digandakan: laporan atau penghapusan berikutnya **ditautkan** ke bukti yang sudah ada (jejak `linked`) dan masa simpannya diperpanjang. Bila isinya berubah (misalnya postingan diedit lalu dilaporkan lagi), bukti baru dibuat. Laporan terbuka dan penghapusan moderator yang sudah ada sebelum migrasi ikut direkam saat migrasi dijalankan.

## Penyimpanan dan integritas

- Tabel `private.evidence` (isi), `private.evidence_files` (file), `private.evidence_custody` (jejak penanganan). Tidak ada FK ke `profiles`/`posts`, jadi hapus akun tidak menyentuh bukti.
- **Tambah-saja.** Trigger menolak `UPDATE`, `DELETE`, dan `TRUNCATE`. Yang boleh berubah hanya legal hold dan perpanjangan masa simpan. Baris hanya bisa dihapus bila masa simpan habis dan tidak ada legal hold. File yang sudah tersalin tidak bisa diubah.
- **Sidik SHA-256:** `content_sha256` (JSON isi), `body_sha256` (teks), `record_sha256` (isi + konteks + waktu rekam), `sha256` per file, dan `entry_sha256` per catatan jejak yang berantai ke catatan sebelumnya (`prev_sha256`). Pemeriksaan integritas menghitung ulang semuanya, sehingga perubahan langsung di database tetap terdeteksi.
- **File:** disalin ke bucket privat `evidence` dengan nama `<id bukti>/<urutan>-<nama file>`. Janitor menghitung SHA-256 file sumber, menyalin lewat API Storage (`POST /object/copy`), lalu menghitung ulang SHA-256 salinannya. Hanya bila keduanya sama, file dicatat `copied`. File sumber yang sudah tidak ada dicatat `missing`. Kegagalan dicoba ulang dengan jeda sampai 6 jam; setelah 30 kali gagal file dicatat `failed`.
- **Urutan dengan pembersihan:** selama ada file yang masih `pending`, folder sumbernya tidak diambil janitor untuk dihapus (hapus akun, gambar yang dihapus moderator), dan pemilik file tidak bisa menghapus atau menimpa file itu lewat API Storage (`409 evidence_pending`). Objek di bucket `evidence` tidak bisa dihapus selama buktinya ada (`409 evidence_retained`), dan folder bucket `evidence` hanya boleh masuk antrean pembersihan dengan alasan `evidence_expired` setelah buktinya terhapus.

## Masa simpan dan legal hold

| Pengaturan | Default | Tempat |
|---|---|---|
| Masa simpan | 730 hari sejak bukti terakhir direkam atau ditautkan | `private.settings` kunci `retention.evidence_days` |
| Penghapusan | Job `evidence-purge` setiap hari 03:33 UTC | menghapus bukti yang lewat masa simpan tanpa legal hold, lalu memasukkan folder file-nya ke antrean janitor (`evidence_expired`) dan mencatat `evidence.purged` di audit log |
| Legal hold | Dipasang/dilepas Kepatuhan dengan alasan 10–500 karakter | menangguhkan penghapusan. Saat dilepas, masa simpan menjadi paling sedikit 30 hari lagi |

## Akses

Hanya peran **Kepatuhan** dan **Super Admin** (hanya baca). Semua lewat RPC `cs_api`:

| RPC | Peran | Dicatat |
|---|---|---|
| `evidence_list(query, filter, source, before_seq, limit)` | Kepatuhan, Super Admin | Tidak berisi teks konten. Cari: kode `EV-000123`, ID bukti/konten/akun/laporan, username |
| `evidence_detail(id)` | Kepatuhan, Super Admin | jejak `viewed` + audit `evidence.view` |
| `evidence_verify(id)` | Kepatuhan, Super Admin | jejak `verified` + audit `evidence.verify` |
| `evidence_file_checked(file_id, sha256)` | Kepatuhan, Super Admin | jejak `file_verified` + audit `evidence.file_verify` (web mengunduh file, menghitung SHA-256 di browser, server membandingkan) |
| `evidence_set_hold(id, hold, reason)` | Kepatuhan | jejak `hold_set`/`hold_released` + audit `evidence.legal_hold` |
| `evidence_export(id, purpose)` | Kepatuhan | jejak `exported` (dengan `manifest_sha256`) + audit `evidence.export` |

File di bucket `evidence` hanya bisa dibaca/ditandatangani (policy `evidence_quarantine_read`) oleh staf Kepatuhan/Super Admin yang dalam 15 menit terakhir membuka, memeriksa, atau mengekspor bukti itu. Jadi setiap akses file selalu didahului catatan di jejak penanganan.

## Paket ekspor

`evidence_export` mengembalikan manifest JSON `olt-evidence-bundle/1`: isi, konteks, semua sidik, daftar file (bucket `evidence`, nama objek, SHA-256, ukuran), jejak penanganan lengkap beserta sidik berantainya, dan laporan terkait. `manifest_sha256` = SHA-256 teks JSON manifest seperti dibentuk Postgres (tanpa `manifest_sha256` dan tautan unduh), dan tercatat di jejak penanganan. Web menambahkan `download_links` (URL bertanda tangan, berlaku 1 jam) lalu mengunduh `bukti-EV-000123-<12 karakter sidik>.json`. Penerima memverifikasi file dengan `sha256sum` terhadap `files[].sha256`.

## Web CS

**Kepatuhan → Bukti**: ringkasan (total, legal hold, segera habis, file menunggu/bermasalah, masa simpan), filter (legal hold, menunggu salinan, file bermasalah, segera habis), filter sumber, pencarian, dan tabel. Panel detail: isi asli, file (lihat lewat URL 2 menit, periksa sidik), sidik SHA-256, laporan, konteks JSON, jejak penanganan, tombol **Periksa integritas**, serta **Pasang/Lepas legal hold** dan **Ekspor paket bukti** (khusus Kepatuhan). Super Admin membuka halaman ini dari command palette (Ctrl K) atau URL; tombol ubah tidak tampil.

## Operasional

- Cek antrean salinan: `select status, count(*) from private.evidence_files group by 1;` dan `select id, source_bucket, source_name, failures, error from private.evidence_files where status = 'pending' and failures > 0;`.
- Metrik janitor: `janitor_evidence_files_total{outcome="copied|missing|error|released"}` dan `janitor_evidence_claim_errors_total`.
- Bila janitor mati, bukti tetap terekam (teks dan sidik di database), file menunggu disalin, dan pembersihan folder sumbernya juga menunggu.
- **Backup:** bucket `evidence` ikut backup file storage (restic, retensi 7 harian/4 mingguan/6 bulanan). Bukti yang sudah dihapus karena masa simpannya habis masih ada di backup lama sampai backup itu terpangkas (paling lama sekitar 6 bulan). Di profil cluster, file storage mengandalkan replikasi SeaweedFS.
