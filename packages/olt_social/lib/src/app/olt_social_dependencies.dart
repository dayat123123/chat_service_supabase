import 'package:flutter/widgets.dart';
import 'package:olt_social/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:olt_social/src/features/feed/domain/repositories/feed_repository.dart';
import 'package:olt_social/src/features/media/domain/repositories/media_repository.dart';
import 'package:olt_social/src/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:olt_social/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:olt_social/src/features/poll/domain/repositories/poll_repository.dart';
import 'package:olt_social/src/features/post/domain/repositories/comment_repository.dart';
import 'package:olt_social/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:olt_social/src/features/stocks/domain/repositories/stock_repository.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

typedef OltStockTapCallback = void Function(BuildContext context, String stockCode);

typedef OltUserTapCallback = void Function(BuildContext context, UserSummary user);

typedef OltPostTapCallback = void Function(BuildContext context, String postId);

typedef OltRoomTapCallback = void Function(BuildContext context, String roomId);

class OltSocialCallbacks {
  const OltSocialCallbacks({this.onStockTap, this.onUserTap, this.onPostTap, this.onRoomTap});

  final OltStockTapCallback? onStockTap;
  final OltUserTapCallback? onUserTap;
  final OltPostTapCallback? onPostTap;
  final OltRoomTapCallback? onRoomTap;
}

abstract interface class OltSocialDependencies {
  FeedRepository get feed;
  CommentRepository get comments;
  PollRepository get polls;
  ProfileRepository get profiles;
  StockRepository get stocks;
  ChatRepository get chat;
  NotificationRepository get notifications;
  ModerationRepository get moderation;
  MediaRepository get media;
  OltSocialCallbacks get callbacks;

  UserSummary? get currentUser;

  Future<UserSummary> ensureSignedIn();
}
