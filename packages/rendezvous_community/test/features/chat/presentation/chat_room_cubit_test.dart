import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../../support/fakes.dart';

class _NoMedia extends Fake implements MediaRepository {}

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
}
