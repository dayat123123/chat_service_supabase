// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentSettings {

 int get waitWarnMinutes; int get waitLateMinutes; int get idleLogoutMinutes; String get assignmentMode; Map<String, Map<String, String>> get outcomes; Map<String, Map<String, String>> get revealReasons;
/// Create a copy of AgentSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentSettingsCopyWith<AgentSettings> get copyWith => _$AgentSettingsCopyWithImpl<AgentSettings>(this as AgentSettings, _$identity);

  /// Serializes this AgentSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentSettings&&(identical(other.waitWarnMinutes, waitWarnMinutes) || other.waitWarnMinutes == waitWarnMinutes)&&(identical(other.waitLateMinutes, waitLateMinutes) || other.waitLateMinutes == waitLateMinutes)&&(identical(other.idleLogoutMinutes, idleLogoutMinutes) || other.idleLogoutMinutes == idleLogoutMinutes)&&(identical(other.assignmentMode, assignmentMode) || other.assignmentMode == assignmentMode)&&const DeepCollectionEquality().equals(other.outcomes, outcomes)&&const DeepCollectionEquality().equals(other.revealReasons, revealReasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,waitWarnMinutes,waitLateMinutes,idleLogoutMinutes,assignmentMode,const DeepCollectionEquality().hash(outcomes),const DeepCollectionEquality().hash(revealReasons));

@override
String toString() {
  return 'AgentSettings(waitWarnMinutes: $waitWarnMinutes, waitLateMinutes: $waitLateMinutes, idleLogoutMinutes: $idleLogoutMinutes, assignmentMode: $assignmentMode, outcomes: $outcomes, revealReasons: $revealReasons)';
}


}

