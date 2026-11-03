// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HashtagSummaryModel {

 String get tag; int? get postCount;@JsonKey(name: 'posts_7d') int? get posts7d; int get authorCount; num get score;
/// Create a copy of HashtagSummaryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HashtagSummaryModelCopyWith<HashtagSummaryModel> get copyWith => _$HashtagSummaryModelCopyWithImpl<HashtagSummaryModel>(this as HashtagSummaryModel, _$identity);

  /// Serializes this HashtagSummaryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HashtagSummaryModel&&(identical(other.tag, tag) || other.tag == tag)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.posts7d, posts7d) || other.posts7d == posts7d)&&(identical(other.authorCount, authorCount) || other.authorCount == authorCount)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tag,postCount,posts7d,authorCount,score);

@override
String toString() {
  return 'HashtagSummaryModel(tag: $tag, postCount: $postCount, posts7d: $posts7d, authorCount: $authorCount, score: $score)';
}


}

/// @nodoc
abstract mixin class $HashtagSummaryModelCopyWith<$Res>  {
  factory $HashtagSummaryModelCopyWith(HashtagSummaryModel value, $Res Function(HashtagSummaryModel) _then) = _$HashtagSummaryModelCopyWithImpl;
@useResult
$Res call({
 String tag, int? postCount,@JsonKey(name: 'posts_7d') int? posts7d, int authorCount, num score
});




}
/// @nodoc
class _$HashtagSummaryModelCopyWithImpl<$Res>
    implements $HashtagSummaryModelCopyWith<$Res> {
  _$HashtagSummaryModelCopyWithImpl(this._self, this._then);

  final HashtagSummaryModel _self;
  final $Res Function(HashtagSummaryModel) _then;

/// Create a copy of HashtagSummaryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tag = null,Object? postCount = freezed,Object? posts7d = freezed,Object? authorCount = null,Object? score = null,}) {
  return _then(_self.copyWith(
tag: null == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String,postCount: freezed == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int?,posts7d: freezed == posts7d ? _self.posts7d : posts7d // ignore: cast_nullable_to_non_nullable
as int?,authorCount: null == authorCount ? _self.authorCount : authorCount // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [HashtagSummaryModel].
extension HashtagSummaryModelPatterns on HashtagSummaryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HashtagSummaryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HashtagSummaryModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HashtagSummaryModel value)  $default,){
final _that = this;
switch (_that) {
case _HashtagSummaryModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HashtagSummaryModel value)?  $default,){
final _that = this;
switch (_that) {
case _HashtagSummaryModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tag,  int? postCount, @JsonKey(name: 'posts_7d')  int? posts7d,  int authorCount,  num score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HashtagSummaryModel() when $default != null:
return $default(_that.tag,_that.postCount,_that.posts7d,_that.authorCount,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tag,  int? postCount, @JsonKey(name: 'posts_7d')  int? posts7d,  int authorCount,  num score)  $default,) {final _that = this;
switch (_that) {
case _HashtagSummaryModel():
return $default(_that.tag,_that.postCount,_that.posts7d,_that.authorCount,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tag,  int? postCount, @JsonKey(name: 'posts_7d')  int? posts7d,  int authorCount,  num score)?  $default,) {final _that = this;
switch (_that) {
case _HashtagSummaryModel() when $default != null:
return $default(_that.tag,_that.postCount,_that.posts7d,_that.authorCount,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HashtagSummaryModel extends HashtagSummaryModel {
  const _HashtagSummaryModel({required this.tag, this.postCount, @JsonKey(name: 'posts_7d') this.posts7d, this.authorCount = 0, this.score = 0}): super._();
  factory _HashtagSummaryModel.fromJson(Map<String, dynamic> json) => _$HashtagSummaryModelFromJson(json);

@override final  String tag;
@override final  int? postCount;
@override@JsonKey(name: 'posts_7d') final  int? posts7d;
@override@JsonKey() final  int authorCount;
@override@JsonKey() final  num score;

/// Create a copy of HashtagSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HashtagSummaryModelCopyWith<_HashtagSummaryModel> get copyWith => __$HashtagSummaryModelCopyWithImpl<_HashtagSummaryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HashtagSummaryModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HashtagSummaryModel&&(identical(other.tag, tag) || other.tag == tag)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.posts7d, posts7d) || other.posts7d == posts7d)&&(identical(other.authorCount, authorCount) || other.authorCount == authorCount)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tag,postCount,posts7d,authorCount,score);

@override
String toString() {
  return 'HashtagSummaryModel(tag: $tag, postCount: $postCount, posts7d: $posts7d, authorCount: $authorCount, score: $score)';
}


}

/// @nodoc
abstract mixin class _$HashtagSummaryModelCopyWith<$Res> implements $HashtagSummaryModelCopyWith<$Res> {
  factory _$HashtagSummaryModelCopyWith(_HashtagSummaryModel value, $Res Function(_HashtagSummaryModel) _then) = __$HashtagSummaryModelCopyWithImpl;
@override @useResult
$Res call({
 String tag, int? postCount,@JsonKey(name: 'posts_7d') int? posts7d, int authorCount, num score
});




}
/// @nodoc
class __$HashtagSummaryModelCopyWithImpl<$Res>
    implements _$HashtagSummaryModelCopyWith<$Res> {
  __$HashtagSummaryModelCopyWithImpl(this._self, this._then);

  final _HashtagSummaryModel _self;
  final $Res Function(_HashtagSummaryModel) _then;

/// Create a copy of HashtagSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tag = null,Object? postCount = freezed,Object? posts7d = freezed,Object? authorCount = null,Object? score = null,}) {
  return _then(_HashtagSummaryModel(
tag: null == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String,postCount: freezed == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int?,posts7d: freezed == posts7d ? _self.posts7d : posts7d // ignore: cast_nullable_to_non_nullable
as int?,authorCount: null == authorCount ? _self.authorCount : authorCount // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$TrendingStockModel {

 String get code; int get posts; num get score; num? get bullishPct; num? get bearishPct; num? get neutralPct; num? get growthPct;
/// Create a copy of TrendingStockModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingStockModelCopyWith<TrendingStockModel> get copyWith => _$TrendingStockModelCopyWithImpl<TrendingStockModel>(this as TrendingStockModel, _$identity);

  /// Serializes this TrendingStockModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingStockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.score, score) || other.score == score)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,posts,score,bullishPct,bearishPct,neutralPct,growthPct);

@override
String toString() {
  return 'TrendingStockModel(code: $code, posts: $posts, score: $score, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class $TrendingStockModelCopyWith<$Res>  {
  factory $TrendingStockModelCopyWith(TrendingStockModel value, $Res Function(TrendingStockModel) _then) = _$TrendingStockModelCopyWithImpl;
@useResult
$Res call({
 String code, int posts, num score, num? bullishPct, num? bearishPct, num? neutralPct, num? growthPct
});




}
/// @nodoc
class _$TrendingStockModelCopyWithImpl<$Res>
    implements $TrendingStockModelCopyWith<$Res> {
  _$TrendingStockModelCopyWithImpl(this._self, this._then);

  final TrendingStockModel _self;
  final $Res Function(TrendingStockModel) _then;

/// Create a copy of TrendingStockModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? posts = null,Object? score = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,Object? growthPct = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as num,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as num?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as num?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as num?,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendingStockModel].
extension TrendingStockModelPatterns on TrendingStockModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingStockModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingStockModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingStockModel value)  $default,){
final _that = this;
switch (_that) {
case _TrendingStockModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingStockModel value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingStockModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int posts,  num score,  num? bullishPct,  num? bearishPct,  num? neutralPct,  num? growthPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingStockModel() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int posts,  num score,  num? bullishPct,  num? bearishPct,  num? neutralPct,  num? growthPct)  $default,) {final _that = this;
switch (_that) {
case _TrendingStockModel():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int posts,  num score,  num? bullishPct,  num? bearishPct,  num? neutralPct,  num? growthPct)?  $default,) {final _that = this;
switch (_that) {
case _TrendingStockModel() when $default != null:
return $default(_that.code,_that.posts,_that.score,_that.bullishPct,_that.bearishPct,_that.neutralPct,_that.growthPct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrendingStockModel extends TrendingStockModel {
  const _TrendingStockModel({required this.code, this.posts = 0, this.score = 0, this.bullishPct, this.bearishPct, this.neutralPct, this.growthPct}): super._();
  factory _TrendingStockModel.fromJson(Map<String, dynamic> json) => _$TrendingStockModelFromJson(json);

@override final  String code;
@override@JsonKey() final  int posts;
@override@JsonKey() final  num score;
@override final  num? bullishPct;
@override final  num? bearishPct;
@override final  num? neutralPct;
@override final  num? growthPct;

/// Create a copy of TrendingStockModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingStockModelCopyWith<_TrendingStockModel> get copyWith => __$TrendingStockModelCopyWithImpl<_TrendingStockModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrendingStockModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingStockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.score, score) || other.score == score)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,posts,score,bullishPct,bearishPct,neutralPct,growthPct);

@override
String toString() {
  return 'TrendingStockModel(code: $code, posts: $posts, score: $score, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class _$TrendingStockModelCopyWith<$Res> implements $TrendingStockModelCopyWith<$Res> {
  factory _$TrendingStockModelCopyWith(_TrendingStockModel value, $Res Function(_TrendingStockModel) _then) = __$TrendingStockModelCopyWithImpl;
@override @useResult
$Res call({
 String code, int posts, num score, num? bullishPct, num? bearishPct, num? neutralPct, num? growthPct
});




}
/// @nodoc
class __$TrendingStockModelCopyWithImpl<$Res>
    implements _$TrendingStockModelCopyWith<$Res> {
  __$TrendingStockModelCopyWithImpl(this._self, this._then);

  final _TrendingStockModel _self;
  final $Res Function(_TrendingStockModel) _then;

/// Create a copy of TrendingStockModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? posts = null,Object? score = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,Object? growthPct = freezed,}) {
  return _then(_TrendingStockModel(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as num,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as num?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as num?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as num?,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}


/// @nodoc
mixin _$RisingStockModel {

 String get code; int get posts; int get prevPosts; num? get growthPct;
/// Create a copy of RisingStockModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RisingStockModelCopyWith<RisingStockModel> get copyWith => _$RisingStockModelCopyWithImpl<RisingStockModel>(this as RisingStockModel, _$identity);

  /// Serializes this RisingStockModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RisingStockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.prevPosts, prevPosts) || other.prevPosts == prevPosts)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,posts,prevPosts,growthPct);

@override
String toString() {
  return 'RisingStockModel(code: $code, posts: $posts, prevPosts: $prevPosts, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class $RisingStockModelCopyWith<$Res>  {
  factory $RisingStockModelCopyWith(RisingStockModel value, $Res Function(RisingStockModel) _then) = _$RisingStockModelCopyWithImpl;
@useResult
$Res call({
 String code, int posts, int prevPosts, num? growthPct
});




}
/// @nodoc
class _$RisingStockModelCopyWithImpl<$Res>
    implements $RisingStockModelCopyWith<$Res> {
  _$RisingStockModelCopyWithImpl(this._self, this._then);

  final RisingStockModel _self;
  final $Res Function(RisingStockModel) _then;

/// Create a copy of RisingStockModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? posts = null,Object? prevPosts = null,Object? growthPct = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,prevPosts: null == prevPosts ? _self.prevPosts : prevPosts // ignore: cast_nullable_to_non_nullable
as int,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}


/// Adds pattern-matching-related methods to [RisingStockModel].
extension RisingStockModelPatterns on RisingStockModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RisingStockModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RisingStockModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RisingStockModel value)  $default,){
final _that = this;
switch (_that) {
case _RisingStockModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RisingStockModel value)?  $default,){
final _that = this;
switch (_that) {
case _RisingStockModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int posts,  int prevPosts,  num? growthPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RisingStockModel() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int posts,  int prevPosts,  num? growthPct)  $default,) {final _that = this;
switch (_that) {
case _RisingStockModel():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int posts,  int prevPosts,  num? growthPct)?  $default,) {final _that = this;
switch (_that) {
case _RisingStockModel() when $default != null:
return $default(_that.code,_that.posts,_that.prevPosts,_that.growthPct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RisingStockModel extends RisingStockModel {
  const _RisingStockModel({required this.code, this.posts = 0, this.prevPosts = 0, this.growthPct}): super._();
  factory _RisingStockModel.fromJson(Map<String, dynamic> json) => _$RisingStockModelFromJson(json);

@override final  String code;
@override@JsonKey() final  int posts;
@override@JsonKey() final  int prevPosts;
@override final  num? growthPct;

/// Create a copy of RisingStockModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RisingStockModelCopyWith<_RisingStockModel> get copyWith => __$RisingStockModelCopyWithImpl<_RisingStockModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RisingStockModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RisingStockModel&&(identical(other.code, code) || other.code == code)&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.prevPosts, prevPosts) || other.prevPosts == prevPosts)&&(identical(other.growthPct, growthPct) || other.growthPct == growthPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,posts,prevPosts,growthPct);

@override
String toString() {
  return 'RisingStockModel(code: $code, posts: $posts, prevPosts: $prevPosts, growthPct: $growthPct)';
}


}

/// @nodoc
abstract mixin class _$RisingStockModelCopyWith<$Res> implements $RisingStockModelCopyWith<$Res> {
  factory _$RisingStockModelCopyWith(_RisingStockModel value, $Res Function(_RisingStockModel) _then) = __$RisingStockModelCopyWithImpl;
@override @useResult
$Res call({
 String code, int posts, int prevPosts, num? growthPct
});




}
/// @nodoc
class __$RisingStockModelCopyWithImpl<$Res>
    implements _$RisingStockModelCopyWith<$Res> {
  __$RisingStockModelCopyWithImpl(this._self, this._then);

  final _RisingStockModel _self;
  final $Res Function(_RisingStockModel) _then;

/// Create a copy of RisingStockModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? posts = null,Object? prevPosts = null,Object? growthPct = freezed,}) {
  return _then(_RisingStockModel(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,prevPosts: null == prevPosts ? _self.prevPosts : prevPosts // ignore: cast_nullable_to_non_nullable
as int,growthPct: freezed == growthPct ? _self.growthPct : growthPct // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}


/// @nodoc
mixin _$SentimentBreakdownModel {

 int get posts; int get bullish; int get bearish; int get neutral; int get unlabeled; num? get bullishPct; num? get bearishPct; num? get neutralPct;
/// Create a copy of SentimentBreakdownModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SentimentBreakdownModelCopyWith<SentimentBreakdownModel> get copyWith => _$SentimentBreakdownModelCopyWithImpl<SentimentBreakdownModel>(this as SentimentBreakdownModel, _$identity);

  /// Serializes this SentimentBreakdownModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SentimentBreakdownModel&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.bullish, bullish) || other.bullish == bullish)&&(identical(other.bearish, bearish) || other.bearish == bearish)&&(identical(other.neutral, neutral) || other.neutral == neutral)&&(identical(other.unlabeled, unlabeled) || other.unlabeled == unlabeled)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,posts,bullish,bearish,neutral,unlabeled,bullishPct,bearishPct,neutralPct);

@override
String toString() {
  return 'SentimentBreakdownModel(posts: $posts, bullish: $bullish, bearish: $bearish, neutral: $neutral, unlabeled: $unlabeled, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct)';
}


}

/// @nodoc
abstract mixin class $SentimentBreakdownModelCopyWith<$Res>  {
  factory $SentimentBreakdownModelCopyWith(SentimentBreakdownModel value, $Res Function(SentimentBreakdownModel) _then) = _$SentimentBreakdownModelCopyWithImpl;
@useResult
$Res call({
 int posts, int bullish, int bearish, int neutral, int unlabeled, num? bullishPct, num? bearishPct, num? neutralPct
});




}
/// @nodoc
class _$SentimentBreakdownModelCopyWithImpl<$Res>
    implements $SentimentBreakdownModelCopyWith<$Res> {
  _$SentimentBreakdownModelCopyWithImpl(this._self, this._then);

  final SentimentBreakdownModel _self;
  final $Res Function(SentimentBreakdownModel) _then;

/// Create a copy of SentimentBreakdownModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? posts = null,Object? bullish = null,Object? bearish = null,Object? neutral = null,Object? unlabeled = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,}) {
  return _then(_self.copyWith(
posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,bullish: null == bullish ? _self.bullish : bullish // ignore: cast_nullable_to_non_nullable
as int,bearish: null == bearish ? _self.bearish : bearish // ignore: cast_nullable_to_non_nullable
as int,neutral: null == neutral ? _self.neutral : neutral // ignore: cast_nullable_to_non_nullable
as int,unlabeled: null == unlabeled ? _self.unlabeled : unlabeled // ignore: cast_nullable_to_non_nullable
as int,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as num?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as num?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}


/// Adds pattern-matching-related methods to [SentimentBreakdownModel].
extension SentimentBreakdownModelPatterns on SentimentBreakdownModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SentimentBreakdownModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SentimentBreakdownModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SentimentBreakdownModel value)  $default,){
final _that = this;
switch (_that) {
case _SentimentBreakdownModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SentimentBreakdownModel value)?  $default,){
final _that = this;
switch (_that) {
case _SentimentBreakdownModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int posts,  int bullish,  int bearish,  int neutral,  int unlabeled,  num? bullishPct,  num? bearishPct,  num? neutralPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SentimentBreakdownModel() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int posts,  int bullish,  int bearish,  int neutral,  int unlabeled,  num? bullishPct,  num? bearishPct,  num? neutralPct)  $default,) {final _that = this;
switch (_that) {
case _SentimentBreakdownModel():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int posts,  int bullish,  int bearish,  int neutral,  int unlabeled,  num? bullishPct,  num? bearishPct,  num? neutralPct)?  $default,) {final _that = this;
switch (_that) {
case _SentimentBreakdownModel() when $default != null:
return $default(_that.posts,_that.bullish,_that.bearish,_that.neutral,_that.unlabeled,_that.bullishPct,_that.bearishPct,_that.neutralPct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SentimentBreakdownModel extends SentimentBreakdownModel {
  const _SentimentBreakdownModel({this.posts = 0, this.bullish = 0, this.bearish = 0, this.neutral = 0, this.unlabeled = 0, this.bullishPct, this.bearishPct, this.neutralPct}): super._();
  factory _SentimentBreakdownModel.fromJson(Map<String, dynamic> json) => _$SentimentBreakdownModelFromJson(json);

@override@JsonKey() final  int posts;
@override@JsonKey() final  int bullish;
@override@JsonKey() final  int bearish;
@override@JsonKey() final  int neutral;
@override@JsonKey() final  int unlabeled;
@override final  num? bullishPct;
@override final  num? bearishPct;
@override final  num? neutralPct;

/// Create a copy of SentimentBreakdownModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentimentBreakdownModelCopyWith<_SentimentBreakdownModel> get copyWith => __$SentimentBreakdownModelCopyWithImpl<_SentimentBreakdownModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentimentBreakdownModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentimentBreakdownModel&&(identical(other.posts, posts) || other.posts == posts)&&(identical(other.bullish, bullish) || other.bullish == bullish)&&(identical(other.bearish, bearish) || other.bearish == bearish)&&(identical(other.neutral, neutral) || other.neutral == neutral)&&(identical(other.unlabeled, unlabeled) || other.unlabeled == unlabeled)&&(identical(other.bullishPct, bullishPct) || other.bullishPct == bullishPct)&&(identical(other.bearishPct, bearishPct) || other.bearishPct == bearishPct)&&(identical(other.neutralPct, neutralPct) || other.neutralPct == neutralPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,posts,bullish,bearish,neutral,unlabeled,bullishPct,bearishPct,neutralPct);

@override
String toString() {
  return 'SentimentBreakdownModel(posts: $posts, bullish: $bullish, bearish: $bearish, neutral: $neutral, unlabeled: $unlabeled, bullishPct: $bullishPct, bearishPct: $bearishPct, neutralPct: $neutralPct)';
}


}

/// @nodoc
abstract mixin class _$SentimentBreakdownModelCopyWith<$Res> implements $SentimentBreakdownModelCopyWith<$Res> {
  factory _$SentimentBreakdownModelCopyWith(_SentimentBreakdownModel value, $Res Function(_SentimentBreakdownModel) _then) = __$SentimentBreakdownModelCopyWithImpl;
@override @useResult
$Res call({
 int posts, int bullish, int bearish, int neutral, int unlabeled, num? bullishPct, num? bearishPct, num? neutralPct
});




}
/// @nodoc
class __$SentimentBreakdownModelCopyWithImpl<$Res>
    implements _$SentimentBreakdownModelCopyWith<$Res> {
  __$SentimentBreakdownModelCopyWithImpl(this._self, this._then);

  final _SentimentBreakdownModel _self;
  final $Res Function(_SentimentBreakdownModel) _then;

/// Create a copy of SentimentBreakdownModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? posts = null,Object? bullish = null,Object? bearish = null,Object? neutral = null,Object? unlabeled = null,Object? bullishPct = freezed,Object? bearishPct = freezed,Object? neutralPct = freezed,}) {
  return _then(_SentimentBreakdownModel(
posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as int,bullish: null == bullish ? _self.bullish : bullish // ignore: cast_nullable_to_non_nullable
as int,bearish: null == bearish ? _self.bearish : bearish // ignore: cast_nullable_to_non_nullable
as int,neutral: null == neutral ? _self.neutral : neutral // ignore: cast_nullable_to_non_nullable
as int,unlabeled: null == unlabeled ? _self.unlabeled : unlabeled // ignore: cast_nullable_to_non_nullable
as int,bullishPct: freezed == bullishPct ? _self.bullishPct : bullishPct // ignore: cast_nullable_to_non_nullable
as num?,bearishPct: freezed == bearishPct ? _self.bearishPct : bearishPct // ignore: cast_nullable_to_non_nullable
as num?,neutralPct: freezed == neutralPct ? _self.neutralPct : neutralPct // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}

// dart format on
