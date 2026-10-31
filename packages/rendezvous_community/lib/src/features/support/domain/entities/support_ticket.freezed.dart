// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_ticket.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SupportAgent {

 String get displayName; String? get agentCode;
/// Create a copy of SupportAgent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportAgentCopyWith<SupportAgent> get copyWith => _$SupportAgentCopyWithImpl<SupportAgent>(this as SupportAgent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportAgent&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode));
}


@override
int get hashCode => Object.hash(runtimeType,displayName,agentCode);

@override
String toString() {
  return 'SupportAgent(displayName: $displayName, agentCode: $agentCode)';
}


}

/// @nodoc
abstract mixin class $SupportAgentCopyWith<$Res>  {
  factory $SupportAgentCopyWith(SupportAgent value, $Res Function(SupportAgent) _then) = _$SupportAgentCopyWithImpl;
@useResult
$Res call({
 String displayName, String? agentCode
});




}
/// @nodoc
class _$SupportAgentCopyWithImpl<$Res>
    implements $SupportAgentCopyWith<$Res> {
  _$SupportAgentCopyWithImpl(this._self, this._then);

  final SupportAgent _self;
  final $Res Function(SupportAgent) _then;

/// Create a copy of SupportAgent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayName = null,Object? agentCode = freezed,}) {
  return _then(_self.copyWith(
displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportAgent].
extension SupportAgentPatterns on SupportAgent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportAgent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportAgent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportAgent value)  $default,){
final _that = this;
switch (_that) {
case _SupportAgent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportAgent value)?  $default,){
final _that = this;
switch (_that) {
case _SupportAgent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String displayName,  String? agentCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportAgent() when $default != null:
return $default(_that.displayName,_that.agentCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String displayName,  String? agentCode)  $default,) {final _that = this;
switch (_that) {
case _SupportAgent():
return $default(_that.displayName,_that.agentCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String displayName,  String? agentCode)?  $default,) {final _that = this;
switch (_that) {
case _SupportAgent() when $default != null:
return $default(_that.displayName,_that.agentCode);case _:
  return null;

}
}

}

/// @nodoc


class _SupportAgent implements SupportAgent {
  const _SupportAgent({required this.displayName, this.agentCode});
  

@override final  String displayName;
@override final  String? agentCode;

/// Create a copy of SupportAgent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportAgentCopyWith<_SupportAgent> get copyWith => __$SupportAgentCopyWithImpl<_SupportAgent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportAgent&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode));
}


@override
int get hashCode => Object.hash(runtimeType,displayName,agentCode);

@override
String toString() {
  return 'SupportAgent(displayName: $displayName, agentCode: $agentCode)';
}


}

/// @nodoc
abstract mixin class _$SupportAgentCopyWith<$Res> implements $SupportAgentCopyWith<$Res> {
  factory _$SupportAgentCopyWith(_SupportAgent value, $Res Function(_SupportAgent) _then) = __$SupportAgentCopyWithImpl;
@override @useResult
$Res call({
 String displayName, String? agentCode
});




}
/// @nodoc
class __$SupportAgentCopyWithImpl<$Res>
    implements _$SupportAgentCopyWith<$Res> {
  __$SupportAgentCopyWithImpl(this._self, this._then);

  final _SupportAgent _self;
  final $Res Function(_SupportAgent) _then;

/// Create a copy of SupportAgent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayName = null,Object? agentCode = freezed,}) {
  return _then(_SupportAgent(
displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$SupportTicket {

 String get id; String get ticketNumber; String get roomId; String get topic; String? get topicName; SupportStatus get status; int? get queueAhead; SupportAgent? get agent; DateTime? get complaintReceivedAt; DateTime? get complaintDueAt; DateTime get createdAt; DateTime? get resolvedAt; DateTime? get closedAt; DateTime? get reopenUntil; int? get rating; bool get canRate;
/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<SupportTicket> get copyWith => _$SupportTicketCopyWithImpl<SupportTicket>(this as SupportTicket, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.topicName, topicName) || other.topicName == topicName)&&(identical(other.status, status) || other.status == status)&&(identical(other.queueAhead, queueAhead) || other.queueAhead == queueAhead)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.complaintReceivedAt, complaintReceivedAt) || other.complaintReceivedAt == complaintReceivedAt)&&(identical(other.complaintDueAt, complaintDueAt) || other.complaintDueAt == complaintDueAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.reopenUntil, reopenUntil) || other.reopenUntil == reopenUntil)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.canRate, canRate) || other.canRate == canRate));
}


