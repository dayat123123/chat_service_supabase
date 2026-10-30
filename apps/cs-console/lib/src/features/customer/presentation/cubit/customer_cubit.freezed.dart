// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'customer_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CustomerState {

 bool get canViewData; Section<Map<String, dynamic>> get profile; Section<List<Map<String, dynamic>>> get orders; Section<List<Map<String, dynamic>>> get cash; Section<Map<String, dynamic>> get devices; Section<Map<String, dynamic>> get security; Section<List<TicketHistoryItem>> get history; Section<List<AgentNote>> get notes; Map<String, RevealedField> get revealed; bool get securing; Object? get actionError; int get actionErrorId;
/// Create a copy of CustomerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerStateCopyWith<CustomerState> get copyWith => _$CustomerStateCopyWithImpl<CustomerState>(this as CustomerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerState&&(identical(other.canViewData, canViewData) || other.canViewData == canViewData)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.orders, orders) || other.orders == orders)&&(identical(other.cash, cash) || other.cash == cash)&&(identical(other.devices, devices) || other.devices == devices)&&(identical(other.security, security) || other.security == security)&&(identical(other.history, history) || other.history == history)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.revealed, revealed)&&(identical(other.securing, securing) || other.securing == securing)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,canViewData,profile,orders,cash,devices,security,history,notes,const DeepCollectionEquality().hash(revealed),securing,const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'CustomerState(canViewData: $canViewData, profile: $profile, orders: $orders, cash: $cash, devices: $devices, security: $security, history: $history, notes: $notes, revealed: $revealed, securing: $securing, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $CustomerStateCopyWith<$Res>  {
  factory $CustomerStateCopyWith(CustomerState value, $Res Function(CustomerState) _then) = _$CustomerStateCopyWithImpl;
