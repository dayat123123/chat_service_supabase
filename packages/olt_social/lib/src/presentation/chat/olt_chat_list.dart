import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/chat.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';
import '../feed/feed_cubit.dart' show LoadStatus;
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../theme/olt_social_theme.dart';
import '../widgets/common.dart';
import 'olt_chat_room.dart';

part 'olt_chat_list.freezed.dart';

@freezed
abstract class ChatListState with _$ChatListState {
  const factory ChatListState({
    @Default(LoadStatus.initial) LoadStatus status,
    @Default(<ChatRoom>[]) List<ChatRoom> rooms,
    @Default(<String>{}) Set<String> online,
    UserSummary? me,
    Object? error,
  }) = _ChatListState;
}

class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit({required this._chat, required this._me})
    : super(const ChatListState());

  final ChatRepository _chat;
  final Future<UserSummary> Function() _me;
  StreamSubscription<RoomActivity>? _activity;
  StreamSubscription<Set<String>>? _presence;
  Timer? _debounce;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, error: null));
    try {
      final me = await _me();
      final rooms = await _chat.getRooms();
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.ready, rooms: rooms, me: me));
      _activity ??= _chat.watchRoomActivity().listen((_) => _scheduleRefresh(), onError: (Object _) {});
      _presence ??= _chat.watchOnlineUsers(me: me).listen((ids) {
        if (!isClosed) emit(state.copyWith(online: ids));
      }, onError: (Object _) {});
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  Future<void> refresh() async {
    try {
      final rooms = await _chat.getRooms();
      if (!isClosed) emit(state.copyWith(rooms: rooms, status: LoadStatus.ready));
    } catch (_) {
      // Daftar lama tetap ditampilkan.
    }
  }

  /// Room dibuka: tandai terbaca secara lokal (server ditandai oleh room).
  void markOpened(String roomId) => emit(state.copyWith(rooms: [
    for (final r in state.rooms) r.id == roomId ? r.copyWith(unreadCount: 0) : r,
  ]));

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _activity?.cancel();
    await _presence?.cancel();
    return super.close();
  }
}

/// Daftar percakapan. Di layar lebar tampil multi-panel (daftar + room).
class OltChatList extends StatelessWidget {
  const OltChatList({super.key, this.initialRoomId});

  /// Room yang langsung dibuka di panel kanan (layar lebar).
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
    final callback = OltSocialScope.of(context).callbacks.onRoomTap;
    if (callback != null) return callback(context, roomId);
    final deps = OltSocialScope.of(context);
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
                return _RoomTile(
                  room: room,
                  me: state.me,
                  online: room.otherUser != null && state.online.contains(room.otherUser!.id),
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

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.me, required this.online, required this.selected, required this.onTap});

  final ChatRoom room;
  final UserSummary? me;
  final bool online;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final preview = room.lastMessagePreview;
    final fromMe = room.lastMessageSenderId != null && room.lastMessageSenderId == me?.id;
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: roomAvatar(context, room, online: online),
      title: Text(roomTitle(room), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: preview == null
          ? null
          : Text(
              fromMe ? '${l10n.you}: $preview' : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: room.unreadCount > 0 ? const TextStyle(fontWeight: FontWeight.w600) : null,
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(l10n.relativeTime(room.sortTime), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (room.muted) Icon(Icons.notifications_off_outlined, size: 14, color: theme.colorScheme.outline),
              OltCountBadge(count: room.unreadCount, muted: room.muted),
            ],
          ),
        ],
      ),
    );
  }
}

/// Judul room: nama lawan bicara, nama grup, atau $KODE.
String roomTitle(ChatRoom room) => switch (room.type) {
  RoomType.direct => room.otherUser?.name ?? '',
  RoomType.group => room.name ?? '',
  RoomType.stock => '\$${room.stockCode}',
};

Widget roomAvatar(BuildContext context, ChatRoom room, {bool online = false, double radius = 20}) {
  final scheme = Theme.of(context).colorScheme;
  return switch (room.type) {
    RoomType.direct => OltAvatar(user: room.otherUser, online: online, radius: radius),
    RoomType.group => CircleAvatar(
      radius: radius,
      backgroundColor: scheme.tertiaryContainer,
      foregroundColor: scheme.onTertiaryContainer,
      child: const Icon(Icons.group),
    ),
    RoomType.stock => CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: const Icon(Icons.show_chart),
    ),
  };
}

/// Dialog membuat grup baru; mengembalikan id room.
Future<String?> showNewGroupDialog(BuildContext context) {
  final deps = OltSocialScope.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => OltSocialScope(dependencies: deps, child: const _NewGroupDialog()),
  );
}

class _NewGroupDialog extends StatefulWidget {
  const _NewGroupDialog();

  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _name = TextEditingController();
  final _query = TextEditingController();
  final _selected = <String, UserSummary>{};
  List<UserSummary> _results = const [];
  Timer? _debounce;
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    final deps = OltSocialScope.of(context);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final users = await deps.profiles.searchUsers(q);
        final me = deps.currentUser?.id;
        if (mounted) setState(() => _results = [for (final u in users) if (u.id != me) u]);
      } catch (_) {}
    });
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final id = await OltSocialScope.of(context).chat.createGroupRoom(_name.text.trim(), _selected.keys.toList());
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showOltError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return AlertDialog(
      title: Text(l10n.newGroup),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.groupName),
              onChanged: (_) => setState(() {}),
            ),
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (final u in _selected.values)
                    InputChip(label: Text(u.name), onDeleted: () => setState(() => _selected.remove(u.id))),
                ],
              ),
            TextField(
              controller: _query,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchUsers),
              onChanged: _search,
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final u in _results)
                    CheckboxListTile(
                      value: _selected.containsKey(u.id),
                      secondary: OltAvatar(user: u, radius: 16),
                      title: Text(u.name),
                      subtitle: Text('@${u.username}'),
                      onChanged: (v) => setState(() => v! ? _selected[u.id] = u : _selected.remove(u.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _creating || _name.text.trim().isEmpty ? null : _create,
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
