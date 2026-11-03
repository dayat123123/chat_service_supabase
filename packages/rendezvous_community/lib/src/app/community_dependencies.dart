import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:rendezvous_community/src/features/media/domain/repositories/media_repository.dart';
import 'package:rendezvous_community/src/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rendezvous_community/src/features/poll/domain/repositories/poll_repository.dart';
import 'package:rendezvous_community/src/features/post/domain/repositories/comment_repository.dart';
import 'package:rendezvous_community/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock_info.dart';
import 'package:rendezvous_community/src/features/stocks/domain/entities/stock_suggestion.dart';
import 'package:rendezvous_community/src/features/stocks/domain/repositories/stock_repository.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

typedef CommunityStockTapCallback = void Function(BuildContext context, String stockCode);

typedef CommunityUserTapCallback = void Function(BuildContext context, UserSummary user);

typedef CommunityPostTapCallback = void Function(BuildContext context, String postId);

typedef CommunityRoomTapCallback = void Function(BuildContext context, String roomId);

typedef CommunityHashtagTapCallback = void Function(BuildContext context, String tag);

typedef CommunityOltNotificationTapCallback = void Function(BuildContext context, Map<String, Object?> data);

typedef CommunityStockSearch = Future<List<StockSuggestion>> Function(String query);

typedef CommunityStockInfoProvider = CommunityStockInfo? Function(String stockCode);

class CommunityCallbacks {
  const CommunityCallbacks({
    this.onStockTap,
    this.onUserTap,
    this.onPostTap,
    this.onRoomTap,
    this.stockSearch,
    this.onHashtagTap,
    this.onOltNotificationTap,
    this.stockInfo,
  });

  final CommunityStockTapCallback? onStockTap;
  final CommunityUserTapCallback? onUserTap;
  final CommunityPostTapCallback? onPostTap;
  final CommunityRoomTapCallback? onRoomTap;
  final CommunityStockSearch? stockSearch;
  final CommunityHashtagTapCallback? onHashtagTap;
  final CommunityOltNotificationTapCallback? onOltNotificationTap;
  final CommunityStockInfoProvider? stockInfo;
}

abstract interface class CommunityDependencies {
  FeedRepository get feed;
  CommentRepository get comments;
  PollRepository get polls;
  ProfileRepository get profiles;
  StockRepository get stocks;
  ChatRepository get chat;
  NotificationRepository get notifications;
  ModerationRepository get moderation;
  MediaRepository get media;
  CommunityCallbacks get callbacks;

  UserSummary? get currentUser;

  Future<UserSummary> ensureSignedIn();
}
