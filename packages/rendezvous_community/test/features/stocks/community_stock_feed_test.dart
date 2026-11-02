import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../support/fakes.dart';

class _FakeStocks implements StockRepository {
  final watched = <String>[];

  @override
  Future<Stock?> getStock(String code) async => Stock(code: code.toUpperCase(), watcherCount: 2);

  @override
  Future<void> watch(String code) async => watched.add(code);

  @override
  Future<void> unwatch(String code) async => watched.remove(code);
}

class _EmptyFeed extends FakeFeedRepository {
  @override
  Future<Paged<Post>> getFeed(FeedScope scope, {String? cursor, int limit = 20}) async => const Paged.empty();
}

Future<void> _pump(WidgetTester tester, StockRepository stocks, Widget child) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: CommunityLocalizations.localizationsDelegates,
    supportedLocales: CommunityLocalizations.supportedLocales,
    home: CommunityScope(
      dependencies: FakeDependencies(feed: _EmptyFeed(), stocks: stocks),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('the stock name comes from the client app and the watcher count from the server', (tester) async {
    final stocks = _FakeStocks();
    await _pump(tester, stocks, const CommunityStockFeed(stockCode: 'bbca', stockName: 'Bank Central Asia Tbk'));
    await tester.pumpAndSettle();

    expect(find.text(r'$BBCA'), findsOneWidget);
    expect(find.text('Bank Central Asia Tbk · 2 pemantau'), findsOneWidget);

    await tester.tap(find.text('Pantau'));
    await tester.pumpAndSettle();

    expect(stocks.watched, ['BBCA']);
    expect(find.text('Bank Central Asia Tbk · 3 pemantau'), findsOneWidget);
    expect(find.text('Dipantau'), findsOneWidget);
  });

  testWidgets('without an app-provided name, the header shows only the code and watchers', (tester) async {
    await _pump(tester, _FakeStocks(), const CommunityStockFeed(stockCode: 'NEWCO'));
    await tester.pumpAndSettle();

    expect(find.text(r'$NEWCO'), findsOneWidget);
    expect(find.text('2 pemantau'), findsOneWidget);
  });
}
