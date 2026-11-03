// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appeal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Appeal {

 String get id; AppealTargetType get targetType; String get targetId; String get reason; AppealStatus get status; String? get decisionNote; DateTime get createdAt; DateTime? get decidedAt;
/// Create a copy of Appeal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppealCopyWith<Appeal> get copyWith => _$AppealCopyWithImpl<Appeal>(this as Appeal, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Appeal&&(identical(other.id, id) || other.id == id)&&(identical(other.targetType, targetType) || other.targetType == targetType)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.status, status) || other.status == status)&&(identical(other.decisionNote, decisionNote) || other.decisionNote == decisionNote)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,targetType,targetId,reason,status,decisionNote,createdAt,decidedAt);

@override
String toString() {
  return 'Appeal(id: $id, targetType: $targetType, targetId: $targetId, reason: $reason, status: $status, decisionNote: $decisionNote, createdAt: $createdAt, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class $AppealCopyWith<$Res>  {
  factory $AppealCopyWith(Appeal value, $Res Function(Appeal) _then) = _$AppealCopyWithImpl;
@useResult
$Res call({
 String id, AppealTargetType targetType, String targetId, String reason, AppealStatus status, String? decisionNote, DateTime createdAt, DateTime? decidedAt
});




}
/// @nodoc
class _$AppealCopyWithImpl<$Res>
    implements $AppealCopyWith<$Res> {
  _$AppealCopyWithImpl(this._self, this._then);

  final Appeal _self;
  final $Res Function(Appeal) _then;

/// Create a copy of Appeal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? targetType = null,Object? targetId = null,Object? reason = null,Object? status = null,Object? decisionNote = freezed,Object? createdAt = null,Object? decidedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,targetType: null == targetType ? _self.targetType : targetType // ignore: cast_nullable_to_non_nullable
as AppealTargetType,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AppealStatus,decisionNote: freezed == decisionNote ? _self.decisionNote : decisionNote // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Appeal].
extension AppealPatterns on Appeal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Appeal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Appeal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Appeal value)  $default,){
final _that = this;
switch (_that) {
case _Appeal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Appeal value)?  $default,){
final _that = this;
switch (_that) {
case _Appeal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AppealTargetType targetType,  String targetId,  String reason,  AppealStatus status,  String? decisionNote,  DateTime createdAt,  DateTime? decidedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Appeal() when $default != null:
return $default(_that.id,_that.targetType,_that.targetId,_that.reason,_that.status,_that.decisionNote,_that.createdAt,_that.decidedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AppealTargetType targetType,  String targetId,  String reason,  AppealStatus status,  String? decisionNote,  DateTime createdAt,  DateTime? decidedAt)  $default,) {final _that = this;
switch (_that) {
case _Appeal():
return $default(_that.id,_that.targetType,_that.targetId,_that.reason,_that.status,_that.decisionNote,_that.createdAt,_that.decidedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AppealTargetType targetType,  String targetId,  String reason,  AppealStatus status,  String? decisionNote,  DateTime createdAt,  DateTime? decidedAt)?  $default,) {final _that = this;
switch (_that) {
case _Appeal() when $default != null:
return $default(_that.id,_that.targetType,_that.targetId,_that.reason,_that.status,_that.decisionNote,_that.createdAt,_that.decidedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Appeal implements Appeal {
  const _Appeal({required this.id, required this.targetType, required this.targetId, this.reason = '', this.status = AppealStatus.pending, this.decisionNote, required this.createdAt, this.decidedAt});
  

@override final  String id;
@override final  AppealTargetType targetType;
@override final  String targetId;
@override@JsonKey() final  String reason;
@override@JsonKey() final  AppealStatus status;
@override final  String? decisionNote;
@override final  DateTime createdAt;
@override final  DateTime? decidedAt;

/// Create a copy of Appeal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppealCopyWith<_Appeal> get copyWith => __$AppealCopyWithImpl<_Appeal>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Appeal&&(identical(other.id, id) || other.id == id)&&(identical(other.targetType, targetType) || other.targetType == targetType)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.status, status) || other.status == status)&&(identical(other.decisionNote, decisionNote) || other.decisionNote == decisionNote)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,targetType,targetId,reason,status,decisionNote,createdAt,decidedAt);

@override
String toString() {
  return 'Appeal(id: $id, targetType: $targetType, targetId: $targetId, reason: $reason, status: $status, decisionNote: $decisionNote, createdAt: $createdAt, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class _$AppealCopyWith<$Res> implements $AppealCopyWith<$Res> {
  factory _$AppealCopyWith(_Appeal value, $Res Function(_Appeal) _then) = __$AppealCopyWithImpl;
@override @useResult
$Res call({
 String id, AppealTargetType targetType, String targetId, String reason, AppealStatus status, String? decisionNote, DateTime createdAt, DateTime? decidedAt
});




}
/// @nodoc
class __$AppealCopyWithImpl<$Res>
    implements _$AppealCopyWith<$Res> {
  __$AppealCopyWithImpl(this._self, this._then);

  final _Appeal _self;
  final $Res Function(_Appeal) _then;

/// Create a copy of Appeal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? targetType = null,Object? targetId = null,Object? reason = null,Object? status = null,Object? decisionNote = freezed,Object? createdAt = null,Object? decidedAt = freezed,}) {
  return _then(_Appeal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,targetType: null == targetType ? _self.targetType : targetType // ignore: cast_nullable_to_non_nullable
as AppealTargetType,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AppealStatus,decisionNote: freezed == decisionNote ? _self.decisionNote : decisionNote // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$ModeratedContent {

 AppealTargetType get type; String get id; ModeratedState get state; String? get excerpt; DateTime? get decidedAt; Appeal? get appeal;
/// Create a copy of ModeratedContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModeratedContentCopyWith<ModeratedContent> get copyWith => _$ModeratedContentCopyWithImpl<ModeratedContent>(this as ModeratedContent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModeratedContent&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.state, state) || other.state == state)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt)&&(identical(other.appeal, appeal) || other.appeal == appeal));
}


@override
int get hashCode => Object.hash(runtimeType,type,id,state,excerpt,decidedAt,appeal);

@override
String toString() {
  return 'ModeratedContent(type: $type, id: $id, state: $state, excerpt: $excerpt, decidedAt: $decidedAt, appeal: $appeal)';
}


}

/// @nodoc
abstract mixin class $ModeratedContentCopyWith<$Res>  {
  factory $ModeratedContentCopyWith(ModeratedContent value, $Res Function(ModeratedContent) _then) = _$ModeratedContentCopyWithImpl;
@useResult
$Res call({
 AppealTargetType type, String id, ModeratedState state, String? excerpt, DateTime? decidedAt, Appeal? appeal
});


$AppealCopyWith<$Res>? get appeal;

}
/// @nodoc
class _$ModeratedContentCopyWithImpl<$Res>
    implements $ModeratedContentCopyWith<$Res> {
  _$ModeratedContentCopyWithImpl(this._self, this._then);

  final ModeratedContent _self;
  final $Res Function(ModeratedContent) _then;

/// Create a copy of ModeratedContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = null,Object? state = null,Object? excerpt = freezed,Object? decidedAt = freezed,Object? appeal = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AppealTargetType,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ModeratedState,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,appeal: freezed == appeal ? _self.appeal : appeal // ignore: cast_nullable_to_non_nullable
as Appeal?,
  ));
}
/// Create a copy of ModeratedContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppealCopyWith<$Res>? get appeal {
    if (_self.appeal == null) {
    return null;
  }

  return $AppealCopyWith<$Res>(_self.appeal!, (value) {
    return _then(_self.copyWith(appeal: value));
  });
}
}


/// Adds pattern-matching-related methods to [ModeratedContent].
extension ModeratedContentPatterns on ModeratedContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModeratedContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModeratedContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModeratedContent value)  $default,){
final _that = this;
switch (_that) {
case _ModeratedContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModeratedContent value)?  $default,){
final _that = this;
switch (_that) {
case _ModeratedContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AppealTargetType type,  String id,  ModeratedState state,  String? excerpt,  DateTime? decidedAt,  Appeal? appeal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModeratedContent() when $default != null:
return $default(_that.type,_that.id,_that.state,_that.excerpt,_that.decidedAt,_that.appeal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AppealTargetType type,  String id,  ModeratedState state,  String? excerpt,  DateTime? decidedAt,  Appeal? appeal)  $default,) {final _that = this;
switch (_that) {
case _ModeratedContent():
return $default(_that.type,_that.id,_that.state,_that.excerpt,_that.decidedAt,_that.appeal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AppealTargetType type,  String id,  ModeratedState state,  String? excerpt,  DateTime? decidedAt,  Appeal? appeal)?  $default,) {final _that = this;
switch (_that) {
case _ModeratedContent() when $default != null:
return $default(_that.type,_that.id,_that.state,_that.excerpt,_that.decidedAt,_that.appeal);case _:
  return null;

}
}

}

/// @nodoc


class _ModeratedContent implements ModeratedContent {
  const _ModeratedContent({required this.type, required this.id, required this.state, this.excerpt, this.decidedAt, this.appeal});
  

@override final  AppealTargetType type;
@override final  String id;
@override final  ModeratedState state;
@override final  String? excerpt;
@override final  DateTime? decidedAt;
@override final  Appeal? appeal;

/// Create a copy of ModeratedContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModeratedContentCopyWith<_ModeratedContent> get copyWith => __$ModeratedContentCopyWithImpl<_ModeratedContent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModeratedContent&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.state, state) || other.state == state)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt)&&(identical(other.appeal, appeal) || other.appeal == appeal));
}


@override
int get hashCode => Object.hash(runtimeType,type,id,state,excerpt,decidedAt,appeal);

@override
String toString() {
  return 'ModeratedContent(type: $type, id: $id, state: $state, excerpt: $excerpt, decidedAt: $decidedAt, appeal: $appeal)';
}


}

