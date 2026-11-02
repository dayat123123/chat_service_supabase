// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SupportTicketModel _$SupportTicketModelFromJson(Map<String, dynamic> json) => _SupportTicketModel(
  id: json['id'] as String,
  ticketNumber: json['ticket_number'] as String,
  roomId: json['room_id'] as String,
  topic: json['topic'] as String,
  topicName: json['topic_name'] as String?,
  status: json['status'] as String,
  queueAhead: (json['queue_ahead'] as num?)?.toInt(),
  agent: json['agent'] as Map<String, dynamic>?,
  complaint: json['complaint'] as Map<String, dynamic>?,
  createdAt: DateTime.parse(json['created_at'] as String),
  resolvedAt: json['resolved_at'] == null ? null : DateTime.parse(json['resolved_at'] as String),
  closedAt: json['closed_at'] == null ? null : DateTime.parse(json['closed_at'] as String),
  reopenUntil: json['reopen_until'] == null ? null : DateTime.parse(json['reopen_until'] as String),
  rating: (json['rating'] as num?)?.toInt(),
  canRate: json['can_rate'] as bool? ?? false,
);

Map<String, dynamic> _$SupportTicketModelToJson(_SupportTicketModel instance) => <String, dynamic>{
  'id': instance.id,
  'ticket_number': instance.ticketNumber,
  'room_id': instance.roomId,
  'topic': instance.topic,
  'topic_name': instance.topicName,
  'status': instance.status,
  'queue_ahead': instance.queueAhead,
  'agent': instance.agent,
  'complaint': instance.complaint,
  'created_at': instance.createdAt.toIso8601String(),
  'resolved_at': instance.resolvedAt?.toIso8601String(),
  'closed_at': instance.closedAt?.toIso8601String(),
  'reopen_until': instance.reopenUntil?.toIso8601String(),
  'rating': instance.rating,
  'can_rate': instance.canRate,
};

_SupportHomeModel _$SupportHomeModelFromJson(Map<String, dynamic> json) => _SupportHomeModel(
  roomId: json['room_id'] as String?,
  supportName: json['support_name'] as String? ?? '',
  ticket: json['ticket'] == null ? null : SupportTicketModel.fromJson(json['ticket'] as Map<String, dynamic>),
  active: json['active'] as bool? ?? false,
  unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
  serviceOpen: json['service_open'] as bool? ?? true,
  nextOpenAt: json['next_open_at'] == null ? null : DateTime.parse(json['next_open_at'] as String),
);

Map<String, dynamic> _$SupportHomeModelToJson(_SupportHomeModel instance) => <String, dynamic>{
  'room_id': instance.roomId,
  'support_name': instance.supportName,
  'ticket': instance.ticket?.toJson(),
  'active': instance.active,
  'unread_count': instance.unreadCount,
  'service_open': instance.serviceOpen,
  'next_open_at': instance.nextOpenAt?.toIso8601String(),
};
