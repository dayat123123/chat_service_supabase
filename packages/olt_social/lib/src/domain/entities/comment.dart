import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'comment.freezed.dart';

/// Komentar dalam thread berantai.
@freezed
abstract class ThreadComment with _$ThreadComment {
  const factory ThreadComment({
    required String id,
    required String postId,
    String? parentId,

    /// null jika komentar sudah dihapus.
    UserSummary? author,

    /// null jika komentar sudah dihapus (tampilkan "[komentar dihapus]").
    String? body,
    @Default(false) bool isDeleted,

    /// 0 = komentar langsung di post.
    required int depth,
    required String path,
    @Default(0) int likeCount,

    /// Jumlah balasan langsung (termasuk yang dihapus).
    @Default(0) int replyCount,
    @Default(false) bool likedByMe,
    DateTime? editedAt,
    required DateTime createdAt,

    /// Cursor untuk "lihat balasan lainnya" di bawah induk yang sama.
    required String cursor,
  }) = _ThreadComment;
}
