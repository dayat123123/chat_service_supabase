import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:olt_social/olt_social.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsoleError implements Exception {
  const ConsoleError(this.code, {this.message, this.status});

  factory ConsoleError.from(Object error) {
    if (error is ConsoleError) return error;
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code.startsWith('PT')) {
        return ConsoleError(error.message, message: error.details?.toString(), status: int.tryParse(code.substring(2)));
      }
      if (code == 'PGRST301' || code == 'PGRST302' || code == 'PGRST303') {
        return const ConsoleError('session_expired', status: 401);
      }
      if (code.startsWith('PGRST0')) return const ConsoleError('unavailable', status: 503);
      return ConsoleError(code.isEmpty ? 'unknown' : code, message: error.message);
    }
    if (error is OltSocialException) {
      return ConsoleError(error.code ?? error.kind.name, message: error.message);
    }
    if (error is FunctionException) {
      final details = error.details;
      if (error.status == 401) return const ConsoleError('session_expired', status: 401);
      if (details is Map && details['code'] is String) {
        return ConsoleError(details['code'] as String, message: details['message'] as String?, status: error.status);
      }
      return ConsoleError('unavailable', status: error.status);
    }
    if (error is AuthException) {
      return ConsoleError(error.code ?? 'auth_failed', message: error.message, status: int.tryParse(error.statusCode ?? ''));
    }
    if (error is TimeoutException || error is http.ClientException) {
      return const ConsoleError('network');
    }
    return ConsoleError('unknown', message: error.toString());
  }

  final String code;
  final String? message;
  final int? status;

  bool get isStale => code == 'stale_ticket';

  @override
  String toString() => 'ConsoleError($code${message == null ? '' : ', $message'})';
}
