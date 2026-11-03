// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppNotification {

 String get id; NotificationType get type; UserSummary? get actor; Map<String, Object?> get payload; int get eventCount; DateTime? get readAt; DateTime get createdAt; String get cursor; int get actorCount; List<UserSummary> get actors;
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationCopyWith<AppNotification> get copyWith => _$AppNotificationCopyWithImpl<AppNotification>(this as AppNotification, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actor, actor) || other.actor == actor)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.actorCount, actorCount) || other.actorCount == actorCount)&&const DeepCollectionEquality().equals(other.actors, actors));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,actor,const DeepCollectionEquality().hash(payload),eventCount,readAt,createdAt,cursor,actorCount,const DeepCollectionEquality().hash(actors));

@override
String toString() {
  return 'AppNotification(id: $id, type: $type, actor: $actor, payload: $payload, eventCount: $eventCount, readAt: $readAt, createdAt: $createdAt, cursor: $cursor, actorCount: $actorCount, actors: $actors)';
}


}

/// @nodoc
abstract mixin class $AppNotificationCopyWith<$Res>  {
  factory $AppNotificationCopyWith(AppNotification value, $Res Function(AppNotification) _then) = _$AppNotificationCopyWithImpl;
@useResult
$Res call({
 String id, NotificationType type, UserSummary? actor, Map<String, Object?> payload, int eventCount, DateTime? readAt, DateTime createdAt, String cursor, int actorCount, List<UserSummary> actors
});


$UserSummaryCopyWith<$Res>? get actor;

}
/// @nodoc
class _$AppNotificationCopyWithImpl<$Res>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._self, this._then);

  final AppNotification _self;
  final $Res Function(AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? actor = freezed,Object? payload = null,Object? eventCount = null,Object? readAt = freezed,Object? createdAt = null,Object? cursor = null,Object? actorCount = null,Object? actors = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,actor: freezed == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as UserSummary?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,actorCount: null == actorCount ? _self.actorCount : actorCount // ignore: cast_nullable_to_non_nullable
as int,actors: null == actors ? _self.actors : actors // ignore: cast_nullable_to_non_nullable
as List<UserSummary>,
  ));
}
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get actor {
    if (_self.actor == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.actor!, (value) {
    return _then(_self.copyWith(actor: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppNotification].
extension AppNotificationPatterns on AppNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotification value)  $default,){
final _that = this;
switch (_that) {
case _AppNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotification value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  NotificationType type,  UserSummary? actor,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor,  int actorCount,  List<UserSummary> actors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.actor,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor,_that.actorCount,_that.actors);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  NotificationType type,  UserSummary? actor,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor,  int actorCount,  List<UserSummary> actors)  $default,) {final _that = this;
switch (_that) {
case _AppNotification():
return $default(_that.id,_that.type,_that.actor,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor,_that.actorCount,_that.actors);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  NotificationType type,  UserSummary? actor,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor,  int actorCount,  List<UserSummary> actors)?  $default,) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.actor,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor,_that.actorCount,_that.actors);case _:
  return null;

}
}

}

/// @nodoc


class _AppNotification extends AppNotification {
  const _AppNotification({required this.id, required this.type, this.actor, final  Map<String, Object?> payload = const <String, Object?>{}, this.eventCount = 1, this.readAt, required this.createdAt, required this.cursor, this.actorCount = 1, final  List<UserSummary> actors = const <UserSummary>[]}): _payload = payload,_actors = actors,super._();
  

@override final  String id;
@override final  NotificationType type;
@override final  UserSummary? actor;
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
@override@JsonKey() final  int actorCount;
 final  List<UserSummary> _actors;
@override@JsonKey() List<UserSummary> get actors {
  if (_actors is EqualUnmodifiableListView) return _actors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actors);
}


/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationCopyWith<_AppNotification> get copyWith => __$AppNotificationCopyWithImpl<_AppNotification>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actor, actor) || other.actor == actor)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.actorCount, actorCount) || other.actorCount == actorCount)&&const DeepCollectionEquality().equals(other._actors, _actors));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,actor,const DeepCollectionEquality().hash(_payload),eventCount,readAt,createdAt,cursor,actorCount,const DeepCollectionEquality().hash(_actors));

@override
String toString() {
  return 'AppNotification(id: $id, type: $type, actor: $actor, payload: $payload, eventCount: $eventCount, readAt: $readAt, createdAt: $createdAt, cursor: $cursor, actorCount: $actorCount, actors: $actors)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationCopyWith<$Res> implements $AppNotificationCopyWith<$Res> {
  factory _$AppNotificationCopyWith(_AppNotification value, $Res Function(_AppNotification) _then) = __$AppNotificationCopyWithImpl;
@override @useResult
$Res call({
 String id, NotificationType type, UserSummary? actor, Map<String, Object?> payload, int eventCount, DateTime? readAt, DateTime createdAt, String cursor, int actorCount, List<UserSummary> actors
});


@override $UserSummaryCopyWith<$Res>? get actor;

}
/// @nodoc
class __$AppNotificationCopyWithImpl<$Res>
    implements _$AppNotificationCopyWith<$Res> {
  __$AppNotificationCopyWithImpl(this._self, this._then);

  final _AppNotification _self;
  final $Res Function(_AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? actor = freezed,Object? payload = null,Object? eventCount = null,Object? readAt = freezed,Object? createdAt = null,Object? cursor = null,Object? actorCount = null,Object? actors = null,}) {
  return _then(_AppNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,actor: freezed == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as UserSummary?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,actorCount: null == actorCount ? _self.actorCount : actorCount // ignore: cast_nullable_to_non_nullable
as int,actors: null == actors ? _self._actors : actors // ignore: cast_nullable_to_non_nullable
as List<UserSummary>,
  ));
}

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get actor {
    if (_self.actor == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.actor!, (value) {
    return _then(_self.copyWith(actor: value));
  });
}
}

// dart format on
