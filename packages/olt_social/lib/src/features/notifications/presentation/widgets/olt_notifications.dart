import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/notifications/domain/entities/app_notification.dart';
import 'package:olt_social/src/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_avatar.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltNotificationList extends StatelessWidget {
  const OltNotificationList({super.key, this.onNotificationTap});

  final void Function(BuildContext context, AppNotification notification)? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => NotificationsCubit(notifications: deps.notifications)..load(),
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final l10n = context.oltL10n;
          final cubit = context.read<NotificationsCubit>();
          return switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const OltSkeleton(),
            LoadStatus.failure => OltErrorView(error: state.error!, onRetry: cubit.load),
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
                      ? OltEmptyView(message: l10n.noNotifications, icon: Icons.notifications_none)
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
    final postId = n.postId;
    final roomId = n.roomId;
    if (n.type == NotificationType.message && roomId != null) {
      OltNavigator.openRoom(context, roomId);
    } else if (postId != null) {
      OltNavigator.openPost(context, postId);
    } else if (n.actor != null) {
      OltNavigator.openUser(context, n.actor!);
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
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final name = n.actor?.name ?? l10n.someone;
    final title = switch (n.type) {
      NotificationType.reply => l10n.notifReply(name),
      NotificationType.mention => l10n.notifMention(name),
      NotificationType.like => l10n.notifLike(name, n.eventCount, n.eventCount - 1),
      NotificationType.follow => l10n.notifFollow(name),
      NotificationType.message => l10n.notifMessage(name, n.eventCount),
    };
    final icon = switch (n.type) {
      NotificationType.reply => Icons.reply,
      NotificationType.mention => Icons.alternate_email,
      NotificationType.like => Icons.favorite,
      NotificationType.follow => Icons.person_add_alt,
      NotificationType.message => Icons.chat_bubble,
    };
    return ListTile(
      tileColor: n.isRead ? null : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          OltAvatar(user: n.actor),
          Positioned(
            right: -4,
            bottom: -4,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: theme.colorScheme.surface,
              child: Icon(icon, size: 13, color: OltSocialTheme.of(context).link),
            ),
          ),
        ],
      ),
      title: Text(title, style: n.isRead ? null : const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: n.snippet == null || n.snippet!.isEmpty
          ? null
          : Text(n.snippet!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(l10n.relativeTime(n.createdAt), style: theme.textTheme.bodySmall),
    );
  }
}

class OltNotificationBadge extends StatelessWidget {
  const OltNotificationBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
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
