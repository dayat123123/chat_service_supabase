import 'package:freezed_annotation/freezed_annotation.dart';

import 'post.dart';
import 'user.dart';

part 'chat.freezed.dart';

enum RoomType { direct, group, stock }

enum MemberRole { owner, admin, member }

/// Room chat milik user (untuk daftar chat).
@freezed
abstract class ChatRoom with _$ChatRoom {
  const factory ChatRoom({
    required String id,
    required RoomType type,
    String? name,
    String? stockCode,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? lastMessageSenderId,
    required DateTime createdAt,
    @Default(MemberRole.member) MemberRole myRole,
    @Default(false) bool muted,
    required DateTime lastReadAt,
    @Default(0) int unreadCount,
    @Default(0) int memberCount,

    /// Lawan bicara untuk room direct.
    UserSummary? otherUser,
  }) = _ChatRoom;

  const ChatRoom._();

  DateTime get sortTime => lastMessageAt ?? createdAt;
}

/// Status kirim pesan di sisi client (optimistic send).
enum MessageStatus { sending, sent, failed }

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String roomId,
    String? senderId,
    UserSummary? sender,

    /// null jika pesan dihapus.
    String? body,
    @Default(false) bool isDeleted,
    String? replyToId,
    String? replyToBody,
    String? replyToSenderUsername,
    @Default(<Attachment>[]) List<Attachment> attachments,
    String? clientId,
    DateTime? editedAt,
    required DateTime createdAt,
    String? cursor,
    @Default(MessageStatus.sent) MessageStatus status,
  }) = _ChatMessage;
}

@freezed
abstract class RoomMember with _$RoomMember {
  const factory RoomMember({
    required UserSummary user,
    @Default(MemberRole.member) MemberRole role,
    required DateTime lastReadAt,
    required DateTime joinedAt,
  }) = _RoomMember;
}

/// Event realtime di dalam sebuah room.
sealed class ChatRoomEvent {
  const ChatRoomEvent();
}

/// Pesan baru atau pesan diubah/dihapus.
class MessageUpserted extends ChatRoomEvent {
  const MessageUpserted(this.message);
  final ChatMessage message;
}

/// Anggota lain sedang/selesai mengetik.
class TypingChanged extends ChatRoomEvent {
  const TypingChanged(this.user, {required this.isTyping});
  final UserSummary user;
  final bool isTyping;
}

/// Anggota lain membaca room sampai [lastReadAt].
class ReadReceipt extends ChatRoomEvent {
  const ReadReceipt(this.userId, this.lastReadAt);
  final String userId;
  final DateTime lastReadAt;
}

/// Status koneksi realtime room.
class ConnectionChanged extends ChatRoomEvent {
  const ConnectionChanged(this.status);
  final RealtimeStatus status;
}

enum RealtimeStatus { connecting, connected, reconnecting }

/// Sinyal bahwa daftar room perlu diperbarui (pesan baru di salah satu room).
class RoomActivity {
  const RoomActivity({required this.roomId, required this.senderId, required this.preview, required this.createdAt});
  final String roomId;
  final String? senderId;
  final String preview;
  final DateTime createdAt;
}
