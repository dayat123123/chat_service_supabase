import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

abstract interface class ChatCacheRepository {
  Future<UserSummary?> cachedUser();

  Future<List<ChatRoom>> cachedRooms();

  Future<List<ChatMessage>> cachedMessages(String roomId);
}
