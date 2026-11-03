// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'legal_document_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LegalDocumentModel {

 String get id; String get kind; int get version; String get title; String get body; String? get changeSummary; DateTime get effectiveAt;@JsonKey(name: 'required') bool get isRequired;@JsonKey(name: 'accepted') bool get isAccepted;
/// Create a copy of LegalDocumentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LegalDocumentModelCopyWith<LegalDocumentModel> get copyWith => _$LegalDocumentModelCopyWithImpl<LegalDocumentModel>(this as LegalDocumentModel, _$identity);

  /// Serializes this LegalDocumentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalDocumentModel&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.changeSummary, changeSummary) || other.changeSummary == changeSummary)&&(identical(other.effectiveAt, effectiveAt) || other.effectiveAt == effectiveAt)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&(identical(other.isAccepted, isAccepted) || other.isAccepted == isAccepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,version,title,body,changeSummary,effectiveAt,isRequired,isAccepted);

@override
String toString() {
  return 'LegalDocumentModel(id: $id, kind: $kind, version: $version, title: $title, body: $body, changeSummary: $changeSummary, effectiveAt: $effectiveAt, isRequired: $isRequired, isAccepted: $isAccepted)';
}


}

/// @nodoc
abstract mixin class $LegalDocumentModelCopyWith<$Res>  {
  factory $LegalDocumentModelCopyWith(LegalDocumentModel value, $Res Function(LegalDocumentModel) _then) = _$LegalDocumentModelCopyWithImpl;
@useResult
$Res call({
 String id, String kind, int version, String title, String body, String? changeSummary, DateTime effectiveAt,@JsonKey(name: 'required') bool isRequired,@JsonKey(name: 'accepted') bool isAccepted
});




}
/// @nodoc
class _$LegalDocumentModelCopyWithImpl<$Res>
    implements $LegalDocumentModelCopyWith<$Res> {
  _$LegalDocumentModelCopyWithImpl(this._self, this._then);

  final LegalDocumentModel _self;
  final $Res Function(LegalDocumentModel) _then;

/// Create a copy of LegalDocumentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? version = null,Object? title = null,Object? body = null,Object? changeSummary = freezed,Object? effectiveAt = null,Object? isRequired = null,Object? isAccepted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,changeSummary: freezed == changeSummary ? _self.changeSummary : changeSummary // ignore: cast_nullable_to_non_nullable
as String?,effectiveAt: null == effectiveAt ? _self.effectiveAt : effectiveAt // ignore: cast_nullable_to_non_nullable
as DateTime,isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,isAccepted: null == isAccepted ? _self.isAccepted : isAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LegalDocumentModel].
extension LegalDocumentModelPatterns on LegalDocumentModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LegalDocumentModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LegalDocumentModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LegalDocumentModel value)  $default,){
final _that = this;
switch (_that) {
case _LegalDocumentModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LegalDocumentModel value)?  $default,){
final _that = this;
switch (_that) {
case _LegalDocumentModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  int version,  String title,  String body,  String? changeSummary,  DateTime effectiveAt, @JsonKey(name: 'required')  bool isRequired, @JsonKey(name: 'accepted')  bool isAccepted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LegalDocumentModel() when $default != null:
return $default(_that.id,_that.kind,_that.version,_that.title,_that.body,_that.changeSummary,_that.effectiveAt,_that.isRequired,_that.isAccepted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  int version,  String title,  String body,  String? changeSummary,  DateTime effectiveAt, @JsonKey(name: 'required')  bool isRequired, @JsonKey(name: 'accepted')  bool isAccepted)  $default,) {final _that = this;
switch (_that) {
case _LegalDocumentModel():
return $default(_that.id,_that.kind,_that.version,_that.title,_that.body,_that.changeSummary,_that.effectiveAt,_that.isRequired,_that.isAccepted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  int version,  String title,  String body,  String? changeSummary,  DateTime effectiveAt, @JsonKey(name: 'required')  bool isRequired, @JsonKey(name: 'accepted')  bool isAccepted)?  $default,) {final _that = this;
switch (_that) {
case _LegalDocumentModel() when $default != null:
return $default(_that.id,_that.kind,_that.version,_that.title,_that.body,_that.changeSummary,_that.effectiveAt,_that.isRequired,_that.isAccepted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LegalDocumentModel extends LegalDocumentModel {
  const _LegalDocumentModel({required this.id, required this.kind, required this.version, required this.title, this.body = '', this.changeSummary, required this.effectiveAt, @JsonKey(name: 'required') this.isRequired = false, @JsonKey(name: 'accepted') this.isAccepted = false}): super._();
  factory _LegalDocumentModel.fromJson(Map<String, dynamic> json) => _$LegalDocumentModelFromJson(json);

@override final  String id;
@override final  String kind;
@override final  int version;
@override final  String title;
@override@JsonKey() final  String body;
@override final  String? changeSummary;
@override final  DateTime effectiveAt;
@override@JsonKey(name: 'required') final  bool isRequired;
@override@JsonKey(name: 'accepted') final  bool isAccepted;

/// Create a copy of LegalDocumentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LegalDocumentModelCopyWith<_LegalDocumentModel> get copyWith => __$LegalDocumentModelCopyWithImpl<_LegalDocumentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LegalDocumentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LegalDocumentModel&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.changeSummary, changeSummary) || other.changeSummary == changeSummary)&&(identical(other.effectiveAt, effectiveAt) || other.effectiveAt == effectiveAt)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&(identical(other.isAccepted, isAccepted) || other.isAccepted == isAccepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,version,title,body,changeSummary,effectiveAt,isRequired,isAccepted);

@override
String toString() {
  return 'LegalDocumentModel(id: $id, kind: $kind, version: $version, title: $title, body: $body, changeSummary: $changeSummary, effectiveAt: $effectiveAt, isRequired: $isRequired, isAccepted: $isAccepted)';
}


}

/// @nodoc
abstract mixin class _$LegalDocumentModelCopyWith<$Res> implements $LegalDocumentModelCopyWith<$Res> {
  factory _$LegalDocumentModelCopyWith(_LegalDocumentModel value, $Res Function(_LegalDocumentModel) _then) = __$LegalDocumentModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, int version, String title, String body, String? changeSummary, DateTime effectiveAt,@JsonKey(name: 'required') bool isRequired,@JsonKey(name: 'accepted') bool isAccepted
});




}
/// @nodoc
class __$LegalDocumentModelCopyWithImpl<$Res>
    implements _$LegalDocumentModelCopyWith<$Res> {
  __$LegalDocumentModelCopyWithImpl(this._self, this._then);

  final _LegalDocumentModel _self;
  final $Res Function(_LegalDocumentModel) _then;

/// Create a copy of LegalDocumentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? version = null,Object? title = null,Object? body = null,Object? changeSummary = freezed,Object? effectiveAt = null,Object? isRequired = null,Object? isAccepted = null,}) {
  return _then(_LegalDocumentModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,changeSummary: freezed == changeSummary ? _self.changeSummary : changeSummary // ignore: cast_nullable_to_non_nullable
as String?,effectiveAt: null == effectiveAt ? _self.effectiveAt : effectiveAt // ignore: cast_nullable_to_non_nullable
as DateTime,isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,isAccepted: null == isAccepted ? _self.isAccepted : isAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
