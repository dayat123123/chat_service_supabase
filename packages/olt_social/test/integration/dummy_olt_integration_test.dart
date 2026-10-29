// Integration test dengan token OLT "asli" dari OLT dummy (services/dummy-olt):
// login WebSocket seperti aplikasi OLT -> token -> olt_social -> auth-bridge
// mode websocket -> JWT. Kode package tidak diubah untuk ini.
//
// Butuh: make up DUMMY_OLT=1 && make seed
//   Windows : $env:OLT_SOCIAL_IT_DUMMY=1; flutter test test/integration/dummy_olt_integration_test.dart
//   Linux   : OLT_SOCIAL_IT_DUMMY=1 flutter test test/integration/dummy_olt_integration_test.dart
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';
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

/// Klien minimal protokol OLT dummy (lihat services/dummy-olt/README.md).
Future<Map<String, dynamic>> oltRequest(String wsUrl, Map<String, Object?> message, String replyType) async {
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

Future<String> oltPasswordLogin(String wsUrl, Map<String, String> credentials) async {
  final res = await oltRequest(wsUrl, {'type': 'login', 'method': 'password', 'payload': credentials}, 'login_result');
  expect(res['status'], 'OK', reason: 'login password: $res');
  return (res['data'] as Map<String, dynamic>)['token'] as String;
}

void main() {
  late String url;
  late String anonKey;
  late String wsUrl;
  final created = <OltSocial>[];

  OltSocial socialWith(Future<String?> Function() tokenProvider) {
    final social = OltSocial.create(supabaseUrl: url, anonKey: anonKey, oltTokenProvider: tokenProvider);
    created.add(social);
    return social;
  }

  setUpAll(() {
    if (!_enabled) return;
    final env = _dockerEnv();
    url = Platform.environment['OLT_SOCIAL_URL'] ?? env['SUPABASE_PUBLIC_URL'] ?? 'http://localhost:8000';
    anonKey = Platform.environment['OLT_SOCIAL_ANON_KEY'] ?? env['ANON_KEY']!;
    wsUrl = Platform.environment['OLT_DUMMY_WS_URL'] ?? 'ws://localhost:${env['DUMMY_OLT_PORT'] ?? '8090'}/ws';
  });

  tearDownAll(() async {
    for (final social in created) {
      await social.dispose();
    }
  });

  final skip = _enabled ? null : 'Set OLT_SOCIAL_IT_DUMMY=1 (stack: make up DUMMY_OLT=1)';

  test('login password OLT dummy -> token -> sesi sosial dengan identitas seed', () async {
    final token = await oltPasswordLogin(wsUrl, {'username': 'budi_santoso', 'password': 'olt12345'});
    expect(token, startsWith('olt_'));

    // Seperti aplikasi OLT saat restart: login ulang memakai token.
    final relogin = await oltRequest(wsUrl, {'type': 'login', 'method': 'token', 'payload': {'token': token}}, 'login_result');
    expect(relogin['status'], 'OK');

    final social = socialWith(() async => token);
    final me = await social.ensureSignedIn();
    expect(me.id, '72689cd3-ea55-584f-9e84-c257af0564e0', reason: 'UUID v5 olt_user_id 1001 = user seed Budi');
    expect(me.username, 'budi_santoso');

    final feed = await social.feed.getFeed(const FeedScope.global(), limit: 3);
    expect(feed.items, isNotEmpty);
  }, skip: skip);

  test('login email + password lalu kirim pesan DM', () async {
    final sariToken = await oltPasswordLogin(wsUrl, {'email': 'sari@olt.test', 'password': 'olt12345'});
    final budiToken = await oltPasswordLogin(wsUrl, {'email': 'budi@olt.test', 'password': 'olt12345'});
    final sari = socialWith(() async => sariToken);
    final budi = socialWith(() async => budiToken);
    final budiUser = await budi.ensureSignedIn();
    await sari.ensureSignedIn();

    final roomId = await sari.chat.getOrCreateDirectRoom(budiUser.id);
    final sent = await sari.chat.sendMessage(roomId, body: 'Halo dari token OLT dummy', clientId: const Uuid().v4());
    expect(sent.sender?.username, 'sari_invest');
    final inbox = await budi.chat.getMessages(roomId, limit: 5);
    expect(inbox.items.map((m) => m.id), contains(sent.id));
  }, skip: skip);

  test('token yang sudah logout ditolak -> unauthenticated', () async {
    final token = await oltPasswordLogin(wsUrl, {'username': 'andi_trader', 'password': 'olt12345'});
    final logout = await oltRequest(wsUrl, {'type': 'logout', 'payload': {'token': token}}, 'logout_result');
    expect(logout['status'], 'OK');

    final social = socialWith(() async => token);
    await expectLater(
      social.ensureSignedIn(),
      throwsA(isA<OltSocialException>().having((e) => e.kind, 'kind', OltSocialErrorKind.unauthenticated)),
    );
  }, skip: skip);

  test('password salah tidak menghasilkan token', () async {
    final res = await oltRequest(
      wsUrl,
      {'type': 'login', 'method': 'password', 'payload': {'username': 'budi_santoso', 'password': 'salah'}},
      'login_result',
    );
    expect(res['status'], 'FAILED');
    expect((res['error'] as Map<String, dynamic>)['code'], 'INVALID_CREDENTIALS');
  }, skip: skip);
}
