// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_request_room_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MessageRequestRoomState {

 LoadStatus get status; List<ChatMessage> get messages; MessageRequestAction? get responding; MessageRequestAction? get completed; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of MessageRequestRoomState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageRequestRoomStateCopyWith<MessageRequestRoomState> get copyWith => _$MessageRequestRoomStateCopyWithImpl<MessageRequestRoomState>(this as MessageRequestRoomState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageRequestRoomState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.responding, responding) || other.responding == responding)&&(identical(other.completed, completed) || other.completed == completed)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(messages),responding,completed,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'MessageRequestRoomState(status: $status, messages: $messages, responding: $responding, completed: $completed, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $MessageRequestRoomStateCopyWith<$Res>  {
  factory $MessageRequestRoomStateCopyWith(MessageRequestRoomState value, $Res Function(MessageRequestRoomState) _then) = _$MessageRequestRoomStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<ChatMessage> messages, MessageRequestAction? responding, MessageRequestAction? completed, Object? error, Object? actionError, int actionErrorId
});




}
/// @nodoc
class _$MessageRequestRoomStateCopyWithImpl<$Res>
    implements $MessageRequestRoomStateCopyWith<$Res> {
  _$MessageRequestRoomStateCopyWithImpl(this._self, this._then);

  final MessageRequestRoomState _self;
  final $Res Function(MessageRequestRoomState) _then;

/// Create a copy of MessageRequestRoomState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? messages = null,Object? responding = freezed,Object? completed = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,responding: freezed == responding ? _self.responding : responding // ignore: cast_nullable_to_non_nullable
as MessageRequestAction?,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as MessageRequestAction?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageRequestRoomState].
extension MessageRequestRoomStatePatterns on MessageRequestRoomState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageRequestRoomState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageRequestRoomState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageRequestRoomState value)  $default,){
final _that = this;
switch (_that) {
case _MessageRequestRoomState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageRequestRoomState value)?  $default,){
final _that = this;
switch (_that) {
case _MessageRequestRoomState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<ChatMessage> messages,  MessageRequestAction? responding,  MessageRequestAction? completed,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageRequestRoomState() when $default != null:
return $default(_that.status,_that.messages,_that.responding,_that.completed,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<ChatMessage> messages,  MessageRequestAction? responding,  MessageRequestAction? completed,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _MessageRequestRoomState():
return $default(_that.status,_that.messages,_that.responding,_that.completed,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<ChatMessage> messages,  MessageRequestAction? responding,  MessageRequestAction? completed,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _MessageRequestRoomState() when $default != null:
return $default(_that.status,_that.messages,_that.responding,_that.completed,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _MessageRequestRoomState implements MessageRequestRoomState {
  const _MessageRequestRoomState({this.status = LoadStatus.initial, final  List<ChatMessage> messages = const <ChatMessage>[], this.responding, this.completed, this.error, this.actionError, this.actionErrorId = 0}): _messages = messages;
  

@override@JsonKey() final  LoadStatus status;
 final  List<ChatMessage> _messages;
@override@JsonKey() List<ChatMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override final  MessageRequestAction? responding;
@override final  MessageRequestAction? completed;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of MessageRequestRoomState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageRequestRoomStateCopyWith<_MessageRequestRoomState> get copyWith => __$MessageRequestRoomStateCopyWithImpl<_MessageRequestRoomState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageRequestRoomState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.responding, responding) || other.responding == responding)&&(identical(other.completed, completed) || other.completed == completed)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_messages),responding,completed,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'MessageRequestRoomState(status: $status, messages: $messages, responding: $responding, completed: $completed, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$MessageRequestRoomStateCopyWith<$Res> implements $MessageRequestRoomStateCopyWith<$Res> {
  factory _$MessageRequestRoomStateCopyWith(_MessageRequestRoomState value, $Res Function(_MessageRequestRoomState) _then) = __$MessageRequestRoomStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<ChatMessage> messages, MessageRequestAction? responding, MessageRequestAction? completed, Object? error, Object? actionError, int actionErrorId
});




}
/// @nodoc
class __$MessageRequestRoomStateCopyWithImpl<$Res>
    implements _$MessageRequestRoomStateCopyWith<$Res> {
  __$MessageRequestRoomStateCopyWithImpl(this._self, this._then);

  final _MessageRequestRoomState _self;
  final $Res Function(_MessageRequestRoomState) _then;

/// Create a copy of MessageRequestRoomState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? messages = null,Object? responding = freezed,Object? completed = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_MessageRequestRoomState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,responding: freezed == responding ? _self.responding : responding // ignore: cast_nullable_to_non_nullable
as MessageRequestAction?,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as MessageRequestAction?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
