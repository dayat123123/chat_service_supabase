import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

part 'admin_list_cubit.freezed.dart';

@freezed
abstract class AdminListState<T> with _$AdminListState<T> {
  const factory AdminListState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default([]) List<T> items,
    @Default(false) bool saving,
    Object? error,
  }) = _AdminListState<T>;
}

class AdminListCubit<T> extends Cubit<AdminListState<T>> {
  AdminListCubit(this._load) : super(AdminListState<T>());

  final Future<List<T>> Function() _load;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final items = await _load();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, items: items));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> save(Future<List<T>> Function(List<T> current) action) async {
    emit(state.copyWith(saving: true));
    try {
      final items = await action(state.items);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, items: items, saving: false));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(saving: false));
      rethrow;
    }
  }
}
