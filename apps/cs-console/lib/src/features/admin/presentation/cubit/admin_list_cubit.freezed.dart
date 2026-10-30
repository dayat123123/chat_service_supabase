// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_list_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AdminListState<T> {

 LoadStatus get status; List<T> get items; bool get saving; Object? get error;
/// Create a copy of AdminListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminListStateCopyWith<T, AdminListState<T>> get copyWith => _$AdminListStateCopyWithImpl<T, AdminListState<T>>(this as AdminListState<T>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminListState<T>&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.saving, saving) || other.saving == saving)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(items),saving,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'AdminListState<$T>(status: $status, items: $items, saving: $saving, error: $error)';
}


}

/// @nodoc
abstract mixin class $AdminListStateCopyWith<T,$Res>  {
  factory $AdminListStateCopyWith(AdminListState<T> value, $Res Function(AdminListState<T>) _then) = _$AdminListStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<T> items, bool saving, Object? error
});




}
/// @nodoc
class _$AdminListStateCopyWithImpl<T,$Res>
    implements $AdminListStateCopyWith<T, $Res> {
  _$AdminListStateCopyWithImpl(this._self, this._then);

  final AdminListState<T> _self;
  final $Res Function(AdminListState<T>) _then;

/// Create a copy of AdminListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? items = null,Object? saving = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<T>,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminListState].
extension AdminListStatePatterns<T> on AdminListState<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminListState<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminListState<T> value)  $default,){
final _that = this;
switch (_that) {
case _AdminListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminListState<T> value)?  $default,){
final _that = this;
switch (_that) {
case _AdminListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<T> items,  bool saving,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminListState() when $default != null:
return $default(_that.status,_that.items,_that.saving,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<T> items,  bool saving,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _AdminListState():
return $default(_that.status,_that.items,_that.saving,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<T> items,  bool saving,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _AdminListState() when $default != null:
return $default(_that.status,_that.items,_that.saving,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _AdminListState<T> implements AdminListState<T> {
  const _AdminListState({this.status = LoadStatus.initial, final  List<T> items = const [], this.saving = false, this.error}): _items = items;
  

@override@JsonKey() final  LoadStatus status;
 final  List<T> _items;
@override@JsonKey() List<T> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  bool saving;
@override final  Object? error;

/// Create a copy of AdminListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminListStateCopyWith<T, _AdminListState<T>> get copyWith => __$AdminListStateCopyWithImpl<T, _AdminListState<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminListState<T>&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.saving, saving) || other.saving == saving)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_items),saving,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'AdminListState<$T>(status: $status, items: $items, saving: $saving, error: $error)';
}


}

/// @nodoc
abstract mixin class _$AdminListStateCopyWith<T,$Res> implements $AdminListStateCopyWith<T, $Res> {
  factory _$AdminListStateCopyWith(_AdminListState<T> value, $Res Function(_AdminListState<T>) _then) = __$AdminListStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<T> items, bool saving, Object? error
});




}
/// @nodoc
class __$AdminListStateCopyWithImpl<T,$Res>
    implements _$AdminListStateCopyWith<T, $Res> {
  __$AdminListStateCopyWithImpl(this._self, this._then);

  final _AdminListState<T> _self;
  final $Res Function(_AdminListState<T>) _then;

/// Create a copy of AdminListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? items = null,Object? saving = null,Object? error = freezed,}) {
  return _then(_AdminListState<T>(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<T>,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
