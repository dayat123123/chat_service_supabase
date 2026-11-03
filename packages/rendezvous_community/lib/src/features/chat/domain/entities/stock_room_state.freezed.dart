// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stock_room_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StockRoomState {

 String? get roomId; String? get stockCode; int get slowModeSeconds; DateTime? get slowModeUntil; String? get slowModeSource; int get waitSeconds; ChatMessage? get pinnedMessage; DateTime? get pinnedAt;
/// Create a copy of StockRoomState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockRoomStateCopyWith<StockRoomState> get copyWith => _$StockRoomStateCopyWithImpl<StockRoomState>(this as StockRoomState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockRoomState&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.slowModeSeconds, slowModeSeconds) || other.slowModeSeconds == slowModeSeconds)&&(identical(other.slowModeUntil, slowModeUntil) || other.slowModeUntil == slowModeUntil)&&(identical(other.slowModeSource, slowModeSource) || other.slowModeSource == slowModeSource)&&(identical(other.waitSeconds, waitSeconds) || other.waitSeconds == waitSeconds)&&(identical(other.pinnedMessage, pinnedMessage) || other.pinnedMessage == pinnedMessage)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt));
}


@override
int get hashCode => Object.hash(runtimeType,roomId,stockCode,slowModeSeconds,slowModeUntil,slowModeSource,waitSeconds,pinnedMessage,pinnedAt);

@override
String toString() {
  return 'StockRoomState(roomId: $roomId, stockCode: $stockCode, slowModeSeconds: $slowModeSeconds, slowModeUntil: $slowModeUntil, slowModeSource: $slowModeSource, waitSeconds: $waitSeconds, pinnedMessage: $pinnedMessage, pinnedAt: $pinnedAt)';
}


}

/// @nodoc
abstract mixin class $StockRoomStateCopyWith<$Res>  {
  factory $StockRoomStateCopyWith(StockRoomState value, $Res Function(StockRoomState) _then) = _$StockRoomStateCopyWithImpl;
@useResult
$Res call({
 String? roomId, String? stockCode, int slowModeSeconds, DateTime? slowModeUntil, String? slowModeSource, int waitSeconds, ChatMessage? pinnedMessage, DateTime? pinnedAt
});


$ChatMessageCopyWith<$Res>? get pinnedMessage;

}
/// @nodoc
class _$StockRoomStateCopyWithImpl<$Res>
    implements $StockRoomStateCopyWith<$Res> {
  _$StockRoomStateCopyWithImpl(this._self, this._then);

  final StockRoomState _self;
  final $Res Function(StockRoomState) _then;

/// Create a copy of StockRoomState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = freezed,Object? stockCode = freezed,Object? slowModeSeconds = null,Object? slowModeUntil = freezed,Object? slowModeSource = freezed,Object? waitSeconds = null,Object? pinnedMessage = freezed,Object? pinnedAt = freezed,}) {
  return _then(_self.copyWith(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,slowModeSeconds: null == slowModeSeconds ? _self.slowModeSeconds : slowModeSeconds // ignore: cast_nullable_to_non_nullable
as int,slowModeUntil: freezed == slowModeUntil ? _self.slowModeUntil : slowModeUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,slowModeSource: freezed == slowModeSource ? _self.slowModeSource : slowModeSource // ignore: cast_nullable_to_non_nullable
as String?,waitSeconds: null == waitSeconds ? _self.waitSeconds : waitSeconds // ignore: cast_nullable_to_non_nullable
as int,pinnedMessage: freezed == pinnedMessage ? _self.pinnedMessage : pinnedMessage // ignore: cast_nullable_to_non_nullable
as ChatMessage?,pinnedAt: freezed == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of StockRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<$Res>? get pinnedMessage {
    if (_self.pinnedMessage == null) {
    return null;
  }

  return $ChatMessageCopyWith<$Res>(_self.pinnedMessage!, (value) {
    return _then(_self.copyWith(pinnedMessage: value));
  });
}
}


/// Adds pattern-matching-related methods to [StockRoomState].
extension StockRoomStatePatterns on StockRoomState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockRoomState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockRoomState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockRoomState value)  $default,){
final _that = this;
switch (_that) {
case _StockRoomState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockRoomState value)?  $default,){
final _that = this;
switch (_that) {
case _StockRoomState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? roomId,  String? stockCode,  int slowModeSeconds,  DateTime? slowModeUntil,  String? slowModeSource,  int waitSeconds,  ChatMessage? pinnedMessage,  DateTime? pinnedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StockRoomState() when $default != null:
return $default(_that.roomId,_that.stockCode,_that.slowModeSeconds,_that.slowModeUntil,_that.slowModeSource,_that.waitSeconds,_that.pinnedMessage,_that.pinnedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? roomId,  String? stockCode,  int slowModeSeconds,  DateTime? slowModeUntil,  String? slowModeSource,  int waitSeconds,  ChatMessage? pinnedMessage,  DateTime? pinnedAt)  $default,) {final _that = this;
switch (_that) {
case _StockRoomState():
return $default(_that.roomId,_that.stockCode,_that.slowModeSeconds,_that.slowModeUntil,_that.slowModeSource,_that.waitSeconds,_that.pinnedMessage,_that.pinnedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? roomId,  String? stockCode,  int slowModeSeconds,  DateTime? slowModeUntil,  String? slowModeSource,  int waitSeconds,  ChatMessage? pinnedMessage,  DateTime? pinnedAt)?  $default,) {final _that = this;
switch (_that) {
case _StockRoomState() when $default != null:
return $default(_that.roomId,_that.stockCode,_that.slowModeSeconds,_that.slowModeUntil,_that.slowModeSource,_that.waitSeconds,_that.pinnedMessage,_that.pinnedAt);case _:
  return null;

}
}

}

/// @nodoc


class _StockRoomState extends StockRoomState {
  const _StockRoomState({this.roomId, this.stockCode, this.slowModeSeconds = 0, this.slowModeUntil, this.slowModeSource, this.waitSeconds = 0, this.pinnedMessage, this.pinnedAt}): super._();
  

@override final  String? roomId;
@override final  String? stockCode;
@override@JsonKey() final  int slowModeSeconds;
@override final  DateTime? slowModeUntil;
@override final  String? slowModeSource;
@override@JsonKey() final  int waitSeconds;
@override final  ChatMessage? pinnedMessage;
@override final  DateTime? pinnedAt;

/// Create a copy of StockRoomState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockRoomStateCopyWith<_StockRoomState> get copyWith => __$StockRoomStateCopyWithImpl<_StockRoomState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockRoomState&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.slowModeSeconds, slowModeSeconds) || other.slowModeSeconds == slowModeSeconds)&&(identical(other.slowModeUntil, slowModeUntil) || other.slowModeUntil == slowModeUntil)&&(identical(other.slowModeSource, slowModeSource) || other.slowModeSource == slowModeSource)&&(identical(other.waitSeconds, waitSeconds) || other.waitSeconds == waitSeconds)&&(identical(other.pinnedMessage, pinnedMessage) || other.pinnedMessage == pinnedMessage)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt));
}


@override
int get hashCode => Object.hash(runtimeType,roomId,stockCode,slowModeSeconds,slowModeUntil,slowModeSource,waitSeconds,pinnedMessage,pinnedAt);

@override
String toString() {
  return 'StockRoomState(roomId: $roomId, stockCode: $stockCode, slowModeSeconds: $slowModeSeconds, slowModeUntil: $slowModeUntil, slowModeSource: $slowModeSource, waitSeconds: $waitSeconds, pinnedMessage: $pinnedMessage, pinnedAt: $pinnedAt)';
}


}

