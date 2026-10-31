import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_unread_cubit.dart';

class OltChatBadge extends StatelessWidget {
  const OltChatBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => ChatUnreadCubit(chat: deps.chat, notifications: deps.notifications)..load(),
      child: BlocBuilder<ChatUnreadCubit, int>(
        builder: (context, unread) => Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: child,
        ),
      ),
    );
  }
}
