import 'dart:async';
import 'dart:math';

class GapFillSchedule {
  GapFillSchedule(
    this._run, {
    required this.interval,
    required this.jitter,
    required this.recheck,
    Random? random,
    bool Function()? online,
  }) : _random = random ?? Random(),
       _online = online ?? _always;

  final Future<void> Function() _run;
  final Duration interval;
  final Duration jitter;
  final Duration recheck;
  final Random _random;
  final bool Function() _online;
  Timer? _periodic;
  Timer? _first;
  Timer? _second;
  bool _disposed = false;

  static bool _always() => true;

  void start() {
    _periodic?.cancel();
    if (_disposed || interval <= Duration.zero) return;
    _periodic = Timer(interval * (0.75 + _random.nextDouble() * 0.5), () {
      if (_online()) unawaited(_run());
      start();
    });
  }

  void reconnected() {
    if (_disposed) return;
    _first?.cancel();
    _second?.cancel();
    final first = _upTo(jitter);
    _first = Timer(first, _fire);
    _second = recheck > Duration.zero ? Timer(first + recheck + _upTo(recheck), _fire) : null;
  }

  Duration _upTo(Duration max) => max > Duration.zero ? max * _random.nextDouble() : Duration.zero;

  void _fire() {
    if (!_disposed) unawaited(_run());
  }

  void dispose() {
    _disposed = true;
    _periodic?.cancel();
    _first?.cancel();
    _second?.cancel();
  }
}
