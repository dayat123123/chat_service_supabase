# Integrasi `olt_social` ke Aplikasi OLT

Langkah memasang fitur sosial ke proyek Flutter OLT yang sudah ada (Windows + Android). Package memakai **flutter_bloc 9**, `supabase_flutter` 2.x, dan Material 3, serta mengikuti `ThemeData` aplikasi.

**Batas integrasi:** server sosial hanya memvalidasi token login OLT. Order, daftar dan nama saham, harga, portofolio, dan data nasabah tetap di app OLT; package hanya menerima perintah dan kode saham sebagai label. Rinciannya di [olt-integration.md](olt-integration.md).

## 1. Tambahkan dependency

```yaml
# pubspec.yaml aplikasi OLT
dependencies:
  olt_social:
    git:
      url: <url repo internal>
      path: packages/olt_social
      ref: v0.3.0            # pin tag/commit
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
- Bila memakai notifikasi lokal untuk balasan CS (`flutter_local_notifications`):
  - tambahkan izin `android.permission.POST_NOTIFICATIONS` (Android 13+);
  - aktifkan core library desugaring di `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` dan `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.

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
    stockSearch: (query) => OltStockDirectory.search(query),             // saran $KODE dari daftar saham OLT
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

**Data saham dari OLT.** Server tidak menyimpan daftar saham:
- `stockSearch` mengembalikan `List<StockSuggestion>` (kode + nama) dari daftar saham milik OLT untuk saran saat nasabah mengetik `$`. Tanpa callback ini, `$KODE` tetap bisa diketik, hanya tanpa saran.
- Kode apa pun yang berformat `$KODE` (huruf di depan, 2–12 huruf/angka) diterima sebagai label untuk feed, pantau, dan room saham. Validasi kode yang benar-benar ada adalah tugas app OLT.
- Nama saham di header `OltStockFeed` datang dari parameter `stockName`. Harga dan grafik tetap di halaman saham OLT.

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
- **Tampilan chat versi OLT:** pasang `OltChatBuildersScope` di `MaterialApp.builder`, lalu isi builder untuk bagian yang ingin diganti (gelembung pesan, composer, header room, tile daftar chat, status kosong/error, dan lainnya). Builder menerima data siap tampil dan handler yang sudah jadi, jadi OLT hanya menggambar UI. Contoh dan daftar lengkapnya ada di README package, bagian "Kustomisasi UI chat (builder)".

## 5. Tempatkan widget

Semua widget adalah konten tanpa `Scaffold`, sehingga OLT tetap memegang AppBar, navigasi, dan layout halaman.

| Lokasi di OLT | Widget |
|---|---|
| Tab/menu "Stream" | `const OltStreamFeed()` |
| Halaman detail saham (tab "Diskusi") | `OltStockFeed(stockCode: code, showHeader: false)` (header disembunyikan karena OLT sudah menampilkan info saham). Bila header dipakai, isi `stockName` dari data OLT |
| Tombol tulis post | `showOltComposer(context, initialStock: code)` atau `OltComposePost(...)` |
| Menu "Chat" | `const OltChatList()` (otomatis multi-panel di Windows) |
| Ikon menu/tab "Chat" | `OltChatBadge(child: Icon(Icons.chat_bubble_outline))` (jumlah chat yang punya pesan belum dibaca) |
| Ikon lonceng | `OltNotificationBadge(child: Icon(Icons.notifications))` → `OltNotificationList()` |
| Halaman profil sosial | `OltUserProfile(userId: id)` |
| Deep link post | `OltPostDetail(postId: id)` |
| Menu "Bantuan / Chat CS" | Windows: `OltSupportChat(onClose: ...)` sebagai panel samping (lebar ±420). Android: `openOltSupport(context)` (layar penuh dengan tombol kembali) |
| Ikon menu "Bantuan" | `OltSupportBadge(child: Icon(Icons.support_agent_outlined))` (balasan CS yang belum dibaca) |
| Tombol bantuan di layar order / dana / portofolio | `openOltSupport(context, topic: 'orders', screen: 'order_detail')` atau `OltSupportChat(topic: ..., screen: ...)` di panel samping. Topik dan asal layar ikut tercatat di tiket; detail order tidak dikirim ke server |
| Riwayat tiket | `OltSupportTickets()` (juga ada di menu "⋯" room CS) |

