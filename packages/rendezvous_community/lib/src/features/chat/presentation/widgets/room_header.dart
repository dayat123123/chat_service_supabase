import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_visuals.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/typing_text.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class RoomHeader extends StatelessWidget {
  const RoomHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final builder = CommunityChatBuilders.of(context).roomHeader;
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      buildWhen: (a, b) =>
          a.room != b.room || a.typing != b.typing || a.members.length != b.members.length || a.online != b.online,
      builder: (context, state) {
        final room = state.room;
        if (room == null) return const SizedBox.shrink();
        final cubit = context.read<ChatRoomCubit>();
        final typing = state.typing.isNotEmpty;
        final otherUser = room.otherUser;
        final stockCode = room.stockCode;
        final details = CommunityRoomHeaderDetails(
          room: room,
          title: roomTitle(room),
          subtitle: typing
              ? typingText(l10n, state.typing.values, direct: room.type == RoomType.direct)
              : switch (room.type) {
                  RoomType.direct when state.otherOnline => l10n.online,
                  RoomType.direct => '@${otherUser?.username ?? ''}',
                  RoomType.group => l10n.members(state.members.length),
                  RoomType.stock => '${room.name ?? ''} · ${l10n.members(state.members.length)}',
                  RoomType.support => l10n.supportOfficialChannel,
                },
          highlightSubtitle: typing || (room.type == RoomType.direct && state.otherOnline),
          online: state.otherOnline,
          typing: state.typing.values.toList(),
          memberCount: state.members.length,
          onTap: room.type == RoomType.direct && otherUser != null
              ? () => CommunityNavigator.openUser(context, otherUser)
              : room.type == RoomType.stock && stockCode != null
              ? () => CommunityNavigator.openStock(context, stockCode)
              : null,
          onToggleMute: room.type == RoomType.support ? null : () => cubit.setMuted(!room.muted),
          onLeave: room.type == RoomType.direct || room.type == RoomType.support
              ? null
              : () async {
                  if (await cubit.leave() && context.mounted) await Navigator.of(context).maybePop();
                },
        );
        return buildChatPart(builder, context, details, _DefaultRoomHeader(details: details));
      },
    );
  }
}

class _DefaultRoomHeader extends StatelessWidget {
  const _DefaultRoomHeader({required this.details});

  final CommunityRoomHeaderDetails details;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final l10n = context.communityL10n;
    final onToggleMute = d.onToggleMute;
    final onLeave = d.onLeave;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: roomAvatar(context, d.room, online: d.online),
        title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          d.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: d.highlightSubtitle ? TextStyle(color: CommunityTheme.of(context).onlineIndicator) : null,
        ),
        onTap: d.onTap,
        trailing: onToggleMute == null
            ? null
            : PopupMenuButton<VoidCallback>(
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: onToggleMute, child: Text(d.room.muted ? l10n.unmute : l10n.mute)),
                  if (onLeave != null) PopupMenuItem(value: onLeave, child: Text(l10n.leaveRoom)),
                ],
              ),
      ),
    );
  }
}
