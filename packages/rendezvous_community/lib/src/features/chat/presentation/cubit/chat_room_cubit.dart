import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/network/community_connectivity.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/analytics/domain/services/community_analytics.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/gap_horizon.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/outbox_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_card.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_room_state.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_cache_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_extras_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/message_gap_fill.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/message_outbox.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/gap_fill_schedule.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/consent_gate.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:uuid/uuid.dart';

part 'chat_room_cubit.freezed.dart';

const _uuid = Uuid();

const attachmentOfflineError = CommunityException(CommunityErrorKind.network, code: 'attachment_offline');

const roomMutedError = CommunityException(CommunityErrorKind.forbidden, code: 'room_muted');

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
    @Default(false) bool stale,
  }) = _ChatRoomState;

  const ChatRoomState._();

  bool isMine(ChatMessage m) => m.senderId != null && m.senderId == me?.id;

  bool get supportsReactions => room != null && room!.type != RoomType.support;

  bool get supportsDmRequests => room?.type == RoomType.direct;

  bool get isStockRoom => room?.type == RoomType.stock;

  bool get isRoomModerator => isStockRoom && (stockRoom?.isModerator(me?.id) ?? false);

  bool isModerator(String? userId) => isStockRoom && (stockRoom?.isModerator(userId) ?? false);

  DateTime? mutedUntil([DateTime? now]) =>
      isStockRoom ? stockRoom?.viewerMute(now) ?? stockRoom?.mutedUntil(me?.id, now) : null;

  DateTime? memberMutedUntil(String? userId, [DateTime? now]) =>
      isStockRoom ? stockRoom?.mutedUntil(userId, now) : null;

  bool canEscalate(ChatMessage m) =>
      isRoomModerator &&
      !isMine(m) &&
      m.senderId != null &&
      m.status == MessageStatus.sent &&
      !m.isLocal &&
      !m.isDeleted &&
      !m.isSystem &&
      m.senderRole == null;

  bool canModerate(ChatMessage m) => canEscalate(m) && !isModerator(m.senderId);

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
    this._cache,
    this._outbox,
    this._connectivity,
    DateTime Function()? clock,
    this.gapFillInterval = const Duration(seconds: 45),
    this.gapOverlap = const Duration(seconds: 10),
    this.reconnectJitter = const Duration(seconds: 5),
    this.gapRecheckDelay = const Duration(seconds: 5),
    this._random,
  }) : _meProvider = me,
       _clock = clock ?? DateTime.now,
       super(const ChatRoomState());

  final ChatRepository _chat;
  final MediaRepository _media;
  final ConsentGate? _consent;
  final ChatExtrasRepository? _extras;
  final CommunityAnalytics? _analytics;
  final MessageRequestRepository? _requests;
  final ChatCacheRepository? _cache;
  final MessageOutbox? _outbox;
  final CommunityConnectivity? _connectivity;
  StreamSubscription<OutboxEvent>? _outboxEvents;
  StreamSubscription<bool>? _onlineChanges;
  Timer? _muteExpiry;
  List<OutboxMessage> _queued = const [];
  final DateTime Function() _clock;
  final Future<UserSummary> Function() _meProvider;
  final String roomId;
  final int pageSize;
  final int maxGapPages;
  final Duration gapFillInterval;
  final Duration gapOverlap;
  final Duration reconnectJitter;
  final Duration gapRecheckDelay;
  final Random? _random;
  late final GapFillSchedule _gapSchedule = GapFillSchedule(
    _fillGap,
    interval: gapFillInterval,
    jitter: reconnectJitter,
    recheck: gapRecheckDelay,
    random: _random,
    online: () => _connectivity?.isOnline ?? true,
  );
  late final MessageGapFill _gapFill = MessageGapFill(_chat, roomId, maxPages: maxGapPages, overlap: gapOverlap);
  GapHorizon? _horizon;
  StreamSubscription<void>? _resumes;
  Future<void>? _gapRun;
  bool _gapAgain = false;

  bool get queuesOffline => _outbox != null;

  ChatRoomConnection? _connection;
  StreamSubscription<ChatRoomEvent>? _events;
  final _typingTimers = <String, Timer>{};
  Timer? _typingIdle;
  Timer? _readDebounce;
  bool _typingSent = false;
  bool _wasConnected = false;
  RealtimeStatus? _signals;

  Future<void> load() async {
    final showingCache = state.status == LoadStatus.ready && state.stale;
    if (!showingCache) {
      emit(state.copyWith(status: LoadStatus.loading, error: null));
      _watchOffline();
      await _showCached();
    }
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
      _horizon = _newestOf(page.items);
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          me: me,
          room: room,
          members: {for (final m in members) m.user.id: m},
          messages: _withLocal(page.items, me),
          nextCursor: page.nextCursor,
          stale: false,
        ),
      );
      _queued = const [];
      if (_connection == null) _connect(me);
      _scheduleMarkRead();
      unawaited(loadStockRoomState());
      unawaited(loadDmRequestState());
    } catch (e) {
      if (isClosed || (state.status == LoadStatus.ready && state.stale)) return;
      emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> _showCached() async {
    _queued = await _outbox?.messages(roomId) ?? const [];
    final cache = _cache;
    if (cache == null) return;
    final messages = await cache.cachedMessages(roomId);
    final room = (await cache.cachedRooms()).where((r) => r.id == roomId).firstOrNull;
    if (isClosed || (messages.isEmpty && room == null)) return;
    final me = await cache.cachedUser();
    if (isClosed || state.status == LoadStatus.ready) return;
    emit(
      state.copyWith(
        status: LoadStatus.ready,
        stale: true,
        me: me,
        room: room,
        messages: _withLocal(messages, me),
        nextCursor: messages.length >= pageSize ? messages.last.cursor : null,
      ),
    );
  }

  void _watchOffline() {
    _outboxEvents ??= _outbox?.eventsFor(roomId).listen(_onOutbox);
    _onlineChanges ??= _connectivity?.changes.listen((online) {
      if (online && state.stale && !isClosed) unawaited(load());
    });
  }

  List<ChatMessage> _withLocal(List<ChatMessage> server, UserSummary? me) {
    final delivered = {
      for (final m in server)
        if (m.clientId != null) m.clientId,
    };
    final local = <String, ChatMessage>{
      for (final queued in _queued) queued.clientId: queued.toMessage(me),
      for (final m in state.messages)
        if (m.isLocal && m.clientId != null) m.clientId!: m,
    };
    return [
      ...server,
      for (final m in local.values)
        if (!delivered.contains(m.clientId)) m,
    ]..sort(_newestFirst);
  }

  void _onOutbox(OutboxEvent event) {
    if (isClosed) return;
    switch (event) {
      case OutboxChanged(:final message):
        _updateLocal(message.toMessage(state.me));
      case OutboxDelivered(:final message):
        _upsert(_resolve(message));
      case OutboxRemoved(:final clientId):
        _removeLocal(clientId);
    }
  }

  void _updateLocal(ChatMessage local) {
    final index = state.messages.indexWhere((m) => m.isLocal && m.clientId == local.clientId);
    if (index < 0) return;
    final old = state.messages[index];
    emit(
      state.copyWith(
        messages: [...state.messages]..[index] = old.copyWith(status: local.status, sendError: local.sendError),
      ),
    );
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
      _scheduleMuteExpiry();
    } catch (_) {}
  }

  Future<bool> hideMessage(ChatMessage message, ReportReason reason, {String? note}) async {
    final extras = _extras;
    if (extras == null || !state.canModerate(message)) return false;
    try {
      await extras.hideMessage(message.id, reason, note: note);
      _applyHidden(message.id);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<RoomModerationResult?> muteMember(
    ChatMessage message,
    Duration duration,
    ReportReason reason, {
    String? note,
  }) async {
    final extras = _extras;
    final userId = message.senderId;
    if (extras == null || userId == null || !state.canModerate(message)) return null;
    try {
      final result = await extras.muteMember(roomId, userId, duration, reason, note: note, messageId: message.id);
      _setMute(userId, result.muteUntil ?? _now().add(duration));
      return result;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> escalateMessage(ChatMessage message, ReportReason reason, {String? note}) async {
    final extras = _extras;
    if (extras == null || !state.canEscalate(message)) return false;
    try {
      await extras.escalateMessage(message.id, reason, note: note);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  void _applyHidden(String messageId) {
    if (isClosed) return;
    final message = state.messages.where((m) => m.id == messageId).firstOrNull;
    final stockRoom = state.stockRoom;
    final unpin = stockRoom != null && stockRoom.pinnedMessage?.id == messageId;
    final mine = message != null && state.isMine(message);
    emit(
      state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id != messageId) m else if (mine) m.copyWith(moderationStatus: ModerationStatus.hidden),
        ],
        stockRoom: unpin && !mine ? stockRoom.copyWith(pinnedMessage: null, pinnedAt: null) : stockRoom,
      ),
    );
  }

  void _setMute(String userId, DateTime until) {
    if (isClosed) return;
    final stockRoom = state.stockRoom ?? StockRoomState(roomId: roomId, stockCode: state.room?.stockCode);
    final next = userId == state.me?.id
        ? stockRoom.copyWith(viewerMutedUntil: until.toUtc())
        : stockRoom.copyWith(mutes: {...stockRoom.mutes, userId: until.toUtc()});
    emit(state.copyWith(stockRoom: next));
    _scheduleMuteExpiry();
  }

  void _scheduleMuteExpiry() {
    _muteExpiry?.cancel();
    _muteExpiry = null;
    final now = _now();
    final until = state.mutedUntil(now);
    if (until == null) return;
    _muteExpiry = Timer(until.difference(now) + const Duration(seconds: 1), () {
      final stockRoom = state.stockRoom;
      final me = state.me?.id;
      if (isClosed || stockRoom == null || me == null) return;
      emit(
        state.copyWith(stockRoom: stockRoom.copyWith(viewerMutedUntil: null, mutes: {...stockRoom.mutes}..remove(me))),
      );
    });
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
    final me = state.me?.id;
    final moderator = next.isModerator(me);
    emit(
      state.copyWith(
        stockRoom: next.copyWith(
          waitSeconds: previous?.waitSeconds ?? 0,
          viewerMutedUntil: next.viewerMutedUntil ?? previous?.viewerMutedUntil,
          mutes: !moderator
              ? const <String, DateTime>{}
              : next.mutes.isNotEmpty
              ? next.mutes
              : previous?.mutes ?? const <String, DateTime>{},
        ),
      ),
    );
    _scheduleMuteExpiry();
    if (moderator && !(previous?.isModerator(me) ?? false)) unawaited(loadStockRoomState());
  }

  void _applyOwnMute(DateTime? until) {
    if (!state.isStockRoom) return;
    final stockRoom = state.stockRoom ?? StockRoomState(roomId: roomId, stockCode: state.room?.stockCode);
    emit(state.copyWith(stockRoom: stockRoom.copyWith(viewerMutedUntil: until?.toUtc())));
    _scheduleMuteExpiry();
    unawaited(loadStockRoomState());
  }

  void _connect(UserSummary me) {
    final connection = _chat.connectRoom(roomId, me: me);
    _connection = connection;
    _events = connection.events.listen(_onEvent, onError: (Object _) {});
    _resumes ??= _connectivity?.resumes.listen((_) => unawaited(_fillGap()));
    _gapSchedule.start();
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
        final joined = status == RealtimeStatus.connected && state.connection != RealtimeStatus.connected;
        final reconnected = joined && _wasConnected;
        if (status == RealtimeStatus.connected) {
          _wasConnected = true;
          _connectivity?.report(reachable: true);
        }
        emit(state.copyWith(connection: status));
        if (reconnected) {
          _gapSchedule.reconnected();
          unawaited(_resendFailed());
        } else if (joined) {
          unawaited(_fillGap());
        }
      case ReactionChanged():
        _applyReactionEvent(event);
      case StockRoomStateChanged(:final state):
        _applyStockRoomState(state);
      case MessageHidden(:final messageId):
        _applyHidden(messageId);
      case OwnRoomMuteChanged(:final mutedUntil):
        _applyOwnMute(mutedUntil);
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

  Future<void> _fillGap() {
    final running = _gapRun;
    if (running != null) {
      _gapAgain = true;
      return running;
    }
    final run = _catchUp().whenComplete(() {
      _gapRun = null;
      if (_gapAgain && !isClosed) {
        _gapAgain = false;
        unawaited(_fillGap());
      }
    });
    _gapRun = run;
    return run;
  }

  static GapHorizon _newestOf(List<ChatMessage> messages) {
    var newest = GapHorizon.origin;
    for (final message in messages) {
      if (!message.isLocal) newest = newest.later(GapHorizon.of(message));
    }
    return newest;
  }

  Set<String> _knownIds() => {
    for (final m in state.messages)
      if (!m.isLocal) m.id,
  };

  Future<void> _catchUp() async {
    final horizon = _horizon;
    if (isClosed || state.status != LoadStatus.ready || horizon == null) return;
    final oldest = state.messages.where((m) => !m.isLocal).lastOrNull;
    try {
      final result = await _gapFill.run(
        horizon,
        floor: oldest == null ? null : GapHorizon.of(oldest),
        known: _knownIds,
      );
      if (isClosed) return;
      switch (result) {
        case GapTooLong():
          await _reloadLatest();
        case GapFilled(:final messages, horizon: final reached):
          _upsertAll(messages);
          _horizon = reached.later(_horizon);
      }
    } catch (_) {}
  }

  Future<void> _reloadLatest() async {
    final page = await _chat.getMessages(roomId, limit: pageSize);
    if (isClosed) return;
    _horizon = _newestOf(page.items).later(_horizon);
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
    if (state.mutedUntil(_now()) != null) return _fail(roomMutedError);
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

  bool get canSendStockCards => _extras != null && state.room != null && state.room!.type != RoomType.support;

  Future<void> sendStockCards(Iterable<String> codes) async {
    final me = state.me;
    final clean = normalizeStockCardCodes(codes);
    if (!canSendStockCards || me == null || clean.isEmpty) return;
    final clientId = _uuid.v4();
    final local = ChatMessage(
      id: 'local-$clientId',
      roomId: roomId,
      senderId: me.id,
      sender: me,
      body: '',
      stockCodes: clean,
      clientId: clientId,
      createdAt: DateTime.now().toUtc(),
      status: MessageStatus.sending,
    );
    emit(state.copyWith(messages: [local, ...state.messages]));
    await _deliver(local);
  }

  Future<void> _resendFailed() async {
    unawaited(_outbox?.flush(force: true));
    for (final message in [...state.messages.reversed]) {
      if (message.isLocal && message.status == MessageStatus.failed && _queueable(message) == null) {
        await _retry(message, askConsent: false);
      }
    }
  }

  OutboxMessage? _queueable(ChatMessage message) => _outbox == null ? null : OutboxMessage.fromLocal(message);

  Future<void> retry(ChatMessage message) => _retry(message, askConsent: true);

  Future<void> _retry(ChatMessage message, {required bool askConsent}) async {
    if (message.status != MessageStatus.failed) return;
    _setStatus(message.clientId, MessageStatus.sending);
    await _deliver(message, askConsent: askConsent);
  }

  Future<void> discard(ChatMessage message) async {
    final clientId = message.clientId;
    if (!message.isLocal || clientId == null || message.status == MessageStatus.sending) return;
    _removeLocal(clientId);
    await _outbox?.discard(clientId);
  }

  Future<void> _deliver(ChatMessage local, {bool askConsent = true}) async {
    final gate = askConsent && state.room?.type != RoomType.support ? _consent : null;
    final outbox = _outbox;
    final queued = _queueable(local);
    if (outbox != null && queued != null) {
      final result = await outbox.send(queued, guard: gate == null ? null : gate.run);
      switch (result) {
        case OutboxSent(:final message):
          _upsert(message);
          _afterSent(local);
        case OutboxQueued():
          _setStatus(local.clientId, MessageStatus.pending);
        case OutboxFailed(:final error):
          _sendFailed(local, error, keep: true);
        case OutboxBusy():
          return;
      }
      return;
    }
    final extras = _extras;
    try {
      final sent = await gate.guard(
        () => local.stockCodes.isNotEmpty && extras != null
            ? extras.sendStockCards(roomId, local.stockCodes, clientId: local.clientId!, body: local.body)
            : _chat.sendMessage(
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
      _sendFailed(local, mapError(e), keep: false);
    }
  }

  void _sendFailed(ChatMessage local, CommunityException mapped, {required bool keep}) {
    CommunityLoggers.chat.event(
      Level.SEVERE,
      'Failed to send message',
      fields: {'roomId': roomId, 'clientId': local.clientId, 'kind': mapped.kind, 'code': mapped.code},
    );
    if (mapped.kind == CommunityErrorKind.contentBlocked && !keep) {
      _removeLocal(local.clientId);
    } else {
      _setStatus(local.clientId, MessageStatus.failed, error: mapped);
    }
    if (mapped.code == 'slow_mode' && !isClosed) {
      final wait = mapped.retryAfter ?? Duration(seconds: state.stockRoom?.slowModeSeconds ?? 0);
      if (wait > Duration.zero) emit(state.copyWith(cooldownUntil: _now().add(wait)));
    }
    if (mapped.code == 'room_muted' && !isClosed) {
      final until = DateTime.tryParse(mapped.message ?? '');
      final me = state.me?.id;
      if (until != null && me != null) _setMute(me, until);
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
    _fail(mapped);
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

  void _setStatus(String? clientId, MessageStatus status, {CommunityException? error}) {
    if (isClosed || clientId == null) return;
    emit(
      state.copyWith(
        messages: [
          for (final m in state.messages)
            m.clientId == clientId && m.isLocal ? m.copyWith(status: status, sendError: error) : m,
        ],
      ),
    );
  }

  Future<void> sendImage(Uint8List bytes, String mimeType) =>
      _sendAttachment(() => _media.uploadChatImage(roomId, bytes, mimeType: mimeType));

  Future<void> sendDocument(Uint8List bytes, String name) =>
      _sendAttachment(() => _media.uploadSupportDocument(roomId, bytes, name: name));

  Future<void> _sendAttachment(Future<Attachment> Function() upload) async {
    if (_connectivity?.isOnline == false) return _fail(attachmentOfflineError);
    emit(state.copyWith(uploading: true));
    try {
      final attachment = await upload();
      if (!isClosed) emit(state.copyWith(uploading: false));
      await send('', attachments: [attachment]);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(uploading: false));
      final mapped = mapError(e);
      _fail(mapped.kind == CommunityErrorKind.network && _outbox != null ? attachmentOfflineError : e);
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
    _muteExpiry?.cancel();
    _gapSchedule.dispose();
    await _resumes?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    if (_typingSent) unawaited(_connection?.sendTyping(isTyping: false));
    await _events?.cancel();
    await _outboxEvents?.cancel();
    await _onlineChanges?.cancel();
    await _connection?.close();
    return super.close();
  }
}
