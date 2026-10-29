// Parser $KODE dan @mention. Pola regex HARUS sama dengan
// private.extract_cashtags / private.extract_mentions di
// supabase/migrations/0004_posts.sql agar yang disorot di UI = yang disimpan server.

/// `$` + huruf + 1-11 huruf/angka, tidak didahului huruf/angka/_/$.
/// `$100` dan `US$5` tidak dianggap kode saham.
final cashtagPattern = RegExp(r'(?<![A-Za-z0-9_$])\$([A-Za-z][A-Za-z0-9]{1,11})(?![A-Za-z0-9_])');

/// `@` + 3-30 huruf/angka/_, tidak didahului huruf/angka/_/@ (email bukan mention).
final mentionPattern = RegExp(r'(?<![A-Za-z0-9_@])@([A-Za-z0-9_]{3,30})(?![A-Za-z0-9_])');

/// Batas tag per post yang diproses server.
const maxTagsPerPost = 10;

/// Kode saham unik (huruf besar) sesuai urutan kemunculan.
List<String> extractCashtags(String text) =>
    _distinct(cashtagPattern.allMatches(text).map((m) => m.group(1)!.toUpperCase()));

/// Username unik (huruf kecil) sesuai urutan kemunculan.
List<String> extractMentions(String text) =>
    _distinct(mentionPattern.allMatches(text).map((m) => m.group(1)!.toLowerCase()));

List<String> _distinct(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final v in values)
      if (seen.add(v)) v,
  ];
}

/// Potongan teks hasil parsing.
sealed class SocialTextSegment {
  const SocialTextSegment(this.text);

  /// Teks asli segmen, termasuk prefiks `$` / `@`.
  final String text;
}

class PlainSegment extends SocialTextSegment {
  const PlainSegment(super.text);
}

class CashtagSegment extends SocialTextSegment {
  const CashtagSegment(super.text, this.code);

  /// Kode saham huruf besar tanpa `$`, mis. `BBCA`.
  final String code;
}

class MentionSegment extends SocialTextSegment {
  const MentionSegment(super.text, this.username);

  /// Username tanpa `@`.
  final String username;
}

/// Memecah [text] menjadi segmen polos, `$KODE`, dan `@mention`.
///
/// Jika [validStockCodes] diisi, hanya kode di dalamnya yang menjadi
/// [CashtagSegment] (mis. tag yang sudah divalidasi server untuk sebuah post).
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
    if (m.start < cursor) continue; // tumpang tindih (tidak terjadi untuk pola di atas)
    if (m.start > cursor) segments.add(PlainSegment(text.substring(cursor, m.start)));
    segments.add(m.segment);
    cursor = m.end;
  }
  if (cursor < text.length) segments.add(PlainSegment(text.substring(cursor)));
  return segments;
}

/// Token `$...` atau `@...` yang sedang diketik di posisi kursor, untuk autocomplete.
class ActiveToken {
  const ActiveToken({required this.trigger, required this.query, required this.start, required this.end});

  /// `$` atau `@`.
  final String trigger;

  /// Teks setelah trigger (boleh kosong).
  final String query;

  /// Posisi trigger di teks.
  final int start;

  /// Posisi akhir token (kursor).
  final int end;
}

final _activeTokenPattern = RegExp(r'(?:^|[^A-Za-z0-9_$@])([$@])([A-Za-z0-9_]{0,30})$');

/// Mencari token autocomplete yang berakhir di [cursor].
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
