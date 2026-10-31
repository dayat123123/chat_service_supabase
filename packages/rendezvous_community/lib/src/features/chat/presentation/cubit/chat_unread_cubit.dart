import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/notifications/domain/repositories/notification_repository.dart';

class ChatUnreadCubit extends Cubit<int> {
  ChatUnreadCubit({
    required this._chat,
    required this._notifications,
    this.refreshDelay = const Duration(milliseconds: 1200),
  }) : super(0);

  final ChatRepository _chat;
  final NotificationRepository _notifications;
  final Duration refreshDelay;
  StreamSubscription<void>? _local;
  StreamSubscription<void>? _remote;
  Timer? _debounce;

  Future<void> load() async {
    await _fetch();
    if (isClosed) return;
    _local ??= _chat.watchUnreadChanges().listen((_) => _scheduleFetch(), onError: (Object _) {});
    _remote ??= _notifications.watchNotifications().listen((_) => _scheduleFetch(), onError: (Object _) {});
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(refreshDelay, _fetch);
  }

  Future<void> _fetch() async {
    try {
      final count = await _chat.unreadChatCount();
      if (!isClosed) emit(count);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _local?.cancel();
    await _remote?.cancel();
    return super.close();
  }
}
