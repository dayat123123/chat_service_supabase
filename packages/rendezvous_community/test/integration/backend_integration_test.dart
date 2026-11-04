@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannelConfig, RealtimeSubscribeStatus;
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
  late String socialUrl;
  late String socialAnonKey;
  final created = <RendezvousCommunity>[];

  setUpAll(() async {
    if (!_enabled) return;
    final env = _dockerEnv();
    final url = Platform.environment['OLT_SOCIAL_URL'] ?? env['SUPABASE_PUBLIC_URL'] ?? 'http://localhost:8000';
    final anonKey = Platform.environment['OLT_SOCIAL_ANON_KEY'] ?? _dockerSecret('anon_key') ?? env['ANON_KEY']!;
    socialUrl = url;
    socialAnonKey = anonKey;
    user = (token) {
      final social = RendezvousCommunity.create(supabaseUrl: url, anonKey: anonKey, tokenProvider: () async => token);
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

  test('room members cannot inject server events and new messages arrive by server broadcast', () async {
    final roomId = await budi.chat.getOrCreateDirectRoom(sari.currentUser!.id);
    final sariRoom = sari.chat.connectRoom(roomId, me: sari.currentUser!);
    final sariEvents = sariRoom.events.asBroadcastStream();
    final spoofed = <ChatRoomEvent>[];
    final sub = sariEvents.listen((e) {
      final serverOnly = e is MessageHidden || e is StockRoomStateChanged || e is ReactionChanged;
      if (serverOnly || e is TypingChanged) spoofed.add(e);
    });
    final raw = budi.client.channel('room:$roomId', opts: const RealtimeChannelConfig(private: true, self: true));
    final echoed = <String>[];
    try {
      await _waitFor(sariEvents, (e) => e is ConnectionChanged && e.status == RealtimeStatus.connected);
      final joined = Completer<void>();
      raw
        ..onBroadcast(event: 'message_hidden', callback: (_) => echoed.add('message_hidden'))
        ..subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && !joined.isCompleted) joined.complete();
        });
      await joined.future.timeout(const Duration(seconds: 15));
      for (final event in ['message_hidden', 'room_state', 'reaction', 'typing', 'message']) {
        await raw.sendBroadcastMessage(
          event: event,
          payload: {'room_id': roomId, 'message_id': 'spoof', 'user_id': budi.currentUser!.id, 'typing': true},
        );
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(spoofed, isEmpty);
      expect(echoed, isEmpty);

      final clientId = const Uuid().v4();
      final received = _waitFor(sariEvents, (e) => e is MessageUpserted && e.message.clientId == clientId);
      final sent = await budi.chat.sendMessage(roomId, body: 'Siaran server $clientId', clientId: clientId);
      final event = await received as MessageUpserted;
      expect(event.message.id, sent.id);
      expect(event.message.sender?.id, budi.currentUser!.id);
    } finally {
      await sub.cancel();
      await budi.client.removeChannel(raw);
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

  test('legal documents come from get_legal_documents', () async {
    final documents = await budi.legalDocuments(refresh: true);
    expect(documents.map((d) => d.id).toSet(), hasLength(documents.length));
    for (final document in documents) {
      expect(document.version, greaterThan(0));
      expect(document.title, isNotEmpty);
    }
    expect(await budi.pendingLegalDocuments(), everyElement(predicate<LegalDocument>((d) => d.isPending)));
  }, skip: skip);

  test('images are uploaded through the media gateway', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final attachment = await budi.media.uploadPostImage(png, mimeType: 'image/jpeg');
    expect(attachment.path, startsWith('posts/${budi.currentUser!.id}/'));
    expect(attachment.path, endsWith('.png'));
    expect(attachment.mime, 'image/png');
    expect((attachment.width, attachment.height), (1, 1));
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

  test('client config: anonymous and signed-in fetch expose flags and limits', () async {
    final anonymous = user('');
    final anonymousConfig = await anonymous.refreshClientConfig();
    expect(anonymousConfig.loaded, isTrue);
    expect(anonymousConfig.flags.keys, containsAll(<String>[CommunityFlags.search, CommunityFlags.analytics]));
    expect(anonymous.currentUser, isNull);

    final config = await budi.refreshClientConfig();
    expect(config.loaded, isTrue);
    expect(config.socialEnabled, isTrue);
    expect(config.updateRequired, isFalse);
    expect(config.editWindow, const Duration(minutes: 15));
    expect(config.messageReactions, hasLength(6));
    expect(config.notificationTypes, containsAll(<String>['appeal', 'olt.trade']));
    expect(config.clockSkew.inMinutes.abs(), lessThan(5));
    expect(budi.clientConfig, config);
  }, skip: skip);

  test('search, hashtag feed, trending and sentiment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tag = 'ittag$stamp';
    final post = await sari.feed.createPost(body: 'Integration zorvexit$stamp \$BBCA #$tag');
    try {
      expect(post.hashtags, [tag]);
      expect(extractHashtags(post.body), [tag]);
      expect(post.moderationStatus, ModerationStatus.visible);

      final hashtagFeed = await budi.search.hashtagFeed('#$tag');
      expect(hashtagFeed.items.map((p) => p.id), contains(post.id));

      final posts = await budi.search.search('zorvexit$stamp', type: SearchType.posts);
      expect(posts.posts.map((p) => p.id), contains(post.id));
      expect(posts.posts.firstWhere((p) => p.id == post.id).moderationStatus, isNull);

      final all = await sari.search.search('BBCA');
      expect(all.type, SearchType.all);
      expect(all.nextCursor, isNull);
      expect(all.stocks.map((s) => s.code), contains('BBCA'));

      final users = await sari.search.search('budi', type: SearchType.users);
      expect(users.users.map((u) => u.user.username), contains('budi_santoso'));

      final stocks = await sari.search.search('BB', type: SearchType.stocks, limit: 1);
      expect(stocks.stocks, hasLength(1));
      if (stocks.nextCursor != null) {
        final next = await sari.search.search('BB', type: SearchType.stocks, cursor: stocks.nextCursor, limit: 1);
        expect(next.stocks.map((s) => s.code), isNot(contains(stocks.stocks.single.code)));
      }

      await expectLater(
        sari.search.search('a'),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'query_too_short')),
      );

      expect(await sari.search.trendingHashtags(window: TrendWindow.week), isA<List<HashtagSummary>>());
      final snapshot = await sari.trending.trending(window: TrendWindow.week);
      expect(snapshot.window, TrendWindow.week);
      final sentiment = await sari.trending.stockSentiment('bbca');
      expect(sentiment.code, 'BBCA');
    } finally {
      await sari.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('bookmarks: set, list, and unset', () async {
    final rina = user('mock:1004:rina_saham');
    await rina.ensureSignedIn();
    final post = await rina.feed.createPost(body: 'Bookmark integration ${DateTime.now().microsecondsSinceEpoch}');
    try {
      expect(await sari.bookmarks.setBookmarked(post.id, bookmarked: true), isTrue);
      expect(await sari.bookmarks.setBookmarked(post.id, bookmarked: true), isTrue);
      final saved = await sari.bookmarks.getBookmarks(limit: 50);
      final row = saved.items.firstWhere((p) => p.id == post.id);
      expect(row.isBookmarked, isTrue);
      expect((await sari.feed.getPost(post.id))!.isBookmarked, isTrue);

      expect(await sari.bookmarks.setBookmarked(post.id), isFalse);
      final after = await sari.bookmarks.getBookmarks(limit: 50);
      expect(after.items.map((p) => p.id), isNot(contains(post.id)));
    } finally {
      await rina.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('edit window: fresh posts and comments are editable, polls and old posts are not', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final dewi = user('mock:1005:dewi_cuan');
    await dewi.ensureSignedIn();
    final post = await dewi.feed.createPost(body: 'Edit integration $stamp');
    final poll = await dewi.feed.createPost(
      body: 'Edit poll $stamp',
      poll: const PollDraft(options: ['Ya', 'Tidak'], duration: PollDuration.oneHour),
    );
    try {
      final edited = await dewi.edits.editPost(post.id, 'Edit integration $stamp (diperbarui)');
      expect(edited.body, endsWith('(diperbarui)'));
      expect(edited.editedAt, isNotNull);

      final comment = await dewi.comments.createComment(postId: post.id, body: 'Komentar $stamp');
      final editedComment = await dewi.edits.editComment(comment.id, 'Komentar $stamp diedit');
      expect(editedComment.body, 'Komentar $stamp diedit');
      expect(editedComment.editedAt, isNotNull);

      await expectLater(
        sari.edits.editPost(post.id, 'bukan milik saya'),
        throwsA(isA<CommunityException>().having((e) => e.kind, 'kind', CommunityErrorKind.forbidden)),
      );
      await expectLater(
        dewi.edits.editPost(poll.id, 'ubah polling'),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'poll_not_editable')),
      );

      final own = await budi.feed.getFeed(FeedScope.user(budi.currentUser!.id), limit: 50);
      final old = own.items.where(
        (p) => p.poll == null && DateTime.now().toUtc().difference(p.createdAt) > const Duration(minutes: 20),
      );
      if (old.isNotEmpty) {
        await expectLater(
          budi.edits.editPost(old.first.id, 'terlambat'),
          throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'edit_window_expired')),
        );
      }
    } finally {
      await dewi.feed.deletePost(post.id);
      await dewi.feed.deletePost(poll.id);
    }
  }, skip: skip);

  test('DM message requests: a new account writes to budi, hits the limit, and is accepted', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final newcomer = user('mock:${880000 + stamp % 100000}:it_dm_${stamp % 100000000}');
    final me = await newcomer.ensureSignedIn();
    String? roomId;
    try {
      final pending = await newcomer.pendingLegalDocuments(refresh: true);
      if (pending.isNotEmpty) await newcomer.acceptLegalDocuments([for (final d in pending) d.id]);

      final room = roomId = await newcomer.chat.getOrCreateDirectRoom(budi.currentUser!.id);
      for (var i = 0; i < 3; i++) {
        await newcomer.chat.sendMessage(room, body: 'Halo $i', clientId: const Uuid().v4());
      }
      await expectLater(
        newcomer.chat.sendMessage(room, body: 'Halo lagi', clientId: const Uuid().v4()),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'dm_request_limit')),
      );

      expect(await budi.messageRequests.requestCount(), greaterThanOrEqualTo(1));
      final requests = await budi.messageRequests.getRequests();
      final request = requests.firstWhere((r) => r.roomId == room);
      expect(request.sender.id, me.id);
      expect(request.messageCount, 3);
      expect((await budi.chat.getRooms(limit: 100)).items.map((r) => r.id), isNot(contains(room)));

      final senderState = await newcomer.messageRequests.requestState(room);
      expect(senderState.pendingAsSender, isTrue);
      expect((senderState.sent, senderState.maxMessages), (3, 3));
      expect(senderState.limitReached, isTrue);
      final recipientState = await budi.messageRequests.requestState(room);
      expect(recipientState.pendingAsRecipient, isTrue);

      await budi.messageRequests.respond(room, MessageRequestAction.accept);
      expect((await newcomer.messageRequests.requestState(room)).isRequest, isFalse);
      expect((await budi.messageRequests.requestState(room)).isRequest, isFalse);
      expect((await budi.messageRequests.getRequests()).map((r) => r.roomId), isNot(contains(room)));
      expect((await budi.chat.getRooms(limit: 100)).items.map((r) => r.id), contains(room));
      await newcomer.chat.sendMessage(room, body: 'Terima kasih', clientId: const Uuid().v4());
    } finally {
      await newcomer.deleteMyAccount();
      if (roomId != null) await _psql("delete from public.chat_rooms where id = '$roomId'");
    }
  }, skip: skip);

  test('desktop platform: config and analytics accept windows', () async {
    final desktop = RendezvousCommunity.create(
      supabaseUrl: socialUrl,
      anonKey: socialAnonKey,
      tokenProvider: () async => 'mock:1002:sari_invest',
      platform: CommunityPlatform.windows,
      appVersion: '1.3.0',
    );
    created.add(desktop);
    final anonymousConfig = await desktop.refreshClientConfig();
    expect(anonymousConfig.loaded, isTrue);
    await desktop.ensureSignedIn();
    final config = await desktop.refreshClientConfig();
    expect(config.loaded, isTrue);
    expect(config.minVersions.keys, contains('windows'));
    desktop.analytics.record(CommunityAnalyticsEvent.feedOpen, {'scope': 'global'});
    final result = await desktop.analytics.flush();
    expect(result, isNotNull);
    if (!result!.disabled) expect(result.accepted, 1);
  }, skip: skip);

  test('moderated content lists hidden posts and their appeal', () async {
    final dewi = user('mock:1005:dewi_cuan');
    await dewi.ensureSignedIn();
    final post = await dewi.feed.createPost(body: 'Moderasi integration ${DateTime.now().microsecondsSinceEpoch}');
    String? appealId;
    try {
      final hidden = await _psql(
        "update public.posts set moderation_status = 'hidden', moderated_at = now() where id = '${post.id}'",
      );
      if (!hidden) {
        markTestSkipped('docker exec psql is not available to hide a post');
        return;
      }
      final before = await dewi.appeals.myModeratedContent();
      final item = before.firstWhere((c) => c.id == post.id);
      expect(item.type, AppealTargetType.post);
      expect(item.state, ModeratedState.hidden);
      expect(item.appeal, isNull);
      expect((await dewi.feed.getPost(post.id))!.isHidden, isTrue);

      final appeal = await dewi.appeals.createAppeal(AppealTargetType.post, post.id, 'Integration: analisis biasa.');
      appealId = appeal.id;
      final after = await dewi.appeals.myModeratedContent();
      expect(after.firstWhere((c) => c.id == post.id).appeal!.status, AppealStatus.pending);
      expect((await dewi.appeals.myAppeals()).map((a) => a.id), contains(appeal.id));
    } finally {
      if (appealId != null) await _psql("delete from public.appeals where id = '$appealId'");
      await dewi.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('DM policy round trip', () async {
    final original = await sari.messageRequests.dmPolicy();
    try {
      final updated = await sari.messageRequests.setDmPolicy(DmPolicy.following);
      expect(updated.policy, DmPolicy.following);
      expect(updated.requestMaxMessages, 3);
      expect((await sari.messageRequests.dmPolicy()).policy, DmPolicy.following);
    } finally {
      await sari.messageRequests.setDmPolicy(original.policy);
    }
  }, skip: skip);

  test('slow mode in a stock room maps to slow_mode with the wait in seconds', () async {
    final code = 'ITSL${DateTime.now().microsecondsSinceEpoch % 100000}';
    final roomId = await budi.chat.joinStockRoom(code);
    try {
      final set = await _psql(
        'insert into private.room_moderation (room_id, slow_mode_seconds, slow_mode_source) '
        "values ('$roomId', 30, 'manual') on conflict (room_id) do update "
        "set slow_mode_seconds = 30, slow_mode_until = null, slow_mode_source = 'manual'",
      );
      if (!set) {
        markTestSkipped('docker exec psql is not available to configure slow mode');
        return;
      }
      final state = await budi.chatExtras.stockRoomState(code);
      expect(state.roomId, roomId);
      expect(state.slowModeSeconds, 30);
      expect(state.slowModeActive(), isTrue);

      await budi.chat.sendMessage(roomId, body: 'Slow mode 1', clientId: const Uuid().v4());
      try {
        await budi.chat.sendMessage(roomId, body: 'Slow mode 2', clientId: const Uuid().v4());
        fail('slow mode was not enforced');
      } on CommunityException catch (e) {
        expect(e.code, 'slow_mode');
        expect(e.kind, CommunityErrorKind.rateLimited);
        expect(e.retryAfter!.inSeconds, inInclusiveRange(1, 30));
        final text = (await CommunityLocalizations.delegate.load(const Locale('id'))).errorMessage(e);
        expect(text, contains('${e.retryAfter!.inSeconds}'));
      }
      expect((await budi.chatExtras.stockRoomState(code)).waitSeconds, greaterThan(0));
    } finally {
      await _psql("delete from public.chat_rooms where id = '$roomId'");
    }
  }, skip: skip);

  test('room mutes stay private: the muted member hears it alone and moderators see the list', () async {
    final code = 'ITMU${DateTime.now().microsecondsSinceEpoch % 100000}';
    final budiId = budi.currentUser!.id;
    final sariId = sari.currentUser!.id;
    final roomId = await budi.chat.joinStockRoom(code);
    await sari.chat.joinStockRoom(code);
    final trust = await _psqlValue("select trust_level from public.profiles where id = '$sariId'");
    final room = budi.chat.connectRoom(roomId, me: budi.currentUser!);
    final events = room.events.asBroadcastStream();
    final connected = _waitFor(
      events,
      (e) => e is ConnectionChanged && e.status == RealtimeStatus.connected,
      timeout: const Duration(seconds: 30),
    );
    final sub = events.listen((_) {});
    try {
      final appointed =
          trust != null &&
          await _psql(
            "update public.profiles set trust_level = 2 where id = '$sariId'; "
            "insert into private.room_moderators (room_id, user_id) values ('$roomId', '$sariId')",
          );
      if (!appointed) {
        connected.ignore();
        markTestSkipped('docker exec psql is not available to appoint a room moderator');
        return;
      }
      await connected;
      await Future<void>.delayed(const Duration(seconds: 3));

      final muted = _waitFor(
        events,
        (e) => e is OwnRoomMuteChanged && e.mutedUntil != null,
        timeout: const Duration(seconds: 20),
      );
      final result = await sari.chatExtras.muteMember(roomId, budiId, const Duration(minutes: 5), ReportReason.spam);
      final notice = await muted as OwnRoomMuteChanged;
      expect(notice.mutedUntil!.difference(result.muteUntil!).inSeconds.abs(), lessThan(2));

      final own = await budi.chatExtras.stockRoomState(code);
      expect(own.mutes, isEmpty);
      expect(own.viewerMute(), isNotNull);
      final moderator = await sari.chatExtras.stockRoomState(code);
      expect(moderator.isModerator(sariId), isTrue);
      expect(moderator.mutedUntil(budiId), isNotNull);
      expect(moderator.viewerMute(), isNull);
      await expectLater(
        budi.chat.sendMessage(roomId, body: 'Masih bisu', clientId: const Uuid().v4()),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'room_muted')),
      );

      final unmuted = _waitFor(
        events,
        (e) => e is OwnRoomMuteChanged && e.mutedUntil == null,
        timeout: const Duration(seconds: 20),
      );
      expect(
        await _psql(
          "update private.room_mod_actions set undone_at = now() where room_id = '$roomId'; "
          "select private.room_mute_notice('$roomId', '$budiId')",
        ),
        isTrue,
      );
      await unmuted;
      expect((await budi.chatExtras.stockRoomState(code)).viewerMute(), isNull);
    } finally {
      await sub.cancel();
      await room.close();
      await _psql(
        "${trust == null ? '' : "update public.profiles set trust_level = $trust where id = '$sariId'; "}"
        "delete from private.push_queue where data ->> 'room_id' = '$roomId'; "
        "delete from public.notifications where payload ->> 'room_id' = '$roomId'; "
        "delete from public.chat_rooms where id = '$roomId'",
      );
    }
  }, skip: skip);

  test('link previews: each URL comes back with a known status', () async {
    final urls = ['https://example.com/it-${DateTime.now().microsecondsSinceEpoch}', 'https://www.idx.co.id/'];
    for (final url in urls) {
      final listenable = budi.linkPreviews.watch(url);
      final completer = Completer<LinkPreview>();
      void listener() {
        final value = listenable.value;
        if (value != null && value.status != LinkPreviewStatus.pending && !completer.isCompleted) {
          completer.complete(value);
        }
      }

      listenable.addListener(listener);
      try {
        final preview = await completer.future.timeout(const Duration(seconds: 30));
        expect(preview.url, url);
        expect(LinkPreviewStatus.values, contains(preview.status));
      } finally {
        listenable.removeListener(listener);
      }
    }
  }, skip: skip);

  test('analytics: track_events accepts whitelisted events without content text', () async {
    budi.analytics
      ..record(CommunityAnalyticsEvent.feedOpen, {'scope': 'global'})
      ..record(CommunityAnalyticsEvent.search, {'type': 'posts', 'query_length': 9, 'result_count': 3, 'query': 'x'})
      ..record('not_an_event');
    expect(budi.analytics.pending, 2);
    final result = await budi.analytics.flush();
    expect(result, isNotNull);
    if (!result!.disabled) expect(result.accepted, 2);
    expect(budi.analytics.pending, 0);
  }, skip: skip);

  test('message reactions with realtime and sharing a post to a DM', () async {
    final roomId = await budi.chat.getOrCreateDirectRoom(sari.currentUser!.id);
    final post = await budi.feed.createPost(body: 'Share integration ${DateTime.now().microsecondsSinceEpoch}');
    final budiRoom = budi.chat.connectRoom(roomId, me: budi.currentUser!);
    final budiEvents = budiRoom.events.asBroadcastStream();
    final sub = budiEvents.listen((_) {});
    final sentIds = <String>[];
    try {
      await _waitFor(budiEvents, (e) => e is SignalsConnectionChanged && e.status == RealtimeStatus.connected);
      final message = await budi.chat.sendMessage(
        roomId,
        body: 'Reaksi ${const Uuid().v4()}',
        clientId: const Uuid().v4(),
      );
      sentIds.add(message.id);

      final event = _waitFor(budiEvents, (e) => e is ReactionChanged && e.messageId == message.id);
      final reactions = await sari.chatExtras.react(message.id, '👍');
      expect(reactions.single.emoji, '👍');
      expect(reactions.single.count, 1);
      expect(reactions.single.mine, isTrue);
      final changed = await event as ReactionChanged;
      expect(changed.userId, sari.currentUser!.id);
      expect(changed.counts.single.count, 1);

      final page = await budi.chat.getMessages(roomId, limit: 5);
      final seen = page.items.firstWhere((m) => m.id == message.id);
      expect(seen.reactions.single.mine, isFalse);
      expect(await sari.chatExtras.react(message.id, '👍'), isEmpty);

      final shared = await budi.chatExtras.sharePost(roomId, post.id, body: 'Lihat ini');
      sentIds.add(shared.id);
      expect(shared.sharedPostId, post.id);
      expect(shared.sharedPost!.available, isTrue);
      final forSari = (await sari.chat.getMessages(roomId, limit: 5)).items.firstWhere((m) => m.id == shared.id);
      expect(forSari.sharedPost!.author!.username, 'budi_santoso');

      await budi.feed.deletePost(post.id);
      final gone = (await sari.chat.getMessages(roomId, limit: 5)).items.firstWhere((m) => m.id == shared.id);
      expect(gone.sharedPost!.available, isFalse);
    } finally {
      await sub.cancel();
      await budiRoom.close();
      for (final id in sentIds) {
        await budi.chat.deleteMessage(id);
      }
      try {
        await budi.feed.deletePost(post.id);
      } on CommunityException catch (_) {}
    }
  }, skip: skip);

  test('banners from get_client_config are visible to signed-in clients', () async {
    final id = const Uuid().v4();
    expect(
      await _psql(
        'insert into private.app_banners (id, title, body, level, dismissible, priority) '
        "values ('$id', 'IT banner', 'Isi', 'warning', false, 999)",
      ),
      isTrue,
    );
    try {
      final config = await budi.refreshClientConfig();
      final banner = config.banners.firstWhere((b) => b.id == id);
      expect(banner.level, CommunityBannerLevel.warning);
      expect(banner.dismissible, isFalse);
      expect(config.banners.first.priority, greaterThanOrEqualTo(banner.priority));
    } finally {
      await _psql("delete from private.app_banners where id = '$id'");
    }
  }, skip: skip);

  test('report_notification_event records opened and tapped for an inbox item', () async {
    final post = await budi.feed.createPost(body: 'Event integration ${DateTime.now().microsecondsSinceEpoch}');
    try {
      await sari.feed.likePost(post.id);
      AppNotification? notification;
      for (var i = 0; i < 20 && notification == null; i++) {
        final page = await budi.notifications.getNotifications(limit: 30);
        notification = page.items.where((n) => n.postId == post.id).firstOrNull;
        if (notification == null) await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(notification, isNotNull);
      await budi.reportNotificationTapped({'notification_id': notification!.id});
      expect(budi.notificationReporter.queuedCount, 0);
      expect(
        await _psql(
          'do \$\$ begin if (select count(*) from private.notification_events '
          "where notification_id = '${notification.id}') < 2 then raise exception 'missing'; end if; end \$\$",
        ),
        isTrue,
      );
    } finally {
      await budi.feed.deletePost(post.id);
    }
  }, skip: skip);

  test('drafts: save, list, update, delete and publishing removes the draft', () async {
    final id = const Uuid().v4();
    final first = await budi.drafts.save(
      PostDraft(clientDraftId: id, body: r'Draf integrasi $BBCA', stocks: const ['bbca'], updatedAt: DateTime.now()),
    );
    expect(first.status, DraftSyncStatus.synced);
    final listed = (await budi.drafts.list()).firstWhere((d) => d.clientDraftId == id);
    expect(listed.stocks, ['BBCA']);

    final second = await budi.drafts.save(listed.copyWith(body: r'Draf integrasi $BBCA diubah'));
    expect(second.status, DraftSyncStatus.synced);

    final post = await budi.feed.createPost(body: r'Terbit dari draf $BBCA', clientId: id);
    try {
      expect((await budi.drafts.list()).where((d) => d.clientDraftId == id), isEmpty);
    } finally {
      await budi.feed.deletePost(post.id);
    }

    final other = const Uuid().v4();
    await budi.drafts.save(PostDraft(clientDraftId: other, body: 'Hapus saya', updatedAt: DateTime.now()));
    await budi.drafts.delete(other);
    expect((await budi.drafts.list()).where((d) => d.clientDraftId == other), isEmpty);
  }, skip: skip);

  test('stock cards round trip through send_message and get_messages', () async {
    final roomId = await budi.chat.getOrCreateDirectRoom(sari.currentUser!.id);
    final sent = await budi.chatExtras.sendStockCards(roomId, ['bbca', 'TLKM'], clientId: const Uuid().v4());
    try {
      expect(sent.stockCodes, ['BBCA', 'TLKM']);
      final seen = (await sari.chat.getMessages(roomId, limit: 5)).items.firstWhere((m) => m.id == sent.id);
      expect(seen.stockCodes, ['BBCA', 'TLKM']);
      await expectLater(
        budi.chatExtras.sendStockCards(roomId, ['BBCA', 'TLKM', 'ASII', 'GOTO'], clientId: const Uuid().v4()),
        throwsA(isA<CommunityException>()),
      );
    } finally {
      await budi.chat.deleteMessage(sent.id);
    }
  }, skip: skip);

  test('gap fill through the message index finds rows missed in the middle of the stream', () async {
    final roomId = await budi.chat.getOrCreateDirectRoom(sari.currentUser!.id);
    final start = (await budi.chat.getMessages(roomId, limit: 1)).items.firstOrNull;
    final horizon = start?.cursor ?? '1970-01-01T00:00:00.000Z|00000000-0000-0000-0000-000000000000';
    final sent = <ChatMessage>[];
    for (var i = 0; i < 3; i++) {
      sent.add(await sari.chat.sendMessage(roomId, body: 'Celah $i', clientId: const Uuid().v4()));
    }
    try {
      final index = budi.chat as MessageIndexRepository;
      final page = await index.getMessageIdsAfter(roomId, horizon, limit: 2);
      expect(page.ids, [sent[0].id, sent[1].id]);
      expect(page.hasMore, isTrue);
      final rest = await index.getMessageIdsAfter(roomId, page.last!, limit: 2);
      expect(rest.ids, [sent[2].id]);
      expect(rest.hasMore, isFalse);
      expect(rest.last, sent[2].cursor);

      final missing = await index.getMessagesByIds(roomId, [sent[1].id]);
      expect(missing.single.body, 'Celah 1');
      expect(missing.single.cursor, sent[1].cursor);
    } finally {
      for (final message in sent) {
        await sari.chat.deleteMessage(message.id);
      }
    }
  }, skip: skip);
}

Future<bool> _psql(String sql) async {
  try {
    final result = await Process.run('docker', [
      'exec',
      'olt-social-db-1',
      'psql',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-tAc',
      sql,
    ]);
    return result.exitCode == 0;
  } on ProcessException catch (_) {
    return false;
  }
}

Future<String?> _psqlValue(String sql) async {
  try {
    final result = await Process.run('docker', [
      'exec',
      'olt-social-db-1',
      'psql',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-tAc',
      sql,
    ]);
    final value = (result.stdout as String).trim();
    return result.exitCode == 0 && value.isNotEmpty ? value : null;
  } on ProcessException catch (_) {
    return null;
  }
}
