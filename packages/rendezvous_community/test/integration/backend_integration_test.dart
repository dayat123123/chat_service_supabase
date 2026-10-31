@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
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

String? _dockerSecret(String name) {
  final file = File('../../docker/secrets/$name');
  return file.existsSync() ? file.readAsStringSync().trim() : null;
}

Future<T> _waitFor<T>(Stream<T> stream, bool Function(T) test, {Duration timeout = const Duration(seconds: 15)}) =>
    stream.firstWhere(test).timeout(timeout);

void main() {
  late RendezvousCommunity budi;
  late RendezvousCommunity sari;
  late RendezvousCommunity Function(String token) user;
  final created = <RendezvousCommunity>[];

  setUpAll(() async {
    if (!_enabled) return;
    final env = _dockerEnv();
    final url = Platform.environment['OLT_SOCIAL_URL'] ?? env['SUPABASE_PUBLIC_URL'] ?? 'http://localhost:8000';
    final anonKey = Platform.environment['OLT_SOCIAL_ANON_KEY'] ?? _dockerSecret('anon_key') ?? env['ANON_KEY']!;
    user = (token) {
      final social = RendezvousCommunity.create(
        supabaseUrl: url,
        anonKey: anonKey,
        oltTokenProvider: () async => token,
      );
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

  final skip = _enabled ? null : 'Set OLT_SOCIAL_IT=1 to run the integration tests';

  test('signing in through auth-bridge yields the same UUID v5 id as the seed', () {
    expect(budi.currentUser!.id, '72689cd3-ea55-584f-9e84-c257af0564e0');
    expect(budi.currentUser!.username, 'budi_santoso');
  }, skip: skip);

  test('global feed with keyset pagination', () async {
    final first = await budi.feed.getFeed(const FeedScope.global(), limit: 3);
    expect(first.items, hasLength(3));
    final second = await budi.feed.getFeed(const FeedScope.global(), cursor: first.nextCursor, limit: 3);
    expect(second.items.map((p) => p.id).toSet().intersection(first.items.map((p) => p.id).toSet()), isEmpty);
    final stock = await budi.feed.getFeed(const FeedScope.stock('BBCA'));
    expect(stock.items.every((p) => p.stockCodes.contains('BBCA')), isTrue);
  }, skip: skip);

  test('five-level seed thread and stock watchers without a server-side stock list', () async {
    final thread = await budi.comments.getThread(
      'a0000000-0000-4000-8000-000000000001',
      maxDepth: 10,
      repliesLimit: 10,
    );
    expect(thread.map((c) => c.depth).reduce((a, b) => a > b ? a : b), 4);
    final stock = await budi.stocks.getStock('bbca');
    expect(stock?.code, 'BBCA');
    expect(stock?.watcherCount, greaterThanOrEqualTo(2));
    expect(stock?.watching, isTrue);
    expect(await budi.stocks.getStock('1X'), isNull);
  }, skip: skip);

  test('the post owner receives new comments in realtime', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final post = await budi.feed.createPost(body: 'Integration test \$BBCA $stamp');
    final seen = <String>{};
    final sub = budi.comments.watchComments(post.id).listen(seen.add);
    try {
      String? received;
      for (var attempt = 0; attempt < 5 && received == null; attempt++) {
        final comment = await sari.comments.createComment(postId: post.id, body: 'Komentar realtime $stamp-$attempt');
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (DateTime.now().isBefore(deadline) && !seen.contains(comment.id)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (seen.contains(comment.id)) received = comment.id;
      }
      expect(received, isNotNull, reason: 'the realtime comment event was never received');
    } finally {
      await sub.cancel();
      await budi.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('realtime chat: messages, typing (private channel), notifications', () async {
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
      final sent = await budi.chat.sendMessage(
        roomId,
        body: 'Halo dari integration test $clientId',
        clientId: clientId,
      );
      final event = await received as MessageUpserted;
      expect(event.message.id, sent.id);
      await notified;

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

  test('per-room presence and WhatsApp-style ticks: delivered then read', () async {
    final roomId = await budi.chat.getOrCreateDirectRoom(sari.currentUser!.id);
    final budiSignals = budi.chat.watchRoomSignals({roomId}, me: budi.currentUser!).asBroadcastStream();
    final budiSub = budiSignals.listen((_) {});
    final sariSub = sari.chat.watchRoomSignals({roomId}, me: sari.currentUser!).listen((_) {});
    try {
      await _waitFor(
        budiSignals,
        (s) => s is RoomPresence && s.userIds.contains(sari.currentUser!.id),
        timeout: const Duration(seconds: 20),
      );

      final clientId = const Uuid().v4();
      final sent = await budi.chat.sendMessage(roomId, body: 'Centang $clientId', clientId: clientId);
      bool reached(RoomSignal s, DateTime Function(MemberReceipt r) pick) =>
          s is RoomReceipt && s.receipt.userId == sari.currentUser!.id && !pick(s.receipt).isBefore(sent.createdAt);

      await _waitFor(budiSignals, (s) => reached(s, (r) => r.lastDeliveredAt), timeout: const Duration(seconds: 20));
      final delivered = (await budi.chat.getRooms()).items.firstWhere((r) => r.id == roomId);
      expect(delivered.lastMessageStatus, ReceiptStatus.delivered);

      final read = _waitFor(budiSignals, (s) => reached(s, (r) => r.lastReadAt), timeout: const Duration(seconds: 20));
      await sari.chat.markRoomRead(roomId);
      await read;
      final seen = (await budi.chat.getRooms()).items.firstWhere((r) => r.id == roomId);
      expect(seen.lastMessageStatus, ReceiptStatus.read);
      final single = await budi.chat.getRoom(roomId);
      expect(single!.otherUser!.username, 'sari_invest');
      expect(single.lastMessageStatus, ReceiptStatus.read);
    } finally {
      await budiSub.cancel();
      await sariSub.cancel();
    }
  }, skip: skip);

  test('chat badge: the unread count rises on new messages and drops after opening', () async {
    final roomId = await sari.chat.getOrCreateDirectRoom(budi.currentUser!.id);
    await budi.chat.markRoomRead(roomId);
    final before = await budi.chat.unreadChatCount();

    await sari.chat.sendMessage(roomId, body: 'Badge ${const Uuid().v4()}', clientId: const Uuid().v4());
    await sari.chat.sendMessage(roomId, body: 'Badge ${const Uuid().v4()}', clientId: const Uuid().v4());
    expect(await budi.chat.unreadChatCount(), before + 1);

    await budi.chat.markRoomRead(roomId);
    expect(await budi.chat.unreadChatCount(), before);
  }, skip: skip);

  test('polls: create, vote, and see results after voting', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final post = await budi.feed.createPost(
      body: 'Polling integration $stamp: IHSG minggu depan?',
      poll: const PollDraft(options: ['Naik', 'Turun', 'Sideways'], duration: PollDuration.oneHour),
    );
    try {
      final created = post.poll!;
      expect(created.options.map((o) => o.label), ['Naik', 'Turun', 'Sideways']);
      expect(created.resultsVisible, isTrue);

      final beforeVote = (await sari.feed.getPost(post.id))!.poll!;
      expect(beforeVote.resultsVisible, isFalse);
      expect(beforeVote.options.first.votes, isNull);

      final afterVote = await sari.polls.vote(post.id, beforeVote.options[1].id);
      expect(afterVote.myOptionId, beforeVote.options[1].id);
      expect(afterVote.totalVotes, 1);
      expect(afterVote.options[1].votes, 1);

      await expectLater(
        sari.polls.vote(post.id, beforeVote.options.first.id),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'already_voted')),
      );
      await expectLater(
        budi.polls.vote(post.id, beforeVote.options.first.id),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'own_poll')),
      );
    } finally {
      await budi.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('maps the server rate limit to CommunityErrorKind.rateLimited', () async {
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
      fail('rate limit was not triggered');
    } on CommunityException catch (e) {
      expect(e.kind, CommunityErrorKind.rateLimited);
    } finally {
      for (final id in ids) {
        await rina.chat.deleteMessage(id);
      }
    }
  }, skip: skip);
}
