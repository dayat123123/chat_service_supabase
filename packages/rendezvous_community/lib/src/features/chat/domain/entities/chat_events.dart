import 'package:olt_social/src/core/network/realtime_status.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/receipt.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

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
