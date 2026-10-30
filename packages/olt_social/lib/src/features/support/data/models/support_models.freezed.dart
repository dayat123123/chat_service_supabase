// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SupportTicketModel {

 String get id; String get ticketNumber; String get roomId; String get topic; String? get topicName; String get status; int? get queueAhead; Map<String, dynamic>? get agent; Map<String, dynamic>? get complaint; DateTime get createdAt; DateTime? get resolvedAt; DateTime? get closedAt; DateTime? get reopenUntil; int? get rating; bool get canRate;
/// Create a copy of SupportTicketModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportTicketModelCopyWith<SupportTicketModel> get copyWith => _$SupportTicketModelCopyWithImpl<SupportTicketModel>(this as SupportTicketModel, _$identity);

  /// Serializes this SupportTicketModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTicketModel&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.topicName, topicName) || other.topicName == topicName)&&(identical(other.status, status) || other.status == status)&&(identical(other.queueAhead, queueAhead) || other.queueAhead == queueAhead)&&const DeepCollectionEquality().equals(other.agent, agent)&&const DeepCollectionEquality().equals(other.complaint, complaint)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.reopenUntil, reopenUntil) || other.reopenUntil == reopenUntil)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.canRate, canRate) || other.canRate == canRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketNumber,roomId,topic,topicName,status,queueAhead,const DeepCollectionEquality().hash(agent),const DeepCollectionEquality().hash(complaint),createdAt,resolvedAt,closedAt,reopenUntil,rating,canRate);

@override
String toString() {
  return 'SupportTicketModel(id: $id, ticketNumber: $ticketNumber, roomId: $roomId, topic: $topic, topicName: $topicName, status: $status, queueAhead: $queueAhead, agent: $agent, complaint: $complaint, createdAt: $createdAt, resolvedAt: $resolvedAt, closedAt: $closedAt, reopenUntil: $reopenUntil, rating: $rating, canRate: $canRate)';
}


}

