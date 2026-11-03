import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/network/community_connectivity.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:rendezvous_community/src/features/edit/domain/repositories/content_edit_repository.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/pinned_post.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_cache_repository.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'feed_cubit.freezed.dart';

typedef PostPageLoader = Future<Paged<Post>> Function(String? cursor, int limit);

@freezed
abstract class FeedState with _$FeedState {
  const factory FeedState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<Post>[]) List<Post> posts,
    @Default(<PinnedPost>[]) List<PinnedPost> pinned,
    String? nextCursor,
    @Default(false) bool loadingMore,
    @Default(0) int newPosts,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
    @Default(false) bool stale,
  }) = _FeedState;
}

class FeedCubit extends Cubit<FeedState> {
  FeedCubit({
    required this._feed,
    required this.scope,
    this.currentUserId,
    this.pageSize = 20,
    this._loader,
    this._bookmarks,
    this._edits,
    this.removeOnUnbookmark = false,
    this._cache,
    this._connectivity,
  }) : super(const FeedState());

  final FeedCacheRepository? _cache;
  final CommunityConnectivity? _connectivity;
  StreamSubscription<bool>? _onlineChanges;

  final FeedRepository _feed;
  final FeedScope scope;
  final String? Function()? currentUserId;
  final int pageSize;
  final PostPageLoader? _loader;
  final BookmarkRepository? _bookmarks;
  final ContentEditRepository? _edits;
  final bool removeOnUnbookmark;
  StreamSubscription<PostChange>? _changes;

  bool get isCustomSource => _loader != null;

  bool get canBookmark => _bookmarks != null;

  bool get canEdit => _edits != null;

  Future<Paged<Post>> _page({String? cursor}) {
    final loader = _loader;
    return loader == null ? _feed.getFeed(scope, cursor: cursor, limit: pageSize) : loader(cursor, pageSize);
  }

