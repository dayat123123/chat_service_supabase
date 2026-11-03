// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_hashtags_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrendingHashtagsState {

 LoadStatus get status; TrendWindow get window; List<HashtagSummary> get hashtags; Object? get error;
/// Create a copy of TrendingHashtagsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingHashtagsStateCopyWith<TrendingHashtagsState> get copyWith => _$TrendingHashtagsStateCopyWithImpl<TrendingHashtagsState>(this as TrendingHashtagsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingHashtagsState&&(identical(other.status, status) || other.status == status)&&(identical(other.window, window) || other.window == window)&&const DeepCollectionEquality().equals(other.hashtags, hashtags)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,window,const DeepCollectionEquality().hash(hashtags),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'TrendingHashtagsState(status: $status, window: $window, hashtags: $hashtags, error: $error)';
}


}

/// @nodoc
abstract mixin class $TrendingHashtagsStateCopyWith<$Res>  {
  factory $TrendingHashtagsStateCopyWith(TrendingHashtagsState value, $Res Function(TrendingHashtagsState) _then) = _$TrendingHashtagsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, TrendWindow window, List<HashtagSummary> hashtags, Object? error
});




}
/// @nodoc
class _$TrendingHashtagsStateCopyWithImpl<$Res>
    implements $TrendingHashtagsStateCopyWith<$Res> {
  _$TrendingHashtagsStateCopyWithImpl(this._self, this._then);

  final TrendingHashtagsState _self;
  final $Res Function(TrendingHashtagsState) _then;

/// Create a copy of TrendingHashtagsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? window = null,Object? hashtags = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,hashtags: null == hashtags ? _self.hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<HashtagSummary>,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendingHashtagsState].
extension TrendingHashtagsStatePatterns on TrendingHashtagsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingHashtagsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingHashtagsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingHashtagsState value)  $default,){
final _that = this;
switch (_that) {
case _TrendingHashtagsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingHashtagsState value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingHashtagsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  TrendWindow window,  List<HashtagSummary> hashtags,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingHashtagsState() when $default != null:
return $default(_that.status,_that.window,_that.hashtags,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  TrendWindow window,  List<HashtagSummary> hashtags,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _TrendingHashtagsState():
return $default(_that.status,_that.window,_that.hashtags,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  TrendWindow window,  List<HashtagSummary> hashtags,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _TrendingHashtagsState() when $default != null:
return $default(_that.status,_that.window,_that.hashtags,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _TrendingHashtagsState implements TrendingHashtagsState {
  const _TrendingHashtagsState({this.status = LoadStatus.initial, this.window = TrendWindow.day, final  List<HashtagSummary> hashtags = const <HashtagSummary>[], this.error}): _hashtags = hashtags;
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  TrendWindow window;
 final  List<HashtagSummary> _hashtags;
@override@JsonKey() List<HashtagSummary> get hashtags {
  if (_hashtags is EqualUnmodifiableListView) return _hashtags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hashtags);
}

@override final  Object? error;

/// Create a copy of TrendingHashtagsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingHashtagsStateCopyWith<_TrendingHashtagsState> get copyWith => __$TrendingHashtagsStateCopyWithImpl<_TrendingHashtagsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingHashtagsState&&(identical(other.status, status) || other.status == status)&&(identical(other.window, window) || other.window == window)&&const DeepCollectionEquality().equals(other._hashtags, _hashtags)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,window,const DeepCollectionEquality().hash(_hashtags),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'TrendingHashtagsState(status: $status, window: $window, hashtags: $hashtags, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TrendingHashtagsStateCopyWith<$Res> implements $TrendingHashtagsStateCopyWith<$Res> {
  factory _$TrendingHashtagsStateCopyWith(_TrendingHashtagsState value, $Res Function(_TrendingHashtagsState) _then) = __$TrendingHashtagsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, TrendWindow window, List<HashtagSummary> hashtags, Object? error
});




}
/// @nodoc
class __$TrendingHashtagsStateCopyWithImpl<$Res>
    implements _$TrendingHashtagsStateCopyWith<$Res> {
  __$TrendingHashtagsStateCopyWithImpl(this._self, this._then);

  final _TrendingHashtagsState _self;
  final $Res Function(_TrendingHashtagsState) _then;

/// Create a copy of TrendingHashtagsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? window = null,Object? hashtags = null,Object? error = freezed,}) {
  return _then(_TrendingHashtagsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,hashtags: null == hashtags ? _self._hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<HashtagSummary>,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
