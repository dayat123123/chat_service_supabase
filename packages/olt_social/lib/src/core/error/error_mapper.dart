import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const jwtErrorCodes = {'PGRST301', 'PGRST302', 'PGRST303'};

OltSocialException mapError(Object error) {
  if (error is OltSocialException) return error;

  if (error is PostgrestException) {
    final code = error.code ?? '';
    final detail = error.details?.toString();
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
        code == '23514' ||
        code == '23505' ||
        code == '22P02' ||
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
