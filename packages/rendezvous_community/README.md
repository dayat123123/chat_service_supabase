# rendezvous_community

> Sebelumnya bernama **`olt_social`** (sampai versi 0.3.0). Panduan pindah ke 1.0.0 ada di [docs/rendezvous-community/migration-1.0.md](../../docs/rendezvous-community/migration-1.0.md).

Package Flutter berisi fitur sosial & chat untuk Rendezvous OLT (Windows desktop & Android).
Isinya feed saham, komentar berantai, reaksi, mention, follow, watch saham, chat realtime, notifikasi, dan moderasi.

Backend yang dipakai adalah Supabase self-hosted dan auth-bridge. Keduanya ada di repo ini, lihat [README root](../../README.md).
Server sosial tidak memanggil sistem OLT: OLT menerbitkan token sosial bertanda tangan saat login, dan server memverifikasinya secara lokal. Data bisnis seperti order, daftar dan nama saham, harga, dan data nasabah tetap milik app OLT; package hanya menerima kode saham sebagai label.
Langkah memasang package ke app OLT ada di [docs/INTEGRATION.md](../../docs/INTEGRATION.md).

## Pemakaian singkat

```dart
await RendezvousCommunity.initialize(
  supabaseUrl: 'https://social-api.domain.com',
  anonKey: '<ANON_KEY>',
  tokenProvider: () => hostAuth.freshSocialToken(),  // token sosial (JWT) dari OLT yang masih berlaku
  onStockTap: (context, code) => openStockPage(context, code),
  stockSearch: (query) => stockDirectory.search(query), // saran $KODE dari daftar saham milik app
  appVersion: '2.4.1',                                  // untuk get_client_config & analitik
  onUpdateRequired: (config) => oltRouter.showForceUpdate(),
);

// Widget siap pakai (tanpa Scaffold, tempel di halaman OLT):
const CommunityStreamFeed();                    // stream umum (Terbaru / Mengikuti)
const CommunityStockFeed(stockCode: 'BBCA', stockName: 'Bank Central Asia Tbk');   // feed di halaman saham
const CommunityPostDetail(postId: '...');       // post + thread komentar
const CommunityComposePost(initialStock: 'BBCA');
const CommunityChatList();                      // multi-panel di layar lebar
const CommunityChatRoom(roomId: '...');
const CommunityChatBadge(child: Icon(Icons.chat_bubble_outline));   // badge chat belum dibaca di tab
const CommunityNotificationList();
const CommunityNotificationBadge(child: Icon(Icons.notifications));
const CommunityUserProfile(userId: '...');
const CommunityAccountSettings();               // "Privasi & akun": dokumen hukum, unduh data, hapus akun
const CommunityConsentBanner();                 // banner dokumen wajib yang belum disetujui (sudah ada di feed)
const CommunitySearch();                        // pencarian (1.3.0), atau openCommunitySearch(context)
const CommunityTrending();                      // saham, naik daun, populer, hashtag
const CommunityStockSentiment(stockCode: 'BBCA'); // bar bullish/bearish 24 jam/7 hari di halaman saham OLT
const CommunityBookmarks();                     // post yang disimpan
const CommunityHashtagFeed(tag: 'dividen');
const CommunityMessageRequests();               // permintaan pesan DM
const CommunityAppeals();                       // "Banding saya"
const CommunityNotificationSettings();          // preferensi notifikasi & jam tenang
```

