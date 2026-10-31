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
const OltChatBadge(child: Icon(Icons.chat_bubble_outline));   // badge chat belum dibaca di tab
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
| Chat | Centang ala WhatsApp: jam (mengirim), ✓ (sampai server), ✓✓ abu-abu (sudah diterima perangkat penerima yang online), ✓✓ biru (sudah dibaca). Di grup, centang naik setelah **semua** anggota menerima/membaca; room saham hanya ✓. Badge belum dibaca per room, balas pesan, reconnect otomatis dengan pengisian celah pesan dan tanda terima |
| Lazy load chat | Pesan dimuat 30 per halaman memakai cursor (bukan offset). Halaman lebih lama diambil saat scroll mendekati pesan tertua, dan otomatis bila halaman pertama belum memenuhi layar. Daftar room juga dimuat 30 per halaman dengan aturan yang sama. Setelah koneksi pulih, pesan yang terlewat disusulkan per 100 sampai habis; bila lebih dari 500, room dimuat ulang dari pesan terbaru dan pesan lama tetap bisa dimuat dengan scroll |
| Badge tab chat | `OltChatBadge` menampilkan jumlah **chat** (DM & grup yang tidak dibisukan) yang punya pesan belum dibaca, seperti tab Chat WhatsApp; `99+` bila lebih. Room saham tidak dihitung. Diperbarui saat pesan masuk dan saat room dibuka |
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

## Kustomisasi UI chat (builder)

Tampilan chat bisa diganti per bagian tanpa menulis ulang logikanya. Setiap builder menerima tiga hal:
- `details`: data siap tampil dan handler yang sudah tersambung ke logika package (kirim, balas, hapus, kirim ulang, bisukan, buka room, dan lain-lain);
- `fallback`: tampilan bawaan bagian itu;
- `context`.

Lazy load, kirim ulang otomatis, indikator mengetik, dan tanda terima tetap diurus package.

Pasang sekali untuk seluruh aplikasi:

```dart
MaterialApp(
  builder: (context, child) => OltChatBuildersScope(
    builders: OltChatBuilders(
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
          child: OltComposerField(
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

Builder juga bisa dipasang per widget: `OltChatList(builders: ...)` atau `OltChatRoom(roomId: id, builders: ...)`. Builder per widget menimpa builder global untuk bagian yang sama.

| Builder | `details` | Data dan handler |
|---|---|---|
| `message` | `OltMessageDetails` | `message`, `isMine`, `receipt`, `showSender`, `startsGroup`, `timeLabel`; `onReply`, `onDelete` (dengan konfirmasi bawaan), `onReport`, `onRetry`, `onSenderTap`, `onShowActions` (menu aksi bawaan) |
| `composer` | `OltComposerDetails` | `controller`, `focusNode`, `hintText`, `maxLength`, `uploading`, `replyTo`, `replyPreview`, `extraActions`; `onSend`, `onPickImage`, `onCancelReply` |
| `roomHeader` | `OltRoomHeaderDetails` | `room`, `title`, `subtitle`, `highlightSubtitle`, `online`, `typing`, `memberCount`; `onTap`, `onToggleMute`, `onLeave` |
| `typingIndicator` | `OltTypingDetails` | `users`, `text` (dipanggil hanya saat ada yang mengetik) |
| `connectionBanner` | `OltConnectionDetails` | `status`, `label` (dipanggil hanya saat menyambung ulang) |
| `dayDivider` | `OltDayDetails` | `day`, `label` |
| `roomTile` | `OltRoomTileDetails` | `room`, `title`, `preview`, `typingText`, `timeLabel`, `online`, `selected`, `lastMessageReceipt`; `onTap` |
| `listHeader` | `OltChatListHeaderDetails` | `title`; `onNewGroup`, `onRefresh` |
| `loading` | `OltLoadingDetails` | `kind`: `rooms`, `moreRooms`, `messages`, `olderMessages` |
| `empty` | `OltEmptyDetails` | `kind`: `rooms`, `messages`, `noRoomSelected`; `message` |
| `error` | `OltErrorDetails` | `error`, `message` (terlokalisasi); `onRetry` |

Aturan pakai:
- **Handler `null` berarti aksinya tidak berlaku.** Contohnya `onDelete` untuk pesan orang lain, atau `onRetry` untuk pesan yang sudah terkirim. Pasang langsung ke `onPressed` supaya tombol otomatis nonaktif.
- **Teks sudah terlokalisasi:** waktu, teks mengetik, pratinjau "Anda: …", subjudul header, pesan kosong, dan pesan error.
- **Kembalikan `fallback` untuk yang tidak ingin digambar sendiri**, misalnya pesan sistem, kartu order, dan pilihan cepat dari CS.
- **Composer kustom sebaiknya menampilkan `extraActions`.** Chat CS memakainya untuk tombol lampirkan order.
- **Tile kustom wajib menampilkan `OfficialBadge` untuk room CS** (`room.pinned` bernilai `true`) supaya nasabah tetap bisa membedakan CS resmi dari akun palsu. Room CS selalu ada di urutan teratas daftar.
- **Pesan dari CS wajib tetap memperlihatkan penanda resmi.** Cara paling aman: kembalikan `fallback` bila `message.senderRole != null`, karena tampilan bawaan sudah memuat label CS Resmi, kartu, pilihan cepat, dan rating.
- **Widget `header:` dan `composer:` di `OltChatRoom` tetap didukung** dan didahulukan dari builder.
- **Builder ikut terbawa ke halaman yang dibuka package:** room di layar sempit, chat CS, dan riwayat tiket.
- **Komponen siap pakai untuk UI sendiri:** `OltComposerField` (Enter mengirim, autocomplete `$KODE`/`@user`), `SocialText`, `AttachmentGrid`, `ReceiptIcon`, `OltAvatar`, `OltRoomAvatar`, `OltCountBadge`.

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
      presentation/  cubit/ (flutter_bloc), widgets/, dan builders/ (khusus chat: kontrak builder UI)
```

