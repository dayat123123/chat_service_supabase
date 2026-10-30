// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ticket.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TicketCustomer {

 String get id; String? get displayName; String? get username; bool get deleted;
/// Create a copy of TicketCustomer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketCustomerCopyWith<TicketCustomer> get copyWith => _$TicketCustomerCopyWithImpl<TicketCustomer>(this as TicketCustomer, _$identity);

  /// Serializes this TicketCustomer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketCustomer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.username, username) || other.username == username)&&(identical(other.deleted, deleted) || other.deleted == deleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,username,deleted);

@override
String toString() {
  return 'TicketCustomer(id: $id, displayName: $displayName, username: $username, deleted: $deleted)';
}


}

/// @nodoc
abstract mixin class $TicketCustomerCopyWith<$Res>  {
  factory $TicketCustomerCopyWith(TicketCustomer value, $Res Function(TicketCustomer) _then) = _$TicketCustomerCopyWithImpl;
@useResult
$Res call({
 String id, String? displayName, String? username, bool deleted
});




}
/// @nodoc
class _$TicketCustomerCopyWithImpl<$Res>
    implements $TicketCustomerCopyWith<$Res> {
  _$TicketCustomerCopyWithImpl(this._self, this._then);

  final TicketCustomer _self;
  final $Res Function(TicketCustomer) _then;

/// Create a copy of TicketCustomer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = freezed,Object? username = freezed,Object? deleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketCustomer].
extension TicketCustomerPatterns on TicketCustomer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketCustomer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketCustomer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketCustomer value)  $default,){
final _that = this;
switch (_that) {
case _TicketCustomer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketCustomer value)?  $default,){
final _that = this;
switch (_that) {
case _TicketCustomer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? displayName,  String? username,  bool deleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketCustomer() when $default != null:
return $default(_that.id,_that.displayName,_that.username,_that.deleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? displayName,  String? username,  bool deleted)  $default,) {final _that = this;
switch (_that) {
case _TicketCustomer():
return $default(_that.id,_that.displayName,_that.username,_that.deleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? displayName,  String? username,  bool deleted)?  $default,) {final _that = this;
switch (_that) {
case _TicketCustomer() when $default != null:
return $default(_that.id,_that.displayName,_that.username,_that.deleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketCustomer extends TicketCustomer {
  const _TicketCustomer({required this.id, this.displayName, this.username, this.deleted = false}): super._();
  factory _TicketCustomer.fromJson(Map<String, dynamic> json) => _$TicketCustomerFromJson(json);

@override final  String id;
@override final  String? displayName;
@override final  String? username;
@override@JsonKey() final  bool deleted;

/// Create a copy of TicketCustomer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketCustomerCopyWith<_TicketCustomer> get copyWith => __$TicketCustomerCopyWithImpl<_TicketCustomer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketCustomerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketCustomer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.username, username) || other.username == username)&&(identical(other.deleted, deleted) || other.deleted == deleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,username,deleted);

@override
String toString() {
  return 'TicketCustomer(id: $id, displayName: $displayName, username: $username, deleted: $deleted)';
}


}

/// @nodoc
abstract mixin class _$TicketCustomerCopyWith<$Res> implements $TicketCustomerCopyWith<$Res> {
  factory _$TicketCustomerCopyWith(_TicketCustomer value, $Res Function(_TicketCustomer) _then) = __$TicketCustomerCopyWithImpl;
@override @useResult
$Res call({
 String id, String? displayName, String? username, bool deleted
});




}
/// @nodoc
class __$TicketCustomerCopyWithImpl<$Res>
    implements _$TicketCustomerCopyWith<$Res> {
  __$TicketCustomerCopyWithImpl(this._self, this._then);

  final _TicketCustomer _self;
  final $Res Function(_TicketCustomer) _then;

/// Create a copy of TicketCustomer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = freezed,Object? username = freezed,Object? deleted = null,}) {
  return _then(_TicketCustomer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TicketOwner {

 String get id; String get displayName; String? get agentCode;@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus get status;
/// Create a copy of TicketOwner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketOwnerCopyWith<TicketOwner> get copyWith => _$TicketOwnerCopyWithImpl<TicketOwner>(this as TicketOwner, _$identity);

  /// Serializes this TicketOwner to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketOwner&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,status);

@override
String toString() {
  return 'TicketOwner(id: $id, displayName: $displayName, agentCode: $agentCode, status: $status)';
}


}

/// @nodoc
abstract mixin class $TicketOwnerCopyWith<$Res>  {
  factory $TicketOwnerCopyWith(TicketOwner value, $Res Function(TicketOwner) _then) = _$TicketOwnerCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String? agentCode,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status
});




}
/// @nodoc
class _$TicketOwnerCopyWithImpl<$Res>
    implements $TicketOwnerCopyWith<$Res> {
  _$TicketOwnerCopyWithImpl(this._self, this._then);

  final TicketOwner _self;
  final $Res Function(TicketOwner) _then;

/// Create a copy of TicketOwner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketOwner].
extension TicketOwnerPatterns on TicketOwner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketOwner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketOwner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketOwner value)  $default,){
final _that = this;
switch (_that) {
case _TicketOwner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketOwner value)?  $default,){
final _that = this;
switch (_that) {
case _TicketOwner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketOwner() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String? agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status)  $default,) {final _that = this;
switch (_that) {
case _TicketOwner():
return $default(_that.id,_that.displayName,_that.agentCode,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String? agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline)  AgentStatus status)?  $default,) {final _that = this;
switch (_that) {
case _TicketOwner() when $default != null:
return $default(_that.id,_that.displayName,_that.agentCode,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketOwner implements TicketOwner {
  const _TicketOwner({required this.id, required this.displayName, this.agentCode, @JsonKey(unknownEnumValue: AgentStatus.offline) this.status = AgentStatus.offline});
  factory _TicketOwner.fromJson(Map<String, dynamic> json) => _$TicketOwnerFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  String? agentCode;
@override@JsonKey(unknownEnumValue: AgentStatus.offline) final  AgentStatus status;

/// Create a copy of TicketOwner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketOwnerCopyWith<_TicketOwner> get copyWith => __$TicketOwnerCopyWithImpl<_TicketOwner>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketOwnerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketOwner&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,agentCode,status);

@override
String toString() {
  return 'TicketOwner(id: $id, displayName: $displayName, agentCode: $agentCode, status: $status)';
}


}

/// @nodoc
abstract mixin class _$TicketOwnerCopyWith<$Res> implements $TicketOwnerCopyWith<$Res> {
  factory _$TicketOwnerCopyWith(_TicketOwner value, $Res Function(_TicketOwner) _then) = __$TicketOwnerCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String? agentCode,@JsonKey(unknownEnumValue: AgentStatus.offline) AgentStatus status
});




}
/// @nodoc
class __$TicketOwnerCopyWithImpl<$Res>
    implements _$TicketOwnerCopyWith<$Res> {
  __$TicketOwnerCopyWithImpl(this._self, this._then);

  final _TicketOwner _self;
  final $Res Function(_TicketOwner) _then;

/// Create a copy of TicketOwner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? agentCode = freezed,Object? status = null,}) {
  return _then(_TicketOwner(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,
  ));
}


}


/// @nodoc
mixin _$PendingTransfer {

 String get id; String? get fromId; String? get fromName; String? get toId; String? get toName; String? get note; DateTime? get expiresAt;
/// Create a copy of PendingTransfer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingTransferCopyWith<PendingTransfer> get copyWith => _$PendingTransferCopyWithImpl<PendingTransfer>(this as PendingTransfer, _$identity);

  /// Serializes this PendingTransfer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingTransfer&&(identical(other.id, id) || other.id == id)&&(identical(other.fromId, fromId) || other.fromId == fromId)&&(identical(other.fromName, fromName) || other.fromName == fromName)&&(identical(other.toId, toId) || other.toId == toId)&&(identical(other.toName, toName) || other.toName == toName)&&(identical(other.note, note) || other.note == note)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fromId,fromName,toId,toName,note,expiresAt);

@override
String toString() {
  return 'PendingTransfer(id: $id, fromId: $fromId, fromName: $fromName, toId: $toId, toName: $toName, note: $note, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $PendingTransferCopyWith<$Res>  {
  factory $PendingTransferCopyWith(PendingTransfer value, $Res Function(PendingTransfer) _then) = _$PendingTransferCopyWithImpl;
@useResult
$Res call({
 String id, String? fromId, String? fromName, String? toId, String? toName, String? note, DateTime? expiresAt
});




}
/// @nodoc
class _$PendingTransferCopyWithImpl<$Res>
    implements $PendingTransferCopyWith<$Res> {
  _$PendingTransferCopyWithImpl(this._self, this._then);

  final PendingTransfer _self;
  final $Res Function(PendingTransfer) _then;

/// Create a copy of PendingTransfer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fromId = freezed,Object? fromName = freezed,Object? toId = freezed,Object? toName = freezed,Object? note = freezed,Object? expiresAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromId: freezed == fromId ? _self.fromId : fromId // ignore: cast_nullable_to_non_nullable
as String?,fromName: freezed == fromName ? _self.fromName : fromName // ignore: cast_nullable_to_non_nullable
as String?,toId: freezed == toId ? _self.toId : toId // ignore: cast_nullable_to_non_nullable
as String?,toName: freezed == toName ? _self.toName : toName // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PendingTransfer].
extension PendingTransferPatterns on PendingTransfer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PendingTransfer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PendingTransfer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PendingTransfer value)  $default,){
final _that = this;
switch (_that) {
case _PendingTransfer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PendingTransfer value)?  $default,){
final _that = this;
switch (_that) {
case _PendingTransfer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? fromId,  String? fromName,  String? toId,  String? toName,  String? note,  DateTime? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PendingTransfer() when $default != null:
return $default(_that.id,_that.fromId,_that.fromName,_that.toId,_that.toName,_that.note,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? fromId,  String? fromName,  String? toId,  String? toName,  String? note,  DateTime? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _PendingTransfer():
return $default(_that.id,_that.fromId,_that.fromName,_that.toId,_that.toName,_that.note,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? fromId,  String? fromName,  String? toId,  String? toName,  String? note,  DateTime? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _PendingTransfer() when $default != null:
return $default(_that.id,_that.fromId,_that.fromName,_that.toId,_that.toName,_that.note,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PendingTransfer implements PendingTransfer {
  const _PendingTransfer({required this.id, this.fromId, this.fromName, this.toId, this.toName, this.note, this.expiresAt});
  factory _PendingTransfer.fromJson(Map<String, dynamic> json) => _$PendingTransferFromJson(json);

@override final  String id;
@override final  String? fromId;
@override final  String? fromName;
@override final  String? toId;
@override final  String? toName;
@override final  String? note;
@override final  DateTime? expiresAt;

/// Create a copy of PendingTransfer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingTransferCopyWith<_PendingTransfer> get copyWith => __$PendingTransferCopyWithImpl<_PendingTransfer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PendingTransferToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingTransfer&&(identical(other.id, id) || other.id == id)&&(identical(other.fromId, fromId) || other.fromId == fromId)&&(identical(other.fromName, fromName) || other.fromName == fromName)&&(identical(other.toId, toId) || other.toId == toId)&&(identical(other.toName, toName) || other.toName == toName)&&(identical(other.note, note) || other.note == note)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fromId,fromName,toId,toName,note,expiresAt);

@override
String toString() {
  return 'PendingTransfer(id: $id, fromId: $fromId, fromName: $fromName, toId: $toId, toName: $toName, note: $note, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$PendingTransferCopyWith<$Res> implements $PendingTransferCopyWith<$Res> {
  factory _$PendingTransferCopyWith(_PendingTransfer value, $Res Function(_PendingTransfer) _then) = __$PendingTransferCopyWithImpl;
@override @useResult
$Res call({
 String id, String? fromId, String? fromName, String? toId, String? toName, String? note, DateTime? expiresAt
});




}
/// @nodoc
class __$PendingTransferCopyWithImpl<$Res>
    implements _$PendingTransferCopyWith<$Res> {
  __$PendingTransferCopyWithImpl(this._self, this._then);

  final _PendingTransfer _self;
  final $Res Function(_PendingTransfer) _then;

/// Create a copy of PendingTransfer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fromId = freezed,Object? fromName = freezed,Object? toId = freezed,Object? toName = freezed,Object? note = freezed,Object? expiresAt = freezed,}) {
  return _then(_PendingTransfer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromId: freezed == fromId ? _self.fromId : fromId // ignore: cast_nullable_to_non_nullable
as String?,fromName: freezed == fromName ? _self.fromName : fromName // ignore: cast_nullable_to_non_nullable
as String?,toId: freezed == toId ? _self.toId : toId // ignore: cast_nullable_to_non_nullable
as String?,toName: freezed == toName ? _self.toName : toName // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$TicketEvent {

 String get type; String? get actorType; String? get actorName; Map<String, dynamic> get data; DateTime get createdAt;
/// Create a copy of TicketEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketEventCopyWith<TicketEvent> get copyWith => _$TicketEventCopyWithImpl<TicketEvent>(this as TicketEvent, _$identity);

  /// Serializes this TicketEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketEvent&&(identical(other.type, type) || other.type == type)&&(identical(other.actorType, actorType) || other.actorType == actorType)&&(identical(other.actorName, actorName) || other.actorName == actorName)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,actorType,actorName,const DeepCollectionEquality().hash(data),createdAt);

@override
String toString() {
  return 'TicketEvent(type: $type, actorType: $actorType, actorName: $actorName, data: $data, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $TicketEventCopyWith<$Res>  {
  factory $TicketEventCopyWith(TicketEvent value, $Res Function(TicketEvent) _then) = _$TicketEventCopyWithImpl;
@useResult
$Res call({
 String type, String? actorType, String? actorName, Map<String, dynamic> data, DateTime createdAt
});




}
/// @nodoc
class _$TicketEventCopyWithImpl<$Res>
    implements $TicketEventCopyWith<$Res> {
  _$TicketEventCopyWithImpl(this._self, this._then);

  final TicketEvent _self;
  final $Res Function(TicketEvent) _then;

/// Create a copy of TicketEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? actorType = freezed,Object? actorName = freezed,Object? data = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorType: freezed == actorType ? _self.actorType : actorType // ignore: cast_nullable_to_non_nullable
as String?,actorName: freezed == actorName ? _self.actorName : actorName // ignore: cast_nullable_to_non_nullable
as String?,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketEvent].
extension TicketEventPatterns on TicketEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketEvent value)  $default,){
final _that = this;
switch (_that) {
case _TicketEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TicketEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String? actorType,  String? actorName,  Map<String, dynamic> data,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketEvent() when $default != null:
return $default(_that.type,_that.actorType,_that.actorName,_that.data,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String? actorType,  String? actorName,  Map<String, dynamic> data,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _TicketEvent():
return $default(_that.type,_that.actorType,_that.actorName,_that.data,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String? actorType,  String? actorName,  Map<String, dynamic> data,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TicketEvent() when $default != null:
return $default(_that.type,_that.actorType,_that.actorName,_that.data,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketEvent implements TicketEvent {
  const _TicketEvent({required this.type, this.actorType, this.actorName, final  Map<String, dynamic> data = const <String, dynamic>{}, required this.createdAt}): _data = data;
  factory _TicketEvent.fromJson(Map<String, dynamic> json) => _$TicketEventFromJson(json);

@override final  String type;
@override final  String? actorType;
@override final  String? actorName;
 final  Map<String, dynamic> _data;
@override@JsonKey() Map<String, dynamic> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}

@override final  DateTime createdAt;

/// Create a copy of TicketEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketEventCopyWith<_TicketEvent> get copyWith => __$TicketEventCopyWithImpl<_TicketEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketEvent&&(identical(other.type, type) || other.type == type)&&(identical(other.actorType, actorType) || other.actorType == actorType)&&(identical(other.actorName, actorName) || other.actorName == actorName)&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,actorType,actorName,const DeepCollectionEquality().hash(_data),createdAt);

@override
String toString() {
  return 'TicketEvent(type: $type, actorType: $actorType, actorName: $actorName, data: $data, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TicketEventCopyWith<$Res> implements $TicketEventCopyWith<$Res> {
  factory _$TicketEventCopyWith(_TicketEvent value, $Res Function(_TicketEvent) _then) = __$TicketEventCopyWithImpl;
@override @useResult
$Res call({
 String type, String? actorType, String? actorName, Map<String, dynamic> data, DateTime createdAt
});




}
/// @nodoc
class __$TicketEventCopyWithImpl<$Res>
    implements _$TicketEventCopyWith<$Res> {
  __$TicketEventCopyWithImpl(this._self, this._then);

  final _TicketEvent _self;
  final $Res Function(_TicketEvent) _then;

/// Create a copy of TicketEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? actorType = freezed,Object? actorName = freezed,Object? data = null,Object? createdAt = null,}) {
  return _then(_TicketEvent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorType: freezed == actorType ? _self.actorType : actorType // ignore: cast_nullable_to_non_nullable
as String?,actorName: freezed == actorName ? _self.actorName : actorName // ignore: cast_nullable_to_non_nullable
as String?,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Ticket {

 String get id; String get ticketNumber; String get roomId;@JsonKey(unknownEnumValue: TicketStatus.closed) TicketStatus get status; int get version; String get topic; String get priority; List<String> get flags; String get language; TicketCustomer? get customer; TicketOwner? get owner; bool get isMine; DateTime? get queuedAt; DateTime? get createdAt; DateTime? get claimedAt; DateTime? get firstResponseAt; DateTime? get lastCustomerMessageAt; DateTime? get lastAgentMessageAt; DateTime? get resolvedAt; DateTime? get closedAt; String? get outcome; String? get resolutionSummary; String? get returnedReason; DateTime? get complaintReceivedAt; DateTime? get complaintDueAt; int? get rating; String? get ratingComment; PendingTransfer? get transfer; String? get preview; int get unreadCount; DateTime? get waitingSince; List<String> get tags; List<TicketEvent> get events;
/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketCopyWith<Ticket> get copyWith => _$TicketCopyWithImpl<Ticket>(this as Ticket, _$identity);

  /// Serializes this Ticket to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ticket&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.flags, flags)&&(identical(other.language, language) || other.language == language)&&(identical(other.customer, customer) || other.customer == customer)&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.queuedAt, queuedAt) || other.queuedAt == queuedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.firstResponseAt, firstResponseAt) || other.firstResponseAt == firstResponseAt)&&(identical(other.lastCustomerMessageAt, lastCustomerMessageAt) || other.lastCustomerMessageAt == lastCustomerMessageAt)&&(identical(other.lastAgentMessageAt, lastAgentMessageAt) || other.lastAgentMessageAt == lastAgentMessageAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.resolutionSummary, resolutionSummary) || other.resolutionSummary == resolutionSummary)&&(identical(other.returnedReason, returnedReason) || other.returnedReason == returnedReason)&&(identical(other.complaintReceivedAt, complaintReceivedAt) || other.complaintReceivedAt == complaintReceivedAt)&&(identical(other.complaintDueAt, complaintDueAt) || other.complaintDueAt == complaintDueAt)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratingComment, ratingComment) || other.ratingComment == ratingComment)&&(identical(other.transfer, transfer) || other.transfer == transfer)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.waitingSince, waitingSince) || other.waitingSince == waitingSince)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.events, events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,ticketNumber,roomId,status,version,topic,priority,const DeepCollectionEquality().hash(flags),language,customer,owner,isMine,queuedAt,createdAt,claimedAt,firstResponseAt,lastCustomerMessageAt,lastAgentMessageAt,resolvedAt,closedAt,outcome,resolutionSummary,returnedReason,complaintReceivedAt,complaintDueAt,rating,ratingComment,transfer,preview,unreadCount,waitingSince,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(events)]);

@override
String toString() {
  return 'Ticket(id: $id, ticketNumber: $ticketNumber, roomId: $roomId, status: $status, version: $version, topic: $topic, priority: $priority, flags: $flags, language: $language, customer: $customer, owner: $owner, isMine: $isMine, queuedAt: $queuedAt, createdAt: $createdAt, claimedAt: $claimedAt, firstResponseAt: $firstResponseAt, lastCustomerMessageAt: $lastCustomerMessageAt, lastAgentMessageAt: $lastAgentMessageAt, resolvedAt: $resolvedAt, closedAt: $closedAt, outcome: $outcome, resolutionSummary: $resolutionSummary, returnedReason: $returnedReason, complaintReceivedAt: $complaintReceivedAt, complaintDueAt: $complaintDueAt, rating: $rating, ratingComment: $ratingComment, transfer: $transfer, preview: $preview, unreadCount: $unreadCount, waitingSince: $waitingSince, tags: $tags, events: $events)';
}


}

/// @nodoc
abstract mixin class $TicketCopyWith<$Res>  {
  factory $TicketCopyWith(Ticket value, $Res Function(Ticket) _then) = _$TicketCopyWithImpl;
@useResult
$Res call({
 String id, String ticketNumber, String roomId,@JsonKey(unknownEnumValue: TicketStatus.closed) TicketStatus status, int version, String topic, String priority, List<String> flags, String language, TicketCustomer? customer, TicketOwner? owner, bool isMine, DateTime? queuedAt, DateTime? createdAt, DateTime? claimedAt, DateTime? firstResponseAt, DateTime? lastCustomerMessageAt, DateTime? lastAgentMessageAt, DateTime? resolvedAt, DateTime? closedAt, String? outcome, String? resolutionSummary, String? returnedReason, DateTime? complaintReceivedAt, DateTime? complaintDueAt, int? rating, String? ratingComment, PendingTransfer? transfer, String? preview, int unreadCount, DateTime? waitingSince, List<String> tags, List<TicketEvent> events
});


$TicketCustomerCopyWith<$Res>? get customer;$TicketOwnerCopyWith<$Res>? get owner;$PendingTransferCopyWith<$Res>? get transfer;

}
/// @nodoc
class _$TicketCopyWithImpl<$Res>
    implements $TicketCopyWith<$Res> {
  _$TicketCopyWithImpl(this._self, this._then);

  final Ticket _self;
  final $Res Function(Ticket) _then;

/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketNumber = null,Object? roomId = null,Object? status = null,Object? version = null,Object? topic = null,Object? priority = null,Object? flags = null,Object? language = null,Object? customer = freezed,Object? owner = freezed,Object? isMine = null,Object? queuedAt = freezed,Object? createdAt = freezed,Object? claimedAt = freezed,Object? firstResponseAt = freezed,Object? lastCustomerMessageAt = freezed,Object? lastAgentMessageAt = freezed,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? outcome = freezed,Object? resolutionSummary = freezed,Object? returnedReason = freezed,Object? complaintReceivedAt = freezed,Object? complaintDueAt = freezed,Object? rating = freezed,Object? ratingComment = freezed,Object? transfer = freezed,Object? preview = freezed,Object? unreadCount = null,Object? waitingSince = freezed,Object? tags = null,Object? events = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: null == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TicketStatus,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as List<String>,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,customer: freezed == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as TicketCustomer?,owner: freezed == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TicketOwner?,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,queuedAt: freezed == queuedAt ? _self.queuedAt : queuedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,firstResponseAt: freezed == firstResponseAt ? _self.firstResponseAt : firstResponseAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastCustomerMessageAt: freezed == lastCustomerMessageAt ? _self.lastCustomerMessageAt : lastCustomerMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastAgentMessageAt: freezed == lastAgentMessageAt ? _self.lastAgentMessageAt : lastAgentMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String?,resolutionSummary: freezed == resolutionSummary ? _self.resolutionSummary : resolutionSummary // ignore: cast_nullable_to_non_nullable
as String?,returnedReason: freezed == returnedReason ? _self.returnedReason : returnedReason // ignore: cast_nullable_to_non_nullable
as String?,complaintReceivedAt: freezed == complaintReceivedAt ? _self.complaintReceivedAt : complaintReceivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,complaintDueAt: freezed == complaintDueAt ? _self.complaintDueAt : complaintDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,ratingComment: freezed == ratingComment ? _self.ratingComment : ratingComment // ignore: cast_nullable_to_non_nullable
as String?,transfer: freezed == transfer ? _self.transfer : transfer // ignore: cast_nullable_to_non_nullable
as PendingTransfer?,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,waitingSince: freezed == waitingSince ? _self.waitingSince : waitingSince // ignore: cast_nullable_to_non_nullable
as DateTime?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<TicketEvent>,
  ));
}
/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketCustomerCopyWith<$Res>? get customer {
    if (_self.customer == null) {
    return null;
  }

  return $TicketCustomerCopyWith<$Res>(_self.customer!, (value) {
    return _then(_self.copyWith(customer: value));
  });
}/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketOwnerCopyWith<$Res>? get owner {
    if (_self.owner == null) {
    return null;
  }

  return $TicketOwnerCopyWith<$Res>(_self.owner!, (value) {
    return _then(_self.copyWith(owner: value));
  });
}/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingTransferCopyWith<$Res>? get transfer {
    if (_self.transfer == null) {
    return null;
  }

  return $PendingTransferCopyWith<$Res>(_self.transfer!, (value) {
    return _then(_self.copyWith(transfer: value));
  });
}
}


/// Adds pattern-matching-related methods to [Ticket].
extension TicketPatterns on Ticket {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Ticket value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Ticket() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Ticket value)  $default,){
final _that = this;
switch (_that) {
case _Ticket():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Ticket value)?  $default,){
final _that = this;
switch (_that) {
case _Ticket() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticketNumber,  String roomId, @JsonKey(unknownEnumValue: TicketStatus.closed)  TicketStatus status,  int version,  String topic,  String priority,  List<String> flags,  String language,  TicketCustomer? customer,  TicketOwner? owner,  bool isMine,  DateTime? queuedAt,  DateTime? createdAt,  DateTime? claimedAt,  DateTime? firstResponseAt,  DateTime? lastCustomerMessageAt,  DateTime? lastAgentMessageAt,  DateTime? resolvedAt,  DateTime? closedAt,  String? outcome,  String? resolutionSummary,  String? returnedReason,  DateTime? complaintReceivedAt,  DateTime? complaintDueAt,  int? rating,  String? ratingComment,  PendingTransfer? transfer,  String? preview,  int unreadCount,  DateTime? waitingSince,  List<String> tags,  List<TicketEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Ticket() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.status,_that.version,_that.topic,_that.priority,_that.flags,_that.language,_that.customer,_that.owner,_that.isMine,_that.queuedAt,_that.createdAt,_that.claimedAt,_that.firstResponseAt,_that.lastCustomerMessageAt,_that.lastAgentMessageAt,_that.resolvedAt,_that.closedAt,_that.outcome,_that.resolutionSummary,_that.returnedReason,_that.complaintReceivedAt,_that.complaintDueAt,_that.rating,_that.ratingComment,_that.transfer,_that.preview,_that.unreadCount,_that.waitingSince,_that.tags,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticketNumber,  String roomId, @JsonKey(unknownEnumValue: TicketStatus.closed)  TicketStatus status,  int version,  String topic,  String priority,  List<String> flags,  String language,  TicketCustomer? customer,  TicketOwner? owner,  bool isMine,  DateTime? queuedAt,  DateTime? createdAt,  DateTime? claimedAt,  DateTime? firstResponseAt,  DateTime? lastCustomerMessageAt,  DateTime? lastAgentMessageAt,  DateTime? resolvedAt,  DateTime? closedAt,  String? outcome,  String? resolutionSummary,  String? returnedReason,  DateTime? complaintReceivedAt,  DateTime? complaintDueAt,  int? rating,  String? ratingComment,  PendingTransfer? transfer,  String? preview,  int unreadCount,  DateTime? waitingSince,  List<String> tags,  List<TicketEvent> events)  $default,) {final _that = this;
switch (_that) {
case _Ticket():
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.status,_that.version,_that.topic,_that.priority,_that.flags,_that.language,_that.customer,_that.owner,_that.isMine,_that.queuedAt,_that.createdAt,_that.claimedAt,_that.firstResponseAt,_that.lastCustomerMessageAt,_that.lastAgentMessageAt,_that.resolvedAt,_that.closedAt,_that.outcome,_that.resolutionSummary,_that.returnedReason,_that.complaintReceivedAt,_that.complaintDueAt,_that.rating,_that.ratingComment,_that.transfer,_that.preview,_that.unreadCount,_that.waitingSince,_that.tags,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticketNumber,  String roomId, @JsonKey(unknownEnumValue: TicketStatus.closed)  TicketStatus status,  int version,  String topic,  String priority,  List<String> flags,  String language,  TicketCustomer? customer,  TicketOwner? owner,  bool isMine,  DateTime? queuedAt,  DateTime? createdAt,  DateTime? claimedAt,  DateTime? firstResponseAt,  DateTime? lastCustomerMessageAt,  DateTime? lastAgentMessageAt,  DateTime? resolvedAt,  DateTime? closedAt,  String? outcome,  String? resolutionSummary,  String? returnedReason,  DateTime? complaintReceivedAt,  DateTime? complaintDueAt,  int? rating,  String? ratingComment,  PendingTransfer? transfer,  String? preview,  int unreadCount,  DateTime? waitingSince,  List<String> tags,  List<TicketEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _Ticket() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.roomId,_that.status,_that.version,_that.topic,_that.priority,_that.flags,_that.language,_that.customer,_that.owner,_that.isMine,_that.queuedAt,_that.createdAt,_that.claimedAt,_that.firstResponseAt,_that.lastCustomerMessageAt,_that.lastAgentMessageAt,_that.resolvedAt,_that.closedAt,_that.outcome,_that.resolutionSummary,_that.returnedReason,_that.complaintReceivedAt,_that.complaintDueAt,_that.rating,_that.ratingComment,_that.transfer,_that.preview,_that.unreadCount,_that.waitingSince,_that.tags,_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Ticket extends Ticket {
  const _Ticket({required this.id, required this.ticketNumber, required this.roomId, @JsonKey(unknownEnumValue: TicketStatus.closed) required this.status, this.version = 1, required this.topic, this.priority = 'P3', final  List<String> flags = const <String>[], this.language = 'id', this.customer, this.owner, this.isMine = false, this.queuedAt, this.createdAt, this.claimedAt, this.firstResponseAt, this.lastCustomerMessageAt, this.lastAgentMessageAt, this.resolvedAt, this.closedAt, this.outcome, this.resolutionSummary, this.returnedReason, this.complaintReceivedAt, this.complaintDueAt, this.rating, this.ratingComment, this.transfer, this.preview, this.unreadCount = 0, this.waitingSince, final  List<String> tags = const <String>[], final  List<TicketEvent> events = const <TicketEvent>[]}): _flags = flags,_tags = tags,_events = events,super._();
  factory _Ticket.fromJson(Map<String, dynamic> json) => _$TicketFromJson(json);

@override final  String id;
@override final  String ticketNumber;
@override final  String roomId;
@override@JsonKey(unknownEnumValue: TicketStatus.closed) final  TicketStatus status;
@override@JsonKey() final  int version;
@override final  String topic;
@override@JsonKey() final  String priority;
 final  List<String> _flags;
@override@JsonKey() List<String> get flags {
  if (_flags is EqualUnmodifiableListView) return _flags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flags);
}

@override@JsonKey() final  String language;
@override final  TicketCustomer? customer;
@override final  TicketOwner? owner;
@override@JsonKey() final  bool isMine;
@override final  DateTime? queuedAt;
@override final  DateTime? createdAt;
@override final  DateTime? claimedAt;
@override final  DateTime? firstResponseAt;
@override final  DateTime? lastCustomerMessageAt;
@override final  DateTime? lastAgentMessageAt;
@override final  DateTime? resolvedAt;
@override final  DateTime? closedAt;
@override final  String? outcome;
@override final  String? resolutionSummary;
@override final  String? returnedReason;
@override final  DateTime? complaintReceivedAt;
@override final  DateTime? complaintDueAt;
@override final  int? rating;
@override final  String? ratingComment;
@override final  PendingTransfer? transfer;
@override final  String? preview;
@override@JsonKey() final  int unreadCount;
@override final  DateTime? waitingSince;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<TicketEvent> _events;
@override@JsonKey() List<TicketEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketCopyWith<_Ticket> get copyWith => __$TicketCopyWithImpl<_Ticket>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ticket&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other._flags, _flags)&&(identical(other.language, language) || other.language == language)&&(identical(other.customer, customer) || other.customer == customer)&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.queuedAt, queuedAt) || other.queuedAt == queuedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.firstResponseAt, firstResponseAt) || other.firstResponseAt == firstResponseAt)&&(identical(other.lastCustomerMessageAt, lastCustomerMessageAt) || other.lastCustomerMessageAt == lastCustomerMessageAt)&&(identical(other.lastAgentMessageAt, lastAgentMessageAt) || other.lastAgentMessageAt == lastAgentMessageAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.resolutionSummary, resolutionSummary) || other.resolutionSummary == resolutionSummary)&&(identical(other.returnedReason, returnedReason) || other.returnedReason == returnedReason)&&(identical(other.complaintReceivedAt, complaintReceivedAt) || other.complaintReceivedAt == complaintReceivedAt)&&(identical(other.complaintDueAt, complaintDueAt) || other.complaintDueAt == complaintDueAt)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratingComment, ratingComment) || other.ratingComment == ratingComment)&&(identical(other.transfer, transfer) || other.transfer == transfer)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.waitingSince, waitingSince) || other.waitingSince == waitingSince)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,ticketNumber,roomId,status,version,topic,priority,const DeepCollectionEquality().hash(_flags),language,customer,owner,isMine,queuedAt,createdAt,claimedAt,firstResponseAt,lastCustomerMessageAt,lastAgentMessageAt,resolvedAt,closedAt,outcome,resolutionSummary,returnedReason,complaintReceivedAt,complaintDueAt,rating,ratingComment,transfer,preview,unreadCount,waitingSince,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_events)]);

@override
String toString() {
  return 'Ticket(id: $id, ticketNumber: $ticketNumber, roomId: $roomId, status: $status, version: $version, topic: $topic, priority: $priority, flags: $flags, language: $language, customer: $customer, owner: $owner, isMine: $isMine, queuedAt: $queuedAt, createdAt: $createdAt, claimedAt: $claimedAt, firstResponseAt: $firstResponseAt, lastCustomerMessageAt: $lastCustomerMessageAt, lastAgentMessageAt: $lastAgentMessageAt, resolvedAt: $resolvedAt, closedAt: $closedAt, outcome: $outcome, resolutionSummary: $resolutionSummary, returnedReason: $returnedReason, complaintReceivedAt: $complaintReceivedAt, complaintDueAt: $complaintDueAt, rating: $rating, ratingComment: $ratingComment, transfer: $transfer, preview: $preview, unreadCount: $unreadCount, waitingSince: $waitingSince, tags: $tags, events: $events)';
}


}

/// @nodoc
abstract mixin class _$TicketCopyWith<$Res> implements $TicketCopyWith<$Res> {
  factory _$TicketCopyWith(_Ticket value, $Res Function(_Ticket) _then) = __$TicketCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticketNumber, String roomId,@JsonKey(unknownEnumValue: TicketStatus.closed) TicketStatus status, int version, String topic, String priority, List<String> flags, String language, TicketCustomer? customer, TicketOwner? owner, bool isMine, DateTime? queuedAt, DateTime? createdAt, DateTime? claimedAt, DateTime? firstResponseAt, DateTime? lastCustomerMessageAt, DateTime? lastAgentMessageAt, DateTime? resolvedAt, DateTime? closedAt, String? outcome, String? resolutionSummary, String? returnedReason, DateTime? complaintReceivedAt, DateTime? complaintDueAt, int? rating, String? ratingComment, PendingTransfer? transfer, String? preview, int unreadCount, DateTime? waitingSince, List<String> tags, List<TicketEvent> events
});


@override $TicketCustomerCopyWith<$Res>? get customer;@override $TicketOwnerCopyWith<$Res>? get owner;@override $PendingTransferCopyWith<$Res>? get transfer;

}
/// @nodoc
class __$TicketCopyWithImpl<$Res>
    implements _$TicketCopyWith<$Res> {
  __$TicketCopyWithImpl(this._self, this._then);

  final _Ticket _self;
  final $Res Function(_Ticket) _then;

/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketNumber = null,Object? roomId = null,Object? status = null,Object? version = null,Object? topic = null,Object? priority = null,Object? flags = null,Object? language = null,Object? customer = freezed,Object? owner = freezed,Object? isMine = null,Object? queuedAt = freezed,Object? createdAt = freezed,Object? claimedAt = freezed,Object? firstResponseAt = freezed,Object? lastCustomerMessageAt = freezed,Object? lastAgentMessageAt = freezed,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? outcome = freezed,Object? resolutionSummary = freezed,Object? returnedReason = freezed,Object? complaintReceivedAt = freezed,Object? complaintDueAt = freezed,Object? rating = freezed,Object? ratingComment = freezed,Object? transfer = freezed,Object? preview = freezed,Object? unreadCount = null,Object? waitingSince = freezed,Object? tags = null,Object? events = null,}) {
  return _then(_Ticket(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: null == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TicketStatus,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,flags: null == flags ? _self._flags : flags // ignore: cast_nullable_to_non_nullable
as List<String>,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,customer: freezed == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as TicketCustomer?,owner: freezed == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TicketOwner?,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,queuedAt: freezed == queuedAt ? _self.queuedAt : queuedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,firstResponseAt: freezed == firstResponseAt ? _self.firstResponseAt : firstResponseAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastCustomerMessageAt: freezed == lastCustomerMessageAt ? _self.lastCustomerMessageAt : lastCustomerMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastAgentMessageAt: freezed == lastAgentMessageAt ? _self.lastAgentMessageAt : lastAgentMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String?,resolutionSummary: freezed == resolutionSummary ? _self.resolutionSummary : resolutionSummary // ignore: cast_nullable_to_non_nullable
as String?,returnedReason: freezed == returnedReason ? _self.returnedReason : returnedReason // ignore: cast_nullable_to_non_nullable
as String?,complaintReceivedAt: freezed == complaintReceivedAt ? _self.complaintReceivedAt : complaintReceivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,complaintDueAt: freezed == complaintDueAt ? _self.complaintDueAt : complaintDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,ratingComment: freezed == ratingComment ? _self.ratingComment : ratingComment // ignore: cast_nullable_to_non_nullable
as String?,transfer: freezed == transfer ? _self.transfer : transfer // ignore: cast_nullable_to_non_nullable
as PendingTransfer?,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,waitingSince: freezed == waitingSince ? _self.waitingSince : waitingSince // ignore: cast_nullable_to_non_nullable
as DateTime?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<TicketEvent>,
  ));
}

