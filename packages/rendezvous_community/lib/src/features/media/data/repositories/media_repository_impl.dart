import 'dart:typed_data';

import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/core/network/authorized_image.dart';
import 'package:rendezvous_community/src/core/network/media_gateway.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<Attachment> uploadPostImage(Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    final path = 'posts/$me/${_uuid.v4()}.${imageExtension(mimeType)}';
    return _image(await _api.upload(attachmentBucket, path, bytes, contentType: mimeType));
  }

  @override
  Future<Attachment> uploadChatImage(String roomId, Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    final path = 'rooms/$roomId/$me/${_uuid.v4()}.${imageExtension(mimeType)}';
    return _image(await _api.upload(attachmentBucket, path, bytes, contentType: mimeType));
  }

  Attachment _image(UploadedObject object) =>
      Attachment(path: object.path, mime: object.mime, width: object.width, height: object.height, held: object.held);

  @override
  Future<AuthorizedImage> attachmentImage(Attachment attachment) =>
      _api.authorizedObject(attachmentBucket, attachment.path);

  @override
  Future<Attachment> uploadSupportDocument(String roomId, Uint8List bytes, {required String name}) async {
    final me = await _api.requireUserId();
    final path = 'rooms/$roomId/$me/${_uuid.v4()}.pdf';
    final object = await _api.upload(supportDocumentBucket, path, bytes, contentType: pdfMimeType);
    return Attachment(
      path: object.path,
      bucket: supportDocumentBucket,
      mime: object.mime,
      name: name.length > 200 ? name.substring(0, 200) : name,
      size: object.size ?? bytes.length,
    );
  }

  @override
  Future<Uri> documentUri(Attachment attachment) async =>
      Uri.parse(await _api.signedUrl(attachment.bucket ?? supportDocumentBucket, attachment.path));
}
