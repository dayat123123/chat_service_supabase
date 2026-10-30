import 'dart:async';

import 'package:olt_social/src/core/auth/auth_bridge_client.dart';
import 'package:olt_social/src/core/auth/social_session.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';

class TokenManager {
  TokenManager({
    required this._bridge,
    required this._oltTokenProvider,
    this.refreshMargin = const Duration(seconds: 60),
    this.retryDelay = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AuthBridgeClient _bridge;
  final Future<String?> Function() _oltTokenProvider;
  final DateTime Function() _clock;
  final Duration refreshMargin;
  final Duration retryDelay;

  final _changes = StreamController<SocialSession?>.broadcast();
  SocialSession? _session;
  Future<SocialSession>? _inflight;
  Timer? _timer;
  bool _disposed = false;

  SocialSession? get currentSession => _session;

  Stream<SocialSession?> get sessionChanges => _changes.stream;

  Future<String> accessToken() async {
    final session = _session;
    if (session != null && !_expiringSoon(session)) return session.accessToken;
    return (await refresh()).accessToken;
  }

  Future<SocialSession> refresh() {
    if (_disposed) {
      return Future.error(const OltSocialException(OltSocialErrorKind.unknown, message: 'TokenManager sudah ditutup'));
    }
    return _inflight ??= _exchange().whenComplete(() => _inflight = null);
  }

  Future<SocialSession> _exchange() async {
    final oltToken = await _oltTokenProvider();
    if (oltToken == null || oltToken.isEmpty) {
      throw const OltSocialException.unauthenticated('Token OLT tidak tersedia (user belum login OLT)');
    }
    final session = await _bridge.exchange(oltToken);
    if (_disposed) return session;
    _session = session;
    _schedule(session.expiresAt.difference(_clock()) - refreshMargin);
    _changes.add(session);
    return session;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      try {
        await refresh();
      } catch (_) {
        if (!_disposed) _schedule(retryDelay);
      }
    });
  }

  bool _expiringSoon(SocialSession s) => !_clock().isBefore(s.expiresAt.subtract(refreshMargin ~/ 2));

  void clear() {
    _timer?.cancel();
    _session = null;
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _changes.close();
    _bridge.close();
  }
}
