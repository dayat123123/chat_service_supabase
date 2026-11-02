// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AttachmentModel _$AttachmentModelFromJson(Map<String, dynamic> json) => _AttachmentModel(
  path: json['path'] as String,
  bucket: json['bucket'] as String?,
  mime: json['mime'] as String?,
  name: json['name'] as String?,
  size: (json['size'] as num?)?.toInt(),
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
);

Map<String, dynamic> _$AttachmentModelToJson(_AttachmentModel instance) => <String, dynamic>{
  'path': instance.path,
  'bucket': ?instance.bucket,
  'mime': instance.mime,
  'name': ?instance.name,
  'size': ?instance.size,
  'width': instance.width,
  'height': instance.height,
};
