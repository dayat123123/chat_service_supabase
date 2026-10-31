import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class CommunityCountBadge extends StatelessWidget {
  const CommunityCountBadge({super.key, required this.count, this.muted = false});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = CommunityTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: muted ? scheme.outline : t.unreadBadge, borderRadius: BorderRadius.circular(10)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: muted ? scheme.surface : t.onUnreadBadge, fontWeight: FontWeight.w700),
      ),
    );
  }
}
