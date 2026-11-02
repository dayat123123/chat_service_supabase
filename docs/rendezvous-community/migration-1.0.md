# Pindah dari `olt_social` 0.3.0 ke `rendezvous_community` 1.0.0

Rilis 1.0.0 adalah **refactor murni**: nama package dan simbol publik berganti, pesan internal menjadi Bahasa Inggris, dan library mendapat logger. Perilaku, tampilan, API backend, skema database, dan nama topik Realtime **tidak berubah**.

## 1. Langkah di aplikasi OLT

1. **`pubspec.yaml`:**
   ```yaml
   dependencies:
     rendezvous_community:          # sebelumnya: olt_social
       git:
         url: <url repo internal>
         path: packages/rendezvous_community   # sebelumnya: packages/olt_social
         ref: v1.0.0
   ```
2. **Ganti import:** `package:olt_social/olt_social.dart` → `package:rendezvous_community/rendezvous_community.dart`.
3. **Ganti nama simbol** sesuai tabel di bagian 2. Rename lewat IDE paling aman: setelah import diganti, `dart fix` tidak bisa menebak nama baru, jadi pakai tabel ini atau cari-ganti per simbol.
4. **Opsional:** pasang handler log OLT: `RendezvousCommunity.initialize(logHandler: ..., logLevel: ...)`. Lihat [logging.md](logging.md).
5. Jalankan `flutter analyze` dan tes OLT.

Parameter `oltTokenProvider` menjadi **`tokenProvider`** (isi dan perilakunya sama: kembalikan token sosial yang masih berlaku, atau `null` bila user sudah logout). Callback lain tidak berubah: `onStockTap`, `onUserTap`, `onPostTap`, `onRoomTap`, dan `stockSearch`.

## 2. Tabel simbol

| 0.3.0 (`olt_social`) | 1.0.0 (`rendezvous_community`) |
|---|---|
| `OltSocial` | `RendezvousCommunity` |
| `OltSocial.initialize(oltTokenProvider: ...)` / `create(oltTokenProvider: ...)` | `RendezvousCommunity.initialize(tokenProvider: ...)` / `create(tokenProvider: ...)` |
| `OltSocialException`, `OltSocialErrorKind` | `CommunityException`, `CommunityErrorKind` |
| `OltSocialScope`, `OltSocialDependencies`, `OltSocialCallbacks` | `CommunityScope`, `CommunityDependencies`, `CommunityCallbacks` |
| `OltSocialTheme` | `CommunityTheme` |
| `OltSocialLocalizations`, `lookupOltSocialLocalizations` | `CommunityLocalizations`, `lookupCommunityLocalizations` |
| `context.oltL10n`, `OltL10nContext`, `OltErrorText` | `context.communityL10n`, `CommunityL10nContext`, `CommunityErrorText` |
| `OltSupportScope`, `OltSupportDependencies` | `CommunitySupportScope`, `CommunitySupportDependencies` |
| `OltStreamFeed`, `OltFeedTab`, `OltFeedList` | `CommunityStreamFeed`, `CommunityFeedTab`, `CommunityFeedList` |
| `OltStockFeed` | `CommunityStockFeed` |
| `OltPostDetail`, `OltComposePost`, `showOltComposer` | `CommunityPostDetail`, `CommunityComposePost`, `showCommunityComposer` |
| `OltPollView` | `CommunityPollView` |
| `OltChatList`, `OltChatRoom`, `OltChatBadge`, `OltRoomAvatar` | `CommunityChatList`, `CommunityChatRoom`, `CommunityChatBadge`, `CommunityRoomAvatar` |
| `OltChatBuilders`, `OltChatBuildersScope`, `OltPartBuilder` | `CommunityChatBuilders`, `CommunityChatBuildersScope`, `CommunityPartBuilder` |
| `OltMessageDetails`, `OltComposerDetails`, `OltRoomHeaderDetails`, `OltTypingDetails`, `OltConnectionDetails`, `OltDayDetails`, `OltRoomTileDetails`, `OltChatListHeaderDetails`, `OltLoadingDetails`, `OltEmptyDetails`, `OltErrorDetails`, `OltChatEmpty`, `OltChatLoad` | nama yang sama dengan prefix `Community` |
| `OltNotificationList`, `OltNotificationBadge` | `CommunityNotificationList`, `CommunityNotificationBadge` |
| `OltUserProfile`, `OltUserName`, `OltAvatar` | `CommunityUserProfile`, `CommunityUserName`, `CommunityAvatar` |
| `OltSupportChat`, `OltSupportPage`, `openOltSupport`, `OltSupportTickets`, `OltSupportBadge`, `OltSupportMessageActions` | `CommunitySupportChat`, `CommunitySupportPage`, `openCommunitySupport`, `CommunitySupportTickets`, `CommunitySupportBadge`, `CommunitySupportMessageActions` |
| `OltComposerField`, `OltCountBadge`, `OltDisclaimer`, `OltSkeleton`, `OltEmptyView`, `OltErrorView`, `OltBreakpoints`, `OltNavigator` | nama yang sama dengan prefix `Community` |
| `OltStockTapCallback`, `OltUserTapCallback`, `OltPostTapCallback`, `OltRoomTapCallback`, `OltStockSearch` | `CommunityStockTapCallback`, `CommunityUserTapCallback`, `CommunityPostTapCallback`, `CommunityRoomTapCallback`, `CommunityStockSearch` |

