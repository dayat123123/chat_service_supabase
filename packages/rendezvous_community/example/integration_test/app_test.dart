import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community_example/main.dart';

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

Future<void> pumpUntilGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('$finder masih ada setelah $timeout');
}

Future<void> pumpUntilFoundWhileScrolling(
  WidgetTester tester,
  Finder finder,
  Finder scrollable, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(scrollable, const Offset(0, -300));
  }
  throw TestFailure('Tidak menemukan $finder dalam $timeout');
}

Future<void> typeAndPressEnter(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login, feed, comment thread, commenting, and chat with Enter', (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(const ExampleApp());
    await pumpUntilFound(tester, find.text('Budi Santoso'));

    await tester.tap(find.text('Budi Santoso'));
    await pumpUntilFound(
      tester,
      find.descendant(of: find.byType(CommunityStreamFeed), matching: find.byIcon(Icons.mode_comment_outlined)),
    );

    final seedPost = find.textContaining('tembus resistance');
    await tester.scrollUntilVisible(
      seedPost,
      300,
      scrollable: find.descendant(of: find.byType(CommunityStreamFeed), matching: find.byType(Scrollable)).first,
    );

    await tester.ensureVisible(seedPost.first);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(seedPost.first);
    await pumpUntilFound(tester, find.textContaining('Divergence itu maksudnya'));
    expect(find.text('Konten ini opini pengguna, bukan rekomendasi investasi.'), findsWidgets);
    final thread = find.descendant(of: find.byType(CommunityPostDetail), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Lanjutkan thread →'), 200, scrollable: thread);

    final commentText = 'Komentar e2e $stamp';
    await typeAndPressEnter(tester, find.widgetWithText(TextField, 'Tulis komentar…'), commentText);
    await pumpUntilFoundWhileScrolling(tester, find.text(commentText), thread);

    await tester.tap(find.text('Chat').first);
    await pumpUntilFound(tester, find.text('Sari Wulandari'));
    await tester.tap(find.text('Sari Wulandari'));
    final messageField = find.widgetWithText(TextField, 'Tulis pesan…');
    await pumpUntilFound(tester, messageField);
    final messageText = 'Pesan e2e $stamp';
    await typeAndPressEnter(tester, messageField, messageText);
    await pumpUntilFound(tester, find.text(messageText));
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate((w) => w is Icon && (w.icon == Icons.done || w.icon == Icons.done_all)),
    );

    await tester.tap(find.text('Notifikasi').first);
    await pumpUntilFound(tester, find.text('Tandai semua dibaca'));

    await tester.tap(find.text('Saham').first);
    await pumpUntilFound(tester, find.text(r'$BBCA'));
    await pumpUntilFound(tester, find.text('Dipantau'));
    await tester.tap(find.text('Dipantau'));
    await pumpUntilFound(tester, find.text('Pantau'));
    await tester.tap(find.text('Pantau'));
    await pumpUntilFound(tester, find.text('Dipantau'));

    await tester.tap(find.text('Profil').first);
    await pumpUntilFound(tester, find.text('Ubah profil'));

    await tester.tap(find.text('Stream').first);
    final prompt = find.text('Apa pendapat Anda tentang pasar hari ini?');
    await pumpUntilFound(tester, prompt);
    await tester.tap(prompt.first);
    final composer = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await pumpUntilFound(tester, composer);
    await typeAndPressEnter(tester, composer, 'Post e2e $stamp \$BBCA ');
    await pumpUntilGone(tester, find.byType(Dialog));
    await pumpUntilFound(
      tester,
      find.descendant(of: find.byType(CommunityStreamFeed), matching: find.textContaining('Post e2e $stamp')),
    );
  });
}
