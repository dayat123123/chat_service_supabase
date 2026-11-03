// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationTypePreference {

 String get type; bool? get inApp; bool get push; bool get inAppLocked;
/// Create a copy of NotificationTypePreference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationTypePreferenceCopyWith<NotificationTypePreference> get copyWith => _$NotificationTypePreferenceCopyWithImpl<NotificationTypePreference>(this as NotificationTypePreference, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationTypePreference&&(identical(other.type, type) || other.type == type)&&(identical(other.inApp, inApp) || other.inApp == inApp)&&(identical(other.push, push) || other.push == push)&&(identical(other.inAppLocked, inAppLocked) || other.inAppLocked == inAppLocked));
}


@override
int get hashCode => Object.hash(runtimeType,type,inApp,push,inAppLocked);

@override
String toString() {
  return 'NotificationTypePreference(type: $type, inApp: $inApp, push: $push, inAppLocked: $inAppLocked)';
}


}

/// @nodoc
abstract mixin class $NotificationTypePreferenceCopyWith<$Res>  {
  factory $NotificationTypePreferenceCopyWith(NotificationTypePreference value, $Res Function(NotificationTypePreference) _then) = _$NotificationTypePreferenceCopyWithImpl;
@useResult
$Res call({
 String type, bool? inApp, bool push, bool inAppLocked
});




}
/// @nodoc
class _$NotificationTypePreferenceCopyWithImpl<$Res>
    implements $NotificationTypePreferenceCopyWith<$Res> {
  _$NotificationTypePreferenceCopyWithImpl(this._self, this._then);

  final NotificationTypePreference _self;
  final $Res Function(NotificationTypePreference) _then;

/// Create a copy of NotificationTypePreference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? inApp = freezed,Object? push = null,Object? inAppLocked = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,inApp: freezed == inApp ? _self.inApp : inApp // ignore: cast_nullable_to_non_nullable
as bool?,push: null == push ? _self.push : push // ignore: cast_nullable_to_non_nullable
as bool,inAppLocked: null == inAppLocked ? _self.inAppLocked : inAppLocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationTypePreference].
extension NotificationTypePreferencePatterns on NotificationTypePreference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationTypePreference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationTypePreference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationTypePreference value)  $default,){
final _that = this;
switch (_that) {
case _NotificationTypePreference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationTypePreference value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationTypePreference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  bool? inApp,  bool push,  bool inAppLocked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationTypePreference() when $default != null:
return $default(_that.type,_that.inApp,_that.push,_that.inAppLocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  bool? inApp,  bool push,  bool inAppLocked)  $default,) {final _that = this;
switch (_that) {
case _NotificationTypePreference():
return $default(_that.type,_that.inApp,_that.push,_that.inAppLocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  bool? inApp,  bool push,  bool inAppLocked)?  $default,) {final _that = this;
switch (_that) {
case _NotificationTypePreference() when $default != null:
return $default(_that.type,_that.inApp,_that.push,_that.inAppLocked);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationTypePreference extends NotificationTypePreference {
  const _NotificationTypePreference({required this.type, this.inApp, this.push = true, this.inAppLocked = false}): super._();
  

@override final  String type;
@override final  bool? inApp;
@override@JsonKey() final  bool push;
@override@JsonKey() final  bool inAppLocked;

/// Create a copy of NotificationTypePreference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationTypePreferenceCopyWith<_NotificationTypePreference> get copyWith => __$NotificationTypePreferenceCopyWithImpl<_NotificationTypePreference>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationTypePreference&&(identical(other.type, type) || other.type == type)&&(identical(other.inApp, inApp) || other.inApp == inApp)&&(identical(other.push, push) || other.push == push)&&(identical(other.inAppLocked, inAppLocked) || other.inAppLocked == inAppLocked));
}


@override
int get hashCode => Object.hash(runtimeType,type,inApp,push,inAppLocked);

@override
String toString() {
  return 'NotificationTypePreference(type: $type, inApp: $inApp, push: $push, inAppLocked: $inAppLocked)';
}


}

/// @nodoc
abstract mixin class _$NotificationTypePreferenceCopyWith<$Res> implements $NotificationTypePreferenceCopyWith<$Res> {
  factory _$NotificationTypePreferenceCopyWith(_NotificationTypePreference value, $Res Function(_NotificationTypePreference) _then) = __$NotificationTypePreferenceCopyWithImpl;
@override @useResult
$Res call({
 String type, bool? inApp, bool push, bool inAppLocked
});




}
/// @nodoc
class __$NotificationTypePreferenceCopyWithImpl<$Res>
    implements _$NotificationTypePreferenceCopyWith<$Res> {
  __$NotificationTypePreferenceCopyWithImpl(this._self, this._then);

  final _NotificationTypePreference _self;
  final $Res Function(_NotificationTypePreference) _then;

/// Create a copy of NotificationTypePreference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? inApp = freezed,Object? push = null,Object? inAppLocked = null,}) {
  return _then(_NotificationTypePreference(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,inApp: freezed == inApp ? _self.inApp : inApp // ignore: cast_nullable_to_non_nullable
as bool?,push: null == push ? _self.push : push // ignore: cast_nullable_to_non_nullable
as bool,inAppLocked: null == inAppLocked ? _self.inAppLocked : inAppLocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$QuietHours {

 bool get enabled; String? get start; String? get end; String get timezone;
/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuietHoursCopyWith<QuietHours> get copyWith => _$QuietHoursCopyWithImpl<QuietHours>(this as QuietHours, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuietHours&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,start,end,timezone);

@override
String toString() {
  return 'QuietHours(enabled: $enabled, start: $start, end: $end, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class $QuietHoursCopyWith<$Res>  {
  factory $QuietHoursCopyWith(QuietHours value, $Res Function(QuietHours) _then) = _$QuietHoursCopyWithImpl;
@useResult
$Res call({
 bool enabled, String? start, String? end, String timezone
});




}
/// @nodoc
class _$QuietHoursCopyWithImpl<$Res>
    implements $QuietHoursCopyWith<$Res> {
  _$QuietHoursCopyWithImpl(this._self, this._then);

  final QuietHours _self;
  final $Res Function(QuietHours) _then;

/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? start = freezed,Object? end = freezed,Object? timezone = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String?,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [QuietHours].
extension QuietHoursPatterns on QuietHours {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuietHours value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuietHours value)  $default,){
final _that = this;
switch (_that) {
case _QuietHours():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuietHours value)?  $default,){
final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String? start,  String? end,  String timezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
return $default(_that.enabled,_that.start,_that.end,_that.timezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String? start,  String? end,  String timezone)  $default,) {final _that = this;
switch (_that) {
case _QuietHours():
return $default(_that.enabled,_that.start,_that.end,_that.timezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String? start,  String? end,  String timezone)?  $default,) {final _that = this;
switch (_that) {
case _QuietHours() when $default != null:
return $default(_that.enabled,_that.start,_that.end,_that.timezone);case _:
  return null;

}
}

}

/// @nodoc


class _QuietHours implements QuietHours {
  const _QuietHours({this.enabled = false, this.start, this.end, this.timezone = 'Asia/Jakarta'});
  

@override@JsonKey() final  bool enabled;
@override final  String? start;
@override final  String? end;
@override@JsonKey() final  String timezone;

/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuietHoursCopyWith<_QuietHours> get copyWith => __$QuietHoursCopyWithImpl<_QuietHours>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuietHours&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,start,end,timezone);

@override
String toString() {
  return 'QuietHours(enabled: $enabled, start: $start, end: $end, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class _$QuietHoursCopyWith<$Res> implements $QuietHoursCopyWith<$Res> {
  factory _$QuietHoursCopyWith(_QuietHours value, $Res Function(_QuietHours) _then) = __$QuietHoursCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String? start, String? end, String timezone
});




}
/// @nodoc
class __$QuietHoursCopyWithImpl<$Res>
    implements _$QuietHoursCopyWith<$Res> {
  __$QuietHoursCopyWithImpl(this._self, this._then);

  final _QuietHours _self;
  final $Res Function(_QuietHours) _then;

/// Create a copy of QuietHours
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? start = freezed,Object? end = freezed,Object? timezone = null,}) {
  return _then(_QuietHours(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String?,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$NotificationPreferences {

 List<NotificationTypePreference> get types; QuietHours get quietHours; int get aggregateMinutes;
/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesCopyWith<NotificationPreferences> get copyWith => _$NotificationPreferencesCopyWithImpl<NotificationPreferences>(this as NotificationPreferences, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferences&&const DeepCollectionEquality().equals(other.types, types)&&(identical(other.quietHours, quietHours) || other.quietHours == quietHours)&&(identical(other.aggregateMinutes, aggregateMinutes) || other.aggregateMinutes == aggregateMinutes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(types),quietHours,aggregateMinutes);

@override
String toString() {
  return 'NotificationPreferences(types: $types, quietHours: $quietHours, aggregateMinutes: $aggregateMinutes)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesCopyWith<$Res>  {
  factory $NotificationPreferencesCopyWith(NotificationPreferences value, $Res Function(NotificationPreferences) _then) = _$NotificationPreferencesCopyWithImpl;
@useResult
$Res call({
 List<NotificationTypePreference> types, QuietHours quietHours, int aggregateMinutes
});


$QuietHoursCopyWith<$Res> get quietHours;

}
/// @nodoc
class _$NotificationPreferencesCopyWithImpl<$Res>
    implements $NotificationPreferencesCopyWith<$Res> {
  _$NotificationPreferencesCopyWithImpl(this._self, this._then);

  final NotificationPreferences _self;
  final $Res Function(NotificationPreferences) _then;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? types = null,Object? quietHours = null,Object? aggregateMinutes = null,}) {
  return _then(_self.copyWith(
types: null == types ? _self.types : types // ignore: cast_nullable_to_non_nullable
as List<NotificationTypePreference>,quietHours: null == quietHours ? _self.quietHours : quietHours // ignore: cast_nullable_to_non_nullable
as QuietHours,aggregateMinutes: null == aggregateMinutes ? _self.aggregateMinutes : aggregateMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuietHoursCopyWith<$Res> get quietHours {
  
  return $QuietHoursCopyWith<$Res>(_self.quietHours, (value) {
    return _then(_self.copyWith(quietHours: value));
  });
}
}


/// Adds pattern-matching-related methods to [NotificationPreferences].
extension NotificationPreferencesPatterns on NotificationPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPreferences value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<NotificationTypePreference> types,  QuietHours quietHours,  int aggregateMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that.types,_that.quietHours,_that.aggregateMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<NotificationTypePreference> types,  QuietHours quietHours,  int aggregateMinutes)  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferences():
return $default(_that.types,_that.quietHours,_that.aggregateMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<NotificationTypePreference> types,  QuietHours quietHours,  int aggregateMinutes)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that.types,_that.quietHours,_that.aggregateMinutes);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationPreferences extends NotificationPreferences {
  const _NotificationPreferences({final  List<NotificationTypePreference> types = const <NotificationTypePreference>[], this.quietHours = const QuietHours(), this.aggregateMinutes = 60}): _types = types,super._();
  

 final  List<NotificationTypePreference> _types;
@override@JsonKey() List<NotificationTypePreference> get types {
  if (_types is EqualUnmodifiableListView) return _types;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_types);
}

@override@JsonKey() final  QuietHours quietHours;
@override@JsonKey() final  int aggregateMinutes;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPreferencesCopyWith<_NotificationPreferences> get copyWith => __$NotificationPreferencesCopyWithImpl<_NotificationPreferences>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPreferences&&const DeepCollectionEquality().equals(other._types, _types)&&(identical(other.quietHours, quietHours) || other.quietHours == quietHours)&&(identical(other.aggregateMinutes, aggregateMinutes) || other.aggregateMinutes == aggregateMinutes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_types),quietHours,aggregateMinutes);

@override
String toString() {
  return 'NotificationPreferences(types: $types, quietHours: $quietHours, aggregateMinutes: $aggregateMinutes)';
}


}

/// @nodoc
abstract mixin class _$NotificationPreferencesCopyWith<$Res> implements $NotificationPreferencesCopyWith<$Res> {
  factory _$NotificationPreferencesCopyWith(_NotificationPreferences value, $Res Function(_NotificationPreferences) _then) = __$NotificationPreferencesCopyWithImpl;
@override @useResult
$Res call({
 List<NotificationTypePreference> types, QuietHours quietHours, int aggregateMinutes
});


@override $QuietHoursCopyWith<$Res> get quietHours;

}
/// @nodoc
class __$NotificationPreferencesCopyWithImpl<$Res>
    implements _$NotificationPreferencesCopyWith<$Res> {
  __$NotificationPreferencesCopyWithImpl(this._self, this._then);

  final _NotificationPreferences _self;
  final $Res Function(_NotificationPreferences) _then;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? types = null,Object? quietHours = null,Object? aggregateMinutes = null,}) {
  return _then(_NotificationPreferences(
types: null == types ? _self._types : types // ignore: cast_nullable_to_non_nullable
as List<NotificationTypePreference>,quietHours: null == quietHours ? _self.quietHours : quietHours // ignore: cast_nullable_to_non_nullable
as QuietHours,aggregateMinutes: null == aggregateMinutes ? _self.aggregateMinutes : aggregateMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuietHoursCopyWith<$Res> get quietHours {
  
  return $QuietHoursCopyWith<$Res>(_self.quietHours, (value) {
    return _then(_self.copyWith(quietHours: value));
  });
}
}

// dart format on
