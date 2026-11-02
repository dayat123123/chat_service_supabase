import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/features/media/data/repositories/media_repository_impl.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';

import '../../support/mock_api.dart';

void main() {
  late MockApi api;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    api = mockApi();
    when(() => api.upload(any(), any(), any(), contentType: any(named: 'contentType'))).thenAnswer((_) async {});
    when(
      () => api.signedUrl(any(), any()),
    ).thenAnswer((_) async => 'https://api.test/storage/v1/object/sign/x?token=t');
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
