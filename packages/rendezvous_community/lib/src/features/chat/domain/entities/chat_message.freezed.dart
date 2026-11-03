// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatMessage {

 String get id; String get roomId; String? get senderId; UserSummary? get sender; String? get body; bool get isDeleted; String? get replyToId; String? get replyToBody; String? get replyToSenderUsername; List<Attachment> get attachments; String? get clientId; DateTime? get editedAt; DateTime get createdAt; String? get cursor; MessageStatus get status; MessageKind get kind; SenderRole? get senderRole; String? get ticketId; Map<String, Object?> get payload; List<MessageReaction> get reactions; String? get sharedPostId; SharedPost? get sharedPost; List<String> get stockCodes; ModerationStatus? get moderationStatus; CommunityException? get sendError;
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<ChatMessage> get copyWith => _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.status, status) || other.status == status)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&const DeepCollectionEquality().equals(other.payload, payload)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.sharedPostId, sharedPostId) || other.sharedPostId == sharedPostId)&&(identical(other.sharedPost, sharedPost) || other.sharedPost == sharedPost)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus)&&(identical(other.sendError, sendError) || other.sendError == sendError));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,roomId,senderId,sender,body,isDeleted,replyToId,replyToBody,replyToSenderUsername,const DeepCollectionEquality().hash(attachments),clientId,editedAt,createdAt,cursor,status,kind,senderRole,ticketId,const DeepCollectionEquality().hash(payload),const DeepCollectionEquality().hash(reactions),sharedPostId,sharedPost,const DeepCollectionEquality().hash(stockCodes),moderationStatus,sendError]);

@override
String toString() {
  return 'ChatMessage(id: $id, roomId: $roomId, senderId: $senderId, sender: $sender, body: $body, isDeleted: $isDeleted, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, attachments: $attachments, clientId: $clientId, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, status: $status, kind: $kind, senderRole: $senderRole, ticketId: $ticketId, payload: $payload, reactions: $reactions, sharedPostId: $sharedPostId, sharedPost: $sharedPost, stockCodes: $stockCodes, moderationStatus: $moderationStatus, sendError: $sendError)';
}


}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res>  {
  factory $ChatMessageCopyWith(ChatMessage value, $Res Function(ChatMessage) _then) = _$ChatMessageCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String? senderId, UserSummary? sender, String? body, bool isDeleted, String? replyToId, String? replyToBody, String? replyToSenderUsername, List<Attachment> attachments, String? clientId, DateTime? editedAt, DateTime createdAt, String? cursor, MessageStatus status, MessageKind kind, SenderRole? senderRole, String? ticketId, Map<String, Object?> payload, List<MessageReaction> reactions, String? sharedPostId, SharedPost? sharedPost, List<String> stockCodes, ModerationStatus? moderationStatus, CommunityException? sendError
});


