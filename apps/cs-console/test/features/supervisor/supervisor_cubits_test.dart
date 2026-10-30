import 'dart:async';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/supervisor/data/supervisor_repository.dart';
import 'package:cs_console/src/features/supervisor/domain/supervisor_models.dart';
import 'package:cs_console/src/features/supervisor/presentation/cubit/report_cubit.dart';
import 'package:cs_console/src/features/supervisor/presentation/cubit/supervisor_cubit.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/olt_social.dart' show LoadStatus;

import '../../support/fixtures.dart';

class _MockSupervisor extends Mock implements SupervisorRepository {}

Map<String, dynamic> overviewJson({int open = 2}) => {
  'generated_at': '2026-10-30T10:00:00+00:00',
  'thresholds': {'unclaimed_minutes': 10, 'p1_unclaimed_minutes': 2},
  'open_count': open,
  'oldest_open_at': '2026-10-30T09:40:00+00:00',
  'active_count': 3,
  'resolved_today': 7,
  'overdue': [ticketJson(id: 't-1', priority: 'P1')],
  'flagged_open': [ticketJson(id: 't-1', priority: 'P1', flags: ['fraud'])],
  'offline_owned': [ticketJson(id: 't-2', status: 'claimed', ownerId: 'a-1')],
  'agents': [
    {
      'id': 'a-1',
      'display_name': 'Nadia',
      'agent_code': 'CS-0045',
      'roles': ['cs_agent'],
      'status': 'break',
      'connected': false,
      'active_tickets': 2,
      'max_active_tickets': 5,
      'resolved_today': 4,
      'status_changed_at': '2026-10-30T09:00:00+00:00',
    },
    {'id': 'a-2', 'display_name': 'Bima', 'status': 'online', 'connected': true},
  ],
};

void main() {
  late _MockSupervisor repo;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repo = _MockSupervisor());

  group('SupervisorCubit', () {
    test('ringkasan server dibaca lengkap dan dihitung untuk badge', () async {
      when(() => repo.overview()).thenAnswer((_) async => SupervisorOverview.fromJson(overviewJson()));
      final cubit = SupervisorCubit(supervisor: repo, events: const Stream.empty(), pollEvery: const Duration(hours: 1));

      await cubit.start();

      final overview = cubit.state.overview!;
      expect(cubit.state.status, LoadStatus.ready);
      expect(overview.thresholds.p1UnclaimedMinutes, 2);
      expect(overview.attentionCount, 2);
      expect(overview.onlineCount, 1);
      expect(overview.agents.first.status, AgentStatus.onBreak);
      expect(overview.offlineOwned.single.owner?.displayName, 'Nadia');
      await cubit.close();
    });

    test('event antrean memicu muat ulang, gagal muat ulang tetap menyimpan data terakhir', () async {
      final events = StreamController<QueueEvent>.broadcast();
      var open = 0;
      when(() => repo.overview()).thenAnswer((_) async => SupervisorOverview.fromJson(overviewJson(open: ++open)));
      final cubit = SupervisorCubit(supervisor: repo, events: events.stream, pollEvery: const Duration(hours: 1));
      await cubit.start();

      events.add(const TicketChanged(event: 'ticket_opened', ticketId: 't-9'));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.state.overview!.openCount, 2);

      when(() => repo.overview()).thenThrow(const ConsoleError('network'));
      await cubit.refresh();
      expect(cubit.state.overview!.openCount, 2);
      expect(cubit.state.error, isA<ConsoleError>());
      await cubit.close();
      await events.close();
    });
  });

  group('ReportCubit', () {
    final today = DateTime(2026, 10, 30);

    test('default 7 hari terakhir, preset dan rentang pilihan memuat ulang laporan', () async {
      when(() => repo.report(any(), any())).thenAnswer(
        (call) async => ReportSummary(from: call.positionalArguments[0] as DateTime, to: call.positionalArguments[1] as DateTime),
      );
      final cubit = ReportCubit(repo, today: () => today);
      expect(cubit.state.range, DateTimeRange(start: DateTime(2026, 10, 24), end: today));

      await cubit.reload();
      expect(cubit.state.status, LoadStatus.ready);
      verify(() => repo.report(DateTime(2026, 10, 24), today)).called(1);

      await cubit.usePreset(ReportPreset.month);
      verify(() => repo.report(DateTime(2026, 10, 1), today)).called(1);

      final custom = DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));
      await cubit.useRange(custom);
      expect(cubit.state.preset, ReportPreset.custom);
      expect(cubit.state.report?.from, DateTime(2026, 9, 1));
      await cubit.close();
    });

    test('gagal memuat laporan menampilkan error', () async {
      when(() => repo.report(any(), any())).thenThrow(const ConsoleError('invalid_range', status: 400));
      final cubit = ReportCubit(repo, today: () => today);

      await cubit.usePreset(ReportPreset.today);

      expect(cubit.state.status, LoadStatus.failure);
      expect((cubit.state.error! as ConsoleError).code, 'invalid_range');
      await cubit.close();
    });
  });
}
