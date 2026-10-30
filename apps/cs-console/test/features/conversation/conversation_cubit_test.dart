import 'dart:async';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/conversation/presentation/cubit/conversation_cubit.dart';
import 'package:cs_console/src/features/tickets/data/queue_events.dart';
import 'package:cs_console/src/features/tickets/data/ticket_repository.dart';
import 'package:cs_console/src/features/tickets/domain/ticket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/olt_social.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fixtures.dart';

class _MockTickets extends Mock implements TicketRepository {}

void main() {
  late _MockTickets tickets;
  late StreamController<QueueEvent> events;
  late OltSupportStaff staff;
  final me = AgentProfile.fromJson(agentJson(status: 'online'));

  setUpAll(() => registerFallbackValue(Ticket.fromJson(ticketJson())));

  setUp(() {
    tickets = _MockTickets();
    events = StreamController<QueueEvent>.broadcast();
    staff = OltSupportStaff(
      client: SupabaseClient('http://localhost:8000', 'anon'),
      supabaseUrl: 'http://localhost:8000',
      anonKey: 'anon',
      me: const UserSummary(id: 'a-1', username: 'cs_cs0045', displayName: 'Nadia'),
    );
    when(() => tickets.quickReplies(any())).thenAnswer((_) async => const []);
  });

  tearDown(() => events.close());

  ConversationCubit cubit() =>
      ConversationCubit(tickets: tickets, staff: staff, agent: () => me, events: events.stream, ticketId: 't-1');

  test('pemilik tiket aktif bisa membalas; pratinjau tiket open hanya-baca', () async {
    when(() => tickets.detail('t-1')).thenAnswer((_) async => Ticket.fromJson(ticketJson()));
    final preview = cubit();
    await preview.load();
    expect(preview.state.status, LoadStatus.ready);
    expect(preview.state.canReply(me.id), isFalse);
    await preview.close();

    when(() => tickets.detail('t-1'))
        .thenAnswer((_) async => Ticket.fromJson(ticketJson(status: 'claimed', ownerId: me.id)));
    final owned = cubit();
    await owned.load();
    expect(owned.state.canReply(me.id), isTrue);
    expect(owned.state.isOwner(me.id), isTrue);
    await owned.close();
  });

  test('versi tiket kedaluwarsa: data dimuat ulang dan CS diberi tahu, bukan error', () async {
    var version = 3;
    when(() => tickets.detail('t-1')).thenAnswer(
      (_) async => Ticket.fromJson(ticketJson(status: 'claimed', ownerId: me.id, version: version)),
    );
    when(() => tickets.resolve(any(), outcome: any(named: 'outcome'), summary: any(named: 'summary'), tags: any(named: 'tags')))
        .thenThrow(const ConsoleError('stale_ticket', status: 409));
    final conversation = cubit();
    await conversation.load();
    version = 4;

    await conversation.resolve(outcome: 'answered', summary: 'Sudah dijelaskan');

    expect(conversation.state.notice, ConversationNotice.stale);
    expect(conversation.state.ticket?.version, 4);
    expect(conversation.state.actionError, isNull);
    expect(conversation.state.busy, isFalse);
    await conversation.close();
  });

  test('pesan nasabah untuk tiket ini memuat ulang detail tiket', () async {
    when(() => tickets.detail('t-1'))
        .thenAnswer((_) async => Ticket.fromJson(ticketJson(status: 'claimed', ownerId: me.id)));
    final conversation = cubit();
    await conversation.load();

    events.add(const CustomerMessaged(ticketId: 't-1', status: 'claimed'));
    events.add(const CustomerMessaged(ticketId: 't-other', status: 'claimed'));
    await Future<void>.delayed(const Duration(milliseconds: 450));

    verify(() => tickets.detail('t-1')).called(2);
    await conversation.close();
  });

  test('balasan cepat mengganti variabel nama, nomor tiket, dan nama CS', () {
    const reply = QuickReply(id: 'q', shortcut: 'salam', title: 'Salam', body: 'Halo {nama}, tiket {nomor_tiket} ditangani {nama_cs}.');
    expect(
      reply.fill(customer: 'Andi', ticketNumber: 'CS-20261030-0001', agent: 'Nadia'),
      'Halo Andi, tiket CS-20261030-0001 ditangani Nadia.',
    );
  });
}
