// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserSummary {

 String get id; String get username; String? get displayName; String? get avatarUrl; bool get isVerified;
/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<UserSummary> get copyWith => _$UserSummaryCopyWithImpl<UserSummary>(this as UserSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,isVerified);

@override
String toString() {
  return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified)';
}


}

/// @nodoc
abstract mixin class $UserSummaryCopyWith<$Res>  {
  factory $UserSummaryCopyWith(UserSummary value, $Res Function(UserSummary) _then) = _$UserSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String username, String? displayName, String? avatarUrl, bool isVerified
});




}
/// @nodoc
class _$UserSummaryCopyWithImpl<$Res>
    implements $UserSummaryCopyWith<$Res> {
  _$UserSummaryCopyWithImpl(this._self, this._then);

  final UserSummary _self;
  final $Res Function(UserSummary) _then;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSummary].
extension UserSummaryPatterns on UserSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSummary value)  $default,){
final _that = this;
switch (_that) {
case _UserSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSummary value)?  $default,){
final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String? displayName,  String? avatarUrl,  bool isVerified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String? displayName,  String? avatarUrl,  bool isVerified)  $default,) {final _that = this;
switch (_that) {
case _UserSummary():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String? displayName,  String? avatarUrl,  bool isVerified)?  $default,) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified);case _:
  return null;

}
}

}

/// @nodoc


class _UserSummary extends UserSummary {
  const _UserSummary({required this.id, required this.username, this.displayName, this.avatarUrl, this.isVerified = false}): super._();
  

@override final  String id;
@override final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override@JsonKey() final  bool isVerified;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSummaryCopyWith<_UserSummary> get copyWith => __$UserSummaryCopyWithImpl<_UserSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified));
}


@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,isVerified);

@override
String toString() {
  return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified)';
}


}

/// @nodoc
abstract mixin class _$UserSummaryCopyWith<$Res> implements $UserSummaryCopyWith<$Res> {
  factory _$UserSummaryCopyWith(_UserSummary value, $Res Function(_UserSummary) _then) = __$UserSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String? displayName, String? avatarUrl, bool isVerified
});




}
/// @nodoc
class __$UserSummaryCopyWithImpl<$Res>
    implements _$UserSummaryCopyWith<$Res> {
  __$UserSummaryCopyWithImpl(this._self, this._then);

  final _UserSummary _self;
  final $Res Function(_UserSummary) _then;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,}) {
  return _then(_UserSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UserProfile {

 UserSummary get user; String? get bio; int get followerCount; int get followingCount; int get postCount; DateTime get createdAt; bool get isMe; bool get isFollowing; bool get followsMe; bool get isBlocked;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.user, user) || other.user == user)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isMe, isMe) || other.isMe == isMe)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followsMe, followsMe) || other.followsMe == followsMe)&&(identical(other.isBlocked, isBlocked) || other.isBlocked == isBlocked));
}


@override
int get hashCode => Object.hash(runtimeType,user,bio,followerCount,followingCount,postCount,createdAt,isMe,isFollowing,followsMe,isBlocked);

@override
String toString() {
  return 'UserProfile(user: $user, bio: $bio, followerCount: $followerCount, followingCount: $followingCount, postCount: $postCount, createdAt: $createdAt, isMe: $isMe, isFollowing: $isFollowing, followsMe: $followsMe, isBlocked: $isBlocked)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 UserSummary user, String? bio, int followerCount, int followingCount, int postCount, DateTime createdAt, bool isMe, bool isFollowing, bool followsMe, bool isBlocked
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? bio = freezed,Object? followerCount = null,Object? followingCount = null,Object? postCount = null,Object? createdAt = null,Object? isMe = null,Object? isFollowing = null,Object? followsMe = null,Object? isBlocked = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,isMe: null == isMe ? _self.isMe : isMe // ignore: cast_nullable_to_non_nullable
as bool,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followsMe: null == followsMe ? _self.followsMe : followsMe // ignore: cast_nullable_to_non_nullable
as bool,isBlocked: null == isBlocked ? _self.isBlocked : isBlocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  String? bio,  int followerCount,  int followingCount,  int postCount,  DateTime createdAt,  bool isMe,  bool isFollowing,  bool followsMe,  bool isBlocked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.user,_that.bio,_that.followerCount,_that.followingCount,_that.postCount,_that.createdAt,_that.isMe,_that.isFollowing,_that.followsMe,_that.isBlocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  String? bio,  int followerCount,  int followingCount,  int postCount,  DateTime createdAt,  bool isMe,  bool isFollowing,  bool followsMe,  bool isBlocked)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.user,_that.bio,_that.followerCount,_that.followingCount,_that.postCount,_that.createdAt,_that.isMe,_that.isFollowing,_that.followsMe,_that.isBlocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  String? bio,  int followerCount,  int followingCount,  int postCount,  DateTime createdAt,  bool isMe,  bool isFollowing,  bool followsMe,  bool isBlocked)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.user,_that.bio,_that.followerCount,_that.followingCount,_that.postCount,_that.createdAt,_that.isMe,_that.isFollowing,_that.followsMe,_that.isBlocked);case _:
  return null;

}
}

}

/// @nodoc


class _UserProfile implements UserProfile {
  const _UserProfile({required this.user, this.bio, required this.followerCount, required this.followingCount, required this.postCount, required this.createdAt, required this.isMe, required this.isFollowing, required this.followsMe, required this.isBlocked});
  

@override final  UserSummary user;
@override final  String? bio;
@override final  int followerCount;
@override final  int followingCount;
@override final  int postCount;
@override final  DateTime createdAt;
@override final  bool isMe;
@override final  bool isFollowing;
@override final  bool followsMe;
@override final  bool isBlocked;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.user, user) || other.user == user)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isMe, isMe) || other.isMe == isMe)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followsMe, followsMe) || other.followsMe == followsMe)&&(identical(other.isBlocked, isBlocked) || other.isBlocked == isBlocked));
}


@override
int get hashCode => Object.hash(runtimeType,user,bio,followerCount,followingCount,postCount,createdAt,isMe,isFollowing,followsMe,isBlocked);

@override
String toString() {
  return 'UserProfile(user: $user, bio: $bio, followerCount: $followerCount, followingCount: $followingCount, postCount: $postCount, createdAt: $createdAt, isMe: $isMe, isFollowing: $isFollowing, followsMe: $followsMe, isBlocked: $isBlocked)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, String? bio, int followerCount, int followingCount, int postCount, DateTime createdAt, bool isMe, bool isFollowing, bool followsMe, bool isBlocked
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? bio = freezed,Object? followerCount = null,Object? followingCount = null,Object? postCount = null,Object? createdAt = null,Object? isMe = null,Object? isFollowing = null,Object? followsMe = null,Object? isBlocked = null,}) {
  return _then(_UserProfile(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,isMe: null == isMe ? _self.isMe : isMe // ignore: cast_nullable_to_non_nullable
as bool,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followsMe: null == followsMe ? _self.followsMe : followsMe // ignore: cast_nullable_to_non_nullable
as bool,isBlocked: null == isBlocked ? _self.isBlocked : isBlocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

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