/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketCustomerCopyWith<$Res>? get customer {
    if (_self.customer == null) {
    return null;
  }

  return $TicketCustomerCopyWith<$Res>(_self.customer!, (value) {
    return _then(_self.copyWith(customer: value));
  });
}/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketOwnerCopyWith<$Res>? get owner {
    if (_self.owner == null) {
    return null;
  }

  return $TicketOwnerCopyWith<$Res>(_self.owner!, (value) {
    return _then(_self.copyWith(owner: value));
  });
}/// Create a copy of Ticket
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingTransferCopyWith<$Res>? get transfer {
    if (_self.transfer == null) {
    return null;
  }

  return $PendingTransferCopyWith<$Res>(_self.transfer!, (value) {
    return _then(_self.copyWith(transfer: value));
  });
}
}


/// @nodoc
mixin _$TransferRequest {

 String get id; String? get note; DateTime? get expiresAt; String? get fromName; Ticket get ticket;
/// Create a copy of TransferRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferRequestCopyWith<TransferRequest> get copyWith => _$TransferRequestCopyWithImpl<TransferRequest>(this as TransferRequest, _$identity);

  /// Serializes this TransferRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.note, note) || other.note == note)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.fromName, fromName) || other.fromName == fromName)&&(identical(other.ticket, ticket) || other.ticket == ticket));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,note,expiresAt,fromName,ticket);

@override
String toString() {
  return 'TransferRequest(id: $id, note: $note, expiresAt: $expiresAt, fromName: $fromName, ticket: $ticket)';
}


}

