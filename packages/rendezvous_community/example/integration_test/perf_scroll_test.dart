import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

import 'perf/perf_fixture.dart';

const _postCount = 200;
const _messageCount = 500;

Finder _list(AxisDirection direction) =>
    find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == direction).first;

Future<void> _scrollThrough(WidgetTester tester, Finder list, {required bool Function() complete}) async {
  var stalls = 0;
  while (stalls < 3) {
    final position = tester.state<ScrollableState>(list).position;
    final target = math.min(position.pixels + 2400, position.maxScrollExtent);
    if (target - position.pixels < 1) {
      stalls = complete() ? 3 : stalls + 1;
      await tester.pump(const Duration(milliseconds: 200));
      continue;
    }
    stalls = 0;
    await position.animateTo(target, duration: const Duration(milliseconds: 1200), curve: Curves.linear);
    await tester.pump(const Duration(milliseconds: 50));
  }
  final position = tester.state<ScrollableState>(list).position;
  await position.animateTo(
    0,
    duration: Duration(milliseconds: math.max(1200, position.pixels ~/ 2)),
    curve: Curves.linear,
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _measure(IntegrationTestWidgetsFlutterBinding binding, String key, Future<void> Function() action) =>
    binding.watchPerformance(() => binding.traceAction(action, reportKey: key), reportKey: '${key}_frames');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('feed and chat scroll stay within frame budgets', (tester) async {
    final images = await PerfImages.create();
    final loader = CommunityImageLoader(client: images.client());
    final dependencies = PerfDependencies(
      feed: PerfFeedRepository(perfPosts(_postCount)),
      chat: PerfChatRepository(perfMessages(_messageCount)),
    );
    final rssBefore = ProcessInfo.currentRss;

    await tester.pumpWidget(
      PerfApp(
        dependencies: dependencies,
        images: loader,
        child: const CommunityFeedList(scope: FeedScope.following(), emptyMessage: 'Kosong'),
      ),
    );
    await tester.pumpAndSettle();
    var feedCards = 0;
    await _measure(
      binding,
      'feed_scroll',
      () => _scrollThrough(
        tester,
        _list(AxisDirection.down),
        complete: () {
          feedCards = math.max(
            feedCards,
            tester.widgetList(find.textContaining('hari ke-199', findRichText: true)).length,
          );
          return feedCards > 0;
        },
      ),
    );
    expect(feedCards, greaterThan(0), reason: 'the last of $_postCount posts was reached');
    final rssFeed = ProcessInfo.currentRss;

    await tester.pumpWidget(
      PerfApp(
        key: const ValueKey('chat'),
        dependencies: dependencies,
        images: loader,
        child: const CommunityChatRoom(roomId: 'perf-room'),
      ),
    );
    await tester.pumpAndSettle();
    var oldestSeen = false;
    await _measure(
      binding,
      'chat_scroll',
      () => _scrollThrough(
        tester,
        _list(AxisDirection.up),
        complete: () {
          oldestSeen = oldestSeen || find.textContaining('Pesan 0 ', findRichText: true).evaluate().isNotEmpty;
          return oldestSeen;
        },
      ),
    );
    expect(oldestSeen, isTrue, reason: 'the oldest of $_messageCount messages was reached');

    binding.reportData ??= {};
    binding.reportData!['memory'] = {
      'rss_before_mb': rssBefore / (1024 * 1024),
      'rss_after_feed_mb': rssFeed / (1024 * 1024),
      'rss_after_chat_mb': ProcessInfo.currentRss / (1024 * 1024),
      'max_rss_mb': ProcessInfo.maxRss / (1024 * 1024),
      'image_cache_bytes': PaintingBinding.instance.imageCache.currentSizeBytes,
      'image_cache_entries': PaintingBinding.instance.imageCache.currentSize,
    };
  });
}
