// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'poll.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PollOption {

 String get id; String get label; int? get votes;
/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollOptionCopyWith<PollOption> get copyWith => _$PollOptionCopyWithImpl<PollOption>(this as PollOption, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.votes, votes) || other.votes == votes));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,votes);

@override
String toString() {
  return 'PollOption(id: $id, label: $label, votes: $votes)';
}


}

/// @nodoc
abstract mixin class $PollOptionCopyWith<$Res>  {
  factory $PollOptionCopyWith(PollOption value, $Res Function(PollOption) _then) = _$PollOptionCopyWithImpl;
@useResult
$Res call({
 String id, String label, int? votes
});




}
/// @nodoc
class _$PollOptionCopyWithImpl<$Res>
    implements $PollOptionCopyWith<$Res> {
  _$PollOptionCopyWithImpl(this._self, this._then);

  final PollOption _self;
  final $Res Function(PollOption) _then;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? votes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,votes: freezed == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PollOption].
extension PollOptionPatterns on PollOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollOption value)  $default,){
final _that = this;
switch (_that) {
case _PollOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollOption value)?  $default,){
final _that = this;
switch (_that) {
case _PollOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  int? votes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that.id,_that.label,_that.votes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  int? votes)  $default,) {final _that = this;
switch (_that) {
case _PollOption():
return $default(_that.id,_that.label,_that.votes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  int? votes)?  $default,) {final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that.id,_that.label,_that.votes);case _:
  return null;

}
}

}

/// @nodoc


class _PollOption implements PollOption {
  const _PollOption({required this.id, required this.label, this.votes});
  

@override final  String id;
@override final  String label;
@override final  int? votes;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollOptionCopyWith<_PollOption> get copyWith => __$PollOptionCopyWithImpl<_PollOption>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.votes, votes) || other.votes == votes));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,votes);

@override
String toString() {
  return 'PollOption(id: $id, label: $label, votes: $votes)';
}


}

/// @nodoc
abstract mixin class _$PollOptionCopyWith<$Res> implements $PollOptionCopyWith<$Res> {
  factory _$PollOptionCopyWith(_PollOption value, $Res Function(_PollOption) _then) = __$PollOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, int? votes
});




}
/// @nodoc
class __$PollOptionCopyWithImpl<$Res>
    implements _$PollOptionCopyWith<$Res> {
  __$PollOptionCopyWithImpl(this._self, this._then);

  final _PollOption _self;
  final $Res Function(_PollOption) _then;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? votes = freezed,}) {
  return _then(_PollOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,votes: freezed == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$Poll {

 DateTime get endsAt; bool get closed; int get totalVotes; String? get myOptionId; bool get resultsVisible; List<PollOption> get options;
/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollCopyWith<Poll> get copyWith => _$PollCopyWithImpl<Poll>(this as Poll, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Poll&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.totalVotes, totalVotes) || other.totalVotes == totalVotes)&&(identical(other.myOptionId, myOptionId) || other.myOptionId == myOptionId)&&(identical(other.resultsVisible, resultsVisible) || other.resultsVisible == resultsVisible)&&const DeepCollectionEquality().equals(other.options, options));
}


@override
int get hashCode => Object.hash(runtimeType,endsAt,closed,totalVotes,myOptionId,resultsVisible,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'Poll(endsAt: $endsAt, closed: $closed, totalVotes: $totalVotes, myOptionId: $myOptionId, resultsVisible: $resultsVisible, options: $options)';
}


}

/// @nodoc
abstract mixin class $PollCopyWith<$Res>  {
  factory $PollCopyWith(Poll value, $Res Function(Poll) _then) = _$PollCopyWithImpl;
@useResult
$Res call({
 DateTime endsAt, bool closed, int totalVotes, String? myOptionId, bool resultsVisible, List<PollOption> options
});




}
/// @nodoc
class _$PollCopyWithImpl<$Res>
    implements $PollCopyWith<$Res> {
  _$PollCopyWithImpl(this._self, this._then);

  final Poll _self;
  final $Res Function(Poll) _then;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? endsAt = null,Object? closed = null,Object? totalVotes = null,Object? myOptionId = freezed,Object? resultsVisible = null,Object? options = null,}) {
  return _then(_self.copyWith(
endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,totalVotes: null == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int,myOptionId: freezed == myOptionId ? _self.myOptionId : myOptionId // ignore: cast_nullable_to_non_nullable
as String?,resultsVisible: null == resultsVisible ? _self.resultsVisible : resultsVisible // ignore: cast_nullable_to_non_nullable
as bool,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<PollOption>,
  ));
}

}


/// Adds pattern-matching-related methods to [Poll].
extension PollPatterns on Poll {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Poll value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Poll() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Poll value)  $default,){
final _that = this;
switch (_that) {
case _Poll():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Poll value)?  $default,){
final _that = this;
switch (_that) {
case _Poll() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime endsAt,  bool closed,  int totalVotes,  String? myOptionId,  bool resultsVisible,  List<PollOption> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that.endsAt,_that.closed,_that.totalVotes,_that.myOptionId,_that.resultsVisible,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime endsAt,  bool closed,  int totalVotes,  String? myOptionId,  bool resultsVisible,  List<PollOption> options)  $default,) {final _that = this;
switch (_that) {
case _Poll():
return $default(_that.endsAt,_that.closed,_that.totalVotes,_that.myOptionId,_that.resultsVisible,_that.options);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime endsAt,  bool closed,  int totalVotes,  String? myOptionId,  bool resultsVisible,  List<PollOption> options)?  $default,) {final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that.endsAt,_that.closed,_that.totalVotes,_that.myOptionId,_that.resultsVisible,_that.options);case _:
  return null;

}
}

}

