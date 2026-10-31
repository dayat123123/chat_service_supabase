import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import 'fakes.dart';

final chatStart = DateTime.utc(2026, 10, 30, 1);

List<ChatMessage> chatHistory(int count, {String roomId = 'dm'}) => [
  for (var i = 1; i <= count; i++)
    ChatMessage(
      id: 'h-${i.toString().padLeft(3, '0')}',
      roomId: roomId,
      senderId: i.isEven ? me.id : alice.id,
      sender: i.isEven ? me : alice,
      body: 'Pesan $i',
      createdAt: chatStart.add(Duration(minutes: i * 5)),
    ),
];

ChatRoom directRoom({String id = 'dm'}) =>
    ChatRoom(id: id, type: RoomType.direct, createdAt: chatStart, lastReadAt: chatStart, otherUser: alice);

List<RoomMember> directMembers() => [
  RoomMember(user: me, lastReadAt: chatStart, lastDeliveredAt: chatStart, joinedAt: chatStart),
  RoomMember(user: alice, lastReadAt: chatStart, lastDeliveredAt: chatStart, joinedAt: chatStart),
];

void useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpChat(WidgetTester tester, ChatRepository chat, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      home: Scaffold(
        body: CommunityScope(
          dependencies: FakeDependencies(chat: chat),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
