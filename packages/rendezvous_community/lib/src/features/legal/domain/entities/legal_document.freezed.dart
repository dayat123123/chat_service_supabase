// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'legal_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LegalDocument {

 String get id; LegalDocumentKind get kind; int get version; String get title; String get body; String? get changeSummary; DateTime get effectiveAt; bool get isRequired; bool get isAccepted;
/// Create a copy of LegalDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LegalDocumentCopyWith<LegalDocument> get copyWith => _$LegalDocumentCopyWithImpl<LegalDocument>(this as LegalDocument, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.changeSummary, changeSummary) || other.changeSummary == changeSummary)&&(identical(other.effectiveAt, effectiveAt) || other.effectiveAt == effectiveAt)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&(identical(other.isAccepted, isAccepted) || other.isAccepted == isAccepted));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,version,title,body,changeSummary,effectiveAt,isRequired,isAccepted);

@override
String toString() {
  return 'LegalDocument(id: $id, kind: $kind, version: $version, title: $title, body: $body, changeSummary: $changeSummary, effectiveAt: $effectiveAt, isRequired: $isRequired, isAccepted: $isAccepted)';
}


}

/// @nodoc
abstract mixin class $LegalDocumentCopyWith<$Res>  {
  factory $LegalDocumentCopyWith(LegalDocument value, $Res Function(LegalDocument) _then) = _$LegalDocumentCopyWithImpl;
@useResult
$Res call({
 String id, LegalDocumentKind kind, int version, String title, String body, String? changeSummary, DateTime effectiveAt, bool isRequired, bool isAccepted
});




}
/// @nodoc
class _$LegalDocumentCopyWithImpl<$Res>
    implements $LegalDocumentCopyWith<$Res> {
  _$LegalDocumentCopyWithImpl(this._self, this._then);

  final LegalDocument _self;
  final $Res Function(LegalDocument) _then;

/// Create a copy of LegalDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? version = null,Object? title = null,Object? body = null,Object? changeSummary = freezed,Object? effectiveAt = null,Object? isRequired = null,Object? isAccepted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LegalDocumentKind,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [LegalDocument].
extension LegalDocumentPatterns on LegalDocument {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LegalDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LegalDocument() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LegalDocument value)  $default,){
final _that = this;
switch (_that) {
case _LegalDocument():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LegalDocument value)?  $default,){
final _that = this;
switch (_that) {
case _LegalDocument() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  LegalDocumentKind kind,  int version,  String title,  String body,  String? changeSummary,  DateTime effectiveAt,  bool isRequired,  bool isAccepted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LegalDocument() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  LegalDocumentKind kind,  int version,  String title,  String body,  String? changeSummary,  DateTime effectiveAt,  bool isRequired,  bool isAccepted)  $default,) {final _that = this;
switch (_that) {
case _LegalDocument():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  LegalDocumentKind kind,  int version,  String title,  String body,  String? changeSummary,  DateTime effectiveAt,  bool isRequired,  bool isAccepted)?  $default,) {final _that = this;
switch (_that) {
case _LegalDocument() when $default != null:
return $default(_that.id,_that.kind,_that.version,_that.title,_that.body,_that.changeSummary,_that.effectiveAt,_that.isRequired,_that.isAccepted);case _:
  return null;

}
}

}

/// @nodoc


class _LegalDocument extends LegalDocument {
  const _LegalDocument({required this.id, required this.kind, required this.version, required this.title, required this.body, this.changeSummary, required this.effectiveAt, this.isRequired = false, this.isAccepted = false}): super._();
  

@override final  String id;
@override final  LegalDocumentKind kind;
@override final  int version;
@override final  String title;
@override final  String body;
@override final  String? changeSummary;
@override final  DateTime effectiveAt;
@override@JsonKey() final  bool isRequired;
@override@JsonKey() final  bool isAccepted;

/// Create a copy of LegalDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LegalDocumentCopyWith<_LegalDocument> get copyWith => __$LegalDocumentCopyWithImpl<_LegalDocument>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LegalDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.changeSummary, changeSummary) || other.changeSummary == changeSummary)&&(identical(other.effectiveAt, effectiveAt) || other.effectiveAt == effectiveAt)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&(identical(other.isAccepted, isAccepted) || other.isAccepted == isAccepted));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,version,title,body,changeSummary,effectiveAt,isRequired,isAccepted);

@override
String toString() {
  return 'LegalDocument(id: $id, kind: $kind, version: $version, title: $title, body: $body, changeSummary: $changeSummary, effectiveAt: $effectiveAt, isRequired: $isRequired, isAccepted: $isAccepted)';
}


}

/// @nodoc
abstract mixin class _$LegalDocumentCopyWith<$Res> implements $LegalDocumentCopyWith<$Res> {
  factory _$LegalDocumentCopyWith(_LegalDocument value, $Res Function(_LegalDocument) _then) = __$LegalDocumentCopyWithImpl;
@override @useResult
$Res call({
 String id, LegalDocumentKind kind, int version, String title, String body, String? changeSummary, DateTime effectiveAt, bool isRequired, bool isAccepted
});




}
/// @nodoc
class __$LegalDocumentCopyWithImpl<$Res>
    implements _$LegalDocumentCopyWith<$Res> {
  __$LegalDocumentCopyWithImpl(this._self, this._then);

  final _LegalDocument _self;
  final $Res Function(_LegalDocument) _then;

/// Create a copy of LegalDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? version = null,Object? title = null,Object? body = null,Object? changeSummary = freezed,Object? effectiveAt = null,Object? isRequired = null,Object? isAccepted = null,}) {
  return _then(_LegalDocument(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LegalDocumentKind,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
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
