import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';

void main() {
  group('PollDraft', () {
    test('a new draft is invalid because the options are still empty', () {
      expect(const PollDraft().isValid, isFalse);
    });

    test('2 to 4 distinct options are valid', () {
      expect(const PollDraft(options: ['Naik', 'Turun']).isValid, isTrue);
      expect(const PollDraft(options: ['A', 'B', 'C', 'D']).isValid, isTrue);
    });

    test('rejects duplicate, empty, too long, or too many options', () {
      expect(const PollDraft(options: ['Naik', ' naik ']).isValid, isFalse);
      expect(const PollDraft(options: ['Naik', '  ']).isValid, isFalse);
      expect(PollDraft(options: ['Naik', 'x' * 41]).isValid, isFalse);
      expect(const PollDraft(options: ['A', 'B', 'C', 'D', 'E']).isValid, isFalse);
      expect(const PollDraft(options: ['A']).isValid, isFalse);
    });

    test('cleanOptions trims whitespace', () {
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

    test('share and top option', () {
      expect(poll.share(poll.options.first), 0.75);
      expect(poll.leadingOptionId, 'a');
    });

    test('has no top option when results are hidden', () {
      expect(poll.copyWith(resultsVisible: false).leadingOptionId, isNull);
    });

    test('treats the poll as finished after ends_at even before the closed flag is updated', () {
      expect(poll.isClosedAt(endsAt.subtract(const Duration(minutes: 1))), isFalse);
      expect(poll.isClosedAt(endsAt), isTrue);
    });
  });
}
