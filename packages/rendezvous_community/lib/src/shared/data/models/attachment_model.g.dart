// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AttachmentModel _$AttachmentModelFromJson(Map<String, dynamic> json) => _AttachmentModel(
  path: json['path'] as String,
  mime: json['mime'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
);

Map<String, dynamic> _$AttachmentModelToJson(_AttachmentModel instance) => <String, dynamic>{
  'path': instance.path,
  'mime': instance.mime,
  'width': instance.width,
  'height': instance.height,
};
