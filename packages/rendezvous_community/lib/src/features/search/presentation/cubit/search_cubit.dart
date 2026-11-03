import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/analytics/domain/services/community_analytics.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/features/search/domain/entities/search_results.dart';
import 'package:rendezvous_community/src/features/search/domain/repositories/search_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'search_cubit.freezed.dart';

final _meaningful = RegExp(r'[\p{L}\p{N}]', unicode: true);

@freezed
abstract class SearchState with _$SearchState {
  const factory SearchState({
    @Default('') String query,
    @Default(SearchType.all) SearchType type,
    @Default(LoadStatus.initial) LoadStatus status,
    SearchResults? results,
    @Default(false) bool loadingMore,
    @Default(false) bool tooShort,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _SearchState;

  const SearchState._();

  bool get hasMore => results?.nextCursor != null;
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required this._search,
    this._feed,
    this._analytics,
    this.minLength = 2,
    this.debounce = const Duration(milliseconds: 300),
    this.pageSize = 20,
    this.previewSize = 5,
  }) : super(const SearchState());

  final SearchRepository _search;
  final FeedRepository? _feed;
  final CommunityAnalytics? _analytics;
  final int minLength;
  final Duration debounce;
  final int pageSize;
  final int previewSize;
  Timer? _timer;
  int _generation = 0;

  void setQuery(String query) {
    if (query == state.query) return;
    _timer?.cancel();
    emit(state.copyWith(query: query));
    _timer = Timer(debounce, () => unawaited(_run()));
  }

  void setType(SearchType type) {
    if (type == state.type) return;
    _timer?.cancel();
    emit(state.copyWith(type: type, results: null));
    unawaited(_run());
  }

  Future<void> submit() async {
    _timer?.cancel();
    await _run();
  }

  Future<void> retry() => _run();

  bool _isSearchable(String query) {
    final text = query.trim();
    return text.length >= minLength && _meaningful.hasMatch(text);
  }

  Future<void> _run() async {
    final generation = ++_generation;
    final query = state.query.trim();
    final type = state.type;
    if (query.isEmpty) {
      emit(state.copyWith(status: LoadStatus.initial, results: null, tooShort: false, error: null));
      return;
    }
    if (!_isSearchable(query)) {
      emit(state.copyWith(status: LoadStatus.initial, results: null, tooShort: true, error: null));
      return;
    }
    emit(state.copyWith(status: LoadStatus.loading, tooShort: false, error: null));
    try {
      final results = await _search.search(query, type: type, limit: type == SearchType.all ? previewSize : pageSize);
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: LoadStatus.ready, results: results));
      _analytics?.record(CommunityAnalyticsEvent.search, {
        'type': type.name,
        'query_length': query.length,
        'result_count': results.count,
      });
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> loadMore() async {
    final results = state.results;
    final cursor = results?.nextCursor;
    if (results == null || cursor == null || state.loadingMore || state.type == SearchType.all) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final next = await _search.search(results.query, type: state.type, cursor: cursor, limit: pageSize);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          loadingMore: false,
          results: results.copyWith(
            posts: [...results.posts, ...next.posts.where((p) => !results.posts.any((x) => x.id == p.id))],
            users: [...results.users, ...next.users.where((u) => !results.users.any((x) => x.user.id == u.user.id))],
            stocks: [...results.stocks, ...next.stocks.where((s) => !results.stocks.any((x) => x.code == s.code))],
            hashtags: [
              ...results.hashtags,
              ...next.hashtags.where((h) => !results.hashtags.any((x) => x.tag == h.tag)),
            ],
            nextCursor: next.nextCursor,
          ),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadingMore: false, actionError: e, actionErrorId: state.actionErrorId + 1));
    }
  }

  Future<void> toggleLike(Post post) async {
    final feed = _feed;
    if (feed == null) return;
    final liked = !post.likedByMe;
    _replace(post.copyWith(likedByMe: liked, likeCount: post.likeCount + (liked ? 1 : -1)));
    try {
      liked ? await feed.likePost(post.id) : await feed.unlikePost(post.id);
    } catch (e) {
      _replace(post);
      if (!isClosed) emit(state.copyWith(actionError: e, actionErrorId: state.actionErrorId + 1));
    }
  }

  void _replace(Post post) {
    final results = state.results;
    if (results == null || isClosed) return;
    emit(state.copyWith(results: results.copyWith(posts: [for (final p in results.posts) p.id == post.id ? post : p])));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