/// @nodoc
abstract mixin class _$ModeratedContentCopyWith<$Res> implements $ModeratedContentCopyWith<$Res> {
  factory _$ModeratedContentCopyWith(_ModeratedContent value, $Res Function(_ModeratedContent) _then) = __$ModeratedContentCopyWithImpl;
@override @useResult
$Res call({
 AppealTargetType type, String id, ModeratedState state, String? excerpt, DateTime? decidedAt, Appeal? appeal
});


@override $AppealCopyWith<$Res>? get appeal;

}
/// @nodoc
class __$ModeratedContentCopyWithImpl<$Res>
    implements _$ModeratedContentCopyWith<$Res> {
  __$ModeratedContentCopyWithImpl(this._self, this._then);

  final _ModeratedContent _self;
  final $Res Function(_ModeratedContent) _then;

/// Create a copy of ModeratedContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = null,Object? state = null,Object? excerpt = freezed,Object? decidedAt = freezed,Object? appeal = freezed,}) {
  return _then(_ModeratedContent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AppealTargetType,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ModeratedState,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,appeal: freezed == appeal ? _self.appeal : appeal // ignore: cast_nullable_to_non_nullable
as Appeal?,
  ));
}

/// Create a copy of ModeratedContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppealCopyWith<$Res>? get appeal {
    if (_self.appeal == null) {
    return null;
  }

  return $AppealCopyWith<$Res>(_self.appeal!, (value) {
    return _then(_self.copyWith(appeal: value));
  });
}
}

