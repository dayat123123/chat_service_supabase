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
