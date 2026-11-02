import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';

part 'poll_model.freezed.dart';
part 'poll_model.g.dart';

@freezed
abstract class PollOptionModel with _$PollOptionModel {
  const factory PollOptionModel({required String id, required String label, int? votes}) = _PollOptionModel;

  const PollOptionModel._();

  factory PollOptionModel.fromJson(Map<String, dynamic> json) => _$PollOptionModelFromJson(json);

  PollOption toEntity() => PollOption(id: id, label: label, votes: votes);
}

@freezed
abstract class PollModel with _$PollModel {
  const factory PollModel({
    required DateTime endsAt,
    @Default(false) bool closed,
    @Default(0) int totalVotes,
    String? myOptionId,
    @Default(false) bool resultsVisible,
    @Default(<PollOptionModel>[]) List<PollOptionModel> options,
  }) = _PollModel;

  const PollModel._();

  factory PollModel.fromJson(Map<String, dynamic> json) => _$PollModelFromJson(json);

  Poll toEntity() => Poll(
    endsAt: endsAt,
    closed: closed,
    totalVotes: totalVotes,
    myOptionId: myOptionId,
    resultsVisible: resultsVisible,
    options: [for (final o in options) o.toEntity()],
  );
}
