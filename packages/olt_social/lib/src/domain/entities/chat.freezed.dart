// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatRoom {

 String get id; RoomType get type; String? get name; String? get stockCode; DateTime? get lastMessageAt; String? get lastMessagePreview; String? get lastMessageSenderId; DateTime get createdAt; MemberRole get myRole; bool get muted; DateTime get lastReadAt; int get unreadCount; int get memberCount;/// Lawan bicara untuk room direct.
 UserSummary? get otherUser;
/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatRoomCopyWith<ChatRoom> get copyWith => _$ChatRoomCopyWithImpl<ChatRoom>(this as ChatRoom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.otherUser, otherUser) || other.otherUser == otherUser));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,name,stockCode,lastMessageAt,lastMessagePreview,lastMessageSenderId,createdAt,myRole,muted,lastReadAt,unreadCount,memberCount,otherUser);

@override
String toString() {
  return 'ChatRoom(id: $id, type: $type, name: $name, stockCode: $stockCode, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, lastMessageSenderId: $lastMessageSenderId, createdAt: $createdAt, myRole: $myRole, muted: $muted, lastReadAt: $lastReadAt, unreadCount: $unreadCount, memberCount: $memberCount, otherUser: $otherUser)';
}


}

/// @nodoc
abstract mixin class $ChatRoomCopyWith<$Res>  {
  factory $ChatRoomCopyWith(ChatRoom value, $Res Function(ChatRoom) _then) = _$ChatRoomCopyWithImpl;
@useResult
$Res call({
 String id, RoomType type, String? name, String? stockCode, DateTime? lastMessageAt, String? lastMessagePreview, String? lastMessageSenderId, DateTime createdAt, MemberRole myRole, bool muted, DateTime lastReadAt, int unreadCount, int memberCount, UserSummary? otherUser
});


$UserSummaryCopyWith<$Res>? get otherUser;

}
/// @nodoc
class _$ChatRoomCopyWithImpl<$Res>
    implements $ChatRoomCopyWith<$Res> {
  _$ChatRoomCopyWithImpl(this._self, this._then);

  final ChatRoom _self;
  final $Res Function(ChatRoom) _then;

/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? name = freezed,Object? stockCode = freezed,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? lastMessageSenderId = freezed,Object? createdAt = null,Object? myRole = null,Object? muted = null,Object? lastReadAt = null,Object? unreadCount = null,Object? memberCount = null,Object? otherUser = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RoomType,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: null == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as MemberRole,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,otherUser: freezed == otherUser ? _self.otherUser : otherUser // ignore: cast_nullable_to_non_nullable
as UserSummary?,
  ));
}
/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get otherUser {
    if (_self.otherUser == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.otherUser!, (value) {
    return _then(_self.copyWith(otherUser: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatRoom].
extension ChatRoomPatterns on ChatRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatRoom value)  $default,){
final _that = this;
switch (_that) {
case _ChatRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatRoom value)?  $default,){
final _that = this;
switch (_that) {
case _ChatRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  RoomType type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  DateTime createdAt,  MemberRole myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  UserSummary? otherUser)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatRoom() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUser);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  RoomType type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  DateTime createdAt,  MemberRole myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  UserSummary? otherUser)  $default,) {final _that = this;
switch (_that) {
case _ChatRoom():
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUser);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  RoomType type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  DateTime createdAt,  MemberRole myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  UserSummary? otherUser)?  $default,) {final _that = this;
switch (_that) {
case _ChatRoom() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUser);case _:
  return null;

}
}

}

/// @nodoc


class _ChatRoom extends ChatRoom {
  const _ChatRoom({required this.id, required this.type, this.name, this.stockCode, this.lastMessageAt, this.lastMessagePreview, this.lastMessageSenderId, required this.createdAt, this.myRole = MemberRole.member, this.muted = false, required this.lastReadAt, this.unreadCount = 0, this.memberCount = 0, this.otherUser}): super._();
  

@override final  String id;
@override final  RoomType type;
@override final  String? name;
@override final  String? stockCode;
@override final  DateTime? lastMessageAt;
@override final  String? lastMessagePreview;
@override final  String? lastMessageSenderId;
@override final  DateTime createdAt;
@override@JsonKey() final  MemberRole myRole;
@override@JsonKey() final  bool muted;
@override final  DateTime lastReadAt;
@override@JsonKey() final  int unreadCount;
@override@JsonKey() final  int memberCount;
/// Lawan bicara untuk room direct.
@override final  UserSummary? otherUser;

/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatRoomCopyWith<_ChatRoom> get copyWith => __$ChatRoomCopyWithImpl<_ChatRoom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.otherUser, otherUser) || other.otherUser == otherUser));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,name,stockCode,lastMessageAt,lastMessagePreview,lastMessageSenderId,createdAt,myRole,muted,lastReadAt,unreadCount,memberCount,otherUser);

