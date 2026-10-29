import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/chat.dart';
import '../../domain/entities/user.dart';
import 'post_models.dart';

part 'chat_models.freezed.dart';
part 'chat_models.g.dart';

MemberRole parseRole(String? value) => MemberRole.values.asNameMap()[value] ?? MemberRole.member;

/// Baris hasil RPC get_messages / send_message (tipe public.chat_message).
@freezed
abstract class ChatMessageModel with _$ChatMessageModel {
  const factory ChatMessageModel({
    required String id,
    required String roomId,
    String? senderId,
    String? senderUsername,
    String? senderDisplayName,
    String? senderAvatarUrl,
    String? body,
    @Default(false) bool isDeleted,
    String? replyToId,
    String? replyToBody,
    String? replyToSenderUsername,
    @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    String? clientId,
    DateTime? editedAt,
    required DateTime createdAt,
    String? cursor,
  }) = _ChatMessageModel;

  const ChatMessageModel._();

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => _$ChatMessageModelFromJson(json);

  ChatMessage toEntity() => ChatMessage(
    id: id,
    roomId: roomId,
    senderId: senderId,
    sender: senderId == null || senderUsername == null
        ? null
        : UserSummary(
            id: senderId!,
            username: senderUsername!,
            displayName: senderDisplayName,
            avatarUrl: senderAvatarUrl,
          ),
    body: body,
    isDeleted: isDeleted,
    replyToId: replyToId,
    replyToBody: replyToBody,
    replyToSenderUsername: replyToSenderUsername,
    attachments: [for (final a in attachments) a.toEntity()],
    clientId: clientId,
    editedAt: editedAt,
    createdAt: createdAt,
    cursor: cursor,
  );
}

/// Baris mentah tabel messages dari realtime postgres_changes.
@freezed
abstract class MessageRowModel with _$MessageRowModel {
  const factory MessageRowModel({
    required String id,
    required String roomId,
    String? senderId,
    @Default('') String body,
    String? replyToId,
    @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    String? clientId,
    DateTime? editedAt,
    DateTime? deletedAt,
    required DateTime createdAt,
  }) = _MessageRowModel;

  const MessageRowModel._();

  factory MessageRowModel.fromJson(Map<String, dynamic> json) => _$MessageRowModelFromJson(json);

  /// [sender] diisi dari cache anggota room (event realtime tidak membawa profil).
  ChatMessage toEntity({UserSummary? sender}) => ChatMessage(
    id: id,
    roomId: roomId,
    senderId: senderId,
    sender: sender,
    body: deletedAt == null ? body : null,
    isDeleted: deletedAt != null,
    replyToId: replyToId,
    attachments: deletedAt == null ? [for (final a in attachments) a.toEntity()] : const [],
    clientId: clientId,
    editedAt: editedAt,
    createdAt: createdAt,
  );
}

/// Baris hasil RPC get_my_rooms.
@freezed
abstract class RoomSummaryModel with _$RoomSummaryModel {
  const factory RoomSummaryModel({
    required String id,
    required String type,
    String? name,
    String? stockCode,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? lastMessageSenderId,
    required DateTime createdAt,
    String? myRole,
    @Default(false) bool muted,
    required DateTime lastReadAt,
    @Default(0) int unreadCount,
    @Default(0) int memberCount,
    String? otherUserId,
    String? otherUsername,
    String? otherDisplayName,
    String? otherAvatarUrl,
    @Default(false) bool otherIsVerified,
  }) = _RoomSummaryModel;

  const RoomSummaryModel._();

  factory RoomSummaryModel.fromJson(Map<String, dynamic> json) => _$RoomSummaryModelFromJson(json);

  ChatRoom toEntity() => ChatRoom(
    id: id,
    type: RoomType.values.asNameMap()[type] ?? RoomType.group,
    name: name,
    stockCode: stockCode,
    lastMessageAt: lastMessageAt,
    lastMessagePreview: lastMessagePreview,
    lastMessageSenderId: lastMessageSenderId,
    createdAt: createdAt,
    myRole: parseRole(myRole),
    muted: muted,
    lastReadAt: lastReadAt,
    unreadCount: unreadCount,
    memberCount: memberCount,
    otherUser: otherUserId == null || otherUsername == null
        ? null
        : UserSummary(
            id: otherUserId!,
            username: otherUsername!,
            displayName: otherDisplayName,
            avatarUrl: otherAvatarUrl,
            isVerified: otherIsVerified,
          ),
  );
}

/// Baris hasil RPC get_room_members.
@freezed
abstract class RoomMemberModel with _$RoomMemberModel {
  const factory RoomMemberModel({
    required String userId,
    required String username,
    String? displayName,
    String? avatarUrl,
    @Default(false) bool isVerified,
    String? role,
    required DateTime lastReadAt,
    required DateTime joinedAt,
  }) = _RoomMemberModel;

  const RoomMemberModel._();

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) => _$RoomMemberModelFromJson(json);

  RoomMember toEntity() => RoomMember(
    user: UserSummary(
      id: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
    ),
    role: parseRole(role),
    lastReadAt: lastReadAt,
    joinedAt: joinedAt,
  );
}
