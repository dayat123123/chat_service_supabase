final cashtagPattern = RegExp(r'(?<![A-Za-z0-9_$])\$([A-Za-z][A-Za-z0-9]{1,11})(?![A-Za-z0-9_])');

final mentionPattern = RegExp(r'(?<![A-Za-z0-9_@])@([A-Za-z0-9_]{3,30})(?![A-Za-z0-9_])');

const maxTagsPerPost = 10;

List<String> extractCashtags(String text) =>
    _distinct(cashtagPattern.allMatches(text).map((m) => m.group(1)!.toUpperCase()));

List<String> extractMentions(String text) =>
    _distinct(mentionPattern.allMatches(text).map((m) => m.group(1)!.toLowerCase()));

List<String> _distinct(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final v in values)
      if (seen.add(v)) v,
  ];
}

sealed class SocialTextSegment {
  const SocialTextSegment(this.text);

  final String text;
}

class PlainSegment extends SocialTextSegment {
  const PlainSegment(super.text);
}

class CashtagSegment extends SocialTextSegment {
  const CashtagSegment(super.text, this.code);

  final String code;
}

class MentionSegment extends SocialTextSegment {
  const MentionSegment(super.text, this.username);

  final String username;
}

List<SocialTextSegment> parseSocialText(String text, {Set<String>? validStockCodes}) {
  final matches = <({int start, int end, SocialTextSegment segment})>[];

  for (final m in cashtagPattern.allMatches(text)) {
    final code = m.group(1)!.toUpperCase();
    if (validStockCodes != null && !validStockCodes.contains(code)) continue;
    matches.add((start: m.start, end: m.end, segment: CashtagSegment(m.group(0)!, code)));
  }
  for (final m in mentionPattern.allMatches(text)) {
    matches.add((start: m.start, end: m.end, segment: MentionSegment(m.group(0)!, m.group(1)!)));
  }
  matches.sort((a, b) => a.start.compareTo(b.start));

  final segments = <SocialTextSegment>[];
  var cursor = 0;
  for (final m in matches) {
    if (m.start < cursor) continue;
    if (m.start > cursor) segments.add(PlainSegment(text.substring(cursor, m.start)));
    segments.add(m.segment);
    cursor = m.end;
  }
  if (cursor < text.length) segments.add(PlainSegment(text.substring(cursor)));
  return segments;
}

class ActiveToken {
  const ActiveToken({required this.trigger, required this.query, required this.start, required this.end});

  final String trigger;

  final String query;

  final int start;

  final int end;
}

final _activeTokenPattern = RegExp(r'(?:^|[^A-Za-z0-9_$@])([$@])([A-Za-z0-9_]{0,30})$');

ActiveToken? findActiveToken(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final match = _activeTokenPattern.firstMatch(text.substring(0, cursor));
  if (match == null) return null;
  final trigger = match.group(1)!;
  final query = match.group(2)!;
  return ActiveToken(
    trigger: trigger,
    query: query,
    start: cursor - query.length - 1,
    end: cursor,
  );
}
