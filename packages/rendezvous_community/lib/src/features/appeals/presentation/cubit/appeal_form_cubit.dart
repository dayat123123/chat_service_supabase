import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/domain/repositories/appeal_repository.dart';

part 'appeal_form_cubit.freezed.dart';

@freezed
abstract class AppealFormState with _$AppealFormState {
  const factory AppealFormState({
    @Default(false) bool submitting,
    Appeal? created,
    Object? error,
    @Default(0) int errorId,
  }) = _AppealFormState;
}

class AppealFormCubit extends Cubit<AppealFormState> {
  AppealFormCubit(this._appeals, {required this.targetType, required this.targetId}) : super(const AppealFormState());

  final AppealRepository _appeals;
  final AppealTargetType targetType;
  final String targetId;

  bool isValid(String reason) {
    final length = reason.trim().length;
    return length >= minAppealReasonLength && length <= maxAppealReasonLength;
  }

  Future<Appeal?> submit(String reason) async {
    if (state.submitting || !isValid(reason)) return null;
    emit(state.copyWith(submitting: true));
    try {
      final appeal = await _appeals.createAppeal(targetType, targetId, reason);
      if (!isClosed) emit(state.copyWith(submitting: false, created: appeal));
      return appeal;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(submitting: false, error: e, errorId: state.errorId + 1));
      return null;
    }
  }
}
