// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileSummaryModel {

 String get id; String get username; String? get displayName; String? get avatarUrl; bool get isVerified;
/// Create a copy of ProfileSummaryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileSummaryModelCopyWith<ProfileSummaryModel> get copyWith => _$ProfileSummaryModelCopyWithImpl<ProfileSummaryModel>(this as ProfileSummaryModel, _$identity);

  /// Serializes this ProfileSummaryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,isVerified);

@override
String toString() {
  return 'ProfileSummaryModel(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified)';
}


}

/// @nodoc
abstract mixin class $ProfileSummaryModelCopyWith<$Res>  {
  factory $ProfileSummaryModelCopyWith(ProfileSummaryModel value, $Res Function(ProfileSummaryModel) _then) = _$ProfileSummaryModelCopyWithImpl;
@useResult
$Res call({
 String id, String username, String? displayName, String? avatarUrl, bool isVerified
});




}
/// @nodoc
class _$ProfileSummaryModelCopyWithImpl<$Res>
    implements $ProfileSummaryModelCopyWith<$Res> {
  _$ProfileSummaryModelCopyWithImpl(this._self, this._then);

  final ProfileSummaryModel _self;
  final $Res Function(ProfileSummaryModel) _then;

/// Create a copy of ProfileSummaryModel
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


/// Adds pattern-matching-related methods to [ProfileSummaryModel].
extension ProfileSummaryModelPatterns on ProfileSummaryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileSummaryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileSummaryModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileSummaryModel value)  $default,){
final _that = this;
switch (_that) {
case _ProfileSummaryModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileSummaryModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileSummaryModel() when $default != null:
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
case _ProfileSummaryModel() when $default != null:
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
case _ProfileSummaryModel():
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
case _ProfileSummaryModel() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileSummaryModel extends ProfileSummaryModel {
  const _ProfileSummaryModel({required this.id, required this.username, this.displayName, this.avatarUrl, this.isVerified = false}): super._();
  factory _ProfileSummaryModel.fromJson(Map<String, dynamic> json) => _$ProfileSummaryModelFromJson(json);

@override final  String id;
@override final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override@JsonKey() final  bool isVerified;

/// Create a copy of ProfileSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileSummaryModelCopyWith<_ProfileSummaryModel> get copyWith => __$ProfileSummaryModelCopyWithImpl<_ProfileSummaryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileSummaryModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,isVerified);

@override
String toString() {
  return 'ProfileSummaryModel(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified)';
}


}

/// @nodoc
abstract mixin class _$ProfileSummaryModelCopyWith<$Res> implements $ProfileSummaryModelCopyWith<$Res> {
  factory _$ProfileSummaryModelCopyWith(_ProfileSummaryModel value, $Res Function(_ProfileSummaryModel) _then) = __$ProfileSummaryModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String? displayName, String? avatarUrl, bool isVerified
});




}
/// @nodoc
class __$ProfileSummaryModelCopyWithImpl<$Res>
    implements _$ProfileSummaryModelCopyWith<$Res> {
  __$ProfileSummaryModelCopyWithImpl(this._self, this._then);

  final _ProfileSummaryModel _self;
  final $Res Function(_ProfileSummaryModel) _then;

/// Create a copy of ProfileSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,}) {
  return _then(_ProfileSummaryModel(
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
mixin _$ProfileModel {

 String get id; String get username; String? get displayName; String? get avatarUrl; String? get bio; bool get isVerified; int get followerCount; int get followingCount; int get postCount; DateTime get createdAt; bool get isMe; bool get isFollowing; bool get followsMe; bool get isBlocked;
/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileModelCopyWith<ProfileModel> get copyWith => _$ProfileModelCopyWithImpl<ProfileModel>(this as ProfileModel, _$identity);

  /// Serializes this ProfileModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isMe, isMe) || other.isMe == isMe)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followsMe, followsMe) || other.followsMe == followsMe)&&(identical(other.isBlocked, isBlocked) || other.isBlocked == isBlocked));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,bio,isVerified,followerCount,followingCount,postCount,createdAt,isMe,isFollowing,followsMe,isBlocked);

@override
String toString() {
  return 'ProfileModel(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, isVerified: $isVerified, followerCount: $followerCount, followingCount: $followingCount, postCount: $postCount, createdAt: $createdAt, isMe: $isMe, isFollowing: $isFollowing, followsMe: $followsMe, isBlocked: $isBlocked)';
}


}

/// @nodoc
abstract mixin class $ProfileModelCopyWith<$Res>  {
  factory $ProfileModelCopyWith(ProfileModel value, $Res Function(ProfileModel) _then) = _$ProfileModelCopyWithImpl;
@useResult
$Res call({
 String id, String username, String? displayName, String? avatarUrl, String? bio, bool isVerified, int followerCount, int followingCount, int postCount, DateTime createdAt, bool isMe, bool isFollowing, bool followsMe, bool isBlocked
});




}
/// @nodoc
class _$ProfileModelCopyWithImpl<$Res>
    implements $ProfileModelCopyWith<$Res> {
  _$ProfileModelCopyWithImpl(this._self, this._then);

  final ProfileModel _self;
  final $Res Function(ProfileModel) _then;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? bio = freezed,Object? isVerified = null,Object? followerCount = null,Object? followingCount = null,Object? postCount = null,Object? createdAt = null,Object? isMe = null,Object? isFollowing = null,Object? followsMe = null,Object? isBlocked = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
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

}


/// Adds pattern-matching-related methods to [ProfileModel].
extension ProfileModelPatterns on ProfileModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileModel value)  $default,){
final _that = this;
switch (_that) {
case _ProfileModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String? displayName,  String? avatarUrl,  String? bio,  bool isVerified,  int followerCount,  int followingCount,  int postCount,  DateTime createdAt,  bool isMe,  bool isFollowing,  bool followsMe,  bool isBlocked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isVerified,_that.followerCount,_that.followingCount,_that.postCount,_that.createdAt,_that.isMe,_that.isFollowing,_that.followsMe,_that.isBlocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String? displayName,  String? avatarUrl,  String? bio,  bool isVerified,  int followerCount,  int followingCount,  int postCount,  DateTime createdAt,  bool isMe,  bool isFollowing,  bool followsMe,  bool isBlocked)  $default,) {final _that = this;
switch (_that) {
case _ProfileModel():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isVerified,_that.followerCount,_that.followingCount,_that.postCount,_that.createdAt,_that.isMe,_that.isFollowing,_that.followsMe,_that.isBlocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String? displayName,  String? avatarUrl,  String? bio,  bool isVerified,  int followerCount,  int followingCount,  int postCount,  DateTime createdAt,  bool isMe,  bool isFollowing,  bool followsMe,  bool isBlocked)?  $default,) {final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isVerified,_that.followerCount,_that.followingCount,_that.postCount,_that.createdAt,_that.isMe,_that.isFollowing,_that.followsMe,_that.isBlocked);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileModel extends ProfileModel {
  const _ProfileModel({required this.id, required this.username, this.displayName, this.avatarUrl, this.bio, this.isVerified = false, this.followerCount = 0, this.followingCount = 0, this.postCount = 0, required this.createdAt, this.isMe = false, this.isFollowing = false, this.followsMe = false, this.isBlocked = false}): super._();
  factory _ProfileModel.fromJson(Map<String, dynamic> json) => _$ProfileModelFromJson(json);

@override final  String id;
@override final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override final  String? bio;
@override@JsonKey() final  bool isVerified;
@override@JsonKey() final  int followerCount;
@override@JsonKey() final  int followingCount;
@override@JsonKey() final  int postCount;
@override final  DateTime createdAt;
@override@JsonKey() final  bool isMe;
@override@JsonKey() final  bool isFollowing;
@override@JsonKey() final  bool followsMe;
@override@JsonKey() final  bool isBlocked;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileModelCopyWith<_ProfileModel> get copyWith => __$ProfileModelCopyWithImpl<_ProfileModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isMe, isMe) || other.isMe == isMe)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followsMe, followsMe) || other.followsMe == followsMe)&&(identical(other.isBlocked, isBlocked) || other.isBlocked == isBlocked));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,bio,isVerified,followerCount,followingCount,postCount,createdAt,isMe,isFollowing,followsMe,isBlocked);

