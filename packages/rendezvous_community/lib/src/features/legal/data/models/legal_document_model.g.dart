// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_document_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LegalDocumentModel _$LegalDocumentModelFromJson(Map<String, dynamic> json) => _LegalDocumentModel(
  id: json['id'] as String,
  kind: json['kind'] as String,
  version: (json['version'] as num).toInt(),
  title: json['title'] as String,
  body: json['body'] as String? ?? '',
  changeSummary: json['change_summary'] as String?,
  effectiveAt: DateTime.parse(json['effective_at'] as String),
  isRequired: json['required'] as bool? ?? false,
  isAccepted: json['accepted'] as bool? ?? false,
);

Map<String, dynamic> _$LegalDocumentModelToJson(_LegalDocumentModel instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'version': instance.version,
  'title': instance.title,
  'body': instance.body,
  'change_summary': instance.changeSummary,
  'effective_at': instance.effectiveAt.toIso8601String(),
  'required': instance.isRequired,
  'accepted': instance.isAccepted,
};
