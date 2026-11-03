import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/auth/host_identity.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/offline_cache.dart';

String _jwt(Map<String, Object?> claims) =>
    'eyJhbGciOiJFZERTQSJ9.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.c2ln';

void main() {
  const budi = UserSummary(id: 'u-1', username: 'budi_santoso', displayName: 'Budi');
  const sari = UserSummary(id: 'u-2', username: 'sari');
  late MemoryOfflineStoreFactory stores;
  late String? userId;
  late String? hostKey;
  late OfflineCache cache;

  setUp(() {
    stores = MemoryOfflineStoreFactory();
    userId = null;
    hostKey = null;
    cache = OfflineCache(stores, currentUserId: () => userId, resolveHostKey: () async => hostKey);
  });

  tearDown(() => cache.dispose());

  Future<List<Map<String, dynamic>>> rooms() async => await cache.read((s) => s.readRooms()) ?? const [];

  test('host identity keys use the token subject and issuer, not the rotating token', () {
    final first = hostIdentityKey(_jwt({'iss': 'olt', 'sub': 'cust-1', 'exp': 1}));
    expect(first, hostIdentityKey(_jwt({'iss': 'olt', 'sub': 'cust-1', 'exp': 2})));
    expect(first, isNot(hostIdentityKey(_jwt({'iss': 'olt', 'sub': 'cust-2', 'exp': 1}))));
    expect(first, isNot(contains('cust-1')));
    expect(hostIdentityKey('mock:u-1:budi'), hostIdentityKey('mock:u-1:budi'));
    expect(hostIdentityKey(_jwt({'iss': 'olt'})), isNull);
    expect(hostIdentityKey(null), isNull);
    expect(hostIdentityKey(''), isNull);
  });

  test('without a session or a known host identity nothing is stored or read', () async {
    await cache.write(
      (s) => s.replaceRooms([
        {'id': 'r1'},
      ]),
    );
    expect(await rooms(), isEmpty);
    expect(stores.stores, isEmpty);
  });

  test('each user gets an own database and switching users removes the previous one', () async {
    userId = budi.id;
    await cache.write(
      (s) => s.replaceRooms([
        {'id': 'r-budi'},
      ]),
    );
    expect(stores.stores.keys, ['u-1']);

    userId = sari.id;
    expect(await rooms(), isEmpty);
    expect(stores.stores.keys, ['u-2']);

    userId = budi.id;
    expect(await rooms(), isEmpty);
  });

  test('wipe deletes every local database and the next session starts empty', () async {
    userId = budi.id;
    await cache.write(
      (s) => s.replaceRooms([
        {'id': 'r1'},
      ]),
    );
    await cache.wipe();
    expect(stores.stores, isEmpty);
    expect(await rooms(), isEmpty);
  });

  test('offline start opens the database of the same host user and reports the cached owner', () async {
    userId = budi.id;
    await cache.remember(budi, hostKey: 'host-budi');
    await cache.write(
      (s) => s.replaceRooms([
        {'id': 'r1'},
      ]),
    );
    await cache.dispose();

    cache = OfflineCache(stores, currentUserId: () => null, resolveHostKey: () async => 'host-budi');
    expect(await rooms(), [
      {'id': 'r1'},
    ]);
    expect(await cache.owner(), budi);
  });

  test('offline start for a different host user deletes the previous user data', () async {
    userId = budi.id;
    await cache.remember(budi, hostKey: 'host-budi');
    await cache.dispose();

    cache = OfflineCache(stores, currentUserId: () => null, resolveHostKey: () async => 'host-sari');
    expect(await rooms(), isEmpty);
    expect(await cache.owner(), isNull);
    expect(stores.stores, isEmpty);
  });

  test('store errors are swallowed so server flows keep working', () async {
    userId = budi.id;
    await cache.write((_) async => throw StateError('disk full'));
    await expectLater(cache.read<int>((_) async => throw StateError('corrupt')), completion(isNull));
    await cache.write(
      (s) => s.replaceRooms([
        {'id': 'r1'},
      ]),
    );
    expect(await rooms(), hasLength(1));
  });
}
