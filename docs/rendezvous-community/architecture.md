# Arsitektur `rendezvous_community`

> Dipindahkan dari README package (1.0.0). Cara pakai ada di [README package](../../packages/rendezvous_community/README.md) dan [docs/INTEGRATION.md](../INTEGRATION.md).

Clean Architecture **per fitur**. Setiap fitur berdiri sendiri dengan tiga lapisan:

```
lib/src/
  app/        RendezvousCommunity (titik komposisi: merakit repository, DeliveryTracker),
              CommunityDependencies (kontrak DI), CommunityScope + CommunityNavigator,
              CommunitySupportScope, CommunityAccountScope (dokumen hukum & akun)
  core/       infrastruktur tanpa UI: auth (TokenManager, auth-bridge), error, logging,
              network (data source Supabase, media gateway, gateway & status realtime, SharedStream),
              paging, parser $KODE/@mention, MIME gambar
  shared/     entitas bersama (UserSummary, Attachment), model JSON bersama,
              kit UI (tema, lokalisasi ARB, avatar, state view, SocialText, composer)
  features/
    feed/          stream & feed, kartu post         chat/          daftar & room chat, centang, mengetik
    post/          detail post & thread komentar      poll/          polling: entitas, vote, CommunityPollView
    compose/       composer post + editor polling     notifications/ notifikasi & badge
    profile/       profil user                        stocks/        halaman saham & watchlist
    moderation/    laporan & blokir                   media/         unggah & tampilkan lampiran
    legal/         dokumen hukum, persetujuan, banner account/       ekspor data, hapus akun, "Privasi & akun"
      domain/        entitas immutable (freezed), kontrak repository, layanan domain
      data/          model JSON (freezed + json_serializable), implementasi repository
      presentation/  cubit/ (flutter_bloc), widgets/, dan builders/ (khusus chat: kontrak builder UI)
```

Aturan dependensi:
- `core` tidak bergantung pada apa pun di package.
- `shared` hanya bergantung pada `core` (kecuali widget yang butuh navigasi lewat `CommunityScope`).
- Fitur boleh memakai **domain** fitur lain (mis. `compose` memakai `poll/domain`), tidak pernah lapisan `data`-nya.
- `app` adalah satu-satunya tempat yang mengenal semua implementasi.
- Cubit selalu di file sendiri (`presentation/cubit/`), terpisah dari widget.
- Widget chat bawaan dan builder kustom memakai `details` yang sama. Logika (handler) dibuat sekali di widget pengendali, lalu tampilan bawaan (`_Default*`) maupun builder host hanya menggambarnya.
- Import di dalam package memakai `package:rendezvous_community/...` (lint `always_use_package_imports`).
- Kode tanpa komentar; penjelasan ada di dokumen ini dan di `docs/rendezvous-community/`. CI menolak komentar baru (`tool/check_comments.dart`), kecuali `// ignore:` dan file hasil generate.
- Library tidak mencetak ke konsol; semua log lewat `CommunityLoggers` ([logging.md](logging.md)). CI menolak `print`/`debugPrint` di luar modul logging (`tool/check_logging.dart`).

- **Auth:** `SupabaseClient(accessToken: tokenManager.accessToken)`.
  - JWT diperbarui otomatis 60 detik sebelum kedaluwarsa dan didorong ke koneksi realtime (`realtime.setAuth`).
  - Request yang ditolak karena JWT kedaluwarsa diulang sekali setelah refresh.
- **Error:** semua API melempar `CommunityException` dengan `kind` (`rateLimited`, `contentBlocked`, `forbidden`, …). `message` hanya untuk log/debug (Bahasa Inggris atau pesan server), tidak pernah ditampilkan langsung.
  - `code` berisi kode stabil dari server, misalnya `rate_limited`.
  - UI menampilkan pesan terlokalisasi lewat `context.communityL10n.errorMessage(e)`.
- **Realtime:**
  - `postgres_changes` (tunduk RLS) untuk pesan, post, komentar, dan notifikasi. Langganan pesan masuk dibagi lewat `SharedStream` (satu channel untuk daftar chat dan `DeliveryTracker`).
  - Satu channel private `room:<id>` per room, dikelola `RoomChannelHub` dengan *ref-count*: daftar chat dan room yang sedang dibuka memakai channel yang sama (Phoenix menutup join ganda ke topic yang sama). Isinya: broadcast `typing` dari klien, broadcast `receipt` dari **server**, dan presence (siapa yang online di room itu). Otorisasinya lewat policy `realtime.messages`.
  - Daftar chat memantau maksimal 30 room DM/grup terbaru. Room saham tidak dipantau (terlalu ramai).
