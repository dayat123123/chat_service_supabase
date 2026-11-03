import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/features/chat/data/local/chat_local_cache.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:rendezvous_community/src/features/feed/data/local/feed_local_cache.dart';
import 'package:rendezvous_community/src/features/feed/data/repositories/feed_repository_impl.dart';

import '../../../support/mock_api.dart';

Map<String, dynamic> _room(String id, {String type = 'direct'}) => {
  'id': id,
  'type': type,
  'name': null,
  'created_at': '2026-11-01T00:00:00+00:00',
  'last_read_at': '2026-11-01T00:00:00+00:00',
  'last_message_preview': 'Halo',
  'cursor': id,
};

Map<String, dynamic> _message(
  String id,
  int minute, {
  String body = 'Halo',
  bool deleted = false,
  String? moderation,
  List<Map<String, dynamic>>? reactions,
}) => {
  'id': id,
  'room_id': 'r1',
  'sender_id': 'u-2',
  'sender_username': 'sari',
  'body': deleted ? null : body,
  'is_deleted': deleted,
  'attachments': <Object?>[],
  'client_id': 'c-$id',
  'created_at': DateTime.utc(2026, 11, 3, 9, minute).toIso8601String(),
  'cursor': '${DateTime.utc(2026, 11, 3, 9, minute).toIso8601String()}|$id',
  'moderation_status': moderation,
  'reactions': reactions,
};

void main() {
  late MockApi api;
  late OfflineCache offline;
  late ChatLocalCache cache;
  late ChatRepositoryImpl chat;

  setUp(() {
    api = mockApi();
    offline = OfflineCache(
      MemoryOfflineStoreFactory(),
      currentUserId: () => 'u-1',
      resolveHostKey: () async => null,
      messageLimit: 4,
    );
    cache = ChatLocalCache(offline);
    chat = ChatRepositoryImpl(api, null, cache);
  });

  tearDown(() => offline.dispose());

  void serveMessages(List<Map<String, dynamic>> rows, {String? cursor}) => when(
    () => api.rpcRows('get_messages', any(that: containsPair('p_cursor', cursor))),
  ).thenAnswer((_) async => rows);

  test('the first page of rooms is cached without support rooms; later pages leave it alone', () async {
    when(
      () => api.rpcRows('get_my_rooms', any()),
    ).thenAnswer((_) async => [_room('r1'), _room('cs', type: 'support'), _room('r2', type: 'stock')]);
    await chat.getRooms(limit: 3);
    expect([for (final r in await cache.cachedRooms()) r.id], ['r1', 'r2']);

    when(() => api.rpcRows('get_my_rooms', any())).thenAnswer((_) async => [_room('r9')]);
    await chat.getRooms(cursor: 'r2');
    expect([for (final r in await cache.cachedRooms()) r.id], ['r1', 'r2']);
  });

  test('a refreshed page reconciles edits, deletions, reactions, moderation and vanished messages', () async {
    serveMessages([_message('m3', 3), _message('m2', 2), _message('m1', 1)]);
    await chat.getMessages('r1', limit: 30);
    expect([for (final m in await cache.cachedMessages('r1')) m.id], ['m3', 'm2', 'm1']);

    serveMessages([
      _message(
        'm3',
        3,
        body: 'Halo (diedit)',
        reactions: [
          {'emoji': '👍', 'count': 2, 'me': true},
        ],
      ),
      _message('m1', 1, deleted: true),
    ]);
    await chat.getMessages('r1', limit: 30);

    final cached = await cache.cachedMessages('r1');
    expect([for (final m in cached) m.id], ['m3', 'm1']);
    expect(cached.first.body, 'Halo (diedit)');
    expect(cached.first.reactions.single.count, 2);
    expect(cached.last.isDeleted, isTrue);

    serveMessages([_message('m3', 3, moderation: 'hidden')]);
    await chat.getMessages('r1', limit: 1);
    final hidden = await cache.cachedMessages('r1');
    expect(hidden.first.moderationStatus, ModerationStatus.hidden);
    expect([for (final m in hidden) m.id], ['m3', 'm1'], reason: 'older rows outside the page window stay');
  });

  test('older pages, newer pages and sent messages are merged and pruned to the newest N per room', () async {
    serveMessages([_message('m6', 6), _message('m5', 5)]);
    await chat.getMessages('r1', limit: 2);
    serveMessages([_message('m4', 4), _message('m3', 3)], cursor: 'm5-cursor');
    await chat.getMessages('r1', cursor: 'm5-cursor', limit: 2);
    when(() => api.rpcRows('send_message', any())).thenAnswer((_) async => [_message('m7', 7)]);
    await chat.sendMessage('r1', body: 'Halo', clientId: 'c-m7');

    expect([for (final m in await cache.cachedMessages('r1')) m.id], ['m7', 'm6', 'm5', 'm4']);
  });

  test('leaving a room forgets its cached summary and messages', () async {
    when(() => api.rpcRows('get_my_rooms', any())).thenAnswer((_) async => [_room('r1')]);
    when(() => api.rpcValue('leave_room', any())).thenAnswer((_) async => null);
    serveMessages([_message('m1', 1)]);
    await chat.getRooms();
    await chat.getMessages('r1');

    await chat.leaveRoom('r1');
    expect(await cache.cachedRooms(), isEmpty);
    expect(await cache.cachedMessages('r1'), isEmpty);
  });

  test('the first feed page is cached per scope; profile feeds and later pages are not', () async {
    final feedCache = FeedLocalCache(offline);
    final feed = FeedRepositoryImpl(api, null, feedCache);
    when(() => api.rpcRows('get_feed', any())).thenAnswer((_) async => [feedRow('p1'), feedRow('p2')]);

    await feed.getFeed(const FeedScope.global());
    await feed.getFeed(const FeedScope.stock('bbca'));
    await feed.getFeed(const FeedScope.user('u-9'));
    when(() => api.rpcRows('get_feed', any())).thenAnswer((_) async => [feedRow('p9')]);
    await feed.getFeed(const FeedScope.global(), cursor: 'c');

    expect([for (final p in (await feedCache.cachedFeed(const FeedScope.global()))!) p.id], ['p1', 'p2']);
    expect(await feedCache.cachedFeed(const FeedScope.stock('BBCA')), hasLength(2));
    expect(await feedCache.cachedFeed(const FeedScope.following()), isNull);
    expect(await feedCache.cachedFeed(const FeedScope.user('u-9')), isNull);
  });
}
