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
  oltTokenProvider: () => oltAuth.freshSocialToken(), // token sosial (JWT) dari OLT yang masih berlaku
  onStockTap: (context, code) => openOltStockPage(context, code),
  stockSearch: (query) => oltStocks.search(query),   // saran $KODE dari daftar saham milik app
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
```

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
| `composer` | `CommunityComposerDetails` | `controller`, `focusNode`, `hintText`, `maxLength`, `uploading`, `replyTo`, `replyPreview`, `extraActions`; `onSend`, `onPickImage`, `onCancelReply` |
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
OLT_SOCIAL_IT=1 flutter test test/integration   # butuh stack Docker + seed
dart run tool/license_audit.dart # tolak GPL/AGPL/LGPL/MPL
dart run tool/check_comments.dart # gagal bila ada komentar di kode Dart (kecuali // ignore & file generate)
dart run tool/check_logging.dart  # gagal bila library memakai print/debugPrint langsung
```

| Test | Isi |
|---|---|
| `test/core` | Parser `$KODE`/`@mention` (identik dengan regex di DB), pemetaan error, TokenManager (single-flight, refresh, login gagal) |
| `test/features/*/data` | Repository dengan data source mock: parameter RPC, pemetaan baris, pagination, idempotensi, polling, status centang |
| `test/features/*/domain` | Perhitungan centang (DM & grup), DeliveryTracker, aturan draf polling |
| `test/features/*/presentation` | Cubit daftar chat (mengetik, centang, online, sinkron ulang setelah reconnect), cubit room, cubit & widget badge chat, tile room, widget polling, composer polling, thread komentar |
| `test/integration` | Ke backend nyata: login, feed keyset, thread, komentar & chat realtime, presence per room, centang terkirim → dibaca, badge chat belum dibaca, polling, rate limit |
| `test/core/logging` | Logger: field terstruktur, level, sanitasi data sensitif, `initialize(logHandler:)` |
| `test/tool` | Pemeriksa komentar dan pemeriksa `print` untuk CI |
| `test/support` | Fake dependensi & mock data source bersama |
| `example/integration_test` | E2E app di Windows: login → feed → thread → komentar (Enter) → chat (Enter) → notifikasi |

## Lisensi

Proprietary (lihat `LICENSE`). Semua dependensi runtime berlisensi permisif: MIT, BSD, atau Apache-2.0. Ini diverifikasi dengan `tool/license_audit.dart`.
