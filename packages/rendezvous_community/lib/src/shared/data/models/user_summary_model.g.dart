// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserSummaryModel _$UserSummaryModelFromJson(Map<String, dynamic> json) => _UserSummaryModel(
  id: json['id'] as String,
  username: json['username'] as String,
  displayName: json['display_name'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  isVerified: json['is_verified'] as bool? ?? false,
);

Map<String, dynamic> _$UserSummaryModelToJson(_UserSummaryModel instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'display_name': instance.displayName,
  'avatar_url': instance.avatarUrl,
  'is_verified': instance.isVerified,
};
