// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_room_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatRoomState {

 LoadStatus get status; ChatRoom? get room; UserSummary? get me; List<ChatMessage> get messages; String? get nextCursor; bool get loadingOlder; Map<String, RoomMember> get members; Map<String, UserSummary> get typing; Set<String> get online; RealtimeStatus get connection; ChatMessage? get replyTo; bool get uploading; Object? get error; Object? get actionError; int get actionErrorId; StockRoomState? get stockRoom; DateTime? get cooldownUntil; bool get dmRequestLimited; DmRequestState? get dmRequest; bool get stale;
/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatRoomStateCopyWith<ChatRoomState> get copyWith => _$ChatRoomStateCopyWithImpl<ChatRoomState>(this as ChatRoomState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatRoomState&&(identical(other.status, status) || other.status == status)&&(identical(other.room, room) || other.room == room)&&(identical(other.me, me) || other.me == me)&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingOlder, loadingOlder) || other.loadingOlder == loadingOlder)&&const DeepCollectionEquality().equals(other.members, members)&&const DeepCollectionEquality().equals(other.typing, typing)&&const DeepCollectionEquality().equals(other.online, online)&&(identical(other.connection, connection) || other.connection == connection)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&(identical(other.uploading, uploading) || other.uploading == uploading)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.stockRoom, stockRoom) || other.stockRoom == stockRoom)&&(identical(other.cooldownUntil, cooldownUntil) || other.cooldownUntil == cooldownUntil)&&(identical(other.dmRequestLimited, dmRequestLimited) || other.dmRequestLimited == dmRequestLimited)&&(identical(other.dmRequest, dmRequest) || other.dmRequest == dmRequest)&&(identical(other.stale, stale) || other.stale == stale));
}


@override
int get hashCode => Object.hashAll([runtimeType,status,room,me,const DeepCollectionEquality().hash(messages),nextCursor,loadingOlder,const DeepCollectionEquality().hash(members),const DeepCollectionEquality().hash(typing),const DeepCollectionEquality().hash(online),connection,replyTo,uploading,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,stockRoom,cooldownUntil,dmRequestLimited,dmRequest,stale]);

@override
String toString() {
  return 'ChatRoomState(status: $status, room: $room, me: $me, messages: $messages, nextCursor: $nextCursor, loadingOlder: $loadingOlder, members: $members, typing: $typing, online: $online, connection: $connection, replyTo: $replyTo, uploading: $uploading, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, stockRoom: $stockRoom, cooldownUntil: $cooldownUntil, dmRequestLimited: $dmRequestLimited, dmRequest: $dmRequest, stale: $stale)';
}


}

/// @nodoc
abstract mixin class $ChatRoomStateCopyWith<$Res>  {
  factory $ChatRoomStateCopyWith(ChatRoomState value, $Res Function(ChatRoomState) _then) = _$ChatRoomStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ChatRoom? room, UserSummary? me, List<ChatMessage> messages, String? nextCursor, bool loadingOlder, Map<String, RoomMember> members, Map<String, UserSummary> typing, Set<String> online, RealtimeStatus connection, ChatMessage? replyTo, bool uploading, Object? error, Object? actionError, int actionErrorId, StockRoomState? stockRoom, DateTime? cooldownUntil, bool dmRequestLimited, DmRequestState? dmRequest, bool stale
});


