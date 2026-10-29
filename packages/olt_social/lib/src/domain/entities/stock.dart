import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock.freezed.dart';

/// Jenis instrumen: saham atau indeks (IHSG, LQ45, ...).
enum StockType { stock, marketIndex }

/// Saham atau indeks IDX.
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
