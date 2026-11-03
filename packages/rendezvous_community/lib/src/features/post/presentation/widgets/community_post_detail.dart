import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/analytics/domain/entities/analytics_event.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_actions.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/post_card.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_consent_flow.dart';
import 'package:rendezvous_community/src/features/post/presentation/cubit/comment_thread_cubit.dart';
import 'package:rendezvous_community/src/features/post/presentation/widgets/comment_tree.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_composer_field.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_disclaimer.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

class CommunityPostDetail extends StatelessWidget {
  const CommunityPostDetail({super.key, required this.postId, this.rootCommentId});

  final String postId;
  final String? rootCommentId;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final features = context.communityFeatures;
    final maxLevels = CommunityTheme.of(context).maxThreadIndentLevels;
    return CommunitySocialGate(
      child: BlocProvider(
        create: (_) => CommentThreadCubit(
          feed: deps.feed,
          comments: deps.comments,
          postId: postId,
          rootCommentId: rootCommentId,
          maxLevels: maxLevels,
          consent: communityConsentGate(context),
          bookmarks: features?.bookmarks,
          edits: features?.edits,
        )..load(),
        child: _PostDetailView(postId: postId, maxLevels: maxLevels),
      ),
    );
  }
}

class _PostDetailView extends StatelessWidget {
  const _PostDetailView({required this.postId, required this.maxLevels});

  final String postId;
  final int maxLevels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocConsumer<CommentThreadCubit, ThreadState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<CommentThreadCubit>();
        switch (state.status) {
          case LoadStatus.initial || LoadStatus.loading:
            return const CommunitySkeleton(itemCount: 4);
          case LoadStatus.failure:
            return CommunityErrorView(error: state.error!, onRetry: cubit.load);
          case LoadStatus.ready:
            final post = state.post;
            if (post == null) return CommunityEmptyView(message: l10n.postNotFound, icon: Icons.search_off);
        }
        final post = state.post!;
        final rows = buildThreadRows(state, maxLevels: maxLevels);
        final header = <Widget>[
          PostCard(
            post: post,
            expanded: true,
            source: 'post',
            onEdit: editPostAction(context, post, cubit.canEdit ? cubit.editPost : null),
            onToggleBookmark: bookmarkPostAction(context, cubit.canBookmark ? cubit.togglePostBookmark : null),
            onShare: sharePostAction(context, post),
            onAppeal: appealPostAction(context, post),
            onLike: cubit.togglePostLike,
            onDelete: () async {
              if (await cubit.deletePost() && context.mounted) {
                showCommunityMessage(context, l10n.postDeleted);
                await Navigator.of(context).maybePop();
              }
            },
          ),
          const CommunityDisclaimer(),
          const Divider(height: 1),
          if (state.root != null) _ThreadContext(postId: postId),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('${l10n.comments} (${post.commentCount})', style: Theme.of(context).textTheme.titleSmall),
          ),
          if (rows.isEmpty) CommunityEmptyView(message: l10n.noComments, icon: Icons.chat_bubble_outline),
        ];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth + 40),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    addAutomaticKeepAlives: false,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: header.length + rows.length,
                    itemBuilder: (context, index) => index < header.length
                        ? header[index]
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ThreadRowView(row: rows[index - header.length], postId: postId),
                          ),
                  ),
                ),
                const Divider(height: 1),
                const _ReplyComposer(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThreadContext extends StatelessWidget {
  const _ThreadContext({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final root = context.select((CommentThreadCubit c) => c.state.root)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.threadContext, style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => CommunityNavigator.openPost(context, postId),
                    child: Text(l10n.postDetail),
                  ),
                ],
              ),
              CommentTile(comment: root, showCollapse: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer();

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final cubit = context.read<CommentThreadCubit>();
    final reply = cubit.state.replyTo != null;
    if (await cubit.send(_controller.text)) {
      _controller.clear();
      if (mounted) {
        context.trackCommunityEvent(CommunityAnalyticsEvent.commentCreate, {
          'post_id': cubit.postId,
          'is_reply': reply,
          'source': 'post',
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocConsumer<CommentThreadCubit, ThreadState>(
      listenWhen: (a, b) => a.replyTo?.id != b.replyTo?.id && b.replyTo != null,
      listener: (_, _) => _focus.requestFocus(),
      buildWhen: (a, b) => a.replyTo != b.replyTo || a.sending != b.sending,
      builder: (context, state) {
        final replyTo = state.replyTo;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyTo != null)
                Row(
                  children: [
                    const Icon(Icons.reply, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.replyingTo(replyTo.author?.name ?? l10n.someone),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.cancel,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.read<CommentThreadCubit>().setReplyTo(null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CommunityComposerField(
                      controller: _controller,
                      focusNode: _focus,
                      hintText: l10n.writeComment,
                      maxLength: 1000,
                      maxLines: 5,
                      enabled: !state.sending,
                      onSubmit: _send,
                      decoration: const InputDecoration(border: OutlineInputBorder(), counterText: '', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: l10n.reply,
                    onPressed: state.sending ? null : _send,
                    icon: state.sending
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
