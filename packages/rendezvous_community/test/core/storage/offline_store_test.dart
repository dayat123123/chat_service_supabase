import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/src/core/storage/community_database.dart';
import 'package:rendezvous_community/src/core/storage/drift_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';

final _t0 = DateTime.utc(2026, 11, 3, 9);

StoredRow _message(String id, int minute, {String room = 'r1', String? body}) => StoredRow(
  id: id,
  group: room,
  createdAt: _t0.add(Duration(minutes: minute)),
  data: {'id': id, 'room_id': room, 'body': body ?? 'pesan $id'},
);

List<String> _ids(List<Map<String, dynamic>> rows) => [for (final row in rows) row['id'] as String];

void main() {
  group('reconcileRows', () {
    test('drops rows missing from the server inside the window and prunes to the newest N', () {
      final result = reconcileRows(
        [
          (id: 'a', createdAt: _t0),
          (id: 'b', createdAt: _t0.add(const Duration(minutes: 1))),
          (id: 'c', createdAt: _t0.add(const Duration(minutes: 2))),
        ],
        [_message('c', 2), _message('d', 3)],
        window: RowWindow(after: _t0),
        keep: 2,
      );
      expect(result.deletes, {'a', 'b'});
      expect([for (final row in result.upserts) row.id], ['c', 'd']);
    });

    test('rows outside the window are kept and new rows beyond the limit are not written', () {
      final result = reconcileRows(
        [(id: 'x', createdAt: _t0.add(const Duration(minutes: 9)))],
        [_message('old', 0)],
        window: RowWindow(before: _t0.add(const Duration(minutes: 5))),
        keep: 1,
      );
      expect(result.deletes, {'old'});
      expect(result.upserts, isEmpty);
    });
  });

  for (final (name, create) in <(String, OfflineStore Function())>[
    ('drift', () => DriftOfflineStore(CommunityDatabase(NativeDatabase.memory()))),
    ('memory', MemoryOfflineStore.new),
  ]) {
    group('$name store', () {
      late OfflineStore store;

      setUp(() => store = create());
      tearDown(() => store.close());

      test('meta values round-trip', () async {
        expect(await store.readMeta('owner'), isNull);
        await store.writeMeta('owner', {'user_id': 'u1'});
        await store.writeMeta('owner', {'user_id': 'u2'});
        expect(await store.readMeta('owner'), {'user_id': 'u2'});
      });

      test('rooms are replaced in server order and deleting a room drops its messages', () async {
        await store.replaceRooms([
          {'id': 'r2'},
          {'id': 'r1'},
        ]);
        await store.mergeMessages('r1', [_message('m1', 1)], keep: 200);
        expect(_ids(await store.readRooms()), ['r2', 'r1']);

        await store.replaceRooms([
          {'id': 'r1', 'name': 'baru'},
        ]);
        expect(await store.readRooms(), [
          {'id': 'r1', 'name': 'baru'},
        ]);

        await store.deleteRoom('r1');
        expect(await store.readRooms(), isEmpty);
        expect(await store.readMessages('r1'), isEmpty);
      });

      test('messages merge newest first, reconcile edits and deletions, and prune per room', () async {
        await store.mergeMessages('r1', [for (var i = 0; i < 5; i++) _message('m$i', i)], keep: 4);
        await store.mergeMessages('r2', [_message('other', 0, room: 'r2')], keep: 4);
        expect(_ids(await store.readMessages('r1')), ['m4', 'm3', 'm2', 'm1']);

        await store.mergeMessages(
          'r1',
          [_message('m4', 4, body: 'diedit'), _message('m2', 2)],
          window: RowWindow(after: _t0.add(const Duration(minutes: 2))),
          keep: 4,
        );
        final rows = await store.readMessages('r1');
        expect(_ids(rows), ['m4', 'm2', 'm1']);
        expect(rows.first['body'], 'diedit');
        expect(_ids(await store.readMessages('r2')), ['other']);
      });

      test('feed pages are stored per scope and only the most recent scopes are kept', () async {
        await store.writeFeed('global', [
          {'id': 'p1'},
        ], keepScopes: 2);
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await store.writeFeed('stock:BBCA', [
          {'id': 'p2'},
        ], keepScopes: 2);
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await store.writeFeed('stock:TLKM', [
          {'id': 'p3'},
        ], keepScopes: 2);
        expect(await store.readFeed('global'), isNull);
        expect(await store.readFeed('stock:TLKM'), [
          {'id': 'p3'},
        ]);
        expect(await store.readFeed('stock:BBCA'), isNotNull);
      });

      test('outbox entries are ordered by creation and can be updated and removed', () async {
        await store.writeOutbox(
          StoredRow(id: 'c2', group: 'r1', createdAt: _t0.add(const Duration(seconds: 2)), data: {'n': 2}),
        );
        await store.writeOutbox(StoredRow(id: 'c1', group: 'r1', createdAt: _t0, data: {'n': 1}));
        await store.writeOutbox(StoredRow(id: 'c1', group: 'r1', createdAt: _t0, data: {'n': 10}));
        expect(await store.readOutbox(), [
          {'n': 10},
          {'n': 2},
        ]);
        await store.deleteOutbox('c1');
        expect(await store.readOutbox(), [
          {'n': 2},
        ]);
      });
    });
  }
}
