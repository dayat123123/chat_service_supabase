import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community_example/main.dart';

const _enabled = bool.fromEnvironment('OLT_DUMMY_E2E');

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Tidak menemukan $finder dalam $timeout');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dummy OLT login form: a wrong password is rejected and email + password signs in', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    final button = find.text('Masuk via OLT dummy');
    await pumpUntilFound(tester, button);
    await tester.ensureVisible(button);

    final identifier = find.widgetWithText(TextField, 'Username / email');
    final password = find.widgetWithText(TextField, 'Password');

    await tester.enterText(password, 'salah');
    await tester.tap(button);
    await pumpUntilFound(tester, find.textContaining('password salah'));
    expect(button, findsOneWidget);

    await tester.enterText(identifier, 'sari@olt.test');
    await tester.enterText(password, 'olt12345');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpUntilFound(tester, find.byType(CommunityStreamFeed));

    await tester.tap(find.text('Profil').first);
    await pumpUntilFound(tester, find.text('@sari_invest'));
  }, skip: !_enabled);
}
