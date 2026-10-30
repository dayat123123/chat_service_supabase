import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:olt_social/src/features/feed/domain/entities/post.dart';
import 'package:olt_social/src/features/poll/domain/entities/poll.dart';

import '../../../support/mock_api.dart';

void main() {
  late MockApi api;

  setUp(() => api = mockApi());

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
    expect(page.nextCursor, 'next');
    final post = page.items.first;
    expect(post.author.name, 'Budi Santoso');
    expect(post.author.isVerified, isTrue);
    expect(post.sentiment, Sentiment.bullish);
    expect(post.stockCodes, ['BBCA']);
    expect(post.attachments.single.path, 'posts/u-1/a.jpg');
    expect(post.createdAt.isUtc, isTrue);
    expect(post.poll, isNull);
  });

  test('halaman tidak penuh berarti tidak ada halaman berikutnya', () async {
    when(() => api.rpcRows('get_feed', any())).thenAnswer((_) async => [feedRow('p-1')]);
    final page = await FeedRepositoryImpl(api).getFeed(const FeedScope.global(), limit: 20);
    expect(page.hasMore, isFalse);
  });

  test('post polling dipetakan beserta pilihan dan suara', () async {
    when(() => api.rpcRows('get_post', any()))
        .thenAnswer((_) async => [feedRow('p-1', poll: pollJson(myOptionId: 'o-1', visible: true, total: 4))]);

    final poll = (await FeedRepositoryImpl(api).getPost('p-1'))!.poll!;

    expect(poll.options.map((o) => o.label), ['Naik', 'Turun']);
    expect(poll.myOptionId, 'o-1');
    expect(poll.totalVotes, 4);
    expect(poll.share(poll.options.first), 0.75);
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

  test('createPost memakai RPC create_post dengan client_id dan polling', () async {
    when(() => api.rpcRows('create_post', any())).thenAnswer((_) async => [feedRow('p-new', poll: pollJson())]);

    final post = await FeedRepositoryImpl(api).createPost(
      body: r'$BBCA ke mana?',
      sentiment: Sentiment.bearish,
      poll: const PollDraft(options: [' Naik ', 'Turun'], duration: PollDuration.threeDays),
      clientId: 'cid-1',
    );

    final params = verify(() => api.rpcRows('create_post', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_sentiment'], 'bearish');
    expect(params['p_client_id'], 'cid-1');
    expect(params['p_poll'], {
      'options': ['Naik', 'Turun'],
      'duration_minutes': 4320,
    });
    expect(post.id, 'p-new');
    expect(post.poll!.options, hasLength(2));
  });

  test('createPost tanpa polling mengirim p_poll null dan client_id acak', () async {
    when(() => api.rpcRows('create_post', any())).thenAnswer((_) async => [feedRow('p-new')]);

    await FeedRepositoryImpl(api).createPost(body: 'Halo');

    final params = verify(() => api.rpcRows('create_post', captureAny())).captured.single as Map<String, Object?>;
    expect(params['p_poll'], isNull);
    expect(params['p_client_id'], isA<String>());
  });
}
