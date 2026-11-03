// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appeal_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppealModel {

 String get id; String get targetType; String get targetId; String get reason; String get status; String? get decisionNote; DateTime get createdAt; DateTime? get decidedAt;
/// Create a copy of AppealModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppealModelCopyWith<AppealModel> get copyWith => _$AppealModelCopyWithImpl<AppealModel>(this as AppealModel, _$identity);

  /// Serializes this AppealModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppealModel&&(identical(other.id, id) || other.id == id)&&(identical(other.targetType, targetType) || other.targetType == targetType)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.status, status) || other.status == status)&&(identical(other.decisionNote, decisionNote) || other.decisionNote == decisionNote)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,targetType,targetId,reason,status,decisionNote,createdAt,decidedAt);

@override
String toString() {
  return 'AppealModel(id: $id, targetType: $targetType, targetId: $targetId, reason: $reason, status: $status, decisionNote: $decisionNote, createdAt: $createdAt, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class $AppealModelCopyWith<$Res>  {
  factory $AppealModelCopyWith(AppealModel value, $Res Function(AppealModel) _then) = _$AppealModelCopyWithImpl;
@useResult
$Res call({
 String id, String targetType, String targetId, String reason, String status, String? decisionNote, DateTime createdAt, DateTime? decidedAt
});




}
/// @nodoc
class _$AppealModelCopyWithImpl<$Res>
    implements $AppealModelCopyWith<$Res> {
  _$AppealModelCopyWithImpl(this._self, this._then);

  final AppealModel _self;
  final $Res Function(AppealModel) _then;

/// Create a copy of AppealModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? targetType = null,Object? targetId = null,Object? reason = null,Object? status = null,Object? decisionNote = freezed,Object? createdAt = null,Object? decidedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,targetType: null == targetType ? _self.targetType : targetType // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,decisionNote: freezed == decisionNote ? _self.decisionNote : decisionNote // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppealModel].
extension AppealModelPatterns on AppealModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppealModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppealModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppealModel value)  $default,){
final _that = this;
switch (_that) {
case _AppealModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppealModel value)?  $default,){
final _that = this;
switch (_that) {
case _AppealModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String targetType,  String targetId,  String reason,  String status,  String? decisionNote,  DateTime createdAt,  DateTime? decidedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppealModel() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String targetType,  String targetId,  String reason,  String status,  String? decisionNote,  DateTime createdAt,  DateTime? decidedAt)  $default,) {final _that = this;
switch (_that) {
case _AppealModel():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String targetType,  String targetId,  String reason,  String status,  String? decisionNote,  DateTime createdAt,  DateTime? decidedAt)?  $default,) {final _that = this;
switch (_that) {
case _AppealModel() when $default != null:
return $default(_that.id,_that.targetType,_that.targetId,_that.reason,_that.status,_that.decisionNote,_that.createdAt,_that.decidedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppealModel extends AppealModel {
  const _AppealModel({required this.id, required this.targetType, required this.targetId, this.reason = '', this.status = 'pending', this.decisionNote, required this.createdAt, this.decidedAt}): super._();
  factory _AppealModel.fromJson(Map<String, dynamic> json) => _$AppealModelFromJson(json);

@override final  String id;
@override final  String targetType;
@override final  String targetId;
@override@JsonKey() final  String reason;
@override@JsonKey() final  String status;
@override final  String? decisionNote;
@override final  DateTime createdAt;
@override final  DateTime? decidedAt;

/// Create a copy of AppealModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppealModelCopyWith<_AppealModel> get copyWith => __$AppealModelCopyWithImpl<_AppealModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppealModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppealModel&&(identical(other.id, id) || other.id == id)&&(identical(other.targetType, targetType) || other.targetType == targetType)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.status, status) || other.status == status)&&(identical(other.decisionNote, decisionNote) || other.decisionNote == decisionNote)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,targetType,targetId,reason,status,decisionNote,createdAt,decidedAt);

@override
String toString() {
  return 'AppealModel(id: $id, targetType: $targetType, targetId: $targetId, reason: $reason, status: $status, decisionNote: $decisionNote, createdAt: $createdAt, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class _$AppealModelCopyWith<$Res> implements $AppealModelCopyWith<$Res> {
  factory _$AppealModelCopyWith(_AppealModel value, $Res Function(_AppealModel) _then) = __$AppealModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String targetType, String targetId, String reason, String status, String? decisionNote, DateTime createdAt, DateTime? decidedAt
});




}
/// @nodoc
class __$AppealModelCopyWithImpl<$Res>
    implements _$AppealModelCopyWith<$Res> {
  __$AppealModelCopyWithImpl(this._self, this._then);

  final _AppealModel _self;
  final $Res Function(_AppealModel) _then;

/// Create a copy of AppealModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? targetType = null,Object? targetId = null,Object? reason = null,Object? status = null,Object? decisionNote = freezed,Object? createdAt = null,Object? decidedAt = freezed,}) {
  return _then(_AppealModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,targetType: null == targetType ? _self.targetType : targetType // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,decisionNote: freezed == decisionNote ? _self.decisionNote : decisionNote // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SanctionModel {

 String get id; String get kind; String? get category; String? get reason; DateTime? get startsAt; DateTime? get endsAt;
/// Create a copy of SanctionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SanctionModelCopyWith<SanctionModel> get copyWith => _$SanctionModelCopyWithImpl<SanctionModel>(this as SanctionModel, _$identity);

  /// Serializes this SanctionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SanctionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.category, category) || other.category == category)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,category,reason,startsAt,endsAt);

@override
String toString() {
  return 'SanctionModel(id: $id, kind: $kind, category: $category, reason: $reason, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class $SanctionModelCopyWith<$Res>  {
  factory $SanctionModelCopyWith(SanctionModel value, $Res Function(SanctionModel) _then) = _$SanctionModelCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String? category, String? reason, DateTime? startsAt, DateTime? endsAt
});




}
/// @nodoc
class _$SanctionModelCopyWithImpl<$Res>
    implements $SanctionModelCopyWith<$Res> {
  _$SanctionModelCopyWithImpl(this._self, this._then);

  final SanctionModel _self;
  final $Res Function(SanctionModel) _then;

/// Create a copy of SanctionModel
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


/// Adds pattern-matching-related methods to [SanctionModel].
extension SanctionModelPatterns on SanctionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SanctionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SanctionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SanctionModel value)  $default,){
final _that = this;
switch (_that) {
case _SanctionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SanctionModel value)?  $default,){
final _that = this;
switch (_that) {
case _SanctionModel() when $default != null:
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
case _SanctionModel() when $default != null:
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
case _SanctionModel():
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
case _SanctionModel() when $default != null:
return $default(_that.id,_that.kind,_that.category,_that.reason,_that.startsAt,_that.endsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SanctionModel extends SanctionModel {
  const _SanctionModel({required this.id, required this.kind, this.category, this.reason, this.startsAt, this.endsAt}): super._();
  factory _SanctionModel.fromJson(Map<String, dynamic> json) => _$SanctionModelFromJson(json);

@override final  String id;
@override final  String kind;
@override final  String? category;
@override final  String? reason;
@override final  DateTime? startsAt;
@override final  DateTime? endsAt;

/// Create a copy of SanctionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SanctionModelCopyWith<_SanctionModel> get copyWith => __$SanctionModelCopyWithImpl<_SanctionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SanctionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SanctionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.category, category) || other.category == category)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,category,reason,startsAt,endsAt);

@override
String toString() {
  return 'SanctionModel(id: $id, kind: $kind, category: $category, reason: $reason, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class _$SanctionModelCopyWith<$Res> implements $SanctionModelCopyWith<$Res> {
  factory _$SanctionModelCopyWith(_SanctionModel value, $Res Function(_SanctionModel) _then) = __$SanctionModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String? category, String? reason, DateTime? startsAt, DateTime? endsAt
});




}
/// @nodoc
class __$SanctionModelCopyWithImpl<$Res>
    implements _$SanctionModelCopyWith<$Res> {
  __$SanctionModelCopyWithImpl(this._self, this._then);

  final _SanctionModel _self;
  final $Res Function(_SanctionModel) _then;

/// Create a copy of SanctionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? category = freezed,Object? reason = freezed,Object? startsAt = freezed,Object? endsAt = freezed,}) {
  return _then(_SanctionModel(
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
