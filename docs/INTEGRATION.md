# Integrasi `rendezvous_community` ke Aplikasi OLT

Langkah memasang fitur sosial ke proyek Flutter OLT yang sudah ada (Windows + Android). Package memakai **flutter_bloc 9**, `supabase_flutter` 2.x, dan Material 3, serta mengikuti `ThemeData` aplikasi.

**Batas integrasi:** server sosial hanya memverifikasi *token sosial* yang ditandatangani OLT, secara lokal tanpa memanggil OLT. Order, daftar dan nama saham, harga, portofolio, dan data nasabah tetap di app OLT; package hanya menerima perintah dan kode saham sebagai label. Rinciannya di [olt-integration.md](olt-integration.md).

## 1. Tambahkan dependency

```yaml
# pubspec.yaml aplikasi OLT
dependencies:
  rendezvous_community:
    git:
      url: <url repo internal>
      path: packages/rendezvous_community
      ref: v1.1.0            # pin tag/commit
  flutter_localizations:
    sdk: flutter
```

Untuk pengembangan lokal bisa memakai `path: ../olt-social/packages/rendezvous_community`.

> Package ini sebelumnya bernama `olt_social` (sampai 0.3.0). Bila app OLT masih memakai nama lama, ikuti [panduan migrasi 1.0](rendezvous-community/migration-1.0.md).

Kompatibilitas:
- **Flutter:** ≥ 3.44, Dart ≥ 3.12.
- **flutter_bloc:** OLT boleh memakai `flutter_bloc` 9.x yang sama. Bloc milik package tersimpan di subtree widget-nya sendiri dan tidak bentrok dengan Bloc OLT.

## 2. Konfigurasi platform

**Android:**
- `android/app/src/main/AndroidManifest.xml` wajib berisi:

  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  ```

- Produksi memakai HTTPS. Bila staging masih HTTP, izinkan cleartext **hanya** di `src/debug/AndroidManifest.xml`. Contohnya ada di `packages/rendezvous_community/example/android`.
- Pemilihan gambar memakai `file_selector`, yang membuka pemilih dokumen sistem; tidak perlu izin storage.
- Bila memakai notifikasi lokal untuk balasan CS (`flutter_local_notifications`):
  - tambahkan izin `android.permission.POST_NOTIFICATIONS` (Android 13+);
  - aktifkan core library desugaring di `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` dan `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.

**Windows:** tidak ada konfigurasi tambahan.

## 3. Inisialisasi setelah login OLT

Panggil `RendezvousCommunity.initialize` **setelah** user berhasil login ke OLT, dengan cara apa pun: username/email + password atau token. Package tidak pernah melihat password; ia hanya meminta **token sosial** lewat `tokenProvider`.

