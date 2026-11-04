import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';

class CommunityConnectivity {
  CommunityConnectivity({
    this.probe,
    this.minProbeDelay = const Duration(seconds: 5),
    this.maxProbeDelay = const Duration(minutes: 1),
  });

  Future<void> Function()? probe;
  final Duration minProbeDelay;
  final Duration maxProbeDelay;
  final _online = ValueNotifier<bool>(true);
  final _changes = StreamController<bool>.broadcast();
  final _resumes = StreamController<void>.broadcast();
  Timer? _timer;
  Duration? _delay;
  bool _disposed = false;

  ValueListenable<bool> get online => _online;

  bool get isOnline => _online.value;

  Stream<bool> get changes => _changes.stream;

  Stream<void> get resumes => _resumes.stream;

  void notifyResumed() {
    if (!_disposed) _resumes.add(null);
  }

  void report({required bool reachable}) {
    if (_disposed) return;
    if (reachable) {
      _timer?.cancel();
      _timer = null;
      _delay = null;
    }
    if (_online.value != reachable) {
      _online.value = reachable;
      _changes.add(reachable);
      CommunityLoggers.offline.event(Level.INFO, 'Network reachability changed', fields: {'online': reachable});
    }
    if (!reachable) _scheduleProbe();
  }

  Future<void> check() async {
    final probe = this.probe;
    if (probe == null || _disposed) return;
    try {
      await probe();
    } catch (_) {
    } finally {
      if (!_online.value) _scheduleProbe();
    }
  }

  void _scheduleProbe() {
    if (probe == null || _timer != null || _disposed) return;
    final previous = _delay;
    final delay = previous == null ? minProbeDelay : previous * 2;
    _delay = delay > maxProbeDelay ? maxProbeDelay : delay;
    _timer = Timer(_delay!, () {
      _timer = null;
      unawaited(check());
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _online.dispose();
    unawaited(_changes.close());
    unawaited(_resumes.close());
  }
}
