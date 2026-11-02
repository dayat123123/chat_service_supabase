// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StockModel _$StockModelFromJson(Map<String, dynamic> json) => _StockModel(
  code: json['code'] as String,
  watcherCount: (json['watcher_count'] as num?)?.toInt() ?? 0,
  watching: json['watching'] as bool? ?? false,
);

Map<String, dynamic> _$StockModelToJson(_StockModel instance) => <String, dynamic>{
  'code': instance.code,
  'watcher_count': instance.watcherCount,
  'watching': instance.watching,
};
