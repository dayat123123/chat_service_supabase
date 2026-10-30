import 'dart:async';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AgentCubit extends Cubit<AgentProfile> {
  AgentCubit(this._agents, super.initial, {this.heartbeatEvery = const Duration(seconds: 20), this.onRevoked});

  final AgentRepository _agents;
  final Duration heartbeatEvery;
  final void Function()? onRevoked;
  Timer? _heartbeat;

  void start() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatEvery, (_) => beat());
  }

  Future<void> beat() async {
    try {
      if (state.status == AgentStatus.offline) {
        await _agents.me();
        return;
      }
      final active = await _agents.heartbeat();
      if (!isClosed && active != state.activeTickets) emit(state.copyWith(activeTickets: active));
    } catch (e) {
      if (!isClosed && ConsoleError.from(e).code == 'agent_required') onRevoked?.call();
    }
  }

  Future<void> setStatus(AgentStatus status) async {
    final profile = await _agents.setStatus(status);
    if (!isClosed) emit(profile);
  }

  Future<void> refresh() async {
    try {
      final profile = await _agents.me();
      if (!isClosed) emit(profile);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _heartbeat?.cancel();
    return super.close();
  }
}