$UserSummaryCopyWith<$Res>? get sender;$SharedPostCopyWith<$Res>? get sharedPost;

}
/// @nodoc
class _$ChatMessageCopyWithImpl<$Res>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? sender = freezed,Object? body = freezed,Object? isDeleted = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? attachments = null,Object? clientId = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = freezed,Object? status = null,Object? kind = null,Object? senderRole = freezed,Object? ticketId = freezed,Object? payload = null,Object? reactions = null,Object? sharedPostId = freezed,Object? sharedPost = freezed,Object? stockCodes = null,Object? moderationStatus = freezed,Object? sendError = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,sender: freezed == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToBody: freezed == replyToBody ? _self.replyToBody : replyToBody // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderUsername: freezed == replyToSenderUsername ? _self.replyToSenderUsername : replyToSenderUsername // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MessageKind,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as SenderRole?,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReaction>,sharedPostId: freezed == sharedPostId ? _self.sharedPostId : sharedPostId // ignore: cast_nullable_to_non_nullable
as String?,sharedPost: freezed == sharedPost ? _self.sharedPost : sharedPost // ignore: cast_nullable_to_non_nullable
as SharedPost?,stockCodes: null == stockCodes ? _self.stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as ModerationStatus?,sendError: freezed == sendError ? _self.sendError : sendError // ignore: cast_nullable_to_non_nullable
as CommunityException?,
  ));
}
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get sender {
    if (_self.sender == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.sender!, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SharedPostCopyWith<$Res>? get sharedPost {
    if (_self.sharedPost == null) {
    return null;
  }

  return $SharedPostCopyWith<$Res>(_self.sharedPost!, (value) {
    return _then(_self.copyWith(sharedPost: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatMessage].
extension ChatMessagePatterns on ChatMessage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  UserSummary? sender,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  List<Attachment> attachments,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  MessageStatus status,  MessageKind kind,  SenderRole? senderRole,  String? ticketId,  Map<String, Object?> payload,  List<MessageReaction> reactions,  String? sharedPostId,  SharedPost? sharedPost,  List<String> stockCodes,  ModerationStatus? moderationStatus,  CommunityException? sendError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.sender,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.status,_that.kind,_that.senderRole,_that.ticketId,_that.payload,_that.reactions,_that.sharedPostId,_that.sharedPost,_that.stockCodes,_that.moderationStatus,_that.sendError);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  UserSummary? sender,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  List<Attachment> attachments,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  MessageStatus status,  MessageKind kind,  SenderRole? senderRole,  String? ticketId,  Map<String, Object?> payload,  List<MessageReaction> reactions,  String? sharedPostId,  SharedPost? sharedPost,  List<String> stockCodes,  ModerationStatus? moderationStatus,  CommunityException? sendError)  $default,) {final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that.id,_that.roomId,_that.senderId,_that.sender,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.status,_that.kind,_that.senderRole,_that.ticketId,_that.payload,_that.reactions,_that.sharedPostId,_that.sharedPost,_that.stockCodes,_that.moderationStatus,_that.sendError);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String? senderId,  UserSummary? sender,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  List<Attachment> attachments,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  MessageStatus status,  MessageKind kind,  SenderRole? senderRole,  String? ticketId,  Map<String, Object?> payload,  List<MessageReaction> reactions,  String? sharedPostId,  SharedPost? sharedPost,  List<String> stockCodes,  ModerationStatus? moderationStatus,  CommunityException? sendError)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.sender,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.status,_that.kind,_that.senderRole,_that.ticketId,_that.payload,_that.reactions,_that.sharedPostId,_that.sharedPost,_that.stockCodes,_that.moderationStatus,_that.sendError);case _:
  return null;

}
}

}

/// @nodoc


class _ChatMessage extends ChatMessage {
  const _ChatMessage({required this.id, required this.roomId, this.senderId, this.sender, this.body, this.isDeleted = false, this.replyToId, this.replyToBody, this.replyToSenderUsername, final  List<Attachment> attachments = const <Attachment>[], this.clientId, this.editedAt, required this.createdAt, this.cursor, this.status = MessageStatus.sent, this.kind = MessageKind.text, this.senderRole, this.ticketId, final  Map<String, Object?> payload = const <String, Object?>{}, final  List<MessageReaction> reactions = const <MessageReaction>[], this.sharedPostId, this.sharedPost, final  List<String> stockCodes = const <String>[], this.moderationStatus, this.sendError}): _attachments = attachments,_payload = payload,_reactions = reactions,_stockCodes = stockCodes,super._();
  

@override final  String id;
@override final  String roomId;
@override final  String? senderId;
@override final  UserSummary? sender;
@override final  String? body;
@override@JsonKey() final  bool isDeleted;
@override final  String? replyToId;
@override final  String? replyToBody;
@override final  String? replyToSenderUsername;
 final  List<Attachment> _attachments;
@override@JsonKey() List<Attachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override final  String? clientId;
@override final  DateTime? editedAt;
@override final  DateTime createdAt;
@override final  String? cursor;
@override@JsonKey() final  MessageStatus status;
@override@JsonKey() final  MessageKind kind;
@override final  SenderRole? senderRole;
@override final  String? ticketId;
 final  Map<String, Object?> _payload;
@override@JsonKey() Map<String, Object?> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

