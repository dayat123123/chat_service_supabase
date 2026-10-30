import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ticket.freezed.dart';
part 'ticket.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum TicketStatus { open, claimed, waitingCustomer, resolved, closed }

const ticketPriorities = ['P1', 'P2', 'P3', 'P4'];

@freezed
abstract class TicketCustomer with _$TicketCustomer {
  const factory TicketCustomer({
    required String id,
    String? displayName,
    String? username,
    @Default(false) bool deleted,
  }) = _TicketCustomer;

  factory TicketCustomer.fromJson(Map<String, dynamic> json) => _$TicketCustomerFromJson(json);

  const TicketCustomer._();

  String get name => (displayName?.trim().isNotEmpty ?? false) ? displayName!.trim() : (username ?? '');

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

@freezed
abstract class TicketOwner with _$TicketOwner {
  const factory TicketOwner({
    required String id,
    required String displayName,
    String? agentCode,
    @JsonKey(unknownEnumValue: AgentStatus.offline) @Default(AgentStatus.offline) AgentStatus status,
  }) = _TicketOwner;

  factory TicketOwner.fromJson(Map<String, dynamic> json) => _$TicketOwnerFromJson(json);
}

@freezed
abstract class PendingTransfer with _$PendingTransfer {
  const factory PendingTransfer({
    required String id,
    String? fromId,
    String? fromName,
    String? toId,
    String? toName,
    String? note,
    DateTime? expiresAt,
  }) = _PendingTransfer;

  factory PendingTransfer.fromJson(Map<String, dynamic> json) => _$PendingTransferFromJson(json);
}

@freezed
abstract class TicketEvent with _$TicketEvent {
  const factory TicketEvent({
    required String type,
    String? actorType,
    String? actorName,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    required DateTime createdAt,
  }) = _TicketEvent;

  factory TicketEvent.fromJson(Map<String, dynamic> json) => _$TicketEventFromJson(json);
}

@freezed
abstract class Ticket with _$Ticket {
  const factory Ticket({
    required String id,
    required String ticketNumber,
    required String roomId,
    @JsonKey(unknownEnumValue: TicketStatus.closed) required TicketStatus status,
    @Default(1) int version,
    required String topic,
    @Default('P3') String priority,
    @Default(<String>[]) List<String> flags,
    @Default('id') String language,
    TicketCustomer? customer,
    TicketOwner? owner,
    @Default(false) bool isMine,
    DateTime? queuedAt,
    DateTime? createdAt,
    DateTime? claimedAt,
    DateTime? firstResponseAt,
    DateTime? lastCustomerMessageAt,
    DateTime? lastAgentMessageAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    String? outcome,
    String? resolutionSummary,
    String? returnedReason,
    DateTime? complaintReceivedAt,
    DateTime? complaintDueAt,
    int? rating,
    String? ratingComment,
    PendingTransfer? transfer,
    String? preview,
    @Default(0) int unreadCount,
    DateTime? waitingSince,
    @Default(<String>[]) List<String> tags,
    @Default(<TicketEvent>[]) List<TicketEvent> events,
  }) = _Ticket;

  factory Ticket.fromJson(Map<String, dynamic> json) => _$TicketFromJson(json);

  const Ticket._();

  bool get isActive => status == TicketStatus.claimed || status == TicketStatus.waitingCustomer;

  bool get isOpen => status == TicketStatus.open;

  bool get isComplaint => flags.contains('complaint');

  bool get isFraud => flags.contains('fraud');

  bool get isVip => flags.contains('vip');

  bool get highPriority => priority == 'P1' || priority == 'P2';

  String get customerName => customer?.name ?? '';

  DateTime get sortTime => waitingSince ?? queuedAt ?? createdAt ?? DateTime.now();
}

@freezed
abstract class TransferRequest with _$TransferRequest {
  const factory TransferRequest({
    required String id,
    String? note,
    DateTime? expiresAt,
    String? fromName,
    required Ticket ticket,
  }) = _TransferRequest;

  factory TransferRequest.fromJson(Map<String, dynamic> json) => _$TransferRequestFromJson(json);
}

@freezed
abstract class OutgoingTransfer with _$OutgoingTransfer {
  const factory OutgoingTransfer({
    required String id,
    required String ticketId,
    DateTime? expiresAt,
    String? toName,
  }) = _OutgoingTransfer;

  factory OutgoingTransfer.fromJson(Map<String, dynamic> json) => _$OutgoingTransferFromJson(json);
}

@freezed
abstract class TicketLists with _$TicketLists {
  const factory TicketLists({
    @Default(<Ticket>[]) List<Ticket> open,
    @Default(<Ticket>[]) List<Ticket> mine,
    @Default(<Ticket>[]) List<Ticket> resolvedToday,
    @Default(<Ticket>[]) List<Ticket> allActive,
    @Default(<TransferRequest>[]) List<TransferRequest> transfersIn,
    @Default(<OutgoingTransfer>[]) List<OutgoingTransfer> transfersOut,
  }) = _TicketLists;

  factory TicketLists.fromJson(Map<String, dynamic> json) => _$TicketListsFromJson(json);
}

@freezed
abstract class SupportTopic with _$SupportTopic {
  const factory SupportTopic({
    required String code,
    required String name,
    String? helpUrl,
    @Default(false) bool urgent,
  }) = _SupportTopic;

  factory SupportTopic.fromJson(Map<String, dynamic> json) => _$SupportTopicFromJson(json);
}

@freezed
abstract class QuickReply with _$QuickReply {
  const factory QuickReply({
    required String id,
    @Default('global') String scope,
    required String shortcut,
    required String title,
    required String body,
  }) = _QuickReply;

  factory QuickReply.fromJson(Map<String, dynamic> json) => _$QuickReplyFromJson(json);

  const QuickReply._();

  String fill({required String customer, required String ticketNumber, required String agent}) => body
      .replaceAll('{nama}', customer)
      .replaceAll('{nomor_tiket}', ticketNumber)
      .replaceAll('{nama_cs}', agent);
}