@override
int get hashCode => Object.hash(runtimeType,id,ticketNumber,roomId,topic,topicName,status,queueAhead,agent,complaintReceivedAt,complaintDueAt,createdAt,resolvedAt,closedAt,reopenUntil,rating,canRate);

@override
String toString() {
  return 'SupportTicket(id: $id, ticketNumber: $ticketNumber, roomId: $roomId, topic: $topic, topicName: $topicName, status: $status, queueAhead: $queueAhead, agent: $agent, complaintReceivedAt: $complaintReceivedAt, complaintDueAt: $complaintDueAt, createdAt: $createdAt, resolvedAt: $resolvedAt, closedAt: $closedAt, reopenUntil: $reopenUntil, rating: $rating, canRate: $canRate)';
}


}

/// @nodoc
abstract mixin class $SupportTicketCopyWith<$Res>  {
  factory $SupportTicketCopyWith(SupportTicket value, $Res Function(SupportTicket) _then) = _$SupportTicketCopyWithImpl;
@useResult
$Res call({
 String id, String ticketNumber, String roomId, String topic, String? topicName, SupportStatus status, int? queueAhead, SupportAgent? agent, DateTime? complaintReceivedAt, DateTime? complaintDueAt, DateTime createdAt, DateTime? resolvedAt, DateTime? closedAt, DateTime? reopenUntil, int? rating, bool canRate
});


$SupportAgentCopyWith<$Res>? get agent;

}
/// @nodoc
class _$SupportTicketCopyWithImpl<$Res>
    implements $SupportTicketCopyWith<$Res> {
  _$SupportTicketCopyWithImpl(this._self, this._then);

  final SupportTicket _self;
  final $Res Function(SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketNumber = null,Object? roomId = null,Object? topic = null,Object? topicName = freezed,Object? status = null,Object? queueAhead = freezed,Object? agent = freezed,Object? complaintReceivedAt = freezed,Object? complaintDueAt = freezed,Object? createdAt = null,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? reopenUntil = freezed,Object? rating = freezed,Object? canRate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: null == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,topicName: freezed == topicName ? _self.topicName : topicName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SupportStatus,queueAhead: freezed == queueAhead ? _self.queueAhead : queueAhead // ignore: cast_nullable_to_non_nullable
as int?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as SupportAgent?,complaintReceivedAt: freezed == complaintReceivedAt ? _self.complaintReceivedAt : complaintReceivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,complaintDueAt: freezed == complaintDueAt ? _self.complaintDueAt : complaintDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reopenUntil: freezed == reopenUntil ? _self.reopenUntil : reopenUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,canRate: null == canRate ? _self.canRate : canRate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportAgentCopyWith<$Res>? get agent {
    if (_self.agent == null) {
    return null;
  }

  return $SupportAgentCopyWith<$Res>(_self.agent!, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupportTicket].
extension SupportTicketPatterns on SupportTicket {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportTicket value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportTicket value)  $default,){
final _that = this;
switch (_that) {
case _SupportTicket():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportTicket value)?  $default,){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticketNumber,  String roomId,  String topic,  String? topicName,  SupportStatus status,  int? queueAhead,  SupportAgent? agent,  DateTime? complaintReceivedAt,  DateTime? complaintDueAt,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  DateTime? reopenUntil,  int? rating,  bool canRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.topic,_that.topicName,_that.status,_that.queueAhead,_that.agent,_that.complaintReceivedAt,_that.complaintDueAt,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.reopenUntil,_that.rating,_that.canRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticketNumber,  String roomId,  String topic,  String? topicName,  SupportStatus status,  int? queueAhead,  SupportAgent? agent,  DateTime? complaintReceivedAt,  DateTime? complaintDueAt,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  DateTime? reopenUntil,  int? rating,  bool canRate)  $default,) {final _that = this;
switch (_that) {
case _SupportTicket():
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.topic,_that.topicName,_that.status,_that.queueAhead,_that.agent,_that.complaintReceivedAt,_that.complaintDueAt,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.reopenUntil,_that.rating,_that.canRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticketNumber,  String roomId,  String topic,  String? topicName,  SupportStatus status,  int? queueAhead,  SupportAgent? agent,  DateTime? complaintReceivedAt,  DateTime? complaintDueAt,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  DateTime? reopenUntil,  int? rating,  bool canRate)?  $default,) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.topic,_that.topicName,_that.status,_that.queueAhead,_that.agent,_that.complaintReceivedAt,_that.complaintDueAt,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.reopenUntil,_that.rating,_that.canRate);case _:
  return null;

}
}

}

