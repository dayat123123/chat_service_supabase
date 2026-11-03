## 1.4.0

* **Perbaikan:** `CommunityChatBuilders.merge()` kini menyertakan `stockCard`, sehingga scope bersarang
  (`CommunityChatRoom(builders: ...)`, `withChatBuilders`, scope di halaman yang dibuka package) tidak lagi
  membuang builder kartu saham milik host. Tes regresi + tes analyzer
  (`test/tool/merge_completeness_test.dart`) yang memastikan setiap `merge`/`copyWith`/`lerp` di package
  meneruskan semua field.
* **Perbaikan:** di desktop/web, scroll cepat saat kursor berada di atas tombol bertooltip tidak lagi membekukan
  input mouse. Semua list lazy package memakai `addAutomaticKeepAlives: false`, sehingga baris yang sedang di-hover
  tidak ditahan di luar layar (bug Flutter flutter/flutter#193566). Dijaga oleh `test/tool/list_keep_alive_test.dart`.
* Baru: builder UI untuk feed, notifikasi, profil, dan badge dengan pola yang sama seperti chat
  (`CommunityPartBuilder<T>(context, details, fallback)` + scope + `merge`):
  * `CommunityFeedBuilders`: `postCard`, `postAvatar`, `postHeader`, `postBody`, `attachments`, `linkPreview`,
    `stockTags`, `actionBar`, `poll`, `pinnedMarker`, `loading`, `empty`, `error`, `comment`
    (`CommunityPostDetails`, `CommunityLinkPreviewDetails`, `CommunityPollDetails`,
    `CommunityPinnedMarkerDetails`, `CommunityCommentDetails`) dengan handler like/komentar/bagikan/bookmark/
    edit/hapus/laporkan/blokir/banding/buka profil/buka saham/buka hashtag/vote.
  * `CommunityNotificationBuilders`: `item`, `header`, `loading`, `empty`, `error`.
  * `CommunityProfileBuilders`: `header`, `stats`, `followButton`.
  * `CommunityBadgeBuilders`: `label` (semua badge label sekaligus), `official`, `supportOfficial`, `bot`,
    `roomModerator`, `sentiment`, `verified`, `count`, `countOverlay`; dipakai di badge akun resmi, CS resmi,
    bot, moderator room, sentimen, centang terverifikasi, jumlah belum dibaca room/permintaan pesan, dan badge
    chat/CS/notifikasi. Widget baru `CommunityCountOverlay`.
  * `CommunityBuilders` + `CommunityBuildersScope` memasang kelima set sekaligus (bersarang = digabung), dan
    ikut terbawa ke halaman yang dibuka package. Parameter `builders:` baru di `CommunityFeedList`,
    `CommunityStreamFeed`, `CommunityNotificationList`, `CommunityUserProfile`.
  * Detail status daftar bersama: `CommunityListLoadingDetails`, `CommunityListEmptyDetails`,
    `CommunityListErrorDetails`. `CommunityPartBuilder` kini diekspor dari `shared`.
  * Tanpa builder, tampilan bawaan tidak berubah.
* Baru: gambar didekode seukuran tampilan (layout × `devicePixelRatio`, kelipatan 64 px, cover, maks 2048 px)
  untuk avatar, lampiran (post, chat, post yang dibagikan, permintaan pesan), dan link preview, dengan kunci
  cache stabil (`storage:<bucket>/<path>`, parameter tanda tangan URL dibuang) lewat `CommunityImageProvider`,
  `CommunityNetworkImage`, `CommunityImageLoader`, `CommunityImageScope`.
* Baru: cache gambar di disk per user (`<application support>/rendezvous_community/images/<user id>/`), LRU
  berdasarkan byte dan kedaluwarsa: `RendezvousCommunity.initialize(imageCache: CommunityImageCacheConfig(
  maxBytes: 200 MB, maxAge: 30 hari))`, `CommunityImageCacheConfig.disabled()`. Hanya aktif bila
  `offlineCache: true`. Dihapus bersama cache offline saat `signOut()`, `deleteMyAccount()`,
  `clearLocalCache()`, dan ganti user. Lampiran chat CS (`cs-documents`, `CommunitySupportChat`, riwayat tiket)
  tidak pernah disimpan ke disk; host bisa menandai layar lain dengan `CommunityImagePersistence`. Web tanpa
  cache disk. Tanpa dependensi baru (memakai `http`, `path_provider`, `crypto` yang sudah ada).
* Baru: tes performa scroll (`example/integration_test/perf_scroll_test.dart` +
  `example/test_driver/perf_driver.dart`, target `make perf-flutter`) dengan 200 post dan 500 pesan palsu,
  budget p90 build < 8 ms, p90 raster < 16 ms, tidak ada frame > 32 ms kecuali frame pertama; penjaga murah
  di `flutter test` untuk daftar lazy dan ukuran dekode gambar.
* Daftar feed memberi `ValueKey` per post, daftar notifikasi per item.
* Contoh app: tombol untuk kartu post kustom dan bentuk badge kustom (`example/lib/custom_feed_style.dart`).

## 1.3.0

* **Butuh backend dengan migrasi `0068`–`0086`** (keamanan konten, permintaan DM, banding,
  integritas pasar, pencarian, trending, edit/bookmark/reaksi/bagikan, preferensi notifikasi,
  konfigurasi klien, analitik, link preview, `moderation_status`) serta layanan `link-preview`
  dan `classifier`. Fitur baru dibaca lewat `get_client_config`; backend lama tanpa RPC ini
  membuat fitur baru tetap tampil tetapi gagal dengan pesan umum.
* Baru: konfigurasi klien & kill switch. `RendezvousCommunity.initialize(appVersion: ...,
  platform: CommunityPlatform..., onUpdateRequired: ...)` (`android`, `ios`, `web`, `windows`,
  `macos`, `linux`; default dari platform yang berjalan) memanggil `get_client_config` saat start, saat login,
  saat aplikasi kembali ke foreground, dan tiap 5 menit (sebelum login lewat anon key).
  `clientConfig`, `clientConfigChanges`, `refreshClientConfig()`. Saat `social_enabled = false`
  feed, composer, detail post, pencarian, trending, bookmark, room non-CS, dan daftar chat (kecuali
  room CS) menampilkan `CommunityUnavailableView`; host bisa menggantinya lewat
  `CommunityAvailabilityScope(builder: ...)` atau `CommunitySocialGate(unavailableBuilder: ...)`.
  Error `social_disabled` dari server langsung mematikan UI sosial. `CommunityUpdateListener`
  dan `onUpdateRequired` dipanggil sekali saat `update_required` menjadi `true`. Flag yang dibaca:
  `search`, `trending`, `bookmarks`, `post_edit`, `message_reactions`, `share_post_to_chat`,
  `notification_prefs`, `analytics` (`CommunityFlags`).
* Baru: pesan error terlokalisasi untuk `new_account_restricted` (gambar/tautan),
  `link_blocked`, `contact_blocked`, `content_blocked`, `slow_mode` (dengan hitung mundur dari
  `details`/`Retry-After`, `CommunityException.retryAfter`), `dm_not_allowed`,
  `dm_request_limit`, `social_disabled`, `edit_window_expired`, `poll_not_editable`,
  `image_blocked`, `classifier_unavailable`, `moderation_unavailable`, `appeal_exists`,
  `appeal_window_closed`, `appeal_not_allowed`, `query_too_short`/`query_too_long`,
  `share_not_allowed`. Pesan tidak menyebut kategori atau kata yang cocok.
  `appeal_reviewer_conflict` (khusus staf) tidak diberi pesan khusus.
* Baru: label "Menunggu tinjauan" untuk post, komentar, dan pesan milik sendiri yang
  `moderation_status = held`, label "Disembunyikan moderator" + "Ajukan banding" untuk yang
  `hidden`, serta label pada gambar yang diunggah dengan respons `"held": true`
  (`Attachment.held`, `UploadedObject.held`).
* Baru: permintaan pesan DM. Entri "Permintaan pesan" dengan jumlah di atas `CommunityChatList`
  (`MessageRequestsEntry`), `CommunityMessageRequests` / `openCommunityMessageRequests`,
  room permintaan dengan gambar diburamkan sampai diterima, aksi Terima / Tolak /
  Blokir & laporkan. Saat DM dibuka, `get_dm_request_state` menentukan status: pengirim melihat
  "Pesan Anda masih berupa permintaan (n/3)" lalu pemberitahuan batas, penerima bisa langsung
  "Terima" dari room (`DmRequestState`, `MessageRequestRepository.requestState`).
  Pengaturan "Siapa yang bisa mengirim pesan langsung" (`CommunityDmPolicySettings`) di
  Privasi & akun.
* Baru: banding. `showCommunityAppealDialog`, `CommunityAppeals` / `openCommunityAppeals`
  ("Banding saya": sanksi aktif, "Konten yang dimoderasi" dari `get_my_moderated_content`
  (post/komentar/pesan yang disembunyikan atau dihapus moderator 90 hari terakhir, dengan banding
  terakhirnya), dan status banding), notifikasi dan push tipe `appeal`
  (`NotificationType.appeal`).
* Baru: room saham menampilkan slow mode, hitung mundur di composer, dan pesan yang disematkan
  (`get_stock_room_state` + event realtime `room_state`).
* Baru: preferensi notifikasi per jenis (di aplikasi / push), jam tenang WIB
  (`CommunityNotificationSettings`, bagian "Notifikasi" di Privasi & akun), dan teks notifikasi
  gabungan ("Budi dan 4 lainnya menyukai konten Anda") dari `actor_count`/`actors`.
* Baru (`0086`): lima jenis notifikasi OLT di pengaturan notifikasi, dalam bagian "Notifikasi OLT"
  dengan keterangan singkat: `olt.trade` (Transaksi), `olt.funds` (Dana), `olt.market` (Pasar),
  `olt.info` (Info), `olt.promo` (Promo; push default mati). Semua jenis OLT kini punya sakelar
  di aplikasi dan push; sakelar di aplikasi hanya disembunyikan bila server mengirim
  `in_app: null`. Jenis yang belum dikenal ditampilkan dengan namanya. Konstanta baru
  `notificationFundsType`, `notificationMarketType`, `notificationOltInfoType`,
  `notificationPromoType`, `isOltNotificationType()`, dan `NotificationTypePreference.isOlt`.
* Baru: pesan OLT di kotak notifikasi (`type = announcement`, `payload.source = "olt"`) tampil
  dengan judul/isi sesuai bahasa aplikasi (`id`/`en`, cadangan `id` lalu `en`, atau teks biasa)
  dan ikon netral per jenis (ikon khusus untuk kategori `important` dan `promo`), tanpa avatar.
  `AppNotification.isOlt`, `oltKind`, `oltCategory`, `localizedTitle()`, `localizedBody()`.
  `AppNotification.title`/`body` kini `null` (bukan error) bila nilainya bukan teks.
* Baru: callback `onOltNotificationTap` di `RendezvousCommunity.initialize`/`create` dan
  `CommunityCallbacks` (`CommunityOltNotificationTapCallback`). Mengetuk pesan OLT di kotak
  notifikasi menandainya terbaca lalu memanggil callback dengan seluruh payload (`kind`,
  `category`, `message_id`, `cust_id`, `title`, `body`, `data`) plus `notification_id`.
  `openCommunityPush` meneruskan push OLT (`source: "olt"`) ke callback yang sama, menandai
  `notification_id` terbaca, dan mengembalikan `true`; tanpa callback tetap `false`.
* Baru: pencarian (`CommunitySearch` / `openCommunitySearch`: tab Semua/Post/Pengguna/Saham/
  Hashtag, debounce 300 ms, paginasi), feed hashtag (`CommunityHashtagFeed`), hashtag trending.
  `SocialText` kini membuat `#hashtag` dan tautan `http(s)` bisa diketuk; tautan dibuka setelah
  dialog konfirmasi yang menampilkan domain asli (`openCommunityLink`). Skema lain tidak bisa
  diketuk. Callback baru `onHashtagTap`.
* Baru: link preview (`LinkPreviewCard`, `LinkPreviewLoader`) untuk URL pertama di post,
  komentar, dan pesan: judul, deskripsi, situs, gambar dari bucket `link-previews`, domain akhir.
  `get_link_previews` dipanggil sekali per batch layar; status `pending` diulang paling banyak
  dua kali (3 dan 10 detik).
* Baru: `CommunityTrending` (saham, naik daun, populer, hashtag; jendela 24 jam/7 hari) dan
  `CommunityStockSentiment(stockCode:)` untuk halaman saham host.
* Baru: edit post dan komentar dalam jendela edit (menu "Edit" hanya 15 menit pertama, bukan post
  polling), label "(diedit)".
* Baru: bookmark (menu dan tombol di kartu post) dan `CommunityBookmarks`.
* Baru: reaksi pesan chat (tekan lama atau tombol hover → 6 emoji, chip jumlah, realtime
  `reaction`), tidak tersedia di chat CS.
* Baru: "Kirim ke chat" di menu post (`showSharePostToChat`) dan kartu post di pesan
  (`SharedPostCard`, termasuk "Post tidak tersedia").
* Baru: `showCommunityComposer(context, initialStock:, initialImage: CommunityComposerImage(...))`
  untuk membagikan chart dari OLT; gambar diunggah lewat media gateway.
* Baru: label Bot (`Post.isBot`) dan Resmi (`Post.authorIsOfficial`).
* Baru: analitik ringan (`CommunityAnalytics`): `feed_open`, `post_create`, `comment_create`,
  `message_send`, `stock_tap`, `search`, `share_chart`, dan `trackOrderTap()` untuk host.
  Batch maks 50, dikirim tiap 60 detik, saat 20 event terkumpul, atau saat aplikasi ke latar
  belakang; batch gagal dibuang; berhenti bila server menjawab `disabled`. Hanya properti
  whitelist yang dikirim, tidak pernah teks konten atau kata kunci.
* Baru: `isCommunityPush(data)` dan `isOltPush(data)`. Tanpa `onOltNotificationTap`,
  `openCommunityPush` mengembalikan `false` untuk push `olt.*` (`source: "olt"`, `cust_id`,
  `message_id`, plus `data` dari OLT seperti `screen`) supaya host yang menanganinya.
* **Butuh migrasi `0087`–`0090`** untuk fitur berikut (backend lama: banner kosong, laporan
  notifikasi/draf/kartu saham gagal tanpa mengganggu UI lain).
* Baru (`0089`): banner aplikasi dari `get_client_config` (`ClientConfig.banners`, `CommunityBanner`,
  level `info`/`warning`/`critical`). `CommunityBannerHost(maxVisible: 3, builder:)` untuk dipasang
  host; tampil otomatis di atas feed Terbaru/Mengikuti. Urut `priority` lalu `starts_at`, banner yang
  sudah berakhir disembunyikan, tautan dibuka lewat dialog konfirmasi `openCommunityLink`. Banner
  `dismissible` yang ditutup disimpan lokal per user (`BannerDismissals`, maks 100 id); yang tidak
  bisa ditutup selalu tampil.
* Baru (`0088`): laporan dibuka/diketuk notifikasi (`report_notification_event`). Membuka item kotak
  notifikasi atau push melapor `opened`; mengikuti tujuannya melapor `tapped` (`notification_id`
  lebih dulu, lalu `campaign_id`/`broadcast_id` dari data push). Kirim lalu lupakan, tiap event
  sekali per sumber, diantrekan di memori saat offline dan dikirim ulang saat koneksi kembali
  (`NotificationReporter`, `RendezvousCommunity.reportNotificationOpened/Tapped(data)` untuk host).
* Baru (`0087`): jenis notifikasi `followed_post` (buka postingan), `watchlist_digest` (buka feed saham
  teratas lewat `onStockTap`), `moderation` (buka "Banding saya", menampilkan bisa/tidaknya banding),
  dan `mention` dari room saham (buka room). Nilai enum baru `NotificationType.followedPost`,
  `watchlistDigest`, `moderation`, `notificationTypeFromKey()`, `openCommunityNotification()`.
  Pengaturan notifikasi menampilkan jenis baru; sakelar in-app nonaktif bila `in_app_locked`
  (`NotificationTypePreference.inAppLocked`).
* Baru (`0090`): draf postingan. Composer menyimpan otomatis (jeda 1,5 detik) ke perangkat lalu
  `save_post_draft` dengan `p_base_updated_at`; `draft_conflict` → versi yang lebih baru dipakai dan
  pengguna diberi tahu; `draft_limit` / offline → draf tetap di perangkat. Terbit memakai
  `client_draft_id` sebagai `client_id` sehingga server menghapus drafnya. `CommunityPostDrafts` /
  `openCommunityPostDrafts` untuk melanjutkan atau menghapus draf, `showCommunityComposer(draft:)`,
  `CommunityDrafts`, `PostDraft`.
* Baru (`0090`): kartu saham di chat. Tombol "Kirim kartu saham" di composer (bukan chat CS), maksimal
  3 kode; lampiran `{"type": "stock", "code"}` tampil sebagai kartu (`ChatMessage.stockCodes`,
  `StockCards`, builder `CommunityChatBuilders.stockCard`). Nama/harga dari host lewat callback baru
  `stockInfo` (`CommunityStockInfo`); ketuk → `onStockTap`. `ChatExtrasRepository.sendStockCards`,
  `ChatRoomCubit.sendStockCards`.
* `CommunityFeatureDependencies` bertambah `notificationReporter`, `bannerDismissals`, `drafts`.
* Baru: cache offline (bawaan aktif, `initialize(offlineCache: false)` untuk mematikan). Database
  lokal per user komunitas (drift + SQLite di Android/iOS/Windows/macOS/Linux, memori di web)
  menyimpan halaman pertama daftar room (tanpa room CS), pesan terakhir per room (bawaan 200,
  `initialize(offlineMessageLimit:)`, dipangkas otomatis), dan halaman pertama feed
  Terbaru/Mengikuti/saham (20 saham terakhir). Saat dibuka, data tersimpan langsung tampil lalu
  diganti data server di latar belakang; server tetap sumber kebenaran (edit, hapus, reaksi, dan
  `moderation_status` di baris ikut tersimpan, pesan yang tidak lagi dikembalikan server dalam
  rentang halaman yang sama dihapus dari cache). Saat koneksi kembali, layar yang masih
  menampilkan data tersimpan memuat ulang sendiri. Skema bernomor versi (`CommunityDatabase.version`).
* Baru: outbox pesan teks. Pesan yang dikirim saat offline atau gagal karena jaringan disimpan
  bersama `client_id`, tampil "Menunggu dikirim" (`MessageStatus.pending`), lalu dikirim ulang
  dengan backoff (2 detik, maks 1 menit) dan segera saat koneksi kembali, aplikasi kembali ke
  foreground, atau realtime tersambung lagi. Urutan per room dijaga; server menolak duplikat lewat
  `client_id`. Error permanen (`content_blocked`, `dm_request_limit`, `consent_required`,
  `slow_mode` setelah 3 percobaan di latar belakang, dll.) menandai pesan gagal beserta alasannya
  (`ChatMessage.sendError`) dengan tombol "Coba lagi" dan "Hapus" (`CommunityMessageDetails.onDiscard`,
  `ChatRoomCubit.discard`, `MessageDeliveryNotice`). Lampiran gambar/PDF tidak masuk antrean:
  saat offline ditolak dengan pesan jelas (kode `attachment_offline`).
* Baru: indikator offline. `CommunityConnectivity` menilai koneksi dari hasil request ke server dan
  status realtime (tanpa plugin konektivitas); saat offline memeriksa ulang lewat
  `get_client_config` (5 detik, naik sampai 1 menit). `CommunityOfflineBanner` tampil di atas
  daftar chat dan feed; room chat memakai builder `connectionBanner` dengan
  `CommunityConnectionDetails.offline`.
* Privasi: database lokal dihapus saat `signOut()`, `deleteMyAccount()`, `clearLocalCache()`, saat
  sesi komunitas berganti user, dan saat aplikasi dibuka offline oleh user OLT lain. Token tidak
  pernah disimpan; pemilik database dicocokkan lewat hash SHA-256 dari `iss`+`sub` token OLT.
  Chat CS tidak di-cache.
* API baru: `RendezvousCommunity.instance.clearLocalCache()`, `connectivity`, `offlineCacheEnabled`,
  `chatCache`, `feedCache`, `outbox`, `CommunityOfflineScope` + `CommunityOfflineDependencies`,
  `ChatCacheRepository`, `FeedCacheRepository`, `MessageOutbox`, `OutboxMessage`. Parameter cubit
  baru (opsional): `ChatRoomCubit(cache:, outbox:, connectivity:)`, `ChatListCubit(cache:,
  connectivity:)`, `FeedCubit(cache:, connectivity:)`; state baru `stale`.
* Dependensi baru: `drift` (MIT), `sqlite3` (MIT; SQLite dibundel lewat build hooks, tanpa
  `sqlite3_flutter_libs`), `path_provider` (BSD), `path` (BSD), `crypto` (BSD); dev: `drift_dev` (MIT).
* Logger baru `RendezvousCommunity.Config`, `RendezvousCommunity.Analytics`, dan
  `RendezvousCommunity.Offline`.
* Kompatibilitas: `CommunityDependencies` tidak berubah; fitur baru lewat antarmuka baru
  `CommunityFeatureDependencies` dan `CommunityFeatureScope` (bawaannya
  `RendezvousCommunity.instance`; tanpa keduanya fitur baru tersembunyi). Parameter baru semua
  opsional. **Perlu perhatian:** subclass baru pada sealed class `RoomSignal` (`RoomReaction`,
  `RoomStateSignal`), `ChatRoomEvent` (`ReactionChanged`, `StockRoomStateChanged`), dan
  `SocialTextSegment` (`HashtagSegment`, `LinkSegment`), serta nilai enum
  `NotificationType.appeal`, `followedPost`, `watchlistDigest`, `moderation`, dan `MessageStatus.pending`:
  `switch` lengkap di kode host perlu
  cabang baru.
  `parseSocialText` hanya menghasilkan segmen baru bila `hashtags: true` / `links: true`.
* Perbaikan: lampiran `{"type": "post"}` dari pesan bagikan post tidak lagi membuat
  `get_messages` gagal di-parse (versi ≤ 1.2.0 gagal membaca room yang berisi post yang dibagikan).

## 1.2.0

* **Wajib backend baru: unggahan lewat media gateway.** Gambar post, gambar chat,
  PDF chat CS, dan foto profil kini dikirim ke
  `POST {supabaseUrl}/media/v1/object/{bucket}/{path}` (header `apikey`,
  `Authorization: Bearer <JWT sosial>`, `Content-Type`), bukan langsung ke Storage.
  Backend harus menjalankan layanan `media` (route Kong `/media/v1`, migrasi
  `0063_media_uploads`). Backend lama tanpa `/media/v1` membuat unggahan gagal
  dengan pesan "Unggahan file sedang tidak tersedia" (kode `media_unavailable`).
  Paket memakai `path` dan `mime` dari respons, karena server bisa mengganti
  ekstensi sesuai isi file; `width`/`height` ikut tersimpan di lampiran gambar.
  Hanya foto profil yang mengirim `x-upsert: true`. GIF tetap boleh untuk gambar
  post dan chat; foto profil GIF ditolak sebelum diunggah. Sesi kedaluwarsa (401)
  diperbarui sekali lalu unggahan diulang.
* Baru: pesan error terlokalisasi (id/en) untuk kode media gateway:
  `unsupported_type`, `file_too_large`, `empty_file`, `invalid_image`,
  `image_too_large`, `invalid_pdf`, `pdf_encrypted`, `pdf_active_content`,
  `upload_forbidden`, `too_many_uploads`, `busy`, `storage_unavailable`,
  `storage_error`. Kode lokal composer untuk gambar di atas 5 MB berganti dari
  `image_too_large` menjadi `file_too_large` (sama dengan server); `image_too_large`
  kini berarti resolusi gambar terlalu besar.
* Baru: Syarat & Ketentuan, Pedoman Komunitas, dan Kebijakan Privasi.
  `RendezvousCommunity.instance.legalDocuments()`, `pendingLegalDocuments()`, dan
  `acceptLegalDocuments(ids)` (RPC `get_legal_documents`, `accept_legal_document`).
  Daftar dokumen dicache per sesi di `CommunityConsent`: dimuat sekali saat login,
  dimuat ulang setelah setuju, tidak dipanggil ulang tiap rebuild.
* Baru: `showCommunityConsent(context)` membuka alur persetujuan (dialog di layar
  lebar, layar penuh di ponsel) berisi dokumen wajib yang belum disetujui, pembaca
  teks lengkap (judul, versi, tanggal berlaku, "Yang berubah"), satu kotak centang
  "Saya telah membaca dan menyetujui …", dan tombol "Setuju" untuk semuanya.
  Hasilnya `true` bila semua disetujui. Komponen lepas: `CommunityConsentView`,
  `CommunityLegalDocumentReader`, `showCommunityLegalDocument`.
* Baru: gerbang persetujuan otomatis. Bila membuat post, komentar, atau mengirim
  pesan chat ditolak server dengan `consent_required`, alur persetujuan terbuka;
  setelah setuju, aksi yang sama diulang satu kali (draf dan `client_id` sama).
  Bila ditunda, draf tetap ada (teks composer tidak dihapus, pesan chat menjadi
  "Gagal terkirim" dan bisa dikirim ulang) dan muncul pesan singkat. Chat CS tidak
  pernah memicu alur ini. Kirim ulang otomatis setelah koneksi pulih tidak membuka
  dialog. Gerbang yang sama bisa dipakai host lewat `communityConsentGate(context)`.
* Baru: `CommunityConsentBanner` tampil di atas feed (stream, saham, profil) bila
  ada dokumen wajib yang belum disetujui, misalnya "Pedoman Komunitas diperbarui —
  tinjau dan setujui." Bisa ditutup untuk sesi ini; muncul lagi bila ada dokumen
  wajib baru.
* Baru: privasi & akun (UU PDP). `exportMyData()` mengembalikan
  `CommunityDataExport` (JSON UTF-8 rapi + nama file
  `data-komunitas-<username>-<yyyyMMdd>.json`); dibatasi server 3 kali sehari.
  `deleteMyAccount()` menghapus akun komunitas lalu membersihkan sesi komunitas di
  perangkat tanpa login ulang otomatis; login berikutnya membuat profil komunitas
  baru yang kosong. Akun trading tidak tersentuh.
* Baru: `CommunityAccountSettings` / `openCommunityAccountSettings(context,
  onAccountDeleted: ...)` ("Privasi & akun"): tautan dokumen hukum, "Unduh data saya"
  (desktop: dialog simpan `file_selector`; Android/iOS/web: bagikan file, web
  mengunduh bila Web Share API tidak tersedia), dan "Hapus akun komunitas" dengan
  penjelasan dampak, konfirmasi mengetik `HAPUS` (`DELETE` di bahasa Inggris), dan
  indikator proses. Cara menyimpan file bisa diganti lewat `exportSaver`.
* Dependensi baru: `share_plus` (BSD-3-Clause). Dibutuhkan karena `file_selector`
  tidak punya dialog simpan di Android, iOS, dan web. Dependensi transitif barunya
  (`share_plus_platform_interface`, `path_provider*`, `jni_flutter`, `objective_c`,
  `hooks`, `code_assets`, `record_use`, `pub_semver`, `yaml`) berlisensi BSD/MIT;
  `tool/license_audit.dart` lulus.
* Logger baru `RendezvousCommunity.Account`. Isi ekspor dan token tidak pernah
  masuk log.
* Tidak ada perubahan yang memecah API Dart: `CommunityDependencies` tidak berubah.
  Fitur dokumen hukum dan akun lewat antarmuka baru `CommunityAccountDependencies`
  dan `CommunityAccountScope` (bawaannya `RendezvousCommunity.instance`).
  `ChatRoomCubit` menerima parameter opsional `consent`.
* Membutuhkan migrasi `0062_legal_documents` dan `0063_media_uploads` serta
  layanan `media`.

## 1.1.0

* Baru: push notification. `RendezvousCommunity.instance.registerPushToken(token,
  platform: CommunityPushPlatform.android, locale: ..., appVersion: ...)` mendaftarkan
  token FCM milik app ke akun yang sedang login; token otomatis pindah ke akun baru
  bila akun berganti, dan dilepas saat `signOut()`. `unregisterPushToken()` mematikan
  push untuk perangkat ini. `openCommunityPush(context, message.data)` membuka
  postingan, chat, chat CS, profil, atau tautan pengumuman dari push yang diketuk dan
  menandai notifikasinya terbaca; nilainya `false` untuk push yang bukan milik paket.
  Paket tidak bergantung pada Firebase (panduan: `docs/push/README.md`).
* Baru: postingan tersemat dan pengumuman resmi tampil di atas stream umum dan stream
  saham (`FeedRepository.getPinned`, `PinnedPost`), tanpa diulang di daftar biasa.
* Baru: badge **Resmi** untuk akun resmi perusahaan sekuritas di semua nama pengguna
  (`OfficialAccounts`, `CommunityOfficialScope`).
* Baru: notifikasi jenis `announcement` (judul dan isi dari kampanye; diketuk membuka
  postingan atau tautan `https`).
* Logger baru `RendezvousCommunity.Push`.
* Tidak ada perubahan yang memecah API: `CommunityDependencies` tidak berubah.

## 1.0.0

* Breaking: package `olt_social` berganti nama menjadi `rendezvous_community`.
  Import `package:olt_social/olt_social.dart` menjadi
  `package:rendezvous_community/rendezvous_community.dart`.
* Breaking: prefix `Olt` dihapus dari API publik. `OltSocial` menjadi
  `RendezvousCommunity`, `OltSocialException`/`OltSocialErrorKind` menjadi
  `CommunityException`/`CommunityErrorKind`, `OltSocialLocalizations` menjadi
  `CommunityLocalizations`, `context.oltL10n` menjadi `context.communityL10n`,
  dan widget `Olt*` menjadi `Community*`. Parameter `oltTokenProvider` menjadi
  `tokenProvider`. Tabel lengkap ada di
  `docs/rendezvous-community/migration-1.0.md`.
* Baru: logger terpusat berbasis `package:logging` (BSD-3) dengan logger per
  komponen `RendezvousCommunity.Auth/Chat/Feed/Realtime/Support`.
  Host memasang handler lewat `RendezvousCommunity.initialize(logHandler: ...,
  logLevel: ...)`. Field log terstruktur (`CommunityLogEvent`) dan data
  sensitif (token, JWT, password, OTP, isi pesan/post, nomor rekening, NIK)
  disamarkan otomatis.
* Pesan exception internal, `assert`, dan deskripsi tes kini berbahasa Inggris.
  Teks yang dilihat user tidak berubah.
* Tidak ada perubahan API backend, skema database, nama topik Realtime, atau
  data di perangkat. Library tidak menyimpan apa pun di perangkat, jadi update
  tidak membuat user logout.

## 0.3.0

* Prinsip integrasi: server hanya memvalidasi token login ke OLT. Order, daftar
  dan nama saham, harga, serta data nasabah tetap milik app OLT.
* Baru: `OltSocial.initialize(stockSearch: ...)` (`OltStockSearch`,
  `StockSuggestion`) untuk saran `$KODE` dari daftar saham milik app, dan
  `OltStockFeed(stockName: ...)` untuk nama saham di header.
* Breaking: `Stock` kini hanya `code`, `watcherCount`, dan `watching`
  (`StockType`, `name`, `sector` dihapus). `StockRepository.searchStocks` dan
  `isWatching` dihapus; `getStock` memakai RPC `get_stock`.
* Breaking: chat CS tanpa kartu order/transaksi dana. `SupportCard`,
  `SupportCardKind`, `SupportOrder`, parameter `card` di `OltSupportChat`,
  `OltSupportPage`, dan `openOltSupport`, `SupportRepository.sendCard` dan
  `recentOrders`, `OltSupportMessageActions.onOpenCard`, serta
  `MessageKind.card` dihapus. Pesan kartu lama tampil sebagai teks.
* Breaking: `OltSupportStaff` dihapus karena web CS kini hanya versi React.
* Membutuhkan migrasi `0037_client_owned_business_data`.

## 0.2.0

* Builder untuk kustomisasi UI chat: `OltChatBuilders` (pesan, composer, header
  room, mengetik, banner koneksi, pemisah hari, tile room, header daftar chat,
  loading, kosong, error) lewat `OltChatBuildersScope` atau parameter `builders`
  di `OltChatList`/`OltChatRoom`. Setiap builder menerima data siap tampil,
  handler yang sudah tersambung ke logika package, dan tampilan bawaan.
* Komponen siap pakai ikut diekspor: `OltComposerField`, `AttachmentGrid`,
  `ReceiptIcon`, `OltRoomAvatar`.
* Lazy load: pesan lama dan daftar room tetap dimuat walau halaman pertama
  belum memenuhi layar. Daftar room kini dimuat per halaman (30, cursor).
* Setelah tersambung ulang, pesan yang terlewat disusulkan per 100 sampai habis;
  bila lebih dari 500, room dimuat ulang dari pesan terbaru.
* Breaking: `ChatRepository.getRooms({cursor, limit})` mengembalikan
  `Paged<ChatRoom>`, ada `getRoom(roomId)` baru, dan `getMessagesAfter`
  mengembalikan `Paged<ChatMessage>`. Membutuhkan migrasi `0036_chat_room_paging`.

## 0.1.0

* Rilis awal: feed & feed saham, compose dengan autocomplete `$KODE`/`@user`,
  thread komentar berantai, reaksi, follow/block/watch, chat realtime
  (DM, grup, room saham) dengan typing indicator & read receipt,
  notifikasi, laporan konten, lokalisasi Indonesia & Inggris.
