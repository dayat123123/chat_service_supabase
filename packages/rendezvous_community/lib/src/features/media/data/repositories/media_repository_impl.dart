import 'dart:typed_data';

import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/core/network/authorized_image.dart';
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
    await _api.upload('attachments', path, bytes, contentType: mimeType);
    return Attachment(path: path, mime: mimeType);
  }

  @override
  Future<Attachment> uploadChatImage(String roomId, Uint8List bytes, {required String mimeType}) async {
    final me = await _api.requireUserId();
    final path = 'rooms/$roomId/$me/${_uuid.v4()}.${imageExtension(mimeType)}';
    await _api.upload('attachments', path, bytes, contentType: mimeType);
    return Attachment(path: path, mime: mimeType);
  }

  @override
  Future<AuthorizedImage> attachmentImage(Attachment attachment) =>
      _api.authorizedObject('attachments', attachment.path);
}
