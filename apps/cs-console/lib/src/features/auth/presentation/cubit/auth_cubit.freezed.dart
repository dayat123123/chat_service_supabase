// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthState()';
}


}

/// @nodoc
class $AuthStateCopyWith<$Res>  {
$AuthStateCopyWith(AuthState _, $Res Function(AuthState) __);
}


/// Adds pattern-matching-related methods to [AuthState].
extension AuthStatePatterns on AuthState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AuthChecking value)?  checking,TResult Function( AuthSignedOut value)?  signedOut,TResult Function( AuthTotp value)?  totp,TResult Function( AuthEnroll value)?  enroll,TResult Function( AuthPassword value)?  password,TResult Function( AuthReady value)?  ready,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AuthChecking() when checking != null:
return checking(_that);case AuthSignedOut() when signedOut != null:
return signedOut(_that);case AuthTotp() when totp != null:
return totp(_that);case AuthEnroll() when enroll != null:
return enroll(_that);case AuthPassword() when password != null:
return password(_that);case AuthReady() when ready != null:
return ready(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AuthChecking value)  checking,required TResult Function( AuthSignedOut value)  signedOut,required TResult Function( AuthTotp value)  totp,required TResult Function( AuthEnroll value)  enroll,required TResult Function( AuthPassword value)  password,required TResult Function( AuthReady value)  ready,}){
final _that = this;
switch (_that) {
case AuthChecking():
return checking(_that);case AuthSignedOut():
return signedOut(_that);case AuthTotp():
return totp(_that);case AuthEnroll():
return enroll(_that);case AuthPassword():
return password(_that);case AuthReady():
return ready(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AuthChecking value)?  checking,TResult? Function( AuthSignedOut value)?  signedOut,TResult? Function( AuthTotp value)?  totp,TResult? Function( AuthEnroll value)?  enroll,TResult? Function( AuthPassword value)?  password,TResult? Function( AuthReady value)?  ready,}){
final _that = this;
switch (_that) {
case AuthChecking() when checking != null:
return checking(_that);case AuthSignedOut() when signedOut != null:
return signedOut(_that);case AuthTotp() when totp != null:
return totp(_that);case AuthEnroll() when enroll != null:
return enroll(_that);case AuthPassword() when password != null:
return password(_that);case AuthReady() when ready != null:
return ready(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  checking,TResult Function( bool busy,  ConsoleError? error,  SignOutReason? reason)?  signedOut,TResult Function( String factorId,  bool busy,  ConsoleError? error)?  totp,TResult Function( String factorId,  String secret,  String uri,  bool busy,  ConsoleError? error)?  enroll,TResult Function( bool busy,  ConsoleError? error)?  password,TResult Function( AgentProfile agent)?  ready,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AuthChecking() when checking != null:
return checking();case AuthSignedOut() when signedOut != null:
return signedOut(_that.busy,_that.error,_that.reason);case AuthTotp() when totp != null:
return totp(_that.factorId,_that.busy,_that.error);case AuthEnroll() when enroll != null:
return enroll(_that.factorId,_that.secret,_that.uri,_that.busy,_that.error);case AuthPassword() when password != null:
return password(_that.busy,_that.error);case AuthReady() when ready != null:
return ready(_that.agent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  checking,required TResult Function( bool busy,  ConsoleError? error,  SignOutReason? reason)  signedOut,required TResult Function( String factorId,  bool busy,  ConsoleError? error)  totp,required TResult Function( String factorId,  String secret,  String uri,  bool busy,  ConsoleError? error)  enroll,required TResult Function( bool busy,  ConsoleError? error)  password,required TResult Function( AgentProfile agent)  ready,}) {final _that = this;
switch (_that) {
case AuthChecking():
return checking();case AuthSignedOut():
return signedOut(_that.busy,_that.error,_that.reason);case AuthTotp():
return totp(_that.factorId,_that.busy,_that.error);case AuthEnroll():
return enroll(_that.factorId,_that.secret,_that.uri,_that.busy,_that.error);case AuthPassword():
return password(_that.busy,_that.error);case AuthReady():
return ready(_that.agent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  checking,TResult? Function( bool busy,  ConsoleError? error,  SignOutReason? reason)?  signedOut,TResult? Function( String factorId,  bool busy,  ConsoleError? error)?  totp,TResult? Function( String factorId,  String secret,  String uri,  bool busy,  ConsoleError? error)?  enroll,TResult? Function( bool busy,  ConsoleError? error)?  password,TResult? Function( AgentProfile agent)?  ready,}) {final _that = this;
switch (_that) {
case AuthChecking() when checking != null:
return checking();case AuthSignedOut() when signedOut != null:
return signedOut(_that.busy,_that.error,_that.reason);case AuthTotp() when totp != null:
return totp(_that.factorId,_that.busy,_that.error);case AuthEnroll() when enroll != null:
return enroll(_that.factorId,_that.secret,_that.uri,_that.busy,_that.error);case AuthPassword() when password != null:
return password(_that.busy,_that.error);case AuthReady() when ready != null:
return ready(_that.agent);case _:
  return null;

}
}

}

/// @nodoc


class AuthChecking implements AuthState {
  const AuthChecking();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthChecking);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthState.checking()';
}


}




