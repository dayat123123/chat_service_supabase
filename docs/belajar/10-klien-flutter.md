# Modul 10: Klien Flutter (library `rendezvous_community`)

**Tujuan:** melihat bagaimana semua konsep server (RPC, error, cursor, realtime, gap-fill, idempotensi) dipakai di sisi aplikasi, dan bagaimana app OLT menyesuaikan tampilannya tanpa mengubah library.

Library ada di repo terpisah: `D:/My Developments/Golang/rendezvous_community`. Semua path di modul ini relatif terhadap repo itu.

---

## 10.1 Lapisan per fitur

Setiap fitur (`lib/src/features/<fitur>/`) punya tiga lapis:

```
presentation/   ← UI dan state
  cubit/          ChatRoomCubit, ChatListCubit
  widgets/        layar dan komponen
  builders/       detail untuk slot kustomisasi
domain/         ← "bahasa bisnis", tanpa Supabase
  entities/       ChatMessage, ChatRoom (freezed)
  repositories/   ChatRepository (interface)
data/           ← bicara dengan server
  models/         ChatMessageModel (JSON ↔ entity)
  repositories/   ChatRepositoryImpl (memanggil RPC)
  realtime/       RoomChannelHub (WebSocket)
  local/          cache drift (offline)
```

Arah ketergantungan hanya satu: `presentation → domain ← data`. Cubit tidak tahu ada Supabase. Ia hanya mengenal `ChatRepository`, sehingga di tes repository bisa diganti versi palsu.

## 10.2 Dari tombol Kirim sampai server

```
Tombol Kirim
  └─ ChatRoomCubit.send(body)
       ├─ buat clientId (UUID) → tampilkan bubble sementara (optimistic UI)
       ├─ simpan ke outbox lokal (agar tidak hilang bila app ditutup / offline)
       └─ ChatRepository.sendMessage(roomId, body:, clientId:)
            └─ ChatRepositoryImpl
                 └─ _api.rpcRows('send_message', {'p_room_id':…, 'p_body':…, 'p_client_id':…, 'p_attachments':[…]})
                      └─ POST /rest/v1/rpc/send_message                (modul 4)
                 ◄── baris chat_message (JSON snake_case)
                 └─ ChatMessageModel.fromJson(row).toEntity()
       └─ ganti bubble sementara dengan pesan resmi (dicocokkan lewat clientId)
```

Buka dan ikuti alurnya:
- `lib/src/features/chat/domain/repositories/chat_repository.dart`: kontraknya.
- `lib/src/features/chat/data/repositories/chat_repository_impl.dart`: cari `'send_message'`.
- `lib/src/features/chat/presentation/cubit/chat_room_cubit.dart`: cari `_outbox`.

## 10.3 Model: JSON ↔ Dart