Helper internal (tidak diekspor) ikut berganti: `showOltError` → `showCommunityError`, `showOltMessage` → `showCommunityMessage`, `confirmOlt` → `confirmCommunityAction`, `AuthBridgeClient.exchange(oltToken)` → `exchange(token)`. Di app contoh: `oltStocks`/`olt_stocks.dart` → `stockNames`/`stock_directory.dart`, `searchOltStocks` → `searchStocks`, `openOltStockPage` → `openStockPage`, `OltEmptyHint` → `DetailPlaceholder`.

File juga berganti nama: `olt_social.dart` → `rendezvous_community.dart`, `olt_social_*.dart` → `community_*.dart`, dan `olt_*.dart` → `community_*.dart`. File ARB menjadi `community_id.arb`/`community_en.arb`; kunci dan teksnya tidak berubah.

## 3. Nama yang sengaja dipertahankan

| Nama | Alasan |
|---|---|
| Topik Realtime `olt-<tabel>-<n>` | Nama topik Realtime tidak boleh berubah (aturan 2.3) |
| Field `olt_user_id` | Field dari backend/database |
| `applicationId`, `namespace`, dan package Kotlin `com.rendezvous.olt.olt_social_example` (app contoh Android) | Identitas app di perangkat. Bila diganti, Android menganggapnya app baru, sehingga update tidak terpasang di atas versi lama |
| AUMID `Rendezvous.Olt.SocialExample` + GUID notifikasi Windows, channel Android `cs_chat` | Identitas notifikasi; mengganti membuat registrasi notifikasi baru |
| `CompanyName` `com.rendezvous.olt` di `Runner.rc` | Identitas perusahaan, bukan nama package |
| `--dart-define`/env `OLT_SOCIAL_ANON_KEY`, `OLT_SOCIAL_URL`, `OLT_DUMMY_WS_URL`, `OLT_SOCIAL_IT`, `OLT_SOCIAL_IT_DUMMY`, `OLT_DUMMY_IT`, `OLT_DUMMY_E2E` | Dipakai Makefile, make.ps1, CI, dan perintah developer; mengganti tidak menambah manfaat bagi library |
| App contoh: `FakeOltAuth`, `DummyOltClient`/`DummyOltException`/`DummyOltSession`, `dummyOltWsUrl`, `fake_olt_auth.dart`, `dummy_olt_client.dart` | Menamai layanan `dummy-olt` dan login OLT tiruan (host), bukan bagian library |
| Komentar di `supabase/migrations/0004_posts.sql` | Migrasi yang sudah diterapkan tidak boleh diubah |

## 4. Data di perangkat (aturan 2.3)