$ChatRoomCopyWith<$Res>? get room;$UserSummaryCopyWith<$Res>? get me;$ChatMessageCopyWith<$Res>? get replyTo;$StockRoomStateCopyWith<$Res>? get stockRoom;$DmRequestStateCopyWith<$Res>? get dmRequest;

}
/// @nodoc
class _$ChatRoomStateCopyWithImpl<$Res>
    implements $ChatRoomStateCopyWith<$Res> {
  _$ChatRoomStateCopyWithImpl(this._self, this._then);

  final ChatRoomState _self;
  final $Res Function(ChatRoomState) _then;

/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? room = freezed,Object? me = freezed,Object? messages = null,Object? nextCursor = freezed,Object? loadingOlder = null,Object? members = null,Object? typing = null,Object? online = null,Object? connection = null,Object? replyTo = freezed,Object? uploading = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? stockRoom = freezed,Object? cooldownUntil = freezed,Object? dmRequestLimited = null,Object? dmRequest = freezed,Object? stale = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,room: freezed == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as ChatRoom?,me: freezed == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as UserSummary?,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingOlder: null == loadingOlder ? _self.loadingOlder : loadingOlder // ignore: cast_nullable_to_non_nullable
as bool,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as Map<String, RoomMember>,typing: null == typing ? _self.typing : typing // ignore: cast_nullable_to_non_nullable
as Map<String, UserSummary>,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as Set<String>,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as RealtimeStatus,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as ChatMessage?,uploading: null == uploading ? _self.uploading : uploading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,stockRoom: freezed == stockRoom ? _self.stockRoom : stockRoom // ignore: cast_nullable_to_non_nullable
as StockRoomState?,cooldownUntil: freezed == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,dmRequestLimited: null == dmRequestLimited ? _self.dmRequestLimited : dmRequestLimited // ignore: cast_nullable_to_non_nullable
as bool,dmRequest: freezed == dmRequest ? _self.dmRequest : dmRequest // ignore: cast_nullable_to_non_nullable
as DmRequestState?,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatRoomCopyWith<$Res>? get room {
    if (_self.room == null) {
    return null;
  }

  return $ChatRoomCopyWith<$Res>(_self.room!, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get me {
    if (_self.me == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.me!, (value) {
    return _then(_self.copyWith(me: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $ChatMessageCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StockRoomStateCopyWith<$Res>? get stockRoom {
    if (_self.stockRoom == null) {
    return null;
  }

  return $StockRoomStateCopyWith<$Res>(_self.stockRoom!, (value) {
    return _then(_self.copyWith(stockRoom: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DmRequestStateCopyWith<$Res>? get dmRequest {
    if (_self.dmRequest == null) {
    return null;
  }

  return $DmRequestStateCopyWith<$Res>(_self.dmRequest!, (value) {
    return _then(_self.copyWith(dmRequest: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatRoomState].
extension ChatRoomStatePatterns on ChatRoomState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatRoomState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatRoomState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatRoomState value)  $default,){
final _that = this;
switch (_that) {
case _ChatRoomState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatRoomState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatRoomState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ChatRoom? room,  UserSummary? me,  List<ChatMessage> messages,  String? nextCursor,  bool loadingOlder,  Map<String, RoomMember> members,  Map<String, UserSummary> typing,  Set<String> online,  RealtimeStatus connection,  ChatMessage? replyTo,  bool uploading,  Object? error,  Object? actionError,  int actionErrorId,  StockRoomState? stockRoom,  DateTime? cooldownUntil,  bool dmRequestLimited,  DmRequestState? dmRequest,  bool stale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatRoomState() when $default != null:
return $default(_that.status,_that.room,_that.me,_that.messages,_that.nextCursor,_that.loadingOlder,_that.members,_that.typing,_that.online,_that.connection,_that.replyTo,_that.uploading,_that.error,_that.actionError,_that.actionErrorId,_that.stockRoom,_that.cooldownUntil,_that.dmRequestLimited,_that.dmRequest,_that.stale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ChatRoom? room,  UserSummary? me,  List<ChatMessage> messages,  String? nextCursor,  bool loadingOlder,  Map<String, RoomMember> members,  Map<String, UserSummary> typing,  Set<String> online,  RealtimeStatus connection,  ChatMessage? replyTo,  bool uploading,  Object? error,  Object? actionError,  int actionErrorId,  StockRoomState? stockRoom,  DateTime? cooldownUntil,  bool dmRequestLimited,  DmRequestState? dmRequest,  bool stale)  $default,) {final _that = this;
switch (_that) {
case _ChatRoomState():
return $default(_that.status,_that.room,_that.me,_that.messages,_that.nextCursor,_that.loadingOlder,_that.members,_that.typing,_that.online,_that.connection,_that.replyTo,_that.uploading,_that.error,_that.actionError,_that.actionErrorId,_that.stockRoom,_that.cooldownUntil,_that.dmRequestLimited,_that.dmRequest,_that.stale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ChatRoom? room,  UserSummary? me,  List<ChatMessage> messages,  String? nextCursor,  bool loadingOlder,  Map<String, RoomMember> members,  Map<String, UserSummary> typing,  Set<String> online,  RealtimeStatus connection,  ChatMessage? replyTo,  bool uploading,  Object? error,  Object? actionError,  int actionErrorId,  StockRoomState? stockRoom,  DateTime? cooldownUntil,  bool dmRequestLimited,  DmRequestState? dmRequest,  bool stale)?  $default,) {final _that = this;
switch (_that) {
case _ChatRoomState() when $default != null:
return $default(_that.status,_that.room,_that.me,_that.messages,_that.nextCursor,_that.loadingOlder,_that.members,_that.typing,_that.online,_that.connection,_that.replyTo,_that.uploading,_that.error,_that.actionError,_that.actionErrorId,_that.stockRoom,_that.cooldownUntil,_that.dmRequestLimited,_that.dmRequest,_that.stale);case _:
  return null;

}
}

}

/// @nodoc


class _ChatRoomState extends ChatRoomState {
  const _ChatRoomState({this.status = LoadStatus.initial, this.room, this.me, final  List<ChatMessage> messages = const <ChatMessage>[], this.nextCursor, this.loadingOlder = false, final  Map<String, RoomMember> members = const <String, RoomMember>{}, final  Map<String, UserSummary> typing = const <String, UserSummary>{}, final  Set<String> online = const <String>{}, this.connection = RealtimeStatus.connecting, this.replyTo, this.uploading = false, this.error, this.actionError, this.actionErrorId = 0, this.stockRoom, this.cooldownUntil, this.dmRequestLimited = false, this.dmRequest, this.stale = false}): _messages = messages,_members = members,_typing = typing,_online = online,super._();
  

@override@JsonKey() final  LoadStatus status;
@override final  ChatRoom? room;
@override final  UserSummary? me;
 final  List<ChatMessage> _messages;
@override@JsonKey() List<ChatMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool loadingOlder;
 final  Map<String, RoomMember> _members;
@override@JsonKey() Map<String, RoomMember> get members {
  if (_members is EqualUnmodifiableMapView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_members);
}

 final  Map<String, UserSummary> _typing;
@override@JsonKey() Map<String, UserSummary> get typing {
  if (_typing is EqualUnmodifiableMapView) return _typing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_typing);
}

 final  Set<String> _online;
@override@JsonKey() Set<String> get online {
  if (_online is EqualUnmodifiableSetView) return _online;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_online);
}

@override@JsonKey() final  RealtimeStatus connection;
@override final  ChatMessage? replyTo;
@override@JsonKey() final  bool uploading;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;
@override final  StockRoomState? stockRoom;
@override final  DateTime? cooldownUntil;
@override@JsonKey() final  bool dmRequestLimited;
@override final  DmRequestState? dmRequest;
@override@JsonKey() final  bool stale;

/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatRoomStateCopyWith<_ChatRoomState> get copyWith => __$ChatRoomStateCopyWithImpl<_ChatRoomState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatRoomState&&(identical(other.status, status) || other.status == status)&&(identical(other.room, room) || other.room == room)&&(identical(other.me, me) || other.me == me)&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingOlder, loadingOlder) || other.loadingOlder == loadingOlder)&&const DeepCollectionEquality().equals(other._members, _members)&&const DeepCollectionEquality().equals(other._typing, _typing)&&const DeepCollectionEquality().equals(other._online, _online)&&(identical(other.connection, connection) || other.connection == connection)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&(identical(other.uploading, uploading) || other.uploading == uploading)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.stockRoom, stockRoom) || other.stockRoom == stockRoom)&&(identical(other.cooldownUntil, cooldownUntil) || other.cooldownUntil == cooldownUntil)&&(identical(other.dmRequestLimited, dmRequestLimited) || other.dmRequestLimited == dmRequestLimited)&&(identical(other.dmRequest, dmRequest) || other.dmRequest == dmRequest)&&(identical(other.stale, stale) || other.stale == stale));
}


@override
int get hashCode => Object.hashAll([runtimeType,status,room,me,const DeepCollectionEquality().hash(_messages),nextCursor,loadingOlder,const DeepCollectionEquality().hash(_members),const DeepCollectionEquality().hash(_typing),const DeepCollectionEquality().hash(_online),connection,replyTo,uploading,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,stockRoom,cooldownUntil,dmRequestLimited,dmRequest,stale]);

@override
String toString() {
  return 'ChatRoomState(status: $status, room: $room, me: $me, messages: $messages, nextCursor: $nextCursor, loadingOlder: $loadingOlder, members: $members, typing: $typing, online: $online, connection: $connection, replyTo: $replyTo, uploading: $uploading, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, stockRoom: $stockRoom, cooldownUntil: $cooldownUntil, dmRequestLimited: $dmRequestLimited, dmRequest: $dmRequest, stale: $stale)';
}


}

/// @nodoc
abstract mixin class _$ChatRoomStateCopyWith<$Res> implements $ChatRoomStateCopyWith<$Res> {
  factory _$ChatRoomStateCopyWith(_ChatRoomState value, $Res Function(_ChatRoomState) _then) = __$ChatRoomStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ChatRoom? room, UserSummary? me, List<ChatMessage> messages, String? nextCursor, bool loadingOlder, Map<String, RoomMember> members, Map<String, UserSummary> typing, Set<String> online, RealtimeStatus connection, ChatMessage? replyTo, bool uploading, Object? error, Object? actionError, int actionErrorId, StockRoomState? stockRoom, DateTime? cooldownUntil, bool dmRequestLimited, DmRequestState? dmRequest, bool stale
});


@override $ChatRoomCopyWith<$Res>? get room;@override $UserSummaryCopyWith<$Res>? get me;@override $ChatMessageCopyWith<$Res>? get replyTo;@override $StockRoomStateCopyWith<$Res>? get stockRoom;@override $DmRequestStateCopyWith<$Res>? get dmRequest;

}
/// @nodoc
class __$ChatRoomStateCopyWithImpl<$Res>
    implements _$ChatRoomStateCopyWith<$Res> {
  __$ChatRoomStateCopyWithImpl(this._self, this._then);

  final _ChatRoomState _self;
  final $Res Function(_ChatRoomState) _then;

/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? room = freezed,Object? me = freezed,Object? messages = null,Object? nextCursor = freezed,Object? loadingOlder = null,Object? members = null,Object? typing = null,Object? online = null,Object? connection = null,Object? replyTo = freezed,Object? uploading = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? stockRoom = freezed,Object? cooldownUntil = freezed,Object? dmRequestLimited = null,Object? dmRequest = freezed,Object? stale = null,}) {
  return _then(_ChatRoomState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,room: freezed == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as ChatRoom?,me: freezed == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as UserSummary?,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingOlder: null == loadingOlder ? _self.loadingOlder : loadingOlder // ignore: cast_nullable_to_non_nullable
as bool,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as Map<String, RoomMember>,typing: null == typing ? _self._typing : typing // ignore: cast_nullable_to_non_nullable
as Map<String, UserSummary>,online: null == online ? _self._online : online // ignore: cast_nullable_to_non_nullable
as Set<String>,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as RealtimeStatus,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as ChatMessage?,uploading: null == uploading ? _self.uploading : uploading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,stockRoom: freezed == stockRoom ? _self.stockRoom : stockRoom // ignore: cast_nullable_to_non_nullable
as StockRoomState?,cooldownUntil: freezed == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,dmRequestLimited: null == dmRequestLimited ? _self.dmRequestLimited : dmRequestLimited // ignore: cast_nullable_to_non_nullable
as bool,dmRequest: freezed == dmRequest ? _self.dmRequest : dmRequest // ignore: cast_nullable_to_non_nullable
as DmRequestState?,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatRoomCopyWith<$Res>? get room {
    if (_self.room == null) {
    return null;
  }

  return $ChatRoomCopyWith<$Res>(_self.room!, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get me {
    if (_self.me == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.me!, (value) {
    return _then(_self.copyWith(me: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $ChatMessageCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StockRoomStateCopyWith<$Res>? get stockRoom {
    if (_self.stockRoom == null) {
    return null;
  }

  return $StockRoomStateCopyWith<$Res>(_self.stockRoom!, (value) {
    return _then(_self.copyWith(stockRoom: value));
  });
}/// Create a copy of ChatRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DmRequestStateCopyWith<$Res>? get dmRequest {
    if (_self.dmRequest == null) {
    return null;
  }

  return $DmRequestStateCopyWith<$Res>(_self.dmRequest!, (value) {
    return _then(_self.copyWith(dmRequest: value));
  });
}
}

// dart format on
