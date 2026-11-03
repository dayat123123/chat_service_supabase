import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_room_state.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

sealed class RoomSignal {
  const RoomSignal(this.roomId);

  final String roomId;
}

class RoomTyping extends RoomSignal {
  const RoomTyping(super.roomId, this.user, {required this.isTyping});

  final UserSummary user;
  final bool isTyping;
}

class RoomReceipt extends RoomSignal {
  const RoomReceipt(super.roomId, this.receipt);

  final MemberReceipt receipt;
}

class RoomPresence extends RoomSignal {
  const RoomPresence(super.roomId, this.userIds);

  final Set<String> userIds;
}

class RoomConnection extends RoomSignal {
  const RoomConnection(super.roomId, this.status);

  final RealtimeStatus status;
}

class RoomReaction extends RoomSignal {
  const RoomReaction(super.roomId, {required this.messageId, required this.userId, this.emoji, required this.counts});

  final String messageId;
  final String userId;
  final String? emoji;
  final List<MessageReaction> counts;
}

class RoomStateSignal extends RoomSignal {
  const RoomStateSignal(super.roomId, this.state);

  final StockRoomState state;
}

class RoomMessageHidden extends RoomSignal {
  const RoomMessageHidden(super.roomId, this.messageId, {this.userId});

  final String messageId;
  final String? userId;
}

sealed class ChatRoomEvent {
  const ChatRoomEvent();
}

class MessageUpserted extends ChatRoomEvent {
  const MessageUpserted(this.message);

  final ChatMessage message;
}

class TypingChanged extends ChatRoomEvent {
  const TypingChanged(this.user, {required this.isTyping});

  final UserSummary user;
  final bool isTyping;
}

class ReceiptChanged extends ChatRoomEvent {
  const ReceiptChanged(this.receipt);

  final MemberReceipt receipt;
}

class PresenceChanged extends ChatRoomEvent {
  const PresenceChanged(this.userIds);

  final Set<String> userIds;
}

class ConnectionChanged extends ChatRoomEvent {
  const ConnectionChanged(this.status);

  final RealtimeStatus status;
}

class ReactionChanged extends ChatRoomEvent {
  const ReactionChanged({required this.messageId, required this.userId, this.emoji, required this.counts});

  final String messageId;
  final String userId;
  final String? emoji;
  final List<MessageReaction> counts;
}

class StockRoomStateChanged extends ChatRoomEvent {
  const StockRoomStateChanged(this.state);

  final StockRoomState state;
}

class OwnRoomMuteChanged extends ChatRoomEvent {
  const OwnRoomMuteChanged(this.mutedUntil);

  final DateTime? mutedUntil;
}

class MessageHidden extends ChatRoomEvent {
  const MessageHidden(this.messageId, {this.userId});

  final String messageId;
  final String? userId;
}

class SignalsConnectionChanged extends ChatRoomEvent {
  const SignalsConnectionChanged(this.status);

  final RealtimeStatus status;
}

class RoomActivity {
  const RoomActivity({required this.roomId, required this.senderId, required this.preview, required this.createdAt});

  final String roomId;
  final String? senderId;
  final String preview;
  final DateTime createdAt;
}
