// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_results.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserSearchResult {

 UserSummary get user; int get followerCount; bool get isOfficial; bool get isFollowing; bool get isMe;
/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSearchResultCopyWith<UserSearchResult> get copyWith => _$UserSearchResultCopyWithImpl<UserSearchResult>(this as UserSearchResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSearchResult&&(identical(other.user, user) || other.user == user)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.isOfficial, isOfficial) || other.isOfficial == isOfficial)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isMe, isMe) || other.isMe == isMe));
}


@override
int get hashCode => Object.hash(runtimeType,user,followerCount,isOfficial,isFollowing,isMe);

@override
String toString() {
  return 'UserSearchResult(user: $user, followerCount: $followerCount, isOfficial: $isOfficial, isFollowing: $isFollowing, isMe: $isMe)';
}


}

/// @nodoc
abstract mixin class $UserSearchResultCopyWith<$Res>  {
  factory $UserSearchResultCopyWith(UserSearchResult value, $Res Function(UserSearchResult) _then) = _$UserSearchResultCopyWithImpl;
@useResult
$Res call({
 UserSummary user, int followerCount, bool isOfficial, bool isFollowing, bool isMe
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$UserSearchResultCopyWithImpl<$Res>
    implements $UserSearchResultCopyWith<$Res> {
  _$UserSearchResultCopyWithImpl(this._self, this._then);

  final UserSearchResult _self;
  final $Res Function(UserSearchResult) _then;

/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? followerCount = null,Object? isOfficial = null,Object? isFollowing = null,Object? isMe = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,isOfficial: null == isOfficial ? _self.isOfficial : isOfficial // ignore: cast_nullable_to_non_nullable
as bool,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,isMe: null == isMe ? _self.isMe : isMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserSearchResult].
extension UserSearchResultPatterns on UserSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _UserSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  int followerCount,  bool isOfficial,  bool isFollowing,  bool isMe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
return $default(_that.user,_that.followerCount,_that.isOfficial,_that.isFollowing,_that.isMe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  int followerCount,  bool isOfficial,  bool isFollowing,  bool isMe)  $default,) {final _that = this;
switch (_that) {
case _UserSearchResult():
return $default(_that.user,_that.followerCount,_that.isOfficial,_that.isFollowing,_that.isMe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  int followerCount,  bool isOfficial,  bool isFollowing,  bool isMe)?  $default,) {final _that = this;
switch (_that) {
case _UserSearchResult() when $default != null:
return $default(_that.user,_that.followerCount,_that.isOfficial,_that.isFollowing,_that.isMe);case _:
  return null;

}
}

}

/// @nodoc


class _UserSearchResult implements UserSearchResult {
  const _UserSearchResult({required this.user, this.followerCount = 0, this.isOfficial = false, this.isFollowing = false, this.isMe = false});
  

@override final  UserSummary user;
@override@JsonKey() final  int followerCount;
@override@JsonKey() final  bool isOfficial;
@override@JsonKey() final  bool isFollowing;
@override@JsonKey() final  bool isMe;

/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSearchResultCopyWith<_UserSearchResult> get copyWith => __$UserSearchResultCopyWithImpl<_UserSearchResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSearchResult&&(identical(other.user, user) || other.user == user)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.isOfficial, isOfficial) || other.isOfficial == isOfficial)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isMe, isMe) || other.isMe == isMe));
}


@override
int get hashCode => Object.hash(runtimeType,user,followerCount,isOfficial,isFollowing,isMe);

@override
String toString() {
  return 'UserSearchResult(user: $user, followerCount: $followerCount, isOfficial: $isOfficial, isFollowing: $isFollowing, isMe: $isMe)';
}


}

