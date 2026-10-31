import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';

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
    localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
    supportedLocales: OltSocialLocalizations.supportedLocales,
    home: OltSocialScope(
      dependencies: FakeDependencies(feed: _EmptyFeed(), stocks: stocks),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('nama saham datang dari app klien, jumlah pemantau dari server', (tester) async {
    final stocks = _FakeStocks();
    await _pump(tester, stocks, const OltStockFeed(stockCode: 'bbca', stockName: 'Bank Central Asia Tbk'));
    await tester.pumpAndSettle();

    expect(find.text(r'$BBCA'), findsOneWidget);
    expect(find.text('Bank Central Asia Tbk · 2 pemantau'), findsOneWidget);

    await tester.tap(find.text('Pantau'));
    await tester.pumpAndSettle();

    expect(stocks.watched, ['BBCA']);
    expect(find.text('Bank Central Asia Tbk · 3 pemantau'), findsOneWidget);
    expect(find.text('Dipantau'), findsOneWidget);
  });

  testWidgets('tanpa nama dari app, header hanya menampilkan kode dan pemantau', (tester) async {
    await _pump(tester, _FakeStocks(), const OltStockFeed(stockCode: 'NEWCO'));
    await tester.pumpAndSettle();

    expect(find.text(r'$NEWCO'), findsOneWidget);
    expect(find.text('2 pemantau'), findsOneWidget);
  });
}
