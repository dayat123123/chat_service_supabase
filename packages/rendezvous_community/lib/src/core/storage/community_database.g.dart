// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_database.dart';

// ignore_for_file: type=lint
class $MetaEntriesTable extends MetaEntries with TableInfo<$MetaEntriesTable, MetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_entries';
  @override
  VerificationContext validateIntegrity(Insertable<MetaEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaEntry(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $MetaEntriesTable createAlias(String alias) {
    return $MetaEntriesTable(attachedDatabase, alias);
  }
}

class MetaEntry extends DataClass implements Insertable<MetaEntry> {
  final String key;
  final String value;
  const MetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MetaEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory MetaEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaEntry(key: serializer.fromJson<String>(json['key']), value: serializer.fromJson<String>(json['value']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
  }

  MetaEntry copyWith({String? key, String? value}) => MetaEntry(key: key ?? this.key, value: value ?? this.value);
  MetaEntry copyWithCompanion(MetaEntriesCompanion data) {
    return MetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MetaEntry && other.key == this.key && other.value == this.value);
}

class MetaEntriesCompanion extends UpdateCompanion<MetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaEntriesCompanion.insert({required String key, required String value, this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<MetaEntry> custom({Expression<String>? key, Expression<String>? value, Expression<int>? rowid}) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaEntriesCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return MetaEntriesCompanion(key: key ?? this.key, value: value ?? this.value, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedRoomsTable extends CachedRooms with TableInfo<$CachedRoomsTable, CachedRoom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, position, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_rooms';
  @override
  VerificationContext validateIntegrity(Insertable<CachedRoom> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedRoom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRoom(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $CachedRoomsTable createAlias(String alias) {
    return $CachedRoomsTable(attachedDatabase, alias);
  }
}

class CachedRoom extends DataClass implements Insertable<CachedRoom> {
  final String id;
  final int position;
  final String data;
  const CachedRoom({required this.id, required this.position, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['data'] = Variable<String>(data);
    return map;
  }

  CachedRoomsCompanion toCompanion(bool nullToAbsent) {
    return CachedRoomsCompanion(id: Value(id), position: Value(position), data: Value(data));
  }

  factory CachedRoom.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRoom(
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'data': serializer.toJson<String>(data),
    };
  }

  CachedRoom copyWith({String? id, int? position, String? data}) =>
      CachedRoom(id: id ?? this.id, position: position ?? this.position, data: data ?? this.data);
  CachedRoom copyWithCompanion(CachedRoomsCompanion data) {
    return CachedRoom(
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoom(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, position, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRoom && other.id == this.id && other.position == this.position && other.data == this.data);
}

class CachedRoomsCompanion extends UpdateCompanion<CachedRoom> {
  final Value<String> id;
  final Value<int> position;
  final Value<String> data;
  final Value<int> rowid;
  const CachedRoomsCompanion({
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedRoomsCompanion.insert({
    required String id,
    required int position,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       position = Value(position),
       data = Value(data);
  static Insertable<CachedRoom> custom({
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedRoomsCompanion copyWith({Value<String>? id, Value<int>? position, Value<String>? data, Value<int>? rowid}) {
    return CachedRoomsCompanion(
      id: id ?? this.id,
      position: position ?? this.position,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoomsCompanion(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMessagesTable extends CachedMessages with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, roomId, createdAt, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMessage> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta, roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      roomId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}room_id'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String id;
  final String roomId;
  final int createdAt;
  final String data;
  const CachedMessage({required this.id, required this.roomId, required this.createdAt, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['room_id'] = Variable<String>(roomId);
    map['created_at'] = Variable<int>(createdAt);
    map['data'] = Variable<String>(data);
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      id: Value(id),
      roomId: Value(roomId),
      createdAt: Value(createdAt),
      data: Value(data),
    );
  }

  factory CachedMessage.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      id: serializer.fromJson<String>(json['id']),
      roomId: serializer.fromJson<String>(json['roomId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'roomId': serializer.toJson<String>(roomId),
      'createdAt': serializer.toJson<int>(createdAt),
      'data': serializer.toJson<String>(data),
    };
  }

  CachedMessage copyWith({String? id, String? roomId, int? createdAt, String? data}) => CachedMessage(
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    createdAt: createdAt ?? this.createdAt,
    data: data ?? this.data,
  );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      id: data.id.present ? data.id.value : this.id,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('createdAt: $createdAt, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, roomId, createdAt, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.id == this.id &&
          other.roomId == this.roomId &&
          other.createdAt == this.createdAt &&
          other.data == this.data);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> id;
  final Value<String> roomId;
  final Value<int> createdAt;
  final Value<String> data;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.id = const Value.absent(),
    this.roomId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String id,
    required String roomId,
    required int createdAt,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       roomId = Value(roomId),
       createdAt = Value(createdAt),
       data = Value(data);
  static Insertable<CachedMessage> custom({
    Expression<String>? id,
    Expression<String>? roomId,
    Expression<int>? createdAt,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roomId != null) 'room_id': roomId,
      if (createdAt != null) 'created_at': createdAt,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? roomId,
    Value<int>? createdAt,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return CachedMessagesCompanion(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('createdAt: $createdAt, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedFeedPagesTable extends CachedFeedPages with TableInfo<$CachedFeedPagesTable, CachedFeedPage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFeedPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta('savedAt');
  @override
  late final GeneratedColumn<int> savedAt = GeneratedColumn<int>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, savedAt, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_feed_pages';
  @override
  VerificationContext validateIntegrity(Insertable<CachedFeedPage> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(_scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta, savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta));
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  CachedFeedPage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedFeedPage(
      scope: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
      savedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}saved_at'])!,
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $CachedFeedPagesTable createAlias(String alias) {
    return $CachedFeedPagesTable(attachedDatabase, alias);
  }
}

class CachedFeedPage extends DataClass implements Insertable<CachedFeedPage> {
  final String scope;
  final int savedAt;
  final String data;
  const CachedFeedPage({required this.scope, required this.savedAt, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['saved_at'] = Variable<int>(savedAt);
    map['data'] = Variable<String>(data);
    return map;
  }

  CachedFeedPagesCompanion toCompanion(bool nullToAbsent) {
    return CachedFeedPagesCompanion(scope: Value(scope), savedAt: Value(savedAt), data: Value(data));
  }

  factory CachedFeedPage.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedFeedPage(
      scope: serializer.fromJson<String>(json['scope']),
      savedAt: serializer.fromJson<int>(json['savedAt']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'savedAt': serializer.toJson<int>(savedAt),
      'data': serializer.toJson<String>(data),
    };
  }

  CachedFeedPage copyWith({String? scope, int? savedAt, String? data}) =>
      CachedFeedPage(scope: scope ?? this.scope, savedAt: savedAt ?? this.savedAt, data: data ?? this.data);
  CachedFeedPage copyWithCompanion(CachedFeedPagesCompanion data) {
    return CachedFeedPage(
      scope: data.scope.present ? data.scope.value : this.scope,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedFeedPage(')
          ..write('scope: $scope, ')
          ..write('savedAt: $savedAt, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, savedAt, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedFeedPage &&
          other.scope == this.scope &&
          other.savedAt == this.savedAt &&
          other.data == this.data);
}

class CachedFeedPagesCompanion extends UpdateCompanion<CachedFeedPage> {
  final Value<String> scope;
  final Value<int> savedAt;
  final Value<String> data;
  final Value<int> rowid;
  const CachedFeedPagesCompanion({
    this.scope = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFeedPagesCompanion.insert({
    required String scope,
    required int savedAt,
    required String data,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       savedAt = Value(savedAt),
       data = Value(data);
  static Insertable<CachedFeedPage> custom({
    Expression<String>? scope,
    Expression<int>? savedAt,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (savedAt != null) 'saved_at': savedAt,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFeedPagesCompanion copyWith({
    Value<String>? scope,
    Value<int>? savedAt,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return CachedFeedPagesCompanion(
      scope: scope ?? this.scope,
      savedAt: savedAt ?? this.savedAt,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<int>(savedAt.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFeedPagesCompanion(')
          ..write('scope: $scope, ')
          ..write('savedAt: $savedAt, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEntriesTable extends OutboxEntries with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, roomId, createdAt, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta, roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta));
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      roomId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}room_id'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final String id;
  final String roomId;
  final int createdAt;
  final String data;
  const OutboxEntry({required this.id, required this.roomId, required this.createdAt, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['room_id'] = Variable<String>(roomId);
    map['created_at'] = Variable<int>(createdAt);
    map['data'] = Variable<String>(data);
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(id: Value(id), roomId: Value(roomId), createdAt: Value(createdAt), data: Value(data));
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<String>(json['id']),
      roomId: serializer.fromJson<String>(json['roomId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'roomId': serializer.toJson<String>(roomId),
      'createdAt': serializer.toJson<int>(createdAt),
      'data': serializer.toJson<String>(data),
    };
  }

  OutboxEntry copyWith({String? id, String? roomId, int? createdAt, String? data}) => OutboxEntry(
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    createdAt: createdAt ?? this.createdAt,
    data: data ?? this.data,
  );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('createdAt: $createdAt, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, roomId, createdAt, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.roomId == this.roomId &&
          other.createdAt == this.createdAt &&
          other.data == this.data);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> id;
  final Value<String> roomId;
  final Value<int> createdAt;
  final Value<String> data;
  final Value<int> rowid;
  const OutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.roomId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    required String id,
    required String roomId,
    required int createdAt,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       roomId = Value(roomId),
       createdAt = Value(createdAt),
       data = Value(data);
  static Insertable<OutboxEntry> custom({
    Expression<String>? id,
    Expression<String>? roomId,
    Expression<int>? createdAt,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roomId != null) 'room_id': roomId,
      if (createdAt != null) 'created_at': createdAt,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? roomId,
    Value<int>? createdAt,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return OutboxEntriesCompanion(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('roomId: $roomId, ')
          ..write('createdAt: $createdAt, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CommunityDatabase extends GeneratedDatabase {
  _$CommunityDatabase(QueryExecutor e) : super(e);
  $CommunityDatabaseManager get managers => $CommunityDatabaseManager(this);
  late final $MetaEntriesTable metaEntries = $MetaEntriesTable(this);
  late final $CachedRoomsTable cachedRooms = $CachedRoomsTable(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  late final $CachedFeedPagesTable cachedFeedPages = $CachedFeedPagesTable(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final Index cachedMessagesRoomTime = Index(
    'cached_messages_room_time',
    'CREATE INDEX cached_messages_room_time ON cached_messages (room_id, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    metaEntries,
    cachedRooms,
    cachedMessages,
    cachedFeedPages,
    outboxEntries,
    cachedMessagesRoomTime,
  ];
}

typedef $$MetaEntriesTableCreateCompanionBuilder =
    MetaEntriesCompanion Function({required String key, required String value, Value<int> rowid});
typedef $$MetaEntriesTableUpdateCompanionBuilder =
    MetaEntriesCompanion Function({Value<String> key, Value<String> value, Value<int> rowid});

class $$MetaEntriesTableFilterComposer extends Composer<_$CommunityDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$MetaEntriesTableOrderingComposer extends Composer<_$CommunityDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$MetaEntriesTableAnnotationComposer extends Composer<_$CommunityDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaEntriesTableTableManager
    extends
        RootTableManager<
          _$CommunityDatabase,
          $MetaEntriesTable,
          MetaEntry,
          $$MetaEntriesTableFilterComposer,
          $$MetaEntriesTableOrderingComposer,
          $$MetaEntriesTableAnnotationComposer,
          $$MetaEntriesTableCreateCompanionBuilder,
          $$MetaEntriesTableUpdateCompanionBuilder,
          (MetaEntry, BaseReferences<_$CommunityDatabase, $MetaEntriesTable, MetaEntry>),
          MetaEntry,
          PrefetchHooks Function()
        > {
  $$MetaEntriesTableTableManager(_$CommunityDatabase db, $MetaEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({required String key, required String value, Value<int> rowid = const Value.absent()}) =>
                  MetaEntriesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CommunityDatabase,
      $MetaEntriesTable,
      MetaEntry,
      $$MetaEntriesTableFilterComposer,
      $$MetaEntriesTableOrderingComposer,
      $$MetaEntriesTableAnnotationComposer,
      $$MetaEntriesTableCreateCompanionBuilder,
      $$MetaEntriesTableUpdateCompanionBuilder,
      (MetaEntry, BaseReferences<_$CommunityDatabase, $MetaEntriesTable, MetaEntry>),
      MetaEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedRoomsTableCreateCompanionBuilder =
    CachedRoomsCompanion Function({required String id, required int position, required String data, Value<int> rowid});
typedef $$CachedRoomsTableUpdateCompanionBuilder =
    CachedRoomsCompanion Function({Value<String> id, Value<int> position, Value<String> data, Value<int> rowid});

class $$CachedRoomsTableFilterComposer extends Composer<_$CommunityDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$CachedRoomsTableOrderingComposer extends Composer<_$CommunityDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$CachedRoomsTableAnnotationComposer extends Composer<_$CommunityDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position => $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get data => $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CachedRoomsTableTableManager
    extends
        RootTableManager<
          _$CommunityDatabase,
          $CachedRoomsTable,
          CachedRoom,
          $$CachedRoomsTableFilterComposer,
          $$CachedRoomsTableOrderingComposer,
          $$CachedRoomsTableAnnotationComposer,
          $$CachedRoomsTableCreateCompanionBuilder,
          $$CachedRoomsTableUpdateCompanionBuilder,
          (CachedRoom, BaseReferences<_$CommunityDatabase, $CachedRoomsTable, CachedRoom>),
          CachedRoom,
          PrefetchHooks Function()
        > {
  $$CachedRoomsTableTableManager(_$CommunityDatabase db, $CachedRoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CachedRoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CachedRoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CachedRoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedRoomsCompanion(id: id, position: position, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required int position,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => CachedRoomsCompanion.insert(id: id, position: position, data: data, rowid: rowid),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedRoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$CommunityDatabase,
      $CachedRoomsTable,
      CachedRoom,
      $$CachedRoomsTableFilterComposer,
      $$CachedRoomsTableOrderingComposer,
      $$CachedRoomsTableAnnotationComposer,
      $$CachedRoomsTableCreateCompanionBuilder,
      $$CachedRoomsTableUpdateCompanionBuilder,
      (CachedRoom, BaseReferences<_$CommunityDatabase, $CachedRoomsTable, CachedRoom>),
      CachedRoom,
      PrefetchHooks Function()
    >;
typedef $$CachedMessagesTableCreateCompanionBuilder =
    CachedMessagesCompanion Function({
      required String id,
      required String roomId,
      required int createdAt,
      required String data,
      Value<int> rowid,
    });
typedef $$CachedMessagesTableUpdateCompanionBuilder =
    CachedMessagesCompanion Function({
      Value<String> id,
      Value<String> roomId,
      Value<int> createdAt,
      Value<String> data,
      Value<int> rowid,
    });

class $$CachedMessagesTableFilterComposer extends Composer<_$CommunityDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$CachedMessagesTableOrderingComposer extends Composer<_$CommunityDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$CachedMessagesTableAnnotationComposer extends Composer<_$CommunityDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roomId => $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get data => $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CachedMessagesTableTableManager
    extends
        RootTableManager<
          _$CommunityDatabase,
          $CachedMessagesTable,
          CachedMessage,
          $$CachedMessagesTableFilterComposer,
          $$CachedMessagesTableOrderingComposer,
          $$CachedMessagesTableAnnotationComposer,
          $$CachedMessagesTableCreateCompanionBuilder,
          $$CachedMessagesTableUpdateCompanionBuilder,
          (CachedMessage, BaseReferences<_$CommunityDatabase, $CachedMessagesTable, CachedMessage>),
          CachedMessage,
          PrefetchHooks Function()
        > {
  $$CachedMessagesTableTableManager(_$CommunityDatabase db, $CachedMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CachedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CachedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CachedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMessagesCompanion(id: id, roomId: roomId, createdAt: createdAt, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String roomId,
                required int createdAt,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => CachedMessagesCompanion.insert(
                id: id,
                roomId: roomId,
                createdAt: createdAt,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$CommunityDatabase,
      $CachedMessagesTable,
      CachedMessage,
      $$CachedMessagesTableFilterComposer,
      $$CachedMessagesTableOrderingComposer,
      $$CachedMessagesTableAnnotationComposer,
      $$CachedMessagesTableCreateCompanionBuilder,
      $$CachedMessagesTableUpdateCompanionBuilder,
      (CachedMessage, BaseReferences<_$CommunityDatabase, $CachedMessagesTable, CachedMessage>),
      CachedMessage,
      PrefetchHooks Function()
    >;
typedef $$CachedFeedPagesTableCreateCompanionBuilder =
    CachedFeedPagesCompanion Function({
      required String scope,
      required int savedAt,
      required String data,
      Value<int> rowid,
    });
typedef $$CachedFeedPagesTableUpdateCompanionBuilder =
    CachedFeedPagesCompanion Function({Value<String> scope, Value<int> savedAt, Value<String> data, Value<int> rowid});

class $$CachedFeedPagesTableFilterComposer extends Composer<_$CommunityDatabase, $CachedFeedPagesTable> {
  $$CachedFeedPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$CachedFeedPagesTableOrderingComposer extends Composer<_$CommunityDatabase, $CachedFeedPagesTable> {
  $$CachedFeedPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$CachedFeedPagesTableAnnotationComposer extends Composer<_$CommunityDatabase, $CachedFeedPagesTable> {
  $$CachedFeedPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope => $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get savedAt => $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<String> get data => $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CachedFeedPagesTableTableManager
    extends
        RootTableManager<
          _$CommunityDatabase,
          $CachedFeedPagesTable,
          CachedFeedPage,
          $$CachedFeedPagesTableFilterComposer,
          $$CachedFeedPagesTableOrderingComposer,
          $$CachedFeedPagesTableAnnotationComposer,
          $$CachedFeedPagesTableCreateCompanionBuilder,
          $$CachedFeedPagesTableUpdateCompanionBuilder,
          (CachedFeedPage, BaseReferences<_$CommunityDatabase, $CachedFeedPagesTable, CachedFeedPage>),
          CachedFeedPage,
          PrefetchHooks Function()
        > {
  $$CachedFeedPagesTableTableManager(_$CommunityDatabase db, $CachedFeedPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CachedFeedPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CachedFeedPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CachedFeedPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<int> savedAt = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFeedPagesCompanion(scope: scope, savedAt: savedAt, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String scope,
                required int savedAt,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => CachedFeedPagesCompanion.insert(scope: scope, savedAt: savedAt, data: data, rowid: rowid),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedFeedPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$CommunityDatabase,
      $CachedFeedPagesTable,
      CachedFeedPage,
      $$CachedFeedPagesTableFilterComposer,
      $$CachedFeedPagesTableOrderingComposer,
      $$CachedFeedPagesTableAnnotationComposer,
      $$CachedFeedPagesTableCreateCompanionBuilder,
      $$CachedFeedPagesTableUpdateCompanionBuilder,
      (CachedFeedPage, BaseReferences<_$CommunityDatabase, $CachedFeedPagesTable, CachedFeedPage>),
      CachedFeedPage,
      PrefetchHooks Function()
    >;
typedef $$OutboxEntriesTableCreateCompanionBuilder =
    OutboxEntriesCompanion Function({
      required String id,
      required String roomId,
      required int createdAt,
      required String data,
      Value<int> rowid,
    });
typedef $$OutboxEntriesTableUpdateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<String> id,
      Value<String> roomId,
      Value<int> createdAt,
      Value<String> data,
      Value<int> rowid,
    });

class $$OutboxEntriesTableFilterComposer extends Composer<_$CommunityDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$OutboxEntriesTableOrderingComposer extends Composer<_$CommunityDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEntriesTableAnnotationComposer extends Composer<_$CommunityDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roomId => $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get data => $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$CommunityDatabase,
          $OutboxEntriesTable,
          OutboxEntry,
          $$OutboxEntriesTableFilterComposer,
          $$OutboxEntriesTableOrderingComposer,
          $$OutboxEntriesTableAnnotationComposer,
          $$OutboxEntriesTableCreateCompanionBuilder,
          $$OutboxEntriesTableUpdateCompanionBuilder,
          (OutboxEntry, BaseReferences<_$CommunityDatabase, $OutboxEntriesTable, OutboxEntry>),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxEntriesTableTableManager(_$CommunityDatabase db, $OutboxEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxEntriesCompanion(id: id, roomId: roomId, createdAt: createdAt, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String roomId,
                required int createdAt,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) =>
                  OutboxEntriesCompanion.insert(id: id, roomId: roomId, createdAt: createdAt, data: data, rowid: rowid),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CommunityDatabase,
      $OutboxEntriesTable,
      OutboxEntry,
      $$OutboxEntriesTableFilterComposer,
      $$OutboxEntriesTableOrderingComposer,
      $$OutboxEntriesTableAnnotationComposer,
      $$OutboxEntriesTableCreateCompanionBuilder,
      $$OutboxEntriesTableUpdateCompanionBuilder,
      (OutboxEntry, BaseReferences<_$CommunityDatabase, $OutboxEntriesTable, OutboxEntry>),
      OutboxEntry,
      PrefetchHooks Function()
    >;

class $CommunityDatabaseManager {
  final _$CommunityDatabase _db;
  $CommunityDatabaseManager(this._db);
  $$MetaEntriesTableTableManager get metaEntries => $$MetaEntriesTableTableManager(_db, _db.metaEntries);
  $$CachedRoomsTableTableManager get cachedRooms => $$CachedRoomsTableTableManager(_db, _db.cachedRooms);
  $$CachedMessagesTableTableManager get cachedMessages => $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
  $$CachedFeedPagesTableTableManager get cachedFeedPages =>
      $$CachedFeedPagesTableTableManager(_db, _db.cachedFeedPages);
  $$OutboxEntriesTableTableManager get outboxEntries => $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
}
