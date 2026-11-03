import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/community_consent.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'consent_cubit.freezed.dart';

@freezed
abstract class ConsentState with _$ConsentState {
  const factory ConsentState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<LegalDocument>[]) List<LegalDocument> documents,
    @Default(false) bool agreed,
    @Default(false) bool submitting,
    @Default(false) bool accepted,
    Object? error,
    Object? actionError,
  }) = _ConsentState;

  const ConsentState._();

  bool get canAccept => agreed && !submitting && documents.isNotEmpty;
}

class ConsentCubit extends Cubit<ConsentState> {
  ConsentCubit(this._consent) : super(const ConsentState());

  final CommunityConsent _consent;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final pending = await _consent.pending(refresh: true);
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.ready, documents: pending, accepted: pending.isEmpty));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  void setAgreed(bool agreed) => emit(state.copyWith(agreed: agreed, actionError: null));

  Future<void> accept() async {
    if (!state.canAccept) return;
    emit(state.copyWith(submitting: true, actionError: null));
    try {
      await _consent.accept([for (final document in state.documents) document.id]);
      if (!isClosed) emit(state.copyWith(submitting: false, accepted: true));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(submitting: false, actionError: e));
    }
  }
}
