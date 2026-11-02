import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock.dart';

part 'stock_model.freezed.dart';
part 'stock_model.g.dart';

@freezed
abstract class StockModel with _$StockModel {
  const factory StockModel({required String code, @Default(0) int watcherCount, @Default(false) bool watching}) =
      _StockModel;

  const StockModel._();

  factory StockModel.fromJson(Map<String, dynamic> json) => _$StockModelFromJson(json);

  Stock toEntity() => Stock(code: code, watcherCount: watcherCount, watching: watching);
}
