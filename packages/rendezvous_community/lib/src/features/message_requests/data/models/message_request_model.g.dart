// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageRequestModel _$MessageRequestModelFromJson(Map<String, dynamic> json) => _MessageRequestModel(
  roomId: json['room_id'] as String,
  senderId: json['sender_id'] as String,
  username: json['username'] as String? ?? '',
  displayName: json['display_name'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  isVerified: json['is_verified'] as bool? ?? false,
  messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
  hasImage: json['has_image'] as bool? ?? false,
  lastMessagePreview: json['last_message_preview'] as String?,
  lastMessageAt: json['last_message_at'] == null ? null : DateTime.parse(json['last_message_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MessageRequestModelToJson(_MessageRequestModel instance) => <String, dynamic>{
  'room_id': instance.roomId,
  'sender_id': instance.senderId,
  'username': instance.username,
  'display_name': instance.displayName,
  'avatar_url': instance.avatarUrl,
  'is_verified': instance.isVerified,
  'message_count': instance.messageCount,
  'has_image': instance.hasImage,
  'last_message_preview': instance.lastMessagePreview,
  'last_message_at': instance.lastMessageAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
