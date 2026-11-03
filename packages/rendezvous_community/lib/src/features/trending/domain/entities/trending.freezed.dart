// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HashtagSummary {

 String get tag; int get postCount; int get authorCount; double get score;
/// Create a copy of HashtagSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HashtagSummaryCopyWith<HashtagSummary> get copyWith => _$HashtagSummaryCopyWithImpl<HashtagSummary>(this as HashtagSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HashtagSummary&&(identical(other.tag, tag) || other.tag == tag)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.authorCount, authorCount) || other.authorCount == authorCount)&&(identical(other.score, score) || other.score == score));
}


@override
int get hashCode => Object.hash(runtimeType,tag,postCount,authorCount,score);

@override
String toString() {
  return 'HashtagSummary(tag: $tag, postCount: $postCount, authorCount: $authorCount, score: $score)';
}


}

/// @nodoc
abstract mixin class $HashtagSummaryCopyWith<$Res>  {
  factory $HashtagSummaryCopyWith(HashtagSummary value, $Res Function(HashtagSummary) _then) = _$HashtagSummaryCopyWithImpl;
@useResult
$Res call({
 String tag, int postCount, int authorCount, double score
});




}
/// @nodoc
class _$HashtagSummaryCopyWithImpl<$Res>
    implements $HashtagSummaryCopyWith<$Res> {
  _$HashtagSummaryCopyWithImpl(this._self, this._then);

  final HashtagSummary _self;
  final $Res Function(HashtagSummary) _then;

/// Create a copy of HashtagSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tag = null,Object? postCount = null,Object? authorCount = null,Object? score = null,}) {
  return _then(_self.copyWith(
tag: null == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,authorCount: null == authorCount ? _self.authorCount : authorCount // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [HashtagSummary].
extension HashtagSummaryPatterns on HashtagSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HashtagSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HashtagSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HashtagSummary value)  $default,){
final _that = this;
switch (_that) {
case _HashtagSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HashtagSummary value)?  $default,){
final _that = this;
switch (_that) {
case _HashtagSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tag,  int postCount,  int authorCount,  double score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HashtagSummary() when $default != null:
return $default(_that.tag,_that.postCount,_that.authorCount,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tag,  int postCount,  int authorCount,  double score)  $default,) {final _that = this;
switch (_that) {
case _HashtagSummary():
return $default(_that.tag,_that.postCount,_that.authorCount,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tag,  int postCount,  int authorCount,  double score)?  $default,) {final _that = this;
switch (_that) {
case _HashtagSummary() when $default != null:
return $default(_that.tag,_that.postCount,_that.authorCount,_that.score);case _:
  return null;

}
}

}

/// @nodoc


class _HashtagSummary implements HashtagSummary {
  const _HashtagSummary({required this.tag, this.postCount = 0, this.authorCount = 0, this.score = 0});
  

@override final  String tag;
@override@JsonKey() final  int postCount;
@override@JsonKey() final  int authorCount;
@override@JsonKey() final  double score;

/// Create a copy of HashtagSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HashtagSummaryCopyWith<_HashtagSummary> get copyWith => __$HashtagSummaryCopyWithImpl<_HashtagSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HashtagSummary&&(identical(other.tag, tag) || other.tag == tag)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.authorCount, authorCount) || other.authorCount == authorCount)&&(identical(other.score, score) || other.score == score));
}


@override
int get hashCode => Object.hash(runtimeType,tag,postCount,authorCount,score);

@override
String toString() {
  return 'HashtagSummary(tag: $tag, postCount: $postCount, authorCount: $authorCount, score: $score)';
}


}

/// @nodoc
abstract mixin class _$HashtagSummaryCopyWith<$Res> implements $HashtagSummaryCopyWith<$Res> {
  factory _$HashtagSummaryCopyWith(_HashtagSummary value, $Res Function(_HashtagSummary) _then) = __$HashtagSummaryCopyWithImpl;
@override @useResult
$Res call({
 String tag, int postCount, int authorCount, double score
});




}
/// @nodoc
class __$HashtagSummaryCopyWithImpl<$Res>
    implements _$HashtagSummaryCopyWith<$Res> {
  __$HashtagSummaryCopyWithImpl(this._self, this._then);

  final _HashtagSummary _self;
  final $Res Function(_HashtagSummary) _then;

/// Create a copy of HashtagSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tag = null,Object? postCount = null,Object? authorCount = null,Object? score = null,}) {
  return _then(_HashtagSummary(
tag: null == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,authorCount: null == authorCount ? _self.authorCount : authorCount // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$TrendingStock {

 String get code; int get posts; double get score; int? get bullishPct; int? get bearishPct; int? get neutralPct; double? get growthPct;
/// Create a copy of TrendingStock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingStockCopyWith<TrendingStock> get copyWith => _$TrendingStockCopyWithImpl<TrendingStock>(this as TrendingStock, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingStock&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.score, score) || other.score == score)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}


@override
int get hashCode => Object.hash(runtimeType,code,posts,score,bullishPct,bearishPct,neutralPct,growthPct);

@override
String toString() {
  return 'TrendingStock(code: $code, posts: $posts, score: $score, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class $TrendingStockCopyWith<$Res>  {
  factory $TrendingStockCopyWith(TrendingStock value, $Res Function(TrendingStock) _then) = _$TrendingStockCopyWithImpl;
@useResult
$Res call({
 String code, int posts, double score, int? bullishPct, int? bearishPct, int? neutralPct, double? growthPct
});




}
/// @nodoc
class _$TrendingStockCopyWithImpl<$Res>
    implements $TrendingStockCopyWith<$Res> {
  _$TrendingStockCopyWithImpl(this._self, this._then);

  final TrendingStock _self;
  final $Res Function(TrendingStock) _then;

/// Create a copy of TrendingStock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? posts = null,Object? score = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,Object? growthPct = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as double,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as int?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as int?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as int?,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendingStock].
extension TrendingStockPatterns on TrendingStock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingStock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingStock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingStock value)  $default,){
final _that = this;
switch (_that) {
case _TrendingStock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingStock value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingStock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int posts,  double score,  int? bullishPct,  int? bearishPct,  int? neutralPct,  double? growthPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingStock() when $default != null:
return $default(_that.code,_that.posts,_that.score,_that.bullishPct,_that.bearishPct,_that.neutralPct,_that.growthPct);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int posts,  double score,  int? bullishPct,  int? bearishPct,  int? neutralPct,  double? growthPct)  $default,) {final _that = this;
switch (_that) {
case _TrendingStock():
return $default(_that.code,_that.posts,_that.score,_that.bullishPct,_that.bearishPct,_that.neutralPct,_that.growthPct);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int posts,  double score,  int? bullishPct,  int? bearishPct,  int? neutralPct,  double? growthPct)?  $default,) {final _that = this;
switch (_that) {
case _TrendingStock() when $default != null:
return $default(_that.code,_that.posts,_that.score,_that.bullishPct,_that.bearishPct,_that.neutralPct,_that.growthPct);case _:
  return null;

}
}

}

/// @nodoc


class _TrendingStock implements TrendingStock {
  const _TrendingStock({required this.code, this.posts = 0, this.score = 0, this.bullishPct, this.bearishPct, this.neutralPct, this.growthPct});
  

@override final  String code;
@override@JsonKey() final  int posts;
@override@JsonKey() final  double score;
@override final  int? bullishPct;
@override final  int? bearishPct;
@override final  int? neutralPct;
@override final  double? growthPct;

/// Create a copy of TrendingStock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingStockCopyWith<_TrendingStock> get copyWith => __$TrendingStockCopyWithImpl<_TrendingStock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingStock&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.score, score) || other.score == score)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}


@override
int get hashCode => Object.hash(runtimeType,code,posts,score,bullishPct,bearishPct,neutralPct,growthPct);

@override
String toString() {
  return 'TrendingStock(code: $code, posts: $posts, score: $score, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class _$TrendingStockCopyWith<$Res> implements $TrendingStockCopyWith<$Res> {
  factory _$TrendingStockCopyWith(_TrendingStock value, $Res Function(_TrendingStock) _then) = __$TrendingStockCopyWithImpl;
@override @useResult
$Res call({
 String code, int posts, double score, int? bullishPct, int? bearishPct, int? neutralPct, double? growthPct
});




}
/// @nodoc
class __$TrendingStockCopyWithImpl<$Res>
    implements _$TrendingStockCopyWith<$Res> {
  __$TrendingStockCopyWithImpl(this._self, this._then);

  final _TrendingStock _self;
  final $Res Function(_TrendingStock) _then;

/// Create a copy of TrendingStock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? posts = null,Object? score = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,Object? growthPct = freezed,}) {
  return _then(_TrendingStock(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as double,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as int?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as int?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as int?,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$RisingStock {

 String get code; int get posts; int get prevPosts; double? get growthPct;
/// Create a copy of RisingStock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RisingStockCopyWith<RisingStock> get copyWith => _$RisingStockCopyWithImpl<RisingStock>(this as RisingStock, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RisingStock&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.prevPosts, prevPosts) || other.prevPosts == prevPosts)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}


@override
int get hashCode => Object.hash(runtimeType,code,posts,prevPosts,growthPct);

@override
String toString() {
  return 'RisingStock(code: $code, posts: $posts, prevPosts: $prevPosts, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class $RisingStockCopyWith<$Res>  {
  factory $RisingStockCopyWith(RisingStock value, $Res Function(RisingStock) _then) = _$RisingStockCopyWithImpl;
@useResult
$Res call({
 String code, int posts, int prevPosts, double? growthPct
});




}
/// @nodoc
class _$RisingStockCopyWithImpl<$Res>
    implements $RisingStockCopyWith<$Res> {
  _$RisingStockCopyWithImpl(this._self, this._then);

  final RisingStock _self;
  final $Res Function(RisingStock) _then;

/// Create a copy of RisingStock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? posts = null,Object? prevPosts = null,Object? growthPct = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,prevPosts: null == prevPosts ? _self.prevPosts : prevPosts // ignore: cast_nullable_to_non_nullable
as int,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [RisingStock].
extension RisingStockPatterns on RisingStock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RisingStock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RisingStock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RisingStock value)  $default,){
final _that = this;
switch (_that) {
case _RisingStock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RisingStock value)?  $default,){
final _that = this;
switch (_that) {
case _RisingStock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int posts,  int prevPosts,  double? growthPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RisingStock() when $default != null:
return $default(_that.code,_that.posts,_that.prevPosts,_that.growthPct);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int posts,  int prevPosts,  double? growthPct)  $default,) {final _that = this;
switch (_that) {
case _RisingStock():
return $default(_that.code,_that.posts,_that.prevPosts,_that.growthPct);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int posts,  int prevPosts,  double? growthPct)?  $default,) {final _that = this;
switch (_that) {
case _RisingStock() when $default != null:
return $default(_that.code,_that.posts,_that.prevPosts,_that.growthPct);case _:
  return null;

}
}

}

/// @nodoc


class _RisingStock implements RisingStock {
  const _RisingStock({required this.code, this.posts = 0, this.prevPosts = 0, this.growthPct});
  

@override final  String code;
@override@JsonKey() final  int posts;
@override@JsonKey() final  int prevPosts;
@override final  double? growthPct;

/// Create a copy of RisingStock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RisingStockCopyWith<_RisingStock> get copyWith => __$RisingStockCopyWithImpl<_RisingStock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RisingStock&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.prevPosts, prevPosts) || other.prevPosts == prevPosts)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}


@override
int get hashCode => Object.hash(runtimeType,code,posts,prevPosts,growthPct);

@override
String toString() {
  return 'RisingStock(code: $code, posts: $posts, prevPosts: $prevPosts, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class _$RisingStockCopyWith<$Res> implements $RisingStockCopyWith<$Res> {
  factory _$RisingStockCopyWith(_RisingStock value, $Res Function(_RisingStock) _then) = __$RisingStockCopyWithImpl;
@override @useResult
$Res call({
 String code, int posts, int prevPosts, double? growthPct
});




}
/// @nodoc
class __$RisingStockCopyWithImpl<$Res>
    implements _$RisingStockCopyWith<$Res> {
  __$RisingStockCopyWithImpl(this._self, this._then);

  final _RisingStock _self;
  final $Res Function(_RisingStock) _then;

/// Create a copy of RisingStock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? posts = null,Object? prevPosts = null,Object? growthPct = freezed,}) {
  return _then(_RisingStock(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,prevPosts: null == prevPosts ? _self.prevPosts : prevPosts // ignore: cast_nullable_to_non_nullable
as int,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$TrendingSnapshot {

 TrendWindow get window; DateTime? get computedAt; List<TrendingStock> get stocks; List<RisingStock> get rising; List<Post> get posts; List<HashtagSummary> get hashtags;
/// Create a copy of TrendingSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingSnapshotCopyWith<TrendingSnapshot> get copyWith => _$TrendingSnapshotCopyWithImpl<TrendingSnapshot>(this as TrendingSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingSnapshot&&(identical(other.window, window) || other.window == window)&&(identical(other.computedAt, computedAt) || other.computedAt == computedAt)&&const DeepCollectionEquality().equals(other.stocks, stocks)&&const DeepCollectionEquality().equals(other.rising, rising)&&const DeepCollectionEquality().equals(other.posts, posts)&&const DeepCollectionEquality().equals(other.hashtags, hashtags));
}


@override
int get hashCode => Object.hash(runtimeType,window,computedAt,const DeepCollectionEquality().hash(stocks),const DeepCollectionEquality().hash(rising),const DeepCollectionEquality().hash(posts),const DeepCollectionEquality().hash(hashtags));

@override
String toString() {
  return 'TrendingSnapshot(window: $window, computedAt: $computedAt, stocks: $stocks, rising: $rising, posts: $posts, hashtags: $hashtags)';
}


}

/// @nodoc
abstract mixin class $TrendingSnapshotCopyWith<$Res>  {
  factory $TrendingSnapshotCopyWith(TrendingSnapshot value, $Res Function(TrendingSnapshot) _then) = _$TrendingSnapshotCopyWithImpl;
@useResult
$Res call({
 TrendWindow window, DateTime? computedAt, List<TrendingStock> stocks, List<RisingStock> rising, List<Post> posts, List<HashtagSummary> hashtags
});




}
/// @nodoc
class _$TrendingSnapshotCopyWithImpl<$Res>
    implements $TrendingSnapshotCopyWith<$Res> {
  _$TrendingSnapshotCopyWithImpl(this._self, this._then);

  final TrendingSnapshot _self;
  final $Res Function(TrendingSnapshot) _then;

/// Create a copy of TrendingSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? window = null,Object? computedAt = freezed,Object? stocks = null,Object? rising = null,Object? posts = null,Object? hashtags = null,}) {
  return _then(_self.copyWith(
window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,computedAt: freezed == computedAt ? _self.computedAt : computedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stocks: null == stocks ? _self.stocks : stocks // ignore: cast_nullable_to_non_nullable
as List<TrendingStock>,rising: null == rising ? _self.rising : rising // ignore: cast_nullable_to_non_nullable
as List<RisingStock>,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as List<Post>,hashtags: null == hashtags ? _self.hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<HashtagSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendingSnapshot].
extension TrendingSnapshotPatterns on TrendingSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _TrendingSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TrendWindow window,  DateTime? computedAt,  List<TrendingStock> stocks,  List<RisingStock> rising,  List<Post> posts,  List<HashtagSummary> hashtags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingSnapshot() when $default != null:
return $default(_that.window,_that.computedAt,_that.stocks,_that.rising,_that.posts,_that.hashtags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TrendWindow window,  DateTime? computedAt,  List<TrendingStock> stocks,  List<RisingStock> rising,  List<Post> posts,  List<HashtagSummary> hashtags)  $default,) {final _that = this;
switch (_that) {
case _TrendingSnapshot():
return $default(_that.window,_that.computedAt,_that.stocks,_that.rising,_that.posts,_that.hashtags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TrendWindow window,  DateTime? computedAt,  List<TrendingStock> stocks,  List<RisingStock> rising,  List<Post> posts,  List<HashtagSummary> hashtags)?  $default,) {final _that = this;
switch (_that) {
case _TrendingSnapshot() when $default != null:
return $default(_that.window,_that.computedAt,_that.stocks,_that.rising,_that.posts,_that.hashtags);case _:
  return null;

}
}

}

/// @nodoc


class _TrendingSnapshot implements TrendingSnapshot {
  const _TrendingSnapshot({required this.window, this.computedAt, final  List<TrendingStock> stocks = const <TrendingStock>[], final  List<RisingStock> rising = const <RisingStock>[], final  List<Post> posts = const <Post>[], final  List<HashtagSummary> hashtags = const <HashtagSummary>[]}): _stocks = stocks,_rising = rising,_posts = posts,_hashtags = hashtags;
  

@override final  TrendWindow window;
@override final  DateTime? computedAt;
 final  List<TrendingStock> _stocks;
@override@JsonKey() List<TrendingStock> get stocks {
  if (_stocks is EqualUnmodifiableListView) return _stocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stocks);
}

 final  List<RisingStock> _rising;
@override@JsonKey() List<RisingStock> get rising {
  if (_rising is EqualUnmodifiableListView) return _rising;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rising);
}

 final  List<Post> _posts;
@override@JsonKey() List<Post> get posts {
  if (_posts is EqualUnmodifiableListView) return _posts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_posts);
}

 final  List<HashtagSummary> _hashtags;
@override@JsonKey() List<HashtagSummary> get hashtags {
  if (_hashtags is EqualUnmodifiableListView) return _hashtags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hashtags);
}


/// Create a copy of TrendingSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingSnapshotCopyWith<_TrendingSnapshot> get copyWith => __$TrendingSnapshotCopyWithImpl<_TrendingSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingSnapshot&&(identical(other.window, window) || other.window == window)&&(identical(other.computedAt, computedAt) || other.computedAt == computedAt)&&const DeepCollectionEquality().equals(other._stocks, _stocks)&&const DeepCollectionEquality().equals(other._rising, _rising)&&const DeepCollectionEquality().equals(other._posts, _posts)&&const DeepCollectionEquality().equals(other._hashtags, _hashtags));
}


@override
int get hashCode => Object.hash(runtimeType,window,computedAt,const DeepCollectionEquality().hash(_stocks),const DeepCollectionEquality().hash(_rising),const DeepCollectionEquality().hash(_posts),const DeepCollectionEquality().hash(_hashtags));

@override
String toString() {
  return 'TrendingSnapshot(window: $window, computedAt: $computedAt, stocks: $stocks, rising: $rising, posts: $posts, hashtags: $hashtags)';
}


}

/// @nodoc
abstract mixin class _$TrendingSnapshotCopyWith<$Res> implements $TrendingSnapshotCopyWith<$Res> {
  factory _$TrendingSnapshotCopyWith(_TrendingSnapshot value, $Res Function(_TrendingSnapshot) _then) = __$TrendingSnapshotCopyWithImpl;
@override @useResult
$Res call({
 TrendWindow window, DateTime? computedAt, List<TrendingStock> stocks, List<RisingStock> rising, List<Post> posts, List<HashtagSummary> hashtags
});




}
/// @nodoc
class __$TrendingSnapshotCopyWithImpl<$Res>
    implements _$TrendingSnapshotCopyWith<$Res> {
  __$TrendingSnapshotCopyWithImpl(this._self, this._then);

  final _TrendingSnapshot _self;
  final $Res Function(_TrendingSnapshot) _then;

/// Create a copy of TrendingSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? window = null,Object? computedAt = freezed,Object? stocks = null,Object? rising = null,Object? posts = null,Object? hashtags = null,}) {
  return _then(_TrendingSnapshot(
window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as TrendWindow,computedAt: freezed == computedAt ? _self.computedAt : computedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stocks: null == stocks ? _self._stocks : stocks // ignore: cast_nullable_to_non_nullable
as List<TrendingStock>,rising: null == rising ? _self._rising : rising // ignore: cast_nullable_to_non_nullable
as List<RisingStock>,posts: null == posts ? _self._posts : posts // ignore: cast_nullable_to_non_nullable
as List<Post>,hashtags: null == hashtags ? _self._hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<HashtagSummary>,
  ));
}


}

/// @nodoc
mixin _$SentimentBreakdown {

 int get posts; int get bullish; int get bearish; int get neutral; int get unlabeled; int? get bullishPct; int? get bearishPct; int? get neutralPct;
/// Create a copy of SentimentBreakdown
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SentimentBreakdownCopyWith<SentimentBreakdown> get copyWith => _$SentimentBreakdownCopyWithImpl<SentimentBreakdown>(this as SentimentBreakdown, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SentimentBreakdown&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.bullish, bullish) || other.bullish == bullish)&&(identical(other.bearish, bearish) || other.bearish == bearish)&&(identical(other.neutral, neutral) || other.neutral == neutral)&&(identical(other.unlabeled, unlabeled) || other.unlabeled == unlabeled)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct));
}


