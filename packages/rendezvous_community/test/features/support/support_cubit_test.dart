import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/support/presentation/cubit/support_cubit.dart';

import '../../support/fakes.dart';

class _MockSupport extends Mock implements SupportRepository {}

class _SupportDeps implements CommunitySupportDependencies {
  _SupportDeps(this.support, this.supportChat);

  @override
  final SupportRepository support;
  @override
  final ChatRepository supportChat;
}

SupportTicket ticket({SupportStatus status = SupportStatus.claimed, bool canRate = false}) => SupportTicket(
  id: 't-1',
  ticketNumber: 'CS-20261030-0001',
  roomId: 'r-cs',
  topic: 'orders',
  topicName: 'Order & Transaksi',
  status: status,
  agent: status == SupportStatus.claimed ? const SupportAgent(displayName: 'Nadia', agentCode: 'CS-0045') : null,
  createdAt: DateTime.utc(2026, 10, 30, 3),
  canRate: canRate,
);

SupportHome home({SupportTicket? current, String? roomId = 'r-cs'}) =>
    SupportHome(roomId: roomId, supportName: 'CS OLT', ticket: current, active: current?.isActive ?? false);

const _topics = [
  SupportTopic(code: 'orders', name: 'Order & Transaksi'),
  SupportTopic(code: 'funds', name: 'Deposit/Tarik Dana'),
];

Future<FakeChatRepository> pumpSupportChat(WidgetTester tester, SupportRepository support) async {
  final chat = FakeChatRepository(
    rooms: [ChatRoom(id: 'r-cs', type: RoomType.support, createdAt: DateTime.now(), lastReadAt: DateTime.now())],
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      home: Scaffold(
        body: CommunityScope(
          dependencies: FakeDependencies(chat: chat),
          child: CommunitySupportScope(dependencies: _SupportDeps(support, chat), child: const CommunitySupportChat()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chat;
}

void main() {
  late _MockSupport support;

  setUp(() {
    support = _MockSupport();
    when(() => support.topics(language: any(named: 'language'))).thenAnswer((_) async => _topics);
    when(() => support.watchTicket(any())).thenAnswer((_) => const Stream.empty());
  });

  test('without an active ticket, the customer picks a topic and the ticket is created immediately', () async {
    when(() => support.home()).thenAnswer((_) async => home(roomId: null));
    final cubit = SupportCubit(support: support);
    await cubit.load();
    expect(cubit.state.showsConversation(DateTime.now()), isFalse);

    when(
      () => support.openTicket(
        topic: any(named: 'topic'),
        language: any(named: 'language'),
        screen: any(named: 'screen'),
        complaint: any(named: 'complaint'),
      ),
    ).thenAnswer((_) async => ticket(status: SupportStatus.open));
    when(() => support.home()).thenAnswer((_) async => home(current: ticket(status: SupportStatus.open)));

    await cubit.start('funds');

    expect(cubit.state.showsConversation(DateTime.now()), isTrue);
    expect(cubit.state.ticket?.status, SupportStatus.open);
    await cubit.close();
  });

  test('the contextual help button fills in the topic and source screen when the ticket is created', () async {
    when(() => support.home()).thenAnswer((_) async => home(roomId: null));
    when(
      () => support.openTicket(
        topic: any(named: 'topic'),
        language: any(named: 'language'),
        screen: any(named: 'screen'),
        complaint: any(named: 'complaint'),
      ),
    ).thenAnswer((_) async => ticket(status: SupportStatus.open));
    final cubit = SupportCubit(support: support, topic: 'orders', screen: 'order_detail');

    await cubit.load();

    verify(() => support.openTicket(topic: 'orders', language: 'id', screen: 'order_detail')).called(1);
    await cubit.close();
  });

  test('with an active ticket, the contextual help button opens the ongoing ticket', () async {
    when(() => support.home()).thenAnswer((_) async => home(current: ticket()));
    final cubit = SupportCubit(support: support, topic: 'orders', screen: 'order_detail');

    await cubit.load();

    verifyNever(
      () => support.openTicket(
        topic: any(named: 'topic'),
        language: any(named: 'language'),
        screen: any(named: 'screen'),
        complaint: any(named: 'complaint'),
      ),
    );
    expect(cubit.state.showsConversation(DateTime.now()), isTrue);
    await cubit.close();
  });

  test('shows the sensitive data warning after a typing pause', () async {
    when(() => support.home()).thenAnswer((_) async => home(current: ticket()));
    when(
      () => support.checkSensitive(any()),
    ).thenAnswer((_) async => const SensitiveCheck(masked: true, kinds: ['otp']));
    final cubit = SupportCubit(support: support);
    await cubit.load();

    cubit.checkText('OTP saya 123456');
    expect(cubit.state.sensitive.masked, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(cubit.state.sensitive.kinds, ['otp']);
    cubit.checkText('ok');
    expect(cubit.state.sensitive.masked, isFalse);
    await cubit.close();
  });

  testWidgets('the ticket header shows the assigned agent and the official support badge', (tester) async {
    when(() => support.home()).thenAnswer((_) async => home(current: ticket()));
    final chat = FakeChatRepository(
      rooms: [ChatRoom(id: 'r-cs', type: RoomType.support, createdAt: DateTime.now(), lastReadAt: DateTime.now())],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: CommunityLocalizations.localizationsDelegates,
        supportedLocales: CommunityLocalizations.supportedLocales,
        home: Scaffold(
          body: CommunityScope(
            dependencies: FakeDependencies(chat: chat),
            child: CommunitySupportScope(
              dependencies: _SupportDeps(support, chat),
              child: const CommunitySupportChat(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ditangani oleh Nadia – CS Resmi'), findsOneWidget);
    expect(find.text('CS Resmi'), findsOneWidget);
    expect(find.textContaining('CS-20261030-0001'), findsOneWidget);
    await chat.dispose();
  });

  testWidgets('without an active ticket, topic choices appear without an attach-order option', (tester) async {
    when(() => support.home()).thenAnswer((_) async => home(roomId: null));
    final chat = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: CommunityLocalizations.localizationsDelegates,
        supportedLocales: CommunityLocalizations.supportedLocales,
        home: Scaffold(
          body: CommunityScope(
            dependencies: FakeDependencies(chat: chat),
            child: CommunitySupportScope(
              dependencies: _SupportDeps(support, chat),
              child: const CommunitySupportChat(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apa yang bisa kami bantu?'), findsOneWidget);
    expect(find.text('Deposit/Tarik Dana'), findsOneWidget);
    expect(find.text('Lampirkan order'), findsNothing);
    await chat.dispose();
  });

  testWidgets('a closed ticket can no longer be answered and offers a new ticket instead', (tester) async {
    when(
      () => support.home(),
    ).thenAnswer((_) async => home(current: ticket(status: SupportStatus.closed, canRate: true)));
    final chat = await pumpSupportChat(tester, support);

    expect(find.text('Tiket #CS-20261030-0001 sudah ditutup dan tidak bisa dibalas lagi.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Buat tiket baru'));
    await tester.pumpAndSettle();

    expect(find.text('Apa yang bisa kami bantu?'), findsOneWidget);
    await chat.dispose();
  });

  testWidgets('a resolved ticket that is not rated yet can still be answered until it closes', (tester) async {
    final resolved = ticket(
      status: SupportStatus.resolved,
      canRate: true,
    ).copyWith(reopenUntil: DateTime.now().add(const Duration(days: 2)));
    when(() => support.home()).thenAnswer((_) async => home(current: resolved));
    final chat = await pumpSupportChat(tester, support);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('sudah ditutup'), findsNothing);
    await chat.dispose();
  });
}
