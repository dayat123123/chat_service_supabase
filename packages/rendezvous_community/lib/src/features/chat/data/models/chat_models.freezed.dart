// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageReactionModel {

 String get emoji; int get count; bool get me;
/// Create a copy of MessageReactionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReactionModelCopyWith<MessageReactionModel> get copyWith => _$MessageReactionModelCopyWithImpl<MessageReactionModel>(this as MessageReactionModel, _$identity);

  /// Serializes this MessageReactionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReactionModel&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.count, count) || other.count == count)&&(identical(other.me, me) || other.me == me));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,emoji,count,me);

@override
String toString() {
  return 'MessageReactionModel(emoji: $emoji, count: $count, me: $me)';
}


}

/// @nodoc
abstract mixin class $MessageReactionModelCopyWith<$Res>  {
  factory $MessageReactionModelCopyWith(MessageReactionModel value, $Res Function(MessageReactionModel) _then) = _$MessageReactionModelCopyWithImpl;
@useResult
$Res call({
 String emoji, int count, bool me
});




}
/// @nodoc
class _$MessageReactionModelCopyWithImpl<$Res>
    implements $MessageReactionModelCopyWith<$Res> {
  _$MessageReactionModelCopyWithImpl(this._self, this._then);

  final MessageReactionModel _self;
  final $Res Function(MessageReactionModel) _then;

/// Create a copy of MessageReactionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? emoji = null,Object? count = null,Object? me = null,}) {
  return _then(_self.copyWith(
emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageReactionModel].
extension MessageReactionModelPatterns on MessageReactionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageReactionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageReactionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageReactionModel value)  $default,){
final _that = this;
switch (_that) {
case _MessageReactionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageReactionModel value)?  $default,){
final _that = this;
switch (_that) {
case _MessageReactionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String emoji,  int count,  bool me)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageReactionModel() when $default != null:
return $default(_that.emoji,_that.count,_that.me);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String emoji,  int count,  bool me)  $default,) {final _that = this;
switch (_that) {
case _MessageReactionModel():
return $default(_that.emoji,_that.count,_that.me);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String emoji,  int count,  bool me)?  $default,) {final _that = this;
switch (_that) {
case _MessageReactionModel() when $default != null:
return $default(_that.emoji,_that.count,_that.me);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageReactionModel extends MessageReactionModel {
  const _MessageReactionModel({required this.emoji, this.count = 0, this.me = false}): super._();
  factory _MessageReactionModel.fromJson(Map<String, dynamic> json) => _$MessageReactionModelFromJson(json);

@override final  String emoji;
@override@JsonKey() final  int count;
@override@JsonKey() final  bool me;

/// Create a copy of MessageReactionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageReactionModelCopyWith<_MessageReactionModel> get copyWith => __$MessageReactionModelCopyWithImpl<_MessageReactionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageReactionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageReactionModel&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.count, count) || other.count == count)&&(identical(other.me, me) || other.me == me));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,emoji,count,me);

@override
String toString() {
  return 'MessageReactionModel(emoji: $emoji, count: $count, me: $me)';
}


}

/// @nodoc
abstract mixin class _$MessageReactionModelCopyWith<$Res> implements $MessageReactionModelCopyWith<$Res> {
  factory _$MessageReactionModelCopyWith(_MessageReactionModel value, $Res Function(_MessageReactionModel) _then) = __$MessageReactionModelCopyWithImpl;
@override @useResult
$Res call({
 String emoji, int count, bool me
});




}
/// @nodoc
class __$MessageReactionModelCopyWithImpl<$Res>
    implements _$MessageReactionModelCopyWith<$Res> {
  __$MessageReactionModelCopyWithImpl(this._self, this._then);

  final _MessageReactionModel _self;
  final $Res Function(_MessageReactionModel) _then;

/// Create a copy of MessageReactionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? emoji = null,Object? count = null,Object? me = null,}) {
  return _then(_MessageReactionModel(
emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SharedPostModel {

 String get postId; bool get available; String? get authorId; String? get authorUsername; String? get authorDisplayName; String? get authorAvatarUrl; bool get authorIsVerified; String? get body;@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments; String? get sentiment; List<String> get stockCodes; int get likeCount; int get commentCount; DateTime? get createdAt;
/// Create a copy of SharedPostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SharedPostModelCopyWith<SharedPostModel> get copyWith => _$SharedPostModelCopyWithImpl<SharedPostModel>(this as SharedPostModel, _$identity);

  /// Serializes this SharedPostModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SharedPostModel&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.available, available) || other.available == available)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,postId,available,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,const DeepCollectionEquality().hash(attachments),sentiment,const DeepCollectionEquality().hash(stockCodes),likeCount,commentCount,createdAt);

@override
String toString() {
  return 'SharedPostModel(postId: $postId, available: $available, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, attachments: $attachments, sentiment: $sentiment, stockCodes: $stockCodes, likeCount: $likeCount, commentCount: $commentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SharedPostModelCopyWith<$Res>  {
  factory $SharedPostModelCopyWith(SharedPostModel value, $Res Function(SharedPostModel) _then) = _$SharedPostModelCopyWithImpl;
@useResult
$Res call({
 String postId, bool available, String? authorId, String? authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String? body,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments, String? sentiment, List<String> stockCodes, int likeCount, int commentCount, DateTime? createdAt
});




}
/// @nodoc
class _$SharedPostModelCopyWithImpl<$Res>
    implements $SharedPostModelCopyWith<$Res> {
  _$SharedPostModelCopyWithImpl(this._self, this._then);

  final SharedPostModel _self;
  final $Res Function(SharedPostModel) _then;

/// Create a copy of SharedPostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? postId = null,Object? available = null,Object? authorId = freezed,Object? authorUsername = freezed,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = freezed,Object? attachments = null,Object? sentiment = freezed,Object? stockCodes = null,Object? likeCount = null,Object? commentCount = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String?,authorUsername: freezed == authorUsername ? _self.authorUsername : authorUsername // ignore: cast_nullable_to_non_nullable
as String?,authorDisplayName: freezed == authorDisplayName ? _self.authorDisplayName : authorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,authorAvatarUrl: freezed == authorAvatarUrl ? _self.authorAvatarUrl : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,authorIsVerified: null == authorIsVerified ? _self.authorIsVerified : authorIsVerified // ignore: cast_nullable_to_non_nullable
as bool,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as String?,stockCodes: null == stockCodes ? _self.stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SharedPostModel].
extension SharedPostModelPatterns on SharedPostModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SharedPostModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SharedPostModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SharedPostModel value)  $default,){
final _that = this;
switch (_that) {
case _SharedPostModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SharedPostModel value)?  $default,){
final _that = this;
switch (_that) {
case _SharedPostModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String postId,  bool available,  String? authorId,  String? authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String? body, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments,  String? sentiment,  List<String> stockCodes,  int likeCount,  int commentCount,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SharedPostModel() when $default != null:
return $default(_that.postId,_that.available,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.attachments,_that.sentiment,_that.stockCodes,_that.likeCount,_that.commentCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String postId,  bool available,  String? authorId,  String? authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String? body, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments,  String? sentiment,  List<String> stockCodes,  int likeCount,  int commentCount,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _SharedPostModel():
return $default(_that.postId,_that.available,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.attachments,_that.sentiment,_that.stockCodes,_that.likeCount,_that.commentCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String postId,  bool available,  String? authorId,  String? authorUsername,  String? authorDisplayName,  String? authorAvatarUrl,  bool authorIsVerified,  String? body, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments,  String? sentiment,  List<String> stockCodes,  int likeCount,  int commentCount,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SharedPostModel() when $default != null:
return $default(_that.postId,_that.available,_that.authorId,_that.authorUsername,_that.authorDisplayName,_that.authorAvatarUrl,_that.authorIsVerified,_that.body,_that.attachments,_that.sentiment,_that.stockCodes,_that.likeCount,_that.commentCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SharedPostModel extends SharedPostModel {
  const _SharedPostModel({required this.postId, this.available = false, this.authorId, this.authorUsername, this.authorDisplayName, this.authorAvatarUrl, this.authorIsVerified = false, this.body, @JsonKey(fromJson: attachmentsFromJson) final  List<AttachmentModel> attachments = const <AttachmentModel>[], this.sentiment, final  List<String> stockCodes = const <String>[], this.likeCount = 0, this.commentCount = 0, this.createdAt}): _attachments = attachments,_stockCodes = stockCodes,super._();
  factory _SharedPostModel.fromJson(Map<String, dynamic> json) => _$SharedPostModelFromJson(json);

@override final  String postId;
@override@JsonKey() final  bool available;
@override final  String? authorId;
@override final  String? authorUsername;
@override final  String? authorDisplayName;
@override final  String? authorAvatarUrl;
@override@JsonKey() final  bool authorIsVerified;
@override final  String? body;
 final  List<AttachmentModel> _attachments;
@override@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override final  String? sentiment;
 final  List<String> _stockCodes;
@override@JsonKey() List<String> get stockCodes {
  if (_stockCodes is EqualUnmodifiableListView) return _stockCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stockCodes);
}

@override@JsonKey() final  int likeCount;
@override@JsonKey() final  int commentCount;
@override final  DateTime? createdAt;

/// Create a copy of SharedPostModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SharedPostModelCopyWith<_SharedPostModel> get copyWith => __$SharedPostModelCopyWithImpl<_SharedPostModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SharedPostModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SharedPostModel&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.available, available) || other.available == available)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorUsername, authorUsername) || other.authorUsername == authorUsername)&&(identical(other.authorDisplayName, authorDisplayName) || other.authorDisplayName == authorDisplayName)&&(identical(other.authorAvatarUrl, authorAvatarUrl) || other.authorAvatarUrl == authorAvatarUrl)&&(identical(other.authorIsVerified, authorIsVerified) || other.authorIsVerified == authorIsVerified)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,postId,available,authorId,authorUsername,authorDisplayName,authorAvatarUrl,authorIsVerified,body,const DeepCollectionEquality().hash(_attachments),sentiment,const DeepCollectionEquality().hash(_stockCodes),likeCount,commentCount,createdAt);

@override
String toString() {
  return 'SharedPostModel(postId: $postId, available: $available, authorId: $authorId, authorUsername: $authorUsername, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorIsVerified: $authorIsVerified, body: $body, attachments: $attachments, sentiment: $sentiment, stockCodes: $stockCodes, likeCount: $likeCount, commentCount: $commentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SharedPostModelCopyWith<$Res> implements $SharedPostModelCopyWith<$Res> {
  factory _$SharedPostModelCopyWith(_SharedPostModel value, $Res Function(_SharedPostModel) _then) = __$SharedPostModelCopyWithImpl;
@override @useResult
$Res call({
 String postId, bool available, String? authorId, String? authorUsername, String? authorDisplayName, String? authorAvatarUrl, bool authorIsVerified, String? body,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments, String? sentiment, List<String> stockCodes, int likeCount, int commentCount, DateTime? createdAt
});




}
/// @nodoc
class __$SharedPostModelCopyWithImpl<$Res>
    implements _$SharedPostModelCopyWith<$Res> {
  __$SharedPostModelCopyWithImpl(this._self, this._then);

  final _SharedPostModel _self;
  final $Res Function(_SharedPostModel) _then;

/// Create a copy of SharedPostModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? postId = null,Object? available = null,Object? authorId = freezed,Object? authorUsername = freezed,Object? authorDisplayName = freezed,Object? authorAvatarUrl = freezed,Object? authorIsVerified = null,Object? body = freezed,Object? attachments = null,Object? sentiment = freezed,Object? stockCodes = null,Object? likeCount = null,Object? commentCount = null,Object? createdAt = freezed,}) {
  return _then(_SharedPostModel(
postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,authorId: freezed == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String?,authorUsername: freezed == authorUsername ? _self.authorUsername : authorUsername // ignore: cast_nullable_to_non_nullable
as String?,authorDisplayName: freezed == authorDisplayName ? _self.authorDisplayName : authorDisplayName // ignore: cast_nullable_to_non_nullable
as String?,authorAvatarUrl: freezed == authorAvatarUrl ? _self.authorAvatarUrl : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,authorIsVerified: null == authorIsVerified ? _self.authorIsVerified : authorIsVerified // ignore: cast_nullable_to_non_nullable
as bool,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as String?,stockCodes: null == stockCodes ? _self._stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ChatMessageModel {

 String get id; String get roomId; String? get senderId; String? get senderUsername; String? get senderDisplayName; String? get senderAvatarUrl; String? get body; bool get isDeleted; String? get replyToId; String? get replyToBody; String? get replyToSenderUsername;@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments;@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? get sharedPostId;@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> get stockCodes; String? get clientId; DateTime? get editedAt; DateTime get createdAt; String? get cursor; String? get kind; String? get senderRole; String? get sessionId; Map<String, dynamic> get payload; List<MessageReactionModel>? get reactions; SharedPostModel? get sharedPost; String? get moderationStatus;
/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatMessageModelCopyWith<ChatMessageModel> get copyWith => _$ChatMessageModelCopyWithImpl<ChatMessageModel>(this as ChatMessageModel, _$identity);

  /// Serializes this ChatMessageModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessageModel&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderUsername, senderUsername) || other.senderUsername == senderUsername)&&(identical(other.senderDisplayName, senderDisplayName) || other.senderDisplayName == senderDisplayName)&&(identical(other.senderAvatarUrl, senderAvatarUrl) || other.senderAvatarUrl == senderAvatarUrl)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.sharedPostId, sharedPostId) || other.sharedPostId == sharedPostId)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other.payload, payload)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.sharedPost, sharedPost) || other.sharedPost == sharedPost)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,roomId,senderId,senderUsername,senderDisplayName,senderAvatarUrl,body,isDeleted,replyToId,replyToBody,replyToSenderUsername,const DeepCollectionEquality().hash(attachments),sharedPostId,const DeepCollectionEquality().hash(stockCodes),clientId,editedAt,createdAt,cursor,kind,senderRole,sessionId,const DeepCollectionEquality().hash(payload),const DeepCollectionEquality().hash(reactions),sharedPost,moderationStatus]);

@override
String toString() {
  return 'ChatMessageModel(id: $id, roomId: $roomId, senderId: $senderId, senderUsername: $senderUsername, senderDisplayName: $senderDisplayName, senderAvatarUrl: $senderAvatarUrl, body: $body, isDeleted: $isDeleted, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, attachments: $attachments, sharedPostId: $sharedPostId, stockCodes: $stockCodes, clientId: $clientId, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, kind: $kind, senderRole: $senderRole, sessionId: $sessionId, payload: $payload, reactions: $reactions, sharedPost: $sharedPost, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class $ChatMessageModelCopyWith<$Res>  {
  factory $ChatMessageModelCopyWith(ChatMessageModel value, $Res Function(ChatMessageModel) _then) = _$ChatMessageModelCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String? senderId, String? senderUsername, String? senderDisplayName, String? senderAvatarUrl, String? body, bool isDeleted, String? replyToId, String? replyToBody, String? replyToSenderUsername,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments,@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? sharedPostId,@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> stockCodes, String? clientId, DateTime? editedAt, DateTime createdAt, String? cursor, String? kind, String? senderRole, String? sessionId, Map<String, dynamic> payload, List<MessageReactionModel>? reactions, SharedPostModel? sharedPost, String? moderationStatus
});


$SharedPostModelCopyWith<$Res>? get sharedPost;

}
/// @nodoc
class _$ChatMessageModelCopyWithImpl<$Res>
    implements $ChatMessageModelCopyWith<$Res> {
  _$ChatMessageModelCopyWithImpl(this._self, this._then);

  final ChatMessageModel _self;
  final $Res Function(ChatMessageModel) _then;

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? senderUsername = freezed,Object? senderDisplayName = freezed,Object? senderAvatarUrl = freezed,Object? body = freezed,Object? isDeleted = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? attachments = null,Object? sharedPostId = freezed,Object? stockCodes = null,Object? clientId = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = freezed,Object? kind = freezed,Object? senderRole = freezed,Object? sessionId = freezed,Object? payload = null,Object? reactions = freezed,Object? sharedPost = freezed,Object? moderationStatus = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderUsername: freezed == senderUsername ? _self.senderUsername : senderUsername // ignore: cast_nullable_to_non_nullable
as String?,senderDisplayName: freezed == senderDisplayName ? _self.senderDisplayName : senderDisplayName // ignore: cast_nullable_to_non_nullable
as String?,senderAvatarUrl: freezed == senderAvatarUrl ? _self.senderAvatarUrl : senderAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToBody: freezed == replyToBody ? _self.replyToBody : replyToBody // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderUsername: freezed == replyToSenderUsername ? _self.replyToSenderUsername : replyToSenderUsername // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,sharedPostId: freezed == sharedPostId ? _self.sharedPostId : sharedPostId // ignore: cast_nullable_to_non_nullable
as String?,stockCodes: null == stockCodes ? _self.stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reactions: freezed == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReactionModel>?,sharedPost: freezed == sharedPost ? _self.sharedPost : sharedPost // ignore: cast_nullable_to_non_nullable
as SharedPostModel?,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SharedPostModelCopyWith<$Res>? get sharedPost {
    if (_self.sharedPost == null) {
    return null;
  }

  return $SharedPostModelCopyWith<$Res>(_self.sharedPost!, (value) {
    return _then(_self.copyWith(sharedPost: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatMessageModel].
extension ChatMessageModelPatterns on ChatMessageModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessageModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessageModel value)  $default,){
final _that = this;
switch (_that) {
case _ChatMessageModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessageModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  String? senderUsername,  String? senderDisplayName,  String? senderAvatarUrl,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments, @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false)  String? sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)  List<String> stockCodes,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  String? kind,  String? senderRole,  String? sessionId,  Map<String, dynamic> payload,  List<MessageReactionModel>? reactions,  SharedPostModel? sharedPost,  String? moderationStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.senderUsername,_that.senderDisplayName,_that.senderAvatarUrl,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.sharedPostId,_that.stockCodes,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.kind,_that.senderRole,_that.sessionId,_that.payload,_that.reactions,_that.sharedPost,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  String? senderUsername,  String? senderDisplayName,  String? senderAvatarUrl,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments, @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false)  String? sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)  List<String> stockCodes,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  String? kind,  String? senderRole,  String? sessionId,  Map<String, dynamic> payload,  List<MessageReactionModel>? reactions,  SharedPostModel? sharedPost,  String? moderationStatus)  $default,) {final _that = this;
switch (_that) {
case _ChatMessageModel():
return $default(_that.id,_that.roomId,_that.senderId,_that.senderUsername,_that.senderDisplayName,_that.senderAvatarUrl,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.sharedPostId,_that.stockCodes,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.kind,_that.senderRole,_that.sessionId,_that.payload,_that.reactions,_that.sharedPost,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String? senderId,  String? senderUsername,  String? senderDisplayName,  String? senderAvatarUrl,  String? body,  bool isDeleted,  String? replyToId,  String? replyToBody,  String? replyToSenderUsername, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments, @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false)  String? sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)  List<String> stockCodes,  String? clientId,  DateTime? editedAt,  DateTime createdAt,  String? cursor,  String? kind,  String? senderRole,  String? sessionId,  Map<String, dynamic> payload,  List<MessageReactionModel>? reactions,  SharedPostModel? sharedPost,  String? moderationStatus)?  $default,) {final _that = this;
switch (_that) {
case _ChatMessageModel() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.senderUsername,_that.senderDisplayName,_that.senderAvatarUrl,_that.body,_that.isDeleted,_that.replyToId,_that.replyToBody,_that.replyToSenderUsername,_that.attachments,_that.sharedPostId,_that.stockCodes,_that.clientId,_that.editedAt,_that.createdAt,_that.cursor,_that.kind,_that.senderRole,_that.sessionId,_that.payload,_that.reactions,_that.sharedPost,_that.moderationStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatMessageModel extends ChatMessageModel {
  const _ChatMessageModel({required this.id, required this.roomId, this.senderId, this.senderUsername, this.senderDisplayName, this.senderAvatarUrl, this.body, this.isDeleted = false, this.replyToId, this.replyToBody, this.replyToSenderUsername, @JsonKey(fromJson: attachmentsFromJson) final  List<AttachmentModel> attachments = const <AttachmentModel>[], @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) this.sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) final  List<String> stockCodes = const <String>[], this.clientId, this.editedAt, required this.createdAt, this.cursor, this.kind, this.senderRole, this.sessionId, final  Map<String, dynamic> payload = const <String, dynamic>{}, final  List<MessageReactionModel>? reactions, this.sharedPost, this.moderationStatus}): _attachments = attachments,_stockCodes = stockCodes,_payload = payload,_reactions = reactions,super._();
  factory _ChatMessageModel.fromJson(Map<String, dynamic> json) => _$ChatMessageModelFromJson(json);

@override final  String id;
@override final  String roomId;
@override final  String? senderId;
@override final  String? senderUsername;
@override final  String? senderDisplayName;
@override final  String? senderAvatarUrl;
@override final  String? body;
@override@JsonKey() final  bool isDeleted;
@override final  String? replyToId;
@override final  String? replyToBody;
@override final  String? replyToSenderUsername;
 final  List<AttachmentModel> _attachments;
@override@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) final  String? sharedPostId;
 final  List<String> _stockCodes;
@override@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> get stockCodes {
  if (_stockCodes is EqualUnmodifiableListView) return _stockCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stockCodes);
}

@override final  String? clientId;
@override final  DateTime? editedAt;
@override final  DateTime createdAt;
@override final  String? cursor;
@override final  String? kind;
@override final  String? senderRole;
@override final  String? sessionId;
 final  Map<String, dynamic> _payload;
@override@JsonKey() Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

 final  List<MessageReactionModel>? _reactions;
@override List<MessageReactionModel>? get reactions {
  final value = _reactions;
  if (value == null) return null;
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  SharedPostModel? sharedPost;
@override final  String? moderationStatus;

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageModelCopyWith<_ChatMessageModel> get copyWith => __$ChatMessageModelCopyWithImpl<_ChatMessageModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatMessageModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessageModel&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderUsername, senderUsername) || other.senderUsername == senderUsername)&&(identical(other.senderDisplayName, senderDisplayName) || other.senderDisplayName == senderDisplayName)&&(identical(other.senderAvatarUrl, senderAvatarUrl) || other.senderAvatarUrl == senderAvatarUrl)&&(identical(other.body, body) || other.body == body)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToBody, replyToBody) || other.replyToBody == replyToBody)&&(identical(other.replyToSenderUsername, replyToSenderUsername) || other.replyToSenderUsername == replyToSenderUsername)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.sharedPostId, sharedPostId) || other.sharedPostId == sharedPostId)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other._payload, _payload)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.sharedPost, sharedPost) || other.sharedPost == sharedPost)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,roomId,senderId,senderUsername,senderDisplayName,senderAvatarUrl,body,isDeleted,replyToId,replyToBody,replyToSenderUsername,const DeepCollectionEquality().hash(_attachments),sharedPostId,const DeepCollectionEquality().hash(_stockCodes),clientId,editedAt,createdAt,cursor,kind,senderRole,sessionId,const DeepCollectionEquality().hash(_payload),const DeepCollectionEquality().hash(_reactions),sharedPost,moderationStatus]);

