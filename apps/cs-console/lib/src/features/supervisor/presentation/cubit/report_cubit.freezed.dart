// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReportState {

 LoadStatus get status; ReportPreset get preset; DateTimeRange get range; ReportSummary? get report; Object? get error;
/// Create a copy of ReportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportStateCopyWith<ReportState> get copyWith => _$ReportStateCopyWithImpl<ReportState>(this as ReportState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportState&&(identical(other.status, status) || other.status == status)&&(identical(other.preset, preset) || other.preset == preset)&&(identical(other.range, range) || other.range == range)&&(identical(other.report, report) || other.report == report)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,preset,range,report,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'ReportState(status: $status, preset: $preset, range: $range, report: $report, error: $error)';
}


}

/// @nodoc
abstract mixin class $ReportStateCopyWith<$Res>  {
  factory $ReportStateCopyWith(ReportState value, $Res Function(ReportState) _then) = _$ReportStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ReportPreset preset, DateTimeRange range, ReportSummary? report, Object? error
});


$ReportSummaryCopyWith<$Res>? get report;

}
/// @nodoc
class _$ReportStateCopyWithImpl<$Res>
    implements $ReportStateCopyWith<$Res> {
  _$ReportStateCopyWithImpl(this._self, this._then);

  final ReportState _self;
  final $Res Function(ReportState) _then;

/// Create a copy of ReportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? preset = null,Object? range = null,Object? report = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,preset: null == preset ? _self.preset : preset // ignore: cast_nullable_to_non_nullable
as ReportPreset,range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as DateTimeRange,report: freezed == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as ReportSummary?,error: freezed == error ? _self.error : error ,
  ));
}
/// Create a copy of ReportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReportSummaryCopyWith<$Res>? get report {
    if (_self.report == null) {
    return null;
  }

  return $ReportSummaryCopyWith<$Res>(_self.report!, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReportState].
extension ReportStatePatterns on ReportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportState value)  $default,){
final _that = this;
switch (_that) {
case _ReportState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportState value)?  $default,){
final _that = this;
switch (_that) {
case _ReportState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ReportPreset preset,  DateTimeRange range,  ReportSummary? report,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportState() when $default != null:
return $default(_that.status,_that.preset,_that.range,_that.report,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ReportPreset preset,  DateTimeRange range,  ReportSummary? report,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _ReportState():
return $default(_that.status,_that.preset,_that.range,_that.report,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ReportPreset preset,  DateTimeRange range,  ReportSummary? report,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _ReportState() when $default != null:
return $default(_that.status,_that.preset,_that.range,_that.report,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ReportState implements ReportState {
  const _ReportState({this.status = LoadStatus.initial, this.preset = ReportPreset.week, required this.range, this.report, this.error});
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  ReportPreset preset;
@override final  DateTimeRange range;
@override final  ReportSummary? report;
@override final  Object? error;

/// Create a copy of ReportState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportStateCopyWith<_ReportState> get copyWith => __$ReportStateCopyWithImpl<_ReportState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportState&&(identical(other.status, status) || other.status == status)&&(identical(other.preset, preset) || other.preset == preset)&&(identical(other.range, range) || other.range == range)&&(identical(other.report, report) || other.report == report)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,preset,range,report,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'ReportState(status: $status, preset: $preset, range: $range, report: $report, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ReportStateCopyWith<$Res> implements $ReportStateCopyWith<$Res> {
  factory _$ReportStateCopyWith(_ReportState value, $Res Function(_ReportState) _then) = __$ReportStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ReportPreset preset, DateTimeRange range, ReportSummary? report, Object? error
});


@override $ReportSummaryCopyWith<$Res>? get report;

}
/// @nodoc
class __$ReportStateCopyWithImpl<$Res>
    implements _$ReportStateCopyWith<$Res> {
  __$ReportStateCopyWithImpl(this._self, this._then);

  final _ReportState _self;
  final $Res Function(_ReportState) _then;

/// Create a copy of ReportState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? preset = null,Object? range = null,Object? report = freezed,Object? error = freezed,}) {
  return _then(_ReportState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,preset: null == preset ? _self.preset : preset // ignore: cast_nullable_to_non_nullable
as ReportPreset,range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as DateTimeRange,report: freezed == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as ReportSummary?,error: freezed == error ? _self.error : error ,
  ));
}

/// Create a copy of ReportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReportSummaryCopyWith<$Res>? get report {
    if (_self.report == null) {
    return null;
  }

  return $ReportSummaryCopyWith<$Res>(_self.report!, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}

// dart format on