Aturan dependensi:
- `core` tidak bergantung pada apa pun di package.
- `shared` hanya bergantung pada `core` (kecuali widget yang butuh navigasi lewat `OltSocialScope`).
- Fitur boleh memakai **domain** fitur lain (mis. `compose` memakai `poll/domain`), tidak pernah lapisan `data`-nya.
- `app` adalah satu-satunya tempat yang mengenal semua implementasi.
- Cubit selalu di file sendiri (`presentation/cubit/`), terpisah dari widget.
- Widget chat bawaan dan builder kustom memakai `details` yang sama. Logika (handler) dibuat sekali di widget pengendali, lalu tampilan bawaan (`_Default*`) maupun builder host hanya menggambarnya.
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
  - Broadcast yang terlewat saat channel `room:<id>` terputus diambil ulang ketika tersambung lagi: room memuat ulang `get_room_members` (digabung, tanda terima tidak pernah mundur), daftar chat memuat ulang `get_my_rooms`.
  - Broadcast dari database butuh Realtime dengan `REGION` yang sama dengan region tenant (`us-east-1`, lihat `docker/compose.yml`). Bila berbeda, Realtime memutus koneksi DB tenant tiap 10 menit dan tanda terima hilang tanpa error.
  - Matikan pelacakan terkirim dengan `OltSocial.initialize(trackDelivery: false)` bila host punya mekanisme sendiri.
- **Badge chat:** `OltChatBadge` memanggil RPC `get_unread_chat_count` dan memuat ulang (digabung 1,2 detik) saat ada notifikasi baru untuk user (server membuat notifikasi `message` hanya untuk DM/grup yang tidak dibisukan, jadi room saham yang ramai tidak memicu permintaan) dan saat room dibaca, dibisukan, atau ditinggalkan di perangkat ini.
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
| `test/features/*/presentation` | Cubit daftar chat (mengetik, centang, online, sinkron ulang setelah reconnect), cubit room, cubit & widget badge chat, tile room, widget polling, composer polling, thread komentar |
| `test/integration` | Ke backend nyata: login, feed keyset, thread, komentar & chat realtime, presence per room, centang terkirim → dibaca, badge chat belum dibaca, polling, rate limit |
| `test/support` | Fake dependensi & mock data source bersama |
| `example/integration_test` | E2E app di Windows: login → feed → thread → komentar (Enter) → chat (Enter) → notifikasi |

## Lisensi

Proprietary (lihat `LICENSE`). Semua dependensi runtime berlisensi permisif: MIT, BSD, atau Apache-2.0. Ini diverifikasi dengan `tool/license_audit.dart`.
