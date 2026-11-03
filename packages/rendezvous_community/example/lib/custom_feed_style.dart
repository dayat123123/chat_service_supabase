import 'package:flutter/material.dart';
import 'package:rendezvous_community/rendezvous_community.dart';

const customBadgeBuilders = CommunityBadgeBuilders(label: _pillBadge, count: _countBadge);

const customFeedBuilders = CommunityFeedBuilders(postCard: _postCard);

Widget _pillBadge(BuildContext context, CommunityLabelBadgeDetails d, Widget fallback) {
  final color = d.background ?? d.border ?? d.foreground;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: color, width: 1.5)),
      color: color.withValues(alpha: 0.12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(d.icon, size: 11, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 4),
        Text(
          d.label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

Widget _countBadge(BuildContext context, CommunityCountBadgeDetails d, Widget fallback) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: ShapeDecoration(shape: const StadiumBorder(), color: d.muted ? scheme.outlineVariant : scheme.tertiary),
    child: Text(
      d.label,
      style: TextStyle(color: scheme.onTertiary, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

Widget _postCard(BuildContext context, CommunityPostDetails d, Widget fallback) {
  if (d.pinned != null || d.expanded) return fallback;
  final post = d.post;
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return Card(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: d.onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CommunityAvatar(user: post.author, radius: 16, onTap: d.onOpenAuthor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.name, style: theme.textTheme.titleSmall),
                      Text(
                        '@${post.author.username} · ${d.timeLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (post.isBot) const CommunityBotBadge(),
                if (post.sentiment != null) ...[const SizedBox(width: 6), SentimentBadge(sentiment: post.sentiment!)],
                PopupMenuButton<VoidCallback>(
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    if (d.onShare != null) PopupMenuItem(value: d.onShare!, child: const Text('Bagikan ke chat')),
                    if (d.onEdit != null) PopupMenuItem(value: d.onEdit!, child: const Text('Edit')),
                    if (d.onDelete != null) PopupMenuItem(value: d.onDelete!, child: const Text('Hapus')),
                    if (d.onReport != null) PopupMenuItem(value: d.onReport!, child: const Text('Laporkan')),
                    if (d.onBlock != null) PopupMenuItem(value: d.onBlock!, child: const Text('Blokir')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SocialText(post.body, validStockCodes: post.stockCodes.toSet(), maxLines: 6, source: d.source),
            LinkPreviewCard(text: post.body),
            if (post.poll != null) CommunityPollView(postId: post.id, poll: post.poll!, canVote: d.canVote),
            if (post.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              AttachmentGrid(attachments: post.attachments, maxHeight: 220),
            ],
            if (post.stockCodes.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (final code in post.stockCodes)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('\$$code'),
                      onPressed: () => d.onOpenStock(code),
                    ),
                ],
              ),
            Row(
              children: [
                IconButton(
                  onPressed: d.onLike,
                  icon: Icon(post.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
                  color: post.likedByMe ? scheme.primary : null,
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 12),
                IconButton(onPressed: d.onComment, icon: const Icon(Icons.forum_outlined, size: 18)),
                Text('${post.commentCount}'),
                const Spacer(),
                if (d.onToggleBookmark != null)
                  IconButton(
                    onPressed: d.onToggleBookmark,
                    icon: Icon(post.isBookmarked ? Icons.bookmark : Icons.bookmark_outline, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
