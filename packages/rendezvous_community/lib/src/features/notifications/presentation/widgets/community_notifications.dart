import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_moderation.dart'
    show roomModerationTime;
import 'package:rendezvous_community/src/features/notifications/domain/entities/app_notification.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_event.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/notification_preferences.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/builders/community_notification_builders.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/builders/community_notification_details.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:rendezvous_community/src/features/notifications/presentation/widgets/community_notification_settings.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_list_state_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_count_badge.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityNotificationList extends StatelessWidget {
  const CommunityNotificationList({super.key, this.onNotificationTap, this.builders});

  final void Function(BuildContext context, AppNotification notification)? onNotificationTap;
  final CommunityNotificationBuilders? builders;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    return withNotificationBuilders(
      context,
      builders,
      BlocProvider(
        create: (_) => NotificationsCubit(notifications: deps.notifications)..load(),
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            final l10n = context.communityL10n;
            final cubit = context.read<NotificationsCubit>();
            final parts = CommunityNotificationBuilders.of(context);
            final header = CommunityNotificationHeaderDetails(
              title: l10n.notifications,
              unread: state.unread,
              onMarkAllRead: state.unread == 0 ? null : cubit.markAllRead,
            );
            return switch (state.status) {
              LoadStatus.initial || LoadStatus.loading => buildCommunityPart(
                parts.loading,
                context,
                const CommunityListLoadingDetails(),
                const CommunitySkeleton(),
              ),
              LoadStatus.failure => buildCommunityPart(
                parts.error,
                context,
                CommunityListErrorDetails(
                  error: state.error!,
                  message: l10n.errorMessage(state.error!),
                  onRetry: cubit.load,
                ),
                CommunityErrorView(error: state.error!, onRetry: cubit.load),
              ),
              LoadStatus.ready => Column(
                children: [
                  buildCommunityPart(parts.header, context, header, _NotificationHeader(details: header)),
                  Expanded(
                    child: state.items.isEmpty
                        ? buildCommunityPart(
                            parts.empty,
                            context,
                            CommunityListEmptyDetails(message: l10n.noNotifications),
                            CommunityEmptyView(message: l10n.noNotifications, icon: Icons.notifications_none),
                          )
                        : NotificationListener<ScrollEndNotification>(
                            onNotification: (n) {
                              if (n.metrics.extentAfter < 300) cubit.loadMore();
                              return false;
                            },
                            child: ListView.separated(
                              addAutomaticKeepAlives: false,
                              itemCount: state.items.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final n = state.items[i];
                                return _NotificationTile(
                                  key: ValueKey(n.id),
                                  notification: n,
                                  onTap: () {
                                    cubit.markRead(n);
                                    final reporter = context.communityFeatures?.notificationReporter;
                                    final source = NotificationSource(notificationId: n.id);
                                    unawaited(reporter?.opened(source));
                                    final custom = onNotificationTap;
                                    if (custom != null) return custom(context, n);
                                    if (openCommunityNotification(context, n)) unawaited(reporter?.tapped(source));
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
      ),
    );
  }
}

bool openCommunityNotification(BuildContext context, AppNotification n) {
  if (n.isOlt) {
    final callback = CommunityScope.of(context).callbacks.onOltNotificationTap;
    callback?.call(context, Map.unmodifiable({...n.payload, 'notification_id': n.id}));
    return callback != null;
  }
  final postId = n.postId;
  final roomId = n.roomId;
  final url = Uri.tryParse(n.url ?? '');
  final topStock = n.stocks.firstOrNull;
  if (n.isRoomMute && roomId != null) {
    CommunityNavigator.openRoom(context, roomId);
  } else if (n.type == NotificationType.appeal || n.type == NotificationType.moderation) {
    if (context.communityFeatures == null) return false;
    unawaited(openCommunityAppeals(context));
  } else if (n.type == NotificationType.watchlistDigest) {
    if (topStock == null) return false;
    CommunityNavigator.openStock(context, topStock, source: 'notification');
  } else if (n.type == NotificationType.announcement && postId == null && url != null && url.scheme == 'https') {
    unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
  } else if ((n.type == NotificationType.message || n.isRoomMention) && roomId != null) {
    CommunityNavigator.openRoom(context, roomId);
  } else if (postId != null) {
    CommunityNavigator.openPost(context, postId);
  } else if (n.actor != null) {
    CommunityNavigator.openUser(context, n.actor!);
  } else {
    return false;
  }
  return true;
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({required this.details});

  final CommunityNotificationHeaderDetails details;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
    child: Row(
      children: [
        Expanded(child: Text(details.title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
          onPressed: details.onMarkAllRead,
          icon: const Icon(Icons.done_all),
          label: Text(context.communityL10n.markAllRead),
        ),
      ],
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({super.key, required this.notification, required this.onTap});

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
      NotificationType.mention when n.isRoomMention => l10n.notifMentionRoom(
        name,
        n.stockCode == null ? (n.payload['room_name'] as String? ?? '') : '\$${n.stockCode}',
      ),
      NotificationType.mention => l10n.notifMention(name),
      NotificationType.like => l10n.notifLike(name, n.actorCount < 1 ? 1 : n.actorCount, n.otherActors),
      NotificationType.follow => n.otherActors > 0 ? l10n.notifFollowMany(name, n.otherActors) : l10n.notifFollow(name),
      NotificationType.message => l10n.notifMessage(name, n.eventCount),
      NotificationType.announcement => n.title ?? l10n.notifAnnouncement(name),
      NotificationType.appeal => n.appealStatus == 'accepted' ? l10n.notifAppealAccepted : l10n.notifAppealRejected,
      NotificationType.followedPost =>
        n.eventCount > 1 ? l10n.notifFollowedPostMany(name, n.eventCount) : l10n.notifFollowedPost(name),
      NotificationType.watchlistDigest => l10n.notifWatchlistDigest,
      NotificationType.moderation => notificationModerationTitle(l10n, n),
    };
    final icon = switch (n.type) {
      NotificationType.followedPost => Icons.article_outlined,
      NotificationType.watchlistDigest => Icons.insights_outlined,
      NotificationType.moderation => Icons.shield_outlined,
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
      NotificationType.watchlistDigest => notificationDigestText(l10n, n),
      NotificationType.moderation when n.isRoomMute => roomMuteNotificationText(l10n, n),
      NotificationType.moderation => [
        if ((n.excerpt ?? '').isNotEmpty) n.excerpt!,
        n.appealable ? l10n.notifModerationAppealable : l10n.notifModerationAppealed,
      ].join('\n'),
      _ => n.snippet,
    };
    final details = CommunityNotificationDetails(
      notification: n,
      title: title,
      snippet: snippet == null || snippet.isEmpty ? null : snippet,
      icon: icon,
      timeLabel: l10n.relativeTime(n.createdAt),
      onTap: onTap,
    );
    return buildCommunityPart(
      CommunityNotificationBuilders.of(context).item,
      context,
      details,
      ListTile(
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
        subtitle: details.snippet == null ? null : Text(details.snippet!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(details.timeLabel, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

String notificationModerationTitle(CommunityLocalizations l10n, AppNotification n) {
  if (n.isRoomMute) {
    final room = n.stockCode == null ? (n.payload['room_name'] as String? ?? '') : '\$${n.stockCode}';
    return n.moderationState == 'muted' ? l10n.notifRoomMuted(room) : l10n.notifRoomUnmuted(room);
  }
  final target = switch (n.targetType) {
    'comment' => l10n.notifTargetComment,
    'message' => l10n.notifTargetMessage,
    _ => l10n.notifTargetPost,
  };
  return n.moderationState == 'removed' ? l10n.notifModerationRemoved(target) : l10n.notifModerationHidden(target);
}

String roomMuteNotificationText(CommunityLocalizations l10n, AppNotification n) {
  final until = n.muteUntil;
  return n.moderationState == 'muted' && until != null
      ? l10n.notifRoomMutedUntil(roomModerationTime(l10n, until))
      : l10n.notifRoomUnmutedBody;
}

String notificationDigestText(CommunityLocalizations l10n, AppNotification n) {
  final codes = [for (final code in n.stocks) '\$$code'].join(', ');
  final others = n.stockCount - n.stocks.length;
  return l10n.notifWatchlistDigestBody(n.postCount, codes, others < 0 ? 0 : others);
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
    final details = CommunityNotificationDetails(
      notification: n,
      title: title,
      snippet: body,
      icon: icon,
      important: important,
      timeLabel: l10n.relativeTime(n.createdAt),
      onTap: onTap,
    );
    return buildCommunityPart(
      CommunityNotificationBuilders.of(context).item,
      context,
      details,
      ListTile(
        tileColor: n.isRead ? null : scheme.primaryContainer.withValues(alpha: 0.25),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: important ? scheme.errorContainer : scheme.secondaryContainer,
          child: Icon(icon, color: important ? scheme.onErrorContainer : scheme.onSecondaryContainer),
        ),
        title: Text(title, style: n.isRead ? null : const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: body == null ? null : Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(details.timeLabel, style: theme.textTheme.bodySmall),
      ),
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
        builder: (context, state) =>
            CommunityCountOverlay(kind: CommunityCountKind.notificationUnread, count: state.unread, child: child),
      ),
    );
  }
}