  Future<void> load() async {
    if (!(state.status == LoadStatus.ready && state.stale)) {
      emit(state.copyWith(status: LoadStatus.loading, error: null));
      _onlineChanges ??= _connectivity?.changes.listen((online) {
        if (online && state.stale && !isClosed) unawaited(load());
      });
      await _showCached();
    }
    try {
      final (page, pinned) = await (_page(), _pinned()).wait;
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          posts: page.items,
          nextCursor: page.nextCursor,
          pinned: pinned,
          newPosts: 0,
          stale: false,
        ),
      );
      _listen();
    } catch (e) {
      final mapped = mapError(e);
      CommunityLoggers.feed.event(
        Level.WARNING,
        'Failed to load feed',
        fields: {'scope': scope, 'kind': mapped.kind, 'code': mapped.code},
      );
      if (isClosed || (state.status == LoadStatus.ready && state.stale)) return;
      emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> _showCached() async {
    final cache = _cache;
    if (cache == null || isCustomSource) return;
    final posts = await cache.cachedFeed(scope);
    if (posts == null || posts.isEmpty || isClosed || state.status == LoadStatus.ready) return;
    emit(state.copyWith(status: LoadStatus.ready, posts: posts, nextCursor: null, stale: true));
  }

  Future<void> refresh() async {
    if (state.status != LoadStatus.ready || state.stale) return load();
    try {
      final page = await _page();
      final pinned = await _pinned();
      if (!isClosed) {
        emit(state.copyWith(posts: page.items, nextCursor: page.nextCursor, pinned: pinned, newPosts: 0));
      }
    } catch (e) {
      _actionError(e);
    }
  }

  Future<List<PinnedPost>> _pinned() async {
    if (isCustomSource) return const [];
    try {
      return await _feed.getPinned(scope);
    } catch (_) {
      return state.pinned;
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.status != LoadStatus.ready) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _page(cursor: cursor);
      if (isClosed) return;
      final known = {for (final p in state.posts) p.id};
      emit(
        state.copyWith(
          posts: [...state.posts, ...page.items.where((p) => !known.contains(p.id))],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadingMore: false));
      _actionError(e);
    }
  }

  Future<void> toggleLike(Post post) async {
    final current = state.posts.firstWhere(
      (p) => p.id == post.id,
      orElse: () => state.pinned.map((pin) => pin.post).firstWhere((p) => p.id == post.id, orElse: () => post),
    );
    final liked = !current.likedByMe;
    _replace(current.copyWith(likedByMe: liked, likeCount: current.likeCount + (liked ? 1 : -1)));
    try {
      liked ? await _feed.likePost(post.id) : await _feed.unlikePost(post.id);
    } catch (e) {
      _replace(current);
      _actionError(e);
    }
  }

  Future<void> delete(Post post) async {
    final before = state.posts;
    emit(
      state.copyWith(
        posts: [
          for (final p in before)
            if (p.id != post.id) p,
        ],
      ),
    );
    try {
      await _feed.deletePost(post.id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(posts: before));
      _actionError(e);
    }
  }

  Future<void> toggleBookmark(Post post) async {
    final bookmarks = _bookmarks;
    if (bookmarks == null) return;
    final current = _find(post);
    final next = !current.isBookmarked;
    final before = state.posts;
    if (!next && removeOnUnbookmark) {
      emit(
        state.copyWith(
          posts: [
            for (final p in state.posts)
              if (p.id != post.id) p,
          ],
        ),
      );
    } else {
      _replace(current.copyWith(isBookmarked: next));
    }
    try {
      final saved = await bookmarks.setBookmarked(post.id, bookmarked: next);
      if (saved != next && !isClosed) {
        emit(state.copyWith(posts: before));
        _replace(current.copyWith(isBookmarked: saved));
      }
    } catch (e) {
      if (!isClosed) emit(state.copyWith(posts: before));
      _replace(current);
      _actionError(e);
    }
  }

  Future<bool> editPost(Post post, String body) async {
    final edits = _edits;
    final text = body.trim();
    if (edits == null || text.isEmpty) return false;
    try {
      final updated = await edits.editPost(post.id, text);
      replacePost(updated.copyWith(cursor: _find(post).cursor));
      return true;
    } catch (e) {
      _actionError(e);
      return false;
    }
  }

  void replacePost(Post post) => _replace(post);

  Post _find(Post post) => state.posts.firstWhere(
    (p) => p.id == post.id,
    orElse: () => state.pinned.map((pin) => pin.post).firstWhere((p) => p.id == post.id, orElse: () => post),
  );

  void insertOwnPost(Post post) {
    if (isCustomSource) return;
    if (!_matchesScope(authorId: post.author.id, body: post.body)) return;
    if (state.posts.any((p) => p.id == post.id)) return;
    emit(state.copyWith(posts: [post, ...state.posts]));
  }

  void hideAuthor(String userId) => emit(
    state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.author.id != userId) p,
      ],
    ),
  );

  void _listen() {
    _changes ??= _feed.watchPosts().listen((change) {
      if (isClosed) return;
      switch (change) {
        case PostInserted():
          if (isCustomSource) return;
          final mine = change.authorId == currentUserId?.call();
          final known = state.posts.any((p) => p.id == change.postId);
          if (mine || known || scope is FollowingFeedScope) return;
          if (_matchesScope(authorId: change.authorId, body: change.body)) {
            emit(state.copyWith(newPosts: state.newPosts + 1));
          }
        case PostUpdated():
          if (change.deleted) {
            emit(
              state.copyWith(
                posts: [
                  for (final p in state.posts)
                    if (p.id != change.postId) p,
                ],
              ),
            );
          } else {
            final index = state.posts.indexWhere((p) => p.id == change.postId);
            if (index >= 0) {
              final p = state.posts[index];
              _replace(p.copyWith(likeCount: change.likeCount, commentCount: change.commentCount));
            }
          }
      }
    }, onError: (Object _) {});
  }

  bool _matchesScope({required String authorId, required String body}) => switch (scope) {
    GlobalFeedScope() => true,
    FollowingFeedScope() => true,
    StockFeedScope(:final code) => extractCashtags(body).contains(code.toUpperCase()),
    UserFeedScope(:final userId) => authorId == userId,
  };

  void _replace(Post post) {
    if (isClosed) return;
    emit(
      state.copyWith(
        posts: [for (final p in state.posts) p.id == post.id ? post : p],
        pinned: [for (final pin in state.pinned) pin.post.id == post.id ? pin.copyWith(post: post) : pin],
      ),
    );
  }

  void _actionError(Object error) {
    if (!isClosed) emit(state.copyWith(actionError: error, actionErrorId: state.actionErrorId + 1));
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    await _onlineChanges?.cancel();
    return super.close();
  }
}
