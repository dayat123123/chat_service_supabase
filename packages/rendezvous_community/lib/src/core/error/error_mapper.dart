import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const jwtErrorCodes = {'PGRST301', 'PGRST302', 'PGRST303'};

CommunityException mapError(Object error) {
  if (error is CommunityException) return error;

  if (error is PostgrestException) {
    final code = error.code ?? '';
    final detail = error.details?.toString();
    final stable = code.startsWith('PT') ? error.message : code;
    CommunityException build(CommunityErrorKind kind) => CommunityException(
      kind,
      code: stable,
      message: detail ?? error.message,
      cause: error,
      retryAfter: kind == CommunityErrorKind.rateLimited ? parseRetryAfter(detail) : null,
    );

    if (code == 'PT429') return build(CommunityErrorKind.rateLimited);
    if (code == 'PT422') return build(CommunityErrorKind.contentBlocked);
    if (code == 'PT401' || jwtErrorCodes.contains(code)) {
      return build(CommunityErrorKind.unauthenticated);
    }
    if (code == 'PT403' || code == '42501') return build(CommunityErrorKind.forbidden);
    if (code == 'PT404') return build(CommunityErrorKind.notFound);
    if (code.startsWith('PT4') || code == '23514' || code == '23505' || code == '22P02' || code == '23503') {
      return build(CommunityErrorKind.invalidInput);
    }
    if (code == 'PGRST000' || code == 'PGRST001' || code == 'PGRST002' || code == '503' || code == 'PT503') {
      return build(CommunityErrorKind.unavailable);
    }
    return build(CommunityErrorKind.unknown);
  }

  if (error is StorageException) {
    final status = error.statusCode ?? '';
    final kind = switch (status) {
      '413' => CommunityErrorKind.invalidInput,
      '415' => CommunityErrorKind.invalidInput,
      '401' => CommunityErrorKind.unauthenticated,
      '403' => CommunityErrorKind.forbidden,
      '404' => CommunityErrorKind.notFound,
      _ when error.message.contains('mime type') => CommunityErrorKind.invalidInput,
      _ when error.message.contains('row-level security') => CommunityErrorKind.forbidden,
      _ => CommunityErrorKind.unknown,
    };
    return CommunityException(kind, code: error.error, message: error.message, cause: error);
  }

  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException) {
    return CommunityException(CommunityErrorKind.network, message: error.toString(), cause: error);
  }

  return CommunityException(CommunityErrorKind.unknown, message: error.toString(), cause: error);
}

Duration? parseRetryAfter(String? value) {
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

CommunityException mapMediaError(int status, {String? code, String? message, String? retryAfter}) {
  final kind = switch (status) {
    401 => CommunityErrorKind.unauthenticated,
    403 => CommunityErrorKind.forbidden,
    404 => code == null ? CommunityErrorKind.unavailable : CommunityErrorKind.notFound,
    429 => CommunityErrorKind.rateLimited,
    400 || 409 || 413 || 415 || 422 => CommunityErrorKind.invalidInput,
    502 || 503 || 504 => CommunityErrorKind.unavailable,
    _ => CommunityErrorKind.unknown,
  };
  return CommunityException(
    kind,
    code: code ?? (status == 404 ? 'media_unavailable' : null),
    message: message ?? 'Media gateway returned status $status',
    retryAfter: parseRetryAfter(retryAfter),
  );
}
