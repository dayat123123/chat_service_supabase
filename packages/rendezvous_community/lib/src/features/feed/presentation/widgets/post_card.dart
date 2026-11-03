import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/pinned_post.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_details.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/sentiment_badge.dart';
import 'package:rendezvous_community/src/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/attachment_grid.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:rendezvous_community/src/features/poll/presentation/widgets/community_poll_view.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/moderation_notice.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/social_text.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onOpen,
    this.onDelete,
    this.onAuthorBlocked,
    this.expanded = false,
    this.onEdit,
    this.onToggleBookmark,
    this.onShare,
    this.onAppeal,
    this.source = 'feed',
    this.pinned,
  });

  final Post post;
  final VoidCallback onLike;

  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onAuthorBlocked;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onAppeal;

  final bool expanded;
  final String source;
  final PinnedPost? pinned;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final isMine = CommunityScope.of(context).currentUser?.id == post.author.id;
    final remove = onDelete;
    final details = CommunityPostDetails(
      post: post,
      isMine: isMine,
      timeLabel: l10n.relativeTime(post.createdAt),
      expanded: expanded,
      source: source,
      pinned: pinned,
      onLike: onLike,
      onOpen: onOpen,
      onComment: onOpen,
      onOpenAuthor: () => CommunityNavigator.openUser(context, post.author),
      onOpenStock: (code) => CommunityNavigator.openStock(context, code, source: source),
      onOpenHashtag: (tag) => CommunityNavigator.openHashtag(context, tag),
      onShare: onShare,
      onToggleBookmark: onToggleBookmark,
      onEdit: isMine ? onEdit : null,
      onDelete: isMine && remove != null
          ? () async {
              if (await confirmCommunityAction(context, l10n.deletePostConfirm)) remove();
            }
          : null,
      onReport: isMine ? null : () => showReportDialog(context, target: ReportTarget.post, targetId: post.id),
      onBlock: isMine
          ? null
          : () async {
              if (await blockUserWithConfirm(context, post.author)) onAuthorBlocked?.call();
            },
      onAppeal: onAppeal,
    );
    final builders = CommunityFeedBuilders.of(context);
    return buildCommunityPart(
      builders.postCard,
      context,
      details,
      _DefaultPostCard(details: details, builders: builders),
    );
  }
}

class _DefaultPostCard extends StatelessWidget {
  const _DefaultPostCard({required this.details, required this.builders});

  final CommunityPostDetails details;
  final CommunityFeedBuilders builders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = details;
    final post = d.post;
    final stockTags = builders.stockTags;
    return InkWell(
      onTap: d.onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildCommunityPart(
              builders.postAvatar,
              context,
              d,
              CommunityAvatar(user: post.author, onTap: d.onOpenAuthor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildCommunityPart(builders.postHeader, context, d, PostCardHeader(details: d)),
                  if (d.isMine) ModerationNotice(status: post.moderationStatus, onAppeal: d.onAppeal),
                  buildCommunityPart(
                    builders.postBody,
                    context,
                    d,
                    SocialText(
                      post.body,
                      validStockCodes: post.stockCodes.toSet(),
                      maxLines: d.expanded ? null : 10,
                      style: d.expanded ? theme.textTheme.bodyLarge : null,
                      source: d.source,
                    ),
                  ),
                  if (stockTags != null) stockTags(context, d, const SizedBox.shrink()),
                  LinkPreviewCard(text: post.body),
                  if (post.poll != null) CommunityPollView(postId: post.id, poll: post.poll!, canVote: d.canVote),
                  if (post.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    buildCommunityPart(builders.attachments, context, d, AttachmentGrid(attachments: post.attachments)),
                  ],
                  buildCommunityPart(builders.actionBar, context, d, PostActionBar(details: d)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostCardHeader extends StatelessWidget {
  const PostCardHeader({super.key, required this.details});

  final CommunityPostDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.communityL10n;
    final d = details;
    final post = d.post;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Row(
      children: [
        Flexible(
          child: CommunityUserName(user: post.author, official: post.authorIsOfficial),
        ),
        if (post.isBot) ...[const SizedBox(width: 4), const CommunityBotBadge()],
        Text(' · ${d.timeLabel}', style: muted),
        if (d.edited) Text(' ${l10n.edited}', style: muted),
        const Spacer(),
        if (post.sentiment != null) SentimentBadge(sentiment: post.sentiment!),
        _PostMenu(details: d),
      ],
    );
  }
}

class PostActionBar extends StatelessWidget {
  const PostActionBar({super.key, required this.details});

  final CommunityPostDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.communityL10n;
    final post = details.post;
    final bookmark = details.onToggleBookmark;
    return Row(
      children: [
        _ActionButton(
          icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
          color: post.likedByMe ? theme.colorScheme.error : null,
          count: post.likeCount,
          tooltip: post.likedByMe ? l10n.unlike : l10n.like,
          onPressed: details.onLike,
        ),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          count: post.commentCount,
          tooltip: l10n.comment,
          onPressed: details.onComment,
        ),
        if (bookmark != null)
          IconButton(
            tooltip: post.isBookmarked ? l10n.bookmarkRemove : l10n.bookmarkAdd,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: post.isBookmarked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            onPressed: bookmark,
            icon: Icon(post.isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.count, required this.tooltip, this.onPressed, this.color});

  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color ?? theme.colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: 18),
        label: Text(count > 0 ? '$count' : ''),
      ),
    );
  }
}

enum _PostAction { edit, bookmark, share, delete, report, block }

class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.details});

  final CommunityPostDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final d = details;
    final bookmarked = d.post.isBookmarked;
    return PopupMenuButton<_PostAction>(
      iconSize: 18,
      padding: EdgeInsets.zero,
      onSelected: (action) => switch (action) {
        _PostAction.edit => d.onEdit?.call(),
        _PostAction.bookmark => d.onToggleBookmark?.call(),
        _PostAction.share => d.onShare?.call(),
        _PostAction.delete => d.onDelete?.call(),
        _PostAction.report => d.onReport?.call(),
        _PostAction.block => d.onBlock?.call(),
      },
      itemBuilder: (_) => [
        if (d.onEdit != null)
          PopupMenuItem(
            value: _PostAction.edit,
            child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.editAction)),
          ),
        if (d.onToggleBookmark != null)
          PopupMenuItem(
            value: _PostAction.bookmark,
            child: ListTile(
              leading: Icon(bookmarked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
              title: Text(bookmarked ? l10n.bookmarkRemove : l10n.bookmarkAdd),
            ),
          ),
        if (d.onShare != null)
          PopupMenuItem(
            value: _PostAction.share,
            child: ListTile(leading: const Icon(Icons.send_outlined), title: Text(l10n.shareToChat)),
          ),
        if (d.onDelete != null)
          PopupMenuItem(
            value: _PostAction.delete,
            child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete)),
          ),
        if (!d.isMine) ...[
          PopupMenuItem(
            value: _PostAction.report,
            child: ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l10n.report)),
          ),
          PopupMenuItem(
            value: _PostAction.block,
            child: ListTile(leading: const Icon(Icons.block), title: Text(l10n.block)),
          ),
        ],
      ],
    );
  }
}
