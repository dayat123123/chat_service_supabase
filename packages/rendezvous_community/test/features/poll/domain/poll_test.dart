import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/src/features/poll/domain/entities/poll.dart';

void main() {
  group('PollDraft', () {
    test('draf baru belum valid karena pilihan masih kosong', () {
      expect(const PollDraft().isValid, isFalse);
    });

    test('2 sampai 4 pilihan berbeda valid', () {
      expect(const PollDraft(options: ['Naik', 'Turun']).isValid, isTrue);
      expect(const PollDraft(options: ['A', 'B', 'C', 'D']).isValid, isTrue);
    });

    test('pilihan kembar, kosong, terlalu panjang, atau terlalu banyak ditolak', () {
      expect(const PollDraft(options: ['Naik', ' naik ']).isValid, isFalse);
      expect(const PollDraft(options: ['Naik', '  ']).isValid, isFalse);
      expect(PollDraft(options: ['Naik', 'x' * 41]).isValid, isFalse);
      expect(const PollDraft(options: ['A', 'B', 'C', 'D', 'E']).isValid, isFalse);
      expect(const PollDraft(options: ['A']).isValid, isFalse);
    });

    test('cleanOptions memangkas spasi', () {
      expect(const PollDraft(options: [' Naik ', 'Turun']).cleanOptions, ['Naik', 'Turun']);
    });
  });

  group('Poll', () {
    final endsAt = DateTime.utc(2026, 10, 30);
    final poll = Poll(
      endsAt: endsAt,
      closed: false,
      totalVotes: 4,
      resultsVisible: true,
      options: const [
        PollOption(id: 'a', label: 'Naik', votes: 3),
        PollOption(id: 'b', label: 'Turun', votes: 1),
      ],
    );

    test('share dan pilihan teratas', () {
      expect(poll.share(poll.options.first), 0.75);
      expect(poll.leadingOptionId, 'a');
    });

    test('tanpa hasil terlihat tidak ada pilihan teratas', () {
      expect(poll.copyWith(resultsVisible: false).leadingOptionId, isNull);
    });

    test('polling dianggap selesai setelah ends_at walau flag closed belum diperbarui', () {
      expect(poll.isClosedAt(endsAt.subtract(const Duration(minutes: 1))), isFalse);
      expect(poll.isClosedAt(endsAt), isTrue);
    });
  });
}
