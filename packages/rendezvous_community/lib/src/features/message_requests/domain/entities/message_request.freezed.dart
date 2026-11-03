// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MessageRequest {

 String get roomId; UserSummary get sender; int get messageCount; bool get hasImage; String? get lastMessagePreview; DateTime? get lastMessageAt; DateTime get createdAt;
/// Create a copy of MessageRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageRequestCopyWith<MessageRequest> get copyWith => _$MessageRequestCopyWithImpl<MessageRequest>(this as MessageRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageRequest&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount)&&(identical(other.hasImage, hasImage) || other.hasImage == hasImage)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,roomId,sender,messageCount,hasImage,lastMessagePreview,lastMessageAt,createdAt);

@override
String toString() {
  return 'MessageRequest(roomId: $roomId, sender: $sender, messageCount: $messageCount, hasImage: $hasImage, lastMessagePreview: $lastMessagePreview, lastMessageAt: $lastMessageAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $MessageRequestCopyWith<$Res>  {
  factory $MessageRequestCopyWith(MessageRequest value, $Res Function(MessageRequest) _then) = _$MessageRequestCopyWithImpl;
@useResult
$Res call({
 String roomId, UserSummary sender, int messageCount, bool hasImage, String? lastMessagePreview, DateTime? lastMessageAt, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class _$MessageRequestCopyWithImpl<$Res>
    implements $MessageRequestCopyWith<$Res> {
  _$MessageRequestCopyWithImpl(this._self, this._then);

  final MessageRequest _self;
  final $Res Function(MessageRequest) _then;

/// Create a copy of MessageRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = null,Object? sender = null,Object? messageCount = null,Object? hasImage = null,Object? lastMessagePreview = freezed,Object? lastMessageAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,messageCount: null == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int,hasImage: null == hasImage ? _self.hasImage : hasImage // ignore: cast_nullable_to_non_nullable
as bool,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of MessageRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageRequest].
extension MessageRequestPatterns on MessageRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageRequest value)  $default,){
final _that = this;
switch (_that) {
case _MessageRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageRequest value)?  $default,){
final _that = this;
switch (_that) {
case _MessageRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roomId,  UserSummary sender,  int messageCount,  bool hasImage,  String? lastMessagePreview,  DateTime? lastMessageAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageRequest() when $default != null:
return $default(_that.roomId,_that.sender,_that.messageCount,_that.hasImage,_that.lastMessagePreview,_that.lastMessageAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roomId,  UserSummary sender,  int messageCount,  bool hasImage,  String? lastMessagePreview,  DateTime? lastMessageAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _MessageRequest():
return $default(_that.roomId,_that.sender,_that.messageCount,_that.hasImage,_that.lastMessagePreview,_that.lastMessageAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roomId,  UserSummary sender,  int messageCount,  bool hasImage,  String? lastMessagePreview,  DateTime? lastMessageAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _MessageRequest() when $default != null:
return $default(_that.roomId,_that.sender,_that.messageCount,_that.hasImage,_that.lastMessagePreview,_that.lastMessageAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _MessageRequest implements MessageRequest {
  const _MessageRequest({required this.roomId, required this.sender, this.messageCount = 0, this.hasImage = false, this.lastMessagePreview, this.lastMessageAt, required this.createdAt});
  

@override final  String roomId;
@override final  UserSummary sender;
@override@JsonKey() final  int messageCount;
@override@JsonKey() final  bool hasImage;
@override final  String? lastMessagePreview;
@override final  DateTime? lastMessageAt;
@override final  DateTime createdAt;

/// Create a copy of MessageRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageRequestCopyWith<_MessageRequest> get copyWith => __$MessageRequestCopyWithImpl<_MessageRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageRequest&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount)&&(identical(other.hasImage, hasImage) || other.hasImage == hasImage)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,roomId,sender,messageCount,hasImage,lastMessagePreview,lastMessageAt,createdAt);

@override
String toString() {
  return 'MessageRequest(roomId: $roomId, sender: $sender, messageCount: $messageCount, hasImage: $hasImage, lastMessagePreview: $lastMessagePreview, lastMessageAt: $lastMessageAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$MessageRequestCopyWith<$Res> implements $MessageRequestCopyWith<$Res> {
  factory _$MessageRequestCopyWith(_MessageRequest value, $Res Function(_MessageRequest) _then) = __$MessageRequestCopyWithImpl;
@override @useResult
$Res call({
 String roomId, UserSummary sender, int messageCount, bool hasImage, String? lastMessagePreview, DateTime? lastMessageAt, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class __$MessageRequestCopyWithImpl<$Res>
    implements _$MessageRequestCopyWith<$Res> {
  __$MessageRequestCopyWithImpl(this._self, this._then);

  final _MessageRequest _self;
  final $Res Function(_MessageRequest) _then;

/// Create a copy of MessageRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = null,Object? sender = null,Object? messageCount = null,Object? hasImage = null,Object? lastMessagePreview = freezed,Object? lastMessageAt = freezed,Object? createdAt = null,}) {
  return _then(_MessageRequest(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,messageCount: null == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int,hasImage: null == hasImage ? _self.hasImage : hasImage // ignore: cast_nullable_to_non_nullable
as bool,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of MessageRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}

/// @nodoc
mixin _$DmRequestState {

 bool get isRequest; DmRequestRole? get role; bool get declined; int get sent; int get maxMessages;
/// Create a copy of DmRequestState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DmRequestStateCopyWith<DmRequestState> get copyWith => _$DmRequestStateCopyWithImpl<DmRequestState>(this as DmRequestState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DmRequestState&&(identical(other.isRequest, isRequest) || other.isRequest == isRequest)&&(identical(other.role, role) || other.role == role)&&(identical(other.declined, declined) || other.declined == declined)&&(identical(other.sent, sent) || other.sent == sent)&&(identical(other.maxMessages, maxMessages) || other.maxMessages == maxMessages));
}


@override
int get hashCode => Object.hash(runtimeType,isRequest,role,declined,sent,maxMessages);

@override
String toString() {
  return 'DmRequestState(isRequest: $isRequest, role: $role, declined: $declined, sent: $sent, maxMessages: $maxMessages)';
}


}

/// @nodoc
abstract mixin class $DmRequestStateCopyWith<$Res>  {
  factory $DmRequestStateCopyWith(DmRequestState value, $Res Function(DmRequestState) _then) = _$DmRequestStateCopyWithImpl;
@useResult
$Res call({
 bool isRequest, DmRequestRole? role, bool declined, int sent, int maxMessages
});




}
/// @nodoc
class _$DmRequestStateCopyWithImpl<$Res>
    implements $DmRequestStateCopyWith<$Res> {
  _$DmRequestStateCopyWithImpl(this._self, this._then);

  final DmRequestState _self;
  final $Res Function(DmRequestState) _then;

/// Create a copy of DmRequestState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isRequest = null,Object? role = freezed,Object? declined = null,Object? sent = null,Object? maxMessages = null,}) {
  return _then(_self.copyWith(
isRequest: null == isRequest ? _self.isRequest : isRequest // ignore: cast_nullable_to_non_nullable
as bool,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as DmRequestRole?,declined: null == declined ? _self.declined : declined // ignore: cast_nullable_to_non_nullable
as bool,sent: null == sent ? _self.sent : sent // ignore: cast_nullable_to_non_nullable
as int,maxMessages: null == maxMessages ? _self.maxMessages : maxMessages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DmRequestState].
extension DmRequestStatePatterns on DmRequestState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DmRequestState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DmRequestState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DmRequestState value)  $default,){
final _that = this;
switch (_that) {
case _DmRequestState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DmRequestState value)?  $default,){
final _that = this;
switch (_that) {
case _DmRequestState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isRequest,  DmRequestRole? role,  bool declined,  int sent,  int maxMessages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DmRequestState() when $default != null:
return $default(_that.isRequest,_that.role,_that.declined,_that.sent,_that.maxMessages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isRequest,  DmRequestRole? role,  bool declined,  int sent,  int maxMessages)  $default,) {final _that = this;
switch (_that) {
case _DmRequestState():
return $default(_that.isRequest,_that.role,_that.declined,_that.sent,_that.maxMessages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isRequest,  DmRequestRole? role,  bool declined,  int sent,  int maxMessages)?  $default,) {final _that = this;
switch (_that) {
case _DmRequestState() when $default != null:
return $default(_that.isRequest,_that.role,_that.declined,_that.sent,_that.maxMessages);case _:
  return null;

}
}

}

/// @nodoc


class _DmRequestState extends DmRequestState {
  const _DmRequestState({this.isRequest = false, this.role, this.declined = false, this.sent = 0, this.maxMessages = defaultRequestMaxMessages}): super._();
  

@override@JsonKey() final  bool isRequest;
@override final  DmRequestRole? role;
@override@JsonKey() final  bool declined;
@override@JsonKey() final  int sent;
@override@JsonKey() final  int maxMessages;

/// Create a copy of DmRequestState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DmRequestStateCopyWith<_DmRequestState> get copyWith => __$DmRequestStateCopyWithImpl<_DmRequestState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DmRequestState&&(identical(other.isRequest, isRequest) || other.isRequest == isRequest)&&(identical(other.role, role) || other.role == role)&&(identical(other.declined, declined) || other.declined == declined)&&(identical(other.sent, sent) || other.sent == sent)&&(identical(other.maxMessages, maxMessages) || other.maxMessages == maxMessages));
}


@override
int get hashCode => Object.hash(runtimeType,isRequest,role,declined,sent,maxMessages);

@override
String toString() {
  return 'DmRequestState(isRequest: $isRequest, role: $role, declined: $declined, sent: $sent, maxMessages: $maxMessages)';
}


}

/// @nodoc
abstract mixin class _$DmRequestStateCopyWith<$Res> implements $DmRequestStateCopyWith<$Res> {
  factory _$DmRequestStateCopyWith(_DmRequestState value, $Res Function(_DmRequestState) _then) = __$DmRequestStateCopyWithImpl;
@override @useResult
$Res call({
 bool isRequest, DmRequestRole? role, bool declined, int sent, int maxMessages
});




}
/// @nodoc
class __$DmRequestStateCopyWithImpl<$Res>
    implements _$DmRequestStateCopyWith<$Res> {
  __$DmRequestStateCopyWithImpl(this._self, this._then);

  final _DmRequestState _self;
  final $Res Function(_DmRequestState) _then;

/// Create a copy of DmRequestState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isRequest = null,Object? role = freezed,Object? declined = null,Object? sent = null,Object? maxMessages = null,}) {
  return _then(_DmRequestState(
isRequest: null == isRequest ? _self.isRequest : isRequest // ignore: cast_nullable_to_non_nullable
as bool,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as DmRequestRole?,declined: null == declined ? _self.declined : declined // ignore: cast_nullable_to_non_nullable
as bool,sent: null == sent ? _self.sent : sent // ignore: cast_nullable_to_non_nullable
as int,maxMessages: null == maxMessages ? _self.maxMessages : maxMessages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$DmPolicySettings {

 DmPolicy get policy; int get requestMaxMessages;
/// Create a copy of DmPolicySettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DmPolicySettingsCopyWith<DmPolicySettings> get copyWith => _$DmPolicySettingsCopyWithImpl<DmPolicySettings>(this as DmPolicySettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DmPolicySettings&&(identical(other.policy, policy) || other.policy == policy)&&(identical(other.requestMaxMessages, requestMaxMessages) || other.requestMaxMessages == requestMaxMessages));
}


@override
int get hashCode => Object.hash(runtimeType,policy,requestMaxMessages);

@override
String toString() {
  return 'DmPolicySettings(policy: $policy, requestMaxMessages: $requestMaxMessages)';
}


}

/// @nodoc
abstract mixin class $DmPolicySettingsCopyWith<$Res>  {
  factory $DmPolicySettingsCopyWith(DmPolicySettings value, $Res Function(DmPolicySettings) _then) = _$DmPolicySettingsCopyWithImpl;
@useResult
$Res call({
 DmPolicy policy, int requestMaxMessages
});




}
/// @nodoc
class _$DmPolicySettingsCopyWithImpl<$Res>
    implements $DmPolicySettingsCopyWith<$Res> {
  _$DmPolicySettingsCopyWithImpl(this._self, this._then);

  final DmPolicySettings _self;
  final $Res Function(DmPolicySettings) _then;

/// Create a copy of DmPolicySettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? policy = null,Object? requestMaxMessages = null,}) {
  return _then(_self.copyWith(
policy: null == policy ? _self.policy : policy // ignore: cast_nullable_to_non_nullable
as DmPolicy,requestMaxMessages: null == requestMaxMessages ? _self.requestMaxMessages : requestMaxMessages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DmPolicySettings].
extension DmPolicySettingsPatterns on DmPolicySettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DmPolicySettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DmPolicySettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DmPolicySettings value)  $default,){
final _that = this;
switch (_that) {
case _DmPolicySettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DmPolicySettings value)?  $default,){
final _that = this;
switch (_that) {
case _DmPolicySettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DmPolicy policy,  int requestMaxMessages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DmPolicySettings() when $default != null:
return $default(_that.policy,_that.requestMaxMessages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DmPolicy policy,  int requestMaxMessages)  $default,) {final _that = this;
switch (_that) {
case _DmPolicySettings():
return $default(_that.policy,_that.requestMaxMessages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DmPolicy policy,  int requestMaxMessages)?  $default,) {final _that = this;
switch (_that) {
case _DmPolicySettings() when $default != null:
return $default(_that.policy,_that.requestMaxMessages);case _:
  return null;

}
}

}

/// @nodoc


class _DmPolicySettings implements DmPolicySettings {
  const _DmPolicySettings({this.policy = DmPolicy.everyone, this.requestMaxMessages = defaultRequestMaxMessages});
  

@override@JsonKey() final  DmPolicy policy;
@override@JsonKey() final  int requestMaxMessages;

/// Create a copy of DmPolicySettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DmPolicySettingsCopyWith<_DmPolicySettings> get copyWith => __$DmPolicySettingsCopyWithImpl<_DmPolicySettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DmPolicySettings&&(identical(other.policy, policy) || other.policy == policy)&&(identical(other.requestMaxMessages, requestMaxMessages) || other.requestMaxMessages == requestMaxMessages));
}


@override
int get hashCode => Object.hash(runtimeType,policy,requestMaxMessages);

@override
String toString() {
  return 'DmPolicySettings(policy: $policy, requestMaxMessages: $requestMaxMessages)';
}


}

/// @nodoc
abstract mixin class _$DmPolicySettingsCopyWith<$Res> implements $DmPolicySettingsCopyWith<$Res> {
  factory _$DmPolicySettingsCopyWith(_DmPolicySettings value, $Res Function(_DmPolicySettings) _then) = __$DmPolicySettingsCopyWithImpl;
@override @useResult
$Res call({
 DmPolicy policy, int requestMaxMessages
});




}
/// @nodoc
class __$DmPolicySettingsCopyWithImpl<$Res>
    implements _$DmPolicySettingsCopyWith<$Res> {
  __$DmPolicySettingsCopyWithImpl(this._self, this._then);

  final _DmPolicySettings _self;
  final $Res Function(_DmPolicySettings) _then;

/// Create a copy of DmPolicySettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? policy = null,Object? requestMaxMessages = null,}) {
  return _then(_DmPolicySettings(
policy: null == policy ? _self.policy : policy // ignore: cast_nullable_to_non_nullable
as DmPolicy,requestMaxMessages: null == requestMaxMessages ? _self.requestMaxMessages : requestMaxMessages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
