import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/network/json_values.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_room_state.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_extras_repository.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ChatExtrasRepositoryImpl implements ChatExtrasRepository {
  ChatExtrasRepositoryImpl(this._api);

  final SocialRemoteDataSource _api;

  @override
  Future<List<MessageReaction>> react(String messageId, String? emoji) async {
    final json = jsonMap(await _api.rpcValue('react_to_message', {'p_message_id': messageId, 'p_emoji': emoji}));
    return reactionsFromJson(json['reactions']);
  }

  @override
  Future<ChatMessage> sharePost(String roomId, String postId, {String? body, String? clientId}) async {
    final text = body?.trim();
    final rows = await _api.rpcRows('share_post_to_chat', {
      'p_room_id': roomId,
      'p_post_id': postId,
      'p_body': text == null || text.isEmpty ? null : text,
      'p_client_id': clientId ?? _uuid.v4(),
    });
    if (rows.isEmpty) {
      throw const CommunityException(CommunityErrorKind.unknown, message: 'share_post_to_chat returned no rows');
    }
    return ChatMessageModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<ChatMessage> sendStockCards(
    String roomId,
    List<String> codes, {
    required String clientId,
    String? body,
  }) async {
    final rows = await _api.rpcRows('send_message', {
      'p_room_id': roomId,
      'p_body': body?.trim() ?? '',
      'p_client_id': clientId,
      'p_reply_to_id': null,
      'p_attachments': [
        for (final code in codes) {'type': 'stock', 'code': code},
      ],
    });
    if (rows.isEmpty) {
      throw const CommunityException(CommunityErrorKind.unknown, message: 'send_message returned no rows');
    }
    return ChatMessageModel.fromJson(rows.first).toEntity();
  }

  @override
  Future<StockRoomState> stockRoomState(String stockCode) async =>
      parseStockRoomState(jsonMap(await _api.rpcValue('get_stock_room_state', {'p_code': stockCode.toUpperCase()})));

  @override
  Future<RoomModerationResult> hideMessage(String messageId, ReportReason reason, {String? note}) async =>
      parseRoomModerationResult(
        jsonMap(
          await _api.rpcValue('room_mod_hide_message', {
            'p_message_id': messageId,
            'p_reason': reason.wireName,
            'p_note': _note(note),
          }),
        ),
      );

  @override
  Future<RoomModerationResult> muteMember(
    String roomId,
    String userId,
    Duration duration,
    ReportReason reason, {
    String? note,
    String? messageId,
  }) async => parseRoomModerationResult(
    jsonMap(
      await _api.rpcValue('room_mod_mute_user', {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_minutes': duration.inMinutes,
        'p_reason': reason.wireName,
        'p_note': _note(note),
        'p_message_id': messageId,
      }),
    ),
  );

  @override
  Future<RoomModerationResult> escalateMessage(String messageId, ReportReason reason, {String? note}) async =>
      parseRoomModerationResult(
        jsonMap(
          await _api.rpcValue('room_mod_escalate', {
            'p_message_id': messageId,
            'p_reason': reason.wireName,
            'p_note': _note(note),
          }),
        ),
      );

  static String? _note(String? note) {
    final text = note?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
