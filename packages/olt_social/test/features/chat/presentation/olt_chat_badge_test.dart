import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeChatRepository chat;
  late FakeNotificationRepository notifications;

  setUp(() {
    chat = FakeChatRepository();
    notifications = FakeNotificationRepository();
  });

  tearDown(() async {
    await chat.dispose();
    await notifications.dispose();
  });

  Future<void> pumpBadge(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OltSocialScope(
          dependencies: FakeDependencies(chat: chat, notifications: notifications),
          child: const Scaffold(body: OltChatBadge(child: Icon(Icons.chat_bubble_outline))),
        ),
      ),
    );
    await tester.pump();
  }

  bool labelVisible(WidgetTester tester) => tester.widget<Badge>(find.byType(Badge)).isLabelVisible;

  testWidgets('menampilkan jumlah chat belum dibaca pada ikon', (tester) async {
    chat.unreadChats = 3;
    await pumpBadge(tester);
    expect(labelVisible(tester), isTrue);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });

  testWidgets('lebih dari 99 ditampilkan 99+', (tester) async {
    chat.unreadChats = 120;
    await pumpBadge(tester);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('tanpa chat belum dibaca, badge disembunyikan', (tester) async {
    await pumpBadge(tester);
    expect(labelVisible(tester), isFalse);
  });
}
