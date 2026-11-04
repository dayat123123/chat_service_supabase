import 'dart:async';

import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TypingSender = Future<void> Function(String roomId, {required bool isTyping});

class RoomMessagePayload {
  const RoomMessagePayload(this.roomId, this.data);

  final String roomId;
  final Map<String, dynamic> data;

  bool get isReference => data['ref'] == true;
}

class RoomChannelHub {
  RoomChannelHub(this._realtime, {this._typing});

  final RealtimeGateway _realtime;
  final TypingSender? _typing;
  final _rooms = <String, _RoomChannel>{};

  Stream<RoomSignal> watch(String roomId, UserSummary me) => _room(roomId, me).watch();

  Stream<RoomMessagePayload> watchMessages(String roomId, UserSummary me) => _room(roomId, me).watchMessages();

  Stream<RoomSignal> watchAll(Iterable<String> roomIds, UserSummary me) {
    final ids = roomIds.toSet();
    return Stream.multi((multi) {
      final subscriptions = [for (final id in ids) watch(id, me).listen(multi.add, onError: multi.addError)];
      multi.onCancel = () => Future.wait([for (final s in subscriptions) s.cancel()]);
    });
  }

  Future<void> sendTyping(String roomId, UserSummary me, {required bool isTyping}) async {
    final typing = _typing;
    if (typing == null) return;
    try {
      await typing(roomId, isTyping: isTyping);
    } catch (_) {}
  }

  _RoomChannel _room(String roomId, UserSummary me) =>
      _rooms.putIfAbsent(roomId, () => _RoomChannel(_realtime, roomId, me, onIdle: () => _rooms.remove(roomId)));
}

class _RoomChannel {
  _RoomChannel(this._realtime, this.roomId, this.me, {required this.onIdle}) {
    _controller = StreamController<Object>.broadcast(onListen: _open, onCancel: _close);
  }

  final RealtimeGateway _realtime;
  final String roomId;
  final UserSummary me;
  final void Function() onIdle;
  late final StreamController<Object> _controller;
  RealtimeChannel? _channel;
  RoomConnection? _connection;
  RoomPresence? _presence;

  Stream<RoomSignal> watch() => Stream.multi((multi) {
    final subscription = _controller.stream
        .where((e) => e is RoomSignal)
        .cast<RoomSignal>()
        .listen(multi.add, onError: multi.addError);
    for (final cached in [_connection, _presence]) {
      if (cached != null) multi.add(cached);
    }
    multi.onCancel = subscription.cancel;
  });

  Stream<RoomMessagePayload> watchMessages() =>
      _controller.stream.where((e) => e is RoomMessagePayload).cast<RoomMessagePayload>();

  void _emit(Object event) {
    if (event is RoomConnection) _connection = event;
    if (event is RoomPresence) _presence = event;
    if (!_controller.isClosed) _controller.add(event);
  }

  void _open() {
    final channel = _realtime.privateChannel('room:$roomId', presenceKey: me.id);
    _channel = channel;
    channel
      ..onBroadcast(event: 'message', callback: _onMessage)
      ..onBroadcast(event: 'typing', callback: _onTyping)
      ..onBroadcast(event: 'receipt', callback: _onReceipt)
      ..onBroadcast(event: 'reaction', callback: _onReaction)
      ..onBroadcast(event: 'room_state', callback: _onRoomState)
      ..onBroadcast(event: 'message_hidden', callback: _onMessageHidden)
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

  bool _forThisRoom(Map<String, dynamic> data) {
    final room = data['room_id'];
    return room == null || room == roomId;
  }

  void _onMessage(Map<String, dynamic> payload) {
    final data = broadcastPayload(payload);
    if (data['room_id'] != roomId || data['id'] is! String) return;
    _emit(RoomMessagePayload(roomId, data));
  }

  void _onTyping(Map<String, dynamic> payload) {
    final data = broadcastPayload(payload);
    final userId = data['user_id'] as String?;
    if (userId == null || userId == me.id || !_forThisRoom(data)) return;
    _emit(
      RoomTyping(
        roomId,
        UserSummary(
          id: userId,
          username: data['username'] as String? ?? '',
          displayName: data['display_name'] as String?,
        ),
        isTyping: data['typing'] == true,
      ),
    );
  }

  void _onReceipt(Map<String, dynamic> payload) {
    final receipt = parseReceipt(broadcastPayload(payload));
    if (receipt == null || receipt.userId == me.id) return;
    _emit(RoomReceipt(roomId, receipt));
  }

  void _onReaction(Map<String, dynamic> payload) {
    final data = broadcastPayload(payload);
    final messageId = data['message_id'] as String?;
    final userId = data['user_id'] as String?;
    if (messageId == null || userId == null) return;
    _emit(
      RoomReaction(
        roomId,
        messageId: messageId,
        userId: userId,
        emoji: data['emoji'] as String?,
        counts: reactionsFromJson(data['reactions']),
      ),
    );
  }

  void _onRoomState(Map<String, dynamic> payload) {
    final data = broadcastPayload(payload);
    if (!_forThisRoom(data)) return;
    _emit(RoomStateSignal(roomId, parseStockRoomState(data)));
  }

  void _onMessageHidden(Map<String, dynamic> payload) {
    final data = broadcastPayload(payload);
    final messageId = data['message_id'] as String?;
    if (messageId == null || !_forThisRoom(data)) return;
    _emit(RoomMessageHidden(roomId, messageId, userId: data['user_id'] as String?));
  }
}
