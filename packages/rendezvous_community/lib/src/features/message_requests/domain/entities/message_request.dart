import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'message_request.freezed.dart';

enum DmPolicy { everyone, following, none }

enum MessageRequestAction { accept, decline, block }

enum DmRequestRole { sender, recipient }

const defaultRequestMaxMessages = 3;

@freezed
abstract class MessageRequest with _$MessageRequest {
  const factory MessageRequest({
    required String roomId,
    required UserSummary sender,
    @Default(0) int messageCount,
    @Default(false) bool hasImage,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    required DateTime createdAt,
  }) = _MessageRequest;
}

@freezed
abstract class DmRequestState with _$DmRequestState {
  const factory DmRequestState({
    @Default(false) bool isRequest,
    DmRequestRole? role,
    @Default(false) bool declined,
    @Default(0) int sent,
    @Default(defaultRequestMaxMessages) int maxMessages,
  }) = _DmRequestState;

  const DmRequestState._();

  bool get pendingAsSender => isRequest && role == DmRequestRole.sender;

  bool get pendingAsRecipient => isRequest && role == DmRequestRole.recipient && !declined;

  bool get limitReached => pendingAsSender && sent >= maxMessages;
}

@freezed
abstract class DmPolicySettings with _$DmPolicySettings {
  const factory DmPolicySettings({
    @Default(DmPolicy.everyone) DmPolicy policy,
    @Default(defaultRequestMaxMessages) int requestMaxMessages,
  }) = _DmPolicySettings;
}
