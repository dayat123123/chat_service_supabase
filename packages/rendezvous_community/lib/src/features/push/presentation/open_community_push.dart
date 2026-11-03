import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/community_dependencies.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/app/rendezvous_community.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_event.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rendezvous_community/src/features/push/domain/entities/community_push_message.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/community_support_chat.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:url_launcher/url_launcher.dart';

bool isCommunityPush(Map<String, Object?> data) => CommunityPushMessage.tryParse(data) != null;

bool isOltPush(Map<String, Object?> data) {
  final kind = data['kind'];
  return data['source'] == 'olt' || (kind is String && kind.startsWith('olt.'));
}

bool openCommunityPush(BuildContext context, Map<String, Object?> data) {
  final reporter = context.communityFeatures?.notificationReporter;
  final source = NotificationSource.fromData(data);
  if (isOltPush(data)) {
    unawaited(reporter?.opened(source));
    final opened = _openOltPush(context, data);
    if (opened) unawaited(reporter?.tapped(source));
    return opened;
  }
  final message = CommunityPushMessage.tryParse(data);
  if (message == null) return false;
  unawaited(reporter?.opened(source));
  final opened = _openMessage(context, message);
  if (opened) unawaited(reporter?.tapped(source));
  return opened;
}

bool _openMessage(BuildContext context, CommunityPushMessage message) {
  final notificationId = message.notificationId;
  if (notificationId != null) unawaited(_markRead(CommunityScope.of(context).notifications, notificationId));

  final postId = message.postId;
  final roomId = message.roomId;
  final actorId = message.actorId;
  final link = message.link;
  final topStock = message.stocks.firstOrNull;
  if (message.isSupport) {
    unawaited(openCommunitySupport(context));
  } else if (message.type == 'moderation' && message.data['target_type'] == 'room' && roomId != null) {
    CommunityNavigator.openRoom(context, roomId);
  } else if ((message.type == 'appeal' || message.type == 'moderation') && context.communityFeatures != null) {
    unawaited(openCommunityAppeals(context));
  } else if (message.type == 'watchlist_digest' && topStock != null) {
    CommunityNavigator.openStock(context, topStock, source: 'notification');
  } else if ((message.type == 'message' || (message.type == 'mention' && postId == null)) && roomId != null) {
    CommunityNavigator.openRoom(context, roomId);
  } else if (message.type == 'follow' && actorId != null) {
    CommunityNavigator.openUser(context, UserSummary(id: actorId, username: message.actorUsername ?? ''));
  } else if (postId != null) {
    CommunityNavigator.openPost(context, postId);
  } else if (link != null) {
    unawaited(launchUrl(link, mode: LaunchMode.externalApplication));
  } else {
    return false;
  }
  return true;
}

bool _openOltPush(BuildContext context, Map<String, Object?> data) {
  final dependencies = _dependencies(context);
  final callback = dependencies?.callbacks.onOltNotificationTap;
  if (dependencies == null || callback == null) return false;
  final notificationId = data['notification_id'];
  if (notificationId is String && notificationId.isNotEmpty) {
    unawaited(_markRead(dependencies.notifications, notificationId));
  }
  callback(context, Map.unmodifiable(data));
  return true;
}

CommunityDependencies? _dependencies(BuildContext context) =>
    context.getInheritedWidgetOfExactType<CommunityScope>()?.dependencies ??
    (RendezvousCommunity.isInitialized ? RendezvousCommunity.instance : null);

Future<void> _markRead(NotificationRepository notifications, String id) async {
  try {
    await notifications.markRead(ids: [id]);
  } catch (_) {}
}
