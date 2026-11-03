import 'dart:convert';

import 'package:crypto/crypto.dart';

String? hostIdentityKey(String? hostToken) {
  final token = hostToken?.trim();
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length == 3) {
    try {
      final Object? claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (claims is Map<String, dynamic>) {
        final subject = claims['sub'];
        if (subject is String && subject.isNotEmpty) return _hash('jwt|${claims['iss'] ?? ''}|$subject');
      }
    } on FormatException {
      return null;
    }
    return null;
  }
  return _hash('opaque|$token');
}

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
