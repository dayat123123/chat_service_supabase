// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrendingState {

 LoadStatus get status; TrendWindow get window; TrendingSnapshot? get snapshot; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingStateCopyWith<TrendingState> get copyWith => _$TrendingStateCopyWithImpl<TrendingState>(this as TrendingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingState&&(identical(other.status, status) || other.status == status)&&(identical(other.window, window) || other.window == window)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,window,snapshot,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'TrendingState(status: $status, window: $window, snapshot: $snapshot, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $TrendingStateCopyWith<$Res>  {
  factory $TrendingStateCopyWith(TrendingState value, $Res Function(TrendingState) _then) = _$TrendingStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, TrendWindow window, TrendingSnapshot? snapshot, Object? error, Object? actionError, int actionErrorId
});


$TrendingSnapshotCopyWith<$Res>? get snapshot;

}
/// @nodoc
class _$TrendingStateCopyWithImpl<$Res>
    implements $TrendingStateCopyWith<$Res> {
  _$TrendingStateCopyWithImpl(this._self, this._then);

  final TrendingState _self;
  final $Res Function(TrendingState) _then;

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? window = null,Object? snapshot = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as TrendingSnapshot?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrendingSnapshotCopyWith<$Res>? get snapshot {
    if (_self.snapshot == null) {
    return null;
  }

  return $TrendingSnapshotCopyWith<$Res>(_self.snapshot!, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrendingState].
extension TrendingStatePatterns on TrendingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingState value)  $default,){
final _that = this;
switch (_that) {
case _TrendingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingState value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  TrendWindow window,  TrendingSnapshot? snapshot,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
return $default(_that.status,_that.window,_that.snapshot,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  TrendWindow window,  TrendingSnapshot? snapshot,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _TrendingState():
return $default(_that.status,_that.window,_that.snapshot,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  TrendWindow window,  TrendingSnapshot? snapshot,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
return $default(_that.status,_that.window,_that.snapshot,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _TrendingState implements TrendingState {
  const _TrendingState({this.status = LoadStatus.initial, this.window = TrendWindow.day, this.snapshot, this.error, this.actionError, this.actionErrorId = 0});
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  TrendWindow window;
@override final  TrendingSnapshot? snapshot;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingStateCopyWith<_TrendingState> get copyWith => __$TrendingStateCopyWithImpl<_TrendingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingState&&(identical(other.status, status) || other.status == status)&&(identical(other.window, window) || other.window == window)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,window,snapshot,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'TrendingState(status: $status, window: $window, snapshot: $snapshot, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$TrendingStateCopyWith<$Res> implements $TrendingStateCopyWith<$Res> {
  factory _$TrendingStateCopyWith(_TrendingState value, $Res Function(_TrendingState) _then) = __$TrendingStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, TrendWindow window, TrendingSnapshot? snapshot, Object? error, Object? actionError, int actionErrorId
});


@override $TrendingSnapshotCopyWith<$Res>? get snapshot;

}
/// @nodoc
class __$TrendingStateCopyWithImpl<$Res>
    implements _$TrendingStateCopyWith<$Res> {
  __$TrendingStateCopyWithImpl(this._self, this._then);

  final _TrendingState _self;
  final $Res Function(_TrendingState) _then;

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? window = null,Object? snapshot = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_TrendingState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as TrendingSnapshot?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrendingSnapshotCopyWith<$Res>? get snapshot {
    if (_self.snapshot == null) {
    return null;
  }

  return $TrendingSnapshotCopyWith<$Res>(_self.snapshot!, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}

// dart format on
