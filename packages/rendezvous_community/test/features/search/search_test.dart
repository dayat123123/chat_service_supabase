import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/search/data/repositories/search_repository_impl.dart';
import 'package:rendezvous_community/src/features/search/presentation/cubit/search_cubit.dart';

import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

void main() {
  group('SearchRepositoryImpl', () {
    test('maps every section of search(all) and never sends a cursor for all', () async {
      final api = mockApi();
      when(() => api.rpcValue('search', any())).thenAnswer(
        (_) async => {
          'query': 'bbca',
          'type': 'all',
          'posts': [feedRow('p-1')],
          'users': [
            {
              'id': 'u-2',
              'username': 'sari_invest',
              'display_name': 'Sari',
              'avatar_url': null,
              'is_verified': false,
              'follower_count': 12,
              'is_official': true,
              'is_following': true,
              'is_me': false,
            },
          ],
          'stocks': [
            {'code': 'BBCA', 'posts_7d': 4, 'watcher_count': 9, 'is_watching': true},
          ],
          'hashtags': [
            {'tag': 'dividen', 'posts_7d': 3},
          ],
          'next_cursor': null,
        },
      );

      final results = await SearchRepositoryImpl(api).search('bbca', cursor: 'ignored', limit: 5);

      final params = verify(() => api.rpcValue('search', captureAny())).captured.single as Map<String, Object?>;
      expect(params, {'p_query': 'bbca', 'p_type': 'all', 'p_cursor': null, 'p_limit': 5});
      expect(results.posts.single.id, 'p-1');
      expect(results.users.single.user.username, 'sari_invest');
      expect(results.users.single.isOfficial, isTrue);
      expect(results.stocks.single.posts7d, 4);
      expect(results.hashtags.single.postCount, 3);
      expect(results.count, 4);
    });

    test('hashtag feed strips the # and pages like the feed; trending hashtags map scores', () async {
      final api = mockApi();
      when(() => api.rpcRows('get_hashtag_feed', any())).thenAnswer((_) async => [feedRow('p-1', cursor: 'n')]);
      when(() => api.rpcRows('get_trending_hashtags', any())).thenAnswer(
        (_) async => [
          {'tag': 'ipo', 'post_count': 7, 'author_count': 3, 'score': 2.4},
        ],
      );
      final repository = SearchRepositoryImpl(api);

      final page = await repository.hashtagFeed('#Dividen', limit: 1);
      expect(page.nextCursor, 'n');
      verify(() => api.rpcRows('get_hashtag_feed', {'p_tag': 'Dividen', 'p_cursor': null, 'p_limit': 1})).called(1);

      final trending = await repository.trendingHashtags(window: TrendWindow.week);
      expect(trending.single.score, 2.4);
      verify(() => api.rpcRows('get_trending_hashtags', {'p_window': '7d', 'p_limit': 10})).called(1);
    });
  });

  group('SearchCubit', () {
    late FakeSearchRepository repository;
    late FakeAnalyticsRepository analyticsRepository;
    late CommunityAnalytics analytics;

    setUp(() {
      repository = FakeSearchRepository()
        ..answer = (query, type, cursor) => SearchResults(
          query: query,
          type: type,
          stocks: [StockSearchResult(code: cursor == null ? 'BBCA' : 'BBRI')],
          nextCursor: cursor == null && type != SearchType.all ? 'o:1' : null,
        );
      analyticsRepository = FakeAnalyticsRepository();
      analytics = CommunityAnalytics(analyticsRepository, enabled: () => true, signedIn: () => true);
    });

    blocTest<SearchCubit, SearchState>(
      'debounces typing and searches once with the final query',
      build: () => SearchCubit(search: repository, analytics: analytics, debounce: const Duration(milliseconds: 50)),
      act: (cubit) async {
        cubit
          ..setQuery('bb')
          ..setQuery('bbc')
          ..setQuery('bbca');
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      verify: (cubit) {
        expect(repository.queries.map((q) => q.$1), ['bbca']);
        expect(repository.queries.single.$4, 5);
        expect(cubit.state.status, LoadStatus.ready);
        expect(cubit.state.results!.stocks.single.code, 'BBCA');
      },
    );

    blocTest<SearchCubit, SearchState>(
      'short or symbol-only queries are not sent',
      build: () => SearchCubit(search: repository, debounce: Duration.zero, minLength: 2),
      act: (cubit) async {
        cubit.setQuery('#');
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.queries, isEmpty);
        expect(cubit.state.tooShort, isTrue);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'switching tabs searches that type and loadMore appends the next page',
      build: () => SearchCubit(search: repository, debounce: Duration.zero),
      act: (cubit) async {
        cubit.setQuery('bb');
        await cubit.submit();
        cubit.setType(SearchType.stocks);
        await Future<void>.delayed(Duration.zero);
        await cubit.loadMore();
      },
      verify: (cubit) {
        expect(repository.queries.last, ('bb', SearchType.stocks, 'o:1', 20));
        expect(cubit.state.results!.stocks.map((s) => s.code), ['BBCA', 'BBRI']);
        expect(cubit.state.hasMore, isFalse);
      },
    );

    test('records a search event with counts only, never the query text', () async {
      final cubit = SearchCubit(search: repository, analytics: analytics, debounce: Duration.zero)
        ..setQuery('rahasia pribadi');
      await cubit.submit();
      await analytics.flush();
      final event = analyticsRepository.batches.single.single;
      expect(event.name, 'search');
      expect(event.props, {'type': 'all', 'query_length': 15, 'result_count': 1});
      expect(event.toJson().toString(), isNot(contains('rahasia')));
      await cubit.close();
    });
  });
}
