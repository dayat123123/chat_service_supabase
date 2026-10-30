import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/entities/receipt.dart';

import '../../../support/mock_api.dart';

void main() {
  late MockApi api;

  setUp(() => api = mockApi());

  test('sendMessage mengirim client_id untuk idempotensi', () async {
    when(() => api.rpcRows('send_message', any())).thenAnswer((_) async => [
      {
        'id': 'm-1',
        'room_id': 'r-1',
        'sender_id': 'u-1',
        'sender_username': 'budi_santoso',
        'sender_display_name': null,
        'sender_avatar_url': null,
        'body': 'Halo',
        'is_deleted': false,
        'reply_to_id': null,
        'reply_to_body': null,
        'reply_to_sender_username': null,
        'attachments': <Object?>[],
        'client_id': 'cid-1',
        'edited_at': null,
        'created_at': '2026-10-29T03:00:00+00:00',
        'cursor': 'x',
      },
    ]);

    final msg = await ChatRepositoryImpl(api).sendMessage('r-1', body: 'Halo', clientId: 'cid-1');

    final params = verify(() => api.rpcRows('send_message', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_client_id'], 'cid-1');
    expect(msg.clientId, 'cid-1');
    expect(msg.sender!.username, 'budi_santoso');
    expect(msg.status, MessageStatus.sent);
  });

  test('unreadCounts memetakan baris menjadi map', () async {
    when(() => api.rpcRows('get_unread_counts', any())).thenAnswer((_) async => [
      {'room_id': 'r-1', 'unread_count': 3},
      {'room_id': 'r-2', 'unread_count': 0},
    ]);
    expect(await ChatRepositoryImpl(api).unreadCounts(), {'r-1': 3, 'r-2': 0});
  });

  test('unreadChatCount memanggil RPC jumlah chat belum dibaca', () async {
    when(() => api.rpcValue('get_unread_chat_count', any())).thenAnswer((_) async => 3);
    expect(await ChatRepositoryImpl(api).unreadChatCount(), 3);
  });

  test('membaca, membisukan, dan keluar room memberi tahu perubahan unread', () async {
    when(() => api.rpcValue(any(), any())).thenAnswer((_) async => null);
    when(() => api.update(any(), any(), any())).thenAnswer((_) async {});
    final repo = ChatRepositoryImpl(api);
    var changes = 0;
    final sub = repo.watchUnreadChanges().listen((_) => changes++);

    await repo.markRoomRead('r-1');
    await repo.setMuted('r-1', muted: true);
    await repo.leaveRoom('r-1');
    await pumpEventQueue();

    expect(changes, 3);
    await sub.cancel();
    await repo.dispose();
  });

  test('getRooms memetakan lawan bicara DM dan status pesan terakhir', () async {
    when(() => api.rpcRows('get_my_rooms', any())).thenAnswer((_) async => [roomRow(status: 'read')]);

    final room = (await ChatRepositoryImpl(api).getRooms()).single;

    expect(room.type, RoomType.direct);
    expect(room.otherUser!.name, 'Sari');
    expect(room.unreadCount, 2);
    expect(room.lastMessageStatus, ReceiptStatus.read);
  });

  test('markDelivered meneruskan daftar room ke RPC', () async {
    when(() => api.rpcValue('mark_rooms_delivered', any())).thenAnswer((_) async => 2);

    final count = await ChatRepositoryImpl(api).markDelivered(roomIds: ['r-1', 'r-2']);

    verify(() => api.rpcValue('mark_rooms_delivered', {'p_room_ids': ['r-1', 'r-2']})).called(1);
    expect(count, 2);
  });

  test('getMembers membaca last_delivered_at untuk centang', () async {
    when(() => api.rpcRows('get_room_members', any())).thenAnswer((_) async => [
      {
        'user_id': 'u-2',
        'username': 'sari_invest',
        'display_name': 'Sari',
        'avatar_url': null,
        'is_verified': false,
        'role': 'member',
        'last_read_at': '2026-10-29T03:00:00+00:00',
        'last_delivered_at': '2026-10-29T04:00:00+00:00',
        'joined_at': '2026-10-01T00:00:00+00:00',
      },
    ]);

    final member = (await ChatRepositoryImpl(api).getMembers('r-1')).single;

    expect(member.lastDeliveredAt, DateTime.utc(2026, 10, 29, 4));
    expect(member.receipt.lastReadAt, DateTime.utc(2026, 10, 29, 3));
  });
}
