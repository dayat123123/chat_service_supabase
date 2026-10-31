import 'package:olt_social/src/features/stocks/domain/entities/stock.dart';

abstract interface class StockRepository {
  Future<Stock?> getStock(String code);

  Future<void> watch(String code);

  Future<void> unwatch(String code);
}
