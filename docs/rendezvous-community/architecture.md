# Arsitektur `rendezvous_community`

> Dipindahkan dari README package (1.0.0). Cara pakai ada di [README package](../../packages/rendezvous_community/README.md) dan [docs/INTEGRATION.md](../INTEGRATION.md).

Clean Architecture **per fitur**. Setiap fitur berdiri sendiri dengan tiga lapisan:

```
lib/src/
  app/        RendezvousCommunity (titik komposisi: merakit repository, DeliveryTracker),
              CommunityDependencies (kontrak DI), CommunityScope + CommunityNavigator
  core/       infrastruktur tanpa UI: auth (TokenManager, auth-bridge), error, logging,
              network (data source Supabase, gateway & status realtime, SharedStream),
              paging, parser $KODE/@mention, MIME gambar
  shared/     entitas bersama (UserSummary, Attachment), model JSON bersama,
              kit UI (tema, lokalisasi ARB, avatar, state view, SocialText, composer)
  features/
    feed/          stream & feed, kartu post         chat/          daftar & room chat, centang, mengetik
    post/          detail post & thread komentar      poll/          polling: entitas, vote, CommunityPollView
    compose/       composer post + editor polling     notifications/ notifikasi & badge
    profile/       profil user                        stocks/        halaman saham & watchlist
    moderation/    laporan & blokir                   media/         unggah & tampilkan lampiran
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
- **Idempotensi:** composer memakai `client_id` per draf, jadi kirim ulang setelah koneksi putus tidak membuat post ganda.
- **Test:** widget bisa diuji tanpa backend dengan membungkusnya di `CommunityScope(dependencies: fake)`.
