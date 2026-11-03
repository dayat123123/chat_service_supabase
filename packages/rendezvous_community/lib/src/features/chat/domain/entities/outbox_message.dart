import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'outbox_message.freezed.dart';

enum OutboxState { pending, sending, failed }

@freezed
abstract class OutboxMessage with _$OutboxMessage {
  const factory OutboxMessage({
    required String clientId,
    required String roomId,
    required String body,
    String? replyToId,
    String? replyToBody,
    String? replyToSenderUsername,
    required DateTime createdAt,
    @Default(OutboxState.pending) OutboxState state,
    @Default(0) int attempts,
    DateTime? nextAttemptAt,
    CommunityException? error,
  }) = _OutboxMessage;

  const OutboxMessage._();

  static OutboxMessage? fromLocal(ChatMessage message) {
    final clientId = message.clientId;
    if (clientId == null || message.attachments.isNotEmpty || message.sharedPostId != null) return null;
    if (message.stockCodes.isNotEmpty) return null;
    return OutboxMessage(
      clientId: clientId,
      roomId: message.roomId,
      body: message.body ?? '',
      replyToId: message.replyToId,
      replyToBody: message.replyToBody,
      replyToSenderUsername: message.replyToSenderUsername,
      createdAt: message.createdAt,
    );
  }

  bool get isFailed => state == OutboxState.failed;

  ChatMessage toMessage(UserSummary? sender) => ChatMessage(
    id: 'local-$clientId',
    roomId: roomId,
    senderId: sender?.id,
    sender: sender,
    body: body,
    replyToId: replyToId,
    replyToBody: replyToBody,
    replyToSenderUsername: replyToSenderUsername,
    clientId: clientId,
    createdAt: createdAt,
    status: switch (state) {
      OutboxState.pending => MessageStatus.pending,
      OutboxState.sending => MessageStatus.sending,
      OutboxState.failed => MessageStatus.failed,
    },
    sendError: isFailed ? error : null,
  );
}
