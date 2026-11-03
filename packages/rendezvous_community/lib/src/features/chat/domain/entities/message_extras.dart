import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'message_extras.freezed.dart';

const defaultMessageReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

@freezed
abstract class MessageReaction with _$MessageReaction {
  const factory MessageReaction({required String emoji, required int count, @Default(false) bool mine}) =
      _MessageReaction;
}

@freezed
abstract class SharedPost with _$SharedPost {
  const factory SharedPost({
    required String postId,
    @Default(true) bool available,
    UserSummary? author,
    String? body,
    @Default(<Attachment>[]) List<Attachment> attachments,
    Sentiment? sentiment,
    @Default(<String>[]) List<String> stockCodes,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    DateTime? createdAt,
  }) = _SharedPost;
}

List<MessageReaction> applyReaction(List<MessageReaction> current, String? previous, String? next) {
  final counts = <String, int>{for (final r in current) r.emoji: r.count};
  if (previous != null) counts[previous] = (counts[previous] ?? 1) - 1;
  if (next != null) counts[next] = (counts[next] ?? 0) + 1;
  final order = [for (final r in current) r.emoji, if (next != null && !current.any((r) => r.emoji == next)) next];
  return [
    for (final emoji in order)
      if ((counts[emoji] ?? 0) > 0) MessageReaction(emoji: emoji, count: counts[emoji]!, mine: emoji == next),
  ];
}

String? myReaction(List<MessageReaction> reactions) => reactions.where((r) => r.mine).firstOrNull?.emoji;