| Item | Temuan | Keputusan |
|---|---|---|
| `flutter_secure_storage` (token) | Tidak dipakai. JWT sosial hanya di memori; token OLT milik host | Tidak ada yang dimigrasi. User tetap login karena sesi OLT disimpan host dan library menukar ulang token saat start |
| Database drift/SQLite (cache chat, antrean offline) | Tidak dipakai. Cache dan pesan gagal kirim hanya di memori | Tidak ada yang dimigrasi |
| Shared preferences (draf, tema, notifikasi) | Tidak dipakai oleh library maupun app contoh | Tidak ada yang dimigrasi |
| Channel notifikasi Android, ID notifikasi Windows | App contoh: channel `cs_chat`, AUMID dan GUID di atas | **Tetap** memakai nama lama |
| Folder cache gambar/lampiran | Tidak ada; gambar memakai cache memori Flutter | Tidak ada yang dimigrasi |
| Identitas app Android | `com.rendezvous.olt.olt_social_example` | **Tetap**, supaya update terpasang di atas versi lama |
| Nama binary Windows / judul web | `olt_social_example` → `rendezvous_community_example` | Diganti. Tidak ada data yang terikat ke nama ini |

## 5. Pesan internal lama → baru

| Lokasi | Lama | Baru |
|---|---|---|
| `RendezvousCommunity.instance` (`StateError`) | `OltSocial belum diinisialisasi. Panggil OltSocial.initialize() saat startup.` | `RendezvousCommunity is not initialized; call RendezvousCommunity.initialize() at startup` |
| `AuthBridgeClient` | `Respons auth-bridge tidak valid (<status>)` | `Auth-bridge returned an invalid response (status <status>)` |
| `TokenManager.refresh` | `TokenManager sudah ditutup` | `Token manager is closed` |
| `TokenManager` tanpa token | `Token OLT tidak tersedia (user belum login OLT)` | `Token provider returned no token because the user is not signed in to the host app` |
| `PollRepositoryImpl.vote` | `vote_poll kosong` | `vote_poll returned no result` |
| `CommentRepositoryImpl.create` | `create_comment kosong` | `create_comment returned no rows` |
| `CommunityUserProfile` (`assert`) | `userId atau username wajib diisi` | `Either userId or username is required` |
| `toString()` exception | `OltSocialException(...)` | `CommunityException(...)` |
| Tes | 171 deskripsi tes, nama grup, dan `reason` assertion; 1 `fail`; 2 `StateError` di fake; 1 alasan skip | Bahasa Inggris |
| App contoh `DummyOltClient` | `OLT dummy tidak dapat dihubungi di <url>. Jalankan stack dengan: …` / `Login gagal` / `Koneksi OLT dummy ditutup sebelum ada balasan` / `OLT dummy tidak menjawab` | `Dummy OLT is unreachable at <url>. Start the stack with: …` / `Sign-in failed` / `Dummy OLT closed the connection before replying` / `Dummy OLT did not respond` |
| App contoh, snackbar login | `Login OLT gagal: …` / `Gagal masuk ke OLT Social: <exception>` | `OLT sign-in failed: …` / `Rendezvous Community sign-in failed (<kind>, <code>)` (tanpa pesan server mentah) |
| App contoh, layar konfigurasi | `OLT_SOCIAL_ANON_KEY belum diisi. Jalankan dengan: …` | `OLT_SOCIAL_ANON_KEY is not set. Run with: …` |
| `tool/license_audit.dart` | `PERIKSA`, `<n> package runtime diperiksa.`, `Ada lisensi yang tidak diizinkan/tidak dikenali…`, `Semua lisensi permisif…` | `REVIEW`, `Checked <n> runtime packages`, `Found disallowed or unrecognized licenses; check the REVIEW rows`, `All licenses are permissive…` |

Pesan dari server (misalnya `message` dari auth-bridge atau `private.api_error`) diteruskan apa adanya di `CommunityException.message`. Pesan ini bukan bagian library dan tidak ditampilkan ke user; UI memetakan `kind`/`code` ke teks lokalisasi.

Sebelum 1.0.0 library belum punya log sama sekali. Daftar log baru ada di [logging.md](logging.md).
