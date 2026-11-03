// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_post_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedPostModel {

 String get id; String get authorId; String get authorUsername; String? get authorDisplayName; String? get authorAvatarUrl; bool get authorIsVerified; String get body; String? get sentiment;@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments; int get likeCount; int get commentCount; List<String> get stockCodes; bool get likedByMe; PollModel? get poll; DateTime? get editedAt; DateTime get createdAt; String get cursor; bool? get isBookmarked; List<String>? get hashtags; bool? get isBot; bool? get authorIsOfficial; String? get moderationStatus;
/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedPostModelCopyWith<FeedPostModel> get copyWith => _$FeedPostModelCopyWithImpl<FeedPostModel>(this as FeedPostModel, _$identity);

  /// Serializes this FeedPostModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedPostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&const DeepCollectionEquality().equals(other.hashtags, hashtags)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.authorIsOfficial, authorIsOfficial) || other.authorIsOfficial == authorIsOfficial)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,sentiment,const DeepCollectionEquality().hash(attachments),likeCount,commentCount,const DeepCollectionEquality().hash(stockCodes),likedByMe,poll,editedAt,createdAt,cursor,isBookmarked,const DeepCollectionEquality().hash(hashtags),isBot,authorIsOfficial,moderationStatus]);

@override
String toString() {
  return 'FeedPostModel(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, sentiment: $sentiment, attachments: $attachments, likeCount: $likeCount, commentCount: $commentCount, stockCodes: $stockCodes, likedByMe: $likedByMe, poll: $poll, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, isBookmarked: $isBookmarked, hashtags: $hashtags, isBot: $isBot, authorIsOfficial: $authorIsOfficial, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class $FeedPostModelCopyWith<$Res>  {
  factory $FeedPostModelCopyWith(FeedPostModel value, $Res Function(FeedPostModel) _then) = _$FeedPostModelCopyWithImpl;
@useResult
$Res call({
 String id, String authorId, String authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String body, String? sentiment,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments, int likeCount, int commentCount, List<String> stockCodes, bool likedByMe, PollModel? poll, DateTime? editedAt, DateTime createdAt, String cursor, bool? isBookmarked, List<String>? hashtags, bool? isBot, bool? authorIsOfficial, String? moderationStatus
});


$PollModelCopyWith<$Res>? get poll;

}
/// @nodoc
class _$FeedPostModelCopyWithImpl<$Res>
    implements $FeedPostModelCopyWith<$Res> {
  _$FeedPostModelCopyWithImpl(this._self, this._then);

  final FeedPostModel _self;
  final $Res Function(FeedPostModel) _then;

/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? authorId = null,Object? authorUsername = null,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = null,Object? sentiment = freezed,Object? attachments = null,Object? likeCount = null,Object? commentCount = null,Object? stockCodes = null,Object? likedByMe = null,Object? poll = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,Object? isBookmarked = freezed,Object? hashtags = freezed,Object? isBot = freezed,Object? authorIsOfficial = freezed,Object? moderationStatus = freezed,}) {
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
as bool,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as PollModel?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,isBookmarked: freezed == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool?,hashtags: freezed == hashtags ? _self.hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<String>?,isBot: freezed == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool?,authorIsOfficial: freezed == authorIsOfficial ? _self.authorIsOfficial : authorIsOfficial // ignore: cast_nullable_to_non_nullable
as bool?,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollModelCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollModelCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String authorId,  String authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String body,  String? sentiment, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  PollModel? poll,  DateTime? editedAt,  DateTime createdAt,  String cursor,  bool? isBookmarked,  List<String>? hashtags,  bool? isBot,  bool? authorIsOfficial,  String? moderationStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedPostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.poll,_that.editedAt,_that.createdAt,_that.cursor,_that.isBookmarked,_that.hashtags,_that.isBot,_that.authorIsOfficial,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String authorId,  String authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String body,  String? sentiment, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  PollModel? poll,  DateTime? editedAt,  DateTime createdAt,  String cursor,  bool? isBookmarked,  List<String>? hashtags,  bool? isBot,  bool? authorIsOfficial,  String? moderationStatus)  $default,) {final _that = this;
switch (_that) {
case _FeedPostModel():
return $default(_that.id,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.poll,_that.editedAt,_that.createdAt,_that.cursor,_that.isBookmarked,_that.hashtags,_that.isBot,_that.authorIsOfficial,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String authorId,  String authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String body,  String? sentiment, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments,  int likeCount,  int commentCount,  List<String> stockCodes,  bool likedByMe,  PollModel? poll,  DateTime? editedAt,  DateTime createdAt,  String cursor,  bool? isBookmarked,  List<String>? hashtags,  bool? isBot,  bool? authorIsOfficial,  String? moderationStatus)?  $default,) {final _that = this;
switch (_that) {
case _FeedPostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.sentiment,_that.attachments,_that.likeCount,_that.commentCount,_that.stockCodes,_that.likedByMe,_that.poll,_that.editedAt,_that.createdAt,_that.cursor,_that.isBookmarked,_that.hashtags,_that.isBot,_that.authorIsOfficial,_that.moderationStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedPostModel extends FeedPostModel {
  const _FeedPostModel({required this.id, required this.authorId, required this.authorUsername, this.authorDisplayName, this.authorAvatarUrl, this.authorIsVerified = false, required this.body, this.sentiment, @JsonKey(fromJson: attachmentsFromJson) final  List<AttachmentModel> attachments = const <AttachmentModel>[], this.likeCount = 0, this.commentCount = 0, final  List<String> stockCodes = const <String>[], this.likedByMe = false, this.poll, this.editedAt, required this.createdAt, this.cursor = '', this.isBookmarked, final  List<String>? hashtags, this.isBot, this.authorIsOfficial, this.moderationStatus}): _attachments = attachments,_stockCodes = stockCodes,_hashtags = hashtags,super._();
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
@override@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments {
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
@override final  PollModel? poll;
@override final  DateTime? editedAt;
@override final  DateTime createdAt;
@override@JsonKey() final  String cursor;
@override final  bool? isBookmarked;
 final  List<String>? _hashtags;
@override List<String>? get hashtags {
  final value = _hashtags;
  if (value == null) return null;
  if (_hashtags is EqualUnmodifiableListView) return _hashtags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  bool? isBot;
@override final  bool? authorIsOfficial;
@override final  String? moderationStatus;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedPostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&const DeepCollectionEquality().equals(other._hashtags, _hashtags)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.authorIsOfficial, authorIsOfficial) || other.authorIsOfficial == authorIsOfficial)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,sentiment,const DeepCollectionEquality().hash(_attachments),likeCount,commentCount,const DeepCollectionEquality().hash(_stockCodes),likedByMe,poll,editedAt,createdAt,cursor,isBookmarked,const DeepCollectionEquality().hash(_hashtags),isBot,authorIsOfficial,moderationStatus]);

@override
String toString() {
  return 'FeedPostModel(id: $id, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, sentiment: $sentiment, attachments: $attachments, likeCount: $likeCount, commentCount: $commentCount, stockCodes: $stockCodes, likedByMe: $likedByMe, poll: $poll, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, isBookmarked: $isBookmarked, hashtags: $hashtags, isBot: $isBot, authorIsOfficial: $authorIsOfficial, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class _$FeedPostModelCopyWith<$Res> implements $FeedPostModelCopyWith<$Res> {
  factory _$FeedPostModelCopyWith(_FeedPostModel value, $Res Function(_FeedPostModel) _then) = __$FeedPostModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String authorId, String authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String body, String? sentiment,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments, int likeCount, int commentCount, List<String> stockCodes, bool likedByMe, PollModel? poll, DateTime? editedAt, DateTime createdAt, String cursor, bool? isBookmarked, List<String>? hashtags, bool? isBot, bool? authorIsOfficial, String? moderationStatus
});


@override $PollModelCopyWith<$Res>? get poll;

}
/// @nodoc
class __$FeedPostModelCopyWithImpl<$Res>
    implements _$FeedPostModelCopyWith<$Res> {
  __$FeedPostModelCopyWithImpl(this._self, this._then);

  final _FeedPostModel _self;
  final $Res Function(_FeedPostModel) _then;

/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? authorId = null,Object? authorUsername = null,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = null,Object? sentiment = freezed,Object? attachments = null,Object? likeCount = null,Object? commentCount = null,Object? stockCodes = null,Object? likedByMe = null,Object? poll = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = null,Object? isBookmarked = freezed,Object? hashtags = freezed,Object? isBot = freezed,Object? authorIsOfficial = freezed,Object? moderationStatus = freezed,}) {
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
as bool,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as PollModel?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,isBookmarked: freezed == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool?,hashtags: freezed == hashtags ? _self._hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<String>?,isBot: freezed == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool?,authorIsOfficial: freezed == authorIsOfficial ? _self.authorIsOfficial : authorIsOfficial // ignore: cast_nullable_to_non_nullable
as bool?,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of FeedPostModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollModelCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollModelCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
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

// dart format on