@override
int get hashCode => Object.hash(runtimeType,posts,bullish,bearish,neutral,unlabeled,bullishPct,bearishPct,neutralPct);

@override
String toString() {
  return 'SentimentBreakdown(posts: $posts, bullish: $bullish, bearish: $bearish, neutral: $neutral, unlabeled: $unlabeled, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct)';
}


}

/// @nodoc
abstract mixin class $SentimentBreakdownCopyWith<$Res>  {
  factory $SentimentBreakdownCopyWith(SentimentBreakdown value, $Res Function(SentimentBreakdown) _then) = _$SentimentBreakdownCopyWithImpl;
@useResult
$Res call({
 int posts, int bullish, int bearish, int neutral, int unlabeled, int? bullishPct, int? bearishPct, int? neutralPct
});




}
/// @nodoc
class _$SentimentBreakdownCopyWithImpl<$Res>
    implements $SentimentBreakdownCopyWith<$Res> {
  _$SentimentBreakdownCopyWithImpl(this._self, this._then);

  final SentimentBreakdown _self;
  final $Res Function(SentimentBreakdown) _then;

/// Create a copy of SentimentBreakdown
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? posts = null,Object? bullish = null,Object? bearish = null,Object? neutral = null,Object? unlabeled = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,}) {
  return _then(_self.copyWith(
posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,bullish: null == bullish ? _self.bullish : bullish // ignore: cast_nullable_to_non_nullable
as int,bearish: null == bearish ? _self.bearish : bearish // ignore: cast_nullable_to_non_nullable
as int,neutral: null == neutral ? _self.neutral : neutral // ignore: cast_nullable_to_non_nullable
as int,unlabeled: null == unlabeled ? _self.unlabeled : unlabeled // ignore: cast_nullable_to_non_nullable
as int,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as int?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as int?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SentimentBreakdown].
extension SentimentBreakdownPatterns on SentimentBreakdown {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SentimentBreakdown value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SentimentBreakdown() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SentimentBreakdown value)  $default,){
final _that = this;
switch (_that) {
case _SentimentBreakdown():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SentimentBreakdown value)?  $default,){
final _that = this;
switch (_that) {
case _SentimentBreakdown() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int posts,  int bullish,  int bearish,  int neutral,  int unlabeled,  int? bullishPct,  int? bearishPct,  int? neutralPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SentimentBreakdown() when $default != null:
return $default(_that.posts,_that.bullish,_that.bearish,_that.neutral,_that.unlabeled,_that.bullishPct,_that.bearishPct,_that.neutralPct);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int posts,  int bullish,  int bearish,  int neutral,  int unlabeled,  int? bullishPct,  int? bearishPct,  int? neutralPct)  $default,) {final _that = this;
switch (_that) {
case _SentimentBreakdown():
return $default(_that.posts,_that.bullish,_that.bearish,_that.neutral,_that.unlabeled,_that.bullishPct,_that.bearishPct,_that.neutralPct);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int posts,  int bullish,  int bearish,  int neutral,  int unlabeled,  int? bullishPct,  int? bearishPct,  int? neutralPct)?  $default,) {final _that = this;
switch (_that) {
case _SentimentBreakdown() when $default != null:
return $default(_that.posts,_that.bullish,_that.bearish,_that.neutral,_that.unlabeled,_that.bullishPct,_that.bearishPct,_that.neutralPct);case _:
  return null;

}
}

}

