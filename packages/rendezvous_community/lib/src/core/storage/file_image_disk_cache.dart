import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';

class _Entry {
  _Entry(this.file, this.bytes, this.created, this.accessed);

  final File file;
  final int bytes;
  final DateTime created;
  DateTime accessed;
}

class _Index {
  _Index(this.owner, this.directory);

  final String owner;
  final Directory directory;
  final entries = <String, _Entry>{};
  int total = 0;

  _Entry? put(String name, _Entry entry) {
    final previous = entries[name];
    if (previous != null) total -= previous.bytes;
    entries[name] = entry;
    total += entry.bytes;
    return previous;
  }

  _Entry? remove(String name) {
    final entry = entries.remove(name);
    if (entry != null) total -= entry.bytes;
    return entry;
  }
}

class FileImageDiskCache implements ImageDiskCache {
  FileImageDiskCache({
    required this._root,
    required this._owner,
    this.config = const CommunityImageCacheConfig(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const folder = 'rendezvous_community';
  static const imagesFolder = 'images';
  static const _touchInterval = Duration(minutes: 1);

  final Future<Directory> Function() _root;
  final Future<String?> Function() _owner;
  final DateTime Function() _clock;
  final CommunityImageCacheConfig config;
  _Index? _index;
  Future<void> _lock = Future.value();
  int _generation = 0;
  final _writes = <Future<void>>{};

  Future<Directory> imagesRoot() async => Directory(p.join((await _root()).path, folder, imagesFolder));

  int get totalBytes => _index?.total ?? 0;

  @override
  Future<Uint8List?> read(String key) async {
    final index = await _open();
    if (index == null) return null;
    final name = _name(key);
    final entry = index.entries[name];
    if (entry == null) return null;
    final now = _clock();
    if (now.difference(entry.created) > config.maxAge) {
      index.remove(name);
      await _delete(entry.file);
      return null;
    }
    final Uint8List bytes;
    try {
      bytes = await entry.file.readAsBytes();
    } on FileSystemException {
      index.remove(name);
      return null;
    }
    final touched = now.difference(entry.accessed) > _touchInterval;
    entry.accessed = now;
    if (touched) unawaited(entry.file.setLastModified(now).catchError((Object _) {}));
    return bytes;
  }

  @override
  Future<void> write(String key, Uint8List bytes) {
    late final Future<void> pending;
    pending = _write(key, bytes).whenComplete(() => _writes.remove(pending));
    _writes.add(pending);
    return pending;
  }

  Future<void> _write(String key, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > config.maxBytes) return;
    final index = await _open();
    if (index == null) return;
    final generation = _generation;
    final name = _name(key);
    final now = _clock();
    final file = File(p.join(index.directory.path, '$name-${now.millisecondsSinceEpoch}'));
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (generation != _generation || !identical(index, _index)) {
        await _delete(temporary);
        return;
      }
      await temporary.rename(file.path);
    } on FileSystemException catch (e) {
      _failed('write', e);
      await _delete(temporary);
      return;
    }
    if (generation != _generation || !identical(index, _index)) {
      await _delete(file);
      return;
    }
    final previous = index.put(name, _Entry(file, bytes.length, now, now));
    if (previous != null && previous.file.path != file.path) await _delete(previous.file);
    await _evict(index);
  }

  @override
  Future<void> wipe() async {
    _generation++;
    _index = null;
    await Future.wait([..._writes]);
    await _serial(_deleteAll);
  }

  Future<void> _deleteAll() async {
    _generation++;
    _index = null;
    try {
      final directory = await imagesRoot();
      if (directory.existsSync()) await directory.delete(recursive: true);
      CommunityLoggers.offline.event(Level.INFO, 'Image cache wiped');
    } catch (e) {
      _failed('wipe', e);
    }
  }

  Future<_Index?> _open() async {
    final owner = await _owner();
    if (owner == null) return null;
    final key = offlineStoreKey(owner);
    final current = _index;
    if (current != null && current.owner == key) return current;
    return _serial(() async {
      final open = _index;
      if (open != null && open.owner == key) return open;
      return _index = await _load(key);
    });
  }

  Future<_Index?> _load(String owner) async {
    try {
      final root = await imagesRoot();
      await root.create(recursive: true);
      await for (final entity in root.list()) {
        if (p.basename(entity.path) == owner) continue;
        await entity.delete(recursive: true);
        CommunityLoggers.offline.event(Level.INFO, 'Image cache of a previous user removed');
      }
      final directory = await Directory(p.join(root.path, owner)).create(recursive: true);
      final index = _Index(owner, directory);
      final now = _clock();
      final stale = <File>[];
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final parsed = _parse(p.basename(entity.path));
        if (parsed == null) {
          stale.add(entity);
          continue;
        }
        final (name, created) = parsed;
        if (now.difference(created) > config.maxAge) {
          stale.add(entity);
          continue;
        }
        final existing = index.entries[name];
        if (existing != null && existing.created.isAfter(created)) {
          stale.add(entity);
          continue;
        }
        final stat = await entity.stat();
        final previous = index.put(name, _Entry(entity, stat.size, created, stat.modified));
        if (previous != null) stale.add(previous.file);
      }
      for (final file in stale) {
        await _delete(file);
      }
      await _evict(index);
      return index;
    } catch (e) {
      _failed('open', e);
      return null;
    }
  }

  Future<void> _evict(_Index index) async {
    if (index.total <= config.maxBytes) return;
    final ordered = index.entries.entries.toList()..sort((a, b) => a.value.accessed.compareTo(b.value.accessed));
    for (final entry in ordered) {
      if (index.total <= config.maxBytes) break;
      index.remove(entry.key);
      await _delete(entry.value.file);
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static String _name(String key) => sha256.convert(utf8.encode(key)).toString();

  static (String, DateTime)? _parse(String basename) {
    final dash = basename.lastIndexOf('-');
    if (dash != 64) return null;
    final millis = int.tryParse(basename.substring(dash + 1));
    if (millis == null) return null;
    return (basename.substring(0, dash), DateTime.fromMillisecondsSinceEpoch(millis));
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      return;
    }
  }

  static void _failed(String operation, Object error) => CommunityLoggers.offline.event(
    Level.WARNING,
    'Image cache operation failed',
    fields: {'operation': operation, 'errorType': error.runtimeType.toString()},
    error: error,
  );
}
