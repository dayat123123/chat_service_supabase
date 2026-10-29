// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AttachmentModel _$AttachmentModelFromJson(Map<String, dynamic> json) =>
    _AttachmentModel(
      path: json['path'] as String,
      mime: json['mime'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AttachmentModelToJson(_AttachmentModel instance) =>
    <String, dynamic>{
      'path': instance.path,
      'mime': instance.mime,
      'width': instance.width,
      'height': instance.height,
    };

_FeedPostModel _$FeedPostModelFromJson(Map<String, dynamic> json) =>
    _FeedPostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorUsername: json['author_username'] as String,
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorIsVerified: json['author_is_verified'] as bool? ?? false,
      body: json['body'] as String,
      sentiment: json['sentiment'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AttachmentModel>[],
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      stockCodes:
          (json['stock_codes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      likedByMe: json['liked_by_me'] as bool? ?? false,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      cursor: json['cursor'] as String,
    );

Map<String, dynamic> _$FeedPostModelToJson(_FeedPostModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author_id': instance.authorId,
      'author_username': instance.authorUsername,
      'author_display_name': instance.authorDisplayName,
      'author_avatar_url': instance.authorAvatarUrl,
      'author_is_verified': instance.authorIsVerified,
      'body': instance.body,
      'sentiment': instance.sentiment,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
      'like_count': instance.likeCount,
      'comment_count': instance.commentCount,
      'stock_codes': instance.stockCodes,
      'liked_by_me': instance.likedByMe,
      'edited_at': instance.editedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'cursor': instance.cursor,
    };

_PostRowModel _$PostRowModelFromJson(Map<String, dynamic> json) =>
    _PostRowModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String? ?? '',
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PostRowModelToJson(_PostRowModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author_id': instance.authorId,
      'body': instance.body,
      'like_count': instance.likeCount,
      'comment_count': instance.commentCount,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

_ThreadCommentModel _$ThreadCommentModelFromJson(Map<String, dynamic> json) =>
    _ThreadCommentModel(
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
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      cursor: json['cursor'] as String,
    );

Map<String, dynamic> _$ThreadCommentModelToJson(_ThreadCommentModel instance) =>
    <String, dynamic>{
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
    };
