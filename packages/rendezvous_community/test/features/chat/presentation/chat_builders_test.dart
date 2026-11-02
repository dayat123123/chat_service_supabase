import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../../support/chat_app.dart';
import '../../../support/fakes.dart';

Widget messageTile(BuildContext context, CommunityMessageDetails d, Widget fallback) => Wrap(
  children: [
    Text('${d.isMine ? 'saya' : 'lawan'}: ${d.message.isDeleted ? 'dihapus' : d.message.body}'),
    if (d.onReply != null) TextButton(onPressed: d.onReply, child: Text('balas ${d.message.id}')),
    if (d.onDelete != null) TextButton(onPressed: d.onDelete, child: Text('hapus ${d.message.id}')),
    if (d.onRetry != null) TextButton(onPressed: d.onRetry, child: Text('ulang ${d.message.id}')),
  ],
);

Widget composerBox(BuildContext context, CommunityComposerDetails d, Widget fallback) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (d.replyPreview != null) Text('membalas ${d.replyPreview}'),
    TextField(controller: d.controller, focusNode: d.focusNode),
    TextButton(onPressed: d.onSend, child: const Text('kirim')),
  ],
);

void main() {
  FakeChatRepository repository({int messages = 2}) =>
      FakeChatRepository(rooms: [directRoom()], members: directMembers(), messages: chatHistory(messages));

  testWidgets('message and composer builders: display-ready data, reply, then send without extra logic', (
    tester,
  ) async {
    useScreen(tester, const Size(900, 1200));
    final chat = repository();
    await pumpChat(
      tester,
      chat,
      const CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(message: messageTile, composer: composerBox),
      ),
    );

    expect(find.text('lawan: Pesan 1'), findsOneWidget);
    expect(find.text('saya: Pesan 2'), findsOneWidget);
    expect(find.text('hapus h-001'), findsNothing);
    expect(find.text('hapus h-002'), findsOneWidget);

    await tester.tap(find.text('balas h-001'));
    await tester.pumpAndSettle();
    expect(find.text('membalas Alice: Pesan 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Halo dari builder');
    await tester.tap(find.text('kirim'));
    await tester.pumpAndSettle();

    expect(find.text('saya: Halo dari builder'), findsOneWidget);
    expect(find.text('membalas Alice: Pesan 1'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('the delete handler uses the built-in confirmation and then deletes the message', (tester) async {
    useScreen(tester, const Size(900, 1200));
    final chat = repository();
    await pumpChat(
      tester,
      chat,
      const CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(message: messageTile),
      ),
    );

    await tester.tap(find.text('hapus h-002'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(chat.deletedMessages, ['h-002']);
    expect(find.text('saya: dihapus'), findsOneWidget);
  });

  testWidgets('failed messages provide a resend handler', (tester) async {
    useScreen(tester, const Size(900, 1200));
    final chat = repository()..sendError = Exception('offline');
    await pumpChat(
      tester,
      chat,
      const CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(message: messageTile, composer: composerBox),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Tertunda');
    await tester.tap(find.text('kirim'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ulang local-'), findsOneWidget);

    chat.sendError = null;
    await tester.tap(find.textContaining('ulang local-'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ulang local-'), findsNothing);
    expect(find.text('saya: Tertunda'), findsOneWidget);
  });

  testWidgets('fallback renders the default view for unhandled messages', (tester) async {
    useScreen(tester, const Size(900, 1200));
    await pumpChat(
      tester,
      repository(),
      CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(
          message: (context, d, fallback) => d.isMine ? Text('kustom ${d.message.body}') : fallback,
        ),
      ),
    );

    expect(find.text('kustom Pesan 2'), findsOneWidget);
    expect(find.text('Pesan 1'), findsOneWidget);
  });

  testWidgets('room header builder: title, status, and mute handler', (tester) async {
    useScreen(tester, const Size(900, 1200));
    final chat = repository();
    await pumpChat(
      tester,
      chat,
      CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(
          roomHeader: (context, d, fallback) => Row(
            children: [
              Text('judul ${d.title}'),
              Text('status ${d.subtitle}'),
              TextButton(onPressed: d.onToggleMute, child: Text(d.room.muted ? 'nyalakan' : 'bisukan')),
              if (d.onLeave != null) const Text('bisa keluar'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('judul Alice'), findsOneWidget);
    expect(find.text('status @alice'), findsOneWidget);
    expect(find.text('bisa keluar'), findsNothing);

    await tester.tap(find.text('bisukan'));
    await tester.pumpAndSettle();

    expect(chat.mutedRooms, {'dm': true});
    expect(find.text('nyalakan'), findsOneWidget);
  });

  testWidgets('status builders: typing, reconnecting, and day separator', (tester) async {
    useScreen(tester, const Size(900, 1200));
    final chat = repository();
    await pumpChat(
      tester,
      chat,
      CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(
          typingIndicator: (context, d, fallback) => Text('ketik ${d.users.single.name}: ${d.text}'),
          connectionBanner: (context, d, fallback) => Text('koneksi ${d.label}'),
          dayDivider: (context, d, fallback) => Text('hari ${d.day.toUtc().day}'),
        ),
      ),
    );
    expect(find.text('hari 30'), findsOneWidget);

    chat.roomEvents
      ..add(const TypingChanged(alice, isTyping: true))
      ..add(const ConnectionChanged(RealtimeStatus.connected))
      ..add(const ConnectionChanged(RealtimeStatus.reconnecting));
    await tester.pumpAndSettle();

    expect(find.text('ketik Alice: mengetik…'), findsOneWidget);
    expect(find.text('koneksi Menyambungkan ulang…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('empty and error builders: the retry handler reloads the room', (tester) async {
    useScreen(tester, const Size(900, 1200));
    final chat = FakeChatRepository(rooms: [directRoom()], members: directMembers())..messagesError = Exception('down');
    await pumpChat(
      tester,
      chat,
      CommunityChatRoom(
        roomId: 'dm',
        builders: CommunityChatBuilders(
          error: (context, d, fallback) => TextButton(onPressed: d.onRetry, child: const Text('ulangi')),
          empty: (context, d, fallback) => Text('kosong ${d.kind.name}: ${d.message}'),
        ),
      ),
    );
    expect(find.text('ulangi'), findsOneWidget);

    chat.messagesError = null;
    await tester.tap(find.text('ulangi'));
    await tester.pumpAndSettle();

    expect(find.text('kosong messages: Tulis pesan…'), findsOneWidget);
  });

  testWidgets('wide chat list: tile and header builders are used, and the opened room uses them too', (tester) async {
    useScreen(tester, const Size(1200, 900));
    await pumpChat(
      tester,
      repository(),
      CommunityChatList(
        builders: CommunityChatBuilders(
          listHeader: (context, d, fallback) => TextButton(onPressed: d.onNewGroup, child: Text('header ${d.title}')),
          roomTile: (context, d, fallback) =>
              ListTile(title: Text('tile ${d.title}'), subtitle: Text('${d.timeLabel}|${d.selected}'), onTap: d.onTap),
          empty: (context, d, fallback) => Text('kosong ${d.kind.name}'),
          message: messageTile,
        ),
      ),
    );

    expect(find.text('header Chat'), findsOneWidget);
    expect(find.text('kosong noRoomSelected'), findsOneWidget);

    await tester.tap(find.text('tile Alice'));
    await tester.pumpAndSettle();

    expect(find.textContaining('|true'), findsOneWidget);
    expect(find.text('lawan: Pesan 1'), findsOneWidget);
  });

  testWidgets('narrow screen: a room opened on a new page still uses builders from the scope', (tester) async {
    useScreen(tester, const Size(500, 900));
    await pumpChat(
      tester,
      repository(),
      CommunityChatBuildersScope(
        builders: CommunityChatBuilders(
          roomTile: (context, d, fallback) => ListTile(title: Text('tile ${d.title}'), onTap: d.onTap),
          message: messageTile,
        ),
        child: const CommunityChatList(),
      ),
    );

    await tester.tap(find.text('tile Alice'));
    await tester.pumpAndSettle();

    expect(find.text('lawan: Pesan 1'), findsOneWidget);
  });
}
