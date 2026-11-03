// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PostDraft {

 String get clientDraftId; String get body; Sentiment? get sentiment; List<String> get stocks; List<Attachment> get attachments; PollDraft? get poll; DateTime get updatedAt; DateTime? get serverUpdatedAt;
/// Create a copy of PostDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostDraftCopyWith<PostDraft> get copyWith => _$PostDraftCopyWithImpl<PostDraft>(this as PostDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostDraft&&(identical(other.clientDraftId, clientDraftId) || other.clientDraftId == clientDraftId)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other.stocks, stocks)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.serverUpdatedAt, serverUpdatedAt) || other.serverUpdatedAt == serverUpdatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,clientDraftId,body,sentiment,const DeepCollectionEquality().hash(stocks),const DeepCollectionEquality().hash(attachments),poll,updatedAt,serverUpdatedAt);

@override
String toString() {
  return 'PostDraft(clientDraftId: $clientDraftId, body: $body, sentiment: $sentiment, stocks: $stocks, attachments: $attachments, poll: $poll, updatedAt: $updatedAt, serverUpdatedAt: $serverUpdatedAt)';
}


}

/// @nodoc
abstract mixin class $PostDraftCopyWith<$Res>  {
  factory $PostDraftCopyWith(PostDraft value, $Res Function(PostDraft) _then) = _$PostDraftCopyWithImpl;
@useResult
$Res call({
 String clientDraftId, String body, Sentiment? sentiment, List<String> stocks, List<Attachment> attachments, PollDraft? poll, DateTime updatedAt, DateTime? serverUpdatedAt
});


$PollDraftCopyWith<$Res>? get poll;

}
/// @nodoc
class _$PostDraftCopyWithImpl<$Res>
    implements $PostDraftCopyWith<$Res> {
  _$PostDraftCopyWithImpl(this._self, this._then);

  final PostDraft _self;
  final $Res Function(PostDraft) _then;

/// Create a copy of PostDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientDraftId = null,Object? body = null,Object? sentiment = freezed,Object? stocks = null,Object? attachments = null,Object? poll = freezed,Object? updatedAt = null,Object? serverUpdatedAt = freezed,}) {
  return _then(_self.copyWith(
clientDraftId: null == clientDraftId ? _self.clientDraftId : clientDraftId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as Sentiment?,stocks: null == stocks ? _self.stocks : stocks // ignore: cast_nullable_to_non_nullable
as List<String>,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as PollDraft?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,serverUpdatedAt: freezed == serverUpdatedAt ? _self.serverUpdatedAt : serverUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of PostDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollDraftCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollDraftCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}


/// Adds pattern-matching-related methods to [PostDraft].
extension PostDraftPatterns on PostDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostDraft value)  $default,){
final _that = this;
switch (_that) {
case _PostDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostDraft value)?  $default,){
final _that = this;
switch (_that) {
case _PostDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clientDraftId,  String body,  Sentiment? sentiment,  List<String> stocks,  List<Attachment> attachments,  PollDraft? poll,  DateTime updatedAt,  DateTime? serverUpdatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostDraft() when $default != null:
return $default(_that.clientDraftId,_that.body,_that.sentiment,_that.stocks,_that.attachments,_that.poll,_that.updatedAt,_that.serverUpdatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clientDraftId,  String body,  Sentiment? sentiment,  List<String> stocks,  List<Attachment> attachments,  PollDraft? poll,  DateTime updatedAt,  DateTime? serverUpdatedAt)  $default,) {final _that = this;
switch (_that) {
case _PostDraft():
return $default(_that.clientDraftId,_that.body,_that.sentiment,_that.stocks,_that.attachments,_that.poll,_that.updatedAt,_that.serverUpdatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clientDraftId,  String body,  Sentiment? sentiment,  List<String> stocks,  List<Attachment> attachments,  PollDraft? poll,  DateTime updatedAt,  DateTime? serverUpdatedAt)?  $default,) {final _that = this;
switch (_that) {
case _PostDraft() when $default != null:
return $default(_that.clientDraftId,_that.body,_that.sentiment,_that.stocks,_that.attachments,_that.poll,_that.updatedAt,_that.serverUpdatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _PostDraft extends PostDraft {
  const _PostDraft({required this.clientDraftId, this.body = '', this.sentiment, final  List<String> stocks = const <String>[], final  List<Attachment> attachments = const <Attachment>[], this.poll, required this.updatedAt, this.serverUpdatedAt}): _stocks = stocks,_attachments = attachments,super._();
  

@override final  String clientDraftId;
@override@JsonKey() final  String body;
@override final  Sentiment? sentiment;
 final  List<String> _stocks;
@override@JsonKey() List<String> get stocks {
  if (_stocks is EqualUnmodifiableListView) return _stocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stocks);
}

 final  List<Attachment> _attachments;
@override@JsonKey() List<Attachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override final  PollDraft? poll;
@override final  DateTime updatedAt;
@override final  DateTime? serverUpdatedAt;

/// Create a copy of PostDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostDraftCopyWith<_PostDraft> get copyWith => __$PostDraftCopyWithImpl<_PostDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostDraft&&(identical(other.clientDraftId, clientDraftId) || other.clientDraftId == clientDraftId)&&(identical(other.body, body) || other.body == body)&&(identical(other.sentiment, sentiment) || other.sentiment == sentiment)&&const DeepCollectionEquality().equals(other._stocks, _stocks)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.serverUpdatedAt, serverUpdatedAt) || other.serverUpdatedAt == serverUpdatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,clientDraftId,body,sentiment,const DeepCollectionEquality().hash(_stocks),const DeepCollectionEquality().hash(_attachments),poll,updatedAt,serverUpdatedAt);

@override
String toString() {
  return 'PostDraft(clientDraftId: $clientDraftId, body: $body, sentiment: $sentiment, stocks: $stocks, attachments: $attachments, poll: $poll, updatedAt: $updatedAt, serverUpdatedAt: $serverUpdatedAt)';
}


}

/// @nodoc
abstract mixin class _$PostDraftCopyWith<$Res> implements $PostDraftCopyWith<$Res> {
  factory _$PostDraftCopyWith(_PostDraft value, $Res Function(_PostDraft) _then) = __$PostDraftCopyWithImpl;
@override @useResult
$Res call({
 String clientDraftId, String body, Sentiment? sentiment, List<String> stocks, List<Attachment> attachments, PollDraft? poll, DateTime updatedAt, DateTime? serverUpdatedAt
});


@override $PollDraftCopyWith<$Res>? get poll;

}
/// @nodoc
class __$PostDraftCopyWithImpl<$Res>
    implements _$PostDraftCopyWith<$Res> {
  __$PostDraftCopyWithImpl(this._self, this._then);

  final _PostDraft _self;
  final $Res Function(_PostDraft) _then;

/// Create a copy of PostDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientDraftId = null,Object? body = null,Object? sentiment = freezed,Object? stocks = null,Object? attachments = null,Object? poll = freezed,Object? updatedAt = null,Object? serverUpdatedAt = freezed,}) {
  return _then(_PostDraft(
clientDraftId: null == clientDraftId ? _self.clientDraftId : clientDraftId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,sentiment: freezed == sentiment ? _self.sentiment : sentiment // ignore: cast_nullable_to_non_nullable
as Sentiment?,stocks: null == stocks ? _self._stocks : stocks // ignore: cast_nullable_to_non_nullable
as List<String>,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as PollDraft?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,serverUpdatedAt: freezed == serverUpdatedAt ? _self.serverUpdatedAt : serverUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of PostDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollDraftCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollDraftCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}

// dart format on
