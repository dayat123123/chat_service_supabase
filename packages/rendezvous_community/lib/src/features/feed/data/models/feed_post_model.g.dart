// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FeedPostModel _$FeedPostModelFromJson(Map<String, dynamic> json) => _FeedPostModel(
  id: json['id'] as String,
  authorId: json['author_id'] as String,
  authorUsername: json['author_username'] as String,
  authorDisplayName: json['author_display_name'] as String?,
  authorAvatarUrl: json['author_avatar_url'] as String?,
  authorIsVerified: json['author_is_verified'] as bool? ?? false,
  body: json['body'] as String,
  sentiment: json['sentiment'] as String?,
  attachments: json['attachments'] == null ? const <AttachmentModel>[] : attachmentsFromJson(json['attachments']),
  likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
  commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
  stockCodes: (json['stock_codes'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  likedByMe: json['liked_by_me'] as bool? ?? false,
  poll: json['poll'] == null ? null : PollModel.fromJson(json['poll'] as Map<String, dynamic>),
  editedAt: json['edited_at'] == null ? null : DateTime.parse(json['edited_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  cursor: json['cursor'] as String? ?? '',
  isBookmarked: json['is_bookmarked'] as bool?,
  hashtags: (json['hashtags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  isBot: json['is_bot'] as bool?,
  authorIsOfficial: json['author_is_official'] as bool?,
  moderationStatus: json['moderation_status'] as String?,
);

Map<String, dynamic> _$FeedPostModelToJson(_FeedPostModel instance) => <String, dynamic>{
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
  'poll': instance.poll?.toJson(),
  'edited_at': instance.editedAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'cursor': instance.cursor,
  'is_bookmarked': instance.isBookmarked,
  'hashtags': instance.hashtags,
  'is_bot': instance.isBot,
  'author_is_official': instance.authorIsOfficial,
  'moderation_status': instance.moderationStatus,
};

_PostRowModel _$PostRowModelFromJson(Map<String, dynamic> json) => _PostRowModel(
  id: json['id'] as String,
  authorId: json['author_id'] as String,
  body: json['body'] as String? ?? '',
  likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
  commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
  deletedAt: json['deleted_at'] == null ? null : DateTime.parse(json['deleted_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$PostRowModelToJson(_PostRowModel instance) => <String, dynamic>{
  'id': instance.id,
  'author_id': instance.authorId,
  'body': instance.body,
  'like_count': instance.likeCount,
  'comment_count': instance.commentCount,
  'deleted_at': instance.deletedAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
