import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';

class MockApi extends Mock implements SocialRemoteDataSource {}

MockApi mockApi() {
  final api = MockApi();
  when(() => api.requireUserId()).thenAnswer((_) async => 'u-1');
  return api;
}

Map<String, dynamic> feedRow(String id, {String cursor = 'c', Map<String, dynamic>? poll}) => {
  'id': id,
  'author_id': 'u-1',
  'author_username': 'budi_santoso',
  'author_display_name': 'Budi Santoso',
  'author_avatar_url': null,
  'author_is_verified': true,
  'body': r'$BBCA naik',
  'sentiment': 'bullish',
  'attachments': [
    {'path': 'posts/u-1/a.jpg', 'mime': 'image/jpeg'},
  ],
  'like_count': 3,
  'comment_count': 7,
  'stock_codes': ['BBCA'],
  'liked_by_me': false,
  'poll': poll,
  'edited_at': null,
  'created_at': '2026-10-29T03:00:00.123456+00:00',
  'cursor': cursor,
};

Map<String, dynamic> pollJson({String? myOptionId, bool visible = false, int total = 0}) => {
  'ends_at': '2026-10-30T03:00:00+00:00',
  'closed': false,
  'total_votes': total,
  'my_option_id': myOptionId,
  'results_visible': visible,
  'options': [
    {'id': 'o-1', 'label': 'Naik', 'votes': visible ? 3 : null},
    {'id': 'o-2', 'label': 'Turun', 'votes': visible ? 1 : null},
  ],
};

Map<String, dynamic> commentRow(String id, {String? parentId, int depth = 0, bool deleted = false}) => {
  'id': id,
  'post_id': 'p-1',
  'parent_id': parentId,
  'author_id': deleted ? null : 'u-2',
  'author_username': deleted ? null : 'sari_invest',
  'author_display_name': null,
  'author_avatar_url': null,
  'author_is_verified': false,
  'body': deleted ? null : 'Setuju',
  'is_deleted': deleted,
  'depth': depth,
  'path': '000000000001',
  'like_count': 0,
  'reply_count': 2,
  'liked_by_me': false,
  'edited_at': null,
  'created_at': '2026-10-29T03:10:00+00:00',
  'cursor': '1',
};

Map<String, dynamic> messageRow(String id) => {
  'id': id,
  'room_id': 'r-1',
  'sender_id': 'u-2',
  'sender_username': 'sari_invest',
  'sender_display_name': 'Sari',
  'sender_avatar_url': null,
  'body': 'Pesan $id',
  'is_deleted': false,
  'reply_to_id': null,
  'reply_to_body': null,
  'reply_to_sender_username': null,
  'attachments': <Object?>[],
  'client_id': null,
  'edited_at': null,
  'created_at': '2026-10-29T03:00:00+00:00',
  'cursor': '2026-10-29T03:00:00.000000Z|$id',
};

Map<String, dynamic> roomRow({
  String id = 'r-1',
  String status = 'delivered',
  String sender = 'u-1',
  String cursor = '0|2026-10-29T03:00:00.000000Z|r-1',
}) => {
  'id': id,
  'type': 'direct',
  'name': null,
  'stock_code': null,
  'created_by': 'u-1',
  'last_message_at': '2026-10-29T03:00:00+00:00',
  'last_message_preview': 'Halo',
  'last_message_sender_id': sender,
  'last_message_status': status,
  'created_at': '2026-10-28T03:00:00+00:00',
  'my_role': 'member',
  'muted': false,
  'last_read_at': '2026-10-28T03:00:00+00:00',
  'unread_count': 2,
  'member_count': 2,
  'other_user_id': 'u-2',
  'other_username': 'sari_invest',
  'other_display_name': 'Sari',
  'other_avatar_url': null,
  'other_is_verified': false,
  'cursor': cursor,
};
