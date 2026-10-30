// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'poll_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PollState {

 Poll get poll; String? get pendingOptionId; Object? get error; int get errorId;
/// Create a copy of PollState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollStateCopyWith<PollState> get copyWith => _$PollStateCopyWithImpl<PollState>(this as PollState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollState&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.pendingOptionId, pendingOptionId) || other.pendingOptionId == pendingOptionId)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,poll,pendingOptionId,const DeepCollectionEquality().hash(error),errorId);

@override
String toString() {
  return 'PollState(poll: $poll, pendingOptionId: $pendingOptionId, error: $error, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class $PollStateCopyWith<$Res>  {
  factory $PollStateCopyWith(PollState value, $Res Function(PollState) _then) = _$PollStateCopyWithImpl;
@useResult
$Res call({
 Poll poll, String? pendingOptionId, Object? error, int errorId
});


$PollCopyWith<$Res> get poll;

}
/// @nodoc
class _$PollStateCopyWithImpl<$Res>
    implements $PollStateCopyWith<$Res> {
  _$PollStateCopyWithImpl(this._self, this._then);

  final PollState _self;
  final $Res Function(PollState) _then;

/// Create a copy of PollState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? poll = null,Object? pendingOptionId = freezed,Object? error = freezed,Object? errorId = null,}) {
  return _then(_self.copyWith(
poll: null == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll,pendingOptionId: freezed == pendingOptionId ? _self.pendingOptionId : pendingOptionId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of PollState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollCopyWith<$Res> get poll {
  
  return $PollCopyWith<$Res>(_self.poll, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}


/// Adds pattern-matching-related methods to [PollState].
extension PollStatePatterns on PollState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollState value)  $default,){
final _that = this;
switch (_that) {
case _PollState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollState value)?  $default,){
final _that = this;
switch (_that) {
case _PollState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Poll poll,  String? pendingOptionId,  Object? error,  int errorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PollState() when $default != null:
return $default(_that.poll,_that.pendingOptionId,_that.error,_that.errorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Poll poll,  String? pendingOptionId,  Object? error,  int errorId)  $default,) {final _that = this;
switch (_that) {
case _PollState():
return $default(_that.poll,_that.pendingOptionId,_that.error,_that.errorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Poll poll,  String? pendingOptionId,  Object? error,  int errorId)?  $default,) {final _that = this;
switch (_that) {
case _PollState() when $default != null:
return $default(_that.poll,_that.pendingOptionId,_that.error,_that.errorId);case _:
  return null;

}
}

}

/// @nodoc


class _PollState implements PollState {
  const _PollState({required this.poll, this.pendingOptionId, this.error, this.errorId = 0});
  

@override final  Poll poll;
@override final  String? pendingOptionId;
@override final  Object? error;
@override@JsonKey() final  int errorId;

/// Create a copy of PollState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollStateCopyWith<_PollState> get copyWith => __$PollStateCopyWithImpl<_PollState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollState&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.pendingOptionId, pendingOptionId) || other.pendingOptionId == pendingOptionId)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,poll,pendingOptionId,const DeepCollectionEquality().hash(error),errorId);

@override
String toString() {
  return 'PollState(poll: $poll, pendingOptionId: $pendingOptionId, error: $error, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class _$PollStateCopyWith<$Res> implements $PollStateCopyWith<$Res> {
  factory _$PollStateCopyWith(_PollState value, $Res Function(_PollState) _then) = __$PollStateCopyWithImpl;
@override @useResult
$Res call({
 Poll poll, String? pendingOptionId, Object? error, int errorId
});


@override $PollCopyWith<$Res> get poll;

}
/// @nodoc
class __$PollStateCopyWithImpl<$Res>
    implements _$PollStateCopyWith<$Res> {
  __$PollStateCopyWithImpl(this._self, this._then);

  final _PollState _self;
  final $Res Function(_PollState) _then;

/// Create a copy of PollState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? poll = null,Object? pendingOptionId = freezed,Object? error = freezed,Object? errorId = null,}) {
  return _then(_PollState(
poll: null == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll,pendingOptionId: freezed == pendingOptionId ? _self.pendingOptionId : pendingOptionId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PollState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollCopyWith<$Res> get poll {
  
  return $PollCopyWith<$Res>(_self.poll, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}

// dart format on
