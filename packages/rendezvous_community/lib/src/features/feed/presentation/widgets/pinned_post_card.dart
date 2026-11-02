import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/pinned_post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_card.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class PinnedPostCard extends StatelessWidget {
  const PinnedPostCard({super.key, required this.pinned, required this.onLike, this.onOpen});

  final PinnedPost pinned;
  final VoidCallback onLike;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.communityL10n;
    final announcement = pinned.announcement;
    final accent = announcement ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: announcement ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: accent, width: 3),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Icon(announcement ? Icons.campaign : Icons.push_pin, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  announcement ? l10n.announcementLabel : l10n.pinnedLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w600),
                ),
                if (pinned.title != null && pinned.title!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      pinned.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PostCard(post: pinned.post, onLike: onLike, onOpen: onOpen),
        ],
      ),
    );
  }
}
