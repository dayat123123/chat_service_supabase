@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:uuid/uuid.dart';

final _enabled = Platform.environment['OLT_SOCIAL_IT_DUMMY'] == '1';

Map<String, String> _dockerEnv() {
  final file = File('../../docker/.env');
  if (!file.existsSync()) return const {};
  return {
    for (final line in file.readAsLinesSync())
      if (line.contains('=') && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim(): line.substring(line.indexOf('=') + 1).trim(),
  };
}

String? _dockerSecret(String name) {
  final file = File('../../docker/secrets/$name');
  return file.existsSync() ? file.readAsStringSync().trim() : null;
}

Future<Map<String, dynamic>> dummyRequest(String wsUrl, Map<String, Object?> message, String replyType) async {
  final socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
  try {
    final requestId = const Uuid().v4();
    socket.add(jsonEncode({...message, 'request_id': requestId}));
    await for (final raw in socket.timeout(const Duration(seconds: 10))) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] == replyType && msg['request_id'] == requestId) return msg;
    }
    throw StateError('Koneksi ditutup sebelum $replyType diterima');
  } finally {
    await socket.close();
  }
}

Future<({String session, String social})> passwordLogin(String wsUrl, Map<String, String> credentials) async {
  final res = await dummyRequest(wsUrl, {
    'type': 'login',
    'method': 'password',
    'payload': credentials,
  }, 'login_result');
  expect(res['status'], 'OK', reason: 'password login: $res');
  final data = res['data'] as Map<String, dynamic>;
  return (session: data['token'] as String, social: data['social_token'] as String);
}

Future<String?> renewSocialToken(String wsUrl, String session) async {
  final res = await dummyRequest(wsUrl, {
    'type': 'social_token',
    'payload': {'token': session},
  }, 'social_token_result');
  return res['status'] == 'OK' ? (res['data'] as Map<String, dynamic>)['token'] as String : null;
}

void main() {
  late String url;
  late String anonKey;
  late String wsUrl;
  final created = <RendezvousCommunity>[];

  RendezvousCommunity socialWith(Future<String?> Function() tokenProvider) {
    final social = RendezvousCommunity.create(supabaseUrl: url, anonKey: anonKey, tokenProvider: tokenProvider);
    created.add(social);
    return social;
  }

  setUpAll(() {
    if (!_enabled) return;
    final env = _dockerEnv();
    url = Platform.environment['OLT_SOCIAL_URL'] ?? env['SUPABASE_PUBLIC_URL'] ?? 'http://localhost:8000';
    anonKey = Platform.environment['OLT_SOCIAL_ANON_KEY'] ?? _dockerSecret('anon_key') ?? env['ANON_KEY']!;
    wsUrl = Platform.environment['OLT_DUMMY_WS_URL'] ?? 'ws://localhost:${env['DUMMY_OLT_PORT'] ?? '8090'}/ws';
  });

  tearDownAll(() async {
    for (final social in created) {
      await social.dispose();
    }
  });

  final skip = _enabled ? null : 'Set OLT_SOCIAL_IT_DUMMY=1 (stack: make up DUMMY_OLT=1)';

  test('dummy OLT password login -> social token -> social session with the seed identity', () async {
    final login = await passwordLogin(wsUrl, {'username': 'budi_santoso', 'password': 'olt12345'});
    expect(login.session, startsWith('olt_'));
    expect(login.social.split('.'), hasLength(3), reason: 'the social token is a JWT');

    final relogin = await dummyRequest(wsUrl, {
      'type': 'login',
      'method': 'token',
      'payload': {'token': login.session},
    }, 'login_result');
    expect(relogin['status'], 'OK');

    final social = socialWith(() async => login.social);
    final me = await social.ensureSignedIn();
    expect(
      me.id,
      '72689cd3-ea55-584f-9e84-c257af0564e0',
      reason: 'the UUID v5 of olt_user_id 1001 equals seed user Budi',
    );
    expect(me.username, 'budi_santoso');

    final feed = await social.feed.getFeed(const FeedScope.global(), limit: 3);
    expect(feed.items, isNotEmpty);
  }, skip: skip);

  test('email + password login, then send a DM', () async {
    final sariLogin = await passwordLogin(wsUrl, {'email': 'sari@olt.test', 'password': 'olt12345'});
    final budiLogin = await passwordLogin(wsUrl, {'email': 'budi@olt.test', 'password': 'olt12345'});
    final sari = socialWith(() => renewSocialToken(wsUrl, sariLogin.session));
    final budi = socialWith(() async => budiLogin.social);
    final budiUser = await budi.ensureSignedIn();
    await sari.ensureSignedIn();

    final roomId = await sari.chat.getOrCreateDirectRoom(budiUser.id);
    final clientId = const Uuid().v4();
    final sent = await sari.chat.sendMessage(roomId, body: 'Halo dari token OLT dummy $clientId', clientId: clientId);
    expect(sent.sender?.username, 'sari_invest');
    final inbox = await budi.chat.getMessages(roomId, limit: 5);
    expect(inbox.items.map((m) => m.id), contains(sent.id));
  }, skip: skip);

  test('a logged-out OLT session gets no new social token -> unauthenticated', () async {
    final login = await passwordLogin(wsUrl, {'username': 'andi_trader', 'password': 'olt12345'});
    final logout = await dummyRequest(wsUrl, {
      'type': 'logout',
      'payload': {'token': login.session},
    }, 'logout_result');
    expect(logout['status'], 'OK');
    expect(await renewSocialToken(wsUrl, login.session), isNull);

    final social = socialWith(() => renewSocialToken(wsUrl, login.session));
    await expectLater(
      social.ensureSignedIn(),
      throwsA(isA<CommunityException>().having((e) => e.kind, 'kind', CommunityErrorKind.unauthenticated)),
    );
  }, skip: skip);

  test('an OLT session token (not a social token) is rejected -> unauthenticated', () async {
    final login = await passwordLogin(wsUrl, {'username': 'rina_saham', 'password': 'olt12345'});
    final social = socialWith(() async => login.session);
    await expectLater(
      social.ensureSignedIn(),
      throwsA(isA<CommunityException>().having((e) => e.kind, 'kind', CommunityErrorKind.unauthenticated)),
    );
  }, skip: skip);

  test('a wrong password yields no token', () async {
    final res = await dummyRequest(wsUrl, {
      'type': 'login',
      'method': 'password',
      'payload': {'username': 'budi_santoso', 'password': 'salah'},
    }, 'login_result');
    expect(res['status'], 'FAILED');
    expect((res['error'] as Map<String, dynamic>)['code'], 'INVALID_CREDENTIALS');
  }, skip: skip);
}
