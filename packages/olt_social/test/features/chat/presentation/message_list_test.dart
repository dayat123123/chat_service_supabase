import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';

import '../../../support/chat_app.dart';
import '../../../support/fakes.dart';

void main() {
  FakeChatRepository repository(int count) =>
      FakeChatRepository(rooms: [directRoom()], members: directMembers(), messages: chatHistory(count));

  testWidgets('halaman pertama belum memenuhi layar: pesan lama dimuat tanpa perlu scroll', (tester) async {
    useScreen(tester, const Size(1000, 3000));
    final chat = repository(45);
    await pumpChat(tester, chat, const OltChatRoom(roomId: 'dm'));

    expect(chat.olderCursors, hasLength(2));
    expect(find.text('Pesan 1'), findsOneWidget);
    expect(find.text('Pesan 45'), findsOneWidget);
  });

  testWidgets('layar sudah penuh: halaman berikutnya baru dimuat saat scroll mendekati pesan tertua', (tester) async {
    useScreen(tester, const Size(1000, 700));
    final chat = repository(45);
    await pumpChat(tester, chat, const OltChatRoom(roomId: 'dm'));
    expect(chat.olderCursors, [null]);

    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(chat.olderCursors, hasLength(2));
  });
}
