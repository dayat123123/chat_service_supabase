import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_builders.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class SentimentBadge extends StatelessWidget {
  const SentimentBadge({super.key, required this.sentiment});

  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final t = CommunityTheme.of(context);
    final l10n = context.communityL10n;
    final details = switch (sentiment) {
      Sentiment.bullish => CommunityLabelBadgeDetails(
        kind: CommunityBadgeKind.sentimentBullish,
        label: l10n.sentimentBullish,
        icon: Icons.trending_up,
        foreground: t.onBullish,
        background: t.bullish,
      ),
      Sentiment.bearish => CommunityLabelBadgeDetails(
        kind: CommunityBadgeKind.sentimentBearish,
        label: l10n.sentimentBearish,
        icon: Icons.trending_down,
        foreground: t.onBearish,
        background: t.bearish,
      ),
      Sentiment.neutral => CommunityLabelBadgeDetails(
        kind: CommunityBadgeKind.sentimentNeutral,
        label: l10n.sentimentNeutral,
        icon: Icons.trending_flat,
        foreground: t.onNeutral,
        background: t.neutral,
      ),
    };
    return buildLabelBadge(context, details, _DefaultSentimentBadge(details: details));
  }
}

class _DefaultSentimentBadge extends StatelessWidget {
  const _DefaultSentimentBadge({required this.details});

  final CommunityLabelBadgeDetails details;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: details.background, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(details.icon, size: 14, color: details.foreground),
        const SizedBox(width: 4),
        Text(
          details.label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: details.foreground, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
