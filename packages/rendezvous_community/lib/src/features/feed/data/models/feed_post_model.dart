import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/poll/data/models/poll_model.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'feed_post_model.freezed.dart';
part 'feed_post_model.g.dart';

Sentiment? parseSentiment(String? value) => value == null ? null : Sentiment.values.asNameMap()[value];

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
    @JsonKey(fromJson: attachmentsFromJson) @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(<String>[]) List<String> stockCodes,
    @Default(false) bool likedByMe,
    PollModel? poll,
    DateTime? editedAt,
    required DateTime createdAt,
    @Default('') String cursor,
    bool? isBookmarked,
    List<String>? hashtags,
    bool? isBot,
    bool? authorIsOfficial,
    String? moderationStatus,
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
    poll: poll?.toEntity(),
    editedAt: editedAt,
    createdAt: createdAt,
    cursor: cursor,
    isBookmarked: isBookmarked ?? false,
    hashtags: hashtags ?? const [],
    isBot: isBot ?? false,
    authorIsOfficial: authorIsOfficial ?? false,
    moderationStatus: parseModerationStatus(moderationStatus),
  );
}

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
