import 'package:olt_social/src/features/stocks/domain/entities/stock.dart';

abstract interface class StockRepository {
  Future<Stock?> getStock(String code);

  Future<List<Stock>> searchStocks(String query, {int limit = 8});

  Future<bool> isWatching(String code);

  Future<void> watch(String code);

  Future<void> unwatch(String code);
}
