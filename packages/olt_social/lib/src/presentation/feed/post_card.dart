import 'package:flutter/material.dart';

import '../../domain/entities/paged.dart';
import '../../domain/entities/post.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../widgets/common.dart';
import '../widgets/moderation_actions.dart';

/// Kartu post untuk feed dan detail.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onOpen,
    this.onDelete,
    this.onAuthorBlocked,
    this.expanded = false,
  });

  final Post post;
  final VoidCallback onLike;

  /// Membuka detail (null di halaman detail).
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onAuthorBlocked;

  /// Tampilkan isi lengkap tanpa batas baris.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.oltL10n;
    final isMine = OltSocialScope.of(context).currentUser?.id == post.author.id;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OltAvatar(user: post.author, onTap: () => OltNavigator.openUser(context, post.author)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: OltUserName(user: post.author)),
                      Text(' · ${l10n.relativeTime(post.createdAt)}', style: muted),
                      if (post.editedAt != null) Text(' ${l10n.edited}', style: muted),
                      const Spacer(),
                      if (post.sentiment != null) SentimentBadge(sentiment: post.sentiment!),
                      _PostMenu(
                        isMine: isMine,
                        onDelete: onDelete,
                        onReport: () => showReportDialog(context, target: ReportTarget.post, targetId: post.id),
                        onBlock: () async {
                          if (await blockUserWithConfirm(context, post.author)) onAuthorBlocked?.call();
                        },
                      ),
                    ],
                  ),
                  SocialText(
                    post.body,
                    validStockCodes: post.stockCodes.toSet(),
                    maxLines: expanded ? null : 10,
                    style: expanded ? theme.textTheme.bodyLarge : null,
                  ),
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

enum _PostAction { delete, report, block }

class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.isMine, this.onDelete, required this.onReport, required this.onBlock});

  final bool isMine;
  final VoidCallback? onDelete;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return PopupMenuButton<_PostAction>(
      iconSize: 18,
      padding: EdgeInsets.zero,
      onSelected: (action) async {
        switch (action) {
          case _PostAction.delete:
            if (await confirmOlt(context, l10n.deletePostConfirm)) onDelete?.call();
          case _PostAction.report:
            onReport();
          case _PostAction.block:
            onBlock();
        }
      },
      itemBuilder: (_) => [
        if (isMine && onDelete != null)
          PopupMenuItem(value: _PostAction.delete, child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete))),
        if (!isMine) ...[
          PopupMenuItem(value: _PostAction.report, child: ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l10n.report))),
          PopupMenuItem(value: _PostAction.block, child: ListTile(leading: const Icon(Icons.block), title: Text(l10n.block))),
        ],
      ],
    );
  }
}
