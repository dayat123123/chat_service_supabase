// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'share_post_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SharePostState {

 LoadStatus get status; List<ChatRoom> get rooms; String? get sendingRoomId; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of SharePostState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SharePostStateCopyWith<SharePostState> get copyWith => _$SharePostStateCopyWithImpl<SharePostState>(this as SharePostState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SharePostState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.rooms, rooms)&&(identical(other.sendingRoomId, sendingRoomId) || other.sendingRoomId == sendingRoomId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(rooms),sendingRoomId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'SharePostState(status: $status, rooms: $rooms, sendingRoomId: $sendingRoomId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $SharePostStateCopyWith<$Res>  {
  factory $SharePostStateCopyWith(SharePostState value, $Res Function(SharePostState) _then) = _$SharePostStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<ChatRoom> rooms, String? sendingRoomId, Object? error, Object? actionError, int actionErrorId
});




}
/// @nodoc
class _$SharePostStateCopyWithImpl<$Res>
    implements $SharePostStateCopyWith<$Res> {
  _$SharePostStateCopyWithImpl(this._self, this._then);

  final SharePostState _self;
  final $Res Function(SharePostState) _then;

/// Create a copy of SharePostState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? rooms = null,Object? sendingRoomId = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,rooms: null == rooms ? _self.rooms : rooms // ignore: cast_nullable_to_non_nullable
as List<ChatRoom>,sendingRoomId: freezed == sendingRoomId ? _self.sendingRoomId : sendingRoomId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SharePostState].
extension SharePostStatePatterns on SharePostState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SharePostState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SharePostState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SharePostState value)  $default,){
final _that = this;
switch (_that) {
case _SharePostState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SharePostState value)?  $default,){
final _that = this;
switch (_that) {
case _SharePostState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<ChatRoom> rooms,  String? sendingRoomId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SharePostState() when $default != null:
return $default(_that.status,_that.rooms,_that.sendingRoomId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<ChatRoom> rooms,  String? sendingRoomId,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _SharePostState():
return $default(_that.status,_that.rooms,_that.sendingRoomId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<ChatRoom> rooms,  String? sendingRoomId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _SharePostState() when $default != null:
return $default(_that.status,_that.rooms,_that.sendingRoomId,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _SharePostState implements SharePostState {
  const _SharePostState({this.status = LoadStatus.initial, final  List<ChatRoom> rooms = const <ChatRoom>[], this.sendingRoomId, this.error, this.actionError, this.actionErrorId = 0}): _rooms = rooms;
  

@override@JsonKey() final  LoadStatus status;
 final  List<ChatRoom> _rooms;
@override@JsonKey() List<ChatRoom> get rooms {
  if (_rooms is EqualUnmodifiableListView) return _rooms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rooms);
}

@override final  String? sendingRoomId;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of SharePostState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SharePostStateCopyWith<_SharePostState> get copyWith => __$SharePostStateCopyWithImpl<_SharePostState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SharePostState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._rooms, _rooms)&&(identical(other.sendingRoomId, sendingRoomId) || other.sendingRoomId == sendingRoomId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_rooms),sendingRoomId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'SharePostState(status: $status, rooms: $rooms, sendingRoomId: $sendingRoomId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$SharePostStateCopyWith<$Res> implements $SharePostStateCopyWith<$Res> {
  factory _$SharePostStateCopyWith(_SharePostState value, $Res Function(_SharePostState) _then) = __$SharePostStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<ChatRoom> rooms, String? sendingRoomId, Object? error, Object? actionError, int actionErrorId
});




}
/// @nodoc
class __$SharePostStateCopyWithImpl<$Res>
    implements _$SharePostStateCopyWith<$Res> {
  __$SharePostStateCopyWithImpl(this._self, this._then);

  final _SharePostState _self;
  final $Res Function(_SharePostState) _then;

/// Create a copy of SharePostState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? rooms = null,Object? sendingRoomId = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_SharePostState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,rooms: null == rooms ? _self._rooms : rooms // ignore: cast_nullable_to_non_nullable
as List<ChatRoom>,sendingRoomId: freezed == sendingRoomId ? _self.sendingRoomId : sendingRoomId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
