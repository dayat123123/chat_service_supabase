import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'thread_comment.freezed.dart';

@freezed
abstract class ThreadComment with _$ThreadComment {
  const factory ThreadComment({
    required String id,
    required String postId,
    String? parentId,
    UserSummary? author,
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
    ModerationStatus? moderationStatus,
  }) = _ThreadComment;

  const ThreadComment._();

  bool get isHeld => moderationStatus == ModerationStatus.held;

  bool get isHidden => moderationStatus == ModerationStatus.hidden;
}
