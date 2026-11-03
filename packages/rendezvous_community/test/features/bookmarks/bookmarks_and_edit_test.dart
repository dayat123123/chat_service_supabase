import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import 'package:rendezvous_community/src/features/edit/data/repositories/content_edit_repository_impl.dart';
import 'package:rendezvous_community/src/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:rendezvous_community/src/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/community_feed_list.dart';
import 'package:rendezvous_community/src/features/post/presentation/cubit/comment_thread_cubit.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

void main() {
  group('repositories', () {
    test('toggle_bookmark sends the desired state and get_bookmarks pages with the bookmark cursor', () async {
      final api = mockApi();
      when(() => api.rpcValue('toggle_bookmark', any())).thenAnswer((_) async => true);
      when(
        () => api.rpcRows('get_bookmarks', any()),
      ).thenAnswer((_) async => [feedRow('p-1', cursor: 'b1')..['is_bookmarked'] = true]);
      final repository = BookmarkRepositoryImpl(api);

      expect(await repository.setBookmarked('p-1', bookmarked: true), isTrue);
      verify(() => api.rpcValue('toggle_bookmark', {'p_post_id': 'p-1', 'p_bookmarked': true})).called(1);
      final page = await repository.getBookmarks(limit: 1);
      expect(page.nextCursor, 'b1');
      expect(page.items.single.isBookmarked, isTrue);
    });

    test('edit_post and edit_comment return the edited rows', () async {
      final api = mockApi();
      when(
        () => api.rpcRows('edit_post', any()),
      ).thenAnswer((_) async => [feedRow('p-1')..['edited_at'] = '2026-11-03T05:00:00Z']);
      when(
        () => api.rpcRows('edit_comment', any()),
      ).thenAnswer((_) async => [commentRow('c-1')..['moderation_status'] = 'held']);
      final repository = ContentEditRepositoryImpl(api);

      expect((await repository.editPost('p-1', 'baru')).editedAt, DateTime.utc(2026, 11, 3, 5));
      verify(() => api.rpcRows('edit_post', {'p_post_id': 'p-1', 'p_body': 'baru'})).called(1);
      expect((await repository.editComment('c-1', 'baru')).isHeld, isTrue);
    });

    test('feed rows map the new columns, including own moderation status', () async {
      final api = mockApi();
      when(() => api.rpcRows('get_post', any())).thenAnswer(
        (_) async => [
          feedRow('p-1')
            ..['is_bookmarked'] = true
            ..['hashtags'] = ['dividen']
            ..['is_bot'] = true
            ..['author_is_official'] = true
            ..['moderation_status'] = 'hidden',
        ],
      );
      final post = (await FeedRepositoryImpl(api).getPost('p-1'))!;
      expect(post.isBookmarked, isTrue);
      expect(post.hashtags, ['dividen']);
      expect(post.isBot, isTrue);
      expect(post.authorIsOfficial, isTrue);
      expect(post.isHidden, isTrue);
    });
  });

  group('FeedCubit', () {
    late FakeBookmarkRepository bookmarks;
    late FakeEditRepository edits;
    late _PagedFeed feed;

    setUp(() {
      bookmarks = FakeBookmarkRepository();
      edits = FakeEditRepository();
      feed = _PagedFeed([samplePost(id: 'p-1'), samplePost(id: 'p-2', bookmarked: true)]);
    });

    test('bookmark toggles optimistically and rolls back on failure', () async {
      final cubit = FeedCubit(feed: feed, scope: const FeedScope.global(), bookmarks: bookmarks);
      await cubit.load();
      await cubit.toggleBookmark(cubit.state.posts.first);
      expect(cubit.state.posts.first.isBookmarked, isTrue);
      expect(bookmarks.calls.single, ('p-1', true));

      bookmarks.error = const CommunityException(CommunityErrorKind.network);
      await cubit.toggleBookmark(cubit.state.posts.first);
      expect(cubit.state.posts.first.isBookmarked, isTrue);
      expect(cubit.state.actionErrorId, 1);
      await cubit.close();
    });

    test('the bookmarks list drops a post when it is unbookmarked', () async {
      final cubit = FeedCubit(
        feed: feed,
        scope: const FeedScope.global(),
        loader: (cursor, limit) async => Paged([samplePost(id: 'p-2', bookmarked: true)]),
        bookmarks: bookmarks,
        removeOnUnbookmark: true,
      );
      await cubit.load();
      expect(cubit.state.pinned, isEmpty);
      await cubit.toggleBookmark(cubit.state.posts.single);
      expect(cubit.state.posts, isEmpty);
      expect(bookmarks.calls.single, ('p-2', false));
      await cubit.close();
    });

    test('editPost replaces the post but keeps its list cursor', () async {
      final cubit = FeedCubit(feed: feed, scope: const FeedScope.global(), edits: edits);
      await cubit.load();
      expect(await cubit.editPost(cubit.state.posts.first, '  Isi baru  '), isTrue);
      expect(edits.posts.single, ('p-1', 'Isi baru'));
      expect(cubit.state.posts.first.body, 'Isi baru');
      expect(cubit.state.posts.first.editedAt, isNotNull);
      expect(cubit.state.posts.first.cursor, 'c-p-1');
      await cubit.close();
    });
  });

  test('CommentThreadCubit edits a comment in place', () async {
    final edits = FakeEditRepository();
    final cubit = CommentThreadCubit(
      feed: FakeFeedRepository(),
      comments: FakeCommentRepository(),
      postId: 'p-1',
      edits: edits,
    );
    await cubit.load();
    final target = cubit.state.comments['c1']!;
    expect(await cubit.editComment(target, 'Diubah'), isTrue);
    expect(cubit.state.comments['c1']!.body, 'Diubah');
    expect(cubit.state.comments['c1']!.editedAt, isNotNull);
    await cubit.close();
  });

  group('post menu', () {
    Future<void> openMenu(WidgetTester tester, Post post, FakeFeatureDependencies features) async {
      final feed = _PagedFeed([post]);
      await pumpFeatureApp(
        tester,
        CommunityFeedList(scope: const FeedScope.global(), emptyMessage: 'kosong'),
        dependencies: FakeDependencies(feed: feed),
        features: features,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
    }

    testWidgets('own fresh posts can be edited, bookmarked, and shared', (tester) async {
      final features = FakeFeatureDependencies(
        config: loadedConfig().copyWith(editWindow: const Duration(minutes: 15)),
      );
      addTearDown(features.dispose);
      await openMenu(tester, samplePost(), features);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Simpan'), findsWidgets);
      expect(find.text('Kirim ke chat'), findsOneWidget);
    });

    testWidgets('the edit item disappears after the window and when the flag is off', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig(flags: {'post_edit': true, 'bookmarks': false}));
      addTearDown(features.dispose);
      await openMenu(
        tester,
        samplePost(createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 20))),
        features,
      );
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Simpan'), findsNothing);
    });

    testWidgets('bot and official labels are shown on posts', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        FeedPostCard(
          post: samplePost(author: alice).copyWith(isBot: true, authorIsOfficial: true),
          cubit: FeedCubit(feed: _PagedFeed(const []), scope: const FeedScope.global()),
        ),
        features: features,
      );
      await tester.pump();
      expect(find.text('Bot'), findsOneWidget);
      expect(find.text('Resmi'), findsOneWidget);
    });

    testWidgets('own held and hidden posts carry a moderation label; hidden ones can be appealed', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      final cubit = FeedCubit(feed: _PagedFeed(const []), scope: const FeedScope.global());
      await pumpFeatureApp(
        tester,
        Column(
          children: [
            FeedPostCard(
              post: samplePost(id: 'h-1').copyWith(moderationStatus: ModerationStatus.held),
              cubit: cubit,
            ),
            FeedPostCard(
              post: samplePost(id: 'h-2').copyWith(moderationStatus: ModerationStatus.hidden),
              cubit: cubit,
            ),
          ],
        ),
        features: features,
      );
      await tester.pump();
      expect(find.text('Menunggu tinjauan'), findsOneWidget);
      expect(find.text('Disembunyikan moderator'), findsOneWidget);
      await tester.tap(find.text('Ajukan banding'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Postingan ini analisis biasa, bukan promosi.');
      await tester.pump();
      await tester.tap(find.text('Kirim banding'));
      await tester.pumpAndSettle();
      expect(features.appeals.created.single.$1, AppealTargetType.post);
      expect(features.appeals.created.single.$2, 'h-2');
    });
  });
}

class _PagedFeed extends FakeFeedRepository {
  _PagedFeed(this.posts);

  final List<Post> posts;

  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async => Paged(posts);

  @override
  Future<List<PinnedPost>> getPinned(FeedScope scope) async => const [];
}
