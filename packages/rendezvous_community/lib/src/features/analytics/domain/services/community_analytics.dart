import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/analytics/domain/repositories/analytics_repository.dart';

class CommunityAnalytics {
  CommunityAnalytics(
    this._repository, {
    required this._enabled,
    required this._signedIn,
    this.platform,
    this.appVersion,
    this.batchSize = 50,
    this.flushThreshold = 20,
    this.maxQueue = 500,
    this.interval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AnalyticsRepository _repository;
  final bool Function() _enabled;
  final bool Function() _signedIn;
  final DateTime Function() _clock;
  final String? platform;
  final String? appVersion;
  final int batchSize;
  final int flushThreshold;
  final int maxQueue;
  final Duration interval;
  final _queue = <AnalyticsEvent>[];
  bool _serverDisabled = false;
  bool _flushing = false;
  Timer? _timer;

  int get pending => _queue.length;

  bool get active => !_serverDisabled && _enabled();

  void record(String event, [Map<String, Object?> props = const {}]) {
    if (!CommunityAnalyticsEvent.all.contains(event) || !active) return;
    _queue.add(AnalyticsEvent(event, sanitizeAnalyticsProps(props), _clock()));
    if (_queue.length > maxQueue) _queue.removeRange(0, _queue.length - maxQueue);
    if (_queue.length >= flushThreshold) unawaited(flush());
  }

  Future<AnalyticsResult?> flush() async {
    if (_flushing || _queue.isEmpty) return null;
    if (!active) {
      _queue.clear();
      return null;
    }
    if (!_signedIn()) return null;
    _flushing = true;
    var accepted = 0;
    var dropped = 0;
    var sent = false;
    try {
      while (_queue.isNotEmpty && active) {
        final batch = _queue.take(batchSize).toList();
        _queue.removeRange(0, batch.length);
        try {
          final result = await _repository.track(batch, platform: platform, appVersion: appVersion);
          sent = true;
          accepted += result.accepted;
          dropped += result.dropped;
          if (result.disabled) {
            _serverDisabled = true;
            _queue.clear();
            CommunityLoggers.analytics.event(Level.FINE, 'Analytics disabled by server');
          }
        } catch (e) {
          final mapped = mapError(e);
          CommunityLoggers.analytics.event(
            Level.FINE,
            'Analytics batch dropped',
            fields: {'eventCount': batch.length, 'kind': mapped.kind, 'code': mapped.code},
          );
          break;
        }
      }
    } finally {
      _flushing = false;
    }
    return sent ? AnalyticsResult(accepted: accepted, dropped: dropped, disabled: _serverDisabled) : null;
  }

  void reset() {
    _queue.clear();
    _serverDisabled = false;
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(flush()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _queue.clear();
  }
}