@override
String toString() {
  return 'ProfileModel(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, isVerified: $isVerified, followerCount: $followerCount, followingCount: $followingCount, postCount: $postCount, createdAt: $createdAt, isMe: $isMe, isFollowing: $isFollowing, followsMe: $followsMe, isBlocked: $isBlocked)';
}


}

/// @nodoc
abstract mixin class _$ProfileModelCopyWith<$Res> implements $ProfileModelCopyWith<$Res> {
  factory _$ProfileModelCopyWith(_ProfileModel value, $Res Function(_ProfileModel) _then) = __$ProfileModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String? displayName, String? avatarUrl, String? bio, bool isVerified, int followerCount, int followingCount, int postCount, DateTime createdAt, bool isMe, bool isFollowing, bool followsMe, bool isBlocked
});




}
/// @nodoc
class __$ProfileModelCopyWithImpl<$Res>
    implements _$ProfileModelCopyWith<$Res> {
  __$ProfileModelCopyWithImpl(this._self, this._then);

  final _ProfileModel _self;
  final $Res Function(_ProfileModel) _then;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? bio = freezed,Object? isVerified = null,Object? followerCount = null,Object? followingCount = null,Object? postCount = null,Object? createdAt = null,Object? isMe = null,Object? isFollowing = null,Object? followsMe = null,Object? isBlocked = null,}) {
  return _then(_ProfileModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
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


}


/// @nodoc
mixin _$StockModel {

 String get code; String get name; String get type; String? get sector; int get watcherCount;
/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockModelCopyWith<StockModel> get copyWith => _$StockModelCopyWithImpl<StockModel>(this as StockModel, _$identity);

  /// Serializes this StockModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.sector, sector) || other.sector == sector)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name,type,sector,watcherCount);

@override
String toString() {
  return 'StockModel(code: $code, name: $name, type: $type, sector: $sector, watcherCount: $watcherCount)';
}


}

/// @nodoc
abstract mixin class $StockModelCopyWith<$Res>  {
  factory $StockModelCopyWith(StockModel value, $Res Function(StockModel) _then) = _$StockModelCopyWithImpl;
@useResult
$Res call({
 String code, String name, String type, String? sector, int watcherCount
});




}
/// @nodoc
class _$StockModelCopyWithImpl<$Res>
    implements $StockModelCopyWith<$Res> {
  _$StockModelCopyWithImpl(this._self, this._then);

  final StockModel _self;
  final $Res Function(StockModel) _then;

/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? type = null,Object? sector = freezed,Object? watcherCount = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,sector: freezed == sector ? _self.sector : sector // ignore: cast_nullable_to_non_nullable
as String?,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [StockModel].
extension StockModelPatterns on StockModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockModel value)  $default,){
final _that = this;
switch (_that) {
case _StockModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockModel value)?  $default,){
final _that = this;
switch (_that) {
case _StockModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String type,  String? sector,  int watcherCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StockModel() when $default != null:
return $default(_that.code,_that.name,_that.type,_that.sector,_that.watcherCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String type,  String? sector,  int watcherCount)  $default,) {final _that = this;
switch (_that) {
case _StockModel():
return $default(_that.code,_that.name,_that.type,_that.sector,_that.watcherCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String type,  String? sector,  int watcherCount)?  $default,) {final _that = this;
switch (_that) {
case _StockModel() when $default != null:
return $default(_that.code,_that.name,_that.type,_that.sector,_that.watcherCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StockModel extends StockModel {
  const _StockModel({required this.code, required this.name, this.type = 'stock', this.sector, this.watcherCount = 0}): super._();
  factory _StockModel.fromJson(Map<String, dynamic> json) => _$StockModelFromJson(json);

@override final  String code;
@override final  String name;
@override@JsonKey() final  String type;
@override final  String? sector;
@override@JsonKey() final  int watcherCount;

/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockModelCopyWith<_StockModel> get copyWith => __$StockModelCopyWithImpl<_StockModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StockModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.sector, sector) || other.sector == sector)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name,type,sector,watcherCount);

@override
String toString() {
  return 'StockModel(code: $code, name: $name, type: $type, sector: $sector, watcherCount: $watcherCount)';
}


}

/// @nodoc
abstract mixin class _$StockModelCopyWith<$Res> implements $StockModelCopyWith<$Res> {
  factory _$StockModelCopyWith(_StockModel value, $Res Function(_StockModel) _then) = __$StockModelCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String type, String? sector, int watcherCount
});




}
/// @nodoc
class __$StockModelCopyWithImpl<$Res>
    implements _$StockModelCopyWith<$Res> {
  __$StockModelCopyWithImpl(this._self, this._then);

  final _StockModel _self;
  final $Res Function(_StockModel) _then;

/// Create a copy of StockModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? type = null,Object? sector = freezed,Object? watcherCount = null,}) {
  return _then(_StockModel(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,sector: freezed == sector ? _self.sector : sector // ignore: cast_nullable_to_non_nullable
as String?,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$NotificationModel {

 String get id; String get type; String? get actorId; String? get actorUsername; String? get actorDisplayName; String? get actorAvatarUrl; Map<String, Object?> get payload; int get eventCount; DateTime? get readAt; DateTime get createdAt; String get cursor;
/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationModelCopyWith<NotificationModel> get copyWith => _$NotificationModelCopyWithImpl<NotificationModel>(this as NotificationModel, _$identity);

  /// Serializes this NotificationModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.actorUsername, actorUsername) || other.actorUsername == actorUsername)&&(identical(other.actorDisplayName, actorDisplayName) || other.actorDisplayName == actorDisplayName)&&(identical(other.actorAvatarUrl, actorAvatarUrl) || other.actorAvatarUrl == actorAvatarUrl)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,actorId,actorUsername,actorDisplayName,actorAvatarUrl,const DeepCollectionEquality().hash(payload),eventCount,readAt,createdAt,cursor);

@override
String toString() {
  return 'NotificationModel(id: $id, type: $type, actorId: $actorId, actorUsername: $actorUsername, actorDisplayName: $actorDisplayName, actorAvatarUrl: $actorAvatarUrl, payload: $payload, eventCount: $eventCount, readAt: $readAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class $NotificationModelCopyWith<$Res>  {
  factory $NotificationModelCopyWith(NotificationModel value, $Res Function(NotificationModel) _then) = _$NotificationModelCopyWithImpl;
@useResult
$Res call({
 String id, String type, String? actorId, String? actorUsername, String? actorDisplayName, String? actorAvatarUrl, Map<String, Object?> payload, int eventCount, DateTime? readAt, DateTime createdAt, String cursor
});




}
/// @nodoc
class _$NotificationModelCopyWithImpl<$Res>
    implements $NotificationModelCopyWith<$Res> {
  _$NotificationModelCopyWithImpl(this._self, this._then);

  final NotificationModel _self;
  final $Res Function(NotificationModel) _then;

/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? actorId = freezed,Object? actorUsername = freezed,Object? actorDisplayName = freezed,Object? actorAvatarUrl = freezed,Object? payload = null,Object? eventCount = null,Object? readAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,actorUsername: freezed == actorUsername ? _self.actorUsername : actorUsername // ignore: cast_nullable_to_non_nullable
as String?,actorDisplayName: freezed == actorDisplayName ? _self.actorDisplayName : actorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,actorAvatarUrl: freezed == actorAvatarUrl ? _self.actorAvatarUrl : actorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationModel].
extension NotificationModelPatterns on NotificationModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationModel value)  $default,){
final _that = this;
switch (_that) {
case _NotificationModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationModel value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String? actorId,  String? actorUsername,  String? actorDisplayName,  String? actorAvatarUrl,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
return $default(_that.id,_that.type,_that.actorId,_that.actorUsername,_that.actorDisplayName,_that.actorAvatarUrl,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String? actorId,  String? actorUsername,  String? actorDisplayName,  String? actorAvatarUrl,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor)  $default,) {final _that = this;
switch (_that) {
case _NotificationModel():
return $default(_that.id,_that.type,_that.actorId,_that.actorUsername,_that.actorDisplayName,_that.actorAvatarUrl,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String? actorId,  String? actorUsername,  String? actorDisplayName,  String? actorAvatarUrl,  Map<String, Object?> payload,  int eventCount,  DateTime? readAt,  DateTime createdAt,  String cursor)?  $default,) {final _that = this;
switch (_that) {
case _NotificationModel() when $default != null:
return $default(_that.id,_that.type,_that.actorId,_that.actorUsername,_that.actorDisplayName,_that.actorAvatarUrl,_that.payload,_that.eventCount,_that.readAt,_that.createdAt,_that.cursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationModel extends NotificationModel {
  const _NotificationModel({required this.id, required this.type, this.actorId, this.actorUsername, this.actorDisplayName, this.actorAvatarUrl, final  Map<String, Object?> payload = const <String, Object?>{}, this.eventCount = 1, this.readAt, required this.createdAt, required this.cursor}): _payload = payload,super._();
  factory _NotificationModel.fromJson(Map<String, dynamic> json) => _$NotificationModelFromJson(json);

@override final  String id;
@override final  String type;
@override final  String? actorId;
@override final  String? actorUsername;
@override final  String? actorDisplayName;
@override final  String? actorAvatarUrl;
 final  Map<String, Object?> _payload;
@override@JsonKey() Map<String, Object?> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override@JsonKey() final  int eventCount;
@override final  DateTime? readAt;
@override final  DateTime createdAt;
@override final  String cursor;

/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationModelCopyWith<_NotificationModel> get copyWith => __$NotificationModelCopyWithImpl<_NotificationModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.actorUsername, actorUsername) || other.actorUsername == actorUsername)&&(identical(other.actorDisplayName, actorDisplayName) || other.actorDisplayName == actorDisplayName)&&(identical(other.actorAvatarUrl, actorAvatarUrl) || other.actorAvatarUrl == actorAvatarUrl)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,actorId,actorUsername,actorDisplayName,actorAvatarUrl,const DeepCollectionEquality().hash(_payload),eventCount,readAt,createdAt,cursor);

@override
String toString() {
  return 'NotificationModel(id: $id, type: $type, actorId: $actorId, actorUsername: $actorUsername, actorDisplayName: $actorDisplayName, actorAvatarUrl: $actorAvatarUrl, payload: $payload, eventCount: $eventCount, readAt: $readAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$NotificationModelCopyWith<$Res> implements $NotificationModelCopyWith<$Res> {
  factory _$NotificationModelCopyWith(_NotificationModel value, $Res Function(_NotificationModel) _then) = __$NotificationModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String? actorId, String? actorUsername, String? actorDisplayName, String? actorAvatarUrl, Map<String, Object?> payload, int eventCount, DateTime? readAt, DateTime createdAt, String cursor
});




}
/// @nodoc
class __$NotificationModelCopyWithImpl<$Res>
    implements _$NotificationModelCopyWith<$Res> {
  __$NotificationModelCopyWithImpl(this._self, this._then);

  final _NotificationModel _self;
  final $Res Function(_NotificationModel) _then;

/// Create a copy of NotificationModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? actorId = freezed,Object? actorUsername = freezed,Object? actorDisplayName = freezed,Object? actorAvatarUrl = freezed,Object? payload = null,Object? eventCount = null,Object? readAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_NotificationModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,actorUsername: freezed == actorUsername ? _self.actorUsername : actorUsername // ignore: cast_nullable_to_non_nullable
as String?,actorDisplayName: freezed == actorDisplayName ? _self.actorDisplayName : actorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,actorAvatarUrl: freezed == actorAvatarUrl ? _self.actorAvatarUrl : actorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
