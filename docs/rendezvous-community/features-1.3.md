# Fitur `rendezvous_community` 1.3.0

Sisi klien untuk paket backend November 2026: [docs/social/README.md](../social/README.md) (pencarian, trending, edit, bookmark, reaksi, bagikan, preferensi notifikasi, konfigurasi klien, analitik), [docs/content-safety.md](../content-safety.md) (filter konten, akun baru, permintaan DM, banding, slow mode), [services/link-preview](../../services/link-preview/README.md), [services/media](../../services/media/README.md) (moderasi gambar), dan [docs/integration](../integration/README.md) (push transaksi OLT).

## Komposisi

Semua fitur baru tersedia lewat `CommunityFeatureDependencies` (diimplementasikan `RendezvousCommunity`) dan dicari widget dengan `CommunityFeatureScope.maybeOf(context)`:

| Getter | Kelas | RPC |
|---|---|---|
| `configService` | `ClientConfigService` | `get_client_config` |
| `search` | `SearchRepository` | `search`, `get_hashtag_feed`, `get_trending_hashtags` |
| `trending` | `TrendingRepository` | `get_trending`, `get_stock_sentiment` |
| `bookmarks` | `BookmarkRepository` | `toggle_bookmark`, `get_bookmarks` |
| `edits` | `ContentEditRepository` | `edit_post`, `edit_comment` |
| `chatExtras` | `ChatExtrasRepository` | `react_to_message`, `share_post_to_chat`, `get_stock_room_state` |
| `messageRequests` | `MessageRequestRepository` | `get_message_requests`, `get_message_request_count`, `respond_message_request`, `get_dm_request_state`, `get_dm_policy`, `set_dm_policy` |
| `appeals` | `AppealRepository` | `create_appeal`, `get_my_appeals`, `get_my_sanctions`, `get_my_moderated_content` |
| `notificationPreferences` | `NotificationPreferencesRepository` | `get_notification_prefs`, `set_notification_prefs` |
| `linkPreviews` | `LinkPreviewLoader` | `get_link_previews` |
| `analytics` | `CommunityAnalytics` | `track_events` |

Tanpa `CommunityFeatureScope` dan tanpa `RendezvousCommunity.initialize` (misalnya tes yang hanya memasang `CommunityScope` palsu), fitur baru tidak tampil: menu Edit/Simpan/Kirim ke chat hilang, gerbang kill switch transparan, link preview tidak dimuat. `CommunityDependencies` tidak berubah.

## Konfigurasi klien

- `ClientConfigService.refresh()` single-flight; gagal → konfigurasi terakhir tetap dipakai dan log `WARNING Config`.
- Pemicu: `initialize()` (langsung + timer 5 menit + `AppLifecycleListener.onResume`), dan setiap ganti user di `sessionChanges` (hanya setelah `initialize`, instance dari `create()` tidak memuat otomatis).
- Sebelum login dipakai `SocialRemoteDataSource.anonymousRpcValue` (header `apikey` + `Authorization: Bearer <anon>`), sesudahnya sesi JWT supaya rollout persentase per user berlaku.
- `ClientConfig.flag(key)`: sebelum termuat `true`; setelah termuat `flags[key] ?? false`. `feature(key)` = `socialEnabled && flag(key)`.
- `canEdit(createdAt)` memakai `serverNow()` (jam lokal + selisih `server_time`) dan `editWindow` dari `edit_minutes`.
- Error apa pun dengan kode `social_disabled` dari data source memanggil `markSocialDisabled()` (UI langsung disembunyikan) lalu memuat ulang konfigurasi.

| Widget | Gerbang |
|---|---|
| `CommunityFeedList` (stream, saham, profil), `CommunityComposePost`, `CommunityPostDetail` | `social_enabled` |
| `CommunityChatRoom` | `social_enabled` kecuali room `support` |
| `CommunityChatList` | `social_enabled = false` → hanya room CS + placeholder; entri permintaan pesan disembunyikan |
| `CommunitySearch`, `CommunityHashtagFeed`, tautan `#hashtag` | `search` |
| `CommunityTrending`, `CommunityStockSentiment` (hilang tanpa placeholder) | `trending` |
| `CommunityBookmarks`, menu/ikon simpan | `bookmarks` |
| Menu Edit | `post_edit` + jendela edit |
| Reaksi pesan | `message_reactions` |
| "Kirim ke chat" | `share_post_to_chat` (tidak tampil untuk post sendiri yang `held`/`hidden`) |
| Bagian "Notifikasi" di Privasi & akun | `notification_prefs` |
| Pencatatan analitik | `analytics` |

