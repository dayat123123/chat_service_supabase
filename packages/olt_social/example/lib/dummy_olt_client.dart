import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Klien protokol login OLT DUMMY (services/dummy-olt), meniru cara aplikasi
/// OLT login ke WebSocket OLT: username/email + password, atau token.
/// Hanya untuk demo & testing; aplikasi OLT asli memakai modul login miliknya.
class DummyOltClient {
  DummyOltClient(this.url, {this.timeout = const Duration(seconds: 10)});

  /// Mis. ws://localhost:8090/ws
  final String url;
  final Duration timeout;

  static final _random = Random();

  /// Login dengan username atau email (otomatis dikenali dari '@') + password.
  Future<DummyOltSession> loginWithPassword(String identifier, String password) async {
    final id = identifier.trim();
    final res = await _request({
      'type': 'login',
      'method': 'password',
      'payload': {id.contains('@') ? 'email' : 'username': id, 'password': password},
    }, 'login_result');
    return DummyOltSession._fromResult(res);
  }

  /// Login ulang memakai token sesi yang sudah dimiliki.
  Future<DummyOltSession> loginWithToken(String token) async {
    final res = await _request({
      'type': 'login',
      'method': 'token',
      'payload': {'token': token},
    }, 'login_result');
    return DummyOltSession._fromResult(res);
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
        'OLT dummy tidak dapat dihubungi di $url. Jalankan stack dengan: make up DUMMY_OLT=1 '
            '(Windows: .\\make.ps1 up -DummyOlt)',
      );
    }
    try {
      // 0x7fffffff: aman juga di web (bilangan bulat JavaScript).
      final requestId = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
      channel.sink.add(jsonEncode({...message, 'request_id': requestId}));
      // Server bisa mengirim pesan lain (welcome, heartbeat) sebelum balasan.
      await for (final raw in channel.stream.timeout(timeout)) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        if (msg['type'] != replyType || msg['request_id'] != requestId) continue;
        if (msg['status'] != 'OK') {
          final error = msg['error'] as Map<String, dynamic>? ?? const {};
          throw DummyOltException(error['code'] as String? ?? 'FAILED', error['message'] as String? ?? 'Login gagal');
        }
        return msg;
      }
      throw const DummyOltException('CLOSED', 'Koneksi OLT dummy ditutup sebelum ada balasan');
    } on TimeoutException {
      throw const DummyOltException('TIMEOUT', 'OLT dummy tidak menjawab');
    } finally {
      await channel.sink.close();
    }
  }
}

/// Sesi hasil login OLT dummy.
class DummyOltSession {
  const DummyOltSession({required this.token, required this.userId, required this.username, required this.fullName});

  factory DummyOltSession._fromResult(Map<String, dynamic> res) {
    final data = res['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    return DummyOltSession(
      token: data['token'] as String,
      userId: '${user['id']}',
      username: user['username'] as String,
      fullName: user['full_name'] as String? ?? '',
    );
  }

  final String token;
  final String userId;
  final String username;
  final String fullName;
}

class DummyOltException implements Exception {
  const DummyOltException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
