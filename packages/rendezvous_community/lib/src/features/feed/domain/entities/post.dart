import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'post.freezed.dart';

enum Sentiment { bullish, bearish, neutral }

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
    Poll? poll,
    DateTime? editedAt,
    required DateTime createdAt,
    required String cursor,
    @Default(false) bool isBookmarked,
    @Default(<String>[]) List<String> hashtags,
    @Default(false) bool isBot,
    @Default(false) bool authorIsOfficial,
    ModerationStatus? moderationStatus,
  }) = _Post;

  const Post._();

  bool get isHeld => moderationStatus == ModerationStatus.held;

  bool get isHidden => moderationStatus == ModerationStatus.hidden;
}

@freezed
sealed class FeedScope with _$FeedScope {
  const factory FeedScope.global() = GlobalFeedScope;

  const factory FeedScope.following() = FollowingFeedScope;

  const factory FeedScope.stock(String code) = StockFeedScope;

  const factory FeedScope.user(String userId) = UserFeedScope;
}

sealed class PostChange {
  const PostChange(this.postId);
  final String postId;
}

class PostInserted extends PostChange {
  const PostInserted(super.postId, {required this.authorId, required this.body, required this.createdAt});
  final String authorId;
  final String body;
  final DateTime createdAt;
}

class PostUpdated extends PostChange {
  const PostUpdated(super.postId, {required this.likeCount, required this.commentCount, required this.deleted});
  final int likeCount;
  final int commentCount;
  final bool deleted;
}
