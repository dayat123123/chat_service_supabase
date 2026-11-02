import 'package:freezed_annotation/freezed_annotation.dart';

part 'poll.freezed.dart';

enum PollDuration {
  oneHour(60),
  sixHours(360),
  oneDay(1440),
  threeDays(4320),
  sevenDays(10080);

  const PollDuration(this.minutes);
  final int minutes;
}

@freezed
abstract class PollOption with _$PollOption {
  const factory PollOption({required String id, required String label, int? votes}) = _PollOption;
}

@freezed
abstract class Poll with _$Poll {
  const factory Poll({
    required DateTime endsAt,
    required bool closed,
    required int totalVotes,
    String? myOptionId,
    required bool resultsVisible,
    required List<PollOption> options,
  }) = _Poll;

  const Poll._();

  bool get hasVoted => myOptionId != null;

  bool isClosedAt(DateTime now) => closed || !now.isBefore(endsAt);

  double share(PollOption option) {
    final votes = option.votes;
    if (votes == null || totalVotes == 0) return 0;
    return votes / totalVotes;
  }

  String? get leadingOptionId {
    if (!resultsVisible || totalVotes == 0) return null;
    PollOption? best;
    for (final option in options) {
      if ((option.votes ?? 0) > (best?.votes ?? -1)) best = option;
    }
    return best?.id;
  }
}

@freezed
abstract class PollDraft with _$PollDraft {
  const factory PollDraft({
    @Default(<String>['', '']) List<String> options,
    @Default(PollDuration.oneDay) PollDuration duration,
  }) = _PollDraft;

  const PollDraft._();

  static const minOptions = 2;
  static const maxOptions = 4;
  static const maxOptionLength = 40;

  List<String> get cleanOptions => [for (final o in options) o.trim()];

  bool get isValid {
    final clean = cleanOptions;
    if (clean.length < minOptions || clean.length > maxOptions) return false;
    if (clean.any((o) => o.isEmpty || o.length > maxOptionLength)) return false;
    return clean.map((o) => o.toLowerCase()).toSet().length == clean.length;
  }
}
