import 'dart:async';

import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';

class DeliveryTracker {
  DeliveryTracker(this._chat, {required this.currentUserId, this.debounce = const Duration(milliseconds: 400)});

  final ChatRepository _chat;
  final String? Function() currentUserId;
  final Duration debounce;
  final _pending = <String>{};
  StreamSubscription<RoomActivity>? _activity;
  Timer? _timer;

  bool get isRunning => _activity != null;

  void start() {
    if (_activity != null) return;
    _activity = _chat.watchRoomActivity().listen(_onActivity, onError: (Object _) {});
    unawaited(_markAll());
  }

  void _onActivity(RoomActivity activity) {
    if (activity.senderId == null || activity.senderId == currentUserId()) return;
    _pending.add(activity.roomId);
    _timer?.cancel();
    _timer = Timer(debounce, _flush);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final rooms = _pending.toList();
    _pending.clear();
    try {
      await _chat.markDelivered(roomIds: rooms);
    } catch (_) {
      _pending.addAll(rooms);
    }
  }

  Future<void> _markAll() async {
    try {
      await _chat.markDelivered();
    } catch (_) {}
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    await _activity?.cancel();
    _activity = null;
  }
}
