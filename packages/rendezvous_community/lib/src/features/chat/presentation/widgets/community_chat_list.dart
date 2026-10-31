import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/builders/olt_chat_builders.dart';
import 'package:olt_social/src/features/chat/presentation/builders/olt_chat_details.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/new_group_dialog.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/olt_chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/room_tile.dart';
import 'package:olt_social/src/features/support/presentation/widgets/olt_support_chat.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltChatList extends StatelessWidget {
  const OltChatList({super.key, this.initialRoomId, this.builders});

  final String? initialRoomId;
  final OltChatBuilders? builders;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return withChatBuilders(
      context,
      builders,
      BlocProvider(
        create: (_) => ChatListCubit(chat: deps.chat, me: deps.ensureSignedIn)..load(),
        child: _ChatListLayout(initialRoomId: initialRoomId),
      ),
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
  bool _selectedSupport = false;

  Future<void> _open(BuildContext context, ChatRoom room, {required bool wide}) async {
    final roomId = room.id;
    final support = room.type == RoomType.support;
    final cubit = context.read<ChatListCubit>()..markOpened(roomId);
    if (wide) {
      setState(() {
        _selected = roomId;
        _selectedSupport = support;
      });
      return;
    }
    if (support) {
      await openOltSupport(context);
      await cubit.refresh();
      return;
    }
    final deps = OltSocialScope.of(context);
    final callback = deps.callbacks.onRoomTap;
    if (callback != null) return callback(context, roomId);
    final carry = carryChatBuilders(context);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => carry(
        OltSocialScope(
          dependencies: deps,
          child: Scaffold(appBar: AppBar(), body: SafeArea(top: false, child: OltChatRoom(roomId: roomId))),
        ),
      ),
    ));
    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= OltBreakpoints.wide;
        final list = _RoomList(selectedRoomId: wide ? _selected : null, onOpen: (room) => _open(context, room, wide: wide));
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: 340, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selected == null
                  ? buildChatPart(
                      OltChatBuilders.of(context).empty,
                      context,
                      OltEmptyDetails(kind: OltChatEmpty.noRoomSelected, message: context.oltL10n.selectChat),
                      OltEmptyView(message: context.oltL10n.selectChat, icon: Icons.chat_outlined),
                    )
                  : _selectedSupport
                      ? const OltSupportChat()
                      : OltChatRoom(key: ValueKey(_selected), roomId: _selected!),
            ),
          ],
        );
      },
    );
  }
}

class _RoomList extends StatefulWidget {
  const _RoomList({required this.selectedRoomId, required this.onOpen});

  final String? selectedRoomId;
  final ValueChanged<ChatRoom> onOpen;

  @override
  State<_RoomList> createState() => _RoomListState();
}

class _RoomListState extends State<_RoomList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 600) context.read<ChatListCubit>().loadMore();
  }

  Future<void> _newGroup(BuildContext context, ChatListCubit cubit) async {
    final roomId = await showNewGroupDialog(context);
    if (roomId == null || !context.mounted) return;
    await cubit.refresh();
    final room = cubit.state.rooms.where((r) => r.id == roomId).firstOrNull;
    if (room != null) widget.onOpen(room);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final builders = OltChatBuilders.of(context);
    return BlocBuilder<ChatListCubit, ChatListState>(
      builder: (context, state) {
        final cubit = context.read<ChatListCubit>();
        final Widget body = switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => buildChatPart(
            builders.loading,
            context,
            const OltLoadingDetails(OltChatLoad.rooms),
            const OltSkeleton(itemCount: 6),
          ),
          LoadStatus.failure => buildChatPart(
            builders.error,
            context,
            OltErrorDetails(error: state.error!, message: l10n.errorMessage(state.error!), onRetry: cubit.load),
            OltErrorView(error: state.error!, onRetry: cubit.load),
          ),
          LoadStatus.ready when state.rooms.isEmpty => buildChatPart(
            builders.empty,
            context,
            OltEmptyDetails(kind: OltChatEmpty.rooms, message: l10n.noChats),
            OltEmptyView(message: l10n.noChats, icon: Icons.chat_bubble_outline),
          ),
          LoadStatus.ready => RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.rooms.length + (state.loadingMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == state.rooms.length) {
                  return buildChatPart(
                    builders.loading,
                    context,
                    const OltLoadingDetails(OltChatLoad.moreRooms),
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                  );
                }
                final room = state.rooms[i];
                return RoomTile(
                  room: room,
                  me: state.me,
                  online: state.isOnline(room),
                  typing: state.typingIn(room.id),
                  selected: room.id == widget.selectedRoomId,
                  onTap: () => widget.onOpen(room),
                );
              },
            ),
          ),
        };
        if (state.status == LoadStatus.ready && state.rooms.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadMoreNearEnd();
          });
        }
        final header = OltChatListHeaderDetails(
          title: l10n.chats,
          onNewGroup: () => _newGroup(context, cubit),
          onRefresh: cubit.refresh,
        );
        return Column(
          children: [
            buildChatPart(builders.listHeader, context, header, _DefaultListHeader(details: header)),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _DefaultListHeader extends StatelessWidget {
  const _DefaultListHeader({required this.details});

  final OltChatListHeaderDetails details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(details.title, style: Theme.of(context).textTheme.titleLarge)),
          IconButton(
            tooltip: context.oltL10n.newGroup,
            onPressed: details.onNewGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
    );
  }
}
