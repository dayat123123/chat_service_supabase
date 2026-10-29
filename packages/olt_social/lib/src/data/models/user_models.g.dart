// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileSummaryModel _$ProfileSummaryModelFromJson(Map<String, dynamic> json) =>
    _ProfileSummaryModel(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );

Map<String, dynamic> _$ProfileSummaryModelToJson(
  _ProfileSummaryModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'display_name': instance.displayName,
  'avatar_url': instance.avatarUrl,
  'is_verified': instance.isVerified,
};

_ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) =>
    _ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      postCount: (json['post_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMe: json['is_me'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
      followsMe: json['follows_me'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
    );

Map<String, dynamic> _$ProfileModelToJson(_ProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'bio': instance.bio,
      'is_verified': instance.isVerified,
      'follower_count': instance.followerCount,
      'following_count': instance.followingCount,
      'post_count': instance.postCount,
      'created_at': instance.createdAt.toIso8601String(),
      'is_me': instance.isMe,
      'is_following': instance.isFollowing,
      'follows_me': instance.followsMe,
      'is_blocked': instance.isBlocked,
    };

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

_NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    _NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      actorId: json['actor_id'] as String?,
      actorUsername: json['actor_username'] as String?,
      actorDisplayName: json['actor_display_name'] as String?,
      actorAvatarUrl: json['actor_avatar_url'] as String?,
      payload:
          json['payload'] as Map<String, dynamic>? ?? const <String, Object?>{},
      eventCount: (json['event_count'] as num?)?.toInt() ?? 1,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      cursor: json['cursor'] as String,
    );

Map<String, dynamic> _$NotificationModelToJson(_NotificationModel instance) =>
    <String, dynamic>{
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
    };