/// @nodoc
mixin _$Sanction {

 String get id; String get kind; String? get category; String? get reason; DateTime? get startsAt; DateTime? get endsAt;
/// Create a copy of Sanction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SanctionCopyWith<Sanction> get copyWith => _$SanctionCopyWithImpl<Sanction>(this as Sanction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sanction&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.category, category) || other.category == category)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,category,reason,startsAt,endsAt);

@override
String toString() {
  return 'Sanction(id: $id, kind: $kind, category: $category, reason: $reason, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class $SanctionCopyWith<$Res>  {
  factory $SanctionCopyWith(Sanction value, $Res Function(Sanction) _then) = _$SanctionCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String? category, String? reason, DateTime? startsAt, DateTime? endsAt
});




}
/// @nodoc
class _$SanctionCopyWithImpl<$Res>
    implements $SanctionCopyWith<$Res> {
  _$SanctionCopyWithImpl(this._self, this._then);

  final Sanction _self;
  final $Res Function(Sanction) _then;

/// Create a copy of Sanction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? category = freezed,Object? reason = freezed,Object? startsAt = freezed,Object? endsAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Sanction].
extension SanctionPatterns on Sanction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sanction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sanction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sanction value)  $default,){
final _that = this;
switch (_that) {
case _Sanction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sanction value)?  $default,){
final _that = this;
switch (_that) {
case _Sanction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String? category,  String? reason,  DateTime? startsAt,  DateTime? endsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sanction() when $default != null:
return $default(_that.id,_that.kind,_that.category,_that.reason,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String? category,  String? reason,  DateTime? startsAt,  DateTime? endsAt)  $default,) {final _that = this;
switch (_that) {
case _Sanction():
return $default(_that.id,_that.kind,_that.category,_that.reason,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String? category,  String? reason,  DateTime? startsAt,  DateTime? endsAt)?  $default,) {final _that = this;
switch (_that) {
case _Sanction() when $default != null:
return $default(_that.id,_that.kind,_that.category,_that.reason,_that.startsAt,_that.endsAt);case _:
  return null;

}
}

}

/// @nodoc


class _Sanction implements Sanction {
  const _Sanction({required this.id, required this.kind, this.category, this.reason, this.startsAt, this.endsAt});
  

@override final  String id;
@override final  String kind;
@override final  String? category;
@override final  String? reason;
@override final  DateTime? startsAt;
@override final  DateTime? endsAt;

/// Create a copy of Sanction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SanctionCopyWith<_Sanction> get copyWith => __$SanctionCopyWithImpl<_Sanction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sanction&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.category, category) || other.category == category)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,category,reason,startsAt,endsAt);

@override
String toString() {
  return 'Sanction(id: $id, kind: $kind, category: $category, reason: $reason, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class _$SanctionCopyWith<$Res> implements $SanctionCopyWith<$Res> {
  factory _$SanctionCopyWith(_Sanction value, $Res Function(_Sanction) _then) = __$SanctionCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String? category, String? reason, DateTime? startsAt, DateTime? endsAt
});




}
/// @nodoc
class __$SanctionCopyWithImpl<$Res>
    implements _$SanctionCopyWith<$Res> {
  __$SanctionCopyWithImpl(this._self, this._then);

  final _Sanction _self;
  final $Res Function(_Sanction) _then;

/// Create a copy of Sanction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? category = freezed,Object? reason = freezed,Object? startsAt = freezed,Object? endsAt = freezed,}) {
  return _then(_Sanction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
