import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/realtime_gateway.dart';
import '../data/datasources/social_remote_data_source.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../data/repositories/feed_repository_impl.dart';
import '../data/repositories/social_repository_impl.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/repositories.dart';
import 'auth/auth_bridge_client.dart';
import 'auth/token_manager.dart';
import 'errors/error_mapper.dart';

/// Dipanggil saat user mengetuk `$KODE`. OLT bisa membuka halaman sahamnya sendiri.
typedef OltStockTapCallback = void Function(BuildContext context, String stockCode);

/// Dipanggil saat user mengetuk `@username` / avatar.
typedef OltUserTapCallback = void Function(BuildContext context, UserSummary user);

/// Dipanggil saat user membuka sebuah post.
typedef OltPostTapCallback = void Function(BuildContext context, String postId);

/// Dipanggil saat user membuka sebuah room chat.
typedef OltRoomTapCallback = void Function(BuildContext context, String roomId);

/// Callback navigasi global. Bila null, olt_social membuka halaman bawaannya.
class OltSocialCallbacks {
  const OltSocialCallbacks({this.onStockTap, this.onUserTap, this.onPostTap, this.onRoomTap});

  final OltStockTapCallback? onStockTap;
  final OltUserTapCallback? onUserTap;
  final OltPostTapCallback? onPostTap;
  final OltRoomTapCallback? onRoomTap;
}

/// Semua yang dibutuhkan widget olt_social. Diimplementasikan [OltSocial];
/// di test bisa diganti fake lewat `OltSocialScope`.
abstract interface class OltSocialDependencies {
  FeedRepository get feed;
  CommentRepository get comments;
  ProfileRepository get profiles;
  StockRepository get stocks;
  ChatRepository get chat;
  NotificationRepository get notifications;
  ModerationRepository get moderation;
  MediaRepository get media;
  OltSocialCallbacks get callbacks;

  /// User yang sedang login (null sebelum sesi pertama terbentuk).
  UserSummary? get currentUser;

  /// Memastikan sesi sosial ada (menukar token OLT bila perlu).
  Future<UserSummary> ensureSignedIn();
}

/// Titik masuk package.
///
/// ```dart
/// await OltSocial.initialize(
///   supabaseUrl: 'https://social-api.example.com',
///   anonKey: '...',
///   oltTokenProvider: () async => oltAuth.currentToken,
/// );
/// ```
class OltSocial implements OltSocialDependencies {
  OltSocial._({
    required this.client,
    required this._tokens,
    required this.callbacks,
    required this.feed,
    required this.comments,
    required this.profiles,
    required this.stocks,
    required this.chat,
    required this.notifications,
    required this.moderation,
    required this.media,
  });

  static OltSocial? _instance;

  /// Instance hasil [initialize].
  static OltSocial get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('OltSocial belum diinisialisasi. Panggil OltSocial.initialize() saat startup.');
    }
    return instance;
  }

  static bool get isInitialized => _instance != null;

  /// Inisialisasi package. Aman dipanggil ulang (instance lama ditutup).
  ///
  /// * [authBridgeUrl] default `<supabaseUrl>/bridge/v1` (route Kong).
  /// * [oltTokenProvider] mengembalikan token login OLT yang sedang aktif,
  ///   atau null bila user belum login. Password user tidak pernah dipakai.
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
      httpClient: httpClient,
    );
    _instance = social;
    if (signInEagerly) {
      unawaited(social._tokens.refresh().then<void>((_) {}, onError: (Object _) {}));
    }
    return social;
  }

  /// Membuat instance mandiri tanpa mendaftarkannya sebagai [instance]
  /// (mis. untuk integration test dengan beberapa user sekaligus).
  static OltSocial create({
    required String supabaseUrl,
    required String anonKey,
    String? authBridgeUrl,
    required Future<String?> Function() oltTokenProvider,
    OltStockTapCallback? onStockTap,
    OltUserTapCallback? onUserTap,
    OltPostTapCallback? onPostTap,
    OltRoomTapCallback? onRoomTap,
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
      callbacks: OltSocialCallbacks(
        onStockTap: onStockTap,
        onUserTap: onUserTap,
        onPostTap: onPostTap,
        onRoomTap: onRoomTap,
      ),
      feed: FeedRepositoryImpl(api, realtime),
      comments: CommentRepositoryImpl(api, realtime),
      profiles: ProfileRepositoryImpl(api),
      stocks: StockRepositoryImpl(api),
      chat: ChatRepositoryImpl(api, realtime),
      notifications: NotificationRepositoryImpl(api, realtime),
      moderation: ModerationRepositoryImpl(api),
      media: MediaRepositoryImpl(api),
    );

    // Koneksi realtime tidak memanggil ulang accessToken sendiri; dorong token
    // baru setiap kali sesi diperbarui agar channel tidak terputus saat JWT habis.
    social._sessionSub = tokens.sessionChanges.listen((session) {
      if (session != null) unawaited(client.realtime.setAuth(session.accessToken));
    });
    return social;
  }

  /// Klien Supabase internal (untuk kebutuhan lanjutan).
  final SupabaseClient client;
  final TokenManager _tokens;
  StreamSubscription<SocialSession?>? _sessionSub;

  @override
  final OltSocialCallbacks callbacks;
  @override
  final FeedRepository feed;
  @override
  final CommentRepository comments;
  @override
  final ProfileRepository profiles;
  @override
  final StockRepository stocks;
  @override
  final ChatRepository chat;
  @override
  final NotificationRepository notifications;
  @override
  final ModerationRepository moderation;
  @override
  final MediaRepository media;

  @override
  UserSummary? get currentUser => _tokens.currentSession?.user;

  /// Perubahan sesi: user baru setelah login/refresh, null setelah [signOut].
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

  /// Panggil saat user logout dari OLT: sesi sosial & koneksi realtime ditutup.
  Future<void> signOut() async {
    _tokens.clear();
    await client.removeAllChannels();
    await client.realtime.disconnect();
  }

  Future<void> dispose() async {
    if (identical(_instance, this)) _instance = null;
    await _sessionSub?.cancel();
    await client.removeAllChannels();
    await client.dispose();
    await _tokens.dispose();
  }
}
