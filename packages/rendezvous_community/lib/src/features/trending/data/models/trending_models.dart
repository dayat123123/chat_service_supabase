import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';

part 'trending_models.freezed.dart';
part 'trending_models.g.dart';

@freezed
abstract class HashtagSummaryModel with _$HashtagSummaryModel {
  const factory HashtagSummaryModel({
    required String tag,
    int? postCount,
    @JsonKey(name: 'posts_7d') int? posts7d,
    @Default(0) int authorCount,
    @Default(0) num score,
  }) = _HashtagSummaryModel;

  const HashtagSummaryModel._();

  factory HashtagSummaryModel.fromJson(Map<String, dynamic> json) => _$HashtagSummaryModelFromJson(json);

  HashtagSummary toEntity() =>
      HashtagSummary(tag: tag, postCount: postCount ?? posts7d ?? 0, authorCount: authorCount, score: score.toDouble());
}

@freezed
abstract class TrendingStockModel with _$TrendingStockModel {
  const factory TrendingStockModel({
    required String code,
    @Default(0) int posts,
    @Default(0) num score,
    num? bullishPct,
    num? bearishPct,
    num? neutralPct,
    num? growthPct,
  }) = _TrendingStockModel;

  const TrendingStockModel._();

  factory TrendingStockModel.fromJson(Map<String, dynamic> json) => _$TrendingStockModelFromJson(json);

  TrendingStock toEntity() => TrendingStock(
    code: code,
    posts: posts,
    score: score.toDouble(),
    bullishPct: bullishPct?.round(),
    bearishPct: bearishPct?.round(),
    neutralPct: neutralPct?.round(),
    growthPct: growthPct?.toDouble(),
  );
}

@freezed
abstract class RisingStockModel with _$RisingStockModel {
  const factory RisingStockModel({
    required String code,
    @Default(0) int posts,
    @Default(0) int prevPosts,
    num? growthPct,
  }) = _RisingStockModel;

  const RisingStockModel._();

  factory RisingStockModel.fromJson(Map<String, dynamic> json) => _$RisingStockModelFromJson(json);

  RisingStock toEntity() =>
      RisingStock(code: code, posts: posts, prevPosts: prevPosts, growthPct: growthPct?.toDouble());
}

@freezed
abstract class SentimentBreakdownModel with _$SentimentBreakdownModel {
  const factory SentimentBreakdownModel({
    @Default(0) int posts,
    @Default(0) int bullish,
    @Default(0) int bearish,
    @Default(0) int neutral,
    @Default(0) int unlabeled,
    num? bullishPct,
    num? bearishPct,
    num? neutralPct,
  }) = _SentimentBreakdownModel;

  const SentimentBreakdownModel._();

  factory SentimentBreakdownModel.fromJson(Map<String, dynamic> json) => _$SentimentBreakdownModelFromJson(json);

  SentimentBreakdown toEntity() => SentimentBreakdown(
    posts: posts,
    bullish: bullish,
    bearish: bearish,
    neutral: neutral,
    unlabeled: unlabeled,
    bullishPct: bullishPct?.round(),
    bearishPct: bearishPct?.round(),
    neutralPct: neutralPct?.round(),
  );
}