Model memakai **freezed** + **json_serializable** dengan `field_rename: snake` ([build.yaml](https://github.com/dayat123123/rendezvous_community/blob/main/build.yaml)), sehingga `senderUsername` di Dart otomatis menjadi `sender_username` di JSON.

```dart
@freezed
abstract class ChatMessageModel with _$ChatMessageModel {
  const factory ChatMessageModel({
    required String id,
    required String roomId,
    String? senderUsername,
    @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    required DateTime createdAt,
    String? cursor,
    ...
  }) = _ChatMessageModel;
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => _$ChatMessageModelFromJson(json);
  ChatMessage toEntity() => ...;
}
```

File `*.freezed.dart` dan `*.g.dart` adalah hasil generator (`dart run build_runner build`) dan tidak diedit manual.

Field baru dari server selalu **opsional** di model (`String?` atau `@Default`). Dengan begitu, library baru tetap jalan di server lama, dan library lama tetap jalan di server baru, karena field yang tidak dikenal diabaikan.

## 10.4 Error server → pesan di layar

`lib/src/core/error/error_mapper.dart` mengubah error PostgREST menjadi `CommunityException(kind, code)`:

- `code` berawalan `PT` → yang dipakai adalah `message` (misalnya `slow_mode`), lalu `kind` ditentukan dari status (`rateLimited`, `forbidden`, …);
- `slow_mode` → `details` dibaca sebagai detik tunggu (`retryAfter`).

`lib/src/shared/presentation/l10n/l10n.dart` lalu memetakan `code` ke teks terjemahan (ARB, Indonesia/Inggris). Di sinilah kontrak "kode error stabil" dari modul 7.5 dipakai.

**Kompatibilitas mundur:** bila fungsi belum ada di server (`PGRST202`), repository memakai jalur lama. Contohnya `create_post` diulang tanpa `p_comment_audience` bila server belum memasang 0169.

## 10.5 Realtime di klien

`lib/src/features/chat/data/realtime/room_channel_hub.dart`:

```dart
final channel = _realtime.privateChannel('room:$roomId', presenceKey: presence ? me.id : null);
channel
  ..onBroadcast(event: 'message', callback: _onMessage)
  ..onBroadcast(event: 'typing', callback: _onTyping)
  ..onBroadcast(event: 'receipt', callback: _onReceipt)
  ...
  ..subscribe((status, _) => _emit(RoomConnection(roomId, mapSubscribeStatus(status))));
```

- Satu channel per room yang sedang dibuka, ditambah satu channel `user:<saya>` untuk daftar chat dan badge.
- Status `reconnecting` memicu gap-fill (`get_message_ids` + `get_messages_by_ids`) begitu tersambung lagi (modul 6.6).
- Event `message` dengan `ref: true` diambil isinya lewat RPC.

## 10.6 State dengan Cubit

Cubit (dari paket `bloc`) adalah kelas yang memegang satu **state** tak berubah (*immutable*) dan memancarkan state baru lewat `emit`. UI hanya menggambar ulang dari state. Pola umumnya (disederhanakan dari `ChatRoomCubit`):

```dart
emit(state.copyWith(status: LoadStatus.loading, error: null));
try {
  final page = await _repository.getMessages(roomId);
  emit(state.copyWith(status: LoadStatus.success, messages: page.items, cursor: page.nextCursor));
} catch (e) {
  emit(state.copyWith(status: LoadStatus.failure, error: e));
}
```

Keuntungannya: setiap perubahan layar bisa diuji tanpa UI (`bloc_test`). Contohnya ada di folder `test/features/chat/`.

## 10.7 Kustomisasi oleh app OLT: builder slot

App OLT punya desainnya sendiri. Supaya tidak perlu *fork* library, library menyediakan **slot**: titik di UI yang bisa diganti app host.

```dart
CommunityBuilders(
  feed: CommunityFeedBuilders(
    commentRestriction: (context, details) => FeedCommentRestriction(details: details),
  ),
)
```

- Library memanggil slot dengan objek `…Details` berisi data **dan** aksi (misalnya `details.onToggleCommentsOff`).
- Bila slot tidak diisi, library memakai tampilan bawaannya.
- App OLT mengisi slot di `lib/features/community_feed/presentation/theme/feed_builders.dart` (repo app OLT).

Daftar slot ada di `doc/customization.md` di repo library.

## 10.8 Offline

- **Cache** (drift/SQLite): pesan dan room yang pernah dibuka disimpan di HP, sehingga chat terbuka seketika dan bisa dibaca saat offline.
- **Outbox**: pesan yang dikirim saat offline masuk antrean lokal dan dikirim ulang dengan `client_id` yang sama saat online. Idempotensi server (modul 7.3) memastikan pesan tidak dobel.

---

## Latihan

1. Ikuti alur 10.2 di kode. Tulis nama file dan nama method di setiap langkah.
2. Cari di `chat_repository_impl.dart` semua nama RPC yang dipanggil. Cocokkan dengan [docs/api/openapi.yaml](../api/openapi.yaml).
3. Tambahkan field fiktif `"is_pinned": true` pada JSON contoh pesan di sebuah tes model. Apakah `ChatMessageModel.fromJson` gagal? Kenapa tidak?
4. Cari di `l10n.dart` kode error `dm_not_allowed`. Teks apa yang ditampilkan dalam bahasa Indonesia?
5. Buka `feed_builders.dart` di app OLT, pilih satu slot, lalu temukan kelas `…Details`-nya di library. Data dan aksi apa saja yang tersedia?

## Cek pemahaman

- Kenapa cubit tidak boleh memanggil Supabase langsung?
- Kenapa field baru di model selalu opsional?
- Apa gunanya `clientId` di sisi klien, selain mencegah pesan ganda?

**Bacaan:** bloclibrary.dev (*Cubit*), pub.dev `freezed` dan `json_serializable`, drift.simonbinder.eu, dan `doc/` di repo library.