/// @nodoc
abstract mixin class _$StockRoomStateCopyWith<$Res> implements $StockRoomStateCopyWith<$Res> {
  factory _$StockRoomStateCopyWith(_StockRoomState value, $Res Function(_StockRoomState) _then) = __$StockRoomStateCopyWithImpl;
@override @useResult
$Res call({
 String? roomId, String? stockCode, int slowModeSeconds, DateTime? slowModeUntil, String? slowModeSource, int waitSeconds, ChatMessage? pinnedMessage, DateTime? pinnedAt
});


@override $ChatMessageCopyWith<$Res>? get pinnedMessage;

}
/// @nodoc
class __$StockRoomStateCopyWithImpl<$Res>
    implements _$StockRoomStateCopyWith<$Res> {
  __$StockRoomStateCopyWithImpl(this._self, this._then);

  final _StockRoomState _self;
  final $Res Function(_StockRoomState) _then;

/// Create a copy of StockRoomState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = freezed,Object? stockCode = freezed,Object? slowModeSeconds = null,Object? slowModeUntil = freezed,Object? slowModeSource = freezed,Object? waitSeconds = null,Object? pinnedMessage = freezed,Object? pinnedAt = freezed,}) {
  return _then(_StockRoomState(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,slowModeSeconds: null == slowModeSeconds ? _self.slowModeSeconds : slowModeSeconds // ignore: cast_nullable_to_non_nullable
as int,slowModeUntil: freezed == slowModeUntil ? _self.slowModeUntil : slowModeUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,slowModeSource: freezed == slowModeSource ? _self.slowModeSource : slowModeSource // ignore: cast_nullable_to_non_nullable
as String?,waitSeconds: null == waitSeconds ? _self.waitSeconds : waitSeconds // ignore: cast_nullable_to_non_nullable
as int,pinnedMessage: freezed == pinnedMessage ? _self.pinnedMessage : pinnedMessage // ignore: cast_nullable_to_non_nullable
as ChatMessage?,pinnedAt: freezed == pinnedAt ? _self.pinnedAt : pinnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of StockRoomState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatMessageCopyWith<$Res>? get pinnedMessage {
    if (_self.pinnedMessage == null) {
    return null;
  }

  return $ChatMessageCopyWith<$Res>(_self.pinnedMessage!, (value) {
    return _then(_self.copyWith(pinnedMessage: value));
  });
}
}

// dart format on
