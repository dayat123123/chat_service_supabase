import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';

import '../../../support/chat_app.dart';
import '../../../support/fakes.dart';

void main() {
  FakeChatRepository repository(int count) => FakeChatRepository(rooms: [
    for (var n = 1; n <= count; n++)
      ChatRoom(
        id: 'g-${n.toString().padLeft(2, '0')}',
        type: RoomType.group,
        name: 'Grup $n',
        lastMessageAt: chatStart.subtract(Duration(minutes: n)),
        createdAt: chatStart.subtract(const Duration(days: 1)),
        lastReadAt: chatStart.subtract(const Duration(days: 1)),
      ),
  ]);

  testWidgets('halaman room berikutnya dimuat saat scroll mendekati bawah', (tester) async {
    useScreen(tester, const Size(500, 800));
    final chat = repository(45);
    await pumpChat(tester, chat, const OltChatList());
    expect(chat.roomCursors, [null]);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(chat.roomCursors, hasLength(2));

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.text('Grup 45'), findsOneWidget);
    expect(chat.roomCursors, hasLength(2));
  });

  testWidgets('halaman pertama belum memenuhi layar: room berikutnya dimuat tanpa scroll', (tester) async {
    useScreen(tester, const Size(500, 3200));
    final chat = repository(45);
    await pumpChat(tester, chat, const OltChatList());

    expect(chat.roomCursors, hasLength(2));
    expect(find.text('Grup 35'), findsOneWidget);
  });
}
