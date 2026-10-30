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
| Chat | Centang ala WhatsApp: jam (mengirim), ✓ (sampai server), ✓✓ abu-abu (sudah diterima perangkat penerima yang online), ✓✓ biru (sudah dibaca). Di grup, centang naik setelah **semua** anggota menerima/membaca; room saham hanya ✓. Badge belum dibaca, balas pesan, reconnect otomatis dengan pengisian celah pesan |
| Mengetik & online | "mengetik…" (DM) atau "Budi sedang mengetik…" (grup) tampil di daftar chat dan di room. Titik hijau dan teks "Online" untuk lawan bicara DM |
| Polling | Tombol polling di composer: 2–4 pilihan (maks 40 karakter, tidak boleh sama), durasi 1 jam–7 hari. Satu suara per user dan tidak bisa diubah; pembuat tidak ikut memilih. Hasil (persentase, pilihan Anda, pilihan teratas) tampil setelah memilih, saat polling selesai, atau bagi pembuat |
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

Clean Architecture **per fitur**. Setiap fitur berdiri sendiri dengan tiga lapisan:

```
lib/src/
  app/        OltSocial (titik komposisi: merakit repository, DeliveryTracker),
              OltSocialDependencies (kontrak DI), OltSocialScope + OltNavigator
  core/       infrastruktur tanpa UI: auth (TokenManager, auth-bridge), error,
              network (data source Supabase, gateway & status realtime, SharedStream),
              paging, parser $KODE/@mention, MIME gambar
  shared/     entitas bersama (UserSummary, Attachment), model JSON bersama,
              kit UI (tema, lokalisasi ARB, avatar, state view, SocialText, composer)
  features/
    feed/          stream & feed, kartu post         chat/          daftar & room chat, centang, mengetik
    post/          detail post & thread komentar      poll/          polling: entitas, vote, OltPollView
    compose/       composer post + editor polling     notifications/ notifikasi & badge
    profile/       profil user                        stocks/        halaman saham & watchlist
    moderation/    laporan & blokir                   media/         unggah & tampilkan lampiran
      domain/        entitas immutable (freezed), kontrak repository, layanan domain
      data/          model JSON (freezed + json_serializable), implementasi repository
      presentation/  cubit/ (flutter_bloc) dan widgets/
```

Aturan dependensi:
- `core` tidak bergantung pada apa pun di package.
- `shared` hanya bergantung pada `core` (kecuali widget yang butuh navigasi lewat `OltSocialScope`).
- Fitur boleh memakai **domain** fitur lain (mis. `compose` memakai `poll/domain`), tidak pernah lapisan `data`-nya.
- `app` adalah satu-satunya tempat yang mengenal semua implementasi.
- Cubit selalu di file sendiri (`presentation/cubit/`), terpisah dari widget.
- Import di dalam package memakai `package:olt_social/...` (lint `always_use_package_imports`).
- Kode tanpa komentar; penjelasan ada di dokumen ini dan di `docs/`.

- **Auth:** `SupabaseClient(accessToken: tokenManager.accessToken)`.
  - JWT diperbarui otomatis 60 detik sebelum kedaluwarsa dan didorong ke koneksi realtime (`realtime.setAuth`).
  - Request yang ditolak karena JWT kedaluwarsa diulang sekali setelah refresh.
- **Error:** semua API melempar `OltSocialException` dengan `kind` (`rateLimited`, `contentBlocked`, `forbidden`, …).
  - `code` berisi kode stabil dari server, misalnya `rate_limited`.
  - UI menampilkan pesan terlokalisasi lewat `context.oltL10n.errorMessage(e)`.
- **Realtime:**
  - `postgres_changes` (tunduk RLS) untuk pesan, post, komentar, dan notifikasi. Langganan pesan masuk dibagi lewat `SharedStream` (satu channel untuk daftar chat dan `DeliveryTracker`).
  - Satu channel private `room:<id>` per room, dikelola `RoomChannelHub` dengan *ref-count*: daftar chat dan room yang sedang dibuka memakai channel yang sama (Phoenix menutup join ganda ke topic yang sama). Isinya: broadcast `typing` dari klien, broadcast `receipt` dari **server**, dan presence (siapa yang online di room itu). Otorisasinya lewat policy `realtime.messages`.
  - Daftar chat memantau maksimal 30 room DM/grup terbaru. Room saham tidak dipantau (terlalu ramai).
- **Centang (tanda terima):**
  - Selama aplikasi terbuka dan sesi aktif, `DeliveryTracker` (dijalankan `OltSocial`) memanggil RPC `mark_rooms_delivered` saat ada pesan masuk dari orang lain. Membuka room memanggil `mark_room_read`.
  - Kedua RPC menyimpan penanda di `chat_members` lalu menyiarkan `receipt` ke `room:<id>` lewat `realtime.send` di database. Klien tidak bisa memalsukan tanda terima orang lain.
  - Status per pesan dihitung fungsi domain `receiptStatus(sentAt, penerima)`. `get_my_rooms` mengembalikan `last_message_status` untuk pesan terakhir milik sendiri.
  - Matikan pelacakan terkirim dengan `OltSocial.initialize(trackDelivery: false)` bila host punya mekanisme sendiri.
- **Polling:** dibuat bersama post dalam satu transaksi (`create_post` dengan `p_poll`), dipilih lewat `vote_poll`. Jumlah suara hanya keluar lewat proyeksi feed (`feed_post.poll`); tabel suara tidak bisa dibaca langsung oleh client.
- **Idempotensi:** composer memakai `client_id` per draf, jadi kirim ulang setelah koneksi putus tidak membuat post ganda.
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
| `test/features/*/data` | Repository dengan data source mock: parameter RPC, pemetaan baris, pagination, idempotensi, polling, status centang |
| `test/features/*/domain` | Perhitungan centang (DM & grup), DeliveryTracker, aturan draf polling |
| `test/features/*/presentation` | Cubit daftar chat (mengetik, centang, online), cubit room, tile room, widget polling, composer polling, thread komentar |
| `test/integration` | Ke backend nyata: login, feed keyset, thread, komentar & chat realtime, presence per room, centang terkirim → dibaca, polling, rate limit |
| `test/support` | Fake dependensi & mock data source bersama |
| `example/integration_test` | E2E app di Windows: login → feed → thread → komentar (Enter) → chat (Enter) → notifikasi |

## Lisensi

Proprietary (lihat `LICENSE`). Semua dependensi runtime berlisensi permisif: MIT, BSD, atau Apache-2.0. Ini diverifikasi dengan `tool/license_audit.dart`.
