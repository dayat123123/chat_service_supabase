import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/appeals/domain/entities/appeal.dart';
import 'package:rendezvous_community/src/features/appeals/presentation/widgets/community_appeals.dart';
import 'package:rendezvous_community/src/features/edit/presentation/widgets/edit_content_dialog.dart';
import 'package:rendezvous_community/src/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:rendezvous_community/src/features/post/domain/entities/thread_comment.dart';
import 'package:rendezvous_community/src/features/post/presentation/cubit/comment_thread_cubit.dart';
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
    final theme = Theme.of(context);
    final cubit = context.read<CommentThreadCubit>();
    final isMine = c.author != null && c.author!.id == CommunityScope.of(context).currentUser?.id;
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
                if (c.author != null) ...[
                  CommunityAvatar(
                    user: c.author,
                    radius: 12,
                    onTap: () => CommunityNavigator.openUser(context, c.author!),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: CommunityUserName(user: c.author!, showUsername: false)),
                ],
                Text(' · ${l10n.relativeTime(c.createdAt)}', style: muted),
                if (c.editedAt != null && !c.isDeleted) Text(' ${l10n.edited}', style: muted),
                const Spacer(),
                if (widget.showCollapse && c.replyCount > 0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: widget.collapsed ? l10n.expand : l10n.collapse,
                    onPressed: () => cubit.toggleCollapse(c.id),
                    icon: Icon(widget.collapsed ? Icons.unfold_more : Icons.unfold_less),
                  ),
              ],
            ),
            if (isMine && !c.isDeleted)
              ModerationNotice(
                status: c.moderationStatus,
                compact: true,
                onAppeal: c.isHidden && context.communityFeatures != null
                    ? () => showCommunityAppealDialog(context, targetType: AppealTargetType.comment, targetId: c.id)
                    : null,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: c.isDeleted
                  ? Text(l10n.commentDeleted, style: muted?.copyWith(fontStyle: FontStyle.italic))
                  : SocialText(c.body ?? '', source: 'comment'),
            ),
            if (!c.isDeleted && (c.body ?? '').isNotEmpty) LinkPreviewCard(text: c.body!),
            if (widget.collapsed)
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
                    onPressed: () => cubit.toggleLike(c),
                    icon: Icon(c.likedByMe ? Icons.favorite : Icons.favorite_border, size: 16),
                    label: Text(c.likeCount > 0 ? '${c.likeCount}' : l10n.like),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => cubit.setReplyTo(c),
                    icon: const Icon(Icons.reply, size: 16),
                    label: Text(l10n.reply),
                  ),
                  PopupMenuButton<String>(
                    iconSize: 16,
                    tooltip: '',
                    onSelected: (action) async {
                      switch (action) {
                        case 'edit':
                          await _edit(c, cubit);
                        case 'delete':
                          if (await confirmCommunityAction(context, l10n.deleteCommentConfirm)) {
                            await cubit.deleteComment(c);
                          }
                        case 'report':
                          await showReportDialog(context, target: ReportTarget.comment, targetId: c.id);
                        case 'block':
                          if (await blockUserWithConfirm(context, c.author!)) await cubit.load();
                      }
                    },
                    itemBuilder: (_) => [
                      if (_canEdit(c, isMine, cubit)) PopupMenuItem(value: 'edit', child: Text(l10n.editAction)),
                      if (isMine) PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      if (!isMine) ...[
                        PopupMenuItem(value: 'report', child: Text(l10n.report)),
                        if (c.author != null) PopupMenuItem(value: 'block', child: Text(l10n.block)),
                      ],
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
