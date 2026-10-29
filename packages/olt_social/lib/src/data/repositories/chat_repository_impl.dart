import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/chat.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/realtime_gateway.dart';
import '../datasources/social_remote_data_source.dart';
import '../models/chat_models.dart';
import '../models/post_models.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._api, [this._realtime]);

  final SocialRemoteDataSource _api;
  final RealtimeGateway? _realtime;

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
  Future<void> markRoomRead(String roomId) => _api.rpcValue('mark_room_read', {'p_room_id': roomId});

  @override
  Future<Map<String, int>> unreadCounts() async {
    final rows = await _api.rpcRows('get_unread_counts');
    return {for (final row in rows) row['room_id'] as String: (row['unread_count'] as num).toInt()};
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
  Future<void> leaveRoom(String roomId) => _api.rpcValue('leave_room', {'p_room_id': roomId});

  @override
  Future<void> setMuted(String roomId, {required bool muted}) async {
    final me = await _api.requireUserId();
    await _api.update('chat_members', {'muted': muted}, {'room_id': roomId, 'user_id': me});
  }

  @override
  Future<List<RoomMember>> getMembers(String roomId) async {
    final rows = await _api.rpcRows('get_room_members', {'p_room_id': roomId});
    return [for (final row in rows) RoomMemberModel.fromJson(row).toEntity()];
  }

  @override
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me}) {
    final realtime = _realtime;
    if (realtime == null) return _NoopRoomConnection();
    return _SupabaseRoomConnection(realtime, roomId, me);
  }

  @override
  Stream<RoomActivity> watchRoomActivity() {
    final realtime = _realtime;
    if (realtime == null) return const Stream.empty();
    // RLS membatasi event hanya untuk room tempat user menjadi anggota.
    return realtime.tableChanges(table: 'messages', event: PostgresChangeEvent.insert).map((p) {
      final row = MessageRowModel.fromJson(p.newRecord);
      return RoomActivity(
        roomId: row.roomId,
        senderId: row.senderId,
        preview: row.body.isEmpty ? '' : row.body,
        createdAt: row.createdAt,
      );
    });
  }

  @override
  Stream<Set<String>> watchOnlineUsers({required UserSummary me}) {
    final realtime = _realtime;
    if (realtime == null) return const Stream.empty();
    RealtimeChannel? channel;
    late final StreamController<Set<String>> controller;
    controller = StreamController<Set<String>>(
      onListen: () {
        channel = realtime.privateChannel('online', presenceKey: me.id)
          ..onPresenceSync((_) {
            final ids = {for (final s in channel!.presenceState()) s.key};
            if (!controller.isClosed) controller.add(ids);
          })
          ..subscribe((status, _) async {
            if (status == RealtimeSubscribeStatus.subscribed) {
              await channel?.track({'user_id': me.id, 'online_at': DateTime.now().toUtc().toIso8601String()});
            }
          });
      },
      onCancel: () async {
        final ch = channel;
        channel = null;
        if (ch != null) await realtime.remove(ch);
        await controller.close();
      },
    );
    return controller.stream;
  }
}

/// Koneksi realtime satu room:
/// * postgres_changes tabel messages (RLS: hanya anggota) -> [MessageUpserted]
/// * channel private `room:<id>` (otorisasi realtime.messages) -> typing & read receipt
class _SupabaseRoomConnection implements ChatRoomConnection {
  _SupabaseRoomConnection(this._realtime, this.roomId, this.me) {
    _controller = StreamController<ChatRoomEvent>.broadcast(onListen: _open);
  }

  final RealtimeGateway _realtime;
  final String roomId;
  final UserSummary me;
  late final StreamController<ChatRoomEvent> _controller;
  StreamSubscription<PostgresChangePayload>? _messages;
  RealtimeChannel? _channel;
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

    _channel = _realtime.privateChannel('room:$roomId')
      ..onBroadcast(event: 'typing', callback: (payload) {
        final data = _unwrap(payload);
        final userId = data['user_id'] as String?;
        if (userId == null || userId == me.id) return;
        _emit(TypingChanged(
          UserSummary(
            id: userId,
            username: data['username'] as String? ?? '',
            displayName: data['display_name'] as String?,
          ),
          isTyping: data['typing'] == true,
        ));
      })
      ..onBroadcast(event: 'read', callback: (payload) {
        final data = _unwrap(payload);
        final userId = data['user_id'] as String?;
        final at = DateTime.tryParse(data['last_read_at'] as String? ?? '');
        if (userId == null || at == null || userId == me.id) return;
        _emit(ReadReceipt(userId, at));
      })
      ..subscribe();
  }

  /// Payload broadcast bisa berada di root atau di bawah key `payload`.
  static Map<String, dynamic> _unwrap(Map<String, dynamic> payload) {
    final inner = payload['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : payload;
  }

  @override
  Future<void> sendTyping({required bool isTyping}) async {
    await _channel?.sendBroadcastMessage(event: 'typing', payload: {
      'user_id': me.id,
      'username': me.username,
      'display_name': me.displayName,
      'typing': isTyping,
    });
  }

  @override
  Future<void> sendReadReceipt(DateTime lastReadAt) async {
    await _channel?.sendBroadcastMessage(event: 'read', payload: {
      'user_id': me.id,
      'last_read_at': lastReadAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> close() async {
    await _messages?.cancel();
    _messages = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) await _realtime.remove(ch);
    await _controller.close();
  }
}

class _NoopRoomConnection implements ChatRoomConnection {
  @override
  Stream<ChatRoomEvent> get events => const Stream.empty();

  @override
  Future<void> sendTyping({required bool isTyping}) async {}

  @override
  Future<void> sendReadReceipt(DateTime lastReadAt) async {}

  @override
  Future<void> close() async {}
}
