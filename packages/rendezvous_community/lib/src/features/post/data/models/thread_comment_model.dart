import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'thread_comment_model.freezed.dart';
part 'thread_comment_model.g.dart';

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
    String? moderationStatus,
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
    moderationStatus: parseModerationStatus(moderationStatus),
  );
}