/// @nodoc
abstract mixin class $TransferRequestCopyWith<$Res>  {
  factory $TransferRequestCopyWith(TransferRequest value, $Res Function(TransferRequest) _then) = _$TransferRequestCopyWithImpl;
@useResult
$Res call({
 String id, String? note, DateTime? expiresAt, String? fromName, Ticket ticket
});


$TicketCopyWith<$Res> get ticket;

}
/// @nodoc
class _$TransferRequestCopyWithImpl<$Res>
    implements $TransferRequestCopyWith<$Res> {
  _$TransferRequestCopyWithImpl(this._self, this._then);

  final TransferRequest _self;
  final $Res Function(TransferRequest) _then;

/// Create a copy of TransferRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? note = freezed,Object? expiresAt = freezed,Object? fromName = freezed,Object? ticket = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,fromName: freezed == fromName ? _self.fromName : fromName // ignore: cast_nullable_to_non_nullable
as String?,ticket: null == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as Ticket,
  ));
}
/// Create a copy of TransferRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketCopyWith<$Res> get ticket {
  
  return $TicketCopyWith<$Res>(_self.ticket, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// Adds pattern-matching-related methods to [TransferRequest].
extension TransferRequestPatterns on TransferRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransferRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransferRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransferRequest value)  $default,){
final _that = this;
switch (_that) {
case _TransferRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransferRequest value)?  $default,){
final _that = this;
switch (_that) {
case _TransferRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? note,  DateTime? expiresAt,  String? fromName,  Ticket ticket)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransferRequest() when $default != null:
return $default(_that.id,_that.note,_that.expiresAt,_that.fromName,_that.ticket);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? note,  DateTime? expiresAt,  String? fromName,  Ticket ticket)  $default,) {final _that = this;
switch (_that) {
case _TransferRequest():
return $default(_that.id,_that.note,_that.expiresAt,_that.fromName,_that.ticket);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? note,  DateTime? expiresAt,  String? fromName,  Ticket ticket)?  $default,) {final _that = this;
switch (_that) {
case _TransferRequest() when $default != null:
return $default(_that.id,_that.note,_that.expiresAt,_that.fromName,_that.ticket);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransferRequest implements TransferRequest {
  const _TransferRequest({required this.id, this.note, this.expiresAt, this.fromName, required this.ticket});
  factory _TransferRequest.fromJson(Map<String, dynamic> json) => _$TransferRequestFromJson(json);

@override final  String id;
@override final  String? note;
@override final  DateTime? expiresAt;
@override final  String? fromName;
@override final  Ticket ticket;

/// Create a copy of TransferRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransferRequestCopyWith<_TransferRequest> get copyWith => __$TransferRequestCopyWithImpl<_TransferRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransferRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransferRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.note, note) || other.note == note)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.fromName, fromName) || other.fromName == fromName)&&(identical(other.ticket, ticket) || other.ticket == ticket));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,note,expiresAt,fromName,ticket);

@override
String toString() {
  return 'TransferRequest(id: $id, note: $note, expiresAt: $expiresAt, fromName: $fromName, ticket: $ticket)';
}


}

/// @nodoc
abstract mixin class _$TransferRequestCopyWith<$Res> implements $TransferRequestCopyWith<$Res> {
  factory _$TransferRequestCopyWith(_TransferRequest value, $Res Function(_TransferRequest) _then) = __$TransferRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, String? note, DateTime? expiresAt, String? fromName, Ticket ticket
});


@override $TicketCopyWith<$Res> get ticket;

}
/// @nodoc
class __$TransferRequestCopyWithImpl<$Res>
    implements _$TransferRequestCopyWith<$Res> {
  __$TransferRequestCopyWithImpl(this._self, this._then);

  final _TransferRequest _self;
  final $Res Function(_TransferRequest) _then;

/// Create a copy of TransferRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? note = freezed,Object? expiresAt = freezed,Object? fromName = freezed,Object? ticket = null,}) {
  return _then(_TransferRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,fromName: freezed == fromName ? _self.fromName : fromName // ignore: cast_nullable_to_non_nullable
as String?,ticket: null == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as Ticket,
  ));
}

