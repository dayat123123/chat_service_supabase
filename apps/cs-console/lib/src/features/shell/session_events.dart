import 'dart:async';

import 'package:cs_console/src/features/tickets/data/queue_events.dart';

class SessionEvents {
  SessionEvents(Stream<QueueEvent> source) {
    _subscription = source.listen(_controller.add, onError: (Object _) {});
  }

  final _controller = StreamController<QueueEvent>.broadcast();
  late final StreamSubscription<QueueEvent> _subscription;

  Stream<QueueEvent> get stream => _controller.stream;

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
