// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClientConfigModel {

 bool get socialEnabled;@JsonKey(fromJson: _flagsFromJson) Map<String, bool> get flags;@JsonKey(fromJson: _versionsFromJson) Map<String, String?> get minVersion; bool get updateRequired; Map<String, dynamic> get config;@JsonKey(fromJson: bannersFromJson, includeToJson: false) List<CommunityBanner> get banners;
/// Create a copy of ClientConfigModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientConfigModelCopyWith<ClientConfigModel> get copyWith => _$ClientConfigModelCopyWithImpl<ClientConfigModel>(this as ClientConfigModel, _$identity);

  /// Serializes this ClientConfigModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientConfigModel&&(identical(other.socialEnabled, socialEnabled) || other.socialEnabled == socialEnabled)&&const DeepCollectionEquality().equals(other.flags, flags)&&const DeepCollectionEquality().equals(other.minVersion, minVersion)&&(identical(other.updateRequired, updateRequired) || other.updateRequired == updateRequired)&&const DeepCollectionEquality().equals(other.config, config)&&const DeepCollectionEquality().equals(other.banners, banners));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,socialEnabled,const DeepCollectionEquality().hash(flags),const DeepCollectionEquality().hash(minVersion),updateRequired,const DeepCollectionEquality().hash(config),const DeepCollectionEquality().hash(banners));

@override
String toString() {
  return 'ClientConfigModel(socialEnabled: $socialEnabled, flags: $flags, minVersion: $minVersion, updateRequired: $updateRequired, config: $config, banners: $banners)';
}


}

/// @nodoc
abstract mixin class $ClientConfigModelCopyWith<$Res>  {
  factory $ClientConfigModelCopyWith(ClientConfigModel value, $Res Function(ClientConfigModel) _then) = _$ClientConfigModelCopyWithImpl;
@useResult
$Res call({
 bool socialEnabled,@JsonKey(fromJson: _flagsFromJson) Map<String, bool> flags,@JsonKey(fromJson: _versionsFromJson) Map<String, String?> minVersion, bool updateRequired, Map<String, dynamic> config,@JsonKey(fromJson: bannersFromJson, includeToJson: false) List<CommunityBanner> banners
});




}
/// @nodoc
class _$ClientConfigModelCopyWithImpl<$Res>
    implements $ClientConfigModelCopyWith<$Res> {
  _$ClientConfigModelCopyWithImpl(this._self, this._then);

  final ClientConfigModel _self;
  final $Res Function(ClientConfigModel) _then;

/// Create a copy of ClientConfigModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? socialEnabled = null,Object? flags = null,Object? minVersion = null,Object? updateRequired = null,Object? config = null,Object? banners = null,}) {
  return _then(_self.copyWith(
socialEnabled: null == socialEnabled ? _self.socialEnabled : socialEnabled // ignore: cast_nullable_to_non_nullable
as bool,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,minVersion: null == minVersion ? _self.minVersion : minVersion // ignore: cast_nullable_to_non_nullable
as Map<String, String?>,updateRequired: null == updateRequired ? _self.updateRequired : updateRequired // ignore: cast_nullable_to_non_nullable
as bool,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,banners: null == banners ? _self.banners : banners // ignore: cast_nullable_to_non_nullable
as List<CommunityBanner>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientConfigModel].
extension ClientConfigModelPatterns on ClientConfigModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientConfigModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientConfigModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientConfigModel value)  $default,){
final _that = this;
switch (_that) {
case _ClientConfigModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientConfigModel value)?  $default,){
final _that = this;
switch (_that) {
case _ClientConfigModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool socialEnabled, @JsonKey(fromJson: _flagsFromJson)  Map<String, bool> flags, @JsonKey(fromJson: _versionsFromJson)  Map<String, String?> minVersion,  bool updateRequired,  Map<String, dynamic> config, @JsonKey(fromJson: bannersFromJson, includeToJson: false)  List<CommunityBanner> banners)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientConfigModel() when $default != null:
return $default(_that.socialEnabled,_that.flags,_that.minVersion,_that.updateRequired,_that.config,_that.banners);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool socialEnabled, @JsonKey(fromJson: _flagsFromJson)  Map<String, bool> flags, @JsonKey(fromJson: _versionsFromJson)  Map<String, String?> minVersion,  bool updateRequired,  Map<String, dynamic> config, @JsonKey(fromJson: bannersFromJson, includeToJson: false)  List<CommunityBanner> banners)  $default,) {final _that = this;
switch (_that) {
case _ClientConfigModel():
return $default(_that.socialEnabled,_that.flags,_that.minVersion,_that.updateRequired,_that.config,_that.banners);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool socialEnabled, @JsonKey(fromJson: _flagsFromJson)  Map<String, bool> flags, @JsonKey(fromJson: _versionsFromJson)  Map<String, String?> minVersion,  bool updateRequired,  Map<String, dynamic> config, @JsonKey(fromJson: bannersFromJson, includeToJson: false)  List<CommunityBanner> banners)?  $default,) {final _that = this;
switch (_that) {
case _ClientConfigModel() when $default != null:
return $default(_that.socialEnabled,_that.flags,_that.minVersion,_that.updateRequired,_that.config,_that.banners);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientConfigModel extends ClientConfigModel {
  const _ClientConfigModel({this.socialEnabled = true, @JsonKey(fromJson: _flagsFromJson) final  Map<String, bool> flags = const <String, bool>{}, @JsonKey(fromJson: _versionsFromJson) final  Map<String, String?> minVersion = const <String, String?>{}, this.updateRequired = false, final  Map<String, dynamic> config = const <String, dynamic>{}, @JsonKey(fromJson: bannersFromJson, includeToJson: false) final  List<CommunityBanner> banners = const <CommunityBanner>[]}): _flags = flags,_minVersion = minVersion,_config = config,_banners = banners,super._();
  factory _ClientConfigModel.fromJson(Map<String, dynamic> json) => _$ClientConfigModelFromJson(json);

@override@JsonKey() final  bool socialEnabled;
 final  Map<String, bool> _flags;
@override@JsonKey(fromJson: _flagsFromJson) Map<String, bool> get flags {
  if (_flags is EqualUnmodifiableMapView) return _flags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_flags);
}

 final  Map<String, String?> _minVersion;
@override@JsonKey(fromJson: _versionsFromJson) Map<String, String?> get minVersion {
  if (_minVersion is EqualUnmodifiableMapView) return _minVersion;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_minVersion);
}

@override@JsonKey() final  bool updateRequired;
 final  Map<String, dynamic> _config;
@override@JsonKey() Map<String, dynamic> get config {
  if (_config is EqualUnmodifiableMapView) return _config;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_config);
}

 final  List<CommunityBanner> _banners;