/// @nodoc
abstract mixin class _$UserSearchResultCopyWith<$Res> implements $UserSearchResultCopyWith<$Res> {
  factory _$UserSearchResultCopyWith(_UserSearchResult value, $Res Function(_UserSearchResult) _then) = __$UserSearchResultCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, int followerCount, bool isOfficial, bool isFollowing, bool isMe
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$UserSearchResultCopyWithImpl<$Res>
    implements _$UserSearchResultCopyWith<$Res> {
  __$UserSearchResultCopyWithImpl(this._self, this._then);

  final _UserSearchResult _self;
  final $Res Function(_UserSearchResult) _then;

/// Create a copy of UserSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? followerCount = null,Object? isOfficial = null,Object? isFollowing = null,Object? isMe = null,}) {
  return _then(_UserSearchResult(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,isOfficial: null == isOfficial ? _self.isOfficial : isOfficial // ignore: cast_nullable_to_non_nullable
as bool,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,isMe: null == isMe ? _self.isMe : isMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of UserSearchResult
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
mixin _$StockSearchResult {

 String get code; int get posts7d; int get watcherCount; bool get isWatching;
/// Create a copy of StockSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockSearchResultCopyWith<StockSearchResult> get copyWith => _$StockSearchResultCopyWithImpl<StockSearchResult>(this as StockSearchResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockSearchResult&&(identical(other.code, code) || other.code == code)&&(identical(other.posts7d, posts7d) || other.posts7d == posts7d)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount)&&(identical(other.isWatching, isWatching) || other.isWatching == isWatching));
}


@override
int get hashCode => Object.hash(runtimeType,code,posts7d,watcherCount,isWatching);

@override
String toString() {
  return 'StockSearchResult(code: $code, posts7d: $posts7d, watcherCount: $watcherCount, isWatching: $isWatching)';
}


}

/// @nodoc
abstract mixin class $StockSearchResultCopyWith<$Res>  {
  factory $StockSearchResultCopyWith(StockSearchResult value, $Res Function(StockSearchResult) _then) = _$StockSearchResultCopyWithImpl;
@useResult
$Res call({
 String code, int posts7d, int watcherCount, bool isWatching
});




}
/// @nodoc
class _$StockSearchResultCopyWithImpl<$Res>
    implements $StockSearchResultCopyWith<$Res> {
  _$StockSearchResultCopyWithImpl(this._self, this._then);

  final StockSearchResult _self;
  final $Res Function(StockSearchResult) _then;

/// Create a copy of StockSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? posts7d = null,Object? watcherCount = null,Object? isWatching = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts7d: null == posts7d ? _self.posts7d : posts7d // ignore: cast_nullable_to_non_nullable
as int,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,isWatching: null == isWatching ? _self.isWatching : isWatching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [StockSearchResult].
extension StockSearchResultPatterns on StockSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _StockSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _StockSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int posts7d,  int watcherCount,  bool isWatching)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StockSearchResult() when $default != null:
return $default(_that.code,_that.posts7d,_that.watcherCount,_that.isWatching);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int posts7d,  int watcherCount,  bool isWatching)  $default,) {final _that = this;
switch (_that) {
case _StockSearchResult():
return $default(_that.code,_that.posts7d,_that.watcherCount,_that.isWatching);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int posts7d,  int watcherCount,  bool isWatching)?  $default,) {final _that = this;
switch (_that) {
case _StockSearchResult() when $default != null:
return $default(_that.code,_that.posts7d,_that.watcherCount,_that.isWatching);case _:
  return null;

}
}

}

/// @nodoc


class _StockSearchResult implements StockSearchResult {
  const _StockSearchResult({required this.code, this.posts7d = 0, this.watcherCount = 0, this.isWatching = false});
  

@override final  String code;
@override@JsonKey() final  int posts7d;
@override@JsonKey() final  int watcherCount;
@override@JsonKey() final  bool isWatching;

/// Create a copy of StockSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockSearchResultCopyWith<_StockSearchResult> get copyWith => __$StockSearchResultCopyWithImpl<_StockSearchResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockSearchResult&&(identical(other.code, code) || other.code == code)&&(identical(other.posts7d, posts7d) || other.posts7d == posts7d)&&(identical(other.watcherCount, watcherCount) || other.watcherCount == watcherCount)&&(identical(other.isWatching, isWatching) || other.isWatching == isWatching));
}


@override
int get hashCode => Object.hash(runtimeType,code,posts7d,watcherCount,isWatching);

@override
String toString() {
  return 'StockSearchResult(code: $code, posts7d: $posts7d, watcherCount: $watcherCount, isWatching: $isWatching)';
}


}

