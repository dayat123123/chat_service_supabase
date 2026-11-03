import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_builders.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class CommunityCountBadge extends StatelessWidget {
  const CommunityCountBadge({
    super.key,
    required this.count,
    this.muted = false,
    this.kind = CommunityCountKind.roomUnread,
  });

  final int count;
  final bool muted;
  final CommunityCountKind kind;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final details = CommunityCountBadgeDetails(kind: kind, count: count, muted: muted);
    return buildCommunityPart(
      CommunityBadgeBuilders.of(context).count,
      context,
      details,
      _DefaultCountBadge(details: details),
    );
  }
}

class _DefaultCountBadge extends StatelessWidget {
  const _DefaultCountBadge({required this.details});

  final CommunityCountBadgeDetails details;

  @override
  Widget build(BuildContext context) {
    final t = CommunityTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = details.muted;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: muted ? scheme.outline : t.unreadBadge, borderRadius: BorderRadius.circular(10)),
      child: Text(
        details.label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: muted ? scheme.surface : t.onUnreadBadge, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class CommunityCountOverlay extends StatelessWidget {
  const CommunityCountOverlay({super.key, required this.kind, required this.count, required this.child});

  final CommunityCountKind kind;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final details = CommunityCountOverlayDetails(kind: kind, count: count, child: child);
    return buildCommunityPart(
      CommunityBadgeBuilders.of(context).countOverlay,
      context,
      details,
      Badge(isLabelVisible: count > 0, label: Text(details.label), child: child),
    );
  }
}