@override@JsonKey(fromJson: bannersFromJson, includeToJson: false) List<CommunityBanner> get banners {
  if (_banners is EqualUnmodifiableListView) return _banners;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_banners);
}


/// Create a copy of ClientConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientConfigModelCopyWith<_ClientConfigModel> get copyWith => __$ClientConfigModelCopyWithImpl<_ClientConfigModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientConfigModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientConfigModel&&(identical(other.socialEnabled, socialEnabled) || other.socialEnabled == socialEnabled)&&const DeepCollectionEquality().equals(other._flags, _flags)&&const DeepCollectionEquality().equals(other._minVersion, _minVersion)&&(identical(other.updateRequired, updateRequired) || other.updateRequired == updateRequired)&&const DeepCollectionEquality().equals(other._config, _config)&&const DeepCollectionEquality().equals(other._banners, _banners));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,socialEnabled,const DeepCollectionEquality().hash(_flags),const DeepCollectionEquality().hash(_minVersion),updateRequired,const DeepCollectionEquality().hash(_config),const DeepCollectionEquality().hash(_banners));

@override
String toString() {
  return 'ClientConfigModel(socialEnabled: $socialEnabled, flags: $flags, minVersion: $minVersion, updateRequired: $updateRequired, config: $config, banners: $banners)';
}


}

/// @nodoc
abstract mixin class _$ClientConfigModelCopyWith<$Res> implements $ClientConfigModelCopyWith<$Res> {
  factory _$ClientConfigModelCopyWith(_ClientConfigModel value, $Res Function(_ClientConfigModel) _then) = __$ClientConfigModelCopyWithImpl;
@override @useResult
$Res call({
 bool socialEnabled,@JsonKey(fromJson: _flagsFromJson) Map<String, bool> flags,@JsonKey(fromJson: _versionsFromJson) Map<String, String?> minVersion, bool updateRequired, Map<String, dynamic> config,@JsonKey(fromJson: bannersFromJson, includeToJson: false) List<CommunityBanner> banners
});




}
/// @nodoc
class __$ClientConfigModelCopyWithImpl<$Res>
    implements _$ClientConfigModelCopyWith<$Res> {
  __$ClientConfigModelCopyWithImpl(this._self, this._then);

  final _ClientConfigModel _self;
  final $Res Function(_ClientConfigModel) _then;

/// Create a copy of ClientConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? socialEnabled = null,Object? flags = null,Object? minVersion = null,Object? updateRequired = null,Object? config = null,Object? banners = null,}) {
  return _then(_ClientConfigModel(
socialEnabled: null == socialEnabled ? _self.socialEnabled : socialEnabled // ignore: cast_nullable_to_non_nullable
as bool,flags: null == flags ? _self._flags : flags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,minVersion: null == minVersion ? _self._minVersion : minVersion // ignore: cast_nullable_to_non_nullable
as Map<String, String?>,updateRequired: null == updateRequired ? _self.updateRequired : updateRequired // ignore: cast_nullable_to_non_nullable
as bool,config: null == config ? _self._config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,banners: null == banners ? _self._banners : banners // ignore: cast_nullable_to_non_nullable
as List<CommunityBanner>,
  ));
}


}

// dart format on
