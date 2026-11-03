import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_room_state.dart';

abstract interface class ChatExtrasRepository {
  Future<List<MessageReaction>> react(String messageId, String? emoji);

  Future<ChatMessage> sharePost(String roomId, String postId, {String? body, String? clientId});

  Future<StockRoomState> stockRoomState(String stockCode);
}
