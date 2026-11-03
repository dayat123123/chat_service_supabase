import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rendezvous_community/src/core/storage/community_database.dart';
import 'package:rendezvous_community/src/core/storage/drift_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';

OfflineStoreFactory platformOfflineStores() => FileOfflineStoreFactory();

class FileOfflineStoreFactory implements OfflineStoreFactory {
  FileOfflineStoreFactory({Future<Directory> Function()? root}) : _root = root ?? getApplicationSupportDirectory;

  static const _folder = 'rendezvous_community';
  static const _extension = '.sqlite';
  static const _sidecars = ['', '-wal', '-shm', '-journal'];

  final Future<Directory> Function() _root;

  Future<Directory> _directory() async {
    final directory = Directory(p.join((await _root()).path, _folder));
    return directory.create(recursive: true);
  }

  @override
  Future<List<String>> keys() async {
    final directory = await _directory();
    return [
      for (final entity in directory.listSync().whereType<File>())
        if (entity.path.endsWith(_extension)) p.basenameWithoutExtension(entity.path),
    ];
  }

  @override
  Future<OfflineStore> open(String key) async {
    final file = File(p.join((await _directory()).path, '$key$_extension'));
    return DriftOfflineStore(CommunityDatabase(NativeDatabase.createInBackground(file)));
  }

  @override
  Future<void> delete(String key) async {
    final base = p.join((await _directory()).path, '$key$_extension');
    for (final suffix in _sidecars) {
      final file = File('$base$suffix');
      if (file.existsSync()) await file.delete();
    }
  }
}
