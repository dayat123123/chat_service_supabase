import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_event.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_event_repository.dart';

class NotificationReporter {
  NotificationReporter(this._repository, {this.maxQueued = 50});

  final NotificationEventRepository _repository;
  final int maxQueued;
  final _reported = <String>{};
  final _queued = <(NotificationEvent, NotificationSource)>[];

  int get queuedCount => _queued.length;

  Future<void> opened(NotificationSource source) => report(NotificationEvent.opened, source);

  Future<void> tapped(NotificationSource source) => report(NotificationEvent.tapped, source);

  Future<void> report(NotificationEvent event, NotificationSource source) async {
    if (source.isEmpty || !_reported.add('${event.name}|${source.key}')) return;
    await _send(event, source);
  }

  Future<void> flush() async {
    final pending = [..._queued];
    _queued.clear();
    for (final (event, source) in pending) {
      await _send(event, source);
    }
  }

  void reset() {
    _reported.clear();
    _queued.clear();
  }

  Future<void> _send(NotificationEvent event, NotificationSource source) async {
    try {
      await _repository.report(event, source);
    } catch (e) {
      final error = mapError(e);
      final queue = error.kind == CommunityErrorKind.network && _queued.length < maxQueued;
      if (queue) _queued.add((event, source));
      CommunityLoggers.push.event(
        Level.FINE,
        queue ? 'Notification event queued' : 'Notification event dropped',
        fields: {'event': event.name, 'kind': error.kind, 'code': error.code},
      );
    }
  }
}
