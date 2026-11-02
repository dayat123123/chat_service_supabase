// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SupportState {

 LoadStatus get status; SupportHome? get home; List<SupportTopic> get topics; bool get picking; bool get history; bool get busy; SensitiveCheck get sensitive; Object? get error; Object? get actionError; int get actionErrorId; SupportNoticeKind? get notice; int get noticeId;
/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportStateCopyWith<SupportState> get copyWith => _$SupportStateCopyWithImpl<SupportState>(this as SupportState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportState&&(identical(other.status, status) || other.status == status)&&(identical(other.home, home) || other.home == home)&&const DeepCollectionEquality().equals(other.topics, topics)&&(identical(other.picking, picking) || other.picking == picking)&&(identical(other.history, history) || other.history == history)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.sensitive, sensitive) || other.sensitive == sensitive)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeId, noticeId) || other.noticeId == noticeId));
}


@override
int get hashCode => Object.hash(runtimeType,status,home,const DeepCollectionEquality().hash(topics),picking,history,busy,sensitive,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,notice,noticeId);

@override
String toString() {
  return 'SupportState(status: $status, home: $home, topics: $topics, picking: $picking, history: $history, busy: $busy, sensitive: $sensitive, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, notice: $notice, noticeId: $noticeId)';
}


}

/// @nodoc
abstract mixin class $SupportStateCopyWith<$Res>  {
  factory $SupportStateCopyWith(SupportState value, $Res Function(SupportState) _then) = _$SupportStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, SupportHome? home, List<SupportTopic> topics, bool picking, bool history, bool busy, SensitiveCheck sensitive, Object? error, Object? actionError, int actionErrorId, SupportNoticeKind? notice, int noticeId
});


$SupportHomeCopyWith<$Res>? get home;$SensitiveCheckCopyWith<$Res> get sensitive;

}
/// @nodoc
class _$SupportStateCopyWithImpl<$Res>
    implements $SupportStateCopyWith<$Res> {
  _$SupportStateCopyWithImpl(this._self, this._then);

  final SupportState _self;
  final $Res Function(SupportState) _then;

/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? home = freezed,Object? topics = null,Object? picking = null,Object? history = null,Object? busy = null,Object? sensitive = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? notice = freezed,Object? noticeId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,home: freezed == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as SupportHome?,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<SupportTopic>,picking: null == picking ? _self.picking : picking // ignore: cast_nullable_to_non_nullable
as bool,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,sensitive: null == sensitive ? _self.sensitive : sensitive // ignore: cast_nullable_to_non_nullable
as SensitiveCheck,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as SupportNoticeKind?,noticeId: null == noticeId ? _self.noticeId : noticeId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportHomeCopyWith<$Res>? get home {
    if (_self.home == null) {
    return null;
  }

  return $SupportHomeCopyWith<$Res>(_self.home!, (value) {
    return _then(_self.copyWith(home: value));
  });
}/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SensitiveCheckCopyWith<$Res> get sensitive {
  
  return $SensitiveCheckCopyWith<$Res>(_self.sensitive, (value) {
    return _then(_self.copyWith(sensitive: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupportState].
extension SupportStatePatterns on SupportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportState value)  $default,){
final _that = this;
switch (_that) {
case _SupportState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportState value)?  $default,){
final _that = this;
switch (_that) {
case _SupportState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  SupportHome? home,  List<SupportTopic> topics,  bool picking,  bool history,  bool busy,  SensitiveCheck sensitive,  Object? error,  Object? actionError,  int actionErrorId,  SupportNoticeKind? notice,  int noticeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportState() when $default != null:
return $default(_that.status,_that.home,_that.topics,_that.picking,_that.history,_that.busy,_that.sensitive,_that.error,_that.actionError,_that.actionErrorId,_that.notice,_that.noticeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  SupportHome? home,  List<SupportTopic> topics,  bool picking,  bool history,  bool busy,  SensitiveCheck sensitive,  Object? error,  Object? actionError,  int actionErrorId,  SupportNoticeKind? notice,  int noticeId)  $default,) {final _that = this;
switch (_that) {
case _SupportState():
return $default(_that.status,_that.home,_that.topics,_that.picking,_that.history,_that.busy,_that.sensitive,_that.error,_that.actionError,_that.actionErrorId,_that.notice,_that.noticeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  SupportHome? home,  List<SupportTopic> topics,  bool picking,  bool history,  bool busy,  SensitiveCheck sensitive,  Object? error,  Object? actionError,  int actionErrorId,  SupportNoticeKind? notice,  int noticeId)?  $default,) {final _that = this;
switch (_that) {
case _SupportState() when $default != null:
return $default(_that.status,_that.home,_that.topics,_that.picking,_that.history,_that.busy,_that.sensitive,_that.error,_that.actionError,_that.actionErrorId,_that.notice,_that.noticeId);case _:
  return null;

}
}

}

/// @nodoc


class _SupportState extends SupportState {
  const _SupportState({this.status = LoadStatus.initial, this.home, final  List<SupportTopic> topics = const <SupportTopic>[], this.picking = false, this.history = false, this.busy = false, this.sensitive = const SensitiveCheck(), this.error, this.actionError, this.actionErrorId = 0, this.notice, this.noticeId = 0}): _topics = topics,super._();
  

@override@JsonKey() final  LoadStatus status;
@override final  SupportHome? home;
 final  List<SupportTopic> _topics;
@override@JsonKey() List<SupportTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

@override@JsonKey() final  bool picking;
@override@JsonKey() final  bool history;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  SensitiveCheck sensitive;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;
@override final  SupportNoticeKind? notice;
@override@JsonKey() final  int noticeId;

/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportStateCopyWith<_SupportState> get copyWith => __$SupportStateCopyWithImpl<_SupportState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportState&&(identical(other.status, status) || other.status == status)&&(identical(other.home, home) || other.home == home)&&const DeepCollectionEquality().equals(other._topics, _topics)&&(identical(other.picking, picking) || other.picking == picking)&&(identical(other.history, history) || other.history == history)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.sensitive, sensitive) || other.sensitive == sensitive)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeId, noticeId) || other.noticeId == noticeId));
}


