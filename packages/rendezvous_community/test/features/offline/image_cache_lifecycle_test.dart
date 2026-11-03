import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/file_image_disk_cache.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';

void main() {
  final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': 'u', 'exp': expiresAt}))).replaceAll('=', '');
  final image = Uint8List.fromList(List.filled(16, 7));

  late Directory root;
  late Map<String, String> user;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rc-image-life-');
    user = {'id': 'u-1', 'username': 'budi_santoso'};
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Directory images() => Directory(p.join(root.path, FileImageDiskCache.folder, FileImageDiskCache.imagesFolder));

  List<String> owners() =>
      images().existsSync() ? [for (final entity in images().listSync()) p.basename(entity.path)] : const [];

  RendezvousCommunity community() {
    late RendezvousCommunity instance;
    instance = RendezvousCommunity.create(
      supabaseUrl: 'http://api.test',
      anonKey: 'anon',
      tokenProvider: () async => 'olt-host',
      trackDelivery: false,
      offlineStores: MemoryOfflineStoreFactory(),
      imageDiskCache: FileImageDiskCache(root: () async => root, owner: () async => instance.currentUser?.id),
      httpClient: MockClient((request) async {
        return switch (request.url.path) {
          '/bridge/v1/exchange' => http.Response(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.c2lnbmF0dXJl',
              'expires_at': expiresAt,
              'user': user,
            }),
            200,
            request: request,
          ),
          '/rest/v1/rpc/delete_my_account' => http.Response('', 204, request: request),
          '/storage/v1/object/authenticated/attachments/rooms/r1/u-2/a.jpg' => http.Response.bytes(image, 200),
          _ => http.Response('[]', 200, request: request),
        };
      }),
    );
    addTearDown(instance.dispose);
    return instance;
  }

  Future<void> cacheAttachment(RendezvousCommunity c) async {
    await c.images.load(
      cacheKey: 'storage:attachments/rooms/r1/u-2/a.jpg',
      resolve: () => c.media.attachmentImage(const Attachment(path: 'rooms/r1/u-2/a.jpg')),
    );
    await c.images.settled();
  }

  test('chat attachments are cached in the signed-in user directory', () async {
    final c = community();
    await c.ensureSignedIn();
    await cacheAttachment(c);
    expect(owners(), ['u-1']);
    expect(Directory(p.join(images().path, 'u-1')).listSync(), hasLength(1));
  });

  test('signOut wipes cached images and the next user starts with an empty directory', () async {
    final c = community();
    await c.ensureSignedIn();
    await cacheAttachment(c);
    await c.signOut();
    expect(owners(), isEmpty);

    user = {'id': 'u-2', 'username': 'sari'};
    await c.ensureSignedIn();
    await cacheAttachment(c);
    expect(owners(), ['u-2']);
  });

  test('deleteMyAccount and clearLocalCache wipe cached images', () async {
    final c = community();
    await c.ensureSignedIn();
    await cacheAttachment(c);
    await c.clearLocalCache();
    expect(owners(), isEmpty);

    await cacheAttachment(c);
    expect(owners(), ['u-1']);
    await c.deleteMyAccount();
    expect(owners(), isEmpty);
  });

  test('offlineCache: false keeps images in memory only', () async {
    final c = RendezvousCommunity.create(
      supabaseUrl: 'http://api.test',
      anonKey: 'anon',
      tokenProvider: () async => 'olt-host',
      trackDelivery: false,
      offlineCache: false,
      imageDiskCache: FileImageDiskCache(root: () async => root, owner: () async => 'u-1'),
      httpClient: MockClient((request) async => http.Response.bytes(image, 200)),
    );
    addTearDown(c.dispose);
    await c.images.load(cacheKey: 'k', resolve: () async => const AuthorizedImage('http://api.test/a.jpg', {}));
    await c.images.settled();
    expect(owners(), isEmpty);
  });
}