/// Create a copy of TransferRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketCopyWith<$Res> get ticket {
  
  return $TicketCopyWith<$Res>(_self.ticket, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// @nodoc
mixin _$OutgoingTransfer {

 String get id; String get ticketId; DateTime? get expiresAt; String? get toName;
/// Create a copy of OutgoingTransfer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutgoingTransferCopyWith<OutgoingTransfer> get copyWith => _$OutgoingTransferCopyWithImpl<OutgoingTransfer>(this as OutgoingTransfer, _$identity);

  /// Serializes this OutgoingTransfer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutgoingTransfer&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.toName, toName) || other.toName == toName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,expiresAt,toName);

@override
String toString() {
  return 'OutgoingTransfer(id: $id, ticketId: $ticketId, expiresAt: $expiresAt, toName: $toName)';
}


}

/// @nodoc
abstract mixin class $OutgoingTransferCopyWith<$Res>  {
  factory $OutgoingTransferCopyWith(OutgoingTransfer value, $Res Function(OutgoingTransfer) _then) = _$OutgoingTransferCopyWithImpl;
@useResult
$Res call({
 String id, String ticketId, DateTime? expiresAt, String? toName
});




}
/// @nodoc
class _$OutgoingTransferCopyWithImpl<$Res>
    implements $OutgoingTransferCopyWith<$Res> {
  _$OutgoingTransferCopyWithImpl(this._self, this._then);

  final OutgoingTransfer _self;
  final $Res Function(OutgoingTransfer) _then;

/// Create a copy of OutgoingTransfer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketId = null,Object? expiresAt = freezed,Object? toName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: null == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,toName: freezed == toName ? _self.toName : toName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OutgoingTransfer].
extension OutgoingTransferPatterns on OutgoingTransfer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OutgoingTransfer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OutgoingTransfer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OutgoingTransfer value)  $default,){
final _that = this;
switch (_that) {
case _OutgoingTransfer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OutgoingTransfer value)?  $default,){
final _that = this;
switch (_that) {
case _OutgoingTransfer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticketId,  DateTime? expiresAt,  String? toName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OutgoingTransfer() when $default != null:
return $default(_that.id,_that.ticketId,_that.expiresAt,_that.toName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticketId,  DateTime? expiresAt,  String? toName)  $default,) {final _that = this;
switch (_that) {
case _OutgoingTransfer():
return $default(_that.id,_that.ticketId,_that.expiresAt,_that.toName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticketId,  DateTime? expiresAt,  String? toName)?  $default,) {final _that = this;
switch (_that) {
case _OutgoingTransfer() when $default != null:
return $default(_that.id,_that.ticketId,_that.expiresAt,_that.toName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OutgoingTransfer implements OutgoingTransfer {
  const _OutgoingTransfer({required this.id, required this.ticketId, this.expiresAt, this.toName});
  factory _OutgoingTransfer.fromJson(Map<String, dynamic> json) => _$OutgoingTransferFromJson(json);

@override final  String id;
@override final  String ticketId;
@override final  DateTime? expiresAt;
@override final  String? toName;

/// Create a copy of OutgoingTransfer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OutgoingTransferCopyWith<_OutgoingTransfer> get copyWith => __$OutgoingTransferCopyWithImpl<_OutgoingTransfer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OutgoingTransferToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OutgoingTransfer&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.toName, toName) || other.toName == toName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,expiresAt,toName);

@override
String toString() {
  return 'OutgoingTransfer(id: $id, ticketId: $ticketId, expiresAt: $expiresAt, toName: $toName)';
}


}

/// @nodoc
abstract mixin class _$OutgoingTransferCopyWith<$Res> implements $OutgoingTransferCopyWith<$Res> {
  factory _$OutgoingTransferCopyWith(_OutgoingTransfer value, $Res Function(_OutgoingTransfer) _then) = __$OutgoingTransferCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticketId, DateTime? expiresAt, String? toName
});




}
/// @nodoc
class __$OutgoingTransferCopyWithImpl<$Res>
    implements _$OutgoingTransferCopyWith<$Res> {
  __$OutgoingTransferCopyWithImpl(this._self, this._then);

  final _OutgoingTransfer _self;
  final $Res Function(_OutgoingTransfer) _then;

/// Create a copy of OutgoingTransfer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketId = null,Object? expiresAt = freezed,Object? toName = freezed,}) {
  return _then(_OutgoingTransfer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: null == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,toName: freezed == toName ? _self.toName : toName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TicketLists {

 List<Ticket> get open; List<Ticket> get mine; List<Ticket> get resolvedToday; List<Ticket> get allActive; List<TransferRequest> get transfersIn; List<OutgoingTransfer> get transfersOut;
/// Create a copy of TicketLists
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketListsCopyWith<TicketLists> get copyWith => _$TicketListsCopyWithImpl<TicketLists>(this as TicketLists, _$identity);

  /// Serializes this TicketLists to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketLists&&const DeepCollectionEquality().equals(other.open, open)&&const DeepCollectionEquality().equals(other.mine, mine)&&const DeepCollectionEquality().equals(other.resolvedToday, resolvedToday)&&const DeepCollectionEquality().equals(other.allActive, allActive)&&const DeepCollectionEquality().equals(other.transfersIn, transfersIn)&&const DeepCollectionEquality().equals(other.transfersOut, transfersOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(open),const DeepCollectionEquality().hash(mine),const DeepCollectionEquality().hash(resolvedToday),const DeepCollectionEquality().hash(allActive),const DeepCollectionEquality().hash(transfersIn),const DeepCollectionEquality().hash(transfersOut));

@override
String toString() {
  return 'TicketLists(open: $open, mine: $mine, resolvedToday: $resolvedToday, allActive: $allActive, transfersIn: $transfersIn, transfersOut: $transfersOut)';
}


}

/// @nodoc
abstract mixin class $TicketListsCopyWith<$Res>  {
  factory $TicketListsCopyWith(TicketLists value, $Res Function(TicketLists) _then) = _$TicketListsCopyWithImpl;
@useResult
$Res call({
 List<Ticket> open, List<Ticket> mine, List<Ticket> resolvedToday, List<Ticket> allActive, List<TransferRequest> transfersIn, List<OutgoingTransfer> transfersOut
});




}
/// @nodoc
class _$TicketListsCopyWithImpl<$Res>
    implements $TicketListsCopyWith<$Res> {
  _$TicketListsCopyWithImpl(this._self, this._then);

  final TicketLists _self;
  final $Res Function(TicketLists) _then;

/// Create a copy of TicketLists
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? open = null,Object? mine = null,Object? resolvedToday = null,Object? allActive = null,Object? transfersIn = null,Object? transfersOut = null,}) {
  return _then(_self.copyWith(
open: null == open ? _self.open : open // ignore: cast_nullable_to_non_nullable
as List<Ticket>,mine: null == mine ? _self.mine : mine // ignore: cast_nullable_to_non_nullable
as List<Ticket>,resolvedToday: null == resolvedToday ? _self.resolvedToday : resolvedToday // ignore: cast_nullable_to_non_nullable
as List<Ticket>,allActive: null == allActive ? _self.allActive : allActive // ignore: cast_nullable_to_non_nullable
as List<Ticket>,transfersIn: null == transfersIn ? _self.transfersIn : transfersIn // ignore: cast_nullable_to_non_nullable
as List<TransferRequest>,transfersOut: null == transfersOut ? _self.transfersOut : transfersOut // ignore: cast_nullable_to_non_nullable
as List<OutgoingTransfer>,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketLists].
extension TicketListsPatterns on TicketLists {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketLists value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketLists() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketLists value)  $default,){
final _that = this;
switch (_that) {
case _TicketLists():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketLists value)?  $default,){
final _that = this;
switch (_that) {
case _TicketLists() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Ticket> open,  List<Ticket> mine,  List<Ticket> resolvedToday,  List<Ticket> allActive,  List<TransferRequest> transfersIn,  List<OutgoingTransfer> transfersOut)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketLists() when $default != null:
return $default(_that.open,_that.mine,_that.resolvedToday,_that.allActive,_that.transfersIn,_that.transfersOut);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Ticket> open,  List<Ticket> mine,  List<Ticket> resolvedToday,  List<Ticket> allActive,  List<TransferRequest> transfersIn,  List<OutgoingTransfer> transfersOut)  $default,) {final _that = this;
switch (_that) {
case _TicketLists():
return $default(_that.open,_that.mine,_that.resolvedToday,_that.allActive,_that.transfersIn,_that.transfersOut);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Ticket> open,  List<Ticket> mine,  List<Ticket> resolvedToday,  List<Ticket> allActive,  List<TransferRequest> transfersIn,  List<OutgoingTransfer> transfersOut)?  $default,) {final _that = this;
switch (_that) {
case _TicketLists() when $default != null:
return $default(_that.open,_that.mine,_that.resolvedToday,_that.allActive,_that.transfersIn,_that.transfersOut);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketLists implements TicketLists {
  const _TicketLists({final  List<Ticket> open = const <Ticket>[], final  List<Ticket> mine = const <Ticket>[], final  List<Ticket> resolvedToday = const <Ticket>[], final  List<Ticket> allActive = const <Ticket>[], final  List<TransferRequest> transfersIn = const <TransferRequest>[], final  List<OutgoingTransfer> transfersOut = const <OutgoingTransfer>[]}): _open = open,_mine = mine,_resolvedToday = resolvedToday,_allActive = allActive,_transfersIn = transfersIn,_transfersOut = transfersOut;
  factory _TicketLists.fromJson(Map<String, dynamic> json) => _$TicketListsFromJson(json);

 final  List<Ticket> _open;
@override@JsonKey() List<Ticket> get open {
  if (_open is EqualUnmodifiableListView) return _open;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_open);
}

 final  List<Ticket> _mine;
@override@JsonKey() List<Ticket> get mine {
  if (_mine is EqualUnmodifiableListView) return _mine;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mine);
}

 final  List<Ticket> _resolvedToday;
@override@JsonKey() List<Ticket> get resolvedToday {
  if (_resolvedToday is EqualUnmodifiableListView) return _resolvedToday;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_resolvedToday);
}

 final  List<Ticket> _allActive;
@override@JsonKey() List<Ticket> get allActive {
  if (_allActive is EqualUnmodifiableListView) return _allActive;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allActive);
}

 final  List<TransferRequest> _transfersIn;
@override@JsonKey() List<TransferRequest> get transfersIn {
  if (_transfersIn is EqualUnmodifiableListView) return _transfersIn;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transfersIn);
}

 final  List<OutgoingTransfer> _transfersOut;
@override@JsonKey() List<OutgoingTransfer> get transfersOut {
  if (_transfersOut is EqualUnmodifiableListView) return _transfersOut;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transfersOut);
}


/// Create a copy of TicketLists
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketListsCopyWith<_TicketLists> get copyWith => __$TicketListsCopyWithImpl<_TicketLists>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketListsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketLists&&const DeepCollectionEquality().equals(other._open, _open)&&const DeepCollectionEquality().equals(other._mine, _mine)&&const DeepCollectionEquality().equals(other._resolvedToday, _resolvedToday)&&const DeepCollectionEquality().equals(other._allActive, _allActive)&&const DeepCollectionEquality().equals(other._transfersIn, _transfersIn)&&const DeepCollectionEquality().equals(other._transfersOut, _transfersOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_open),const DeepCollectionEquality().hash(_mine),const DeepCollectionEquality().hash(_resolvedToday),const DeepCollectionEquality().hash(_allActive),const DeepCollectionEquality().hash(_transfersIn),const DeepCollectionEquality().hash(_transfersOut));

