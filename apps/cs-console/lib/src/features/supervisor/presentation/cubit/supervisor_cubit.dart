import 'dart:async';

import 'package:cs_console/src/features/supervisor/data/supervisor_repository.dart';
import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

part 'supervisor_cubit.freezed.dart';

@freezed
abstract class SupervisorState with _$SupervisorState {
  const factory SupervisorState({
    @Default(LoadStatus.initial) LoadStatus status,
    SupervisorOverview? overview,
    Object? error,
  }) = _SupervisorState;
}

class SupervisorCubit extends Cubit<SupervisorState> {
  SupervisorCubit({required this._supervisor, required this._events, this.pollEvery = const Duration(seconds: 30)})
    : super(const SupervisorState());

  final SupervisorRepository _supervisor;
  final Stream<QueueEvent> _events;
  final Duration pollEvery;
  StreamSubscription<QueueEvent>? _subscription;
  Timer? _poll;
  Timer? _debounce;

  Future<void> start() async {
    emit(state.copyWith(status: LoadStatus.loading));
    _subscription = _events.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), refresh);
    });
    _poll = Timer.periodic(pollEvery, (_) => refresh());
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final overview = await _supervisor.overview();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, overview: overview, error: null));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: state.overview == null ? LoadStatus.failure : state.status, error: e));
    }
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    _debounce?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
