// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => _ProfileModel(
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

Map<String, dynamic> _$ProfileModelToJson(_ProfileModel instance) => <String, dynamic>{
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
