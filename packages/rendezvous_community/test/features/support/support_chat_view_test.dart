import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../support/fakes.dart';

class _NoMedia extends Fake implements MediaRepository {}

void main() {
  final now = DateTime.now().toUtc();
  const nadia = UserSummary(id: 'a-1', username: 'cs_cs0045', displayName: 'Nadia', isVerified: true);

  ChatRoom supportRoom() =>
      ChatRoom(id: 'r-cs', type: RoomType.support, name: 'CS OLT', createdAt: now, lastReadAt: now);

  FakeChatRepository repository() => FakeChatRepository(
    rooms: [supportRoom()],
    members: [
      RoomMember(user: me, lastReadAt: now, lastDeliveredAt: now, joinedAt: now),
      RoomMember(user: nadia, lastReadAt: now, lastDeliveredAt: now, joinedAt: now),
    ],
    messages: [
      ChatMessage(
        id: 'm-3',
        roomId: 'r-cs',
        body: 'Tiket CS-20261030-0001 selesai. Bagaimana pelayanan kami?',
        createdAt: now,
        kind: MessageKind.csat,
        senderRole: SenderRole.system,
        ticketId: 't-1',
        payload: const {'code': 'ticket_resolved'},
      ),
      ChatMessage(
        id: 'm-2',
        roomId: 'r-cs',
        senderId: nadia.id,
        sender: nadia,
        body: 'Apakah sudah bisa login?',
        createdAt: now.subtract(const Duration(minutes: 1)),
        kind: MessageKind.quickReply,
        senderRole: SenderRole.agent,
        ticketId: 't-1',
        payload: const {
          'options': ['Sudah', 'Belum'],
        },
      ),
    ],
  );

  testWidgets('support room: compact system messages, official support badge, quick replies, and in-chat rating', (
    tester,
  ) async {
    final chat = repository();
    final picked = <String>[];
    final rated = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: CommunityLocalizations.localizationsDelegates,
        supportedLocales: CommunityLocalizations.supportedLocales,
        home: Scaffold(
          body: CommunityScope(
            dependencies: FakeDependencies(chat: chat),
            child: CommunitySupportMessageActions(
              onQuickReply: picked.add,
              canRate: (ticketId) => ticketId == 't-1',
              onRate: rated.add,
              child: CommunityChatRoom(roomId: 'r-cs', repository: chat),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('CS Resmi'), findsOneWidget);
    expect(find.text('Layanan resmi'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsOneWidget);

    await tester.tap(find.text('Belum'));
    await tester.tap(find.text('Beri nilai layanan ini'));
    expect(picked, ['Belum']);
    expect(rated, ['t-1']);
    await chat.dispose();
  });

  test('messages held by the server are removed from the list instead of marked failed', () async {
    final chat = repository()
      ..sendError = const CommunityException(CommunityErrorKind.contentBlocked, code: 'secret_request_blocked');
    final cubit = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'r-cs');
    await cubit.load();

    await cubit.send('Mohon kirim kode OTP Anda');

    expect(cubit.state.messages.where((m) => m.isLocal), isEmpty);
    expect(cubit.state.actionError, isA<CommunityException>());
    await cubit.close();
    await chat.dispose();
  });
}
