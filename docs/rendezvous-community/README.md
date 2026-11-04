# `rendezvous_community`

Catatan backend untuk library Flutter (kode dan dokumentasinya di repo [rendezvous_community](https://github.com/dayat123123/rendezvous_community)). Library fitur komunitas (feed, komentar, chat, chat CS) untuk aplikasi Rendezvous OLT. Sebelumnya bernama `olt_social`.

| Dokumen | Isi |
|---|---|
| [README library](https://github.com/dayat123123/rendezvous_community/blob/main/README.md) | Pemakaian singkat, fitur UI, tema, builder chat, perintah pengembangan |
| [doc/integration.md](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md) | Langkah memasang library di aplikasi OLT |
| [architecture.md](https://github.com/dayat123123/rendezvous_community/blob/main/doc/architecture.md) | Struktur folder, aturan dependensi, alur auth, realtime, centang, error |
| [logging.md](https://github.com/dayat123123/rendezvous_community/blob/main/doc/logging.md) | Logger, level, format pesan, penyamaran data sensitif |
| [features-1.3.md](features-1.3.md) | Fitur 1.3.0: konfigurasi klien & kill switch, keamanan konten, permintaan DM, banding, room saham, pencarian, link preview, trending, edit, bookmark, reaksi, bagikan, analitik, catatan backend |
| [migration-1.0.md](https://github.com/dayat123123/rendezvous_community/blob/main/doc/migration-1.0.md) | Pindah dari `olt_social` 0.3.0: tabel simbol, nama yang dipertahankan, data perangkat |
| [backlog.md](backlog.md) | Tempat `TODO`/`FIXME` (kode tanpa komentar) |
| [PROMPT-RENAME-COMMUNITY.md](../PROMPT-RENAME-COMMUNITY.md) | Spesifikasi refactor 1.0.0 |

**Aturan kode:**
- **Tanpa komentar:** CI menjalankan `tool/check_comments.dart`. Yang boleh hanya `// ignore:`, `// ignore_for_file:`, dan file hasil generate.
- **Log:** Bahasa Inggris, lewat `CommunityLoggers`, tanpa data sensitif (`tool/check_logging.dart` + tes sanitasi).
- **Teks UI:** lewat lokalisasi ARB (`lib/src/shared/presentation/l10n/arb/`), Bahasa Indonesia default dan Inggris.
