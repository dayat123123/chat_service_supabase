// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationModel {

 String get id; String get type; String? get actorId; String? get actorUsername; String? get actorDisplayName; String? get actorAvatarUrl; Map<String, Object?> get payload; int get eventCount; DateTime? get readAt; DateTime get createdAt; String get cursor; int? get actorCount; List<Map<String, dynamic>> get actors;
/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationModelCopyWith<NotificationModel> get copyWith => _$NotificationModelCopyWithImpl<NotificationModel>(this as NotificationModel, _$identity);

  /// Serializes this NotificationModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.actorUsername, actorUsername) || other.actorUsername == actorUsername)&&(identical(other.actorDisplayName, actorDisplayName) || other.actorDisplayName == actorDisplayName)&&(identical(other.actorAvatarUrl, actorAvatarUrl) || other.actorAvatarUrl == actorAvatarUrl)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.actorCount, actorCount) || other.actorCount == actorCount)&&const DeepCollectionEquality().equals(other.actors, actors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,actorId,actorUsername,actorDisplayName,actorAvatarUrl,const DeepCollectionEquality().hash(payload),eventCount,readAt,createdAt,cursor,actorCount,const DeepCollectionEquality().hash(actors));

@override
String toString() {
  return 'NotificationModel(id: $id, type: $type, actorId: $actorId, actorUsername: $actorUsername, actorDisplayName: $actorDisplayName, actorAvatarUrl: $actorAvatarUrl, payload: $payload, eventCount: $eventCount, readAt: $readAt, createdAt: $createdAt, cursor: $cursor, actorCount: $actorCount, actors: $actors)';
}


}

/// @nodoc
abstract mixin class $NotificationModelCopyWith<$Res>  {
  factory $NotificationModelCopyWith(NotificationModel value, $Res Function(NotificationModel) _then) = _$NotificationModelCopyWithImpl;
@useResult
$Res call({
 String id, String type, String? actorId, String? actorUsername, String? actorDisplayName, String? actorAvatarUrl, Map<String, Object?> payload, int eventCount, DateTime? readAt, DateTime createdAt, String cursor, int? actorCount, List<Map<String, dynamic>> actors
});




}
/// @nodoc
class _$NotificationModelCopyWithImpl<$Res>
    implements $NotificationModelCopyWith<$Res> {
  _$NotificationModelCopyWithImpl(this._self, this._then);

  final NotificationModel _self;
  final $Res Function(NotificationModel) _then;

/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? actorId = freezed,Object? actorUsername = freezed,Object? actorDisplayName = freezed,Object? actorAvatarUrl = freezed,Object? payload = null,Object? eventCount = null,Object? readAt = freezed,Object? createdAt = null,Object? cursor = null,Object? actorCount = freezed,Object? actors = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,actorUsername: freezed == actorUsername ? _self.actorUsername : actorUsername // ignore: cast_nullable_to_non_nullable
as String?,actorDisplayName: freezed == actorDisplayName ? _self.actorDisplayName : actorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,actorAvatarUrl: freezed == actorAvatarUrl ? _self.actorAvatarUrl : actorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,actorCount: freezed == actorCount ? _self.actorCount : actorCount // ignore: cast_nullable_to_non_nullable
as int?,actors: null == actors ? _self.actors : actors // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationModel].
extension NotificationModelPatterns on NotificationModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationModel value)  $default,){
final _that = this;
switch (_that) {
case _NotificationModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationModel value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String? actorId,  String? actorUsername,  String? actorDisplayName,  String? actorAvatarUrl,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor,  int? actorCount,  List<Map<String, dynamic>> actors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
return $default(_that.id,_that.type,_that.actorId,_that.actorUsername,_that.actorDisplayName,_that.actorAvatarUrl,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor,_that.actorCount,_that.actors);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String? actorId,  String? actorUsername,  String? actorDisplayName,  String? actorAvatarUrl,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor,  int? actorCount,  List<Map<String, dynamic>> actors)  $default,) {final _that = this;
switch (_that) {
case _NotificationModel():
return $default(_that.id,_that.type,_that.actorId,_that.actorUsername,_that.actorDisplayName,_that.actorAvatarUrl,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor,_that.actorCount,_that.actors);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String? actorId,  String? actorUsername,  String? actorDisplayName,  String? actorAvatarUrl,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor,  int? actorCount,  List<Map<String, dynamic>> actors)?  $default,) {final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
return $default(_that.id,_that.type,_that.actorId,_that.actorUsername,_that.actorDisplayName,_that.actorAvatarUrl,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor,_that.actorCount,_that.actors);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationModel extends NotificationModel {
  const _NotificationModel({required this.id, required this.type, this.actorId, this.actorUsername, this.actorDisplayName, this.actorAvatarUrl, final  Map<String, Object?> payload = const <String, Object?>{}, this.eventCount = 1, this.readAt, required this.createdAt, required this.cursor, this.actorCount, final  List<Map<String, dynamic>> actors = const <Map<String, dynamic>>[]}): _payload = payload,_actors = actors,super._();
  factory _NotificationModel.fromJson(Map<String, dynamic> json) => _$NotificationModelFromJson(json);

@override final  String id;
@override final  String type;
@override final  String? actorId;
@override final  String? actorUsername;
@override final  String? actorDisplayName;
@override final  String? actorAvatarUrl;
 final  Map<String, Object?> _payload;
@override@JsonKey() Map<String, Object?> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override@JsonKey() final  int eventCount;
@override final  DateTime? readAt;
@override final  DateTime createdAt;
@override final  String cursor;
@override final  int? actorCount;
 final  List<Map<String, dynamic>> _actors;
@override@JsonKey() List<Map<String, dynamic>> get actors {
  if (_actors is EqualUnmodifiableListView) return _actors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actors);
}


/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationModelCopyWith<_NotificationModel> get copyWith => __$NotificationModelCopyWithImpl<_NotificationModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.actorUsername, actorUsername) || other.actorUsername == actorUsername)&&(identical(other.actorDisplayName, actorDisplayName) || other.actorDisplayName == actorDisplayName)&&(identical(other.actorAvatarUrl, actorAvatarUrl) || other.actorAvatarUrl == actorAvatarUrl)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.actorCount, actorCount) || other.actorCount == actorCount)&&const DeepCollectionEquality().equals(other._actors, _actors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,actorId,actorUsername,actorDisplayName,actorAvatarUrl,const DeepCollectionEquality().hash(_payload),eventCount,readAt,createdAt,cursor,actorCount,const DeepCollectionEquality().hash(_actors));

