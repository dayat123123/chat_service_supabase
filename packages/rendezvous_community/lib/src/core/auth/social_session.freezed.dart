// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SocialSession {

 String get accessToken; DateTime get expiresAt; UserSummary get user;
/// Create a copy of SocialSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SocialSessionCopyWith<SocialSession> get copyWith => _$SocialSessionCopyWithImpl<SocialSession>(this as SocialSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SocialSession&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,accessToken,expiresAt,user);

@override
String toString() {
  return 'SocialSession(accessToken: $accessToken, expiresAt: $expiresAt, user: $user)';
}


}

/// @nodoc
abstract mixin class $SocialSessionCopyWith<$Res>  {
  factory $SocialSessionCopyWith(SocialSession value, $Res Function(SocialSession) _then) = _$SocialSessionCopyWithImpl;
@useResult
$Res call({
 String accessToken, DateTime expiresAt, UserSummary user
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$SocialSessionCopyWithImpl<$Res>
    implements $SocialSessionCopyWith<$Res> {
  _$SocialSessionCopyWithImpl(this._self, this._then);

  final SocialSession _self;
  final $Res Function(SocialSession) _then;

/// Create a copy of SocialSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? expiresAt = null,Object? user = null,}) {
  return _then(_self.copyWith(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,
  ));
}
/// Create a copy of SocialSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [SocialSession].
extension SocialSessionPatterns on SocialSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SocialSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SocialSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SocialSession value)  $default,){
final _that = this;
switch (_that) {
case _SocialSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SocialSession value)?  $default,){
final _that = this;
switch (_that) {
case _SocialSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  DateTime expiresAt,  UserSummary user)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SocialSession() when $default != null:
return $default(_that.accessToken,_that.expiresAt,_that.user);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  DateTime expiresAt,  UserSummary user)  $default,) {final _that = this;
switch (_that) {
case _SocialSession():
return $default(_that.accessToken,_that.expiresAt,_that.user);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  DateTime expiresAt,  UserSummary user)?  $default,) {final _that = this;
switch (_that) {
case _SocialSession() when $default != null:
return $default(_that.accessToken,_that.expiresAt,_that.user);case _:
  return null;

}
}

}

/// @nodoc


class _SocialSession implements SocialSession {
  const _SocialSession({required this.accessToken, required this.expiresAt, required this.user});
  

@override final  String accessToken;
@override final  DateTime expiresAt;
@override final  UserSummary user;

/// Create a copy of SocialSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SocialSessionCopyWith<_SocialSession> get copyWith => __$SocialSessionCopyWithImpl<_SocialSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SocialSession&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,accessToken,expiresAt,user);

@override
String toString() {
  return 'SocialSession(accessToken: $accessToken, expiresAt: $expiresAt, user: $user)';
}


}

/// @nodoc
abstract mixin class _$SocialSessionCopyWith<$Res> implements $SocialSessionCopyWith<$Res> {
  factory _$SocialSessionCopyWith(_SocialSession value, $Res Function(_SocialSession) _then) = __$SocialSessionCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, DateTime expiresAt, UserSummary user
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$SocialSessionCopyWithImpl<$Res>
    implements _$SocialSessionCopyWith<$Res> {
  __$SocialSessionCopyWithImpl(this._self, this._then);

  final _SocialSession _self;
  final $Res Function(_SocialSession) _then;

/// Create a copy of SocialSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? expiresAt = null,Object? user = null,}) {
  return _then(_SocialSession(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,
  ));
}

/// Create a copy of SocialSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
