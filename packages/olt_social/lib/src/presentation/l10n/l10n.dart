import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/olt_social_exception.dart';
import 'gen/olt_social_localizations.dart';

export 'gen/olt_social_localizations.dart';

extension OltL10nContext on BuildContext {
  /// String terlokalisasi olt_social. Jika aplikasi host belum menambahkan
  /// `OltSocialLocalizations.delegate`, bahasa Indonesia dipakai.
  OltSocialLocalizations get oltL10n =>
      OltSocialLocalizations.of(this) ?? lookupOltSocialLocalizations(const Locale('id'));
}

extension OltErrorText on OltSocialLocalizations {
  /// Pesan ramah pengguna untuk error apa pun.
  String errorMessage(Object error) => switch (mapError(error).kind) {
    OltSocialErrorKind.network => errorNetwork,
    OltSocialErrorKind.unauthenticated => errorUnauthenticated,
    OltSocialErrorKind.rateLimited => errorRateLimited,
    OltSocialErrorKind.contentBlocked => errorContentBlocked,
    OltSocialErrorKind.invalidInput => errorInvalidInput,
    OltSocialErrorKind.forbidden => errorForbidden,
    OltSocialErrorKind.notFound => errorNotFound,
    OltSocialErrorKind.unavailable => errorUnavailable,
    OltSocialErrorKind.unknown => errorUnknown,
  };

  /// Waktu relatif singkat: "baru saja", "5 mnt", "3 j", "2 h", lalu tanggal.
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

  /// Jam:menit untuk gelembung chat.
  String clockTime(DateTime time) => DateFormat.Hm(localeName).format(time.toLocal());
}
