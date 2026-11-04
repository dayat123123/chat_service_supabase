import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../../support/fakes.dart';

class _NoMedia extends Fake implements MediaRepository {}

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor();

  @override
  bool nextBool() => value >= 0.5;
}

void main() {
  final sentAt = DateTime.utc(2026, 10, 29, 10);
  final before = sentAt.subtract(const Duration(minutes: 1));
  late FakeChatRepository chat;
  late ChatRoomCubit cubit;

  setUp(() async {
    chat = FakeChatRepository(
      rooms: [ChatRoom(id: 'dm', type: RoomType.direct, createdAt: before, lastReadAt: before, otherUser: alice)],
      members: [
        RoomMember(user: me, lastReadAt: sentAt, lastDeliveredAt: sentAt, joinedAt: before),
        RoomMember(user: alice, lastReadAt: before, lastDeliveredAt: before, joinedAt: before),
      ],
      messages: [
        ChatMessage(id: 'm-1', roomId: 'dm', senderId: me.id, sender: me, body: 'Halo', createdAt: sentAt),
        ChatMessage(id: 'm-0', roomId: 'dm', senderId: alice.id, sender: alice, body: 'Hai', createdAt: before),
      ],
    );
    cubit = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'dm');
    await cubit.load();
  });

  tearDown(() async {
    await cubit.close();
    await chat.dispose();
  });

  ReceiptStatus? receiptOfMine() => cubit.state.receiptOf(cubit.state.messages.first);

  test('own undelivered message: one tick; messages from others: no ticks', () {
    expect(receiptOfMine(), ReceiptStatus.sent);
    expect(cubit.state.receiptOf(cubit.state.messages.last), isNull);
  });

  test('server receipts raise ticks up to blue', () async {
    chat.roomEvents.add(ReceiptChanged(MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: before)));
    await pumpEventQueue();
    expect(receiptOfMine(), ReceiptStatus.delivered);

    chat.roomEvents.add(ReceiptChanged(MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: sentAt)));
    await pumpEventQueue();
    expect(receiptOfMine(), ReceiptStatus.read);
  });

  test('a room channel reconnect refetches missed receipts from the server', () async {
    chat.roomEvents.add(const SignalsConnectionChanged(RealtimeStatus.connected));
    await pumpEventQueue();
    chat.members = [
      RoomMember(user: me, lastReadAt: sentAt, lastDeliveredAt: sentAt, joinedAt: before),
      RoomMember(user: alice, lastReadAt: sentAt, lastDeliveredAt: sentAt, joinedAt: before),
    ];
    chat.roomEvents.add(const SignalsConnectionChanged(RealtimeStatus.reconnecting));
    await pumpEventQueue();
    expect(receiptOfMine(), ReceiptStatus.sent);

    chat.roomEvents.add(const SignalsConnectionChanged(RealtimeStatus.connected));
    await pumpEventQueue();
    expect(receiptOfMine(), ReceiptStatus.read);
  });

  test('member data from the server does not downgrade newer receipts', () async {
    chat.roomEvents.add(ReceiptChanged(MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: sentAt)));
    await pumpEventQueue();
    chat.roomEvents.add(const SignalsConnectionChanged(RealtimeStatus.connected));
    chat.roomEvents.add(const SignalsConnectionChanged(RealtimeStatus.reconnecting));
    chat.roomEvents.add(const SignalsConnectionChanged(RealtimeStatus.connected));
    await pumpEventQueue();
    expect(receiptOfMine(), ReceiptStatus.read);
  });

  test('presence shows the peer as online', () async {
    chat.roomEvents.add(PresenceChanged({alice.id}));
    await pumpEventQueue();
    expect(cubit.state.otherOnline, isTrue);
  });

  test('opening a room marks it read through the RPC', () async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(chat.readRooms, ['dm']);
  });

  group('reconnects after a disconnect', () {
    List<ChatMessage> missed(int count) => [
      for (var i = 1; i <= count; i++)
        ChatMessage(
          id: 'n-${i.toString().padLeft(3, '0')}',
          roomId: 'dm',
          senderId: alice.id,
          sender: alice,
          body: 'Baru $i',
          createdAt: sentAt.add(Duration(seconds: i)),
        ),
    ];

    Future<void> reconnect(FakeChatRepository repository) async {
      repository.roomEvents
        ..add(const ConnectionChanged(RealtimeStatus.connected))
        ..add(const ConnectionChanged(RealtimeStatus.reconnecting))
        ..add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();
    }

    test('more than 100 messages received while disconnected are all caught up', () async {
      chat.messages = [...missed(150), ...chat.messages];
      await reconnect(chat);

      expect(cubit.state.messages, hasLength(152));
      expect(cubit.state.messages.first.id, 'n-150');
      expect(cubit.state.messages[50].id, 'n-100');
    });

    test('an overly long catch-up reloads the room from the newest message', () async {
      final far = ChatRoomCubit(chat: chat, media: _NoMedia(), me: () async => me, roomId: 'dm', maxGapPages: 2);
      addTearDown(far.close);
      await far.load();
      chat.sendError = Exception('offline');
      await far.send('Belum terkirim');
      chat.messages = [...missed(250), ...chat.messages];
      await reconnect(chat);

      final unsent = far.state.messages.where((m) => m.isLocal).toList();
      final synced = far.state.messages.where((m) => !m.isLocal).toList();
      expect(unsent.single.body, 'Belum terkirim');
      expect(synced, hasLength(30));
      expect(synced.first.id, 'n-250');
      expect(synced.last.id, 'n-221');
      expect(far.state.nextCursor, isNotNull);
    });
  });

  group('gap fill', () {
    ChatMessage fromAlice(String id, DateTime at) =>
        ChatMessage(id: id, roomId: 'dm', senderId: alice.id, sender: alice, body: 'Isi $id', createdAt: at);

    test('joining the room channel catches up messages sent between loading and subscribing', () async {
      chat.messages = [fromAlice('g-1', sentAt.add(const Duration(seconds: 1))), ...chat.messages];
      chat.roomEvents.add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();

      expect(cubit.state.messages.first.id, 'g-1');
    });

    test('a periodic catch-up recovers messages dropped by realtime without any reconnect', () async {
      final polling = ChatRoomCubit(
        chat: chat,
        media: _NoMedia(),
        me: () async => me,
        roomId: 'dm',
        gapFillInterval: const Duration(milliseconds: 40),
      );
      addTearDown(polling.close);
      await polling.load();
      chat.messages = [fromAlice('g-2', sentAt.add(const Duration(seconds: 2))), ...chat.messages];
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(polling.state.messages.first.id, 'g-2');
      expect(chat.afterCursors.last, endsWith('|00000000-0000-0000-0000-000000000000'));
    });

    test('the catch-up overlaps a few seconds so a message committed late with an earlier time is not lost', () async {
      final early = fromAlice('g-early', sentAt.add(const Duration(seconds: 4)));
      final seen = fromAlice('g-late', sentAt.add(const Duration(seconds: 5)));
      chat.roomEvents.add(MessageUpserted(seen));
      await pumpEventQueue();
      chat.messages = [seen, early, ...chat.messages];
      chat.roomEvents.add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();

      expect(cubit.state.messages.map((m) => m.id).take(2), ['g-late', 'g-early']);
    });

    test('a message delivered live and again by the catch-up appears once', () async {
      final live = fromAlice('g-3', sentAt.add(const Duration(seconds: 3)));
      chat.roomEvents.add(MessageUpserted(live));
      await pumpEventQueue();
      chat.messages = [live, ...chat.messages];
      chat.roomEvents.add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();

      expect(cubit.state.messages.where((m) => m.id == 'g-3'), hasLength(1));
      expect(cubit.state.messages, hasLength(3));
    });

    test('returning to the app catches up immediately', () async {
      final connectivity = CommunityConnectivity();
      addTearDown(connectivity.dispose);
      final resumed = ChatRoomCubit(
        chat: chat,
        media: _NoMedia(),
        me: () async => me,
        roomId: 'dm',
        connectivity: connectivity,
      );
      addTearDown(resumed.close);
      await resumed.load();
      chat.messages = [fromAlice('g-4', sentAt.add(const Duration(seconds: 4))), ...chat.messages];
      connectivity.notifyResumed();
      await pumpEventQueue();

      expect(resumed.state.messages.first.id, 'g-4');
    });
  });

  group('horizon gap fill', () {
    ChatMessage fromAlice(String id, Duration after) => ChatMessage(
      id: id,
      roomId: 'dm',
      senderId: alice.id,
      sender: alice,
      body: 'Isi $id',
      createdAt: sentAt.add(after),
    );

    FakeChatRepository copyOf(FakeChatRepository source, {required bool indexed}) {
      final copy = indexed
          ? IndexedFakeChatRepository(rooms: source.rooms, members: source.members, messages: source.messages)
          : FakeChatRepository(rooms: source.rooms, members: source.members, messages: source.messages);
      addTearDown(copy.dispose);
      return copy;
    }

    Future<ChatRoomCubit> open(
      FakeChatRepository repository, {
      CommunityConnectivity? connectivity,
      Duration interval = Duration.zero,
      Duration jitter = Duration.zero,
      Duration recheck = Duration.zero,
      double roll = 0,
    }) async {
      final opened = ChatRoomCubit(
        chat: repository,
        media: _NoMedia(),
        me: () async => me,
        roomId: 'dm',
        connectivity: connectivity,
        gapFillInterval: interval,
        reconnectJitter: jitter,
        gapRecheckDelay: recheck,
        random: _FixedRandom(roll),
      );
      addTearDown(opened.close);
      await opened.load();
      return opened;
    }

    List<String> cursorsOf(FakeChatRepository repository) =>
        repository is IndexedFakeChatRepository ? repository.idCursors : repository.afterCursors;

    for (final indexed in [false, true]) {
      final path = indexed ? 'message index' : 'paged fetch';

      test(
        '$path: a message dropped in the middle of the live stream is recovered after newer live messages',
        () async {
          final repository = copyOf(chat, indexed: indexed);
          final connectivity = CommunityConnectivity();
          addTearDown(connectivity.dispose);
          final room = await open(repository, connectivity: connectivity);
          repository.roomEvents.add(const ConnectionChanged(RealtimeStatus.connected));
          await pumpEventQueue();

          final before = fromAlice('h-1', const Duration(seconds: 10));
          final dropped = fromAlice('h-2', const Duration(seconds: 20));
          final after = fromAlice('h-3', const Duration(seconds: 60));
          repository.messages = [after, dropped, before, ...repository.messages];
          repository.roomEvents
            ..add(MessageUpserted(before))
            ..add(MessageUpserted(after));
          await pumpEventQueue();
          connectivity.notifyResumed();
          await pumpEventQueue();

          expect(room.state.messages.map((m) => m.id).take(3), ['h-3', 'h-2', 'h-1']);
        },
      );

      test('$path: live messages do not move the horizon, a completed catch-up does', () async {
        final repository = copyOf(chat, indexed: indexed);
        final connectivity = CommunityConnectivity();
        addTearDown(connectivity.dispose);
        await open(repository, connectivity: connectivity);

        final live = fromAlice('h-live', const Duration(seconds: 60));
        repository.messages = [live, ...repository.messages];
        repository.roomEvents.add(MessageUpserted(live));
        await pumpEventQueue();
        connectivity.notifyResumed();
        await pumpEventQueue();
        connectivity.notifyResumed();
        await pumpEventQueue();

        expect(cursorsOf(repository), hasLength(2));
        expect(cursorsOf(repository).first, startsWith('2026-10-29T09:59:50.000Z|'));
        expect(cursorsOf(repository).last, startsWith('2026-10-29T10:00:50.000Z|'));
      });
    }

    test('the message index only fetches rows the room does not have yet', () async {
      final repository = copyOf(chat, indexed: true) as IndexedFakeChatRepository;
      final connectivity = CommunityConnectivity();
      addTearDown(connectivity.dispose);
      await open(repository, connectivity: connectivity);

      final live = fromAlice('h-live', const Duration(seconds: 5));
      final dropped = fromAlice('h-dropped', const Duration(seconds: 6));
      repository.messages = [dropped, live, ...repository.messages];
      repository.roomEvents.add(MessageUpserted(live));
      await pumpEventQueue();
      connectivity.notifyResumed();
      await pumpEventQueue();

      expect(repository.idRequests, [
        ['h-dropped'],
      ]);
      expect(repository.afterCursors, isEmpty);
    });

    test('a reconnect waits a random jitter, then checks again 5-10 s later for late commits', () async {
      final repository = copyOf(chat, indexed: false);
      final room = await open(
        repository,
        jitter: const Duration(milliseconds: 200),
        recheck: const Duration(milliseconds: 200),
        roll: 0.5,
      );
      repository.roomEvents.add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();
      final joined = repository.afterCursors.length;

      repository.roomEvents
        ..add(const ConnectionChanged(RealtimeStatus.reconnecting))
        ..add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();
      expect(repository.afterCursors, hasLength(joined));

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(repository.afterCursors, hasLength(joined + 1));

      final late = fromAlice('h-late', const Duration(seconds: 1));
      repository.messages = [late, ...repository.messages];
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(room.state.messages.first.id, isNot('h-late'));

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(repository.afterCursors, hasLength(joined + 2));
      expect(room.state.messages.first.id, 'h-late');
    });

    test('a new reconnect replaces the pending catch-ups instead of stacking them', () async {
      final repository = copyOf(chat, indexed: false);
      await open(
        repository,
        jitter: const Duration(milliseconds: 100),
        recheck: const Duration(milliseconds: 100),
        roll: 0.5,
      );
      repository.roomEvents.add(const ConnectionChanged(RealtimeStatus.connected));
      await pumpEventQueue();
      final joined = repository.afterCursors.length;

      for (var i = 0; i < 3; i++) {
        repository.roomEvents
          ..add(const ConnectionChanged(RealtimeStatus.reconnecting))
          ..add(const ConnectionChanged(RealtimeStatus.connected));
        await pumpEventQueue();
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(repository.afterCursors, hasLength(joined + 2));
    });

    test('the periodic catch-up is spread around its interval', () async {
      final early = copyOf(chat, indexed: false);
      final lateRepository = copyOf(chat, indexed: false);
      await open(early, interval: const Duration(milliseconds: 200), roll: 0);
      await open(lateRepository, interval: const Duration(milliseconds: 200), roll: 0.99);

      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(early.afterCursors, hasLength(1));
      expect(lateRepository.afterCursors, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(lateRepository.afterCursors, hasLength(1));
    });
  });
}