## Keamanan konten

- `CommunityException.retryAfter` diisi dari `details` angka (PostgREST, `slow_mode`) atau header `Retry-After` (media gateway).
- Pesan `content_blocked`/`link_blocked`/`contact_blocked` (422) menghapus pesan chat lokal seperti sebelumnya; error lain (termasuk `slow_mode`, `dm_request_limit`, `new_account_restricted`) menandai pesan "Gagal terkirim" agar bisa dikirim ulang.
- `moderation_status` hanya terisi pada baris milik pemanggil (`0083`): `held` → "Menunggu tinjauan", `hidden` → "Disembunyikan moderator" + "Ajukan banding". Pesan realtime (event `message` dari server, `0098`) tidak membawa `moderation_status`; pesan `held`/`hidden` tidak pernah disiarkan, dan label hanya ditampilkan untuk pesan sendiri.
- Unggahan dengan `"held": true` → `Attachment.held` (tidak ikut dikirim ke server). Status ini dipertahankan saat pesan lokal diganti baris server dan saat post baru masuk ke feed.

## Permintaan pesan & kebijakan DM

- `MessageRequestsEntry` memuat `get_message_request_count` saat dibuat dan setiap pull-to-refresh daftar chat; tidak tampil bila 0.
- Room permintaan memuat 50 pesan terakhir lewat `get_messages` tanpa `mark_room_read` dan tanpa realtime; gambar diburamkan (`AttachmentGrid(blurred: true)`), teks tampil sebagai teks biasa (tautan tidak bisa diketuk).
- Terima → room dibuka seperti biasa (`CommunityNavigator.openRoom`). Tolak/Blokir → kembali ke daftar. Blokir meminta konfirmasi.
- Status DM saat room dibuka: `ChatRoomCubit` memanggil `get_dm_request_state` (`DmRequestState`) untuk room `direct`. Pengirim: "Pesan Anda masih berupa permintaan (n/max)", `sent` naik setiap pesan terkirim, dan pemberitahuan batas saat `sent >= max_messages` atau setelah `dm_request_limit`. Permintaan yang ditolak sengaja tetap dilaporkan `pending` ke pengirim. Penerima (`role: recipient`, `pending`): banner dengan tombol "Terima" (`acceptDmRequest`); membalas juga menerima. Bila RPC tidak tersedia (fitur tidak terpasang), paket kembali ke penjelasan bersyarat untuk DM yang belum dibalas.

## Banding

- `showCommunityAppealDialog(targetType, targetId)` → `create_appeal` (alasan 10–1000 karakter, divalidasi sebelum dikirim).
- Titik masuk: label konten `hidden` milik sendiri (post, komentar, pesan), "Banding saya" (sanksi aktif dari `get_my_sanctions` dan "Konten yang dimoderasi" dari `get_my_moderated_content`: konten `hidden` dan `removed` 90 hari terakhir beserta banding terakhirnya; tombol "Ajukan banding" hanya untuk yang belum dibanding), notifikasi dan push `appeal`. Bila `get_my_moderated_content` gagal, bagian itu kosong dan bagian lain tetap tampil.

## Room saham

`ChatRoomCubit` memuat `get_stock_room_state(code)` untuk room `stock` dan memperbarui dari broadcast `room_state` di `room:<id>`. Hitung mundur di composer (`ChatRoomState.cooldownUntil`) diisi dari `wait_seconds` saat dibuka, dari `slow_mode_seconds` setelah berhasil mengirim, dan dari `retryAfter` saat server menolak `slow_mode`. Broadcast `room_state` dibuat tanpa user (`wait_seconds` selalu 0), jadi hitung mundur lokal tidak ditimpa.

