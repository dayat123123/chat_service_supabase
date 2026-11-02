import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/features/poll/domain/repositories/poll_repository.dart';

part 'poll_cubit.freezed.dart';

@freezed
abstract class PollState with _$PollState {
  const factory PollState({required Poll poll, String? pendingOptionId, Object? error, @Default(0) int errorId}) =
      _PollState;
}

class PollCubit extends Cubit<PollState> {
  PollCubit({required this._polls, required this.postId, required Poll poll, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(PollState(poll: poll));

  final PollRepository _polls;
  final String postId;
  final DateTime Function() _clock;

  bool get canVote => !state.poll.hasVoted && !state.poll.isClosedAt(_clock()) && state.pendingOptionId == null;

  void sync(Poll poll) {
    if (state.pendingOptionId == null && poll != state.poll) emit(state.copyWith(poll: poll));
  }

  Future<void> vote(PollOption option) async {
    if (!canVote) return;
    emit(state.copyWith(pendingOptionId: option.id));
    try {
      final poll = await _polls.vote(postId, option.id);
      if (!isClosed) emit(state.copyWith(poll: poll, pendingOptionId: null));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(pendingOptionId: null, error: e, errorId: state.errorId + 1));
    }
  }
}
