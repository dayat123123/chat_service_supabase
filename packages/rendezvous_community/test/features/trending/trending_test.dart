import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/trending/data/repositories/trending_repository_impl.dart';

import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

void main() {
  test('get_trending maps stocks, rising, posts, and hashtags', () async {
    final api = mockApi();
    when(() => api.rpcValue('get_trending', any())).thenAnswer(
      (_) async => {
        'window': '7d',
        'computed_at': '2026-11-03T05:00:00Z',
        'stocks': [
          {
            'code': 'BBCA',
            'posts': 12,
            'score': 8.5,
            'bullish_pct': 60,
            'bearish_pct': 30,
            'neutral_pct': 10,
            'growth_pct': 25.5,
          },
        ],
        'rising': [
          {'code': 'GOTO', 'posts': 9, 'prev_posts': 2, 'growth_pct': 350},
        ],
        'posts': [feedRow('p-1')],
        'hashtags': [
          {'tag': 'ipo', 'post_count': 4, 'author_count': 3, 'score': 2},
        ],
      },
    );

    final snapshot = await TrendingRepositoryImpl(api).trending(window: TrendWindow.week);

    verify(() => api.rpcValue('get_trending', {'p_window': '7d'})).called(1);
    expect(snapshot.computedAt, DateTime.utc(2026, 11, 3, 5));
    expect(snapshot.stocks.single.bullishPct, 60);
    expect(snapshot.stocks.single.growthPct, 25.5);
    expect(snapshot.rising.single.prevPosts, 2);
    expect(snapshot.posts.single.id, 'p-1');
    expect(snapshot.hashtags.single.authorCount, 3);
  });

  test('get_stock_sentiment maps both windows and null percentages', () async {
    final api = mockApi();
    when(() => api.rpcValue('get_stock_sentiment', any())).thenAnswer(
      (_) async => {
        'code': 'BBCA',
        '24h': {
          'posts': 4,
          'bullish': 2,
          'bearish': 1,
          'neutral': 0,
          'unlabeled': 1,
          'bullish_pct': 67,
          'bearish_pct': 33,
          'neutral_pct': 0,
        },
        '7d': {
          'posts': 0,
          'bullish': 0,
          'bearish': 0,
          'neutral': 0,
          'unlabeled': 0,
          'bullish_pct': null,
          'bearish_pct': null,
          'neutral_pct': null,
        },
        'updated_at': '2026-11-03T05:00:00Z',
      },
    );

    final sentiment = await TrendingRepositoryImpl(api).stockSentiment('bbca');

    verify(() => api.rpcValue('get_stock_sentiment', {'p_code': 'BBCA'})).called(1);
    expect(sentiment.day.bullishPct, 67);
    expect(sentiment.day.hasLabels, isTrue);
    expect(sentiment.of(TrendWindow.week).hasLabels, isFalse);
  });

  testWidgets('CommunityStockSentiment shows the bar and switches windows', (tester) async {
    final features = FakeFeatureDependencies(config: loadedConfig());
    addTearDown(features.dispose);
    features.trending.sentiment = const StockSentiment(
      code: 'BBCA',
      day: SentimentBreakdown(posts: 4, bullishPct: 67, bearishPct: 33, neutralPct: 0),
    );

    await pumpFeatureApp(tester, const CommunityStockSentiment(stockCode: 'bbca'), features: features);
    await tester.pumpAndSettle();
    expect(find.text('Bullish 67%'), findsOneWidget);
    expect(find.text('Bearish 33%'), findsOneWidget);
    expect(find.byType(SentimentBar), findsOneWidget);

    await tester.tap(find.text('7 hari'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada post berlabel sentimen.'), findsOneWidget);
  });

  testWidgets('CommunityStockSentiment disappears when trending is turned off', (tester) async {
    final features = FakeFeatureDependencies(config: loadedConfig(flags: {'trending': false}));
    addTearDown(features.dispose);
    await pumpFeatureApp(tester, const CommunityStockSentiment(stockCode: 'BBCA'), features: features);
    await tester.pumpAndSettle();
    expect(find.byType(SentimentBar), findsNothing);
    expect(find.text('Sentimen komunitas'), findsNothing);
  });
}
