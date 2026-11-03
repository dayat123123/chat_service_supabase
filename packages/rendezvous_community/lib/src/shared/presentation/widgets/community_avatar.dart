import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/domain/entities/user.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_network_image.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.user, this.radius = 20, this.online = false, this.onTap});

  final UserSummary? user;
  final double radius;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.name ?? '?';
    final initials = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final url = user?.avatarUrl;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      foregroundImage: url == null
          ? null
          : communityUrlImageProvider(context, url, width: radius * 2, height: radius * 2),
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600),
      ),
    );

    if (online) {
      final dot = radius * 0.55;
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: CommunityTheme.of(context).onlineIndicator,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return Semantics(label: name, child: avatar);
    return Semantics(
      button: true,
      label: name,
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: avatar),
    );
  }
}
