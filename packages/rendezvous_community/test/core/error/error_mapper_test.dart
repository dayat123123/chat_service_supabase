import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  CommunityException pg(String code, [String message = 'msg']) =>
      mapError(PostgrestException(message: message, code: code, details: 'detail'));

  test('maps PT codes from private.api_error to an error kind and a stable code', () {
    final e = pg('PT429', 'rate_limited');
    expect(e.kind, CommunityErrorKind.rateLimited);
    expect(e.code, 'rate_limited');
    expect(e.message, 'detail');

    expect(pg('PT422', 'content_blocked').kind, CommunityErrorKind.contentBlocked);
    expect(pg('PT403', 'blocked').kind, CommunityErrorKind.forbidden);
    expect(pg('PT404').kind, CommunityErrorKind.notFound);
    expect(pg('PT400', 'invalid_cursor').kind, CommunityErrorKind.invalidInput);
    expect(pg('PT409', 'parent_deleted').kind, CommunityErrorKind.invalidInput);
  });

  test('uses SQLSTATE as the code for Postgres errors', () {
    final e = pg('23505', 'duplicate key value');
    expect(e.kind, CommunityErrorKind.invalidInput);
    expect(e.code, '23505');
    expect(pg('42501').kind, CommunityErrorKind.forbidden);
  });

  test('treats an expired JWT as unauthenticated', () {
    expect(pg('PGRST303').kind, CommunityErrorKind.unauthenticated);
  });

  test('network errors', () {
    expect(mapError(const SocketException('offline')).kind, CommunityErrorKind.network);
    expect(mapError(TimeoutException('lambat')).kind, CommunityErrorKind.network);
  });

  test('passes CommunityException through unchanged', () {
    const e = CommunityException(CommunityErrorKind.forbidden, code: 'x');
    expect(identical(mapError(e), e), isTrue);
  });
}
