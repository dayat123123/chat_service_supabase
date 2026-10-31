import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rendezvous_community/src/features/notifications/domain/entities/app_notification.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';

part 'notifications_cubit.freezed.dart';

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

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required NotificationRepository notifications, this.countOnly = false})
    : _repo = notifications,
      super(const NotificationsState());

  final NotificationRepository _repo;
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
    emit(
      state.copyWith(
        items: [for (final i in state.items) i.id == n.id ? i.copyWith(readAt: now) : i],
        unread: state.unread > 0 ? state.unread - 1 : 0,
      ),
    );
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