@override
String toString() {
  return 'ChatRoom(id: $id, type: $type, name: $name, stockCode: $stockCode, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, lastMessageSenderId: $lastMessageSenderId, createdAt: $createdAt, myRole: $myRole, muted: $muted, lastReadAt: $lastReadAt, unreadCount: $unreadCount, memberCount: $memberCount, otherUser: $otherUser)';
}


}

/// @nodoc
abstract mixin class _$ChatRoomCopyWith<$Res> implements $ChatRoomCopyWith<$Res> {
  factory _$ChatRoomCopyWith(_ChatRoom value, $Res Function(_ChatRoom) _then) = __$ChatRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, RoomType type, String? name, String? stockCode, DateTime? lastMessageAt, String? lastMessagePreview, String? lastMessageSenderId, DateTime createdAt, MemberRole myRole, bool muted, DateTime lastReadAt, int unreadCount, int memberCount, UserSummary? otherUser
});


@override $UserSummaryCopyWith<$Res>? get otherUser;

}
/// @nodoc
class __$ChatRoomCopyWithImpl<$Res>
    implements _$ChatRoomCopyWith<$Res> {
  __$ChatRoomCopyWithImpl(this._self, this._then);

  final _ChatRoom _self;
  final $Res Function(_ChatRoom) _then;

/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? name = freezed,Object? stockCode = freezed,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? lastMessageSenderId = freezed,Object? createdAt = null,Object? myRole = null,Object? muted = null,Object? lastReadAt = null,Object? unreadCount = null,Object? memberCount = null,Object? otherUser = freezed,}) {
  return _then(_ChatRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RoomType,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: null == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as MemberRole,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,otherUser: freezed == otherUser ? _self.otherUser : otherUser // ignore: cast_nullable_to_non_nullable
as UserSummary?,
  ));
}

/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get otherUser {
    if (_self.otherUser == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.otherUser!, (value) {
    return _then(_self.copyWith(otherUser: value));
  });
}
}

/// @nodoc
mixin _$ChatMessage {

 String get id; String get roomId; String? get senderId; UserSummary? get sender;/// null jika pesan dihapus.
 String? get body; bool get isDeleted; String? get replyToId; String? get replyToBody; String? get replyToSenderUsername; List<Attachment> get attachments; String? get clientId; DateTime? get editedAt; DateTime get createdAt; String? get cursor; MessageStatus get status;
/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<ChatMessage> get copyWith => _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,roomId,senderId,sender,body,isDeleted,replyToId,replyToBody,replyToSenderUsername,const DeepCollectionEquality().hash(attachments),clientId,editedAt,createdAt,cursor,status);

@override
String toString() {
  return 'ChatMessage(id: $id, roomId: $roomId, senderId: $senderId, sender: $sender, body: $body, isDeleted: $isDeleted, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, attachments: $attachments, clientId: $clientId, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, status: $status)';
}


}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res>  {
  factory $ChatMessageCopyWith(ChatMessage value, $Res Function(ChatMessage) _then) = _$ChatMessageCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String? senderId, UserSummary? sender, String? body, bool isDeleted, String? replyToId, String? replyToBody, String? replyToSenderUsername, List<Attachment> attachments, String? clientId, DateTime? editedAt, DateTime createdAt, String? cursor, MessageStatus status
});


