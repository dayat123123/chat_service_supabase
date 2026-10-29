import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/user.dart';
import '../errors/error_mapper.dart';
import '../errors/olt_social_exception.dart';

/// Klien endpoint auth-bridge: menukar token OLT dengan JWT Supabase.
class AuthBridgeClient {
  AuthBridgeClient({
    required String baseUrl,
    required this._anonKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _exchangeUri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/exchange'),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final Uri _exchangeUri;
  final String _anonKey;
  final http.Client _http;

  /// Client milik aplikasi host tidak boleh ditutup oleh package.
  final bool _ownsHttpClient;
  final Duration timeout;

  Future<SocialSession> exchange(String oltToken) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            _exchangeUri,
            headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'token': oltToken}),
          )
          .timeout(timeout);
    } catch (e) {
      throw mapError(e);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw OltSocialException(OltSocialErrorKind.unavailable, message: 'Respons auth-bridge tidak valid (${res.statusCode})');
    }

    if (res.statusCode != 200) {
      final code = body['error'] as String?;
      final message = body['message'] as String?;
      final kind = switch (res.statusCode) {
        401 => OltSocialErrorKind.unauthenticated,
        429 => OltSocialErrorKind.rateLimited,
        400 => OltSocialErrorKind.invalidInput,
        503 || 502 => OltSocialErrorKind.unavailable,
        _ => OltSocialErrorKind.unknown,
      };
      throw OltSocialException(kind, code: code, message: message);
    }

    final user = body['user'] as Map<String, dynamic>;
    return SocialSession(
      accessToken: body['access_token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch((body['expires_at'] as num).toInt() * 1000, isUtc: true),
      user: UserSummary(
        id: user['id'] as String,
        username: user['username'] as String,
        displayName: user['display_name'] as String?,
        avatarUrl: user['avatar_url'] as String?,
        isVerified: user['is_verified'] as bool? ?? false,
      ),
    );
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }
}