/// @nodoc


class _SupportTicket extends SupportTicket {
  const _SupportTicket({required this.id, required this.ticketNumber, required this.roomId, required this.topic, this.topicName, required this.status, this.queueAhead, this.agent, this.complaintReceivedAt, this.complaintDueAt, required this.createdAt, this.resolvedAt, this.closedAt, this.reopenUntil, this.rating, this.canRate = false}): super._();
  

@override final  String id;
@override final  String ticketNumber;
@override final  String roomId;
@override final  String topic;
@override final  String? topicName;
@override final  SupportStatus status;
@override final  int? queueAhead;
@override final  SupportAgent? agent;
@override final  DateTime? complaintReceivedAt;
@override final  DateTime? complaintDueAt;
@override final  DateTime createdAt;
@override final  DateTime? resolvedAt;
@override final  DateTime? closedAt;
@override final  DateTime? reopenUntil;
@override final  int? rating;
@override@JsonKey() final  bool canRate;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportTicketCopyWith<_SupportTicket> get copyWith => __$SupportTicketCopyWithImpl<_SupportTicket>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.topicName, topicName) || other.topicName == topicName)&&(identical(other.status, status) || other.status == status)&&(identical(other.queueAhead, queueAhead) || other.queueAhead == queueAhead)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.complaintReceivedAt, complaintReceivedAt) || other.complaintReceivedAt == complaintReceivedAt)&&(identical(other.complaintDueAt, complaintDueAt) || other.complaintDueAt == complaintDueAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.reopenUntil, reopenUntil) || other.reopenUntil == reopenUntil)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.canRate, canRate) || other.canRate == canRate));
}


@override
int get hashCode => Object.hash(runtimeType,id,ticketNumber,roomId,topic,topicName,status,queueAhead,agent,complaintReceivedAt,complaintDueAt,createdAt,resolvedAt,closedAt,reopenUntil,rating,canRate);

@override
String toString() {
  return 'SupportTicket(id: $id, ticketNumber: $ticketNumber, roomId: $roomId, topic: $topic, topicName: $topicName, status: $status, queueAhead: $queueAhead, agent: $agent, complaintReceivedAt: $complaintReceivedAt, complaintDueAt: $complaintDueAt, createdAt: $createdAt, resolvedAt: $resolvedAt, closedAt: $closedAt, reopenUntil: $reopenUntil, rating: $rating, canRate: $canRate)';
}


}

/// @nodoc
abstract mixin class _$SupportTicketCopyWith<$Res> implements $SupportTicketCopyWith<$Res> {
  factory _$SupportTicketCopyWith(_SupportTicket value, $Res Function(_SupportTicket) _then) = __$SupportTicketCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticketNumber, String roomId, String topic, String? topicName, SupportStatus status, int? queueAhead, SupportAgent? agent, DateTime? complaintReceivedAt, DateTime? complaintDueAt, DateTime createdAt, DateTime? resolvedAt, DateTime? closedAt, DateTime? reopenUntil, int? rating, bool canRate
});


