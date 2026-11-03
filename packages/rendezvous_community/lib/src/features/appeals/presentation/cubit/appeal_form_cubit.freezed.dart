// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appeal_form_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppealFormState {

 bool get submitting; Appeal? get created; Object? get error; int get errorId;
/// Create a copy of AppealFormState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppealFormStateCopyWith<AppealFormState> get copyWith => _$AppealFormStateCopyWithImpl<AppealFormState>(this as AppealFormState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppealFormState&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.created, created) || other.created == created)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,submitting,created,const DeepCollectionEquality().hash(error),errorId);

@override
String toString() {
  return 'AppealFormState(submitting: $submitting, created: $created, error: $error, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class $AppealFormStateCopyWith<$Res>  {
  factory $AppealFormStateCopyWith(AppealFormState value, $Res Function(AppealFormState) _then) = _$AppealFormStateCopyWithImpl;
@useResult
$Res call({
 bool submitting, Appeal? created, Object? error, int errorId
});


$AppealCopyWith<$Res>? get created;

}
/// @nodoc
class _$AppealFormStateCopyWithImpl<$Res>
    implements $AppealFormStateCopyWith<$Res> {
  _$AppealFormStateCopyWithImpl(this._self, this._then);

  final AppealFormState _self;
  final $Res Function(AppealFormState) _then;

/// Create a copy of AppealFormState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? submitting = null,Object? created = freezed,Object? error = freezed,Object? errorId = null,}) {
  return _then(_self.copyWith(
submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,created: freezed == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as Appeal?,error: freezed == error ? _self.error : error ,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of AppealFormState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppealCopyWith<$Res>? get created {
    if (_self.created == null) {
    return null;
  }

  return $AppealCopyWith<$Res>(_self.created!, (value) {
    return _then(_self.copyWith(created: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppealFormState].
extension AppealFormStatePatterns on AppealFormState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppealFormState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppealFormState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppealFormState value)  $default,){
final _that = this;
switch (_that) {
case _AppealFormState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppealFormState value)?  $default,){
final _that = this;
switch (_that) {
case _AppealFormState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool submitting,  Appeal? created,  Object? error,  int errorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppealFormState() when $default != null:
return $default(_that.submitting,_that.created,_that.error,_that.errorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool submitting,  Appeal? created,  Object? error,  int errorId)  $default,) {final _that = this;
switch (_that) {
case _AppealFormState():
return $default(_that.submitting,_that.created,_that.error,_that.errorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool submitting,  Appeal? created,  Object? error,  int errorId)?  $default,) {final _that = this;
switch (_that) {
case _AppealFormState() when $default != null:
return $default(_that.submitting,_that.created,_that.error,_that.errorId);case _:
  return null;

}
}

}

/// @nodoc


class _AppealFormState implements AppealFormState {
  const _AppealFormState({this.submitting = false, this.created, this.error, this.errorId = 0});
  

@override@JsonKey() final  bool submitting;
@override final  Appeal? created;
@override final  Object? error;
@override@JsonKey() final  int errorId;

/// Create a copy of AppealFormState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppealFormStateCopyWith<_AppealFormState> get copyWith => __$AppealFormStateCopyWithImpl<_AppealFormState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppealFormState&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.created, created) || other.created == created)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,submitting,created,const DeepCollectionEquality().hash(error),errorId);

@override
String toString() {
  return 'AppealFormState(submitting: $submitting, created: $created, error: $error, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class _$AppealFormStateCopyWith<$Res> implements $AppealFormStateCopyWith<$Res> {
  factory _$AppealFormStateCopyWith(_AppealFormState value, $Res Function(_AppealFormState) _then) = __$AppealFormStateCopyWithImpl;
@override @useResult
$Res call({
 bool submitting, Appeal? created, Object? error, int errorId
});


@override $AppealCopyWith<$Res>? get created;

}
/// @nodoc
class __$AppealFormStateCopyWithImpl<$Res>
    implements _$AppealFormStateCopyWith<$Res> {
  __$AppealFormStateCopyWithImpl(this._self, this._then);

  final _AppealFormState _self;
  final $Res Function(_AppealFormState) _then;

/// Create a copy of AppealFormState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? submitting = null,Object? created = freezed,Object? error = freezed,Object? errorId = null,}) {
  return _then(_AppealFormState(
submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,created: freezed == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as Appeal?,error: freezed == error ? _self.error : error ,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of AppealFormState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppealCopyWith<$Res>? get created {
    if (_self.created == null) {
    return null;
  }

  return $AppealCopyWith<$Res>(_self.created!, (value) {
    return _then(_self.copyWith(created: value));
  });
}
}

// dart format on
