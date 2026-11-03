import 'dart:convert';

import 'package:rendezvous_community/src/core/storage/offline_store.dart';

class MemoryOfflineStore implements OfflineStore {
  final _meta = <String, String>{};
  var _rooms = <String>[];
  final _messages = <String, Map<String, StoredRow>>{};
  final _feed = <String, ({DateTime savedAt, String rows})>{};
  final _outbox = <String, StoredRow>{};
  bool closed = false;

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>?> readMeta(String key) async {
    final value = _meta[key];
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> writeMeta(String key, Map<String, dynamic> value) async => _meta[key] = jsonEncode(value);

  @override
  Future<List<Map<String, dynamic>>> readRooms() async => [
    for (final row in _rooms) jsonDecode(row) as Map<String, dynamic>,
  ];

  @override
  Future<void> replaceRooms(List<Map<String, dynamic>> rows) async =>
      _rooms = [for (final row in rows) jsonEncode(row)];

  @override
  Future<void> deleteRoom(String roomId) async {
    _rooms = [
      for (final row in _rooms)
        if ((jsonDecode(row) as Map<String, dynamic>)['id'] != roomId) row,
    ];
    _messages.remove(roomId);
  }

  @override
  Future<List<Map<String, dynamic>>> readMessages(String roomId) async {
    final rows = [...?_messages[roomId]?.values]
      ..sort((a, b) {
        final time = b.createdAt.compareTo(a.createdAt);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    return [for (final row in rows) _copy(row.data)];
  }

  @override
  Future<void> mergeMessages(String roomId, List<StoredRow> rows, {RowWindow? window, required int keep}) async {
    final room = _messages.putIfAbsent(roomId, () => {});
    final result = reconcileRows(
      [for (final row in room.values) (id: row.id, createdAt: row.createdAt)],
      rows,
      window: window,
      keep: keep,
    );
    result.deletes.forEach(room.remove);
    for (final row in result.upserts) {
      room[row.id] = StoredRow(id: row.id, group: roomId, createdAt: row.createdAt, data: _copy(row.data));
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> readFeed(String scope) async {
    final page = _feed[scope];
    return page == null ? null : (jsonDecode(page.rows) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> writeFeed(String scope, List<Map<String, dynamic>> rows, {required int keepScopes}) async {
    _feed[scope] = (savedAt: DateTime.now().toUtc(), rows: jsonEncode(rows));
    final ordered = _feed.entries.toList()..sort((a, b) => b.value.savedAt.compareTo(a.value.savedAt));
    for (final entry in ordered.skip(keepScopes)) {
      if (entry.key != scope) _feed.remove(entry.key);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readOutbox() async {
    final rows = _outbox.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [for (final row in rows) _copy(row.data)];
  }

  @override
  Future<void> writeOutbox(StoredRow row) async =>
      _outbox[row.id] = StoredRow(id: row.id, group: row.group, createdAt: row.createdAt, data: _copy(row.data));

  @override
  Future<void> deleteOutbox(String id) async => _outbox.remove(id);

  @override
  Future<void> close() async => closed = true;
}

class MemoryOfflineStoreFactory implements OfflineStoreFactory {
  final stores = <String, MemoryOfflineStore>{};

  @override
  Future<List<String>> keys() async => stores.keys.toList();

  @override
  Future<OfflineStore> open(String key) async {
    final store = stores.putIfAbsent(key, MemoryOfflineStore.new);
    store.closed = false;
    return store;
  }

  @override
  Future<void> delete(String key) async => stores.remove(key);
}
