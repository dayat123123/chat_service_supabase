import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/auth/session_tokens.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/network/media_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens implements SessionTokens {
  @override
  String? get currentUserId => 'u-1';

  @override
  Future<String> accessToken() async => 'jwt';

  @override
  Future<String> refreshUserId() async => 'u-1';
}

PostgrestException _pg(String code, String message, [String? details]) =>
    PostgrestException(message: message, code: code, details: details);

void main() {
  late CommunityLocalizations id;
  late CommunityLocalizations en;

  setUpAll(() async {
    id = await CommunityLocalizations.delegate.load(const Locale('id'));
    en = await CommunityLocalizations.delegate.load(const Locale('en'));
  });

  test('slow_mode carries the wait from details as retryAfter', () {
    final error = mapError(_pg('PT429', 'slow_mode', '12'));
    expect(error.kind, CommunityErrorKind.rateLimited);
    expect(error.code, 'slow_mode');
    expect(error.retryAfter, const Duration(seconds: 12));
    expect(id.errorMessage(error), contains('12 detik'));
    expect(en.errorMessage(error), contains('12 seconds'));
    expect(id.errorMessage(const CommunityException(CommunityErrorKind.rateLimited, code: 'slow_mode')), isNotEmpty);
  });

  test('rate limits without a numeric detail have no retryAfter', () {
    expect(mapError(_pg('PT429', 'rate_limited', 'Coba lagi nanti')).retryAfter, isNull);
  });

  test('social_disabled (503) maps to unavailable with its own message', () {
    final error = mapError(_pg('PT503', 'social_disabled'));
    expect(error.kind, CommunityErrorKind.unavailable);
    expect(id.errorMessage(error), id.errorSocialDisabled);
  });

  test('every new code has a localized message that does not leak rule details', () {
    final codes = {
      ('PT403', 'new_account_restricted', 'image'): id.errorNewAccountImage,
      ('PT403', 'new_account_restricted', 'link'): id.errorNewAccountLink,
      ('PT422', 'link_blocked', null): id.errorLinkBlocked,
      ('PT422', 'contact_blocked', null): id.errorContactBlocked,
      ('PT422', 'content_blocked', null): id.errorContentBlocked,
      ('PT403', 'dm_not_allowed', null): id.errorDmNotAllowed,
      ('PT403', 'dm_request_limit', null): id.errorDmRequestLimit,
      ('PT403', 'edit_window_expired', null): id.errorEditWindowExpired,
      ('PT409', 'poll_not_editable', null): id.errorPollNotEditable,
      ('PT409', 'appeal_exists', null): id.errorAppealExists,
      ('PT400', 'appeal_window_closed', null): id.errorAppealWindowClosed,
      ('PT400', 'query_too_short', null): id.errorQueryTooShort,
      ('PT400', 'share_not_allowed', null): id.errorShareNotAllowed,
    };
    codes.forEach((key, message) {
      final (status, code, details) = key;
      expect(id.errorMessage(_pg(status, code, details)), message, reason: code);
    });
    expect(id.errorContactBlocked.toLowerCase(), isNot(contains('nomor')));
    expect(id.errorMessage(_pg('PT403', 'appeal_reviewer_conflict')), id.errorForbidden);
  });

  group('media gateway', () {
    MediaGatewayClient client(http.Response Function(http.Request) handler) => MediaGatewayClient(
      baseUrl: 'http://api.test',
      anonKey: 'anon',
      tokens: _Tokens(),
      httpClient: MockClient((request) async => handler(request)),
    );

    test('held uploads are flagged', () async {
      final uploaded = await client(
        (r) => http.Response(
          jsonEncode({'bucket': 'attachments', 'path': 'posts/u-1/a.jpg', 'mime': 'image/jpeg', 'held': true}),
          200,
        ),
      ).upload('attachments', 'posts/u-1/a.jpg', Uint8List(3), contentType: 'image/jpeg');
      expect(uploaded.held, isTrue);
    });

    test('classifier errors carry Retry-After and localized messages', () async {
      Future<CommunityException> fail(int status, String code) async {
        try {
          await client(
            (r) => http.Response(jsonEncode({'code': code}), status, headers: {'retry-after': '2'}),
          ).upload('attachments', 'posts/u-1/a.jpg', Uint8List(3), contentType: 'image/jpeg');
        } on CommunityException catch (e) {
          return e;
        }
        throw StateError('upload did not fail');
      }

      final unavailable = await fail(503, 'classifier_unavailable');
      expect(unavailable.kind, CommunityErrorKind.unavailable);
      expect(unavailable.retryAfter, const Duration(seconds: 2));
      expect(id.errorMessage(unavailable), id.errorImageCheckUnavailable);
      expect(id.errorMessage(await fail(503, 'moderation_unavailable')), id.errorImageCheckUnavailable);
      final blocked = await fail(422, 'image_blocked');
      expect(blocked.kind, CommunityErrorKind.invalidInput);
      expect(id.errorMessage(blocked), id.errorImageBlocked);
    });
  });
}
