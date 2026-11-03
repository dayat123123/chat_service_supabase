import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/app_notification.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_preferences.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/widgets/community_notification_settings.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityNotificationList extends StatelessWidget {
  const CommunityNotificationList({super.key, this.onNotificationTap});

  final void Function(BuildContext context, AppNotification notification)? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    return BlocProvider(
      create: (_) => NotificationsCubit(notifications: deps.notifications)..load(),
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final l10n = context.communityL10n;
          final cubit = context.read<NotificationsCubit>();
          return switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(),
            LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
            LoadStatus.ready => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.notifications, style: Theme.of(context).textTheme.titleLarge)),
                      TextButton.icon(
                        onPressed: state.unread == 0 ? null : cubit.markAllRead,
                        icon: const Icon(Icons.done_all),
                        label: Text(l10n.markAllRead),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state.items.isEmpty
                      ? CommunityEmptyView(message: l10n.noNotifications, icon: Icons.notifications_none)
                      : NotificationListener<ScrollEndNotification>(
                          onNotification: (n) {
                            if (n.metrics.extentAfter < 300) cubit.loadMore();
                            return false;
                          },
                          child: ListView.separated(
                            itemCount: state.items.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final n = state.items[i];
                              return _NotificationTile(
                                notification: n,
                                onTap: () {
                                  cubit.markRead(n);
                                  final custom = onNotificationTap;
                                  custom != null ? custom(context, n) : _openDefault(context, n);
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          };
        },
      ),
    );
  }

  static void _openDefault(BuildContext context, AppNotification n) {
    if (n.isOlt) {
      CommunityScope.of(
        context,
      ).callbacks.onOltNotificationTap?.call(context, Map.unmodifiable({...n.payload, 'notification_id': n.id}));
      return;
    }
    final postId = n.postId;
    final roomId = n.roomId;
    final url = Uri.tryParse(n.url ?? '');
    if (n.type == NotificationType.appeal) {
      if (context.communityFeatures != null) unawaited(openCommunityAppeals(context));
    } else if (n.type == NotificationType.announcement && postId == null && url != null && url.scheme == 'https') {
      unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
    } else if (n.type == NotificationType.message && roomId != null) {
      CommunityNavigator.openRoom(context, roomId);
    } else if (postId != null) {
      CommunityNavigator.openPost(context, postId);
    } else if (n.actor != null) {
      CommunityNavigator.openUser(context, n.actor!);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    if (n.isOlt) return _OltNotificationTile(notification: n, onTap: onTap);
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final name = n.actor?.name ?? l10n.someone;
    final title = switch (n.type) {
      NotificationType.reply => l10n.notifReply(name),
      NotificationType.mention => l10n.notifMention(name),
      NotificationType.like => l10n.notifLike(name, n.actorCount < 1 ? 1 : n.actorCount, n.otherActors),
      NotificationType.follow => n.otherActors > 0 ? l10n.notifFollowMany(name, n.otherActors) : l10n.notifFollow(name),
      NotificationType.message => l10n.notifMessage(name, n.eventCount),
      NotificationType.announcement => n.title ?? l10n.notifAnnouncement(name),
      NotificationType.appeal => n.appealStatus == 'accepted' ? l10n.notifAppealAccepted : l10n.notifAppealRejected,
    };
    final icon = switch (n.type) {
      NotificationType.reply => Icons.reply,
      NotificationType.mention => Icons.alternate_email,
      NotificationType.like => Icons.favorite,
      NotificationType.follow => Icons.person_add_alt,
      NotificationType.message => Icons.chat_bubble,
      NotificationType.announcement => Icons.campaign,
      NotificationType.appeal => Icons.gavel_outlined,
    };
    final snippet = switch (n.type) {
      NotificationType.announcement => n.body,
      NotificationType.appeal => n.note ?? n.body,
      _ => n.snippet,
    };
    return ListTile(
      tileColor: n.isRead ? null : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CommunityAvatar(user: n.actor),
          Positioned(
            right: -4,
            bottom: -4,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: theme.colorScheme.surface,
              child: Icon(icon, size: 13, color: CommunityTheme.of(context).link),
            ),
          ),
        ],
      ),
      title: Text(title, style: n.isRead ? null : const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: snippet == null || snippet.isEmpty ? null : Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(l10n.relativeTime(n.createdAt), style: theme.textTheme.bodySmall),
    );
  }
}

class _OltNotificationTile extends StatelessWidget {
  const _OltNotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = l10n.localeName.split('_').first;
    final kind = n.oltKind;
    final kindLabel = kind == null ? null : notificationTypeLabel(l10n, kind);
    final title =
        n.localizedTitle(language) ?? (kindLabel == null || kindLabel == kind ? l10n.notifSectionOlt : kindLabel);
    final body = n.localizedBody(language);
    final important = n.oltCategory == 'important';
    final icon = important
        ? Icons.notification_important_outlined
        : switch (kind) {
            notificationTradeType => Icons.receipt_long_outlined,
            notificationFundsType => Icons.account_balance_wallet_outlined,
            notificationMarketType => Icons.show_chart,
            notificationPromoType => Icons.local_offer_outlined,
            _ => n.oltCategory == 'promo' ? Icons.local_offer_outlined : Icons.info_outline,
          };
    return ListTile(
      tileColor: n.isRead ? null : scheme.primaryContainer.withValues(alpha: 0.25),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: important ? scheme.errorContainer : scheme.secondaryContainer,
        child: Icon(icon, color: important ? scheme.onErrorContainer : scheme.onSecondaryContainer),
      ),
      title: Text(title, style: n.isRead ? null : const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: body == null ? null : Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(l10n.relativeTime(n.createdAt), style: theme.textTheme.bodySmall),
    );
  }
}

class CommunityNotificationBadge extends StatelessWidget {
  const CommunityNotificationBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    return BlocProvider(
      create: (_) => NotificationsCubit(notifications: deps.notifications, countOnly: true)..load(),
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        buildWhen: (a, b) => a.unread != b.unread,
        builder: (context, state) => Badge(
          isLabelVisible: state.unread > 0,
          label: Text(state.unread > 99 ? '99+' : '${state.unread}'),
          child: child,
        ),
      ),
    );
  }
}
