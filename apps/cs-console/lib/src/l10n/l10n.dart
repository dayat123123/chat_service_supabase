import 'package:cs_console/src/l10n/gen/console_localizations.dart';
import 'package:flutter/widgets.dart';

export 'gen/console_localizations.dart';

extension ConsoleL10nContext on BuildContext {
  ConsoleLocalizations get l10n => ConsoleLocalizations.of(this);
}
