import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SessionTokens {
  String? get currentUserId;

  Future<String> accessToken();

  Future<String> refreshUserId();
}

class SupabaseAuthTokens implements SessionTokens {
  SupabaseAuthTokens(this._auth);

  final GoTrueClient _auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Future<String> accessToken() async {
    final session = _auth.currentSession;
    if (session == null) throw const CommunityException.unauthenticated();
    if (!session.isExpired) return session.accessToken;
    return (await _refresh()).accessToken;
  }

  @override
  Future<String> refreshUserId() async => (await _refresh()).user.id;

  Future<Session> _refresh() async {
    final session = (await _auth.refreshSession()).session;
    if (session == null) throw const CommunityException.unauthenticated();
    return session;
  }
}
