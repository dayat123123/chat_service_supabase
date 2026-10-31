import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/src/core/auth/auth_bridge_client.dart';
import 'package:rendezvous_community/src/core/auth/token_manager.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';

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

  TokenManager build({String? token = 'host-token', int ttl = 900, int status = 200}) {
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
      tokenProvider: () async => token,
      clock: () => now,
    );
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 29, 9);
    exchangeCalls = 0;
    sentTokens = [];
  });

  test('exchanges the token and reuses a JWT that is still valid', () async {
    final tokens = build();
    expect(await tokens.accessToken(), 'jwt-1');
    expect(await tokens.accessToken(), 'jwt-1');
    expect(exchangeCalls, 1);
    expect(sentTokens, ['host-token']);
    expect(tokens.currentSession!.user.username, 'budi');
    await tokens.dispose();
  });

  test('merges parallel refreshes into a single call', () async {
    final tokens = build();
    final results = await Future.wait([
      tokens.accessToken(),
      tokens.accessToken(),
      tokens.refresh().then((s) => s.accessToken),
    ]);
    expect(results.toSet(), {'jwt-1'});
    expect(exchangeCalls, 1);
    await tokens.dispose();
  });

  test('re-exchanges a JWT that is about to expire', () async {
    final tokens = build(ttl: 120);
    await tokens.accessToken();
    now = now.add(const Duration(seconds: 100));
    expect(await tokens.accessToken(), 'jwt-2');
    expect(exchangeCalls, 2);
    await tokens.dispose();
  });

  test('announces new sessions through sessionChanges', () async {
    final tokens = build();
    final next = tokens.sessionChanges.first;
    await tokens.refresh();
    expect((await next)!.accessToken, 'jwt-1');
    await tokens.dispose();
  });

  test('without a token -> unauthenticated without calling auth-bridge', () async {
    final tokens = build(token: null);
    await expectLater(
      tokens.accessToken(),
      throwsA(isA<CommunityException>().having((e) => e.kind, 'kind', CommunityErrorKind.unauthenticated)),
    );
    expect(exchangeCalls, 0);
    await tokens.dispose();
  });

  test('token rejected by auth-bridge -> unauthenticated', () async {
    final tokens = build(status: 401);
    await expectLater(
      tokens.refresh(),
      throwsA(
        isA<CommunityException>()
            .having((e) => e.kind, 'kind', CommunityErrorKind.unauthenticated)
            .having((e) => e.code, 'code', 'invalid_token'),
      ),
    );
    await tokens.dispose();
  });

  test('clear removes the session', () async {
    final tokens = build();
    await tokens.refresh();
    tokens.clear();
    expect(tokens.currentSession, isNull);
    await tokens.dispose();
  });
}
