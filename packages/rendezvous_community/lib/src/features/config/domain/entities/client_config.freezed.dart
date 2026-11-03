// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClientConfig {

 bool get socialEnabled; Map<String, bool> get flags; Map<String, String?> get minVersions; bool get updateRequired; Duration get editWindow; List<String> get messageReactions; int get searchMinLength; List<String> get notificationTypes; List<String> get trendingWindows; int get notificationAggregateMinutes; Duration get clockSkew; List<CommunityBanner> get banners; DateTime? get fetchedAt;
/// Create a copy of ClientConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientConfigCopyWith<ClientConfig> get copyWith => _$ClientConfigCopyWithImpl<ClientConfig>(this as ClientConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientConfig&&(identical(other.socialEnabled, socialEnabled) || other.socialEnabled == socialEnabled)&&const DeepCollectionEquality().equals(other.flags, flags)&&const DeepCollectionEquality().equals(other.minVersions, minVersions)&&(identical(other.updateRequired, updateRequired) || other.updateRequired == updateRequired)&&(identical(other.editWindow, editWindow) || other.editWindow == editWindow)&&const DeepCollectionEquality().equals(other.messageReactions, messageReactions)&&(identical(other.searchMinLength, searchMinLength) || other.searchMinLength == searchMinLength)&&const DeepCollectionEquality().equals(other.notificationTypes, notificationTypes)&&const DeepCollectionEquality().equals(other.trendingWindows, trendingWindows)&&(identical(other.notificationAggregateMinutes, notificationAggregateMinutes) || other.notificationAggregateMinutes == notificationAggregateMinutes)&&(identical(other.clockSkew, clockSkew) || other.clockSkew == clockSkew)&&const DeepCollectionEquality().equals(other.banners, banners)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}


@override
int get hashCode => Object.hash(runtimeType,socialEnabled,const DeepCollectionEquality().hash(flags),const DeepCollectionEquality().hash(minVersions),updateRequired,editWindow,const DeepCollectionEquality().hash(messageReactions),searchMinLength,const DeepCollectionEquality().hash(notificationTypes),const DeepCollectionEquality().hash(trendingWindows),notificationAggregateMinutes,clockSkew,const DeepCollectionEquality().hash(banners),fetchedAt);