@override
String toString() {
  return 'NotificationModel(id: $id, type: $type, actorId: $actorId, actorUsername: $actorUsername, actorDisplayName: $actorDisplayName, actorAvatarUrl: $actorAvatarUrl, payload: $payload, eventCount: $eventCount, readAt: $readAt, createdAt: $createdAt, cursor: $cursor, actorCount: $actorCount, actors: $actors)';
}


}

/// @nodoc
abstract mixin class _$NotificationModelCopyWith<$Res> implements $NotificationModelCopyWith<$Res> {
  factory _$NotificationModelCopyWith(_NotificationModel value, $Res Function(_NotificationModel) _then) = __$NotificationModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String? actorId, String? actorUsername, String? actorDisplayName, String? actorAvatarUrl, Map<String, Object?> payload, int eventCount, DateTime? readAt, DateTime createdAt, String cursor, int? actorCount, List<Map<String, dynamic>> actors
});




}
/// @nodoc
class __$NotificationModelCopyWithImpl<$Res>
    implements _$NotificationModelCopyWith<$Res> {
  __$NotificationModelCopyWithImpl(this._self, this._then);

  final _NotificationModel _self;
  final $Res Function(_NotificationModel) _then;

/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? actorId = freezed,Object? actorUsername = freezed,Object? actorDisplayName = freezed,Object? actorAvatarUrl = freezed,Object? payload = null,Object? eventCount = null,Object? readAt = freezed,Object? createdAt = null,Object? cursor = null,Object? actorCount = freezed,Object? actors = null,}) {
  return _then(_NotificationModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,actorUsername: freezed == actorUsername ? _self.actorUsername : actorUsername // ignore: cast_nullable_to_non_nullable
as String?,actorDisplayName: freezed == actorDisplayName ? _self.actorDisplayName : actorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,actorAvatarUrl: freezed == actorAvatarUrl ? _self.actorAvatarUrl : actorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,actorCount: freezed == actorCount ? _self.actorCount : actorCount // ignore: cast_nullable_to_non_nullable
as int?,actors: null == actors ? _self._actors : actors // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}

// dart format on
