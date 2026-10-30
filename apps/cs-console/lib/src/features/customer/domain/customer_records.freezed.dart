// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'customer_records.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NoteAuthor {

 String get displayName; String? get agentCode;
/// Create a copy of NoteAuthor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteAuthorCopyWith<NoteAuthor> get copyWith => _$NoteAuthorCopyWithImpl<NoteAuthor>(this as NoteAuthor, _$identity);

  /// Serializes this NoteAuthor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteAuthor&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,displayName,agentCode);

@override
String toString() {
  return 'NoteAuthor(displayName: $displayName, agentCode: $agentCode)';
}


}

/// @nodoc
abstract mixin class $NoteAuthorCopyWith<$Res>  {
  factory $NoteAuthorCopyWith(NoteAuthor value, $Res Function(NoteAuthor) _then) = _$NoteAuthorCopyWithImpl;
@useResult
$Res call({
 String displayName, String? agentCode
});




}
/// @nodoc
class _$NoteAuthorCopyWithImpl<$Res>
    implements $NoteAuthorCopyWith<$Res> {
  _$NoteAuthorCopyWithImpl(this._self, this._then);

  final NoteAuthor _self;
  final $Res Function(NoteAuthor) _then;

/// Create a copy of NoteAuthor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayName = null,Object? agentCode = freezed,}) {
  return _then(_self.copyWith(
displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NoteAuthor].
extension NoteAuthorPatterns on NoteAuthor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NoteAuthor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NoteAuthor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NoteAuthor value)  $default,){
final _that = this;
switch (_that) {
case _NoteAuthor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NoteAuthor value)?  $default,){
final _that = this;
switch (_that) {
case _NoteAuthor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String displayName,  String? agentCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NoteAuthor() when $default != null:
return $default(_that.displayName,_that.agentCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String displayName,  String? agentCode)  $default,) {final _that = this;
switch (_that) {
case _NoteAuthor():
return $default(_that.displayName,_that.agentCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String displayName,  String? agentCode)?  $default,) {final _that = this;
switch (_that) {
case _NoteAuthor() when $default != null:
return $default(_that.displayName,_that.agentCode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NoteAuthor implements NoteAuthor {
  const _NoteAuthor({required this.displayName, this.agentCode});
  factory _NoteAuthor.fromJson(Map<String, dynamic> json) => _$NoteAuthorFromJson(json);

@override final  String displayName;
@override final  String? agentCode;

/// Create a copy of NoteAuthor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NoteAuthorCopyWith<_NoteAuthor> get copyWith => __$NoteAuthorCopyWithImpl<_NoteAuthor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NoteAuthorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NoteAuthor&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,displayName,agentCode);

@override
String toString() {
  return 'NoteAuthor(displayName: $displayName, agentCode: $agentCode)';
}


}

/// @nodoc
abstract mixin class _$NoteAuthorCopyWith<$Res> implements $NoteAuthorCopyWith<$Res> {
  factory _$NoteAuthorCopyWith(_NoteAuthor value, $Res Function(_NoteAuthor) _then) = __$NoteAuthorCopyWithImpl;
@override @useResult
$Res call({
 String displayName, String? agentCode
});




}
/// @nodoc
class __$NoteAuthorCopyWithImpl<$Res>
    implements _$NoteAuthorCopyWith<$Res> {
  __$NoteAuthorCopyWithImpl(this._self, this._then);

  final _NoteAuthor _self;
  final $Res Function(_NoteAuthor) _then;

/// Create a copy of NoteAuthor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayName = null,Object? agentCode = freezed,}) {
  return _then(_NoteAuthor(
displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AgentNote {

 String get id;@JsonKey(readValue: _ticketOf) String? get ticketId; String get kind; String get body; DateTime get createdAt; NoteAuthor? get author;
/// Create a copy of AgentNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentNoteCopyWith<AgentNote> get copyWith => _$AgentNoteCopyWithImpl<AgentNote>(this as AgentNote, _$identity);

  /// Serializes this AgentNote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentNote&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.author, author) || other.author == author));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,kind,body,createdAt,author);

@override
String toString() {
  return 'AgentNote(id: $id, ticketId: $ticketId, kind: $kind, body: $body, createdAt: $createdAt, author: $author)';
}


}

/// @nodoc
abstract mixin class $AgentNoteCopyWith<$Res>  {
  factory $AgentNoteCopyWith(AgentNote value, $Res Function(AgentNote) _then) = _$AgentNoteCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(readValue: _ticketOf) String? ticketId, String kind, String body, DateTime createdAt, NoteAuthor? author
});


$NoteAuthorCopyWith<$Res>? get author;

}
/// @nodoc
class _$AgentNoteCopyWithImpl<$Res>
    implements $AgentNoteCopyWith<$Res> {
  _$AgentNoteCopyWithImpl(this._self, this._then);

  final AgentNote _self;
  final $Res Function(AgentNote) _then;

/// Create a copy of AgentNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketId = freezed,Object? kind = null,Object? body = null,Object? createdAt = null,Object? author = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as NoteAuthor?,
  ));
}
/// Create a copy of AgentNote
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NoteAuthorCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $NoteAuthorCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgentNote].
extension AgentNotePatterns on AgentNote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentNote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentNote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentNote value)  $default,){
final _that = this;
switch (_that) {
case _AgentNote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentNote value)?  $default,){
final _that = this;
switch (_that) {
case _AgentNote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(readValue: _ticketOf)  String? ticketId,  String kind,  String body,  DateTime createdAt,  NoteAuthor? author)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentNote() when $default != null:
return $default(_that.id,_that.ticketId,_that.kind,_that.body,_that.createdAt,_that.author);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(readValue: _ticketOf)  String? ticketId,  String kind,  String body,  DateTime createdAt,  NoteAuthor? author)  $default,) {final _that = this;
switch (_that) {
case _AgentNote():
return $default(_that.id,_that.ticketId,_that.kind,_that.body,_that.createdAt,_that.author);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(readValue: _ticketOf)  String? ticketId,  String kind,  String body,  DateTime createdAt,  NoteAuthor? author)?  $default,) {final _that = this;
switch (_that) {
case _AgentNote() when $default != null:
return $default(_that.id,_that.ticketId,_that.kind,_that.body,_that.createdAt,_that.author);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentNote implements AgentNote {
  const _AgentNote({required this.id, @JsonKey(readValue: _ticketOf) this.ticketId, this.kind = 'note', required this.body, required this.createdAt, this.author});
  factory _AgentNote.fromJson(Map<String, dynamic> json) => _$AgentNoteFromJson(json);

@override final  String id;
@override@JsonKey(readValue: _ticketOf) final  String? ticketId;
@override@JsonKey() final  String kind;
@override final  String body;
@override final  DateTime createdAt;
@override final  NoteAuthor? author;

/// Create a copy of AgentNote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentNoteCopyWith<_AgentNote> get copyWith => __$AgentNoteCopyWithImpl<_AgentNote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentNoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentNote&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.author, author) || other.author == author));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,kind,body,createdAt,author);

@override
String toString() {
  return 'AgentNote(id: $id, ticketId: $ticketId, kind: $kind, body: $body, createdAt: $createdAt, author: $author)';
}


}

/// @nodoc
abstract mixin class _$AgentNoteCopyWith<$Res> implements $AgentNoteCopyWith<$Res> {
  factory _$AgentNoteCopyWith(_AgentNote value, $Res Function(_AgentNote) _then) = __$AgentNoteCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(readValue: _ticketOf) String? ticketId, String kind, String body, DateTime createdAt, NoteAuthor? author
});


@override $NoteAuthorCopyWith<$Res>? get author;

}
/// @nodoc
class __$AgentNoteCopyWithImpl<$Res>
    implements _$AgentNoteCopyWith<$Res> {
  __$AgentNoteCopyWithImpl(this._self, this._then);

  final _AgentNote _self;
  final $Res Function(_AgentNote) _then;

/// Create a copy of AgentNote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketId = freezed,Object? kind = null,Object? body = null,Object? createdAt = null,Object? author = freezed,}) {
  return _then(_AgentNote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: freezed == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as NoteAuthor?,
  ));
}

