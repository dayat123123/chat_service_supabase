import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:olt_social/src/core/error/error_mapper.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:olt_social/src/shared/presentation/l10n/gen/olt_social_localizations.dart';

export 'gen/olt_social_localizations.dart';

extension OltL10nContext on BuildContext {
  OltSocialLocalizations get oltL10n =>
      OltSocialLocalizations.of(this) ?? lookupOltSocialLocalizations(const Locale('id'));
}

extension OltErrorText on OltSocialLocalizations {
  String errorMessage(Object error) {
    final mapped = mapError(error);
    return switch (mapped.code) {
      'poll_closed' => errorPollClosed,
      'already_voted' => errorAlreadyVoted,
      'own_poll' => errorOwnPoll,
      'invalid_poll' ||
      'invalid_poll_options' ||
      'invalid_poll_option' ||
      'duplicate_poll_option' ||
      'invalid_poll_duration' ||
      'poll_with_attachments' => errorInvalidPoll,
      'duplicate_content' => errorDuplicateContent,
      'user_muted' => errorUserMuted,
      'secret_request_blocked' => errorSecretRequestBlocked,
      _ => switch (mapped.kind) {
        OltSocialErrorKind.network => errorNetwork,
        OltSocialErrorKind.unauthenticated => errorUnauthenticated,
        OltSocialErrorKind.rateLimited => errorRateLimited,
        OltSocialErrorKind.contentBlocked => errorContentBlocked,
        OltSocialErrorKind.invalidInput => errorInvalidInput,
        OltSocialErrorKind.forbidden => errorForbidden,
        OltSocialErrorKind.notFound => errorNotFound,
        OltSocialErrorKind.unavailable => errorUnavailable,
        OltSocialErrorKind.unknown => errorUnknown,
      },
    };
  }

  String relativeTime(DateTime time, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(time);
    if (diff.inSeconds < 60) return justNow;
    if (diff.inMinutes < 60) return minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return hoursAgo(diff.inHours);
    if (diff.inDays < 7) return daysAgo(diff.inDays);
    final local = time.toLocal();
    final pattern = local.year == current.year ? DateFormat.MMMd(localeName) : DateFormat.yMMMd(localeName);
    return pattern.format(local);
  }

  String clockTime(DateTime time) => DateFormat.Hm(localeName).format(time.toLocal());

  String dayLabel(DateTime time, {DateTime? now}) {
    final local = time.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final days = DateTime(current.year, current.month, current.day).difference(day).inDays;
    if (days == 0) return today;
    if (days == 1) return yesterday;
    final pattern = local.year == current.year ? DateFormat.MMMMEEEEd(localeName) : DateFormat.yMMMMEEEEd(localeName);
    return pattern.format(local);
  }

  String remainingTime(Duration left) {
    if (left.inDays >= 1) return pollTimeDays(left.inDays);
    if (left.inHours >= 1) return pollTimeHours(left.inHours);
    return pollTimeMinutes(left.inMinutes < 1 ? 1 : left.inMinutes);
  }
}
