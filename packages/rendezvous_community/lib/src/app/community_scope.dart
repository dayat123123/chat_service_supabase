import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_builders.dart';
import 'package:rendezvous_community/src/app/community_dependencies.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/community_chat_room.dart';
import 'package:rendezvous_community/src/features/post/presentation/widgets/community_post_detail.dart';
import 'package:rendezvous_community/src/features/profile/presentation/widgets/community_user_profile.dart';
import 'package:rendezvous_community/src/features/search/presentation/widgets/community_hashtag_feed.dart';
import 'package:rendezvous_community/src/features/stocks/presentation/widgets/community_stock_feed.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';

class CommunityScope extends InheritedWidget {
  const CommunityScope({super.key, required this.dependencies, required super.child});

  final CommunityDependencies dependencies;

  static CommunityDependencies of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CommunityScope>()?.dependencies ?? RendezvousCommunity.instance;

  @override
  bool updateShouldNotify(CommunityScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}

abstract final class CommunityNavigator {
  static void openStock(BuildContext context, String code, {String? source}) {
    context.trackCommunityEvent(CommunityAnalyticsEvent.stockTap, {'stock_code': code, 'source': source ?? 'other'});
    final callback = CommunityScope.of(context).callbacks.onStockTap;
    if (callback != null) return callback(context, code);
    _push(context, '\$$code', CommunityStockFeed(stockCode: code));
  }

  static void openUser(BuildContext context, UserSummary user) {
    final callback = CommunityScope.of(context).callbacks.onUserTap;
    if (callback != null) return callback(context, user);
    _push(
      context,
      '@${user.username}',
      CommunityUserProfile(userId: user.id.isEmpty ? null : user.id, username: user.username),
    );
  }

  static void openUsername(BuildContext context, String username) {
    openUser(context, UserSummary(id: '', username: username));
  }

  static void openHashtag(BuildContext context, String tag) {
    final callback = CommunityScope.of(context).callbacks.onHashtagTap;
    if (callback != null) return callback(context, tag);
    _push(context, '#$tag', CommunityHashtagFeed(tag: tag));
  }

  static void openPost(BuildContext context, String postId, {String? rootCommentId}) {
    final callback = CommunityScope.of(context).callbacks.onPostTap;
    if (callback != null && rootCommentId == null) return callback(context, postId);
    _push(context, null, CommunityPostDetail(postId: postId, rootCommentId: rootCommentId));
  }

  static void openRoom(BuildContext context, String roomId) {
    final callback = CommunityScope.of(context).callbacks.onRoomTap;
    if (callback != null) return callback(context, roomId);
    _push(context, null, CommunityChatRoom(roomId: roomId));
  }

  static void _push(BuildContext context, String? title, Widget body) {
    final dependencies = CommunityScope.of(context);
    final features = context.getInheritedWidgetOfExactType<CommunityFeatureScope>()?.dependencies;
    final carry = carryCommunityBuilders(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          Widget page = CommunityScope(
            dependencies: dependencies,
            child: Scaffold(
              appBar: AppBar(title: title == null ? null : Text(title)),
              body: SafeArea(top: false, child: body),
            ),
          );
          if (features != null) page = CommunityFeatureScope(dependencies: features, child: page);
          return carry(page);
        },
      ),
    );
  }
}
