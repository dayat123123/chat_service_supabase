import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import '../../../support/fakes.dart';

Poll poll({String? mine, bool visible = false, int total = 0}) => Poll(
  endsAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
  closed: false,
  totalVotes: total,
  myOptionId: mine,
  resultsVisible: visible,
  options: [
    PollOption(id: 'a', label: 'Naik', votes: visible ? 3 : null),
    PollOption(id: 'b', label: 'Turun', votes: visible ? 1 : null),
  ],
);

Future<FakeDependencies> pumpPoll(WidgetTester tester, Poll value, {bool canVote = true}) async {
  final deps = FakeDependencies();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      home: CommunityScope(
        dependencies: deps,
        child: Scaffold(
          body: CommunityPollView(postId: 'p-1', poll: value, canVote: canVote),
        ),
      ),
    ),
  );
  return deps;
}

void main() {
  testWidgets('shows option buttons without percentages before voting', (tester) async {
    await pumpPoll(tester, poll());
    expect(find.widgetWithText(OutlinedButton, 'Naik'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('Belum ada suara'), findsOneWidget);
  });

  testWidgets('voting submits the vote and then shows results and my choice', (tester) async {
    final deps = await pumpPoll(tester, poll());
    deps.polls.onVote = (_, optionId) => poll(mine: optionId, visible: true, total: 4);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Turun'));
    await tester.pump();
    await tester.pump();

    expect(deps.polls.votes, [('p-1', 'b')]);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.textContaining('4 suara'), findsOneWidget);
  });

  testWidgets('a failed vote shows an error message and keeps the buttons', (tester) async {
    final deps = await pumpPoll(tester, poll());
    deps.polls.error = const CommunityException(CommunityErrorKind.invalidInput, code: 'poll_closed');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Naik'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Polling sudah berakhir.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Naik'), findsOneWidget);
  });

  testWidgets('the poll author sees results immediately without buttons', (tester) async {
    await pumpPoll(tester, poll(visible: true, total: 4), canVote: false);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('75%'), findsOneWidget);
  });
}
