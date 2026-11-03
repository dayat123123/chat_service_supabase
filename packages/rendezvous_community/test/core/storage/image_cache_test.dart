import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/file_image_disk_cache.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';

Uint8List _bytes(int length, [int value = 1]) => Uint8List.fromList(List.filled(length, value));

class _RecordingDisk implements ImageDiskCache {
  final reads = <String>[];
  final writes = <String>[];
  int wipes = 0;

  @override
  Future<Uint8List?> read(String key) async {
    reads.add(key);
    return null;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async => writes.add(key);

  @override
  Future<void> wipe() async => wipes++;
}

void main() {
  group('cache keys', () {
    test('signed and authenticated storage URLs map to bucket and path', () {
      const a = 'http://api.test/storage/v1/object/sign/attachments/rooms/r1/u1/x.jpg?token=aaa.bbb.ccc';
      const b = 'http://api.test/storage/v1/object/sign/attachments/rooms/r1/u1/x.jpg?token=zzz.yyy.xxx';
      const c = 'http://api.test/storage/v1/object/authenticated/attachments/rooms/r1/u1/x.jpg';
      expect(imageCacheKeyForUrl(a), 'storage:attachments/rooms/r1/u1/x.jpg');
      expect(imageCacheKeyForUrl(b), imageCacheKeyForUrl(a));
      expect(imageCacheKeyForUrl(c), imageCacheKeyForUrl(a));
      expect(imageCacheKeyForObject('attachments', 'rooms/r1/u1/x.jpg'), imageCacheKeyForUrl(a));
    });

    test('presigned query parameters are dropped and the rest is sorted', () {
      const first = 'https://cdn.test/a.png?w=200&X-Amz-Signature=abc&X-Amz-Date=1&b=2&Expires=10';
      const second = 'https://cdn.test/a.png?b=2&X-Amz-Signature=def&w=200&X-Amz-Date=2&Expires=99#frag';
      expect(imageCacheKeyForUrl(first), 'https://cdn.test/a.png?b=2&w=200');
      expect(imageCacheKeyForUrl(second), imageCacheKeyForUrl(first));
      expect(imageCacheKeyForUrl('https://cdn.test/a.png'), 'https://cdn.test/a.png');
    });
  });

  group('FileImageDiskCache', () {
    late Directory root;
    late String? owner;
    late DateTime clock;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('rc-images-');
      owner = 'u-1';
      clock = DateTime(2026, 11, 3, 10);
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    FileImageDiskCache cache({int maxBytes = 1000, Duration maxAge = const Duration(days: 30)}) => FileImageDiskCache(
      root: () async => root,
      owner: () async => owner,
      config: CommunityImageCacheConfig(maxBytes: maxBytes, maxAge: maxAge),
      clock: () => clock,
    );

    Directory userDir(String id) =>
        Directory(p.join(root.path, FileImageDiskCache.folder, FileImageDiskCache.imagesFolder, id));

    test('stores bytes per user and reloads them in a new instance', () async {
      await cache().write('storage:attachments/a.jpg', _bytes(10));
      expect(userDir('u-1').listSync(), hasLength(1));

      final reopened = cache();
      expect(await reopened.read('storage:attachments/a.jpg'), _bytes(10));
      expect(await reopened.read('storage:attachments/missing.jpg'), isNull);
    });

    test('evicts the least recently used images once the byte budget is exceeded', () async {
      final c = cache(maxBytes: 250);
      await c.write('a', _bytes(100));
      clock = clock.add(const Duration(minutes: 2));
      await c.write('b', _bytes(100));
      clock = clock.add(const Duration(minutes: 2));
      expect(await c.read('a'), isNotNull);
      clock = clock.add(const Duration(minutes: 2));
      await c.write('c', _bytes(100));

      expect(await c.read('b'), isNull);
      expect(await c.read('a'), isNotNull);
      expect(await c.read('c'), isNotNull);
      expect(c.totalBytes, 200);
      expect(userDir('u-1').listSync(), hasLength(2));
    });

    test('skips images larger than the whole budget', () async {
      final c = cache(maxBytes: 50);
      await c.write('big', _bytes(51));
      expect(await c.read('big'), isNull);
    });

    test('expires images older than maxAge, also after a restart', () async {
      final c = cache(maxAge: const Duration(days: 1));
      await c.write('a', _bytes(10));
      await c.write('b', _bytes(10));
      clock = clock.add(const Duration(days: 2));
      expect(await c.read('a'), isNull);

      final reopened = cache(maxAge: const Duration(days: 1));
      expect(await reopened.read('b'), isNull);
      expect(userDir('u-1').listSync(), isEmpty);
    });

    test('a different user never sees and removes the previous user images', () async {
      final c = cache();
      await c.write('storage:attachments/rooms/r1/secret.jpg', _bytes(10));
      owner = 'u-2';
      expect(await c.read('storage:attachments/rooms/r1/secret.jpg'), isNull);
      expect(userDir('u-1').existsSync(), isFalse);
      expect(userDir('u-2').existsSync(), isTrue);
    });

    test('no signed-in owner means no disk access', () async {
      owner = null;
      final c = cache();
      await c.write('a', _bytes(10));
      expect(await c.read('a'), isNull);
      expect(Directory(p.join(root.path, FileImageDiskCache.folder)).existsSync(), isFalse);
    });

    test('wipe removes every cached image', () async {
      final c = cache();
      await c.write('a', _bytes(10));
      await c.wipe();
      expect(
        Directory(p.join(root.path, FileImageDiskCache.folder, FileImageDiskCache.imagesFolder)).existsSync(),
        isFalse,
      );
      expect(await c.read('a'), isNull);
    });
  });

  group('CommunityImageLoader', () {
    test('serves the disk copy before the network and stores network results', () async {
      final disk = _RecordingDisk();
      var requests = 0;
      final headers = <Map<String, String>>[];
      final loader = CommunityImageLoader(
        disk: disk,
        client: MockClient((request) async {
          requests++;
          headers.add(request.headers);
          return http.Response.bytes(_bytes(4), 200);
        }),
      );

      final bytes = await loader.load(
        cacheKey: 'storage:attachments/a.jpg',
        resolve: () async => const AuthorizedImage('http://api.test/a.jpg', {'Authorization': 'Bearer t'}),
      );
      await loader.settled();

      expect(bytes, _bytes(4));
      expect(requests, 1);
      expect(headers.single['Authorization'], 'Bearer t');
      expect(disk.reads, ['storage:attachments/a.jpg']);
      expect(disk.writes, ['storage:attachments/a.jpg']);
    });

    test('non-persistent images never touch the disk', () async {
      final disk = _RecordingDisk();
      final loader = CommunityImageLoader(
        disk: disk,
        client: MockClient((request) async => http.Response.bytes(_bytes(4), 200)),
      );
      await loader.load(
        cacheKey: 'storage:cs-documents/rooms/r1/a.pdf',
        resolve: () async => const AuthorizedImage('http://api.test/a', {}),
        persist: false,
      );
      await pumpEventQueue();
      expect(disk.reads, isEmpty);
      expect(disk.writes, isEmpty);
    });

    test('failed responses throw and are not cached', () async {
      final disk = _RecordingDisk();
      final loader = CommunityImageLoader(
        disk: disk,
        client: MockClient((request) async => http.Response('denied', 403)),
      );
      await expectLater(
        loader.load(cacheKey: 'k', resolve: () async => const AuthorizedImage('http://api.test/a', {})),
        throwsA(isA<CommunityImageLoadException>()),
      );
      expect(disk.writes, isEmpty);
    });
  });
}
