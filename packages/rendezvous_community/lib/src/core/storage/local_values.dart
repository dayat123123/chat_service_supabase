import 'package:rendezvous_community/src/core/storage/offline_cache.dart';

abstract interface class LocalValues {
  Future<Map<String, dynamic>?> read(String key);

  Future<void> write(String key, Map<String, dynamic> value);
}

class OfflineLocalValues implements LocalValues {
  OfflineLocalValues(this._cache);

  final OfflineCache _cache;

  @override
  Future<Map<String, dynamic>?> read(String key) => _cache.read<Map<String, dynamic>?>((store) => store.readMeta(key));

  @override
  Future<void> write(String key, Map<String, dynamic> value) => _cache.write((store) => store.writeMeta(key, value));
}

class MemoryLocalValues implements LocalValues {
  final _values = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async => _values[key] = value;
}
