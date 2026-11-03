import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';

const _jwt = 'eyJhbGciOiJFZERTQSJ9.eyJzdWIiOiIxMDAxIn0.c2lnbmF0dXJl';

void main() {
  tearDown(CommunityLoggers.reset);

  group('sanitizeLogFields', () {
    test('redacts values of sensitive keys and keeps identifiers', () {
      final fields = sanitizeLogFields({
        'token': 'olt_abc',
        'accessToken': 'abc',
        'password': 'olt12345',
        'otp': '123456',
        'body': 'Halo, saldo saya hilang',
        'content': 'Post content',
        'accountNumber': '1234567890',
        'nik': '3201234567890001',
        'roomId': 'room-1',
        'clientId': 'client-1',
        'messageId': 'message-1',
        'ticketId': 'ticket-1',
        'attempt': 3,
      });
      expect(fields, {
        'token': redactedValue,
        'accessToken': redactedValue,
        'password': redactedValue,
        'otp': redactedValue,
        'body': redactedValue,
        'content': redactedValue,
        'accountNumber': redactedValue,
        'nik': redactedValue,
        'roomId': 'room-1',
        'clientId': 'client-1',
        'messageId': 'message-1',
        'ticketId': 'ticket-1',
        'attempt': 3,
      });
    });

    test('redacts secrets embedded in free text values', () {
      final fields = sanitizeLogFields({
        'error': 'exchange failed for $_jwt with Bearer abc.def-ghi and olt_dGVzdHRva2VudGVzdA.c2ln',
        'detail': 'NIK 3201234567890001 rekening 1234567890123',
        'ticket': 'CS-20261031-0041',
        'nested': {'refreshToken': 'x', 'channel': 'room:1'},
      });
      expect(fields['error'], 'exchange failed for $redactedValue with Bearer $redactedValue and $redactedValue');
      expect(fields['detail'], 'NIK $redactedValue rekening $redactedValue');
      expect(fields['ticket'], 'CS-20261031-0041');
      expect(fields['nested'], {'refreshToken': redactedValue, 'channel': 'room:1'});
    });
  });

  group('CommunityLoggers', () {
    test('routes structured records from component loggers to the host handler', () {
      final records = <LogRecord>[];
      CommunityLoggers.configure(handler: records.add, level: Level.FINE);

      CommunityLoggers.chat.event(
        Level.SEVERE,
        'Failed to send message',
        fields: {'roomId': 'room-1', 'body': 'secret text'},
        error: Exception('rejected token $_jwt'),
      );

      expect(records, hasLength(1));
      final record = records.single;
      expect(record.loggerName, 'RendezvousCommunity.Chat');
      expect(record.level, Level.SEVERE);
      final event = record.object! as CommunityLogEvent;
      expect(event.message, 'Failed to send message');
      expect(event.fields, {'roomId': 'room-1', 'body': redactedValue});
      expect(record.message, 'Failed to send message {"roomId":"room-1","body":"$redactedValue"}');
      expect(record.error, 'Exception: rejected token $redactedValue');
    });

    test('drops records below the configured level', () {
      final records = <LogRecord>[];
      CommunityLoggers.configure(handler: records.add, level: Level.INFO);

      CommunityLoggers.realtime.event(Level.FINE, 'Realtime channel subscribed', fields: {'channel': 'room:1'});
      CommunityLoggers.auth.event(Level.INFO, 'Social session issued');

      expect(records.map((record) => record.loggerName), ['RendezvousCommunity.Auth']);
    });

    test('defaults to INFO in release builds and FINE otherwise', () {
      expect(defaultLogLevel(release: true), Level.INFO);
      expect(defaultLogLevel(release: false), Level.FINE);
    });
  });

  test('RendezvousCommunity.initialize installs the host log handler', () async {
    final records = <LogRecord>[];
    final community = await RendezvousCommunity.initialize(
      supabaseUrl: 'http://localhost:8000',
      anonKey: 'anon',
      tokenProvider: () async => null,
      signInEagerly: false,
      trackDelivery: false,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
      logHandler: records.add,
      logLevel: Level.ALL,
    );
    addTearDown(community.dispose);

    CommunityLoggers.support.event(Level.INFO, 'Support ticket opened', fields: {'ticketId': 't-1'});

    final support = records.where((record) => record.loggerName == 'RendezvousCommunity.Support');
    expect(support.single.message, 'Support ticket opened {"ticketId":"t-1"}');
  });
}