@override
String toString() {
  return 'ChatMessageModel(id: $id, roomId: $roomId, senderId: $senderId, senderUsername: $senderUsername, senderDisplayName: $senderDisplayName, senderAvatarUrl: $senderAvatarUrl, body: $body, isDeleted: $isDeleted, replyToId: $replyToId, replyToBody: $replyToBody, replyToSenderUsername: $replyToSenderUsername, attachments: $attachments, sharedPostId: $sharedPostId, stockCodes: $stockCodes, clientId: $clientId, editedAt: $editedAt, createdAt: $createdAt, cursor: $cursor, kind: $kind, senderRole: $senderRole, sessionId: $sessionId, payload: $payload, reactions: $reactions, sharedPost: $sharedPost, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageModelCopyWith<$Res> implements $ChatMessageModelCopyWith<$Res> {
  factory _$ChatMessageModelCopyWith(_ChatMessageModel value, $Res Function(_ChatMessageModel) _then) = __$ChatMessageModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String? senderId, String? senderUsername, String? senderDisplayName, String? senderAvatarUrl, String? body, bool isDeleted, String? replyToId, String? replyToBody, String? replyToSenderUsername,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments,@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? sharedPostId,@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> stockCodes, String? clientId, DateTime? editedAt, DateTime createdAt, String? cursor, String? kind, String? senderRole, String? sessionId, Map<String, dynamic> payload, List<MessageReactionModel>? reactions, SharedPostModel? sharedPost, String? moderationStatus
});


