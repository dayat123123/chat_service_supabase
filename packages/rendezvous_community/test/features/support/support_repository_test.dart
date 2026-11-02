import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/support/data/repositories/support_repository_impl.dart';

import '../../support/mock_api.dart';

class _MockNotifications extends Mock implements NotificationRepository {}

Map<String, dynamic> ticketView({String status = 'claimed', bool canRate = false}) => {
  'id': 't-1',
  'ticket_number': 'CS-20261030-0001',
  'room_id': 'r-cs',
  'topic': 'orders',
  'topic_name': 'Order & Transaksi',
  'status': status,
  'queue_ahead': status == 'open' ? 2 : null,
  'agent': status == 'claimed' ? {'display_name': 'Nadia', 'agent_code': 'CS-0045'} : null,
  'complaint': null,
  'created_at': '2026-10-30T03:00:00+00:00',
  'resolved_at': null,
  'closed_at': null,
  'reopen_until': null,
  'rating': null,
  'can_rate': canRate,
};

AppNotification notification(String id, {bool support = true, bool read = false}) => AppNotification(
  id: id,
  type: NotificationType.message,
  actor: const UserSummary(id: 'a-1', username: 'cs_cs0045', displayName: 'Nadia'),
  payload: {
    'room_id': 'r-cs',
    'room_type': support ? 'support' : 'direct',
    'ticket_id': 't-1',
    'snippet': 'Halo, saya bantu cek',
  },
  readAt: read ? DateTime.utc(2026, 10, 30) : null,
  createdAt: DateTime.utc(2026, 10, 30, 3),
  cursor: id,
);

void main() {
  late MockApi cs;
  late _MockNotifications notifications;
  late SupportRepositoryImpl repo;

  setUp(() {
    cs = mockApi();
    notifications = _MockNotifications();
    repo = SupportRepositoryImpl(cs: cs, notifications: notifications);
  });

  test('support home maps the active ticket, its status, and the assigned agent', () async {
    when(() => cs.rpcValue('support_home', any())).thenAnswer(
      (_) async => {
        'room_id': 'r-cs',
        'support_name': 'CS OLT',
        'ticket': ticketView(),
        'active': true,
        'unread_count': 2,
        'service_open': false,
        'next_open_at': '2026-10-31T02:00:00+00:00',
      },
    );

    final home = await repo.home();

    expect(home.supportName, 'CS OLT');
    expect(home.ticket?.status, SupportStatus.claimed);
    expect(home.ticket?.agent?.displayName, 'Nadia');
    expect(home.unreadCount, 2);
    expect(home.serviceOpen, isFalse);
    expect(home.showsConversation(DateTime.utc(2026, 10, 30)), isTrue);
  });

  test('opening a ticket sends only the topic and source screen, without client business data', () async {
    when(() => cs.rpcValue('open_ticket', any())).thenAnswer((_) async => ticketView(status: 'open'));

    final ticket = await repo.openTicket(topic: 'orders', screen: 'order_detail');

    final params = verify(() => cs.rpcValue('open_ticket', captureAny())).captured.single as Map<String, Object?>;
    expect(params.keys, unorderedEquals(['p_topic', 'p_language', 'p_screen', 'p_complaint']));
    expect(params, containsPair('p_topic', 'orders'));
    expect(params, containsPair('p_screen', 'order_detail'));
    expect(ticket.queueAhead, 2);
  });

  test('sensitive data and secret requests require a warning', () async {
    when(
      () => cs.rpcValue('check_sensitive', any()),
    ).thenAnswer((_) async => {'masked': false, 'kinds': <Object?>[], 'preview': 'x', 'requests_secret': true});
    expect((await repo.checkSensitive('kode OTP')).masked, isTrue);
  });

  test('local notifications only cover new unread support messages', () async {
    final changes = StreamController<void>.broadcast();
    var page = [notification('n-1')];
    when(() => notifications.watchNotifications()).thenAnswer((_) => changes.stream);
    when(() => notifications.getNotifications(limit: any(named: 'limit'))).thenAnswer((_) async => Paged(page));

    final received = <SupportNotice>[];
    final sub = repo.notices().listen(received.add);
    await pumpEventQueue();
    expect(received, isEmpty);

    page = [notification('n-3', support: false), notification('n-2'), notification('n-4', read: true), ...page];
    changes.add(null);
    await pumpEventQueue();

    expect([for (final n in received) n.id], ['n-2']);
    expect(received.single.title, 'Nadia');
    expect(received.single.body, 'Halo, saya bantu cek');
    await sub.cancel();
    await changes.close();
  });
}
