// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'outbox_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OutboxMessage {

 String get clientId; String get roomId; String get body; String? get replyToId; String? get replyToBody; String? get replyToSenderUsername; DateTime get createdAt; OutboxState get state; int get attempts; DateTime? get nextAttemptAt; CommunityException? get error;
/// Create a copy of OutboxMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutboxMessageCopyWith<OutboxMessage> get copyWith => _$OutboxMessageCopyWithImpl<OutboxMessage>(this as OutboxMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboxMessage&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.body, body) || other.body == body)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.state, state) || other.state == state)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.nextAttemptAt, nextAttemptAt) || other.nextAttemptAt == nextAttemptAt)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,clientId,roomId,body,replyToId,replyToBody,replyToSenderUsername,createdAt,state,attempts,nextAttemptAt,error);

@override
String toString() {
  return 'OutboxMessage(clientId: $clientId, roomId: $roomId, body: $body, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, createdAt: $createdAt, state: $state, attempts: $attempts, nextAttemptAt: $nextAttemptAt, error: $error)';
}


}

/// @nodoc
abstract mixin class $OutboxMessageCopyWith<$Res>  {
  factory $OutboxMessageCopyWith(OutboxMessage value, $Res Function(OutboxMessage) _then) = _$OutboxMessageCopyWithImpl;
@useResult
$Res call({
 String clientId, String roomId, String body, String? replyToId, String? replyToBody, String? replyToSenderUsername, DateTime createdAt, OutboxState state, int attempts, DateTime? nextAttemptAt, CommunityException? error
});




}
/// @nodoc
class _$OutboxMessageCopyWithImpl<$Res>
    implements $OutboxMessageCopyWith<$Res> {
  _$OutboxMessageCopyWithImpl(this._self, this._then);

  final OutboxMessage _self;
  final $Res Function(OutboxMessage) _then;

/// Create a copy of OutboxMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientId = null,Object? roomId = null,Object? body = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? createdAt = null,Object? state = null,Object? attempts = null,Object? nextAttemptAt = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToBody: freezed == replyToBody ? _self.replyToBody : replyToBody // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderUsername: freezed == replyToSenderUsername ? _self.replyToSenderUsername : replyToSenderUsername // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as OutboxState,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,nextAttemptAt: freezed == nextAttemptAt ? _self.nextAttemptAt : nextAttemptAt // ignore: cast_nullable_to_non_nullable
as DateTime?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as CommunityException?,
  ));
}

}


/// Adds pattern-matching-related methods to [OutboxMessage].
extension OutboxMessagePatterns on OutboxMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OutboxMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OutboxMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OutboxMessage value)  $default,){
final _that = this;
switch (_that) {
case _OutboxMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OutboxMessage value)?  $default,){
final _that = this;
switch (_that) {
case _OutboxMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clientId,  String roomId,  String body,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  DateTime createdAt,  OutboxState state,  int attempts,  DateTime? nextAttemptAt,  CommunityException? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OutboxMessage() when $default != null:
return $default(_that.clientId,_that.roomId,_that.body,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.createdAt,_that.state,_that.attempts,_that.nextAttemptAt,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clientId,  String roomId,  String body,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  DateTime createdAt,  OutboxState state,  int attempts,  DateTime? nextAttemptAt,  CommunityException? error)  $default,) {final _that = this;
switch (_that) {
case _OutboxMessage():
return $default(_that.clientId,_that.roomId,_that.body,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.createdAt,_that.state,_that.attempts,_that.nextAttemptAt,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clientId,  String roomId,  String body,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername,  DateTime createdAt,  OutboxState state,  int attempts,  DateTime? nextAttemptAt,  CommunityException? error)?  $default,) {final _that = this;
switch (_that) {
case _OutboxMessage() when $default != null:
return $default(_that.clientId,_that.roomId,_that.body,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.createdAt,_that.state,_that.attempts,_that.nextAttemptAt,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _OutboxMessage extends OutboxMessage {
  const _OutboxMessage({required this.clientId, required this.roomId, required this.body, this.replyToId, this.replyToBody, this.replyToSenderUsername, required this.createdAt, this.state = OutboxState.pending, this.attempts = 0, this.nextAttemptAt, this.error}): super._();
  

@override final  String clientId;
@override final  String roomId;
@override final  String body;
@override final  String? replyToId;
@override final  String? replyToBody;
@override final  String? replyToSenderUsername;
@override final  DateTime createdAt;
@override@JsonKey() final  OutboxState state;
@override@JsonKey() final  int attempts;
@override final  DateTime? nextAttemptAt;
@override final  CommunityException? error;

/// Create a copy of OutboxMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OutboxMessageCopyWith<_OutboxMessage> get copyWith => __$OutboxMessageCopyWithImpl<_OutboxMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OutboxMessage&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.body, body) || other.body == body)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.state, state) || other.state == state)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.nextAttemptAt, nextAttemptAt) || other.nextAttemptAt == nextAttemptAt)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,clientId,roomId,body,replyToId,replyToBody,replyToSenderUsername,createdAt,state,attempts,nextAttemptAt,error);

@override
String toString() {
  return 'OutboxMessage(clientId: $clientId, roomId: $roomId, body: $body, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, createdAt: $createdAt, state: $state, attempts: $attempts, nextAttemptAt: $nextAttemptAt, error: $error)';
}


}

/// @nodoc
abstract mixin class _$OutboxMessageCopyWith<$Res> implements $OutboxMessageCopyWith<$Res> {
  factory _$OutboxMessageCopyWith(_OutboxMessage value, $Res Function(_OutboxMessage) _then) = __$OutboxMessageCopyWithImpl;
@override @useResult
$Res call({
 String clientId, String roomId, String body, String? replyToId, String? replyToBody, String? replyToSenderUsername, DateTime createdAt, OutboxState state, int attempts, DateTime? nextAttemptAt, CommunityException? error
});




}
/// @nodoc
class __$OutboxMessageCopyWithImpl<$Res>
    implements _$OutboxMessageCopyWith<$Res> {
  __$OutboxMessageCopyWithImpl(this._self, this._then);

  final _OutboxMessage _self;
  final $Res Function(_OutboxMessage) _then;

/// Create a copy of OutboxMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientId = null,Object? roomId = null,Object? body = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? createdAt = null,Object? state = null,Object? attempts = null,Object? nextAttemptAt = freezed,Object? error = freezed,}) {
  return _then(_OutboxMessage(
clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToBody: freezed == replyToBody ? _self.replyToBody : replyToBody // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderUsername: freezed == replyToSenderUsername ? _self.replyToSenderUsername : replyToSenderUsername // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as OutboxState,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,nextAttemptAt: freezed == nextAttemptAt ? _self.nextAttemptAt : nextAttemptAt // ignore: cast_nullable_to_non_nullable
as DateTime?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as CommunityException?,
  ));
}


}

// dart format on
