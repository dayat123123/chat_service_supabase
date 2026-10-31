// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stock_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StockModel {

 String get code; int get watcherCount; bool get watching;
/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockModelCopyWith<StockModel> get copyWith => _$StockModelCopyWithImpl<StockModel>(this as StockModel, _$identity);

  /// Serializes this StockModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount)&&(identical(other.watching, watching) || other.watching == watching));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,watcherCount,watching);

@override
String toString() {
  return 'StockModel(code: $code, watcherCount: $watcherCount, watching: $watching)';
}


}

/// @nodoc
abstract mixin class $StockModelCopyWith<$Res>  {
  factory $StockModelCopyWith(StockModel value, $Res Function(StockModel) _then) = _$StockModelCopyWithImpl;
@useResult
$Res call({
 String code, int watcherCount, bool watching
});




}
/// @nodoc
class _$StockModelCopyWithImpl<$Res>
    implements $StockModelCopyWith<$Res> {
  _$StockModelCopyWithImpl(this._self, this._then);

  final StockModel _self;
  final $Res Function(StockModel) _then;

/// Create a copy of StockModel
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


/// Adds pattern-matching-related methods to [StockModel].
extension StockModelPatterns on StockModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockModel value)  $default,){
final _that = this;
switch (_that) {
case _StockModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockModel value)?  $default,){
final _that = this;
switch (_that) {
case _StockModel() when $default != null:
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
case _StockModel() when $default != null:
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
case _StockModel():
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
case _StockModel() when $default != null:
return $default(_that.code,_that.watcherCount,_that.watching);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StockModel extends StockModel {
  const _StockModel({required this.code, this.watcherCount = 0, this.watching = false}): super._();
  factory _StockModel.fromJson(Map<String, dynamic> json) => _$StockModelFromJson(json);

@override final  String code;
@override@JsonKey() final  int watcherCount;
@override@JsonKey() final  bool watching;

/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockModelCopyWith<_StockModel> get copyWith => __$StockModelCopyWithImpl<_StockModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StockModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount)&&(identical(other.watching, watching) || other.watching == watching));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,watcherCount,watching);

@override
String toString() {
  return 'StockModel(code: $code, watcherCount: $watcherCount, watching: $watching)';
}


}

/// @nodoc
abstract mixin class _$StockModelCopyWith<$Res> implements $StockModelCopyWith<$Res> {
  factory _$StockModelCopyWith(_StockModel value, $Res Function(_StockModel) _then) = __$StockModelCopyWithImpl;
@override @useResult
$Res call({
 String code, int watcherCount, bool watching
});




}
/// @nodoc
class __$StockModelCopyWithImpl<$Res>
    implements _$StockModelCopyWith<$Res> {
  __$StockModelCopyWithImpl(this._self, this._then);

  final _StockModel _self;
  final $Res Function(_StockModel) _then;

/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? watcherCount = null,Object? watching = null,}) {
  return _then(_StockModel(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,watching: null == watching ? _self.watching : watching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
