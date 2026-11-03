// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_requests_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MessageRequestsState {

 LoadStatus get status; List<MessageRequest> get requests; int get count; bool get loadingMore; bool get hasMore; String? get respondingRoomId; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of MessageRequestsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageRequestsStateCopyWith<MessageRequestsState> get copyWith => _$MessageRequestsStateCopyWithImpl<MessageRequestsState>(this as MessageRequestsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageRequestsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.requests, requests)&&(identical(other.count, count) || other.count == count)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.respondingRoomId, respondingRoomId) || other.respondingRoomId == respondingRoomId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(requests),count,loadingMore,hasMore,respondingRoomId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'MessageRequestsState(status: $status, requests: $requests, count: $count, loadingMore: $loadingMore, hasMore: $hasMore, respondingRoomId: $respondingRoomId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $MessageRequestsStateCopyWith<$Res>  {
  factory $MessageRequestsStateCopyWith(MessageRequestsState value, $Res Function(MessageRequestsState) _then) = _$MessageRequestsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<MessageRequest> requests, int count, bool loadingMore, bool hasMore, String? respondingRoomId, Object? error, Object? actionError, int actionErrorId
});




}
/// @nodoc
class _$MessageRequestsStateCopyWithImpl<$Res>
    implements $MessageRequestsStateCopyWith<$Res> {
  _$MessageRequestsStateCopyWithImpl(this._self, this._then);

  final MessageRequestsState _self;
  final $Res Function(MessageRequestsState) _then;

/// Create a copy of MessageRequestsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? requests = null,Object? count = null,Object? loadingMore = null,Object? hasMore = null,Object? respondingRoomId = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,requests: null == requests ? _self.requests : requests // ignore: cast_nullable_to_non_nullable
as List<MessageRequest>,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,respondingRoomId: freezed == respondingRoomId ? _self.respondingRoomId : respondingRoomId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageRequestsState].
extension MessageRequestsStatePatterns on MessageRequestsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageRequestsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageRequestsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageRequestsState value)  $default,){
final _that = this;
switch (_that) {
case _MessageRequestsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageRequestsState value)?  $default,){
final _that = this;
switch (_that) {
case _MessageRequestsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<MessageRequest> requests,  int count,  bool loadingMore,  bool hasMore,  String? respondingRoomId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageRequestsState() when $default != null:
return $default(_that.status,_that.requests,_that.count,_that.loadingMore,_that.hasMore,_that.respondingRoomId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<MessageRequest> requests,  int count,  bool loadingMore,  bool hasMore,  String? respondingRoomId,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _MessageRequestsState():
return $default(_that.status,_that.requests,_that.count,_that.loadingMore,_that.hasMore,_that.respondingRoomId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<MessageRequest> requests,  int count,  bool loadingMore,  bool hasMore,  String? respondingRoomId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _MessageRequestsState() when $default != null:
return $default(_that.status,_that.requests,_that.count,_that.loadingMore,_that.hasMore,_that.respondingRoomId,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _MessageRequestsState implements MessageRequestsState {
  const _MessageRequestsState({this.status = LoadStatus.initial, final  List<MessageRequest> requests = const <MessageRequest>[], this.count = 0, this.loadingMore = false, this.hasMore = true, this.respondingRoomId, this.error, this.actionError, this.actionErrorId = 0}): _requests = requests;
  

@override@JsonKey() final  LoadStatus status;
 final  List<MessageRequest> _requests;
@override@JsonKey() List<MessageRequest> get requests {
  if (_requests is EqualUnmodifiableListView) return _requests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requests);
}

@override@JsonKey() final  int count;
@override@JsonKey() final  bool loadingMore;
@override@JsonKey() final  bool hasMore;
@override final  String? respondingRoomId;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of MessageRequestsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageRequestsStateCopyWith<_MessageRequestsState> get copyWith => __$MessageRequestsStateCopyWithImpl<_MessageRequestsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageRequestsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._requests, _requests)&&(identical(other.count, count) || other.count == count)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.respondingRoomId, respondingRoomId) || other.respondingRoomId == respondingRoomId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_requests),count,loadingMore,hasMore,respondingRoomId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'MessageRequestsState(status: $status, requests: $requests, count: $count, loadingMore: $loadingMore, hasMore: $hasMore, respondingRoomId: $respondingRoomId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$MessageRequestsStateCopyWith<$Res> implements $MessageRequestsStateCopyWith<$Res> {
  factory _$MessageRequestsStateCopyWith(_MessageRequestsState value, $Res Function(_MessageRequestsState) _then) = __$MessageRequestsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<MessageRequest> requests, int count, bool loadingMore, bool hasMore, String? respondingRoomId, Object? error, Object? actionError, int actionErrorId
});




}
/// @nodoc
class __$MessageRequestsStateCopyWithImpl<$Res>
    implements _$MessageRequestsStateCopyWith<$Res> {
  __$MessageRequestsStateCopyWithImpl(this._self, this._then);

  final _MessageRequestsState _self;
  final $Res Function(_MessageRequestsState) _then;

/// Create a copy of MessageRequestsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? requests = null,Object? count = null,Object? loadingMore = null,Object? hasMore = null,Object? respondingRoomId = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_MessageRequestsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,requests: null == requests ? _self._requests : requests // ignore: cast_nullable_to_non_nullable
as List<MessageRequest>,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,respondingRoomId: freezed == respondingRoomId ? _self.respondingRoomId : respondingRoomId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
