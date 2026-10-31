// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_room.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatRoom {

 String get id; RoomType get type; String? get name; String? get stockCode; DateTime? get lastMessageAt; String? get lastMessagePreview; String? get lastMessageSenderId; ReceiptStatus? get lastMessageStatus; DateTime get createdAt; MemberRole get myRole; bool get muted; DateTime get lastReadAt; int get unreadCount; int get memberCount; UserSummary? get otherUser;
/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatRoomCopyWith<ChatRoom> get copyWith => _$ChatRoomCopyWithImpl<ChatRoom>(this as ChatRoom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.lastMessageStatus, lastMessageStatus) || other.lastMessageStatus == lastMessageStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.otherUser, otherUser) || other.otherUser == otherUser));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,name,stockCode,lastMessageAt,lastMessagePreview,lastMessageSenderId,lastMessageStatus,createdAt,myRole,muted,lastReadAt,unreadCount,memberCount,otherUser);

@override
String toString() {
  return 'ChatRoom(id: $id, type: $type, name: $name, stockCode: $stockCode, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, lastMessageSenderId: $lastMessageSenderId, lastMessageStatus: $lastMessageStatus, createdAt: $createdAt, myRole: $myRole, muted: $muted, lastReadAt: $lastReadAt, unreadCount: $unreadCount, memberCount: $memberCount, otherUser: $otherUser)';
}


}

/// @nodoc
abstract mixin class $ChatRoomCopyWith<$Res>  {
  factory $ChatRoomCopyWith(ChatRoom value, $Res Function(ChatRoom) _then) = _$ChatRoomCopyWithImpl;
@useResult
$Res call({
 String id, RoomType type, String? name, String? stockCode, DateTime? lastMessageAt, String? lastMessagePreview, String? lastMessageSenderId, ReceiptStatus? lastMessageStatus, DateTime createdAt, MemberRole myRole, bool muted, DateTime lastReadAt, int unreadCount, int memberCount, UserSummary? otherUser
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? name = freezed,Object? stockCode = freezed,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? lastMessageSenderId = freezed,Object? lastMessageStatus = freezed,Object? createdAt = null,Object? myRole = null,Object? muted = null,Object? lastReadAt = null,Object? unreadCount = null,Object? memberCount = null,Object? otherUser = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RoomType,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,lastMessageStatus: freezed == lastMessageStatus ? _self.lastMessageStatus : lastMessageStatus // ignore: cast_nullable_to_non_nullable
as ReceiptStatus?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  RoomType type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  ReceiptStatus? lastMessageStatus,  DateTime createdAt,  MemberRole myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  UserSummary? otherUser)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatRoom() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.lastMessageStatus,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUser);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  RoomType type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  ReceiptStatus? lastMessageStatus,  DateTime createdAt,  MemberRole myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  UserSummary? otherUser)  $default,) {final _that = this;
switch (_that) {
case _ChatRoom():
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.lastMessageStatus,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUser);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  RoomType type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  ReceiptStatus? lastMessageStatus,  DateTime createdAt,  MemberRole myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  UserSummary? otherUser)?  $default,) {final _that = this;
switch (_that) {
case _ChatRoom() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.lastMessageStatus,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUser);case _:
  return null;

}
}

}

/// @nodoc


class _ChatRoom extends ChatRoom {
  const _ChatRoom({required this.id, required this.type, this.name, this.stockCode, this.lastMessageAt, this.lastMessagePreview, this.lastMessageSenderId, this.lastMessageStatus, required this.createdAt, this.myRole = MemberRole.member, this.muted = false, required this.lastReadAt, this.unreadCount = 0, this.memberCount = 0, this.otherUser}): super._();
  

@override final  String id;
@override final  RoomType type;
@override final  String? name;
@override final  String? stockCode;
@override final  DateTime? lastMessageAt;
@override final  String? lastMessagePreview;
@override final  String? lastMessageSenderId;
@override final  ReceiptStatus? lastMessageStatus;
@override final  DateTime createdAt;
@override@JsonKey() final  MemberRole myRole;
@override@JsonKey() final  bool muted;
@override final  DateTime lastReadAt;
@override@JsonKey() final  int unreadCount;
@override@JsonKey() final  int memberCount;
@override final  UserSummary? otherUser;

/// Create a copy of ChatRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatRoomCopyWith<_ChatRoom> get copyWith => __$ChatRoomCopyWithImpl<_ChatRoom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.lastMessageStatus, lastMessageStatus) || other.lastMessageStatus == lastMessageStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.otherUser, otherUser) || other.otherUser == otherUser));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,name,stockCode,lastMessageAt,lastMessagePreview,lastMessageSenderId,lastMessageStatus,createdAt,myRole,muted,lastReadAt,unreadCount,memberCount,otherUser);

@override
String toString() {
  return 'ChatRoom(id: $id, type: $type, name: $name, stockCode: $stockCode, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, lastMessageSenderId: $lastMessageSenderId, lastMessageStatus: $lastMessageStatus, createdAt: $createdAt, myRole: $myRole, muted: $muted, lastReadAt: $lastReadAt, unreadCount: $unreadCount, memberCount: $memberCount, otherUser: $otherUser)';
}


}

