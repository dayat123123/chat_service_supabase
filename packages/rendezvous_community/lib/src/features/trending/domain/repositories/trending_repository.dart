import 'package:rendezvous_community/src/features/trending/domain/entities/trending.dart';

abstract interface class TrendingRepository {
  Future<TrendingSnapshot> trending({TrendWindow window = TrendWindow.day});

  Future<StockSentiment> stockSentiment(String stockCode);
}
