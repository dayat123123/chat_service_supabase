import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/app/community_account_scope.dart';
import 'package:rendezvous_community/src/app/community_dependencies.dart';
import 'package:rendezvous_community/src/app/community_support_scope.dart';
import 'package:rendezvous_community/src/core/auth/auth_bridge_client.dart';
import 'package:rendezvous_community/src/core/auth/social_session.dart';
import 'package:rendezvous_community/src/core/auth/token_manager.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/core/network/realtime_gateway.dart';
import 'package:rendezvous_community/src/core/network/social_remote_data_source.dart';
import 'package:rendezvous_community/src/features/account/data/repositories/account_repository_impl.dart';
import 'package:rendezvous_community/src/features/account/domain/entities/community_data_export.dart';
import 'package:rendezvous_community/src/features/account/domain/repositories/account_repository.dart';
import 'package:rendezvous_community/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/services/delivery_tracker.dart';
import 'package:rendezvous_community/src/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/features/legal/data/repositories/legal_repository_impl.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/features/legal/domain/services/community_consent.dart';
import 'package:rendezvous_community/src/features/media/data/repositories/media_repository_impl.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/features/moderation/data/repositories/moderation_repository_impl.dart';
import 'package:rendezvous_community/src/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:rendezvous_community/src/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rendezvous_community/src/features/poll/data/repositories/poll_repository_impl.dart';
import 'package:rendezvous_community/src/features/poll/domain/repositories/poll_repository.dart';
import 'package:rendezvous_community/src/features/post/data/repositories/comment_repository_impl.dart';
import 'package:rendezvous_community/src/features/post/domain/repositories/comment_repository.dart';
import 'package:rendezvous_community/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:rendezvous_community/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:rendezvous_community/src/features/push/data/repositories/push_repository_impl.dart';
import 'package:rendezvous_community/src/features/push/domain/entities/community_push_message.dart';
import 'package:rendezvous_community/src/features/push/domain/services/push_registrar.dart';
import 'package:rendezvous_community/src/features/stocks/data/repositories/stock_repository_impl.dart';
import 'package:rendezvous_community/src/features/stocks/domain/repositories/stock_repository.dart';
import 'package:rendezvous_community/src/features/support/data/repositories/support_chat_repository.dart';
import 'package:rendezvous_community/src/features/support/data/repositories/support_repository_impl.dart';
import 'package:rendezvous_community/src/features/support/domain/repositories/support_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/domain/official_accounts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RendezvousCommunity implements CommunityDependencies, CommunitySupportDependencies, CommunityAccountDependencies {
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
    bool signInEagerly = true,
    bool trackDelivery = true,
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
      trackDelivery: trackDelivery,
      httpClient: httpClient,
    );
    _instance = social;
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
    bool trackDelivery = true,
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

    final social = RendezvousCommunity._(
      client: client,
      tokens: tokens,
      chatImpl: ChatRepositoryImpl(api, realtime),
      callbacks: CommunityCallbacks(
        onStockTap: onStockTap,
        onUserTap: onUserTap,
        onPostTap: onPostTap,
        onRoomTap: onRoomTap,
        stockSearch: stockSearch,
      ),
      feed: FeedRepositoryImpl(api, realtime),
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
      trackDelivery: trackDelivery,
    );

    social._sessionSub = tokens.sessionChanges.listen((session) {
      social.consent.onUserChanged(session?.user.id);
      if (session == null) {
        unawaited(social._delivery?.stop());
        return;
      }
      social._push.onUserChanged(session.user.id);
      unawaited(client.realtime.setAuth(session.accessToken));
      social._delivery?.start();
    });
    return social;
  }

  final SupabaseClient client;
  final TokenManager _tokens;
  final ChatRepositoryImpl _chatImpl;
  final PushRegistrar _push;
  final AccountRepository _account;
  DeliveryTracker? _delivery;
  StreamSubscription<SocialSession?>? _sessionSub;

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
      throw mapError(e);
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
    await _push.detach();
    await _endSession();
  }

  Future<void> _endSession() async {
    await _delivery?.stop();
    _tokens.clear();
    await client.removeAllChannels();
    await client.realtime.disconnect();
  }

  Future<void> dispose() async {
    if (identical(_instance, this)) _instance = null;
    await _sessionSub?.cancel();
    await _delivery?.stop();
    await _chatImpl.dispose();
    await client.removeAllChannels();
    await client.dispose();
    await _tokens.dispose();
    consent.dispose();
  }
}
