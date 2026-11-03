// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClientConfigModel _$ClientConfigModelFromJson(Map<String, dynamic> json) => _ClientConfigModel(
  socialEnabled: json['social_enabled'] as bool? ?? true,
  flags: json['flags'] == null ? const <String, bool>{} : _flagsFromJson(json['flags']),
  minVersion: json['min_version'] == null ? const <String, String?>{} : _versionsFromJson(json['min_version']),
  updateRequired: json['update_required'] as bool? ?? false,
  config: json['config'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  banners: json['banners'] == null ? const <CommunityBanner>[] : bannersFromJson(json['banners']),
);

Map<String, dynamic> _$ClientConfigModelToJson(_ClientConfigModel instance) => <String, dynamic>{
  'social_enabled': instance.socialEnabled,
  'flags': instance.flags,
  'min_version': instance.minVersion,
  'update_required': instance.updateRequired,
  'config': instance.config,
};
