import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/feed/presentation/widgets/post_card.dart';
import 'package:olt_social/src/features/post/presentation/cubit/comment_thread_cubit.dart';
import 'package:olt_social/src/features/post/presentation/widgets/comment_tree.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_composer_field.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_disclaimer.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltPostDetail extends StatelessWidget {
  const OltPostDetail({super.key, required this.postId, this.rootCommentId});

  final String postId;
  final String? rootCommentId;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    final maxLevels = OltSocialTheme.of(context).maxThreadIndentLevels;
    return BlocProvider(
      create: (_) => CommentThreadCubit(
        feed: deps.feed,
        comments: deps.comments,
        postId: postId,
        rootCommentId: rootCommentId,
        maxLevels: maxLevels,
      )..load(),
      child: _PostDetailView(postId: postId, maxLevels: maxLevels),
    );
  }
}

class _PostDetailView extends StatelessWidget {
  const _PostDetailView({required this.postId, required this.maxLevels});

  final String postId;
  final int maxLevels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return BlocConsumer<CommentThreadCubit, ThreadState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showOltError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<CommentThreadCubit>();
        switch (state.status) {
          case LoadStatus.initial || LoadStatus.loading:
            return const OltSkeleton(itemCount: 4);
          case LoadStatus.failure:
            return OltErrorView(error: state.error!, onRetry: cubit.load);
          case LoadStatus.ready:
            final post = state.post;
            if (post == null) return OltEmptyView(message: l10n.postNotFound, icon: Icons.search_off);
        }
        final post = state.post!;
        final rows = buildThreadRows(state, maxLevels: maxLevels);
        final header = <Widget>[
          PostCard(
            post: post,
            expanded: true,
            onLike: cubit.togglePostLike,
            onDelete: () async {
              if (await cubit.deletePost() && context.mounted) {
                showOltMessage(context, l10n.postDeleted);
                await Navigator.of(context).maybePop();
              }
            },
          ),
          const OltDisclaimer(),
          const Divider(height: 1),
          if (state.root != null) _ThreadContext(postId: postId),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${l10n.comments} (${post.commentCount})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (rows.isEmpty) OltEmptyView(message: l10n.noComments, icon: Icons.chat_bubble_outline),
        ];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OltBreakpoints.contentMaxWidth + 40),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
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
    final l10n = context.oltL10n;
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
                    onPressed: () => OltNavigator.openPost(context, postId),
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
    if (await context.read<CommentThreadCubit>().send(_controller.text)) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
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
                    child: OltComposerField(
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
