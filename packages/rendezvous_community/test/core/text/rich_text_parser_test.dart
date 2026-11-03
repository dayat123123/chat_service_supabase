import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/src/core/text/social_text_parser.dart';

void main() {
  group('hashtags', () {
    test('extracts like the database: lower case, 2–50 characters, distinct', () {
      expect(extractHashtags('Diskusi #Dividen dan #dividen, #IPO2026 #a'), ['dividen', 'ipo2026']);
    });

    test('ignores URL fragments, HTML entities, and tags glued to words', () {
      expect(extractHashtags('lihat https://x.com/a#bagian dan kata#tempel &#39; #ok'), ['ok']);
    });

    test('are only emitted as segments when asked', () {
      expect(parseSocialText('#bbca naik').whereType<HashtagSegment>(), isEmpty);
      final tags = parseSocialText('#BBCA naik', hashtags: true).whereType<HashtagSegment>();
      expect(tags.single.tag, 'bbca');
      expect(tags.single.text, '#BBCA');
    });
  });

  group('links', () {
    test('only http and https are recognised, trailing punctuation is trimmed', () {
      expect(extractLinks('Baca https://idx.co.id/berita. Atau (http://ojk.go.id/a_(b)).'), [
        'https://idx.co.id/berita',
        'http://ojk.go.id/a_(b)',
      ]);
      expect(extractLinks('javascript:alert(1) ftp://x.com tel:0812 www.example.com'), isEmpty);
    });

    test('rejects userinfo tricks and caps at three links', () {
      expect(extractLinks('https://bank.com@evil.com/login'), isEmpty);
      expect(extractLinks('https://a.com https://b.com https://c.com https://d.com'), hasLength(3));
    });

    test('link segments win over mentions, cashtags, and hashtags inside the URL', () {
      final segments = parseSocialText(
        r'Cek https://medium.com/@budi/$bbca#catatan sekarang $BBCA',
        links: true,
        hashtags: true,
      );
      final link = segments.whereType<LinkSegment>().single;
      expect(link.uri.host, 'medium.com');
      expect(link.text, r'https://medium.com/@budi/$bbca#catatan');
      expect(segments.whereType<MentionSegment>(), isEmpty);
      expect(segments.whereType<HashtagSegment>(), isEmpty);
      expect(segments.whereType<CashtagSegment>().single.code, 'BBCA');
      expect(segments.map((s) => s.text).join(), r'Cek https://medium.com/@budi/$bbca#catatan sekarang $BBCA');
    });

    test('safeLinkUri accepts only http(s) with a host', () {
      expect(safeLinkUri('https://idx.co.id'), isNotNull);
      expect(safeLinkUri('mailto:a@b.com'), isNull);
      expect(safeLinkUri('https://user:pw@x.com'), isNull);
    });
  });
}
