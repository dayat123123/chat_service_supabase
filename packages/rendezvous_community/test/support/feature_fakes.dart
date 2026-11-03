import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rendezvous_community/rendezvous_community.dart';
import 'package:rendezvous_community/src/core/storage/local_values.dart';
import 'package:rendezvous_community/src/features/config/data/repositories/banner_dismissal_repository_impl.dart';
import 'package:rendezvous_community/src/features/drafts/data/repositories/post_draft_repository_impl.dart';

import 'fakes.dart';

class FakeConfigRepository implements ClientConfigRepository {
  FakeConfigRepository([this.config = const ClientConfig()]);

  ClientConfig config;
  Object? error;
  int calls = 0;
  final requests = <(String?, String?)>[];

  @override
  Future<ClientConfig> fetch({String? platform, String? appVersion}) async {
    calls++;
    requests.add((platform, appVersion));
    final failure = error;
    if (failure != null) throw failure;
    return config.copyWith(fetchedAt: DateTime.now().toUtc());
  }
}

class FakeAnalyticsRepository implements AnalyticsRepository {
  final batches = <List<AnalyticsEvent>>[];
  AnalyticsResult result = const AnalyticsResult(accepted: 1);
  Object? error;

  @override
  Future<AnalyticsResult> track(List<AnalyticsEvent> events, {String? platform, String? appVersion}) async {
    batches.add(events);
    final failure = error;
    if (failure != null) throw failure;
    return AnalyticsResult(accepted: events.length, disabled: result.disabled);
  }
}

class FakeLinkPreviewRepository implements LinkPreviewRepository {
  final lookups = <List<String>>[];
  LinkPreview Function(String url) answer = (url) => LinkPreview(url: url);

  @override
  Future<List<LinkPreview>> lookup(List<String> urls) async {
    lookups.add(urls);
    return [for (final url in urls) answer(url)];
  }
}

class FakeBookmarkRepository extends Fake implements BookmarkRepository {
  final calls = <(String, bool?)>[];
  Object? error;
  List<Post> saved = const [];

  @override
  Future<bool> setBookmarked(String postId, {bool? bookmarked}) async {
    calls.add((postId, bookmarked));
    final failure = error;
    if (failure != null) throw failure;
    return bookmarked ?? true;
  }

  @override
  Future<Paged<Post>> getBookmarks({String? cursor, int limit = 20}) async => Paged(saved);
}

class FakeEditRepository extends Fake implements ContentEditRepository {
  final posts = <(String, String)>[];
  final comments = <(String, String)>[];
  Object? error;

  @override
  Future<Post> editPost(String postId, String body) async {
    posts.add((postId, body));
    final failure = error;
    if (failure != null) throw failure;
    return samplePost(id: postId, body: body).copyWith(editedAt: DateTime.now().toUtc(), cursor: 'srv');
  }

  @override
  Future<ThreadComment> editComment(String commentId, String body) async {
    comments.add((commentId, body));
    final failure = error;
    if (failure != null) throw failure;
    return comment(commentId, depth: 0, path: '1', body: body).copyWith(editedAt: DateTime.now().toUtc());
  }
}

class FakeChatExtrasRepository extends Fake implements ChatExtrasRepository {
  final reactions = <(String, String?)>[];
  List<MessageReaction>? answer;
  Object? reactError;
  StockRoomState stockRoom = const StockRoomState();
  final shares = <(String, String, String?)>[];

  @override
  Future<List<MessageReaction>> react(String messageId, String? emoji) async {
    reactions.add((messageId, emoji));
    final failure = reactError;
    if (failure != null) throw failure;
    return answer ?? [if (emoji != null) MessageReaction(emoji: emoji, count: 1, mine: true)];
  }

  @override
  Future<StockRoomState> stockRoomState(String stockCode) async => stockRoom;

