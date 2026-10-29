import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'post.freezed.dart';

/// Sentimen opsional pada post.
enum Sentiment { bullish, bearish, neutral }

/// Lampiran gambar di storage (bucket `attachments`).
@freezed
abstract class Attachment with _$Attachment {
  const factory Attachment({
    required String path,
    String? mime,
    int? width,
    int? height,
  }) = _Attachment;
}

/// Post di feed.
@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    required UserSummary author,
    required String body,
    Sentiment? sentiment,
    @Default(<Attachment>[]) List<Attachment> attachments,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(<String>[]) List<String> stockCodes,
    @Default(false) bool likedByMe,
    DateTime? editedAt,
    required DateTime createdAt,

    /// Cursor keyset untuk mengambil halaman setelah post ini.
    required String cursor,
  }) = _Post;
}

/// Lingkup feed.
@freezed
sealed class FeedScope with _$FeedScope {
  /// Stream umum, semua post.
  const factory FeedScope.global() = GlobalFeedScope;

  /// Post sendiri + user yang di-follow.
  const factory FeedScope.following() = FollowingFeedScope;

  /// Post yang ditandai kode saham.
  const factory FeedScope.stock(String code) = StockFeedScope;

  /// Post milik satu user.
  const factory FeedScope.user(String userId) = UserFeedScope;
}

/// Perubahan post yang diterima secara realtime.
sealed class PostChange {
  const PostChange(this.postId);
  final String postId;
}

/// Post baru (data minimal; muat ulang feed untuk detail lengkap).
class PostInserted extends PostChange {
  const PostInserted(super.postId, {required this.authorId, required this.body, required this.createdAt});
  final String authorId;
  final String body;
  final DateTime createdAt;
}

/// Counter berubah atau post dihapus.
class PostUpdated extends PostChange {
  const PostUpdated(super.postId, {required this.likeCount, required this.commentCount, required this.deleted});
  final int likeCount;
  final int commentCount;
  final bool deleted;
}
