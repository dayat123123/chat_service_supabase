import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock.freezed.dart';

@freezed
abstract class Stock with _$Stock {
  const factory Stock({required String code, @Default(0) int watcherCount, @Default(false) bool watching}) = _Stock;
}
