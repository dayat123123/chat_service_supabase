import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community_example/main.dart';

void main() {
  testWidgets('shows configuration hints without an anon key', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.textContaining('OLT_SOCIAL_ANON_KEY'), findsOneWidget);
  });
}
