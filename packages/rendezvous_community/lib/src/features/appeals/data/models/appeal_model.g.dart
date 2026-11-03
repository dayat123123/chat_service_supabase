// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appeal_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppealModel _$AppealModelFromJson(Map<String, dynamic> json) => _AppealModel(
  id: json['id'] as String,
  targetType: json['target_type'] as String,
  targetId: json['target_id'] as String,
  reason: json['reason'] as String? ?? '',
  status: json['status'] as String? ?? 'pending',
  decisionNote: json['decision_note'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  decidedAt: json['decided_at'] == null ? null : DateTime.parse(json['decided_at'] as String),
);

Map<String, dynamic> _$AppealModelToJson(_AppealModel instance) => <String, dynamic>{
  'id': instance.id,
  'target_type': instance.targetType,
  'target_id': instance.targetId,
  'reason': instance.reason,
  'status': instance.status,
  'decision_note': instance.decisionNote,
  'created_at': instance.createdAt.toIso8601String(),
  'decided_at': instance.decidedAt?.toIso8601String(),
};

_SanctionModel _$SanctionModelFromJson(Map<String, dynamic> json) => _SanctionModel(
  id: json['id'] as String,
  kind: json['kind'] as String,
  category: json['category'] as String?,
  reason: json['reason'] as String?,
  startsAt: json['starts_at'] == null ? null : DateTime.parse(json['starts_at'] as String),
  endsAt: json['ends_at'] == null ? null : DateTime.parse(json['ends_at'] as String),
);

Map<String, dynamic> _$SanctionModelToJson(_SanctionModel instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'category': instance.category,
  'reason': instance.reason,
  'starts_at': instance.startsAt?.toIso8601String(),
  'ends_at': instance.endsAt?.toIso8601String(),
};