@override $SharedPostModelCopyWith<$Res>? get sharedPost;

}
/// @nodoc
class __$ChatMessageModelCopyWithImpl<$Res>
    implements _$ChatMessageModelCopyWith<$Res> {
  __$ChatMessageModelCopyWithImpl(this._self, this._then);

  final _ChatMessageModel _self;
  final $Res Function(_ChatMessageModel) _then;

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? senderUsername = freezed,Object? senderDisplayName = freezed,Object? senderAvatarUrl = freezed,Object? body = freezed,Object? isDeleted = null,Object? replyToId = freezed,Object? replyToBody = freezed,Object? replyToSenderUsername = freezed,Object? attachments = null,Object? sharedPostId = freezed,Object? stockCodes = null,Object? clientId = freezed,Object? editedAt = freezed,Object? createdAt = null,Object? cursor = freezed,Object? kind = freezed,Object? senderRole = freezed,Object? sessionId = freezed,Object? payload = null,Object? reactions = freezed,Object? sharedPost = freezed,Object? moderationStatus = freezed,}) {
  return _then(_ChatMessageModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderUsername: freezed == senderUsername ? _self.senderUsername : senderUsername // ignore: cast_nullable_to_non_nullable
as String?,senderDisplayName: freezed == senderDisplayName ? _self.senderDisplayName : senderDisplayName // ignore: cast_nullable_to_non_nullable
as String?,senderAvatarUrl: freezed == senderAvatarUrl ? _self.senderAvatarUrl : senderAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToBody: freezed == replyToBody ? _self.replyToBody : replyToBody // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderUsername: freezed == replyToSenderUsername ? _self.replyToSenderUsername : replyToSenderUsername // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,sharedPostId: freezed == sharedPostId ? _self.sharedPostId : sharedPostId // ignore: cast_nullable_to_non_nullable
as String?,stockCodes: null == stockCodes ? _self._stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reactions: freezed == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReactionModel>?,sharedPost: freezed == sharedPost ? _self.sharedPost : sharedPost // ignore: cast_nullable_to_non_nullable
as SharedPostModel?,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ChatMessageModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SharedPostModelCopyWith<$Res>? get sharedPost {
    if (_self.sharedPost == null) {
    return null;
  }

  return $SharedPostModelCopyWith<$Res>(_self.sharedPost!, (value) {
    return _then(_self.copyWith(sharedPost: value));
  });
}
}


/// @nodoc
mixin _$MessageRowModel {

 String get id; String get roomId; String? get senderId; String get body; String? get replyToId;@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments;@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? get sharedPostId;@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> get stockCodes; String? get clientId; DateTime? get editedAt; DateTime? get deletedAt; DateTime get createdAt; String? get kind; String? get senderRole; String? get sessionId; Map<String, dynamic> get payload; String? get moderationStatus;
/// Create a copy of MessageRowModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageRowModelCopyWith<MessageRowModel> get copyWith => _$MessageRowModelCopyWithImpl<MessageRowModel>(this as MessageRowModel, _$identity);

  /// Serializes this MessageRowModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageRowModel&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.body, body) || other.body == body)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.sharedPostId, sharedPostId) || other.sharedPostId == sharedPostId)&&const DeepCollectionEquality().equals(other.stockCodes, stockCodes)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,senderId,body,replyToId,const DeepCollectionEquality().hash(attachments),sharedPostId,const DeepCollectionEquality().hash(stockCodes),clientId,editedAt,deletedAt,createdAt,kind,senderRole,sessionId,const DeepCollectionEquality().hash(payload),moderationStatus);

@override
String toString() {
  return 'MessageRowModel(id: $id, roomId: $roomId, senderId: $senderId, body: $body, replyToId: $replyToId, attachments: $attachments, sharedPostId: $sharedPostId, stockCodes: $stockCodes, clientId: $clientId, editedAt: $editedAt, deletedAt: $deletedAt, createdAt: $createdAt, kind: $kind, senderRole: $senderRole, sessionId: $sessionId, payload: $payload, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class $MessageRowModelCopyWith<$Res>  {
  factory $MessageRowModelCopyWith(MessageRowModel value, $Res Function(MessageRowModel) _then) = _$MessageRowModelCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String? senderId, String body, String? replyToId,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments,@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? sharedPostId,@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> stockCodes, String? clientId, DateTime? editedAt, DateTime? deletedAt, DateTime createdAt, String? kind, String? senderRole, String? sessionId, Map<String, dynamic> payload, String? moderationStatus
});




}
/// @nodoc
class _$MessageRowModelCopyWithImpl<$Res>
    implements $MessageRowModelCopyWith<$Res> {
  _$MessageRowModelCopyWithImpl(this._self, this._then);

  final MessageRowModel _self;
  final $Res Function(MessageRowModel) _then;

/// Create a copy of MessageRowModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? body = null,Object? replyToId = freezed,Object? attachments = null,Object? sharedPostId = freezed,Object? stockCodes = null,Object? clientId = freezed,Object? editedAt = freezed,Object? deletedAt = freezed,Object? createdAt = null,Object? kind = freezed,Object? senderRole = freezed,Object? sessionId = freezed,Object? payload = null,Object? moderationStatus = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,sharedPostId: freezed == sharedPostId ? _self.sharedPostId : sharedPostId // ignore: cast_nullable_to_non_nullable
as String?,stockCodes: null == stockCodes ? _self.stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageRowModel].
extension MessageRowModelPatterns on MessageRowModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageRowModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageRowModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageRowModel value)  $default,){
final _that = this;
switch (_that) {
case _MessageRowModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageRowModel value)?  $default,){
final _that = this;
switch (_that) {
case _MessageRowModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  String body,  String? replyToId, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments, @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false)  String? sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)  List<String> stockCodes,  String? clientId,  DateTime? editedAt,  DateTime? deletedAt,  DateTime createdAt,  String? kind,  String? senderRole,  String? sessionId,  Map<String, dynamic> payload,  String? moderationStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageRowModel() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.body,_that.replyToId,_that.attachments,_that.sharedPostId,_that.stockCodes,_that.clientId,_that.editedAt,_that.deletedAt,_that.createdAt,_that.kind,_that.senderRole,_that.sessionId,_that.payload,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String? senderId,  String body,  String? replyToId, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments, @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false)  String? sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)  List<String> stockCodes,  String? clientId,  DateTime? editedAt,  DateTime? deletedAt,  DateTime createdAt,  String? kind,  String? senderRole,  String? sessionId,  Map<String, dynamic> payload,  String? moderationStatus)  $default,) {final _that = this;
switch (_that) {
case _MessageRowModel():
return $default(_that.id,_that.roomId,_that.senderId,_that.body,_that.replyToId,_that.attachments,_that.sharedPostId,_that.stockCodes,_that.clientId,_that.editedAt,_that.deletedAt,_that.createdAt,_that.kind,_that.senderRole,_that.sessionId,_that.payload,_that.moderationStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String? senderId,  String body,  String? replyToId, @JsonKey(fromJson: attachmentsFromJson)  List<AttachmentModel> attachments, @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false)  String? sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false)  List<String> stockCodes,  String? clientId,  DateTime? editedAt,  DateTime? deletedAt,  DateTime createdAt,  String? kind,  String? senderRole,  String? sessionId,  Map<String, dynamic> payload,  String? moderationStatus)?  $default,) {final _that = this;
switch (_that) {
case _MessageRowModel() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.body,_that.replyToId,_that.attachments,_that.sharedPostId,_that.stockCodes,_that.clientId,_that.editedAt,_that.deletedAt,_that.createdAt,_that.kind,_that.senderRole,_that.sessionId,_that.payload,_that.moderationStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageRowModel extends MessageRowModel {
  const _MessageRowModel({required this.id, required this.roomId, this.senderId, this.body = '', this.replyToId, @JsonKey(fromJson: attachmentsFromJson) final  List<AttachmentModel> attachments = const <AttachmentModel>[], @JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) this.sharedPostId, @JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) final  List<String> stockCodes = const <String>[], this.clientId, this.editedAt, this.deletedAt, required this.createdAt, this.kind, this.senderRole, this.sessionId, final  Map<String, dynamic> payload = const <String, dynamic>{}, this.moderationStatus}): _attachments = attachments,_stockCodes = stockCodes,_payload = payload,super._();
  factory _MessageRowModel.fromJson(Map<String, dynamic> json) => _$MessageRowModelFromJson(json);

@override final  String id;
@override final  String roomId;
@override final  String? senderId;
@override@JsonKey() final  String body;
@override final  String? replyToId;
 final  List<AttachmentModel> _attachments;
@override@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) final  String? sharedPostId;
 final  List<String> _stockCodes;
