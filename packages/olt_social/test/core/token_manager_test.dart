import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olt_social/src/core/auth/auth_bridge_client.dart';
import 'package:olt_social/src/core/auth/token_manager.dart';
import 'package:olt_social/src/core/errors/olt_social_exception.dart';

void main() {
  late DateTime now;
  late int exchangeCalls;
  late List<String> sentTokens;

  http.Response okResponse(int ttlSeconds) {
    final exp = now.add(Duration(seconds: ttlSeconds));
    return http.Response(
      jsonEncode({
        'access_token': 'jwt-$exchangeCalls',
        'token_type': 'bearer',
        'expires_in': ttlSeconds,
        'expires_at': exp.millisecondsSinceEpoch ~/ 1000,
        'user': {'id': 'u-1', 'username': 'budi', 'display_name': 'Budi', 'avatar_url': null, 'is_verified': true},
      }),
      200,
    );
  }

  TokenManager build({String? oltToken = 'olt-token', int ttl = 900, int status = 200}) {
    final client = MockClient((request) async {
      exchangeCalls++;
      expect(request.url.path, '/bridge/v1/exchange');
      expect(request.headers['apikey'], 'anon');
      sentTokens.add((jsonDecode(request.body) as Map<String, dynamic>)['token'] as String);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (status != 200) {
        return http.Response(jsonEncode({'error': 'invalid_token', 'message': 'login ulang'}), status);
      }
      return okResponse(ttl);
    });
    return TokenManager(
      bridge: AuthBridgeClient(baseUrl: 'http://localhost:8000/bridge/v1/', anonKey: 'anon', httpClient: client),
      oltTokenProvider: () async => oltToken,
      clock: () => now,
    );
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 29, 9);
    exchangeCalls = 0;
    sentTokens = [];
  });

  test('menukar token OLT dan memakai ulang JWT yang masih berlaku', () async {
    final tokens = build();
    expect(await tokens.accessToken(), 'jwt-1');
    expect(await tokens.accessToken(), 'jwt-1');
    expect(exchangeCalls, 1);
    expect(sentTokens, ['olt-token']);
    expect(tokens.currentSession!.user.username, 'budi');
    await tokens.dispose();
  });

  test('refresh paralel digabung menjadi satu panggilan', () async {
    final tokens = build();
    final results = await Future.wait([tokens.accessToken(), tokens.accessToken(), tokens.refresh().then((s) => s.accessToken)]);
    expect(results.toSet(), {'jwt-1'});
    expect(exchangeCalls, 1);
    await tokens.dispose();
  });

  test('JWT yang hampir kedaluwarsa ditukar ulang', () async {
    final tokens = build(ttl: 120);
    await tokens.accessToken();
    now = now.add(const Duration(seconds: 100)); // sisa 20 dtk < margin/2 (30 dtk)
    expect(await tokens.accessToken(), 'jwt-2');
    expect(exchangeCalls, 2);
    await tokens.dispose();
  });

  test('sesi baru diumumkan lewat sessionChanges', () async {
    final tokens = build();
    final next = tokens.sessionChanges.first;
    await tokens.refresh();
    expect((await next)!.accessToken, 'jwt-1');
    await tokens.dispose();
  });

  test('tanpa token OLT -> unauthenticated tanpa memanggil auth-bridge', () async {
    final tokens = build(oltToken: null);
    await expectLater(
      tokens.accessToken(),
      throwsA(isA<OltSocialException>().having((e) => e.kind, 'kind', OltSocialErrorKind.unauthenticated)),
    );
    expect(exchangeCalls, 0);
    await tokens.dispose();
  });

  test('token OLT ditolak auth-bridge -> unauthenticated', () async {
    final tokens = build(status: 401);
    await expectLater(
      tokens.refresh(),
      throwsA(isA<OltSocialException>()
          .having((e) => e.kind, 'kind', OltSocialErrorKind.unauthenticated)
          .having((e) => e.code, 'code', 'invalid_token')),
    );
    await tokens.dispose();
  });

  test('clear menghapus sesi', () async {
    final tokens = build();
    await tokens.refresh();
    tokens.clear();
    expect(tokens.currentSession, isNull);
    await tokens.dispose();
  });
}