/// @nodoc


class _SentimentBreakdown extends SentimentBreakdown {
  const _SentimentBreakdown({this.posts = 0, this.bullish = 0, this.bearish = 0, this.neutral = 0, this.unlabeled = 0, this.bullishPct, this.bearishPct, this.neutralPct}): super._();
  

@override@JsonKey() final  int posts;
@override@JsonKey() final  int bullish;
@override@JsonKey() final  int bearish;
@override@JsonKey() final  int neutral;
@override@JsonKey() final  int unlabeled;
@override final  int? bullishPct;
@override final  int? bearishPct;
@override final  int? neutralPct;

/// Create a copy of SentimentBreakdown
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentimentBreakdownCopyWith<_SentimentBreakdown> get copyWith => __$SentimentBreakdownCopyWithImpl<_SentimentBreakdown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentimentBreakdown&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.bullish, bullish) || other.bullish == bullish)&&(identical(other.bearish, bearish) || other.bearish == bearish)&&(identical(other.neutral, neutral) || other.neutral == neutral)&&(identical(other.unlabeled, unlabeled) || other.unlabeled == unlabeled)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct));
}


@override
int get hashCode => Object.hash(runtimeType,posts,bullish,bearish,neutral,unlabeled,bullishPct,bearishPct,neutralPct);

