import 'dart:typed_data';

import 'package:rendezvous_community/src/core/network/authorized_image.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';

abstract interface class MediaRepository {
  Future<Attachment> uploadPostImage(Uint8List bytes, {required String mimeType});

  Future<Attachment> uploadChatImage(String roomId, Uint8List bytes, {required String mimeType});

  Future<AuthorizedImage> attachmentImage(Attachment attachment);

  Future<Attachment> uploadSupportDocument(String roomId, Uint8List bytes, {required String name});

  Future<Uri> documentUri(Attachment attachment);
}
