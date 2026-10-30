// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StockModel _$StockModelFromJson(Map<String, dynamic> json) => _StockModel(
  code: json['code'] as String,
  name: json['name'] as String,
  type: json['type'] as String? ?? 'stock',
  sector: json['sector'] as String?,
  watcherCount: (json['watcher_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$StockModelToJson(_StockModel instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'type': instance.type,
      'sector': instance.sector,
      'watcher_count': instance.watcherCount,
    };