@override
int get hashCode => Object.hash(runtimeType,status,home,const DeepCollectionEquality().hash(_topics),picking,history,busy,sensitive,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,notice,noticeId);

@override
String toString() {
  return 'SupportState(status: $status, home: $home, topics: $topics, picking: $picking, history: $history, busy: $busy, sensitive: $sensitive, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, notice: $notice, noticeId: $noticeId)';
}


}

/// @nodoc
abstract mixin class _$SupportStateCopyWith<$Res> implements $SupportStateCopyWith<$Res> {
  factory _$SupportStateCopyWith(_SupportState value, $Res Function(_SupportState) _then) = __$SupportStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, SupportHome? home, List<SupportTopic> topics, bool picking, bool history, bool busy, SensitiveCheck sensitive, Object? error, Object? actionError, int actionErrorId, SupportNoticeKind? notice, int noticeId
});


@override $SupportHomeCopyWith<$Res>? get home;@override $SensitiveCheckCopyWith<$Res> get sensitive;

}
/// @nodoc
class __$SupportStateCopyWithImpl<$Res>
    implements _$SupportStateCopyWith<$Res> {
  __$SupportStateCopyWithImpl(this._self, this._then);

  final _SupportState _self;
  final $Res Function(_SupportState) _then;

/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? home = freezed,Object? topics = null,Object? picking = null,Object? history = null,Object? busy = null,Object? sensitive = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? notice = freezed,Object? noticeId = null,}) {
  return _then(_SupportState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,home: freezed == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as SupportHome?,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<SupportTopic>,picking: null == picking ? _self.picking : picking // ignore: cast_nullable_to_non_nullable
as bool,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,sensitive: null == sensitive ? _self.sensitive : sensitive // ignore: cast_nullable_to_non_nullable
as SensitiveCheck,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as SupportNoticeKind?,noticeId: null == noticeId ? _self.noticeId : noticeId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportHomeCopyWith<$Res>? get home {
    if (_self.home == null) {
    return null;
  }

  return $SupportHomeCopyWith<$Res>(_self.home!, (value) {
    return _then(_self.copyWith(home: value));
  });
}/// Create a copy of SupportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SensitiveCheckCopyWith<$Res> get sensitive {
  
  return $SensitiveCheckCopyWith<$Res>(_self.sensitive, (value) {
    return _then(_self.copyWith(sensitive: value));
  });
}
}

// dart format on
