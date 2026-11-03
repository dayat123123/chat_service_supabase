// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_drafts_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PostDraftsState {

 LoadStatus get status; List<PostDraft> get drafts; Object? get error;
/// Create a copy of PostDraftsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostDraftsStateCopyWith<PostDraftsState> get copyWith => _$PostDraftsStateCopyWithImpl<PostDraftsState>(this as PostDraftsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostDraftsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.drafts, drafts)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(drafts),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'PostDraftsState(status: $status, drafts: $drafts, error: $error)';
}


}

/// @nodoc
abstract mixin class $PostDraftsStateCopyWith<$Res>  {
  factory $PostDraftsStateCopyWith(PostDraftsState value, $Res Function(PostDraftsState) _then) = _$PostDraftsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<PostDraft> drafts, Object? error
});




}
/// @nodoc
class _$PostDraftsStateCopyWithImpl<$Res>
    implements $PostDraftsStateCopyWith<$Res> {
  _$PostDraftsStateCopyWithImpl(this._self, this._then);

  final PostDraftsState _self;
  final $Res Function(PostDraftsState) _then;

/// Create a copy of PostDraftsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? drafts = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,drafts: null == drafts ? _self.drafts : drafts // ignore: cast_nullable_to_non_nullable
as List<PostDraft>,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [PostDraftsState].
extension PostDraftsStatePatterns on PostDraftsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostDraftsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostDraftsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostDraftsState value)  $default,){
final _that = this;
switch (_that) {
case _PostDraftsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostDraftsState value)?  $default,){
final _that = this;
switch (_that) {
case _PostDraftsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<PostDraft> drafts,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostDraftsState() when $default != null:
return $default(_that.status,_that.drafts,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<PostDraft> drafts,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _PostDraftsState():
return $default(_that.status,_that.drafts,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<PostDraft> drafts,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _PostDraftsState() when $default != null:
return $default(_that.status,_that.drafts,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _PostDraftsState implements PostDraftsState {
  const _PostDraftsState({this.status = LoadStatus.initial, final  List<PostDraft> drafts = const <PostDraft>[], this.error}): _drafts = drafts;
  

@override@JsonKey() final  LoadStatus status;
 final  List<PostDraft> _drafts;
@override@JsonKey() List<PostDraft> get drafts {
  if (_drafts is EqualUnmodifiableListView) return _drafts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_drafts);
}

@override final  Object? error;

/// Create a copy of PostDraftsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostDraftsStateCopyWith<_PostDraftsState> get copyWith => __$PostDraftsStateCopyWithImpl<_PostDraftsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostDraftsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._drafts, _drafts)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_drafts),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'PostDraftsState(status: $status, drafts: $drafts, error: $error)';
}


}

/// @nodoc
abstract mixin class _$PostDraftsStateCopyWith<$Res> implements $PostDraftsStateCopyWith<$Res> {
  factory _$PostDraftsStateCopyWith(_PostDraftsState value, $Res Function(_PostDraftsState) _then) = __$PostDraftsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<PostDraft> drafts, Object? error
});




}
/// @nodoc
class __$PostDraftsStateCopyWithImpl<$Res>
    implements _$PostDraftsStateCopyWith<$Res> {
  __$PostDraftsStateCopyWithImpl(this._self, this._then);

  final _PostDraftsState _self;
  final $Res Function(_PostDraftsState) _then;

/// Create a copy of PostDraftsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? drafts = null,Object? error = freezed,}) {
  return _then(_PostDraftsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,drafts: null == drafts ? _self._drafts : drafts // ignore: cast_nullable_to_non_nullable
as List<PostDraft>,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
