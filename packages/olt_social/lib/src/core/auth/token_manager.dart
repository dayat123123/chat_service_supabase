import 'dart:async';

import '../../domain/entities/user.dart';
import '../errors/olt_social_exception.dart';
import 'auth_bridge_client.dart';

/// Mengelola JWT Supabase yang diterbitkan auth-bridge.
///
/// * [accessToken] dipakai SupabaseClient untuk setiap request: mengembalikan
///   token yang masih berlaku, atau menukar ulang token OLT bila hampir habis.
/// * Refresh dijadwalkan [refreshMargin] sebelum kedaluwarsa dan diumumkan lewat
///   [sessionChanges] (dipakai untuk memperbarui token koneksi realtime).
/// * Refresh paralel digabung menjadi satu panggilan ke auth-bridge.
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

  /// Sesi aktif (null sebelum login pertama atau setelah [clear]).
  SocialSession? get currentSession => _session;

  /// Memancar setiap sesi baru (refresh) dan null saat [clear].
  Stream<SocialSession?> get sessionChanges => _changes.stream;

  /// Token yang masih berlaku; melempar [OltSocialException] bila tidak bisa login.
  Future<String> accessToken() async {
    final session = _session;
    if (session != null && !_expiringSoon(session)) return session.accessToken;
    return (await refresh()).accessToken;
  }

  /// Menukar ulang token OLT sekarang juga.
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
        // Gagal (mis. offline): coba lagi nanti. Request berikutnya juga akan refresh.
        if (!_disposed) _schedule(retryDelay);
      }
    });
  }

  bool _expiringSoon(SocialSession s) => !_clock().isBefore(s.expiresAt.subtract(refreshMargin ~/ 2));

  /// Hapus sesi (mis. user logout dari OLT).
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
