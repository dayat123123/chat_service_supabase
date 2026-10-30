# Integrasi `olt_social` ke Aplikasi OLT

Langkah memasang fitur sosial ke proyek Flutter OLT yang sudah ada (Windows + Android). Package memakai **flutter_bloc 9**, `supabase_flutter` 2.x, dan Material 3, serta mengikuti `ThemeData` aplikasi.

## 1. Tambahkan dependency

```yaml
# pubspec.yaml aplikasi OLT
dependencies:
  olt_social:
    git:
      url: <url repo internal>
      path: packages/olt_social
      ref: v0.1.0            # pin tag/commit
  flutter_localizations:
    sdk: flutter
```

Untuk pengembangan lokal bisa memakai `path: ../olt-social/packages/olt_social`.

Kompatibilitas:
- **Flutter:** ≥ 3.44, Dart ≥ 3.12.
- **flutter_bloc:** OLT boleh memakai `flutter_bloc` 9.x yang sama. Bloc milik package tersimpan di subtree widget-nya sendiri dan tidak bentrok dengan Bloc OLT.

## 2. Konfigurasi platform

**Android:**
- `android/app/src/main/AndroidManifest.xml` wajib berisi:

  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  ```

- Produksi memakai HTTPS. Bila staging masih HTTP, izinkan cleartext **hanya** di `src/debug/AndroidManifest.xml`. Contohnya ada di `packages/olt_social/example/android`.
- Pemilihan gambar memakai `file_selector`, yang membuka pemilih dokumen sistem; tidak perlu izin storage.

**Windows:** tidak ada konfigurasi tambahan.

## 3. Inisialisasi setelah login OLT

Panggil `OltSocial.initialize` **setelah** user berhasil login ke WebSocket OLT, dengan cara apa pun: username/email + password atau token. Package tidak pernah melihat password; ia hanya meminta token sesi lewat `oltTokenProvider`.

```dart
import 'package:olt_social/olt_social.dart';

Future<void> onOltLoggedIn() async {
  await OltSocial.initialize(
    supabaseUrl: Env.socialApiUrl,          // https://social-api.domain.com
    anonKey: Env.socialAnonKey,             // ANON_KEY (aman di aplikasi)
    // authBridgeUrl default: '<supabaseUrl>/bridge/v1'
    oltTokenProvider: () async => oltSession.token,   // null bila belum/tidak login
    onStockTap: (context, code) => OltRouter.openStock(context, code),  // halaman saham OLT
    onUserTap: null,      // null = pakai halaman profil bawaan olt_social
    onPostTap: null,      // null = buka OltPostDetail
    onRoomTap: null,      // null = buka OltChatRoom
  );
}