 final  List<MessageReaction> _reactions;
@override@JsonKey() List<MessageReaction> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

@override final  String? sharedPostId;
@override final  SharedPost? sharedPost;
 final  List<String> _stockCodes;
@override@JsonKey() List<String> get stockCodes {
  if (_stockCodes is EqualUnmodifiableListView) return _stockCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stockCodes);
}

@override final  ModerationStatus? moderationStatus;
@override final  CommunityException? sendError;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageCopyWith<_ChatMessage> get copyWith => __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.status, status) || other.status == status)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&const DeepCollectionEquality().equals(other._payload, _payload)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.sharedPostId, sharedPostId) || other.sharedPostId == sharedPostId)&&(identical(other.sharedPost, sharedPost) || other.sharedPost == sharedPost)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus)&&(identical(other.sendError, sendError) || other.sendError == sendError));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,roomId,senderId,sender,body,isDeleted,replyToId,replyToBody,replyToSenderUsername,const DeepCollectionEquality().hash(_attachments),clientId,editedAt,createdAt,cursor,status,kind,senderRole,ticketId,const DeepCollectionEquality().hash(_payload),const DeepCollectionEquality().hash(_reactions),sharedPostId,sharedPost,const DeepCollectionEquality().hash(_stockCodes),moderationStatus,sendError]);

@override
String toString() {
  return 'ChatMessage(id: $id, roomId: $roomId, senderId: $senderId, sender: $sender, body: $body, isDeleted: $isDeleted, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, attachments: $attachments, clientId: $clientId, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, status: $status, kind: $kind, senderRole: $senderRole, ticketId: $ticketId, payload: $payload, reactions: $reactions, sharedPostId: $sharedPostId, sharedPost: $sharedPost, stockCodes: $stockCodes, moderationStatus: $moderationStatus, sendError: $sendError)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res> implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(_ChatMessage value, $Res Function(_ChatMessage) _then) = __$ChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String? senderId, UserSummary? sender, String? body, bool isDeleted, String? replyToId, String? replyToBody, String? replyToSenderUsername, List<Attachment> attachments, String? clientId, DateTime? editedAt, DateTime createdAt, String? cursor, MessageStatus status, MessageKind kind, SenderRole? senderRole, String? ticketId, Map<String, Object?> payload, List<MessageReaction> reactions, String? sharedPostId, SharedPost? sharedPost, List<String> stockCodes, ModerationStatus? moderationStatus, CommunityException? sendError
});


@override $UserSummaryCopyWith<$Res>? get sender;@override $SharedPostCopyWith<$Res>? get sharedPost;

}
/// @nodoc
class __$ChatMessageCopyWithImpl<$Res>
    implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? sender = freezed,Object? body = freezed,Object? isDeleted = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? attachments = null,Object? clientId = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = freezed,Object? status = null,Object? kind = null,Object? senderRole = freezed,Object? ticketId = freezed,Object? payload = null,Object? reactions = null,Object? sharedPostId = freezed,Object? sharedPost = freezed,Object? stockCodes = null,Object? moderationStatus = freezed,Object? sendError = freezed,}) {
  return _then(_ChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,sender: freezed == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToBody: freezed == replyToBody ? _self.replyToBody : replyToBody // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderUsername: freezed == replyToSenderUsername ? _self.replyToSenderUsername : replyToSenderUsername // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MessageKind,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as SenderRole?,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReaction>,sharedPostId: freezed == sharedPostId ? _self.sharedPostId : sharedPostId // ignore: cast_nullable_to_non_nullable
as String?,sharedPost: freezed == sharedPost ? _self.sharedPost : sharedPost // ignore: cast_nullable_to_non_nullable
as SharedPost?,stockCodes: null == stockCodes ? _self._stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as ModerationStatus?,sendError: freezed == sendError ? _self.sendError : sendError // ignore: cast_nullable_to_non_nullable
as CommunityException?,
  ));
}

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get sender {
    if (_self.sender == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.sender!, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SharedPostCopyWith<$Res>? get sharedPost {
    if (_self.sharedPost == null) {
    return null;
  }

  return $SharedPostCopyWith<$Res>(_self.sharedPost!, (value) {
    return _then(_self.copyWith(sharedPost: value));
  });
}
}

// dart format on