Contoh tab Diskusi di halaman saham OLT:

```dart
TabBarView(children: [
  StockChartTab(code: code),          // milik OLT
  OrderBookTab(code: code),           // milik OLT
  OltStockFeed(stockCode: code, showHeader: false),
]);
```

Navigasi dari dalam widget sosial memakai callback dari langkah 3. Contohnya, mengetuk `$TLKM` di sebuah post memanggil `onStockTap(context, 'TLKM')`, sehingga OLT bisa membuka halaman sahamnya sendiri.

### Chat CS (modul `support`)

Room CS selalu disematkan paling atas di `OltChatList` dengan badge **CS Resmi**. Mengetuknya membuka tampilan CS, bukan chat biasa.

**Alur nasabah:**
1. **Buka chat CS.** Bila sudah ada tiket aktif, `OltSupportChat` langsung membuka tiket itu.
2. **Pilih topik.** Bila belum ada tiket aktif, nasabah memilih topik di satu layar. Tiket langsung dibuat dan nasabah bisa mengetik atau mengirim gambar (mis. tangkapan layar order).
3. **Selama tiket berjalan**, nasabah melihat:
   - header dengan nomor, topik, dan status ("Menunggu CS", "Ditangani oleh [nama] – CS Resmi", "Menunggu balasan Anda", "Selesai");
   - pesan sistem yang ringkas;
   - pilihan jawaban cepat dari CS;
   - peringatan saat mengetik OTP/PIN/nomor kartu.
4. **Setelah tiket diselesaikan**, nasabah memberi rating langsung di chat.

Menu "⋯" berisi:
- Ajukan pengaduan
- Laporkan CS palsu
- Buat tiket baru
- Tiket saya
- Akhiri chat

Pesan yang gagal karena offline otomatis dikirim ulang saat koneksi kembali. Pengiriman ulang ini aman karena memakai `client_id` yang idempoten.

**Notifikasi saat CS mengambil, membalas, atau menyelesaikan tiket.** `OltSocial.instance.support.notices()` mengalirkan `SupportNotice` (judul = nama CS, isi = cuplikan pesan) selama aplikasi berjalan. Tampilkan sebagai notifikasi lokal bila room CS sedang tidak terbuka. Contohnya ada di `example/lib/support_notifications.dart` (`flutter_local_notifications`, BSD-3: Windows toast dan Android). Push saat aplikasi tertutup membutuhkan service notifier + FCM (tahap F1 produksi).

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

Bila hanya tampilan yang ingin diganti, pakai builder (langkah 4) supaya logika chat tetap dari package. Bila OLT ingin membuat UI sendiri sepenuhnya, semua repository tersedia di `OltSocial.instance`:
- `feed.getFeed(FeedScope.stock('BBCA'), cursor: ..., limit: 20)` mengembalikan `Paged<Post>`.
- `chat.getRooms(cursor: ..., limit: 30)` mengembalikan `Paged<ChatRoom>`; room CS selalu di halaman pertama. `chat.getRoom(roomId)` memuat satu room.
- `chat.getMessages(roomId, cursor: ..., limit: 30)` memuat pesan dari yang terbaru per halaman. `chat.getMessagesAfter(roomId, cursor)` menyusulkan pesan baru; selama `nextCursor` tidak `null`, masih ada pesan berikutnya.
- `comments.getThread(postId, maxDepth: 3)`.
- `chat.connectRoom(roomId, me: user).events` adalah stream realtime room (pesan, mengetik, tanda terima, presence).
- `chat.watchRoomSignals({roomId, ...}, me: user)` memantau mengetik, tanda terima, dan presence banyak room sekaligus (untuk daftar chat buatan sendiri).
- `polls.vote(postId, optionId)` memberi suara; data polling ada di `Post.poll`.
- `stocks.getStock(code)` mengembalikan kode, jumlah pemantau, dan status pantau user; `stocks.watch(code)` / `unwatch(code)` mengubahnya.

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