Token sosial adalah JWT berumur pendek (≤ 15 menit) yang diterbitkan backend OLT saat login dan saat app memintanya lagi. Formatnya ada di [olt-integration.md](olt-integration.md#3-format-token-sosial). `tokenProvider` harus mengembalikan token sosial yang **masih berlaku**: bila hampir kedaluwarsa, minta yang baru ke OLT dulu. Jangan mengembalikan token sesi OLT, karena token itu ditolak.

```dart
import 'package:rendezvous_community/rendezvous_community.dart';

Future<void> onOltLoggedIn() async {
  await RendezvousCommunity.initialize(
    supabaseUrl: Env.socialApiUrl,          // https://social-api.domain.com
    anonKey: Env.socialAnonKey,             // ANON_KEY (aman di aplikasi)
    // authBridgeUrl default: '<supabaseUrl>/bridge/v1'
    tokenProvider: () => oltSession.freshSocialToken(),   // token sosial yang masih berlaku; null bila sudah logout
    onStockTap: (context, code) => OltRouter.openStock(context, code),  // halaman saham OLT
    stockSearch: (query) => OltStockDirectory.search(query),             // saran $KODE dari daftar saham OLT
    onUserTap: null,      // null = pakai halaman profil bawaan rendezvous_community
    onPostTap: null,      // null = buka CommunityPostDetail
    onRoomTap: null,      // null = buka CommunityChatRoom
    logHandler: (record) => oltLog.write(record.level.name, record.loggerName, record.message),  // opsional
  );
}

Future<void> onOltLoggedOut() async {
  await RendezvousCommunity.instance.signOut();       // tutup sesi sosial & koneksi realtime
}
```

Yang terjadi di belakang layar:
- **Penerbitan JWT:** auth-bridge memeriksa tanda tangan token sosial dengan kunci publik OLT, lalu menukarnya menjadi JWT Supabase berumur 15 menit. Server sosial tidak menghubungi OLT.
- **Refresh otomatis:** JWT diperbarui sebelum kedaluwarsa, termasuk untuk koneksi realtime yang sedang berjalan. Saat refresh, `tokenProvider` dipanggil lagi.
- **Token sosial ditolak** (kedaluwarsa, salah tanda tangan, atau OLT berhenti menerbitkannya karena akun disuspend/logout): semua API melempar `CommunityException(kind: unauthenticated)`, dan UI menampilkan *"Sesi berakhir. Silakan login ulang di OLT."*. OLT sebaiknya mengarahkan user ke login ulang.
- **Log:** library tidak mencetak ke konsol. Tanpa `logHandler`, log hanya muncul di mode debug. Log berbahasa Inggris, field terstruktur, dan data sensitif disamarkan ([logging.md](rendezvous-community/logging.md)).
- **Memastikan sesi sejak awal:** `await RendezvousCommunity.instance.ensureSignedIn()` melempar error lebih awal, misalnya bila backend tidak terjangkau.

**Data saham dari OLT.** Server tidak menyimpan daftar saham:
- `stockSearch` mengembalikan `List<StockSuggestion>` (kode + nama) dari daftar saham milik OLT untuk saran saat nasabah mengetik `$`. Tanpa callback ini, `$KODE` tetap bisa diketik, hanya tanpa saran.
- Kode apa pun yang berformat `$KODE` (huruf di depan, 2–12 huruf/angka) diterima sebagai label untuk feed, pantau, dan room saham. Validasi kode yang benar-benar ada adalah tugas app OLT.
- Nama saham di header `CommunityStockFeed` datang dari parameter `stockName`. Harga dan grafik tetap di halaman saham OLT.

## 4. Lokalisasi & tema

```dart
MaterialApp(
  localizationsDelegates: const [
    CommunityLocalizations.delegate,
    AppLocalizations.delegate,                 // milik OLT
    GlobalMaterialLocalizations.delegate,      // package:flutter_localizations
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('id'), Locale('en')],
  theme: oltTheme,          // rendezvous_community mengikuti ColorScheme ini (terang & gelap)
  darkTheme: oltDarkTheme,
);
```

- **Lokalisasi:** tanpa delegate pun package tetap tampil dalam bahasa Indonesia.
- **Warna bullish/bearish dan indentasi thread:** sesuaikan lewat `CommunityTheme` (ThemeExtension). Lihat README package.
- **Tampilan chat versi OLT:** pasang `CommunityChatBuildersScope` di `MaterialApp.builder`, lalu isi builder untuk bagian yang ingin diganti (gelembung pesan, composer, header room, tile daftar chat, status kosong/error, dan lainnya). Builder menerima data siap tampil dan handler yang sudah jadi, jadi OLT hanya menggambar UI. Contoh dan daftar lengkapnya ada di README package, bagian "Kustomisasi UI chat (builder)".

## 5. Tempatkan widget

Semua widget adalah konten tanpa `Scaffold`, sehingga OLT tetap memegang AppBar, navigasi, dan layout halaman.

| Lokasi di OLT | Widget |
|---|---|
| Tab/menu "Stream" | `const CommunityStreamFeed()` |
| Halaman detail saham (tab "Diskusi") | `CommunityStockFeed(stockCode: code, showHeader: false)` (header disembunyikan karena OLT sudah menampilkan info saham). Bila header dipakai, isi `stockName` dari data OLT |
| Tombol tulis post | `showCommunityComposer(context, initialStock: code)` atau `CommunityComposePost(...)` |
| Menu "Chat" | `const CommunityChatList()` (otomatis multi-panel di Windows) |
| Ikon menu/tab "Chat" | `CommunityChatBadge(child: Icon(Icons.chat_bubble_outline))` (jumlah chat yang punya pesan belum dibaca) |
| Ikon lonceng | `CommunityNotificationBadge(child: Icon(Icons.notifications))` → `CommunityNotificationList()` |
| Halaman profil sosial | `CommunityUserProfile(userId: id)` |
| Deep link post | `CommunityPostDetail(postId: id)` |
| Menu "Bantuan / Chat CS" | Windows: `CommunitySupportChat(onClose: ...)` sebagai panel samping (lebar ±420). Android: `openCommunitySupport(context)` (layar penuh dengan tombol kembali) |
| Ikon menu "Bantuan" | `CommunitySupportBadge(child: Icon(Icons.support_agent_outlined))` (balasan CS yang belum dibaca) |
| Tombol bantuan di layar order / dana / portofolio | `openCommunitySupport(context, topic: 'orders', screen: 'order_detail')` atau `CommunitySupportChat(topic: ..., screen: ...)` di panel samping. Topik dan asal layar ikut tercatat di tiket; detail order tidak dikirim ke server |
| Riwayat tiket | `CommunitySupportTickets()` (juga ada di menu "⋯" room CS) |

Contoh tab Diskusi di halaman saham OLT:

```dart
TabBarView(children: [
  StockChartTab(code: code),          // milik OLT
  OrderBookTab(code: code),           // milik OLT
  CommunityStockFeed(stockCode: code, showHeader: false),
]);
```

Navigasi dari dalam widget sosial memakai callback dari langkah 3. Contohnya, mengetuk `$TLKM` di sebuah post memanggil `onStockTap(context, 'TLKM')`, sehingga OLT bisa membuka halaman sahamnya sendiri.

### Chat CS (modul `support`)

Room CS selalu disematkan paling atas di `CommunityChatList` dengan badge **CS Resmi**. Mengetuknya membuka tampilan CS, bukan chat biasa.

**Alur nasabah:**
1. **Buka chat CS.** Bila sudah ada tiket aktif, `CommunitySupportChat` langsung membuka tiket itu.
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

**Notifikasi saat CS mengambil, membalas, atau menyelesaikan tiket.** `RendezvousCommunity.instance.support.notices()` mengalirkan `SupportNotice` (judul = nama CS, isi = cuplikan pesan) selama aplikasi berjalan. Tampilkan sebagai notifikasi lokal bila room CS sedang tidak terbuka. Contohnya ada di `example/lib/support_notifications.dart` (`flutter_local_notifications`, BSD-3: Windows toast dan Android). Push saat aplikasi tertutup dikirim layanan notifier lewat FCM: daftarkan token dengan `RendezvousCommunity.instance.registerPushToken(...)` dan buka push yang diketuk dengan `openCommunityPush(context, message.data)`. Langkahnya ada di [docs/push](push/README.md#aplikasi-olt-pengembang).

## 6. Penanganan error

Semua method repository melempar `CommunityException`. Widget bawaan sudah menampilkan pesan terlokalisasi. Bila OLT memanggil repository langsung:

```dart
try {
  await RendezvousCommunity.instance.chat.sendMessage(roomId, body: text, clientId: uuid);
} on CommunityException catch (e) {
  final message = context.communityL10n.errorMessage(e);   // pesan ramah pengguna
  if (e.kind == CommunityErrorKind.unauthenticated) oltSession.requireLogin();
}
```

Jenis error (`kind`) yang tersedia: `network`, `unauthenticated`, `rateLimited`, `contentBlocked`, `invalidInput`, `forbidden`, `notFound`, `unavailable`, `unknown`.

## 7. Memakai API tanpa UI bawaan

Bila hanya tampilan yang ingin diganti, pakai builder (langkah 4) supaya logika chat tetap dari package. Bila OLT ingin membuat UI sendiri sepenuhnya, semua repository tersedia di `RendezvousCommunity.instance`:
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

Bungkus widget sosial dengan `CommunityScope` dan berikan implementasi palsu `CommunityDependencies`. Dengan begitu widget test berjalan tanpa backend. Contohnya ada di `packages/rendezvous_community/test/support/fakes.dart`.

## 9. Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| Emulator Android tidak bisa terhubung | Gunakan `http://10.0.2.2:8000`, bukan `localhost`. Untuk HP fisik: `EDGE_HTTP_BIND=0.0.0.0` + IP PC |
| `Cleartext HTTP traffic not permitted` | Build debug: tambahkan `usesCleartextTraffic` di manifest debug. Produksi: gunakan HTTPS |
| Selalu "Sesi berakhir" | `tokenProvider` mengembalikan null, token sesi OLT (bukan token sosial), atau token sosial kedaluwarsa. Alasan pastinya ada di `docker compose logs auth-bridge` (`exchange ditolak`, field `reason`) |
| Log auth-bridge: `kid tidak dikenal` / `tanda tangan tidak valid` | `docker/secrets/olt_jwks` belum berisi kunci publik OLT yang dipakai menandatangani. Tambahkan JWKS dari OLT, lalu restart auth-bridge |
| Log auth-bridge: `masa berlaku token melebihi batas` / `token kedaluwarsa` | OLT menerbitkan token lebih dari `OLT_JWT_MAX_TTL` (15 menit), atau jam server OLT/sosial selisih lebih dari 30 detik (cek NTP) |
| Log auth-bridge: `audience` / `issuer` | Klaim `aud` harus memuat `olt-social` dan `iss` harus `olt` (atau sesuai `OLT_JWT_AUDIENCE` / `OLT_JWT_ISSUER`) |
| Realtime tidak masuk | Pastikan port 443/8000 meneruskan WebSocket (Traefik sudah). Cek `docker compose logs realtime` |
| "Terlalu cepat" | Rate limit server (post 5/menit, komentar 20/menit, pesan 30/menit). Ubah lewat `private.rate_limits` |
