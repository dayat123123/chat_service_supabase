// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ticket_list_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TicketFilter {

 String? get topic; String? get priority; String? get flag;
/// Create a copy of TicketFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketFilterCopyWith<TicketFilter> get copyWith => _$TicketFilterCopyWithImpl<TicketFilter>(this as TicketFilter, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketFilter&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.flag, flag) || other.flag == flag));
}


@override
int get hashCode => Object.hash(runtimeType,topic,priority,flag);

@override
String toString() {
  return 'TicketFilter(topic: $topic, priority: $priority, flag: $flag)';
}


}

/// @nodoc
abstract mixin class $TicketFilterCopyWith<$Res>  {
  factory $TicketFilterCopyWith(TicketFilter value, $Res Function(TicketFilter) _then) = _$TicketFilterCopyWithImpl;
@useResult
$Res call({
 String? topic, String? priority, String? flag
});




}
/// @nodoc
class _$TicketFilterCopyWithImpl<$Res>
    implements $TicketFilterCopyWith<$Res> {
  _$TicketFilterCopyWithImpl(this._self, this._then);

  final TicketFilter _self;
  final $Res Function(TicketFilter) _then;

/// Create a copy of TicketFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? topic = freezed,Object? priority = freezed,Object? flag = freezed,}) {
  return _then(_self.copyWith(
topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,flag: freezed == flag ? _self.flag : flag // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketFilter].
extension TicketFilterPatterns on TicketFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketFilter value)  $default,){
final _that = this;
switch (_that) {
case _TicketFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketFilter value)?  $default,){
final _that = this;
switch (_that) {
case _TicketFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? topic,  String? priority,  String? flag)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketFilter() when $default != null:
return $default(_that.topic,_that.priority,_that.flag);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? topic,  String? priority,  String? flag)  $default,) {final _that = this;
switch (_that) {
case _TicketFilter():
return $default(_that.topic,_that.priority,_that.flag);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? topic,  String? priority,  String? flag)?  $default,) {final _that = this;
switch (_that) {
case _TicketFilter() when $default != null:
return $default(_that.topic,_that.priority,_that.flag);case _:
  return null;

}
}

}

/// @nodoc


class _TicketFilter extends TicketFilter {
  const _TicketFilter({this.topic, this.priority, this.flag}): super._();
  

@override final  String? topic;
@override final  String? priority;
@override final  String? flag;

/// Create a copy of TicketFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketFilterCopyWith<_TicketFilter> get copyWith => __$TicketFilterCopyWithImpl<_TicketFilter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketFilter&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.flag, flag) || other.flag == flag));
}


@override
int get hashCode => Object.hash(runtimeType,topic,priority,flag);

@override
String toString() {
  return 'TicketFilter(topic: $topic, priority: $priority, flag: $flag)';
}


}

