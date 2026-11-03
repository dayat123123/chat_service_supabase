import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/memory_offline_store.dart';
import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/outbox_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_list_cubit.dart';

import '../../../support/chat_app.dart';
import '../../../support/fakes.dart';

const _network = CommunityException(CommunityErrorKind.network, message: 'SocketException');

class _NoMedia extends Fake implements MediaRepository {}

class _FakeChatCache implements ChatCacheRepository {
  _FakeChatCache({this.user, this.rooms = const [], this.messages = const []});

  final UserSummary? user;
  final List<ChatRoom> rooms;
  final List<ChatMessage> messages;

  @override
  Future<UserSummary?> cachedUser() async => user;

  @override
  Future<List<ChatRoom>> cachedRooms() async => rooms;

  @override
  Future<List<ChatMessage>> cachedMessages(String roomId) async => [
    for (final m in messages)
      if (m.roomId == roomId) m,
  ];
}

class _OfflineDeps implements CommunityOfflineDependencies {
  _OfflineDeps(this.connectivity, {this.chatCache, this.outbox});

  @override
  final CommunityConnectivity connectivity;
  @override
  final ChatCacheRepository? chatCache;
  @override
  FeedCacheRepository? get feedCache => null;
  @override
  final MessageOutbox? outbox;
}

