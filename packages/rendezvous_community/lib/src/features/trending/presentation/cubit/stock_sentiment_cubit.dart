import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/features/trending/domain/repositories/trending_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'stock_sentiment_cubit.freezed.dart';

@freezed
abstract class StockSentimentState with _$StockSentimentState {
  const factory StockSentimentState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(TrendWindow.day) TrendWindow window,
    StockSentiment? sentiment,
    Object? error,
  }) = _StockSentimentState;

  const StockSentimentState._();

  SentimentBreakdown? get current => sentiment?.of(window);
}

class StockSentimentCubit extends Cubit<StockSentimentState> {
  StockSentimentCubit(this._trending, {required this.stockCode, TrendWindow window = TrendWindow.day})
    : super(StockSentimentState(window: window));

  final TrendingRepository _trending;
  final String stockCode;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final sentiment = await _trending.stockSentiment(stockCode);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, sentiment: sentiment));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  void setWindow(TrendWindow window) => emit(state.copyWith(window: window));
}
