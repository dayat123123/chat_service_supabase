import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_ticket.freezed.dart';

enum SupportStatus { open, claimed, waitingCustomer, resolved, closed }

@freezed
abstract class SupportAgent with _$SupportAgent {
  const factory SupportAgent({required String displayName, String? agentCode}) = _SupportAgent;
}

@freezed
abstract class SupportTicket with _$SupportTicket {
  const factory SupportTicket({
    required String id,
    required String ticketNumber,
    required String roomId,
    required String topic,
    String? topicName,
    required SupportStatus status,
    int? queueAhead,
    SupportAgent? agent,
    DateTime? complaintReceivedAt,
    DateTime? complaintDueAt,
    required DateTime createdAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    DateTime? reopenUntil,
    int? rating,
    @Default(false) bool canRate,
  }) = _SupportTicket;

  const SupportTicket._();

  bool get isActive =>
      status == SupportStatus.open || status == SupportStatus.claimed || status == SupportStatus.waitingCustomer;

  bool reopenable(DateTime now) => status == SupportStatus.resolved && (reopenUntil?.isAfter(now) ?? false);
}

@freezed
abstract class SupportHome with _$SupportHome {
  const factory SupportHome({
    String? roomId,
    required String supportName,
    SupportTicket? ticket,
    @Default(false) bool active,
    @Default(0) int unreadCount,
    @Default(true) bool serviceOpen,
    DateTime? nextOpenAt,
  }) = _SupportHome;

  const SupportHome._();

  bool showsConversation(DateTime now) =>
      roomId != null && (active || (ticket?.reopenable(now) ?? false) || (ticket?.canRate ?? false));
}

@freezed
abstract class SupportTopic with _$SupportTopic {
  const factory SupportTopic({
    required String code,
    required String name,
    String? helpUrl,
    @Default(false) bool urgent,
  }) = _SupportTopic;
}

@freezed
abstract class SensitiveCheck with _$SensitiveCheck {
  const factory SensitiveCheck({@Default(false) bool masked, @Default(<String>[]) List<String> kinds}) =
      _SensitiveCheck;
}

@freezed
abstract class SupportNotice with _$SupportNotice {
  const factory SupportNotice({
    required String id,
    required String title,
    required String body,
    String? ticketId,
    String? roomId,
  }) = _SupportNotice;
}
