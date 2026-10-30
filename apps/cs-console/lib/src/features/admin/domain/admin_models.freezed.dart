// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StaffAccount {

 String get id; String get agentCode; String get displayName; String? get email; List<String> get roles; String? get team; int get maxActiveTickets; DateTime? get disabledAt;@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus get status; int get activeTickets; bool get totp; DateTime? get createdAt;
/// Create a copy of StaffAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StaffAccountCopyWith<StaffAccount> get copyWith => _$StaffAccountCopyWithImpl<StaffAccount>(this as StaffAccount, _$identity);

  /// Serializes this StaffAccount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StaffAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.team, team) || other.team == team)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.disabledAt, disabledAt) || other.disabledAt == disabledAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.totp, totp) || other.totp == totp)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentCode,displayName,email,const DeepCollectionEquality().hash(roles),team,maxActiveTickets,disabledAt,status,activeTickets,totp,createdAt);

@override
String toString() {
  return 'StaffAccount(id: $id, agentCode: $agentCode, displayName: $displayName, email: $email, roles: $roles, team: $team, maxActiveTickets: $maxActiveTickets, disabledAt: $disabledAt, status: $status, activeTickets: $activeTickets, totp: $totp, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $StaffAccountCopyWith<$Res>  {
  factory $StaffAccountCopyWith(StaffAccount value, $Res Function(StaffAccount) _then) = _$StaffAccountCopyWithImpl;
@useResult
$Res call({
 String id, String agentCode, String displayName, String? email, List<String> roles, String? team, int maxActiveTickets, DateTime? disabledAt,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, int activeTickets, bool totp, DateTime? createdAt
});




}
/// @nodoc
class _$StaffAccountCopyWithImpl<$Res>
    implements $StaffAccountCopyWith<$Res> {
  _$StaffAccountCopyWithImpl(this._self, this._then);

  final StaffAccount _self;
  final $Res Function(StaffAccount) _then;

/// Create a copy of StaffAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agentCode = null,Object? displayName = null,Object? email = freezed,Object? roles = null,Object? team = freezed,Object? maxActiveTickets = null,Object? disabledAt = freezed,Object? status = null,Object? activeTickets = null,Object? totp = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentCode: null == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,team: freezed == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as String?,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,disabledAt: freezed == disabledAt ? _self.disabledAt : disabledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,totp: null == totp ? _self.totp : totp // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StaffAccount].
extension StaffAccountPatterns on StaffAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StaffAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StaffAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StaffAccount value)  $default,){
final _that = this;
switch (_that) {
case _StaffAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StaffAccount value)?  $default,){
final _that = this;
switch (_that) {
case _StaffAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agentCode,  String displayName,  String? email,  List<String> roles,  String? team,  int maxActiveTickets,  DateTime? disabledAt, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  bool totp,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StaffAccount() when $default != null:
return $default(_that.id,_that.agentCode,_that.displayName,_that.email,_that.roles,_that.team,_that.maxActiveTickets,_that.disabledAt,_that.status,_that.activeTickets,_that.totp,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agentCode,  String displayName,  String? email,  List<String> roles,  String? team,  int maxActiveTickets,  DateTime? disabledAt, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  bool totp,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _StaffAccount():
return $default(_that.id,_that.agentCode,_that.displayName,_that.email,_that.roles,_that.team,_that.maxActiveTickets,_that.disabledAt,_that.status,_that.activeTickets,_that.totp,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agentCode,  String displayName,  String? email,  List<String> roles,  String? team,  int maxActiveTickets,  DateTime? disabledAt, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status,  int activeTickets,  bool totp,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _StaffAccount() when $default != null:
return $default(_that.id,_that.agentCode,_that.displayName,_that.email,_that.roles,_that.team,_that.maxActiveTickets,_that.disabledAt,_that.status,_that.activeTickets,_that.totp,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StaffAccount extends StaffAccount {
  const _StaffAccount({required this.id, required this.agentCode, required this.displayName, this.email, final  List<String> roles = const <String>[], this.team, this.maxActiveTickets = 5, this.disabledAt, @JsonKey(unknownEnumValue: AgentStatus.offline) this.status = AgentStatus.offline, this.activeTickets = 0, this.totp = false, this.createdAt}): _roles = roles,super._();
  factory _StaffAccount.fromJson(Map<String, dynamic> json) => _$StaffAccountFromJson(json);

@override final  String id;
@override final  String agentCode;
@override final  String displayName;
@override final  String? email;
 final  List<String> _roles;
@override@JsonKey() List<String> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override final  String? team;
@override@JsonKey() final  int maxActiveTickets;
@override final  DateTime? disabledAt;
@override@JsonKey(unknownEnumValue: AgentStatus.offline) final  AgentStatus status;
@override@JsonKey() final  int activeTickets;
@override@JsonKey() final  bool totp;
@override final  DateTime? createdAt;

/// Create a copy of StaffAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StaffAccountCopyWith<_StaffAccount> get copyWith => __$StaffAccountCopyWithImpl<_StaffAccount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StaffAccountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StaffAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.team, team) || other.team == team)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.disabledAt, disabledAt) || other.disabledAt == disabledAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.activeTickets, activeTickets) || other.activeTickets == activeTickets)&&(identical(other.totp, totp) || other.totp == totp)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentCode,displayName,email,const DeepCollectionEquality().hash(_roles),team,maxActiveTickets,disabledAt,status,activeTickets,totp,createdAt);

@override
String toString() {
  return 'StaffAccount(id: $id, agentCode: $agentCode, displayName: $displayName, email: $email, roles: $roles, team: $team, maxActiveTickets: $maxActiveTickets, disabledAt: $disabledAt, status: $status, activeTickets: $activeTickets, totp: $totp, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$StaffAccountCopyWith<$Res> implements $StaffAccountCopyWith<$Res> {
  factory _$StaffAccountCopyWith(_StaffAccount value, $Res Function(_StaffAccount) _then) = __$StaffAccountCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentCode, String displayName, String? email, List<String> roles, String? team, int maxActiveTickets, DateTime? disabledAt,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status, int activeTickets, bool totp, DateTime? createdAt
});




}
/// @nodoc
class __$StaffAccountCopyWithImpl<$Res>
    implements _$StaffAccountCopyWith<$Res> {
  __$StaffAccountCopyWithImpl(this._self, this._then);

  final _StaffAccount _self;
  final $Res Function(_StaffAccount) _then;

/// Create a copy of StaffAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentCode = null,Object? displayName = null,Object? email = freezed,Object? roles = null,Object? team = freezed,Object? maxActiveTickets = null,Object? disabledAt = freezed,Object? status = null,Object? activeTickets = null,Object? totp = null,Object? createdAt = freezed,}) {
  return _then(_StaffAccount(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentCode: null == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,team: freezed == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as String?,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,disabledAt: freezed == disabledAt ? _self.disabledAt : disabledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,activeTickets: null == activeTickets ? _self.activeTickets : activeTickets // ignore: cast_nullable_to_non_nullable
as int,totp: null == totp ? _self.totp : totp // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$AccountDraft {

@JsonKey(includeIfNull: false) String? get email; String get displayName; List<String> get roles; String get team; int get maxActiveTickets; bool get disabled;
/// Create a copy of AccountDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountDraftCopyWith<AccountDraft> get copyWith => _$AccountDraftCopyWithImpl<AccountDraft>(this as AccountDraft, _$identity);

  /// Serializes this AccountDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountDraft&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.team, team) || other.team == team)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.disabled, disabled) || other.disabled == disabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,displayName,const DeepCollectionEquality().hash(roles),team,maxActiveTickets,disabled);

@override
String toString() {
  return 'AccountDraft(email: $email, displayName: $displayName, roles: $roles, team: $team, maxActiveTickets: $maxActiveTickets, disabled: $disabled)';
}


}

/// @nodoc
abstract mixin class $AccountDraftCopyWith<$Res>  {
  factory $AccountDraftCopyWith(AccountDraft value, $Res Function(AccountDraft) _then) = _$AccountDraftCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeIfNull: false) String? email, String displayName, List<String> roles, String team, int maxActiveTickets, bool disabled
});




}
/// @nodoc
class _$AccountDraftCopyWithImpl<$Res>
    implements $AccountDraftCopyWith<$Res> {
  _$AccountDraftCopyWithImpl(this._self, this._then);

  final AccountDraft _self;
  final $Res Function(AccountDraft) _then;

/// Create a copy of AccountDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = freezed,Object? displayName = null,Object? roles = null,Object? team = null,Object? maxActiveTickets = null,Object? disabled = null,}) {
  return _then(_self.copyWith(
email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as String,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountDraft].
extension AccountDraftPatterns on AccountDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountDraft value)  $default,){
final _that = this;
switch (_that) {
case _AccountDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountDraft value)?  $default,){
final _that = this;
switch (_that) {
case _AccountDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeIfNull: false)  String? email,  String displayName,  List<String> roles,  String team,  int maxActiveTickets,  bool disabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountDraft() when $default != null:
return $default(_that.email,_that.displayName,_that.roles,_that.team,_that.maxActiveTickets,_that.disabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeIfNull: false)  String? email,  String displayName,  List<String> roles,  String team,  int maxActiveTickets,  bool disabled)  $default,) {final _that = this;
switch (_that) {
case _AccountDraft():
return $default(_that.email,_that.displayName,_that.roles,_that.team,_that.maxActiveTickets,_that.disabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeIfNull: false)  String? email,  String displayName,  List<String> roles,  String team,  int maxActiveTickets,  bool disabled)?  $default,) {final _that = this;
switch (_that) {
case _AccountDraft() when $default != null:
return $default(_that.email,_that.displayName,_that.roles,_that.team,_that.maxActiveTickets,_that.disabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountDraft implements AccountDraft {
  const _AccountDraft({@JsonKey(includeIfNull: false) this.email, required this.displayName, required final  List<String> roles, required this.team, required this.maxActiveTickets, this.disabled = false}): _roles = roles;
  factory _AccountDraft.fromJson(Map<String, dynamic> json) => _$AccountDraftFromJson(json);

@override@JsonKey(includeIfNull: false) final  String? email;
@override final  String displayName;
 final  List<String> _roles;
@override List<String> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override final  String team;
@override final  int maxActiveTickets;
@override@JsonKey() final  bool disabled;

/// Create a copy of AccountDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountDraftCopyWith<_AccountDraft> get copyWith => __$AccountDraftCopyWithImpl<_AccountDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountDraftToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountDraft&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.team, team) || other.team == team)&&(identical(other.maxActiveTickets, maxActiveTickets) || other.maxActiveTickets == maxActiveTickets)&&(identical(other.disabled, disabled) || other.disabled == disabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,displayName,const DeepCollectionEquality().hash(_roles),team,maxActiveTickets,disabled);

@override
String toString() {
  return 'AccountDraft(email: $email, displayName: $displayName, roles: $roles, team: $team, maxActiveTickets: $maxActiveTickets, disabled: $disabled)';
}


}

/// @nodoc
abstract mixin class _$AccountDraftCopyWith<$Res> implements $AccountDraftCopyWith<$Res> {
  factory _$AccountDraftCopyWith(_AccountDraft value, $Res Function(_AccountDraft) _then) = __$AccountDraftCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeIfNull: false) String? email, String displayName, List<String> roles, String team, int maxActiveTickets, bool disabled
});




}
/// @nodoc
class __$AccountDraftCopyWithImpl<$Res>
    implements _$AccountDraftCopyWith<$Res> {
  __$AccountDraftCopyWithImpl(this._self, this._then);

  final _AccountDraft _self;
  final $Res Function(_AccountDraft) _then;

/// Create a copy of AccountDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = freezed,Object? displayName = null,Object? roles = null,Object? team = null,Object? maxActiveTickets = null,Object? disabled = null,}) {
  return _then(_AccountDraft(
email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as String,maxActiveTickets: null == maxActiveTickets ? _self.maxActiveTickets : maxActiveTickets // ignore: cast_nullable_to_non_nullable
as int,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CreatedAccount {

 StaffAccount get agent; String get temporaryPassword;
/// Create a copy of CreatedAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreatedAccountCopyWith<CreatedAccount> get copyWith => _$CreatedAccountCopyWithImpl<CreatedAccount>(this as CreatedAccount, _$identity);

  /// Serializes this CreatedAccount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreatedAccount&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.temporaryPassword, temporaryPassword) || other.temporaryPassword == temporaryPassword));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agent,temporaryPassword);

@override
String toString() {
  return 'CreatedAccount(agent: $agent, temporaryPassword: $temporaryPassword)';
}


}

/// @nodoc
abstract mixin class $CreatedAccountCopyWith<$Res>  {
  factory $CreatedAccountCopyWith(CreatedAccount value, $Res Function(CreatedAccount) _then) = _$CreatedAccountCopyWithImpl;
@useResult
$Res call({
 StaffAccount agent, String temporaryPassword
});


$StaffAccountCopyWith<$Res> get agent;

}
/// @nodoc
class _$CreatedAccountCopyWithImpl<$Res>
    implements $CreatedAccountCopyWith<$Res> {
  _$CreatedAccountCopyWithImpl(this._self, this._then);

  final CreatedAccount _self;
  final $Res Function(CreatedAccount) _then;

/// Create a copy of CreatedAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agent = null,Object? temporaryPassword = null,}) {
  return _then(_self.copyWith(
agent: null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as StaffAccount,temporaryPassword: null == temporaryPassword ? _self.temporaryPassword : temporaryPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of CreatedAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StaffAccountCopyWith<$Res> get agent {
  
  return $StaffAccountCopyWith<$Res>(_self.agent, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}


/// Adds pattern-matching-related methods to [CreatedAccount].
extension CreatedAccountPatterns on CreatedAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreatedAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreatedAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreatedAccount value)  $default,){
final _that = this;
switch (_that) {
case _CreatedAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreatedAccount value)?  $default,){
final _that = this;
switch (_that) {
case _CreatedAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StaffAccount agent,  String temporaryPassword)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreatedAccount() when $default != null:
return $default(_that.agent,_that.temporaryPassword);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StaffAccount agent,  String temporaryPassword)  $default,) {final _that = this;
switch (_that) {
case _CreatedAccount():
return $default(_that.agent,_that.temporaryPassword);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StaffAccount agent,  String temporaryPassword)?  $default,) {final _that = this;
switch (_that) {
case _CreatedAccount() when $default != null:
return $default(_that.agent,_that.temporaryPassword);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreatedAccount implements CreatedAccount {
  const _CreatedAccount({required this.agent, required this.temporaryPassword});
  factory _CreatedAccount.fromJson(Map<String, dynamic> json) => _$CreatedAccountFromJson(json);

@override final  StaffAccount agent;
@override final  String temporaryPassword;

/// Create a copy of CreatedAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreatedAccountCopyWith<_CreatedAccount> get copyWith => __$CreatedAccountCopyWithImpl<_CreatedAccount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreatedAccountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreatedAccount&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.temporaryPassword, temporaryPassword) || other.temporaryPassword == temporaryPassword));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agent,temporaryPassword);

@override
String toString() {
  return 'CreatedAccount(agent: $agent, temporaryPassword: $temporaryPassword)';
}


}

/// @nodoc
abstract mixin class _$CreatedAccountCopyWith<$Res> implements $CreatedAccountCopyWith<$Res> {
  factory _$CreatedAccountCopyWith(_CreatedAccount value, $Res Function(_CreatedAccount) _then) = __$CreatedAccountCopyWithImpl;
@override @useResult
$Res call({
 StaffAccount agent, String temporaryPassword
});


@override $StaffAccountCopyWith<$Res> get agent;

}
/// @nodoc
class __$CreatedAccountCopyWithImpl<$Res>
    implements _$CreatedAccountCopyWith<$Res> {
  __$CreatedAccountCopyWithImpl(this._self, this._then);

  final _CreatedAccount _self;
  final $Res Function(_CreatedAccount) _then;

/// Create a copy of CreatedAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agent = null,Object? temporaryPassword = null,}) {
  return _then(_CreatedAccount(
agent: null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as StaffAccount,temporaryPassword: null == temporaryPassword ? _self.temporaryPassword : temporaryPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of CreatedAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StaffAccountCopyWith<$Res> get agent {
  
  return $StaffAccountCopyWith<$Res>(_self.agent, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}


/// @nodoc
mixin _$Choice {

 String get code; String get name;
/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChoiceCopyWith<Choice> get copyWith => _$ChoiceCopyWithImpl<Choice>(this as Choice, _$identity);

  /// Serializes this Choice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Choice&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name);

@override
String toString() {
  return 'Choice(code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class $ChoiceCopyWith<$Res>  {
  factory $ChoiceCopyWith(Choice value, $Res Function(Choice) _then) = _$ChoiceCopyWithImpl;
@useResult
$Res call({
 String code, String name
});




}
/// @nodoc
class _$ChoiceCopyWithImpl<$Res>
    implements $ChoiceCopyWith<$Res> {
  _$ChoiceCopyWithImpl(this._self, this._then);

  final Choice _self;
  final $Res Function(Choice) _then;

/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Choice].
extension ChoicePatterns on Choice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Choice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Choice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Choice value)  $default,){
final _that = this;
switch (_that) {
case _Choice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Choice value)?  $default,){
final _that = this;
switch (_that) {
case _Choice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Choice() when $default != null:
return $default(_that.code,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name)  $default,) {final _that = this;
switch (_that) {
case _Choice():
return $default(_that.code,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name)?  $default,) {final _that = this;
switch (_that) {
case _Choice() when $default != null:
return $default(_that.code,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Choice implements Choice {
  const _Choice({required this.code, required this.name});
  factory _Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);

@override final  String code;
@override final  String name;

/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChoiceCopyWith<_Choice> get copyWith => __$ChoiceCopyWithImpl<_Choice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChoiceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Choice&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name);

@override
String toString() {
  return 'Choice(code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class _$ChoiceCopyWith<$Res> implements $ChoiceCopyWith<$Res> {
  factory _$ChoiceCopyWith(_Choice value, $Res Function(_Choice) _then) = __$ChoiceCopyWithImpl;
@override @useResult
$Res call({
 String code, String name
});




}
/// @nodoc
class __$ChoiceCopyWithImpl<$Res>
    implements _$ChoiceCopyWith<$Res> {
  __$ChoiceCopyWithImpl(this._self, this._then);

  final _Choice _self;
  final $Res Function(_Choice) _then;

/// Create a copy of Choice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,}) {
  return _then(_Choice(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AdminOptions {

 List<Choice> get teams; List<Choice> get skills;
/// Create a copy of AdminOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminOptionsCopyWith<AdminOptions> get copyWith => _$AdminOptionsCopyWithImpl<AdminOptions>(this as AdminOptions, _$identity);

  /// Serializes this AdminOptions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminOptions&&const DeepCollectionEquality().equals(other.teams, teams)&&const DeepCollectionEquality().equals(other.skills, skills));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(teams),const DeepCollectionEquality().hash(skills));

@override
String toString() {
  return 'AdminOptions(teams: $teams, skills: $skills)';
}


}

/// @nodoc
abstract mixin class $AdminOptionsCopyWith<$Res>  {
  factory $AdminOptionsCopyWith(AdminOptions value, $Res Function(AdminOptions) _then) = _$AdminOptionsCopyWithImpl;
@useResult
$Res call({
 List<Choice> teams, List<Choice> skills
});




}
/// @nodoc
class _$AdminOptionsCopyWithImpl<$Res>
    implements $AdminOptionsCopyWith<$Res> {
  _$AdminOptionsCopyWithImpl(this._self, this._then);

  final AdminOptions _self;
  final $Res Function(AdminOptions) _then;

/// Create a copy of AdminOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? teams = null,Object? skills = null,}) {
  return _then(_self.copyWith(
teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<Choice>,skills: null == skills ? _self.skills : skills // ignore: cast_nullable_to_non_nullable
as List<Choice>,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminOptions].
extension AdminOptionsPatterns on AdminOptions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminOptions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminOptions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminOptions value)  $default,){
final _that = this;
switch (_that) {
case _AdminOptions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminOptions value)?  $default,){
final _that = this;
switch (_that) {
case _AdminOptions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Choice> teams,  List<Choice> skills)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminOptions() when $default != null:
return $default(_that.teams,_that.skills);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Choice> teams,  List<Choice> skills)  $default,) {final _that = this;
switch (_that) {
case _AdminOptions():
return $default(_that.teams,_that.skills);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Choice> teams,  List<Choice> skills)?  $default,) {final _that = this;
switch (_that) {
case _AdminOptions() when $default != null:
return $default(_that.teams,_that.skills);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminOptions implements AdminOptions {
  const _AdminOptions({final  List<Choice> teams = const <Choice>[], final  List<Choice> skills = const <Choice>[]}): _teams = teams,_skills = skills;
  factory _AdminOptions.fromJson(Map<String, dynamic> json) => _$AdminOptionsFromJson(json);

 final  List<Choice> _teams;
@override@JsonKey() List<Choice> get teams {
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_teams);
}

 final  List<Choice> _skills;
@override@JsonKey() List<Choice> get skills {
  if (_skills is EqualUnmodifiableListView) return _skills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skills);
}


/// Create a copy of AdminOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminOptionsCopyWith<_AdminOptions> get copyWith => __$AdminOptionsCopyWithImpl<_AdminOptions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminOptionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminOptions&&const DeepCollectionEquality().equals(other._teams, _teams)&&const DeepCollectionEquality().equals(other._skills, _skills));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_teams),const DeepCollectionEquality().hash(_skills));

@override
String toString() {
  return 'AdminOptions(teams: $teams, skills: $skills)';
}


}

/// @nodoc
abstract mixin class _$AdminOptionsCopyWith<$Res> implements $AdminOptionsCopyWith<$Res> {
  factory _$AdminOptionsCopyWith(_AdminOptions value, $Res Function(_AdminOptions) _then) = __$AdminOptionsCopyWithImpl;
@override @useResult
$Res call({
 List<Choice> teams, List<Choice> skills
});




}
/// @nodoc
class __$AdminOptionsCopyWithImpl<$Res>
    implements _$AdminOptionsCopyWith<$Res> {
  __$AdminOptionsCopyWithImpl(this._self, this._then);

  final _AdminOptions _self;
  final $Res Function(_AdminOptions) _then;

/// Create a copy of AdminOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? teams = null,Object? skills = null,}) {
  return _then(_AdminOptions(
teams: null == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<Choice>,skills: null == skills ? _self._skills : skills // ignore: cast_nullable_to_non_nullable
as List<Choice>,
  ));
}


}


/// @nodoc
mixin _$TopicConfig {

 String get code; String get nameId; String get nameEn; String get skill; String get defaultPriority; String? get helpUrl; int get sortOrder; bool get active;
/// Create a copy of TopicConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopicConfigCopyWith<TopicConfig> get copyWith => _$TopicConfigCopyWithImpl<TopicConfig>(this as TopicConfig, _$identity);

  /// Serializes this TopicConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopicConfig&&(identical(other.code, code) || other.code == code)&&(identical(other.nameId, nameId) || other.nameId == nameId)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.skill, skill) || other.skill == skill)&&(identical(other.defaultPriority, defaultPriority) || other.defaultPriority == defaultPriority)&&(identical(other.helpUrl, helpUrl) || other.helpUrl == helpUrl)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,nameId,nameEn,skill,defaultPriority,helpUrl,sortOrder,active);

@override
String toString() {
  return 'TopicConfig(code: $code, nameId: $nameId, nameEn: $nameEn, skill: $skill, defaultPriority: $defaultPriority, helpUrl: $helpUrl, sortOrder: $sortOrder, active: $active)';
}


}

/// @nodoc
abstract mixin class $TopicConfigCopyWith<$Res>  {
  factory $TopicConfigCopyWith(TopicConfig value, $Res Function(TopicConfig) _then) = _$TopicConfigCopyWithImpl;
@useResult
$Res call({
 String code, String nameId, String nameEn, String skill, String defaultPriority, String? helpUrl, int sortOrder, bool active
});




}
/// @nodoc
class _$TopicConfigCopyWithImpl<$Res>
    implements $TopicConfigCopyWith<$Res> {
  _$TopicConfigCopyWithImpl(this._self, this._then);

  final TopicConfig _self;
  final $Res Function(TopicConfig) _then;

/// Create a copy of TopicConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? nameId = null,Object? nameEn = null,Object? skill = null,Object? defaultPriority = null,Object? helpUrl = freezed,Object? sortOrder = null,Object? active = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,nameId: null == nameId ? _self.nameId : nameId // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,skill: null == skill ? _self.skill : skill // ignore: cast_nullable_to_non_nullable
as String,defaultPriority: null == defaultPriority ? _self.defaultPriority : defaultPriority // ignore: cast_nullable_to_non_nullable
as String,helpUrl: freezed == helpUrl ? _self.helpUrl : helpUrl // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TopicConfig].
extension TopicConfigPatterns on TopicConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopicConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopicConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopicConfig value)  $default,){
final _that = this;
switch (_that) {
case _TopicConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopicConfig value)?  $default,){
final _that = this;
switch (_that) {
case _TopicConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String nameId,  String nameEn,  String skill,  String defaultPriority,  String? helpUrl,  int sortOrder,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopicConfig() when $default != null:
return $default(_that.code,_that.nameId,_that.nameEn,_that.skill,_that.defaultPriority,_that.helpUrl,_that.sortOrder,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String nameId,  String nameEn,  String skill,  String defaultPriority,  String? helpUrl,  int sortOrder,  bool active)  $default,) {final _that = this;
switch (_that) {
case _TopicConfig():
return $default(_that.code,_that.nameId,_that.nameEn,_that.skill,_that.defaultPriority,_that.helpUrl,_that.sortOrder,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String nameId,  String nameEn,  String skill,  String defaultPriority,  String? helpUrl,  int sortOrder,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _TopicConfig() when $default != null:
return $default(_that.code,_that.nameId,_that.nameEn,_that.skill,_that.defaultPriority,_that.helpUrl,_that.sortOrder,_that.active);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopicConfig implements TopicConfig {
  const _TopicConfig({required this.code, required this.nameId, required this.nameEn, required this.skill, this.defaultPriority = 'P3', this.helpUrl, this.sortOrder = 100, this.active = true});
  factory _TopicConfig.fromJson(Map<String, dynamic> json) => _$TopicConfigFromJson(json);

@override final  String code;
@override final  String nameId;
@override final  String nameEn;
@override final  String skill;
@override@JsonKey() final  String defaultPriority;
@override final  String? helpUrl;
@override@JsonKey() final  int sortOrder;
@override@JsonKey() final  bool active;

/// Create a copy of TopicConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopicConfigCopyWith<_TopicConfig> get copyWith => __$TopicConfigCopyWithImpl<_TopicConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopicConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopicConfig&&(identical(other.code, code) || other.code == code)&&(identical(other.nameId, nameId) || other.nameId == nameId)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.skill, skill) || other.skill == skill)&&(identical(other.defaultPriority, defaultPriority) || other.defaultPriority == defaultPriority)&&(identical(other.helpUrl, helpUrl) || other.helpUrl == helpUrl)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,nameId,nameEn,skill,defaultPriority,helpUrl,sortOrder,active);

@override
String toString() {
  return 'TopicConfig(code: $code, nameId: $nameId, nameEn: $nameEn, skill: $skill, defaultPriority: $defaultPriority, helpUrl: $helpUrl, sortOrder: $sortOrder, active: $active)';
}


}

/// @nodoc
abstract mixin class _$TopicConfigCopyWith<$Res> implements $TopicConfigCopyWith<$Res> {
  factory _$TopicConfigCopyWith(_TopicConfig value, $Res Function(_TopicConfig) _then) = __$TopicConfigCopyWithImpl;
@override @useResult
$Res call({
 String code, String nameId, String nameEn, String skill, String defaultPriority, String? helpUrl, int sortOrder, bool active
});




}
/// @nodoc
class __$TopicConfigCopyWithImpl<$Res>
    implements _$TopicConfigCopyWith<$Res> {
  __$TopicConfigCopyWithImpl(this._self, this._then);

  final _TopicConfig _self;
  final $Res Function(_TopicConfig) _then;

/// Create a copy of TopicConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? nameId = null,Object? nameEn = null,Object? skill = null,Object? defaultPriority = null,Object? helpUrl = freezed,Object? sortOrder = null,Object? active = null,}) {
  return _then(_TopicConfig(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,nameId: null == nameId ? _self.nameId : nameId // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,skill: null == skill ? _self.skill : skill // ignore: cast_nullable_to_non_nullable
as String,defaultPriority: null == defaultPriority ? _self.defaultPriority : defaultPriority // ignore: cast_nullable_to_non_nullable
as String,helpUrl: freezed == helpUrl ? _self.helpUrl : helpUrl // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$QuickReplyConfig {

 String? get id; String get shortcut; String get title; String get body; String get language; bool get active; DateTime? get updatedAt;
/// Create a copy of QuickReplyConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuickReplyConfigCopyWith<QuickReplyConfig> get copyWith => _$QuickReplyConfigCopyWithImpl<QuickReplyConfig>(this as QuickReplyConfig, _$identity);

  /// Serializes this QuickReplyConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuickReplyConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.shortcut, shortcut) || other.shortcut == shortcut)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.language, language) || other.language == language)&&(identical(other.active, active) || other.active == active)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,shortcut,title,body,language,active,updatedAt);

@override
String toString() {
  return 'QuickReplyConfig(id: $id, shortcut: $shortcut, title: $title, body: $body, language: $language, active: $active, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $QuickReplyConfigCopyWith<$Res>  {
  factory $QuickReplyConfigCopyWith(QuickReplyConfig value, $Res Function(QuickReplyConfig) _then) = _$QuickReplyConfigCopyWithImpl;
@useResult
$Res call({
 String? id, String shortcut, String title, String body, String language, bool active, DateTime? updatedAt
});




}
/// @nodoc
class _$QuickReplyConfigCopyWithImpl<$Res>
    implements $QuickReplyConfigCopyWith<$Res> {
  _$QuickReplyConfigCopyWithImpl(this._self, this._then);

  final QuickReplyConfig _self;
  final $Res Function(QuickReplyConfig) _then;

/// Create a copy of QuickReplyConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? shortcut = null,Object? title = null,Object? body = null,Object? language = null,Object? active = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,shortcut: null == shortcut ? _self.shortcut : shortcut // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuickReplyConfig].
extension QuickReplyConfigPatterns on QuickReplyConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuickReplyConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuickReplyConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuickReplyConfig value)  $default,){
final _that = this;
switch (_that) {
case _QuickReplyConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuickReplyConfig value)?  $default,){
final _that = this;
switch (_that) {
case _QuickReplyConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id,  String shortcut,  String title,  String body,  String language,  bool active,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuickReplyConfig() when $default != null:
return $default(_that.id,_that.shortcut,_that.title,_that.body,_that.language,_that.active,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id,  String shortcut,  String title,  String body,  String language,  bool active,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _QuickReplyConfig():
return $default(_that.id,_that.shortcut,_that.title,_that.body,_that.language,_that.active,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id,  String shortcut,  String title,  String body,  String language,  bool active,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _QuickReplyConfig() when $default != null:
return $default(_that.id,_that.shortcut,_that.title,_that.body,_that.language,_that.active,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuickReplyConfig implements QuickReplyConfig {
  const _QuickReplyConfig({this.id, required this.shortcut, required this.title, required this.body, this.language = 'id', this.active = true, this.updatedAt});
  factory _QuickReplyConfig.fromJson(Map<String, dynamic> json) => _$QuickReplyConfigFromJson(json);

@override final  String? id;
@override final  String shortcut;
@override final  String title;
@override final  String body;
@override@JsonKey() final  String language;
@override@JsonKey() final  bool active;
@override final  DateTime? updatedAt;

/// Create a copy of QuickReplyConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuickReplyConfigCopyWith<_QuickReplyConfig> get copyWith => __$QuickReplyConfigCopyWithImpl<_QuickReplyConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuickReplyConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuickReplyConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.shortcut, shortcut) || other.shortcut == shortcut)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.language, language) || other.language == language)&&(identical(other.active, active) || other.active == active)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,shortcut,title,body,language,active,updatedAt);

@override
String toString() {
  return 'QuickReplyConfig(id: $id, shortcut: $shortcut, title: $title, body: $body, language: $language, active: $active, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$QuickReplyConfigCopyWith<$Res> implements $QuickReplyConfigCopyWith<$Res> {
  factory _$QuickReplyConfigCopyWith(_QuickReplyConfig value, $Res Function(_QuickReplyConfig) _then) = __$QuickReplyConfigCopyWithImpl;
@override @useResult
$Res call({
 String? id, String shortcut, String title, String body, String language, bool active, DateTime? updatedAt
});




}
/// @nodoc
class __$QuickReplyConfigCopyWithImpl<$Res>
    implements _$QuickReplyConfigCopyWith<$Res> {
  __$QuickReplyConfigCopyWithImpl(this._self, this._then);

  final _QuickReplyConfig _self;
  final $Res Function(_QuickReplyConfig) _then;

/// Create a copy of QuickReplyConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? shortcut = null,Object? title = null,Object? body = null,Object? language = null,Object? active = null,Object? updatedAt = freezed,}) {
  return _then(_QuickReplyConfig(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,shortcut: null == shortcut ? _self.shortcut : shortcut // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SettingEntry {

 String get key; Object? get value; String? get description; int get version; DateTime? get updatedAt; String? get updatedBy;
/// Create a copy of SettingEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingEntryCopyWith<SettingEntry> get copyWith => _$SettingEntryCopyWithImpl<SettingEntry>(this as SettingEntry, _$identity);

  /// Serializes this SettingEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingEntry&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.value, value)&&(identical(other.description, description) || other.description == description)&&(identical(other.version, version) || other.version == version)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,const DeepCollectionEquality().hash(value),description,version,updatedAt,updatedBy);

@override
String toString() {
  return 'SettingEntry(key: $key, value: $value, description: $description, version: $version, updatedAt: $updatedAt, updatedBy: $updatedBy)';
}


}

/// @nodoc
abstract mixin class $SettingEntryCopyWith<$Res>  {
  factory $SettingEntryCopyWith(SettingEntry value, $Res Function(SettingEntry) _then) = _$SettingEntryCopyWithImpl;
@useResult
$Res call({
 String key, Object? value, String? description, int version, DateTime? updatedAt, String? updatedBy
});




}
/// @nodoc
class _$SettingEntryCopyWithImpl<$Res>
    implements $SettingEntryCopyWith<$Res> {
  _$SettingEntryCopyWithImpl(this._self, this._then);

  final SettingEntry _self;
  final $Res Function(SettingEntry) _then;

/// Create a copy of SettingEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? value = freezed,Object? description = freezed,Object? version = null,Object? updatedAt = freezed,Object? updatedBy = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedBy: freezed == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingEntry].
extension SettingEntryPatterns on SettingEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingEntry value)  $default,){
final _that = this;
switch (_that) {
case _SettingEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingEntry value)?  $default,){
final _that = this;
switch (_that) {
case _SettingEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  Object? value,  String? description,  int version,  DateTime? updatedAt,  String? updatedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingEntry() when $default != null:
return $default(_that.key,_that.value,_that.description,_that.version,_that.updatedAt,_that.updatedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  Object? value,  String? description,  int version,  DateTime? updatedAt,  String? updatedBy)  $default,) {final _that = this;
switch (_that) {
case _SettingEntry():
return $default(_that.key,_that.value,_that.description,_that.version,_that.updatedAt,_that.updatedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  Object? value,  String? description,  int version,  DateTime? updatedAt,  String? updatedBy)?  $default,) {final _that = this;
switch (_that) {
case _SettingEntry() when $default != null:
return $default(_that.key,_that.value,_that.description,_that.version,_that.updatedAt,_that.updatedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SettingEntry implements SettingEntry {
  const _SettingEntry({required this.key, required this.value, this.description, this.version = 1, this.updatedAt, this.updatedBy});
  factory _SettingEntry.fromJson(Map<String, dynamic> json) => _$SettingEntryFromJson(json);

@override final  String key;
@override final  Object? value;
@override final  String? description;
@override@JsonKey() final  int version;
@override final  DateTime? updatedAt;
@override final  String? updatedBy;

/// Create a copy of SettingEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingEntryCopyWith<_SettingEntry> get copyWith => __$SettingEntryCopyWithImpl<_SettingEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettingEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingEntry&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.value, value)&&(identical(other.description, description) || other.description == description)&&(identical(other.version, version) || other.version == version)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,const DeepCollectionEquality().hash(value),description,version,updatedAt,updatedBy);

@override
String toString() {
  return 'SettingEntry(key: $key, value: $value, description: $description, version: $version, updatedAt: $updatedAt, updatedBy: $updatedBy)';
}


}

/// @nodoc
abstract mixin class _$SettingEntryCopyWith<$Res> implements $SettingEntryCopyWith<$Res> {
  factory _$SettingEntryCopyWith(_SettingEntry value, $Res Function(_SettingEntry) _then) = __$SettingEntryCopyWithImpl;
@override @useResult
$Res call({
 String key, Object? value, String? description, int version, DateTime? updatedAt, String? updatedBy
});




}
/// @nodoc
class __$SettingEntryCopyWithImpl<$Res>
    implements _$SettingEntryCopyWith<$Res> {
  __$SettingEntryCopyWithImpl(this._self, this._then);

  final _SettingEntry _self;
  final $Res Function(_SettingEntry) _then;

/// Create a copy of SettingEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? value = freezed,Object? description = freezed,Object? version = null,Object? updatedAt = freezed,Object? updatedBy = freezed,}) {
  return _then(_SettingEntry(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedBy: freezed == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Holiday {

 DateTime get day; String get name;@JsonKey(unknownEnumValue: HolidayKind.national) HolidayKind get kind;
/// Create a copy of Holiday
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HolidayCopyWith<Holiday> get copyWith => _$HolidayCopyWithImpl<Holiday>(this as Holiday, _$identity);

  /// Serializes this Holiday to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Holiday&&(identical(other.day, day) || other.day == day)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,name,kind);

@override
String toString() {
  return 'Holiday(day: $day, name: $name, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $HolidayCopyWith<$Res>  {
  factory $HolidayCopyWith(Holiday value, $Res Function(Holiday) _then) = _$HolidayCopyWithImpl;
@useResult
$Res call({
 DateTime day, String name,@JsonKey(unknownEnumValue: HolidayKind.national) HolidayKind kind
});




}
/// @nodoc
class _$HolidayCopyWithImpl<$Res>
    implements $HolidayCopyWith<$Res> {
  _$HolidayCopyWithImpl(this._self, this._then);

  final Holiday _self;
  final $Res Function(Holiday) _then;

/// Create a copy of Holiday
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? name = null,Object? kind = null,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as HolidayKind,
  ));
}

}


/// Adds pattern-matching-related methods to [Holiday].
extension HolidayPatterns on Holiday {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Holiday value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Holiday() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Holiday value)  $default,){
final _that = this;
switch (_that) {
case _Holiday():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Holiday value)?  $default,){
final _that = this;
switch (_that) {
case _Holiday() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime day,  String name, @JsonKey(unknownEnumValue: HolidayKind.national)  HolidayKind kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Holiday() when $default != null:
return $default(_that.day,_that.name,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime day,  String name, @JsonKey(unknownEnumValue: HolidayKind.national)  HolidayKind kind)  $default,) {final _that = this;
switch (_that) {
case _Holiday():
return $default(_that.day,_that.name,_that.kind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime day,  String name, @JsonKey(unknownEnumValue: HolidayKind.national)  HolidayKind kind)?  $default,) {final _that = this;
switch (_that) {
case _Holiday() when $default != null:
return $default(_that.day,_that.name,_that.kind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Holiday implements Holiday {
  const _Holiday({required this.day, required this.name, @JsonKey(unknownEnumValue: HolidayKind.national) this.kind = HolidayKind.national});
  factory _Holiday.fromJson(Map<String, dynamic> json) => _$HolidayFromJson(json);

@override final  DateTime day;
@override final  String name;
@override@JsonKey(unknownEnumValue: HolidayKind.national) final  HolidayKind kind;

/// Create a copy of Holiday
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HolidayCopyWith<_Holiday> get copyWith => __$HolidayCopyWithImpl<_Holiday>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HolidayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Holiday&&(identical(other.day, day) || other.day == day)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,name,kind);

@override
String toString() {
  return 'Holiday(day: $day, name: $name, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$HolidayCopyWith<$Res> implements $HolidayCopyWith<$Res> {
  factory _$HolidayCopyWith(_Holiday value, $Res Function(_Holiday) _then) = __$HolidayCopyWithImpl;
@override @useResult
$Res call({
 DateTime day, String name,@JsonKey(unknownEnumValue: HolidayKind.national) HolidayKind kind
});




}
/// @nodoc
class __$HolidayCopyWithImpl<$Res>
    implements _$HolidayCopyWith<$Res> {
  __$HolidayCopyWithImpl(this._self, this._then);

  final _Holiday _self;
  final $Res Function(_Holiday) _then;

/// Create a copy of Holiday
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? name = null,Object? kind = null,}) {
  return _then(_Holiday(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as HolidayKind,
  ));
}


}

// dart format on
