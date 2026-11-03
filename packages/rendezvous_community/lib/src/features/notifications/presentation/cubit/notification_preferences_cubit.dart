import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_preferences.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'notification_preferences_cubit.freezed.dart';

@freezed
abstract class NotificationPreferencesState with _$NotificationPreferencesState {
  const factory NotificationPreferencesState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(NotificationPreferences()) NotificationPreferences preferences,
    @Default(false) bool saving,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _NotificationPreferencesState;
}

class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit(this._repository) : super(const NotificationPreferencesState());

  final NotificationPreferencesRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final preferences = await _repository.get();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, preferences: preferences));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> setChannel(String type, {bool? inApp, bool? push}) async {
    final before = state.preferences;
    final current = before.of(type);
    if (current == null || (current.inAppLocked && inApp != null && push == null)) return;
    if (current.inAppLocked) inApp = null;
    final next = current.copyWith(
      inApp: current.supportsInApp ? (inApp ?? current.inApp) : null,
      push: push ?? current.push,
    );
    emit(
      state.copyWith(
        saving: true,
        preferences: before.copyWith(types: [for (final t in before.types) t.type == type ? next : t]),
      ),
    );
    await _save(
      before,
      () => _repository.update(
        types: [NotificationPreferenceChange(type: type, inApp: current.supportsInApp ? inApp : null, push: push)],
      ),
    );
  }

  Future<void> setQuietHours(QuietHours quietHours) async {
    final before = state.preferences;
    emit(state.copyWith(saving: true, preferences: before.copyWith(quietHours: quietHours)));
    await _save(before, () => _repository.update(quietHours: quietHours));
  }

  Future<void> _save(NotificationPreferences before, Future<NotificationPreferences> Function() call) async {
    try {
      final saved = await call();
      if (!isClosed) emit(state.copyWith(saving: false, preferences: saved));
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(saving: false, preferences: before, actionError: e, actionErrorId: state.actionErrorId + 1),
        );
      }
    }
  }
}