@useResult
$Res call({
 bool canViewData, Section<Map<String, dynamic>> profile, Section<List<Map<String, dynamic>>> orders, Section<List<Map<String, dynamic>>> cash, Section<Map<String, dynamic>> devices, Section<Map<String, dynamic>> security, Section<List<TicketHistoryItem>> history, Section<List<AgentNote>> notes, Map<String, RevealedField> revealed, bool securing, Object? actionError, int actionErrorId
});




}
/// @nodoc
class _$CustomerStateCopyWithImpl<$Res>
    implements $CustomerStateCopyWith<$Res> {
  _$CustomerStateCopyWithImpl(this._self, this._then);

  final CustomerState _self;
  final $Res Function(CustomerState) _then;

/// Create a copy of CustomerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? canViewData = null,Object? profile = null,Object? orders = null,Object? cash = null,Object? devices = null,Object? security = null,Object? history = null,Object? notes = null,Object? revealed = null,Object? securing = null,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
canViewData: null == canViewData ? _self.canViewData : canViewData // ignore: cast_nullable_to_non_nullable
as bool,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as Section<Map<String, dynamic>>,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as Section<List<Map<String, dynamic>>>,cash: null == cash ? _self.cash : cash // ignore: cast_nullable_to_non_nullable
as Section<List<Map<String, dynamic>>>,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as Section<Map<String, dynamic>>,security: null == security ? _self.security : security // ignore: cast_nullable_to_non_nullable
as Section<Map<String, dynamic>>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as Section<List<TicketHistoryItem>>,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as Section<List<AgentNote>>,revealed: null == revealed ? _self.revealed : revealed // ignore: cast_nullable_to_non_nullable
as Map<String, RevealedField>,securing: null == securing ? _self.securing : securing // ignore: cast_nullable_to_non_nullable
as bool,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomerState].
extension CustomerStatePatterns on CustomerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerState value)  $default,){
final _that = this;
switch (_that) {
case _CustomerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerState value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool canViewData,  Section<Map<String, dynamic>> profile,  Section<List<Map<String, dynamic>>> orders,  Section<List<Map<String, dynamic>>> cash,  Section<Map<String, dynamic>> devices,  Section<Map<String, dynamic>> security,  Section<List<TicketHistoryItem>> history,  Section<List<AgentNote>> notes,  Map<String, RevealedField> revealed,  bool securing,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerState() when $default != null:
return $default(_that.canViewData,_that.profile,_that.orders,_that.cash,_that.devices,_that.security,_that.history,_that.notes,_that.revealed,_that.securing,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool canViewData,  Section<Map<String, dynamic>> profile,  Section<List<Map<String, dynamic>>> orders,  Section<List<Map<String, dynamic>>> cash,  Section<Map<String, dynamic>> devices,  Section<Map<String, dynamic>> security,  Section<List<TicketHistoryItem>> history,  Section<List<AgentNote>> notes,  Map<String, RevealedField> revealed,  bool securing,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _CustomerState():
return $default(_that.canViewData,_that.profile,_that.orders,_that.cash,_that.devices,_that.security,_that.history,_that.notes,_that.revealed,_that.securing,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool canViewData,  Section<Map<String, dynamic>> profile,  Section<List<Map<String, dynamic>>> orders,  Section<List<Map<String, dynamic>>> cash,  Section<Map<String, dynamic>> devices,  Section<Map<String, dynamic>> security,  Section<List<TicketHistoryItem>> history,  Section<List<AgentNote>> notes,  Map<String, RevealedField> revealed,  bool securing,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _CustomerState() when $default != null:
return $default(_that.canViewData,_that.profile,_that.orders,_that.cash,_that.devices,_that.security,_that.history,_that.notes,_that.revealed,_that.securing,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _CustomerState implements CustomerState {
  const _CustomerState({this.canViewData = false, this.profile = const Section<Map<String, dynamic>>(), this.orders = const Section<List<Map<String, dynamic>>>(), this.cash = const Section<List<Map<String, dynamic>>>(), this.devices = const Section<Map<String, dynamic>>(), this.security = const Section<Map<String, dynamic>>(), this.history = const Section<List<TicketHistoryItem>>(), this.notes = const Section<List<AgentNote>>(), final  Map<String, RevealedField> revealed = const <String, RevealedField>{}, this.securing = false, this.actionError, this.actionErrorId = 0}): _revealed = revealed;
  

@override@JsonKey() final  bool canViewData;
@override@JsonKey() final  Section<Map<String, dynamic>> profile;
@override@JsonKey() final  Section<List<Map<String, dynamic>>> orders;
@override@JsonKey() final  Section<List<Map<String, dynamic>>> cash;
@override@JsonKey() final  Section<Map<String, dynamic>> devices;
@override@JsonKey() final  Section<Map<String, dynamic>> security;
@override@JsonKey() final  Section<List<TicketHistoryItem>> history;
@override@JsonKey() final  Section<List<AgentNote>> notes;
 final  Map<String, RevealedField> _revealed;
@override@JsonKey() Map<String, RevealedField> get revealed {
  if (_revealed is EqualUnmodifiableMapView) return _revealed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_revealed);
}

@override@JsonKey() final  bool securing;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of CustomerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerStateCopyWith<_CustomerState> get copyWith => __$CustomerStateCopyWithImpl<_CustomerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerState&&(identical(other.canViewData, canViewData) || other.canViewData == canViewData)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.orders, orders) || other.orders == orders)&&(identical(other.cash, cash) || other.cash == cash)&&(identical(other.devices, devices) || other.devices == devices)&&(identical(other.security, security) || other.security == security)&&(identical(other.history, history) || other.history == history)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other._revealed, _revealed)&&(identical(other.securing, securing) || other.securing == securing)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,canViewData,profile,orders,cash,devices,security,history,notes,const DeepCollectionEquality().hash(_revealed),securing,const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'CustomerState(canViewData: $canViewData, profile: $profile, orders: $orders, cash: $cash, devices: $devices, security: $security, history: $history, notes: $notes, revealed: $revealed, securing: $securing, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$CustomerStateCopyWith<$Res> implements $CustomerStateCopyWith<$Res> {
  factory _$CustomerStateCopyWith(_CustomerState value, $Res Function(_CustomerState) _then) = __$CustomerStateCopyWithImpl;
@override @useResult
$Res call({
 bool canViewData, Section<Map<String, dynamic>> profile, Section<List<Map<String, dynamic>>> orders, Section<List<Map<String, dynamic>>> cash, Section<Map<String, dynamic>> devices, Section<Map<String, dynamic>> security, Section<List<TicketHistoryItem>> history, Section<List<AgentNote>> notes, Map<String, RevealedField> revealed, bool securing, Object? actionError, int actionErrorId
});




}
/// @nodoc
class __$CustomerStateCopyWithImpl<$Res>
    implements _$CustomerStateCopyWith<$Res> {
  __$CustomerStateCopyWithImpl(this._self, this._then);

  final _CustomerState _self;
  final $Res Function(_CustomerState) _then;

/// Create a copy of CustomerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? canViewData = null,Object? profile = null,Object? orders = null,Object? cash = null,Object? devices = null,Object? security = null,Object? history = null,Object? notes = null,Object? revealed = null,Object? securing = null,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_CustomerState(
canViewData: null == canViewData ? _self.canViewData : canViewData // ignore: cast_nullable_to_non_nullable
as bool,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as Section<Map<String, dynamic>>,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as Section<List<Map<String, dynamic>>>,cash: null == cash ? _self.cash : cash // ignore: cast_nullable_to_non_nullable
as Section<List<Map<String, dynamic>>>,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as Section<Map<String, dynamic>>,security: null == security ? _self.security : security // ignore: cast_nullable_to_non_nullable
as Section<Map<String, dynamic>>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as Section<List<TicketHistoryItem>>,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as Section<List<AgentNote>>,revealed: null == revealed ? _self._revealed : revealed // ignore: cast_nullable_to_non_nullable
as Map<String, RevealedField>,securing: null == securing ? _self.securing : securing // ignore: cast_nullable_to_non_nullable
as bool,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
