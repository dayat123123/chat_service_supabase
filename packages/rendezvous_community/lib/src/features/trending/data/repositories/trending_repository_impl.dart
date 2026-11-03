import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/feed/data/models/feed_post_model.dart';
import 'package:rendezvous_community/src/features/trending/data/models/trending_models.dart';
import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';
import 'package:rendezvous_community/src/features/trending/domain/repositories/trending_repository.dart';

class TrendingRepositoryImpl implements TrendingRepository {
  TrendingRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<TrendingSnapshot> trending({TrendWindow window = TrendWindow.day}) async {
    final json = jsonMap(await _api.rpcValue('get_trending', {'p_window': window.value}));
    return TrendingSnapshot(
      window: window,
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? ''),
      stocks: [for (final row in jsonList(json['stocks'])) TrendingStockModel.fromJson(row).toEntity()],
      rising: [for (final row in jsonList(json['rising'])) RisingStockModel.fromJson(row).toEntity()],
      posts: [for (final row in jsonList(json['posts'])) FeedPostModel.fromJson(row).toEntity()],
      hashtags: [for (final row in jsonList(json['hashtags'])) HashtagSummaryModel.fromJson(row).toEntity()],
    );
  }

  @override
  Future<StockSentiment> stockSentiment(String stockCode) async {
    final code = stockCode.toUpperCase();
    final json = jsonMap(await _api.rpcValue('get_stock_sentiment', {'p_code': code}));
    return StockSentiment(
      code: json['code'] as String? ?? code,
      day: SentimentBreakdownModel.fromJson(jsonMap(json['24h'])).toEntity(),
      week: SentimentBreakdownModel.fromJson(jsonMap(json['7d'])).toEntity(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
