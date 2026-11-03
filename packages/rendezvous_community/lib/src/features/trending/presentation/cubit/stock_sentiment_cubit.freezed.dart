// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stock_sentiment_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StockSentimentState {

 LoadStatus get status; TrendWindow get window; StockSentiment? get sentiment; Object? get error;
/// Create a copy of StockSentimentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockSentimentStateCopyWith<StockSentimentState> get copyWith => _$StockSentimentStateCopyWithImpl<StockSentimentState>(this as StockSentimentState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockSentimentState&&(identical(other.status, status) || other.status == status)&&(identical(other.window, window) || other.window == window)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,window,sentiment,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'StockSentimentState(status: $status, window: $window, sentiment: $sentiment, error: $error)';
}


}

/// @nodoc
abstract mixin class $StockSentimentStateCopyWith<$Res>  {
  factory $StockSentimentStateCopyWith(StockSentimentState value, $Res Function(StockSentimentState) _then) = _$StockSentimentStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, TrendWindow window, StockSentiment? sentiment, Object? error
});


$StockSentimentCopyWith<$Res>? get sentiment;

}
/// @nodoc
class _$StockSentimentStateCopyWithImpl<$Res>
    implements $StockSentimentStateCopyWith<$Res> {
  _$StockSentimentStateCopyWithImpl(this._self, this._then);

  final StockSentimentState _self;
  final $Res Function(StockSentimentState) _then;

/// Create a copy of StockSentimentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? window = null,Object? sentiment = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as StockSentiment?,error: freezed == error ? _self.error : error ,
  ));
}
/// Create a copy of StockSentimentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StockSentimentCopyWith<$Res>? get sentiment {
    if (_self.sentiment == null) {
    return null;
  }

  return $StockSentimentCopyWith<$Res>(_self.sentiment!, (value) {
    return _then(_self.copyWith(sentiment: value));
  });
}
}


/// Adds pattern-matching-related methods to [StockSentimentState].
extension StockSentimentStatePatterns on StockSentimentState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockSentimentState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockSentimentState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockSentimentState value)  $default,){
final _that = this;
switch (_that) {
case _StockSentimentState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockSentimentState value)?  $default,){
final _that = this;
switch (_that) {
case _StockSentimentState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  TrendWindow window,  StockSentiment? sentiment,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StockSentimentState() when $default != null:
return $default(_that.status,_that.window,_that.sentiment,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  TrendWindow window,  StockSentiment? sentiment,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _StockSentimentState():
return $default(_that.status,_that.window,_that.sentiment,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  TrendWindow window,  StockSentiment? sentiment,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _StockSentimentState() when $default != null:
return $default(_that.status,_that.window,_that.sentiment,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _StockSentimentState extends StockSentimentState {
  const _StockSentimentState({this.status = LoadStatus.initial, this.window = TrendWindow.day, this.sentiment, this.error}): super._();
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  TrendWindow window;
@override final  StockSentiment? sentiment;
@override final  Object? error;

/// Create a copy of StockSentimentState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockSentimentStateCopyWith<_StockSentimentState> get copyWith => __$StockSentimentStateCopyWithImpl<_StockSentimentState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockSentimentState&&(identical(other.status, status) || other.status == status)&&(identical(other.window, window) || other.window == window)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,window,sentiment,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'StockSentimentState(status: $status, window: $window, sentiment: $sentiment, error: $error)';
}


}

/// @nodoc
abstract mixin class _$StockSentimentStateCopyWith<$Res> implements $StockSentimentStateCopyWith<$Res> {
  factory _$StockSentimentStateCopyWith(_StockSentimentState value, $Res Function(_StockSentimentState) _then) = __$StockSentimentStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, TrendWindow window, StockSentiment? sentiment, Object? error
});


@override $StockSentimentCopyWith<$Res>? get sentiment;

}
/// @nodoc
class __$StockSentimentStateCopyWithImpl<$Res>
    implements _$StockSentimentStateCopyWith<$Res> {
  __$StockSentimentStateCopyWithImpl(this._self, this._then);

  final _StockSentimentState _self;
  final $Res Function(_StockSentimentState) _then;

/// Create a copy of StockSentimentState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? window = null,Object? sentiment = freezed,Object? error = freezed,}) {
  return _then(_StockSentimentState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as StockSentiment?,error: freezed == error ? _self.error : error ,
  ));
}

/// Create a copy of StockSentimentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StockSentimentCopyWith<$Res>? get sentiment {
    if (_self.sentiment == null) {
    return null;
  }

  return $StockSentimentCopyWith<$Res>(_self.sentiment!, (value) {
    return _then(_self.copyWith(sentiment: value));
  });
}
}

// dart format on
