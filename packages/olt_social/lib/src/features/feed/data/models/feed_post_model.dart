import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/src/features/feed/domain/entities/post.dart';
import 'package:olt_social/src/features/poll/data/models/poll_model.dart';
import 'package:olt_social/src/shared/data/models/attachment_model.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

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
    @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(<String>[]) List<String> stockCodes,
    @Default(false) bool likedByMe,
    PollModel? poll,
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
    poll: poll?.toEntity(),
    editedAt: editedAt,
    createdAt: createdAt,
    cursor: cursor,
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
