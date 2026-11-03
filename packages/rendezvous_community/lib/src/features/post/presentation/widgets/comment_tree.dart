import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/edit/presentation/widgets/edit_content_dialog.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_details.dart';
import 'package:rendezvous_community/src/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';
import 'package:rendezvous_community/src/features/post/presentation/cubit/comment_thread_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/moderation_notice.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/social_text.dart';

class ThreadLinesPainter extends CustomPainter {
  const ThreadLinesPainter({required this.level, required this.indent, required this.color, this.inset = 8});

  final int level;
  final double indent;
  final double inset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var i = 0; i < level; i++) {
      final x = inset + i * indent + indent / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(ThreadLinesPainter old) =>
      old.level != level || old.indent != indent || old.color != color || old.inset != inset;
}

class _Indented extends StatelessWidget {
  const _Indented({required this.level, required this.child});

  final int level;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CommunityTheme.of(context);
    return CustomPaint(
      painter: ThreadLinesPainter(level: level, indent: t.threadIndent, color: t.threadLine),
      child: Padding(
        padding: EdgeInsets.only(left: 8 + level * t.threadIndent),
        child: child,
      ),
    );
  }
}

class ThreadRowView extends StatelessWidget {
  const ThreadRowView({super.key, required this.row, required this.postId});

  final ThreadRow row;
  final String postId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final cubit = context.read<CommentThreadCubit>();
    return switch (row) {
      CommentRow(:final comment, :final collapsed) => _Indented(
        level: row.level,
        child: CommentTile(comment: comment, collapsed: collapsed),
      ),
      MoreRepliesRow(:final parentId, :final remaining, :final loading) => _Indented(
        level: row.level,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: loading ? null : () => cubit.loadMoreReplies(parentId),
            icon: loading
                ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.subdirectory_arrow_right, size: 18),
            label: Text(l10n.viewMoreReplies(remaining)),
          ),
        ),
      ),
      ContinueThreadRow(:final comment) => _Indented(
        level: row.level,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => CommunityNavigator.openPost(context, postId, rootCommentId: comment.id),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: Text('${l10n.continueThread} →'),
          ),
        ),
      ),
      MoreTopLevelRow(:final loading) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: OutlinedButton(
          onPressed: loading ? null : cubit.loadMoreTop,
          child: loading
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.loadMoreComments),
        ),
      ),
    };
  }
}

class CommentTile extends StatefulWidget {
  const CommentTile({super.key, required this.comment, this.collapsed = false, this.showCollapse = true});

  final ThreadComment comment;
  final bool collapsed;
  final bool showCollapse;

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _hovered = false;

  bool _canEdit(ThreadComment c, bool isMine, CommentThreadCubit cubit) =>
      isMine && !c.isDeleted && cubit.canEdit && context.communityConfig.canEdit(c.createdAt);

  Future<void> _edit(ThreadComment c, CommentThreadCubit cubit) async {
    final l10n = context.communityL10n;
    final body = await showEditContentDialog(
      context,
      title: l10n.editCommentTitle,
      initial: c.body ?? '',
      maxLength: 1000,
    );
    if (body == null || !mounted) return;
    if (await cubit.editComment(c, body) && mounted) showCommunityMessage(context, l10n.editSaved);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final l10n = context.communityL10n;
    final cubit = context.read<CommentThreadCubit>();
    final author = c.author;
    final isMine = author != null && author.id == CommunityScope.of(context).currentUser?.id;
    final details = CommunityCommentDetails(
      comment: c,
      isMine: isMine,
      collapsed: widget.collapsed,
      timeLabel: l10n.relativeTime(c.createdAt),
      onLike: c.isDeleted ? null : () => cubit.toggleLike(c),
      onReply: c.isDeleted ? null : () => cubit.setReplyTo(c),
      onToggleCollapse: widget.showCollapse && c.replyCount > 0 ? () => cubit.toggleCollapse(c.id) : null,
      onOpenAuthor: author == null ? null : () => CommunityNavigator.openUser(context, author),
      onEdit: _canEdit(c, isMine, cubit) ? () => _edit(c, cubit) : null,
      onDelete: isMine && !c.isDeleted
          ? () async {
              if (await confirmCommunityAction(context, l10n.deleteCommentConfirm)) await cubit.deleteComment(c);
            }
          : null,
      onReport: isMine || c.isDeleted
          ? null
          : () => showReportDialog(context, target: ReportTarget.comment, targetId: c.id),
      onBlock: isMine || c.isDeleted || author == null
          ? null
          : () async {
              if (await blockUserWithConfirm(context, author)) await cubit.load();
            },
      onAppeal: isMine && !c.isDeleted && c.isHidden && context.communityFeatures != null
          ? () => showCommunityAppealDialog(context, targetType: AppealTargetType.comment, targetId: c.id)
          : null,
    );
    return buildCommunityPart(CommunityFeedBuilders.of(context).comment, context, details, _tile(context, details));
  }

  Widget _tile(BuildContext context, CommunityCommentDetails d) {
    final c = d.comment;
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final author = c.author;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? theme.colorScheme.surfaceContainerLow : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (author != null) ...[
                  CommunityAvatar(user: author, radius: 12, onTap: d.onOpenAuthor),
                  const SizedBox(width: 8),
                  Flexible(child: CommunityUserName(user: author, showUsername: false)),
                ],
                Text(' · ${d.timeLabel}', style: muted),
                if (d.edited) Text(' ${l10n.edited}', style: muted),
                const Spacer(),
                if (d.onToggleCollapse != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: d.collapsed ? l10n.expand : l10n.collapse,
                    onPressed: d.onToggleCollapse,
                    icon: Icon(d.collapsed ? Icons.unfold_more : Icons.unfold_less),
                  ),
              ],
            ),
            if (d.isMine && !c.isDeleted)
              ModerationNotice(status: c.moderationStatus, compact: true, onAppeal: d.onAppeal),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: c.isDeleted
                  ? Text(l10n.commentDeleted, style: muted?.copyWith(fontStyle: FontStyle.italic))
                  : SocialText(c.body ?? '', source: 'comment'),
            ),
            if (!c.isDeleted && (c.body ?? '').isNotEmpty) LinkPreviewCard(text: c.body!),
            if (d.collapsed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.hiddenReplies(c.replyCount), style: muted),
              ),
            if (!c.isDeleted)
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: c.likedByMe ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: d.onLike,
                    icon: Icon(c.likedByMe ? Icons.favorite : Icons.favorite_border, size: 16),
                    label: Text(c.likeCount > 0 ? '${c.likeCount}' : l10n.like),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: d.onReply,
                    icon: const Icon(Icons.reply, size: 16),
                    label: Text(l10n.reply),
                  ),
                  PopupMenuButton<String>(
                    iconSize: 16,
                    tooltip: '',
                    onSelected: (action) => switch (action) {
                      'edit' => d.onEdit?.call(),
                      'delete' => d.onDelete?.call(),
                      'report' => d.onReport?.call(),
                      'block' => d.onBlock?.call(),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      if (d.onEdit != null) PopupMenuItem(value: 'edit', child: Text(l10n.editAction)),
                      if (d.onDelete != null) PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      if (d.onReport != null) PopupMenuItem(value: 'report', child: Text(l10n.report)),
                      if (d.onBlock != null) PopupMenuItem(value: 'block', child: Text(l10n.block)),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