/// Create a copy of AgentNote
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NoteAuthorCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $NoteAuthorCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// @nodoc
mixin _$TicketHistoryItem {

 String get id; String? get ticketNumber; String get topic; String get status; List<String> get flags; DateTime get createdAt; DateTime? get resolvedAt; DateTime? get closedAt; String? get outcome; int? get rating; String? get agent;
/// Create a copy of TicketHistoryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketHistoryItemCopyWith<TicketHistoryItem> get copyWith => _$TicketHistoryItemCopyWithImpl<TicketHistoryItem>(this as TicketHistoryItem, _$identity);

  /// Serializes this TicketHistoryItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketHistoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.flags, flags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketNumber,topic,status,const DeepCollectionEquality().hash(flags),createdAt,resolvedAt,closedAt,outcome,rating,agent);

@override
String toString() {
  return 'TicketHistoryItem(id: $id, ticketNumber: $ticketNumber, topic: $topic, status: $status, flags: $flags, createdAt: $createdAt, resolvedAt: $resolvedAt, closedAt: $closedAt, outcome: $outcome, rating: $rating, agent: $agent)';
}


}

/// @nodoc
abstract mixin class $TicketHistoryItemCopyWith<$Res>  {
  factory $TicketHistoryItemCopyWith(TicketHistoryItem value, $Res Function(TicketHistoryItem) _then) = _$TicketHistoryItemCopyWithImpl;
@useResult
$Res call({
 String id, String? ticketNumber, String topic, String status, List<String> flags, DateTime createdAt, DateTime? resolvedAt, DateTime? closedAt, String? outcome, int? rating, String? agent
});




}
/// @nodoc
class _$TicketHistoryItemCopyWithImpl<$Res>
    implements $TicketHistoryItemCopyWith<$Res> {
  _$TicketHistoryItemCopyWithImpl(this._self, this._then);

  final TicketHistoryItem _self;
  final $Res Function(TicketHistoryItem) _then;

/// Create a copy of TicketHistoryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketNumber = freezed,Object? topic = null,Object? status = null,Object? flags = null,Object? createdAt = null,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? outcome = freezed,Object? rating = freezed,Object? agent = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: freezed == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String?,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketHistoryItem].
extension TicketHistoryItemPatterns on TicketHistoryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketHistoryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketHistoryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketHistoryItem value)  $default,){
final _that = this;
switch (_that) {
case _TicketHistoryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketHistoryItem value)?  $default,){
final _that = this;
switch (_that) {
case _TicketHistoryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? ticketNumber,  String topic,  String status,  List<String> flags,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  String? outcome,  int? rating,  String? agent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketHistoryItem() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.topic,_that.status,_that.flags,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.outcome,_that.rating,_that.agent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? ticketNumber,  String topic,  String status,  List<String> flags,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  String? outcome,  int? rating,  String? agent)  $default,) {final _that = this;
switch (_that) {
case _TicketHistoryItem():
return $default(_that.id,_that.ticketNumber,_that.topic,_that.status,_that.flags,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.outcome,_that.rating,_that.agent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? ticketNumber,  String topic,  String status,  List<String> flags,  DateTime createdAt,  DateTime? resolvedAt,  DateTime? closedAt,  String? outcome,  int? rating,  String? agent)?  $default,) {final _that = this;
switch (_that) {
case _TicketHistoryItem() when $default != null:
return $default(_that.id,_that.ticketNumber,_that.topic,_that.status,_that.flags,_that.createdAt,_that.resolvedAt,_that.closedAt,_that.outcome,_that.rating,_that.agent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TicketHistoryItem implements TicketHistoryItem {
  const _TicketHistoryItem({required this.id, this.ticketNumber, required this.topic, required this.status, final  List<String> flags = const <String>[], required this.createdAt, this.resolvedAt, this.closedAt, this.outcome, this.rating, this.agent}): _flags = flags;
  factory _TicketHistoryItem.fromJson(Map<String, dynamic> json) => _$TicketHistoryItemFromJson(json);

@override final  String id;
@override final  String? ticketNumber;
@override final  String topic;
@override final  String status;
 final  List<String> _flags;
@override@JsonKey() List<String> get flags {
  if (_flags is EqualUnmodifiableListView) return _flags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flags);
}

@override final  DateTime createdAt;
@override final  DateTime? resolvedAt;
@override final  DateTime? closedAt;
@override final  String? outcome;
@override final  int? rating;
@override final  String? agent;

/// Create a copy of TicketHistoryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketHistoryItemCopyWith<_TicketHistoryItem> get copyWith => __$TicketHistoryItemCopyWithImpl<_TicketHistoryItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketHistoryItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketHistoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketNumber, ticketNumber) || other.ticketNumber == ticketNumber)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._flags, _flags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketNumber,topic,status,const DeepCollectionEquality().hash(_flags),createdAt,resolvedAt,closedAt,outcome,rating,agent);

@override
String toString() {
  return 'TicketHistoryItem(id: $id, ticketNumber: $ticketNumber, topic: $topic, status: $status, flags: $flags, createdAt: $createdAt, resolvedAt: $resolvedAt, closedAt: $closedAt, outcome: $outcome, rating: $rating, agent: $agent)';
}


}

/// @nodoc
abstract mixin class _$TicketHistoryItemCopyWith<$Res> implements $TicketHistoryItemCopyWith<$Res> {
  factory _$TicketHistoryItemCopyWith(_TicketHistoryItem value, $Res Function(_TicketHistoryItem) _then) = __$TicketHistoryItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String? ticketNumber, String topic, String status, List<String> flags, DateTime createdAt, DateTime? resolvedAt, DateTime? closedAt, String? outcome, int? rating, String? agent
});




}
/// @nodoc
class __$TicketHistoryItemCopyWithImpl<$Res>
    implements _$TicketHistoryItemCopyWith<$Res> {
  __$TicketHistoryItemCopyWithImpl(this._self, this._then);

  final _TicketHistoryItem _self;
  final $Res Function(_TicketHistoryItem) _then;

/// Create a copy of TicketHistoryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketNumber = freezed,Object? topic = null,Object? status = null,Object? flags = null,Object? createdAt = null,Object? resolvedAt = freezed,Object? closedAt = freezed,Object? outcome = freezed,Object? rating = freezed,Object? agent = freezed,}) {
  return _then(_TicketHistoryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketNumber: freezed == ticketNumber ? _self.ticketNumber : ticketNumber // ignore: cast_nullable_to_non_nullable
as String?,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,flags: null == flags ? _self._flags : flags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
