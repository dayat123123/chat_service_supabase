import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/feed/presentation/cubit/feed_cubit.dart';

import '../../support/fakes.dart';

const _network = CommunityException(CommunityErrorKind.network);

Post _post(String id) => Post(id: id, author: alice, body: 'Post $id', createdAt: now, cursor: id);

class _Feed extends FakeFeedRepository {
  bool online = false;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async {
    if (!online) throw _network;
    return Paged([_post('fresh')]);
  }

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => const [];
}

class _FeedCache implements FeedCacheRepository {
  final scopes = <FeedScope>[];

  @override
  Future<List<Post>?> cachedFeed(FeedScope scope) async {
    scopes.add(scope);
    return [_post('cached-1'), _post('cached-2')];
  }
}

void main() {
  late _Feed feed;
  late _FeedCache cache;
  late CommunityConnectivity connectivity;

  setUp(() {
    feed = _Feed();
    cache = _FeedCache();
    connectivity = CommunityConnectivity();
  });

  tearDown(() => connectivity.dispose());

  test('the cached first page is shown offline and replaced by the server when back online', () async {
    final cubit = FeedCubit(feed: feed, scope: const FeedScope.global(), cache: cache, connectivity: connectivity);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, LoadStatus.ready);
    expect(cubit.state.stale, isTrue);
    expect([for (final p in cubit.state.posts) p.id], ['cached-1', 'cached-2']);
    expect(cubit.state.nextCursor, isNull);

    feed.online = true;
    connectivity.report(reachable: false);
    connectivity.report(reachable: true);
    await pumpEventQueue();
    expect(cubit.state.stale, isFalse);
    expect([for (final p in cubit.state.posts) p.id], ['fresh']);
  });

  test('custom sources such as hashtags and bookmarks never use the feed cache', () async {
    final cubit = FeedCubit(
      feed: feed,
      scope: const FeedScope.global(),
      cache: cache,
      loader: (cursor, limit) async => throw _network,
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, LoadStatus.failure);
    expect(cache.scopes, isEmpty);
  });
}
