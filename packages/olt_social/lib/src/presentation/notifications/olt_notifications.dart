import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/notification.dart';
import '../../domain/repositories/repositories.dart';
import '../feed/feed_cubit.dart' show LoadStatus;
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../theme/olt_social_theme.dart';
import '../widgets/common.dart';

part 'olt_notifications.freezed.dart';

@freezed
abstract class NotificationsState with _$NotificationsState {
  const factory NotificationsState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<AppNotification>[]) List<AppNotification> items,
    String? nextCursor,
    @Default(false) bool loadingMore,
    @Default(0) int unread,
    Object? error,
  }) = _NotificationsState;
}

/// Daftar notifikasi + jumlah belum dibaca, diperbarui secara realtime.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required NotificationRepository notifications, this.countOnly = false})
    : _repo = notifications,
      super(const NotificationsState());

  final NotificationRepository _repo;

  /// Hanya menghitung belum dibaca (untuk badge).
  final bool countOnly;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  Future<void> load() async {
    if (!countOnly) emit(state.copyWith(status: LoadStatus.loading, error: null));
    await _fetch();
    _sub ??= _repo.watchNotifications().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _fetch);
    }, onError: (Object _) {});
  }

  Future<void> _fetch() async {
    try {
      final unread = await _repo.unreadCount();
      if (countOnly) {
        if (!isClosed) emit(state.copyWith(unread: unread, status: LoadStatus.ready));
        return;
      }
      final page = await _repo.getNotifications();
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.ready, items: page.items, nextCursor: page.nextCursor, unread: unread));
      }
    } catch (e) {
      if (!isClosed && state.status != LoadStatus.ready) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repo.getNotifications(cursor: cursor);
      if (!isClosed) {
        emit(state.copyWith(items: [...state.items, ...page.items], nextCursor: page.nextCursor, loadingMore: false));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final now = DateTime.now();
    emit(state.copyWith(
      items: [for (final i in state.items) i.id == n.id ? i.copyWith(readAt: now) : i],
      unread: state.unread > 0 ? state.unread - 1 : 0,
    ));
    try {
      await _repo.markRead(ids: [n.id]);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    emit(state.copyWith(items: [for (final i in state.items) i.isRead ? i : i.copyWith(readAt: now)], unread: 0));
    try {
      await _repo.markRead();
    } catch (_) {
      await _fetch();
    }
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}

/// Daftar notifikasi. Ketuk -> buka post / room / profil terkait.
class OltNotificationList extends StatelessWidget {
  const OltNotificationList({super.key, this.onNotificationTap});

  /// Ganti navigasi bawaan.
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

/// Badge jumlah notifikasi belum dibaca di atas [child] (mis. ikon lonceng OLT).
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
