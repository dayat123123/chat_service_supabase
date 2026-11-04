import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/gap_horizon.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/message_gap_fill.dart';

import '../../../support/fakes.dart';

void main() {
  final start = DateTime.utc(2026, 11, 4, 9);

  ChatMessage at(int second, [String? id]) => ChatMessage(
    id: id ?? 'm-${second.toString().padLeft(3, '0')}',
    roomId: 'r',
    senderId: alice.id,
    body: 'Isi $second',
    createdAt: start.add(Duration(seconds: second)),
  );

  final stream = [
    for (final s in [0, 10, 20, 25, 30, 40, 50]) at(s),
  ];
  Set<String> knownExcept(Iterable<String> missing) => {
    for (final m in stream)
      if (!missing.contains(m.id)) m.id,
  };

  group('with a message index', () {
    late IndexedFakeChatRepository chat;

    setUp(() => chat = IndexedFakeChatRepository(messages: stream));

    test('fills a hole far behind the newest live message and advances the horizon to the newest server row', () async {
      final fill = MessageGapFill(chat, 'r', overlap: const Duration(seconds: 3));

      final result = await fill.run(GapHorizon.of(at(10)), known: () => knownExcept(['m-025']));

      final filled = result as GapFilled;
      expect(filled.messages.map((m) => m.id), ['m-025']);
      expect(filled.horizon.id, 'm-050');
      expect(chat.idCursors.single, startsWith('2026-11-04T09:00:07.000Z|'));
      expect(chat.idRequests.single, ['m-025']);
      expect(chat.afterCursors, isEmpty);
    });

    test('asks for nothing when every row is already known', () async {
      final result = await MessageGapFill(chat, 'r').run(GapHorizon.of(at(10)), known: () => knownExcept(const []));

      expect((result as GapFilled).messages, isEmpty);
      expect(result.horizon.id, 'm-050');
      expect(chat.idRequests, isEmpty);
    });

    test('pages through the index and stops at the page budget', () async {
      final paged = MessageGapFill(chat, 'r', idPageSize: 2, overlap: Duration.zero);
      final filled = await paged.run(GapHorizon.of(at(0)), known: () => {'m-000'}) as GapFilled;
      expect(chat.idCursors, hasLength(4));
      expect(filled.messages.map((m) => m.id).toSet(), {'m-010', 'm-020', 'm-025', 'm-030', 'm-040', 'm-050'});

      final short = MessageGapFill(chat, 'r', idPageSize: 2, maxPages: 2, overlap: Duration.zero);
      expect(await short.run(GapHorizon.of(at(0)), known: () => {'m-000'}), isA<GapTooLong>());
    });

    test('fetches missing rows in batches and gives up when more are missing than the budget allows', () async {
      final batched = MessageGapFill(chat, 'r', idBatchSize: 2, overlap: Duration.zero);
      await batched.run(GapHorizon.of(at(0)), known: () => {'m-000'});
      expect(chat.idRequests.map((ids) => ids.length), [2, 2, 2]);

      final tight = MessageGapFill(chat, 'r', idBatchSize: 2, maxPages: 2, overlap: Duration.zero);
      expect(await tight.run(GapHorizon.of(at(0)), known: () => {'m-000'}), isA<GapTooLong>());
    });

    test('starts at the oldest loaded message when the overlap reaches further back', () async {
      await MessageGapFill(
        chat,
        'r',
        overlap: const Duration(minutes: 5),
      ).run(GapHorizon.of(at(40)), floor: GapHorizon.of(at(20)), known: () => knownExcept(const []));

      expect(chat.idCursors.single, messageCursor(at(20)));
    });

    test('falls back to paged fetches for good when the backend has no message index yet', () async {
      chat.indexError = const CommunityException(CommunityErrorKind.unknown, code: 'PGRST202');
      final fill = MessageGapFill(chat, 'r', overlap: Duration.zero);

      final first = await fill.run(GapHorizon.of(at(40)), known: () => knownExcept(const []));
      await fill.run(GapHorizon.of(at(40)), known: () => knownExcept(const []));

      expect((first as GapFilled).horizon.id, 'm-050');
      expect(chat.idCursors, hasLength(1));
      expect(chat.afterCursors, hasLength(2));
    });

    test('lets other index errors through so the next catch-up retries', () async {
      chat.indexError = const CommunityException(CommunityErrorKind.network);
      final fill = MessageGapFill(chat, 'r');

      await expectLater(fill.run(GapHorizon.of(at(40)), known: () => const {}), throwsA(isA<CommunityException>()));
      chat.indexError = null;
      await fill.run(GapHorizon.of(at(40)), known: () => knownExcept(const []));

      expect(chat.idCursors, hasLength(2));
      expect(chat.afterCursors, isEmpty);
    });

    test('keeps the horizon when the index has nothing newer', () async {
      final result = await MessageGapFill(
        chat,
        'r',
        overlap: Duration.zero,
      ).run(GapHorizon.of(at(50)), known: () => knownExcept(const []));

      expect((result as GapFilled).horizon.id, 'm-050');
    });
  });

  group('without a message index', () {
    late FakeChatRepository chat;

    setUp(() => chat = FakeChatRepository(messages: stream));

    test('fetches every row after the horizon minus the overlap and advances to the newest', () async {
      final result = await MessageGapFill(
        chat,
        'r',
        overlap: const Duration(seconds: 3),
      ).run(GapHorizon.of(at(10)), known: () => knownExcept(['m-025']));

      final filled = result as GapFilled;
      expect(filled.messages.map((m) => m.id), containsAll(['m-010', 'm-020', 'm-025', 'm-050']));
      expect(filled.horizon.id, 'm-050');
      expect(chat.afterCursors.single, startsWith('2026-11-04T09:00:07.000Z|'));
    });

    test('reports a catch-up longer than the page budget', () async {
      final result = await MessageGapFill(
        chat,
        'r',
        maxPages: 2,
        afterPageSize: 2,
        overlap: Duration.zero,
      ).run(GapHorizon.of(at(0)), known: () => const {});

      expect(result, isA<GapTooLong>());
    });
  });

  test('horizons order by time and then id', () {
    final a = GapHorizon.of(at(10, 'a'));
    final b = GapHorizon.of(at(10, 'b'));
    expect(b.isAfter(a), isTrue);
    expect(a.later(b), same(b));
    expect(b.later(a), same(b));
    expect(a.later(null), same(a));
    expect(GapHorizon.parse(messageCursor(at(10, 'a')))!.isAfter(a), isFalse);
    expect(GapHorizon.parse('rusak'), isNull);
    expect(a.back(const Duration(seconds: 10)).cursor, '2026-11-04T09:00:00.000Z|$zeroMessageId');
    expect(a.back(Duration.zero), same(a));
  });
}
