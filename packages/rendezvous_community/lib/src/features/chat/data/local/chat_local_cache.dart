import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_cache_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

class ChatLocalCache implements ChatCacheRepository {
  ChatLocalCache(this._cache);

  final OfflineCache _cache;

  @override
  Future<UserSummary?> cachedUser() => _cache.owner();

  @override
  Future<List<ChatRoom>> cachedRooms() async => [
    for (final row in await _cache.read((store) => store.readRooms()) ?? const <Map<String, dynamic>>[])
      ?_parse(() => RoomSummaryModel.fromJson(row).toEntity()),
  ];

  @override
  Future<List<ChatMessage>> cachedMessages(String roomId) async => [
    for (final row in await _cache.read((store) => store.readMessages(roomId)) ?? const <Map<String, dynamic>>[])
      ?_parse(() => ChatMessageModel.fromJson(row).toEntity()),
  ];

  Future<void> saveRooms(List<Map<String, dynamic>> rows) => _cache.write(
    (store) => store.replaceRooms([
      for (final row in rows)
        if (row['type'] != RoomType.support.name) row,
    ]),
  );

  Future<void> saveMessages(
    String roomId,
    List<Map<String, dynamic>> rows,
    List<ChatMessage> messages, {
    RowWindow? window,
  }) => _cache.write(
    (store) => store.mergeMessages(
      roomId,
      [
        for (final (index, message) in messages.indexed)
          StoredRow(id: message.id, group: roomId, createdAt: message.createdAt, data: rows[index]),
      ],
      window: window,
      keep: _cache.messageLimit,
    ),
  );

  Future<void> forgetRoom(String roomId) => _cache.write((store) => store.deleteRoom(roomId));

  static T? _parse<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      return null;
    }
  }
}

RowWindow? olderPageWindow(List<ChatMessage> items, {String? cursor, required bool hasMore}) {
  final before = cursor == null ? null : DateTime.tryParse(cursor.split('|').first);
  if (cursor != null && before == null) return null;
  return RowWindow(after: hasMore && items.isNotEmpty ? items.last.createdAt : null, before: before);
}
