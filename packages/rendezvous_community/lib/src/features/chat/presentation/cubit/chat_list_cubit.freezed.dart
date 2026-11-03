// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_list_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatListState {

 LoadStatus get status; List<ChatRoom> get rooms; String? get nextCursor; bool get loadingMore; Map<String, Set<String>> get presence; Map<String, Map<String, UserSummary>> get typing; UserSummary? get me; Object? get error; bool get stale;
/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatListStateCopyWith<ChatListState> get copyWith => _$ChatListStateCopyWithImpl<ChatListState>(this as ChatListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatListState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.rooms, rooms)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&const DeepCollectionEquality().equals(other.presence, presence)&&const DeepCollectionEquality().equals(other.typing, typing)&&(identical(other.me, me) || other.me == me)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.stale, stale) || other.stale == stale));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(rooms),nextCursor,loadingMore,const DeepCollectionEquality().hash(presence),const DeepCollectionEquality().hash(typing),me,const DeepCollectionEquality().hash(error),stale);

@override
String toString() {
  return 'ChatListState(status: $status, rooms: $rooms, nextCursor: $nextCursor, loadingMore: $loadingMore, presence: $presence, typing: $typing, me: $me, error: $error, stale: $stale)';
}


}

/// @nodoc
abstract mixin class $ChatListStateCopyWith<$Res>  {
  factory $ChatListStateCopyWith(ChatListState value, $Res Function(ChatListState) _then) = _$ChatListStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<ChatRoom> rooms, String? nextCursor, bool loadingMore, Map<String, Set<String>> presence, Map<String, Map<String, UserSummary>> typing, UserSummary? me, Object? error, bool stale
});


$UserSummaryCopyWith<$Res>? get me;

}
/// @nodoc
class _$ChatListStateCopyWithImpl<$Res>
    implements $ChatListStateCopyWith<$Res> {
  _$ChatListStateCopyWithImpl(this._self, this._then);

  final ChatListState _self;
  final $Res Function(ChatListState) _then;

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? rooms = null,Object? nextCursor = freezed,Object? loadingMore = null,Object? presence = null,Object? typing = null,Object? me = freezed,Object? error = freezed,Object? stale = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,rooms: null == rooms ? _self.rooms : rooms // ignore: cast_nullable_to_non_nullable
as List<ChatRoom>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,typing: null == typing ? _self.typing : typing // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, UserSummary>>,me: freezed == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as UserSummary?,error: freezed == error ? _self.error : error ,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get me {
    if (_self.me == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.me!, (value) {
    return _then(_self.copyWith(me: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatListState].
extension ChatListStatePatterns on ChatListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatListState value)  $default,){
final _that = this;
switch (_that) {
case _ChatListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatListState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<ChatRoom> rooms,  String? nextCursor,  bool loadingMore,  Map<String, Set<String>> presence,  Map<String, Map<String, UserSummary>> typing,  UserSummary? me,  Object? error,  bool stale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
return $default(_that.status,_that.rooms,_that.nextCursor,_that.loadingMore,_that.presence,_that.typing,_that.me,_that.error,_that.stale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<ChatRoom> rooms,  String? nextCursor,  bool loadingMore,  Map<String, Set<String>> presence,  Map<String, Map<String, UserSummary>> typing,  UserSummary? me,  Object? error,  bool stale)  $default,) {final _that = this;
switch (_that) {
case _ChatListState():
return $default(_that.status,_that.rooms,_that.nextCursor,_that.loadingMore,_that.presence,_that.typing,_that.me,_that.error,_that.stale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<ChatRoom> rooms,  String? nextCursor,  bool loadingMore,  Map<String, Set<String>> presence,  Map<String, Map<String, UserSummary>> typing,  UserSummary? me,  Object? error,  bool stale)?  $default,) {final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
return $default(_that.status,_that.rooms,_that.nextCursor,_that.loadingMore,_that.presence,_that.typing,_that.me,_that.error,_that.stale);case _:
  return null;

}
}

}

/// @nodoc


class _ChatListState extends ChatListState {
  const _ChatListState({this.status = LoadStatus.initial, final  List<ChatRoom> rooms = const <ChatRoom>[], this.nextCursor, this.loadingMore = false, final  Map<String, Set<String>> presence = const <String, Set<String>>{}, final  Map<String, Map<String, UserSummary>> typing = const <String, Map<String, UserSummary>>{}, this.me, this.error, this.stale = false}): _rooms = rooms,_presence = presence,_typing = typing,super._();
  

@override@JsonKey() final  LoadStatus status;
 final  List<ChatRoom> _rooms;
@override@JsonKey() List<ChatRoom> get rooms {
  if (_rooms is EqualUnmodifiableListView) return _rooms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rooms);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool loadingMore;
 final  Map<String, Set<String>> _presence;
@override@JsonKey() Map<String, Set<String>> get presence {
  if (_presence is EqualUnmodifiableMapView) return _presence;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_presence);
}

 final  Map<String, Map<String, UserSummary>> _typing;
@override@JsonKey() Map<String, Map<String, UserSummary>> get typing {
  if (_typing is EqualUnmodifiableMapView) return _typing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_typing);
}

@override final  UserSummary? me;
@override final  Object? error;
@override@JsonKey() final  bool stale;

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatListStateCopyWith<_ChatListState> get copyWith => __$ChatListStateCopyWithImpl<_ChatListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatListState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._rooms, _rooms)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&const DeepCollectionEquality().equals(other._presence, _presence)&&const DeepCollectionEquality().equals(other._typing, _typing)&&(identical(other.me, me) || other.me == me)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.stale, stale) || other.stale == stale));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_rooms),nextCursor,loadingMore,const DeepCollectionEquality().hash(_presence),const DeepCollectionEquality().hash(_typing),me,const DeepCollectionEquality().hash(error),stale);

@override
String toString() {
  return 'ChatListState(status: $status, rooms: $rooms, nextCursor: $nextCursor, loadingMore: $loadingMore, presence: $presence, typing: $typing, me: $me, error: $error, stale: $stale)';
}


}

/// @nodoc
abstract mixin class _$ChatListStateCopyWith<$Res> implements $ChatListStateCopyWith<$Res> {
  factory _$ChatListStateCopyWith(_ChatListState value, $Res Function(_ChatListState) _then) = __$ChatListStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<ChatRoom> rooms, String? nextCursor, bool loadingMore, Map<String, Set<String>> presence, Map<String, Map<String, UserSummary>> typing, UserSummary? me, Object? error, bool stale
});


@override $UserSummaryCopyWith<$Res>? get me;

}
/// @nodoc
class __$ChatListStateCopyWithImpl<$Res>
    implements _$ChatListStateCopyWith<$Res> {
  __$ChatListStateCopyWithImpl(this._self, this._then);

  final _ChatListState _self;
  final $Res Function(_ChatListState) _then;

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? rooms = null,Object? nextCursor = freezed,Object? loadingMore = null,Object? presence = null,Object? typing = null,Object? me = freezed,Object? error = freezed,Object? stale = null,}) {
  return _then(_ChatListState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,rooms: null == rooms ? _self._rooms : rooms // ignore: cast_nullable_to_non_nullable
as List<ChatRoom>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,presence: null == presence ? _self._presence : presence // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,typing: null == typing ? _self._typing : typing // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, UserSummary>>,me: freezed == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as UserSummary?,error: freezed == error ? _self.error : error ,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get me {
    if (_self.me == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.me!, (value) {
    return _then(_self.copyWith(me: value));
  });
}
}

// dart format on