@override
String toString() {
  return 'SentimentBreakdown(posts: $posts, bullish: $bullish, bearish: $bearish, neutral: $neutral, unlabeled: $unlabeled, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct)';
}


}

/// @nodoc
abstract mixin class _$SentimentBreakdownCopyWith<$Res> implements $SentimentBreakdownCopyWith<$Res> {
  factory _$SentimentBreakdownCopyWith(_SentimentBreakdown value, $Res Function(_SentimentBreakdown) _then) = __$SentimentBreakdownCopyWithImpl;
@override @useResult
$Res call({
 int posts, int bullish, int bearish, int neutral, int unlabeled, int? bullishPct, int? bearishPct, int? neutralPct
});




}
/// @nodoc
class __$SentimentBreakdownCopyWithImpl<$Res>
    implements _$SentimentBreakdownCopyWith<$Res> {
  __$SentimentBreakdownCopyWithImpl(this._self, this._then);

  final _SentimentBreakdown _self;
  final $Res Function(_SentimentBreakdown) _then;

/// Create a copy of SentimentBreakdown
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? posts = null,Object? bullish = null,Object? bearish = null,Object? neutral = null,Object? unlabeled = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,}) {
  return _then(_SentimentBreakdown(
posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,bullish: null == bullish ? _self.bullish : bullish // ignore: cast_nullable_to_non_nullable
as int,bearish: null == bearish ? _self.bearish : bearish // ignore: cast_nullable_to_non_nullable
as int,neutral: null == neutral ? _self.neutral : neutral // ignore: cast_nullable_to_non_nullable
as int,unlabeled: null == unlabeled ? _self.unlabeled : unlabeled // ignore: cast_nullable_to_non_nullable
as int,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as int?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as int?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$StockSentiment {

 String get code; SentimentBreakdown get day; SentimentBreakdown get week; DateTime? get updatedAt;
/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StockSentimentCopyWith<StockSentiment> get copyWith => _$StockSentimentCopyWithImpl<StockSentiment>(this as StockSentiment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StockSentiment&&(identical(other.code, code) || other.code == code)&&(identical(other.day, day) || other.day == day)&&(identical(other.week, week) || other.week == week)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,code,day,week,updatedAt);

@override
String toString() {
  return 'StockSentiment(code: $code, day: $day, week: $week, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $StockSentimentCopyWith<$Res>  {
  factory $StockSentimentCopyWith(StockSentiment value, $Res Function(StockSentiment) _then) = _$StockSentimentCopyWithImpl;
@useResult
$Res call({
 String code, SentimentBreakdown day, SentimentBreakdown week, DateTime? updatedAt
});


$SentimentBreakdownCopyWith<$Res> get day;$SentimentBreakdownCopyWith<$Res> get week;

}
/// @nodoc
class _$StockSentimentCopyWithImpl<$Res>
    implements $StockSentimentCopyWith<$Res> {
  _$StockSentimentCopyWithImpl(this._self, this._then);

  final StockSentiment _self;
  final $Res Function(StockSentiment) _then;

/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? day = null,Object? week = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as SentimentBreakdown,week: null == week ? _self.week : week // ignore: cast_nullable_to_non_nullable
as SentimentBreakdown,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SentimentBreakdownCopyWith<$Res> get day {
  
  return $SentimentBreakdownCopyWith<$Res>(_self.day, (value) {
    return _then(_self.copyWith(day: value));
  });
}/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SentimentBreakdownCopyWith<$Res> get week {
  
  return $SentimentBreakdownCopyWith<$Res>(_self.week, (value) {
    return _then(_self.copyWith(week: value));
  });
}
}


/// Adds pattern-matching-related methods to [StockSentiment].
extension StockSentimentPatterns on StockSentiment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StockSentiment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StockSentiment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StockSentiment value)  $default,){
final _that = this;
switch (_that) {
case _StockSentiment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StockSentiment value)?  $default,){
final _that = this;
switch (_that) {
case _StockSentiment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  SentimentBreakdown day,  SentimentBreakdown week,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StockSentiment() when $default != null:
return $default(_that.code,_that.day,_that.week,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  SentimentBreakdown day,  SentimentBreakdown week,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _StockSentiment():
return $default(_that.code,_that.day,_that.week,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  SentimentBreakdown day,  SentimentBreakdown week,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _StockSentiment() when $default != null:
return $default(_that.code,_that.day,_that.week,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _StockSentiment extends StockSentiment {
  const _StockSentiment({required this.code, this.day = const SentimentBreakdown(), this.week = const SentimentBreakdown(), this.updatedAt}): super._();
  

@override final  String code;
@override@JsonKey() final  SentimentBreakdown day;
@override@JsonKey() final  SentimentBreakdown week;
@override final  DateTime? updatedAt;

/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StockSentimentCopyWith<_StockSentiment> get copyWith => __$StockSentimentCopyWithImpl<_StockSentiment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StockSentiment&&(identical(other.code, code) || other.code == code)&&(identical(other.day, day) || other.day == day)&&(identical(other.week, week) || other.week == week)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,code,day,week,updatedAt);

@override
String toString() {
  return 'StockSentiment(code: $code, day: $day, week: $week, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$StockSentimentCopyWith<$Res> implements $StockSentimentCopyWith<$Res> {
  factory _$StockSentimentCopyWith(_StockSentiment value, $Res Function(_StockSentiment) _then) = __$StockSentimentCopyWithImpl;
@override @useResult
$Res call({
 String code, SentimentBreakdown day, SentimentBreakdown week, DateTime? updatedAt
});


@override $SentimentBreakdownCopyWith<$Res> get day;@override $SentimentBreakdownCopyWith<$Res> get week;

}
/// @nodoc
class __$StockSentimentCopyWithImpl<$Res>
    implements _$StockSentimentCopyWith<$Res> {
  __$StockSentimentCopyWithImpl(this._self, this._then);

  final _StockSentiment _self;
  final $Res Function(_StockSentiment) _then;

/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? day = null,Object? week = null,Object? updatedAt = freezed,}) {
  return _then(_StockSentiment(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as SentimentBreakdown,week: null == week ? _self.week : week // ignore: cast_nullable_to_non_nullable
as SentimentBreakdown,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SentimentBreakdownCopyWith<$Res> get day {
  
  return $SentimentBreakdownCopyWith<$Res>(_self.day, (value) {
    return _then(_self.copyWith(day: value));
  });
}/// Create a copy of StockSentiment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SentimentBreakdownCopyWith<$Res> get week {
  
  return $SentimentBreakdownCopyWith<$Res>(_self.week, (value) {
    return _then(_self.copyWith(week: value));
  });
}
}

// dart format on
