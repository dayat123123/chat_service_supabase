import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
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
  final message = CommunityPushMessage.tryParse(data);
  if (message == null) return false;
  final notificationId = message.notificationId;
  if (notificationId != null) unawaited(_markRead(CommunityScope.of(context).notifications, notificationId));

  final postId = message.postId;
  final roomId = message.roomId;
  final actorId = message.actorId;
  final link = message.link;
  if (message.isSupport) {
    unawaited(openCommunitySupport(context));
  } else if (message.type == 'appeal' && context.communityFeatures != null) {
    unawaited(openCommunityAppeals(context));
  } else if (message.type == 'message' && roomId != null) {
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

Future<void> _markRead(NotificationRepository notifications, String id) async {
  try {
    await notifications.markRead(ids: [id]);
  } catch (_) {}
}