/// @nodoc
abstract mixin class _$StockSearchResultCopyWith<$Res> implements $StockSearchResultCopyWith<$Res> {
  factory _$StockSearchResultCopyWith(_StockSearchResult value, $Res Function(_StockSearchResult) _then) = __$StockSearchResultCopyWithImpl;
@override @useResult
$Res call({
 String code, int posts7d, int watcherCount, bool isWatching
});




}
/// @nodoc
class __$StockSearchResultCopyWithImpl<$Res>
    implements _$StockSearchResultCopyWith<$Res> {
  __$StockSearchResultCopyWithImpl(this._self, this._then);

  final _StockSearchResult _self;
  final $Res Function(_StockSearchResult) _then;

/// Create a copy of StockSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? posts7d = null,Object? watcherCount = null,Object? isWatching = null,}) {
  return _then(_StockSearchResult(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts7d: null == posts7d ? _self.posts7d : posts7d // ignore: cast_nullable_to_non_nullable
as int,watcherCount: null == watcherCount ? _self.watcherCount : watcherCount // ignore: cast_nullable_to_non_nullable
as int,isWatching: null == isWatching ? _self.isWatching : isWatching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$SearchResults {

 String get query; SearchType get type; List<Post> get posts; List<UserSearchResult> get users; List<StockSearchResult> get stocks; List<HashtagSummary> get hashtags; String? get nextCursor;
/// Create a copy of SearchResults
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchResultsCopyWith<SearchResults> get copyWith => _$SearchResultsCopyWithImpl<SearchResults>(this as SearchResults, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResults&&(identical(other.query, query) || other.query == query)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.posts, posts)&&const DeepCollectionEquality().equals(other.users, users)&&const DeepCollectionEquality().equals(other.stocks, stocks)&&const DeepCollectionEquality().equals(other.hashtags, hashtags)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}


@override
int get hashCode => Object.hash(runtimeType,query,type,const DeepCollectionEquality().hash(posts),const DeepCollectionEquality().hash(users),const DeepCollectionEquality().hash(stocks),const DeepCollectionEquality().hash(hashtags),nextCursor);

@override
String toString() {
  return 'SearchResults(query: $query, type: $type, posts: $posts, users: $users, stocks: $stocks, hashtags: $hashtags, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class $SearchResultsCopyWith<$Res>  {
  factory $SearchResultsCopyWith(SearchResults value, $Res Function(SearchResults) _then) = _$SearchResultsCopyWithImpl;
@useResult
$Res call({
 String query, SearchType type, List<Post> posts, List<UserSearchResult> users, List<StockSearchResult> stocks, List<HashtagSummary> hashtags, String? nextCursor
});




}
/// @nodoc
class _$SearchResultsCopyWithImpl<$Res>
    implements $SearchResultsCopyWith<$Res> {
  _$SearchResultsCopyWithImpl(this._self, this._then);

  final SearchResults _self;
  final $Res Function(SearchResults) _then;

/// Create a copy of SearchResults
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = null,Object? type = null,Object? posts = null,Object? users = null,Object? stocks = null,Object? hashtags = null,Object? nextCursor = freezed,}) {
  return _then(_self.copyWith(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SearchType,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as List<Post>,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<UserSearchResult>,stocks: null == stocks ? _self.stocks : stocks // ignore: cast_nullable_to_non_nullable
as List<StockSearchResult>,hashtags: null == hashtags ? _self.hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<HashtagSummary>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchResults].
extension SearchResultsPatterns on SearchResults {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchResults value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchResults() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchResults value)  $default,){
final _that = this;
switch (_that) {
case _SearchResults():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchResults value)?  $default,){
final _that = this;
switch (_that) {
case _SearchResults() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String query,  SearchType type,  List<Post> posts,  List<UserSearchResult> users,  List<StockSearchResult> stocks,  List<HashtagSummary> hashtags,  String? nextCursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchResults() when $default != null:
return $default(_that.query,_that.type,_that.posts,_that.users,_that.stocks,_that.hashtags,_that.nextCursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String query,  SearchType type,  List<Post> posts,  List<UserSearchResult> users,  List<StockSearchResult> stocks,  List<HashtagSummary> hashtags,  String? nextCursor)  $default,) {final _that = this;
switch (_that) {
case _SearchResults():
return $default(_that.query,_that.type,_that.posts,_that.users,_that.stocks,_that.hashtags,_that.nextCursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String query,  SearchType type,  List<Post> posts,  List<UserSearchResult> users,  List<StockSearchResult> stocks,  List<HashtagSummary> hashtags,  String? nextCursor)?  $default,) {final _that = this;
switch (_that) {
case _SearchResults() when $default != null:
return $default(_that.query,_that.type,_that.posts,_that.users,_that.stocks,_that.hashtags,_that.nextCursor);case _:
  return null;

}
}

}

/// @nodoc


class _SearchResults extends SearchResults {
  const _SearchResults({required this.query, required this.type, final  List<Post> posts = const <Post>[], final  List<UserSearchResult> users = const <UserSearchResult>[], final  List<StockSearchResult> stocks = const <StockSearchResult>[], final  List<HashtagSummary> hashtags = const <HashtagSummary>[], this.nextCursor}): _posts = posts,_users = users,_stocks = stocks,_hashtags = hashtags,super._();
  

@override final  String query;
@override final  SearchType type;
 final  List<Post> _posts;
@override@JsonKey() List<Post> get posts {
  if (_posts is EqualUnmodifiableListView) return _posts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_posts);
}

 final  List<UserSearchResult> _users;
@override@JsonKey() List<UserSearchResult> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}

 final  List<StockSearchResult> _stocks;
@override@JsonKey() List<StockSearchResult> get stocks {
  if (_stocks is EqualUnmodifiableListView) return _stocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stocks);
}

 final  List<HashtagSummary> _hashtags;
@override@JsonKey() List<HashtagSummary> get hashtags {
  if (_hashtags is EqualUnmodifiableListView) return _hashtags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hashtags);
}

@override final  String? nextCursor;

/// Create a copy of SearchResults
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchResultsCopyWith<_SearchResults> get copyWith => __$SearchResultsCopyWithImpl<_SearchResults>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchResults&&(identical(other.query, query) || other.query == query)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._posts, _posts)&&const DeepCollectionEquality().equals(other._users, _users)&&const DeepCollectionEquality().equals(other._stocks, _stocks)&&const DeepCollectionEquality().equals(other._hashtags, _hashtags)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}


