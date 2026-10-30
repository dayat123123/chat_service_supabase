// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'poll_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PollOptionModel {

 String get id; String get label; int? get votes;
/// Create a copy of PollOptionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollOptionModelCopyWith<PollOptionModel> get copyWith => _$PollOptionModelCopyWithImpl<PollOptionModel>(this as PollOptionModel, _$identity);

  /// Serializes this PollOptionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollOptionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.votes, votes) || other.votes == votes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,votes);

@override
String toString() {
  return 'PollOptionModel(id: $id, label: $label, votes: $votes)';
}


}

/// @nodoc
abstract mixin class $PollOptionModelCopyWith<$Res>  {
  factory $PollOptionModelCopyWith(PollOptionModel value, $Res Function(PollOptionModel) _then) = _$PollOptionModelCopyWithImpl;
@useResult
$Res call({
 String id, String label, int? votes
});




}
/// @nodoc
class _$PollOptionModelCopyWithImpl<$Res>
    implements $PollOptionModelCopyWith<$Res> {
  _$PollOptionModelCopyWithImpl(this._self, this._then);

  final PollOptionModel _self;
  final $Res Function(PollOptionModel) _then;

/// Create a copy of PollOptionModel
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


/// Adds pattern-matching-related methods to [PollOptionModel].
extension PollOptionModelPatterns on PollOptionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollOptionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollOptionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollOptionModel value)  $default,){
final _that = this;
switch (_that) {
case _PollOptionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollOptionModel value)?  $default,){
final _that = this;
switch (_that) {
case _PollOptionModel() when $default != null:
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
case _PollOptionModel() when $default != null:
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
case _PollOptionModel():
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
case _PollOptionModel() when $default != null:
return $default(_that.id,_that.label,_that.votes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PollOptionModel extends PollOptionModel {
  const _PollOptionModel({required this.id, required this.label, this.votes}): super._();
  factory _PollOptionModel.fromJson(Map<String, dynamic> json) => _$PollOptionModelFromJson(json);

@override final  String id;
@override final  String label;
@override final  int? votes;

/// Create a copy of PollOptionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollOptionModelCopyWith<_PollOptionModel> get copyWith => __$PollOptionModelCopyWithImpl<_PollOptionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PollOptionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollOptionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.votes, votes) || other.votes == votes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,votes);

@override
String toString() {
  return 'PollOptionModel(id: $id, label: $label, votes: $votes)';
}


}

/// @nodoc
abstract mixin class _$PollOptionModelCopyWith<$Res> implements $PollOptionModelCopyWith<$Res> {
  factory _$PollOptionModelCopyWith(_PollOptionModel value, $Res Function(_PollOptionModel) _then) = __$PollOptionModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, int? votes
});




}
/// @nodoc
class __$PollOptionModelCopyWithImpl<$Res>
    implements _$PollOptionModelCopyWith<$Res> {
  __$PollOptionModelCopyWithImpl(this._self, this._then);

  final _PollOptionModel _self;
  final $Res Function(_PollOptionModel) _then;

/// Create a copy of PollOptionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? votes = freezed,}) {
  return _then(_PollOptionModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,votes: freezed == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$PollModel {

 DateTime get endsAt; bool get closed; int get totalVotes; String? get myOptionId; bool get resultsVisible; List<PollOptionModel> get options;
/// Create a copy of PollModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollModelCopyWith<PollModel> get copyWith => _$PollModelCopyWithImpl<PollModel>(this as PollModel, _$identity);

  /// Serializes this PollModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollModel&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.totalVotes, totalVotes) || other.totalVotes == totalVotes)&&(identical(other.myOptionId, myOptionId) || other.myOptionId == myOptionId)&&(identical(other.resultsVisible, resultsVisible) || other.resultsVisible == resultsVisible)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,endsAt,closed,totalVotes,myOptionId,resultsVisible,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'PollModel(endsAt: $endsAt, closed: $closed, totalVotes: $totalVotes, myOptionId: $myOptionId, resultsVisible: $resultsVisible, options: $options)';
}


}

/// @nodoc
abstract mixin class $PollModelCopyWith<$Res>  {
  factory $PollModelCopyWith(PollModel value, $Res Function(PollModel) _then) = _$PollModelCopyWithImpl;
@useResult
$Res call({
 DateTime endsAt, bool closed, int totalVotes, String? myOptionId, bool resultsVisible, List<PollOptionModel> options
});




}
/// @nodoc
class _$PollModelCopyWithImpl<$Res>
    implements $PollModelCopyWith<$Res> {
  _$PollModelCopyWithImpl(this._self, this._then);

  final PollModel _self;
  final $Res Function(PollModel) _then;

/// Create a copy of PollModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? endsAt = null,Object? closed = null,Object? totalVotes = null,Object? myOptionId = freezed,Object? resultsVisible = null,Object? options = null,}) {
  return _then(_self.copyWith(
endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,totalVotes: null == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int,myOptionId: freezed == myOptionId ? _self.myOptionId : myOptionId // ignore: cast_nullable_to_non_nullable
as String?,resultsVisible: null == resultsVisible ? _self.resultsVisible : resultsVisible // ignore: cast_nullable_to_non_nullable
as bool,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<PollOptionModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [PollModel].
extension PollModelPatterns on PollModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollModel value)  $default,){
final _that = this;
switch (_that) {
case _PollModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollModel value)?  $default,){
final _that = this;
switch (_that) {
case _PollModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime endsAt,  bool closed,  int totalVotes,  String? myOptionId,  bool resultsVisible,  List<PollOptionModel> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PollModel() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime endsAt,  bool closed,  int totalVotes,  String? myOptionId,  bool resultsVisible,  List<PollOptionModel> options)  $default,) {final _that = this;
switch (_that) {
case _PollModel():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime endsAt,  bool closed,  int totalVotes,  String? myOptionId,  bool resultsVisible,  List<PollOptionModel> options)?  $default,) {final _that = this;
switch (_that) {
case _PollModel() when $default != null:
return $default(_that.endsAt,_that.closed,_that.totalVotes,_that.myOptionId,_that.resultsVisible,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PollModel extends PollModel {
  const _PollModel({required this.endsAt, this.closed = false, this.totalVotes = 0, this.myOptionId, this.resultsVisible = false, final  List<PollOptionModel> options = const <PollOptionModel>[]}): _options = options,super._();
  factory _PollModel.fromJson(Map<String, dynamic> json) => _$PollModelFromJson(json);

@override final  DateTime endsAt;
@override@JsonKey() final  bool closed;
@override@JsonKey() final  int totalVotes;
@override final  String? myOptionId;
@override@JsonKey() final  bool resultsVisible;
 final  List<PollOptionModel> _options;
@override@JsonKey() List<PollOptionModel> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of PollModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollModelCopyWith<_PollModel> get copyWith => __$PollModelCopyWithImpl<_PollModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PollModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollModel&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.totalVotes, totalVotes) || other.totalVotes == totalVotes)&&(identical(other.myOptionId, myOptionId) || other.myOptionId == myOptionId)&&(identical(other.resultsVisible, resultsVisible) || other.resultsVisible == resultsVisible)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,endsAt,closed,totalVotes,myOptionId,resultsVisible,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'PollModel(endsAt: $endsAt, closed: $closed, totalVotes: $totalVotes, myOptionId: $myOptionId, resultsVisible: $resultsVisible, options: $options)';
}


}

/// @nodoc
abstract mixin class _$PollModelCopyWith<$Res> implements $PollModelCopyWith<$Res> {
  factory _$PollModelCopyWith(_PollModel value, $Res Function(_PollModel) _then) = __$PollModelCopyWithImpl;
@override @useResult
$Res call({
 DateTime endsAt, bool closed, int totalVotes, String? myOptionId, bool resultsVisible, List<PollOptionModel> options
});




}
/// @nodoc
class __$PollModelCopyWithImpl<$Res>
    implements _$PollModelCopyWith<$Res> {
  __$PollModelCopyWithImpl(this._self, this._then);

  final _PollModel _self;
  final $Res Function(_PollModel) _then;

/// Create a copy of PollModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? endsAt = null,Object? closed = null,Object? totalVotes = null,Object? myOptionId = freezed,Object? resultsVisible = null,Object? options = null,}) {
  return _then(_PollModel(
endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,totalVotes: null == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int,myOptionId: freezed == myOptionId ? _self.myOptionId : myOptionId // ignore: cast_nullable_to_non_nullable
as String?,resultsVisible: null == resultsVisible ? _self.resultsVisible : resultsVisible // ignore: cast_nullable_to_non_nullable
as bool,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<PollOptionModel>,
  ));
}


}

// dart format on