$UserSummaryCopyWith<$Res>? get sender;

}
/// @nodoc
class _$ChatMessageCopyWithImpl<$Res>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? sender = freezed,Object? body = freezed,Object? isDeleted = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? attachments = null,Object? clientId = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = freezed,Object? status = null,}) {
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
as MessageStatus,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  UserSummary? sender,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  List<Attachment> attachments,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  MessageStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.sender,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  UserSummary? sender,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  List<Attachment> attachments,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  MessageStatus status)  $default,) {final _that = this;
switch (_that) {
case _ChatMessage():
return $default(_that.id,_that.roomId,_that.senderId,_that.sender,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String? senderId,  UserSummary? sender,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  List<Attachment> attachments,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  MessageStatus status)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessage() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.sender,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _ChatMessage implements ChatMessage {
  const _ChatMessage({required this.id, required this.roomId, this.senderId, this.sender, this.body, this.isDeleted = false, this.replyToId, this.replyToBody, this.replyToSenderUsername, final  List<Attachment> attachments = const <Attachment>[], this.clientId, this.editedAt, required this.createdAt, this.cursor, this.status = MessageStatus.sent}): _attachments = attachments;
  

@override final  String id;
@override final  String roomId;
@override final  String? senderId;
@override final  UserSummary? sender;
/// null jika pesan dihapus.
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

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageCopyWith<_ChatMessage> get copyWith => __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,roomId,senderId,sender,body,isDeleted,replyToId,replyToBody,replyToSenderUsername,const DeepCollectionEquality().hash(_attachments),clientId,editedAt,createdAt,cursor,status);

@override
String toString() {
  return 'ChatMessage(id: $id, roomId: $roomId, senderId: $senderId, sender: $sender, body: $body, isDeleted: $isDeleted, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, attachments: $attachments, clientId: $clientId, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res> implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(_ChatMessage value, $Res Function(_ChatMessage) _then) = __$ChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String? senderId, UserSummary? sender, String? body, bool isDeleted, String? replyToId, String? replyToBody, String? replyToSenderUsername, List<Attachment> attachments, String? clientId, DateTime? editedAt, DateTime createdAt, String? cursor, MessageStatus status
});


@override $UserSummaryCopyWith<$Res>? get sender;

}
/// @nodoc
class __$ChatMessageCopyWithImpl<$Res>
    implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

/// Create a copy of ChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? sender = freezed,Object? body = freezed,Object? isDeleted = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? attachments = null,Object? clientId = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = freezed,Object? status = null,}) {
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
as MessageStatus,
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
}
}

/// @nodoc
mixin _$RoomMember {

 UserSummary get user; MemberRole get role; DateTime get lastReadAt; DateTime get joinedAt;
/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomMemberCopyWith<RoomMember> get copyWith => _$RoomMemberCopyWithImpl<RoomMember>(this as RoomMember, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomMember&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}


@override
int get hashCode => Object.hash(runtimeType,user,role,lastReadAt,joinedAt);

@override
String toString() {
  return 'RoomMember(user: $user, role: $role, lastReadAt: $lastReadAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $RoomMemberCopyWith<$Res>  {
  factory $RoomMemberCopyWith(RoomMember value, $Res Function(RoomMember) _then) = _$RoomMemberCopyWithImpl;
@useResult
$Res call({
 UserSummary user, MemberRole role, DateTime lastReadAt, DateTime joinedAt
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$RoomMemberCopyWithImpl<$Res>
    implements $RoomMemberCopyWith<$Res> {
  _$RoomMemberCopyWithImpl(this._self, this._then);

  final RoomMember _self;
  final $Res Function(RoomMember) _then;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? role = null,Object? lastReadAt = null,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MemberRole,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomMember].
extension RoomMemberPatterns on RoomMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomMember value)  $default,){
final _that = this;
switch (_that) {
case _RoomMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomMember value)?  $default,){
final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  MemberRole role,  DateTime lastReadAt,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
return $default(_that.user,_that.role,_that.lastReadAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  MemberRole role,  DateTime lastReadAt,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _RoomMember():
return $default(_that.user,_that.role,_that.lastReadAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  MemberRole role,  DateTime lastReadAt,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
return $default(_that.user,_that.role,_that.lastReadAt,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc


class _RoomMember implements RoomMember {
  const _RoomMember({required this.user, this.role = MemberRole.member, required this.lastReadAt, required this.joinedAt});
  

@override final  UserSummary user;
@override@JsonKey() final  MemberRole role;
@override final  DateTime lastReadAt;
@override final  DateTime joinedAt;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomMemberCopyWith<_RoomMember> get copyWith => __$RoomMemberCopyWithImpl<_RoomMember>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomMember&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}


@override
int get hashCode => Object.hash(runtimeType,user,role,lastReadAt,joinedAt);

@override
String toString() {
  return 'RoomMember(user: $user, role: $role, lastReadAt: $lastReadAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$RoomMemberCopyWith<$Res> implements $RoomMemberCopyWith<$Res> {
  factory _$RoomMemberCopyWith(_RoomMember value, $Res Function(_RoomMember) _then) = __$RoomMemberCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, MemberRole role, DateTime lastReadAt, DateTime joinedAt
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$RoomMemberCopyWithImpl<$Res>
    implements _$RoomMemberCopyWith<$Res> {
  __$RoomMemberCopyWithImpl(this._self, this._then);

  final _RoomMember _self;
  final $Res Function(_RoomMember) _then;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? role = null,Object? lastReadAt = null,Object? joinedAt = null,}) {
  return _then(_RoomMember(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MemberRole,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
