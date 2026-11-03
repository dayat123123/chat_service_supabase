import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/search/domain/repositories/search_repository.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'trending_hashtags_cubit.freezed.dart';

@freezed
abstract class TrendingHashtagsState with _$TrendingHashtagsState {
  const factory TrendingHashtagsState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(TrendWindow.day) TrendWindow window,
    @Default(<HashtagSummary>[]) List<HashtagSummary> hashtags,
    Object? error,
  }) = _TrendingHashtagsState;
}

class TrendingHashtagsCubit extends Cubit<TrendingHashtagsState> {
  TrendingHashtagsCubit(this._search, {this.limit = 10}) : super(const TrendingHashtagsState());

  final SearchRepository _search;
  final int limit;

  Future<void> load({TrendWindow? window}) async {
    final target = window ?? state.window;
    emit(state.copyWith(status: LoadStatus.loading, window: target, error: null));
    try {
      final hashtags = await _search.trendingHashtags(window: target, limit: limit);
      if (!isClosed && state.window == target) emit(state.copyWith(status: LoadStatus.ready, hashtags: hashtags));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }
}