@override
String toString() {
  return 'TicketLists(open: $open, mine: $mine, resolvedToday: $resolvedToday, allActive: $allActive, transfersIn: $transfersIn, transfersOut: $transfersOut)';
}


}

/// @nodoc
abstract mixin class _$TicketListsCopyWith<$Res> implements $TicketListsCopyWith<$Res> {
  factory _$TicketListsCopyWith(_TicketLists value, $Res Function(_TicketLists) _then) = __$TicketListsCopyWithImpl;
@override @useResult
$Res call({
 List<Ticket> open, List<Ticket> mine, List<Ticket> resolvedToday, List<Ticket> allActive, List<TransferRequest> transfersIn, List<OutgoingTransfer> transfersOut
});




}
/// @nodoc
class __$TicketListsCopyWithImpl<$Res>
    implements _$TicketListsCopyWith<$Res> {
  __$TicketListsCopyWithImpl(this._self, this._then);

  final _TicketLists _self;
  final $Res Function(_TicketLists) _then;

/// Create a copy of TicketLists
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? open = null,Object? mine = null,Object? resolvedToday = null,Object? allActive = null,Object? transfersIn = null,Object? transfersOut = null,}) {
  return _then(_TicketLists(
open: null == open ? _self._open : open // ignore: cast_nullable_to_non_nullable
as List<Ticket>,mine: null == mine ? _self._mine : mine // ignore: cast_nullable_to_non_nullable
as List<Ticket>,resolvedToday: null == resolvedToday ? _self._resolvedToday : resolvedToday // ignore: cast_nullable_to_non_nullable
as List<Ticket>,allActive: null == allActive ? _self._allActive : allActive // ignore: cast_nullable_to_non_nullable
as List<Ticket>,transfersIn: null == transfersIn ? _self._transfersIn : transfersIn // ignore: cast_nullable_to_non_nullable
as List<TransferRequest>,transfersOut: null == transfersOut ? _self._transfersOut : transfersOut // ignore: cast_nullable_to_non_nullable
as List<OutgoingTransfer>,
  ));
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

  /// Serializes this SupportTopic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTopic&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.helpUrl, helpUrl) || other.helpUrl == helpUrl)&&(identical(other.urgent, urgent) || other.urgent == urgent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
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
@JsonSerializable()

class _SupportTopic implements SupportTopic {
  const _SupportTopic({required this.code, required this.name, this.helpUrl, this.urgent = false});
  factory _SupportTopic.fromJson(Map<String, dynamic> json) => _$SupportTopicFromJson(json);

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
Map<String, dynamic> toJson() {
  return _$SupportTopicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTopic&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.helpUrl, helpUrl) || other.helpUrl == helpUrl)&&(identical(other.urgent, urgent) || other.urgent == urgent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
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
mixin _$QuickReply {

 String get id; String get scope; String get shortcut; String get title; String get body;
/// Create a copy of QuickReply
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuickReplyCopyWith<QuickReply> get copyWith => _$QuickReplyCopyWithImpl<QuickReply>(this as QuickReply, _$identity);

  /// Serializes this QuickReply to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuickReply&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.shortcut, shortcut) || other.shortcut == shortcut)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,scope,shortcut,title,body);

@override
String toString() {
  return 'QuickReply(id: $id, scope: $scope, shortcut: $shortcut, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $QuickReplyCopyWith<$Res>  {
  factory $QuickReplyCopyWith(QuickReply value, $Res Function(QuickReply) _then) = _$QuickReplyCopyWithImpl;
@useResult
$Res call({
 String id, String scope, String shortcut, String title, String body
});




}
/// @nodoc
class _$QuickReplyCopyWithImpl<$Res>
    implements $QuickReplyCopyWith<$Res> {
  _$QuickReplyCopyWithImpl(this._self, this._then);

  final QuickReply _self;
  final $Res Function(QuickReply) _then;

/// Create a copy of QuickReply
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scope = null,Object? shortcut = null,Object? title = null,Object? body = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,shortcut: null == shortcut ? _self.shortcut : shortcut // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [QuickReply].
extension QuickReplyPatterns on QuickReply {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuickReply value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuickReply() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuickReply value)  $default,){
final _that = this;
switch (_that) {
case _QuickReply():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuickReply value)?  $default,){
final _that = this;
switch (_that) {
case _QuickReply() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String scope,  String shortcut,  String title,  String body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuickReply() when $default != null:
return $default(_that.id,_that.scope,_that.shortcut,_that.title,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String scope,  String shortcut,  String title,  String body)  $default,) {final _that = this;
switch (_that) {
case _QuickReply():
return $default(_that.id,_that.scope,_that.shortcut,_that.title,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String scope,  String shortcut,  String title,  String body)?  $default,) {final _that = this;
switch (_that) {
case _QuickReply() when $default != null:
return $default(_that.id,_that.scope,_that.shortcut,_that.title,_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuickReply extends QuickReply {
  const _QuickReply({required this.id, this.scope = 'global', required this.shortcut, required this.title, required this.body}): super._();
  factory _QuickReply.fromJson(Map<String, dynamic> json) => _$QuickReplyFromJson(json);

@override final  String id;
@override@JsonKey() final  String scope;
@override final  String shortcut;
@override final  String title;
@override final  String body;

/// Create a copy of QuickReply
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuickReplyCopyWith<_QuickReply> get copyWith => __$QuickReplyCopyWithImpl<_QuickReply>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuickReplyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuickReply&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.shortcut, shortcut) || other.shortcut == shortcut)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,scope,shortcut,title,body);

@override
String toString() {
  return 'QuickReply(id: $id, scope: $scope, shortcut: $shortcut, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class _$QuickReplyCopyWith<$Res> implements $QuickReplyCopyWith<$Res> {
  factory _$QuickReplyCopyWith(_QuickReply value, $Res Function(_QuickReply) _then) = __$QuickReplyCopyWithImpl;
@override @useResult
$Res call({
 String id, String scope, String shortcut, String title, String body
});




}
/// @nodoc
class __$QuickReplyCopyWithImpl<$Res>
    implements _$QuickReplyCopyWith<$Res> {
  __$QuickReplyCopyWithImpl(this._self, this._then);

  final _QuickReply _self;
  final $Res Function(_QuickReply) _then;

/// Create a copy of QuickReply
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scope = null,Object? shortcut = null,Object? title = null,Object? body = null,}) {
  return _then(_QuickReply(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,shortcut: null == shortcut ? _self.shortcut : shortcut // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