@override $SupportAgentCopyWith<$Res>? get agent;

}
/// @nodoc
class __$SupportTicketCopyWithImpl<$Res>
    implements _$SupportTicketCopyWith<$Res> {
  __$SupportTicketCopyWithImpl(this._self, this._then);

  final _SupportTicket _self;
  final $Res Function(_SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketNumber = null,Object? roomId = null,Object? topic = null,Object? topicName = freezed,Object? status = null,Object? queueAhead = freezed,Object? agent = freezed,Object? complaintReceivedAt = freezed,Object? complaintDueAt = freezed,Object? createdAt = null,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? reopenUntil = freezed,Object? rating = freezed,Object? canRate = null,}) {
  return _then(_SupportTicket(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: null == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,topicName: freezed == topicName ? _self.topicName : topicName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SupportStatus,queueAhead: freezed == queueAhead ? _self.queueAhead : queueAhead // ignore: cast_nullable_to_non_nullable
as int?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as SupportAgent?,complaintReceivedAt: freezed == complaintReceivedAt ? _self.complaintReceivedAt : complaintReceivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,complaintDueAt: freezed == complaintDueAt ? _self.complaintDueAt : complaintDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reopenUntil: freezed == reopenUntil ? _self.reopenUntil : reopenUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,canRate: null == canRate ? _self.canRate : canRate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportAgentCopyWith<$Res>? get agent {
    if (_self.agent == null) {
    return null;
  }

  return $SupportAgentCopyWith<$Res>(_self.agent!, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}

/// @nodoc
mixin _$SupportHome {

 String? get roomId; String get supportName; SupportTicket? get ticket; bool get active; int get unreadCount; bool get serviceOpen; DateTime? get nextOpenAt;
/// Create a copy of SupportHome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportHomeCopyWith<SupportHome> get copyWith => _$SupportHomeCopyWithImpl<SupportHome>(this as SupportHome, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportHome&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.supportName, supportName) || other.supportName == supportName)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.active, active) || other.active == active)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.serviceOpen, serviceOpen) || other.serviceOpen == serviceOpen)&&(identical(other.nextOpenAt, nextOpenAt) || other.nextOpenAt == nextOpenAt));
}


@override
int get hashCode => Object.hash(runtimeType,roomId,supportName,ticket,active,unreadCount,serviceOpen,nextOpenAt);

@override
String toString() {
  return 'SupportHome(roomId: $roomId, supportName: $supportName, ticket: $ticket, active: $active, unreadCount: $unreadCount, serviceOpen: $serviceOpen, nextOpenAt: $nextOpenAt)';
}


}

/// @nodoc
abstract mixin class $SupportHomeCopyWith<$Res>  {
  factory $SupportHomeCopyWith(SupportHome value, $Res Function(SupportHome) _then) = _$SupportHomeCopyWithImpl;
@useResult
$Res call({
 String? roomId, String supportName, SupportTicket? ticket, bool active, int unreadCount, bool serviceOpen, DateTime? nextOpenAt
});


$SupportTicketCopyWith<$Res>? get ticket;

}
/// @nodoc
class _$SupportHomeCopyWithImpl<$Res>
    implements $SupportHomeCopyWith<$Res> {
  _$SupportHomeCopyWithImpl(this._self, this._then);

  final SupportHome _self;
  final $Res Function(SupportHome) _then;

/// Create a copy of SupportHome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = freezed,Object? supportName = null,Object? ticket = freezed,Object? active = null,Object? unreadCount = null,Object? serviceOpen = null,Object? nextOpenAt = freezed,}) {
  return _then(_self.copyWith(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,supportName: null == supportName ? _self.supportName : supportName // ignore: cast_nullable_to_non_nullable
as String,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicket?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,serviceOpen: null == serviceOpen ? _self.serviceOpen : serviceOpen // ignore: cast_nullable_to_non_nullable
as bool,nextOpenAt: freezed == nextOpenAt ? _self.nextOpenAt : nextOpenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of SupportHome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $SupportTicketCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupportHome].
extension SupportHomePatterns on SupportHome {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportHome value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportHome() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportHome value)  $default,){
final _that = this;
switch (_that) {
case _SupportHome():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportHome value)?  $default,){
final _that = this;
switch (_that) {
case _SupportHome() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? roomId,  String supportName,  SupportTicket? ticket,  bool active,  int unreadCount,  bool serviceOpen,  DateTime? nextOpenAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportHome() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? roomId,  String supportName,  SupportTicket? ticket,  bool active,  int unreadCount,  bool serviceOpen,  DateTime? nextOpenAt)  $default,) {final _that = this;
switch (_that) {
case _SupportHome():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? roomId,  String supportName,  SupportTicket? ticket,  bool active,  int unreadCount,  bool serviceOpen,  DateTime? nextOpenAt)?  $default,) {final _that = this;
switch (_that) {
case _SupportHome() when $default != null:
return $default(_that.roomId,_that.supportName,_that.ticket,_that.active,_that.unreadCount,_that.serviceOpen,_that.nextOpenAt);case _:
  return null;

}
}

}

/// @nodoc


class _SupportHome extends SupportHome {
  const _SupportHome({this.roomId, required this.supportName, this.ticket, this.active = false, this.unreadCount = 0, this.serviceOpen = true, this.nextOpenAt}): super._();
  

@override final  String? roomId;
@override final  String supportName;
@override final  SupportTicket? ticket;
@override@JsonKey() final  bool active;
@override@JsonKey() final  int unreadCount;
@override@JsonKey() final  bool serviceOpen;
@override final  DateTime? nextOpenAt;

/// Create a copy of SupportHome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportHomeCopyWith<_SupportHome> get copyWith => __$SupportHomeCopyWithImpl<_SupportHome>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportHome&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.supportName, supportName) || other.supportName == supportName)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.active, active) || other.active == active)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.serviceOpen, serviceOpen) || other.serviceOpen == serviceOpen)&&(identical(other.nextOpenAt, nextOpenAt) || other.nextOpenAt == nextOpenAt));
}


@override
int get hashCode => Object.hash(runtimeType,roomId,supportName,ticket,active,unreadCount,serviceOpen,nextOpenAt);

@override
String toString() {
  return 'SupportHome(roomId: $roomId, supportName: $supportName, ticket: $ticket, active: $active, unreadCount: $unreadCount, serviceOpen: $serviceOpen, nextOpenAt: $nextOpenAt)';
}


}

/// @nodoc
abstract mixin class _$SupportHomeCopyWith<$Res> implements $SupportHomeCopyWith<$Res> {
  factory _$SupportHomeCopyWith(_SupportHome value, $Res Function(_SupportHome) _then) = __$SupportHomeCopyWithImpl;
@override @useResult
$Res call({
 String? roomId, String supportName, SupportTicket? ticket, bool active, int unreadCount, bool serviceOpen, DateTime? nextOpenAt
});


@override $SupportTicketCopyWith<$Res>? get ticket;

}
/// @nodoc
class __$SupportHomeCopyWithImpl<$Res>
    implements _$SupportHomeCopyWith<$Res> {
  __$SupportHomeCopyWithImpl(this._self, this._then);

  final _SupportHome _self;
  final $Res Function(_SupportHome) _then;

/// Create a copy of SupportHome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = freezed,Object? supportName = null,Object? ticket = freezed,Object? active = null,Object? unreadCount = null,Object? serviceOpen = null,Object? nextOpenAt = freezed,}) {
  return _then(_SupportHome(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,supportName: null == supportName ? _self.supportName : supportName // ignore: cast_nullable_to_non_nullable
as String,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicket?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,serviceOpen: null == serviceOpen ? _self.serviceOpen : serviceOpen // ignore: cast_nullable_to_non_nullable
as bool,nextOpenAt: freezed == nextOpenAt ? _self.nextOpenAt : nextOpenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of SupportHome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $SupportTicketCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}

/// @nodoc
mixin _$SupportTopic {

 String get code; String get name; String? get helpUrl; bool get urgent;
/// Create a copy of SupportTopic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportTopicCopyWith<SupportTopic> get copyWith => _$SupportTopicCopyWithImpl<SupportTopic>(this as SupportTopic, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTopic&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.helpUrl, helpUrl) || other.helpUrl == helpUrl)&&(identical(other.urgent, urgent) || other.urgent == urgent));
}


@override
int get hashCode => Object.hash(runtimeType,code,name,helpUrl,urgent);

@override
String toString() {
  return 'SupportTopic(code: $code, name: $name, helpUrl: $helpUrl, urgent: $urgent)';
}


}

/// @nodoc
abstract mixin class $SupportTopicCopyWith<$Res>  {
  factory $SupportTopicCopyWith(SupportTopic value, $Res Function(SupportTopic) _then) = _$SupportTopicCopyWithImpl;
@useResult
$Res call({
 String code, String name, String? helpUrl, bool urgent
});




}
/// @nodoc
class _$SupportTopicCopyWithImpl<$Res>
    implements $SupportTopicCopyWith<$Res> {
  _$SupportTopicCopyWithImpl(this._self, this._then);

  final SupportTopic _self;
  final $Res Function(SupportTopic) _then;

/// Create a copy of SupportTopic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? helpUrl = freezed,Object? urgent = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,helpUrl: freezed == helpUrl ? _self.helpUrl : helpUrl // ignore: cast_nullable_to_non_nullable
as String?,urgent: null == urgent ? _self.urgent : urgent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportTopic].
extension SupportTopicPatterns on SupportTopic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportTopic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportTopic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportTopic value)  $default,){
final _that = this;
switch (_that) {
case _SupportTopic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportTopic value)?  $default,){
final _that = this;
switch (_that) {
case _SupportTopic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String? helpUrl,  bool urgent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportTopic() when $default != null:
return $default(_that.code,_that.name,_that.helpUrl,_that.urgent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String? helpUrl,  bool urgent)  $default,) {final _that = this;
switch (_that) {
case _SupportTopic():
return $default(_that.code,_that.name,_that.helpUrl,_that.urgent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String? helpUrl,  bool urgent)?  $default,) {final _that = this;
switch (_that) {
case _SupportTopic() when $default != null:
return $default(_that.code,_that.name,_that.helpUrl,_that.urgent);case _:
  return null;

}
}

}

/// @nodoc


class _SupportTopic implements SupportTopic {
  const _SupportTopic({required this.code, required this.name, this.helpUrl, this.urgent = false});
  

@override final  String code;
@override final  String name;
@override final  String? helpUrl;
@override@JsonKey() final  bool urgent;

/// Create a copy of SupportTopic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportTopicCopyWith<_SupportTopic> get copyWith => __$SupportTopicCopyWithImpl<_SupportTopic>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTopic&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.helpUrl, helpUrl) || other.helpUrl == helpUrl)&&(identical(other.urgent, urgent) || other.urgent == urgent));
}


@override
int get hashCode => Object.hash(runtimeType,code,name,helpUrl,urgent);

@override
String toString() {
  return 'SupportTopic(code: $code, name: $name, helpUrl: $helpUrl, urgent: $urgent)';
}


}

/// @nodoc
abstract mixin class _$SupportTopicCopyWith<$Res> implements $SupportTopicCopyWith<$Res> {
  factory _$SupportTopicCopyWith(_SupportTopic value, $Res Function(_SupportTopic) _then) = __$SupportTopicCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String? helpUrl, bool urgent
});




}
/// @nodoc
class __$SupportTopicCopyWithImpl<$Res>
    implements _$SupportTopicCopyWith<$Res> {
  __$SupportTopicCopyWithImpl(this._self, this._then);

  final _SupportTopic _self;
  final $Res Function(_SupportTopic) _then;

/// Create a copy of SupportTopic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? helpUrl = freezed,Object? urgent = null,}) {
  return _then(_SupportTopic(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,helpUrl: freezed == helpUrl ? _self.helpUrl : helpUrl // ignore: cast_nullable_to_non_nullable
as String?,urgent: null == urgent ? _self.urgent : urgent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$SensitiveCheck {

 bool get masked; List<String> get kinds;
/// Create a copy of SensitiveCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SensitiveCheckCopyWith<SensitiveCheck> get copyWith => _$SensitiveCheckCopyWithImpl<SensitiveCheck>(this as SensitiveCheck, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SensitiveCheck&&(identical(other.masked, masked) || other.masked == masked)&&const DeepCollectionEquality().equals(other.kinds, kinds));
}


@override
int get hashCode => Object.hash(runtimeType,masked,const DeepCollectionEquality().hash(kinds));

@override
String toString() {
  return 'SensitiveCheck(masked: $masked, kinds: $kinds)';
}


}

/// @nodoc
abstract mixin class $SensitiveCheckCopyWith<$Res>  {
  factory $SensitiveCheckCopyWith(SensitiveCheck value, $Res Function(SensitiveCheck) _then) = _$SensitiveCheckCopyWithImpl;
@useResult
$Res call({
 bool masked, List<String> kinds
});




}
/// @nodoc
class _$SensitiveCheckCopyWithImpl<$Res>
    implements $SensitiveCheckCopyWith<$Res> {
  _$SensitiveCheckCopyWithImpl(this._self, this._then);

  final SensitiveCheck _self;
  final $Res Function(SensitiveCheck) _then;

/// Create a copy of SensitiveCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? masked = null,Object? kinds = null,}) {
  return _then(_self.copyWith(
masked: null == masked ? _self.masked : masked // ignore: cast_nullable_to_non_nullable
as bool,kinds: null == kinds ? _self.kinds : kinds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SensitiveCheck].
extension SensitiveCheckPatterns on SensitiveCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SensitiveCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SensitiveCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SensitiveCheck value)  $default,){
final _that = this;
switch (_that) {
case _SensitiveCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SensitiveCheck value)?  $default,){
final _that = this;
switch (_that) {
case _SensitiveCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool masked,  List<String> kinds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SensitiveCheck() when $default != null:
return $default(_that.masked,_that.kinds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool masked,  List<String> kinds)  $default,) {final _that = this;
switch (_that) {
case _SensitiveCheck():
return $default(_that.masked,_that.kinds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool masked,  List<String> kinds)?  $default,) {final _that = this;
switch (_that) {
case _SensitiveCheck() when $default != null:
return $default(_that.masked,_that.kinds);case _:
  return null;

}
}

}

/// @nodoc


class _SensitiveCheck implements SensitiveCheck {
  const _SensitiveCheck({this.masked = false, final  List<String> kinds = const <String>[]}): _kinds = kinds;
  

@override@JsonKey() final  bool masked;
 final  List<String> _kinds;
@override@JsonKey() List<String> get kinds {
  if (_kinds is EqualUnmodifiableListView) return _kinds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_kinds);
}


/// Create a copy of SensitiveCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SensitiveCheckCopyWith<_SensitiveCheck> get copyWith => __$SensitiveCheckCopyWithImpl<_SensitiveCheck>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SensitiveCheck&&(identical(other.masked, masked) || other.masked == masked)&&const DeepCollectionEquality().equals(other._kinds, _kinds));
}


@override
int get hashCode => Object.hash(runtimeType,masked,const DeepCollectionEquality().hash(_kinds));

@override
String toString() {
  return 'SensitiveCheck(masked: $masked, kinds: $kinds)';
}


}

/// @nodoc
abstract mixin class _$SensitiveCheckCopyWith<$Res> implements $SensitiveCheckCopyWith<$Res> {
  factory _$SensitiveCheckCopyWith(_SensitiveCheck value, $Res Function(_SensitiveCheck) _then) = __$SensitiveCheckCopyWithImpl;
@override @useResult
$Res call({
 bool masked, List<String> kinds
});




}
/// @nodoc
class __$SensitiveCheckCopyWithImpl<$Res>
    implements _$SensitiveCheckCopyWith<$Res> {
  __$SensitiveCheckCopyWithImpl(this._self, this._then);

  final _SensitiveCheck _self;
  final $Res Function(_SensitiveCheck) _then;

/// Create a copy of SensitiveCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? masked = null,Object? kinds = null,}) {
  return _then(_SensitiveCheck(
masked: null == masked ? _self.masked : masked // ignore: cast_nullable_to_non_nullable
as bool,kinds: null == kinds ? _self._kinds : kinds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$SupportNotice {

 String get id; String get title; String get body; String? get ticketId; String? get roomId;
/// Create a copy of SupportNotice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportNoticeCopyWith<SupportNotice> get copyWith => _$SupportNoticeCopyWithImpl<SupportNotice>(this as SupportNotice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportNotice&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.roomId, roomId) || other.roomId == roomId));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,body,ticketId,roomId);

@override
String toString() {
  return 'SupportNotice(id: $id, title: $title, body: $body, ticketId: $ticketId, roomId: $roomId)';
}


}

/// @nodoc
abstract mixin class $SupportNoticeCopyWith<$Res>  {
  factory $SupportNoticeCopyWith(SupportNotice value, $Res Function(SupportNotice) _then) = _$SupportNoticeCopyWithImpl;
@useResult
$Res call({
 String id, String title, String body, String? ticketId, String? roomId
});




}
/// @nodoc
class _$SupportNoticeCopyWithImpl<$Res>
    implements $SupportNoticeCopyWith<$Res> {
  _$SupportNoticeCopyWithImpl(this._self, this._then);

  final SupportNotice _self;
  final $Res Function(SupportNotice) _then;

/// Create a copy of SupportNotice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? body = null,Object? ticketId = freezed,Object? roomId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportNotice].
extension SupportNoticePatterns on SupportNotice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportNotice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportNotice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportNotice value)  $default,){
final _that = this;
switch (_that) {
case _SupportNotice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportNotice value)?  $default,){
final _that = this;
switch (_that) {
case _SupportNotice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String body,  String? ticketId,  String? roomId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportNotice() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.ticketId,_that.roomId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String body,  String? ticketId,  String? roomId)  $default,) {final _that = this;
switch (_that) {
case _SupportNotice():
return $default(_that.id,_that.title,_that.body,_that.ticketId,_that.roomId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String body,  String? ticketId,  String? roomId)?  $default,) {final _that = this;
switch (_that) {
case _SupportNotice() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.ticketId,_that.roomId);case _:
  return null;

}
}

}

/// @nodoc


class _SupportNotice implements SupportNotice {
  const _SupportNotice({required this.id, required this.title, required this.body, this.ticketId, this.roomId});
  

@override final  String id;
@override final  String title;
@override final  String body;
@override final  String? ticketId;
@override final  String? roomId;

/// Create a copy of SupportNotice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportNoticeCopyWith<_SupportNotice> get copyWith => __$SupportNoticeCopyWithImpl<_SupportNotice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportNotice&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.roomId, roomId) || other.roomId == roomId));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,body,ticketId,roomId);

@override
String toString() {
  return 'SupportNotice(id: $id, title: $title, body: $body, ticketId: $ticketId, roomId: $roomId)';
}


}

/// @nodoc
abstract mixin class _$SupportNoticeCopyWith<$Res> implements $SupportNoticeCopyWith<$Res> {
  factory _$SupportNoticeCopyWith(_SupportNotice value, $Res Function(_SupportNotice) _then) = __$SupportNoticeCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String body, String? ticketId, String? roomId
});




}
/// @nodoc
class __$SupportNoticeCopyWithImpl<$Res>
    implements _$SupportNoticeCopyWith<$Res> {
  __$SupportNoticeCopyWithImpl(this._self, this._then);

  final _SupportNotice _self;
  final $Res Function(_SupportNotice) _then;

/// Create a copy of SupportNotice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? body = null,Object? ticketId = freezed,Object? roomId = freezed,}) {
  return _then(_SupportNotice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
