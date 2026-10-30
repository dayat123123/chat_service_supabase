import 'dart:async';

import 'package:olt_social/src/core/network/realtime_gateway.dart';
import 'package:olt_social/src/core/network/shared_stream.dart';
import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/core/paging/paged.dart';
import 'package:olt_social/src/features/chat/data/models/chat_models.dart';
import 'package:olt_social/src/features/chat/data/realtime/room_channel_hub.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/shared/data/models/attachment_model.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._api, [this._realtime]) : _hub = _realtime == null ? null : RoomChannelHub(_realtime);

  final SocialRemoteDataSource _api;
  final RealtimeGateway? _realtime;
  final RoomChannelHub? _hub;
  late final SharedStream<RoomActivity> _activity = SharedStream(_createActivityStream);
  final _unreadChanges = StreamController<void>.broadcast();

  @override
  Future<List<ChatRoom>> getRooms() async {
    final rows = await _api.rpcRows('get_my_rooms');
    return [for (final row in rows) RoomSummaryModel.fromJson(row).toEntity()];
  }

  @override
  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30}) async {
    final rows = await _api.rpcRows('get_messages', {'p_room_id': roomId, 'p_cursor': cursor, 'p_limit': limit});
    final items = [for (final row in rows) ChatMessageModel.fromJson(row).toEntity()];
    return Paged(items, nextCursor: items.length < limit ? null : items.last.cursor);
  }

  @override
  Future<List<ChatMessage>> getMessagesAfter(String roomId, String cursor) async {
    final rows = await _api.rpcRows('get_messages', {'p_room_id': roomId, 'p_after': cursor, 'p_limit': 100});
    return [for (final row in rows) ChatMessageModel.fromJson(row).toEntity()];
  }

  @override
  Future<ChatMessage> sendMessage(
    String roomId, {
    required String body,
    required String clientId,
    String? replyToId,
    List<Attachment> attachments = const [],
  }) async {
    final rows = await _api.rpcRows('send_message', {
      'p_room_id': roomId,
      'p_body': body,
      'p_client_id': clientId,
      'p_reply_to_id': replyToId,
      'p_attachments': [for (final a in attachments) AttachmentModel.fromEntity(a).toJson()],
    });
    return ChatMessageModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<void> deleteMessage(String messageId) => _api.rpcValue('delete_message', {'p_message_id': messageId});

  @override
  Future<void> markRoomRead(String roomId) async {
    await _api.rpcValue('mark_room_read', {'p_room_id': roomId});
    _unreadChanged();
  }

  @override
  Future<int> markDelivered({List<String>? roomIds}) async =>
      ((await _api.rpcValue('mark_rooms_delivered', {'p_room_ids': roomIds})) as num?)?.toInt() ?? 0;

  @override
  Future<Map<String, int>> unreadCounts() async {
    final rows = await _api.rpcRows('get_unread_counts');
    return {for (final row in rows) row['room_id'] as String: (row['unread_count'] as num).toInt()};
  }

  @override
  Future<int> unreadChatCount() async =>
      ((await _api.rpcValue('get_unread_chat_count')) as num?)?.toInt() ?? 0;

  @override
  Stream<void> watchUnreadChanges() => _unreadChanges.stream;

  void _unreadChanged() {
    if (!_unreadChanges.isClosed) _unreadChanges.add(null);
  }

  @override
  Future<String> getOrCreateDirectRoom(String otherUserId) async =>
      (await _api.rpcValue('get_or_create_direct_room', {'p_other_user_id': otherUserId}))! as String;

  @override
  Future<String> createGroupRoom(String name, List<String> memberIds) async =>
      (await _api.rpcValue('create_group_room', {'p_name': name, 'p_member_ids': memberIds}))! as String;

  @override
  Future<String> joinStockRoom(String stockCode) async =>
      (await _api.rpcValue('join_stock_room', {'p_stock_code': stockCode}))! as String;

  @override
  Future<void> leaveRoom(String roomId) async {
    await _api.rpcValue('leave_room', {'p_room_id': roomId});
    _unreadChanged();
  }

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {
    final me = await _api.requireUserId();
    await _api.update('chat_members', {'muted': muted}, {'room_id': roomId, 'user_id': me});
    _unreadChanged();
  }

  @override
  Future<List<RoomMember>> getMembers(String roomId) async {
    final rows = await _api.rpcRows('get_room_members', {'p_room_id': roomId});
    return [for (final row in rows) RoomMemberModel.fromJson(row).toEntity()];
  }

  @override
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me}) {
    final realtime = _realtime;
    final hub = _hub;
    if (realtime == null || hub == null) return _NoopRoomConnection();
    return _SupabaseRoomConnection(realtime, hub, roomId, me);
  }

  @override
  Stream<RoomActivity> watchRoomActivity() => _realtime == null ? const Stream.empty() : _activity.stream;

  @override
  Stream<RoomSignal> watchRoomSignals(Set<String> roomIds, {required UserSummary me}) {
    final hub = _hub;
    if (hub == null || roomIds.isEmpty) return const Stream.empty();
    return hub.watchAll(roomIds, me);
  }

  Future<void> dispose() async {
    await _activity.close();
    await _unreadChanges.close();
  }

  Stream<RoomActivity> _createActivityStream() =>
      _realtime!.tableChanges(table: 'messages', event: PostgresChangeEvent.insert).map((p) {
        final row = MessageRowModel.fromJson(p.newRecord);
        return RoomActivity(roomId: row.roomId, senderId: row.senderId, preview: row.body, createdAt: row.createdAt);
      });
}

class _SupabaseRoomConnection implements ChatRoomConnection {
  _SupabaseRoomConnection(this._realtime, this._hub, this.roomId, this.me) {
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

class _NoopRoomConnection implements ChatRoomConnection {
  @override
  Stream<ChatRoomEvent> get events => const Stream.empty();

  @override
  Future<void> sendTyping({required bool isTyping}) async {}

  @override
  Future<void> close() async {}
}
