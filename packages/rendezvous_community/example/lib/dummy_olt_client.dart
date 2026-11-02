import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

class DummyOltClient {
  DummyOltClient(this.url, {this.timeout = const Duration(seconds: 10)});

  final String url;
  final Duration timeout;

  static final _random = Random();

  Future<DummyOltSession> loginWithPassword(String identifier, String password) async {
    final id = identifier.trim();
    final res = await _request({
      'type': 'login',
      'method': 'password',
      'payload': {id.contains('@') ? 'email' : 'username': id, 'password': password},
    }, 'login_result');
    return DummyOltSession._fromResult(res);
  }

  Future<DummyOltSession> loginWithToken(String token) async {
    final res = await _request({
      'type': 'login',
      'method': 'token',
      'payload': {'token': token},
    }, 'login_result');
    return DummyOltSession._fromResult(res);
  }

  Future<DummySocialToken> socialToken(String sessionToken) async {
    final res = await _request({
      'type': 'social_token',
      'payload': {'token': sessionToken},
    }, 'social_token_result');
    final data = res['data'] as Map<String, dynamic>;
    return DummySocialToken(data['token'] as String, DateTime.parse(data['expires_at'] as String));
  }

  Future<void> logout(String token) => _request({
    'type': 'logout',
    'payload': {'token': token},
  }, 'logout_result');

  Future<Map<String, dynamic>> _request(Map<String, Object?> message, String replyType) async {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    try {
      await channel.ready.timeout(timeout);
    } catch (_) {
      unawaited(channel.sink.close());
      throw DummyOltException(
        'UNREACHABLE',
        'Dummy OLT is unreachable at $url. Start the stack with: make up DUMMY_OLT=1 '
            '(Windows: .\\make.ps1 up -DummyOlt)',
      );
    }
    try {
      final requestId = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
      channel.sink.add(jsonEncode({...message, 'request_id': requestId}));
      await for (final raw in channel.stream.timeout(timeout)) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        if (msg['type'] != replyType || msg['request_id'] != requestId) continue;
        if (msg['status'] != 'OK') {
          final error = msg['error'] as Map<String, dynamic>? ?? const {};
          throw DummyOltException(
            error['code'] as String? ?? 'FAILED',
            error['message'] as String? ?? 'Sign-in failed',
          );
        }
        return msg;
      }
      throw const DummyOltException('CLOSED', 'Dummy OLT closed the connection before replying');
    } on TimeoutException {
      throw const DummyOltException('TIMEOUT', 'Dummy OLT did not respond');
    } finally {
      await channel.sink.close();
    }
  }
}

class DummyOltSession {
  const DummyOltSession({
    required this.token,
    required this.socialToken,
    required this.userId,
    required this.username,
    required this.fullName,
  });

  factory DummyOltSession._fromResult(Map<String, dynamic> res) {
    final data = res['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    return DummyOltSession(
      token: data['token'] as String,
      socialToken: DummySocialToken(
        data['social_token'] as String,
        DateTime.parse(data['social_token_expires_at'] as String),
      ),
      userId: '${user['id']}',
      username: user['username'] as String,
      fullName: user['full_name'] as String? ?? '',
    );
  }

  final String token;
  final DummySocialToken socialToken;
  final String userId;
  final String username;
  final String fullName;
}

class DummySocialToken {
  const DummySocialToken(this.token, this.expiresAt);

  final String token;
  final DateTime expiresAt;
}

class DummyOltException implements Exception {
  const DummyOltException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
