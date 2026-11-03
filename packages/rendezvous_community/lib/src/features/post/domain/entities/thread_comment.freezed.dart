// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thread_comment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThreadComment {

 String get id; String get postId; String? get parentId; UserSummary? get author; String? get body; bool get isDeleted; int get depth; String get path; int get likeCount; int get replyCount; bool get likedByMe; DateTime? get editedAt; DateTime get createdAt; String get cursor; ModerationStatus? get moderationStatus;
/// Create a copy of ThreadComment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThreadCommentCopyWith<ThreadComment> get copyWith => _$ThreadCommentCopyWithImpl<ThreadComment>(this as ThreadComment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThreadComment&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.author, author) || other.author == author)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.path, path) || other.path == path)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,postId,parentId,author,body,isDeleted,depth,path,likeCount,replyCount,likedByMe,editedAt,createdAt,cursor,moderationStatus);

@override
String toString() {
  return 'ThreadComment(id: $id, postId: $postId, parentId: $parentId, author: $author, body: $body, isDeleted: $isDeleted, depth: $depth, path: $path, likeCount: $likeCount, replyCount: $replyCount, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class $ThreadCommentCopyWith<$Res>  {
  factory $ThreadCommentCopyWith(ThreadComment value, $Res Function(ThreadComment) _then) = _$ThreadCommentCopyWithImpl;
@useResult
$Res call({
 String id, String postId, String? parentId, UserSummary? author, String? body, bool isDeleted, int depth, String path, int likeCount, int replyCount, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor, ModerationStatus? moderationStatus
});


$UserSummaryCopyWith<$Res>? get author;

}
/// @nodoc
class _$ThreadCommentCopyWithImpl<$Res>
    implements $ThreadCommentCopyWith<$Res> {
  _$ThreadCommentCopyWithImpl(this._self, this._then);

  final ThreadComment _self;
  final $Res Function(ThreadComment) _then;

/// Create a copy of ThreadComment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? postId = null,Object? parentId = freezed,Object? author = freezed,Object? body = freezed,Object? isDeleted = null,Object? depth = null,Object? path = null,Object? likeCount = null,Object? replyCount = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,Object? moderationStatus = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as ModerationStatus?,
  ));
}
/// Create a copy of ThreadComment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThreadComment].
extension ThreadCommentPatterns on ThreadComment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThreadComment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThreadComment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThreadComment value)  $default,){
final _that = this;
switch (_that) {
case _ThreadComment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThreadComment value)?  $default,){
final _that = this;
switch (_that) {
case _ThreadComment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String postId,  String? parentId,  UserSummary? author,  String? body,  bool isDeleted,  int depth,  String path,  int likeCount,  int replyCount,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor,  ModerationStatus? moderationStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThreadComment() when $default != null:
return $default(_that.id,_that.postId,_that.parentId,_that.author,_that.body,_that.isDeleted,_that.depth,_that.path,_that.likeCount,_that.replyCount,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String postId,  String? parentId,  UserSummary? author,  String? body,  bool isDeleted,  int depth,  String path,  int likeCount,  int replyCount,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor,  ModerationStatus? moderationStatus)  $default,) {final _that = this;
switch (_that) {
case _ThreadComment():
return $default(_that.id,_that.postId,_that.parentId,_that.author,_that.body,_that.isDeleted,_that.depth,_that.path,_that.likeCount,_that.replyCount,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String postId,  String? parentId,  UserSummary? author,  String? body,  bool isDeleted,  int depth,  String path,  int likeCount,  int replyCount,  bool likedByMe,  DateTime? editedAt,  DateTime createdAt,  String cursor,  ModerationStatus? moderationStatus)?  $default,) {final _that = this;
switch (_that) {
case _ThreadComment() when $default != null:
return $default(_that.id,_that.postId,_that.parentId,_that.author,_that.body,_that.isDeleted,_that.depth,_that.path,_that.likeCount,_that.replyCount,_that.likedByMe,_that.editedAt,_that.createdAt,_that.cursor,_that.moderationStatus);case _:
  return null;

}
}

}

/// @nodoc


class _ThreadComment extends ThreadComment {
  const _ThreadComment({required this.id, required this.postId, this.parentId, this.author, this.body, this.isDeleted = false, required this.depth, required this.path, this.likeCount = 0, this.replyCount = 0, this.likedByMe = false, this.editedAt, required this.createdAt, required this.cursor, this.moderationStatus}): super._();
  

@override final  String id;
@override final  String postId;
@override final  String? parentId;
@override final  UserSummary? author;
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
@override final  ModerationStatus? moderationStatus;

/// Create a copy of ThreadComment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThreadCommentCopyWith<_ThreadComment> get copyWith => __$ThreadCommentCopyWithImpl<_ThreadComment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThreadComment&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.author, author) || other.author == author)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.path, path) || other.path == path)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}


@override
int get hashCode => Object.hash(runtimeType,id,postId,parentId,author,body,isDeleted,depth,path,likeCount,replyCount,likedByMe,editedAt,createdAt,cursor,moderationStatus);

@override
String toString() {
  return 'ThreadComment(id: $id, postId: $postId, parentId: $parentId, author: $author, body: $body, isDeleted: $isDeleted, depth: $depth, path: $path, likeCount: $likeCount, replyCount: $replyCount, likedByMe: $likedByMe, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class _$ThreadCommentCopyWith<$Res> implements $ThreadCommentCopyWith<$Res> {
  factory _$ThreadCommentCopyWith(_ThreadComment value, $Res Function(_ThreadComment) _then) = __$ThreadCommentCopyWithImpl;
@override @useResult
$Res call({
 String id, String postId, String? parentId, UserSummary? author, String? body, bool isDeleted, int depth, String path, int likeCount, int replyCount, bool likedByMe, DateTime? editedAt, DateTime createdAt, String cursor, ModerationStatus? moderationStatus
});


@override $UserSummaryCopyWith<$Res>? get author;

}
/// @nodoc
class __$ThreadCommentCopyWithImpl<$Res>
    implements _$ThreadCommentCopyWith<$Res> {
  __$ThreadCommentCopyWithImpl(this._self, this._then);

  final _ThreadComment _self;
  final $Res Function(_ThreadComment) _then;

/// Create a copy of ThreadComment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? postId = null,Object? parentId = freezed,Object? author = freezed,Object? body = freezed,Object? isDeleted = null,Object? depth = null,Object? path = null,Object? likeCount = null,Object? replyCount = null,Object? likedByMe = null,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,Object? moderationStatus = freezed,}) {
  return _then(_ThreadComment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as ModerationStatus?,
  ));
}

/// Create a copy of ThreadComment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}

// dart format on
