import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

typedef CommunityLogHandler = void Function(LogRecord record);

const redactedValue = '[REDACTED]';

const _sensitiveKeyWords = {
  'token',
  'jwt',
  'password',
  'passwd',
  'secret',
  'otp',
  'pin',
  'authorization',
  'cookie',
  'body',
  'content',
  'text',
  'message',
  'caption',
  'comment',
  'account',
  'rekening',
  'nik',
  'card',
  'cvv',
  'apikey',
};

const _identifierSuffixes = {'id', 'ids', 'count', 'at', 'status', 'kind', 'code', 'type'};

final _keyWord = RegExp(r'[A-Z]?[a-z]+|[A-Z]+(?![a-z])|\d+');

final _secretPatterns = <(RegExp, String Function(Match))>[
  (RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), (_) => redactedValue),
  (RegExp(r'(bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false), (match) => '${match[1]}$redactedValue'),
  (RegExp(r'olt_[A-Za-z0-9_-]{16,}(?:\.[A-Za-z0-9_-]+)?'), (_) => redactedValue),
  (RegExp(r'mock:\d+:[A-Za-z0-9_.]+(?::[^\s,]+)?'), (_) => redactedValue),
  (
    RegExp(r'((?:access_|refresh_)?token|password|apikey|otp)=[^&\s]+', caseSensitive: false),
    (match) => '${match[1]}=$redactedValue',
  ),
  (RegExp(r'(?<!\d)\d{10,}(?!\d)'), (_) => redactedValue),
];

bool isSensitiveLogKey(String key) {
  final words = _keyWord.allMatches(key).map((match) => match[0]!.toLowerCase()).toList();
  if (words.isEmpty || _identifierSuffixes.contains(words.last)) return false;
  return words.any(_sensitiveKeyWords.contains) || _sensitiveKeyWords.contains(words.join());
}

String sanitizeLogText(String text) =>
    _secretPatterns.fold(text, (result, pattern) => result.replaceAllMapped(pattern.$1, pattern.$2));

Object? _sanitizeValue(Object? value) => switch (value) {
  null || num() || bool() => value,
  String() => sanitizeLogText(value),
  DateTime() => value.toUtc().toIso8601String(),
  Enum() => value.name,
  Map() => sanitizeLogFields({for (final entry in value.entries) '${entry.key}': entry.value}),
  Iterable() => [for (final item in value) _sanitizeValue(item)],
  _ => sanitizeLogText(value.toString()),
};

Map<String, Object?> sanitizeLogFields(Map<String, Object?> fields) => {
  for (final entry in fields.entries)
    entry.key: isSensitiveLogKey(entry.key) ? redactedValue : _sanitizeValue(entry.value),
};

class CommunityLogEvent {
  CommunityLogEvent(this.message, [Map<String, Object?> fields = const {}]) : fields = sanitizeLogFields(fields);

  final String message;
  final Map<String, Object?> fields;

  @override
  String toString() => fields.isEmpty ? message : '$message ${jsonEncode(fields)}';
}

extension StructuredCommunityLog on Logger {
  void event(
    Level level,
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isLoggable(level)) return;
    log(level, CommunityLogEvent(message, fields), error == null ? null : sanitizeLogText('$error'), stackTrace);
  }
}

Level defaultLogLevel({bool release = kReleaseMode}) => release ? Level.INFO : Level.FINE;

String formatLogRecord(LogRecord record) {
  final error = record.error == null ? '' : ' error=${record.error}';
  return '${record.time.toUtc().toIso8601String()} ${record.level.name} ${record.loggerName}: ${record.message}$error';
}

void debugConsoleLogHandler(LogRecord record) {
  if (kDebugMode) debugPrint(formatLogRecord(record));
}

abstract final class CommunityLoggers {
  static const rootName = 'RendezvousCommunity';

  static final Logger root = Logger(rootName);
  static final Logger account = Logger('$rootName.Account');
  static final Logger auth = Logger('$rootName.Auth');
  static final Logger chat = Logger('$rootName.Chat');
  static final Logger feed = Logger('$rootName.Feed');
  static final Logger realtime = Logger('$rootName.Realtime');
  static final Logger support = Logger('$rootName.Support');
  static final Logger push = Logger('$rootName.Push');
  static final Logger config = Logger('$rootName.Config');
  static final Logger analytics = Logger('$rootName.Analytics');
  static final Logger offline = Logger('$rootName.Offline');

  static StreamSubscription<LogRecord>? _subscription;

  static void configure({CommunityLogHandler? handler, Level? level}) {
    hierarchicalLoggingEnabled = true;
    root.level = level ?? defaultLogLevel();
    unawaited(_subscription?.cancel());
    _subscription = root.onRecord.listen(handler ?? debugConsoleLogHandler);
  }

  static Future<void> reset() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
