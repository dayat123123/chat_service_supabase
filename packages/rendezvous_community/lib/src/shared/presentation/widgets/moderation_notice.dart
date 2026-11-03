import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/domain/entities/moderation_status.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_builders.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class ModerationNotice extends StatelessWidget {
  const ModerationNotice({super.key, required this.status, this.onAppeal, this.compact = false, this.color});

  final ModerationStatus? status;
  final VoidCallback? onAppeal;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    if (status == null || status == ModerationStatus.visible) return const SizedBox.shrink();
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final held = status == ModerationStatus.held;
    final accent = color ?? (held ? theme.colorScheme.tertiary : theme.colorScheme.error);
    final label = held ? l10n.moderationHeld : l10n.moderationHidden;
    final hint = held ? l10n.moderationHeldHint : l10n.moderationHiddenHint;
    final icon = held ? Icons.hourglass_top : Icons.visibility_off_outlined;
    if (compact) {
      return Semantics(
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 3),
            Flexible(
              child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: accent)),
            ),
            if (!held && onAppeal != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onAppeal,
                child: Text(
                  l10n.appealAction,
                  style: theme.textTheme.labelSmall?.copyWith(color: accent, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge?.copyWith(color: accent)),
                Text(hint, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (!held && onAppeal != null) TextButton(onPressed: onAppeal, child: Text(l10n.appealAction)),
        ],
      ),
    );
  }
}

class HeldAttachmentLabel extends StatelessWidget {
  const HeldAttachmentLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top, size: 12, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 3),
          Text(
            context.communityL10n.moderationHeld,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}

class CommunityBotBadge extends StatelessWidget {
  const CommunityBotBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = CommunityLabelBadgeDetails(
      kind: CommunityBadgeKind.bot,
      label: context.communityL10n.botLabel,
      icon: Icons.smart_toy_outlined,
      foreground: scheme.onSecondaryContainer,
      background: scheme.secondaryContainer,
    );
    return buildLabelBadge(context, details, _DefaultBotBadge(details: details));
  }
}

class _DefaultBotBadge extends StatelessWidget {
  const _DefaultBotBadge({required this.details});

  final CommunityLabelBadgeDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: details.background, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(details.icon, size: 11, color: details.foreground),
          const SizedBox(width: 2),
          Text(
            details.label,
            style: theme.textTheme.labelSmall?.copyWith(color: details.foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
