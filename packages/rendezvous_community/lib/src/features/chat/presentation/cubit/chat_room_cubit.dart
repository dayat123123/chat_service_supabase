import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/analytics/domain/services/community_analytics.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_room_state.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_extras_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/consent_gate.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
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
    StockRoomState? stockRoom,
    DateTime? cooldownUntil,
    @Default(false) bool dmRequestLimited,
    DmRequestState? dmRequest,
  }) = _ChatRoomState;

  const ChatRoomState._();

  bool isMine(ChatMessage m) => m.senderId != null && m.senderId == me?.id;

  bool get supportsReactions => room != null && room!.type != RoomType.support;

  bool get supportsDmRequests => room?.type == RoomType.direct;

  bool get awaitingReply {
    final room = this.room;
    if (room == null || room.type != RoomType.direct || nextCursor != null) return false;
    final mine = messages.where((m) => !m.isSystem && isMine(m));
    return mine.isNotEmpty && messages.every((m) => m.isSystem || isMine(m));
  }

  Duration cooldownLeft([DateTime? now]) {
    final until = cooldownUntil;
    if (until == null) return Duration.zero;
    final left = until.difference((now ?? DateTime.now()).toUtc());
    return left.isNegative ? Duration.zero : left;
  }

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
    this.maxGapPages = 5,
    this._consent,
    this._extras,
    this._analytics,
    this._requests,
    DateTime Function()? clock,
  }) : _meProvider = me,
       _clock = clock ?? DateTime.now,
       super(const ChatRoomState());

  final ChatRepository _chat;
  final MediaRepository _media;
  final ConsentGate? _consent;
  final ChatExtrasRepository? _extras;
  final CommunityAnalytics? _analytics;
  final MessageRequestRepository? _requests;
  final DateTime Function() _clock;
  final Future<UserSummary> Function() _meProvider;
  final String roomId;
  final int pageSize;
  final int maxGapPages;

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
        _chat.getRoom(roomId),
        _chat.getMembers(roomId),
        _chat.getMessages(roomId, limit: pageSize),
      ]);
      if (isClosed) return;
      final room = results[0] as ChatRoom?;
      final members = results[1] as List<RoomMember>;
      final page = results[2] as Paged<ChatMessage>;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          me: me,
          room: room,
          members: {for (final m in members) m.user.id: m},
          messages: List<ChatMessage>.of(page.items),
          nextCursor: page.nextCursor,
        ),
      );
      _connect(me);
      _scheduleMarkRead();
      unawaited(loadStockRoomState());
      unawaited(loadDmRequestState());
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> loadStockRoomState() async {
    final extras = _extras;
    final code = state.room?.stockCode;
    if (extras == null || state.room?.type != RoomType.stock || code == null) return;
    try {
      final stockRoom = await extras.stockRoomState(code);
      if (isClosed) return;
      final wait = stockRoom.waitSeconds;
      emit(
        state.copyWith(
          stockRoom: stockRoom,
          cooldownUntil: wait > 0 ? _now().add(Duration(seconds: wait)) : state.cooldownUntil,
        ),
      );
    } catch (_) {}
  }

  DateTime _now() => _clock().toUtc();

  Future<void> loadDmRequestState() async {
    final requests = _requests;
    if (requests == null || state.room?.type != RoomType.direct) return;
    try {
      final dmRequest = await requests.requestState(roomId);
      if (!isClosed) emit(state.copyWith(dmRequest: dmRequest, dmRequestLimited: dmRequest.limitReached));
    } catch (_) {}
  }

  Future<bool> acceptDmRequest() async {
    final requests = _requests;
    if (requests == null || !(state.dmRequest?.pendingAsRecipient ?? false)) return false;
    try {
      await requests.respond(roomId, MessageRequestAction.accept);
      if (!isClosed) emit(state.copyWith(dmRequest: const DmRequestState()));
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<void> react(ChatMessage message, String emoji) async {
    final extras = _extras;
    if (extras == null || !state.supportsReactions || message.isLocal || message.isDeleted) return;
    final current = state.messages.where((m) => m.id == message.id).firstOrNull ?? message;
    final previous = myReaction(current.reactions);
    final next = previous == emoji ? null : emoji;
    _setReactions(current.id, applyReaction(current.reactions, previous, next));
    try {
      final reactions = await extras.react(current.id, next);
      _setReactions(current.id, reactions);
    } catch (e) {
      _setReactions(current.id, current.reactions);
      _fail(e);
    }
  }

  void _setReactions(String messageId, List<MessageReaction> reactions) {
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: [for (final m in state.messages) m.id == messageId ? m.copyWith(reactions: reactions) : m],
      ),
    );
  }

  void _applyReactionEvent(ReactionChanged event) {
    final message = state.messages.where((m) => m.id == event.messageId).firstOrNull;
    if (message == null) return;
    final mine = event.userId == state.me?.id ? event.emoji : myReaction(message.reactions);
    _setReactions(event.messageId, [
      for (final r in event.counts)
        if (r.count > 0) r.copyWith(mine: r.emoji == mine),
    ]);
  }

  void _applyStockRoomState(StockRoomState next) {
    final previous = state.stockRoom;
    emit(state.copyWith(stockRoom: next.copyWith(waitSeconds: previous?.waitSeconds ?? 0)));
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
        if (reconnected) {
          unawaited(_fillGap());
          unawaited(_resendFailed());
        }
      case ReactionChanged():
        _applyReactionEvent(event);
      case StockRoomStateChanged(:final state):
        _applyStockRoomState(state);
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
    emit(
      state.copyWith(
        members: {
          ...state.members,
          receipt.userId: member.copyWith(lastDeliveredAt: merged.lastDeliveredAt, lastReadAt: merged.lastReadAt),
        },
      ),
    );
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

  void _upsert(ChatMessage message) => _upsertAll([message]);

  void _upsertAll(Iterable<ChatMessage> incoming) {
    if (isClosed) return;
    final list = [...state.messages];
    for (final message in incoming) {
      final index = list.indexWhere(
        (m) => m.id == message.id || (message.clientId != null && m.clientId == message.clientId),
      );
      if (index >= 0) {
        final old = list[index];
        final held = {for (final a in old.attachments.where((a) => a.held)) a.path};
        list[index] = message.copyWith(
          sender: message.sender ?? old.sender,
          replyToBody: message.replyToBody ?? old.replyToBody,
          replyToSenderUsername: message.replyToSenderUsername ?? old.replyToSenderUsername,
          cursor: message.cursor ?? old.cursor,
          status: MessageStatus.sent,
          reactions: message.isDeleted || message.reactions.isNotEmpty ? message.reactions : old.reactions,
          sharedPost: message.sharedPost ?? (message.sharedPostId == old.sharedPostId ? old.sharedPost : null),
          sharedPostId: message.sharedPostId ?? old.sharedPostId,
          moderationStatus: message.moderationStatus ?? old.moderationStatus,
          attachments: held.isEmpty
              ? message.attachments
              : [for (final a in message.attachments) held.contains(a.path) ? a.copyWith(held: true) : a],
        );
      } else {
        list.add(message);
      }
    }
    emit(state.copyWith(messages: list..sort(_newestFirst)));
  }

  static int _newestFirst(ChatMessage a, ChatMessage b) => b.createdAt.compareTo(a.createdAt);

  Future<void> _reloadMembers() async {
    try {
      final members = await _chat.getMembers(roomId);
      if (isClosed) return;
      final map = {for (final m in members) m.user.id: _keepLatestReceipt(m)};
      emit(
        state.copyWith(
          members: map,
          messages: [
            for (final m in state.messages)
              m.sender == null && map[m.senderId] != null ? m.copyWith(sender: map[m.senderId]!.user) : m,
          ],
        ),
      );
    } catch (_) {}
  }

  Future<void> _fillGap() async {
    final newest = state.messages.where((m) => !m.isLocal).firstOrNull;
    if (newest == null) return;
    String? cursor = newest.cursor ?? '${newest.createdAt.toUtc().toIso8601String()}|${newest.id}';
    try {
      for (var page = 0; cursor != null; page++) {
        if (page == maxGapPages) return await _reloadLatest();
        final batch = await _chat.getMessagesAfter(roomId, cursor);
        if (isClosed) return;
        _upsertAll(batch.items);
        cursor = batch.nextCursor;
      }
    } catch (_) {}
  }

  Future<void> _reloadLatest() async {
    final page = await _chat.getMessages(roomId, limit: pageSize);
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: [...state.messages.where((m) => m.isLocal), ...page.items]..sort(_newestFirst),
        nextCursor: page.nextCursor,
      ),
    );
  }

  Future<void> loadOlder() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingOlder) return;
    emit(state.copyWith(loadingOlder: true));
    try {
      final page = await _chat.getMessages(roomId, cursor: cursor, limit: pageSize);
      if (isClosed) return;
      final known = {for (final m in state.messages) m.id};
      emit(
        state.copyWith(
          messages: [...state.messages, ...page.items.where((m) => !known.contains(m.id))],
          nextCursor: page.nextCursor,
          loadingOlder: false,
        ),
      );
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

  Future<void> _resendFailed() async {
    for (final message in [...state.messages.reversed]) {
      if (message.isLocal && message.status == MessageStatus.failed) await _retry(message, askConsent: false);
    }
  }

  Future<void> retry(ChatMessage message) => _retry(message, askConsent: true);

  Future<void> _retry(ChatMessage message, {required bool askConsent}) async {
    if (message.status != MessageStatus.failed) return;
    _setStatus(message.clientId, MessageStatus.sending);
    await _deliver(message, askConsent: askConsent);
  }

  Future<void> _deliver(ChatMessage local, {bool askConsent = true}) async {
    final gate = askConsent && state.room?.type != RoomType.support ? _consent : null;
    try {
      final sent = await gate.guard(
        () => _chat.sendMessage(
          roomId,
          body: local.body ?? '',
          clientId: local.clientId!,
          replyToId: local.replyToId,
          attachments: local.attachments,
        ),
      );
      _upsert(sent);
      _afterSent(local);
    } catch (e) {
      final mapped = mapError(e);
      CommunityLoggers.chat.event(
        Level.SEVERE,
        'Failed to send message',
        fields: {'roomId': roomId, 'clientId': local.clientId, 'kind': mapped.kind, 'code': mapped.code},
      );
      if (mapped.kind == CommunityErrorKind.contentBlocked) {
        _removeLocal(local.clientId);
      } else {
        _setStatus(local.clientId, MessageStatus.failed);
      }
      if (mapped.code == 'slow_mode' && !isClosed) {
        final wait = mapped.retryAfter ?? Duration(seconds: state.stockRoom?.slowModeSeconds ?? 0);
        if (wait > Duration.zero) emit(state.copyWith(cooldownUntil: _now().add(wait)));
      }
      if (mapped.code == 'dm_request_limit' && !isClosed) {
        final dmRequest = state.dmRequest;
        emit(
          state.copyWith(
            dmRequestLimited: true,
            dmRequest: dmRequest != null && dmRequest.pendingAsSender
                ? dmRequest.copyWith(sent: dmRequest.maxMessages)
                : dmRequest,
          ),
        );
      }
      _fail(e);
    }
  }

  void _afterSent(ChatMessage local) {
    if (isClosed) return;
    final room = state.room;
    final stockRoom = state.stockRoom;
    if (room?.type == RoomType.stock && stockRoom != null && stockRoom.slowModeActive(_now())) {
      emit(state.copyWith(cooldownUntil: _now().add(Duration(seconds: stockRoom.slowModeSeconds))));
    }
    final dmRequest = state.dmRequest;
    if (dmRequest != null && dmRequest.pendingAsSender) {
      final next = dmRequest.copyWith(sent: dmRequest.sent + 1);
      emit(state.copyWith(dmRequest: next, dmRequestLimited: next.limitReached));
    } else if (dmRequest != null && dmRequest.pendingAsRecipient) {
      emit(state.copyWith(dmRequest: const DmRequestState()));
    }
    if (room == null || room.type == RoomType.support) return;
    _analytics?.record(CommunityAnalyticsEvent.messageSend, {
      'room_id': roomId,
      'type': room.type.name,
      'has_attachment': local.attachments.isNotEmpty,
    });
  }

  void _removeLocal(String? clientId) {
    if (isClosed || clientId == null) return;
    emit(
      state.copyWith(
        messages: [
          for (final m in state.messages)
            if (!(m.isLocal && m.clientId == clientId)) m,
        ],
      ),
    );
  }

  void _setStatus(String? clientId, MessageStatus status) {
    if (isClosed || clientId == null) return;
    emit(
      state.copyWith(
        messages: [
          for (final m in state.messages) m.clientId == clientId && m.isLocal ? m.copyWith(status: status) : m,
        ],
      ),
    );
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

  Future<void> sendDocument(Uint8List bytes, String name) async {
    emit(state.copyWith(uploading: true));
    try {
      final attachment = await _media.uploadSupportDocument(roomId, bytes, name: name);
      if (!isClosed) emit(state.copyWith(uploading: false));
      await send('', attachments: [attachment]);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(uploading: false));
      _fail(e);
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    final before = state.messages;
    emit(
      state.copyWith(
        messages: [
          for (final m in before)
            m.id == message.id ? m.copyWith(isDeleted: true, body: null, attachments: const []) : m,
        ],
      ),
    );
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