/// @nodoc
abstract mixin class $SupportTicketModelCopyWith<$Res>  {
  factory $SupportTicketModelCopyWith(SupportTicketModel value, $Res Function(SupportTicketModel) _then) = _$SupportTicketModelCopyWithImpl;
@useResult
$Res call({
 String id, String ticketNumber, String roomId, String topic, String? topicName, String status, int? queueAhead, Map<String, dynamic>? agent, Map<String, dynamic>? complaint, DateTime createdAt, DateTime? resolvedAt, DateTime? closedAt, DateTime? reopenUntil, int? rating, bool canRate
});




}
/// @nodoc
class _$SupportTicketModelCopyWithImpl<$Res>
    implements $SupportTicketModelCopyWith<$Res> {
  _$SupportTicketModelCopyWithImpl(this._self, this._then);

  final SupportTicketModel _self;
  final $Res Function(SupportTicketModel) _then;

/// Create a copy of SupportTicketModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketNumber = null,Object? roomId = null,Object? topic = null,Object? topicName = freezed,Object? status = null,Object? queueAhead = freezed,Object? agent = freezed,Object? complaint = freezed,Object? createdAt = null,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? reopenUntil = freezed,Object? rating = freezed,Object? canRate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: null == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,topicName: freezed == topicName ? _self.topicName : topicName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,queueAhead: freezed == queueAhead ? _self.queueAhead : queueAhead // ignore: cast_nullable_to_non_nullable
as int?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,complaint: freezed == complaint ? _self.complaint : complaint // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reopenUntil: freezed == reopenUntil ? _self.reopenUntil : reopenUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,canRate: null == canRate ? _self.canRate : canRate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportTicketModel].
extension SupportTicketModelPatterns on SupportTicketModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportTicketModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportTicketModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportTicketModel value)  $default,){
final _that = this;
switch (_that) {
case _SupportTicketModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportTicketModel value)?  $default,){
final _that = this;
switch (_that) {
case _SupportTicketModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticketNumber,  String roomId,  String topic,  String? topicName,  String status,  int? queueAhead,  Map<String, dynamic>? agent,  Map<String, dynamic>? complaint,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  DateTime? reopenUntil,  int? rating,  bool canRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportTicketModel() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.topic,_that.topicName,_that.status,_that.queueAhead,_that.agent,_that.complaint,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.reopenUntil,_that.rating,_that.canRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticketNumber,  String roomId,  String topic,  String? topicName,  String status,  int? queueAhead,  Map<String, dynamic>? agent,  Map<String, dynamic>? complaint,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  DateTime? reopenUntil,  int? rating,  bool canRate)  $default,) {final _that = this;
switch (_that) {
case _SupportTicketModel():
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.topic,_that.topicName,_that.status,_that.queueAhead,_that.agent,_that.complaint,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.reopenUntil,_that.rating,_that.canRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticketNumber,  String roomId,  String topic,  String? topicName,  String status,  int? queueAhead,  Map<String, dynamic>? agent,  Map<String, dynamic>? complaint,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  DateTime? reopenUntil,  int? rating,  bool canRate)?  $default,) {final _that = this;
switch (_that) {
case _SupportTicketModel() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.topic,_that.topicName,_that.status,_that.queueAhead,_that.agent,_that.complaint,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.reopenUntil,_that.rating,_that.canRate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupportTicketModel extends SupportTicketModel {
  const _SupportTicketModel({required this.id, required this.ticketNumber, required this.roomId, required this.topic, this.topicName, required this.status, this.queueAhead, final  Map<String, dynamic>? agent, final  Map<String, dynamic>? complaint, required this.createdAt, this.resolvedAt, this.closedAt, this.reopenUntil, this.rating, this.canRate = false}): _agent = agent,_complaint = complaint,super._();
  factory _SupportTicketModel.fromJson(Map<String, dynamic> json) => _$SupportTicketModelFromJson(json);

@override final  String id;
@override final  String ticketNumber;
@override final  String roomId;
@override final  String topic;
@override final  String? topicName;
@override final  String status;
@override final  int? queueAhead;
 final  Map<String, dynamic>? _agent;
@override Map<String, dynamic>? get agent {
  final value = _agent;
  if (value == null) return null;
  if (_agent is EqualUnmodifiableMapView) return _agent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _complaint;
@override Map<String, dynamic>? get complaint {
  final value = _complaint;
  if (value == null) return null;
  if (_complaint is EqualUnmodifiableMapView) return _complaint;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  DateTime createdAt;
@override final  DateTime? resolvedAt;
@override final  DateTime? closedAt;
@override final  DateTime? reopenUntil;
@override final  int? rating;
@override@JsonKey() final  bool canRate;

/// Create a copy of SupportTicketModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportTicketModelCopyWith<_SupportTicketModel> get copyWith => __$SupportTicketModelCopyWithImpl<_SupportTicketModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportTicketModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTicketModel&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.topicName, topicName) || other.topicName == topicName)&&(identical(other.status, status) || other.status == status)&&(identical(other.queueAhead, queueAhead) || other.queueAhead == queueAhead)&&const DeepCollectionEquality().equals(other._agent, _agent)&&const DeepCollectionEquality().equals(other._complaint, _complaint)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.reopenUntil, reopenUntil) || other.reopenUntil == reopenUntil)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.canRate, canRate) || other.canRate == canRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketNumber,roomId,topic,topicName,status,queueAhead,const DeepCollectionEquality().hash(_agent),const DeepCollectionEquality().hash(_complaint),createdAt,resolvedAt,closedAt,reopenUntil,rating,canRate);

@override
String toString() {
  return 'SupportTicketModel(id: $id, ticketNumber: $ticketNumber, roomId: $roomId, topic: $topic, topicName: $topicName, status: $status, queueAhead: $queueAhead, agent: $agent, complaint: $complaint, createdAt: $createdAt, resolvedAt: $resolvedAt, closedAt: $closedAt, reopenUntil: $reopenUntil, rating: $rating, canRate: $canRate)';
}


}

/// @nodoc
abstract mixin class _$SupportTicketModelCopyWith<$Res> implements $SupportTicketModelCopyWith<$Res> {
  factory _$SupportTicketModelCopyWith(_SupportTicketModel value, $Res Function(_SupportTicketModel) _then) = __$SupportTicketModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticketNumber, String roomId, String topic, String? topicName, String status, int? queueAhead, Map<String, dynamic>? agent, Map<String, dynamic>? complaint, DateTime createdAt, DateTime? resolvedAt, DateTime? closedAt, DateTime? reopenUntil, int? rating, bool canRate
});




}
/// @nodoc
class __$SupportTicketModelCopyWithImpl<$Res>
    implements _$SupportTicketModelCopyWith<$Res> {
  __$SupportTicketModelCopyWithImpl(this._self, this._then);

  final _SupportTicketModel _self;
  final $Res Function(_SupportTicketModel) _then;

/// Create a copy of SupportTicketModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketNumber = null,Object? roomId = null,Object? topic = null,Object? topicName = freezed,Object? status = null,Object? queueAhead = freezed,Object? agent = freezed,Object? complaint = freezed,Object? createdAt = null,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? reopenUntil = freezed,Object? rating = freezed,Object? canRate = null,}) {
  return _then(_SupportTicketModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: null == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,topicName: freezed == topicName ? _self.topicName : topicName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,queueAhead: freezed == queueAhead ? _self.queueAhead : queueAhead // ignore: cast_nullable_to_non_nullable
as int?,agent: freezed == agent ? _self._agent : agent // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,complaint: freezed == complaint ? _self._complaint : complaint // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reopenUntil: freezed == reopenUntil ? _self.reopenUntil : reopenUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,canRate: null == canRate ? _self.canRate : canRate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SupportHomeModel {

 String? get roomId; String get supportName; SupportTicketModel? get ticket; bool get active; int get unreadCount; bool get serviceOpen; DateTime? get nextOpenAt;
/// Create a copy of SupportHomeModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportHomeModelCopyWith<SupportHomeModel> get copyWith => _$SupportHomeModelCopyWithImpl<SupportHomeModel>(this as SupportHomeModel, _$identity);

  /// Serializes this SupportHomeModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportHomeModel&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.supportName, supportName) || other.supportName == supportName)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.active, active) || other.active == active)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.serviceOpen, serviceOpen) || other.serviceOpen == serviceOpen)&&(identical(other.nextOpenAt, nextOpenAt) || other.nextOpenAt == nextOpenAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,roomId,supportName,ticket,active,unreadCount,serviceOpen,nextOpenAt);

@override
String toString() {
  return 'SupportHomeModel(roomId: $roomId, supportName: $supportName, ticket: $ticket, active: $active, unreadCount: $unreadCount, serviceOpen: $serviceOpen, nextOpenAt: $nextOpenAt)';
}


}

/// @nodoc
abstract mixin class $SupportHomeModelCopyWith<$Res>  {
  factory $SupportHomeModelCopyWith(SupportHomeModel value, $Res Function(SupportHomeModel) _then) = _$SupportHomeModelCopyWithImpl;
@useResult
$Res call({
 String? roomId, String supportName, SupportTicketModel? ticket, bool active, int unreadCount, bool serviceOpen, DateTime? nextOpenAt
});


$SupportTicketModelCopyWith<$Res>? get ticket;

}
/// @nodoc
class _$SupportHomeModelCopyWithImpl<$Res>
    implements $SupportHomeModelCopyWith<$Res> {
  _$SupportHomeModelCopyWithImpl(this._self, this._then);

  final SupportHomeModel _self;
  final $Res Function(SupportHomeModel) _then;

/// Create a copy of SupportHomeModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = freezed,Object? supportName = null,Object? ticket = freezed,Object? active = null,Object? unreadCount = null,Object? serviceOpen = null,Object? nextOpenAt = freezed,}) {
  return _then(_self.copyWith(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,supportName: null == supportName ? _self.supportName : supportName // ignore: cast_nullable_to_non_nullable
as String,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicketModel?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,serviceOpen: null == serviceOpen ? _self.serviceOpen : serviceOpen // ignore: cast_nullable_to_non_nullable
as bool,nextOpenAt: freezed == nextOpenAt ? _self.nextOpenAt : nextOpenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of SupportHomeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketModelCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $SupportTicketModelCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupportHomeModel].
extension SupportHomeModelPatterns on SupportHomeModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportHomeModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportHomeModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportHomeModel value)  $default,){
final _that = this;
switch (_that) {
case _SupportHomeModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportHomeModel value)?  $default,){
final _that = this;
switch (_that) {
case _SupportHomeModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? roomId,  String supportName,  SupportTicketModel? ticket,  bool active,  int unreadCount,  bool serviceOpen,  DateTime? nextOpenAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportHomeModel() when $default != null:
return $default(_that.roomId,_that.supportName,_that.ticket,_that.active,_that.unreadCount,_that.serviceOpen,_that.nextOpenAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? roomId,  String supportName,  SupportTicketModel? ticket,  bool active,  int unreadCount,  bool serviceOpen,  DateTime? nextOpenAt)  $default,) {final _that = this;
switch (_that) {
case _SupportHomeModel():
return $default(_that.roomId,_that.supportName,_that.ticket,_that.active,_that.unreadCount,_that.serviceOpen,_that.nextOpenAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? roomId,  String supportName,  SupportTicketModel? ticket,  bool active,  int unreadCount,  bool serviceOpen,  DateTime? nextOpenAt)?  $default,) {final _that = this;
switch (_that) {
case _SupportHomeModel() when $default != null:
return $default(_that.roomId,_that.supportName,_that.ticket,_that.active,_that.unreadCount,_that.serviceOpen,_that.nextOpenAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupportHomeModel extends SupportHomeModel {
  const _SupportHomeModel({this.roomId, this.supportName = '', this.ticket, this.active = false, this.unreadCount = 0, this.serviceOpen = true, this.nextOpenAt}): super._();
  factory _SupportHomeModel.fromJson(Map<String, dynamic> json) => _$SupportHomeModelFromJson(json);

@override final  String? roomId;
@override@JsonKey() final  String supportName;
@override final  SupportTicketModel? ticket;
@override@JsonKey() final  bool active;
@override@JsonKey() final  int unreadCount;
@override@JsonKey() final  bool serviceOpen;
@override final  DateTime? nextOpenAt;

/// Create a copy of SupportHomeModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportHomeModelCopyWith<_SupportHomeModel> get copyWith => __$SupportHomeModelCopyWithImpl<_SupportHomeModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportHomeModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportHomeModel&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.supportName, supportName) || other.supportName == supportName)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.active, active) || other.active == active)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.serviceOpen, serviceOpen) || other.serviceOpen == serviceOpen)&&(identical(other.nextOpenAt, nextOpenAt) || other.nextOpenAt == nextOpenAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,roomId,supportName,ticket,active,unreadCount,serviceOpen,nextOpenAt);

@override
String toString() {
  return 'SupportHomeModel(roomId: $roomId, supportName: $supportName, ticket: $ticket, active: $active, unreadCount: $unreadCount, serviceOpen: $serviceOpen, nextOpenAt: $nextOpenAt)';
}


}

/// @nodoc
abstract mixin class _$SupportHomeModelCopyWith<$Res> implements $SupportHomeModelCopyWith<$Res> {
  factory _$SupportHomeModelCopyWith(_SupportHomeModel value, $Res Function(_SupportHomeModel) _then) = __$SupportHomeModelCopyWithImpl;
@override @useResult
$Res call({
 String? roomId, String supportName, SupportTicketModel? ticket, bool active, int unreadCount, bool serviceOpen, DateTime? nextOpenAt
});


@override $SupportTicketModelCopyWith<$Res>? get ticket;

}
/// @nodoc
class __$SupportHomeModelCopyWithImpl<$Res>
    implements _$SupportHomeModelCopyWith<$Res> {
  __$SupportHomeModelCopyWithImpl(this._self, this._then);

  final _SupportHomeModel _self;
  final $Res Function(_SupportHomeModel) _then;

/// Create a copy of SupportHomeModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = freezed,Object? supportName = null,Object? ticket = freezed,Object? active = null,Object? unreadCount = null,Object? serviceOpen = null,Object? nextOpenAt = freezed,}) {
  return _then(_SupportHomeModel(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,supportName: null == supportName ? _self.supportName : supportName // ignore: cast_nullable_to_non_nullable
as String,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicketModel?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,serviceOpen: null == serviceOpen ? _self.serviceOpen : serviceOpen // ignore: cast_nullable_to_non_nullable
as bool,nextOpenAt: freezed == nextOpenAt ? _self.nextOpenAt : nextOpenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of SupportHomeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketModelCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $SupportTicketModelCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}

// dart format on
