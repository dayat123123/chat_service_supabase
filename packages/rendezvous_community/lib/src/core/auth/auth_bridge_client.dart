import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rendezvous_community/src/core/auth/social_session.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

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

  final bool _ownsHttpClient;
  final Duration timeout;

  Future<SocialSession> exchange(String token) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            _exchangeUri,
            headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(timeout);
    } catch (e) {
      throw mapError(e);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw CommunityException(
        CommunityErrorKind.unavailable,
        message: 'Auth-bridge returned an invalid response (status ${res.statusCode})',
      );
    }

    if (res.statusCode != 200) {
      final code = body['error'] as String?;
      final message = body['message'] as String?;
      final kind = switch (res.statusCode) {
        401 => CommunityErrorKind.unauthenticated,
        429 => CommunityErrorKind.rateLimited,
        400 => CommunityErrorKind.invalidInput,
        503 || 502 => CommunityErrorKind.unavailable,
        _ => CommunityErrorKind.unknown,
      };
      throw CommunityException(kind, code: code, message: message);
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
