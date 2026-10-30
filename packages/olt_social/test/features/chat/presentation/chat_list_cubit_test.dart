import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_list_cubit.dart';

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
    chat = FakeChatRepository(rooms: [
      dm(),
      ChatRoom(id: 'grp', type: RoomType.group, name: 'Grup', createdAt: sentAt, lastReadAt: sentAt),
      ChatRoom(id: 'bbca', type: RoomType.stock, stockCode: 'BBCA', createdAt: sentAt, lastReadAt: sentAt),
    ]);
    cubit = ChatListCubit(chat: chat, me: () async => me, typingTimeout: const Duration(milliseconds: 40));
    await cubit.load();
  });

  tearDown(() async {
    await cubit.close();
    await chat.dispose();
  });

  test('memantau sinyal realtime room DM dan grup, bukan room saham', () {
    expect(chat.watchedRoomIds.single, {'dm', 'grp'});
  });

  test('sedang mengetik tampil di daftar lalu hilang otomatis', () async {
    chat.signals.add(const RoomTyping('grp', alice, isTyping: true));
    await pumpEventQueue();
    expect(cubit.state.typingIn('grp'), [alice]);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(cubit.state.typingIn('grp'), isEmpty);
  });

  test('pesan masuk dari yang sedang mengetik menghapus indikator', () async {
    chat.signals.add(const RoomTyping('dm', alice, isTyping: true));
    await pumpEventQueue();
    chat.activity.add(RoomActivity(roomId: 'dm', senderId: alice.id, preview: 'Hai', createdAt: sentAt));
    await pumpEventQueue();
    expect(cubit.state.typingIn('dm'), isEmpty);
  });

  test('tanda terima lawan bicara memperbarui centang pesan terakhir', () async {
    chat.signals.add(RoomReceipt(
      'dm',
      MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: sentAt.subtract(const Duration(seconds: 1))),
    ));
    await pumpEventQueue();
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.delivered);

    chat.signals.add(RoomReceipt('dm', MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: sentAt)));
    await pumpEventQueue();
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.read);
  });

  test('status centang tidak pernah mundur', () async {
    chat.rooms = [dm(status: ReceiptStatus.read)];
    await cubit.refresh();
    chat.signals.add(RoomReceipt(
      'dm',
      MemberReceipt(userId: alice.id, lastDeliveredAt: sentAt, lastReadAt: sentAt.subtract(const Duration(minutes: 1))),
    ));
    await pumpEventQueue();
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.read);
  });

  test('channel room tersambung ulang: daftar dimuat ulang agar centang yang terlewat diperbarui', () async {
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.connected));
    await pumpEventQueue();
    chat.rooms = [dm(status: ReceiptStatus.read)];
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.reconnecting));
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.connected));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.read);
  });

  test('sambungan pertama channel room tidak memuat ulang daftar', () async {
    chat.rooms = [dm(status: ReceiptStatus.read)];
    chat.signals.add(const RoomConnection('dm', RealtimeStatus.connected));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(cubit.state.rooms.first.lastMessageStatus, ReceiptStatus.sent);
  });

  test('presence room DM menandai lawan bicara online', () async {
    chat.signals.add(RoomPresence('dm', {me.id, alice.id}));
    await pumpEventQueue();
    expect(cubit.state.isOnline(cubit.state.rooms.first), isTrue);
  });
}
