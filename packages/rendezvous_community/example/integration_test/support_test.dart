import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rendezvous_community_example/main.dart';

const _shots = String.fromEnvironment('SUPPORT_SHOTS');

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Tidak menemukan $finder dalam $timeout');
}

Future<void> pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finders.any((f) => f.evaluate().isNotEmpty)) return;
  }
  throw TestFailure('Tidak menemukan $finders dalam $timeout');
}

Future<void> capture(WidgetTester tester, String name) async {
  if (_shots.isEmpty) return;
  await tester.pump(const Duration(milliseconds: 300));
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: view.flutterView.devicePixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_shots/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows: support chat in a side panel while the main screen stays visible', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await pumpUntilFound(tester, find.text('Rina Kartika'));
    await tester.tap(find.text('Rina Kartika'));
    await pumpUntilFound(tester, find.text('Bantuan'));

    await tester.tap(find.text('Bantuan').last);
    await pumpUntilAny(tester, [find.text('Apa yang bisa kami bantu?'), find.textContaining('#CS-')]);
    await capture(tester, 'windows-01-panel');

    if (find.text('Apa yang bisa kami bantu?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Aplikasi/Teknis'));
      await pumpUntilFound(tester, find.textContaining('Menunggu CS'));
    }
    await capture(tester, 'windows-02-ticket');

    final composer = find.widgetWithText(TextField, 'Tulis pesan…');
    await tester.tap(composer);
    await tester.enterText(composer, 'Aplikasi Windows saya tidak bisa membuka grafik.');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpUntilFound(tester, find.text('Aplikasi Windows saya tidak bisa membuka grafik.'));

    await tester.enterText(composer, 'PIN saya 123456');
    await pumpUntilFound(tester, find.textContaining('akan disamarkan'));
    await capture(tester, 'windows-03-chat');
    await tester.enterText(composer, '');
    await tester.pump(const Duration(seconds: 1));
  });
}
