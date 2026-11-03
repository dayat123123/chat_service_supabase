import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'dm_policy_cubit.freezed.dart';

@freezed
abstract class DmPolicyState with _$DmPolicyState {
  const factory DmPolicyState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(DmPolicySettings()) DmPolicySettings settings,
    @Default(false) bool saving,
    @Default(0) int savedId,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _DmPolicyState;
}

class DmPolicyCubit extends Cubit<DmPolicyState> {
  DmPolicyCubit(this._requests) : super(const DmPolicyState());

  final MessageRequestRepository _requests;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final settings = await _requests.dmPolicy();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, settings: settings));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> setPolicy(DmPolicy policy) async {
    final before = state.settings;
    if (before.policy == policy || state.saving) return;
    emit(state.copyWith(saving: true, settings: before.copyWith(policy: policy)));
    try {
      final saved = await _requests.setDmPolicy(policy);
      if (!isClosed) emit(state.copyWith(saving: false, settings: saved, savedId: state.savedId + 1));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, settings: before, actionError: e, actionErrorId: state.actionErrorId + 1));
      }
    }
  }
}
