import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';

part 'trending.freezed.dart';

enum TrendWindow {
  day('24h'),
  week('7d');

  const TrendWindow(this.value);

  final String value;
}

@freezed
abstract class HashtagSummary with _$HashtagSummary {
  const factory HashtagSummary({
    required String tag,
    @Default(0) int postCount,
    @Default(0) int authorCount,
    @Default(0) double score,
  }) = _HashtagSummary;
}

@freezed
abstract class TrendingStock with _$TrendingStock {
  const factory TrendingStock({
    required String code,
    @Default(0) int posts,
    @Default(0) double score,
    int? bullishPct,
    int? bearishPct,
    int? neutralPct,
    double? growthPct,
  }) = _TrendingStock;
}

@freezed
abstract class RisingStock with _$RisingStock {
  const factory RisingStock({
    required String code,
    @Default(0) int posts,
    @Default(0) int prevPosts,
    double? growthPct,
  }) = _RisingStock;
}

@freezed
abstract class TrendingSnapshot with _$TrendingSnapshot {
  const factory TrendingSnapshot({
    required TrendWindow window,
    DateTime? computedAt,
    @Default(<TrendingStock>[]) List<TrendingStock> stocks,
    @Default(<RisingStock>[]) List<RisingStock> rising,
    @Default(<Post>[]) List<Post> posts,
    @Default(<HashtagSummary>[]) List<HashtagSummary> hashtags,
  }) = _TrendingSnapshot;
}

@freezed
abstract class SentimentBreakdown with _$SentimentBreakdown {
  const factory SentimentBreakdown({
    @Default(0) int posts,
    @Default(0) int bullish,
    @Default(0) int bearish,
    @Default(0) int neutral,
    @Default(0) int unlabeled,
    int? bullishPct,
    int? bearishPct,
    int? neutralPct,
  }) = _SentimentBreakdown;

  const SentimentBreakdown._();

  bool get hasLabels => bullishPct != null || bearishPct != null || neutralPct != null;
}

@freezed
abstract class StockSentiment with _$StockSentiment {
  const factory StockSentiment({
    required String code,
    @Default(SentimentBreakdown()) SentimentBreakdown day,
    @Default(SentimentBreakdown()) SentimentBreakdown week,
    DateTime? updatedAt,
  }) = _StockSentiment;

  const StockSentiment._();

  SentimentBreakdown of(TrendWindow window) => window == TrendWindow.day ? day : week;
}
