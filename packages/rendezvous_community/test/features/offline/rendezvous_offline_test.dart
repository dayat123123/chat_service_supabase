import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';

void main() {
  final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': 'u', 'exp': expiresAt}))).replaceAll('=', '');
  final room = {
    'id': 'r1',
    'type': 'direct',
    'created_at': '2026-11-01T00:00:00+00:00',
    'last_read_at': '2026-11-01T00:00:00+00:00',
    'cursor': 'r1',
  };

  late MemoryOfflineStoreFactory stores;
  late Map<String, String> user;
  late bool online;

  setUp(() {
    stores = MemoryOfflineStoreFactory();
    user = {'id': 'u-1', 'username': 'budi_santoso'};
    online = true;
  });

  RendezvousCommunity community({String hostToken = 'olt-budi', bool offlineCache = true}) {
    final instance = RendezvousCommunity.create(
      supabaseUrl: 'http://api.test',
      anonKey: 'anon',
      tokenProvider: () async => hostToken,
      trackDelivery: false,
      offlineCache: offlineCache,
      offlineStores: stores,
      httpClient: MockClient((request) async {
        if (!online) throw http.ClientException('offline', request.url);
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
          '/rest/v1/rpc/get_my_rooms' => http.Response(jsonEncode([room]), 200, request: request),
          '/rest/v1/rpc/delete_my_account' => http.Response('', 204, request: request),
          _ => http.Response('[]', 200, request: request),
        };
      }),
    );
    addTearDown(instance.dispose);
    return instance;
  }

  Future<List<String>> cachedRoomIds(RendezvousCommunity c) async => [
    for (final r in await c.chatCache!.cachedRooms()) r.id,
  ];

  test('rooms are cached per user and survive an offline restart of the same host user', () async {
    final first = community();
    await first.ensureSignedIn();
    await first.chat.getRooms();
    await pumpEventQueue();
    expect(await cachedRoomIds(first), ['r1']);
    expect(stores.stores.keys, ['u-1']);

    online = false;
    final restarted = community();
    await expectLater(restarted.ensureSignedIn(), throwsA(isA<CommunityException>()));
    expect(restarted.connectivity.isOnline, isFalse);
    expect(await cachedRoomIds(restarted), ['r1']);
    expect((await restarted.chatCache!.cachedUser())?.id, 'u-1');

    final stranger = community(hostToken: 'olt-sari');
    expect(await stranger.chatCache!.cachedRooms(), isEmpty);
    expect(stores.stores, isEmpty, reason: 'another host user removes the previous user data');
  });

  test('signing out wipes the local database and the next user starts empty', () async {
    final c = community();
    await c.ensureSignedIn();
    await c.chat.getRooms();
    await c.signOut();
    expect(stores.stores, isEmpty);

    user = {'id': 'u-2', 'username': 'sari'};
    await c.ensureSignedIn();
    await pumpEventQueue();
    expect(await c.chatCache!.cachedRooms(), isEmpty);
    expect(stores.stores.keys, ['u-2']);
  });

  test('deleting the account and clearLocalCache wipe the local database', () async {
    final c = community();
    await c.ensureSignedIn();
    await c.chat.getRooms();
    await c.clearLocalCache();
    expect(await c.chatCache!.cachedRooms(), isEmpty);

    await c.chat.getRooms();
    expect(await cachedRoomIds(c), ['r1']);
    await c.deleteMyAccount();
    expect(stores.stores, isEmpty);
  });

  test('offlineCache: false keeps the previous online-only behaviour', () async {
    final c = community(offlineCache: false);
    await c.ensureSignedIn();
    await c.chat.getRooms();
    expect(c.offlineCacheEnabled, isFalse);
    expect(c.chatCache, isNull);
    expect(c.feedCache, isNull);
    expect(c.outbox, isNull);
    expect(stores.stores, isEmpty);
  });
}
