// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FeedState {

 LoadStatus get status; List<Post> get posts; List<PinnedPost> get pinned; String? get nextCursor; bool get loadingMore; int get newPosts; Object? get error; Object? get actionError; int get actionErrorId; bool get stale;
/// Create a copy of FeedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedStateCopyWith<FeedState> get copyWith => _$FeedStateCopyWithImpl<FeedState>(this as FeedState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.posts, posts)&&const DeepCollectionEquality().equals(other.pinned, pinned)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.newPosts, newPosts) || other.newPosts == newPosts)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.stale, stale) || other.stale == stale));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(posts),const DeepCollectionEquality().hash(pinned),nextCursor,loadingMore,newPosts,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,stale);

@override
String toString() {
  return 'FeedState(status: $status, posts: $posts, pinned: $pinned, nextCursor: $nextCursor, loadingMore: $loadingMore, newPosts: $newPosts, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, stale: $stale)';
}


}

/// @nodoc
abstract mixin class $FeedStateCopyWith<$Res>  {
  factory $FeedStateCopyWith(FeedState value, $Res Function(FeedState) _then) = _$FeedStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<Post> posts, List<PinnedPost> pinned, String? nextCursor, bool loadingMore, int newPosts, Object? error, Object? actionError, int actionErrorId, bool stale
});




}
/// @nodoc
class _$FeedStateCopyWithImpl<$Res>
    implements $FeedStateCopyWith<$Res> {
  _$FeedStateCopyWithImpl(this._self, this._then);

  final FeedState _self;
  final $Res Function(FeedState) _then;

/// Create a copy of FeedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? posts = null,Object? pinned = null,Object? nextCursor = freezed,Object? loadingMore = null,Object? newPosts = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? stale = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as List<Post>,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as List<PinnedPost>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,newPosts: null == newPosts ? _self.newPosts : newPosts // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedState].
extension FeedStatePatterns on FeedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedState value)  $default,){
final _that = this;
switch (_that) {
case _FeedState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedState value)?  $default,){
final _that = this;
switch (_that) {
case _FeedState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<Post> posts,  List<PinnedPost> pinned,  String? nextCursor,  bool loadingMore,  int newPosts,  Object? error,  Object? actionError,  int actionErrorId,  bool stale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedState() when $default != null:
return $default(_that.status,_that.posts,_that.pinned,_that.nextCursor,_that.loadingMore,_that.newPosts,_that.error,_that.actionError,_that.actionErrorId,_that.stale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<Post> posts,  List<PinnedPost> pinned,  String? nextCursor,  bool loadingMore,  int newPosts,  Object? error,  Object? actionError,  int actionErrorId,  bool stale)  $default,) {final _that = this;
switch (_that) {
case _FeedState():
return $default(_that.status,_that.posts,_that.pinned,_that.nextCursor,_that.loadingMore,_that.newPosts,_that.error,_that.actionError,_that.actionErrorId,_that.stale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<Post> posts,  List<PinnedPost> pinned,  String? nextCursor,  bool loadingMore,  int newPosts,  Object? error,  Object? actionError,  int actionErrorId,  bool stale)?  $default,) {final _that = this;
switch (_that) {
case _FeedState() when $default != null:
return $default(_that.status,_that.posts,_that.pinned,_that.nextCursor,_that.loadingMore,_that.newPosts,_that.error,_that.actionError,_that.actionErrorId,_that.stale);case _:
  return null;

}
}

}

/// @nodoc


class _FeedState implements FeedState {
  const _FeedState({this.status = LoadStatus.initial, final  List<Post> posts = const <Post>[], final  List<PinnedPost> pinned = const <PinnedPost>[], this.nextCursor, this.loadingMore = false, this.newPosts = 0, this.error, this.actionError, this.actionErrorId = 0, this.stale = false}): _posts = posts,_pinned = pinned;
  

@override@JsonKey() final  LoadStatus status;
 final  List<Post> _posts;
@override@JsonKey() List<Post> get posts {
  if (_posts is EqualUnmodifiableListView) return _posts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_posts);
}

 final  List<PinnedPost> _pinned;
@override@JsonKey() List<PinnedPost> get pinned {
  if (_pinned is EqualUnmodifiableListView) return _pinned;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pinned);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool loadingMore;
@override@JsonKey() final  int newPosts;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;
@override@JsonKey() final  bool stale;

/// Create a copy of FeedState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedStateCopyWith<_FeedState> get copyWith => __$FeedStateCopyWithImpl<_FeedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._posts, _posts)&&const DeepCollectionEquality().equals(other._pinned, _pinned)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.newPosts, newPosts) || other.newPosts == newPosts)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.stale, stale) || other.stale == stale));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_posts),const DeepCollectionEquality().hash(_pinned),nextCursor,loadingMore,newPosts,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,stale);

@override
String toString() {
  return 'FeedState(status: $status, posts: $posts, pinned: $pinned, nextCursor: $nextCursor, loadingMore: $loadingMore, newPosts: $newPosts, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, stale: $stale)';
}


}

/// @nodoc
abstract mixin class _$FeedStateCopyWith<$Res> implements $FeedStateCopyWith<$Res> {
  factory _$FeedStateCopyWith(_FeedState value, $Res Function(_FeedState) _then) = __$FeedStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<Post> posts, List<PinnedPost> pinned, String? nextCursor, bool loadingMore, int newPosts, Object? error, Object? actionError, int actionErrorId, bool stale
});




}
/// @nodoc
class __$FeedStateCopyWithImpl<$Res>
    implements _$FeedStateCopyWith<$Res> {
  __$FeedStateCopyWithImpl(this._self, this._then);

  final _FeedState _self;
  final $Res Function(_FeedState) _then;

/// Create a copy of FeedState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? posts = null,Object? pinned = null,Object? nextCursor = freezed,Object? loadingMore = null,Object? newPosts = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? stale = null,}) {
  return _then(_FeedState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,posts: null == posts ? _self._posts : posts // ignore: cast_nullable_to_non_nullable
as List<Post>,pinned: null == pinned ? _self._pinned : pinned // ignore: cast_nullable_to_non_nullable
as List<PinnedPost>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,newPosts: null == newPosts ? _self.newPosts : newPosts // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
