// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comment_thread_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThreadState {

 LoadStatus get status; Post? get post; ThreadComment? get root; Map<String, ThreadComment> get comments; Map<String, List<String>> get children; String? get topCursor; bool get hasMoreTop; Set<String> get collapsed; Set<String> get loadingBranches; ThreadComment? get replyTo; bool get sending; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThreadStateCopyWith<ThreadState> get copyWith => _$ThreadStateCopyWithImpl<ThreadState>(this as ThreadState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThreadState&&(identical(other.status, status) || other.status == status)&&(identical(other.post, post) || other.post == post)&&(identical(other.root, root) || other.root == root)&&const DeepCollectionEquality().equals(other.comments, comments)&&const DeepCollectionEquality().equals(other.children, children)&&(identical(other.topCursor, topCursor) || other.topCursor == topCursor)&&(identical(other.hasMoreTop, hasMoreTop) || other.hasMoreTop == hasMoreTop)&&const DeepCollectionEquality().equals(other.collapsed, collapsed)&&const DeepCollectionEquality().equals(other.loadingBranches, loadingBranches)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&(identical(other.sending, sending) || other.sending == sending)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,post,root,const DeepCollectionEquality().hash(comments),const DeepCollectionEquality().hash(children),topCursor,hasMoreTop,const DeepCollectionEquality().hash(collapsed),const DeepCollectionEquality().hash(loadingBranches),replyTo,sending,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'ThreadState(status: $status, post: $post, root: $root, comments: $comments, children: $children, topCursor: $topCursor, hasMoreTop: $hasMoreTop, collapsed: $collapsed, loadingBranches: $loadingBranches, replyTo: $replyTo, sending: $sending, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $ThreadStateCopyWith<$Res>  {
  factory $ThreadStateCopyWith(ThreadState value, $Res Function(ThreadState) _then) = _$ThreadStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, Post? post, ThreadComment? root, Map<String, ThreadComment> comments, Map<String, List<String>> children, String? topCursor, bool hasMoreTop, Set<String> collapsed, Set<String> loadingBranches, ThreadComment? replyTo, bool sending, Object? error, Object? actionError, int actionErrorId
});


