import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock.freezed.dart';

enum StockType { stock, marketIndex }

@freezed
abstract class Stock with _$Stock {
  const factory Stock({
    required String code,
    required String name,
    @Default(StockType.stock) StockType type,
    String? sector,
    @Default(0) int watcherCount,
  }) = _Stock;
}
