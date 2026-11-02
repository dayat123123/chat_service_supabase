// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pinned_post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PinnedPost {

 Post get post; bool get announcement; String? get title; DateTime? get pinnedUntil;
/// Create a copy of PinnedPost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PinnedPostCopyWith<PinnedPost> get copyWith => _$PinnedPostCopyWithImpl<PinnedPost>(this as PinnedPost, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PinnedPost&&(identical(other.post, post) || other.post == post)&&(identical(other.announcement, announcement) || other.announcement == announcement)&&(identical(other.title, title) || other.title == title)&&(identical(other.pinnedUntil, pinnedUntil) || other.pinnedUntil == pinnedUntil));
}


@override
int get hashCode => Object.hash(runtimeType,post,announcement,title,pinnedUntil);

@override
String toString() {
  return 'PinnedPost(post: $post, announcement: $announcement, title: $title, pinnedUntil: $pinnedUntil)';
}


}

/// @nodoc
abstract mixin class $PinnedPostCopyWith<$Res>  {
  factory $PinnedPostCopyWith(PinnedPost value, $Res Function(PinnedPost) _then) = _$PinnedPostCopyWithImpl;
@useResult
$Res call({
 Post post, bool announcement, String? title, DateTime? pinnedUntil
});


$PostCopyWith<$Res> get post;

}
/// @nodoc
class _$PinnedPostCopyWithImpl<$Res>
    implements $PinnedPostCopyWith<$Res> {
  _$PinnedPostCopyWithImpl(this._self, this._then);

  final PinnedPost _self;
  final $Res Function(PinnedPost) _then;

/// Create a copy of PinnedPost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? post = null,Object? announcement = null,Object? title = freezed,Object? pinnedUntil = freezed,}) {
  return _then(_self.copyWith(
post: null == post ? _self.post : post // ignore: cast_nullable_to_non_nullable
as Post,announcement: null == announcement ? _self.announcement : announcement // ignore: cast_nullable_to_non_nullable
as bool,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,pinnedUntil: freezed == pinnedUntil ? _self.pinnedUntil : pinnedUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of PinnedPost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostCopyWith<$Res> get post {
  
  return $PostCopyWith<$Res>(_self.post, (value) {
    return _then(_self.copyWith(post: value));
  });
}
}


/// Adds pattern-matching-related methods to [PinnedPost].
extension PinnedPostPatterns on PinnedPost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PinnedPost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PinnedPost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PinnedPost value)  $default,){
final _that = this;
switch (_that) {
case _PinnedPost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PinnedPost value)?  $default,){
final _that = this;
switch (_that) {
case _PinnedPost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Post post,  bool announcement,  String? title,  DateTime? pinnedUntil)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PinnedPost() when $default != null:
return $default(_that.post,_that.announcement,_that.title,_that.pinnedUntil);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Post post,  bool announcement,  String? title,  DateTime? pinnedUntil)  $default,) {final _that = this;
switch (_that) {
case _PinnedPost():
return $default(_that.post,_that.announcement,_that.title,_that.pinnedUntil);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Post post,  bool announcement,  String? title,  DateTime? pinnedUntil)?  $default,) {final _that = this;
switch (_that) {
case _PinnedPost() when $default != null:
return $default(_that.post,_that.announcement,_that.title,_that.pinnedUntil);case _:
  return null;

}
}

}

/// @nodoc


class _PinnedPost implements PinnedPost {
  const _PinnedPost({required this.post, this.announcement = false, this.title, this.pinnedUntil});
  

@override final  Post post;
@override@JsonKey() final  bool announcement;
@override final  String? title;
@override final  DateTime? pinnedUntil;

/// Create a copy of PinnedPost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PinnedPostCopyWith<_PinnedPost> get copyWith => __$PinnedPostCopyWithImpl<_PinnedPost>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PinnedPost&&(identical(other.post, post) || other.post == post)&&(identical(other.announcement, announcement) || other.announcement == announcement)&&(identical(other.title, title) || other.title == title)&&(identical(other.pinnedUntil, pinnedUntil) || other.pinnedUntil == pinnedUntil));
}


@override
int get hashCode => Object.hash(runtimeType,post,announcement,title,pinnedUntil);

@override
String toString() {
  return 'PinnedPost(post: $post, announcement: $announcement, title: $title, pinnedUntil: $pinnedUntil)';
}


}

/// @nodoc
abstract mixin class _$PinnedPostCopyWith<$Res> implements $PinnedPostCopyWith<$Res> {
  factory _$PinnedPostCopyWith(_PinnedPost value, $Res Function(_PinnedPost) _then) = __$PinnedPostCopyWithImpl;
@override @useResult
$Res call({
 Post post, bool announcement, String? title, DateTime? pinnedUntil
});


@override $PostCopyWith<$Res> get post;

}
/// @nodoc
class __$PinnedPostCopyWithImpl<$Res>
    implements _$PinnedPostCopyWith<$Res> {
  __$PinnedPostCopyWithImpl(this._self, this._then);

  final _PinnedPost _self;
  final $Res Function(_PinnedPost) _then;

/// Create a copy of PinnedPost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? post = null,Object? announcement = null,Object? title = freezed,Object? pinnedUntil = freezed,}) {
  return _then(_PinnedPost(
post: null == post ? _self.post : post // ignore: cast_nullable_to_non_nullable
as Post,announcement: null == announcement ? _self.announcement : announcement // ignore: cast_nullable_to_non_nullable
as bool,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,pinnedUntil: freezed == pinnedUntil ? _self.pinnedUntil : pinnedUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of PinnedPost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostCopyWith<$Res> get post {
  
  return $PostCopyWith<$Res>(_self.post, (value) {
    return _then(_self.copyWith(post: value));
  });
}
}

// dart format on
