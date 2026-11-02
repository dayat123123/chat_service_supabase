import 'package:rendezvous_community/src/core/paging/paged.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/shared/domain/entities/attachment.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

abstract interface class ChatRepository {
  Future<Paged<ChatRoom>> getRooms({String? cursor, int limit = 30});

  Future<ChatRoom?> getRoom(String roomId);

  Future<Paged<ChatMessage>> getMessages(String roomId, {String? cursor, int limit = 30});

  Future<Paged<ChatMessage>> getMessagesAfter(String roomId, String cursor, {int limit = 100});

  Future<ChatMessage> sendMessage(
    String roomId, {
    required String body,
    required String clientId,
    String? replyToId,
    List<Attachment> attachments = const [],
  });

  Future<void> deleteMessage(String messageId);

  Future<void> markRoomRead(String roomId);

  Future<int> markDelivered({List<String>? roomIds});

  Future<Map<String, int>> unreadCounts();

  Future<int> unreadChatCount();

  Stream<void> watchUnreadChanges();

  Future<String> getOrCreateDirectRoom(String otherUserId);

  Future<String> createGroupRoom(String name, List<String> memberIds);

  Future<String> joinStockRoom(String stockCode);

  Future<void> leaveRoom(String roomId);

  Future<void> setMuted(String roomId, {required bool muted});

  Future<List<RoomMember>> getMembers(String roomId);

  ChatRoomConnection connectRoom(String roomId, {required UserSummary me});

  Stream<RoomActivity> watchRoomActivity();

  Stream<RoomSignal> watchRoomSignals(Set<String> roomIds, {required UserSummary me});
}

abstract interface class ChatRoomConnection {
  Stream<ChatRoomEvent> get events;

  Future<void> sendTyping({required bool isTyping});

  Future<void> close();
}