/// @nodoc
abstract mixin class _$TicketFilterCopyWith<$Res> implements $TicketFilterCopyWith<$Res> {
  factory _$TicketFilterCopyWith(_TicketFilter value, $Res Function(_TicketFilter) _then) = __$TicketFilterCopyWithImpl;
@override @useResult
$Res call({
 String? topic, String? priority, String? flag
});




}
/// @nodoc
class __$TicketFilterCopyWithImpl<$Res>
    implements _$TicketFilterCopyWith<$Res> {
  __$TicketFilterCopyWithImpl(this._self, this._then);

  final _TicketFilter _self;
  final $Res Function(_TicketFilter) _then;

/// Create a copy of TicketFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? topic = freezed,Object? priority = freezed,Object? flag = freezed,}) {
  return _then(_TicketFilter(
topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,flag: freezed == flag ? _self.flag : flag // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$TicketListState {

 LoadStatus get status; TicketLists get lists; List<SupportTopic> get topics; TicketTab get tab; TicketFilter get filter; String get query; List<Ticket>? get results; bool get searching; Set<String> get claiming; String? get selectedId; Object? get error; Object? get actionError; int get actionErrorId;
/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketListStateCopyWith<TicketListState> get copyWith => _$TicketListStateCopyWithImpl<TicketListState>(this as TicketListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketListState&&(identical(other.status, status) || other.status == status)&&(identical(other.lists, lists) || other.lists == lists)&&const DeepCollectionEquality().equals(other.topics, topics)&&(identical(other.tab, tab) || other.tab == tab)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other.results, results)&&(identical(other.searching, searching) || other.searching == searching)&&const DeepCollectionEquality().equals(other.claiming, claiming)&&(identical(other.selectedId, selectedId) || other.selectedId == selectedId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,lists,const DeepCollectionEquality().hash(topics),tab,filter,query,const DeepCollectionEquality().hash(results),searching,const DeepCollectionEquality().hash(claiming),selectedId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'TicketListState(status: $status, lists: $lists, topics: $topics, tab: $tab, filter: $filter, query: $query, results: $results, searching: $searching, claiming: $claiming, selectedId: $selectedId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class $TicketListStateCopyWith<$Res>  {
  factory $TicketListStateCopyWith(TicketListState value, $Res Function(TicketListState) _then) = _$TicketListStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, TicketLists lists, List<SupportTopic> topics, TicketTab tab, TicketFilter filter, String query, List<Ticket>? results, bool searching, Set<String> claiming, String? selectedId, Object? error, Object? actionError, int actionErrorId
});


$TicketListsCopyWith<$Res> get lists;$TicketFilterCopyWith<$Res> get filter;

}
/// @nodoc
class _$TicketListStateCopyWithImpl<$Res>
    implements $TicketListStateCopyWith<$Res> {
  _$TicketListStateCopyWithImpl(this._self, this._then);

  final TicketListState _self;
  final $Res Function(TicketListState) _then;

/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? lists = null,Object? topics = null,Object? tab = null,Object? filter = null,Object? query = null,Object? results = freezed,Object? searching = null,Object? claiming = null,Object? selectedId = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,lists: null == lists ? _self.lists : lists // ignore: cast_nullable_to_non_nullable
as TicketLists,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<SupportTopic>,tab: null == tab ? _self.tab : tab // ignore: cast_nullable_to_non_nullable
as TicketTab,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as TicketFilter,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,results: freezed == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<Ticket>?,searching: null == searching ? _self.searching : searching // ignore: cast_nullable_to_non_nullable
as bool,claiming: null == claiming ? _self.claiming : claiming // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedId: freezed == selectedId ? _self.selectedId : selectedId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketListsCopyWith<$Res> get lists {
  
  return $TicketListsCopyWith<$Res>(_self.lists, (value) {
    return _then(_self.copyWith(lists: value));
  });
}/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketFilterCopyWith<$Res> get filter {
  
  return $TicketFilterCopyWith<$Res>(_self.filter, (value) {
    return _then(_self.copyWith(filter: value));
  });
}
}


/// Adds pattern-matching-related methods to [TicketListState].
extension TicketListStatePatterns on TicketListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketListState value)  $default,){
final _that = this;
switch (_that) {
case _TicketListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketListState value)?  $default,){
final _that = this;
switch (_that) {
case _TicketListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  TicketLists lists,  List<SupportTopic> topics,  TicketTab tab,  TicketFilter filter,  String query,  List<Ticket>? results,  bool searching,  Set<String> claiming,  String? selectedId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketListState() when $default != null:
return $default(_that.status,_that.lists,_that.topics,_that.tab,_that.filter,_that.query,_that.results,_that.searching,_that.claiming,_that.selectedId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  TicketLists lists,  List<SupportTopic> topics,  TicketTab tab,  TicketFilter filter,  String query,  List<Ticket>? results,  bool searching,  Set<String> claiming,  String? selectedId,  Object? error,  Object? actionError,  int actionErrorId)  $default,) {final _that = this;
switch (_that) {
case _TicketListState():
return $default(_that.status,_that.lists,_that.topics,_that.tab,_that.filter,_that.query,_that.results,_that.searching,_that.claiming,_that.selectedId,_that.error,_that.actionError,_that.actionErrorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  TicketLists lists,  List<SupportTopic> topics,  TicketTab tab,  TicketFilter filter,  String query,  List<Ticket>? results,  bool searching,  Set<String> claiming,  String? selectedId,  Object? error,  Object? actionError,  int actionErrorId)?  $default,) {final _that = this;
switch (_that) {
case _TicketListState() when $default != null:
return $default(_that.status,_that.lists,_that.topics,_that.tab,_that.filter,_that.query,_that.results,_that.searching,_that.claiming,_that.selectedId,_that.error,_that.actionError,_that.actionErrorId);case _:
  return null;

}
}

}

/// @nodoc


class _TicketListState extends TicketListState {
  const _TicketListState({this.status = LoadStatus.initial, this.lists = const TicketLists(), final  List<SupportTopic> topics = const <SupportTopic>[], this.tab = TicketTab.open, this.filter = const TicketFilter(), this.query = '', final  List<Ticket>? results, this.searching = false, final  Set<String> claiming = const <String>{}, this.selectedId, this.error, this.actionError, this.actionErrorId = 0}): _topics = topics,_results = results,_claiming = claiming,super._();
  

@override@JsonKey() final  LoadStatus status;
@override@JsonKey() final  TicketLists lists;
 final  List<SupportTopic> _topics;
@override@JsonKey() List<SupportTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

@override@JsonKey() final  TicketTab tab;
@override@JsonKey() final  TicketFilter filter;
@override@JsonKey() final  String query;
 final  List<Ticket>? _results;
@override List<Ticket>? get results {
  final value = _results;
  if (value == null) return null;
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool searching;
 final  Set<String> _claiming;
@override@JsonKey() Set<String> get claiming {
  if (_claiming is EqualUnmodifiableSetView) return _claiming;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_claiming);
}

@override final  String? selectedId;
@override final  Object? error;
@override final  Object? actionError;
@override@JsonKey() final  int actionErrorId;

/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketListStateCopyWith<_TicketListState> get copyWith => __$TicketListStateCopyWithImpl<_TicketListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketListState&&(identical(other.status, status) || other.status == status)&&(identical(other.lists, lists) || other.lists == lists)&&const DeepCollectionEquality().equals(other._topics, _topics)&&(identical(other.tab, tab) || other.tab == tab)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other._results, _results)&&(identical(other.searching, searching) || other.searching == searching)&&const DeepCollectionEquality().equals(other._claiming, _claiming)&&(identical(other.selectedId, selectedId) || other.selectedId == selectedId)&&const DeepCollectionEquality().equals(other.error, error)&&const DeepCollectionEquality().equals(other.actionError, actionError)&&(identical(other.actionErrorId, actionErrorId) || other.actionErrorId == actionErrorId));
}


