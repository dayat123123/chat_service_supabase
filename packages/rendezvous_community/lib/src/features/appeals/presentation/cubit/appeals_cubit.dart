import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/domain/repositories/appeal_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'appeals_cubit.freezed.dart';

@freezed
abstract class AppealsState with _$AppealsState {
  const factory AppealsState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<Appeal>[]) List<Appeal> appeals,
    @Default(<Sanction>[]) List<Sanction> sanctions,
    @Default(<ModeratedContent>[]) List<ModeratedContent> moderated,
    Object? error,
  }) = _AppealsState;

  const AppealsState._();

  Appeal? appealFor(AppealTargetType type, String targetId) =>
      appeals.where((a) => a.targetType == type && a.targetId == targetId).firstOrNull;
}

class AppealsCubit extends Cubit<AppealsState> {
  AppealsCubit(this._appeals) : super(const AppealsState());

  final AppealRepository _appeals;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final appeals = await _appeals.myAppeals();
      final sanctions = await _appeals.mySanctions();
      final moderated = await _moderated();
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.ready, appeals: appeals, sanctions: sanctions, moderated: moderated));
      }
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<List<ModeratedContent>> _moderated() async {
    try {
      return await _appeals.myModeratedContent();
    } catch (_) {
      return const [];
    }
  }
}
