import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_unread_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_count_badge.dart';

class CommunityChatBadge extends StatelessWidget {
  const CommunityChatBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    return BlocProvider(
      create: (_) => ChatUnreadCubit(chat: deps.chat, notifications: deps.notifications)..load(),
      child: BlocBuilder<ChatUnreadCubit, int>(
        builder: (context, unread) =>
            CommunityCountOverlay(kind: CommunityCountKind.chatUnread, count: unread, child: child),
      ),
    );
  }
}
