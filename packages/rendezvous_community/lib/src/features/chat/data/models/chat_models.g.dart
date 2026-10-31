// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessageModel _$ChatMessageModelFromJson(Map<String, dynamic> json) =>
    _ChatMessageModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String?,
      senderUsername: json['sender_username'] as String?,
      senderDisplayName: json['sender_display_name'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      body: json['body'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      replyToId: json['reply_to_id'] as String?,
      replyToBody: json['reply_to_body'] as String?,
      replyToSenderUsername: json['reply_to_sender_username'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AttachmentModel>[],
      clientId: json['client_id'] as String?,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      cursor: json['cursor'] as String?,
      kind: json['kind'] as String?,
      senderRole: json['sender_role'] as String?,
      sessionId: json['session_id'] as String?,
      payload:
          json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$ChatMessageModelToJson(_ChatMessageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'sender_id': instance.senderId,
      'sender_username': instance.senderUsername,
      'sender_display_name': instance.senderDisplayName,
      'sender_avatar_url': instance.senderAvatarUrl,
      'body': instance.body,
      'is_deleted': instance.isDeleted,
      'reply_to_id': instance.replyToId,
      'reply_to_body': instance.replyToBody,
      'reply_to_sender_username': instance.replyToSenderUsername,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
      'client_id': instance.clientId,
      'edited_at': instance.editedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'cursor': instance.cursor,
      'kind': instance.kind,
      'sender_role': instance.senderRole,
      'session_id': instance.sessionId,
      'payload': instance.payload,
    };

_MessageRowModel _$MessageRowModelFromJson(Map<String, dynamic> json) =>
    _MessageRowModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String?,
      body: json['body'] as String? ?? '',
      replyToId: json['reply_to_id'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AttachmentModel>[],
      clientId: json['client_id'] as String?,
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      kind: json['kind'] as String?,
      senderRole: json['sender_role'] as String?,
      sessionId: json['session_id'] as String?,
      payload:
          json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$MessageRowModelToJson(_MessageRowModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'sender_id': instance.senderId,
      'body': instance.body,
      'reply_to_id': instance.replyToId,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
      'client_id': instance.clientId,
      'edited_at': instance.editedAt?.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'kind': instance.kind,
      'sender_role': instance.senderRole,
      'session_id': instance.sessionId,
      'payload': instance.payload,
    };

_RoomSummaryModel _$RoomSummaryModelFromJson(Map<String, dynamic> json) =>
    _RoomSummaryModel(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String?,
      stockCode: json['stock_code'] as String?,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageStatus: json['last_message_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      myRole: json['my_role'] as String?,
      muted: json['muted'] as bool? ?? false,
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      otherUserId: json['other_user_id'] as String?,
      otherUsername: json['other_username'] as String?,
      otherDisplayName: json['other_display_name'] as String?,
      otherAvatarUrl: json['other_avatar_url'] as String?,
      otherIsVerified: json['other_is_verified'] as bool? ?? false,
      cursor: json['cursor'] as String?,
    );

Map<String, dynamic> _$RoomSummaryModelToJson(_RoomSummaryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'name': instance.name,
      'stock_code': instance.stockCode,
      'last_message_at': instance.lastMessageAt?.toIso8601String(),
      'last_message_preview': instance.lastMessagePreview,
      'last_message_sender_id': instance.lastMessageSenderId,
      'last_message_status': instance.lastMessageStatus,
      'created_at': instance.createdAt.toIso8601String(),
      'my_role': instance.myRole,
      'muted': instance.muted,
      'last_read_at': instance.lastReadAt.toIso8601String(),
      'unread_count': instance.unreadCount,
      'member_count': instance.memberCount,
      'other_user_id': instance.otherUserId,
      'other_username': instance.otherUsername,
      'other_display_name': instance.otherDisplayName,
      'other_avatar_url': instance.otherAvatarUrl,
      'other_is_verified': instance.otherIsVerified,
      'cursor': instance.cursor,
    };

_RoomMemberModel _$RoomMemberModelFromJson(Map<String, dynamic> json) =>
    _RoomMemberModel(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      role: json['role'] as String?,
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
      lastDeliveredAt: json['last_delivered_at'] == null
          ? null
          : DateTime.parse(json['last_delivered_at'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$RoomMemberModelToJson(_RoomMemberModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'username': instance.username,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'is_verified': instance.isVerified,
      'role': instance.role,
      'last_read_at': instance.lastReadAt.toIso8601String(),
      'last_delivered_at': instance.lastDeliveredAt?.toIso8601String(),
      'joined_at': instance.joinedAt.toIso8601String(),
    };
