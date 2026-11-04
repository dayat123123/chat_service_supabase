import 'dart:async';

import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/data/realtime/room_channel_hub.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

typedef MessagesAfter = Future<Paged<ChatMessage>> Function(String cursor);

const _zeroId = '00000000-0000-0000-0000-000000000000';

class SupabaseRoomConnection implements ChatRoomConnection {
  SupabaseRoomConnection(
    this._hub,
    this.roomId,
    this.me, {
    this._muteNotices,
    this._fetchAfter,
    this.referenceDelay = const Duration(milliseconds: 250),
  }) {
    _controller = StreamController<ChatRoomEvent>.broadcast(onListen: _open);
  }

  final RoomChannelHub _hub;
  final String roomId;
  final UserSummary me;
  final Stream<RoomMuteNotice>? _muteNotices;
  final MessagesAfter? _fetchAfter;
  final Duration referenceDelay;
  late final StreamController<ChatRoomEvent> _controller;
  StreamSubscription<RoomMessagePayload>? _messages;
  StreamSubscription<RoomSignal>? _signals;
  StreamSubscription<RoomMuteNotice>? _mutes;
  final _references = <String, DateTime>{};
  Timer? _referenceTimer;
  bool _opened = false;

  @override
  Stream<ChatRoomEvent> get events => _controller.stream;

  void _emit(ChatRoomEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _open() {
    if (_opened) return;
    _opened = true;

    _messages = _hub.watchMessages(roomId, me).listen(_onMessage);

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
          _emit(ConnectionChanged(status));
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

  void _onMessage(RoomMessagePayload event) {
    if (event.isReference) return _queueReference(event.data);
    final ChatMessage message;
    try {
      message = ChatMessageModel.fromJson(event.data).toEntity();
    } catch (_) {
      return;
    }
    if (message.roomId != roomId) return;
    _emit(MessageUpserted(message));
  }

  void _queueReference(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '');
    if (id == null || createdAt == null || _fetchAfter == null) return;
    _references[id] = createdAt.toUtc();
    _referenceTimer?.cancel();
    _referenceTimer = Timer(referenceDelay, () => unawaited(_fetchReferences()));
  }

  Future<void> _fetchReferences() async {
    final fetch = _fetchAfter;
    if (fetch == null || _references.isEmpty) return;
    final wanted = Map.of(_references);
    _references.clear();
    final earliest = wanted.values.reduce((a, b) => a.isBefore(b) ? a : b);
    try {
      final page = await fetch('${earliest.toIso8601String()}|$_zeroId');
      for (final message in page.items) {
        if (message.roomId == roomId && wanted.containsKey(message.id)) _emit(MessageUpserted(message));
      }
    } catch (_) {}
  }

  @override
  Future<void> sendTyping({required bool isTyping}) => _hub.sendTyping(roomId, me, isTyping: isTyping);

  @override
  Future<void> close() async {
    _referenceTimer?.cancel();
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
