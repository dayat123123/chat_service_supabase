import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';

String roomTitle(ChatRoom room) => switch (room.type) {
  RoomType.direct => room.otherUser?.name ?? '',
  RoomType.group || RoomType.support => room.name ?? '',
  RoomType.stock => '\$${room.stockCode}',
};

class CommunityRoomAvatar extends StatelessWidget {
  const CommunityRoomAvatar({super.key, required this.room, this.online = false, this.radius = 20});

  final ChatRoom room;
  final bool online;
  final double radius;

  @override
  Widget build(BuildContext context) => roomAvatar(context, room, online: online, radius: radius);
}

Widget roomAvatar(BuildContext context, ChatRoom room, {bool online = false, double radius = 20}) {
  final scheme = Theme.of(context).colorScheme;
  return switch (room.type) {
    RoomType.direct => CommunityAvatar(user: room.otherUser, online: online, radius: radius),
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
    RoomType.support => CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: const Icon(Icons.support_agent),
    ),
  };
}
