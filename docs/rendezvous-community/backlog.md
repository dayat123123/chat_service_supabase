# Backlog `rendezvous_community`

Tempat memindahkan `TODO`/`FIXME` dari kode, karena kode Dart di package ini tidak boleh berisi komentar (dicek `tool/check_comments.dart` di CI).

Format: `file:baris lama` — isi.

## Inventaris 31 Okt 2026 (rilis 1.0.0)

Tidak ada `TODO`/`FIXME` di 177 file Dart yang ditulis tangan (`lib/`, `test/`, `tool/`, `example/`). File hasil generate (`*.g.dart`, `*.freezed.dart`, `lib/src/shared/presentation/l10n/gen/`) dikecualikan.

## Catatan dari refactor 1.0.0

- Teks UI app contoh (`example/lib`), misalnya layar login dan petunjuk konfigurasi, masih ditulis langsung di kode dalam Bahasa Indonesia. App contoh meniru aplikasi OLT (host) yang punya lokalisasi sendiri; library tetap memakai ARB. Pindahkan ke ARB bila app contoh perlu dua bahasa.