$PostCopyWith<$Res>? get post;$ThreadCommentCopyWith<$Res>? get root;$ThreadCommentCopyWith<$Res>? get replyTo;

}
/// @nodoc
class _$ThreadStateCopyWithImpl<$Res>
    implements $ThreadStateCopyWith<$Res> {
  _$ThreadStateCopyWithImpl(this._self, this._then);

  final ThreadState _self;
  final $Res Function(ThreadState) _then;

/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? post = freezed,Object? root = freezed,Object? comments = null,Object? children = null,Object? topCursor = freezed,Object? hasMoreTop = null,Object? collapsed = null,Object? loadingBranches = null,Object? replyTo = freezed,Object? sending = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,post: freezed == post ? _self.post : post // ignore: cast_nullable_to_non_nullable
as Post?,root: freezed == root ? _self.root : root // ignore: cast_nullable_to_non_nullable
as ThreadComment?,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as Map<String, ThreadComment>,children: null == children ? _self.children : children // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,topCursor: freezed == topCursor ? _self.topCursor : topCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMoreTop: null == hasMoreTop ? _self.hasMoreTop : hasMoreTop // ignore: cast_nullable_to_non_nullable
as bool,collapsed: null == collapsed ? _self.collapsed : collapsed // ignore: cast_nullable_to_non_nullable
as Set<String>,loadingBranches: null == loadingBranches ? _self.loadingBranches : loadingBranches // ignore: cast_nullable_to_non_nullable
as Set<String>,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as ThreadComment?,sending: null == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostCopyWith<$Res>? get post {
    if (_self.post == null) {
    return null;
  }

  return $PostCopyWith<$Res>(_self.post!, (value) {
    return _then(_self.copyWith(post: value));
  });
}/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadCommentCopyWith<$Res>? get root {
    if (_self.root == null) {
    return null;
  }

  return $ThreadCommentCopyWith<$Res>(_self.root!, (value) {
    return _then(_self.copyWith(root: value));
  });
}/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadCommentCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $ThreadCommentCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThreadState].
extension ThreadStatePatterns on ThreadState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThreadState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThreadState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThreadState value)  $default,){
final _that = this;
switch (_that) {
case _ThreadState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThreadState value)?  $default,){
final _that = this;
switch (_that) {
case _ThreadState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  Post? post,  ThreadComment? root,  Map<String, ThreadComment> comments,  Map<String, List<String>> children,  String? topCursor,  bool hasMoreTop,  Set<String> collapsed,  Set<String> loadingBranches,  ThreadComment? replyTo,  bool sending,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThreadState() when $default != null:
return $default(_that.status,_that.post,_that.root,_that.comments,_that.children,_that.topCursor,_that.hasMoreTop,_that.collapsed,_that.loadingBranches,_that.replyTo,_that.sending,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  Post? post,  ThreadComment? root,  Map<String, ThreadComment> comments,  Map<String, List<String>> children,  String? topCursor,  bool hasMoreTop,  Set<String> collapsed,  Set<String> loadingBranches,  ThreadComment? replyTo,  bool sending,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _ThreadState():
return $default(_that.status,_that.post,_that.root,_that.comments,_that.children,_that.topCursor,_that.hasMoreTop,_that.collapsed,_that.loadingBranches,_that.replyTo,_that.sending,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  Post? post,  ThreadComment? root,  Map<String, ThreadComment> comments,  Map<String, List<String>> children,  String? topCursor,  bool hasMoreTop,  Set<String> collapsed,  Set<String> loadingBranches,  ThreadComment? replyTo,  bool sending,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _ThreadState() when $default != null:
return $default(_that.status,_that.post,_that.root,_that.comments,_that.children,_that.topCursor,_that.hasMoreTop,_that.collapsed,_that.loadingBranches,_that.replyTo,_that.sending,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _ThreadState extends ThreadState {
  const _ThreadState({this.status = LoadStatus.initial, this.post, this.root, final  Map<String, ThreadComment> comments = const <String, ThreadComment>{}, final  Map<String, List<String>> children = const <String, List<String>>{}, this.topCursor, this.hasMoreTop = false, final  Set<String> collapsed = const <String>{}, final  Set<String> loadingBranches = const <String>{}, this.replyTo, this.sending = false, this.error, this.actionError, this.actionErrorId = 0}): _comments = comments,_children = children,_collapsed = collapsed,_loadingBranches = loadingBranches,super._();
  

@override@JsonKey() final  LoadStatus status;
@override final  Post? post;
@override final  ThreadComment? root;
 final  Map<String, ThreadComment> _comments;
@override@JsonKey() Map<String, ThreadComment> get comments {
  if (_comments is EqualUnmodifiableMapView) return _comments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_comments);
}

 final  Map<String, List<String>> _children;
@override@JsonKey() Map<String, List<String>> get children {
  if (_children is EqualUnmodifiableMapView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_children);
}

@override final  String? topCursor;
@override@JsonKey() final  bool hasMoreTop;
 final  Set<String> _collapsed;
@override@JsonKey() Set<String> get collapsed {
  if (_collapsed is EqualUnmodifiableSetView) return _collapsed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_collapsed);
}

 final  Set<String> _loadingBranches;
@override@JsonKey() Set<String> get loadingBranches {
  if (_loadingBranches is EqualUnmodifiableSetView) return _loadingBranches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_loadingBranches);
}

@override final  ThreadComment? replyTo;
@override@JsonKey() final  bool sending;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThreadStateCopyWith<_ThreadState> get copyWith => __$ThreadStateCopyWithImpl<_ThreadState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThreadState&&(identical(other.status, status) || other.status == status)&&(identical(other.post, post) || other.post == post)&&(identical(other.root, root) || other.root == root)&&const DeepCollectionEquality().equals(other._comments, _comments)&&const DeepCollectionEquality().equals(other._children, _children)&&(identical(other.topCursor, topCursor) || other.topCursor == topCursor)&&(identical(other.hasMoreTop, hasMoreTop) || other.hasMoreTop == hasMoreTop)&&const DeepCollectionEquality().equals(other._collapsed, _collapsed)&&const DeepCollectionEquality().equals(other._loadingBranches, _loadingBranches)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&(identical(other.sending, sending) || other.sending == sending)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,post,root,const DeepCollectionEquality().hash(_comments),const DeepCollectionEquality().hash(_children),topCursor,hasMoreTop,const DeepCollectionEquality().hash(_collapsed),const DeepCollectionEquality().hash(_loadingBranches),replyTo,sending,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'ThreadState(status: $status, post: $post, root: $root, comments: $comments, children: $children, topCursor: $topCursor, hasMoreTop: $hasMoreTop, collapsed: $collapsed, loadingBranches: $loadingBranches, replyTo: $replyTo, sending: $sending, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$ThreadStateCopyWith<$Res> implements $ThreadStateCopyWith<$Res> {
  factory _$ThreadStateCopyWith(_ThreadState value, $Res Function(_ThreadState) _then) = __$ThreadStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, Post? post, ThreadComment? root, Map<String, ThreadComment> comments, Map<String, List<String>> children, String? topCursor, bool hasMoreTop, Set<String> collapsed, Set<String> loadingBranches, ThreadComment? replyTo, bool sending, Object? error, Object? actionError, int actionErrorId
});


@override $PostCopyWith<$Res>? get post;@override $ThreadCommentCopyWith<$Res>? get root;@override $ThreadCommentCopyWith<$Res>? get replyTo;

}
/// @nodoc
class __$ThreadStateCopyWithImpl<$Res>
    implements _$ThreadStateCopyWith<$Res> {
  __$ThreadStateCopyWithImpl(this._self, this._then);

  final _ThreadState _self;
  final $Res Function(_ThreadState) _then;

/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? post = freezed,Object? root = freezed,Object? comments = null,Object? children = null,Object? topCursor = freezed,Object? hasMoreTop = null,Object? collapsed = null,Object? loadingBranches = null,Object? replyTo = freezed,Object? sending = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_ThreadState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,post: freezed == post ? _self.post : post // ignore: cast_nullable_to_non_nullable
as Post?,root: freezed == root ? _self.root : root // ignore: cast_nullable_to_non_nullable
as ThreadComment?,comments: null == comments ? _self._comments : comments // ignore: cast_nullable_to_non_nullable
as Map<String, ThreadComment>,children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,topCursor: freezed == topCursor ? _self.topCursor : topCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMoreTop: null == hasMoreTop ? _self.hasMoreTop : hasMoreTop // ignore: cast_nullable_to_non_nullable
as bool,collapsed: null == collapsed ? _self._collapsed : collapsed // ignore: cast_nullable_to_non_nullable
as Set<String>,loadingBranches: null == loadingBranches ? _self._loadingBranches : loadingBranches // ignore: cast_nullable_to_non_nullable
as Set<String>,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as ThreadComment?,sending: null == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostCopyWith<$Res>? get post {
    if (_self.post == null) {
    return null;
  }

  return $PostCopyWith<$Res>(_self.post!, (value) {
    return _then(_self.copyWith(post: value));
  });
}/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadCommentCopyWith<$Res>? get root {
    if (_self.root == null) {
    return null;
  }

  return $ThreadCommentCopyWith<$Res>(_self.root!, (value) {
    return _then(_self.copyWith(root: value));
  });
}/// Create a copy of ThreadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadCommentCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $ThreadCommentCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}
}

// dart format on
