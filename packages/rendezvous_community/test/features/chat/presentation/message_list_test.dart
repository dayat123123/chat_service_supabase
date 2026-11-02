import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../../support/chat_app.dart';
import '../../../support/fakes.dart';

void main() {
  FakeChatRepository repository(int count) =>
      FakeChatRepository(rooms: [directRoom()], members: directMembers(), messages: chatHistory(count));

  testWidgets('first page does not fill the screen: older messages load without scrolling', (tester) async {
    useScreen(tester, const Size(1000, 3000));
    final chat = repository(45);
    await pumpChat(tester, chat, const CommunityChatRoom(roomId: 'dm'));

    expect(chat.olderCursors, hasLength(2));
    expect(find.text('Pesan 1'), findsOneWidget);
    expect(find.text('Pesan 45'), findsOneWidget);
  });

  testWidgets('screen is full: the next page loads only when scrolling near the oldest message', (tester) async {
    useScreen(tester, const Size(1000, 700));
    final chat = repository(45);
    await pumpChat(tester, chat, const CommunityChatRoom(roomId: 'dm'));
    expect(chat.olderCursors, [null]);

    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(chat.olderCursors, hasLength(2));
  });
}