@override
int get hashCode => Object.hash(runtimeType,query,type,const DeepCollectionEquality().hash(_posts),const DeepCollectionEquality().hash(_users),const DeepCollectionEquality().hash(_stocks),const DeepCollectionEquality().hash(_hashtags),nextCursor);

@override
String toString() {
  return 'SearchResults(query: $query, type: $type, posts: $posts, users: $users, stocks: $stocks, hashtags: $hashtags, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$SearchResultsCopyWith<$Res> implements $SearchResultsCopyWith<$Res> {
  factory _$SearchResultsCopyWith(_SearchResults value, $Res Function(_SearchResults) _then) = __$SearchResultsCopyWithImpl;
@override @useResult
$Res call({
 String query, SearchType type, List<Post> posts, List<UserSearchResult> users, List<StockSearchResult> stocks, List<HashtagSummary> hashtags, String? nextCursor
});




}
/// @nodoc
class __$SearchResultsCopyWithImpl<$Res>
    implements _$SearchResultsCopyWith<$Res> {
  __$SearchResultsCopyWithImpl(this._self, this._then);

  final _SearchResults _self;
  final $Res Function(_SearchResults) _then;

/// Create a copy of SearchResults
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = null,Object? type = null,Object? posts = null,Object? users = null,Object? stocks = null,Object? hashtags = null,Object? nextCursor = freezed,}) {
  return _then(_SearchResults(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SearchType,posts: null == posts ? _self._posts : posts // ignore: cast_nullable_to_non_nullable
as List<Post>,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<UserSearchResult>,stocks: null == stocks ? _self._stocks : stocks // ignore: cast_nullable_to_non_nullable
as List<StockSearchResult>,hashtags: null == hashtags ? _self._hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<HashtagSummary>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
