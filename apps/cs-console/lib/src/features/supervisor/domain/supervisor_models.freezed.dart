// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supervisor_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AlertThresholds {

 int get unclaimedMinutes; int get p1UnclaimedMinutes;
/// Create a copy of AlertThresholds
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertThresholdsCopyWith<AlertThresholds> get copyWith => _$AlertThresholdsCopyWithImpl<AlertThresholds>(this as AlertThresholds, _$identity);

  /// Serializes this AlertThresholds to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertThresholds&&(identical(other.unclaimedMinutes, unclaimedMinutes) || other.unclaimedMinutes == unclaimedMinutes)&&(identical(other.p1UnclaimedMinutes, p1UnclaimedMinutes) || other.p1UnclaimedMinutes == p1UnclaimedMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,unclaimedMinutes,p1UnclaimedMinutes);

@override
String toString() {
  return 'AlertThresholds(unclaimedMinutes: $unclaimedMinutes, p1UnclaimedMinutes: $p1UnclaimedMinutes)';
}


}

/// @nodoc
abstract mixin class $AlertThresholdsCopyWith<$Res>  {
  factory $AlertThresholdsCopyWith(AlertThresholds value, $Res Function(AlertThresholds) _then) = _$AlertThresholdsCopyWithImpl;
@useResult
$Res call({
 int unclaimedMinutes, int p1UnclaimedMinutes
});




}
/// @nodoc
class _$AlertThresholdsCopyWithImpl<$Res>
    implements $AlertThresholdsCopyWith<$Res> {
  _$AlertThresholdsCopyWithImpl(this._self, this._then);

  final AlertThresholds _self;
  final $Res Function(AlertThresholds) _then;

/// Create a copy of AlertThresholds
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? unclaimedMinutes = null,Object? p1UnclaimedMinutes = null,}) {
  return _then(_self.copyWith(
unclaimedMinutes: null == unclaimedMinutes ? _self.unclaimedMinutes : unclaimedMinutes // ignore: cast_nullable_to_non_nullable
as int,p1UnclaimedMinutes: null == p1UnclaimedMinutes ? _self.p1UnclaimedMinutes : p1UnclaimedMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AlertThresholds].
extension AlertThresholdsPatterns on AlertThresholds {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertThresholds value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertThresholds() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertThresholds value)  $default,){
final _that = this;
switch (_that) {
case _AlertThresholds():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertThresholds value)?  $default,){
final _that = this;
switch (_that) {
case _AlertThresholds() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int unclaimedMinutes,  int p1UnclaimedMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertThresholds() when $default != null:
return $default(_that.unclaimedMinutes,_that.p1UnclaimedMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int unclaimedMinutes,  int p1UnclaimedMinutes)  $default,) {final _that = this;
switch (_that) {
case _AlertThresholds():
return $default(_that.unclaimedMinutes,_that.p1UnclaimedMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int unclaimedMinutes,  int p1UnclaimedMinutes)?  $default,) {final _that = this;
switch (_that) {
case _AlertThresholds() when $default != null:
return $default(_that.unclaimedMinutes,_that.p1UnclaimedMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlertThresholds implements AlertThresholds {
  const _AlertThresholds({this.unclaimedMinutes = 10, this.p1UnclaimedMinutes = 2});
  factory _AlertThresholds.fromJson(Map<String, dynamic> json) => _$AlertThresholdsFromJson(json);

@override@JsonKey() final  int unclaimedMinutes;
@override@JsonKey() final  int p1UnclaimedMinutes;

/// Create a copy of AlertThresholds
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertThresholdsCopyWith<_AlertThresholds> get copyWith => __$AlertThresholdsCopyWithImpl<_AlertThresholds>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlertThresholdsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertThresholds&&(identical(other.unclaimedMinutes, unclaimedMinutes) || other.unclaimedMinutes == unclaimedMinutes)&&(identical(other.p1UnclaimedMinutes, p1UnclaimedMinutes) || other.p1UnclaimedMinutes == p1UnclaimedMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,unclaimedMinutes,p1UnclaimedMinutes);

@override
String toString() {
  return 'AlertThresholds(unclaimedMinutes: $unclaimedMinutes, p1UnclaimedMinutes: $p1UnclaimedMinutes)';
}


}

/// @nodoc
abstract mixin class _$AlertThresholdsCopyWith<$Res> implements $AlertThresholdsCopyWith<$Res> {
  factory _$AlertThresholdsCopyWith(_AlertThresholds value, $Res Function(_AlertThresholds) _then) = __$AlertThresholdsCopyWithImpl;
@override @useResult
$Res call({
 int unclaimedMinutes, int p1UnclaimedMinutes
});




}
/// @nodoc
class __$AlertThresholdsCopyWithImpl<$Res>
    implements _$AlertThresholdsCopyWith<$Res> {
  __$AlertThresholdsCopyWithImpl(this._self, this._then);

  final _AlertThresholds _self;
  final $Res Function(_AlertThresholds) _then;

/// Create a copy of AlertThresholds
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? unclaimedMinutes = null,Object? p1UnclaimedMinutes = null,}) {
  return _then(_AlertThresholds(
unclaimedMinutes: null == unclaimedMinutes ? _self.unclaimedMinutes : unclaimedMinutes // ignore: cast_nullable_to_non_nullable
as int,p1UnclaimedMinutes: null == p1UnclaimedMinutes ? _self.p1UnclaimedMinutes : p1UnclaimedMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AgentLoad {

 String get id; String get displayName; String? get agentCode; List<String> get roles;@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus get status; bool get connected; int get activeTickets; int get maxActiveTickets; int get resolvedToday; DateTime? get statusChangedAt;
/// Create a copy of AgentLoad
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentLoadCopyWith<AgentLoad> get copyWith => _$AgentLoadCopyWithImpl<AgentLoad>(this as AgentLoad, _$identity);

  /// Serializes this AgentLoad to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentLoad&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.status, status) || other.status == status)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.resolvedToday, resolvedToday) || other.resolvedToday == resolvedToday)&&(identical(other.statusChangedAt, statusChangedAt) || other.statusChangedAt == statusChangedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,const DeepCollectionEquality().hash(roles),status,connected,activeTickets,maxActiveTickets,resolvedToday,statusChangedAt);

@override
String toString() {
  return 'AgentLoad(id: $id, displayName: $displayName, agentCode: $agentCode, roles: $roles, status: $status, connected: $connected, activeTickets: $activeTickets, maxActiveTickets: $maxActiveTickets, resolvedToday: $resolvedToday, statusChangedAt: $statusChangedAt)';
}


}

/// @nodoc
abstract mixin class $AgentLoadCopyWith<$Res>  {
  factory $AgentLoadCopyWith(AgentLoad value, $Res Function(AgentLoad) _then) = _$AgentLoadCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String? agentCode, List<String> roles,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, bool connected, int activeTickets, int maxActiveTickets, int resolvedToday, DateTime? statusChangedAt
});




}
/// @nodoc
class _$AgentLoadCopyWithImpl<$Res>
    implements $AgentLoadCopyWith<$Res> {
  _$AgentLoadCopyWithImpl(this._self, this._then);

  final AgentLoad _self;
  final $Res Function(AgentLoad) _then;

/// Create a copy of AgentLoad
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? roles = null,Object? status = null,Object? connected = null,Object? activeTickets = null,Object? maxActiveTickets = null,Object? resolvedToday = null,Object? statusChangedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,resolvedToday: null == resolvedToday ? _self.resolvedToday : resolvedToday // ignore: cast_nullable_to_non_nullable
as int,statusChangedAt: freezed == statusChangedAt ? _self.statusChangedAt : statusChangedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentLoad].
extension AgentLoadPatterns on AgentLoad {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentLoad value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentLoad() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentLoad value)  $default,){
final _that = this;
switch (_that) {
case _AgentLoad():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentLoad value)?  $default,){
final _that = this;
switch (_that) {
case _AgentLoad() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode,  List<String> roles, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  bool connected,  int activeTickets,  int maxActiveTickets,  int resolvedToday,  DateTime? statusChangedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentLoad() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.roles,_that.status,_that.connected,_that.activeTickets,_that.maxActiveTickets,_that.resolvedToday,_that.statusChangedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode,  List<String> roles, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  bool connected,  int activeTickets,  int maxActiveTickets,  int resolvedToday,  DateTime? statusChangedAt)  $default,) {final _that = this;
switch (_that) {
case _AgentLoad():
return $default(_that.id,_that.displayName,_that.agentCode,_that.roles,_that.status,_that.connected,_that.activeTickets,_that.maxActiveTickets,_that.resolvedToday,_that.statusChangedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String? agentCode,  List<String> roles, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  bool connected,  int activeTickets,  int maxActiveTickets,  int resolvedToday,  DateTime? statusChangedAt)?  $default,) {final _that = this;
switch (_that) {
case _AgentLoad() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.roles,_that.status,_that.connected,_that.activeTickets,_that.maxActiveTickets,_that.resolvedToday,_that.statusChangedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentLoad implements AgentLoad {
  const _AgentLoad({required this.id, required this.displayName, this.agentCode, final  List<String> roles = const <String>[], @JsonKey(unknownEnumValue: AgentStatus.offline) this.status = AgentStatus.offline, this.connected = false, this.activeTickets = 0, this.maxActiveTickets = 5, this.resolvedToday = 0, this.statusChangedAt}): _roles = roles;
  factory _AgentLoad.fromJson(Map<String, dynamic> json) => _$AgentLoadFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  String? agentCode;
 final  List<String> _roles;
@override@JsonKey() List<String> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override@JsonKey(unknownEnumValue: AgentStatus.offline) final  AgentStatus status;
@override@JsonKey() final  bool connected;
@override@JsonKey() final  int activeTickets;
@override@JsonKey() final  int maxActiveTickets;
@override@JsonKey() final  int resolvedToday;
@override final  DateTime? statusChangedAt;

/// Create a copy of AgentLoad
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentLoadCopyWith<_AgentLoad> get copyWith => __$AgentLoadCopyWithImpl<_AgentLoad>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentLoadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentLoad&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.status, status) || other.status == status)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.resolvedToday, resolvedToday) || other.resolvedToday == resolvedToday)&&(identical(other.statusChangedAt, statusChangedAt) || other.statusChangedAt == statusChangedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,const DeepCollectionEquality().hash(_roles),status,connected,activeTickets,maxActiveTickets,resolvedToday,statusChangedAt);

@override
String toString() {
  return 'AgentLoad(id: $id, displayName: $displayName, agentCode: $agentCode, roles: $roles, status: $status, connected: $connected, activeTickets: $activeTickets, maxActiveTickets: $maxActiveTickets, resolvedToday: $resolvedToday, statusChangedAt: $statusChangedAt)';
}


}

/// @nodoc
abstract mixin class _$AgentLoadCopyWith<$Res> implements $AgentLoadCopyWith<$Res> {
  factory _$AgentLoadCopyWith(_AgentLoad value, $Res Function(_AgentLoad) _then) = __$AgentLoadCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String? agentCode, List<String> roles,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, bool connected, int activeTickets, int maxActiveTickets, int resolvedToday, DateTime? statusChangedAt
});




}
/// @nodoc
class __$AgentLoadCopyWithImpl<$Res>
    implements _$AgentLoadCopyWith<$Res> {
  __$AgentLoadCopyWithImpl(this._self, this._then);

  final _AgentLoad _self;
  final $Res Function(_AgentLoad) _then;

/// Create a copy of AgentLoad
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? roles = null,Object? status = null,Object? connected = null,Object? activeTickets = null,Object? maxActiveTickets = null,Object? resolvedToday = null,Object? statusChangedAt = freezed,}) {
  return _then(_AgentLoad(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,resolvedToday: null == resolvedToday ? _self.resolvedToday : resolvedToday // ignore: cast_nullable_to_non_nullable
as int,statusChangedAt: freezed == statusChangedAt ? _self.statusChangedAt : statusChangedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SupervisorOverview {

 DateTime get generatedAt; AlertThresholds get thresholds; int get openCount; DateTime? get oldestOpenAt; int get activeCount; int get resolvedToday; List<Ticket> get overdue; List<Ticket> get flaggedOpen; List<Ticket> get offlineOwned; List<AgentLoad> get agents;
/// Create a copy of SupervisorOverview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupervisorOverviewCopyWith<SupervisorOverview> get copyWith => _$SupervisorOverviewCopyWithImpl<SupervisorOverview>(this as SupervisorOverview, _$identity);

  /// Serializes this SupervisorOverview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupervisorOverview&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.thresholds, thresholds) || other.thresholds == thresholds)&&(identical(other.openCount, openCount) || other.openCount == openCount)&&(identical(other.oldestOpenAt, oldestOpenAt) || other.oldestOpenAt == oldestOpenAt)&&(identical(other.activeCount, activeCount) || other.activeCount == activeCount)&&(identical(other.resolvedToday, resolvedToday) || other.resolvedToday == resolvedToday)&&const DeepCollectionEquality().equals(other.overdue, overdue)&&const DeepCollectionEquality().equals(other.flaggedOpen, flaggedOpen)&&const DeepCollectionEquality().equals(other.offlineOwned, offlineOwned)&&const DeepCollectionEquality().equals(other.agents, agents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,generatedAt,thresholds,openCount,oldestOpenAt,activeCount,resolvedToday,const DeepCollectionEquality().hash(overdue),const DeepCollectionEquality().hash(flaggedOpen),const DeepCollectionEquality().hash(offlineOwned),const DeepCollectionEquality().hash(agents));

@override
String toString() {
  return 'SupervisorOverview(generatedAt: $generatedAt, thresholds: $thresholds, openCount: $openCount, oldestOpenAt: $oldestOpenAt, activeCount: $activeCount, resolvedToday: $resolvedToday, overdue: $overdue, flaggedOpen: $flaggedOpen, offlineOwned: $offlineOwned, agents: $agents)';
}


}

/// @nodoc
abstract mixin class $SupervisorOverviewCopyWith<$Res>  {
  factory $SupervisorOverviewCopyWith(SupervisorOverview value, $Res Function(SupervisorOverview) _then) = _$SupervisorOverviewCopyWithImpl;
@useResult
$Res call({
 DateTime generatedAt, AlertThresholds thresholds, int openCount, DateTime? oldestOpenAt, int activeCount, int resolvedToday, List<Ticket> overdue, List<Ticket> flaggedOpen, List<Ticket> offlineOwned, List<AgentLoad> agents
});


$AlertThresholdsCopyWith<$Res> get thresholds;

}
/// @nodoc
class _$SupervisorOverviewCopyWithImpl<$Res>
    implements $SupervisorOverviewCopyWith<$Res> {
  _$SupervisorOverviewCopyWithImpl(this._self, this._then);

  final SupervisorOverview _self;
  final $Res Function(SupervisorOverview) _then;

/// Create a copy of SupervisorOverview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generatedAt = null,Object? thresholds = null,Object? openCount = null,Object? oldestOpenAt = freezed,Object? activeCount = null,Object? resolvedToday = null,Object? overdue = null,Object? flaggedOpen = null,Object? offlineOwned = null,Object? agents = null,}) {
  return _then(_self.copyWith(
generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,thresholds: null == thresholds ? _self.thresholds : thresholds // ignore: cast_nullable_to_non_nullable
as AlertThresholds,openCount: null == openCount ? _self.openCount : openCount // ignore: cast_nullable_to_non_nullable
as int,oldestOpenAt: freezed == oldestOpenAt ? _self.oldestOpenAt : oldestOpenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activeCount: null == activeCount ? _self.activeCount : activeCount // ignore: cast_nullable_to_non_nullable
as int,resolvedToday: null == resolvedToday ? _self.resolvedToday : resolvedToday // ignore: cast_nullable_to_non_nullable
as int,overdue: null == overdue ? _self.overdue : overdue // ignore: cast_nullable_to_non_nullable
as List<Ticket>,flaggedOpen: null == flaggedOpen ? _self.flaggedOpen : flaggedOpen // ignore: cast_nullable_to_non_nullable
as List<Ticket>,offlineOwned: null == offlineOwned ? _self.offlineOwned : offlineOwned // ignore: cast_nullable_to_non_nullable
as List<Ticket>,agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentLoad>,
  ));
}
/// Create a copy of SupervisorOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AlertThresholdsCopyWith<$Res> get thresholds {
  
  return $AlertThresholdsCopyWith<$Res>(_self.thresholds, (value) {
    return _then(_self.copyWith(thresholds: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupervisorOverview].
extension SupervisorOverviewPatterns on SupervisorOverview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupervisorOverview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupervisorOverview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupervisorOverview value)  $default,){
final _that = this;
switch (_that) {
case _SupervisorOverview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupervisorOverview value)?  $default,){
final _that = this;
switch (_that) {
case _SupervisorOverview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime generatedAt,  AlertThresholds thresholds,  int openCount,  DateTime? oldestOpenAt,  int activeCount,  int resolvedToday,  List<Ticket> overdue,  List<Ticket> flaggedOpen,  List<Ticket> offlineOwned,  List<AgentLoad> agents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupervisorOverview() when $default != null:
return $default(_that.generatedAt,_that.thresholds,_that.openCount,_that.oldestOpenAt,_that.activeCount,_that.resolvedToday,_that.overdue,_that.flaggedOpen,_that.offlineOwned,_that.agents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime generatedAt,  AlertThresholds thresholds,  int openCount,  DateTime? oldestOpenAt,  int activeCount,  int resolvedToday,  List<Ticket> overdue,  List<Ticket> flaggedOpen,  List<Ticket> offlineOwned,  List<AgentLoad> agents)  $default,) {final _that = this;
switch (_that) {
case _SupervisorOverview():
return $default(_that.generatedAt,_that.thresholds,_that.openCount,_that.oldestOpenAt,_that.activeCount,_that.resolvedToday,_that.overdue,_that.flaggedOpen,_that.offlineOwned,_that.agents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime generatedAt,  AlertThresholds thresholds,  int openCount,  DateTime? oldestOpenAt,  int activeCount,  int resolvedToday,  List<Ticket> overdue,  List<Ticket> flaggedOpen,  List<Ticket> offlineOwned,  List<AgentLoad> agents)?  $default,) {final _that = this;
switch (_that) {
case _SupervisorOverview() when $default != null:
return $default(_that.generatedAt,_that.thresholds,_that.openCount,_that.oldestOpenAt,_that.activeCount,_that.resolvedToday,_that.overdue,_that.flaggedOpen,_that.offlineOwned,_that.agents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupervisorOverview extends SupervisorOverview {
  const _SupervisorOverview({required this.generatedAt, this.thresholds = const AlertThresholds(), this.openCount = 0, this.oldestOpenAt, this.activeCount = 0, this.resolvedToday = 0, final  List<Ticket> overdue = const <Ticket>[], final  List<Ticket> flaggedOpen = const <Ticket>[], final  List<Ticket> offlineOwned = const <Ticket>[], final  List<AgentLoad> agents = const <AgentLoad>[]}): _overdue = overdue,_flaggedOpen = flaggedOpen,_offlineOwned = offlineOwned,_agents = agents,super._();
  factory _SupervisorOverview.fromJson(Map<String, dynamic> json) => _$SupervisorOverviewFromJson(json);

@override final  DateTime generatedAt;
@override@JsonKey() final  AlertThresholds thresholds;
@override@JsonKey() final  int openCount;
@override final  DateTime? oldestOpenAt;
@override@JsonKey() final  int activeCount;
@override@JsonKey() final  int resolvedToday;
 final  List<Ticket> _overdue;
@override@JsonKey() List<Ticket> get overdue {
  if (_overdue is EqualUnmodifiableListView) return _overdue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_overdue);
}

 final  List<Ticket> _flaggedOpen;
@override@JsonKey() List<Ticket> get flaggedOpen {
  if (_flaggedOpen is EqualUnmodifiableListView) return _flaggedOpen;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flaggedOpen);
}

 final  List<Ticket> _offlineOwned;
@override@JsonKey() List<Ticket> get offlineOwned {
  if (_offlineOwned is EqualUnmodifiableListView) return _offlineOwned;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_offlineOwned);
}

 final  List<AgentLoad> _agents;
@override@JsonKey() List<AgentLoad> get agents {
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_agents);
}


/// Create a copy of SupervisorOverview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupervisorOverviewCopyWith<_SupervisorOverview> get copyWith => __$SupervisorOverviewCopyWithImpl<_SupervisorOverview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupervisorOverviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupervisorOverview&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.thresholds, thresholds) || other.thresholds == thresholds)&&(identical(other.openCount, openCount) || other.openCount == openCount)&&(identical(other.oldestOpenAt, oldestOpenAt) || other.oldestOpenAt == oldestOpenAt)&&(identical(other.activeCount, activeCount) || other.activeCount == activeCount)&&(identical(other.resolvedToday, resolvedToday) || other.resolvedToday == resolvedToday)&&const DeepCollectionEquality().equals(other._overdue, _overdue)&&const DeepCollectionEquality().equals(other._flaggedOpen, _flaggedOpen)&&const DeepCollectionEquality().equals(other._offlineOwned, _offlineOwned)&&const DeepCollectionEquality().equals(other._agents, _agents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,generatedAt,thresholds,openCount,oldestOpenAt,activeCount,resolvedToday,const DeepCollectionEquality().hash(_overdue),const DeepCollectionEquality().hash(_flaggedOpen),const DeepCollectionEquality().hash(_offlineOwned),const DeepCollectionEquality().hash(_agents));

@override
String toString() {
  return 'SupervisorOverview(generatedAt: $generatedAt, thresholds: $thresholds, openCount: $openCount, oldestOpenAt: $oldestOpenAt, activeCount: $activeCount, resolvedToday: $resolvedToday, overdue: $overdue, flaggedOpen: $flaggedOpen, offlineOwned: $offlineOwned, agents: $agents)';
}


}

/// @nodoc
abstract mixin class _$SupervisorOverviewCopyWith<$Res> implements $SupervisorOverviewCopyWith<$Res> {
  factory _$SupervisorOverviewCopyWith(_SupervisorOverview value, $Res Function(_SupervisorOverview) _then) = __$SupervisorOverviewCopyWithImpl;
@override @useResult
$Res call({
 DateTime generatedAt, AlertThresholds thresholds, int openCount, DateTime? oldestOpenAt, int activeCount, int resolvedToday, List<Ticket> overdue, List<Ticket> flaggedOpen, List<Ticket> offlineOwned, List<AgentLoad> agents
});


@override $AlertThresholdsCopyWith<$Res> get thresholds;

}
/// @nodoc
class __$SupervisorOverviewCopyWithImpl<$Res>
    implements _$SupervisorOverviewCopyWith<$Res> {
  __$SupervisorOverviewCopyWithImpl(this._self, this._then);

  final _SupervisorOverview _self;
  final $Res Function(_SupervisorOverview) _then;

/// Create a copy of SupervisorOverview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generatedAt = null,Object? thresholds = null,Object? openCount = null,Object? oldestOpenAt = freezed,Object? activeCount = null,Object? resolvedToday = null,Object? overdue = null,Object? flaggedOpen = null,Object? offlineOwned = null,Object? agents = null,}) {
  return _then(_SupervisorOverview(
generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,thresholds: null == thresholds ? _self.thresholds : thresholds // ignore: cast_nullable_to_non_nullable
as AlertThresholds,openCount: null == openCount ? _self.openCount : openCount // ignore: cast_nullable_to_non_nullable
as int,oldestOpenAt: freezed == oldestOpenAt ? _self.oldestOpenAt : oldestOpenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activeCount: null == activeCount ? _self.activeCount : activeCount // ignore: cast_nullable_to_non_nullable
as int,resolvedToday: null == resolvedToday ? _self.resolvedToday : resolvedToday // ignore: cast_nullable_to_non_nullable
as int,overdue: null == overdue ? _self._overdue : overdue // ignore: cast_nullable_to_non_nullable
as List<Ticket>,flaggedOpen: null == flaggedOpen ? _self._flaggedOpen : flaggedOpen // ignore: cast_nullable_to_non_nullable
as List<Ticket>,offlineOwned: null == offlineOwned ? _self._offlineOwned : offlineOwned // ignore: cast_nullable_to_non_nullable
as List<Ticket>,agents: null == agents ? _self._agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentLoad>,
  ));
}

/// Create a copy of SupervisorOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AlertThresholdsCopyWith<$Res> get thresholds {
  
  return $AlertThresholdsCopyWith<$Res>(_self.thresholds, (value) {
    return _then(_self.copyWith(thresholds: value));
  });
}
}


/// @nodoc
mixin _$ReportStats {

 DateTime? get day; int get created; int get resolved; double? get avgClaimMinutes; double? get avgFirstResponseMinutes; double? get avgResolutionMinutes; double? get avgRating; int get ratings;
/// Create a copy of ReportStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportStatsCopyWith<ReportStats> get copyWith => _$ReportStatsCopyWithImpl<ReportStats>(this as ReportStats, _$identity);

  /// Serializes this ReportStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportStats&&(identical(other.day, day) || other.day == day)&&(identical(other.created, created) || other.created == created)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&(identical(other.avgClaimMinutes, avgClaimMinutes) || other.avgClaimMinutes == avgClaimMinutes)&&(identical(other.avgFirstResponseMinutes, avgFirstResponseMinutes) || other.avgFirstResponseMinutes == avgFirstResponseMinutes)&&(identical(other.avgResolutionMinutes, avgResolutionMinutes) || other.avgResolutionMinutes == avgResolutionMinutes)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.ratings, ratings) || other.ratings == ratings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,created,resolved,avgClaimMinutes,avgFirstResponseMinutes,avgResolutionMinutes,avgRating,ratings);

@override
String toString() {
  return 'ReportStats(day: $day, created: $created, resolved: $resolved, avgClaimMinutes: $avgClaimMinutes, avgFirstResponseMinutes: $avgFirstResponseMinutes, avgResolutionMinutes: $avgResolutionMinutes, avgRating: $avgRating, ratings: $ratings)';
}


}

/// @nodoc
abstract mixin class $ReportStatsCopyWith<$Res>  {
  factory $ReportStatsCopyWith(ReportStats value, $Res Function(ReportStats) _then) = _$ReportStatsCopyWithImpl;
@useResult
$Res call({
 DateTime? day, int created, int resolved, double? avgClaimMinutes, double? avgFirstResponseMinutes, double? avgResolutionMinutes, double? avgRating, int ratings
});




}
/// @nodoc
class _$ReportStatsCopyWithImpl<$Res>
    implements $ReportStatsCopyWith<$Res> {
  _$ReportStatsCopyWithImpl(this._self, this._then);

  final ReportStats _self;
  final $Res Function(ReportStats) _then;

/// Create a copy of ReportStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = freezed,Object? created = null,Object? resolved = null,Object? avgClaimMinutes = freezed,Object? avgFirstResponseMinutes = freezed,Object? avgResolutionMinutes = freezed,Object? avgRating = freezed,Object? ratings = null,}) {
  return _then(_self.copyWith(
day: freezed == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime?,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as int,avgClaimMinutes: freezed == avgClaimMinutes ? _self.avgClaimMinutes : avgClaimMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgFirstResponseMinutes: freezed == avgFirstResponseMinutes ? _self.avgFirstResponseMinutes : avgFirstResponseMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgResolutionMinutes: freezed == avgResolutionMinutes ? _self.avgResolutionMinutes : avgResolutionMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,ratings: null == ratings ? _self.ratings : ratings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportStats].
extension ReportStatsPatterns on ReportStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportStats value)  $default,){
final _that = this;
switch (_that) {
case _ReportStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportStats value)?  $default,){
final _that = this;
switch (_that) {
case _ReportStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime? day,  int created,  int resolved,  double? avgClaimMinutes,  double? avgFirstResponseMinutes,  double? avgResolutionMinutes,  double? avgRating,  int ratings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportStats() when $default != null:
return $default(_that.day,_that.created,_that.resolved,_that.avgClaimMinutes,_that.avgFirstResponseMinutes,_that.avgResolutionMinutes,_that.avgRating,_that.ratings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime? day,  int created,  int resolved,  double? avgClaimMinutes,  double? avgFirstResponseMinutes,  double? avgResolutionMinutes,  double? avgRating,  int ratings)  $default,) {final _that = this;
switch (_that) {
case _ReportStats():
return $default(_that.day,_that.created,_that.resolved,_that.avgClaimMinutes,_that.avgFirstResponseMinutes,_that.avgResolutionMinutes,_that.avgRating,_that.ratings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime? day,  int created,  int resolved,  double? avgClaimMinutes,  double? avgFirstResponseMinutes,  double? avgResolutionMinutes,  double? avgRating,  int ratings)?  $default,) {final _that = this;
switch (_that) {
case _ReportStats() when $default != null:
return $default(_that.day,_that.created,_that.resolved,_that.avgClaimMinutes,_that.avgFirstResponseMinutes,_that.avgResolutionMinutes,_that.avgRating,_that.ratings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReportStats implements ReportStats {
  const _ReportStats({this.day, this.created = 0, this.resolved = 0, this.avgClaimMinutes, this.avgFirstResponseMinutes, this.avgResolutionMinutes, this.avgRating, this.ratings = 0});
  factory _ReportStats.fromJson(Map<String, dynamic> json) => _$ReportStatsFromJson(json);

@override final  DateTime? day;
@override@JsonKey() final  int created;
@override@JsonKey() final  int resolved;
@override final  double? avgClaimMinutes;
@override final  double? avgFirstResponseMinutes;
@override final  double? avgResolutionMinutes;
@override final  double? avgRating;
@override@JsonKey() final  int ratings;

/// Create a copy of ReportStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportStatsCopyWith<_ReportStats> get copyWith => __$ReportStatsCopyWithImpl<_ReportStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReportStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportStats&&(identical(other.day, day) || other.day == day)&&(identical(other.created, created) || other.created == created)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&(identical(other.avgClaimMinutes, avgClaimMinutes) || other.avgClaimMinutes == avgClaimMinutes)&&(identical(other.avgFirstResponseMinutes, avgFirstResponseMinutes) || other.avgFirstResponseMinutes == avgFirstResponseMinutes)&&(identical(other.avgResolutionMinutes, avgResolutionMinutes) || other.avgResolutionMinutes == avgResolutionMinutes)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.ratings, ratings) || other.ratings == ratings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,created,resolved,avgClaimMinutes,avgFirstResponseMinutes,avgResolutionMinutes,avgRating,ratings);

@override
String toString() {
  return 'ReportStats(day: $day, created: $created, resolved: $resolved, avgClaimMinutes: $avgClaimMinutes, avgFirstResponseMinutes: $avgFirstResponseMinutes, avgResolutionMinutes: $avgResolutionMinutes, avgRating: $avgRating, ratings: $ratings)';
}


}

/// @nodoc
abstract mixin class _$ReportStatsCopyWith<$Res> implements $ReportStatsCopyWith<$Res> {
  factory _$ReportStatsCopyWith(_ReportStats value, $Res Function(_ReportStats) _then) = __$ReportStatsCopyWithImpl;
@override @useResult
$Res call({
 DateTime? day, int created, int resolved, double? avgClaimMinutes, double? avgFirstResponseMinutes, double? avgResolutionMinutes, double? avgRating, int ratings
});




}
/// @nodoc
class __$ReportStatsCopyWithImpl<$Res>
    implements _$ReportStatsCopyWith<$Res> {
  __$ReportStatsCopyWithImpl(this._self, this._then);

  final _ReportStats _self;
  final $Res Function(_ReportStats) _then;

/// Create a copy of ReportStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = freezed,Object? created = null,Object? resolved = null,Object? avgClaimMinutes = freezed,Object? avgFirstResponseMinutes = freezed,Object? avgResolutionMinutes = freezed,Object? avgRating = freezed,Object? ratings = null,}) {
  return _then(_ReportStats(
day: freezed == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime?,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as int,avgClaimMinutes: freezed == avgClaimMinutes ? _self.avgClaimMinutes : avgClaimMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgFirstResponseMinutes: freezed == avgFirstResponseMinutes ? _self.avgFirstResponseMinutes : avgFirstResponseMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgResolutionMinutes: freezed == avgResolutionMinutes ? _self.avgResolutionMinutes : avgResolutionMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,ratings: null == ratings ? _self.ratings : ratings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AgentReport {

 String get id; String get displayName; String? get agentCode; int get handled; int get resolved; double? get avgFirstResponseMinutes; double? get avgRating; int get ratings;
/// Create a copy of AgentReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentReportCopyWith<AgentReport> get copyWith => _$AgentReportCopyWithImpl<AgentReport>(this as AgentReport, _$identity);

  /// Serializes this AgentReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentReport&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.handled, handled) || other.handled == handled)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&(identical(other.avgFirstResponseMinutes, avgFirstResponseMinutes) || other.avgFirstResponseMinutes == avgFirstResponseMinutes)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.ratings, ratings) || other.ratings == ratings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,handled,resolved,avgFirstResponseMinutes,avgRating,ratings);

@override
String toString() {
  return 'AgentReport(id: $id, displayName: $displayName, agentCode: $agentCode, handled: $handled, resolved: $resolved, avgFirstResponseMinutes: $avgFirstResponseMinutes, avgRating: $avgRating, ratings: $ratings)';
}


}

/// @nodoc
abstract mixin class $AgentReportCopyWith<$Res>  {
  factory $AgentReportCopyWith(AgentReport value, $Res Function(AgentReport) _then) = _$AgentReportCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String? agentCode, int handled, int resolved, double? avgFirstResponseMinutes, double? avgRating, int ratings
});




}
/// @nodoc
class _$AgentReportCopyWithImpl<$Res>
    implements $AgentReportCopyWith<$Res> {
  _$AgentReportCopyWithImpl(this._self, this._then);

  final AgentReport _self;
  final $Res Function(AgentReport) _then;

/// Create a copy of AgentReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? handled = null,Object? resolved = null,Object? avgFirstResponseMinutes = freezed,Object? avgRating = freezed,Object? ratings = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,handled: null == handled ? _self.handled : handled // ignore: cast_nullable_to_non_nullable
as int,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as int,avgFirstResponseMinutes: freezed == avgFirstResponseMinutes ? _self.avgFirstResponseMinutes : avgFirstResponseMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,ratings: null == ratings ? _self.ratings : ratings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentReport].
extension AgentReportPatterns on AgentReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentReport value)  $default,){
final _that = this;
switch (_that) {
case _AgentReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentReport value)?  $default,){
final _that = this;
switch (_that) {
case _AgentReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode,  int handled,  int resolved,  double? avgFirstResponseMinutes,  double? avgRating,  int ratings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentReport() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.handled,_that.resolved,_that.avgFirstResponseMinutes,_that.avgRating,_that.ratings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode,  int handled,  int resolved,  double? avgFirstResponseMinutes,  double? avgRating,  int ratings)  $default,) {final _that = this;
switch (_that) {
case _AgentReport():
return $default(_that.id,_that.displayName,_that.agentCode,_that.handled,_that.resolved,_that.avgFirstResponseMinutes,_that.avgRating,_that.ratings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String? agentCode,  int handled,  int resolved,  double? avgFirstResponseMinutes,  double? avgRating,  int ratings)?  $default,) {final _that = this;
switch (_that) {
case _AgentReport() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.handled,_that.resolved,_that.avgFirstResponseMinutes,_that.avgRating,_that.ratings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentReport implements AgentReport {
  const _AgentReport({required this.id, required this.displayName, this.agentCode, this.handled = 0, this.resolved = 0, this.avgFirstResponseMinutes, this.avgRating, this.ratings = 0});
  factory _AgentReport.fromJson(Map<String, dynamic> json) => _$AgentReportFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  String? agentCode;
@override@JsonKey() final  int handled;
@override@JsonKey() final  int resolved;
@override final  double? avgFirstResponseMinutes;
@override final  double? avgRating;
@override@JsonKey() final  int ratings;

/// Create a copy of AgentReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentReportCopyWith<_AgentReport> get copyWith => __$AgentReportCopyWithImpl<_AgentReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentReport&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.handled, handled) || other.handled == handled)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&(identical(other.avgFirstResponseMinutes, avgFirstResponseMinutes) || other.avgFirstResponseMinutes == avgFirstResponseMinutes)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.ratings, ratings) || other.ratings == ratings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,handled,resolved,avgFirstResponseMinutes,avgRating,ratings);

@override
String toString() {
  return 'AgentReport(id: $id, displayName: $displayName, agentCode: $agentCode, handled: $handled, resolved: $resolved, avgFirstResponseMinutes: $avgFirstResponseMinutes, avgRating: $avgRating, ratings: $ratings)';
}


}

/// @nodoc
abstract mixin class _$AgentReportCopyWith<$Res> implements $AgentReportCopyWith<$Res> {
  factory _$AgentReportCopyWith(_AgentReport value, $Res Function(_AgentReport) _then) = __$AgentReportCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String? agentCode, int handled, int resolved, double? avgFirstResponseMinutes, double? avgRating, int ratings
});




}
/// @nodoc
class __$AgentReportCopyWithImpl<$Res>
    implements _$AgentReportCopyWith<$Res> {
  __$AgentReportCopyWithImpl(this._self, this._then);

  final _AgentReport _self;
  final $Res Function(_AgentReport) _then;

/// Create a copy of AgentReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? handled = null,Object? resolved = null,Object? avgFirstResponseMinutes = freezed,Object? avgRating = freezed,Object? ratings = null,}) {
  return _then(_AgentReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,handled: null == handled ? _self.handled : handled // ignore: cast_nullable_to_non_nullable
as int,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as int,avgFirstResponseMinutes: freezed == avgFirstResponseMinutes ? _self.avgFirstResponseMinutes : avgFirstResponseMinutes // ignore: cast_nullable_to_non_nullable
as double?,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,ratings: null == ratings ? _self.ratings : ratings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TopicCount {

 String get topic; String get name; int get count;
/// Create a copy of TopicCount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopicCountCopyWith<TopicCount> get copyWith => _$TopicCountCopyWithImpl<TopicCount>(this as TopicCount, _$identity);

  /// Serializes this TopicCount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopicCount&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.name, name) || other.name == name)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,topic,name,count);

@override
String toString() {
  return 'TopicCount(topic: $topic, name: $name, count: $count)';
}


}

/// @nodoc
abstract mixin class $TopicCountCopyWith<$Res>  {
  factory $TopicCountCopyWith(TopicCount value, $Res Function(TopicCount) _then) = _$TopicCountCopyWithImpl;
@useResult
$Res call({
 String topic, String name, int count
});




}
/// @nodoc
class _$TopicCountCopyWithImpl<$Res>
    implements $TopicCountCopyWith<$Res> {
  _$TopicCountCopyWithImpl(this._self, this._then);

  final TopicCount _self;
  final $Res Function(TopicCount) _then;

/// Create a copy of TopicCount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? topic = null,Object? name = null,Object? count = null,}) {
  return _then(_self.copyWith(
topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TopicCount].
extension TopicCountPatterns on TopicCount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopicCount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopicCount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopicCount value)  $default,){
final _that = this;
switch (_that) {
case _TopicCount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopicCount value)?  $default,){
final _that = this;
switch (_that) {
case _TopicCount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String topic,  String name,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopicCount() when $default != null:
return $default(_that.topic,_that.name,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String topic,  String name,  int count)  $default,) {final _that = this;
switch (_that) {
case _TopicCount():
return $default(_that.topic,_that.name,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String topic,  String name,  int count)?  $default,) {final _that = this;
switch (_that) {
case _TopicCount() when $default != null:
return $default(_that.topic,_that.name,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopicCount implements TopicCount {
  const _TopicCount({required this.topic, required this.name, this.count = 0});
  factory _TopicCount.fromJson(Map<String, dynamic> json) => _$TopicCountFromJson(json);

@override final  String topic;
@override final  String name;
@override@JsonKey() final  int count;

/// Create a copy of TopicCount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopicCountCopyWith<_TopicCount> get copyWith => __$TopicCountCopyWithImpl<_TopicCount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopicCountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopicCount&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.name, name) || other.name == name)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,topic,name,count);

@override
String toString() {
  return 'TopicCount(topic: $topic, name: $name, count: $count)';
}


}

/// @nodoc
abstract mixin class _$TopicCountCopyWith<$Res> implements $TopicCountCopyWith<$Res> {
  factory _$TopicCountCopyWith(_TopicCount value, $Res Function(_TopicCount) _then) = __$TopicCountCopyWithImpl;
@override @useResult
$Res call({
 String topic, String name, int count
});




}
/// @nodoc
class __$TopicCountCopyWithImpl<$Res>
    implements _$TopicCountCopyWith<$Res> {
  __$TopicCountCopyWithImpl(this._self, this._then);

  final _TopicCount _self;
  final $Res Function(_TopicCount) _then;

/// Create a copy of TopicCount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? topic = null,Object? name = null,Object? count = null,}) {
  return _then(_TopicCount(
topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ReportSummary {

 DateTime get from; DateTime get to; ReportStats get totals; List<ReportStats> get daily; List<AgentReport> get agents; List<TopicCount> get topics;
/// Create a copy of ReportSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportSummaryCopyWith<ReportSummary> get copyWith => _$ReportSummaryCopyWithImpl<ReportSummary>(this as ReportSummary, _$identity);

  /// Serializes this ReportSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportSummary&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.totals, totals) || other.totals == totals)&&const DeepCollectionEquality().equals(other.daily, daily)&&const DeepCollectionEquality().equals(other.agents, agents)&&const DeepCollectionEquality().equals(other.topics, topics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,from,to,totals,const DeepCollectionEquality().hash(daily),const DeepCollectionEquality().hash(agents),const DeepCollectionEquality().hash(topics));

@override
String toString() {
  return 'ReportSummary(from: $from, to: $to, totals: $totals, daily: $daily, agents: $agents, topics: $topics)';
}


}

/// @nodoc
abstract mixin class $ReportSummaryCopyWith<$Res>  {
  factory $ReportSummaryCopyWith(ReportSummary value, $Res Function(ReportSummary) _then) = _$ReportSummaryCopyWithImpl;
@useResult
$Res call({
 DateTime from, DateTime to, ReportStats totals, List<ReportStats> daily, List<AgentReport> agents, List<TopicCount> topics
});


$ReportStatsCopyWith<$Res> get totals;

}
/// @nodoc
class _$ReportSummaryCopyWithImpl<$Res>
    implements $ReportSummaryCopyWith<$Res> {
  _$ReportSummaryCopyWithImpl(this._self, this._then);

  final ReportSummary _self;
  final $Res Function(ReportSummary) _then;

/// Create a copy of ReportSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? to = null,Object? totals = null,Object? daily = null,Object? agents = null,Object? topics = null,}) {
  return _then(_self.copyWith(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as DateTime,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as DateTime,totals: null == totals ? _self.totals : totals // ignore: cast_nullable_to_non_nullable
as ReportStats,daily: null == daily ? _self.daily : daily // ignore: cast_nullable_to_non_nullable
as List<ReportStats>,agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentReport>,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<TopicCount>,
  ));
}
/// Create a copy of ReportSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReportStatsCopyWith<$Res> get totals {
  
  return $ReportStatsCopyWith<$Res>(_self.totals, (value) {
    return _then(_self.copyWith(totals: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReportSummary].
extension ReportSummaryPatterns on ReportSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportSummary value)  $default,){
final _that = this;
switch (_that) {
case _ReportSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ReportSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime from,  DateTime to,  ReportStats totals,  List<ReportStats> daily,  List<AgentReport> agents,  List<TopicCount> topics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportSummary() when $default != null:
return $default(_that.from,_that.to,_that.totals,_that.daily,_that.agents,_that.topics);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime from,  DateTime to,  ReportStats totals,  List<ReportStats> daily,  List<AgentReport> agents,  List<TopicCount> topics)  $default,) {final _that = this;
switch (_that) {
case _ReportSummary():
return $default(_that.from,_that.to,_that.totals,_that.daily,_that.agents,_that.topics);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime from,  DateTime to,  ReportStats totals,  List<ReportStats> daily,  List<AgentReport> agents,  List<TopicCount> topics)?  $default,) {final _that = this;
switch (_that) {
case _ReportSummary() when $default != null:
return $default(_that.from,_that.to,_that.totals,_that.daily,_that.agents,_that.topics);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReportSummary implements ReportSummary {
  const _ReportSummary({required this.from, required this.to, this.totals = const ReportStats(), final  List<ReportStats> daily = const <ReportStats>[], final  List<AgentReport> agents = const <AgentReport>[], final  List<TopicCount> topics = const <TopicCount>[]}): _daily = daily,_agents = agents,_topics = topics;
  factory _ReportSummary.fromJson(Map<String, dynamic> json) => _$ReportSummaryFromJson(json);

@override final  DateTime from;
@override final  DateTime to;
@override@JsonKey() final  ReportStats totals;
 final  List<ReportStats> _daily;
@override@JsonKey() List<ReportStats> get daily {
  if (_daily is EqualUnmodifiableListView) return _daily;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_daily);
}

 final  List<AgentReport> _agents;
@override@JsonKey() List<AgentReport> get agents {
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_agents);
}

 final  List<TopicCount> _topics;
@override@JsonKey() List<TopicCount> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}


/// Create a copy of ReportSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportSummaryCopyWith<_ReportSummary> get copyWith => __$ReportSummaryCopyWithImpl<_ReportSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReportSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportSummary&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.totals, totals) || other.totals == totals)&&const DeepCollectionEquality().equals(other._daily, _daily)&&const DeepCollectionEquality().equals(other._agents, _agents)&&const DeepCollectionEquality().equals(other._topics, _topics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,from,to,totals,const DeepCollectionEquality().hash(_daily),const DeepCollectionEquality().hash(_agents),const DeepCollectionEquality().hash(_topics));

@override
String toString() {
  return 'ReportSummary(from: $from, to: $to, totals: $totals, daily: $daily, agents: $agents, topics: $topics)';
}


}

/// @nodoc
abstract mixin class _$ReportSummaryCopyWith<$Res> implements $ReportSummaryCopyWith<$Res> {
  factory _$ReportSummaryCopyWith(_ReportSummary value, $Res Function(_ReportSummary) _then) = __$ReportSummaryCopyWithImpl;
@override @useResult
$Res call({
 DateTime from, DateTime to, ReportStats totals, List<ReportStats> daily, List<AgentReport> agents, List<TopicCount> topics
});


@override $ReportStatsCopyWith<$Res> get totals;

}
/// @nodoc
class __$ReportSummaryCopyWithImpl<$Res>
    implements _$ReportSummaryCopyWith<$Res> {
  __$ReportSummaryCopyWithImpl(this._self, this._then);

  final _ReportSummary _self;
  final $Res Function(_ReportSummary) _then;

/// Create a copy of ReportSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,Object? totals = null,Object? daily = null,Object? agents = null,Object? topics = null,}) {
  return _then(_ReportSummary(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as DateTime,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as DateTime,totals: null == totals ? _self.totals : totals // ignore: cast_nullable_to_non_nullable
as ReportStats,daily: null == daily ? _self._daily : daily // ignore: cast_nullable_to_non_nullable
as List<ReportStats>,agents: null == agents ? _self._agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentReport>,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<TopicCount>,
  ));
}

/// Create a copy of ReportSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReportStatsCopyWith<$Res> get totals {
  
  return $ReportStatsCopyWith<$Res>(_self.totals, (value) {
    return _then(_self.copyWith(totals: value));
  });
}
}

// dart format on
