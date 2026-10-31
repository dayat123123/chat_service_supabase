import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'feed_cubit.freezed.dart';

@freezed
abstract class FeedState with _$FeedState {
  const factory FeedState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<Post>[]) List<Post> posts,
    String? nextCursor,
    @Default(false) bool loadingMore,
    @Default(0) int newPosts,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _FeedState;
}

class FeedCubit extends Cubit<FeedState> {
  FeedCubit({required this._feed, required this.scope, this.currentUserId, this.pageSize = 20})
    : super(const FeedState());

  final FeedRepository _feed;
  final FeedScope scope;
  final String? Function()? currentUserId;
  final int pageSize;
  StreamSubscription<PostChange>? _changes;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final page = await _feed.getFeed(scope, limit: pageSize);
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.ready, posts: page.items, nextCursor: page.nextCursor, newPosts: 0));
      _listen();
    } catch (e) {
      final mapped = mapError(e);
      CommunityLoggers.feed.event(
        Level.WARNING,
        'Failed to load feed',
        fields: {'scope': scope, 'kind': mapped.kind, 'code': mapped.code},
      );
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> refresh() async {
    if (state.status != LoadStatus.ready) return load();
    try {
      final page = await _feed.getFeed(scope, limit: pageSize);
      if (!isClosed) emit(state.copyWith(posts: page.items, nextCursor: page.nextCursor, newPosts: 0));
    } catch (e) {
      _actionError(e);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.status != LoadStatus.ready) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _feed.getFeed(scope, cursor: cursor, limit: pageSize);
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
    final current = state.posts.firstWhere((p) => p.id == post.id, orElse: () => post);
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

  void insertOwnPost(Post post) {
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
    emit(state.copyWith(posts: [for (final p in state.posts) p.id == post.id ? post : p]));
  }

  void _actionError(Object error) {
    if (!isClosed) emit(state.copyWith(actionError: error, actionErrorId: state.actionErrorId + 1));
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
