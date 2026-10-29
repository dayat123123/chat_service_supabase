// E2E: login lewat form OLT dummy (WebSocket) di app contoh -> fitur sosial.
// Dilewati kecuali --dart-define=OLT_DUMMY_E2E=true (stack: make up DUMMY_OLT=1).
//
//   flutter test integration_test/dummy_olt_login_test.dart -d windows \
//     --dart-define=OLT_DUMMY_E2E=true --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social_example/main.dart';

const _enabled = bool.fromEnvironment('OLT_DUMMY_E2E');

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Tidak menemukan $finder dalam $timeout');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('form login OLT dummy: password salah ditolak, email + password masuk', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    final button = find.text('Masuk via OLT dummy');
    await pumpUntilFound(tester, button);
    await tester.ensureVisible(button);

    final identifier = find.widgetWithText(TextField, 'Username / email');
    final password = find.widgetWithText(TextField, 'Password');

    // Password salah: OLT dummy menolak, tetap di halaman login.
    await tester.enterText(password, 'salah');
    await tester.tap(button);
    await pumpUntilFound(tester, find.textContaining('password salah'));
    expect(button, findsOneWidget);

    // Login dengan email + password -> token OLT dummy -> auth-bridge -> feed.
    await tester.enterText(identifier, 'sari@olt.test');
    await tester.enterText(password, 'olt12345');
    await tester.ensureVisible(button);
    await tester.tap(button);
    // Feed sosial tampil. Isi feed berubah-ubah (post baru dari tes lain), jadi
    // tidak menunggu post tertentu.
    await pumpUntilFound(tester, find.byType(OltStreamFeed));

    // Identitas sosial = user seed Sari.
    await tester.tap(find.text('Profil').first);
    await pumpUntilFound(tester, find.text('@sari_invest'));
  }, skip: !_enabled);
}
