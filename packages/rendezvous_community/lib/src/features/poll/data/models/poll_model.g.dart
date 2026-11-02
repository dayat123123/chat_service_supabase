// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poll_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PollOptionModel _$PollOptionModelFromJson(Map<String, dynamic> json) =>
    _PollOptionModel(id: json['id'] as String, label: json['label'] as String, votes: (json['votes'] as num?)?.toInt());

Map<String, dynamic> _$PollOptionModelToJson(_PollOptionModel instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'votes': instance.votes,
};

_PollModel _$PollModelFromJson(Map<String, dynamic> json) => _PollModel(
  endsAt: DateTime.parse(json['ends_at'] as String),
  closed: json['closed'] as bool? ?? false,
  totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
  myOptionId: json['my_option_id'] as String?,
  resultsVisible: json['results_visible'] as bool? ?? false,
  options:
      (json['options'] as List<dynamic>?)?.map((e) => PollOptionModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const <PollOptionModel>[],
);

Map<String, dynamic> _$PollModelToJson(_PollModel instance) => <String, dynamic>{
  'ends_at': instance.endsAt.toIso8601String(),
  'closed': instance.closed,
  'total_votes': instance.totalVotes,
  'my_option_id': instance.myOptionId,
  'results_visible': instance.resultsVisible,
  'options': instance.options.map((e) => e.toJson()).toList(),
};
