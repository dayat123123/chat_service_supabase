// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supervisor_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SupervisorState {

 LoadStatus get status; SupervisorOverview? get overview; Object? get error;
/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupervisorStateCopyWith<SupervisorState> get copyWith => _$SupervisorStateCopyWithImpl<SupervisorState>(this as SupervisorState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupervisorState&&(identical(other.status, status) || other.status == status)&&(identical(other.overview, overview) || other.overview == overview)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,overview,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'SupervisorState(status: $status, overview: $overview, error: $error)';
}


}

/// @nodoc
abstract mixin class $SupervisorStateCopyWith<$Res>  {
  factory $SupervisorStateCopyWith(SupervisorState value, $Res Function(SupervisorState) _then) = _$SupervisorStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, SupervisorOverview? overview, Object? error
});


$SupervisorOverviewCopyWith<$Res>? get overview;

}
/// @nodoc
class _$SupervisorStateCopyWithImpl<$Res>
    implements $SupervisorStateCopyWith<$Res> {
  _$SupervisorStateCopyWithImpl(this._self, this._then);

  final SupervisorState _self;
  final $Res Function(SupervisorState) _then;

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? overview = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as SupervisorOverview?,error: freezed == error ? _self.error : error ,
  ));
}
/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupervisorOverviewCopyWith<$Res>? get overview {
    if (_self.overview == null) {
    return null;
  }

  return $SupervisorOverviewCopyWith<$Res>(_self.overview!, (value) {
    return _then(_self.copyWith(overview: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupervisorState].
extension SupervisorStatePatterns on SupervisorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupervisorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupervisorState value)  $default,){
final _that = this;
switch (_that) {
case _SupervisorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupervisorState value)?  $default,){
final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  SupervisorOverview? overview,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
return $default(_that.status,_that.overview,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  SupervisorOverview? overview,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _SupervisorState():
return $default(_that.status,_that.overview,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  SupervisorOverview? overview,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _SupervisorState() when $default != null:
return $default(_that.status,_that.overview,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _SupervisorState implements SupervisorState {
  const _SupervisorState({this.status = LoadStatus.initial, this.overview, this.error});
  

@override@JsonKey() final  LoadStatus status;
@override final  SupervisorOverview? overview;
@override final  Object? error;

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupervisorStateCopyWith<_SupervisorState> get copyWith => __$SupervisorStateCopyWithImpl<_SupervisorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupervisorState&&(identical(other.status, status) || other.status == status)&&(identical(other.overview, overview) || other.overview == overview)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,overview,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'SupervisorState(status: $status, overview: $overview, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SupervisorStateCopyWith<$Res> implements $SupervisorStateCopyWith<$Res> {
  factory _$SupervisorStateCopyWith(_SupervisorState value, $Res Function(_SupervisorState) _then) = __$SupervisorStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, SupervisorOverview? overview, Object? error
});


@override $SupervisorOverviewCopyWith<$Res>? get overview;

}
/// @nodoc
class __$SupervisorStateCopyWithImpl<$Res>
    implements _$SupervisorStateCopyWith<$Res> {
  __$SupervisorStateCopyWithImpl(this._self, this._then);

  final _SupervisorState _self;
  final $Res Function(_SupervisorState) _then;

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? overview = freezed,Object? error = freezed,}) {
  return _then(_SupervisorState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as SupervisorOverview?,error: freezed == error ? _self.error : error ,
  ));
}

/// Create a copy of SupervisorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupervisorOverviewCopyWith<$Res>? get overview {
    if (_self.overview == null) {
    return null;
  }

  return $SupervisorOverviewCopyWith<$Res>(_self.overview!, (value) {
    return _then(_self.copyWith(overview: value));
  });
}
}

// dart format on
