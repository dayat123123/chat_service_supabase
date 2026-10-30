import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/src/core/network/realtime_status.dart';
import 'package:olt_social/src/core/paging/paged.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/entities/receipt.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/features/media/domain/repositories/media_repository.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:uuid/uuid.dart';

part 'chat_room_cubit.freezed.dart';

const _uuid = Uuid();

@freezed
abstract class ChatRoomState with _$ChatRoomState {
  const factory ChatRoomState({
    @Default(LoadStatus.initial) LoadStatus status,
    ChatRoom? room,
    UserSummary? me,
    @Default(<ChatMessage>[]) List<ChatMessage> messages,
    String? nextCursor,
    @Default(false) bool loadingOlder,
    @Default(<String, RoomMember>{}) Map<String, RoomMember> members,
    @Default(<String, UserSummary>{}) Map<String, UserSummary> typing,
    @Default(<String>{}) Set<String> online,
    @Default(RealtimeStatus.connecting) RealtimeStatus connection,
    ChatMessage? replyTo,
    @Default(false) bool uploading,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _ChatRoomState;

  const ChatRoomState._();

  bool isMine(ChatMessage m) => m.senderId != null && m.senderId == me?.id;

  bool get otherOnline {
    final other = room?.otherUser;
    return other != null && online.contains(other.id);
  }

  ReceiptStatus? receiptOf(ChatMessage m) {
    if (!isMine(m) || m.status != MessageStatus.sent || m.isLocal) return null;
    final room = this.room;
    if (room == null || !room.tracksReceipts) return ReceiptStatus.sent;
    return receiptStatus(m.createdAt, [
      for (final member in members.values)
        if (member.user.id != me?.id) member.receipt,
    ]);
  }
}

class ChatRoomCubit extends Cubit<ChatRoomState> {
  ChatRoomCubit({
    required this._chat,
    required this._media,
    required Future<UserSummary> Function() me,
    required this.roomId,
    this.pageSize = 30,
  }) : _meProvider = me,
       super(const ChatRoomState());

  final ChatRepository _chat;
  final MediaRepository _media;
  final Future<UserSummary> Function() _meProvider;
  final String roomId;
  final int pageSize;

  ChatRoomConnection? _connection;
  StreamSubscription<ChatRoomEvent>? _events;
  final _typingTimers = <String, Timer>{};
  Timer? _typingIdle;
  Timer? _readDebounce;
  bool _typingSent = false;
  bool _wasConnected = false;
  RealtimeStatus? _signals;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final me = await _meProvider();
      final results = await Future.wait([
        _chat.getRooms(),
        _chat.getMembers(roomId),
        _chat.getMessages(roomId, limit: pageSize),
      ]);
      if (isClosed) return;
      final rooms = results[0] as List<ChatRoom>;
      final members = results[1] as List<RoomMember>;
      final page = results[2] as Paged<ChatMessage>;
      emit(state.copyWith(
        status: LoadStatus.ready,
        me: me,
        room: rooms.where((r) => r.id == roomId).firstOrNull,
        members: {for (final m in members) m.user.id: m},
        messages: List<ChatMessage>.of(page.items),
        nextCursor: page.nextCursor,
      ));
      _connect(me);
      _scheduleMarkRead();
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  void _connect(UserSummary me) {
    final connection = _chat.connectRoom(roomId, me: me);
    _connection = connection;
    _events = connection.events.listen(_onEvent, onError: (Object _) {});
  }

  void _onEvent(ChatRoomEvent event) {
    if (isClosed) return;
    switch (event) {
      case MessageUpserted(:final message):
        _upsert(_resolve(message));
        if (!state.isMine(message)) {
          _removeTyping(message.senderId);
          _scheduleMarkRead();
        }
      case TypingChanged(:final user, :final isTyping):
        isTyping ? _addTyping(user) : _removeTyping(user.id);
      case ReceiptChanged(:final receipt):
        _applyReceipt(receipt);
      case PresenceChanged(:final userIds):
        emit(state.copyWith(online: userIds));
      case ConnectionChanged(:final status):
        final reconnected =
            status == RealtimeStatus.connected && _wasConnected && state.connection != RealtimeStatus.connected;
        if (status == RealtimeStatus.connected) _wasConnected = true;
        emit(state.copyWith(connection: status));
        if (reconnected) unawaited(_fillGap());
      case SignalsConnectionChanged(:final status):
        final previous = _signals;
        _signals = status;
        if (status == RealtimeStatus.connected && previous != null && previous != status) {
          unawaited(_reloadMembers());
        }
    }
  }

  void _applyReceipt(MemberReceipt receipt) {
    final member = state.members[receipt.userId];
    if (member == null) return;
    final merged = member.receipt.merge(receipt);
    if (merged == member.receipt) return;
    emit(state.copyWith(members: {
      ...state.members,
      receipt.userId: member.copyWith(lastDeliveredAt: merged.lastDeliveredAt, lastReadAt: merged.lastReadAt),
    }));
  }

  RoomMember _keepLatestReceipt(RoomMember fresh) {
    final known = state.members[fresh.user.id];
    if (known == null) return fresh;
    final merged = known.receipt.merge(fresh.receipt);
    return fresh.copyWith(lastDeliveredAt: merged.lastDeliveredAt, lastReadAt: merged.lastReadAt);
  }

  ChatMessage _resolve(ChatMessage m) {
    var resolved = m;
    if (m.sender == null && m.senderId != null) {
      final member = state.members[m.senderId];
      if (member != null) {
        resolved = resolved.copyWith(sender: member.user);
      } else {
        unawaited(_reloadMembers());
      }
    }
    if (m.replyToId != null && m.replyToBody == null) {
      final target = state.messages.where((x) => x.id == m.replyToId).firstOrNull;
      if (target != null) {
        resolved = resolved.copyWith(replyToBody: target.body, replyToSenderUsername: target.sender?.username);
      }
    }
    return resolved;
  }

  void _upsert(ChatMessage message) {
    if (isClosed) return;
    final list = [...state.messages];
    final index = list.indexWhere(
      (m) => m.id == message.id || (message.clientId != null && m.clientId == message.clientId),
    );
    if (index >= 0) {
      final old = list[index];
      list[index] = message.copyWith(
        sender: message.sender ?? old.sender,
        replyToBody: message.replyToBody ?? old.replyToBody,
        replyToSenderUsername: message.replyToSenderUsername ?? old.replyToSenderUsername,
        cursor: message.cursor ?? old.cursor,
        status: MessageStatus.sent,
      );
    } else {
      list.add(message);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(messages: list));
  }

  Future<void> _reloadMembers() async {
    try {
      final members = await _chat.getMembers(roomId);
      if (isClosed) return;
      final map = {for (final m in members) m.user.id: _keepLatestReceipt(m)};
      emit(state.copyWith(
        members: map,
        messages: [
          for (final m in state.messages)
            m.sender == null && map[m.senderId] != null ? m.copyWith(sender: map[m.senderId]!.user) : m,
        ],
      ));
    } catch (_) {}
  }

  Future<void> _fillGap() async {
    final newest = state.messages.where((m) => !m.isLocal).firstOrNull;
    if (newest == null) return;
    final cursor = newest.cursor ?? '${newest.createdAt.toUtc().toIso8601String()}|${newest.id}';
    try {
      for (final m in await _chat.getMessagesAfter(roomId, cursor)) {
        _upsert(m);
      }
    } catch (_) {}
  }

  Future<void> loadOlder() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingOlder) return;
    emit(state.copyWith(loadingOlder: true));
    try {
      final page = await _chat.getMessages(roomId, cursor: cursor, limit: pageSize);
      if (isClosed) return;
      final known = {for (final m in state.messages) m.id};
      emit(state.copyWith(
        messages: [...state.messages, ...page.items.where((m) => !known.contains(m.id))],
        nextCursor: page.nextCursor,
        loadingOlder: false,
      ));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loadingOlder: false));
      _fail(e);
    }
  }

  void setReplyTo(ChatMessage? message) => emit(state.copyWith(replyTo: message));

  Future<void> send(String text, {List<Attachment> attachments = const []}) async {
    final body = text.trim();
    final me = state.me;
    if ((body.isEmpty && attachments.isEmpty) || me == null) return;
    final clientId = _uuid.v4();
    final replyTo = state.replyTo;
    final local = ChatMessage(
      id: 'local-$clientId',
      roomId: roomId,
      senderId: me.id,
      sender: me,
      body: body,
      replyToId: replyTo?.id,
      replyToBody: replyTo?.body,
      replyToSenderUsername: replyTo?.sender?.username,
      attachments: attachments,
      clientId: clientId,
      createdAt: DateTime.now().toUtc(),
      status: MessageStatus.sending,
    );
    emit(state.copyWith(messages: [local, ...state.messages], replyTo: null));
    unawaited(stopTyping());
    await _deliver(local);
  }

  Future<void> retry(ChatMessage message) async {
    if (message.status != MessageStatus.failed) return;
    _setStatus(message.clientId, MessageStatus.sending);
    await _deliver(message);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      final sent = await _chat.sendMessage(
        roomId,
        body: local.body ?? '',
        clientId: local.clientId!,
        replyToId: local.replyToId,
        attachments: local.attachments,
      );
      _upsert(sent);
    } catch (e) {
      _setStatus(local.clientId, MessageStatus.failed);
      _fail(e);
    }
  }

  void _setStatus(String? clientId, MessageStatus status) {
    if (isClosed || clientId == null) return;
    emit(state.copyWith(messages: [
      for (final m in state.messages) m.clientId == clientId && m.isLocal ? m.copyWith(status: status) : m,
    ]));
  }

  Future<void> sendImage(Uint8List bytes, String mimeType) async {
    emit(state.copyWith(uploading: true));
    try {
      final attachment = await _media.uploadChatImage(roomId, bytes, mimeType: mimeType);
      if (!isClosed) emit(state.copyWith(uploading: false));
      await send('', attachments: [attachment]);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(uploading: false));
      _fail(e);
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    final before = state.messages;
    emit(state.copyWith(messages: [
      for (final m in before) m.id == message.id ? m.copyWith(isDeleted: true, body: null, attachments: const []) : m,
    ]));
    try {
      await _chat.deleteMessage(message.id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(messages: before));
      _fail(e);
    }
  }

  void onTextChanged(String text) {
    if (text.trim().isEmpty) {
      unawaited(stopTyping());
      return;
    }
    if (!_typingSent) {
      _typingSent = true;
      unawaited(_connection?.sendTyping(isTyping: true));
    }
    _typingIdle?.cancel();
    _typingIdle = Timer(const Duration(seconds: 3), stopTyping);
  }

  Future<void> stopTyping() async {
    _typingIdle?.cancel();
    if (!_typingSent) return;
    _typingSent = false;
    await _connection?.sendTyping(isTyping: false);
  }

  void _addTyping(UserSummary user) {
    final known = state.members[user.id]?.user ?? user;
    _typingTimers[user.id]?.cancel();
    _typingTimers[user.id] = Timer(const Duration(seconds: 6), () => _removeTyping(user.id));
    emit(state.copyWith(typing: {...state.typing, user.id: known}));
  }

  void _removeTyping(String? userId) {
    if (userId == null || isClosed || !state.typing.containsKey(userId)) return;
    _typingTimers.remove(userId)?.cancel();
    emit(state.copyWith(typing: {...state.typing}..remove(userId)));
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        await _chat.markRoomRead(roomId);
      } catch (_) {}
    });
  }

  Future<void> setMuted(bool muted) async {
    final room = state.room;
    if (room == null) return;
    emit(state.copyWith(room: room.copyWith(muted: muted)));
    try {
      await _chat.setMuted(roomId, muted: muted);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(room: room));
      _fail(e);
    }
  }

  Future<bool> leave() async {
    try {
      await _chat.leaveRoom(roomId);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  void _fail(Object error) {
    if (!isClosed) emit(state.copyWith(actionError: error, actionErrorId: state.actionErrorId + 1));
  }

  @override
  Future<void> close() async {
    _readDebounce?.cancel();
    _typingIdle?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    if (_typingSent) unawaited(_connection?.sendTyping(isTyping: false));
    await _events?.cancel();
    await _connection?.close();
    return super.close();
  }
}
