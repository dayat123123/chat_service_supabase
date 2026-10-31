import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social_example/main.dart';

void main() {
  testWidgets('tanpa anon key menampilkan petunjuk konfigurasi', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.textContaining('OLT_SOCIAL_ANON_KEY'), findsOneWidget);
  });
}
