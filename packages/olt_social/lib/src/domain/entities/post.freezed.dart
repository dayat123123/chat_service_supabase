// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Attachment {

 String get path; String? get mime; int? get width; int? get height;
/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentCopyWith<Attachment> get copyWith => _$AttachmentCopyWithImpl<Attachment>(this as Attachment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Attachment&&(identical(other.path, path) || other.path == path)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,path,mime,width,height);

@override
String toString() {
  return 'Attachment(path: $path, mime: $mime, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $AttachmentCopyWith<$Res>  {
  factory $AttachmentCopyWith(Attachment value, $Res Function(Attachment) _then) = _$AttachmentCopyWithImpl;
@useResult
$Res call({
 String path, String? mime, int? width, int? height
});




}
/// @nodoc
class _$AttachmentCopyWithImpl<$Res>
    implements $AttachmentCopyWith<$Res> {
  _$AttachmentCopyWithImpl(this._self, this._then);

  final Attachment _self;
  final $Res Function(Attachment) _then;

/// Create a copy of Attachment
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


/// Adds pattern-matching-related methods to [Attachment].
extension AttachmentPatterns on Attachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Attachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Attachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Attachment value)  $default,){
final _that = this;
switch (_that) {
case _Attachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Attachment value)?  $default,){
final _that = this;
switch (_that) {
case _Attachment() when $default != null:
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
case _Attachment() when $default != null:
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
case _Attachment():
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
case _Attachment() when $default != null:
return $default(_that.path,_that.mime,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc


class _Attachment implements Attachment {
  const _Attachment({required this.path, this.mime, this.width, this.height});
  

@override final  String path;
@override final  String? mime;
@override final  int? width;
@override final  int? height;

/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentCopyWith<_Attachment> get copyWith => __$AttachmentCopyWithImpl<_Attachment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Attachment&&(identical(other.path, path) || other.path == path)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,path,mime,width,height);

@override
String toString() {
  return 'Attachment(path: $path, mime: $mime, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$AttachmentCopyWith<$Res> implements $AttachmentCopyWith<$Res> {
  factory _$AttachmentCopyWith(_Attachment value, $Res Function(_Attachment) _then) = __$AttachmentCopyWithImpl;
@override @useResult
$Res call({
 String path, String? mime, int? width, int? height
});




}
/// @nodoc
class __$AttachmentCopyWithImpl<$Res>
    implements _$AttachmentCopyWith<$Res> {
  __$AttachmentCopyWithImpl(this._self, this._then);

  final _Attachment _self;
  final $Res Function(_Attachment) _then;

/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? mime = freezed,Object? width = freezed,Object? height = freezed,}) {
  return _then(_Attachment(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$Post {

 String get id; UserSummary get author; String get body; Sentiment? get sentiment; List<Attachment> get attachments; int get likeCount; int get commentCount; List<String> get stockCodes; bool get likedByMe; DateTime? get editedAt; DateTime get createdAt;/// Cursor keyset untuk mengambil halaman setelah post ini.
 String get cursor;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}


@override
int get hashCode => Object.hash(runtimeType,id,author,body,sentiment,const DeepCollectionEquality().hash(attachments),likeCount,commentCount,const DeepCollectionEquality().hash(stockCodes),likedByMe,editedAt,createdAt,cursor);

@override
String toString() {
  return 'Post(id: $id, author: $author, body: $body, sentiment: $sentiment, attachments: $attachments, likeCount: $likeCount, commentCount: $commentCount, stockCodes: $stockCodes, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id, UserSummary author, String body, Sentiment? sentiment, List<Attachment> attachments, int likeCount, int commentCount, List<String> stockCodes, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor
});


$UserSummaryCopyWith<$Res> get author;

}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = null,Object? body = null,Object? sentiment = freezed,Object? attachments = null,Object? likeCount = null,Object? commentCount = null,Object? stockCodes = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as Sentiment?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,stockCodes: null == stockCodes ? _self.stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get author {
  
  return $UserSummaryCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  UserSummary author,  String body,  Sentiment? sentiment,  List<Attachment> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.author,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  UserSummary author,  String body,  Sentiment? sentiment,  List<Attachment> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.author,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  UserSummary author,  String body,  Sentiment? sentiment,  List<Attachment> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.author,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor);case _:
  return null;

}
}

}

/// @nodoc


class _Post implements Post {
  const _Post({required this.id, required this.author, required this.body, this.sentiment, final  List<Attachment> attachments = const <Attachment>[], this.likeCount = 0, this.commentCount = 0, final  List<String> stockCodes = const <String>[], this.likedByMe = false, this.editedAt, required this.createdAt, required this.cursor}): _attachments = attachments,_stockCodes = stockCodes;
  

@override final  String id;
@override final  UserSummary author;
@override final  String body;
@override final  Sentiment? sentiment;
 final  List<Attachment> _attachments;
@override@JsonKey() List<Attachment> get attachments {
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
/// Cursor keyset untuk mengambil halaman setelah post ini.
@override final  String cursor;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}


@override
int get hashCode => Object.hash(runtimeType,id,author,body,sentiment,const DeepCollectionEquality().hash(_attachments),likeCount,commentCount,const DeepCollectionEquality().hash(_stockCodes),likedByMe,editedAt,createdAt,cursor);

@override
String toString() {
  return 'Post(id: $id, author: $author, body: $body, sentiment: $sentiment, attachments: $attachments, likeCount: $likeCount, commentCount: $commentCount, stockCodes: $stockCodes, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id, UserSummary author, String body, Sentiment? sentiment, List<Attachment> attachments, int likeCount, int commentCount, List<String> stockCodes, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor
});


