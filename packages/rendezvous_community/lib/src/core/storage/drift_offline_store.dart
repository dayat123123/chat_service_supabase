import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rendezvous_community/src/core/storage/community_database.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';

class DriftOfflineStore implements OfflineStore {
  DriftOfflineStore(this.db);

  final CommunityDatabase db;

  static int _micros(DateTime time) => time.toUtc().microsecondsSinceEpoch;

  static DateTime _time(int micros) => DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);

  static Map<String, dynamic> _decode(String data) => jsonDecode(data) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>?> readMeta(String key) async {
    final row = await (db.select(db.metaEntries)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : _decode(row.value);
  }

  @override
  Future<void> writeMeta(String key, Map<String, dynamic> value) =>
      db.into(db.metaEntries).insertOnConflictUpdate(MetaEntry(key: key, value: jsonEncode(value)));

  @override
  Future<List<Map<String, dynamic>>> readRooms() async {
    final rows = await (db.select(db.cachedRooms)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    return [for (final row in rows) _decode(row.data)];
  }

  @override
  Future<void> replaceRooms(List<Map<String, dynamic>> rows) => db.transaction(() async {
    await db.delete(db.cachedRooms).go();
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.cachedRooms, [
        for (final (index, row) in rows.indexed)
          CachedRoom(id: row['id'] as String, position: index, data: jsonEncode(row)),
      ]);
    });
  });

  @override
  Future<void> deleteRoom(String roomId) => db.transaction(() async {
    await (db.delete(db.cachedRooms)..where((t) => t.id.equals(roomId))).go();
    await (db.delete(db.cachedMessages)..where((t) => t.roomId.equals(roomId))).go();
  });

  @override
  Future<List<Map<String, dynamic>>> readMessages(String roomId) async {
    final rows =
        await (db.select(db.cachedMessages)
              ..where((t) => t.roomId.equals(roomId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)]))
            .get();
    return [for (final row in rows) _decode(row.data)];
  }

  @override
  Future<void> mergeMessages(String roomId, List<StoredRow> rows, {RowWindow? window, required int keep}) =>
      db.transaction(() async {
        final existing =
            await (db.selectOnly(db.cachedMessages)
                  ..addColumns([db.cachedMessages.id, db.cachedMessages.createdAt])
                  ..where(db.cachedMessages.roomId.equals(roomId)))
                .get();
        final result = reconcileRows(
          [
            for (final row in existing)
              (id: row.read(db.cachedMessages.id)!, createdAt: _time(row.read(db.cachedMessages.createdAt)!)),
          ],
          rows,
          window: window,
          keep: keep,
        );
        if (result.deletes.isNotEmpty) {
          await (db.delete(db.cachedMessages)..where((t) => t.id.isIn(result.deletes))).go();
        }
        await db.batch((batch) {
          batch.insertAllOnConflictUpdate(db.cachedMessages, [
            for (final row in result.upserts)
              CachedMessage(id: row.id, roomId: roomId, createdAt: _micros(row.createdAt), data: jsonEncode(row.data)),
          ]);
        });
      });

  @override
  Future<List<Map<String, dynamic>>?> readFeed(String scope) async {
    final row = await (db.select(db.cachedFeedPages)..where((t) => t.scope.equals(scope))).getSingleOrNull();
    return row == null ? null : (jsonDecode(row.data) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> writeFeed(String scope, List<Map<String, dynamic>> rows, {required int keepScopes}) =>
      db.transaction(() async {
        await db
            .into(db.cachedFeedPages)
            .insertOnConflictUpdate(
              CachedFeedPage(scope: scope, savedAt: _micros(DateTime.now()), data: jsonEncode(rows)),
            );
        final stale =
            await (db.select(db.cachedFeedPages)
                  ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
                  ..limit(-1, offset: keepScopes))
                .get();
        final ids = [
          for (final page in stale)
            if (page.scope != scope) page.scope,
        ];
        if (ids.isNotEmpty) await (db.delete(db.cachedFeedPages)..where((t) => t.scope.isIn(ids))).go();
      });

  @override
  Future<List<Map<String, dynamic>>> readOutbox() async {
    final rows = await (db.select(db.outboxEntries)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    return [for (final row in rows) _decode(row.data)];
  }

  @override
  Future<void> writeOutbox(StoredRow row) => db
      .into(db.outboxEntries)
      .insertOnConflictUpdate(
        OutboxEntry(id: row.id, roomId: row.group, createdAt: _micros(row.createdAt), data: jsonEncode(row.data)),
      );

  @override
  Future<void> deleteOutbox(String id) => (db.delete(db.outboxEntries)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> close() => db.close();
}