- **Centang (tanda terima):**
  - Selama aplikasi terbuka dan sesi aktif, `DeliveryTracker` (dijalankan `RendezvousCommunity`) memanggil RPC `mark_rooms_delivered` saat ada pesan masuk dari orang lain. Membuka room memanggil `mark_room_read`.
  - Kedua RPC menyimpan penanda di `chat_members` lalu menyiarkan `receipt` ke `room:<id>` lewat `realtime.send` di database. Klien tidak bisa memalsukan tanda terima orang lain.
  - Status per pesan dihitung fungsi domain `receiptStatus(sentAt, penerima)`. `get_my_rooms` mengembalikan `last_message_status` untuk pesan terakhir milik sendiri.
  - Broadcast yang terlewat saat channel `room:<id>` terputus diambil ulang ketika tersambung lagi: room memuat ulang `get_room_members` (digabung, tanda terima tidak pernah mundur), daftar chat memuat ulang `get_my_rooms`.
  - Broadcast dari database butuh Realtime dengan `REGION` yang sama dengan region tenant (`us-east-1`, lihat `docker/compose.yml`). Bila berbeda, Realtime memutus koneksi DB tenant tiap 10 menit dan tanda terima hilang tanpa error.
  - Matikan pelacakan terkirim dengan `RendezvousCommunity.initialize(trackDelivery: false)` bila host punya mekanisme sendiri.
- **Badge chat:** `CommunityChatBadge` memanggil RPC `get_unread_chat_count` dan memuat ulang (digabung 1,2 detik) saat ada notifikasi baru untuk user (server membuat notifikasi `message` hanya untuk DM/grup yang tidak dibisukan, jadi room saham yang ramai tidak memicu permintaan) dan saat room dibaca, dibisukan, atau ditinggalkan di perangkat ini.
- **Polling:** dibuat bersama post dalam satu transaksi (`create_post` dengan `p_poll`), dipilih lewat `vote_poll`. Jumlah suara hanya keluar lewat proyeksi feed (`feed_post.poll`); tabel suara tidak bisa dibaca langsung oleh client.
- **Unggahan (media gateway):** `SocialRemoteDataSource.upload` mengirim byte ke `POST {supabaseUrl}/media/v1/object/{bucket}/{path}` lewat `MediaGatewayClient` (`core/network/media_gateway.dart`) dengan `apikey`, `Authorization: Bearer <JWT sosial>`, dan `Content-Type`; `x-upsert: true` hanya untuk avatar. Layanan `media` memeriksa jenis dari isi file, membuang metadata, lalu meneruskan ke Storage dengan klaim `media_verified` (kebijakan Storage menolak unggahan nasabah tanpa klaim itu). Repository memakai `path`/`mime` dari respons karena ekstensi bisa diganti. 401 → refresh sesi dan satu kali ulang. Error `{code, message}` dipetakan `mapMediaError` (status → `CommunityErrorKind`, `code` dari server); 404 tanpa kode (backend tanpa `/media/v1`) menjadi `unavailable`/`media_unavailable`. Membaca lampiran tetap lewat Storage (`authenticated`/signed URL).
- **Dokumen hukum & persetujuan:** `CommunityConsent` (`legal/domain/services`) menyimpan hasil `get_legal_documents` per sesi. `RendezvousCommunity` memanggil `onUserChanged` dari `sessionChanges`: ganti user → cache dikosongkan dan dimuat sekali; refresh token user yang sama tidak memicu permintaan. Gagal memuat → coba lagi paling cepat 30 detik kemudian. `accept` memanggil `accept_legal_document` per dokumen lalu memuat ulang.
  - `ConsentGate` (domain) membungkus aksi tulis: error `consent_required` → `prompt()` → bila setuju, aksi diulang satu kali; bila tidak, `CommunityException(forbidden, code: consent_declined)`. Prompt dibuat di lapisan presentasi oleh `communityConsentGate(context)` (membuka `showCommunityConsent`) dan disuntikkan ke `ComposeCubit`, `CommentThreadCubit`, dan `ChatRoomCubit`; cubit tidak memegang `BuildContext`. `CommunityConsent.prompt` menjamin hanya satu dialog walau beberapa aksi gagal bersamaan. `ChatRoomCubit` melewati gerbang untuk room `support` dan untuk kirim ulang otomatis setelah reconnect.
  - Widget mencari dependensi lewat `CommunityAccountScope.maybeOf` (fallback `RendezvousCommunity.instance`). Tanpa keduanya (mis. tes dengan `CommunityScope` palsu) banner tidak tampil dan gerbang nonaktif, jadi `CommunityDependencies` tidak perlu berubah.
- **Hapus akun:** `deleteMyAccount()` memanggil `delete_my_account` (server mengarsipkan konten, menghapus relasi, mencabut sesi, dan menghapus perangkat push), lalu `PushRegistrar.release()` (tanpa RPC, supaya token dipasang lagi di sesi berikutnya) dan mengakhiri sesi lokal seperti `signOut()` tanpa `unregister_push_device`. Tidak ada exchange ulang otomatis; profil kosong baru dibuat saat panggilan API komunitas berikutnya.
- **Ekspor data:** `exportMyData()` mengubah hasil `export_my_data` menjadi JSON berindentasi UTF-8. Penyimpanan file ada di presentasi (`saveCommunityDataExport`: `file_selector` di desktop, `share_plus` di Android/iOS/web) dan bisa diganti host lewat `exportSaver`. Isi ekspor tidak pernah ditulis ke log.
- **Idempotensi:** composer memakai `client_id` per draf, jadi kirim ulang setelah koneksi putus tidak membuat post ganda.
- **Test:** widget bisa diuji tanpa backend dengan membungkusnya di `CommunityScope(dependencies: fake)`.
