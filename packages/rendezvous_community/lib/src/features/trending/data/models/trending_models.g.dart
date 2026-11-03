// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trending_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HashtagSummaryModel _$HashtagSummaryModelFromJson(Map<String, dynamic> json) => _HashtagSummaryModel(
  tag: json['tag'] as String,
  postCount: (json['post_count'] as num?)?.toInt(),
  posts7d: (json['posts_7d'] as num?)?.toInt(),
  authorCount: (json['author_count'] as num?)?.toInt() ?? 0,
  score: json['score'] as num? ?? 0,
);

Map<String, dynamic> _$HashtagSummaryModelToJson(_HashtagSummaryModel instance) => <String, dynamic>{
  'tag': instance.tag,
  'post_count': instance.postCount,
  'posts_7d': instance.posts7d,
  'author_count': instance.authorCount,
  'score': instance.score,
};

_TrendingStockModel _$TrendingStockModelFromJson(Map<String, dynamic> json) => _TrendingStockModel(
  code: json['code'] as String,
  posts: (json['posts'] as num?)?.toInt() ?? 0,
  score: json['score'] as num? ?? 0,
  bullishPct: json['bullish_pct'] as num?,
  bearishPct: json['bearish_pct'] as num?,
  neutralPct: json['neutral_pct'] as num?,
  growthPct: json['growth_pct'] as num?,
);

Map<String, dynamic> _$TrendingStockModelToJson(_TrendingStockModel instance) => <String, dynamic>{
  'code': instance.code,
  'posts': instance.posts,
  'score': instance.score,
  'bullish_pct': instance.bullishPct,
  'bearish_pct': instance.bearishPct,
  'neutral_pct': instance.neutralPct,
  'growth_pct': instance.growthPct,
};

_RisingStockModel _$RisingStockModelFromJson(Map<String, dynamic> json) => _RisingStockModel(
  code: json['code'] as String,
  posts: (json['posts'] as num?)?.toInt() ?? 0,
  prevPosts: (json['prev_posts'] as num?)?.toInt() ?? 0,
  growthPct: json['growth_pct'] as num?,
);

Map<String, dynamic> _$RisingStockModelToJson(_RisingStockModel instance) => <String, dynamic>{
  'code': instance.code,
  'posts': instance.posts,
  'prev_posts': instance.prevPosts,
  'growth_pct': instance.growthPct,
};

_SentimentBreakdownModel _$SentimentBreakdownModelFromJson(Map<String, dynamic> json) => _SentimentBreakdownModel(
  posts: (json['posts'] as num?)?.toInt() ?? 0,
  bullish: (json['bullish'] as num?)?.toInt() ?? 0,
  bearish: (json['bearish'] as num?)?.toInt() ?? 0,
  neutral: (json['neutral'] as num?)?.toInt() ?? 0,
  unlabeled: (json['unlabeled'] as num?)?.toInt() ?? 0,
  bullishPct: json['bullish_pct'] as num?,
  bearishPct: json['bearish_pct'] as num?,
  neutralPct: json['neutral_pct'] as num?,
);

Map<String, dynamic> _$SentimentBreakdownModelToJson(_SentimentBreakdownModel instance) => <String, dynamic>{
  'posts': instance.posts,
  'bullish': instance.bullish,
  'bearish': instance.bearish,
  'neutral': instance.neutral,
  'unlabeled': instance.unlabeled,
  'bullish_pct': instance.bullishPct,
  'bearish_pct': instance.bearishPct,
  'neutral_pct': instance.neutralPct,
};
