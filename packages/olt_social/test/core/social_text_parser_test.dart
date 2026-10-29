import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/src/core/utils/social_text_parser.dart';

void main() {
  group('extractCashtags', () {
    test('mengambil kode saham unik, huruf besar, sesuai urutan', () {
      expect(
        extractCashtags(r'Beli $BBCA dan $goto, lalu $bbca lagi ($ABC).'),
        ['BBCA', 'GOTO', 'ABC'],
      );
    });

    test('mengabaikan harga dan simbol mata uang', () {
      expect(extractCashtags(r'harga $100, US$5, $1BBCA'), isEmpty);
    });

    test('mendukung kode indeks dan angka setelah huruf', () {
      expect(extractCashtags(r'$IHSG dan $IDX30 naik'), ['IHSG', 'IDX30']);
    });

    test('tidak menganggap kode yang menempel huruf/angka/_', () {
      expect(extractCashtags(r'a$BBCA _$TLKM $BBCA_x $TLKMx'), ['TLKMX']);
    });

    test('maksimal 12 karakter setelah \$', () {
      expect(extractCashtags(r'$ABCDEFGHIJKL ok, $ABCDEFGHIJKLM tidak'), ['ABCDEFGHIJKL']);
    });
  });

  group('extractMentions', () {
    test('mengambil username unik huruf kecil', () {
      expect(extractMentions('cc @Budi_Santoso dan @sari, @budi_santoso!'), ['budi_santoso', 'sari']);
    });

    test('mengabaikan email dan username terlalu pendek', () {
      expect(extractMentions('kirim ke budi@mail.com atau @al'), isEmpty);
    });
  });

  group('parseSocialText', () {
    test('memecah teks menjadi segmen polos, cashtag, mention', () {
      final segments = parseSocialText(r'Halo @budi_s, $BBCA naik!');
      expect(segments.map((s) => s.runtimeType).toList(), [
        PlainSegment,
        MentionSegment,
        PlainSegment,
        CashtagSegment,
        PlainSegment,
      ]);
      expect(segments.map((s) => s.text).join(), r'Halo @budi_s, $BBCA naik!');
      expect((segments[1] as MentionSegment).username, 'budi_s');
      expect((segments[3] as CashtagSegment).code, 'BBCA');
    });

    test('validStockCodes membatasi kode yang dapat diketuk', () {
      final segments = parseSocialText(r'$BBCA dan $ZZZZ', validStockCodes: {'BBCA'});
      expect(segments.whereType<CashtagSegment>().map((s) => s.code), ['BBCA']);
      expect(segments.map((s) => s.text).join(), r'$BBCA dan $ZZZZ');
    });

    test('teks tanpa tag menjadi satu segmen polos', () {
      expect(parseSocialText('biasa saja').single, isA<PlainSegment>());
    });
  });

  group('findActiveToken', () {
    test('mendeteksi \$ yang sedang diketik', () {
      final token = findActiveToken(r'lihat $BB', 9)!;
      expect(token.trigger, r'$');
      expect(token.query, 'BB');
      expect(token.start, 6);
    });

    test('mendeteksi @ di awal teks', () {
      final token = findActiveToken('@bu', 3)!;
      expect(token.trigger, '@');
      expect(token.query, 'bu');
      expect(token.start, 0);
    });

    test('tidak aktif di tengah kata atau setelah spasi', () {
      expect(findActiveToken('email@do', 8), isNull);
      expect(findActiveToken(r'$BBCA ', 6), isNull);
    });
  });
}
