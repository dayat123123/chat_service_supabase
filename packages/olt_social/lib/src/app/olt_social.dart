import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:olt_social/src/app/olt_social_dependencies.dart';
import 'package:olt_social/src/core/auth/auth_bridge_client.dart';
import 'package:olt_social/src/core/auth/social_session.dart';
import 'package:olt_social/src/core/auth/token_manager.dart';
import 'package:olt_social/src/core/error/error_mapper.dart';
import 'package:olt_social/src/core/network/realtime_gateway.dart';
import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/features/chat/domain/services/delivery_tracker.dart';
import 'package:olt_social/src/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:olt_social/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:olt_social/src/features/media/data/repositories/media_repository_impl.dart';
import 'package:olt_social/src/features/media/domain/repositories/media_repository.dart';
import 'package:olt_social/src/features/moderation/data/repositories/moderation_repository_impl.dart';
import 'package:olt_social/src/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:olt_social/src/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:olt_social/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:olt_social/src/features/poll/data/repositories/poll_repository_impl.dart';
import 'package:olt_social/src/features/poll/domain/repositories/poll_repository.dart';
import 'package:olt_social/src/features/post/data/repositories/comment_repository_impl.dart';
import 'package:olt_social/src/features/post/domain/repositories/comment_repository.dart';
import 'package:olt_social/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:olt_social/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:olt_social/src/features/stocks/data/repositories/stock_repository_impl.dart';
import 'package:olt_social/src/features/stocks/domain/repositories/stock_repository.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OltSocial implements OltSocialDependencies {
  OltSocial._({
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
    required bool trackDelivery,
  }) {
    if (trackDelivery) {
      _delivery = DeliveryTracker(_chatImpl, currentUserId: () => currentUser?.id);
      if (_tokens.currentSession != null) _delivery!.start();
    }
  }

  static OltSocial? _instance;

  static OltSocial get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('OltSocial belum diinisialisasi. Panggil OltSocial.initialize() saat startup.');
    }
    return instance;
  }

  static bool get isInitialized => _instance != null;

  static Future<OltSocial> initialize({
    required String supabaseUrl,
    required String anonKey,
    String? authBridgeUrl,
    required Future<String?> Function() oltTokenProvider,
    OltStockTapCallback? onStockTap,
    OltUserTapCallback? onUserTap,
    OltPostTapCallback? onPostTap,
    OltRoomTapCallback? onRoomTap,
    bool signInEagerly = true,
    bool trackDelivery = true,
    http.Client? httpClient,
  }) async {
    await _instance?.dispose();
    final social = create(
      supabaseUrl: supabaseUrl,
      anonKey: anonKey,
      authBridgeUrl: authBridgeUrl,
      oltTokenProvider: oltTokenProvider,
      onStockTap: onStockTap,
      onUserTap: onUserTap,
      onPostTap: onPostTap,
      onRoomTap: onRoomTap,
      trackDelivery: trackDelivery,
      httpClient: httpClient,
    );
    _instance = social;
    if (signInEagerly) {
      unawaited(social._tokens.refresh().then<void>((_) {}, onError: (Object _) {}));
    }
    return social;
  }

  static OltSocial create({
    required String supabaseUrl,
    required String anonKey,
    String? authBridgeUrl,
    required Future<String?> Function() oltTokenProvider,
    OltStockTapCallback? onStockTap,
    OltUserTapCallback? onUserTap,
    OltPostTapCallback? onPostTap,
    OltRoomTapCallback? onRoomTap,
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
      oltTokenProvider: oltTokenProvider,
    );
    final client = SupabaseClient(baseUrl, anonKey, accessToken: tokens.accessToken, httpClient: httpClient);
    final api = SupabaseSocialDataSource(client, tokens, supabaseUrl: baseUrl, anonKey: anonKey);
    final realtime = RealtimeGateway(client);

    final social = OltSocial._(
      client: client,
      tokens: tokens,
      chatImpl: ChatRepositoryImpl(api, realtime),
      callbacks: OltSocialCallbacks(
        onStockTap: onStockTap,
        onUserTap: onUserTap,
        onPostTap: onPostTap,
        onRoomTap: onRoomTap,
      ),
      feed: FeedRepositoryImpl(api, realtime),
      comments: CommentRepositoryImpl(api, realtime),
      polls: PollRepositoryImpl(api),
      profiles: ProfileRepositoryImpl(api),
      stocks: StockRepositoryImpl(api),
      notifications: NotificationRepositoryImpl(api, realtime),
      moderation: ModerationRepositoryImpl(api),
      media: MediaRepositoryImpl(api),
      trackDelivery: trackDelivery,
    );

    social._sessionSub = tokens.sessionChanges.listen((session) {
      if (session == null) {
        unawaited(social._delivery?.stop());
        return;
      }
      unawaited(client.realtime.setAuth(session.accessToken));
      social._delivery?.start();
    });
    return social;
  }

  final SupabaseClient client;
  final TokenManager _tokens;
  final ChatRepositoryImpl _chatImpl;
  DeliveryTracker? _delivery;
  StreamSubscription<SocialSession?>? _sessionSub;

  @override
  final OltSocialCallbacks callbacks;
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

  Future<void> signOut() async {
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
  }
}
