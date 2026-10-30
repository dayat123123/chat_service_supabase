import 'package:supabase_flutter/supabase_flutter.dart';

sealed class AuthStep {
  const AuthStep();
}

class NoSession extends AuthStep {
  const NoSession();
}

class TotpRequired extends AuthStep {
  const TotpRequired(this.factorId);

  final String factorId;
}

class TotpEnrollment extends AuthStep {
  const TotpEnrollment({required this.factorId, required this.secret, required this.uri});

  final String factorId;
  final String secret;
  final String uri;
}

class PasswordChangeRequired extends AuthStep {
  const PasswordChangeRequired();
}

class Verified extends AuthStep {
  const Verified();
}

class AuthRepository {
  AuthRepository(this._auth, this._realtime);

  final GoTrueClient _auth;
  final RealtimeClient _realtime;

  Stream<AuthChangeEvent> get changes => _auth.onAuthStateChange.map((state) => state.event);

  Future<void> signIn(String email, String password) => _auth.signInWithPassword(email: email, password: password);

  bool get _mustChangePassword => _auth.currentUser?.userMetadata?['must_change_password'] == true;

  Future<AuthStep> nextStep() async {
    if (_auth.currentSession == null) return const NoSession();
    if (_auth.mfa.getAuthenticatorAssuranceLevel().currentLevel == AuthenticatorAssuranceLevels.aal2) {
      return _mustChangePassword ? const PasswordChangeRequired() : const Verified();
    }
    final factors = await _auth.mfa.listFactors();
    if (factors.totp.isNotEmpty) return TotpRequired(factors.totp.first.id);
    if (_mustChangePassword) return const PasswordChangeRequired();
    for (final factor in factors.all.where((f) => f.status != FactorStatus.verified)) {
      await _auth.mfa.unenroll(factor.id);
    }
    final enrolled = await _auth.mfa.enroll(issuer: 'OLT CS Console', friendlyName: 'CS Console');
    final totp = enrolled.totp!;
    return TotpEnrollment(factorId: enrolled.id, secret: totp.secret, uri: totp.uri);
  }

  Future<void> verify(String factorId, String code) async {
    await _auth.mfa.challengeAndVerify(factorId: factorId, code: code);
    await _realtime.setAuth(_auth.currentSession?.accessToken);
  }

  Future<void> changePassword(String password) =>
      _auth.updateUser(UserAttributes(password: password, data: {'must_change_password': false}));

  Future<String> freshToken() async {
    final session = _auth.currentSession;
    if (session != null && !session.isExpired) return session.accessToken;
    final refreshed = (await _auth.refreshSession()).session;
    if (refreshed == null) throw const AuthException('Sesi berakhir', code: 'session_expired');
    return refreshed.accessToken;
  }

  Future<void> signOut() => _auth.signOut();
}
