import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/support/domain/entities/support_ticket.dart';

part 'support_models.freezed.dart';
part 'support_models.g.dart';

const _statuses = {
  'open': SupportStatus.open,
  'claimed': SupportStatus.claimed,
  'waiting_customer': SupportStatus.waitingCustomer,
  'resolved': SupportStatus.resolved,
  'closed': SupportStatus.closed,
};

@freezed
abstract class SupportTicketModel with _$SupportTicketModel {
  const factory SupportTicketModel({
    required String id,
    required String ticketNumber,
    required String roomId,
    required String topic,
    String? topicName,
    required String status,
    int? queueAhead,
    Map<String, dynamic>? agent,
    Map<String, dynamic>? complaint,
    required DateTime createdAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    DateTime? reopenUntil,
    int? rating,
    @Default(false) bool canRate,
  }) = _SupportTicketModel;

  const SupportTicketModel._();

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) => _$SupportTicketModelFromJson(json);

  SupportTicket toEntity() => SupportTicket(
    id: id,
    ticketNumber: ticketNumber,
    roomId: roomId,
    topic: topic,
    topicName: topicName,
    status: _statuses[status] ?? SupportStatus.closed,
    queueAhead: queueAhead,
    agent: agent == null
        ? null
        : SupportAgent(
            displayName: agent!['display_name'] as String? ?? '',
            agentCode: agent!['agent_code'] as String?,
          ),
    complaintReceivedAt: DateTime.tryParse(complaint?['received_at'] as String? ?? ''),
    complaintDueAt: DateTime.tryParse(complaint?['due_at'] as String? ?? ''),
    createdAt: createdAt,
    resolvedAt: resolvedAt,
    closedAt: closedAt,
    reopenUntil: reopenUntil,
    rating: rating,
    canRate: canRate,
  );
}

@freezed
abstract class SupportHomeModel with _$SupportHomeModel {
  const factory SupportHomeModel({
    String? roomId,
    @Default('') String supportName,
    SupportTicketModel? ticket,
    @Default(false) bool active,
    @Default(0) int unreadCount,
    @Default(true) bool serviceOpen,
    DateTime? nextOpenAt,
  }) = _SupportHomeModel;

  const SupportHomeModel._();

  factory SupportHomeModel.fromJson(Map<String, dynamic> json) => _$SupportHomeModelFromJson(json);

  SupportHome toEntity() => SupportHome(
    roomId: roomId,
    supportName: supportName,
    ticket: ticket?.toEntity(),
    active: active,
    unreadCount: unreadCount,
    serviceOpen: serviceOpen,
    nextOpenAt: nextOpenAt,
  );
}
