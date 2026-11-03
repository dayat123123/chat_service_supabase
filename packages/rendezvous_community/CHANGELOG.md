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
