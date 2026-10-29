import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'olt_social_exception.dart';

/// Kode PostgREST untuk JWT tidak valid / kedaluwarsa.
const jwtErrorCodes = {'PGRST301', 'PGRST302', 'PGRST303'};

/// Memetakan error apa pun dari Supabase/HTTP menjadi [OltSocialException].
///
/// Server memakai SQLSTATE `PT<status>` (lihat private.api_error di migrasi),
/// sehingga `code` = `PT429` dan `message` = kode stabil seperti `rate_limited`.
OltSocialException mapError(Object error) {
  if (error is OltSocialException) return error;

  if (error is PostgrestException) {
    final code = error.code ?? '';
    final detail = error.details?.toString();
    // Error PT*: message berisi kode stabil (mis. rate_limited). Error lain: SQLSTATE.
    final stable = code.startsWith('PT') ? error.message : code;
    OltSocialException build(OltSocialErrorKind kind) =>
        OltSocialException(kind, code: stable, message: detail ?? error.message, cause: error);

    if (code == 'PT429') return build(OltSocialErrorKind.rateLimited);
    if (code == 'PT422') return build(OltSocialErrorKind.contentBlocked);
    if (code == 'PT401' || jwtErrorCodes.contains(code)) {
      return build(OltSocialErrorKind.unauthenticated);
    }
    if (code == 'PT403' || code == '42501') return build(OltSocialErrorKind.forbidden);
    if (code == 'PT404') return build(OltSocialErrorKind.notFound);
    if (code.startsWith('PT4') ||
        code == '23514' || // check_violation
        code == '23505' || // unique_violation
        code == '22P02' || // invalid_text_representation
        code == '23503') {
      return build(OltSocialErrorKind.invalidInput);
    }
    if (code == 'PGRST000' || code == 'PGRST001' || code == 'PGRST002' || code == '503') {
      return build(OltSocialErrorKind.unavailable);
    }
    return build(OltSocialErrorKind.unknown);
  }

  if (error is StorageException) {
    final status = error.statusCode ?? '';
    final kind = switch (status) {
      '413' => OltSocialErrorKind.invalidInput,
      '415' => OltSocialErrorKind.invalidInput,
      '401' => OltSocialErrorKind.unauthenticated,
      '403' => OltSocialErrorKind.forbidden,
      '404' => OltSocialErrorKind.notFound,
      _ when error.message.contains('mime type') => OltSocialErrorKind.invalidInput,
      _ when error.message.contains('row-level security') => OltSocialErrorKind.forbidden,
      _ => OltSocialErrorKind.unknown,
    };
    return OltSocialException(kind, code: error.error, message: error.message, cause: error);
  }

  if (error is TimeoutException || error is SocketException || error is http.ClientException ||
      error is HandshakeException) {
    return OltSocialException(OltSocialErrorKind.network, message: error.toString(), cause: error);
  }

  return OltSocialException(OltSocialErrorKind.unknown, message: error.toString(), cause: error);
}
