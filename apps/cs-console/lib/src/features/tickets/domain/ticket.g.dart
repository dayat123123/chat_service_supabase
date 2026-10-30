// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TicketCustomer _$TicketCustomerFromJson(Map<String, dynamic> json) =>
    _TicketCustomer(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      deleted: json['deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$TicketCustomerToJson(_TicketCustomer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'username': instance.username,
      'deleted': instance.deleted,
    };

_TicketOwner _$TicketOwnerFromJson(Map<String, dynamic> json) => _TicketOwner(
  id: json['id'] as String,
  displayName: json['display_name'] as String,
  agentCode: json['agent_code'] as String?,
  status:
      $enumDecodeNullable(
        _$AgentStatusEnumMap,
        json['status'],
        unknownValue: AgentStatus.offline,
      ) ??
      AgentStatus.offline,
);

Map<String, dynamic> _$TicketOwnerToJson(_TicketOwner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'agent_code': instance.agentCode,
      'status': _$AgentStatusEnumMap[instance.status]!,
    };

const _$AgentStatusEnumMap = {
  AgentStatus.online: 'online',
  AgentStatus.busy: 'busy',
  AgentStatus.onBreak: 'break',
  AgentStatus.offline: 'offline',
};

_PendingTransfer _$PendingTransferFromJson(Map<String, dynamic> json) =>
    _PendingTransfer(
      id: json['id'] as String,
      fromId: json['from_id'] as String?,
      fromName: json['from_name'] as String?,
      toId: json['to_id'] as String?,
      toName: json['to_name'] as String?,
      note: json['note'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$PendingTransferToJson(_PendingTransfer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'from_id': instance.fromId,
      'from_name': instance.fromName,
      'to_id': instance.toId,
      'to_name': instance.toName,
      'note': instance.note,
      'expires_at': instance.expiresAt?.toIso8601String(),
    };

_TicketEvent _$TicketEventFromJson(Map<String, dynamic> json) => _TicketEvent(
  type: json['type'] as String,
  actorType: json['actor_type'] as String?,
  actorName: json['actor_name'] as String?,
  data: json['data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$TicketEventToJson(_TicketEvent instance) =>
    <String, dynamic>{
      'type': instance.type,
      'actor_type': instance.actorType,
      'actor_name': instance.actorName,
      'data': instance.data,
      'created_at': instance.createdAt.toIso8601String(),
    };

_Ticket _$TicketFromJson(Map<String, dynamic> json) => _Ticket(
  id: json['id'] as String,
  ticketNumber: json['ticket_number'] as String,
  roomId: json['room_id'] as String,
  status: $enumDecode(
    _$TicketStatusEnumMap,
    json['status'],
    unknownValue: TicketStatus.closed,
  ),
  version: (json['version'] as num?)?.toInt() ?? 1,
  topic: json['topic'] as String,
  priority: json['priority'] as String? ?? 'P3',
  flags:
      (json['flags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  language: json['language'] as String? ?? 'id',
  customer: json['customer'] == null
      ? null
      : TicketCustomer.fromJson(json['customer'] as Map<String, dynamic>),
  owner: json['owner'] == null
      ? null
      : TicketOwner.fromJson(json['owner'] as Map<String, dynamic>),
  isMine: json['is_mine'] as bool? ?? false,
  queuedAt: json['queued_at'] == null
      ? null
      : DateTime.parse(json['queued_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  claimedAt: json['claimed_at'] == null
      ? null
      : DateTime.parse(json['claimed_at'] as String),
  firstResponseAt: json['first_response_at'] == null
      ? null
      : DateTime.parse(json['first_response_at'] as String),
  lastCustomerMessageAt: json['last_customer_message_at'] == null
      ? null
      : DateTime.parse(json['last_customer_message_at'] as String),
  lastAgentMessageAt: json['last_agent_message_at'] == null
      ? null
      : DateTime.parse(json['last_agent_message_at'] as String),
  resolvedAt: json['resolved_at'] == null
      ? null
      : DateTime.parse(json['resolved_at'] as String),
  closedAt: json['closed_at'] == null
      ? null
      : DateTime.parse(json['closed_at'] as String),
  outcome: json['outcome'] as String?,
  resolutionSummary: json['resolution_summary'] as String?,
  returnedReason: json['returned_reason'] as String?,
  complaintReceivedAt: json['complaint_received_at'] == null
      ? null
      : DateTime.parse(json['complaint_received_at'] as String),
  complaintDueAt: json['complaint_due_at'] == null
      ? null
      : DateTime.parse(json['complaint_due_at'] as String),
  rating: (json['rating'] as num?)?.toInt(),
  ratingComment: json['rating_comment'] as String?,
  transfer: json['transfer'] == null
      ? null
      : PendingTransfer.fromJson(json['transfer'] as Map<String, dynamic>),
  preview: json['preview'] as String?,
  unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
  waitingSince: json['waiting_since'] == null
      ? null
      : DateTime.parse(json['waiting_since'] as String),
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  events:
      (json['events'] as List<dynamic>?)
          ?.map((e) => TicketEvent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TicketEvent>[],
);

Map<String, dynamic> _$TicketToJson(_Ticket instance) => <String, dynamic>{
  'id': instance.id,
  'ticket_number': instance.ticketNumber,
  'room_id': instance.roomId,
  'status': _$TicketStatusEnumMap[instance.status]!,
  'version': instance.version,
  'topic': instance.topic,
  'priority': instance.priority,
  'flags': instance.flags,
  'language': instance.language,
  'customer': instance.customer?.toJson(),
  'owner': instance.owner?.toJson(),
  'is_mine': instance.isMine,
  'queued_at': instance.queuedAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
  'claimed_at': instance.claimedAt?.toIso8601String(),
  'first_response_at': instance.firstResponseAt?.toIso8601String(),
  'last_customer_message_at': instance.lastCustomerMessageAt?.toIso8601String(),
  'last_agent_message_at': instance.lastAgentMessageAt?.toIso8601String(),
  'resolved_at': instance.resolvedAt?.toIso8601String(),
  'closed_at': instance.closedAt?.toIso8601String(),
  'outcome': instance.outcome,
  'resolution_summary': instance.resolutionSummary,
  'returned_reason': instance.returnedReason,
  'complaint_received_at': instance.complaintReceivedAt?.toIso8601String(),
  'complaint_due_at': instance.complaintDueAt?.toIso8601String(),
  'rating': instance.rating,
  'rating_comment': instance.ratingComment,
  'transfer': instance.transfer?.toJson(),
  'preview': instance.preview,
  'unread_count': instance.unreadCount,
  'waiting_since': instance.waitingSince?.toIso8601String(),
  'tags': instance.tags,
  'events': instance.events.map((e) => e.toJson()).toList(),
};

const _$TicketStatusEnumMap = {
  TicketStatus.open: 'open',
  TicketStatus.claimed: 'claimed',
  TicketStatus.waitingCustomer: 'waiting_customer',
  TicketStatus.resolved: 'resolved',
  TicketStatus.closed: 'closed',
};

_TransferRequest _$TransferRequestFromJson(Map<String, dynamic> json) =>
    _TransferRequest(
      id: json['id'] as String,
      note: json['note'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      fromName: json['from_name'] as String?,
      ticket: Ticket.fromJson(json['ticket'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TransferRequestToJson(_TransferRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'note': instance.note,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'from_name': instance.fromName,
      'ticket': instance.ticket.toJson(),
    };

_OutgoingTransfer _$OutgoingTransferFromJson(Map<String, dynamic> json) =>
    _OutgoingTransfer(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      toName: json['to_name'] as String?,
    );

Map<String, dynamic> _$OutgoingTransferToJson(_OutgoingTransfer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_id': instance.ticketId,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'to_name': instance.toName,
    };

_TicketLists _$TicketListsFromJson(Map<String, dynamic> json) => _TicketLists(
  open:
      (json['open'] as List<dynamic>?)
          ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Ticket>[],
  mine:
      (json['mine'] as List<dynamic>?)
          ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Ticket>[],
  resolvedToday:
      (json['resolved_today'] as List<dynamic>?)
          ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Ticket>[],
  allActive:
      (json['all_active'] as List<dynamic>?)
          ?.map((e) => Ticket.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Ticket>[],
  transfersIn:
      (json['transfers_in'] as List<dynamic>?)
          ?.map((e) => TransferRequest.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TransferRequest>[],
  transfersOut:
      (json['transfers_out'] as List<dynamic>?)
          ?.map((e) => OutgoingTransfer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <OutgoingTransfer>[],
);

Map<String, dynamic> _$TicketListsToJson(_TicketLists instance) =>
    <String, dynamic>{
      'open': instance.open.map((e) => e.toJson()).toList(),
      'mine': instance.mine.map((e) => e.toJson()).toList(),
      'resolved_today': instance.resolvedToday.map((e) => e.toJson()).toList(),
      'all_active': instance.allActive.map((e) => e.toJson()).toList(),
      'transfers_in': instance.transfersIn.map((e) => e.toJson()).toList(),
      'transfers_out': instance.transfersOut.map((e) => e.toJson()).toList(),
    };

_SupportTopic _$SupportTopicFromJson(Map<String, dynamic> json) =>
    _SupportTopic(
      code: json['code'] as String,
      name: json['name'] as String,
      helpUrl: json['help_url'] as String?,
      urgent: json['urgent'] as bool? ?? false,
    );

Map<String, dynamic> _$SupportTopicToJson(_SupportTopic instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'help_url': instance.helpUrl,
      'urgent': instance.urgent,
    };

_QuickReply _$QuickReplyFromJson(Map<String, dynamic> json) => _QuickReply(
  id: json['id'] as String,
  scope: json['scope'] as String? ?? 'global',
  shortcut: json['shortcut'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
);

Map<String, dynamic> _$QuickReplyToJson(_QuickReply instance) =>
    <String, dynamic>{
      'id': instance.id,
      'scope': instance.scope,
      'shortcut': instance.shortcut,
      'title': instance.title,
      'body': instance.body,
    };
