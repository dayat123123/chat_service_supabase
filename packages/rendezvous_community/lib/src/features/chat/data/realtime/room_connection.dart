import 'dart:async';

import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/data/realtime/room_channel_hub.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRoomConnection implements ChatRoomConnection {
  SupabaseRoomConnection(this._realtime, this._hub, this.roomId, this.me, [this._muteNotices]) {
    _controller = StreamController<ChatRoomEvent>.broadcast(onListen: _open);
  }

  final RealtimeGateway _realtime;
  final RoomChannelHub _hub;
  final String roomId;
  final UserSummary me;
  final Stream<RoomMuteNotice>? _muteNotices;
  late final StreamController<ChatRoomEvent> _controller;
  StreamSubscription<PostgresChangePayload>? _messages;
  StreamSubscription<RoomSignal>? _signals;
  StreamSubscription<RoomMuteNotice>? _mutes;
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

    _mutes = _muteNotices
        ?.where((notice) => notice.roomId == roomId)
        .listen((notice) => _emit(OwnRoomMuteChanged(notice.mutedUntil)), onError: (Object _) {});

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
        case RoomReaction(:final messageId, :final userId, :final emoji, :final counts):
          _emit(ReactionChanged(messageId: messageId, userId: userId, emoji: emoji, counts: counts));
        case RoomStateSignal(:final state):
          _emit(StockRoomStateChanged(state));
        case RoomMessageHidden(:final messageId, :final userId):
          _emit(MessageHidden(messageId, userId: userId));
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
    await _mutes?.cancel();
    _mutes = null;
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
