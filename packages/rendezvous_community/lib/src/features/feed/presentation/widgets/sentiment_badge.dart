import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class SentimentBadge extends StatelessWidget {
  const SentimentBadge({super.key, required this.sentiment});

  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final t = CommunityTheme.of(context);
    final l10n = context.communityL10n;
    final (bg, fg, label, icon) = switch (sentiment) {
      Sentiment.bullish => (t.bullish, t.onBullish, l10n.sentimentBullish, Icons.trending_up),
      Sentiment.bearish => (t.bearish, t.onBearish, l10n.sentimentBearish, Icons.trending_down),
      Sentiment.neutral => (t.neutral, t.onNeutral, l10n.sentimentNeutral, Icons.trending_flat),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
