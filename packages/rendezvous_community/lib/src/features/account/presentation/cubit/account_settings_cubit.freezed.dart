// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_settings_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AccountSettingsState {

 LoadStatus get status; List<LegalDocument> get documents; Object? get error; bool get exporting; bool get deleting; bool get deleted; AccountAction? get failedAction; Object? get actionError; int get actionErrorId;
/// Create a copy of AccountSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountSettingsStateCopyWith<AccountSettingsState> get copyWith => _$AccountSettingsStateCopyWithImpl<AccountSettingsState>(this as AccountSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountSettingsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.exporting, exporting) || other.exporting == exporting)&&(identical(other.deleting, deleting) || other.deleting == deleting)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.failedAction, failedAction) || other.failedAction == failedAction)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(error),exporting,deleting,deleted,failedAction,const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'AccountSettingsState(status: $status, documents: $documents, error: $error, exporting: $exporting, deleting: $deleting, deleted: $deleted, failedAction: $failedAction, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $AccountSettingsStateCopyWith<$Res>  {
  factory $AccountSettingsStateCopyWith(AccountSettingsState value, $Res Function(AccountSettingsState) _then) = _$AccountSettingsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<LegalDocument> documents, Object? error, bool exporting, bool deleting, bool deleted, AccountAction? failedAction, Object? actionError, int actionErrorId
});




}
/// @nodoc
class _$AccountSettingsStateCopyWithImpl<$Res>
    implements $AccountSettingsStateCopyWith<$Res> {
  _$AccountSettingsStateCopyWithImpl(this._self, this._then);

  final AccountSettingsState _self;
  final $Res Function(AccountSettingsState) _then;

/// Create a copy of AccountSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? documents = null,Object? error = freezed,Object? exporting = null,Object? deleting = null,Object? deleted = null,Object? failedAction = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<LegalDocument>,error: freezed == error ? _self.error : error ,exporting: null == exporting ? _self.exporting : exporting // ignore: cast_nullable_to_non_nullable
as bool,deleting: null == deleting ? _self.deleting : deleting // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,failedAction: freezed == failedAction ? _self.failedAction : failedAction // ignore: cast_nullable_to_non_nullable
as AccountAction?,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountSettingsState].
extension AccountSettingsStatePatterns on AccountSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _AccountSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _AccountSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<LegalDocument> documents,  Object? error,  bool exporting,  bool deleting,  bool deleted,  AccountAction? failedAction,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountSettingsState() when $default != null:
return $default(_that.status,_that.documents,_that.error,_that.exporting,_that.deleting,_that.deleted,_that.failedAction,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<LegalDocument> documents,  Object? error,  bool exporting,  bool deleting,  bool deleted,  AccountAction? failedAction,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _AccountSettingsState():
return $default(_that.status,_that.documents,_that.error,_that.exporting,_that.deleting,_that.deleted,_that.failedAction,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<LegalDocument> documents,  Object? error,  bool exporting,  bool deleting,  bool deleted,  AccountAction? failedAction,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _AccountSettingsState() when $default != null:
return $default(_that.status,_that.documents,_that.error,_that.exporting,_that.deleting,_that.deleted,_that.failedAction,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _AccountSettingsState implements AccountSettingsState {
  const _AccountSettingsState({this.status = LoadStatus.initial, final  List<LegalDocument> documents = const <LegalDocument>[], this.error, this.exporting = false, this.deleting = false, this.deleted = false, this.failedAction, this.actionError, this.actionErrorId = 0}): _documents = documents;
  

@override@JsonKey() final  LoadStatus status;
 final  List<LegalDocument> _documents;
@override@JsonKey() List<LegalDocument> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

@override final  Object? error;
@override@JsonKey() final  bool exporting;
@override@JsonKey() final  bool deleting;
@override@JsonKey() final  bool deleted;
@override final  AccountAction? failedAction;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of AccountSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountSettingsStateCopyWith<_AccountSettingsState> get copyWith => __$AccountSettingsStateCopyWithImpl<_AccountSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountSettingsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.exporting, exporting) || other.exporting == exporting)&&(identical(other.deleting, deleting) || other.deleting == deleting)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.failedAction, failedAction) || other.failedAction == failedAction)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(error),exporting,deleting,deleted,failedAction,const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'AccountSettingsState(status: $status, documents: $documents, error: $error, exporting: $exporting, deleting: $deleting, deleted: $deleted, failedAction: $failedAction, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$AccountSettingsStateCopyWith<$Res> implements $AccountSettingsStateCopyWith<$Res> {
  factory _$AccountSettingsStateCopyWith(_AccountSettingsState value, $Res Function(_AccountSettingsState) _then) = __$AccountSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<LegalDocument> documents, Object? error, bool exporting, bool deleting, bool deleted, AccountAction? failedAction, Object? actionError, int actionErrorId
});




}
/// @nodoc
class __$AccountSettingsStateCopyWithImpl<$Res>
    implements _$AccountSettingsStateCopyWith<$Res> {
  __$AccountSettingsStateCopyWithImpl(this._self, this._then);

  final _AccountSettingsState _self;
  final $Res Function(_AccountSettingsState) _then;

/// Create a copy of AccountSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? documents = null,Object? error = freezed,Object? exporting = null,Object? deleting = null,Object? deleted = null,Object? failedAction = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_AccountSettingsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<LegalDocument>,error: freezed == error ? _self.error : error ,exporting: null == exporting ? _self.exporting : exporting // ignore: cast_nullable_to_non_nullable
as bool,deleting: null == deleting ? _self.deleting : deleting // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,failedAction: freezed == failedAction ? _self.failedAction : failedAction // ignore: cast_nullable_to_non_nullable
as AccountAction?,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