/// @nodoc


class AuthSignedOut implements AuthState {
  const AuthSignedOut({this.busy = false, this.error, this.reason});
  

@JsonKey() final  bool busy;
 final  ConsoleError? error;
 final  SignOutReason? reason;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSignedOutCopyWith<AuthSignedOut> get copyWith => _$AuthSignedOutCopyWithImpl<AuthSignedOut>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignedOut&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,busy,error,reason);

@override
String toString() {
  return 'AuthState.signedOut(busy: $busy, error: $error, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $AuthSignedOutCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthSignedOutCopyWith(AuthSignedOut value, $Res Function(AuthSignedOut) _then) = _$AuthSignedOutCopyWithImpl;
@useResult
$Res call({
 bool busy, ConsoleError? error, SignOutReason? reason
});




}
/// @nodoc
class _$AuthSignedOutCopyWithImpl<$Res>
    implements $AuthSignedOutCopyWith<$Res> {
  _$AuthSignedOutCopyWithImpl(this._self, this._then);

  final AuthSignedOut _self;
  final $Res Function(AuthSignedOut) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? error = freezed,Object? reason = freezed,}) {
  return _then(AuthSignedOut(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ConsoleError?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SignOutReason?,
  ));
}


}

/// @nodoc


class AuthTotp implements AuthState {
  const AuthTotp({required this.factorId, this.busy = false, this.error});
  

 final  String factorId;
@JsonKey() final  bool busy;
 final  ConsoleError? error;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthTotpCopyWith<AuthTotp> get copyWith => _$AuthTotpCopyWithImpl<AuthTotp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthTotp&&(identical(other.factorId, factorId) || other.factorId == factorId)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,factorId,busy,error);

@override
String toString() {
  return 'AuthState.totp(factorId: $factorId, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class $AuthTotpCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthTotpCopyWith(AuthTotp value, $Res Function(AuthTotp) _then) = _$AuthTotpCopyWithImpl;
@useResult
$Res call({
 String factorId, bool busy, ConsoleError? error
});




}
/// @nodoc
class _$AuthTotpCopyWithImpl<$Res>
    implements $AuthTotpCopyWith<$Res> {
  _$AuthTotpCopyWithImpl(this._self, this._then);

  final AuthTotp _self;
  final $Res Function(AuthTotp) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? factorId = null,Object? busy = null,Object? error = freezed,}) {
  return _then(AuthTotp(
factorId: null == factorId ? _self.factorId : factorId // ignore: cast_nullable_to_non_nullable
as String,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ConsoleError?,
  ));
}


}

/// @nodoc


class AuthEnroll implements AuthState {
  const AuthEnroll({required this.factorId, required this.secret, required this.uri, this.busy = false, this.error});
  

