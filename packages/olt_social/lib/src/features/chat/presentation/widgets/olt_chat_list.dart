import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/new_group_dialog.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/olt_chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/room_tile.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltChatList extends StatelessWidget {
  const OltChatList({super.key, this.initialRoomId});

  final String? initialRoomId;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => ChatListCubit(chat: deps.chat, me: deps.ensureSignedIn)..load(),
      child: _ChatListLayout(initialRoomId: initialRoomId),
    );
  }
}

class _ChatListLayout extends StatefulWidget {
  const _ChatListLayout({this.initialRoomId});

  final String? initialRoomId;

  @override
  State<_ChatListLayout> createState() => _ChatListLayoutState();
}

class _ChatListLayoutState extends State<_ChatListLayout> {
  late String? _selected = widget.initialRoomId;

  Future<void> _open(BuildContext context, String roomId, {required bool wide}) async {
    final cubit = context.read<ChatListCubit>()..markOpened(roomId);
    if (wide) {
      setState(() => _selected = roomId);
      return;
    }
    final deps = OltSocialScope.of(context);
    final callback = deps.callbacks.onRoomTap;
    if (callback != null) return callback(context, roomId);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OltSocialScope(
        dependencies: deps,
        child: Scaffold(appBar: AppBar(), body: SafeArea(top: false, child: OltChatRoom(roomId: roomId))),
      ),
    ));
    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= OltBreakpoints.wide;
        final list = _RoomList(selectedRoomId: wide ? _selected : null, onOpen: (id) => _open(context, id, wide: wide));
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: 340, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selected == null
                  ? OltEmptyView(message: context.oltL10n.selectChat, icon: Icons.chat_outlined)
                  : OltChatRoom(key: ValueKey(_selected), roomId: _selected!),
            ),
          ],
        );
      },
    );
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({required this.selectedRoomId, required this.onOpen});

  final String? selectedRoomId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return BlocBuilder<ChatListCubit, ChatListState>(
      builder: (context, state) {
        final cubit = context.read<ChatListCubit>();
        final Widget body = switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const OltSkeleton(itemCount: 6),
          LoadStatus.failure => OltErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready when state.rooms.isEmpty => OltEmptyView(message: l10n.noChats, icon: Icons.chat_bubble_outline),
          LoadStatus.ready => RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.rooms.length,
              itemBuilder: (context, i) {
                final room = state.rooms[i];
                return RoomTile(
                  room: room,
                  me: state.me,
                  online: state.isOnline(room),
                  typing: state.typingIn(room.id),
                  selected: room.id == selectedRoomId,
                  onTap: () => onOpen(room.id),
                );
              },
            ),
          ),
        };
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.chats, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: l10n.newGroup,
                    onPressed: () async {
                      final roomId = await showNewGroupDialog(context);
                      if (roomId != null && context.mounted) {
                        await cubit.refresh();
                        onOpen(roomId);
                      }
                    },
                    icon: const Icon(Icons.group_add_outlined),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
