// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stock_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StockState {

 Stock? get stock; bool get loaded; bool get watching; bool get joining; Object? get error; int get errorId;
/// Create a copy of StockState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockStateCopyWith<StockState> get copyWith => _$StockStateCopyWithImpl<StockState>(this as StockState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockState&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.watching, watching) || other.watching == watching)&&(identical(other.joining, joining) || other.joining == joining)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,stock,loaded,watching,joining,const DeepCollectionEquality().hash(error),errorId);

@override
String toString() {
  return 'StockState(stock: $stock, loaded: $loaded, watching: $watching, joining: $joining, error: $error, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class $StockStateCopyWith<$Res>  {
  factory $StockStateCopyWith(StockState value, $Res Function(StockState) _then) = _$StockStateCopyWithImpl;
@useResult
$Res call({
 Stock? stock, bool loaded, bool watching, bool joining, Object? error, int errorId
});


$StockCopyWith<$Res>? get stock;

}
/// @nodoc
class _$StockStateCopyWithImpl<$Res>
    implements $StockStateCopyWith<$Res> {
  _$StockStateCopyWithImpl(this._self, this._then);

  final StockState _self;
  final $Res Function(StockState) _then;

/// Create a copy of StockState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stock = freezed,Object? loaded = null,Object? watching = null,Object? joining = null,Object? error = freezed,Object? errorId = null,}) {
  return _then(_self.copyWith(
stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as Stock?,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,watching: null == watching ? _self.watching : watching // ignore: cast_nullable_to_non_nullable
as bool,joining: null == joining ? _self.joining : joining // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of StockState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StockCopyWith<$Res>? get stock {
    if (_self.stock == null) {
    return null;
  }

  return $StockCopyWith<$Res>(_self.stock!, (value) {
    return _then(_self.copyWith(stock: value));
  });
}
}


/// Adds pattern-matching-related methods to [StockState].
extension StockStatePatterns on StockState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockState value)  $default,){
final _that = this;
switch (_that) {
case _StockState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockState value)?  $default,){
final _that = this;
switch (_that) {
case _StockState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Stock? stock,  bool loaded,  bool watching,  bool joining,  Object? error,  int errorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StockState() when $default != null:
return $default(_that.stock,_that.loaded,_that.watching,_that.joining,_that.error,_that.errorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Stock? stock,  bool loaded,  bool watching,  bool joining,  Object? error,  int errorId)  $default,) {final _that = this;
switch (_that) {
case _StockState():
return $default(_that.stock,_that.loaded,_that.watching,_that.joining,_that.error,_that.errorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Stock? stock,  bool loaded,  bool watching,  bool joining,  Object? error,  int errorId)?  $default,) {final _that = this;
switch (_that) {
case _StockState() when $default != null:
return $default(_that.stock,_that.loaded,_that.watching,_that.joining,_that.error,_that.errorId);case _:
  return null;

}
}

}

/// @nodoc


class _StockState implements StockState {
  const _StockState({this.stock, this.loaded = false, this.watching = false, this.joining = false, this.error, this.errorId = 0});
  

@override final  Stock? stock;
@override@JsonKey() final  bool loaded;
@override@JsonKey() final  bool watching;
@override@JsonKey() final  bool joining;
@override final  Object? error;
@override@JsonKey() final  int errorId;

/// Create a copy of StockState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockStateCopyWith<_StockState> get copyWith => __$StockStateCopyWithImpl<_StockState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockState&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.watching, watching) || other.watching == watching)&&(identical(other.joining, joining) || other.joining == joining)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,stock,loaded,watching,joining,const DeepCollectionEquality().hash(error),errorId);

@override
String toString() {
  return 'StockState(stock: $stock, loaded: $loaded, watching: $watching, joining: $joining, error: $error, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class _$StockStateCopyWith<$Res> implements $StockStateCopyWith<$Res> {
  factory _$StockStateCopyWith(_StockState value, $Res Function(_StockState) _then) = __$StockStateCopyWithImpl;
@override @useResult
$Res call({
 Stock? stock, bool loaded, bool watching, bool joining, Object? error, int errorId
});


@override $StockCopyWith<$Res>? get stock;

}
/// @nodoc
class __$StockStateCopyWithImpl<$Res>
    implements _$StockStateCopyWith<$Res> {
  __$StockStateCopyWithImpl(this._self, this._then);

  final _StockState _self;
  final $Res Function(_StockState) _then;

/// Create a copy of StockState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stock = freezed,Object? loaded = null,Object? watching = null,Object? joining = null,Object? error = freezed,Object? errorId = null,}) {
  return _then(_StockState(
stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as Stock?,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,watching: null == watching ? _self.watching : watching // ignore: cast_nullable_to_non_nullable
as bool,joining: null == joining ? _self.joining : joining // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of StockState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StockCopyWith<$Res>? get stock {
    if (_self.stock == null) {
    return null;
  }

  return $StockCopyWith<$Res>(_self.stock!, (value) {
    return _then(_self.copyWith(stock: value));
  });
}
}

// dart format on
