import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/domain/repositories/client_config_repository.dart';

typedef CommunityUpdateRequiredCallback = void Function(ClientConfig config);

class ClientConfigService {
  ClientConfigService(
    this._repository, {
    this.platform,
    this.appVersion,
    this.onUpdateRequired,
    this.interval = const Duration(minutes: 5),
    ClientConfig initial = const ClientConfig(),
  }) : _value = ValueNotifier(initial);

  final ClientConfigRepository _repository;
  final String? platform;
  final String? appVersion;
  final CommunityUpdateRequiredCallback? onUpdateRequired;
  final Duration interval;
  final ValueNotifier<ClientConfig> _value;
  final _changes = StreamController<ClientConfig>.broadcast();
  Future<ClientConfig>? _inflight;
  Timer? _timer;
  bool _disposed = false;

  ClientConfig get current => _value.value;

  ValueListenable<ClientConfig> get listenable => _value;

  Stream<ClientConfig> get changes => _changes.stream;

  Future<ClientConfig> refresh() => _inflight ??= _fetch().whenComplete(() => _inflight = null);

  Future<ClientConfig> _fetch() async {
    try {
      final next = await _repository.fetch(platform: platform, appVersion: appVersion);
      _set(next);
    } catch (e) {
      final mapped = mapError(e);
      CommunityLoggers.config.event(
        Level.WARNING,
        'Client config refresh failed',
        fields: {'kind': mapped.kind, 'code': mapped.code},
      );
    }
    return current;
  }

  void markSocialDisabled() {
    if (_disposed || !current.socialEnabled) return;
    _set(current.copyWith(socialEnabled: false));
    unawaited(refresh());
  }

  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _set(ClientConfig next) {
    if (_disposed) return;
    final previous = current;
    if (previous.loaded && next.copyWith(fetchedAt: previous.fetchedAt, clockSkew: previous.clockSkew) == previous) {
      return;
    }
    _value.value = next;
    if (!_changes.isClosed) _changes.add(next);
    if (previous.socialEnabled != next.socialEnabled || previous.updateRequired != next.updateRequired) {
      CommunityLoggers.config.event(
        Level.INFO,
        'Client config changed',
        fields: {'socialEnabled': next.socialEnabled, 'updateRequired': next.updateRequired},
      );
    }
    if (next.updateRequired && !previous.updateRequired) onUpdateRequired?.call(next);
  }

  Future<void> dispose() async {
    _disposed = true;
    stop();
    await _changes.close();
  }
}
