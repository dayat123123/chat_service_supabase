import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

part 'chat_message.freezed.dart';

enum MessageStatus { sending, sent, failed }

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
  }) = _ChatMessage;

  const ChatMessage._();

  bool get isLocal => id.startsWith('local-');
}
