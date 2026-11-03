import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/core/network/media_gateway.dart';
import 'package:rendezvous_community/src/features/media/data/repositories/media_repository_impl.dart';
import 'package:rendezvous_community/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';

import '../../support/mock_api.dart';

void main() {
  late MockApi api;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  void answerUpload({String? path, String? mime, int? size, int? width, int? height}) {
    when(
      () => api.upload(
        any(),
        any(),
        any(),
        contentType: any(named: 'contentType'),
        upsert: any(named: 'upsert'),
      ),
    ).thenAnswer((invocation) async {
      final bucket = invocation.positionalArguments[0] as String;
      final requested = invocation.positionalArguments[1] as String;
      final bytes = invocation.positionalArguments[2] as Uint8List;
      return UploadedObject(
        bucket: bucket,
        path: path ?? requested,
        mime: mime ?? invocation.namedArguments[#contentType] as String,
        size: size ?? bytes.length,
        width: width,
        height: height,
      );
    });
  }

  setUp(() {
    api = mockApi();
    answerUpload();
    when(
      () => api.signedUrl(any(), any()),
    ).thenAnswer((_) async => 'https://api.test/storage/v1/object/sign/x?token=t');
    when(() => api.publicUrl(any(), any())).thenAnswer(
      (invocation) => 'https://api.test/storage/v1/object/public/${invocation.positionalArguments.join('/')}',
    );
    when(() => api.update(any(), any(), any())).thenAnswer((_) async {});
  });

  test('support documents go to the private PDF bucket with their name and size', () async {
    final bytes = Uint8List(2048);
    final attachment = await MediaRepositoryImpl(api).uploadSupportDocument('r-1', bytes, name: 'Bukti Transfer.pdf');

    final captured = verify(
      () => api.upload(captureAny(), captureAny(), bytes, contentType: 'application/pdf'),
    ).captured;
    expect(captured.first, 'cs-documents');
    expect(captured.last as String, matches(RegExp(r'^rooms/r-1/u-1/[0-9a-f-]{36}\.pdf$')));
    expect(attachment.isDocument, isTrue);
    expect(AttachmentModel.fromEntity(attachment).toJson(), {
      'path': attachment.path,
      'bucket': 'cs-documents',
      'mime': 'application/pdf',
      'name': 'Bukti Transfer.pdf',
      'size': 2048,
      'width': null,
      'height': null,
    });
  });

  test('images use the path and type chosen by the media gateway', () async {
    answerUpload(path: 'posts/u-1/abc.png', mime: 'image/png', width: 640, height: 480);
    final attachment = await MediaRepositoryImpl(api).uploadPostImage(Uint8List(10), mimeType: 'image/jpeg');

    final captured = verify(() => api.upload('attachments', captureAny(), any(), contentType: 'image/jpeg')).captured;
    expect(captured.single as String, matches(RegExp(r'^posts/u-1/[0-9a-f-]{36}\.jpg$')));
    expect(attachment, const Attachment(path: 'posts/u-1/abc.png', mime: 'image/png', width: 640, height: 480));
  });

  test('chat images keep GIF and go under the room folder without upsert', () async {
    final attachment = await MediaRepositoryImpl(api).uploadChatImage('r-9', Uint8List(4), mimeType: 'image/gif');

    final captured = verify(() => api.upload('attachments', captureAny(), any(), contentType: 'image/gif')).captured;
    expect(captured.single as String, matches(RegExp(r'^rooms/r-9/u-1/[0-9a-f-]{36}\.gif$')));
    expect(attachment.mime, 'image/gif');
  });

  test('only the avatar upload asks the gateway to overwrite', () async {
    answerUpload(path: 'u-1/avatar-1.webp', mime: 'image/webp');
    final url = await ProfileRepositoryImpl(api).uploadAvatar(Uint8List(8), mimeType: 'image/png');

    verify(() => api.upload('avatars', any(), any(), contentType: 'image/png', upsert: true)).called(1);
    verify(() => api.publicUrl('avatars', 'u-1/avatar-1.webp')).called(1);
    verify(() => api.update('profiles', {'avatar_url': url}, {'id': 'u-1'})).called(1);
    expect(url, endsWith('/avatars/u-1/avatar-1.webp'));

    await MediaRepositoryImpl(api).uploadPostImage(Uint8List(4), mimeType: 'image/png');
    verifyNever(() => api.upload('attachments', any(), any(), contentType: any(named: 'contentType'), upsert: true));
  });

  test('avatars reject GIF before uploading', () async {
    await expectLater(
      ProfileRepositoryImpl(api).uploadAvatar(Uint8List(8), mimeType: 'image/gif'),
      throwsA(isA<Object>().having((e) => '$e', 'error', contains('unsupported_type'))),
    );
    verifyNever(
      () => api.upload(
        any(),
        any(),
        any(),
        contentType: any(named: 'contentType'),
        upsert: any(named: 'upsert'),
      ),
    );
  });

  test('images keep the attachment JSON without document fields', () {
    const image = Attachment(path: 'rooms/r-1/u-1/a.png', mime: 'image/png', width: 10, height: 20);
    expect(image.isDocument, isFalse);
    expect(AttachmentModel.fromEntity(image).toJson(), {
      'path': 'rooms/r-1/u-1/a.png',
      'mime': 'image/png',
      'width': 10,
      'height': 20,
    });
  });

  test('documents open through a short-lived signed URL', () async {
    final uri = await MediaRepositoryImpl(
      api,
    ).documentUri(const Attachment(path: 'rooms/r-1/u-2/b.pdf', bucket: 'cs-documents', mime: 'application/pdf'));

    verify(() => api.signedUrl('cs-documents', 'rooms/r-1/u-2/b.pdf')).called(1);
    expect(uri.host, 'api.test');
  });
}