## Reaksi & bagikan

- Reaksi: `ChatRoomCubit.react(message, emoji)` optimistis (`applyReaction`), lalu memakai daftar dari server. Broadcast `reaction` membawa total tanpa `me`; paket menghitung `mine` dari `user_id`.
- Baris realtime tidak membawa `reactions`/`shared_post`; saat menggabungkan, nilai lama dipertahankan. Bila pesan bagikan masuk lewat realtime tanpa `shared_post`, `SharedPostCard` memuat `get_post` sekali.
- Lampiran `{"type": "post", "post_id": ...}` dipisahkan dari lampiran gambar (`ChatMessage.sharedPostId`).

## Pencarian, hashtag, tautan

- Parser (`core/text/social_text_parser.dart`) memakai pola hashtag yang sama dengan `private.extract_hashtags` (`(?<![[:alnum:]_#&/])#([A-Za-z0-9_]{2,50})`), dan URL `https?://…` dengan tanda baca penutup dibuang (kurung seimbang dipertahankan). Link selalu menang atas mention/cashtag/hashtag di dalam URL.
- `openCommunityLink` hanya membuka `http`/`https` tanpa userinfo, setelah dialog yang menebalkan host asli.
- `SearchCubit`: debounce 300 ms, minimal `search_min_length` karakter yang mengandung huruf/angka, `p_type = all` (5 per jenis) untuk tab Semua, 20 per halaman untuk tab lain; hasil basi diabaikan.

## Link preview

`LinkPreviewLoader.watch(url)` mengembalikan `ValueListenable<LinkPreview?>`. Permintaan dalam 80 ms digabung (maks 20 URL per RPC). `pending` diulang setelah 3 dan 10 detik lalu dianggap `none`. Cache 300 URL per sesi, dikosongkan saat ganti user. Gambar dari bucket publik `link-previews`; domain yang ditampilkan dari `final_url`.

## Analitik

`CommunityAnalytics.record(event, props)` → antrean (maks 500). Kirim saat 20 event, tiap 60 detik (setelah `initialize`), saat `onHide`/`onPause`, dan saat `signOut`. `flush()` mengembalikan `AnalyticsResult` gabungan. Properti disaring `sanitizeAnalyticsProps` sesuai tabel di docs/social (selain itu dibuang di klien juga).

| Event | Dicatat di | Properti |
|---|---|---|
| `feed_open` | `CommunityFeedList`, `CommunityHashtagFeed`, `CommunityBookmarks` | `scope`, `stock_code`/`hashtag` |
| `post_create` | composer | `post_id`, `has_attachment`, `has_poll`, `stock_code`, `source` (`share` untuk chart) |
| `comment_create` | detail post | `post_id`, `is_reply`, `source` |
| `message_send` | `ChatRoomCubit` (bukan CS) | `room_id`, `type`, `has_attachment` |
| `stock_tap` | `CommunityNavigator.openStock` | `stock_code`, `source` |
| `search` | `SearchCubit` | `type`, `query_length`, `result_count` |
| `share_chart` | composer dengan `initialImage` | `post_id`, `stock_code` |
| `order_tap` | host: `trackOrderTap()` | `stock_code`, `side`, `source` |

## Platform

`CommunityPlatform` (`android`, `ios`, `web`, `windows`, `macos`, `linux`) dikirim ke `get_client_config` dan `track_events` (migrasi `0085`). Default: `defaultCommunityPlatform()` dari `kIsWeb`/`defaultTargetPlatform`. Push tetap memakai `CommunityPushPlatform` (`android`, `ios`, `web`).

## Catatan backend

- Paket ≤ 1.2.0 gagal mem-parse `get_messages` untuk room yang berisi pesan bagikan post (lampiran `{"type": "post"}` tanpa `path`). Belum ada app OLT yang memakai ≤ 1.2.0, jadi tidak ada perubahan backend.
- Status permintaan DM untuk pengirim (`get_dm_request_state`), platform desktop, dan titik masuk banding konten yang dihapus (`get_my_moderated_content`) ditambahkan di migrasi `0085`.