@override
String toString() {
  return 'ClientConfig(socialEnabled: $socialEnabled, flags: $flags, minVersions: $minVersions, updateRequired: $updateRequired, editWindow: $editWindow, messageReactions: $messageReactions, searchMinLength: $searchMinLength, notificationTypes: $notificationTypes, trendingWindows: $trendingWindows, notificationAggregateMinutes: $notificationAggregateMinutes, clockSkew: $clockSkew, banners: $banners, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class $ClientConfigCopyWith<$Res>  {
  factory $ClientConfigCopyWith(ClientConfig value, $Res Function(ClientConfig) _then) = _$ClientConfigCopyWithImpl;
@useResult
$Res call({
 bool socialEnabled, Map<String, bool> flags, Map<String, String?> minVersions, bool updateRequired, Duration editWindow, List<String> messageReactions, int searchMinLength, List<String> notificationTypes, List<String> trendingWindows, int notificationAggregateMinutes, Duration clockSkew, List<CommunityBanner> banners, DateTime? fetchedAt
});




}
/// @nodoc
class _$ClientConfigCopyWithImpl<$Res>
    implements $ClientConfigCopyWith<$Res> {
  _$ClientConfigCopyWithImpl(this._self, this._then);

  final ClientConfig _self;
  final $Res Function(ClientConfig) _then;

/// Create a copy of ClientConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? socialEnabled = null,Object? flags = null,Object? minVersions = null,Object? updateRequired = null,Object? editWindow = null,Object? messageReactions = null,Object? searchMinLength = null,Object? notificationTypes = null,Object? trendingWindows = null,Object? notificationAggregateMinutes = null,Object? clockSkew = null,Object? banners = null,Object? fetchedAt = freezed,}) {
  return _then(_self.copyWith(
socialEnabled: null == socialEnabled ? _self.socialEnabled : socialEnabled // ignore: cast_nullable_to_non_nullable
as bool,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,minVersions: null == minVersions ? _self.minVersions : minVersions // ignore: cast_nullable_to_non_nullable
as Map<String, String?>,updateRequired: null == updateRequired ? _self.updateRequired : updateRequired // ignore: cast_nullable_to_non_nullable
as bool,editWindow: null == editWindow ? _self.editWindow : editWindow // ignore: cast_nullable_to_non_nullable
as Duration,messageReactions: null == messageReactions ? _self.messageReactions : messageReactions // ignore: cast_nullable_to_non_nullable
as List<String>,searchMinLength: null == searchMinLength ? _self.searchMinLength : searchMinLength // ignore: cast_nullable_to_non_nullable
as int,notificationTypes: null == notificationTypes ? _self.notificationTypes : notificationTypes // ignore: cast_nullable_to_non_nullable
as List<String>,trendingWindows: null == trendingWindows ? _self.trendingWindows : trendingWindows // ignore: cast_nullable_to_non_nullable
as List<String>,notificationAggregateMinutes: null == notificationAggregateMinutes ? _self.notificationAggregateMinutes : notificationAggregateMinutes // ignore: cast_nullable_to_non_nullable
as int,clockSkew: null == clockSkew ? _self.clockSkew : clockSkew // ignore: cast_nullable_to_non_nullable
as Duration,banners: null == banners ? _self.banners : banners // ignore: cast_nullable_to_non_nullable
as List<CommunityBanner>,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientConfig].
extension ClientConfigPatterns on ClientConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientConfig value)  $default,){
final _that = this;
switch (_that) {
case _ClientConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ClientConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool socialEnabled,  Map<String, bool> flags,  Map<String, String?> minVersions,  bool updateRequired,  Duration editWindow,  List<String> messageReactions,  int searchMinLength,  List<String> notificationTypes,  List<String> trendingWindows,  int notificationAggregateMinutes,  Duration clockSkew,  List<CommunityBanner> banners,  DateTime? fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientConfig() when $default != null:
return $default(_that.socialEnabled,_that.flags,_that.minVersions,_that.updateRequired,_that.editWindow,_that.messageReactions,_that.searchMinLength,_that.notificationTypes,_that.trendingWindows,_that.notificationAggregateMinutes,_that.clockSkew,_that.banners,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool socialEnabled,  Map<String, bool> flags,  Map<String, String?> minVersions,  bool updateRequired,  Duration editWindow,  List<String> messageReactions,  int searchMinLength,  List<String> notificationTypes,  List<String> trendingWindows,  int notificationAggregateMinutes,  Duration clockSkew,  List<CommunityBanner> banners,  DateTime? fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _ClientConfig():
return $default(_that.socialEnabled,_that.flags,_that.minVersions,_that.updateRequired,_that.editWindow,_that.messageReactions,_that.searchMinLength,_that.notificationTypes,_that.trendingWindows,_that.notificationAggregateMinutes,_that.clockSkew,_that.banners,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool socialEnabled,  Map<String, bool> flags,  Map<String, String?> minVersions,  bool updateRequired,  Duration editWindow,  List<String> messageReactions,  int searchMinLength,  List<String> notificationTypes,  List<String> trendingWindows,  int notificationAggregateMinutes,  Duration clockSkew,  List<CommunityBanner> banners,  DateTime? fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _ClientConfig() when $default != null:
return $default(_that.socialEnabled,_that.flags,_that.minVersions,_that.updateRequired,_that.editWindow,_that.messageReactions,_that.searchMinLength,_that.notificationTypes,_that.trendingWindows,_that.notificationAggregateMinutes,_that.clockSkew,_that.banners,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ClientConfig extends ClientConfig {
  const _ClientConfig({this.socialEnabled = true, final  Map<String, bool> flags = const <String, bool>{}, final  Map<String, String?> minVersions = const <String, String?>{}, this.updateRequired = false, this.editWindow = const Duration(minutes: 15), final  List<String> messageReactions = const <String>['👍', '❤️', '😂', '😮', '😢', '🔥'], this.searchMinLength = 2, final  List<String> notificationTypes = const <String>[], final  List<String> trendingWindows = const <String>['24h', '7d'], this.notificationAggregateMinutes = 60, this.clockSkew = Duration.zero, final  List<CommunityBanner> banners = const <CommunityBanner>[], this.fetchedAt}): _flags = flags,_minVersions = minVersions,_messageReactions = messageReactions,_notificationTypes = notificationTypes,_trendingWindows = trendingWindows,_banners = banners,super._();
  

@override@JsonKey() final  bool socialEnabled;
 final  Map<String, bool> _flags;
@override@JsonKey() Map<String, bool> get flags {
  if (_flags is EqualUnmodifiableMapView) return _flags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_flags);
}

 final  Map<String, String?> _minVersions;
@override@JsonKey() Map<String, String?> get minVersions {
  if (_minVersions is EqualUnmodifiableMapView) return _minVersions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_minVersions);
}

@override@JsonKey() final  bool updateRequired;
@override@JsonKey() final  Duration editWindow;
 final  List<String> _messageReactions;
@override@JsonKey() List<String> get messageReactions {
  if (_messageReactions is EqualUnmodifiableListView) return _messageReactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messageReactions);
}

@override@JsonKey() final  int searchMinLength;
 final  List<String> _notificationTypes;
@override@JsonKey() List<String> get notificationTypes {
  if (_notificationTypes is EqualUnmodifiableListView) return _notificationTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notificationTypes);
}

 final  List<String> _trendingWindows;
@override@JsonKey() List<String> get trendingWindows {
  if (_trendingWindows is EqualUnmodifiableListView) return _trendingWindows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trendingWindows);
}

@override@JsonKey() final  int notificationAggregateMinutes;
@override@JsonKey() final  Duration clockSkew;
 final  List<CommunityBanner> _banners;
@override@JsonKey() List<CommunityBanner> get banners {
  if (_banners is EqualUnmodifiableListView) return _banners;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_banners);
}

