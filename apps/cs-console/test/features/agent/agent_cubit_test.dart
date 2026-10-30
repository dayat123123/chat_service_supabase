import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/agent/presentation/cubit/agent_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';

class _MockAgents extends Mock implements AgentRepository {}

void main() {
  late _MockAgents agents;
  late int revoked;

  setUp(() {
    agents = _MockAgents();
    revoked = 0;
  });

  AgentCubit cubitFor(String status) =>
      AgentCubit(agents, AgentProfile.fromJson(agentJson(status: status)), onRevoked: () => revoked++);

  test('CS online yang akunnya dinonaktifkan admin langsung dikeluarkan', () async {
    when(() => agents.heartbeat()).thenThrow(const ConsoleError('agent_required', status: 403));
    final cubit = cubitFor('online');

    await cubit.beat();

    expect(revoked, 1);
    await cubit.close();
  });

  test('CS offline tetap dicek supaya pencabutan akun terdeteksi', () async {
    when(() => agents.me()).thenThrow(const ConsoleError('agent_required', status: 403));
    final cubit = cubitFor('offline');

    await cubit.beat();

    expect(revoked, 1);
    verifyNever(() => agents.heartbeat());
    await cubit.close();
  });

  test('gangguan jaringan tidak mengeluarkan CS dan jumlah tiket aktif tetap diperbarui', () async {
    when(() => agents.heartbeat()).thenThrow(const ConsoleError('network'));
    final cubit = cubitFor('online');

    await cubit.beat();
    expect(revoked, 0);

    when(() => agents.heartbeat()).thenAnswer((_) async => 3);
    await cubit.beat();
    expect(cubit.state.activeTickets, 3);
    await cubit.close();
  });
}
