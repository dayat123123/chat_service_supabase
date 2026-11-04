import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';

class MessageIdPage {
  const MessageIdPage(this.ids, {this.last, this.hasMore = false});

  final List<String> ids;
  final String? last;
  final bool hasMore;
}

abstract interface class MessageIndexRepository {
  Future<MessageIdPage> getMessageIdsAfter(String roomId, String cursor, {int limit = 1000});

  Future<List<ChatMessage>> getMessagesByIds(String roomId, List<String> ids);
}
