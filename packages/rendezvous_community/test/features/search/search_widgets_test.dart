import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';

void main() {
  testWidgets('CommunitySearch shows trending hashtags first, then sectioned results', (tester) async {
    final features = FakeFeatureDependencies(config: loadedConfig());
    addTearDown(features.dispose);
    features.search
      ..trending = const [HashtagSummary(tag: 'ipo', postCount: 3)]
      ..answer = (query, type, cursor) => SearchResults(
        query: query,
        type: type,
        users: const [UserSearchResult(user: alice, followerCount: 5)],
        stocks: const [StockSearchResult(code: 'BBCA', posts7d: 4, watcherCount: 2)],
        hashtags: const [HashtagSummary(tag: 'bbca', postCount: 2)],
      );
    await pumpFeatureApp(tester, const CommunitySearch(), features: features);
    await tester.pumpAndSettle();
    expect(find.text('Hashtag trending'), findsOneWidget);
    expect(find.text('ipo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bbca');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(features.search.queries.single.$1, 'bbca');
    expect(find.text('\$BBCA'), findsOneWidget);
    expect(find.text('#bbca'), findsOneWidget);
    expect(find.text('Lihat semua'), findsNWidgets(3));

    await tester.tap(find.text('Lihat semua').first);
    await tester.pumpAndSettle();
    expect(features.search.queries.last.$2, SearchType.users);
  });

  testWidgets('CommunityTrending switches tabs and windows', (tester) async {
    final features = FakeFeatureDependencies(config: loadedConfig());
    addTearDown(features.dispose);
    features.trending.snapshot = (window) => TrendingSnapshot(
      window: window,
      stocks: [
        TrendingStock(code: window == TrendWindow.day ? 'BBCA' : 'TLKM', posts: 12, bullishPct: 70, bearishPct: 20),
      ],
      rising: const [RisingStock(code: 'GOTO', posts: 9, prevPosts: 2, growthPct: 350)],
      hashtags: const [HashtagSummary(tag: 'dividen', postCount: 4)],
    );
    await pumpFeatureApp(tester, const CommunityTrending(), features: features);
    await tester.pumpAndSettle();
    expect(find.text('\$BBCA'), findsOneWidget);

    await tester.tap(find.text('7 hari'));
    await tester.pumpAndSettle();
    expect(find.text('\$TLKM'), findsOneWidget);

    await tester.tap(find.text('Naik daun'));
    await tester.pumpAndSettle();
    expect(find.text('\$GOTO'), findsOneWidget);
    expect(find.text('+350%'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hashtag'));
    await tester.pumpAndSettle();
    expect(find.text('#dividen'), findsOneWidget);
  });
}
