import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../support/fakes.dart';

Future<void> _pump(WidgetTester tester, CommunityCallbacks callbacks) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: CommunityLocalizations.localizationsDelegates,
    supportedLocales: CommunityLocalizations.supportedLocales,
    home: CommunityScope(
      dependencies: FakeDependencies(callbacks: callbacks),
      child: Scaffold(
        body: CommunityComposerField(controller: TextEditingController(), hintText: 'Tulis'),
      ),
    ),
  ),
);

void main() {
  testWidgets(r'saran $KODE berasal dari pencarian milik app klien', (tester) async {
    final queries = <String>[];
    await _pump(
      tester,
      CommunityCallbacks(
        stockSearch: (query) async {
          queries.add(query);
          return const [StockSuggestion(code: 'BBCA', name: 'Bank Central Asia Tbk'), StockSuggestion(code: 'BBRI')];
        },
      ),
    );

    await tester.enterText(find.byType(TextField), r'Akumulasi $bb');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(queries, ['bb']);
    expect(find.text(r'$BBCA'), findsOneWidget);
    expect(find.text('Bank Central Asia Tbk'), findsOneWidget);
    expect(find.text(r'$BBRI'), findsOneWidget);

    await tester.tap(find.text(r'$BBCA'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, r'Akumulasi $BBCA ');
  });

  testWidgets(r'tanpa pencarian dari app, $KODE tetap bisa diketik tanpa saran', (tester) async {
    await _pump(tester, const CommunityCallbacks());

    await tester.enterText(find.byType(TextField), r'$bb');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byType(ListTile), findsNothing);
  });
}
