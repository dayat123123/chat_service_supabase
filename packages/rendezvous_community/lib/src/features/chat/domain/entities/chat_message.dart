import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'chat_message.freezed.dart';

enum MessageStatus { sending, sent, failed, pending }

enum MessageKind { text, system, quickReply, helpLink, identityRequest, csat }

enum SenderRole { customer, agent, supervisor, system }

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String roomId,
    String? senderId,
    UserSummary? sender,
    String? body,
    @Default(false) bool isDeleted,
    String? replyToId,
    String? replyToBody,
    String? replyToSenderUsername,
    @Default(<Attachment>[]) List<Attachment> attachments,
    String? clientId,
    DateTime? editedAt,
    required DateTime createdAt,
    String? cursor,
    @Default(MessageStatus.sent) MessageStatus status,
    @Default(MessageKind.text) MessageKind kind,
    SenderRole? senderRole,
    String? ticketId,
    @Default(<String, Object?>{}) Map<String, Object?> payload,
    @Default(<MessageReaction>[]) List<MessageReaction> reactions,
    String? sharedPostId,
    SharedPost? sharedPost,
    @Default(<String>[]) List<String> stockCodes,
    ModerationStatus? moderationStatus,
    CommunityException? sendError,
  }) = _ChatMessage;

  const ChatMessage._();

  bool get isLocal => id.startsWith('local-');

  bool get isSystem => senderRole == SenderRole.system;

  bool get isOfficial => senderRole == SenderRole.agent || senderRole == SenderRole.supervisor;

  String? get systemCode => payload['code'] as String?;

  bool get isHeld => moderationStatus == ModerationStatus.held;

  bool get isHidden => moderationStatus == ModerationStatus.hidden;
}
