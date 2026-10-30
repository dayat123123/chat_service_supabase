import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/room_tile.dart';

import '../../../support/fakes.dart';

void main() {
  final at = DateTime.now().toUtc();

  Future<void> pumpTile(WidgetTester tester, ChatRoom room, {List<UserSummary> typing = const []}) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
          supportedLocales: OltSocialLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomTile(room: room, me: me, online: false, typing: typing, selected: false, onTap: () {}),
          ),
        ),
      );

  ChatRoom dm(ReceiptStatus status) => ChatRoom(
    id: 'dm',
    type: RoomType.direct,
    lastMessageAt: at,
    lastMessagePreview: 'Sudah lihat BBCA?',
    lastMessageSenderId: me.id,
    lastMessageStatus: status,
    createdAt: at,
    lastReadAt: at,
    otherUser: alice,
  );

  testWidgets('DM yang sedang mengetik menampilkan "mengetik…"', (tester) async {
    await pumpTile(tester, dm(ReceiptStatus.sent), typing: [alice]);
    expect(find.text('mengetik…'), findsOneWidget);
    expect(find.text('Sudah lihat BBCA?'), findsNothing);
  });

  testWidgets('grup yang sedang mengetik menyebut nama pengetik', (tester) async {
    final group = ChatRoom(id: 'g', type: RoomType.group, name: 'Grup', createdAt: at, lastReadAt: at);
    await pumpTile(tester, group, typing: [alice]);
    expect(find.text('Alice sedang mengetik…'), findsOneWidget);
  });

  testWidgets('centang pesan terakhir: satu, dua abu-abu, dua biru', (tester) async {
    await pumpTile(tester, dm(ReceiptStatus.sent));
    expect(find.byIcon(Icons.done), findsOneWidget);

    await pumpTile(tester, dm(ReceiptStatus.delivered));
    final delivered = tester.widget<Icon>(find.byIcon(Icons.done_all));
    expect(delivered.color, isNot(OltSocialTheme.fallback(ThemeData()).readReceipt));

    await pumpTile(tester, dm(ReceiptStatus.read));
    final read = tester.widget<Icon>(find.byIcon(Icons.done_all));
    final context = tester.element(find.byType(RoomTile));
    expect(read.color, OltSocialTheme.of(context).readReceipt);
    expect(find.text('Sudah lihat BBCA?'), findsOneWidget);
  });
}
