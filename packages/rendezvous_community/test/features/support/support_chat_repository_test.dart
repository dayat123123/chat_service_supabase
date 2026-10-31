import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/support/data/repositories/support_chat_repository.dart';

import '../../support/mock_api.dart';

Map<String, dynamic> messageRow({
  String id = 'm-1',
  String? senderId = 'a-1',
  String body = 'Halo Pak Budi',
  String kind = 'text',
  String? senderRole = 'agent',
  Map<String, dynamic>? payload,
}) => {
  'id': id,
  'room_id': 'r-cs',
  'sender_id': senderId,
  'sender_username': senderId == null ? null : 'cs_cs0045',
  'sender_display_name': senderId == null ? null : 'Nadia',
  'sender_avatar_url': null,
  'body': body,
  'is_deleted': false,
  'reply_to_id': null,
  'reply_to_body': null,
  'reply_to_sender_username': null,
  'attachments': <Object?>[],
  'client_id': 'cid-1',
  'edited_at': null,
  'created_at': '2026-10-30T03:00:00+00:00',
  'cursor': 'x',
  'kind': kind,
  'payload': payload,
  'session_id': 't-1',
  'sender_role': senderRole,
};

void main() {
  late MockApi cs;

  setUp(() => cs = mockApi());

  SupportChatRepository customer() => SupportChatRepository(cs, rooms: () async => const []);

  test('support messages carry kind, sender role, ticket, and payload', () async {
    when(() => cs.rpcRows('get_messages', any())).thenAnswer(
      (_) async => [
        messageRow(
          kind: 'quick_reply',
          payload: {
            'options': ['Ya', 'Tidak'],
          },
        ),
        messageRow(id: 'm-0', senderId: null, kind: 'csat', senderRole: 'system', payload: {'code': 'ticket_resolved'}),
      ],
    );

    final page = await customer().getMessages('r-cs');

    final reply = page.items.first;
    expect(reply.kind, MessageKind.quickReply);
    expect(reply.senderRole, SenderRole.agent);
    expect(reply.isOfficial, isTrue);
    expect(reply.ticketId, 't-1');
    expect(reply.payload['options'], ['Ya', 'Tidak']);
    final notice = page.items.last;
    expect(notice.isSystem, isTrue);
    expect(notice.kind, MessageKind.csat);
    expect(notice.systemCode, 'ticket_resolved');
  });

  test('customers send through the cs_api send_message', () async {
    when(
      () => cs.rpcRows('send_message', any()),
    ).thenAnswer((_) async => [messageRow(senderId: 'u-1', senderRole: 'customer')]);

    final sent = await customer().sendMessage('r-cs', body: 'Halo', clientId: 'cid-1');

    final params = verify(() => cs.rpcRows('send_message', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_room_id'], 'r-cs');
    expect(params['p_client_id'], 'cid-1');
    expect(sent.senderRole, SenderRole.customer);
  });

  test('staff members are marked official and support messages cannot be deleted', () async {
    when(() => cs.rpcValue('room_members', any())).thenAnswer(
      (_) async => [
        {
          'user_id': 'a-1',
          'username': 'cs_cs0045',
          'display_name': 'Nadia',
          'role': 'member',
          'is_staff': true,
          'last_read_at': '2026-10-30T03:00:00+00:00',
          'last_delivered_at': '2026-10-30T03:00:00+00:00',
          'joined_at': '2026-10-30T02:00:00+00:00',
        },
        {
          'user_id': 'u-1',
          'username': 'budi_santoso',
          'display_name': 'Budi Santoso',
          'role': 'member',
          'is_staff': false,
          'last_read_at': '2026-10-30T03:00:00+00:00',
          'last_delivered_at': null,
          'joined_at': '2026-10-01T02:00:00+00:00',
        },
      ],
    );

    final members = await customer().getMembers('r-cs');

    expect(members.first.user.isVerified, isTrue);
    expect(members.last.user.isVerified, isFalse);
    await expectLater(customer().deleteMessage('m-1'), throwsA(isA<CommunityException>()));
  });
}
