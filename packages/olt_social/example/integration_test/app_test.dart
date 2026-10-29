// End-to-end: app example sungguhan + stack Docker lokal (make up && make seed).
//
//   flutter test integration_test -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY>
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social_example/main.dart';

/// pumpAndSettle tidak pernah selesai selama ada animasi berulang / realtime,
/// jadi tunggu sampai [finder] muncul.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
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

Future<void> typeAndPressEnter(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login, feed, thread komentar, komentar & chat dengan Enter', (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(const ExampleApp());
    await pumpUntilFound(tester, find.text('Budi Santoso'));

    // Login OLT (mock) -> auth-bridge -> JWT Supabase. Feed tampil dengan minimal
    // satu kartu post. Isi teratas berubah-ubah (post baru dari tes lain), jadi
    // tidak menunggu post tertentu.
    await tester.tap(find.text('Budi Santoso'));
    await pumpUntilFound(
      tester,
      find.descendant(of: find.byType(OltStreamFeed), matching: find.byIcon(Icons.mode_comment_outlined)),
    );

    // Post seed tertua ada di bawah; scroll feed (memicu infinite scroll bila perlu).
    final seedPost = find.textContaining('tembus resistance');
    await tester.scrollUntilVisible(
      seedPost,
      300,
      scrollable: find.descendant(of: find.byType(OltStreamFeed), matching: find.byType(Scrollable)).first,
    );

    // Pastikan seluruh kartu terlihat (bukan hanya sebagian) sebelum diketuk.
    await tester.ensureVisible(seedPost.first);
    await tester.pump(const Duration(milliseconds: 300));

    // Desktop: detail post terbuka di panel kanan.
    await tester.tap(seedPost.first);
    await pumpUntilFound(tester, find.textContaining('Divergence itu maksudnya'));
    expect(find.text('Konten ini opini pengguna, bukan rekomendasi investasi.'), findsWidgets);
    // Balasan level 5 berada di balik batas indentasi -> tombol "Lanjutkan thread".
    await tester.scrollUntilVisible(
      find.text('Lanjutkan thread →'),
      200,
      scrollable: find.descendant(of: find.byType(OltPostDetail), matching: find.byType(Scrollable)).first,
    );

    // Komentar baru dikirim dengan Enter (desktop).
    final commentText = 'Komentar e2e $stamp';
    await typeAndPressEnter(tester, find.widgetWithText(TextField, 'Tulis komentar…'), commentText);
    await pumpUntilFound(tester, find.text(commentText));

    // Chat: DM dengan Sari, kirim pesan dengan Enter.
    await tester.tap(find.text('Chat').first);
    await pumpUntilFound(tester, find.text('Sari Wulandari'));
    await tester.tap(find.text('Sari Wulandari'));
    final messageField = find.widgetWithText(TextField, 'Tulis pesan…');
    await pumpUntilFound(tester, messageField);
    final messageText = 'Pesan e2e $stamp';
    await typeAndPressEnter(tester, messageField, messageText);
    await pumpUntilFound(tester, find.text(messageText));
    // Status berubah dari "mengirim" (jam) menjadi terkirim/dibaca.
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate((w) => w is Icon && (w.icon == Icons.done || w.icon == Icons.done_all)),
    );

    // Notifikasi.
    await tester.tap(find.text('Notifikasi').first);
    await pumpUntilFound(tester, find.text('Tandai semua dibaca'));

    // Halaman saham: header + pantau/berhenti pantau (optimistic), kembalikan ke semula.
    await tester.tap(find.text('Saham').first);
    await pumpUntilFound(tester, find.text(r'$BBCA'));
    await pumpUntilFound(tester, find.text('Dipantau'));
    await tester.tap(find.text('Dipantau'));
    await pumpUntilFound(tester, find.text('Pantau'));
    await tester.tap(find.text('Pantau'));
    await pumpUntilFound(tester, find.text('Dipantau'));

    // Profil sendiri.
    await tester.tap(find.text('Profil').first);
    await pumpUntilFound(tester, find.text('Ubah profil'));

    // Compose post (dialog di desktop), kirim dengan Enter, muncul di feed.
    await tester.tap(find.text('Stream').first);
    final prompt = find.text('Apa pendapat Anda tentang pasar hari ini?');
    await pumpUntilFound(tester, prompt);
    await tester.tap(prompt.first);
    final composer = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await pumpUntilFound(tester, composer);
    await typeAndPressEnter(tester, composer, 'Post e2e $stamp \$BBCA ');
    await pumpUntilGone(tester, find.byType(Dialog)); // terkirim -> dialog tertutup
    await pumpUntilFound(
      tester,
      find.descendant(of: find.byType(OltStreamFeed), matching: find.textContaining('Post e2e $stamp')),
    );
  });
}