  @override
  Future<ChatMessage> sharePost(String roomId, String postId, {String? body, String? clientId}) async {
    shares.add((roomId, postId, body));
    return ChatMessage(
      id: 'share-$roomId',
      roomId: roomId,
      senderId: me.id,
      body: body,
      sharedPostId: postId,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

class FakeMessageRequestRepository extends Fake implements MessageRequestRepository {
  List<MessageRequest> requests = const [];
  int count = 0;
  final responses = <(String, MessageRequestAction)>[];
  DmPolicySettings policy = const DmPolicySettings();
  DmRequestState state = const DmRequestState();

  @override
  Future<DmRequestState> requestState(String roomId) async => state;

  @override
  Future<List<MessageRequest>> getRequests({int limit = 50, DateTime? before}) async => requests;

  @override
  Future<int> requestCount() async => count;

  @override
  Future<void> respond(String roomId, MessageRequestAction action) async => responses.add((roomId, action));

  @override
  Future<DmPolicySettings> dmPolicy() async => policy;

  @override
  Future<DmPolicySettings> setDmPolicy(DmPolicy value) async => policy = policy.copyWith(policy: value);
}

class FakeAppealRepository extends Fake implements AppealRepository {
  final created = <(AppealTargetType, String, String)>[];
  List<Appeal> appeals = const [];
  List<Sanction> sanctions = const [];
  List<ModeratedContent> moderated = const [];
  Object? error;

  @override
  Future<List<ModeratedContent>> myModeratedContent({int limit = 50}) async => moderated;

  @override
  Future<Appeal> createAppeal(AppealTargetType targetType, String targetId, String reason) async {
    final failure = error;
    if (failure != null) throw failure;
    created.add((targetType, targetId, reason));
    return Appeal(id: 'a-1', targetType: targetType, targetId: targetId, reason: reason, createdAt: DateTime.now());
  }

  @override
  Future<List<Appeal>> myAppeals() async => appeals;

  @override
  Future<List<Sanction>> mySanctions() async => sanctions;
}

class FakeNotificationPreferencesRepository extends Fake implements NotificationPreferencesRepository {
  NotificationPreferences preferences = const NotificationPreferences(
    types: [
      NotificationTypePreference(type: 'like', inApp: true),
      NotificationTypePreference(type: 'olt.trade'),
    ],
  );
  final updates = <(List<NotificationPreferenceChange>, QuietHours?)>[];
  Object? error;

  @override
  Future<NotificationPreferences> get() async => preferences;

  @override
  Future<NotificationPreferences> update({
    List<NotificationPreferenceChange> types = const [],
    QuietHours? quietHours,
  }) async {
    updates.add((types, quietHours));
    final failure = error;
    if (failure != null) throw failure;
    preferences = preferences.copyWith(
      types: [
        for (final t in preferences.types)
          if (types.where((c) => c.type == t.type).firstOrNull case final change?)
            t.copyWith(inApp: change.inApp ?? t.inApp, push: change.push ?? t.push)
          else
            t,
      ],
      quietHours: quietHours ?? preferences.quietHours,
    );
    return preferences;
  }
}

class FakeSearchRepository extends Fake implements SearchRepository {
  final queries = <(String, SearchType, String?, int)>[];
  SearchResults Function(String query, SearchType type, String? cursor) answer = (query, type, cursor) =>
      SearchResults(query: query, type: type);
  List<HashtagSummary> trending = const [];

  @override
  Future<SearchResults> search(String query, {SearchType type = SearchType.all, String? cursor, int limit = 20}) async {
    queries.add((query, type, cursor, limit));
    return answer(query, type, cursor);
  }

  @override
  Future<List<HashtagSummary>> trendingHashtags({TrendWindow window = TrendWindow.day, int limit = 10}) async =>
      trending;
}

class FakeTrendingRepository extends Fake implements TrendingRepository {
  StockSentiment sentiment = const StockSentiment(code: 'BBCA');
  TrendingSnapshot Function(TrendWindow window) snapshot = (window) => TrendingSnapshot(window: window);

  @override
  Future<TrendingSnapshot> trending({TrendWindow window = TrendWindow.day}) async => snapshot(window);

  @override
  Future<StockSentiment> stockSentiment(String stockCode) async => sentiment;
}

class FakeFeatureDependencies implements CommunityFeatureDependencies {
  FakeFeatureDependencies({
    ClientConfig config = const ClientConfig(),
    FakeConfigRepository? configRepository,
    this.signedIn = true,
  }) : configRepository = configRepository ?? FakeConfigRepository(config) {
    configService = ClientConfigService(this.configRepository, initial: config);
    analytics = CommunityAnalytics(
      analyticsRepository,
      enabled: () => configService.current.feature(CommunityFlags.analytics),
      signedIn: () => signedIn,
    );
    linkPreviews = LinkPreviewLoader(linkPreviewRepository, batchDelay: Duration.zero);
  }

  final FakeConfigRepository configRepository;
  final analyticsRepository = FakeAnalyticsRepository();
  final linkPreviewRepository = FakeLinkPreviewRepository();
  bool signedIn;

  @override
  late final ClientConfigService configService;
  @override
  late final CommunityAnalytics analytics;
  @override
  late final LinkPreviewLoader linkPreviews;
  @override
  final FakeSearchRepository search = FakeSearchRepository();
  @override
  final FakeTrendingRepository trending = FakeTrendingRepository();
  @override
  final FakeBookmarkRepository bookmarks = FakeBookmarkRepository();
  @override
  final FakeEditRepository edits = FakeEditRepository();
  @override
  final FakeChatExtrasRepository chatExtras = FakeChatExtrasRepository();
  @override
  final FakeMessageRequestRepository messageRequests = FakeMessageRequestRepository();
  @override
  final FakeAppealRepository appeals = FakeAppealRepository();
  @override
  final FakeNotificationPreferencesRepository notificationPreferences = FakeNotificationPreferencesRepository();
  final notificationEvents = FakeNotificationEventRepository();
  final draftRepository = FakePostDraftRepository();
  final localValues = MemoryLocalValues();
  @override
  late final NotificationReporter notificationReporter = NotificationReporter(notificationEvents);
  @override
  late final BannerDismissals bannerDismissals = BannerDismissals(BannerDismissalRepositoryImpl(localValues));
  @override
  late final CommunityDrafts drafts = CommunityDrafts(draftRepository, PostDraftStoreImpl(localValues));

  void dispose() {
    analytics.dispose();
    linkPreviews.dispose();
  }
}

ClientConfig loadedConfig({bool social = true, Map<String, bool>? flags}) => ClientConfig(
  socialEnabled: social,
  flags: flags ?? {for (final flag in CommunityFlags.all) flag: true},
  fetchedAt: DateTime.now().toUtc(),
);

Post samplePost({
  String id = 'p-1',
  String body = r'Analisis $BBCA',
  UserSummary author = me,
  DateTime? createdAt,
  bool bookmarked = false,
}) => Post(
  id: id,
  author: author,
  body: body,
  stockCodes: const ['BBCA'],
  createdAt: createdAt ?? DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
  cursor: 'c-$id',
  isBookmarked: bookmarked,
);

Future<void> pumpFeatureApp(
  WidgetTester tester,
  Widget child, {
  CommunityDependencies? dependencies,
  CommunityFeatureDependencies? features,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: CommunityLocalizations.localizationsDelegates,
      supportedLocales: CommunityLocalizations.supportedLocales,
      home: Scaffold(
        body: CommunityScope(
          dependencies: dependencies ?? FakeDependencies(),
          child: features == null ? child : CommunityFeatureScope(dependencies: features, child: child),
        ),
      ),
    ),
  );
}

class FakeNotificationEventRepository implements NotificationEventRepository {
  final reported = <(NotificationEvent, NotificationSource)>[];
  Object? error;

  @override
  Future<void> report(NotificationEvent event, NotificationSource source) async {
    final failure = error;
    if (failure != null) throw failure;
    reported.add((event, source));
  }
}

class FakePostDraftRepository implements PostDraftRepository {
  final saved = <String, PostDraft>{};
  final deleted = <String>[];
  Object? saveError;
  Object? listError;
  DateTime Function() clock = () => DateTime.now().toUtc();

  @override
  Future<List<PostDraft>> list() async {
    final failure = listError;
    if (failure != null) throw failure;
    return saved.values.toList();
  }

  @override
  Future<PostDraft> save(PostDraft draft, {DateTime? baseUpdatedAt}) async {
    final failure = saveError;
    if (failure != null) throw failure;
    final stored = draft.copyWith(updatedAt: clock(), serverUpdatedAt: clock());
    saved[draft.clientDraftId] = stored;
    return stored;
  }

  @override
  Future<void> delete(String clientDraftId) async {
    deleted.add(clientDraftId);
    saved.remove(clientDraftId);
  }
}
