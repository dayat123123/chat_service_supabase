import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/message_bubble.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

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
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) context.read<ChatRoomCubit>().loadOlder();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      buildWhen: (a, b) =>
          a.messages != b.messages || a.members != b.members || a.loadingOlder != b.loadingOlder || a.room != b.room,
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return OltEmptyView(message: context.oltL10n.messageHint, icon: Icons.waving_hand_outlined);
        }
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: state.messages.length + (state.loadingOlder ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.messages.length) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            }
            final message = state.messages[i];
            final older = i + 1 < state.messages.length ? state.messages[i + 1] : null;
            final grouped = older != null &&
                older.senderId == message.senderId &&
                message.createdAt.difference(older.createdAt).inMinutes < 3;
            final mine = state.isMine(message);
            return MessageBubble(
              key: ValueKey(message.clientId ?? message.id),
              message: message,
              mine: mine,
              receipt: state.receiptOf(message),
              showSender: !grouped && state.room?.type != RoomType.direct && !mine,
            );
          },
        );
      },
    );
  }
}
