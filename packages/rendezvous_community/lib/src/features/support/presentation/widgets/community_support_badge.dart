import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/app/community_support_scope.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_events.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/support/domain/repositories/support_repository.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_count_badge.dart';

class SupportUnreadCubit extends Cubit<int> {
  SupportUnreadCubit({required this._support, required this._chat, required this._supportChat}) : super(0);

  final SupportRepository _support;
  final ChatRepository _chat;
  final ChatRepository _supportChat;
  String? _roomId;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Future<void> start() async {
    _subscriptions
      ..add(_chat.watchRoomActivity().listen(_onActivity))
      ..add(_supportChat.watchUnreadChanges().listen((_) => refresh()));
    await refresh();
  }

  void _onActivity(RoomActivity activity) {
    if (_roomId == null || activity.roomId == _roomId) unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final home = await _support.home();
      _roomId = home.roomId;
      if (!isClosed) emit(home.unreadCount);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }
}

class CommunitySupportBadge extends StatelessWidget {
  const CommunitySupportBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final support = CommunitySupportScope.of(context);
    return BlocProvider(
      create: (_) => SupportUnreadCubit(
        support: support.support,
        chat: CommunityScope.of(context).chat,
        supportChat: support.supportChat,
      )..start(),
      child: BlocBuilder<SupportUnreadCubit, int>(
        builder: (context, count) =>
            CommunityCountOverlay(kind: CommunityCountKind.supportUnread, count: count, child: child),
      ),
    );
  }
}