/// @nodoc


class _Poll extends Poll {
  const _Poll({required this.endsAt, required this.closed, required this.totalVotes, this.myOptionId, required this.resultsVisible, required final  List<PollOption> options}): _options = options,super._();
  

@override final  DateTime endsAt;
@override final  bool closed;
@override final  int totalVotes;
@override final  String? myOptionId;
@override final  bool resultsVisible;
 final  List<PollOption> _options;
@override List<PollOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollCopyWith<_Poll> get copyWith => __$PollCopyWithImpl<_Poll>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Poll&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.totalVotes, totalVotes) || other.totalVotes == totalVotes)&&(identical(other.myOptionId, myOptionId) || other.myOptionId == myOptionId)&&(identical(other.resultsVisible, resultsVisible) || other.resultsVisible == resultsVisible)&&const DeepCollectionEquality().equals(other._options, _options));
}


@override
int get hashCode => Object.hash(runtimeType,endsAt,closed,totalVotes,myOptionId,resultsVisible,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'Poll(endsAt: $endsAt, closed: $closed, totalVotes: $totalVotes, myOptionId: $myOptionId, resultsVisible: $resultsVisible, options: $options)';
}


}

/// @nodoc
abstract mixin class _$PollCopyWith<$Res> implements $PollCopyWith<$Res> {
  factory _$PollCopyWith(_Poll value, $Res Function(_Poll) _then) = __$PollCopyWithImpl;
@override @useResult
$Res call({
 DateTime endsAt, bool closed, int totalVotes, String? myOptionId, bool resultsVisible, List<PollOption> options
});




}
/// @nodoc
class __$PollCopyWithImpl<$Res>
    implements _$PollCopyWith<$Res> {
  __$PollCopyWithImpl(this._self, this._then);

  final _Poll _self;
  final $Res Function(_Poll) _then;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? endsAt = null,Object? closed = null,Object? totalVotes = null,Object? myOptionId = freezed,Object? resultsVisible = null,Object? options = null,}) {
  return _then(_Poll(
endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,totalVotes: null == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int,myOptionId: freezed == myOptionId ? _self.myOptionId : myOptionId // ignore: cast_nullable_to_non_nullable
as String?,resultsVisible: null == resultsVisible ? _self.resultsVisible : resultsVisible // ignore: cast_nullable_to_non_nullable
as bool,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<PollOption>,
  ));
}


}

/// @nodoc
mixin _$PollDraft {

 List<String> get options; PollDuration get duration;
/// Create a copy of PollDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollDraftCopyWith<PollDraft> get copyWith => _$PollDraftCopyWithImpl<PollDraft>(this as PollDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollDraft&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(options),duration);

@override
String toString() {
  return 'PollDraft(options: $options, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $PollDraftCopyWith<$Res>  {
  factory $PollDraftCopyWith(PollDraft value, $Res Function(PollDraft) _then) = _$PollDraftCopyWithImpl;
@useResult
$Res call({
 List<String> options, PollDuration duration
});




}
/// @nodoc
class _$PollDraftCopyWithImpl<$Res>
    implements $PollDraftCopyWith<$Res> {
  _$PollDraftCopyWithImpl(this._self, this._then);

  final PollDraft _self;
  final $Res Function(PollDraft) _then;

/// Create a copy of PollDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? options = null,Object? duration = null,}) {
  return _then(_self.copyWith(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as PollDuration,
  ));
}

}


/// Adds pattern-matching-related methods to [PollDraft].
extension PollDraftPatterns on PollDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollDraft value)  $default,){
final _that = this;
switch (_that) {
case _PollDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollDraft value)?  $default,){
final _that = this;
switch (_that) {
case _PollDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> options,  PollDuration duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PollDraft() when $default != null:
return $default(_that.options,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> options,  PollDuration duration)  $default,) {final _that = this;
switch (_that) {
case _PollDraft():
return $default(_that.options,_that.duration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> options,  PollDuration duration)?  $default,) {final _that = this;
switch (_that) {
case _PollDraft() when $default != null:
return $default(_that.options,_that.duration);case _:
  return null;

}
}

}

/// @nodoc


class _PollDraft extends PollDraft {
  const _PollDraft({final  List<String> options = const <String>['', ''], this.duration = PollDuration.oneDay}): _options = options,super._();
  

 final  List<String> _options;
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override@JsonKey() final  PollDuration duration;

/// Create a copy of PollDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollDraftCopyWith<_PollDraft> get copyWith => __$PollDraftCopyWithImpl<_PollDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollDraft&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_options),duration);

@override
String toString() {
  return 'PollDraft(options: $options, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$PollDraftCopyWith<$Res> implements $PollDraftCopyWith<$Res> {
  factory _$PollDraftCopyWith(_PollDraft value, $Res Function(_PollDraft) _then) = __$PollDraftCopyWithImpl;
@override @useResult
$Res call({
 List<String> options, PollDuration duration
});




}
/// @nodoc
class __$PollDraftCopyWithImpl<$Res>
    implements _$PollDraftCopyWith<$Res> {
  __$PollDraftCopyWithImpl(this._self, this._then);

  final _PollDraft _self;
  final $Res Function(_PollDraft) _then;

/// Create a copy of PollDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? options = null,Object? duration = null,}) {
  return _then(_PollDraft(
options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as PollDuration,
  ));
}


}

// dart format on
