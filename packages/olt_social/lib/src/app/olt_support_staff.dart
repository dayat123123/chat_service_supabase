import 'package:olt_social/src/app/olt_social_dependencies.dart';
import 'package:olt_social/src/core/auth/session_tokens.dart';
import 'package:olt_social/src/core/network/realtime_gateway.dart';
import 'package:olt_social/src/core/network/social_remote_data_source.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
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
import 'package:olt_social/src/features/support/data/repositories/support_chat_repository.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OltSupportStaff implements OltSocialDependencies {
  OltSupportStaff._(SocialRemoteDataSource api, RealtimeGateway realtime, this._me, this.callbacks)
    : feed = FeedRepositoryImpl(api),
      comments = CommentRepositoryImpl(api),
      polls = PollRepositoryImpl(api),
      profiles = ProfileRepositoryImpl(api),
      stocks = StockRepositoryImpl(api),
      notifications = NotificationRepositoryImpl(api),
      moderation = ModerationRepositoryImpl(api),
      media = MediaRepositoryImpl(api) {
    chat = SupportChatRepository(
      api.inSchema('cs_api'),
      realtime: realtime,
      rooms: () async => [..._rooms.values],
      ticketOf: (roomId) => _tickets[roomId],
    );
  }

  factory OltSupportStaff({
    required SupabaseClient client,
    required String supabaseUrl,
    required String anonKey,
    required UserSummary me,
    OltSocialCallbacks callbacks = const OltSocialCallbacks(),
  }) {
    final api = SupabaseSocialDataSource(
      client,
      SupabaseAuthTokens(client.auth),
      supabaseUrl: supabaseUrl,
      anonKey: anonKey,
    );
    return OltSupportStaff._(api, RealtimeGateway(client), me, callbacks);
  }

  final UserSummary _me;
  final _rooms = <String, ChatRoom>{};
  final _tickets = <String, String>{};

  void showTicket(ChatRoom room, {String? replyTicketId}) {
    _rooms[room.id] = room;
    if (replyTicketId == null) {
      _tickets.remove(room.id);
    } else {
      _tickets[room.id] = replyTicketId;
    }
  }

  @override
  final OltSocialCallbacks callbacks;
  @override
  late final ChatRepository chat;
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
  final NotificationRepository notifications;
  @override
  final ModerationRepository moderation;
  @override
  final MediaRepository media;

  @override
  UserSummary get currentUser => _me;

  @override
  Future<UserSummary> ensureSignedIn() async => _me;
}
