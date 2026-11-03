import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/core/network/community_connectivity.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_cache_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'chat_list_cubit.freezed.dart';

@freezed
abstract class ChatListState with _$ChatListState {
  const factory ChatListState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<ChatRoom>[]) List<ChatRoom> rooms,
    String? nextCursor,
    @Default(false) bool loadingMore,
    @Default(<String, Set<String>>{}) Map<String, Set<String>> presence,
    @Default(<String, Map<String, UserSummary>>{}) Map<String, Map<String, UserSummary>> typing,
    UserSummary? me,
    Object? error,
    @Default(false) bool stale,
  }) = _ChatListState;

  const ChatListState._();

  bool isOnline(ChatRoom room) {
    final other = room.otherUser;
    return other != null && (presence[room.id]?.contains(other.id) ?? false);
  }

  List<UserSummary> typingIn(String roomId) => typing[roomId]?.values.toList() ?? const [];
}

class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit({
    required this._chat,
    required this._me,
    this.pageSize = 30,
    this.maxWatchedRooms = 30,
    this.typingTimeout = const Duration(seconds: 6),
    this._cache,
    this._connectivity,
  }) : super(const ChatListState());

  final ChatRepository _chat;
  final Future<UserSummary> Function() _me;
  final ChatCacheRepository? _cache;
  final CommunityConnectivity? _connectivity;
  StreamSubscription<bool>? _onlineChanges;
  final int pageSize;
  final int maxWatchedRooms;
  final Duration typingTimeout;
  StreamSubscription<RoomActivity>? _activity;
  StreamSubscription<RoomSignal>? _signals;
  Set<String> _watched = const {};
  final _channels = <String, RealtimeStatus>{};
  final _typingTimers = <String, Timer>{};
  Timer? _debounce;

  Future<void> load() async {
    if (!(state.status == LoadStatus.ready && state.stale)) {
      emit(state.copyWith(status: LoadStatus.loading, error: null));
      _onlineChanges ??= _connectivity?.changes.listen((online) {
        if (online && state.stale && !isClosed) unawaited(load());
      });
      await _showCached();
    }
    try {
      final me = await _me();
      final page = await _chat.getRooms(limit: pageSize);
      if (isClosed) return;
      emit(
        state.copyWith(status: LoadStatus.ready, rooms: page.items, nextCursor: page.nextCursor, me: me, stale: false),
      );
      _activity ??= _chat.watchRoomActivity().listen(_onActivity, onError: (Object _) {});
      _watchRooms();
    } catch (e) {
      if (isClosed || (state.status == LoadStatus.ready && state.stale)) return;
      emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> _showCached() async {
    final cache = _cache;
    if (cache == null) return;
    final rooms = await cache.cachedRooms();
    if (rooms.isEmpty || isClosed || state.status == LoadStatus.ready) return;
    final me = await cache.cachedUser();
    if (isClosed || state.status == LoadStatus.ready) return;
    emit(state.copyWith(status: LoadStatus.ready, rooms: rooms, me: me, nextCursor: null, stale: true));
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || state.status != LoadStatus.ready) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _chat.getRooms(cursor: cursor, limit: pageSize);
      if (isClosed) return;
      final known = {for (final r in state.rooms) r.id};
      emit(
        state.copyWith(
          rooms: [...state.rooms, ...page.items.where((r) => !known.contains(r.id))],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
      _watchRooms();
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    try {
      final fresh = await _chat.getRooms(limit: max(pageSize, state.rooms.length));
      if (isClosed) return;
      final ids = {for (final r in fresh.items) r.id};
      final boundary = fresh.items.lastOrNull;
      final beyond = fresh.hasMore && boundary != null
          ? [
              for (final r in state.rooms)
                if (!ids.contains(r.id) && r.compareListOrder(boundary) > 0) r,
            ]
          : const <ChatRoom>[];
      emit(
        state.copyWith(
          rooms: [...fresh.items, ...beyond],
          nextCursor: beyond.isEmpty ? fresh.nextCursor : state.nextCursor,
          status: LoadStatus.ready,
          stale: false,
        ),
      );
      _watchRooms();
    } catch (_) {}
  }

  void markOpened(String roomId) =>
      emit(state.copyWith(rooms: [for (final r in state.rooms) r.id == roomId ? r.copyWith(unreadCount: 0) : r]));

  void _onActivity(RoomActivity activity) {
    final sender = activity.senderId;
    if (sender != null) _removeTyping(activity.roomId, sender);
    _scheduleRefresh();
  }

  void _watchRooms() {
    final me = state.me;
    if (me == null) return;
    final ids = {for (final r in state.rooms.where((r) => r.tracksReceipts).take(maxWatchedRooms)) r.id};
    if (ids.length == _watched.length && ids.containsAll(_watched)) return;
    _watched = ids;
    final previous = _signals;
    _signals = _chat.watchRoomSignals(ids, me: me).listen(_onSignal, onError: (Object _) {});
    unawaited(previous?.cancel());
  }

  void _onSignal(RoomSignal signal) {
    if (isClosed) return;
    switch (signal) {
      case RoomTyping(:final roomId, :final user, :final isTyping):
        isTyping ? _addTyping(roomId, user) : _removeTyping(roomId, user.id);
      case RoomReceipt(:final roomId, :final receipt):
        _applyReceipt(roomId, receipt);
      case RoomPresence(:final roomId, :final userIds):
        emit(state.copyWith(presence: {...state.presence, roomId: userIds}));
      case RoomConnection(:final roomId, :final status):
        final previous = _channels[roomId];
        _channels[roomId] = status;
        if (status == RealtimeStatus.connected && previous != null && previous != status) _scheduleRefresh();
      case RoomReaction() || RoomStateSignal() || RoomMessageHidden():
        return;
    }
  }

  void _applyReceipt(String roomId, MemberReceipt receipt) {
    final room = state.rooms.where((r) => r.id == roomId).firstOrNull;
    final sentAt = room?.lastMessageAt;
    if (room == null || sentAt == null || room.lastMessageSenderId != state.me?.id) return;
    if (room.type != RoomType.direct) return _scheduleRefresh();
    final status = receiptStatus(sentAt, [receipt]);
    if (status.index <= (room.lastMessageStatus?.index ?? 0)) return;
    emit(
      state.copyWith(rooms: [for (final r in state.rooms) r.id == roomId ? r.copyWith(lastMessageStatus: status) : r]),
    );
  }

  void _addTyping(String roomId, UserSummary user) {
    final key = '$roomId/${user.id}';
    _typingTimers[key]?.cancel();
    _typingTimers[key] = Timer(typingTimeout, () => _removeTyping(roomId, user.id));
    emit(
      state.copyWith(
        typing: {
          ...state.typing,
          roomId: {...?state.typing[roomId], user.id: user},
        },
      ),
    );
  }

  void _removeTyping(String roomId, String userId) {
    final users = state.typing[roomId];
    if (isClosed || users == null || !users.containsKey(userId)) return;
    _typingTimers.remove('$roomId/$userId')?.cancel();
    final rest = {...users}..remove(userId);
    emit(state.copyWith(typing: {...state.typing, roomId: rest}..removeWhere((_, v) => v.isEmpty)));
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    await _activity?.cancel();
    await _signals?.cancel();
    await _onlineChanges?.cancel();
    return super.close();
  }
}
