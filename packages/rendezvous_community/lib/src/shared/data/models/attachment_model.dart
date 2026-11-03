import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';

part 'attachment_model.freezed.dart';
part 'attachment_model.g.dart';

List<AttachmentModel> attachmentsFromJson(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map && item['path'] is String) AttachmentModel.fromJson(Map<String, dynamic>.from(item)),
];

List<String> stockCodesFromJson(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map && item['type'] == 'stock' && item['code'] is String) item['code'] as String,
];

String? sharedPostIdFromJson(Object? value) {
  if (value is! List) return null;
  for (final item in value) {
    if (item is Map && item['type'] == 'post' && item['post_id'] is String) return item['post_id'] as String;
  }
  return null;
}

@freezed
abstract class AttachmentModel with _$AttachmentModel {
  const factory AttachmentModel({
    required String path,
    @JsonKey(includeIfNull: false) String? bucket,
    String? mime,
    @JsonKey(includeIfNull: false) String? name,
    @JsonKey(includeIfNull: false) int? size,
    int? width,
    int? height,
  }) = _AttachmentModel;

  const AttachmentModel._();

  factory AttachmentModel.fromJson(Map<String, dynamic> json) => _$AttachmentModelFromJson(json);

  factory AttachmentModel.fromEntity(Attachment a) => AttachmentModel(
    path: a.path,
    bucket: a.bucket,
    mime: a.mime,
    name: a.name,
    size: a.size,
    width: a.width,
    height: a.height,
  );

  Attachment toEntity() =>
      Attachment(path: path, bucket: bucket, mime: mime, name: name, size: size, width: width, height: height);
}
