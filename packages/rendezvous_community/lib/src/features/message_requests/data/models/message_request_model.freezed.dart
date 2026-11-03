// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageRequestModel {

 String get roomId; String get senderId; String get username; String? get displayName; String? get avatarUrl; bool get isVerified; int get messageCount; bool get hasImage; String? get lastMessagePreview; DateTime? get lastMessageAt; DateTime get createdAt;
/// Create a copy of MessageRequestModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageRequestModelCopyWith<MessageRequestModel> get copyWith => _$MessageRequestModelCopyWithImpl<MessageRequestModel>(this as MessageRequestModel, _$identity);

  /// Serializes this MessageRequestModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageRequestModel&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount)&&(identical(other.hasImage, hasImage) || other.hasImage == hasImage)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,roomId,senderId,username,displayName,avatarUrl,isVerified,messageCount,hasImage,lastMessagePreview,lastMessageAt,createdAt);

@override
String toString() {
  return 'MessageRequestModel(roomId: $roomId, senderId: $senderId, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified, messageCount: $messageCount, hasImage: $hasImage, lastMessagePreview: $lastMessagePreview, lastMessageAt: $lastMessageAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $MessageRequestModelCopyWith<$Res>  {
  factory $MessageRequestModelCopyWith(MessageRequestModel value, $Res Function(MessageRequestModel) _then) = _$MessageRequestModelCopyWithImpl;
@useResult
$Res call({
 String roomId, String senderId, String username, String? displayName, String? avatarUrl, bool isVerified, int messageCount, bool hasImage, String? lastMessagePreview, DateTime? lastMessageAt, DateTime createdAt
});




}
/// @nodoc
class _$MessageRequestModelCopyWithImpl<$Res>
    implements $MessageRequestModelCopyWith<$Res> {
  _$MessageRequestModelCopyWithImpl(this._self, this._then);

  final MessageRequestModel _self;
  final $Res Function(MessageRequestModel) _then;

/// Create a copy of MessageRequestModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = null,Object? senderId = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,Object? messageCount = null,Object? hasImage = null,Object? lastMessagePreview = freezed,Object? lastMessageAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,messageCount: null == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int,hasImage: null == hasImage ? _self.hasImage : hasImage // ignore: cast_nullable_to_non_nullable
as bool,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageRequestModel].
extension MessageRequestModelPatterns on MessageRequestModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageRequestModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageRequestModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageRequestModel value)  $default,){
final _that = this;
switch (_that) {
case _MessageRequestModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageRequestModel value)?  $default,){
final _that = this;
switch (_that) {
case _MessageRequestModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roomId,  String senderId,  String username,  String? displayName,  String? avatarUrl,  bool isVerified,  int messageCount,  bool hasImage,  String? lastMessagePreview,  DateTime? lastMessageAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageRequestModel() when $default != null:
return $default(_that.roomId,_that.senderId,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified,_that.messageCount,_that.hasImage,_that.lastMessagePreview,_that.lastMessageAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roomId,  String senderId,  String username,  String? displayName,  String? avatarUrl,  bool isVerified,  int messageCount,  bool hasImage,  String? lastMessagePreview,  DateTime? lastMessageAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _MessageRequestModel():
return $default(_that.roomId,_that.senderId,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified,_that.messageCount,_that.hasImage,_that.lastMessagePreview,_that.lastMessageAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roomId,  String senderId,  String username,  String? displayName,  String? avatarUrl,  bool isVerified,  int messageCount,  bool hasImage,  String? lastMessagePreview,  DateTime? lastMessageAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _MessageRequestModel() when $default != null:
return $default(_that.roomId,_that.senderId,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified,_that.messageCount,_that.hasImage,_that.lastMessagePreview,_that.lastMessageAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageRequestModel extends MessageRequestModel {
  const _MessageRequestModel({required this.roomId, required this.senderId, this.username = '', this.displayName, this.avatarUrl, this.isVerified = false, this.messageCount = 0, this.hasImage = false, this.lastMessagePreview, this.lastMessageAt, required this.createdAt}): super._();
  factory _MessageRequestModel.fromJson(Map<String, dynamic> json) => _$MessageRequestModelFromJson(json);

@override final  String roomId;
@override final  String senderId;
@override@JsonKey() final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override@JsonKey() final  bool isVerified;
@override@JsonKey() final  int messageCount;
@override@JsonKey() final  bool hasImage;
@override final  String? lastMessagePreview;
@override final  DateTime? lastMessageAt;
@override final  DateTime createdAt;

/// Create a copy of MessageRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageRequestModelCopyWith<_MessageRequestModel> get copyWith => __$MessageRequestModelCopyWithImpl<_MessageRequestModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageRequestModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageRequestModel&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount)&&(identical(other.hasImage, hasImage) || other.hasImage == hasImage)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,roomId,senderId,username,displayName,avatarUrl,isVerified,messageCount,hasImage,lastMessagePreview,lastMessageAt,createdAt);

@override
String toString() {
  return 'MessageRequestModel(roomId: $roomId, senderId: $senderId, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified, messageCount: $messageCount, hasImage: $hasImage, lastMessagePreview: $lastMessagePreview, lastMessageAt: $lastMessageAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$MessageRequestModelCopyWith<$Res> implements $MessageRequestModelCopyWith<$Res> {
  factory _$MessageRequestModelCopyWith(_MessageRequestModel value, $Res Function(_MessageRequestModel) _then) = __$MessageRequestModelCopyWithImpl;
@override @useResult
$Res call({
 String roomId, String senderId, String username, String? displayName, String? avatarUrl, bool isVerified, int messageCount, bool hasImage, String? lastMessagePreview, DateTime? lastMessageAt, DateTime createdAt
});




}
/// @nodoc
class __$MessageRequestModelCopyWithImpl<$Res>
    implements _$MessageRequestModelCopyWith<$Res> {
  __$MessageRequestModelCopyWithImpl(this._self, this._then);

  final _MessageRequestModel _self;
  final $Res Function(_MessageRequestModel) _then;

/// Create a copy of MessageRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = null,Object? senderId = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,Object? messageCount = null,Object? hasImage = null,Object? lastMessagePreview = freezed,Object? lastMessageAt = freezed,Object? createdAt = null,}) {
  return _then(_MessageRequestModel(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,messageCount: null == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int,hasImage: null == hasImage ? _self.hasImage : hasImage // ignore: cast_nullable_to_non_nullable
as bool,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
