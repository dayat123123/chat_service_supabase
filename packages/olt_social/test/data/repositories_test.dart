import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/src/core/errors/olt_social_exception.dart';
import 'package:olt_social/src/data/datasources/social_remote_data_source.dart';
import 'package:olt_social/src/data/repositories/chat_repository_impl.dart';
import 'package:olt_social/src/data/repositories/feed_repository_impl.dart';
import 'package:olt_social/src/data/repositories/social_repository_impl.dart';
import 'package:olt_social/src/domain/entities/chat.dart';
import 'package:olt_social/src/domain/entities/paged.dart';
import 'package:olt_social/src/domain/entities/post.dart';

class MockApi extends Mock implements SocialRemoteDataSource {}

/// Bentuk baris persis seperti respons RPC get_feed.
Map<String, dynamic> feedRow(String id, {String cursor = 'c'}) => {
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
  'edited_at': null,
  'created_at': '2026-10-29T03:00:00.123456+00:00',
  'cursor': cursor,
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

void main() {
  late MockApi api;

  setUp(() {
    api = MockApi();
    when(() => api.requireUserId()).thenAnswer((_) async => 'u-1');
  });

  group('FeedRepositoryImpl', () {
    test('getFeed memetakan scope ke parameter RPC dan baris ke entitas', () async {
      when(() => api.rpcRows('get_feed', any())).thenAnswer((_) async => [feedRow('p-1'), feedRow('p-2', cursor: 'next')]);

      final page = await FeedRepositoryImpl(api).getFeed(const FeedScope.stock('BBCA'), limit: 2);

      final params = verify(() => api.rpcRows('get_feed', captureAny())).captured.single as Map<String, Object?>;
      expect(params, {
        'p_scope': 'stock',
        'p_stock_code': 'BBCA',
        'p_cursor': null,
        'p_limit': 2,
        'p_author_id': null,
      });
      expect(page.items, hasLength(2));
      expect(page.nextCursor, 'next', reason: 'halaman penuh -> ada halaman berikutnya');
      final post = page.items.first;
      expect(post.author.name, 'Budi Santoso');
      expect(post.author.isVerified, isTrue);
      expect(post.sentiment, Sentiment.bullish);
      expect(post.stockCodes, ['BBCA']);
      expect(post.attachments.single.path, 'posts/u-1/a.jpg');
      expect(post.createdAt.isUtc, isTrue);
    });

    test('halaman tidak penuh berarti tidak ada halaman berikutnya', () async {
      when(() => api.rpcRows('get_feed', any())).thenAnswer((_) async => [feedRow('p-1')]);
      final page = await FeedRepositoryImpl(api).getFeed(const FeedScope.global(), limit: 20);
      expect(page.hasMore, isFalse);
    });

    test('likePost mengabaikan like ganda (unique violation)', () async {
      when(() => api.insert('reactions', any())).thenThrow(
        const OltSocialException(OltSocialErrorKind.invalidInput, code: '23505'),
      );
      await FeedRepositoryImpl(api).likePost('p-1');
      verify(() => api.insert('reactions', {
        'user_id': 'u-1',
        'target_type': 'post',
        'target_id': 'p-1',
        'type': 'like',
      })).called(1);
    });

    test('error lain saat like diteruskan', () async {
      when(() => api.insert('reactions', any())).thenThrow(
        const OltSocialException(OltSocialErrorKind.forbidden, code: 'blocked'),
      );
      expect(FeedRepositoryImpl(api).likePost('p-1'), throwsA(isA<OltSocialException>()));
    });

    test('createPost menyisipkan post milik user lalu mengambil versi lengkap', () async {
      when(() => api.insert('posts', any())).thenAnswer((_) async {});
      when(() => api.rpcRows('get_post', any())).thenAnswer((_) async => [feedRow('p-new')]);

      final post = await FeedRepositoryImpl(api).createPost(body: r'$BBCA', sentiment: Sentiment.bearish);

      final values = verify(() => api.insert('posts', captureAny())).captured.single as Map<String, Object?>;
      expect(values['author_id'], 'u-1');
      expect(values['sentiment'], 'bearish');
      expect(values['id'], isA<String>());
      expect(post.id, 'p-new');
    });
  });

  group('CommentRepositoryImpl', () {
    test('getThread meneruskan parameter thread dan memetakan komentar terhapus', () async {
      when(() => api.rpcRows('get_comment_thread', any()))
          .thenAnswer((_) async => [commentRow('c-1'), commentRow('c-2', parentId: 'c-1', depth: 1, deleted: true)]);

      final thread = await CommentRepositoryImpl(api).getThread('p-1', rootCommentId: 'c-0', maxDepth: 4, includeRoot: true);

      final params = verify(() => api.rpcRows('get_comment_thread', captureAny())).captured.single as Map<String, Object?>;
      expect(params['p_root_comment_id'], 'c-0');
      expect(params['p_max_depth'], 4);
      expect(params['p_include_root'], true);
      expect(thread.first.author!.username, 'sari_invest');
      expect(thread.last.isDeleted, isTrue);
      expect(thread.last.author, isNull);
      expect(thread.last.body, isNull);
    });
  });

  group('ChatRepositoryImpl', () {
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

    test('getRooms memetakan lawan bicara DM', () async {
      when(() => api.rpcRows('get_my_rooms', any())).thenAnswer((_) async => [
        {
          'id': 'r-1',
          'type': 'direct',
          'name': null,
          'stock_code': null,
          'created_by': 'u-1',
          'last_message_at': '2026-10-29T03:00:00+00:00',
          'last_message_preview': 'Halo',
          'last_message_sender_id': 'u-2',
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
        },
      ]);
      final room = (await ChatRepositoryImpl(api).getRooms()).single;
      expect(room.type, RoomType.direct);
      expect(room.otherUser!.name, 'Sari');
      expect(room.unreadCount, 2);
    });
  });

  group('ModerationRepositoryImpl', () {
    test('report memakai nama alasan sesuai constraint DB', () async {
      when(() => api.insert('reports', any())).thenAnswer((_) async {});
      await ModerationRepositoryImpl(api).report(
        target: ReportTarget.post,
        targetId: 'p-1',
        reason: ReportReason.pumpAndDump,
      );
      final values = verify(() => api.insert('reports', captureAny())).captured.single as Map<String, Object?>;
      expect(values['reason'], 'pump_and_dump');
      expect(values['target_type'], 'post');
    });
  });

  group('NotificationRepositoryImpl', () {
    test('tipe notifikasi tak dikenal diabaikan', () async {
      when(() => api.rpcRows('get_notifications', any())).thenAnswer((_) async => [
        {
          'id': 'n-1',
          'type': 'like',
          'actor_id': 'u-2',
          'actor_username': 'sari_invest',
          'actor_display_name': null,
          'actor_avatar_url': null,
          'payload': {'post_id': 'p-1', 'snippet': 'Halo'},
          'event_count': 2,
          'read_at': null,
          'created_at': '2026-10-29T03:00:00+00:00',
          'cursor': 'a',
        },
        {
          'id': 'n-2',
          'type': 'jenis_baru',
          'payload': <String, Object?>{},
          'event_count': 1,
          'created_at': '2026-10-29T02:00:00+00:00',
          'cursor': 'b',
        },
      ]);
      final page = await NotificationRepositoryImpl(api).getNotifications(limit: 30);
      expect(page.items.single.postId, 'p-1');
      expect(page.items.single.eventCount, 2);
      expect(page.hasMore, isFalse);
    });
  });
}
