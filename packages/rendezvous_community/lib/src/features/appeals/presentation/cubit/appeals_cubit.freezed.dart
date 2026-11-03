// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appeals_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppealsState {

 LoadStatus get status; List<Appeal> get appeals; List<Sanction> get sanctions; List<ModeratedContent> get moderated; Object? get error;
/// Create a copy of AppealsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppealsStateCopyWith<AppealsState> get copyWith => _$AppealsStateCopyWithImpl<AppealsState>(this as AppealsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppealsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.appeals, appeals)&&const DeepCollectionEquality().equals(other.sanctions, sanctions)&&const DeepCollectionEquality().equals(other.moderated, moderated)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(appeals),const DeepCollectionEquality().hash(sanctions),const DeepCollectionEquality().hash(moderated),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'AppealsState(status: $status, appeals: $appeals, sanctions: $sanctions, moderated: $moderated, error: $error)';
}


}

/// @nodoc
abstract mixin class $AppealsStateCopyWith<$Res>  {
  factory $AppealsStateCopyWith(AppealsState value, $Res Function(AppealsState) _then) = _$AppealsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<Appeal> appeals, List<Sanction> sanctions, List<ModeratedContent> moderated, Object? error
});




}
/// @nodoc
class _$AppealsStateCopyWithImpl<$Res>
    implements $AppealsStateCopyWith<$Res> {
  _$AppealsStateCopyWithImpl(this._self, this._then);

  final AppealsState _self;
  final $Res Function(AppealsState) _then;

/// Create a copy of AppealsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? appeals = null,Object? sanctions = null,Object? moderated = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,appeals: null == appeals ? _self.appeals : appeals // ignore: cast_nullable_to_non_nullable
as List<Appeal>,sanctions: null == sanctions ? _self.sanctions : sanctions // ignore: cast_nullable_to_non_nullable
as List<Sanction>,moderated: null == moderated ? _self.moderated : moderated // ignore: cast_nullable_to_non_nullable
as List<ModeratedContent>,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [AppealsState].
extension AppealsStatePatterns on AppealsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppealsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppealsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppealsState value)  $default,){
final _that = this;
switch (_that) {
case _AppealsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppealsState value)?  $default,){
final _that = this;
switch (_that) {
case _AppealsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<Appeal> appeals,  List<Sanction> sanctions,  List<ModeratedContent> moderated,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppealsState() when $default != null:
return $default(_that.status,_that.appeals,_that.sanctions,_that.moderated,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<Appeal> appeals,  List<Sanction> sanctions,  List<ModeratedContent> moderated,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _AppealsState():
return $default(_that.status,_that.appeals,_that.sanctions,_that.moderated,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<Appeal> appeals,  List<Sanction> sanctions,  List<ModeratedContent> moderated,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _AppealsState() when $default != null:
return $default(_that.status,_that.appeals,_that.sanctions,_that.moderated,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _AppealsState extends AppealsState {
  const _AppealsState({this.status = LoadStatus.initial, final  List<Appeal> appeals = const <Appeal>[], final  List<Sanction> sanctions = const <Sanction>[], final  List<ModeratedContent> moderated = const <ModeratedContent>[], this.error}): _appeals = appeals,_sanctions = sanctions,_moderated = moderated,super._();
  

@override@JsonKey() final  LoadStatus status;
 final  List<Appeal> _appeals;
@override@JsonKey() List<Appeal> get appeals {
  if (_appeals is EqualUnmodifiableListView) return _appeals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_appeals);
}

 final  List<Sanction> _sanctions;
@override@JsonKey() List<Sanction> get sanctions {
  if (_sanctions is EqualUnmodifiableListView) return _sanctions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sanctions);
}

 final  List<ModeratedContent> _moderated;
@override@JsonKey() List<ModeratedContent> get moderated {
  if (_moderated is EqualUnmodifiableListView) return _moderated;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_moderated);
}

@override final  Object? error;

/// Create a copy of AppealsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppealsStateCopyWith<_AppealsState> get copyWith => __$AppealsStateCopyWithImpl<_AppealsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppealsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._appeals, _appeals)&&const DeepCollectionEquality().equals(other._sanctions, _sanctions)&&const DeepCollectionEquality().equals(other._moderated, _moderated)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_appeals),const DeepCollectionEquality().hash(_sanctions),const DeepCollectionEquality().hash(_moderated),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'AppealsState(status: $status, appeals: $appeals, sanctions: $sanctions, moderated: $moderated, error: $error)';
}


}

/// @nodoc
abstract mixin class _$AppealsStateCopyWith<$Res> implements $AppealsStateCopyWith<$Res> {
  factory _$AppealsStateCopyWith(_AppealsState value, $Res Function(_AppealsState) _then) = __$AppealsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<Appeal> appeals, List<Sanction> sanctions, List<ModeratedContent> moderated, Object? error
});




}
/// @nodoc
class __$AppealsStateCopyWithImpl<$Res>
    implements _$AppealsStateCopyWith<$Res> {
  __$AppealsStateCopyWithImpl(this._self, this._then);

  final _AppealsState _self;
  final $Res Function(_AppealsState) _then;

/// Create a copy of AppealsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? appeals = null,Object? sanctions = null,Object? moderated = null,Object? error = freezed,}) {
  return _then(_AppealsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,appeals: null == appeals ? _self._appeals : appeals // ignore: cast_nullable_to_non_nullable
as List<Appeal>,sanctions: null == sanctions ? _self._sanctions : sanctions // ignore: cast_nullable_to_non_nullable
as List<Sanction>,moderated: null == moderated ? _self._moderated : moderated // ignore: cast_nullable_to_non_nullable
as List<ModeratedContent>,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
