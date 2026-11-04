import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/app/community_account_scope.dart';
import 'package:rendezvous_community/src/app/community_dependencies.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_offline_scope.dart';
import 'package:rendezvous_community/src/app/community_support_scope.dart';
import 'package:rendezvous_community/src/core/auth/auth_bridge_client.dart';
import 'package:rendezvous_community/src/core/auth/social_session.dart';
import 'package:rendezvous_community/src/core/auth/token_manager.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/network/community_connectivity.dart';
import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/core/storage/image_disk_cache.dart';
import 'package:rendezvous_community/src/core/storage/local_values.dart';
import 'package:rendezvous_community/src/core/storage/offline_cache.dart';
import 'package:rendezvous_community/src/core/storage/offline_store.dart';
import 'package:rendezvous_community/src/core/storage/platform_image_disk_cache.dart';
import 'package:rendezvous_community/src/core/storage/platform_offline_stores.dart';
import 'package:rendezvous_community/src/features/account/data/repositories/account_repository_impl.dart';
import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';
import 'package:rendezvous_community/src/features/account/domain/repositories/account_repository.dart';
import 'package:rendezvous_community/src/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/analytics/domain/services/community_analytics.dart';
import 'package:rendezvous_community/src/features/appeals/data/repositories/appeal_repository_impl.dart';
import 'package:rendezvous_community/src/features/appeals/domain/repositories/appeal_repository.dart';
import 'package:rendezvous_community/src/features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import 'package:rendezvous_community/src/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:rendezvous_community/src/features/chat/data/local/chat_local_cache.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_extras_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/outbox_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_cache_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_extras_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/delivery_tracker.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/message_outbox.dart';
import 'package:rendezvous_community/src/features/config/data/repositories/banner_dismissal_repository_impl.dart';
import 'package:rendezvous_community/src/features/config/data/repositories/client_config_repository_impl.dart';
import 'package:rendezvous_community/src/features/config/domain/entities/client_config.dart';
import 'package:rendezvous_community/src/features/config/domain/services/banner_dismissals.dart';
import 'package:rendezvous_community/src/features/config/domain/services/client_config_service.dart';
import 'package:rendezvous_community/src/features/drafts/data/repositories/post_draft_repository_impl.dart';
import 'package:rendezvous_community/src/features/drafts/domain/services/community_drafts.dart';
import 'package:rendezvous_community/src/features/edit/data/repositories/content_edit_repository_impl.dart';
import 'package:rendezvous_community/src/features/edit/domain/repositories/content_edit_repository.dart';
import 'package:rendezvous_community/src/features/feed/data/local/feed_local_cache.dart';
import 'package:rendezvous_community/src/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_cache_repository.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/features/legal/data/repositories/legal_repository_impl.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/community_consent.dart';
import 'package:rendezvous_community/src/features/link_preview/data/repositories/link_preview_repository_impl.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/services/link_preview_loader.dart';
import 'package:rendezvous_community/src/features/media/data/repositories/media_repository_impl.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/features/message_requests/data/repositories/message_request_repository_impl.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/repositories/message_request_repository.dart';
import 'package:rendezvous_community/src/features/moderation/data/repositories/moderation_repository_impl.dart';
import 'package:rendezvous_community/src/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:rendezvous_community/src/features/notifications/data/repositories/notification_event_repository_impl.dart';
import 'package:rendezvous_community/src/features/notifications/data/repositories/notification_preferences_repository_impl.dart';
import 'package:rendezvous_community/src/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_event.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rendezvous_community/src/features/notifications/domain/services/notification_reporter.dart';
import 'package:rendezvous_community/src/features/poll/data/repositories/poll_repository_impl.dart';
import 'package:rendezvous_community/src/features/poll/domain/repositories/poll_repository.dart';
import 'package:rendezvous_community/src/features/post/data/repositories/comment_repository_impl.dart';
import 'package:rendezvous_community/src/features/post/domain/repositories/comment_repository.dart';
import 'package:rendezvous_community/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:rendezvous_community/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:rendezvous_community/src/features/push/data/repositories/push_repository_impl.dart';
import 'package:rendezvous_community/src/features/push/domain/entities/community_push_message.dart';
import 'package:rendezvous_community/src/features/push/domain/services/push_registrar.dart';
import 'package:rendezvous_community/src/features/search/data/repositories/search_repository_impl.dart';
import 'package:rendezvous_community/src/features/search/domain/repositories/search_repository.dart';
import 'package:rendezvous_community/src/features/stocks/data/repositories/stock_repository_impl.dart';
import 'package:rendezvous_community/src/features/stocks/domain/repositories/stock_repository.dart';
import 'package:rendezvous_community/src/features/support/data/repositories/support_chat_repository.dart';
import 'package:rendezvous_community/src/features/support/data/repositories/support_repository_impl.dart';
import 'package:rendezvous_community/src/features/support/domain/repositories/support_repository.dart';
import 'package:rendezvous_community/src/features/trending/data/repositories/trending_repository_impl.dart';
import 'package:rendezvous_community/src/features/trending/domain/repositories/trending_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/domain/official_accounts.dart';
import 'package:rendezvous_community/src/shared/presentation/images/community_image_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

