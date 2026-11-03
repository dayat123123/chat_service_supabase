import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/sentiment_badge.dart';
import 'package:rendezvous_community/src/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/attachment_grid.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:rendezvous_community/src/features/poll/presentation/widgets/community_poll_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.communityL10n;
    final isMine = CommunityScope.of(context).currentUser?.id == post.author.id;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommunityAvatar(user: post.author, onTap: () => CommunityNavigator.openUser(context, post.author)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: CommunityUserName(user: post.author, official: post.authorIsOfficial),
                      ),
                      if (post.isBot) ...[const SizedBox(width: 4), const CommunityBotBadge()],
                      Text(' · ${l10n.relativeTime(post.createdAt)}', style: muted),
                      if (post.editedAt != null) Text(' ${l10n.edited}', style: muted),
                      const Spacer(),
                      if (post.sentiment != null) SentimentBadge(sentiment: post.sentiment!),
                      _PostMenu(
                        isMine: isMine,
                        bookmarked: post.isBookmarked,
                        onEdit: onEdit,
                        onToggleBookmark: onToggleBookmark,
                        onShare: onShare,
                        onDelete: onDelete,
                        onReport: () => showReportDialog(context, target: ReportTarget.post, targetId: post.id),
                        onBlock: () async {
                          if (await blockUserWithConfirm(context, post.author)) onAuthorBlocked?.call();
                        },
                      ),
                    ],
                  ),
                  if (isMine) ModerationNotice(status: post.moderationStatus, onAppeal: onAppeal),
                  SocialText(
                    post.body,
                    validStockCodes: post.stockCodes.toSet(),
                    maxLines: expanded ? null : 10,
                    style: expanded ? theme.textTheme.bodyLarge : null,
                    source: source,
                  ),
                  LinkPreviewCard(text: post.body),
                  if (post.poll != null) CommunityPollView(postId: post.id, poll: post.poll!, canVote: !isMine),
                  if (post.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AttachmentGrid(attachments: post.attachments),
                  ],
                  Row(
                    children: [
                      _ActionButton(
                        icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                        color: post.likedByMe ? theme.colorScheme.error : null,
                        count: post.likeCount,
                        tooltip: post.likedByMe ? l10n.unlike : l10n.like,
                        onPressed: onLike,
                      ),
                      _ActionButton(
                        icon: Icons.mode_comment_outlined,
                        count: post.commentCount,
                        tooltip: l10n.comment,
                        onPressed: onOpen,
                      ),
                      if (onToggleBookmark != null)
                        IconButton(
                          tooltip: post.isBookmarked ? l10n.bookmarkRemove : l10n.bookmarkAdd,
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          color: post.isBookmarked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          onPressed: onToggleBookmark,
                          icon: Icon(post.isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  const _PostMenu({
    required this.isMine,
    required this.bookmarked,
    this.onEdit,
    this.onToggleBookmark,
    this.onShare,
    this.onDelete,
    required this.onReport,
    required this.onBlock,
  });

  final bool isMine;
  final bool bookmarked;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return PopupMenuButton<_PostAction>(
      iconSize: 18,
      padding: EdgeInsets.zero,
      onSelected: (action) async {
        switch (action) {
          case _PostAction.edit:
            onEdit?.call();
          case _PostAction.bookmark:
            onToggleBookmark?.call();
          case _PostAction.share:
            onShare?.call();
          case _PostAction.delete:
            if (await confirmCommunityAction(context, l10n.deletePostConfirm)) onDelete?.call();
          case _PostAction.report:
            onReport();
          case _PostAction.block:
            onBlock();
        }
      },
      itemBuilder: (_) => [
        if (isMine && onEdit != null)
          PopupMenuItem(
            value: _PostAction.edit,
            child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.editAction)),
          ),
        if (onToggleBookmark != null)
          PopupMenuItem(
            value: _PostAction.bookmark,
            child: ListTile(
              leading: Icon(bookmarked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
              title: Text(bookmarked ? l10n.bookmarkRemove : l10n.bookmarkAdd),
            ),
          ),
        if (onShare != null)
          PopupMenuItem(
            value: _PostAction.share,
            child: ListTile(leading: const Icon(Icons.send_outlined), title: Text(l10n.shareToChat)),
          ),
        if (isMine && onDelete != null)
          PopupMenuItem(
            value: _PostAction.delete,
            child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete)),
          ),
        if (!isMine) ...[
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