 final  String factorId;
 final  String secret;
 final  String uri;
@JsonKey() final  bool busy;
 final  ConsoleError? error;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthEnrollCopyWith<AuthEnroll> get copyWith => _$AuthEnrollCopyWithImpl<AuthEnroll>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthEnroll&&(identical(other.factorId, factorId) || other.factorId == factorId)&&(identical(other.secret, secret) || other.secret == secret)&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,factorId,secret,uri,busy,error);

@override
String toString() {
  return 'AuthState.enroll(factorId: $factorId, secret: $secret, uri: $uri, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class $AuthEnrollCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthEnrollCopyWith(AuthEnroll value, $Res Function(AuthEnroll) _then) = _$AuthEnrollCopyWithImpl;
@useResult
$Res call({
 String factorId, String secret, String uri, bool busy, ConsoleError? error
});




}
/// @nodoc
class _$AuthEnrollCopyWithImpl<$Res>
    implements $AuthEnrollCopyWith<$Res> {
  _$AuthEnrollCopyWithImpl(this._self, this._then);

  final AuthEnroll _self;
  final $Res Function(AuthEnroll) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? factorId = null,Object? secret = null,Object? uri = null,Object? busy = null,Object? error = freezed,}) {
  return _then(AuthEnroll(
factorId: null == factorId ? _self.factorId : factorId // ignore: cast_nullable_to_non_nullable
as String,secret: null == secret ? _self.secret : secret // ignore: cast_nullable_to_non_nullable
as String,uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ConsoleError?,
  ));
}


}

/// @nodoc


class AuthPassword implements AuthState {
  const AuthPassword({this.busy = false, this.error});
  

@JsonKey() final  bool busy;
 final  ConsoleError? error;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthPasswordCopyWith<AuthPassword> get copyWith => _$AuthPasswordCopyWithImpl<AuthPassword>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthPassword&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,busy,error);

@override
String toString() {
  return 'AuthState.password(busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class $AuthPasswordCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthPasswordCopyWith(AuthPassword value, $Res Function(AuthPassword) _then) = _$AuthPasswordCopyWithImpl;
@useResult
$Res call({
 bool busy, ConsoleError? error
});




}
/// @nodoc
class _$AuthPasswordCopyWithImpl<$Res>
    implements $AuthPasswordCopyWith<$Res> {
  _$AuthPasswordCopyWithImpl(this._self, this._then);

  final AuthPassword _self;
  final $Res Function(AuthPassword) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? error = freezed,}) {
  return _then(AuthPassword(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ConsoleError?,
  ));
}


}

/// @nodoc


class AuthReady implements AuthState {
  const AuthReady(this.agent);
  

 final  AgentProfile agent;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthReadyCopyWith<AuthReady> get copyWith => _$AuthReadyCopyWithImpl<AuthReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthReady&&(identical(other.agent, agent) || other.agent == agent));
}


@override
int get hashCode => Object.hash(runtimeType,agent);

@override
String toString() {
  return 'AuthState.ready(agent: $agent)';
}


}

/// @nodoc
abstract mixin class $AuthReadyCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthReadyCopyWith(AuthReady value, $Res Function(AuthReady) _then) = _$AuthReadyCopyWithImpl;
@useResult
$Res call({
 AgentProfile agent
});


$AgentProfileCopyWith<$Res> get agent;

}
/// @nodoc
class _$AuthReadyCopyWithImpl<$Res>
    implements $AuthReadyCopyWith<$Res> {
  _$AuthReadyCopyWithImpl(this._self, this._then);

  final AuthReady _self;
  final $Res Function(AuthReady) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? agent = null,}) {
  return _then(AuthReady(
null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as AgentProfile,
  ));
}

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentProfileCopyWith<$Res> get agent {
  
  return $AgentProfileCopyWith<$Res>(_self.agent, (value) {
    return _then(_self.copyWith(agent: value));
  });
}
}

// dart format on
