import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:olt_social/src/features/post/presentation/cubit/comment_thread_cubit.dart';
import 'package:olt_social/src/features/post/presentation/widgets/comment_tree.dart';

import '../../../support/fakes.dart';

Future<FakeDependencies> pumpDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final deps = FakeDependencies();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
      supportedLocales: OltSocialLocalizations.supportedLocales,
      home: OltSocialScope(
        dependencies: deps,
        child: const Scaffold(body: OltPostDetail(postId: 'p-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return deps;
}

int threadLevelOf(WidgetTester tester, String text) {
  final paint = tester.widget<CustomPaint>(
    find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ThreadLinesPainter)).first,
  );
  return (paint.painter! as ThreadLinesPainter).level;
}

void main() {
  testWidgets('menampilkan thread bertingkat dengan garis indentasi', (tester) async {
    await pumpDetail(tester);

    expect(find.textContaining('Analisis'), findsOneWidget);
    expect(find.text('Konten ini opini pengguna, bukan rekomendasi investasi.'), findsOneWidget);
    expect(threadLevelOf(tester, 'Level 1'), 0);
    expect(threadLevelOf(tester, 'Level 2'), 1);
    expect(threadLevelOf(tester, 'Level 3'), 2);
    expect(threadLevelOf(tester, 'Level 4'), 3);
    expect(threadLevelOf(tester, 'Top kedua'), 0);
  });

  testWidgets('indentasi berhenti di level 4 dan muncul "Lanjutkan thread"', (tester) async {
    await pumpDetail(tester);
    expect(find.text('Lanjutkan thread →'), findsOneWidget);
  });

  testWidgets('komentar terhapus tampil sebagai [komentar dihapus]', (tester) async {
    await pumpDetail(tester);
    expect(find.text('[komentar dihapus]'), findsOneWidget);
  });

  testWidgets('"Lihat N balasan lainnya" memuat balasan berikutnya dari cursor terakhir', (tester) async {
    final deps = await pumpDetail(tester);

    expect(find.text('Lihat 1 balasan lainnya'), findsOneWidget);
    await tester.tap(find.text('Lihat 1 balasan lainnya'));
    await tester.pumpAndSettle();

    expect(find.text('Balasan C'), findsOneWidget);
    expect(find.text('Lihat 1 balasan lainnya'), findsNothing);
    expect(threadLevelOf(tester, 'Balasan C'), 1);
    expect(deps.comments.requests.last, {'root': 'c1', 'cursor': '000000000006', 'maxDepth': 2});
  });

  testWidgets('collapse menyembunyikan cabang, expand menampilkannya lagi', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Ciutkan').first);
    await tester.pumpAndSettle();
    expect(find.text('Level 2'), findsNothing);
    expect(find.text('3 balasan disembunyikan'), findsOneWidget);
    expect(find.text('Top kedua'), findsOneWidget);

    await tester.tap(find.byTooltip('Bentangkan'));
    await tester.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('like komentar langsung terlihat (optimistic)', (tester) async {
    final deps = await pumpDetail(tester);

    final topKedua = find.ancestor(of: find.text('Top kedua'), matching: find.byType(CommentTile));
    await tester.tap(find.descendant(of: topKedua, matching: find.text('Suka')));
    await tester.pump();

    expect(find.descendant(of: topKedua, matching: find.text('1')), findsOneWidget);
    expect(deps.comments.likedComments, ['t2']);
  });

  testWidgets('tombol Balas menampilkan target balasan di composer', (tester) async {
    await pumpDetail(tester);

    final level2 = find.ancestor(of: find.text('Level 2'), matching: find.byType(CommentTile));
    await tester.tap(find.descendant(of: level2, matching: find.text('Balas')));
    await tester.pumpAndSettle();

    expect(find.text('Membalas Bob'), findsOneWidget);
  });

  test('buildThreadRows: batas level, sisa balasan, dan komentar teratas berikutnya', () {
    final comments = {
      for (final c in [
        comment('a', depth: 0, path: '1', replyCount: 2),
        comment('b', parentId: 'a', depth: 1, path: '1.2', replyCount: 1),
        comment('c', parentId: 'b', depth: 2, path: '1.2.3'),
      ])
        c.id: c,
    };
    final state = ThreadState(
      comments: comments,
      children: const {
        topLevelKey: ['a'],
        'a': ['b'],
        'b': ['c'],
      },
      hasMoreTop: true,
    );

    final rows = buildThreadRows(state, maxLevels: 2);
    expect(rows.map((r) => r.runtimeType), [CommentRow, CommentRow, ContinueThreadRow, MoreRepliesRow, MoreTopLevelRow]);
    expect((rows[3] as MoreRepliesRow).remaining, 1);
    expect(rows.map((r) => r.level).toList(), [0, 1, 2, 1, 0]);
  });
}