@override@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> get stockCodes {
  if (_stockCodes is EqualUnmodifiableListView) return _stockCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stockCodes);
}

@override final  String? clientId;
@override final  DateTime? editedAt;
@override final  DateTime? deletedAt;
@override final  DateTime createdAt;
@override final  String? kind;
@override final  String? senderRole;
@override final  String? sessionId;
 final  Map<String, dynamic> _payload;
@override@JsonKey() Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override final  String? moderationStatus;

/// Create a copy of MessageRowModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageRowModelCopyWith<_MessageRowModel> get copyWith => __$MessageRowModelCopyWithImpl<_MessageRowModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageRowModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageRowModel&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.body, body) || other.body == body)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.sharedPostId, sharedPostId) || other.sharedPostId == sharedPostId)&&const DeepCollectionEquality().equals(other._stockCodes, _stockCodes)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.moderationStatus, moderationStatus) || other.moderationStatus == moderationStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,senderId,body,replyToId,const DeepCollectionEquality().hash(_attachments),sharedPostId,const DeepCollectionEquality().hash(_stockCodes),clientId,editedAt,deletedAt,createdAt,kind,senderRole,sessionId,const DeepCollectionEquality().hash(_payload),moderationStatus);

@override
String toString() {
  return 'MessageRowModel(id: $id, roomId: $roomId, senderId: $senderId, body: $body, replyToId: $replyToId, attachments: $attachments, sharedPostId: $sharedPostId, stockCodes: $stockCodes, clientId: $clientId, editedAt: $editedAt, deletedAt: $deletedAt, createdAt: $createdAt, kind: $kind, senderRole: $senderRole, sessionId: $sessionId, payload: $payload, moderationStatus: $moderationStatus)';
}


}

