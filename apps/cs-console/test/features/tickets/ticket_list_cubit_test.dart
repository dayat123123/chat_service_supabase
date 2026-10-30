import 'dart:async';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/data/ticket_repository.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:cs_console/src/features/tickets/presentation/cubit/ticket_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';

class _MockTickets extends Mock implements TicketRepository {}

void main() {
  late _MockTickets tickets;
  late StreamController<QueueEvent> events;
  late TicketListCubit cubit;

  TicketLists lists(List<Map<String, dynamic>> open, {List<Map<String, dynamic>> mine = const []}) =>
      TicketLists.fromJson({'open': open, 'mine': mine});

  setUp(() {
    tickets = _MockTickets();
    events = StreamController<QueueEvent>.broadcast();
    when(() => tickets.topics()).thenAnswer((_) async => const [SupportTopic(code: 'orders', name: 'Order & Transaksi')]);
    when(() => tickets.lists()).thenAnswer((_) async => lists([
      ticketJson(id: 'late-p3', waitingSince: '2026-10-30T01:00:00+00:00'),
      ticketJson(id: 'new-p1', priority: 'P1', waitingSince: '2026-10-30T03:30:00+00:00', flags: ['fraud']),
      ticketJson(id: 'early-p1', priority: 'P1', waitingSince: '2026-10-30T02:00:00+00:00'),
    ]));
    cubit = TicketListCubit(tickets: tickets, events: events.stream, pollEvery: const Duration(hours: 1));
  });

  tearDown(() async {
    await cubit.close();
    await events.close();
  });

  test('tiket terbuka diurutkan prioritas lalu menunggu paling lama, dan bisa difilter', () async {
    await cubit.start();

    expect([for (final t in cubit.state.visible) t.id], ['early-p1', 'new-p1', 'late-p3']);
    expect(cubit.state.topicName('orders'), 'Order & Transaksi');

    cubit.setFilter(const TicketFilter(flag: 'fraud'));
    expect([for (final t in cubit.state.visible) t.id], ['new-p1']);
  });

  test('event realtime memuat ulang daftar, misalnya tiket yang diambil CS lain hilang', () async {
    await cubit.start();
    when(() => tickets.lists()).thenAnswer((_) async => lists([ticketJson(id: 'late-p3')]));

    events.add(const TicketChanged(event: 'ticket_claimed', ticketId: 'early-p1'));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect([for (final t in cubit.state.visible) t.id], ['late-p3']);
  });

  test('mengambil tiket: berhasil memilih tiket dan pindah ke tab Saya', () async {
    await cubit.start();
    when(() => tickets.claim('early-p1'))
        .thenAnswer((_) async => Ticket.fromJson(ticketJson(id: 'early-p1', status: 'claimed', ownerId: 'a-1')));

    final claimed = await cubit.claim(cubit.state.visible.first);

    expect(claimed?.id, 'early-p1');
    expect(cubit.state.selectedId, 'early-p1');
    expect(cubit.state.tab, TicketTab.mine);
    expect(cubit.state.claiming, isEmpty);
  });

  test('kalah rebutan: pesan "sudah diambil" diteruskan ke UI dan daftar dimuat ulang', () async {
    await cubit.start();
    when(() => tickets.claim(any())).thenThrow(
      const ConsoleError('ticket_taken', message: 'Tiket sudah diambil oleh Bima', status: 409),
    );

    final claimed = await cubit.claim(cubit.state.visible.first);

    expect(claimed, isNull);
    expect((cubit.state.actionError! as ConsoleError).message, 'Tiket sudah diambil oleh Bima');
    expect(cubit.state.claiming, isEmpty);
    verify(() => tickets.lists()).called(2);
  });
}