/// @nodoc
abstract mixin class _$ChatRoomCopyWith<$Res> implements $ChatRoomCopyWith<$Res> {
  factory _$ChatRoomCopyWith(_ChatRoom value, $Res Function(_ChatRoom) _then) = __$ChatRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, RoomType type, String? name, String? stockCode, DateTime? lastMessageAt, String? lastMessagePreview, String? lastMessageSenderId, ReceiptStatus? lastMessageStatus, DateTime createdAt, MemberRole myRole, bool muted, DateTime lastReadAt, int unreadCount, int memberCount, UserSummary? otherUser
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? name = freezed,Object? stockCode = freezed,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? lastMessageSenderId = freezed,Object? lastMessageStatus = freezed,Object? createdAt = null,Object? myRole = null,Object? muted = null,Object? lastReadAt = null,Object? unreadCount = null,Object? memberCount = null,Object? otherUser = freezed,}) {
  return _then(_ChatRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RoomType,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,lastMessageStatus: freezed == lastMessageStatus ? _self.lastMessageStatus : lastMessageStatus // ignore: cast_nullable_to_non_nullable
as ReceiptStatus?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
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
mixin _$RoomMember {

 UserSummary get user; MemberRole get role; DateTime get lastReadAt; DateTime get lastDeliveredAt; DateTime get joinedAt;
/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomMemberCopyWith<RoomMember> get copyWith => _$RoomMemberCopyWithImpl<RoomMember>(this as RoomMember, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomMember&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastDeliveredAt, lastDeliveredAt) || other.lastDeliveredAt == lastDeliveredAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}


@override
int get hashCode => Object.hash(runtimeType,user,role,lastReadAt,lastDeliveredAt,joinedAt);

@override
String toString() {
  return 'RoomMember(user: $user, role: $role, lastReadAt: $lastReadAt, lastDeliveredAt: $lastDeliveredAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $RoomMemberCopyWith<$Res>  {
  factory $RoomMemberCopyWith(RoomMember value, $Res Function(RoomMember) _then) = _$RoomMemberCopyWithImpl;
@useResult
$Res call({
 UserSummary user, MemberRole role, DateTime lastReadAt, DateTime lastDeliveredAt, DateTime joinedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? role = null,Object? lastReadAt = null,Object? lastDeliveredAt = null,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MemberRole,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastDeliveredAt: null == lastDeliveredAt ? _self.lastDeliveredAt : lastDeliveredAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  MemberRole role,  DateTime lastReadAt,  DateTime lastDeliveredAt,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
return $default(_that.user,_that.role,_that.lastReadAt,_that.lastDeliveredAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  MemberRole role,  DateTime lastReadAt,  DateTime lastDeliveredAt,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _RoomMember():
return $default(_that.user,_that.role,_that.lastReadAt,_that.lastDeliveredAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  MemberRole role,  DateTime lastReadAt,  DateTime lastDeliveredAt,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
return $default(_that.user,_that.role,_that.lastReadAt,_that.lastDeliveredAt,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc


class _RoomMember extends RoomMember {
  const _RoomMember({required this.user, this.role = MemberRole.member, required this.lastReadAt, required this.lastDeliveredAt, required this.joinedAt}): super._();
  

@override final  UserSummary user;
@override@JsonKey() final  MemberRole role;
@override final  DateTime lastReadAt;
@override final  DateTime lastDeliveredAt;
@override final  DateTime joinedAt;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomMemberCopyWith<_RoomMember> get copyWith => __$RoomMemberCopyWithImpl<_RoomMember>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomMember&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastDeliveredAt, lastDeliveredAt) || other.lastDeliveredAt == lastDeliveredAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}


@override
int get hashCode => Object.hash(runtimeType,user,role,lastReadAt,lastDeliveredAt,joinedAt);

@override
String toString() {
  return 'RoomMember(user: $user, role: $role, lastReadAt: $lastReadAt, lastDeliveredAt: $lastDeliveredAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$RoomMemberCopyWith<$Res> implements $RoomMemberCopyWith<$Res> {
  factory _$RoomMemberCopyWith(_RoomMember value, $Res Function(_RoomMember) _then) = __$RoomMemberCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, MemberRole role, DateTime lastReadAt, DateTime lastDeliveredAt, DateTime joinedAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? role = null,Object? lastReadAt = null,Object? lastDeliveredAt = null,Object? joinedAt = null,}) {
  return _then(_RoomMember(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MemberRole,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastDeliveredAt: null == lastDeliveredAt ? _self.lastDeliveredAt : lastDeliveredAt // ignore: cast_nullable_to_non_nullable
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
