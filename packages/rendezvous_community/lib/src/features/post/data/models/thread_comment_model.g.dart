// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_comment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ThreadCommentModel _$ThreadCommentModelFromJson(Map<String, dynamic> json) => _ThreadCommentModel(
  id: json['id'] as String,
  postId: json['post_id'] as String,
  parentId: json['parent_id'] as String?,
  authorId: json['author_id'] as String?,
  authorUsername: json['author_username'] as String?,
  authorDisplayName: json['author_display_name'] as String?,
  authorAvatarUrl: json['author_avatar_url'] as String?,
  authorIsVerified: json['author_is_verified'] as bool? ?? false,
  body: json['body'] as String?,
  isDeleted: json['is_deleted'] as bool? ?? false,
  depth: (json['depth'] as num).toInt(),
  path: json['path'] as String,
  likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
  replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
  likedByMe: json['liked_by_me'] as bool? ?? false,
  editedAt: json['edited_at'] == null ? null : DateTime.parse(json['edited_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  cursor: json['cursor'] as String,
  moderationStatus: json['moderation_status'] as String?,
);

Map<String, dynamic> _$ThreadCommentModelToJson(_ThreadCommentModel instance) => <String, dynamic>{
  'id': instance.id,
  'post_id': instance.postId,
  'parent_id': instance.parentId,
  'author_id': instance.authorId,
  'author_username': instance.authorUsername,
  'author_display_name': instance.authorDisplayName,
  'author_avatar_url': instance.authorAvatarUrl,
  'author_is_verified': instance.authorIsVerified,
  'body': instance.body,
  'is_deleted': instance.isDeleted,
  'depth': instance.depth,
  'path': instance.path,
  'like_count': instance.likeCount,
  'reply_count': instance.replyCount,
  'liked_by_me': instance.likedByMe,
  'edited_at': instance.editedAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'cursor': instance.cursor,
  'moderation_status': instance.moderationStatus,
};
