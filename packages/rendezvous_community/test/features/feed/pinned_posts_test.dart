import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';

import '../../support/fakes.dart';
import '../../support/mock_api.dart';

Post _post(String id, String body, {UserSummary author = alice}) =>
    Post(id: id, author: author, body: body, createdAt: now, cursor: id);

const _official = UserSummary(id: 'acc-1', username: 'olt_research', displayName: 'OLT Research', isVerified: true);

class _PinnedFeed extends FakeFeedRepository {
  _PinnedFeed(this.pinned, this.posts);

  final List<PinnedPost> pinned;
  final List<Post> posts;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async => Paged(posts);

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => scope is GlobalFeedScope ? pinned : const [];
}

Widget _app(Widget child, {OfficialAccounts? official, FakeFeedRepository? feed}) => MaterialApp(
  locale: const Locale('id'),
  localizationsDelegates: CommunityLocalizations.localizationsDelegates,
  supportedLocales: CommunityLocalizations.supportedLocales,
  home: Scaffold(
    body: CommunityScope(
      dependencies: FakeDependencies(feed: feed),
      child: official == null ? child : CommunityOfficialScope(accounts: official, child: child),
    ),
  ),
);

void main() {
  test('getPinned asks for the main or stock stream and maps announcements', () async {
    final api = mockApi();
    when(() => api.rpcRows('get_pinned_posts', any())).thenAnswer(
      (_) async => [
        {'kind': 'announcement', 'title': 'Libur Bursa', 'pinned_until': null, 'post': feedRow('p-9')},
      ],
    );
    final repo = FeedRepositoryImpl(api);

    final pinned = await repo.getPinned(const FeedScope.stock('BBCA'));

    final params = verify(() => api.rpcRows('get_pinned_posts', captureAny())).captured.single;
    expect(params, {'p_scope': 'stock', 'p_stock_code': 'BBCA'});
    expect(pinned.single.announcement, isTrue);
    expect(pinned.single.title, 'Libur Bursa');
    expect(pinned.single.post.id, 'p-9');
    expect(await repo.getPinned(const FeedScope.following()), isEmpty);
  });

  testWidgets('the stream shows announcements on top without repeating them below', (tester) async {
    final announcement = _post('p-1', 'Bursa libur pada 25 Desember.', author: _official);
    final feed = _PinnedFeed(
      [PinnedPost(post: announcement, announcement: true, title: 'Libur Bursa')],
      [announcement, _post('p-2', r'$BBCA naik')],
    );
    await tester.pumpWidget(
      _app(
        const CommunityFeedList(scope: FeedScope.global(), emptyMessage: 'Kosong'),
        feed: feed,
        official: OfficialAccounts(() async => {'acc-1'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pengumuman'), findsOneWidget);
    expect(find.text('Libur Bursa'), findsOneWidget);
    expect(find.text('Bursa libur pada 25 Desember.'), findsOneWidget);
    expect(find.text('Resmi'), findsOneWidget);
    expect(find.textContaining('BBCA naik'), findsOneWidget);
  });

  testWidgets('official accounts get the Official badge instead of a plain check', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            CommunityUserName(user: _official),
            CommunityUserName(
              user: UserSummary(id: 'u-v', username: 'analis', isVerified: true),
            ),
          ],
        ),
        official: OfficialAccounts(() async => {'acc-1'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resmi'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNWidgets(2));
  });

  test('official accounts load once and retry after a failure', () async {
    var calls = 0;
    final official = OfficialAccounts(() async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return {'acc-1'};
    }, retryAfter: Duration.zero);

    official.ensureLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(official.isOfficial('acc-1'), isFalse);

    official.ensureLoaded();
    await Future<void>.delayed(Duration.zero);
    official.ensureLoaded();
    expect(official.isOfficial('acc-1'), isTrue);
    expect(calls, 2);
  });
}
