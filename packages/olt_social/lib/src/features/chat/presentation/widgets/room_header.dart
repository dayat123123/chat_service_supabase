import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/room_visuals.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/typing_text.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';

class RoomHeader extends StatelessWidget {
  const RoomHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      buildWhen: (a, b) =>
          a.room != b.room || a.typing != b.typing || a.members.length != b.members.length || a.online != b.online,
      builder: (context, state) {
        final room = state.room;
        if (room == null) return const SizedBox.shrink();
        final cubit = context.read<ChatRoomCubit>();
        final typing = state.typing.isNotEmpty;
        final subtitle = typing
            ? typingText(l10n, state.typing.values, direct: room.type == RoomType.direct)
            : switch (room.type) {
                RoomType.direct when state.otherOnline => l10n.online,
                RoomType.direct => '@${room.otherUser?.username ?? ''}',
                RoomType.group => l10n.members(state.members.length),
                RoomType.stock => '${room.name ?? ''} · ${l10n.members(state.members.length)}',
              };
        final accent = typing || (room.type == RoomType.direct && state.otherOnline);
        return Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: roomAvatar(context, room, online: state.otherOnline),
            title: Text(roomTitle(room), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: accent ? TextStyle(color: OltSocialTheme.of(context).onlineIndicator) : null,
            ),
            onTap: room.type == RoomType.direct && room.otherUser != null
                ? () => OltNavigator.openUser(context, room.otherUser!)
                : room.type == RoomType.stock && room.stockCode != null
                    ? () => OltNavigator.openStock(context, room.stockCode!)
                    : null,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                switch (action) {
                  case 'mute':
                    await cubit.setMuted(!room.muted);
                  case 'leave':
                    if (await cubit.leave() && context.mounted) await Navigator.of(context).maybePop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'mute', child: Text(room.muted ? l10n.unmute : l10n.mute)),
                if (room.type != RoomType.direct) PopupMenuItem(value: 'leave', child: Text(l10n.leaveRoom)),
              ],
            ),
          ),
        );
      },
    );
  }
}
