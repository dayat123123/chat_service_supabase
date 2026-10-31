import 'dart:async';

import 'package:olt_social/src/core/network/realtime_gateway.dart';
import 'package:olt_social/src/features/chat/data/models/chat_models.dart';
import 'package:olt_social/src/features/chat/data/realtime/room_channel_hub.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRoomConnection implements ChatRoomConnection {
  SupabaseRoomConnection(this._realtime, this._hub, this.roomId, this.me) {
    _controller = StreamController<ChatRoomEvent>.broadcast(onListen: _open);
  }

  final RealtimeGateway _realtime;
  final RoomChannelHub _hub;
  final String roomId;
  final UserSummary me;
  late final StreamController<ChatRoomEvent> _controller;
  StreamSubscription<PostgresChangePayload>? _messages;
  StreamSubscription<RoomSignal>? _signals;
  bool _opened = false;

  @override
  Stream<ChatRoomEvent> get events => _controller.stream;

  void _emit(ChatRoomEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _open() {
    if (_opened) return;
    _opened = true;

    _messages = _realtime
        .tableChanges(
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          onStatus: (status) => _emit(ConnectionChanged(status)),
        )
        .listen((payload) {
          if (payload.eventType == PostgresChangeEvent.delete) return;
          _emit(MessageUpserted(MessageRowModel.fromJson(payload.newRecord).toEntity()));
        });

    _signals = _hub.watch(roomId, me).listen((signal) {
      switch (signal) {
        case RoomTyping(:final user, :final isTyping):
          _emit(TypingChanged(user, isTyping: isTyping));
        case RoomReceipt(:final receipt):
          _emit(ReceiptChanged(receipt));
        case RoomPresence(:final userIds):
          _emit(PresenceChanged(userIds));
        case RoomConnection(:final status):
          _emit(SignalsConnectionChanged(status));
      }
    });
  }

  @override
  Future<void> sendTyping({required bool isTyping}) => _hub.sendTyping(roomId, me, isTyping: isTyping);

  @override
  Future<void> close() async {
    await _messages?.cancel();
    _messages = null;
    await _signals?.cancel();
    _signals = null;
    await _controller.close();
  }
}

class NoopRoomConnection implements ChatRoomConnection {
  @override
  Stream<ChatRoomEvent> get events => const Stream.empty();

  @override
  Future<void> sendTyping({required bool isTyping}) async {}

  @override
  Future<void> close() async {}
}
