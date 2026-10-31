import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/src/core/error/error_mapper.dart';
import 'package:olt_social/src/core/error/olt_social_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  OltSocialException pg(String code, [String message = 'msg']) =>
      mapError(PostgrestException(message: message, code: code, details: 'detail'));

  test('kode PT dari private.api_error dipetakan ke jenis error & kode stabil', () {
    final e = pg('PT429', 'rate_limited');
    expect(e.kind, OltSocialErrorKind.rateLimited);
    expect(e.code, 'rate_limited');
    expect(e.message, 'detail');

    expect(pg('PT422', 'content_blocked').kind, OltSocialErrorKind.contentBlocked);
    expect(pg('PT403', 'blocked').kind, OltSocialErrorKind.forbidden);
    expect(pg('PT404').kind, OltSocialErrorKind.notFound);
    expect(pg('PT400', 'invalid_cursor').kind, OltSocialErrorKind.invalidInput);
    expect(pg('PT409', 'parent_deleted').kind, OltSocialErrorKind.invalidInput);
  });

  test('error Postgres memakai SQLSTATE sebagai kode', () {
    final e = pg('23505', 'duplicate key value');
    expect(e.kind, OltSocialErrorKind.invalidInput);
    expect(e.code, '23505');
    expect(pg('42501').kind, OltSocialErrorKind.forbidden);
  });

  test('JWT kedaluwarsa dianggap unauthenticated', () {
    expect(pg('PGRST303').kind, OltSocialErrorKind.unauthenticated);
  });

  test('error jaringan', () {
    expect(mapError(const SocketException('offline')).kind, OltSocialErrorKind.network);
    expect(mapError(TimeoutException('lambat')).kind, OltSocialErrorKind.network);
  });

  test('OltSocialException diteruskan apa adanya', () {
    const e = OltSocialException(OltSocialErrorKind.forbidden, code: 'x');
    expect(identical(mapError(e), e), isTrue);
  });
}
