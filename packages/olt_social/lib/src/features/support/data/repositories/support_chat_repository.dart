import 'dart:async';

import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/core/network/realtime_gateway.dart';
import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/core/paging/paged.dart';
import 'package:olt_social/src/features/chat/data/models/chat_models.dart';
import 'package:olt_social/src/features/chat/data/realtime/room_channel_hub.dart';
import 'package:olt_social/src/features/chat/data/realtime/room_connection.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_events.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/shared/data/models/attachment_model.dart';
import 'package:olt_social/src/shared/domain/entities/attachment.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

class SupportChatRepository implements ChatRepository {
  SupportChatRepository(this._cs, {RealtimeGateway? realtime, required this._rooms, this._ticketOf})
    : _realtime = realtime,
      _hub = realtime == null ? null : RoomChannelHub(realtime);

  final SocialRemoteDataSource _cs;
  final RealtimeGateway? _realtime;
  final RoomChannelHub? _hub;
  final Future<List<ChatRoom>> Function() _rooms;
  final String? Function(String roomId)? _ticketOf;
  final _unreadChanges = StreamController<void>.broadcast();

  static const _locked = OltSocialException(OltSocialErrorKind.forbidden, code: 'support_message_locked');

  @override
  Future<List<ChatRoom>> getRooms() => _rooms();

  @override
  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30}) async {
    final rows = await _cs.rpcRows('get_messages', {'p_room_id': roomId, 'p_cursor': cursor, 'p_limit': limit});
    final items = [for (final row in rows) ChatMessageModel.fromJson(row).toEntity()];
    return Paged(items, nextCursor: items.length < limit ? null : items.last.cursor);
  }

  @override
  Future<List<ChatMessage>> getMessagesAfter(String roomId, String cursor) async {
    final rows = await _cs.rpcRows('get_messages', {'p_room_id': roomId, 'p_after': cursor, 'p_limit': 100});
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
    final files = [for (final a in attachments) AttachmentModel.fromEntity(a).toJson()];
    final ticketOf = _ticketOf;
    if (ticketOf == null) {
      final rows = await _cs.rpcRows('send_message', {
        'p_room_id': roomId,
        'p_body': body,
        'p_client_id': clientId,
        'p_reply_to_id': replyToId,
        'p_attachments': files,
      });
      return ChatMessageModel.fromJson(rows.first).toEntity();
    }
    final ticketId = ticketOf(roomId);
    if (ticketId == null) {
      throw const OltSocialException(OltSocialErrorKind.forbidden, code: 'ticket_not_active');
    }
    final result = (await _cs.rpcValue('agent_send_message', {
      'p_ticket_id': ticketId,
      'p_body': body,
      'p_client_id': clientId,
      'p_reply_to_id': replyToId,
      'p_attachments': files,
    }))! as Map<String, dynamic>;
    if (result['status'] != 'sent') {
      throw OltSocialException(
        OltSocialErrorKind.contentBlocked,
        code: result['code'] as String?,
        message: result['message'] as String?,
      );
    }
    return ChatMessageModel.fromJson(result['message'] as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> deleteMessage(String messageId) => Future.error(_locked);

  @override
  Future<void> markRoomRead(String roomId) async {
    await _cs.rpcValue('mark_read', {'p_room_id': roomId});
    if (!_unreadChanges.isClosed) _unreadChanges.add(null);
  }

  @override
  Future<int> markDelivered({List<String>? roomIds}) async => 0;

  @override
  Future<Map<String, int>> unreadCounts() async => const {};

  @override
  Future<int> unreadChatCount() async => 0;

  @override
  Stream<void> watchUnreadChanges() => _unreadChanges.stream;

  @override
  Future<String> getOrCreateDirectRoom(String otherUserId) => Future.error(_locked);

  @override
  Future<String> createGroupRoom(String name, List<String> memberIds) => Future.error(_locked);

  @override
  Future<String> joinStockRoom(String stockCode) => Future.error(_locked);

  @override
  Future<void> leaveRoom(String roomId) => Future.error(_locked);

  @override
  Future<void> setMuted(String roomId, {required bool muted}) => Future.error(_locked);

  @override
  Future<List<RoomMember>> getMembers(String roomId) async {
    final rows = (await _cs.rpcValue('room_members', {'p_room_id': roomId})) as List<Object?>? ?? const [];
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        _officialIfStaff(RoomMemberModel.fromJson(row).toEntity(), row['is_staff'] == true),
    ];
  }

  RoomMember _officialIfStaff(RoomMember member, bool staff) =>
      staff ? member.copyWith(user: member.user.copyWith(isVerified: true)) : member;

  @override
  ChatRoomConnection connectRoom(String roomId, {required UserSummary me}) {
    final realtime = _realtime;
    final hub = _hub;
    if (realtime == null || hub == null) return NoopRoomConnection();
    return SupabaseRoomConnection(realtime, hub, roomId, me);
  }

  @override
  Stream<RoomActivity> watchRoomActivity() => const Stream.empty();

  @override
  Stream<RoomSignal> watchRoomSignals(Set<String> roomIds, {required UserSummary me}) {
    final hub = _hub;
    if (hub == null || roomIds.isEmpty) return const Stream.empty();
    return hub.watchAll(roomIds, me);
  }
}
