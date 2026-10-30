import 'package:flutter/material.dart';
import 'package:olt_social/src/app/olt_social.dart';
import 'package:olt_social/src/app/olt_social_dependencies.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/olt_chat_room.dart';
import 'package:olt_social/src/features/post/presentation/widgets/olt_post_detail.dart';
import 'package:olt_social/src/features/profile/presentation/widgets/olt_user_profile.dart';
import 'package:olt_social/src/features/stocks/presentation/widgets/olt_stock_feed.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';

class OltSocialScope extends InheritedWidget {
  const OltSocialScope({super.key, required this.dependencies, required super.child});

  final OltSocialDependencies dependencies;

  static OltSocialDependencies of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OltSocialScope>()?.dependencies ?? OltSocial.instance;

  @override
  bool updateShouldNotify(OltSocialScope oldWidget) => !identical(dependencies, oldWidget.dependencies);
}

abstract final class OltNavigator {
  static void openStock(BuildContext context, String code) {
    final callback = OltSocialScope.of(context).callbacks.onStockTap;
    if (callback != null) return callback(context, code);
    _push(context, '\$$code', OltStockFeed(stockCode: code));
  }

  static void openUser(BuildContext context, UserSummary user) {
    final callback = OltSocialScope.of(context).callbacks.onUserTap;
    if (callback != null) return callback(context, user);
    _push(
      context,
      '@${user.username}',
      OltUserProfile(userId: user.id.isEmpty ? null : user.id, username: user.username),
    );
  }

  static void openUsername(BuildContext context, String username) {
    openUser(context, UserSummary(id: '', username: username));
  }

  static void openPost(BuildContext context, String postId, {String? rootCommentId}) {
    final callback = OltSocialScope.of(context).callbacks.onPostTap;
    if (callback != null && rootCommentId == null) return callback(context, postId);
    _push(context, null, OltPostDetail(postId: postId, rootCommentId: rootCommentId));
  }

  static void openRoom(BuildContext context, String roomId) {
    final callback = OltSocialScope.of(context).callbacks.onRoomTap;
    if (callback != null) return callback(context, roomId);
    _push(context, null, OltChatRoom(roomId: roomId));
  }

  static void _push(BuildContext context, String? title, Widget body) {
    final dependencies = OltSocialScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OltSocialScope(
          dependencies: dependencies,
          child: Scaffold(
            appBar: AppBar(title: title == null ? null : Text(title)),
            body: SafeArea(top: false, child: body),
          ),
        ),
      ),
    );
  }
}