CommunityPlatform? defaultCommunityPlatform() {
  if (kIsWeb) return CommunityPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => CommunityPlatform.android,
    TargetPlatform.iOS => CommunityPlatform.ios,
    TargetPlatform.windows => CommunityPlatform.windows,
    TargetPlatform.macOS => CommunityPlatform.macos,
    TargetPlatform.linux => CommunityPlatform.linux,
    TargetPlatform.fuchsia => null,
  };
}

class RendezvousCommunity
    implements
        CommunityDependencies,
        CommunitySupportDependencies,
        CommunityAccountDependencies,
        CommunityFeatureDependencies,
        CommunityOfflineDependencies {
  RendezvousCommunity._({
    required this.client,
    required this._tokens,
    required this._chatImpl,
    required this.callbacks,
    required this.feed,
    required this.comments,
    required this.polls,
    required this.profiles,
    required this.stocks,
    required this.notifications,
    required this.moderation,
    required this.media,
    required this.support,
    required this.supportChat,
    required this._push,
    required this.consent,
    required this._account,
    required this.configService,
    required this.search,
    required this.trending,
    required this.bookmarks,
    required this.edits,
    required this.chatExtras,
    required this.messageRequests,
    required this.appeals,
    required this.notificationPreferences,
    required this.linkPreviews,
    required this.analytics,
    required this.notificationReporter,
    required this.bannerDismissals,
    required this.drafts,
    required this.connectivity,
    required this._offline,
    required this.chatCache,
    required this.feedCache,
    required this.outbox,
    required this.images,
    required bool trackDelivery,
  }) {
    if (trackDelivery) {
      _delivery = DeliveryTracker(_chatImpl, currentUserId: () => currentUser?.id);
      if (_tokens.currentSession != null) _delivery!.start();
    }
  }

  static RendezvousCommunity? _instance;

  static RendezvousCommunity get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('RendezvousCommunity is not initialized; call RendezvousCommunity.initialize() at startup');
    }
    return instance;
  }

  static bool get isInitialized => _instance != null;

  static Future<RendezvousCommunity> initialize({
    required String supabaseUrl,
    required String anonKey,
    String? authBridgeUrl,
    required Future<String?> Function() tokenProvider,
    CommunityStockTapCallback? onStockTap,
    CommunityUserTapCallback? onUserTap,
    CommunityPostTapCallback? onPostTap,
    CommunityRoomTapCallback? onRoomTap,
    CommunityStockSearch? stockSearch,
    CommunityStockInfoProvider? stockInfo,
    CommunityHashtagTapCallback? onHashtagTap,
    CommunityOltNotificationTapCallback? onOltNotificationTap,
    String? appVersion,
    CommunityPlatform? platform,
    CommunityUpdateRequiredCallback? onUpdateRequired,
    bool signInEagerly = true,
    bool trackDelivery = true,
    bool offlineCache = true,
    int offlineMessageLimit = 200,
    CommunityImageCacheConfig imageCache = const CommunityImageCacheConfig(),
    http.Client? httpClient,
    CommunityLogHandler? logHandler,
    Level? logLevel,
  }) async {
    await _instance?.dispose();
    CommunityLoggers.configure(handler: logHandler, level: logLevel);
    final social = create(
      supabaseUrl: supabaseUrl,
      anonKey: anonKey,
      authBridgeUrl: authBridgeUrl,
      tokenProvider: tokenProvider,
      onStockTap: onStockTap,
      onUserTap: onUserTap,
      onPostTap: onPostTap,
      onRoomTap: onRoomTap,
      stockSearch: stockSearch,
      stockInfo: stockInfo,
      onHashtagTap: onHashtagTap,
      onOltNotificationTap: onOltNotificationTap,
      appVersion: appVersion,
      platform: platform ?? defaultCommunityPlatform(),
      onUpdateRequired: onUpdateRequired,
      trackDelivery: trackDelivery,
      offlineCache: offlineCache,
      offlineMessageLimit: offlineMessageLimit,
      imageCache: imageCache,
      httpClient: httpClient,
    );
    _instance = social;
    social._startBackgroundWork();
    if (signInEagerly) {
      unawaited(social._tokens.refresh().then<void>((_) {}, onError: (Object _) {}));
    }
    return social;
  }

  static RendezvousCommunity create({
    required String supabaseUrl,
    required String anonKey,
    String? authBridgeUrl,
    required Future<String?> Function() tokenProvider,
    CommunityStockTapCallback? onStockTap,
    CommunityUserTapCallback? onUserTap,
    CommunityPostTapCallback? onPostTap,
    CommunityRoomTapCallback? onRoomTap,
    CommunityStockSearch? stockSearch,
    CommunityStockInfoProvider? stockInfo,
    CommunityHashtagTapCallback? onHashtagTap,
    CommunityOltNotificationTapCallback? onOltNotificationTap,
    String? appVersion,
    CommunityPlatform? platform,
    CommunityUpdateRequiredCallback? onUpdateRequired,
    bool trackDelivery = true,
    bool offlineCache = true,
    int offlineMessageLimit = 200,
    OfflineStoreFactory? offlineStores,
    CommunityImageCacheConfig imageCache = const CommunityImageCacheConfig(),
    ImageDiskCache? imageDiskCache,
    http.Client? httpClient,
  }) {
    final baseUrl = supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    final tokens = TokenManager(
      bridge: AuthBridgeClient(
        baseUrl: authBridgeUrl ?? '$baseUrl/bridge/v1',
        anonKey: anonKey,
        httpClient: httpClient,
      ),
      tokenProvider: tokenProvider,
    );
    final client = SupabaseClient(baseUrl, anonKey, accessToken: tokens.accessToken, httpClient: httpClient);
    final api = SupabaseSocialDataSource(
      client,
      tokens,
      supabaseUrl: baseUrl,
      anonKey: anonKey,
      httpClient: httpClient,
    );
    final realtime = RealtimeGateway(client);
    final notifications = NotificationRepositoryImpl(api, realtime);
    final cs = api.inSchema('cs_api');
    final support = SupportRepositoryImpl(cs: cs, realtime: realtime, notifications: notifications);
    final configService = ClientConfigService(
      ClientConfigRepositoryImpl(api),
      platform: platform?.name,
      appVersion: appVersion,
      onUpdateRequired: onUpdateRequired,
    );
    api.errorListener = (error) {
      if (error.code == 'social_disabled') configService.markSocialDisabled();
    };
    final connectivity = CommunityConnectivity();
    api.reachabilityListener = connectivity.report;
    final offline = offlineCache
        ? OfflineCache(
            offlineStores ?? platformOfflineStores(),
            currentUserId: () => tokens.currentUserId,
            resolveHostKey: tokens.resolveHostKey,
            messageLimit: offlineMessageLimit,
          )
        : null;
    final chatCache = offline == null ? null : ChatLocalCache(offline);
    final feedCache = offline == null ? null : FeedLocalCache(offline);
    final chatImpl = ChatRepositoryImpl(api, realtime, chatCache);
    final LocalValues localValues = offline == null ? MemoryLocalValues() : OfflineLocalValues(offline);
    final images = CommunityImageLoader(
      disk: offline == null || !imageCache.persists
          ? const NoImageDiskCache()
          : imageDiskCache ??
                platformImageDiskCache(
                  owner: () async => tokens.currentUserId ?? (await offline.owner())?.id,
                  config: imageCache,
                ),
      client: httpClient,
    );

    final social = RendezvousCommunity._(
      client: client,
      tokens: tokens,
      chatImpl: chatImpl,
      callbacks: CommunityCallbacks(
        onStockTap: onStockTap,
        onUserTap: onUserTap,
        onPostTap: onPostTap,
        onRoomTap: onRoomTap,
        stockSearch: stockSearch,
        stockInfo: stockInfo,
        onHashtagTap: onHashtagTap,
        onOltNotificationTap: onOltNotificationTap,
      ),
      feed: FeedRepositoryImpl(api, realtime, feedCache),
      comments: CommentRepositoryImpl(api, realtime),
      polls: PollRepositoryImpl(api),
      profiles: ProfileRepositoryImpl(api),
      stocks: StockRepositoryImpl(api),
      notifications: notifications,
      moderation: ModerationRepositoryImpl(api),
      media: MediaRepositoryImpl(api),
      support: support,
      supportChat: SupportChatRepository(
        cs,
        realtime: realtime,
        rooms: () async {
          final home = await support.home();
          final roomId = home.roomId;
          if (roomId == null) return const <ChatRoom>[];
          final now = DateTime.now().toUtc();
          return [
            ChatRoom(id: roomId, type: RoomType.support, name: home.supportName, createdAt: now, lastReadAt: now),
          ];
        },
      ),
      push: PushRegistrar(PushRepositoryImpl(api), currentUserId: () => tokens.currentSession?.user.id),
      consent: CommunityConsent(LegalRepositoryImpl(api)),
      account: AccountRepositoryImpl(api, currentUsername: () => tokens.currentSession?.user.username),
      configService: configService,
      search: SearchRepositoryImpl(api),
      trending: TrendingRepositoryImpl(api),
      bookmarks: BookmarkRepositoryImpl(api),
      edits: ContentEditRepositoryImpl(api),
      chatExtras: ChatExtrasRepositoryImpl(api),
      messageRequests: MessageRequestRepositoryImpl(api),
      appeals: AppealRepositoryImpl(api),
      notificationPreferences: NotificationPreferencesRepositoryImpl(api),
      linkPreviews: LinkPreviewLoader(LinkPreviewRepositoryImpl(api)),
      notificationReporter: NotificationReporter(NotificationEventRepositoryImpl(api)),
      bannerDismissals: BannerDismissals(BannerDismissalRepositoryImpl(localValues)),
      drafts: CommunityDrafts(PostDraftRepositoryImpl(api), PostDraftStoreImpl(localValues)),
      analytics: CommunityAnalytics(
        AnalyticsRepositoryImpl(api),
        enabled: () => configService.current.feature(CommunityFlags.analytics),
        signedIn: () => tokens.currentSession != null,
        platform: platform?.name,
        appVersion: appVersion,
      ),
      connectivity: connectivity,
      offline: offline,
      chatCache: chatCache,
      feedCache: feedCache,
      outbox: offline == null ? null : MessageOutbox(chatImpl, OutboxRepositoryImpl(offline)),
      images: images,
      trackDelivery: trackDelivery,
    );

    social._sessionSub = tokens.sessionChanges.listen((session) {
      social.consent.onUserChanged(session?.user.id);
      final userId = session?.user.id;
      if (userId != social._sessionUserId) {
        social._sessionUserId = userId;
        final owner = social._imageOwner;
        if (userId != null) {
          social._imageOwner = userId;
          if (owner != null && owner != userId) unawaited(social.images.wipe());
        }
        social.analytics.reset();
        social.linkPreviews.clear();
        social.notificationReporter.reset();
        social.bannerDismissals.reset();
        if (social._started && userId != null) unawaited(social.configService.refresh());
        if (session != null) unawaited(social._bindOffline(session.user));
      }
      if (session == null) {
        unawaited(social._delivery?.stop());
        return;
      }
      social._push.onUserChanged(session.user.id);
      unawaited(client.realtime.setAuth(session.accessToken));
      social._delivery?.start();
    });
    social._connectivitySub = connectivity.changes.listen((online) {
      if (!online) return;
      unawaited(social.outbox?.flush(force: true));
      unawaited(social.notificationReporter.flush());
    });
    return social;
  }

  final SupabaseClient client;
  final TokenManager _tokens;
  final ChatRepositoryImpl _chatImpl;
  final PushRegistrar _push;
  final AccountRepository _account;
  final OfflineCache? _offline;
  DeliveryTracker? _delivery;
  StreamSubscription<SocialSession?>? _sessionSub;
  StreamSubscription<bool>? _connectivitySub;
  AppLifecycleListener? _lifecycle;
  String? _sessionUserId;
  String? _imageOwner;
  bool _started = false;

  @override
  final ClientConfigService configService;
  @override
  final SearchRepository search;
  @override
  final TrendingRepository trending;
  @override
  final BookmarkRepository bookmarks;
  @override
  final ContentEditRepository edits;
  @override
  final ChatExtrasRepository chatExtras;
  @override
  final MessageRequestRepository messageRequests;
  @override
  final AppealRepository appeals;
  @override
  final NotificationPreferencesRepository notificationPreferences;
  @override
  final LinkPreviewLoader linkPreviews;
  @override
  final CommunityAnalytics analytics;
  @override
  final NotificationReporter notificationReporter;
  @override
  final BannerDismissals bannerDismissals;
  @override
  final CommunityDrafts drafts;
  @override
  final CommunityConnectivity connectivity;
  @override
  final ChatCacheRepository? chatCache;
  @override
  final FeedCacheRepository? feedCache;
  @override
  final MessageOutbox? outbox;

  final CommunityImageLoader images;

  bool get offlineCacheEnabled => _offline != null;

  Future<void> reportNotificationOpened(Map<String, Object?> data) =>
      notificationReporter.opened(NotificationSource.fromData(data));

  Future<void> reportNotificationTapped(Map<String, Object?> data) =>
      notificationReporter.tapped(NotificationSource.fromData(data));

  Future<void> clearLocalCache() async {
    outbox?.reset();
    await images.wipe();
    await _offline?.wipe();
    final session = _tokens.currentSession;
    if (session != null) await _offline?.remember(session.user, hostKey: _tokens.hostKey);
  }

  Future<void> _bindOffline(UserSummary user) async {
    final offline = _offline;
    if (offline == null) return;
    outbox?.reset();
    await offline.remember(user, hostKey: _tokens.hostKey);
    await outbox?.flush(force: true);
  }

  ClientConfig get clientConfig => configService.current;

  Stream<ClientConfig> get clientConfigChanges => configService.changes;

  Future<ClientConfig> refreshClientConfig() => configService.refresh();

  void trackOrderTap({String? stockCode, String? side, String source = 'stock'}) =>
      analytics.record(CommunityAnalyticsEvent.orderTap, {'stock_code': stockCode, 'side': side, 'source': source});

  void _startBackgroundWork() {
    if (_started) return;
    _started = true;
    unawaited(configService.refresh());
    configService.start();
    analytics.start();
    connectivity.probe = configService.refresh;
    WidgetsFlutterBinding.ensureInitialized();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(configService.refresh());
        unawaited(outbox?.flush(force: true));
        connectivity.notifyResumed();
      },
      onHide: () => unawaited(analytics.flush()),
      onPause: () => unawaited(analytics.flush()),
    );
  }

  @override
  final CommunityCallbacks callbacks;
  @override
  final FeedRepository feed;
  @override
  final CommentRepository comments;
  @override
  final PollRepository polls;
  @override
  final ProfileRepository profiles;
  @override
  final StockRepository stocks;
  @override
  ChatRepository get chat => _chatImpl;
  @override
  final NotificationRepository notifications;
  @override
  final ModerationRepository moderation;
  @override
  final MediaRepository media;
  @override
  final SupportRepository support;
  @override
  final ChatRepository supportChat;
  @override
  final CommunityConsent consent;
  late final OfficialAccounts officialAccounts = OfficialAccounts(profiles.officialAccountIds);

  @override
  UserSummary? get currentUser => _tokens.currentSession?.user;

  Stream<UserSummary?> get userChanges => _tokens.sessionChanges.map((s) => s?.user);

  @override
  Future<UserSummary> ensureSignedIn() async {
    final user = currentUser;
    if (user != null) return user;
    try {
      return (await _tokens.refresh()).user;
    } catch (e) {
      final error = mapError(e);
      if (error.kind == CommunityErrorKind.network) connectivity.report(reachable: false);
      throw error;
    }
  }

  CommunityPushRegistration? get pushRegistration => _push.registration;

  Future<void> registerPushToken(
    String token, {
    required CommunityPushPlatform platform,
    String? locale,
    String? appVersion,
  }) async {
    try {
      await _push.register(
        CommunityPushRegistration(token: token, platform: platform, locale: locale, appVersion: appVersion),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> unregisterPushToken() async {
    try {
      await _push.forget();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<LegalDocument>> legalDocuments({bool refresh = false}) => consent.documents(refresh: refresh);

  Future<List<LegalDocument>> pendingLegalDocuments({bool refresh = false}) => consent.pending(refresh: refresh);

  Future<void> acceptLegalDocuments(Iterable<String> documentIds) async {
    try {
      await consent.accept(documentIds);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CommunityDataExport> exportMyData() async {
    try {
      final export = await _account.exportMyData();
      CommunityLoggers.account.event(
        Level.INFO,
        'Personal data exported',
        fields: {'userId': currentUser?.id, 'byteCount': export.bytes.length},
      );
      return export;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteMyAccount() async {
    final userId = currentUser?.id;
    try {
      await _account.deleteMyAccount();
    } catch (e) {
      throw mapError(e);
    }
    CommunityLoggers.account.event(Level.INFO, 'Community account deleted', fields: {'userId': userId});
    _push.release();
    await _endSession();
  }

  Future<void> signOut() async {
    await analytics.flush();
    await _push.detach();
    await _endSession();
  }

  Future<void> _endSession() async {
    await _delivery?.stop();
    outbox?.reset();
    _tokens.clear();
    _imageOwner = null;
    await images.wipe();
    await _offline?.wipe();
    await client.removeAllChannels();
    await client.realtime.disconnect();
  }

  Future<void> dispose() async {
    if (identical(_instance, this)) _instance = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    analytics.dispose();
    linkPreviews.dispose();
    await bannerDismissals.dispose();
    await configService.dispose();
    await _sessionSub?.cancel();
    await _connectivitySub?.cancel();
    await outbox?.dispose();
    await _offline?.dispose();
    images.dispose();
    connectivity.dispose();
    await _delivery?.stop();
    await _chatImpl.dispose();
    await client.removeAllChannels();
    await client.dispose();
    await _tokens.dispose();
    consent.dispose();
  }
}