void main() {
  late FakeChatRepository chat;
  late CommunityConnectivity connectivity;
  late OutboxRepositoryImpl outboxStore;
  late MessageOutbox outbox;
  late bool serverReachable;

  final history = chatHistory(3);
  final cachedOnly = ChatMessage(
    id: 'gone',
    roomId: 'dm',
    senderId: alice.id,
    sender: alice,
    body: 'Sudah dihapus di server',
    createdAt: chatStart.add(const Duration(minutes: 1)),
  );

  setUp(() {
    serverReachable = true;
    chat = FakeChatRepository(rooms: [directRoom()], members: directMembers(), messages: history);
    connectivity = CommunityConnectivity();
    outboxStore = OutboxRepositoryImpl(
      OfflineCache(MemoryOfflineStoreFactory(), currentUserId: () => me.id, resolveHostKey: () async => null),
    );
    outbox = MessageOutbox(chat, outboxStore, baseDelay: const Duration(hours: 1));
  });

  tearDown(() async {
    await outbox.dispose();
    connectivity.dispose();
    await chat.dispose();
  });

  ChatRoomCubit roomCubit({ChatCacheRepository? cache}) => ChatRoomCubit(
    chat: chat,
    media: _NoMedia(),
    me: () async => serverReachable ? me : throw _network,
    roomId: 'dm',
    cache: cache ?? _FakeChatCache(user: me, rooms: [directRoom()], messages: [...history, cachedOnly]),
    outbox: outbox,
    connectivity: connectivity,
  );

  group('ChatRoomCubit', () {
    test('cached messages stay visible while offline and are replaced by the server once online', () async {
      serverReachable = false;
      chat.messagesError = _network;
      final cubit = roomCubit();
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.stale, isTrue);
      expect(cubit.state.me, me);
      expect([for (final m in cubit.state.messages) m.id], ['h-003', 'h-002', 'h-001', 'gone']);

      serverReachable = true;
      chat.messagesError = null;
      connectivity.report(reachable: false);
      connectivity.report(reachable: true);
      await pumpEventQueue();

      expect(cubit.state.stale, isFalse);
      expect([for (final m in cubit.state.messages) m.id], ['h-003', 'h-002', 'h-001']);
    });

    test('without cache or server the room fails as before', () async {
      serverReachable = false;
      final cubit = roomCubit(cache: _FakeChatCache());
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, LoadStatus.failure);
    });

    test('a text sent offline waits as pending and is replaced by the server copy after delivery', () async {
      final cubit = roomCubit();
      addTearDown(cubit.close);
      await cubit.load();

      chat.sendError = _network;
      await cubit.send('Kirim nanti');
      final local = cubit.state.messages.first;
      expect(local.isLocal, isTrue);
      expect(local.status, MessageStatus.pending);
      expect(cubit.state.actionErrorId, 0, reason: 'queued sends do not show an error');
      expect((await outboxStore.load()).single.body, 'Kirim nanti');

      chat.sendError = null;
      await outbox.flush(force: true);
      await pumpEventQueue();
      final sent = cubit.state.messages.first;
      expect(sent.id, 'srv-${local.clientId}');
      expect(sent.status, MessageStatus.sent);
      expect(cubit.state.messages.where((m) => m.clientId == local.clientId), hasLength(1));
      expect(await outboxStore.load(), isEmpty);
    });

    test('a rejected text stays failed with its reason and can be deleted', () async {
      final cubit = roomCubit();
      addTearDown(cubit.close);
      await cubit.load();

      chat.sendError = const CommunityException(CommunityErrorKind.contentBlocked, code: 'content_blocked');
      await cubit.send('Kata terlarang');
      final failed = cubit.state.messages.first;
      expect(failed.status, MessageStatus.failed);
      expect(failed.sendError?.code, 'content_blocked');
      expect(cubit.state.actionErrorId, 1);

      await cubit.discard(failed);
      expect(cubit.state.messages.where((m) => m.isLocal), isEmpty);
      expect(await outboxStore.load(), isEmpty);
    });

    test('messages queued in an earlier session show up as pending when the room opens', () async {
      await outboxStore.save(
        OutboxMessage(
          clientId: 'old',
          roomId: 'dm',
          body: 'Dari kemarin',
          createdAt: chatStart.add(const Duration(hours: 1)),
        ),
      );
      final cubit = roomCubit();
      addTearDown(cubit.close);
      await cubit.load();

      final queued = cubit.state.messages.first;
      expect(queued.clientId, 'old');
      expect(queued.status, MessageStatus.pending);
      expect(cubit.state.isMine(queued), isTrue);
    });

    test('images are refused with a clear message while offline', () async {
      final cubit = roomCubit();
      addTearDown(cubit.close);
      await cubit.load();
      connectivity.report(reachable: false);

      await cubit.sendImage(Uint8List(4), 'image/png');
      expect((cubit.state.actionError! as CommunityException).code, 'attachment_offline');
      expect(cubit.state.uploading, isFalse);
    });
  });

  test('ChatListCubit shows cached rooms while the server is unreachable', () async {
    final cubit = ChatListCubit(
      chat: chat,
      me: () async => throw _network,
      cache: _FakeChatCache(
        user: me,
        rooms: [directRoom(id: 'cached')],
      ),
      connectivity: connectivity,
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, LoadStatus.ready);
    expect(cubit.state.stale, isTrue);
    expect([for (final r in cubit.state.rooms) r.id], ['cached']);
  });

  group('widgets', () {
    Future<void> pumpRoom(WidgetTester tester, {required List<OutboxMessage> queued}) async {
      useScreen(tester, const Size(800, 1000));
      for (final message in queued) {
        await outboxStore.save(message);
      }
      await pumpChat(
        tester,
        chat,
        CommunityOfflineScope(
          dependencies: _OfflineDeps(
            connectivity,
            chatCache: _FakeChatCache(user: me, rooms: [directRoom()], messages: history),
            outbox: outbox,
          ),
          child: const CommunityChatRoom(roomId: 'dm'),
        ),
      );
    }

    testWidgets('pending and failed messages show their state with retry and delete actions', (tester) async {
      await tester.runAsync(
        () => pumpRoom(
          tester,
          queued: [
            OutboxMessage(
              clientId: 'p1',
              roomId: 'dm',
              body: 'Antre',
              createdAt: chatStart.add(const Duration(hours: 1)),
            ),
            OutboxMessage(
              clientId: 'f1',
              roomId: 'dm',
              body: 'Ditolak',
              createdAt: chatStart.add(const Duration(hours: 2)),
              state: OutboxState.failed,
              error: const CommunityException(CommunityErrorKind.contentBlocked, code: 'content_blocked'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final l10n = CommunityLocalizations.of(tester.element(find.byType(CommunityChatRoom)))!;

      expect(find.text(l10n.messagePending), findsOneWidget);
      expect(find.text(l10n.messageFailed), findsOneWidget);
      expect(find.text(l10n.errorContentBlocked), findsOneWidget);
      expect(find.widgetWithText(TextButton, l10n.retry), findsOneWidget);
      expect(find.widgetWithText(TextButton, l10n.delete), findsNWidgets(2));

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, l10n.delete).first);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.text('Ditolak'), findsNothing);
    });

    testWidgets('the room shows an offline banner while the network is down', (tester) async {
      await tester.runAsync(() => pumpRoom(tester, queued: const []));
      await tester.pumpAndSettle();
      final l10n = CommunityLocalizations.of(tester.element(find.byType(CommunityChatRoom)))!;
      expect(find.text(l10n.offlineChatBanner), findsNothing);

      connectivity.report(reachable: false);
      await tester.pump();
      expect(find.text(l10n.offlineChatBanner), findsOneWidget);

      connectivity.report(reachable: true);
      await tester.pump();
      expect(find.text(l10n.offlineChatBanner), findsNothing);
    });

    testWidgets('CommunityOfflineBanner follows the connectivity state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: CommunityLocalizations.localizationsDelegates,
          supportedLocales: CommunityLocalizations.supportedLocales,
          home: Scaffold(body: CommunityOfflineBanner(connectivity: connectivity)),
        ),
      );
      expect(find.byType(CommunityOfflineNotice), findsNothing);
      connectivity.report(reachable: false);
      await tester.pump();
      expect(find.text('Anda sedang offline. Menampilkan data tersimpan.'), findsOneWidget);
    });
  });
}