@override
int get hashCode => Object.hash(runtimeType,status,lists,const DeepCollectionEquality().hash(_topics),tab,filter,query,const DeepCollectionEquality().hash(_results),searching,const DeepCollectionEquality().hash(_claiming),selectedId,const DeepCollectionEquality().hash(error),const DeepCollectionEquality().hash(actionError),actionErrorId);

@override
String toString() {
  return 'TicketListState(status: $status, lists: $lists, topics: $topics, tab: $tab, filter: $filter, query: $query, results: $results, searching: $searching, claiming: $claiming, selectedId: $selectedId, error: $error, actionError: $actionError, actionErrorId: $actionErrorId)';
}


}

/// @nodoc
abstract mixin class _$TicketListStateCopyWith<$Res> implements $TicketListStateCopyWith<$Res> {
  factory _$TicketListStateCopyWith(_TicketListState value, $Res Function(_TicketListState) _then) = __$TicketListStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, TicketLists lists, List<SupportTopic> topics, TicketTab tab, TicketFilter filter, String query, List<Ticket>? results, bool searching, Set<String> claiming, String? selectedId, Object? error, Object? actionError, int actionErrorId
});


@override $TicketListsCopyWith<$Res> get lists;@override $TicketFilterCopyWith<$Res> get filter;

}
/// @nodoc
class __$TicketListStateCopyWithImpl<$Res>
    implements _$TicketListStateCopyWith<$Res> {
  __$TicketListStateCopyWithImpl(this._self, this._then);

  final _TicketListState _self;
  final $Res Function(_TicketListState) _then;

/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? lists = null,Object? topics = null,Object? tab = null,Object? filter = null,Object? query = null,Object? results = freezed,Object? searching = null,Object? claiming = null,Object? selectedId = freezed,Object? error = freezed,Object? actionError = freezed,Object? actionErrorId = null,}) {
  return _then(_TicketListState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,lists: null == lists ? _self.lists : lists // ignore: cast_nullable_to_non_nullable
as TicketLists,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<SupportTopic>,tab: null == tab ? _self.tab : tab // ignore: cast_nullable_to_non_nullable
as TicketTab,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as TicketFilter,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,results: freezed == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<Ticket>?,searching: null == searching ? _self.searching : searching // ignore: cast_nullable_to_non_nullable
as bool,claiming: null == claiming ? _self._claiming : claiming // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedId: freezed == selectedId ? _self.selectedId : selectedId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error ,actionError: freezed == actionError ? _self.actionError : actionError ,actionErrorId: null == actionErrorId ? _self.actionErrorId : actionErrorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketListsCopyWith<$Res> get lists {
  
  return $TicketListsCopyWith<$Res>(_self.lists, (value) {
    return _then(_self.copyWith(lists: value));
  });
}/// Create a copy of TicketListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TicketFilterCopyWith<$Res> get filter {
  
  return $TicketFilterCopyWith<$Res>(_self.filter, (value) {
    return _then(_self.copyWith(filter: value));
  });
}
}

// dart format on
