// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationState {

 LoadStatus get status; Ticket? get ticket; bool get joined; bool get busy; List<QuickReply> get quickReplies; Object? get error; Object? get actionError; int get actionErrorId; ConversationNotice? get notice; int get noticeId; int get notesVersion;
/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationStateCopyWith<ConversationState> get copyWith => _$ConversationStateCopyWithImpl<ConversationState>(this as ConversationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationState&&(identical(other.status, status) || other.status == status)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.joined, joined) || other.joined == joined)&&(identical(other.busy, busy) || other.busy == busy)&&const DeepCollectionEquality().equals(other.quickReplies, quickReplies)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeId, noticeId) || other.noticeId == noticeId)&&(identical(other.notesVersion, notesVersion) || other.notesVersion == notesVersion));
}


@override
int get hashCode => Object.hash(runtimeType,status,ticket,joined,busy,const DeepCollectionEquality().hash(quickReplies),const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,notice,noticeId,notesVersion);

@override
String toString() {
  return 'ConversationState(status: $status, ticket: $ticket, joined: $joined, busy: $busy, quickReplies: $quickReplies, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, notice: $notice, noticeId: $noticeId, notesVersion: $notesVersion)';
}


}

/// @nodoc
abstract mixin class $ConversationStateCopyWith<$Res>  {
  factory $ConversationStateCopyWith(ConversationState value, $Res Function(ConversationState) _then) = _$ConversationStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, Ticket? ticket, bool joined, bool busy, List<QuickReply> quickReplies, Object? error, Object? actionError, int actionErrorId, ConversationNotice? notice, int noticeId, int notesVersion
});


$TicketCopyWith<$Res>? get ticket;

}
/// @nodoc
class _$ConversationStateCopyWithImpl<$Res>
    implements $ConversationStateCopyWith<$Res> {
  _$ConversationStateCopyWithImpl(this._self, this._then);

  final ConversationState _self;
  final $Res Function(ConversationState) _then;

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? ticket = freezed,Object? joined = null,Object? busy = null,Object? quickReplies = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? notice = freezed,Object? noticeId = null,Object? notesVersion = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as Ticket?,joined: null == joined ? _self.joined : joined // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,quickReplies: null == quickReplies ? _self.quickReplies : quickReplies // ignore: cast_nullable_to_non_nullable
as List<QuickReply>,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ConversationNotice?,noticeId: null == noticeId ? _self.noticeId : noticeId // ignore: cast_nullable_to_non_nullable
as int,notesVersion: null == notesVersion ? _self.notesVersion : notesVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $TicketCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConversationState].
extension ConversationStatePatterns on ConversationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationState value)  $default,){
final _that = this;
switch (_that) {
case _ConversationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationState value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  Ticket? ticket,  bool joined,  bool busy,  List<QuickReply> quickReplies,  Object? error,  Object? actionError,  int actionErrorId,  ConversationNotice? notice,  int noticeId,  int notesVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
return $default(_that.status,_that.ticket,_that.joined,_that.busy,_that.quickReplies,_that.error,_that.actionError,_that.actionErrorId,_that.notice,_that.noticeId,_that.notesVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  Ticket? ticket,  bool joined,  bool busy,  List<QuickReply> quickReplies,  Object? error,  Object? actionError,  int actionErrorId,  ConversationNotice? notice,  int noticeId,  int notesVersion)  $default,) {final _that = this;
switch (_that) {
case _ConversationState():
return $default(_that.status,_that.ticket,_that.joined,_that.busy,_that.quickReplies,_that.error,_that.actionError,_that.actionErrorId,_that.notice,_that.noticeId,_that.notesVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  Ticket? ticket,  bool joined,  bool busy,  List<QuickReply> quickReplies,  Object? error,  Object? actionError,  int actionErrorId,  ConversationNotice? notice,  int noticeId,  int notesVersion)?  $default,) {final _that = this;
switch (_that) {
case _ConversationState() when $default != null:
return $default(_that.status,_that.ticket,_that.joined,_that.busy,_that.quickReplies,_that.error,_that.actionError,_that.actionErrorId,_that.notice,_that.noticeId,_that.notesVersion);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationState extends ConversationState {
  const _ConversationState({this.status = LoadStatus.initial, this.ticket, this.joined = false, this.busy = false, final  List<QuickReply> quickReplies = const <QuickReply>[], this.error, this.actionError, this.actionErrorId = 0, this.notice, this.noticeId = 0, this.notesVersion = 0}): _quickReplies = quickReplies,super._();
  

@override@JsonKey() final  LoadStatus status;
@override final  Ticket? ticket;
@override@JsonKey() final  bool joined;
@override@JsonKey() final  bool busy;
 final  List<QuickReply> _quickReplies;
@override@JsonKey() List<QuickReply> get quickReplies {
  if (_quickReplies is EqualUnmodifiableListView) return _quickReplies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_quickReplies);
}

@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;
@override final  ConversationNotice? notice;
@override@JsonKey() final  int noticeId;
@override@JsonKey() final  int notesVersion;

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationStateCopyWith<_ConversationState> get copyWith => __$ConversationStateCopyWithImpl<_ConversationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationState&&(identical(other.status, status) || other.status == status)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.joined, joined) || other.joined == joined)&&(identical(other.busy, busy) || other.busy == busy)&&const DeepCollectionEquality().equals(other._quickReplies, _quickReplies)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeId, noticeId) || other.noticeId == noticeId)&&(identical(other.notesVersion, notesVersion) || other.notesVersion == notesVersion));
}


@override
int get hashCode => Object.hash(runtimeType,status,ticket,joined,busy,const DeepCollectionEquality().hash(_quickReplies),const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId,notice,noticeId,notesVersion);

@override
String toString() {
  return 'ConversationState(status: $status, ticket: $ticket, joined: $joined, busy: $busy, quickReplies: $quickReplies, error: $error, actionError: $actionError, actionErrorId: $actionErrorId, notice: $notice, noticeId: $noticeId, notesVersion: $notesVersion)';
}


}

/// @nodoc
abstract mixin class _$ConversationStateCopyWith<$Res> implements $ConversationStateCopyWith<$Res> {
  factory _$ConversationStateCopyWith(_ConversationState value, $Res Function(_ConversationState) _then) = __$ConversationStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, Ticket? ticket, bool joined, bool busy, List<QuickReply> quickReplies, Object? error, Object? actionError, int actionErrorId, ConversationNotice? notice, int noticeId, int notesVersion
});


@override $TicketCopyWith<$Res>? get ticket;

}
/// @nodoc
class __$ConversationStateCopyWithImpl<$Res>
    implements _$ConversationStateCopyWith<$Res> {
  __$ConversationStateCopyWithImpl(this._self, this._then);

  final _ConversationState _self;
  final $Res Function(_ConversationState) _then;

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? ticket = freezed,Object? joined = null,Object? busy = null,Object? quickReplies = null,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,Object? notice = freezed,Object? noticeId = null,Object? notesVersion = null,}) {
  return _then(_ConversationState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as Ticket?,joined: null == joined ? _self.joined : joined // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,quickReplies: null == quickReplies ? _self._quickReplies : quickReplies // ignore: cast_nullable_to_non_nullable
as List<QuickReply>,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ConversationNotice?,noticeId: null == noticeId ? _self.noticeId : noticeId // ignore: cast_nullable_to_non_nullable
as int,notesVersion: null == notesVersion ? _self.notesVersion : notesVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ConversationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $TicketCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}

// dart format on
