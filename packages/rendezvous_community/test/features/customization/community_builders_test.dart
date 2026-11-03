import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_official_badge.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';

import '../../support/fakes.dart';

class _Feed extends FakeFeedRepository {
  _Feed(this.posts, {this.pinned = const []});

  final List<Post> posts;
  final List<PinnedPost> pinned;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async => Paged(posts);

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => pinned;
}

class _Notifications extends FakeNotificationRepository {
  _Notifications(this.items);

  final List<AppNotification> items;
  final marked = <List<String>?>[];

  @override
  Future<Paged<AppNotification>> getNotifications({String? cursor, int limit = 30}) async => Paged(items);

  @override
  Future<int> unreadCount() async => items.where((n) => !n.isRead).length;

  @override
  Future<void> markRead({List<String>? ids}) async => marked.add(ids);
}

class _Profiles extends Fake implements ProfileRepository {
  _Profiles(this.profile);

  UserProfile profile;
  final followed = <String>[];

  @override
  Future<UserProfile?> getProfile({String? userId, String? username}) async => profile;

  @override
  Future<void> follow(String userId) async => followed.add(userId);
}

class _Deps extends FakeDependencies {
  _Deps({super.feed, super.notifications, this._profiles});

  final ProfileRepository? _profiles;

  @override
  ProfileRepository get profiles => _profiles ?? super.profiles;
}

Post _post(String id, {UserSummary author = alice, String body = 'Isi', Poll? poll, bool isBot = false}) =>
    Post(id: id, author: author, body: body, createdAt: now, cursor: id, poll: poll, isBot: isBot, likeCount: 2);

