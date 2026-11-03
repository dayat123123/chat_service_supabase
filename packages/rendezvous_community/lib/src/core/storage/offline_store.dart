class StoredRow {
  const StoredRow({required this.id, required this.group, required this.createdAt, required this.data});

  final String id;
  final String group;
  final DateTime createdAt;
  final Map<String, dynamic> data;
}

class RowWindow {
  const RowWindow({this.after, this.before});

  const RowWindow.all() : this();

  final DateTime? after;
  final DateTime? before;

  bool contains(DateTime time) {
    final after = this.after;
    final before = this.before;
    return (after == null || time.isAfter(after)) && (before == null || time.isBefore(before));
  }
}

typedef RowKey = ({String id, DateTime createdAt});

class RowReconciliation {
  const RowReconciliation({required this.upserts, required this.deletes});

  final List<StoredRow> upserts;
  final Set<String> deletes;
}

RowReconciliation reconcileRows(
  Iterable<RowKey> existing,
  List<StoredRow> incoming, {
  RowWindow? window,
  required int keep,
}) {
  final incomingIds = {for (final row in incoming) row.id};
  final deletes = <String>{
    if (window != null)
      for (final row in existing)
        if (!incomingIds.contains(row.id) && window.contains(row.createdAt)) row.id,
  };
  final survivors = <String, DateTime>{
    for (final row in existing)
      if (!deletes.contains(row.id)) row.id: row.createdAt,
    for (final row in incoming) row.id: row.createdAt,
  };
  final ordered = survivors.entries.toList()
    ..sort((a, b) {
      final time = b.value.compareTo(a.value);
      return time != 0 ? time : b.key.compareTo(a.key);
    });
  final kept = {for (final entry in ordered.take(keep < 0 ? 0 : keep)) entry.key};
  deletes.addAll(survivors.keys.where((id) => !kept.contains(id)));
  return RowReconciliation(
    upserts: [
      for (final row in incoming)
        if (kept.contains(row.id)) row,
    ],
    deletes: deletes,
  );
}

abstract interface class OfflineStore {
  Future<Map<String, dynamic>?> readMeta(String key);

  Future<void> writeMeta(String key, Map<String, dynamic> value);

  Future<List<Map<String, dynamic>>> readRooms();

  Future<void> replaceRooms(List<Map<String, dynamic>> rows);

  Future<void> deleteRoom(String roomId);

  Future<List<Map<String, dynamic>>> readMessages(String roomId);

  Future<void> mergeMessages(String roomId, List<StoredRow> rows, {RowWindow? window, required int keep});

  Future<List<Map<String, dynamic>>?> readFeed(String scope);

  Future<void> writeFeed(String scope, List<Map<String, dynamic>> rows, {required int keepScopes});

  Future<List<Map<String, dynamic>>> readOutbox();

  Future<void> writeOutbox(StoredRow row);

  Future<void> deleteOutbox(String id);

  Future<void> close();
}

abstract interface class OfflineStoreFactory {
  Future<List<String>> keys();

  Future<OfflineStore> open(String key);

  Future<void> delete(String key);
}

String offlineStoreKey(String userId) => userId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
