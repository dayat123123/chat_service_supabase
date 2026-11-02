import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community_example/dummy_olt_client.dart';

void main() {
  final enabled = Platform.environment['OLT_DUMMY_IT'] == '1';
  final skip = enabled ? null : 'Set OLT_DUMMY_IT=1 (stack: make up DUMMY_OLT=1)';
  final client = DummyOltClient(Platform.environment['OLT_DUMMY_WS_URL'] ?? 'ws://localhost:8090/ws');

  test('password login -> token -> sign in again with the token', () async {
    final session = await client.loginWithPassword('sari@olt.test', 'olt12345');
    expect(session.token, startsWith('olt_'));
    expect(session.username, 'sari_invest');
    final again = await client.loginWithToken(session.token);
    expect(again.userId, '1002');
  }, skip: skip);

  test('wrong password -> DummyOltException INVALID_CREDENTIALS', () async {
    await expectLater(
      client.loginWithPassword('budi_santoso', 'salah'),
      throwsA(isA<DummyOltException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );
  }, skip: skip);

  test('unreachable server -> UNREACHABLE', () async {
    final offline = DummyOltClient('ws://127.0.0.1:1/ws', timeout: const Duration(seconds: 3));
    await expectLater(
      offline.loginWithPassword('budi_santoso', 'olt12345'),
      throwsA(isA<DummyOltException>().having((e) => e.code, 'code', 'UNREACHABLE')),
    );
  }, skip: skip);
}
