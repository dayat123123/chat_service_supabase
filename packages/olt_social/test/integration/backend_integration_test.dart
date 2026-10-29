// Integration test ke stack Docker lokal (butuh `make up` + `make seed`, mode mock).
//
//   Windows : $env:OLT_SOCIAL_IT=1; flutter test test/integration
//   Linux   : OLT_SOCIAL_IT=1 flutter test test/integration
//
// URL & anon key dibaca dari docker/.env repo (atau env OLT_SOCIAL_URL / OLT_SOCIAL_ANON_KEY).
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:olt_social/olt_social.dart';
import 'package:uuid/uuid.dart';

final _enabled = Platform.environment['OLT_SOCIAL_IT'] == '1';

Map<String, String> _dockerEnv() {
  final file = File('../../docker/.env');
  if (!file.existsSync()) return const {};
  return {
    for (final line in file.readAsLinesSync())
      if (line.contains('=') && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim(): line.substring(line.indexOf('=') + 1).trim(),
  };
}

Future<T> _waitFor<T>(Stream<T> stream, bool Function(T) test, {Duration timeout = const Duration(seconds: 15)}) =>
    stream.firstWhere(test).timeout(timeout);

void main() {
  late OltSocial budi;
  late OltSocial sari;
  late OltSocial Function(String token) user;
  final created = <OltSocial>[];

  setUpAll(() async {
    if (!_enabled) return;
    final env = _dockerEnv();
    final url = Platform.environment['OLT_SOCIAL_URL'] ?? env['SUPABASE_PUBLIC_URL'] ?? 'http://localhost:8000';
    final anonKey = Platform.environment['OLT_SOCIAL_ANON_KEY'] ?? env['ANON_KEY']!;
    user = (token) {
      final social = OltSocial.create(supabaseUrl: url, anonKey: anonKey, oltTokenProvider: () async => token);
      created.add(social);
      return social;
    };
    budi = user('mock:1001:budi_santoso');
    sari = user('mock:1002:sari_invest');
    await budi.ensureSignedIn();
    await sari.ensureSignedIn();
  });

  tearDownAll(() async {
    for (final social in created) {
      await social.dispose();
    }
  });

  final skip = _enabled ? null : 'Set OLT_SOCIAL_IT=1 untuk menjalankan integration test';

  test('login via auth-bridge memberi id UUID v5 yang sama dengan seed', () {
    expect(budi.currentUser!.id, '72689cd3-ea55-584f-9e84-c257af0564e0');
    expect(budi.currentUser!.username, 'budi_santoso');
  }, skip: skip);

  test('feed global dengan pagination keyset', () async {
    final first = await budi.feed.getFeed(const FeedScope.global(), limit: 3);
    expect(first.items, hasLength(3));
    final second = await budi.feed.getFeed(const FeedScope.global(), cursor: first.nextCursor, limit: 3);
    expect(second.items.map((p) => p.id).toSet().intersection(first.items.map((p) => p.id).toSet()), isEmpty);
    final stock = await budi.feed.getFeed(const FeedScope.stock('BBCA'));
    expect(stock.items.every((p) => p.stockCodes.contains('BBCA')), isTrue);
  }, skip: skip);

  test('thread seed 5 level & pencarian saham', () async {
    final thread = await budi.comments.getThread('a0000000-0000-4000-8000-000000000001', maxDepth: 10, repliesLimit: 10);
    expect(thread.map((c) => c.depth).reduce((a, b) => a > b ? a : b), 4);
    final stocks = await budi.stocks.searchStocks('bb');
    expect(stocks.map((s) => s.code), contains('BBCA'));
  }, skip: skip);

  test('komentar baru diterima realtime oleh pemilik post', () async {
    final post = await budi.feed.createPost(body: r'Integration test $BBCA');
    final seen = <String>{};
    final sub = budi.comments.watchComments(post.id).listen(seen.add);
    try {
      // Langganan realtime yang baru dibuka (mis. stack baru start) butuh waktu
      // siap: kirim komentar ulang sampai event pertamanya diterima.
      String? received;
      for (var attempt = 0; attempt < 5 && received == null; attempt++) {
        final comment = await sari.comments.createComment(postId: post.id, body: 'Komentar realtime $attempt');
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (DateTime.now().isBefore(deadline) && !seen.contains(comment.id)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (seen.contains(comment.id)) received = comment.id;
      }
      expect(received, isNotNull, reason: 'event komentar realtime tidak pernah diterima');
    } finally {
      await sub.cancel();
      await budi.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('chat realtime: pesan, mengetik (channel private), notifikasi', () async {
    final roomId = await budi.chat.getOrCreateDirectRoom(sari.currentUser!.id);
    final sariRoom = sari.chat.connectRoom(roomId, me: sari.currentUser!);
    final budiRoom = budi.chat.connectRoom(roomId, me: budi.currentUser!);
    final sariEvents = sariRoom.events.asBroadcastStream();
    final budiSub = budiRoom.events.listen((_) {});
    try {
      await _waitFor(sariEvents, (e) => e is ConnectionChanged && e.status == RealtimeStatus.connected);

      final notified = _waitFor(sari.notifications.watchNotifications(), (_) => true);
      final clientId = const Uuid().v4();
      final received = _waitFor(sariEvents, (e) => e is MessageUpserted && e.message.clientId == clientId);
      await Future<void>.delayed(const Duration(seconds: 1));
      final sent = await budi.chat.sendMessage(roomId, body: 'Halo dari integration test', clientId: clientId);
      final event = await received as MessageUpserted;
      expect(event.message.id, sent.id);
      await notified;

      // Sinyal mengetik lewat channel private room:<id> (policy realtime.messages).
      final typing = _waitFor(sariEvents, (e) => e is TypingChanged && e.isTyping);
      final ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => budiRoom.sendTyping(isTyping: true));
      try {
        final t = await typing as TypingChanged;
        expect(t.user.id, budi.currentUser!.id);
      } finally {
        ticker.cancel();
      }
    } finally {
      await budiSub.cancel();
      await budiRoom.close();
      await sariRoom.close();
    }
  }, skip: skip);

  test('presence online', () async {
    final budiOnline = budi.chat.watchOnlineUsers(me: budi.currentUser!);
    final sub = sari.chat.watchOnlineUsers(me: sari.currentUser!).listen((_) {});
    try {
      final ids = await _waitFor(budiOnline, (ids) => ids.contains(sari.currentUser!.id));
      expect(ids, contains(sari.currentUser!.id));
    } finally {
      await sub.cancel();
    }
  }, skip: skip);

  test('rate limit server dipetakan ke OltSocialErrorKind.rateLimited', () async {
    // User terpisah: kuota pesan Budi/Sari (dipakai tes & E2E lain) tidak ikut habis,
    // sehingga suite bisa diulang tanpa menunggu satu menit.
    final rina = user('mock:1004:rina_saham');
    final dewi = user('mock:1005:dewi_cuan');
    final dewiUser = await dewi.ensureSignedIn();
    await rina.ensureSignedIn();
    final roomId = await rina.chat.getOrCreateDirectRoom(dewiUser.id);
    final ids = <String>[];
    try {
      for (var i = 0; i < 40; i++) {
        ids.add((await rina.chat.sendMessage(roomId, body: 'spam $i', clientId: const Uuid().v4())).id);
      }
      fail('rate limit tidak terpicu');
    } on OltSocialException catch (e) {
      expect(e.kind, OltSocialErrorKind.rateLimited);
    } finally {
      for (final id in ids) {
        await rina.chat.deleteMessage(id);
      }
    }
  }, skip: skip);
}
