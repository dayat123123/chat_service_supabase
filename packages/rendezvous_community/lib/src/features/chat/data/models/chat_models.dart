import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/stock_room_state.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/shared/data/models/attachment_model.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
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

Object? readAttachments(Map<dynamic, dynamic> json, String key) => json['attachments'];

@freezed
abstract class MessageReactionModel with _$MessageReactionModel {
  const factory MessageReactionModel({required String emoji, @Default(0) int count, @Default(false) bool me}) =
      _MessageReactionModel;

  const MessageReactionModel._();

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) => _$MessageReactionModelFromJson(json);

  MessageReaction toEntity() => MessageReaction(emoji: emoji, count: count, mine: me);
}

List<MessageReaction> reactionsFromJson(Object? value, {String? mine}) => [
  if (value is List)
    for (final item in value)
      if (item is Map && item['emoji'] is String)
        MessageReaction(
          emoji: item['emoji'] as String,
          count: (item['count'] as num?)?.toInt() ?? 0,
          mine: mine == null ? item['me'] == true : item['emoji'] == mine,
        ),
];

@freezed
abstract class SharedPostModel with _$SharedPostModel {
  const factory SharedPostModel({
    required String postId,
    @Default(false) bool available,
    String? authorId,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    @Default(false) bool authorIsVerified,
    String? body,
    @JsonKey(fromJson: attachmentsFromJson) @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    String? sentiment,
    @Default(<String>[]) List<String> stockCodes,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    DateTime? createdAt,
  }) = _SharedPostModel;

  const SharedPostModel._();

  factory SharedPostModel.fromJson(Map<String, dynamic> json) => _$SharedPostModelFromJson(json);

  SharedPost toEntity() => SharedPost(
    postId: postId,
    available: available,
    author: authorId == null || authorUsername == null
        ? null
        : UserSummary(
            id: authorId!,
            username: authorUsername!,
            displayName: authorDisplayName,
            avatarUrl: authorAvatarUrl,
            isVerified: authorIsVerified,
          ),
    body: body,
    attachments: [for (final a in attachments) a.toEntity()],
    sentiment: sentiment == null ? null : Sentiment.values.asNameMap()[sentiment],
    stockCodes: stockCodes,
    likeCount: likeCount,
    commentCount: commentCount,
    createdAt: createdAt,
  );
}

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
    @JsonKey(fromJson: attachmentsFromJson) @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? sharedPostId,
    @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)
    @Default(<String>[])
    List<String> stockCodes,
    String? clientId,
    DateTime? editedAt,
    required DateTime createdAt,
    String? cursor,
    String? kind,
    String? senderRole,
    String? sessionId,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    List<MessageReactionModel>? reactions,
    SharedPostModel? sharedPost,
    String? moderationStatus,
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
    reactions: isDeleted ? const [] : [for (final r in reactions ?? const <MessageReactionModel>[]) r.toEntity()],
    sharedPostId: isDeleted ? null : sharedPost?.postId ?? sharedPostId,
    stockCodes: isDeleted ? const [] : stockCodes,
    sharedPost: isDeleted ? null : sharedPost?.toEntity(),
    moderationStatus: parseModerationStatus(moderationStatus),
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
    @JsonKey(fromJson: attachmentsFromJson) @Default(<AttachmentModel>[]) List<AttachmentModel> attachments,
    @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? sharedPostId,
    @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)
    @Default(<String>[])
    List<String> stockCodes,
    String? clientId,
    DateTime? editedAt,
    DateTime? deletedAt,
    required DateTime createdAt,
    String? kind,
    String? senderRole,
    String? sessionId,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    String? moderationStatus,
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
    sharedPostId: deletedAt == null ? sharedPostId : null,
    stockCodes: deletedAt == null ? stockCodes : const [],
    clientId: clientId,
    editedAt: editedAt,
    createdAt: createdAt,
    kind: parseMessageKind(kind),
    senderRole: parseSenderRole(senderRole),
    ticketId: sessionId,
    payload: payload,
    moderationStatus: parseModerationStatus(moderationStatus),
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

StockRoomState parseStockRoomState(Map<String, dynamic> json) {
  final slow = json['slow_mode'];
  final slowMode = slow is Map ? Map<String, dynamic>.from(slow) : const <String, dynamic>{};
  final pinned = json['pinned_message'];
  return StockRoomState(
    roomId: json['room_id'] as String?,
    stockCode: json['stock_code'] as String?,
    slowModeSeconds: (slowMode['seconds'] as num?)?.toInt() ?? 0,
    slowModeUntil: DateTime.tryParse(slowMode['until'] as String? ?? ''),
    slowModeSource: slowMode['source'] as String?,
    waitSeconds: (json['wait_seconds'] as num?)?.toInt() ?? 0,
    pinnedMessage: pinned is Map ? ChatMessageModel.fromJson(Map<String, dynamic>.from(pinned)).toEntity() : null,
    pinnedAt: DateTime.tryParse(json['pinned_at'] as String? ?? ''),
    moderatorIds: {
      if (json['moderators'] case final List<dynamic> ids)
        for (final id in ids)
          if (id is String) id,
    },
    mutes: {
      if (json['mutes'] case final List<dynamic> mutes)
        for (final mute in mutes)
          if (mute case {'user_id': final String userId, 'until': final String until})
            if (DateTime.tryParse(until) case final DateTime at) userId: at.toUtc(),
    },
    viewerMutedUntil: DateTime.tryParse(json['muted_until'] as String? ?? '')?.toUtc(),
  );
}

typedef RoomMuteNotice = ({String roomId, DateTime? mutedUntil});

RoomMuteNotice? parseRoomMuteNotice(Map<String, dynamic> row) {
  if (row['type'] != 'moderation') return null;
  final payload = switch (row['payload']) {
    final Map<dynamic, dynamic> map => map,
    final String text => _decodeMap(text),
    _ => null,
  };
  if (payload == null || payload['target_type'] != 'room') return null;
  final roomId = payload['room_id'];
  if (roomId is! String) return null;
  final until = payload['state'] == 'muted' ? DateTime.tryParse(payload['until'] as String? ?? '')?.toUtc() : null;
  return (roomId: roomId, mutedUntil: until);
}

Map<dynamic, dynamic>? _decodeMap(String text) {
  try {
    final value = jsonDecode(text);
    return value is Map ? value : null;
  } on FormatException {
    return null;
  }
}

const _roomModerationActions = {
  'hide': RoomModerationAction.hide,
  'mute': RoomModerationAction.mute,
  'escalate': RoomModerationAction.escalate,
};

RoomModerationResult parseRoomModerationResult(Map<String, dynamic> json) => RoomModerationResult(
  id: json['id'] as String? ?? '',
  action: _roomModerationActions[json['action']] ?? RoomModerationAction.hide,
  targetUserId: json['target_user_id'] as String?,
  messageId: json['message_id'] as String?,
  muteUntil: DateTime.tryParse(json['mute_until'] as String? ?? '')?.toUtc(),
  reportId: json['report_id'] as String?,
);

RoomActivity? parseRoomActivity(Map<String, dynamic> json) {
  final roomId = json['room_id'];
  final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
  if (roomId is! String || createdAt == null) return null;
  return RoomActivity(
    roomId: roomId,
    senderId: json['sender_id'] as String?,
    preview: json['preview'] as String? ?? '',
    createdAt: createdAt.toUtc(),
  );
}
