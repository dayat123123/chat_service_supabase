import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

part 'chat_models.freezed.dart';
part 'chat_models.g.dart';

MemberRole parseRole(String? value) => MemberRole.values.asNameMap()[value] ?? MemberRole.member;

ReceiptStatus? parseReceiptStatus(String? value) => value == null ? null : ReceiptStatus.values.asNameMap()[value];

const _messageKinds = {
  'text': MessageKind.text,
  'system': MessageKind.system,
  'quick_reply': MessageKind.quickReply,
  'help_link': MessageKind.helpLink,
  'identity_request': MessageKind.identityRequest,
  'csat': MessageKind.csat,
};

MessageKind parseMessageKind(String? value) => _messageKinds[value] ?? MessageKind.text;

SenderRole? parseSenderRole(String? value) => value == null ? null : SenderRole.values.asNameMap()[value];

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
    String? kind,
    String? senderRole,
    String? sessionId,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
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
    kind: parseMessageKind(kind),
    senderRole: parseSenderRole(senderRole),
    ticketId: sessionId,
    payload: payload,
  );
}

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
    String? kind,
    String? senderRole,
    String? sessionId,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
  }) = _MessageRowModel;

  const MessageRowModel._();

  factory MessageRowModel.fromJson(Map<String, dynamic> json) => _$MessageRowModelFromJson(json);

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
    kind: parseMessageKind(kind),
    senderRole: parseSenderRole(senderRole),
    ticketId: sessionId,
    payload: payload,
  );
}

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
    String? lastMessageStatus,
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
    String? cursor,
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
    lastMessageStatus: parseReceiptStatus(lastMessageStatus),
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
    DateTime? lastDeliveredAt,
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
    lastDeliveredAt: lastDeliveredAt ?? lastReadAt,
    joinedAt: joinedAt,
  );
}

MemberReceipt? parseReceipt(Map<String, dynamic> json) {
  final userId = json['user_id'] as String?;
  final delivered = DateTime.tryParse(json['last_delivered_at'] as String? ?? '');
  final read = DateTime.tryParse(json['last_read_at'] as String? ?? '');
  if (userId == null || delivered == null || read == null) return null;
  return MemberReceipt(userId: userId, lastDeliveredAt: delivered, lastReadAt: read);
}
