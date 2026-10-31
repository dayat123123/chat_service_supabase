import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_suggestion.freezed.dart';

@freezed
abstract class StockSuggestion with _$StockSuggestion {
  const factory StockSuggestion({required String code, String? name}) = _StockSuggestion;
}
