import 'package:drift/drift.dart';

part 'community_database.g.dart';

class MetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class CachedRooms extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get data => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'cached_messages_room_time', columns: {#roomId, #createdAt})
class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  IntColumn get createdAt => integer()();
  TextColumn get data => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CachedFeedPages extends Table {
  TextColumn get scope => text()();
  IntColumn get savedAt => integer()();
  TextColumn get data => text()();

  @override
  Set<Column<Object>> get primaryKey => {scope};
}

class OutboxEntries extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  IntColumn get createdAt => integer()();
  TextColumn get data => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [MetaEntries, CachedRooms, CachedMessages, CachedFeedPages, OutboxEntries])
class CommunityDatabase extends _$CommunityDatabase {
  CommunityDatabase(super.executor);

  static const version = 1;

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      for (final table in <TableInfo<Table, Object?>>[cachedRooms, cachedMessages, cachedFeedPages]) {
        await m.deleteTable(table.actualTableName);
        await m.createTable(table);
      }
      await m.createIndex(cachedMessagesRoomTime);
    },
  );
}
