// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AttachmentModel {

 String get path; String? get mime; int? get width; int? get height;
/// Create a copy of AttachmentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentModelCopyWith<AttachmentModel> get copyWith => _$AttachmentModelCopyWithImpl<AttachmentModel>(this as AttachmentModel, _$identity);

  /// Serializes this AttachmentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttachmentModel&&(identical(other.path, path) || other.path == path)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,mime,width,height);

@override
String toString() {
  return 'AttachmentModel(path: $path, mime: $mime, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $AttachmentModelCopyWith<$Res>  {
  factory $AttachmentModelCopyWith(AttachmentModel value, $Res Function(AttachmentModel) _then) = _$AttachmentModelCopyWithImpl;
@useResult
$Res call({
 String path, String? mime, int? width, int? height
});




}
/// @nodoc
class _$AttachmentModelCopyWithImpl<$Res>
    implements $AttachmentModelCopyWith<$Res> {
  _$AttachmentModelCopyWithImpl(this._self, this._then);

  final AttachmentModel _self;
  final $Res Function(AttachmentModel) _then;

/// Create a copy of AttachmentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? mime = freezed,Object? width = freezed,Object? height = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AttachmentModel].
extension AttachmentModelPatterns on AttachmentModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttachmentModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttachmentModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttachmentModel value)  $default,){
final _that = this;
switch (_that) {
case _AttachmentModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttachmentModel value)?  $default,){
final _that = this;
switch (_that) {
case _AttachmentModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String? mime,  int? width,  int? height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttachmentModel() when $default != null:
return $default(_that.path,_that.mime,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String? mime,  int? width,  int? height)  $default,) {final _that = this;
switch (_that) {
case _AttachmentModel():
return $default(_that.path,_that.mime,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String? mime,  int? width,  int? height)?  $default,) {final _that = this;
switch (_that) {
case _AttachmentModel() when $default != null:
return $default(_that.path,_that.mime,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttachmentModel extends AttachmentModel {
  const _AttachmentModel({required this.path, this.mime, this.width, this.height}): super._();
  factory _AttachmentModel.fromJson(Map<String, dynamic> json) => _$AttachmentModelFromJson(json);

@override final  String path;
@override final  String? mime;
@override final  int? width;
@override final  int? height;

/// Create a copy of AttachmentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentModelCopyWith<_AttachmentModel> get copyWith => __$AttachmentModelCopyWithImpl<_AttachmentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttachmentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttachmentModel&&(identical(other.path, path) || other.path == path)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,mime,width,height);

@override
String toString() {
  return 'AttachmentModel(path: $path, mime: $mime, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$AttachmentModelCopyWith<$Res> implements $AttachmentModelCopyWith<$Res> {
  factory _$AttachmentModelCopyWith(_AttachmentModel value, $Res Function(_AttachmentModel) _then) = __$AttachmentModelCopyWithImpl;
@override @useResult
$Res call({
 String path, String? mime, int? width, int? height
});




}
/// @nodoc
class __$AttachmentModelCopyWithImpl<$Res>
    implements _$AttachmentModelCopyWith<$Res> {
  __$AttachmentModelCopyWithImpl(this._self, this._then);

  final _AttachmentModel _self;
  final $Res Function(_AttachmentModel) _then;

/// Create a copy of AttachmentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? mime = freezed,Object? width = freezed,Object? height = freezed,}) {
  return _then(_AttachmentModel(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$FeedPostModel {

 String get id; String get authorId; String get authorUsername; String? get authorDisplayName; String? get authorAvatarUrl; bool get authorIsVerified; String get body; String? get sentiment; List<AttachmentModel> get attachments; int get likeCount; int get commentCount; List<String> get stockCodes; bool get likedByMe; DateTime? get editedAt; DateTime get createdAt; String get cursor;
/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedPostModelCopyWith<FeedPostModel> get copyWith => _$FeedPostModelCopyWithImpl<FeedPostModel>(this as FeedPostModel, _$identity);

  /// Serializes this FeedPostModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedPostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,sentiment,const DeepCollectionEquality().hash(attachments),likeCount,commentCount,const DeepCollectionEquality().hash(stockCodes),likedByMe,editedAt,createdAt,cursor);

@override
String toString() {
  return 'FeedPostModel(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, sentiment: $sentiment, attachments: $attachments, likeCount: $likeCount, commentCount: $commentCount, stockCodes: $stockCodes, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class $FeedPostModelCopyWith<$Res>  {
  factory $FeedPostModelCopyWith(FeedPostModel value, $Res Function(FeedPostModel) _then) = _$FeedPostModelCopyWithImpl;
@useResult
$Res call({
 String id, String authorId, String authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String body, String? sentiment, List<AttachmentModel> attachments, int likeCount, int commentCount, List<String> stockCodes, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor
});




}
/// @nodoc
class _$FeedPostModelCopyWithImpl<$Res>
    implements $FeedPostModelCopyWith<$Res> {
  _$FeedPostModelCopyWithImpl(this._self, this._then);

  final FeedPostModel _self;
  final $Res Function(FeedPostModel) _then;

/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? authorId = null,Object? authorUsername = null,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = null,Object? sentiment = freezed,Object? attachments = null,Object? likeCount = null,Object? commentCount = null,Object? stockCodes = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,authorUsername: null == authorUsername ? _self.authorUsername : authorUsername // ignore: cast_nullable_to_non_nullable
as String,authorDisplayName: freezed == authorDisplayName ? _self.authorDisplayName : authorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,authorAvatarUrl: freezed == authorAvatarUrl ? _self.authorAvatarUrl : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,authorIsVerified: null == authorIsVerified ? _self.authorIsVerified : authorIsVerified // ignore: cast_nullable_to_non_nullable
as bool,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,stockCodes: null == stockCodes ? _self.stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedPostModel].
extension FeedPostModelPatterns on FeedPostModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedPostModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedPostModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedPostModel value)  $default,){
final _that = this;
switch (_that) {
case _FeedPostModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedPostModel value)?  $default,){
final _that = this;
switch (_that) {
case _FeedPostModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String authorId,  String authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String body,  String? sentiment,  List<AttachmentModel> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedPostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String authorId,  String authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String body,  String? sentiment,  List<AttachmentModel> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)  $default,) {final _that = this;
switch (_that) {
case _FeedPostModel():
return $default(_that.id,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String authorId,  String authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String body,  String? sentiment,  List<AttachmentModel> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)?  $default,) {final _that = this;
switch (_that) {
case _FeedPostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedPostModel extends FeedPostModel {
  const _FeedPostModel({required this.id, required this.authorId, required this.authorUsername, this.authorDisplayName, this.authorAvatarUrl, this.authorIsVerified = false, required this.body, this.sentiment, final  List<AttachmentModel> attachments = const <AttachmentModel>[], this.likeCount = 0, this.commentCount = 0, final  List<String> stockCodes = const <String>[], this.likedByMe = false, this.editedAt, required this.createdAt, required this.cursor}): _attachments = attachments,_stockCodes = stockCodes,super._();
  factory _FeedPostModel.fromJson(Map<String, dynamic> json) => _$FeedPostModelFromJson(json);

@override final  String id;
@override final  String authorId;
@override final  String authorUsername;
@override final  String? authorDisplayName;
@override final  String? authorAvatarUrl;
@override@JsonKey() final  bool authorIsVerified;
@override final  String body;
@override final  String? sentiment;
 final  List<AttachmentModel> _attachments;
@override@JsonKey() List<AttachmentModel> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override@JsonKey() final  int likeCount;
@override@JsonKey() final  int commentCount;
 final  List<String> _stockCodes;
@override@JsonKey() List<String> get stockCodes {
  if (_stockCodes is EqualUnmodifiableListView) return _stockCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stockCodes);
}

@override@JsonKey() final  bool likedByMe;
@override final  DateTime? editedAt;
@override final  DateTime createdAt;
@override final  String cursor;

/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedPostModelCopyWith<_FeedPostModel> get copyWith => __$FeedPostModelCopyWithImpl<_FeedPostModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedPostModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedPostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,sentiment,const DeepCollectionEquality().hash(_attachments),likeCount,commentCount,const DeepCollectionEquality().hash(_stockCodes),likedByMe,editedAt,createdAt,cursor);

@override
String toString() {
  return 'FeedPostModel(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, sentiment: $sentiment, attachments: $attachments, likeCount: $likeCount, commentCount: $commentCount, stockCodes: $stockCodes, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$FeedPostModelCopyWith<$Res> implements $FeedPostModelCopyWith<$Res> {
  factory _$FeedPostModelCopyWith(_FeedPostModel value, $Res Function(_FeedPostModel) _then) = __$FeedPostModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String authorId, String authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String body, String? sentiment, List<AttachmentModel> attachments, int likeCount, int commentCount, List<String> stockCodes, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor
});




}
/// @nodoc
class __$FeedPostModelCopyWithImpl<$Res>
    implements _$FeedPostModelCopyWith<$Res> {
  __$FeedPostModelCopyWithImpl(this._self, this._then);

  final _FeedPostModel _self;
  final $Res Function(_FeedPostModel) _then;

/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? authorId = null,Object? authorUsername = null,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = null,Object? sentiment = freezed,Object? attachments = null,Object? likeCount = null,Object? commentCount = null,Object? stockCodes = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_FeedPostModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,authorUsername: null == authorUsername ? _self.authorUsername : authorUsername // ignore: cast_nullable_to_non_nullable
as String,authorDisplayName: freezed == authorDisplayName ? _self.authorDisplayName : authorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,authorAvatarUrl: freezed == authorAvatarUrl ? _self.authorAvatarUrl : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,authorIsVerified: null == authorIsVerified ? _self.authorIsVerified : authorIsVerified // ignore: cast_nullable_to_non_nullable
as bool,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,stockCodes: null == stockCodes ? _self._stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PostRowModel {

 String get id; String get authorId; String get body; int get likeCount; int get commentCount; DateTime? get deletedAt; DateTime get createdAt;
/// Create a copy of PostRowModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostRowModelCopyWith<PostRowModel> get copyWith => _$PostRowModelCopyWithImpl<PostRowModel>(this as PostRowModel, _$identity);

  /// Serializes this PostRowModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostRowModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.body, body) || other.body == body)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,body,likeCount,commentCount,deletedAt,createdAt);

@override
String toString() {
  return 'PostRowModel(id: $id, authorId: $authorId, body: $body, likeCount: $likeCount, commentCount: $commentCount, deletedAt: $deletedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PostRowModelCopyWith<$Res>  {
  factory $PostRowModelCopyWith(PostRowModel value, $Res Function(PostRowModel) _then) = _$PostRowModelCopyWithImpl;
@useResult
$Res call({
 String id, String authorId, String body, int likeCount, int commentCount, DateTime? deletedAt, DateTime createdAt
});




}
/// @nodoc
class _$PostRowModelCopyWithImpl<$Res>
    implements $PostRowModelCopyWith<$Res> {
  _$PostRowModelCopyWithImpl(this._self, this._then);

  final PostRowModel _self;
  final $Res Function(PostRowModel) _then;

/// Create a copy of PostRowModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? authorId = null,Object? body = null,Object? likeCount = null,Object? commentCount = null,Object? deletedAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PostRowModel].
extension PostRowModelPatterns on PostRowModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostRowModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostRowModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostRowModel value)  $default,){
final _that = this;
switch (_that) {
case _PostRowModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostRowModel value)?  $default,){
final _that = this;
switch (_that) {
case _PostRowModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String authorId,  String body,  int likeCount,  int commentCount,  DateTime? deletedAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostRowModel() when $default != null:
return $default(_that.id,_that.authorId,_that.body,_that.likeCount,_that.commentCount,_that.deletedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String authorId,  String body,  int likeCount,  int commentCount,  DateTime? deletedAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _PostRowModel():
return $default(_that.id,_that.authorId,_that.body,_that.likeCount,_that.commentCount,_that.deletedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String authorId,  String body,  int likeCount,  int commentCount,  DateTime? deletedAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PostRowModel() when $default != null:
return $default(_that.id,_that.authorId,_that.body,_that.likeCount,_that.commentCount,_that.deletedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PostRowModel implements PostRowModel {
  const _PostRowModel({required this.id, required this.authorId, this.body = '', this.likeCount = 0, this.commentCount = 0, this.deletedAt, required this.createdAt});
  factory _PostRowModel.fromJson(Map<String, dynamic> json) => _$PostRowModelFromJson(json);

@override final  String id;
@override final  String authorId;
@override@JsonKey() final  String body;
@override@JsonKey() final  int likeCount;
@override@JsonKey() final  int commentCount;
@override final  DateTime? deletedAt;
@override final  DateTime createdAt;

/// Create a copy of PostRowModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostRowModelCopyWith<_PostRowModel> get copyWith => __$PostRowModelCopyWithImpl<_PostRowModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostRowModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostRowModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.body, body) || other.body == body)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,body,likeCount,commentCount,deletedAt,createdAt);

@override
String toString() {
  return 'PostRowModel(id: $id, authorId: $authorId, body: $body, likeCount: $likeCount, commentCount: $commentCount, deletedAt: $deletedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PostRowModelCopyWith<$Res> implements $PostRowModelCopyWith<$Res> {
  factory _$PostRowModelCopyWith(_PostRowModel value, $Res Function(_PostRowModel) _then) = __$PostRowModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String authorId, String body, int likeCount, int commentCount, DateTime? deletedAt, DateTime createdAt
});




}
/// @nodoc
class __$PostRowModelCopyWithImpl<$Res>
    implements _$PostRowModelCopyWith<$Res> {
  __$PostRowModelCopyWithImpl(this._self, this._then);

  final _PostRowModel _self;
  final $Res Function(_PostRowModel) _then;

/// Create a copy of PostRowModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? authorId = null,Object? body = null,Object? likeCount = null,Object? commentCount = null,Object? deletedAt = freezed,Object? createdAt = null,}) {
  return _then(_PostRowModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$ThreadCommentModel {

 String get id; String get postId; String? get parentId; String? get authorId; String? get authorUsername; String? get authorDisplayName; String? get authorAvatarUrl; bool get authorIsVerified; String? get body; bool get isDeleted; int get depth; String get path; int get likeCount; int get replyCount; bool get likedByMe; DateTime? get editedAt; DateTime get createdAt; String get cursor;
/// Create a copy of ThreadCommentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThreadCommentModelCopyWith<ThreadCommentModel> get copyWith => _$ThreadCommentModelCopyWithImpl<ThreadCommentModel>(this as ThreadCommentModel, _$identity);

  /// Serializes this ThreadCommentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThreadCommentModel&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.path, path) || other.path == path)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,postId,parentId,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,isDeleted,depth,path,likeCount,replyCount,likedByMe,editedAt,createdAt,cursor);

@override
String toString() {
  return 'ThreadCommentModel(id: $id, postId: $postId, parentId: $parentId, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, isDeleted: $isDeleted, depth: $depth, path: $path, likeCount: $likeCount, replyCount: $replyCount, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class $ThreadCommentModelCopyWith<$Res>  {
  factory $ThreadCommentModelCopyWith(ThreadCommentModel value, $Res Function(ThreadCommentModel) _then) = _$ThreadCommentModelCopyWithImpl;
@useResult
$Res call({
 String id, String postId, String? parentId, String? authorId, String? authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String? body, bool isDeleted, int depth, String path, int likeCount, int replyCount, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor
});




}
/// @nodoc
class _$ThreadCommentModelCopyWithImpl<$Res>
    implements $ThreadCommentModelCopyWith<$Res> {
  _$ThreadCommentModelCopyWithImpl(this._self, this._then);

  final ThreadCommentModel _self;
  final $Res Function(ThreadCommentModel) _then;

/// Create a copy of ThreadCommentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? postId = null,Object? parentId = freezed,Object? authorId = freezed,Object? authorUsername = freezed,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = freezed,Object? isDeleted = null,Object? depth = null,Object? path = null,Object? likeCount = null,Object? replyCount = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String?,authorUsername: freezed == authorUsername ? _self.authorUsername : authorUsername // ignore: cast_nullable_to_non_nullable
as String?,authorDisplayName: freezed == authorDisplayName ? _self.authorDisplayName : authorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,authorAvatarUrl: freezed == authorAvatarUrl ? _self.authorAvatarUrl : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,authorIsVerified: null == authorIsVerified ? _self.authorIsVerified : authorIsVerified // ignore: cast_nullable_to_non_nullable
as bool,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ThreadCommentModel].
extension ThreadCommentModelPatterns on ThreadCommentModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThreadCommentModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThreadCommentModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThreadCommentModel value)  $default,){
final _that = this;
switch (_that) {
case _ThreadCommentModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThreadCommentModel value)?  $default,){
final _that = this;
switch (_that) {
case _ThreadCommentModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String postId,  String? parentId,  String? authorId,  String? authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String? body,  bool isDeleted,  int depth,  String path,  int likeCount,  int replyCount,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThreadCommentModel() when $default != null:
return $default(_that.id,_that.postId,_that.parentId,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.isDeleted,_that.depth,_that.path,_that.likeCount,_that.replyCount,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String postId,  String? parentId,  String? authorId,  String? authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String? body,  bool isDeleted,  int depth,  String path,  int likeCount,  int replyCount,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)  $default,) {final _that = this;
switch (_that) {
case _ThreadCommentModel():
return $default(_that.id,_that.postId,_that.parentId,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.isDeleted,_that.depth,_that.path,_that.likeCount,_that.replyCount,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String postId,  String? parentId,  String? authorId,  String? authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String? body,  bool isDeleted,  int depth,  String path,  int likeCount,  int replyCount,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)?  $default,) {final _that = this;
switch (_that) {
case _ThreadCommentModel() when $default != null:
return $default(_that.id,_that.postId,_that.parentId,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.isDeleted,_that.depth,_that.path,_that.likeCount,_that.replyCount,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ThreadCommentModel extends ThreadCommentModel {
  const _ThreadCommentModel({required this.id, required this.postId, this.parentId, this.authorId, this.authorUsername, this.authorDisplayName, this.authorAvatarUrl, this.authorIsVerified = false, this.body, this.isDeleted = false, required this.depth, required this.path, this.likeCount = 0, this.replyCount = 0, this.likedByMe = false, this.editedAt, required this.createdAt, required this.cursor}): super._();
  factory _ThreadCommentModel.fromJson(Map<String, dynamic> json) => _$ThreadCommentModelFromJson(json);

@override final  String id;
@override final  String postId;
@override final  String? parentId;
@override final  String? authorId;
@override final  String? authorUsername;
@override final  String? authorDisplayName;
@override final  String? authorAvatarUrl;
@override@JsonKey() final  bool authorIsVerified;
@override final  String? body;
@override@JsonKey() final  bool isDeleted;
@override final  int depth;
@override final  String path;
@override@JsonKey() final  int likeCount;
@override@JsonKey() final  int replyCount;
@override@JsonKey() final  bool likedByMe;
@override final  DateTime? editedAt;
@override final  DateTime createdAt;
@override final  String cursor;

/// Create a copy of ThreadCommentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThreadCommentModelCopyWith<_ThreadCommentModel> get copyWith => __$ThreadCommentModelCopyWithImpl<_ThreadCommentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThreadCommentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThreadCommentModel&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.path, path) || other.path == path)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,postId,parentId,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,isDeleted,depth,path,likeCount,replyCount,likedByMe,editedAt,createdAt,cursor);

@override
String toString() {
  return 'ThreadCommentModel(id: $id, postId: $postId, parentId: $parentId, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, isDeleted: $isDeleted, depth: $depth, path: $path, likeCount: $likeCount, replyCount: $replyCount, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$ThreadCommentModelCopyWith<$Res> implements $ThreadCommentModelCopyWith<$Res> {
  factory _$ThreadCommentModelCopyWith(_ThreadCommentModel value, $Res Function(_ThreadCommentModel) _then) = __$ThreadCommentModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String postId, String? parentId, String? authorId, String? authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String? body, bool isDeleted, int depth, String path, int likeCount, int replyCount, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor
});




}
/// @nodoc
class __$ThreadCommentModelCopyWithImpl<$Res>
    implements _$ThreadCommentModelCopyWith<$Res> {
  __$ThreadCommentModelCopyWithImpl(this._self, this._then);

  final _ThreadCommentModel _self;
  final $Res Function(_ThreadCommentModel) _then;

/// Create a copy of ThreadCommentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? postId = null,Object? parentId = freezed,Object? authorId = freezed,Object? authorUsername = freezed,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = freezed,Object? isDeleted = null,Object? depth = null,Object? path = null,Object? likeCount = null,Object? replyCount = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_ThreadCommentModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String?,authorUsername: freezed == authorUsername ? _self.authorUsername : authorUsername // ignore: cast_nullable_to_non_nullable
as String?,authorDisplayName: freezed == authorDisplayName ? _self.authorDisplayName : authorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,authorAvatarUrl: freezed == authorAvatarUrl ? _self.authorAvatarUrl : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,authorIsVerified: null == authorIsVerified ? _self.authorIsVerified : authorIsVerified // ignore: cast_nullable_to_non_nullable
as bool,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
