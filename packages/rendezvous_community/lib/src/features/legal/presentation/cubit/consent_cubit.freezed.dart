// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'consent_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConsentState {

 LoadStatus get status; List<LegalDocument> get documents; bool get agreed; bool get submitting; bool get accepted; Object? get error; Object? get actionError;
/// Create a copy of ConsentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConsentStateCopyWith<ConsentState> get copyWith => _$ConsentStateCopyWithImpl<ConsentState>(this as ConsentState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.documents, documents)&&(identical(other.agreed, agreed) || other.agreed == agreed)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.accepted, accepted) || other.accepted == accepted)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(documents),agreed,submitting,accepted,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError));

@override
String toString() {
  return 'ConsentState(status: $status, documents: $documents, agreed: $agreed, submitting: $submitting, accepted: $accepted, error: $error, actionError: $actionError)';
}


}

/// @nodoc
abstract mixin class $ConsentStateCopyWith<$Res>  {
  factory $ConsentStateCopyWith(ConsentState value, $Res Function(ConsentState) _then) = _$ConsentStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<LegalDocument> documents, bool agreed, bool submitting, bool accepted, Object? error, Object? actionError
});




}
/// @nodoc
class _$ConsentStateCopyWithImpl<$Res>
    implements $ConsentStateCopyWith<$Res> {
  _$ConsentStateCopyWithImpl(this._self, this._then);

  final ConsentState _self;
  final $Res Function(ConsentState) _then;

/// Create a copy of ConsentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? documents = null,Object? agreed = null,Object? submitting = null,Object? accepted = null,Object? error = freezed,Object? actionError = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<LegalDocument>,agreed: null == agreed ? _self.agreed : agreed // ignore: cast_nullable_to_non_nullable
as bool,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,
  ));
}

}


/// Adds pattern-matching-related methods to [ConsentState].
extension ConsentStatePatterns on ConsentState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConsentState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConsentState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConsentState value)  $default,){
final _that = this;
switch (_that) {
case _ConsentState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConsentState value)?  $default,){
final _that = this;
switch (_that) {
case _ConsentState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<LegalDocument> documents,  bool agreed,  bool submitting,  bool accepted,  Object? error,  Object? actionError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConsentState() when $default != null:
return $default(_that.status,_that.documents,_that.agreed,_that.submitting,_that.accepted,_that.error,_that.actionError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<LegalDocument> documents,  bool agreed,  bool submitting,  bool accepted,  Object? error,  Object? actionError)  $default,) {final _that = this;
switch (_that) {
case _ConsentState():
return $default(_that.status,_that.documents,_that.agreed,_that.submitting,_that.accepted,_that.error,_that.actionError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<LegalDocument> documents,  bool agreed,  bool submitting,  bool accepted,  Object? error,  Object? actionError)?  $default,) {final _that = this;
switch (_that) {
case _ConsentState() when $default != null:
return $default(_that.status,_that.documents,_that.agreed,_that.submitting,_that.accepted,_that.error,_that.actionError);case _:
  return null;

}
}

}

/// @nodoc


class _ConsentState extends ConsentState {
  const _ConsentState({this.status = LoadStatus.initial, final  List<LegalDocument> documents = const <LegalDocument>[], this.agreed = false, this.submitting = false, this.accepted = false, this.error, this.actionError}): _documents = documents,super._();
  

@override@JsonKey() final  LoadStatus status;
 final  List<LegalDocument> _documents;
@override@JsonKey() List<LegalDocument> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

@override@JsonKey() final  bool agreed;
@override@JsonKey() final  bool submitting;
@override@JsonKey() final  bool accepted;
@override final  Object? error;
@override final  Object? actionError;

/// Create a copy of ConsentState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConsentStateCopyWith<_ConsentState> get copyWith => __$ConsentStateCopyWithImpl<_ConsentState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConsentState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._documents, _documents)&&(identical(other.agreed, agreed) || other.agreed == agreed)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.accepted, accepted) || other.accepted == accepted)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_documents),agreed,submitting,accepted,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError));

@override
String toString() {
  return 'ConsentState(status: $status, documents: $documents, agreed: $agreed, submitting: $submitting, accepted: $accepted, error: $error, actionError: $actionError)';
}


}

/// @nodoc
abstract mixin class _$ConsentStateCopyWith<$Res> implements $ConsentStateCopyWith<$Res> {
  factory _$ConsentStateCopyWith(_ConsentState value, $Res Function(_ConsentState) _then) = __$ConsentStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<LegalDocument> documents, bool agreed, bool submitting, bool accepted, Object? error, Object? actionError
});




}
/// @nodoc
class __$ConsentStateCopyWithImpl<$Res>
    implements _$ConsentStateCopyWith<$Res> {
  __$ConsentStateCopyWithImpl(this._self, this._then);

  final _ConsentState _self;
  final $Res Function(_ConsentState) _then;

/// Create a copy of ConsentState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? documents = null,Object? agreed = null,Object? submitting = null,Object? accepted = null,Object? error = freezed,Object? actionError = freezed,}) {
  return _then(_ConsentState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<LegalDocument>,agreed: null == agreed ? _self.agreed : agreed // ignore: cast_nullable_to_non_nullable
as bool,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,
  ));
}


}

// dart format on
