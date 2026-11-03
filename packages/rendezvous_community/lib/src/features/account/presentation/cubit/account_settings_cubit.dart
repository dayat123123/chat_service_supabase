import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/app/community_account_scope.dart';
import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'account_settings_cubit.freezed.dart';

enum AccountAction { export, delete }

@freezed
abstract class AccountSettingsState with _$AccountSettingsState {
  const factory AccountSettingsState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<LegalDocument>[]) List<LegalDocument> documents,
    Object? error,
    @Default(false) bool exporting,
    @Default(false) bool deleting,
    @Default(false) bool deleted,
    AccountAction? failedAction,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _AccountSettingsState;
}

class AccountSettingsCubit extends Cubit<AccountSettingsState> {
  AccountSettingsCubit(this._account) : super(const AccountSettingsState());

  final CommunityAccountDependencies _account;

  Future<void> load({bool refresh = false}) async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final documents = await _account.consent.documents(refresh: refresh);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, documents: documents));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<CommunityDataExport?> exportData() async {
    if (state.exporting || state.deleting) return null;
    emit(state.copyWith(exporting: true));
    try {
      return await _account.exportMyData();
    } catch (e) {
      _fail(AccountAction.export, e);
      return null;
    } finally {
      if (!isClosed) emit(state.copyWith(exporting: false));
    }
  }

  void exportFailed(Object error) => _fail(AccountAction.export, error);

  Future<bool> deleteAccount() async {
    if (state.deleting) return false;
    emit(state.copyWith(deleting: true, failedAction: null, actionError: null));
    try {
      await _account.deleteMyAccount();
      if (!isClosed) emit(state.copyWith(deleting: false, deleted: true));
      return true;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(deleting: false));
      _fail(AccountAction.delete, e);
      return false;
    }
  }

  void _fail(AccountAction action, Object error) {
    if (isClosed) return;
    emit(state.copyWith(failedAction: action, actionError: error, actionErrorId: state.actionErrorId + 1));
  }
}
