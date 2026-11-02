import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_list_cubit.dart';

import '../../../support/fakes.dart';

void main() {
  final sentAt = DateTime.utc(2026, 10, 29, 10);
  late FakeChatRepository chat;
  late ChatListCubit cubit;

  ChatRoom dm({ReceiptStatus? status = ReceiptStatus.sent}) => ChatRoom(
    id: 'dm',
    type: RoomType.direct,
    lastMessageAt: sentAt,
    lastMessagePreview: 'Halo',
    lastMessageSenderId: me.id,
    lastMessageStatus: status,
    createdAt: sentAt,
    lastReadAt: sentAt,
    otherUser: alice,
  );

  setUp(() async {
    final earlier = sentAt.subtract(const Duration(hours: 1));
    chat = FakeChatRepository(
      rooms: [
        dm(),
        ChatRoom(id: 'grp', type: RoomType.group, name: 'Grup', createdAt: earlier, lastReadAt: earlier),
        ChatRoom(id: 'bbca', type: RoomType.stock, stockCode: 'BBCA', createdAt: earlier, lastReadAt: earlier),
      ],
    );
    cubit = ChatListCubit(chat: chat, me: () async => me, typingTimeout: const Duration(milliseconds: 40));
    await cubit.load();
  });

  tearDown(() async {
    await cubit.close();
    await chat.dispose();
  });

  test('watches realtime signals for DM and group rooms, not stock rooms', () {
    expect(chat.watchedRoomIds.single, {'dm', 'grp'});
  });

  test('typing appears in the list and clears automatically', () async {
    chat.signals.add(const RoomTyping('grp', alice, isTyping: true));
    await pumpEventQueue();
    expect(cubit.state.typingIn('grp'), [alice]);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(cubit.state.typingIn('grp'), isEmpty);
  });

  test('an incoming message from the typist clears the indicator', () async {
    chat.signals.add(const RoomTyping('dm', alice, isTyping: true));
    await pumpEventQueue();
    chat.activity.add(RoomActivity(roomId: 'dm', senderId: alice.id, preview: 'Hai', createdAt: sentAt));
    await pumpEventQueue();
    expect(cubit.state.typingIn('dm'), isEmpty);
  });

  test('peer receipts update the last message ticks', () async {
    chat.signals.add(
      RoomReceipt(
        'dm',
        MemberReceipt(
          userId: alice.id,
          lastDeliveredAt: sentAt,
          lastReadAt: sentAt.subtract(const Duration(seconds: 1)),
        ),
      ),
    );
    await pumpEventQueue();
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.delivered);

    chat.signals.add(RoomReceipt('dm', MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: sentAt)));
    await pumpEventQueue();
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.read);
  });

  test('tick status never moves backwards', () async {
    chat.rooms = [dm(status: ReceiptStatus.read)];
    await cubit.refresh();
    chat.signals.add(
      RoomReceipt(
        'dm',
        MemberReceipt(
          userId: alice.id,
          lastDeliveredAt: sentAt,
          lastReadAt: sentAt.subtract(const Duration(minutes: 1)),
        ),
      ),
    );
    await pumpEventQueue();
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.read);
  });

  test('a room channel reconnect reloads the list so missed ticks are updated', () async {
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.connected));
    await pumpEventQueue();
    chat.rooms = [dm(status: ReceiptStatus.read)];
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.reconnecting));
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.connected));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.read);
  });

  test('the first room channel connection does not reload the list', () async {
    chat.rooms = [dm(status: ReceiptStatus.read)];
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.connected));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.sent);
  });

  test('DM room presence marks the peer as online', () async {
    chat.signals.add(RoomPresence('dm', {me.id, alice.id}));
    await pumpEventQueue();
    expect(cubit.state.isOnline(cubit.state.rooms.first), isTrue);
  });

  group('paging', () {
    late FakeChatRepository many;
    late ChatListCubit paged;

    ChatRoom group(int n, {DateTime? activeAt}) => ChatRoom(
      id: 'g-${n.toString().padLeft(2, '0')}',
      type: RoomType.group,
      name: 'Grup $n',
      lastMessageAt: activeAt ?? sentAt.subtract(Duration(minutes: n)),
      createdAt: sentAt.subtract(const Duration(days: 1)),
      lastReadAt: sentAt.subtract(const Duration(days: 1)),
    );

    List<String> ids() => [for (final r in paged.state.rooms) r.id];

    setUp(() async {
      many = FakeChatRepository(rooms: [for (var n = 1; n <= 25; n++) group(n)]);
      paged = ChatListCubit(chat: many, me: () async => me, pageSize: 10);
      await paged.load();
    });

    tearDown(() async {
      await paged.close();
      await many.dispose();
    });

    test('loads only the first page, then the next page through loadMore', () async {
      expect(ids(), [for (var n = 1; n <= 10; n++) 'g-${n.toString().padLeft(2, '0')}']);

      await paged.loadMore();
      await paged.loadMore();
      expect(ids(), hasLength(25));
      expect(ids().last, 'g-25');
      expect(many.roomCursors, [null, 'g-10', 'g-20']);

      await paged.loadMore();
      expect(many.roomCursors, hasLength(3));
    });

    test('consecutive loadMore calls fetch a single page', () async {
      await Future.wait([paged.loadMore(), paged.loadMore()]);
      expect(many.roomCursors, [null, 'g-10']);
      expect(ids(), hasLength(20));
    });

    test('refresh keeps loaded pages and moves active rooms up', () async {
      await paged.loadMore();
      many.rooms = [for (var n = 1; n <= 25; n++) n == 18 ? group(18, activeAt: sentAt) : group(n)];

      await paged.refresh();

      expect(ids().first, 'g-18');
      expect(ids(), hasLength(20));
      expect(ids().toSet(), hasLength(20));
      await paged.loadMore();
      expect(ids(), hasLength(25));
      expect(ids().toSet(), hasLength(25));
    });

    test('a room outside the loaded pages moves to the top without dropping visible rooms', () async {
      await paged.loadMore();
      many.rooms = [for (var n = 1; n <= 25; n++) n == 25 ? group(25, activeAt: sentAt) : group(n)];

      await paged.refresh();

      expect(ids().first, 'g-25');
      expect(ids(), containsAll([for (var n = 1; n <= 20; n++) 'g-${n.toString().padLeft(2, '0')}']));
      expect(ids(), hasLength(21));
      await paged.loadMore();
      expect(ids(), hasLength(25));
      expect(ids().toSet(), hasLength(25));
    });

    test('refresh drops rooms that were left', () async {
      many.rooms = [
        for (var n = 1; n <= 25; n++)
          if (n != 3) group(n),
      ];

      await paged.refresh();

      expect(ids(), isNot(contains('g-03')));
      expect(ids(), hasLength(10));
      await paged.loadMore();
      await paged.loadMore();
      expect(ids(), hasLength(24));
    });
  });
}
