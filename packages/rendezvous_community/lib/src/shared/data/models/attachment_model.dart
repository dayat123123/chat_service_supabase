import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';

part 'attachment_model.freezed.dart';
part 'attachment_model.g.dart';

@freezed
abstract class AttachmentModel with _$AttachmentModel {
  const factory AttachmentModel({required String path, String? mime, int? width, int? height}) = _AttachmentModel;

  const AttachmentModel._();

  factory AttachmentModel.fromJson(Map<String, dynamic> json) => _$AttachmentModelFromJson(json);

  factory AttachmentModel.fromEntity(Attachment a) =>
      AttachmentModel(path: a.path, mime: a.mime, width: a.width, height: a.height);

  Attachment toEntity() => Attachment(path: path, mime: mime, width: width, height: height);
}