/// @nodoc
abstract mixin class $AgentSettingsCopyWith<$Res>  {
  factory $AgentSettingsCopyWith(AgentSettings value, $Res Function(AgentSettings) _then) = _$AgentSettingsCopyWithImpl;
@useResult
$Res call({
 int waitWarnMinutes, int waitLateMinutes, int idleLogoutMinutes, String assignmentMode, Map<String, Map<String, String>> outcomes, Map<String, Map<String, String>> revealReasons
});




}
/// @nodoc
class _$AgentSettingsCopyWithImpl<$Res>
    implements $AgentSettingsCopyWith<$Res> {
  _$AgentSettingsCopyWithImpl(this._self, this._then);

  final AgentSettings _self;
  final $Res Function(AgentSettings) _then;

/// Create a copy of AgentSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? waitWarnMinutes = null,Object? waitLateMinutes = null,Object? idleLogoutMinutes = null,Object? assignmentMode = null,Object? outcomes = null,Object? revealReasons = null,}) {
  return _then(_self.copyWith(
waitWarnMinutes: null == waitWarnMinutes ? _self.waitWarnMinutes : waitWarnMinutes // ignore: cast_nullable_to_non_nullable
as int,waitLateMinutes: null == waitLateMinutes ? _self.waitLateMinutes : waitLateMinutes // ignore: cast_nullable_to_non_nullable
as int,idleLogoutMinutes: null == idleLogoutMinutes ? _self.idleLogoutMinutes : idleLogoutMinutes // ignore: cast_nullable_to_non_nullable
as int,assignmentMode: null == assignmentMode ? _self.assignmentMode : assignmentMode // ignore: cast_nullable_to_non_nullable
as String,outcomes: null == outcomes ? _self.outcomes : outcomes // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, String>>,revealReasons: null == revealReasons ? _self.revealReasons : revealReasons // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, String>>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentSettings].
extension AgentSettingsPatterns on AgentSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentSettings value)  $default,){
final _that = this;
switch (_that) {
case _AgentSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AgentSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int waitWarnMinutes,  int waitLateMinutes,  int idleLogoutMinutes,  String assignmentMode,  Map<String, Map<String, String>> outcomes,  Map<String, Map<String, String>> revealReasons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentSettings() when $default != null:
return $default(_that.waitWarnMinutes,_that.waitLateMinutes,_that.idleLogoutMinutes,_that.assignmentMode,_that.outcomes,_that.revealReasons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int waitWarnMinutes,  int waitLateMinutes,  int idleLogoutMinutes,  String assignmentMode,  Map<String, Map<String, String>> outcomes,  Map<String, Map<String, String>> revealReasons)  $default,) {final _that = this;
switch (_that) {
case _AgentSettings():
return $default(_that.waitWarnMinutes,_that.waitLateMinutes,_that.idleLogoutMinutes,_that.assignmentMode,_that.outcomes,_that.revealReasons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int waitWarnMinutes,  int waitLateMinutes,  int idleLogoutMinutes,  String assignmentMode,  Map<String, Map<String, String>> outcomes,  Map<String, Map<String, String>> revealReasons)?  $default,) {final _that = this;
switch (_that) {
case _AgentSettings() when $default != null:
return $default(_that.waitWarnMinutes,_that.waitLateMinutes,_that.idleLogoutMinutes,_that.assignmentMode,_that.outcomes,_that.revealReasons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentSettings implements AgentSettings {
  const _AgentSettings({this.waitWarnMinutes = 5, this.waitLateMinutes = 15, this.idleLogoutMinutes = 30, this.assignmentMode = 'claim', final  Map<String, Map<String, String>> outcomes = const <String, Map<String, String>>{}, final  Map<String, Map<String, String>> revealReasons = const <String, Map<String, String>>{}}): _outcomes = outcomes,_revealReasons = revealReasons;
  factory _AgentSettings.fromJson(Map<String, dynamic> json) => _$AgentSettingsFromJson(json);

@override@JsonKey() final  int waitWarnMinutes;
@override@JsonKey() final  int waitLateMinutes;
@override@JsonKey() final  int idleLogoutMinutes;
@override@JsonKey() final  String assignmentMode;
 final  Map<String, Map<String, String>> _outcomes;
@override@JsonKey() Map<String, Map<String, String>> get outcomes {
  if (_outcomes is EqualUnmodifiableMapView) return _outcomes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_outcomes);
}

 final  Map<String, Map<String, String>> _revealReasons;
@override@JsonKey() Map<String, Map<String, String>> get revealReasons {
  if (_revealReasons is EqualUnmodifiableMapView) return _revealReasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_revealReasons);
}


/// Create a copy of AgentSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentSettingsCopyWith<_AgentSettings> get copyWith => __$AgentSettingsCopyWithImpl<_AgentSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentSettings&&(identical(other.waitWarnMinutes, waitWarnMinutes) || other.waitWarnMinutes == waitWarnMinutes)&&(identical(other.waitLateMinutes, waitLateMinutes) || other.waitLateMinutes == waitLateMinutes)&&(identical(other.idleLogoutMinutes, idleLogoutMinutes) || other.idleLogoutMinutes == idleLogoutMinutes)&&(identical(other.assignmentMode, assignmentMode) || other.assignmentMode == assignmentMode)&&const DeepCollectionEquality().equals(other._outcomes, _outcomes)&&const DeepCollectionEquality().equals(other._revealReasons, _revealReasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,waitWarnMinutes,waitLateMinutes,idleLogoutMinutes,assignmentMode,const DeepCollectionEquality().hash(_outcomes),const DeepCollectionEquality().hash(_revealReasons));

@override
String toString() {
  return 'AgentSettings(waitWarnMinutes: $waitWarnMinutes, waitLateMinutes: $waitLateMinutes, idleLogoutMinutes: $idleLogoutMinutes, assignmentMode: $assignmentMode, outcomes: $outcomes, revealReasons: $revealReasons)';
}


}

/// @nodoc
abstract mixin class _$AgentSettingsCopyWith<$Res> implements $AgentSettingsCopyWith<$Res> {
  factory _$AgentSettingsCopyWith(_AgentSettings value, $Res Function(_AgentSettings) _then) = __$AgentSettingsCopyWithImpl;
@override @useResult
$Res call({
 int waitWarnMinutes, int waitLateMinutes, int idleLogoutMinutes, String assignmentMode, Map<String, Map<String, String>> outcomes, Map<String, Map<String, String>> revealReasons
});




}
/// @nodoc
class __$AgentSettingsCopyWithImpl<$Res>
    implements _$AgentSettingsCopyWith<$Res> {
  __$AgentSettingsCopyWithImpl(this._self, this._then);

  final _AgentSettings _self;
  final $Res Function(_AgentSettings) _then;

/// Create a copy of AgentSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? waitWarnMinutes = null,Object? waitLateMinutes = null,Object? idleLogoutMinutes = null,Object? assignmentMode = null,Object? outcomes = null,Object? revealReasons = null,}) {
  return _then(_AgentSettings(
waitWarnMinutes: null == waitWarnMinutes ? _self.waitWarnMinutes : waitWarnMinutes // ignore: cast_nullable_to_non_nullable
as int,waitLateMinutes: null == waitLateMinutes ? _self.waitLateMinutes : waitLateMinutes // ignore: cast_nullable_to_non_nullable
as int,idleLogoutMinutes: null == idleLogoutMinutes ? _self.idleLogoutMinutes : idleLogoutMinutes // ignore: cast_nullable_to_non_nullable
as int,assignmentMode: null == assignmentMode ? _self.assignmentMode : assignmentMode // ignore: cast_nullable_to_non_nullable
as String,outcomes: null == outcomes ? _self._outcomes : outcomes // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, String>>,revealReasons: null == revealReasons ? _self._revealReasons : revealReasons // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, String>>,
  ));
}


}


/// @nodoc
mixin _$AgentProfile {

 String get id; String get agentCode; String get displayName; List<String> get roles; String? get team; int get maxActiveTickets;@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus get status; int get activeTickets; AgentSettings get settings;
/// Create a copy of AgentProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentProfileCopyWith<AgentProfile> get copyWith => _$AgentProfileCopyWithImpl<AgentProfile>(this as AgentProfile, _$identity);

  /// Serializes this AgentProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.team, team) || other.team == team)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentCode,displayName,const DeepCollectionEquality().hash(roles),team,maxActiveTickets,status,activeTickets,settings);

@override
String toString() {
  return 'AgentProfile(id: $id, agentCode: $agentCode, displayName: $displayName, roles: $roles, team: $team, maxActiveTickets: $maxActiveTickets, status: $status, activeTickets: $activeTickets, settings: $settings)';
}


}

/// @nodoc
abstract mixin class $AgentProfileCopyWith<$Res>  {
  factory $AgentProfileCopyWith(AgentProfile value, $Res Function(AgentProfile) _then) = _$AgentProfileCopyWithImpl;
@useResult
$Res call({
 String id, String agentCode, String displayName, List<String> roles, String? team, int maxActiveTickets,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, int activeTickets, AgentSettings settings
});


$AgentSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$AgentProfileCopyWithImpl<$Res>
    implements $AgentProfileCopyWith<$Res> {
  _$AgentProfileCopyWithImpl(this._self, this._then);

  final AgentProfile _self;
  final $Res Function(AgentProfile) _then;

/// Create a copy of AgentProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agentCode = null,Object? displayName = null,Object? roles = null,Object? team = freezed,Object? maxActiveTickets = null,Object? status = null,Object? activeTickets = null,Object? settings = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentCode: null == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,team: freezed == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as String?,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as AgentSettings,
  ));
}
/// Create a copy of AgentProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentSettingsCopyWith<$Res> get settings {
  
  return $AgentSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentProfile].
extension AgentProfilePatterns on AgentProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentProfile value)  $default,){
final _that = this;
switch (_that) {
case _AgentProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentProfile value)?  $default,){
final _that = this;
switch (_that) {
case _AgentProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agentCode,  String displayName,  List<String> roles,  String? team,  int maxActiveTickets, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  AgentSettings settings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentProfile() when $default != null:
return $default(_that.id,_that.agentCode,_that.displayName,_that.roles,_that.team,_that.maxActiveTickets,_that.status,_that.activeTickets,_that.settings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agentCode,  String displayName,  List<String> roles,  String? team,  int maxActiveTickets, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  AgentSettings settings)  $default,) {final _that = this;
switch (_that) {
case _AgentProfile():
return $default(_that.id,_that.agentCode,_that.displayName,_that.roles,_that.team,_that.maxActiveTickets,_that.status,_that.activeTickets,_that.settings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agentCode,  String displayName,  List<String> roles,  String? team,  int maxActiveTickets, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  AgentSettings settings)?  $default,) {final _that = this;
switch (_that) {
case _AgentProfile() when $default != null:
return $default(_that.id,_that.agentCode,_that.displayName,_that.roles,_that.team,_that.maxActiveTickets,_that.status,_that.activeTickets,_that.settings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentProfile extends AgentProfile {
  const _AgentProfile({required this.id, required this.agentCode, required this.displayName, final  List<String> roles = const <String>[], this.team, this.maxActiveTickets = 5, @JsonKey(unknownEnumValue: AgentStatus.offline) this.status = AgentStatus.offline, this.activeTickets = 0, this.settings = const AgentSettings()}): _roles = roles,super._();
  factory _AgentProfile.fromJson(Map<String, dynamic> json) => _$AgentProfileFromJson(json);

@override final  String id;
@override final  String agentCode;
@override final  String displayName;
 final  List<String> _roles;
@override@JsonKey() List<String> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override final  String? team;
@override@JsonKey() final  int maxActiveTickets;
@override@JsonKey(unknownEnumValue: AgentStatus.offline) final  AgentStatus status;
@override@JsonKey() final  int activeTickets;
@override@JsonKey() final  AgentSettings settings;

/// Create a copy of AgentProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentProfileCopyWith<_AgentProfile> get copyWith => __$AgentProfileCopyWithImpl<_AgentProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.team, team) || other.team == team)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.settings, settings) || other.settings == settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentCode,displayName,const DeepCollectionEquality().hash(_roles),team,maxActiveTickets,status,activeTickets,settings);

@override
String toString() {
  return 'AgentProfile(id: $id, agentCode: $agentCode, displayName: $displayName, roles: $roles, team: $team, maxActiveTickets: $maxActiveTickets, status: $status, activeTickets: $activeTickets, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$AgentProfileCopyWith<$Res> implements $AgentProfileCopyWith<$Res> {
  factory _$AgentProfileCopyWith(_AgentProfile value, $Res Function(_AgentProfile) _then) = __$AgentProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentCode, String displayName, List<String> roles, String? team, int maxActiveTickets,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, int activeTickets, AgentSettings settings
});


@override $AgentSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$AgentProfileCopyWithImpl<$Res>
    implements _$AgentProfileCopyWith<$Res> {
  __$AgentProfileCopyWithImpl(this._self, this._then);

  final _AgentProfile _self;
  final $Res Function(_AgentProfile) _then;

/// Create a copy of AgentProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentCode = null,Object? displayName = null,Object? roles = null,Object? team = freezed,Object? maxActiveTickets = null,Object? status = null,Object? activeTickets = null,Object? settings = null,}) {
  return _then(_AgentProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentCode: null == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,team: freezed == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as String?,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as AgentSettings,
  ));
}

/// Create a copy of AgentProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentSettingsCopyWith<$Res> get settings {
  
  return $AgentSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// @nodoc
mixin _$OnlineAgent {

 String get id; String get displayName; String? get agentCode;@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus get status; int get activeTickets; int get maxActiveTickets; bool get canTake;
/// Create a copy of OnlineAgent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineAgentCopyWith<OnlineAgent> get copyWith => _$OnlineAgentCopyWithImpl<OnlineAgent>(this as OnlineAgent, _$identity);

  /// Serializes this OnlineAgent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineAgent&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.canTake, canTake) || other.canTake == canTake));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,status,activeTickets,maxActiveTickets,canTake);

@override
String toString() {
  return 'OnlineAgent(id: $id, displayName: $displayName, agentCode: $agentCode, status: $status, activeTickets: $activeTickets, maxActiveTickets: $maxActiveTickets, canTake: $canTake)';
}


}

/// @nodoc
abstract mixin class $OnlineAgentCopyWith<$Res>  {
  factory $OnlineAgentCopyWith(OnlineAgent value, $Res Function(OnlineAgent) _then) = _$OnlineAgentCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String? agentCode,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, int activeTickets, int maxActiveTickets, bool canTake
});




}
/// @nodoc
class _$OnlineAgentCopyWithImpl<$Res>
    implements $OnlineAgentCopyWith<$Res> {
  _$OnlineAgentCopyWithImpl(this._self, this._then);

  final OnlineAgent _self;
  final $Res Function(OnlineAgent) _then;

/// Create a copy of OnlineAgent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? status = null,Object? activeTickets = null,Object? maxActiveTickets = null,Object? canTake = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,canTake: null == canTake ? _self.canTake : canTake // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineAgent].
extension OnlineAgentPatterns on OnlineAgent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineAgent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineAgent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineAgent value)  $default,){
final _that = this;
switch (_that) {
case _OnlineAgent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineAgent value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineAgent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  int maxActiveTickets,  bool canTake)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineAgent() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.status,_that.activeTickets,_that.maxActiveTickets,_that.canTake);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  int maxActiveTickets,  bool canTake)  $default,) {final _that = this;
switch (_that) {
case _OnlineAgent():
return $default(_that.id,_that.displayName,_that.agentCode,_that.status,_that.activeTickets,_that.maxActiveTickets,_that.canTake);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String? agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  int maxActiveTickets,  bool canTake)?  $default,) {final _that = this;
switch (_that) {
case _OnlineAgent() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.status,_that.activeTickets,_that.maxActiveTickets,_that.canTake);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OnlineAgent implements OnlineAgent {
  const _OnlineAgent({required this.id, required this.displayName, this.agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline) this.status = AgentStatus.offline, this.activeTickets = 0, this.maxActiveTickets = 5, this.canTake = false});
  factory _OnlineAgent.fromJson(Map<String, dynamic> json) => _$OnlineAgentFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  String? agentCode;
@override@JsonKey(unknownEnumValue: AgentStatus.offline) final  AgentStatus status;
@override@JsonKey() final  int activeTickets;
@override@JsonKey() final  int maxActiveTickets;
@override@JsonKey() final  bool canTake;

/// Create a copy of OnlineAgent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineAgentCopyWith<_OnlineAgent> get copyWith => __$OnlineAgentCopyWithImpl<_OnlineAgent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OnlineAgentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineAgent&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.canTake, canTake) || other.canTake == canTake));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,status,activeTickets,maxActiveTickets,canTake);

@override
String toString() {
  return 'OnlineAgent(id: $id, displayName: $displayName, agentCode: $agentCode, status: $status, activeTickets: $activeTickets, maxActiveTickets: $maxActiveTickets, canTake: $canTake)';
}


}

/// @nodoc
abstract mixin class _$OnlineAgentCopyWith<$Res> implements $OnlineAgentCopyWith<$Res> {
  factory _$OnlineAgentCopyWith(_OnlineAgent value, $Res Function(_OnlineAgent) _then) = __$OnlineAgentCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String? agentCode,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, int activeTickets, int maxActiveTickets, bool canTake
});




}
/// @nodoc
class __$OnlineAgentCopyWithImpl<$Res>
    implements _$OnlineAgentCopyWith<$Res> {
  __$OnlineAgentCopyWithImpl(this._self, this._then);

  final _OnlineAgent _self;
  final $Res Function(_OnlineAgent) _then;

/// Create a copy of OnlineAgent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? status = null,Object? activeTickets = null,Object? maxActiveTickets = null,Object? canTake = null,}) {
  return _then(_OnlineAgent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,canTake: null == canTake ? _self.canTake : canTake // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
