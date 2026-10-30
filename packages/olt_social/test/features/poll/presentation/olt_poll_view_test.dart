import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';

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
      localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
      supportedLocales: OltSocialLocalizations.supportedLocales,
      home: OltSocialScope(
        dependencies: deps,
        child: Scaffold(body: OltPollView(postId: 'p-1', poll: value, canVote: canVote)),
      ),
    ),
  );
  return deps;
}

void main() {
  testWidgets('sebelum memilih tampil tombol pilihan tanpa persentase', (tester) async {
    await pumpPoll(tester, poll());
    expect(find.widgetWithText(OutlinedButton, 'Naik'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('Belum ada suara'), findsOneWidget);
  });

  testWidgets('memilih mengirim suara lalu menampilkan hasil dan pilihan saya', (tester) async {
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

  testWidgets('gagal memilih menampilkan pesan error dan tombol tetap ada', (tester) async {
    final deps = await pumpPoll(tester, poll());
    deps.polls.error = const OltSocialException(OltSocialErrorKind.invalidInput, code: 'poll_closed');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Naik'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Polling sudah berakhir.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Naik'), findsOneWidget);
  });

  testWidgets('pembuat polling langsung melihat hasil tanpa tombol', (tester) async {
    await pumpPoll(tester, poll(visible: true, total: 4), canVote: false);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('75%'), findsOneWidget);
  });
}
