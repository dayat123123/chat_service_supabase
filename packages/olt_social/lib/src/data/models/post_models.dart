import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/user.dart';

part 'post_models.freezed.dart';
part 'post_models.g.dart';

Sentiment? parseSentiment(String? value) => value == null ? null : Sentiment.values.asNameMap()[value];

@freezed
abstract class AttachmentModel with _$AttachmentModel {
  const factory AttachmentModel({
    required String path,
    String? mime,
    int? width,
    int? height,
  }) = _AttachmentModel;

  const AttachmentModel._();

  factory AttachmentModel.fromJson(Map<String, dynamic> json) => _$AttachmentModelFromJson(json);

  factory AttachmentModel.fromEntity(Attachment a) =>
      AttachmentModel(path: a.path, mime: a.mime, width: a.width, height: a.height);

  Attachment toEntity() => Attachment(path: path, mime: mime, width: width, height: height);
}

/// Baris hasil RPC get_feed / get_post (tipe public.feed_post).
@freezed
abstract class FeedPostModel with _$FeedPostModel {
  const factory FeedPostModel({
    required String id,
    required String authorId,
    required String authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    @Default(false) bool authorIsVerified,
    required String body,
    String? sentiment,
    @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(<String>[]) List<String> stockCodes,
    @Default(false) bool likedByMe,
    DateTime? editedAt,
    required DateTime createdAt,
    required String cursor,
  }) = _FeedPostModel;

  const FeedPostModel._();

  factory FeedPostModel.fromJson(Map<String, dynamic> json) => _$FeedPostModelFromJson(json);

  Post toEntity() => Post(
    id: id,
    author: UserSummary(
      id: authorId,
      username: authorUsername,
      displayName: authorDisplayName,
      avatarUrl: authorAvatarUrl,
      isVerified: authorIsVerified,
    ),
    body: body,
    sentiment: parseSentiment(sentiment),
    attachments: [for (final a in attachments) a.toEntity()],
    likeCount: likeCount,
    commentCount: commentCount,
    stockCodes: stockCodes,
    likedByMe: likedByMe,
    editedAt: editedAt,
    createdAt: createdAt,
    cursor: cursor,
  );
}

/// Baris mentah tabel posts dari realtime postgres_changes.
@freezed
abstract class PostRowModel with _$PostRowModel {
  const factory PostRowModel({
    required String id,
    required String authorId,
    @Default('') String body,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    DateTime? deletedAt,
    required DateTime createdAt,
  }) = _PostRowModel;

  factory PostRowModel.fromJson(Map<String, dynamic> json) => _$PostRowModelFromJson(json);
}

/// Baris hasil RPC get_comment_thread / create_comment (tipe public.thread_comment).
@freezed
abstract class ThreadCommentModel with _$ThreadCommentModel {
  const factory ThreadCommentModel({
    required String id,
    required String postId,
    String? parentId,
    String? authorId,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    @Default(false) bool authorIsVerified,
    String? body,
    @Default(false) bool isDeleted,
    required int depth,
    required String path,
    @Default(0) int likeCount,
    @Default(0) int replyCount,
    @Default(false) bool likedByMe,
    DateTime? editedAt,
    required DateTime createdAt,
    required String cursor,
  }) = _ThreadCommentModel;

  const ThreadCommentModel._();

  factory ThreadCommentModel.fromJson(Map<String, dynamic> json) => _$ThreadCommentModelFromJson(json);

  ThreadComment toEntity() => ThreadComment(
    id: id,
    postId: postId,
    parentId: parentId,
    author: authorId == null || authorUsername == null
        ? null
        : UserSummary(
            id: authorId!,
            username: authorUsername!,
            displayName: authorDisplayName,
            avatarUrl: authorAvatarUrl,
            isVerified: authorIsVerified,
          ),
    body: body,
    isDeleted: isDeleted,
    depth: depth,
    path: path,
    likeCount: likeCount,
    replyCount: replyCount,
    likedByMe: likedByMe,
    editedAt: editedAt,
    createdAt: createdAt,
    cursor: cursor,
  );
}
