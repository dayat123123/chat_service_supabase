// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stock.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Stock {

 String get code; int get watcherCount; bool get watching;
/// Create a copy of Stock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockCopyWith<Stock> get copyWith => _$StockCopyWithImpl<Stock>(this as Stock, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Stock&&(identical(other.code, code) || other.code == code)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount)&&(identical(other.watching, watching) || other.watching == watching));
}


@override
int get hashCode => Object.hash(runtimeType,code,watcherCount,watching);

@override
String toString() {
  return 'Stock(code: $code, watcherCount: $watcherCount, watching: $watching)';
}


}

/// @nodoc
abstract mixin class $StockCopyWith<$Res>  {
  factory $StockCopyWith(Stock value, $Res Function(Stock) _then) = _$StockCopyWithImpl;
@useResult
$Res call({
 String code, int watcherCount, bool watching
});




}
/// @nodoc
class _$StockCopyWithImpl<$Res>
    implements $StockCopyWith<$Res> {
  _$StockCopyWithImpl(this._self, this._then);

  final Stock _self;
  final $Res Function(Stock) _then;

/// Create a copy of Stock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? watcherCount = null,Object? watching = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,watching: null == watching ? _self.watching : watching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Stock].
extension StockPatterns on Stock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Stock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Stock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Stock value)  $default,){
final _that = this;
switch (_that) {
case _Stock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Stock value)?  $default,){
final _that = this;
switch (_that) {
case _Stock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int watcherCount,  bool watching)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Stock() when $default != null:
return $default(_that.code,_that.watcherCount,_that.watching);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int watcherCount,  bool watching)  $default,) {final _that = this;
switch (_that) {
case _Stock():
return $default(_that.code,_that.watcherCount,_that.watching);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int watcherCount,  bool watching)?  $default,) {final _that = this;
switch (_that) {
case _Stock() when $default != null:
return $default(_that.code,_that.watcherCount,_that.watching);case _:
  return null;

}
}

}

/// @nodoc


class _Stock implements Stock {
  const _Stock({required this.code, this.watcherCount = 0, this.watching = false});
  

@override final  String code;
@override@JsonKey() final  int watcherCount;
@override@JsonKey() final  bool watching;

/// Create a copy of Stock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockCopyWith<_Stock> get copyWith => __$StockCopyWithImpl<_Stock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Stock&&(identical(other.code, code) || other.code == code)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount)&&(identical(other.watching, watching) || other.watching == watching));
}


@override
int get hashCode => Object.hash(runtimeType,code,watcherCount,watching);

@override
String toString() {
  return 'Stock(code: $code, watcherCount: $watcherCount, watching: $watching)';
}


}

/// @nodoc
abstract mixin class _$StockCopyWith<$Res> implements $StockCopyWith<$Res> {
  factory _$StockCopyWith(_Stock value, $Res Function(_Stock) _then) = __$StockCopyWithImpl;
@override @useResult
$Res call({
 String code, int watcherCount, bool watching
});




}
/// @nodoc
class __$StockCopyWithImpl<$Res>
    implements _$StockCopyWith<$Res> {
  __$StockCopyWithImpl(this._self, this._then);

  final _Stock _self;
  final $Res Function(_Stock) _then;

/// Create a copy of Stock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? watcherCount = null,Object? watching = null,}) {
  return _then(_Stock(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,watching: null == watching ? _self.watching : watching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
