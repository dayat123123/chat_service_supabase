import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/src/features/stocks/domain/entities/stock.dart';

part 'stock_model.freezed.dart';
part 'stock_model.g.dart';

@freezed
abstract class StockModel with _$StockModel {
  const factory StockModel({
    required String code,
    required String name,
    @Default('stock') String type,
    String? sector,
    @Default(0) int watcherCount,
  }) = _StockModel;

  const StockModel._();

  factory StockModel.fromJson(Map<String, dynamic> json) => _$StockModelFromJson(json);

  Stock toEntity() => Stock(
    code: code,
    name: name,
    type: type == 'index' ? StockType.marketIndex : StockType.stock,
    sector: sector,
    watcherCount: watcherCount,
  );
}
