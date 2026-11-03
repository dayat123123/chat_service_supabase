// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_preferences_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationPreferencesState {

 LoadStatus get status; NotificationPreferences get preferences; bool get saving; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesStateCopyWith<NotificationPreferencesState> get copyWith => _$NotificationPreferencesStateCopyWithImpl<NotificationPreferencesState>(this as NotificationPreferencesState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencesState&&(identical(other.status, status) || other.status == status)&&(identical(other.preferences, preferences) || other.preferences == preferences)&&(identical(other.saving, saving) || other.saving == saving)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,preferences,saving,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'NotificationPreferencesState(status: $status, preferences: $preferences, saving: $saving, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesStateCopyWith<$Res>  {
  factory $NotificationPreferencesStateCopyWith(NotificationPreferencesState value, $Res Function(NotificationPreferencesState) _then) = _$NotificationPreferencesStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, NotificationPreferences preferences, bool saving, Object? error, Object? actionError, int actionErrorId
});


$NotificationPreferencesCopyWith<$Res> get preferences;

}
/// @nodoc
class _$NotificationPreferencesStateCopyWithImpl<$Res>
    implements $NotificationPreferencesStateCopyWith<$Res> {
  _$NotificationPreferencesStateCopyWithImpl(this._self, this._then);

  final NotificationPreferencesState _self;
  final $Res Function(NotificationPreferencesState) _then;

/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? preferences = null,Object? saving = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,preferences: null == preferences ? _self.preferences : preferences // ignore: cast_nullable_to_non_nullable
as NotificationPreferences,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPreferencesCopyWith<$Res> get preferences {
  
  return $NotificationPreferencesCopyWith<$Res>(_self.preferences, (value) {
    return _then(_self.copyWith(preferences: value));
  });
}
}


/// Adds pattern-matching-related methods to [NotificationPreferencesState].
extension NotificationPreferencesStatePatterns on NotificationPreferencesState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPreferencesState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPreferencesState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPreferencesState value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferencesState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPreferencesState value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferencesState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  NotificationPreferences preferences,  bool saving,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPreferencesState() when $default != null:
return $default(_that.status,_that.preferences,_that.saving,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  NotificationPreferences preferences,  bool saving,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferencesState():
return $default(_that.status,_that.preferences,_that.saving,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  NotificationPreferences preferences,  bool saving,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferencesState() when $default != null:
return $default(_that.status,_that.preferences,_that.saving,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationPreferencesState implements NotificationPreferencesState {
  const _NotificationPreferencesState({this.status = LoadStatus.initial, this.preferences = const NotificationPreferences(), this.saving = false, this.error, this.actionError, this.actionErrorId = 0});
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  NotificationPreferences preferences;
@override@JsonKey() final  bool saving;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPreferencesStateCopyWith<_NotificationPreferencesState> get copyWith => __$NotificationPreferencesStateCopyWithImpl<_NotificationPreferencesState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPreferencesState&&(identical(other.status, status) || other.status == status)&&(identical(other.preferences, preferences) || other.preferences == preferences)&&(identical(other.saving, saving) || other.saving == saving)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,preferences,saving,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'NotificationPreferencesState(status: $status, preferences: $preferences, saving: $saving, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$NotificationPreferencesStateCopyWith<$Res> implements $NotificationPreferencesStateCopyWith<$Res> {
  factory _$NotificationPreferencesStateCopyWith(_NotificationPreferencesState value, $Res Function(_NotificationPreferencesState) _then) = __$NotificationPreferencesStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, NotificationPreferences preferences, bool saving, Object? error, Object? actionError, int actionErrorId
});


@override $NotificationPreferencesCopyWith<$Res> get preferences;

}
/// @nodoc
class __$NotificationPreferencesStateCopyWithImpl<$Res>
    implements _$NotificationPreferencesStateCopyWith<$Res> {
  __$NotificationPreferencesStateCopyWithImpl(this._self, this._then);

  final _NotificationPreferencesState _self;
  final $Res Function(_NotificationPreferencesState) _then;

/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? preferences = null,Object? saving = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_NotificationPreferencesState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,preferences: null == preferences ? _self.preferences : preferences // ignore: cast_nullable_to_non_nullable
as NotificationPreferences,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPreferencesCopyWith<$Res> get preferences {
  
  return $NotificationPreferencesCopyWith<$Res>(_self.preferences, (value) {
    return _then(_self.copyWith(preferences: value));
  });
}
}

// dart format on
