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

    final room = (await ChatRepositoryImpl(api).getRooms()).items.single;

    expect(room.type, RoomType.direct);
    expect(room.otherUser!.name, 'Sari');
    expect(room.unreadCount, 2);
    expect(room.lastMessageStatus, ReceiptStatus.read);
  });

  test('getRooms memuat per halaman dan memberi cursor halaman berikutnya', () async {
    when(() => api.rpcRows('get_my_rooms', any())).thenAnswer((_) async => [
      roomRow(id: 'r-1', cursor: '0|2026-10-29T03:00:00.000000Z|r-1'),
      roomRow(id: 'r-2', cursor: '0|2026-10-29T02:00:00.000000Z|r-2'),
    ]);

    final page = await ChatRepositoryImpl(api).getRooms(cursor: '1|2026-10-29T05:00:00.000000Z|r-0', limit: 2);

    verify(() => api.rpcRows('get_my_rooms', {'p_cursor': '1|2026-10-29T05:00:00.000000Z|r-0', 'p_limit': 2}))
        .called(1);
    expect(page.items.map((r) => r.id), ['r-1', 'r-2']);
    expect(page.nextCursor, '0|2026-10-29T02:00:00.000000Z|r-2');
  });

  test('getRooms halaman terakhir tidak punya cursor lanjutan', () async {
    when(() => api.rpcRows('get_my_rooms', any())).thenAnswer((_) async => [roomRow()]);

    final page = await ChatRepositoryImpl(api).getRooms(limit: 2);

    expect(page.items, hasLength(1));
    expect(page.nextCursor, isNull);
  });

  test('getRoom memuat satu room lewat get_my_room, null bila bukan anggota', () async {
    when(() => api.rpcRows('get_my_room', {'p_room_id': 'r-1'})).thenAnswer((_) async => [roomRow()]);
    when(() => api.rpcRows('get_my_room', {'p_room_id': 'r-9'})).thenAnswer((_) async => []);
    final repo = ChatRepositoryImpl(api);

    expect((await repo.getRoom('r-1'))!.otherUser!.username, 'sari_invest');
    expect(await repo.getRoom('r-9'), isNull);
  });

  test('getMessagesAfter memberi cursor pesan terbaru bila halaman penuh', () async {
    Map<String, dynamic> row(String id, String at) => {
      ...messageRow(id),
      'created_at': at,
      'cursor': '$at|$id',
    };
    when(() => api.rpcRows('get_messages', any())).thenAnswer((_) async => [
      row('m-3', '2026-10-29T03:03:00Z'),
      row('m-2', '2026-10-29T03:02:00Z'),
    ]);
    final repo = ChatRepositoryImpl(api);

    final full = await repo.getMessagesAfter('r-1', 'c-0', limit: 2);
    final partial = await repo.getMessagesAfter('r-1', 'c-0', limit: 3);

    verify(() => api.rpcRows('get_messages', {'p_room_id': 'r-1', 'p_after': 'c-0', 'p_limit': 2})).called(1);
    expect(full.nextCursor, '2026-10-29T03:03:00Z|m-3');
    expect(partial.nextCursor, isNull);
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