Future<void> _pump(WidgetTester tester, Widget child, {CommunityDependencies? deps}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      home: Scaffold(
        body: CommunityScope(dependencies: deps ?? FakeDependencies(), child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _label(BuildContext context, CommunityLabelBadgeDetails d, Widget fallback) => Text('badge:${d.kind.name}');

void main() {
  group('feed builders', () {
    testWidgets('post parts get display-ready details and wired handlers', (tester) async {
      final feed = _Feed([_post('p-1', body: 'Halo pasar')]);
      await _pump(
        tester,
        CommunityFeedList(
          scope: const FeedScope.global(),
          emptyMessage: 'Kosong',
          builders: CommunityFeedBuilders(
            postHeader: (context, d, fallback) => Text('header ${d.post.author.username} ${d.timeLabel.isNotEmpty}'),
            postBody: (context, d, fallback) => Text('body ${d.post.body}'),
            actionBar: (context, d, fallback) =>
                TextButton(onPressed: d.onLike, child: Text('suka ${d.post.likeCount} ${d.onReport != null}')),
            stockTags: (context, d, fallback) => const Text('tags'),
          ),
        ),
        deps: _Deps(feed: feed),
      );

      expect(find.text('header alice true'), findsOneWidget);
      expect(find.text('body Halo pasar'), findsOneWidget);
      expect(find.text('tags'), findsOneWidget);
      await tester.tap(find.text('suka 2 true'));
      await tester.pumpAndSettle();
      expect(feed.likes, ['p-1']);
    });

    testWidgets('the post card builder can replace the whole card and fall back per post', (tester) async {
      final feed = _Feed([_post('p-1', body: 'Satu'), _post('p-2', body: 'Dua', author: me)]);
      await _pump(
        tester,
        CommunityFeedList(
          scope: const FeedScope.global(),
          emptyMessage: 'Kosong',
          builders: CommunityFeedBuilders(
            postCard: (context, d, fallback) => d.isMine
                ? fallback
                : ListTile(title: Text('kartu ${d.post.body}'), subtitle: Text('hapus ${d.onDelete != null}')),
          ),
        ),
        deps: _Deps(feed: feed),
      );

      expect(find.text('kartu Satu'), findsOneWidget);
      expect(find.text('hapus false'), findsOneWidget);
      expect(find.textContaining('Dua'), findsOneWidget);
      expect(find.text('kartu Dua'), findsNothing);
    });

    testWidgets('pinned marker, poll, empty and error parts', (tester) async {
      final poll = Poll(
        endsAt: now.add(const Duration(days: 1)),
        closed: false,
        totalVotes: 3,
        resultsVisible: true,
        options: const [
          PollOption(id: 'a', label: 'Naik'),
          PollOption(id: 'b', label: 'Turun'),
        ],
      );
      final pinned = _post('p-9', body: 'Pengumuman libur', poll: poll);
      await _pump(
        tester,
        CommunityFeedList(
          scope: const FeedScope.global(),
          emptyMessage: 'Kosong',
          builders: CommunityFeedBuilders(
            pinnedMarker: (context, d, fallback) => Text('pin ${d.announcement} ${d.title}'),
            poll: (context, d, fallback) => Text('poll ${d.poll.options.length} ${d.canVote} ${d.onVote != null}'),
          ),
        ),
        deps: _Deps(
          feed: _Feed(
            const [],
            pinned: [PinnedPost(post: pinned, announcement: true, title: 'Libur')],
          ),
        ),
      );
      expect(find.text('pin true Libur'), findsOneWidget);
      expect(find.text('poll 2 true true'), findsOneWidget);

      await _pump(
        tester,
        CommunityFeedList(
          key: const ValueKey('empty'),
          scope: const FeedScope.following(),
          emptyMessage: 'Belum ada',
          builders: CommunityFeedBuilders(empty: (context, d, fallback) => Text('kosong: ${d.message}')),
        ),
        deps: _Deps(feed: _Feed(const [])),
      );
      expect(find.text('kosong: Belum ada'), findsOneWidget);

      await _pump(
        tester,
        CommunityFeedList(
          key: const ValueKey('error'),
          scope: const FeedScope.following(),
          emptyMessage: 'Belum ada',
          builders: CommunityFeedBuilders(
            error: (context, d, fallback) =>
                TextButton(onPressed: d.onRetry, child: Text('gagal ${d.message.isNotEmpty}')),
          ),
        ),
        deps: _Deps(feed: FakeFeedRepository()),
      );
      expect(find.text('gagal true'), findsOneWidget);
    });

    testWidgets('defaults are unchanged when no builder is installed', (tester) async {
      final feed = _Feed([_post('p-1', body: 'Default')]);
      await _pump(
        tester,
        const CommunityFeedList(scope: FeedScope.global(), emptyMessage: 'Kosong'),
        deps: _Deps(feed: feed),
      );
      expect(find.text('Default'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    });
  });

  group('notification builders', () {
    final items = [
      AppNotification(id: 'n-1', type: NotificationType.like, actor: alice, createdAt: now, cursor: 'n-1'),
      AppNotification(id: 'n-2', type: NotificationType.follow, actor: bob, createdAt: now, cursor: 'n-2'),
    ];

    testWidgets('item and header builders receive titles and handlers', (tester) async {
      final notifications = _Notifications(items);
      await _pump(
        tester,
        CommunityNotificationList(
          onNotificationTap: (_, _) {},
          builders: CommunityNotificationBuilders(
            header: (context, d, fallback) =>
                TextButton(onPressed: d.onMarkAllRead, child: Text('${d.title} ${d.unread}')),
            item: (context, d, fallback) => TextButton(onPressed: d.onTap, child: Text('item ${d.title}')),
          ),
        ),
        deps: _Deps(notifications: notifications),
      );

      expect(find.textContaining('item Alice'), findsOneWidget);
      expect(find.textContaining('item Bob'), findsOneWidget);
      await tester.tap(find.textContaining('item Alice'));
      await tester.pumpAndSettle();
      expect(notifications.marked, [
        ['n-1'],
      ]);
    });

    testWidgets('empty builder', (tester) async {
      await _pump(
        tester,
        CommunityNotificationList(
          builders: CommunityNotificationBuilders(empty: (context, d, fallback) => Text('nihil ${d.message}')),
        ),
        deps: _Deps(notifications: _Notifications(const [])),
      );
      expect(find.textContaining('nihil '), findsOneWidget);
    });
  });

  group('profile builders', () {
    testWidgets('stats and follow button builders with a working follow handler', (tester) async {
      final profiles = _Profiles(
        UserProfile(
          user: alice,
          followerCount: 10,
          followingCount: 2,
          postCount: 5,
          createdAt: now,
          isMe: false,
          isFollowing: false,
          followsMe: false,
          isBlocked: false,
        ),
      );
      await _pump(
        tester,
        CommunityUserProfile(
          userId: alice.id,
          builders: CommunityProfileBuilders(
            stats: (context, d, fallback) => Text('stat ${d.profile.followerCount}/${d.profile.postCount}'),
            followButton: (context, d, fallback) =>
                TextButton(onPressed: d.onToggleFollow, child: Text('ikuti ${d.isFollowing}')),
          ),
        ),
        deps: _Deps(feed: _Feed(const []), profiles: profiles),
      );

      expect(find.text('stat 10/5'), findsOneWidget);
      await tester.tap(find.text('ikuti false'));
      await tester.pumpAndSettle();
      expect(profiles.followed, [alice.id]);
      expect(find.text('ikuti true'), findsOneWidget);
    });

    testWidgets('the header builder replaces the whole header', (tester) async {
      final profiles = _Profiles(
        UserProfile(
          user: alice,
          followerCount: 1,
          followingCount: 1,
          postCount: 1,
          createdAt: now,
          isMe: true,
          isFollowing: false,
          followsMe: false,
          isBlocked: false,
        ),
      );
      await _pump(
        tester,
        CommunityUserProfile(
          userId: alice.id,
          builders: CommunityProfileBuilders(
            header: (context, d, fallback) => Text('profil ${d.profile.user.username} ${d.onEdit != null}'),
          ),
        ),
        deps: _Deps(feed: _Feed(const []), profiles: profiles),
      );
      expect(find.text('profil alice true'), findsOneWidget);
    });
  });

  group('badge builders', () {
    testWidgets('one label builder reshapes every label badge', (tester) async {
      const verified = UserSummary(id: 'v', username: 'v', isVerified: true);
      await _pump(
        tester,
        CommunityBadgeBuildersScope(
          builders: CommunityBadgeBuilders(
            label: _label,
            verified: (context, d, fallback) => Text('verified ${d.user.username}'),
            count: (context, d, fallback) => Text('count ${d.kind.name} ${d.label}'),
            countOverlay: (context, d, fallback) => Row(children: [d.child, Text('overlay ${d.kind.name} ${d.count}')]),
          ),
          child: const Column(
            children: [
              CommunityOfficialBadge(),
              CommunityBotBadge(),
              RoomModeratorBadge(),
              OfficialBadge(color: Colors.blue),
              SentimentBadge(sentiment: Sentiment.bullish),
              CommunityUserName(user: verified),
              CommunityCountBadge(count: 120),
              CommunityCountOverlay(kind: CommunityCountKind.notificationUnread, count: 3, child: Icon(Icons.home)),
            ],
          ),
        ),
      );

      expect(find.text('badge:official'), findsOneWidget);
      expect(find.text('badge:bot'), findsOneWidget);
      expect(find.text('badge:roomModerator'), findsOneWidget);
      expect(find.text('badge:supportOfficial'), findsOneWidget);
      expect(find.text('badge:sentimentBullish'), findsOneWidget);
      expect(find.text('verified v'), findsOneWidget);
      expect(find.text('count roomUnread 99+'), findsOneWidget);
      expect(find.text('overlay notificationUnread 3'), findsOneWidget);
    });

    testWidgets('a specific builder wins over the generic label builder', (tester) async {
      await _pump(
        tester,
        CommunityBadgeBuildersScope(
          builders: CommunityBadgeBuilders(label: _label, bot: (context, d, fallback) => Text('robot ${d.label}')),
          child: const Column(children: [CommunityBotBadge(), CommunityOfficialBadge()]),
        ),
      );
      expect(find.text('robot Bot'), findsOneWidget);
      expect(find.text('badge:official'), findsOneWidget);
    });

    testWidgets('the chat unread badge uses the overlay builder', (tester) async {
      final chat = FakeChatRepository()..unreadChats = 4;
      await _pump(
        tester,
        CommunityBadgeBuildersScope(
          builders: CommunityBadgeBuilders(
            countOverlay: (context, d, fallback) => Text('chat ${d.kind.name} ${d.label}'),
          ),
          child: const CommunityChatBadge(child: Icon(Icons.chat)),
        ),
        deps: FakeDependencies(chat: chat, notifications: FakeNotificationRepository()),
      );
      expect(find.text('chat chatUnread 4'), findsOneWidget);
    });
  });

  group('CommunityBuilders', () {
    testWidgets('nested scopes merge every builder set', (tester) async {
      final feed = _Feed([_post('p-1', body: 'Bot bicara', isBot: true)]);
      await _pump(
        tester,
        const CommunityBuildersScope(
          builders: CommunityBuilders(
            badges: CommunityBadgeBuilders(label: _label),
            chat: CommunityChatBuilders(stockCard: _stock),
          ),
          child: CommunityBuildersScope(
            builders: CommunityBuilders(feed: CommunityFeedBuilders(postBody: _body)),
            child: _Probe(
              child: CommunityFeedList(scope: FeedScope.global(), emptyMessage: 'Kosong'),
            ),
          ),
        ),
        deps: _Deps(feed: feed),
      );

      expect(find.text('badge:bot'), findsOneWidget);
      expect(find.text('isi Bot bicara'), findsOneWidget);
      expect(_Probe.seen?.chat.stockCard, same(_stock));
      expect(_Probe.seen?.badges.label, same(_label));
      expect(_Probe.seen?.feed.postBody, same(_body));
    });

    test('merge keeps the parent slot unless the child sets it', () {
      const parent = CommunityBuilders(
        notifications: CommunityNotificationBuilders(item: _item),
        profile: CommunityProfileBuilders(stats: _stats),
      );
      final merged = parent.merge(const CommunityBuilders(profile: CommunityProfileBuilders(header: _stats)));
      expect(merged.notifications.item, same(_item));
      expect(merged.profile.stats, same(_stats));
      expect(merged.profile.header, same(_stats));
    });
  });
}

Widget _stock(BuildContext context, CommunityStockCardDetails d, Widget fallback) => Text(d.code);

Widget _body(BuildContext context, CommunityPostDetails d, Widget fallback) => Text('isi ${d.post.body}');

Widget _item(BuildContext context, CommunityNotificationDetails d, Widget fallback) => fallback;

Widget _stats(BuildContext context, CommunityProfileDetails d, Widget fallback) => fallback;

class _Probe extends StatelessWidget {
  const _Probe({required this.child});

  static CommunityBuilders? seen;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    seen = CommunityBuilders.of(context);
    return child;
  }
}