/// @nodoc
abstract mixin class _$MessageRowModelCopyWith<$Res> implements $MessageRowModelCopyWith<$Res> {
  factory _$MessageRowModelCopyWith(_MessageRowModel value, $Res Function(_MessageRowModel) _then) = __$MessageRowModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String? senderId, String body, String? replyToId,@JsonKey(fromJson: attachmentsFromJson) List<AttachmentModel> attachments,@JsonKey(readValue: readAttachments, fromJson: sharedPostIdFromJson, includeToJson: false) String? sharedPostId,@JsonKey(readValue: readAttachments, fromJson: stockCodesFromJson, includeToJson: false) List<String> stockCodes, String? clientId, DateTime? editedAt, DateTime? deletedAt, DateTime createdAt, String? kind, String? senderRole, String? sessionId, Map<String, dynamic> payload, String? moderationStatus
});




}
/// @nodoc
class __$MessageRowModelCopyWithImpl<$Res>
    implements _$MessageRowModelCopyWith<$Res> {
  __$MessageRowModelCopyWithImpl(this._self, this._then);

  final _MessageRowModel _self;
  final $Res Function(_MessageRowModel) _then;

/// Create a copy of MessageRowModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? senderId = freezed,Object? body = null,Object? replyToId = freezed,Object? attachments = null,Object? sharedPostId = freezed,Object? stockCodes = null,Object? clientId = freezed,Object? editedAt = freezed,Object? deletedAt = freezed,Object? createdAt = null,Object? kind = freezed,Object? senderRole = freezed,Object? sessionId = freezed,Object? payload = null,Object? moderationStatus = freezed,}) {
  return _then(_MessageRowModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentModel>,sharedPostId: freezed == sharedPostId ? _self.sharedPostId : sharedPostId // ignore: cast_nullable_to_non_nullable
as String?,stockCodes: null == stockCodes ? _self._stockCodes : stockCodes // ignore: cast_nullable_to_non_nullable
as List<String>,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,moderationStatus: freezed == moderationStatus ? _self.moderationStatus : moderationStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$RoomSummaryModel {

 String get id; String get type; String? get name; String? get stockCode; DateTime? get lastMessageAt; String? get lastMessagePreview; String? get lastMessageSenderId; String? get lastMessageStatus; DateTime get createdAt; String? get myRole; bool get muted; DateTime get lastReadAt; int get unreadCount; int get memberCount; String? get otherUserId; String? get otherUsername; String? get otherDisplayName; String? get otherAvatarUrl; bool get otherIsVerified; String? get cursor;
/// Create a copy of RoomSummaryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomSummaryModelCopyWith<RoomSummaryModel> get copyWith => _$RoomSummaryModelCopyWithImpl<RoomSummaryModel>(this as RoomSummaryModel, _$identity);

  /// Serializes this RoomSummaryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.lastMessageStatus, lastMessageStatus) || other.lastMessageStatus == lastMessageStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.otherUserId, otherUserId) || other.otherUserId == otherUserId)&&(identical(other.otherUsername, otherUsername) || other.otherUsername == otherUsername)&&(identical(other.otherDisplayName, otherDisplayName) || other.otherDisplayName == otherDisplayName)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl)&&(identical(other.otherIsVerified, otherIsVerified) || other.otherIsVerified == otherIsVerified)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,type,name,stockCode,lastMessageAt,lastMessagePreview,lastMessageSenderId,lastMessageStatus,createdAt,myRole,muted,lastReadAt,unreadCount,memberCount,otherUserId,otherUsername,otherDisplayName,otherAvatarUrl,otherIsVerified,cursor]);

@override
String toString() {
  return 'RoomSummaryModel(id: $id, type: $type, name: $name, stockCode: $stockCode, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, lastMessageSenderId: $lastMessageSenderId, lastMessageStatus: $lastMessageStatus, createdAt: $createdAt, myRole: $myRole, muted: $muted, lastReadAt: $lastReadAt, unreadCount: $unreadCount, memberCount: $memberCount, otherUserId: $otherUserId, otherUsername: $otherUsername, otherDisplayName: $otherDisplayName, otherAvatarUrl: $otherAvatarUrl, otherIsVerified: $otherIsVerified, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class $RoomSummaryModelCopyWith<$Res>  {
  factory $RoomSummaryModelCopyWith(RoomSummaryModel value, $Res Function(RoomSummaryModel) _then) = _$RoomSummaryModelCopyWithImpl;
@useResult
$Res call({
 String id, String type, String? name, String? stockCode, DateTime? lastMessageAt, String? lastMessagePreview, String? lastMessageSenderId, String? lastMessageStatus, DateTime createdAt, String? myRole, bool muted, DateTime lastReadAt, int unreadCount, int memberCount, String? otherUserId, String? otherUsername, String? otherDisplayName, String? otherAvatarUrl, bool otherIsVerified, String? cursor
});




}
/// @nodoc
class _$RoomSummaryModelCopyWithImpl<$Res>
    implements $RoomSummaryModelCopyWith<$Res> {
  _$RoomSummaryModelCopyWithImpl(this._self, this._then);

  final RoomSummaryModel _self;
  final $Res Function(RoomSummaryModel) _then;

/// Create a copy of RoomSummaryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? name = freezed,Object? stockCode = freezed,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? lastMessageSenderId = freezed,Object? lastMessageStatus = freezed,Object? createdAt = null,Object? myRole = freezed,Object? muted = null,Object? lastReadAt = null,Object? unreadCount = null,Object? memberCount = null,Object? otherUserId = freezed,Object? otherUsername = freezed,Object? otherDisplayName = freezed,Object? otherAvatarUrl = freezed,Object? otherIsVerified = null,Object? cursor = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,lastMessageStatus: freezed == lastMessageStatus ? _self.lastMessageStatus : lastMessageStatus // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: freezed == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as String?,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,otherUserId: freezed == otherUserId ? _self.otherUserId : otherUserId // ignore: cast_nullable_to_non_nullable
as String?,otherUsername: freezed == otherUsername ? _self.otherUsername : otherUsername // ignore: cast_nullable_to_non_nullable
as String?,otherDisplayName: freezed == otherDisplayName ? _self.otherDisplayName : otherDisplayName // ignore: cast_nullable_to_non_nullable
as String?,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,otherIsVerified: null == otherIsVerified ? _self.otherIsVerified : otherIsVerified // ignore: cast_nullable_to_non_nullable
as bool,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomSummaryModel].
extension RoomSummaryModelPatterns on RoomSummaryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomSummaryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomSummaryModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomSummaryModel value)  $default,){
final _that = this;
switch (_that) {
case _RoomSummaryModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomSummaryModel value)?  $default,){
final _that = this;
switch (_that) {
case _RoomSummaryModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  String? lastMessageStatus,  DateTime createdAt,  String? myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  String? otherUserId,  String? otherUsername,  String? otherDisplayName,  String? otherAvatarUrl,  bool otherIsVerified,  String? cursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomSummaryModel() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.lastMessageStatus,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUserId,_that.otherUsername,_that.otherDisplayName,_that.otherAvatarUrl,_that.otherIsVerified,_that.cursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  String? lastMessageStatus,  DateTime createdAt,  String? myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  String? otherUserId,  String? otherUsername,  String? otherDisplayName,  String? otherAvatarUrl,  bool otherIsVerified,  String? cursor)  $default,) {final _that = this;
switch (_that) {
case _RoomSummaryModel():
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.lastMessageStatus,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUserId,_that.otherUsername,_that.otherDisplayName,_that.otherAvatarUrl,_that.otherIsVerified,_that.cursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String? name,  String? stockCode,  DateTime? lastMessageAt,  String? lastMessagePreview,  String? lastMessageSenderId,  String? lastMessageStatus,  DateTime createdAt,  String? myRole,  bool muted,  DateTime lastReadAt,  int unreadCount,  int memberCount,  String? otherUserId,  String? otherUsername,  String? otherDisplayName,  String? otherAvatarUrl,  bool otherIsVerified,  String? cursor)?  $default,) {final _that = this;
switch (_that) {
case _RoomSummaryModel() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.stockCode,_that.lastMessageAt,_that.lastMessagePreview,_that.lastMessageSenderId,_that.lastMessageStatus,_that.createdAt,_that.myRole,_that.muted,_that.lastReadAt,_that.unreadCount,_that.memberCount,_that.otherUserId,_that.otherUsername,_that.otherDisplayName,_that.otherAvatarUrl,_that.otherIsVerified,_that.cursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomSummaryModel extends RoomSummaryModel {
  const _RoomSummaryModel({required this.id, required this.type, this.name, this.stockCode, this.lastMessageAt, this.lastMessagePreview, this.lastMessageSenderId, this.lastMessageStatus, required this.createdAt, this.myRole, this.muted = false, required this.lastReadAt, this.unreadCount = 0, this.memberCount = 0, this.otherUserId, this.otherUsername, this.otherDisplayName, this.otherAvatarUrl, this.otherIsVerified = false, this.cursor}): super._();
  factory _RoomSummaryModel.fromJson(Map<String, dynamic> json) => _$RoomSummaryModelFromJson(json);

@override final  String id;
@override final  String type;
@override final  String? name;
@override final  String? stockCode;
@override final  DateTime? lastMessageAt;
@override final  String? lastMessagePreview;
@override final  String? lastMessageSenderId;
@override final  String? lastMessageStatus;
@override final  DateTime createdAt;
@override final  String? myRole;
@override@JsonKey() final  bool muted;
@override final  DateTime lastReadAt;
@override@JsonKey() final  int unreadCount;
@override@JsonKey() final  int memberCount;
@override final  String? otherUserId;
@override final  String? otherUsername;
@override final  String? otherDisplayName;
@override final  String? otherAvatarUrl;
@override@JsonKey() final  bool otherIsVerified;
@override final  String? cursor;

/// Create a copy of RoomSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomSummaryModelCopyWith<_RoomSummaryModel> get copyWith => __$RoomSummaryModelCopyWithImpl<_RoomSummaryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomSummaryModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.stockCode, stockCode) || other.stockCode == stockCode)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.lastMessageStatus, lastMessageStatus) || other.lastMessageStatus == lastMessageStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.otherUserId, otherUserId) || other.otherUserId == otherUserId)&&(identical(other.otherUsername, otherUsername) || other.otherUsername == otherUsername)&&(identical(other.otherDisplayName, otherDisplayName) || other.otherDisplayName == otherDisplayName)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl)&&(identical(other.otherIsVerified, otherIsVerified) || other.otherIsVerified == otherIsVerified)&&(identical(other.cursor, cursor) || other.cursor == cursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,type,name,stockCode,lastMessageAt,lastMessagePreview,lastMessageSenderId,lastMessageStatus,createdAt,myRole,muted,lastReadAt,unreadCount,memberCount,otherUserId,otherUsername,otherDisplayName,otherAvatarUrl,otherIsVerified,cursor]);

@override
String toString() {
  return 'RoomSummaryModel(id: $id, type: $type, name: $name, stockCode: $stockCode, lastMessageAt: $lastMessageAt, lastMessagePreview: $lastMessagePreview, lastMessageSenderId: $lastMessageSenderId, lastMessageStatus: $lastMessageStatus, createdAt: $createdAt, myRole: $myRole, muted: $muted, lastReadAt: $lastReadAt, unreadCount: $unreadCount, memberCount: $memberCount, otherUserId: $otherUserId, otherUsername: $otherUsername, otherDisplayName: $otherDisplayName, otherAvatarUrl: $otherAvatarUrl, otherIsVerified: $otherIsVerified, cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class _$RoomSummaryModelCopyWith<$Res> implements $RoomSummaryModelCopyWith<$Res> {
  factory _$RoomSummaryModelCopyWith(_RoomSummaryModel value, $Res Function(_RoomSummaryModel) _then) = __$RoomSummaryModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String? name, String? stockCode, DateTime? lastMessageAt, String? lastMessagePreview, String? lastMessageSenderId, String? lastMessageStatus, DateTime createdAt, String? myRole, bool muted, DateTime lastReadAt, int unreadCount, int memberCount, String? otherUserId, String? otherUsername, String? otherDisplayName, String? otherAvatarUrl, bool otherIsVerified, String? cursor
});




}
/// @nodoc
class __$RoomSummaryModelCopyWithImpl<$Res>
    implements _$RoomSummaryModelCopyWith<$Res> {
  __$RoomSummaryModelCopyWithImpl(this._self, this._then);

  final _RoomSummaryModel _self;
  final $Res Function(_RoomSummaryModel) _then;

/// Create a copy of RoomSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? name = freezed,Object? stockCode = freezed,Object? lastMessageAt = freezed,Object? lastMessagePreview = freezed,Object? lastMessageSenderId = freezed,Object? lastMessageStatus = freezed,Object? createdAt = null,Object? myRole = freezed,Object? muted = null,Object? lastReadAt = null,Object? unreadCount = null,Object? memberCount = null,Object? otherUserId = freezed,Object? otherUsername = freezed,Object? otherDisplayName = freezed,Object? otherAvatarUrl = freezed,Object? otherIsVerified = null,Object? cursor = freezed,}) {
  return _then(_RoomSummaryModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,stockCode: freezed == stockCode ? _self.stockCode : stockCode // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,lastMessageStatus: freezed == lastMessageStatus ? _self.lastMessageStatus : lastMessageStatus // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: freezed == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as String?,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,otherUserId: freezed == otherUserId ? _self.otherUserId : otherUserId // ignore: cast_nullable_to_non_nullable
as String?,otherUsername: freezed == otherUsername ? _self.otherUsername : otherUsername // ignore: cast_nullable_to_non_nullable
as String?,otherDisplayName: freezed == otherDisplayName ? _self.otherDisplayName : otherDisplayName // ignore: cast_nullable_to_non_nullable
as String?,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,otherIsVerified: null == otherIsVerified ? _self.otherIsVerified : otherIsVerified // ignore: cast_nullable_to_non_nullable
as bool,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$RoomMemberModel {

 String get userId; String get username; String? get displayName; String? get avatarUrl; bool get isVerified; String? get role; DateTime get lastReadAt; DateTime? get lastDeliveredAt; DateTime get joinedAt;
/// Create a copy of RoomMemberModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomMemberModelCopyWith<RoomMemberModel> get copyWith => _$RoomMemberModelCopyWithImpl<RoomMemberModel>(this as RoomMemberModel, _$identity);

  /// Serializes this RoomMemberModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomMemberModel&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.role, role) || other.role == role)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastDeliveredAt, lastDeliveredAt) || other.lastDeliveredAt == lastDeliveredAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,displayName,avatarUrl,isVerified,role,lastReadAt,lastDeliveredAt,joinedAt);

@override
String toString() {
  return 'RoomMemberModel(userId: $userId, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified, role: $role, lastReadAt: $lastReadAt, lastDeliveredAt: $lastDeliveredAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $RoomMemberModelCopyWith<$Res>  {
  factory $RoomMemberModelCopyWith(RoomMemberModel value, $Res Function(RoomMemberModel) _then) = _$RoomMemberModelCopyWithImpl;
@useResult
$Res call({
 String userId, String username, String? displayName, String? avatarUrl, bool isVerified, String? role, DateTime lastReadAt, DateTime? lastDeliveredAt, DateTime joinedAt
});




}
/// @nodoc
class _$RoomMemberModelCopyWithImpl<$Res>
    implements $RoomMemberModelCopyWith<$Res> {
  _$RoomMemberModelCopyWithImpl(this._self, this._then);

  final RoomMemberModel _self;
  final $Res Function(RoomMemberModel) _then;

/// Create a copy of RoomMemberModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,Object? role = freezed,Object? lastReadAt = null,Object? lastDeliveredAt = freezed,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastDeliveredAt: freezed == lastDeliveredAt ? _self.lastDeliveredAt : lastDeliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomMemberModel].
extension RoomMemberModelPatterns on RoomMemberModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomMemberModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomMemberModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomMemberModel value)  $default,){
final _that = this;
switch (_that) {
case _RoomMemberModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomMemberModel value)?  $default,){
final _that = this;
switch (_that) {
case _RoomMemberModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String username,  String? displayName,  String? avatarUrl,  bool isVerified,  String? role,  DateTime lastReadAt,  DateTime? lastDeliveredAt,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomMemberModel() when $default != null:
return $default(_that.userId,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified,_that.role,_that.lastReadAt,_that.lastDeliveredAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String username,  String? displayName,  String? avatarUrl,  bool isVerified,  String? role,  DateTime lastReadAt,  DateTime? lastDeliveredAt,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _RoomMemberModel():
return $default(_that.userId,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified,_that.role,_that.lastReadAt,_that.lastDeliveredAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String username,  String? displayName,  String? avatarUrl,  bool isVerified,  String? role,  DateTime lastReadAt,  DateTime? lastDeliveredAt,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _RoomMemberModel() when $default != null:
return $default(_that.userId,_that.username,_that.displayName,_that.avatarUrl,_that.isVerified,_that.role,_that.lastReadAt,_that.lastDeliveredAt,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomMemberModel extends RoomMemberModel {
  const _RoomMemberModel({required this.userId, required this.username, this.displayName, this.avatarUrl, this.isVerified = false, this.role, required this.lastReadAt, this.lastDeliveredAt, required this.joinedAt}): super._();
  factory _RoomMemberModel.fromJson(Map<String, dynamic> json) => _$RoomMemberModelFromJson(json);

@override final  String userId;
@override final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override@JsonKey() final  bool isVerified;
@override final  String? role;
@override final  DateTime lastReadAt;
@override final  DateTime? lastDeliveredAt;
@override final  DateTime joinedAt;

/// Create a copy of RoomMemberModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomMemberModelCopyWith<_RoomMemberModel> get copyWith => __$RoomMemberModelCopyWithImpl<_RoomMemberModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomMemberModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomMemberModel&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.role, role) || other.role == role)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt)&&(identical(other.lastDeliveredAt, lastDeliveredAt) || other.lastDeliveredAt == lastDeliveredAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,displayName,avatarUrl,isVerified,role,lastReadAt,lastDeliveredAt,joinedAt);

@override
String toString() {
  return 'RoomMemberModel(userId: $userId, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isVerified: $isVerified, role: $role, lastReadAt: $lastReadAt, lastDeliveredAt: $lastDeliveredAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$RoomMemberModelCopyWith<$Res> implements $RoomMemberModelCopyWith<$Res> {
  factory _$RoomMemberModelCopyWith(_RoomMemberModel value, $Res Function(_RoomMemberModel) _then) = __$RoomMemberModelCopyWithImpl;
@override @useResult
$Res call({
 String userId, String username, String? displayName, String? avatarUrl, bool isVerified, String? role, DateTime lastReadAt, DateTime? lastDeliveredAt, DateTime joinedAt
});




}
/// @nodoc
class __$RoomMemberModelCopyWithImpl<$Res>
    implements _$RoomMemberModelCopyWith<$Res> {
  __$RoomMemberModelCopyWithImpl(this._self, this._then);

  final _RoomMemberModel _self;
  final $Res Function(_RoomMemberModel) _then;

/// Create a copy of RoomMemberModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isVerified = null,Object? role = freezed,Object? lastReadAt = null,Object? lastDeliveredAt = freezed,Object? joinedAt = null,}) {
  return _then(_RoomMemberModel(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,lastReadAt: null == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastDeliveredAt: freezed == lastDeliveredAt ? _self.lastDeliveredAt : lastDeliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
