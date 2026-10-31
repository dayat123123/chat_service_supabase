import 'dart:async';

import 'package:olt_social/src/core/network/realtime_gateway.dart';
import 'package:olt_social/src/features/chat/data/models/chat_models.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomChannelHub {
  RoomChannelHub(this._realtime);

  final RealtimeGateway _realtime;
  final _rooms = <String, _RoomChannel>{};

  Stream<RoomSignal> watch(String roomId, UserSummary me) => _room(roomId, me).watch();

  Stream<RoomSignal> watchAll(Iterable<String> roomIds, UserSummary me) {
    final ids = roomIds.toSet();
    return Stream.multi((multi) {
      final subscriptions = [
        for (final id in ids) watch(id, me).listen(multi.add, onError: multi.addError),
      ];
      multi.onCancel = () => Future.wait([for (final s in subscriptions) s.cancel()]);
    });
  }

  Future<void> sendTyping(String roomId, UserSummary me, {required bool isTyping}) async {
    await _rooms[roomId]?.sendTyping(me, isTyping: isTyping);
  }

  _RoomChannel _room(String roomId, UserSummary me) =>
      _rooms.putIfAbsent(roomId, () => _RoomChannel(_realtime, roomId, me, onIdle: () => _rooms.remove(roomId)));
}

class _RoomChannel {
  _RoomChannel(this._realtime, this.roomId, this.me, {required this.onIdle}) {
    _controller = StreamController<RoomSignal>.broadcast(onListen: _open, onCancel: _close);
  }

  final RealtimeGateway _realtime;
  final String roomId;
  final UserSummary me;
  final void Function() onIdle;
  late final StreamController<RoomSignal> _controller;
  RealtimeChannel? _channel;
  RoomConnection? _connection;
  RoomPresence? _presence;

  Stream<RoomSignal> watch() => Stream.multi((multi) {
    final subscription = _controller.stream.listen(multi.add, onError: multi.addError);
    for (final cached in [_connection, _presence]) {
      if (cached != null) multi.add(cached);
    }
    multi.onCancel = subscription.cancel;
  });

  void _emit(RoomSignal signal) {
    if (signal is RoomConnection) _connection = signal;
    if (signal is RoomPresence) _presence = signal;
    if (!_controller.isClosed) _controller.add(signal);
  }

  void _open() {
    final channel = _realtime.privateChannel('room:$roomId', presenceKey: me.id);
    _channel = channel;
    channel
      ..onBroadcast(event: 'typing', callback: _onTyping)
      ..onBroadcast(event: 'receipt', callback: _onReceipt)
      ..onPresenceSync((_) => _emit(RoomPresence(roomId, {for (final s in channel.presenceState()) s.key})))
      ..subscribe((status, _) async {
        _emit(RoomConnection(roomId, mapSubscribeStatus(status)));
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.track({'user_id': me.id});
        }
      });
  }

  Future<void> _close() async {
    final channel = _channel;
    _channel = null;
    onIdle();
    if (channel != null) await _realtime.remove(channel);
  }

  void _onTyping(Map<String, dynamic> payload) {
    final data = _unwrap(payload);
    final userId = data['user_id'] as String?;
    if (userId == null || userId == me.id) return;
    _emit(RoomTyping(
      roomId,
      UserSummary(id: userId, username: data['username'] as String? ?? '', displayName: data['display_name'] as String?),
      isTyping: data['typing'] == true,
    ));
  }

  void _onReceipt(Map<String, dynamic> payload) {
    final receipt = parseReceipt(_unwrap(payload));
    if (receipt == null || receipt.userId == me.id) return;
    _emit(RoomReceipt(roomId, receipt));
  }

  Future<void> sendTyping(UserSummary me, {required bool isTyping}) async {
    await _channel?.sendBroadcastMessage(event: 'typing', payload: {
      'user_id': me.id,
      'username': me.username,
      'display_name': me.displayName,
      'typing': isTyping,
    });
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> payload) {
    final inner = payload['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : payload;
  }
}