@override final  DateTime? fetchedAt;

/// Create a copy of ClientConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientConfigCopyWith<_ClientConfig> get copyWith => __$ClientConfigCopyWithImpl<_ClientConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientConfig&&(identical(other.socialEnabled, socialEnabled) || other.socialEnabled == socialEnabled)&&const DeepCollectionEquality().equals(other._flags, _flags)&&const DeepCollectionEquality().equals(other._minVersions, _minVersions)&&(identical(other.updateRequired, updateRequired) || other.updateRequired == updateRequired)&&(identical(other.editWindow, editWindow) || other.editWindow == editWindow)&&const DeepCollectionEquality().equals(other._messageReactions, _messageReactions)&&(identical(other.searchMinLength, searchMinLength) || other.searchMinLength == searchMinLength)&&const DeepCollectionEquality().equals(other._notificationTypes, _notificationTypes)&&const DeepCollectionEquality().equals(other._trendingWindows, _trendingWindows)&&(identical(other.notificationAggregateMinutes, notificationAggregateMinutes) || other.notificationAggregateMinutes == notificationAggregateMinutes)&&(identical(other.clockSkew, clockSkew) || other.clockSkew == clockSkew)&&const DeepCollectionEquality().equals(other._banners, _banners)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}


@override
int get hashCode => Object.hash(runtimeType,socialEnabled,const DeepCollectionEquality().hash(_flags),const DeepCollectionEquality().hash(_minVersions),updateRequired,editWindow,const DeepCollectionEquality().hash(_messageReactions),searchMinLength,const DeepCollectionEquality().hash(_notificationTypes),const DeepCollectionEquality().hash(_trendingWindows),notificationAggregateMinutes,clockSkew,const DeepCollectionEquality().hash(_banners),fetchedAt);

