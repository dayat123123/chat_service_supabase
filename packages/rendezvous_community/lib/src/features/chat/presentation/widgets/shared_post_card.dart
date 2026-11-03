import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/message_extras.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/attachment_grid.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';

SharedPost sharedPostFromPost(Post post) => SharedPost(
  postId: post.id,
  author: post.author,
  body: post.body.length > 280 ? '${post.body.substring(0, 279)}…' : post.body,
  attachments: post.attachments,
  sentiment: post.sentiment,
  stockCodes: post.stockCodes,
  likeCount: post.likeCount,
  commentCount: post.commentCount,
  createdAt: post.createdAt,
);

class SharedPostCard extends StatefulWidget {
  const SharedPostCard({super.key, required this.postId, this.sharedPost, this.color, this.onOpen});

  final String postId;
  final SharedPost? sharedPost;
  final Color? color;
  final VoidCallback? onOpen;

  @override
  State<SharedPostCard> createState() => _SharedPostCardState();
}

class _SharedPostCardState extends State<SharedPostCard> {
  Future<SharedPost>? _lookup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.sharedPost == null) _lookup ??= _load();
  }

  Future<SharedPost> _load() async {
    try {
      final post = await CommunityScope.of(context).feed.getPost(widget.postId);
      return post == null ? SharedPost(postId: widget.postId, available: false) : sharedPostFromPost(post);
    } catch (_) {
      return SharedPost(postId: widget.postId, available: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final known = widget.sharedPost;
    if (known != null) return _card(context, known);
    return FutureBuilder<SharedPost>(future: _lookup, builder: (context, snapshot) => _card(context, snapshot.data));
  }

  Widget _card(BuildContext context, SharedPost? shared) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final fg = widget.color ?? theme.colorScheme.onSurface;
    final available = shared?.available ?? true;
    final author = shared?.author;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.06),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: available ? widget.onOpen : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: shared == null
              ? const SizedBox(height: 36, child: Center(child: LinearProgressIndicator()))
              : !available
              ? Row(
                  children: [
                    Icon(Icons.hide_source_outlined, size: 18, color: fg.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      l10n.sharedPostUnavailable,
                      style: theme.textTheme.bodySmall?.copyWith(color: fg, fontStyle: FontStyle.italic),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.article_outlined, size: 14, color: fg.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          l10n.sharedPostLabel,
                          style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7)),
                        ),
                        if (author != null) ...[
                          const SizedBox(width: 6),
                          CommunityAvatar(user: author, radius: 9),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((shared.body ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          shared.body!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: fg),
                        ),
                      ),
                    if (shared.attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: AttachmentGrid(attachments: shared.attachments.take(1).toList(), maxHeight: 120),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
