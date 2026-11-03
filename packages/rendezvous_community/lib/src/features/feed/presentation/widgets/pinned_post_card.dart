import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/pinned_post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_details.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_actions.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_card.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class PinnedPostCard extends StatelessWidget {
  const PinnedPostCard({super.key, required this.pinned, required this.onLike, this.onOpen, this.onToggleBookmark});

  final PinnedPost pinned;
  final VoidCallback onLike;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.communityL10n;
    final announcement = pinned.announcement;
    final accent = announcement ? scheme.primary : scheme.onSurfaceVariant;
    final marker = CommunityPinnedMarkerDetails(
      pinned: pinned,
      label: announcement ? l10n.announcementLabel : l10n.pinnedLabel,
    );
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
          buildCommunityPart(
            CommunityFeedBuilders.of(context).pinnedMarker,
            context,
            marker,
            _DefaultPinnedMarker(details: marker, accent: accent),
          ),
          PostCard(
            post: pinned.post,
            pinned: pinned,
            onLike: onLike,
            onOpen: onOpen,
            onToggleBookmark: bookmarkPostAction(context, onToggleBookmark),
            onShare: sharePostAction(context, pinned.post),
          ),
        ],
      ),
    );
  }
}

class _DefaultPinnedMarker extends StatelessWidget {
  const _DefaultPinnedMarker({required this.details, required this.accent});

  final CommunityPinnedMarkerDetails details;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = details.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Icon(details.announcement ? Icons.campaign : Icons.push_pin, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            details.label,
            style: theme.textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w600),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