Future<void> onOltLoggedOut() async {
  await OltSocial.instance.signOut();       // tutup sesi sosial & koneksi realtime
}
```

Yang terjadi di belakang layar:
- **Penerbitan JWT:** auth-bridge menukar token OLT menjadi JWT Supabase berumur 15 menit.
- **Refresh otomatis:** JWT diperbarui sebelum kedaluwarsa, termasuk untuk koneksi realtime yang sedang berjalan. Saat refresh, `oltTokenProvider` dipanggil lagi.
- **Token OLT ditolak:** semua API melempar `OltSocialException(kind: unauthenticated)`, dan UI menampilkan *"Sesi berakhir. Silakan login ulang di OLT."*. OLT sebaiknya mengarahkan user ke login ulang.
- **Memastikan sesi sejak awal:** `await OltSocial.instance.ensureSignedIn()` melempar error lebih awal, misalnya bila backend tidak terjangkau.

## 4. Lokalisasi & tema

```dart
MaterialApp(
  localizationsDelegates: const [
    OltSocialLocalizations.delegate,
    AppLocalizations.delegate,                 // milik OLT
    GlobalMaterialLocalizations.delegate,      // package:flutter_localizations
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('id'), Locale('en')],
  theme: oltTheme,          // olt_social mengikuti ColorScheme ini (terang & gelap)
  darkTheme: oltDarkTheme,
);
```

- **Lokalisasi:** tanpa delegate pun package tetap tampil dalam bahasa Indonesia.
- **Warna bullish/bearish dan indentasi thread:** sesuaikan lewat `OltSocialTheme` (ThemeExtension). Lihat README package.

## 5. Tempatkan widget

Semua widget adalah konten tanpa `Scaffold`, sehingga OLT tetap memegang AppBar, navigasi, dan layout halaman.

| Lokasi di OLT | Widget |
|---|---|
| Tab/menu "Stream" | `const OltStreamFeed()` |
| Halaman detail saham (tab "Diskusi") | `OltStockFeed(stockCode: code, showHeader: false)` (header disembunyikan karena OLT sudah menampilkan info saham) |
| Tombol tulis post | `showOltComposer(context, initialStock: code)` atau `OltComposePost(...)` |
| Menu "Chat" | `const OltChatList()` (otomatis multi-panel di Windows) |
| Ikon lonceng | `OltNotificationBadge(child: Icon(Icons.notifications))` → `OltNotificationList()` |
| Halaman profil sosial | `OltUserProfile(userId: id)` |
| Deep link post | `OltPostDetail(postId: id)` |

Contoh tab Diskusi di halaman saham OLT:

```dart
TabBarView(children: [
  StockChartTab(code: code),          // milik OLT
  OrderBookTab(code: code),           // milik OLT
  OltStockFeed(stockCode: code, showHeader: false),
]);
```

Navigasi dari dalam widget sosial memakai callback dari langkah 3. Contohnya, mengetuk `$TLKM` di sebuah post memanggil `onStockTap(context, 'TLKM')`, sehingga OLT bisa membuka halaman sahamnya sendiri.

## 6. Penanganan error

Semua method repository melempar `OltSocialException`. Widget bawaan sudah menampilkan pesan terlokalisasi. Bila OLT memanggil repository langsung:

```dart
try {
  await OltSocial.instance.chat.sendMessage(roomId, body: text, clientId: uuid);
} on OltSocialException catch (e) {
  final message = context.oltL10n.errorMessage(e);   // pesan ramah pengguna
  if (e.kind == OltSocialErrorKind.unauthenticated) oltSession.requireLogin();
}
```

Jenis error (`kind`) yang tersedia: `network`, `unauthenticated`, `rateLimited`, `contentBlocked`, `invalidInput`, `forbidden`, `notFound`, `unavailable`, `unknown`.

## 7. Memakai API tanpa UI bawaan

Bila OLT ingin membuat UI sendiri, semua repository tersedia di `OltSocial.instance`:
- `feed.getFeed(FeedScope.stock('BBCA'), cursor: ..., limit: 20)` mengembalikan `Paged<Post>`.
- `comments.getThread(postId, maxDepth: 3)`.
- `chat.connectRoom(roomId, me: user).events` adalah stream realtime room (pesan, mengetik, tanda terima, presence).
- `chat.watchRoomSignals({roomId, ...}, me: user)` memantau mengetik, tanda terima, dan presence banyak room sekaligus (untuk daftar chat buatan sendiri).
- `polls.vote(postId, optionId)` memberi suara; data polling ada di `Post.poll`.

Kontrak lengkapnya ada di `lib/src/features/<fitur>/domain/repositories/` (mis. `features/chat/domain/repositories/chat_repository.dart`).

## 8. Test di proyek OLT

Bungkus widget sosial dengan `OltSocialScope` dan berikan implementasi palsu `OltSocialDependencies`. Dengan begitu widget test berjalan tanpa backend. Contohnya ada di `packages/olt_social/test/support/fakes.dart`.

## 9. Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| Emulator Android tidak bisa terhubung | Gunakan `http://10.0.2.2:8000`, bukan `localhost`. Untuk HP fisik: `EDGE_HTTP_BIND=0.0.0.0` + IP PC |
| `Cleartext HTTP traffic not permitted` | Build debug: tambahkan `usesCleartextTraffic` di manifest debug. Produksi: gunakan HTTPS |
| Selalu "Sesi berakhir" | `oltTokenProvider` mengembalikan null/token kedaluwarsa, atau auth-bridge masih mode `mock` sementara app mengirim token asli (cek `docker compose logs auth-bridge`) |
| "Server OLT sedang tidak dapat dihubungi" | auth-bridge gagal menghubungi `OLT_WS_URL` dalam `OLT_WS_TIMEOUT` |
| Realtime tidak masuk | Pastikan port 443/8000 meneruskan WebSocket (Traefik sudah). Cek `docker compose logs realtime` |
| "Terlalu cepat" | Rate limit server (post 5/menit, komentar 20/menit, pesan 30/menit). Ubah lewat `private.rate_limits` |