@override $UserSummaryCopyWith<$Res> get author;

}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = null,Object? body = null,Object? sentiment = freezed,Object? attachments = null,Object? likeCount = null,Object? commentCount = null,Object? stockCodes = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as Sentiment?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,stockCodes: null == stockCodes ? _self._stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get author {
  
  return $UserSummaryCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}

/// @nodoc
mixin _$FeedScope {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedScope);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FeedScope()';
}


}

/// @nodoc
class $FeedScopeCopyWith<$Res>  {
$FeedScopeCopyWith(FeedScope _, $Res Function(FeedScope) __);
}


/// Adds pattern-matching-related methods to [FeedScope].
extension FeedScopePatterns on FeedScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( GlobalFeedScope value)?  global,TResult Function( FollowingFeedScope value)?  following,TResult Function( StockFeedScope value)?  stock,TResult Function( UserFeedScope value)?  user,required TResult orElse(),}){
final _that = this;
switch (_that) {
case GlobalFeedScope() when global != null:
return global(_that);case FollowingFeedScope() when following != null:
return following(_that);case StockFeedScope() when stock != null:
return stock(_that);case UserFeedScope() when user != null:
return user(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( GlobalFeedScope value)  global,required TResult Function( FollowingFeedScope value)  following,required TResult Function( StockFeedScope value)  stock,required TResult Function( UserFeedScope value)  user,}){
final _that = this;
switch (_that) {
case GlobalFeedScope():
return global(_that);case FollowingFeedScope():
return following(_that);case StockFeedScope():
return stock(_that);case UserFeedScope():
return user(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( GlobalFeedScope value)?  global,TResult? Function( FollowingFeedScope value)?  following,TResult? Function( StockFeedScope value)?  stock,TResult? Function( UserFeedScope value)?  user,}){
final _that = this;
switch (_that) {
case GlobalFeedScope() when global != null:
return global(_that);case FollowingFeedScope() when following != null:
return following(_that);case StockFeedScope() when stock != null:
return stock(_that);case UserFeedScope() when user != null:
return user(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  global,TResult Function()?  following,TResult Function( String code)?  stock,TResult Function( String userId)?  user,required TResult orElse(),}) {final _that = this;
switch (_that) {
case GlobalFeedScope() when global != null:
return global();case FollowingFeedScope() when following != null:
return following();case StockFeedScope() when stock != null:
return stock(_that.code);case UserFeedScope() when user != null:
return user(_that.userId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  global,required TResult Function()  following,required TResult Function( String code)  stock,required TResult Function( String userId)  user,}) {final _that = this;
switch (_that) {
case GlobalFeedScope():
return global();case FollowingFeedScope():
return following();case StockFeedScope():
return stock(_that.code);case UserFeedScope():
return user(_that.userId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  global,TResult? Function()?  following,TResult? Function( String code)?  stock,TResult? Function( String userId)?  user,}) {final _that = this;
switch (_that) {
case GlobalFeedScope() when global != null:
return global();case FollowingFeedScope() when following != null:
return following();case StockFeedScope() when stock != null:
return stock(_that.code);case UserFeedScope() when user != null:
return user(_that.userId);case _:
  return null;

}
}

}

/// @nodoc


class GlobalFeedScope implements FeedScope {
  const GlobalFeedScope();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalFeedScope);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FeedScope.global()';
}


}




/// @nodoc


class FollowingFeedScope implements FeedScope {
  const FollowingFeedScope();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowingFeedScope);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FeedScope.following()';
}


}




/// @nodoc


class StockFeedScope implements FeedScope {
  const StockFeedScope(this.code);
  

 final  String code;

/// Create a copy of FeedScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockFeedScopeCopyWith<StockFeedScope> get copyWith => _$StockFeedScopeCopyWithImpl<StockFeedScope>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockFeedScope&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode => Object.hash(runtimeType,code);

@override
String toString() {
  return 'FeedScope.stock(code: $code)';
}


}

/// @nodoc
abstract mixin class $StockFeedScopeCopyWith<$Res> implements $FeedScopeCopyWith<$Res> {
  factory $StockFeedScopeCopyWith(StockFeedScope value, $Res Function(StockFeedScope) _then) = _$StockFeedScopeCopyWithImpl;
@useResult
$Res call({
 String code
});




}
/// @nodoc
class _$StockFeedScopeCopyWithImpl<$Res>
    implements $StockFeedScopeCopyWith<$Res> {
  _$StockFeedScopeCopyWithImpl(this._self, this._then);

  final StockFeedScope _self;
  final $Res Function(StockFeedScope) _then;

/// Create a copy of FeedScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(StockFeedScope(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UserFeedScope implements FeedScope {
  const UserFeedScope(this.userId);
  

 final  String userId;

/// Create a copy of FeedScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserFeedScopeCopyWith<UserFeedScope> get copyWith => _$UserFeedScopeCopyWithImpl<UserFeedScope>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserFeedScope&&(identical(other.userId, userId) || other.userId == userId));
}


@override
int get hashCode => Object.hash(runtimeType,userId);

@override
String toString() {
  return 'FeedScope.user(userId: $userId)';
}


}

/// @nodoc
abstract mixin class $UserFeedScopeCopyWith<$Res> implements $FeedScopeCopyWith<$Res> {
  factory $UserFeedScopeCopyWith(UserFeedScope value, $Res Function(UserFeedScope) _then) = _$UserFeedScopeCopyWithImpl;
@useResult
$Res call({
 String userId
});




}
/// @nodoc
class _$UserFeedScopeCopyWithImpl<$Res>
    implements $UserFeedScopeCopyWith<$Res> {
  _$UserFeedScopeCopyWithImpl(this._self, this._then);

  final UserFeedScope _self;
  final $Res Function(UserFeedScope) _then;

/// Create a copy of FeedScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = null,}) {
  return _then(UserFeedScope(
null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
