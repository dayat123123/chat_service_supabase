import 'dart:typed_data';

import 'package:olt_social/src/core/network/authorized_image.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';

abstract interface class MediaRepository {
  Future<Attachment> uploadPostImage(Uint8List bytes, {required String mimeType});

  Future<Attachment> uploadChatImage(String roomId, Uint8List bytes, {required String mimeType});

  Future<AuthorizedImage> attachmentImage(Attachment attachment);
}
