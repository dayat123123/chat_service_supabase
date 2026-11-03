import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/data/models/chat_models.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_extras_repository_impl.dart';

import '../../support/chat_app.dart';
import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

class _NoMedia extends Fake implements MediaRepository {}

class _Extras extends FakeChatExtrasRepository {
  final sent = <List<String>>[];

  @override
  Future<ChatMessage> sendStockCards(
    String roomId,
    List<String> codes, {
    required String clientId,
    String? body,
  }) async {
    sent.add(codes);
    return ChatMessage(
      id: 'srv-$clientId',
      roomId: roomId,
      senderId: me.id,
      sender: me,
      body: body,
      stockCodes: codes,
      clientId: clientId,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

void main() {
  test('stock attachments are read from message rows next to images and shared posts', () {
    final message = ChatMessageModel.fromJson({
      'id': 'm-1',
      'room_id': 'r-1',
      'body': '',
      'attachments': [
        {'path': 'chat/u/a.jpg', 'mime': 'image/jpeg'},
        {'type': 'post', 'post_id': 'p-1'},
        {'type': 'stock', 'code': 'BBCA'},
        {'type': 'stock', 'code': 'TLKM'},
      ],
      'created_at': '2026-11-03T09:00:00Z',
    }).toEntity();
    expect(message.stockCodes, ['BBCA', 'TLKM']);
    expect(message.attachments, hasLength(1));
    expect(message.sharedPostId, 'p-1');
  });

  test('codes are normalized, validated and capped at three', () {
    expect(normalizeStockCardCodes([r' $bbca', 'tlkm', 'BBCA', '1X', 'ASII', 'GOTO']), ['BBCA', 'TLKM', 'ASII']);
  });

  test('send_message carries stock attachments', () async {
    final api = mockApi();
    when(() => api.rpcRows('send_message', any())).thenAnswer(
      (_) async => [
        {
          'id': 'm-1',
          'room_id': 'r-1',
          'body': '',
          'attachments': [
            {'type': 'stock', 'code': 'BBCA'},
          ],
          'client_id': 'c-1',
          'created_at': '2026-11-03T09:00:00Z',
        },
      ],
    );
    final message = await ChatExtrasRepositoryImpl(api).sendStockCards('r-1', ['BBCA'], clientId: 'c-1');
    expect(message.stockCodes, ['BBCA']);
    final params = verify(() => api.rpcRows('send_message', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_attachments'], [
      {'type': 'stock', 'code': 'BBCA'},
    ]);
  });

  test('the room cubit sends stock cards outside support chat only', () async {
    final extras = _Extras();
    final chat = FakeChatRepository(rooms: [directRoom()], members: directMembers());
    addTearDown(chat.dispose);
    final cubit = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'dm', extras: extras);
    addTearDown(cubit.close);
    await cubit.load();

    expect(cubit.canSendStockCards, isTrue);
    await cubit.sendStockCards(['bbca', 'tlkm']);
    expect(extras.sent, [
      ['BBCA', 'TLKM'],
    ]);
    expect(cubit.state.messages.first.stockCodes, ['BBCA', 'TLKM']);
    expect(cubit.state.messages.first.isLocal, isFalse);

    final support = FakeChatRepository(
      rooms: [ChatRoom(id: 'dm', type: RoomType.support, createdAt: chatStart, lastReadAt: chatStart)],
    );
    addTearDown(support.dispose);
    final cs = ChatRoomCubit(chat: support, media: _NoMedia(), me: () async => me, roomId: 'dm', extras: extras);
    addTearDown(cs.close);
    await cs.load();
    expect(cs.canSendStockCards, isFalse);
  });

  testWidgets('cards show host info and open the stock page', (tester) async {
    final opened = <String>[];
    await pumpFeatureApp(
      tester,
      const StockCards(codes: ['BBCA', 'TLKM'], isMine: false),
      dependencies: FakeDependencies(
        callbacks: CommunityCallbacks(
          onStockTap: (_, code) => opened.add(code),
          stockInfo: (code) => code == 'BBCA'
              ? const CommunityStockInfo(name: 'Bank Central Asia', price: '9.200', change: '+1,2%', rising: true)
              : null,
        ),
      ),
    );

    expect(find.text(r'$BBCA'), findsOneWidget);
    expect(find.text('Bank Central Asia'), findsOneWidget);
    expect(find.text('9.200'), findsOneWidget);
    expect(find.text(r'$TLKM'), findsOneWidget);
    await tester.tap(find.text(r'$TLKM'));
    expect(opened, ['TLKM']);
  });

  testWidgets('the picker validates codes and returns up to three', (tester) async {
    List<String>? picked;
    await pumpFeatureApp(
      tester,
      Builder(
        builder: (context) =>
            TextButton(onPressed: () async => picked = await showStockCardPicker(context), child: const Text('open')),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1X');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Kode saham tidak valid'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bbca, tlkm');
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(picked, ['BBCA', 'TLKM']);
  });
}
