// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_records.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NoteAuthor _$NoteAuthorFromJson(Map<String, dynamic> json) => _NoteAuthor(
  displayName: json['display_name'] as String,
  agentCode: json['agent_code'] as String?,
);

Map<String, dynamic> _$NoteAuthorToJson(_NoteAuthor instance) =>
    <String, dynamic>{
      'display_name': instance.displayName,
      'agent_code': instance.agentCode,
    };

_AgentNote _$AgentNoteFromJson(Map<String, dynamic> json) => _AgentNote(
  id: json['id'] as String,
  ticketId: _ticketOf(json, 'ticket_id') as String?,
  kind: json['kind'] as String? ?? 'note',
  body: json['body'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  author: json['author'] == null
      ? null
      : NoteAuthor.fromJson(json['author'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AgentNoteToJson(_AgentNote instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_id': instance.ticketId,
      'kind': instance.kind,
      'body': instance.body,
      'created_at': instance.createdAt.toIso8601String(),
      'author': instance.author?.toJson(),
    };

_TicketHistoryItem _$TicketHistoryItemFromJson(Map<String, dynamic> json) =>
    _TicketHistoryItem(
      id: json['id'] as String,
      ticketNumber: json['ticket_number'] as String?,
      topic: json['topic'] as String,
      status: json['status'] as String,
      flags:
          (json['flags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      closedAt: json['closed_at'] == null
          ? null
          : DateTime.parse(json['closed_at'] as String),
      outcome: json['outcome'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      agent: json['agent'] as String?,
    );

Map<String, dynamic> _$TicketHistoryItemToJson(_TicketHistoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_number': instance.ticketNumber,
      'topic': instance.topic,
      'status': instance.status,
      'flags': instance.flags,
      'created_at': instance.createdAt.toIso8601String(),
      'resolved_at': instance.resolvedAt?.toIso8601String(),
      'closed_at': instance.closedAt?.toIso8601String(),
      'outcome': instance.outcome,
      'rating': instance.rating,
      'agent': instance.agent,
    };