> **Backend wajib menjalankan layanan `media`** (mulai 1.2.0). Semua unggahan nasabah lewat `POST {supabaseUrl}/media/v1/object/{bucket}/{path}`. Backend lama tanpa route `/media/v1` membuat unggahan gambar, PDF, dan foto profil gagal ("Unggahan file sedang tidak tersedia"). Detail di [Unggahan lewat media gateway](#unggahan-lewat-media-gateway).

Tambahkan delegate lokalisasi di `MaterialApp`. Bahasa default Indonesia, tersedia juga Inggris:

```dart
localizationsDelegates: [...CommunityLocalizations.localizationsDelegates],
supportedLocales: CommunityLocalizations.supportedLocales,
```

## Fitur UI

| Fitur | Perilaku |
|---|---|
| Layout responsif | Kolom konten maksimal 720 px. `CommunityChatList` tampil multi-panel di lebar ≥ 840 px |
| Keyboard desktop | Di composer post, komentar, dan chat: Enter mengirim, Shift+Enter membuat baris baru. Autocomplete bisa dipilih dengan ↑/↓ dan Enter/Tab |
| Hover | Sorotan komentar. Aksi balas/hapus pesan muncul saat kursor di atas gelembung |
| `$KODE` & `@user` | Bisa diketuk lewat `onStockTap` / `onUserTap`. Bila callback tidak diisi, halaman bawaan yang dibuka |
| Data saham | Server tidak menyimpan daftar saham. Kode apa pun yang berformat `$KODE` (huruf di depan, 2–12 huruf/angka) dipakai sebagai label untuk feed, pantau, dan room saham. Saran saat mengetik `$` datang dari `stockSearch` milik app (tanpa callback: tidak ada saran). Nama saham di header `CommunityStockFeed` datang dari `stockName`; server hanya memberi jumlah pemantau |
| Thread komentar | Garis indentasi per level. Mulai level 4, indentasi berhenti dan muncul "Lanjutkan thread". Tersedia "Lihat N balasan lainnya" dan collapse/expand per cabang |
| Optimistic update | Like post/komentar, follow, watch, dan kirim pesan. Bila server gagal, perubahan dibatalkan dan SnackBar ditampilkan |
| Chat | Centang ala WhatsApp: jam (mengirim), ✓ (sampai server), ✓✓ abu-abu (sudah diterima perangkat penerima yang online), ✓✓ biru (sudah dibaca). Di grup, centang naik setelah **semua** anggota menerima/membaca; room saham hanya ✓. Badge belum dibaca per room, balas pesan, reconnect otomatis dengan pengisian celah pesan dan tanda terima |
| Lazy load chat | Pesan dimuat 30 per halaman memakai cursor (bukan offset). Halaman lebih lama diambil saat scroll mendekati pesan tertua, dan otomatis bila halaman pertama belum memenuhi layar. Daftar room juga dimuat 30 per halaman dengan aturan yang sama. Setelah koneksi pulih, pesan yang terlewat disusulkan per 100 sampai habis; bila lebih dari 500, room dimuat ulang dari pesan terbaru dan pesan lama tetap bisa dimuat dengan scroll |
| Badge tab chat | `CommunityChatBadge` menampilkan jumlah **chat** (DM & grup yang tidak dibisukan) yang punya pesan belum dibaca, seperti tab Chat WhatsApp; `99+` bila lebih. Room saham tidak dihitung. Diperbarui saat pesan masuk dan saat room dibuka |
| Mengetik & online | "mengetik…" (DM) atau "Budi sedang mengetik…" (grup) tampil di daftar chat dan di room. Titik hijau dan teks "Online" untuk lawan bicara DM |
| Lampiran | Chat global (DM, grup, room saham) hanya gambar (JPEG, PNG, WebP, GIF). Chat CS (`CommunitySupportChat`) juga menerima PDF maksimal 10 MB lewat `MessageComposer(allowDocuments: true)`. PDF tampil sebagai kartu nama + ukuran dan dibuka di aplikasi PDF perangkat lewat signed URL 5 menit. Semua unggahan lewat media gateway (lihat di bawah) |
| Polling | Tombol polling di composer: 2–4 pilihan (maks 40 karakter, tidak boleh sama), durasi 1 jam–7 hari. Satu suara per user dan tidak bisa diubah; pembuat tidak ikut memilih. Hasil (persentase, pilihan Anda, pilihan teratas) tampil setelah memilih, saat polling selesai, atau bagi pembuat |
| State | Skeleton saat memuat, tampilan kosong, error dengan tombol coba lagi, pull-to-refresh, infinite scroll, banner "N post baru" |
| Disclaimer | *"Konten ini opini pengguna, bukan rekomendasi investasi."* di composer dan detail post |
| Tautan & hashtag | `#hashtag` membuka `CommunityHashtagFeed` (atau `onHashtagTap`). Tautan `http(s)` dibuka di browser setelah dialog yang menampilkan domain asli; skema lain (`javascript:`, `tel:`, `www.` tanpa skema) tetap teks biasa |
| Link preview | Kartu di bawah post, komentar, dan pesan untuk URL pertama: judul, deskripsi, situs, gambar, domain akhir setelah redirect. Satu `get_link_previews` per batch layar, `pending` diulang paling banyak dua kali |
| Edit | Menu "Edit" di post/komentar sendiri hanya selama `edit_minutes` (15 menit, waktu server); post polling tidak bisa diedit. Label "(diedit)" |
| Bookmark | Ikon simpan di kartu post dan menu; `CommunityBookmarks` menampilkan daftar, post yang dibatalkan langsung hilang dari daftar |
| Reaksi pesan | Tekan lama (atau tombol saat hover) → 👍 ❤️ 😂 😮 😢 🔥; chip jumlah di bawah gelembung, sorot bila milik sendiri, realtime. Tidak ada di chat CS |
| Bagikan post | "Kirim ke chat" di menu post → pilih room → kartu post di pesan ("Post tidak tersedia" bila dihapus/ditahan/blokir) |
| Label | "Bot" untuk post dari API bot integrasi, "Resmi" untuk akun resmi |
| Konten ditahan | Post/komentar/pesan sendiri berstatus `held`: "Menunggu tinjauan"; `hidden`: "Disembunyikan moderator" + "Ajukan banding". Gambar yang diunggah dengan `"held": true` juga berlabel |
| Room saham | Banner slow mode ("1 pesan tiap 10 detik"), hitung mundur di tombol kirim, dan pesan yang disematkan (realtime `room_state`) |

## Dokumen hukum & persetujuan

Server menolak post, komentar, dan pesan chat (kecuali chat CS) dengan kode `consent_required` bila ada dokumen wajib (Syarat & Ketentuan, Pedoman Komunitas) versi terbaru yang belum disetujui. Paket menanganinya sendiri:

| Bagian | Perilaku |
|---|---|
| Gerbang otomatis | Post, komentar, atau pesan chat yang ditolak `consent_required` membuka alur persetujuan. Setelah "Setuju", aksi yang sama diulang **satu kali** dengan draf yang sama. Bila ditunda ("Nanti"), draf tetap ada (teks composer tidak dihapus, pesan chat menjadi "Gagal terkirim" dan bisa diketuk untuk kirim ulang) dan SnackBar singkat muncul. Chat CS tidak pernah memicu alur ini |
| Alur persetujuan | Dialog di layar lebar, layar penuh di ponsel. Daftar dokumen wajib yang belum disetujui; tiap dokumen bisa dibaca lengkap (judul, versi, tanggal berlaku, kotak "Yang berubah", teks dengan baris baru apa adanya). Satu kotak centang "Saya telah membaca dan menyetujui …" lalu "Setuju" menyetujui semuanya |
| Banner | `CommunityConsentBanner` tampil di atas feed, misalnya *"Pedoman Komunitas diperbarui — tinjau dan setujui."* "Tinjau" membuka alur persetujuan; ikon tutup menyembunyikannya sampai ada dokumen wajib baru |
| Cache | Daftar dokumen (`get_legal_documents`) dimuat sekali per sesi saat login, dimuat ulang setelah menyetujui. Rebuild widget tidak memanggil server |

```dart
final community = RendezvousCommunity.instance;
final all = await community.legalDocuments();                 // versi berlaku terbaru per jenis
final pending = await community.pendingLegalDocuments();     // wajib & belum disetujui
await community.acceptLegalDocuments([for (final d in pending) d.id]);

final accepted = await showCommunityConsent(context);         // true bila semua sudah disetujui
await showCommunityLegalDocument(context, all.first);         // pembaca dokumen
CommunityLegalDocumentReader(document: all.first);            // pembaca sebagai widget
```

`communityConsentGate(context)` mengembalikan `ConsentGate` yang sama dengan yang dipakai paket, untuk aksi host yang juga bisa ditolak `consent_required`: `await gate.run(() => aksi())`.

## Privasi & akun

`CommunityAccountSettings` (tanpa Scaffold) atau `openCommunityAccountSettings(context)` (halaman dengan AppBar "Privasi & akun") berisi:

- **Dokumen hukum:** tautan ke setiap dokumen yang berlaku, plus banner bila ada yang belum disetujui.
- **Unduh data saya:** memanggil `export_my_data` dan menyimpan JSON rapi bernama `data-komunitas-<username>-<yyyyMMdd>.json`. Windows/macOS/Linux memakai dialog simpan; Android/iOS/web membagikan file (web mengunduh bila Web Share API tidak ada). Server membatasi 3 kali sehari; batas ini ditampilkan sebagai pesan yang jelas.
- **Hapus akun komunitas:** menjelaskan dampaknya (post, komentar, dan chat hilang dari tampilan; salinan diarsipkan untuk regulator; pengikut/blokir/bisukan dihapus; riwayat CS tetap; akun trading tidak tersentuh; profil baru yang kosong dibuat saat masuk lagi), meminta mengetik `HAPUS`, menampilkan proses, lalu memanggil `onAccountDeleted`.

```dart
await openCommunityAccountSettings(
  context,
  onAccountDeleted: () => oltRouter.goHome(),    // halaman pengaturan sudah ditutup paket
);

CommunityAccountSettings(
  onAccountDeleted: () => Navigator.of(context).pop(),   // tanpa callback: Navigator.maybePop
  exportSaver: (context, export) async => oltFiles.save(export.fileName, export.bytes),
);

final export = await RendezvousCommunity.instance.exportMyData();   // CommunityDataExport: bytes + fileName
await RendezvousCommunity.instance.deleteMyAccount();
```

`deleteMyAccount()` membersihkan sesi komunitas di perangkat (realtime, pelacak centang, cache dokumen, cache offline dan outbox) tanpa login ulang otomatis. Panggilan API komunitas berikutnya menukar token OLT lagi dan server membuat profil komunitas baru yang kosong. Token push dilepas server; token yang terdaftar dipasang lagi otomatis di sesi berikutnya. Karena itu, arahkan pengguna keluar dari layar komunitas di `onAccountDeleted`.

## Unggahan lewat media gateway

Mulai 1.2.0 semua unggahan nasabah lewat layanan `media`, bukan langsung ke Storage:

```
POST {supabaseUrl}/media/v1/object/{bucket}/{path}
apikey: <anon key>
Authorization: Bearer <JWT sosial>
Content-Type: <tebakan dari nama file>
x-upsert: true            # hanya foto profil
```

| Unggahan | Bucket | Path yang diminta | Jenis |
|---|---|---|---|
| Gambar post | `attachments` | `posts/<user>/<uuid>.<ext>` | JPEG, PNG, WebP, GIF, maks 5 MB |
| Gambar chat (termasuk chat CS) | `attachments` | `rooms/<room>/<user>/<uuid>.<ext>` | JPEG, PNG, WebP, GIF, maks 5 MB |
| PDF chat CS | `cs-documents` | `rooms/<room>/<user>/<uuid>.pdf` | PDF, maks 10 MB |
| Foto profil | `avatars` | `<user>/avatar-<ms>.<ext>` | JPEG, PNG, WebP (GIF ditolak), maks 2 MB |

Server membaca jenis file dari isinya, membuang metadata (EXIF/GPS dan sejenisnya), dan bisa mengganti ekstensi. Paket memakai `path` dan `mime` dari respons, juga `width`/`height` untuk gambar. Respons 401 memicu refresh sesi lalu satu kali percobaan ulang. Error dipetakan ke `CommunityException` (`kind` + `code` dari server) dan pesan terlokalisasi lewat `context.communityL10n.errorMessage(e)`:

| Kode | Pesan (id) |
|---|---|
| `unsupported_type` | Jenis file tidak didukung … |
| `file_too_large` | File terlalu besar. Batasnya 5 MB untuk gambar, 2 MB untuk foto profil, dan 10 MB untuk PDF. |
| `invalid_image` / `image_too_large` | Gambar rusak … / Resolusi gambar terlalu besar … |
| `invalid_pdf` / `pdf_encrypted` / `pdf_active_content` | PDF rusak … / PDF yang dikunci kata sandi … / PDF berisi skrip … |
| `upload_forbidden` | Anda tidak diizinkan mengunggah file ke sini. |
| `too_many_uploads` | Batas unggahan hari ini sudah tercapai … |
| `busy` | Server unggahan sedang sibuk … |
| `storage_unavailable`, `storage_error`, 404 tanpa kode (backend lama) | Unggahan file sedang tidak tersedia … |
| `image_blocked` | Gambar ini tidak bisa diunggah karena melanggar Pedoman Komunitas. |
| `classifier_unavailable`, `moderation_unavailable` | Pemeriksaan gambar sedang tidak tersedia … (`retryAfter` dari `Retry-After`) |

Gambar yang perlu ditinjau tetap tersimpan dan respons memuat `"held": true`; paket menandainya `Attachment.held` dan menampilkan label "Menunggu tinjauan" di composer dan gelembung chat pengunggah.

Kong harus mengizinkan header `x-upsert` di CORS untuk app web.

## Konfigurasi klien & kill switch (1.3.0)

`get_client_config` dipanggil saat `initialize`, saat login/ganti akun, saat aplikasi kembali ke foreground, dan tiap 5 menit. Sebelum login dipanggil dengan anon key (hanya flag 100%). `platform` (`CommunityPlatform`: `android`, `ios`, `web`, `windows`, `macos`, `linux`) default dari platform yang berjalan, dan ikut dikirim ke `track_events`.

```dart
final config = RendezvousCommunity.instance.clientConfig;          // ClientConfig
RendezvousCommunity.instance.clientConfigChanges.listen((c) { ... });
await RendezvousCommunity.instance.refreshClientConfig();
config.feature(CommunityFlags.search);                               // social_enabled && flag
```

| Bagian | Perilaku |
|---|---|
| Kill switch | `social_enabled = false` atau error `social_disabled` → feed, composer, detail post, pencarian, trending, bookmark, room non-CS menampilkan `CommunityUnavailableView`; daftar chat hanya menampilkan room CS. Chat CS tetap jalan |
| Placeholder kustom | `CommunityAvailabilityScope(builder: (context, reason, fallback) => ...)` di `MaterialApp.builder`, atau `CommunitySocialGate(unavailableBuilder: ...)` per widget. `reason`: `socialDisabled` / `featureDisabled` |
| Versi minimum | `update_required` → `initialize(onUpdateRequired:)` dan `CommunityUpdateListener(onUpdateRequired: (context, config) => ...)` dipanggil sekali per transisi |
| Flag yang dibaca | `search` (pencarian, hashtag), `trending` (trending, sentimen), `bookmarks`, `post_edit`, `message_reactions`, `share_post_to_chat`, `notification_prefs`, `analytics`. Sebelum konfigurasi termuat semua flag dianggap aktif; setelah termuat, flag yang tidak dikenal server dianggap mati |
| Nilai lain | `edit_minutes`, `message_reactions`, `search_min_length`, `notification_types`, selisih jam server (`clockSkew`) untuk jendela edit |

Detail lengkap fitur 1.3.0: [docs/rendezvous-community/features-1.3.md](../../docs/rendezvous-community/features-1.3.md).

## Pesan langsung, banding, notifikasi (1.3.0)

```dart
await openCommunityMessageRequests(context);                    // daftar permintaan pesan
await openCommunityAppeals(context);                            // "Banding saya"
await showCommunityAppealDialog(context, targetType: AppealTargetType.post, targetId: postId);
await openCommunityNotificationSettings(context);
```

- **Permintaan pesan:** DM dari orang yang tidak Anda ikuti masuk ke "Permintaan pesan" di atas daftar chat (jumlah dari `get_message_request_count`). Room permintaan memburamkan gambar sampai diterima; aksi Terima / Tolak / Blokir & laporkan. Saat DM dibuka, `get_dm_request_state` dibaca: pengirim melihat "Pesan Anda masih berupa permintaan (n/3)" lalu pemberitahuan batas, penerima bisa menekan "Terima" langsung dari room.
- **Privasi & akun** kini juga berisi "Pesan langsung" (semua orang / hanya yang saya ikuti / tidak ada), "Notifikasi" (di aplikasi & push per jenis, jam tenang WIB; bagian "Notifikasi OLT" untuk Transaksi, Dana, Pasar, Info, dan Promo; pesan CS resmi dan pesan OLT kategori `important` selalu dikirim), dan "Banding & sanksi".
- **Banding saya:** sanksi aktif, "Konten yang dimoderasi" (post/komentar/pesan yang disembunyikan atau dihapus moderator dalam 90 hari, dari `get_my_moderated_content`) dengan tombol "Ajukan banding" bila belum dibanding, dan riwayat banding.
- **Notifikasi gabungan:** "Budi dan 4 lainnya menyukai konten Anda" memakai `actor_count`, bukan `event_count`. Notifikasi `appeal` membuka "Banding saya".

## Analitik (1.3.0)

Paket mencatat `feed_open`, `post_create`, `comment_create`, `message_send`, `stock_tap`, `search`, dan `share_chart` lalu mengirimnya ke `track_events` per batch (maks 50, tiap 60 detik, saat 20 event terkumpul, atau saat aplikasi ke latar belakang). Batch yang gagal dibuang; bila server menjawab `disabled` atau flag `analytics` mati, pencatatan berhenti. Hanya properti whitelist (kode saham, UUID, enum, angka, boolean) yang dikirim; teks post, pesan, dan kata kunci pencarian tidak pernah dikirim.

```dart
RendezvousCommunity.instance.trackOrderTap(stockCode: 'BBCA', side: 'buy', source: 'stock'); // dari sosial ke layar order
```

## Banner, draf, kartu saham, statistik notifikasi (1.3.0, migrasi `0087`–`0090`)

```dart
await RendezvousCommunity.initialize(
  // ...
  stockInfo: (code) => CommunityStockInfo(name: oltStocks.name(code), price: oltQuotes.last(code)), // kartu saham
  onOltNotificationTap: (context, data) => oltRouter.openNotification(data),
);

const CommunityBannerHost();                 // banner dari get_client_config, mis. di atas halaman host
await openCommunityPostDrafts(context);      // daftar draf postingan
await showCommunityComposer(context, draft: draft);
await RendezvousCommunity.instance.reportNotificationTapped(pushData); // bila host membuka tujuan push sendiri
```

- **Banner:** maksimal 3 tampil (atur `maxVisible`), urut `priority`. Gaya per level `info`/`warning`/`critical`, tautan dibuka setelah dialog konfirmasi. Banner yang bisa ditutup dan sudah ditutup disimpan per user di perangkat (ikut terhapus saat logout); banner yang tidak bisa ditutup selalu tampil. Feed Terbaru/Mengikuti menampilkannya otomatis di atas daftar.
- **Statistik notifikasi:** membuka item kotak notifikasi atau push melapor `opened`, mengikuti tujuannya melapor `tapped` (`report_notification_event`; `notification_id`, lalu `campaign_id`/`broadcast_id`). Tidak pernah menahan UI; gagal karena jaringan diantrekan di memori sampai online. Push OLT yang diteruskan ke `onOltNotificationTap` dihitung `tapped`.
- **Notifikasi baru:** `followed_post` → postingan, `watchlist_digest` → feed saham teratas (`onStockTap`), `moderation` → "Banding saya" dengan keterangan bisa/tidaknya banding, mention di room saham → room. Sakelar in-app jenis yang dikunci server (`moderation`) nonaktif.
- **Draf:** composer menyimpan otomatis ke perangkat dan server (`save_post_draft`). Bila draf diubah di perangkat lain dan lebih baru, versi itu dimuat dan pengguna diberi tahu; batas 20 draf atau offline → draf hanya di perangkat. Saat terbit, `client_draft_id` dipakai sebagai `client_id` sehingga server menghapus drafnya.
- **Kartu saham:** tombol "Kirim kartu saham" di composer chat (DM, grup, room saham; tidak di chat CS), maksimal 3 kode. Harga tidak dikirim ke server; nama/harga di kartu berasal dari `stockInfo` host atau builder `CommunityChatBuilders(stockCard:)`.

## Offline: cache & outbox (1.3.0)

Bawaannya aktif. Paket menyimpan data terakhir di database lokal milik user komunitas yang sedang masuk, lalu menampilkannya seketika saat layar dibuka; data server dimuat di latar belakang dan menggantikannya (server tetap sumber kebenaran).

```dart
await RendezvousCommunity.initialize(
  // ...
  offlineCache: true,          // false: perilaku lama, tanpa database lokal dan tanpa outbox
  offlineMessageLimit: 200,    // pesan terakhir yang disimpan per room
);

await RendezvousCommunity.instance.clearLocalCache();   // hapus cache & antrean user ini (sesi tetap)
RendezvousCommunity.instance.connectivity.online;       // ValueListenable<bool> untuk UI host
const CommunityOfflineBanner();                          // banner "Anda sedang offline" untuk layar host
```

| Data | Yang disimpan | Batas |
|---|---|---|
| Daftar chat | halaman pertama `get_my_rooms` (tanpa room CS) | 30 room |
| Pesan | baris `get_messages` yang pernah dimuat, pesan terkirim | `offlineMessageLimit` per room, yang terlama dipangkas |
| Feed | halaman pertama Terbaru, Mengikuti, dan feed saham | 20 feed saham terakhir; profil, hashtag, bookmark tidak |
| Outbox | pesan teks yang belum terkirim (`client_id`, isi, balasan) | sampai terkirim, dihapus user, atau logout |

- **Sinkron:** baris server menimpa baris cache (edit, hapus, reaksi, `moderation_status`). Pesan yang tidak lagi dikembalikan server dalam rentang halaman yang sama dihapus dari cache. Saat koneksi kembali, layar yang masih menampilkan data tersimpan memuat ulang sendiri.
- **Outbox:** pesan teks yang dikirim saat offline atau gagal karena jaringan tampil "Menunggu dikirim" lalu dikirim ulang otomatis (backoff 2 detik sampai 1 menit, langsung saat koneksi kembali, aplikasi kembali ke foreground, atau realtime tersambung). Urutan per room dijaga; `client_id` membuat server menolak duplikat. Penolakan server (`content_blocked`, `dm_request_limit`, persetujuan dokumen, `slow_mode` setelah 3 percobaan, dll.) membuat pesan "Gagal terkirim" dengan alasannya dan tombol **Coba lagi** / **Hapus**.
- **Lampiran:** gambar dan PDF butuh media gateway, jadi tidak masuk antrean. Saat offline paket menolak dengan pesan "Gambar dan dokumen hanya bisa dikirim saat online."
- **Status koneksi:** dinilai dari hasil request ke server dan status realtime (tanpa plugin konektivitas). Saat offline, paket memeriksa ulang lewat `get_client_config` (5 detik, naik sampai 1 menit). Banner offline tampil di daftar chat, room chat (builder `connectionBanner`, `CommunityConnectionDetails.offline`), dan feed.
- **Buka aplikasi tanpa jaringan:** database dibuka bila token OLT dari `tokenProvider` milik user OLT yang sama dengan sesi terakhir (dicocokkan lewat hash SHA-256 `iss`+`sub`, tanpa jaringan). Token yang tidak bisa dibaca berarti tidak ada cache sampai online.
- **Web:** cache dan outbox hanya di memori (hilang saat halaman dimuat ulang), sehingga host web tidak perlu menyediakan `sqlite3.wasm`.

**Privasi.** Satu database per user komunitas (`<application support>/rendezvous_community/<user id>.sqlite`). Database dihapus saat `signOut()`, `deleteMyAccount()`, `clearLocalCache()`, saat sesi komunitas berganti ke user lain, dan saat aplikasi dibuka offline oleh user OLT lain. Token sosial maupun token OLT tidak pernah disimpan. **Chat CS tidak di-cache**: riwayatnya berisi verifikasi identitas dan data akun, dan aksesnya sudah lewat jalur `cs_api` sendiri, jadi selalu dimuat dari server. Panggil `signOut()` saat user keluar dari OLT supaya data komunitasnya hilang dari perangkat.

## Push transaksi OLT

Push dari backend OLT (`/integration/v1/notify/messages`) berisi `source: "olt"`, `kind` berawalan `olt.` (`olt.trade`, `olt.funds`, `olt.market`, `olt.info`, `olt.promo`), `category`, `message_id`, `cust_id`, `notification_id`, dan isi `data` dari OLT (mis. `screen`, `order_id`). Pesan yang sama juga masuk ke kotak notifikasi. Daftarkan `onOltNotificationTap` di `initialize` supaya ketukan di kotak notifikasi (payload lengkap: `kind`, `category`, `message_id`, `title`, `body`, `data`, `notification_id`) dan `openCommunityPush` untuk push OLT diteruskan ke router OLT; notifikasinya ditandai terbaca otomatis:

```dart
await RendezvousCommunity.initialize(
  // ...
  onOltNotificationTap: (context, data) => oltRouter.openOltMessage(data),
);
```

Tanpa callback itu, `openCommunityPush` mengembalikan `false` untuk push OLT supaya app OLT yang membuka layarnya sendiri:

```dart
if (isOltPush(message.data)) return oltRouter.openTradePush(message.data);
if (isCommunityPush(message.data)) openCommunityPush(context, message.data);
```

## Tema

Semua warna diturunkan dari `ThemeData` aplikasi host, termasuk dark mode. Untuk menyesuaikan:

```dart
final base = ThemeData(colorScheme: oltColorScheme);
ThemeData(
  colorScheme: oltColorScheme,
  extensions: [
    CommunityTheme.fallback(base).copyWith(
      bullish: oltGreen, bearish: oltRed,
      maxThreadIndentLevels: 4,   // level komentar yang diindentasi
    ),
  ],
);
```

## Kustomisasi UI chat (builder)

Tampilan chat bisa diganti per bagian tanpa menulis ulang logikanya. Setiap builder menerima tiga hal:
- `details`: data siap tampil dan handler yang sudah tersambung ke logika package (kirim, balas, hapus, kirim ulang, bisukan, buka room, dan lain-lain);
- `fallback`: tampilan bawaan bagian itu;
- `context`.

Lazy load, kirim ulang otomatis, indikator mengetik, dan tanda terima tetap diurus package.

Pasang sekali untuk seluruh aplikasi:

```dart
MaterialApp(
  builder: (context, child) => CommunityChatBuildersScope(
    builders: CommunityChatBuilders(
      message: (context, d, fallback) {
        final m = d.message;
        if (m.kind != MessageKind.text || m.isDeleted || m.senderRole != null) return fallback;
        final scheme = Theme.of(context).colorScheme;
        return Align(
          alignment: d.isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onTap: d.onRetry,
            onLongPress: d.onShowActions,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: d.isMine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SocialText(m.body ?? ''),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(d.timeLabel),
                  if (d.isMine) ReceiptIcon(receipt: d.receipt, sendStatus: m.status, color: scheme.outline),
                ]),
              ]),
            ),
          ),
        );
      },
      composer: (context, d, fallback) => Row(children: [
        ...d.extraActions,
        IconButton(onPressed: d.onPickImage, icon: const Icon(Icons.image_outlined)),
        Expanded(
          child: CommunityComposerField(
            controller: d.controller,
            focusNode: d.focusNode,
            hintText: d.hintText,
            maxLength: d.maxLength,
            onSubmit: d.onSend,
          ),
        ),
        IconButton(onPressed: d.onSend, icon: const Icon(Icons.send)),
      ]),
    ),
    child: child!,
  ),
);
```

Builder juga bisa dipasang per widget: `CommunityChatList(builders: ...)` atau `CommunityChatRoom(roomId: id, builders: ...)`. Builder per widget menimpa builder global untuk bagian yang sama.

| Builder | `details` | Data dan handler |
|---|---|---|
| `message` | `CommunityMessageDetails` | `message`, `isMine`, `receipt`, `showSender`, `startsGroup`, `timeLabel`; `onReply`, `onDelete` (dengan konfirmasi bawaan), `onReport`, `onRetry`, `onSenderTap`, `onShowActions` (menu aksi bawaan) |
| `composer` | `CommunityComposerDetails` | `controller`, `focusNode`, `hintText`, `maxLength`, `uploading`, `replyTo`, `replyPreview`, `allowsDocuments`, `extraActions`; `onSend`, `onPickImage` (di chat CS juga memilih PDF), `onCancelReply` |
| `roomHeader` | `CommunityRoomHeaderDetails` | `room`, `title`, `subtitle`, `highlightSubtitle`, `online`, `typing`, `memberCount`; `onTap`, `onToggleMute`, `onLeave` |
| `typingIndicator` | `CommunityTypingDetails` | `users`, `text` (dipanggil hanya saat ada yang mengetik) |
| `connectionBanner` | `CommunityConnectionDetails` | `status`, `label` (dipanggil hanya saat menyambung ulang) |
| `dayDivider` | `CommunityDayDetails` | `day`, `label` |
| `roomTile` | `CommunityRoomTileDetails` | `room`, `title`, `preview`, `typingText`, `timeLabel`, `online`, `selected`, `lastMessageReceipt`; `onTap` |
| `listHeader` | `CommunityChatListHeaderDetails` | `title`; `onNewGroup`, `onRefresh` |
| `loading` | `CommunityLoadingDetails` | `kind`: `rooms`, `moreRooms`, `messages`, `olderMessages` |
| `empty` | `CommunityEmptyDetails` | `kind`: `rooms`, `messages`, `noRoomSelected`; `message` |
| `error` | `CommunityErrorDetails` | `error`, `message` (terlokalisasi); `onRetry` |

Aturan pakai:
- **Handler `null` berarti aksinya tidak berlaku.** Contohnya `onDelete` untuk pesan orang lain, atau `onRetry` untuk pesan yang sudah terkirim. Pasang langsung ke `onPressed` supaya tombol otomatis nonaktif.
- **Teks sudah terlokalisasi:** waktu, teks mengetik, pratinjau "Anda: …", subjudul header, pesan kosong, dan pesan error.
- **Kembalikan `fallback` untuk yang tidak ingin digambar sendiri**, misalnya pesan sistem, tautan bantuan, dan pilihan cepat dari CS.
- **Composer kustom sebaiknya menampilkan `extraActions`.** Tombol tambahan dari `leading` milik pemanggil (`MessageComposer`) masuk lewat sini.
- **Tile kustom wajib menampilkan `OfficialBadge` untuk room CS** (`room.pinned` bernilai `true`) supaya nasabah tetap bisa membedakan CS resmi dari akun palsu. Room CS selalu ada di urutan teratas daftar.
- **Pesan dari CS wajib tetap memperlihatkan penanda resmi.** Cara paling aman: kembalikan `fallback` bila `message.senderRole != null`, karena tampilan bawaan sudah memuat label CS Resmi, tautan bantuan, pilihan cepat, dan rating.
- **Widget `header:` dan `composer:` di `CommunityChatRoom` tetap didukung** dan didahulukan dari builder.
- **Builder ikut terbawa ke halaman yang dibuka package:** room di layar sempit, chat CS, dan riwayat tiket.
- **Komponen siap pakai untuk UI sendiri:** `CommunityComposerField` (Enter mengirim, autocomplete `$KODE`/`@user`), `SocialText`, `AttachmentGrid`, `ReceiptIcon`, `CommunityAvatar`, `CommunityRoomAvatar`, `CommunityCountBadge`.

## Arsitektur & logging

Struktur folder, aturan dependensi, alur auth/realtime/centang ada di [docs/rendezvous-community/architecture.md](../../docs/rendezvous-community/architecture.md). Logger dan aturan data sensitif ada di [docs/rendezvous-community/logging.md](../../docs/rendezvous-community/logging.md).

```dart
await RendezvousCommunity.initialize(
  // ...
  logHandler: (record) => oltLogger.write(record.level.name, record.loggerName, record.message),
  logLevel: Level.INFO,   // default: INFO di release, FINE di debug
);
```

## Pengembangan

```bash
flutter pub get
dart run build_runner build      # setelah mengubah model/state freezed
flutter gen-l10n                 # setelah mengubah file .arb
flutter analyze                  # wajib: tanpa issue
flutter test                     # unit + widget test (integration dilewati)
OLT_SOCIAL_IT=1 flutter test test/integration   # butuh stack Docker + seed + auth-bridge mode mock
dart run tool/license_audit.dart # tolak GPL/AGPL/LGPL/MPL
dart run tool/check_comments.dart # gagal bila ada komentar di kode Dart (kecuali // ignore & file generate)
dart run tool/check_logging.dart  # gagal bila library memakai print/debugPrint langsung
```

| Test | Isi |
|---|---|
| `test/core` | Parser `$KODE`/`@mention` (identik dengan regex di DB), pemetaan error, TokenManager (single-flight, refresh, login gagal), media gateway (URL, header, `x-upsert`, refresh 401, pemetaan kode error) |
| `test/features/*/data` | Repository dengan data source mock: parameter RPC, pemetaan baris, pagination, idempotensi, polling, status centang |
| `test/features/*/domain` | Perhitungan centang (DM & grup), DeliveryTracker, aturan draf polling |
| `test/features/*/presentation` | Cubit daftar chat (mengetik, centang, online, sinkron ulang setelah reconnect), cubit room, cubit & widget badge chat, tile room, widget polling, composer polling, thread komentar |
| `test/features/legal`, `test/features/account` | Pemetaan `get_legal_documents`, cache per sesi, gerbang persetujuan (tertunda → setuju → ulang sekali, ditunda, chat CS), alur & pembaca dokumen, banner feed, ekspor data (isi + nama file, batas harian), hapus akun (ketik `HAPUS`, callback, sesi dibersihkan) |
| `test/integration` | Ke backend nyata: login, feed keyset, thread, komentar & chat realtime, presence per room, centang terkirim → dibaca, badge chat belum dibaca, polling, rate limit, dokumen hukum, unggah lewat media gateway, konfigurasi klien (anon & login), pencarian/hashtag/trending, bookmark, jendela edit, permintaan DM (akun baru → budi, batas 3, terima), kebijakan DM, slow mode (`slow_mode` + detik), link preview, analitik, reaksi realtime & bagikan post, banner di konfigurasi, `report_notification_event`, draf (simpan, ubah, hapus, terbit menghapus draf), kartu saham |
| `test/features/{config,search,trending,bookmarks,chat,message_requests,appeals,link_preview}` | 1.3.0: pemetaan RPC dengan mock, cubit (debounce pencarian, bookmark/edit optimistis, reaksi, slow mode, permintaan pesan, preferensi notifikasi), widget (gate kill switch, sentimen, menu post, chip reaksi, room permintaan, dialog tautan, banding) |
| `test/core/logging` | Logger: field terstruktur, level, sanitasi data sensitif, `initialize(logHandler:)` |
| `test/features/{config,notifications,drafts,chat}` (0087–0090) | Banner (parsing, prioritas, tutup tersimpan, widget), laporan dibuka/diketuk (dedupe, antrean offline, push & kotak notifikasi), tipe notifikasi baru & sakelar terkunci, draf (simpan, offline/batas, konflik, gabung daftar, autosave composer, `client_id`), kartu saham (parsing, normalisasi, cubit, kartu & pemilih) |
| `test/core/storage`, `test/features/{chat,feed,offline}` (offline) | Store drift in-memory & memori (kontrak sama), rekonsiliasi & pemangkasan, database per user, hapus saat logout/ganti user/hapus akun, buka offline lewat identitas OLT, outbox (tertunda → terkirim/gagal, backoff, urutan, dedupe), cubit cache → server, widget pesan tertunda/gagal & banner offline |
| `test/tool` | Pemeriksa komentar dan pemeriksa `print` untuk CI |
| `test/support` | Fake dependensi & mock data source bersama |
| `example/integration_test` | E2E app di Windows: login → feed → thread → komentar (Enter) → chat (Enter) → notifikasi |

## Lisensi

Proprietary (lihat `LICENSE`). Semua dependensi runtime berlisensi permisif: MIT, BSD, atau Apache-2.0. Ini diverifikasi dengan `tool/license_audit.dart`.
