import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/auth/session_tokens.dart';
import 'package:rendezvous_community/src/core/network/media_gateway.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart' show lookupCommunityLocalizations;

class _Tokens implements SessionTokens {
  String token = 'jwt-1';
  int refreshes = 0;

  @override
  String? get currentUserId => 'u-1';

  @override
  Future<String> accessToken() async => token;

  @override
  Future<String> refreshUserId() async {
    refreshes++;
    token = 'jwt-2';
    return 'u-1';
  }
}

http.Response _json(int status, Map<String, Object?> body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  late _Tokens tokens;
  late List<http.Request> requests;

  MediaGatewayClient gateway(Future<http.Response> Function(http.Request request) handler) => MediaGatewayClient(
    baseUrl: 'https://social.test/',
    anonKey: 'anon-key',
    tokens: tokens,
    httpClient: MockClient((request) {
      requests.add(request);
      return handler(request);
    }),
  );

  setUp(() {
    tokens = _Tokens();
    requests = [];
  });

  test('posts the bytes to the media gateway with the session headers', () async {
    final client = gateway(
      (_) async => _json(200, {
        'bucket': 'attachments',
        'path': 'posts/u-1/a.png',
        'mime': 'image/png',
        'size': 3,
        'width': 2,
        'height': 1,
      }),
    );

    final object = await client.upload(
      'attachments',
      'posts/u-1/a.jpg',
      Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.toString(), 'https://social.test/media/v1/object/attachments/posts/u-1/a.jpg');
    expect(request.headers['apikey'], 'anon-key');
    expect(request.headers['Authorization'], 'Bearer jwt-1');
    expect(request.headers['Content-Type'], startsWith('image/jpeg'));
    expect(request.headers.containsKey('x-upsert'), isFalse);
    expect(request.bodyBytes, [1, 2, 3]);
    expect(object.path, 'posts/u-1/a.png');
    expect(object.mime, 'image/png');
    expect((object.size, object.width, object.height), (3, 2, 1));
  });

  test('sends x-upsert only when asked to overwrite', () async {
    final client = gateway(
      (request) async => _json(200, {'bucket': 'avatars', 'path': request.url.pathSegments.last, 'mime': 'image/png'}),
    );

    await client.upload('avatars', 'u-1/avatar-1.png', Uint8List(1), contentType: 'image/png', upsert: true);

    expect(requests.single.headers['x-upsert'], 'true');
    expect(requests.single.url.path, '/media/v1/object/avatars/u-1/avatar-1.png');
  });

  test('refreshes an expired session once and retries', () async {
    final client = gateway(
      (request) async => request.headers['Authorization'] == 'Bearer jwt-1'
          ? _json(401, {'code': 'invalid_token', 'message': 'Token tidak valid'})
          : _json(200, {'bucket': 'attachments', 'path': 'p/a.gif', 'mime': 'image/gif'}),
    );

    final object = await client.upload('attachments', 'p/a.gif', Uint8List(1), contentType: 'image/gif');

    expect(tokens.refreshes, 1);
    expect(requests.map((r) => r.headers['Authorization']), ['Bearer jwt-1', 'Bearer jwt-2']);
    expect(object.mime, 'image/gif');
  });

  group('maps gateway errors to localized messages', () {
    final l10n = lookupCommunityLocalizations(const Locale('id'));
    final cases = <(int, String?, CommunityErrorKind, String)>[
      (415, 'unsupported_type', CommunityErrorKind.invalidInput, l10n.errorUnsupportedType),
      (413, 'file_too_large', CommunityErrorKind.invalidInput, l10n.errorFileTooLarge),
      (400, 'empty_file', CommunityErrorKind.invalidInput, l10n.errorEmptyFile),
      (422, 'invalid_image', CommunityErrorKind.invalidInput, l10n.errorInvalidImage),
      (422, 'image_too_large', CommunityErrorKind.invalidInput, l10n.errorImageTooLarge),
      (422, 'invalid_pdf', CommunityErrorKind.invalidInput, l10n.errorInvalidPdf),
      (422, 'pdf_encrypted', CommunityErrorKind.invalidInput, l10n.errorPdfEncrypted),
      (422, 'pdf_active_content', CommunityErrorKind.invalidInput, l10n.errorPdfActiveContent),
      (403, 'upload_forbidden', CommunityErrorKind.forbidden, l10n.errorUploadForbidden),
      (429, 'too_many_uploads', CommunityErrorKind.rateLimited, l10n.errorTooManyUploads),
      (503, 'busy', CommunityErrorKind.unavailable, l10n.errorUploadBusy),
      (502, 'storage_unavailable', CommunityErrorKind.unavailable, l10n.errorStorageUnavailable),
      (502, 'storage_error', CommunityErrorKind.unavailable, l10n.errorStorageUnavailable),
      (404, null, CommunityErrorKind.unavailable, l10n.errorStorageUnavailable),
    ];
    for (final (status, code, kind, message) in cases) {
      test('$status ${code ?? 'without a code'}', () async {
        final client = gateway(
          (_) async => code == null
              ? http.Response('{"message":"no Route matched with those values"}', status)
              : _json(status, {'code': code, 'message': 'Pesan server'}),
        );

        final error = await client
            .upload('attachments', 'posts/u-1/a.jpg', Uint8List(1), contentType: 'image/jpeg')
            .then<Object?>((_) => null, onError: (Object e) => e);

        expect(error, isA<CommunityException>().having((e) => e.kind, 'kind', kind));
        expect(l10n.errorMessage(error!), message);
      });
    }
  });

  test('RendezvousCommunity uploads through the gateway instead of Storage', () async {
    final seen = <http.Request>[];
    final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': 'u-1', 'exp': expiresAt}))).replaceAll('=', '');
    final community = RendezvousCommunity.create(
      supabaseUrl: 'http://api.test',
      anonKey: 'anon',
      tokenProvider: () async => 'olt-session',
      trackDelivery: false,
      httpClient: MockClient((request) async {
        seen.add(request);
        final path = request.url.path;
        if (path == '/bridge/v1/exchange') {
          return _json(200, {
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.c2ln',
            'expires_at': expiresAt,
            'user': {'id': 'u-1', 'username': 'budi_santoso'},
          });
        }
        if (path.startsWith('/media/v1/object/')) {
          final segments = request.url.pathSegments.skip(3).toList();
          return _json(200, {'bucket': segments.first, 'path': segments.skip(1).join('/'), 'mime': 'image/png'});
        }
        return http.Response('[]', 200, request: request);
      }),
    );
    addTearDown(community.dispose);
    await community.ensureSignedIn();

    final attachment = await community.media.uploadPostImage(Uint8List(3), mimeType: 'image/png');
    await community.profiles.uploadAvatar(Uint8List(3), mimeType: 'image/png');

    final uploads = seen.where((r) => r.url.path.startsWith('/media/v1/object/')).toList();
    expect(uploads, hasLength(2));
    expect(uploads.first.url.path, startsWith('/media/v1/object/attachments/posts/u-1/'));
    expect(uploads.first.headers.containsKey('x-upsert'), isFalse);
    expect(uploads.last.url.path, startsWith('/media/v1/object/avatars/u-1/avatar-'));
    expect(uploads.last.headers['x-upsert'], 'true');
    expect(uploads.every((r) => r.headers['Authorization'] == 'Bearer eyJhbGciOiJIUzI1NiJ9.$payload.c2ln'), isTrue);
    expect(seen.where((r) => r.url.path.startsWith('/storage/v1/object/attachments')), isEmpty);
    expect(attachment.path, startsWith('posts/u-1/'));
  });

  test('a lost connection is a network error', () async {
    final client = gateway((_) async => throw http.ClientException('offline'));

    await expectLater(
      client.upload('attachments', 'posts/u-1/a.jpg', Uint8List(1), contentType: 'image/jpeg'),
      throwsA(isA<CommunityException>().having((e) => e.kind, 'kind', CommunityErrorKind.network)),
    );
  });
}
