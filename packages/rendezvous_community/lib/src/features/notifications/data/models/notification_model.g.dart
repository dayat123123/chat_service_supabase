// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) => _NotificationModel(
  id: json['id'] as String,
  type: json['type'] as String,
  actorId: json['actor_id'] as String?,
  actorUsername: json['actor_username'] as String?,
  actorDisplayName: json['actor_display_name'] as String?,
  actorAvatarUrl: json['actor_avatar_url'] as String?,
  payload: json['payload'] as Map<String, dynamic>? ?? const <String, Object?>{},
  eventCount: (json['event_count'] as num?)?.toInt() ?? 1,
  readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  cursor: json['cursor'] as String,
  actorCount: (json['actor_count'] as num?)?.toInt(),
  actors:
      (json['actors'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ??
      const <Map<String, dynamic>>[],
);

Map<String, dynamic> _$NotificationModelToJson(_NotificationModel instance) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'actor_id': instance.actorId,
  'actor_username': instance.actorUsername,
  'actor_display_name': instance.actorDisplayName,
  'actor_avatar_url': instance.actorAvatarUrl,
  'payload': instance.payload,
  'event_count': instance.eventCount,
  'read_at': instance.readAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'cursor': instance.cursor,
  'actor_count': instance.actorCount,
  'actors': instance.actors,
};
