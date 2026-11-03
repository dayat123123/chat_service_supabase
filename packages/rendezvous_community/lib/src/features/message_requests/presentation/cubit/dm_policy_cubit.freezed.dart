// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dm_policy_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DmPolicyState {

 LoadStatus get status; DmPolicySettings get settings; bool get saving; int get savedId; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of DmPolicyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DmPolicyStateCopyWith<DmPolicyState> get copyWith => _$DmPolicyStateCopyWithImpl<DmPolicyState>(this as DmPolicyState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DmPolicyState&&(identical(other.status, status) || other.status == status)&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.savedId, savedId) || other.savedId == savedId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,settings,saving,savedId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'DmPolicyState(status: $status, settings: $settings, saving: $saving, savedId: $savedId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $DmPolicyStateCopyWith<$Res>  {
  factory $DmPolicyStateCopyWith(DmPolicyState value, $Res Function(DmPolicyState) _then) = _$DmPolicyStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, DmPolicySettings settings, bool saving, int savedId, Object? error, Object? actionError, int actionErrorId
});


$DmPolicySettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$DmPolicyStateCopyWithImpl<$Res>
    implements $DmPolicyStateCopyWith<$Res> {
  _$DmPolicyStateCopyWithImpl(this._self, this._then);

  final DmPolicyState _self;
  final $Res Function(DmPolicyState) _then;

/// Create a copy of DmPolicyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? settings = null,Object? saving = null,Object? savedId = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as DmPolicySettings,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,savedId: null == savedId ? _self.savedId : savedId // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of DmPolicyState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DmPolicySettingsCopyWith<$Res> get settings {
  
  return $DmPolicySettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [DmPolicyState].
extension DmPolicyStatePatterns on DmPolicyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DmPolicyState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DmPolicyState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DmPolicyState value)  $default,){
final _that = this;
switch (_that) {
case _DmPolicyState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DmPolicyState value)?  $default,){
final _that = this;
switch (_that) {
case _DmPolicyState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  DmPolicySettings settings,  bool saving,  int savedId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DmPolicyState() when $default != null:
return $default(_that.status,_that.settings,_that.saving,_that.savedId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  DmPolicySettings settings,  bool saving,  int savedId,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _DmPolicyState():
return $default(_that.status,_that.settings,_that.saving,_that.savedId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  DmPolicySettings settings,  bool saving,  int savedId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _DmPolicyState() when $default != null:
return $default(_that.status,_that.settings,_that.saving,_that.savedId,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _DmPolicyState implements DmPolicyState {
  const _DmPolicyState({this.status = LoadStatus.initial, this.settings = const DmPolicySettings(), this.saving = false, this.savedId = 0, this.error, this.actionError, this.actionErrorId = 0});
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  DmPolicySettings settings;
@override@JsonKey() final  bool saving;
@override@JsonKey() final  int savedId;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of DmPolicyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DmPolicyStateCopyWith<_DmPolicyState> get copyWith => __$DmPolicyStateCopyWithImpl<_DmPolicyState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DmPolicyState&&(identical(other.status, status) || other.status == status)&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.savedId, savedId) || other.savedId == savedId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,settings,saving,savedId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'DmPolicyState(status: $status, settings: $settings, saving: $saving, savedId: $savedId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$DmPolicyStateCopyWith<$Res> implements $DmPolicyStateCopyWith<$Res> {
  factory _$DmPolicyStateCopyWith(_DmPolicyState value, $Res Function(_DmPolicyState) _then) = __$DmPolicyStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, DmPolicySettings settings, bool saving, int savedId, Object? error, Object? actionError, int actionErrorId
});


@override $DmPolicySettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$DmPolicyStateCopyWithImpl<$Res>
    implements _$DmPolicyStateCopyWith<$Res> {
  __$DmPolicyStateCopyWithImpl(this._self, this._then);

  final _DmPolicyState _self;
  final $Res Function(_DmPolicyState) _then;

/// Create a copy of DmPolicyState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? settings = null,Object? saving = null,Object? savedId = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_DmPolicyState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as DmPolicySettings,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,savedId: null == savedId ? _self.savedId : savedId // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of DmPolicyState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DmPolicySettingsCopyWith<$Res> get settings {
  
  return $DmPolicySettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

// dart format on
