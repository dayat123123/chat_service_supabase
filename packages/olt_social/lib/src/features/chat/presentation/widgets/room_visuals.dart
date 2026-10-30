import 'package:flutter/material.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_room.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_avatar.dart';

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
