import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/core/network/realtime_status.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/message_composer.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/message_list.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/room_header.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/typing_text.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltChatRoom extends StatelessWidget {
  const OltChatRoom({super.key, required this.roomId, this.showHeader = true});

  final String roomId;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => ChatRoomCubit(chat: deps.chat, media: deps.media, me: deps.ensureSignedIn, roomId: roomId)..load(),
      child: _ChatRoomView(showHeader: showHeader),
    );
  }
}

class _ChatRoomView extends StatelessWidget {
  const _ChatRoomView({required this.showHeader});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatRoomCubit, ChatRoomState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showOltError(context, state.actionError!),
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        final cubit = context.read<ChatRoomCubit>();
        return switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const OltSkeleton(itemCount: 6),
          LoadStatus.failure => OltErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready => Column(
            children: [
              if (showHeader) const RoomHeader(),
              const _ReconnectBanner(),
              const Expanded(child: MessageList()),
              const _TypingIndicator(),
              const Divider(height: 1),
              const MessageComposer(),
            ],
          ),
        };
      },
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final reconnecting = context.select((ChatRoomCubit c) => c.state.connection == RealtimeStatus.reconnecting);
    if (!reconnecting) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onTertiaryContainer),
          ),
          const SizedBox(width: 8),
          Text(context.oltL10n.reconnecting, style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final state = context.select((ChatRoomCubit c) => c.state);
    if (state.typing.isEmpty) return const SizedBox(height: 0);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          typingText(context.oltL10n, state.typing.values, direct: state.room?.type == RoomType.direct),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
