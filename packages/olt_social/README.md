# olt_social

Package Flutter berisi fitur sosial & chat untuk Rendezvous OLT (Windows desktop & Android).
Isinya feed saham, komentar berantai, reaksi, mention, follow, watch saham, chat realtime, notifikasi, dan moderasi.

Backend yang dipakai adalah Supabase self-hosted dan auth-bridge. Keduanya ada di repo ini, lihat [README root](../../README.md).
Langkah memasang package ke app OLT ada di [docs/INTEGRATION.md](../../docs/INTEGRATION.md).

## Pemakaian singkat

```dart
await OltSocial.initialize(
  supabaseUrl: 'https://social-api.domain.com',
  anonKey: '<ANON_KEY>',
  oltTokenProvider: () async => oltAuth.currentToken, // token login OLT
  onStockTap: (context, code) => openOltStockPage(context, code),
);

// Widget siap pakai (tanpa Scaffold, tempel di halaman OLT):
const OltStreamFeed();                    // stream umum (Terbaru / Mengikuti)
const OltStockFeed(stockCode: 'BBCA');    // feed di halaman saham
const OltPostDetail(postId: '...');       // post + thread komentar
const OltComposePost(initialStock: 'BBCA');
const OltChatList();                      // multi-panel di layar lebar
const OltChatRoom(roomId: '...');
const OltNotificationList();
const OltNotificationBadge(child: Icon(Icons.notifications));
const OltUserProfile(userId: '...');
```

Tambahkan delegate lokalisasi di `MaterialApp`. Bahasa default Indonesia, tersedia juga Inggris:

```dart
localizationsDelegates: [...OltSocialLocalizations.localizationsDelegates],
supportedLocales: OltSocialLocalizations.supportedLocales,
```

## Fitur UI

| Fitur | Perilaku |
|---|---|
| Layout responsif | Kolom konten maksimal 720 px. `OltChatList` tampil multi-panel di lebar ≥ 840 px |
| Keyboard desktop | Di composer post, komentar, dan chat: Enter mengirim, Shift+Enter membuat baris baru. Autocomplete bisa dipilih dengan ↑/↓ dan Enter/Tab |
| Hover | Sorotan komentar. Aksi balas/hapus pesan muncul saat kursor di atas gelembung |
| `$KODE` & `@user` | Bisa diketuk lewat `onStockTap` / `onUserTap`. Bila callback tidak diisi, halaman bawaan yang dibuka |
| Thread komentar | Garis indentasi per level. Mulai level 4, indentasi berhenti dan muncul "Lanjutkan thread". Tersedia "Lihat N balasan lainnya" dan collapse/expand per cabang |
| Optimistic update | Like post/komentar, follow, watch, dan kirim pesan. Bila server gagal, perubahan dibatalkan dan SnackBar ditampilkan |
| Chat | Status mengirim/terkirim/dibaca (DM), badge belum dibaca, indikator mengetik, balas pesan, reconnect otomatis dengan pengisian celah pesan |
| State | Skeleton saat memuat, tampilan kosong, error dengan tombol coba lagi, pull-to-refresh, infinite scroll, banner "N post baru" |
| Disclaimer | *"Konten ini opini pengguna, bukan rekomendasi investasi."* di composer dan detail post |

## Tema

Semua warna diturunkan dari `ThemeData` aplikasi host, termasuk dark mode. Untuk menyesuaikan:

```dart
final base = ThemeData(colorScheme: oltColorScheme);
ThemeData(
  colorScheme: oltColorScheme,
  extensions: [
    OltSocialTheme.fallback(base).copyWith(
      bullish: oltGreen, bearish: oltRed,
      maxThreadIndentLevels: 4,   // level komentar yang diindentasi
    ),
  ],
);
```

## Arsitektur

```
lib/src/
  core/          OltSocial (inisialisasi), TokenManager (JWT dari auth-bridge),
                 pemetaan error, parser $KODE/@mention
  domain/        entitas immutable (freezed) + kontrak repository
  data/          model JSON (freezed + json_serializable), data source Supabase,
                 gateway realtime, implementasi repository
  presentation/  Cubit (flutter_bloc) + widget, tema, lokalisasi (ARB)
```

- **Auth:** `SupabaseClient(accessToken: tokenManager.accessToken)`.
  - JWT diperbarui otomatis 60 detik sebelum kedaluwarsa dan didorong ke koneksi realtime (`realtime.setAuth`).
  - Request yang ditolak karena JWT kedaluwarsa diulang sekali setelah refresh.
- **Error:** semua API melempar `OltSocialException` dengan `kind` (`rateLimited`, `contentBlocked`, `forbidden`, …).
  - `code` berisi kode stabil dari server, misalnya `rate_limited`.
  - UI menampilkan pesan terlokalisasi lewat `context.oltL10n.errorMessage(e)`.
- **Realtime:**
  - `postgres_changes` (tunduk RLS) untuk pesan, post, komentar, dan notifikasi.
  - Channel private `room:<id>` untuk mengetik/read receipt, dan `online` untuk presence. Keduanya diotorisasi policy `realtime.messages`.
- **Test:** widget bisa diuji tanpa backend dengan membungkusnya di `OltSocialScope(dependencies: fake)`.

## Pengembangan

```bash
flutter pub get
dart run build_runner build      # setelah mengubah model/state freezed
flutter gen-l10n                 # setelah mengubah file .arb
flutter analyze                  # wajib: tanpa issue
flutter test                     # unit + widget test (integration dilewati)
OLT_SOCIAL_IT=1 flutter test test/integration   # butuh stack Docker + seed
dart run tool/license_audit.dart # tolak GPL/AGPL/LGPL/MPL
```

| Test | Isi |
|---|---|
| `test/core` | Parser `$KODE`/`@mention` (identik dengan regex di DB), pemetaan error, TokenManager (single-flight, refresh, login gagal) |
| `test/data` | Repository dengan data source mock: parameter RPC, pemetaan baris, pagination, idempotensi |
| `test/presentation` | Widget test thread komentar: indentasi, "Lanjutkan thread", "Lihat N balasan", collapse, like optimistic, balas |
| `test/integration` | Ke backend nyata: login, feed keyset, thread, komentar & chat realtime, channel private, presence, rate limit |
| `example/integration_test` | E2E app di Windows: login → feed → thread → komentar (Enter) → chat (Enter) → notifikasi |

## Lisensi

Proprietary (lihat `LICENSE`). Semua dependensi runtime berlisensi permisif: MIT, BSD, atau Apache-2.0. Ini diverifikasi dengan `tool/license_audit.dart`.