@override
String toString() {
  return 'ClientConfig(socialEnabled: $socialEnabled, flags: $flags, minVersions: $minVersions, updateRequired: $updateRequired, editWindow: $editWindow, messageReactions: $messageReactions, searchMinLength: $searchMinLength, notificationTypes: $notificationTypes, trendingWindows: $trendingWindows, notificationAggregateMinutes: $notificationAggregateMinutes, clockSkew: $clockSkew, banners: $banners, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$ClientConfigCopyWith<$Res> implements $ClientConfigCopyWith<$Res> {
  factory _$ClientConfigCopyWith(_ClientConfig value, $Res Function(_ClientConfig) _then) = __$ClientConfigCopyWithImpl;
@override @useResult
$Res call({
 bool socialEnabled, Map<String, bool> flags, Map<String, String?> minVersions, bool updateRequired, Duration editWindow, List<String> messageReactions, int searchMinLength, List<String> notificationTypes, List<String> trendingWindows, int notificationAggregateMinutes, Duration clockSkew, List<CommunityBanner> banners, DateTime? fetchedAt
});




}
/// @nodoc
class __$ClientConfigCopyWithImpl<$Res>
    implements _$ClientConfigCopyWith<$Res> {
  __$ClientConfigCopyWithImpl(this._self, this._then);

  final _ClientConfig _self;
  final $Res Function(_ClientConfig) _then;

/// Create a copy of ClientConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? socialEnabled = null,Object? flags = null,Object? minVersions = null,Object? updateRequired = null,Object? editWindow = null,Object? messageReactions = null,Object? searchMinLength = null,Object? notificationTypes = null,Object? trendingWindows = null,Object? notificationAggregateMinutes = null,Object? clockSkew = null,Object? banners = null,Object? fetchedAt = freezed,}) {
  return _then(_ClientConfig(
socialEnabled: null == socialEnabled ? _self.socialEnabled : socialEnabled // ignore: cast_nullable_to_non_nullable
as bool,flags: null == flags ? _self._flags : flags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,minVersions: null == minVersions ? _self._minVersions : minVersions // ignore: cast_nullable_to_non_nullable
as Map<String, String?>,updateRequired: null == updateRequired ? _self.updateRequired : updateRequired // ignore: cast_nullable_to_non_nullable
as bool,editWindow: null == editWindow ? _self.editWindow : editWindow // ignore: cast_nullable_to_non_nullable
as Duration,messageReactions: null == messageReactions ? _self._messageReactions : messageReactions // ignore: cast_nullable_to_non_nullable
as List<String>,searchMinLength: null == searchMinLength ? _self.searchMinLength : searchMinLength // ignore: cast_nullable_to_non_nullable
as int,notificationTypes: null == notificationTypes ? _self._notificationTypes : notificationTypes // ignore: cast_nullable_to_non_nullable
as List<String>,trendingWindows: null == trendingWindows ? _self._trendingWindows : trendingWindows // ignore: cast_nullable_to_non_nullable
as List<String>,notificationAggregateMinutes: null == notificationAggregateMinutes ? _self.notificationAggregateMinutes : notificationAggregateMinutes // ignore: cast_nullable_to_non_nullable
as int,clockSkew: null == clockSkew ? _self.clockSkew : clockSkew // ignore: cast_nullable_to_non_nullable
as Duration,banners: null == banners ? _self._banners : banners // ignore: cast_nullable_to_non_nullable
as List<CommunityBanner>,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$CommunityBanner {

 String get id; String get title; String get body; String? get linkUrl; CommunityBannerLevel get level; bool get dismissible; int get priority; DateTime? get startsAt; DateTime? get endsAt;
/// Create a copy of CommunityBanner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunityBannerCopyWith<CommunityBanner> get copyWith => _$CommunityBannerCopyWithImpl<CommunityBanner>(this as CommunityBanner, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunityBanner&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.linkUrl, linkUrl) || other.linkUrl == linkUrl)&&(identical(other.level, level) || other.level == level)&&(identical(other.dismissible, dismissible) || other.dismissible == dismissible)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,body,linkUrl,level,dismissible,priority,startsAt,endsAt);

@override
String toString() {
  return 'CommunityBanner(id: $id, title: $title, body: $body, linkUrl: $linkUrl, level: $level, dismissible: $dismissible, priority: $priority, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class $CommunityBannerCopyWith<$Res>  {
  factory $CommunityBannerCopyWith(CommunityBanner value, $Res Function(CommunityBanner) _then) = _$CommunityBannerCopyWithImpl;
@useResult
$Res call({
 String id, String title, String body, String? linkUrl, CommunityBannerLevel level, bool dismissible, int priority, DateTime? startsAt, DateTime? endsAt
});




}
/// @nodoc
class _$CommunityBannerCopyWithImpl<$Res>
    implements $CommunityBannerCopyWith<$Res> {
  _$CommunityBannerCopyWithImpl(this._self, this._then);

  final CommunityBanner _self;
  final $Res Function(CommunityBanner) _then;

/// Create a copy of CommunityBanner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? body = null,Object? linkUrl = freezed,Object? level = null,Object? dismissible = null,Object? priority = null,Object? startsAt = freezed,Object? endsAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,linkUrl: freezed == linkUrl ? _self.linkUrl : linkUrl // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as CommunityBannerLevel,dismissible: null == dismissible ? _self.dismissible : dismissible // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunityBanner].
extension CommunityBannerPatterns on CommunityBanner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunityBanner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunityBanner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunityBanner value)  $default,){
final _that = this;
switch (_that) {
case _CommunityBanner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunityBanner value)?  $default,){
final _that = this;
switch (_that) {
case _CommunityBanner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String body,  String? linkUrl,  CommunityBannerLevel level,  bool dismissible,  int priority,  DateTime? startsAt,  DateTime? endsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunityBanner() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.linkUrl,_that.level,_that.dismissible,_that.priority,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String body,  String? linkUrl,  CommunityBannerLevel level,  bool dismissible,  int priority,  DateTime? startsAt,  DateTime? endsAt)  $default,) {final _that = this;
switch (_that) {
case _CommunityBanner():
return $default(_that.id,_that.title,_that.body,_that.linkUrl,_that.level,_that.dismissible,_that.priority,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String body,  String? linkUrl,  CommunityBannerLevel level,  bool dismissible,  int priority,  DateTime? startsAt,  DateTime? endsAt)?  $default,) {final _that = this;
switch (_that) {
case _CommunityBanner() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.linkUrl,_that.level,_that.dismissible,_that.priority,_that.startsAt,_that.endsAt);case _:
  return null;

}
}

}

/// @nodoc


class _CommunityBanner implements CommunityBanner {
  const _CommunityBanner({required this.id, required this.title, this.body = '', this.linkUrl, this.level = CommunityBannerLevel.info, this.dismissible = true, this.priority = 0, this.startsAt, this.endsAt});
  

@override final  String id;
@override final  String title;
@override@JsonKey() final  String body;
@override final  String? linkUrl;
@override@JsonKey() final  CommunityBannerLevel level;
@override@JsonKey() final  bool dismissible;
@override@JsonKey() final  int priority;
@override final  DateTime? startsAt;
@override final  DateTime? endsAt;

/// Create a copy of CommunityBanner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunityBannerCopyWith<_CommunityBanner> get copyWith => __$CommunityBannerCopyWithImpl<_CommunityBanner>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunityBanner&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.linkUrl, linkUrl) || other.linkUrl == linkUrl)&&(identical(other.level, level) || other.level == level)&&(identical(other.dismissible, dismissible) || other.dismissible == dismissible)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,body,linkUrl,level,dismissible,priority,startsAt,endsAt);

@override
String toString() {
  return 'CommunityBanner(id: $id, title: $title, body: $body, linkUrl: $linkUrl, level: $level, dismissible: $dismissible, priority: $priority, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class _$CommunityBannerCopyWith<$Res> implements $CommunityBannerCopyWith<$Res> {
  factory _$CommunityBannerCopyWith(_CommunityBanner value, $Res Function(_CommunityBanner) _then) = __$CommunityBannerCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String body, String? linkUrl, CommunityBannerLevel level, bool dismissible, int priority, DateTime? startsAt, DateTime? endsAt
});




}
/// @nodoc
class __$CommunityBannerCopyWithImpl<$Res>
    implements _$CommunityBannerCopyWith<$Res> {
  __$CommunityBannerCopyWithImpl(this._self, this._then);

  final _CommunityBanner _self;
  final $Res Function(_CommunityBanner) _then;

/// Create a copy of CommunityBanner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? body = null,Object? linkUrl = freezed,Object? level = null,Object? dismissible = null,Object? priority = null,Object? startsAt = freezed,Object? endsAt = freezed,}) {
  return _then(_CommunityBanner(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,linkUrl: freezed == linkUrl ? _self.linkUrl : linkUrl // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as CommunityBannerLevel,dismissible: null == dismissible ? _self.dismissible : dismissible // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
