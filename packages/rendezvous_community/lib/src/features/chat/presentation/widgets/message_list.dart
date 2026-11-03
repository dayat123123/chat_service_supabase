import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_bubble.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadOlderNearTop);
  }

  void _loadOlderNearTop() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) context.read<ChatRoomCubit>().loadOlder();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builders = CommunityChatBuilders.of(context);
    final l10n = context.communityL10n;
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      buildWhen: (a, b) =>
          a.messages != b.messages ||
          a.members != b.members ||
          a.loadingOlder != b.loadingOlder ||
          a.room != b.room ||
          a.stockRoom?.moderatorIds != b.stockRoom?.moderatorIds ||
          a.stockRoom?.mutes != b.stockRoom?.mutes ||
          a.me != b.me,
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return buildChatPart(
            builders.empty,
            context,
            CommunityEmptyDetails(kind: CommunityChatEmpty.messages, message: l10n.messageHint),
            CommunityEmptyView(message: l10n.messageHint, icon: Icons.waving_hand_outlined),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadOlderNearTop();
        });
        return ListView.builder(
          addAutomaticKeepAlives: false,
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: state.messages.length + (state.loadingOlder ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.messages.length) {
              return buildChatPart(
                builders.loading,
                context,
                const CommunityLoadingDetails(CommunityChatLoad.olderMessages),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final message = state.messages[i];
            final older = i + 1 < state.messages.length ? state.messages[i + 1] : null;
            final newDay = older == null || !_sameDay(older.createdAt, message.createdAt);
            final grouped =
                older != null &&
                !newDay &&
                !older.isSystem &&
                older.senderId == message.senderId &&
                message.createdAt.difference(older.createdAt).inMinutes < 3;
            final mine = state.isMine(message);
            final bubble = MessageBubble(
              key: ValueKey(message.clientId ?? message.id),
              message: message,
              mine: mine,
              receipt: state.receiptOf(message),
              showSender: !grouped && state.room?.type != RoomType.direct && !mine,
              startsGroup: !grouped,
            );
            if (!newDay) return bubble;
            final divider = buildChatPart(
              builders.dayDivider,
              context,
              CommunityDayDetails(day: message.createdAt, label: l10n.dayLabel(message.createdAt)),
              _DayDivider(time: message.createdAt),
            );
            return Column(
              key: ValueKey('day-${message.clientId ?? message.id}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [divider, bubble],
            );
          },
        );
      },
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            context.communityL10n.dayLabel(time),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
