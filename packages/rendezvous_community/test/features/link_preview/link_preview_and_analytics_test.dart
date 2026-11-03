import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/link_preview/data/repositories/link_preview_repository_impl.dart';

import '../../support/fakes.dart';
import '../../support/feature_fakes.dart';
import '../../support/mock_api.dart';

void main() {
  group('link previews', () {
    test('repository maps rows and builds the public image URL', () async {
      final api = mockApi();
      when(
        () => api.publicUrl('link-previews', any()),
      ).thenAnswer((i) => 'http://api.test/storage/v1/object/public/link-previews/${i.positionalArguments[1]}');
      when(() => api.rpcRows('get_link_previews', any())).thenAnswer(
        (_) async => [
          {
            'url': 'https://idx.co.id/a',
            'status': 'ok',
            'title': 'IDX',
            'description': 'Bursa',
            'site_name': 'IDX',
            'image_path': 'h/n/preview.jpg',
            'image_width': 600,
            'image_height': 315,
            'final_url': 'https://www.idx.co.id/id/a',
            'fetched_at': '2026-11-03T05:00:00Z',
          },
        ],
      );
      final previews = await LinkPreviewRepositoryImpl(api).lookup(['https://idx.co.id/a']);
      verify(
        () => api.rpcRows('get_link_previews', {
          'p_urls': ['https://idx.co.id/a'],
        }),
      ).called(1);
      final preview = previews.single;
      expect(preview.hasCard, isTrue);
      expect(preview.domain, 'idx.co.id');
      expect(preview.imageUrl, endsWith('/link-previews/h/n/preview.jpg'));
    });

    testWidgets('loader batches URLs requested together and caches the answer', (tester) async {
      final repository = FakeLinkPreviewRepository()
        ..answer = (url) => LinkPreview(url: url, status: LinkPreviewStatus.ok, title: 'T');
      final loader = LinkPreviewLoader(repository);
      addTearDown(loader.dispose);
      final a = loader.watch('https://a.com');
      final b = loader.watch('https://b.com');
      loader.watch('https://a.com');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.lookups, [
        ['https://a.com', 'https://b.com'],
      ]);
      expect(a.value!.title, 'T');
      expect(b.value!.status, LinkPreviewStatus.ok);
      loader.watch('https://a.com');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.lookups, hasLength(1));
    });

    testWidgets('pending previews are retried at most twice, then treated as none', (tester) async {
      final repository = FakeLinkPreviewRepository()
        ..answer = (url) => LinkPreview(url: url, status: LinkPreviewStatus.pending);
      final loader = LinkPreviewLoader(repository);
      addTearDown(loader.dispose);
      final preview = loader.watch('https://slow.com');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(repository.lookups, hasLength(3));
      expect(preview.value!.status, LinkPreviewStatus.none);
    });

    testWidgets('the card shows the final domain and opens only after confirmation', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      features.linkPreviewRepository.answer = (url) => LinkPreview(
        url: url,
        status: LinkPreviewStatus.ok,
        title: 'Laporan keuangan',
        siteName: 'Situs',
        finalUrl: 'https://www.contoh.co.id/laporan',
      );
      await pumpFeatureApp(tester, const LinkPreviewCard(text: 'Baca https://bit.ly/x ya'), features: features);
      await tester.pumpAndSettle();
      expect(find.text('Laporan keuangan'), findsOneWidget);
      expect(find.text('contoh.co.id'), findsOneWidget);
      expect(features.linkPreviewRepository.lookups.single, ['https://bit.ly/x']);
    });

    testWidgets('openCommunityLink asks first and shows the real host', (tester) async {
      final opened = <Uri>[];
      await pumpFeatureApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openCommunityLink(
              context,
              Uri.parse('https://evil.example.com/path?x=1'),
              launcher: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.textContaining('evil.example.com di luar aplikasi'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'evil.example.com');
    });

    testWidgets('SocialText makes hashtags and http(s) links tappable, other schemes stay text', (tester) async {
      final tags = <String>[];
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      await pumpFeatureApp(
        tester,
        const SocialText('Cek #Dividen di https://idx.co.id/x dan javascript:alert(1)'),
        dependencies: FakeDependencies(callbacks: CommunityCallbacks(onHashtagTap: (context, tag) => tags.add(tag))),
        features: features,
      );
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final spans = <TextSpan>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) spans.add(span);
        return true;
      });
      expect(spans.map((s) => s.text), ['#Dividen', 'https://idx.co.id/x']);
    });
  });

  group('analytics', () {
    test('only whitelisted properties survive and text is dropped', () {
      expect(
        sanitizeAnalyticsProps({
          'stock_code': r'$bbca',
          'post_id': '7F0B3C1E-1111-4222-8333-944444444444',
          'hashtag': '#Dividen',
          'source': 'feed',
          'scope': 'nowhere',
          'type': 'posts',
          'result_count': 3,
          'query_length': -1,
          'has_poll': true,
          'query': 'kata kunci rahasia',
          'body': 'isi post',
        }),
        {
          'stock_code': 'BBCA',
          'post_id': '7f0b3c1e-1111-4222-8333-944444444444',
          'hashtag': 'dividen',
          'source': 'feed',
          'type': 'posts',
          'result_count': 3,
          'has_poll': true,
        },
      );
    });

    test('batches of at most 50, flush at the threshold, unknown events ignored', () async {
      final repository = FakeAnalyticsRepository();
      final analytics = CommunityAnalytics(repository, enabled: () => true, signedIn: () => true, flushThreshold: 1000);
      analytics.record('made_up');
      for (var i = 0; i < 120; i++) {
        analytics.record(CommunityAnalyticsEvent.feedOpen, {'scope': 'global'});
      }
      final result = await analytics.flush();
      expect(repository.batches.map((b) => b.length), [50, 50, 20]);
      expect(result!.accepted, 120);
      expect(analytics.pending, 0);
    });

    test('drops a failed batch, waits while signed out, and stops when the server disables it', () async {
      final repository = FakeAnalyticsRepository();
      var signedIn = false;
      final analytics = CommunityAnalytics(repository, enabled: () => true, signedIn: () => signedIn);
      analytics.record(CommunityAnalyticsEvent.stockTap, {'stock_code': 'BBCA'});
      expect(await analytics.flush(), isNull);
      expect(analytics.pending, 1);

      signedIn = true;
      repository.error = Exception('offline');
      await analytics.flush();
      expect(analytics.pending, 0);

      repository
        ..error = null
        ..result = const AnalyticsResult(disabled: true);
      analytics.record(CommunityAnalyticsEvent.stockTap);
      final result = await analytics.flush();
      expect(result!.disabled, isTrue);
      analytics.record(CommunityAnalyticsEvent.stockTap);
      expect(analytics.pending, 0);
      analytics.reset();
      analytics.record(CommunityAnalyticsEvent.stockTap);
      expect(analytics.pending, 1);
    });

    test('the analytics flag turning off discards queued events', () async {
      final repository = FakeAnalyticsRepository();
      var enabled = true;
      final analytics = CommunityAnalytics(repository, enabled: () => enabled, signedIn: () => true);
      analytics.record(CommunityAnalyticsEvent.orderTap, {'side': 'buy'});
      enabled = false;
      expect(await analytics.flush(), isNull);
      expect(repository.batches, isEmpty);
      expect(analytics.pending, 0);
    });
  });

  group('push helpers', () {
    test('OLT trade pushes are not community pushes', () {
      final trade = {'source': 'olt', 'kind': 'olt.trade', 'cust_id': 'W137', 'message_id': 't-1', 'screen': 'orders'};
      expect(isCommunityPush(trade), isFalse);
      expect(isOltPush(trade), isTrue);
      final appeal = {'source': 'rendezvous_community', 'type': 'appeal', 'notification_id': 'n-1'};
      expect(isCommunityPush(appeal), isTrue);
      expect(isOltPush(appeal), isFalse);
    });

    testWidgets('openCommunityPush leaves olt.* pushes to the host', (tester) async {
      late bool handled;
      await pumpFeatureApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => handled = openCommunityPush(context, {'source': 'olt', 'kind': 'olt.trade'}),
            child: const Text('push'),
          ),
        ),
      );
      await tester.tap(find.text('push'));
      expect(handled, isFalse);
    });
  });

  group('composer', () {
    testWidgets('an initial chart image is uploaded and share_chart is recorded on submit', (tester) async {
      final features = FakeFeatureDependencies(config: loadedConfig());
      addTearDown(features.dispose);
      final media = _HeldMedia();
      final feed = _CreatingFeed();
      await pumpFeatureApp(
        tester,
        CommunityComposePost(
          initialStock: 'BBCA',
          initialImage: CommunityComposerImage(bytes: Uint8List(4), mimeType: 'image/png'),
        ),
        dependencies: FakeDependencies(feed: feed, mediaRepository: media),
        features: features,
      );
      await tester.pumpAndSettle();
      expect(media.uploads, 1);
      expect(find.text('Menunggu tinjauan'), findsOneWidget);

      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();
      expect(feed.created.single.$2.single.path, 'posts/u/chart.png');
      await features.analytics.flush();
      final events = features.analyticsRepository.batches.single;
      expect(events.map((e) => e.name), ['post_create', 'share_chart']);
      expect(events.last.props, {'post_id': '7f0b3c1e-1111-4222-8333-944444444444', 'stock_code': 'BBCA'});
    });
  });
}

class _HeldMedia extends Fake implements MediaRepository {
  int uploads = 0;

  @override
  Future<Attachment> uploadPostImage(Uint8List bytes, {required String mimeType}) async {
    uploads++;
    return const Attachment(path: 'posts/u/chart.png', mime: 'image/png', held: true);
  }
}

class _CreatingFeed extends FakeFeedRepository {
  final created = <(String, List<Attachment>)>[];

  @override
  Future<Post> createPost({
    required String body,
    Sentiment? sentiment,
    List<Attachment> attachments = const [],
    PollDraft? poll,
    String? clientId,
  }) async {
    created.add((body, attachments));
    return samplePost(id: '7f0b3c1e-1111-4222-8333-944444444444', body: body).copyWith(attachments: attachments);
  }
}
