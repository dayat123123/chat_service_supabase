import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social/src/features/support/presentation/cubit/support_cubit.dart';

import '../../support/fakes.dart';

class _MockSupport extends Mock implements SupportRepository {}

class _SupportDeps implements OltSupportDependencies {
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

SupportHome home({SupportTicket? current, String? roomId = 'r-cs'}) => SupportHome(
  roomId: roomId,
  supportName: 'CS OLT',
  ticket: current,
  active: current?.isActive ?? false,
);

const _topics = [
  SupportTopic(code: 'orders', name: 'Order & Transaksi'),
  SupportTopic(code: 'funds', name: 'Deposit/Tarik Dana'),
];

void main() {
  late _MockSupport support;

  setUpAll(() => registerFallbackValue(const SupportCard(kind: SupportCardKind.order, ref: 'x')));

  setUp(() {
    support = _MockSupport();
    when(() => support.topics(language: any(named: 'language'))).thenAnswer((_) async => _topics);
    when(() => support.watchTicket(any())).thenAnswer((_) => const Stream.empty());
  });

  test('tanpa tiket aktif: nasabah memilih topik, lalu tiket langsung dibuat', () async {
    when(() => support.home()).thenAnswer((_) async => home(roomId: null));
    final cubit = SupportCubit(support: support);
    await cubit.load();
    expect(cubit.state.showsConversation(DateTime.now()), isFalse);

    when(() => support.openTicket(
      topic: any(named: 'topic'),
      language: any(named: 'language'),
      screen: any(named: 'screen'),
      complaint: any(named: 'complaint'),
      card: any(named: 'card'),
    )).thenAnswer((_) async => ticket(status: SupportStatus.open));
    when(() => support.home()).thenAnswer((_) async => home(current: ticket(status: SupportStatus.open)));

    await cubit.start('funds');

    expect(cubit.state.showsConversation(DateTime.now()), isTrue);
    expect(cubit.state.ticket?.status, SupportStatus.open);
    await cubit.close();
  });

  test('tombol bantuan kontekstual: topik dan kartu order ikut terisi saat tiket dibuat', () async {
    when(() => support.home()).thenAnswer((_) async => home(roomId: null));
    when(() => support.openTicket(
      topic: any(named: 'topic'),
      language: any(named: 'language'),
      screen: any(named: 'screen'),
      complaint: any(named: 'complaint'),
      card: any(named: 'card'),
    )).thenAnswer((_) async => ticket(status: SupportStatus.open));
    const card = SupportCard(kind: SupportCardKind.order, ref: 'ORD-9');
    final cubit = SupportCubit(support: support, topic: 'orders', card: card, screen: 'order_detail');

    await cubit.load();

    verify(() => support.openTicket(topic: 'orders', language: 'id', screen: 'order_detail', card: card)).called(1);
    expect(cubit.state.pendingCard, isNull);
    await cubit.close();
  });

  test('tiket aktif: kartu order langsung dikirim ke chat', () async {
    when(() => support.home()).thenAnswer((_) async => home(current: ticket()));
    when(() => support.sendCard(any(), any(), clientId: any(named: 'clientId'))).thenAnswer((_) async {});
    final cubit = SupportCubit(support: support);
    await cubit.load();

    await cubit.attachCard(const SupportCard(kind: SupportCardKind.order, ref: 'ORD-2'));

    verify(() => support.sendCard('r-cs', any(), clientId: any(named: 'clientId'))).called(1);
    expect(cubit.state.notice, SupportNoticeKind.cardSent);
    await cubit.close();
  });

  test('peringatan data sensitif muncul setelah jeda mengetik', () async {
    when(() => support.home()).thenAnswer((_) async => home(current: ticket()));
    when(() => support.checkSensitive(any()))
        .thenAnswer((_) async => const SensitiveCheck(masked: true, kinds: ['otp']));
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

  testWidgets('header tiket menampilkan CS yang menangani dan badge CS Resmi', (tester) async {
    when(() => support.home()).thenAnswer((_) async => home(current: ticket()));
    final chat = FakeChatRepository(
      rooms: [ChatRoom(id: 'r-cs', type: RoomType.support, createdAt: DateTime.now(), lastReadAt: DateTime.now())],
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
      supportedLocales: OltSocialLocalizations.supportedLocales,
      home: Scaffold(
        body: OltSocialScope(
          dependencies: FakeDependencies(chat: chat),
          child: OltSupportScope(dependencies: _SupportDeps(support, chat), child: const OltSupportChat()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ditangani oleh Nadia – CS Resmi'), findsOneWidget);
    expect(find.text('CS Resmi'), findsOneWidget);
    expect(find.textContaining('CS-20261030-0001'), findsOneWidget);
    await chat.dispose();
  });

  testWidgets('tanpa tiket aktif tampil pilihan topik', (tester) async {
    when(() => support.home()).thenAnswer((_) async => home(roomId: null));
    final chat = FakeChatRepository();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
      supportedLocales: OltSocialLocalizations.supportedLocales,
      home: Scaffold(
        body: OltSocialScope(
          dependencies: FakeDependencies(chat: chat),
          child: OltSupportScope(dependencies: _SupportDeps(support, chat), child: const OltSupportChat()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Apa yang bisa kami bantu?'), findsOneWidget);
    expect(find.text('Deposit/Tarik Dana'), findsOneWidget);
    expect(find.text('Lampirkan order'), findsOneWidget);
    await chat.dispose();
  });
}
