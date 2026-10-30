import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';

String errorText(BuildContext context, Object error) {
  final l10n = context.l10n;
  final e = ConsoleError.from(error);
  return switch (e.code) {
    'invalid_credentials' => l10n.errorInvalidLogin,
    'mfa_verification_failed' || 'mfa_challenge_expired' || 'mfa_verification_rejected' => l10n.errorInvalidCode,
    'over_request_rate_limit' || 'too_many_requests' => l10n.errorTooManyAttempts,
    'network' => l10n.errorNetwork,
    'session_expired' => l10n.signedOutExpired,
    'unavailable' => l10n.errorUnavailable,
    'secret_request_blocked' || 'contentBlocked' => e.message ?? l10n.errorSecretRequestBlocked,
    'same_password' => l10n.errorSamePassword,
    'weak_password' => l10n.errorWeakPassword,
    _ when e.status != null && (e.message?.isNotEmpty ?? false) => e.message!,
    _ => l10n.errorGeneric,
  };
}

void showError(BuildContext context, Object error) => _show(context, errorText(context, error));

void showNotice(BuildContext context, String message) => _show(context, message);

void _show(BuildContext context, String message) {
  final width = MediaQuery.sizeOf(context).width;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, width > 820 ? width - 396 : 16, 16),
    ));
}
