import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/auth/auth_bridge_client.dart';
import 'package:rendezvous_community/src/core/auth/host_identity.dart';
import 'package:rendezvous_community/src/core/auth/session_tokens.dart';
import 'package:rendezvous_community/src/core/auth/social_session.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';

class TokenManager implements SessionTokens {
  TokenManager({
    required this._bridge,
    required this._tokenProvider,
    this.refreshMargin = const Duration(seconds: 60),
    this.retryDelay = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AuthBridgeClient _bridge;
  final Future<String?> Function() _tokenProvider;
  final DateTime Function() _clock;
  final Duration refreshMargin;
  final Duration retryDelay;

  final _changes = StreamController<SocialSession?>.broadcast();
  SocialSession? _session;
  String? _hostKey;
  Future<SocialSession>? _inflight;
  Timer? _timer;
  bool _disposed = false;

  SocialSession? get currentSession => _session;

  String? get hostKey => _session == null ? null : _hostKey;

  Future<String?> resolveHostKey() async {
    try {
      return hostIdentityKey(await _tokenProvider());
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentUserId => _session?.user.id;

  Stream<SocialSession?> get sessionChanges => _changes.stream;

  @override
  Future<String> accessToken() async {
    final session = _session;
    if (session != null && !_expiringSoon(session)) return session.accessToken;
    return (await refresh()).accessToken;
  }

  @override
  Future<String> refreshUserId() async => (await refresh()).user.id;

  Future<SocialSession> refresh() {
    if (_disposed) {
      return Future.error(const CommunityException(CommunityErrorKind.unknown, message: 'Token manager is closed'));
    }
    return _inflight ??= _exchange().whenComplete(() => _inflight = null);
  }

  Future<SocialSession> _exchange() async {
    try {
      return await _issueSession();
    } catch (error) {
      final mapped = mapError(error);
      CommunityLoggers.auth.event(
        Level.WARNING,
        'Social session exchange failed',
        fields: {'kind': mapped.kind, 'code': mapped.code},
      );
      rethrow;
    }
  }

  Future<SocialSession> _issueSession() async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const CommunityException.unauthenticated(
        'Token provider returned no token because the user is not signed in to the host app',
      );
    }
    final session = await _bridge.exchange(token);
    if (_disposed) return session;
    _hostKey = hostIdentityKey(token);
    _session = session;
    _schedule(session.expiresAt.difference(_clock()) - refreshMargin);
    _changes.add(session);
    CommunityLoggers.auth.event(
      Level.INFO,
      'Social session issued',
      fields: {'userId': session.user.id, 'expiresAt': session.expiresAt},
    );
    return session;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      try {
        await refresh();
      } catch (_) {
        if (_disposed) return;
        CommunityLoggers.auth.event(
          Level.FINE,
          'Scheduled session refresh failed, retrying',
          fields: {'delayMs': retryDelay.inMilliseconds},
        );
        _schedule(retryDelay);
      }
    });
  }

  bool _expiringSoon(SocialSession s) => !_clock().isBefore(s.expiresAt.subtract(refreshMargin ~/ 2));

  void clear() {
    _timer?.cancel();
    _session = null;
    _hostKey = null;
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _changes.close();
    _bridge.close();
  }
}
