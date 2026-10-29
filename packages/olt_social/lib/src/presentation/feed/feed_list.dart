import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/post.dart';
import '../compose/olt_compose_post.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../theme/olt_social_theme.dart';
import '../widgets/common.dart';
import 'feed_cubit.dart';
import 'post_card.dart';

/// Daftar post untuk satu [FeedScope]: skeleton, error, kosong, infinite scroll,
/// pull-to-refresh, dan banner post baru.
class OltFeedList extends StatelessWidget {
  const OltFeedList({super.key, required this.scope, required this.emptyMessage, this.header});

  final FeedScope scope;
  final String emptyMessage;

  /// Widget di atas daftar (ikut ter-scroll).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => FeedCubit(feed: deps.feed, scope: scope, currentUserId: () => deps.currentUser?.id)..load(),
      child: _FeedListView(emptyMessage: emptyMessage, header: header),
    );
  }
}

class _FeedListView extends StatefulWidget {
  const _FeedListView({required this.emptyMessage, this.header});

  final String emptyMessage;
  final Widget? header;

  @override
  State<_FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends State<_FeedListView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) context.read<FeedCubit>().loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showNewPosts() async {
    await context.read<FeedCubit>().refresh();
    if (_scroll.hasClients) {
      await _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return BlocConsumer<FeedCubit, FeedState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showOltError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<FeedCubit>();
        final Widget body = switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const OltSkeleton(),
          LoadStatus.failure => OltErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready => RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.posts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      ?widget.header,
                      if (state.posts.isEmpty) OltEmptyView(message: widget.emptyMessage),
                    ],
                  );
                }
                if (index == state.posts.length + 1) {
                  return state.loadingMore
                      ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      : const SizedBox(height: 32);
                }
                final post = state.posts[index - 1];
                return Column(
                  children: [
                    PostCard(
                      post: post,
                      onLike: () => cubit.toggleLike(post),
                      onOpen: () => OltNavigator.openPost(context, post.id),
                      onDelete: () => cubit.delete(post),
                      onAuthorBlocked: () => cubit.hideAuthor(post.author.id),
                    ),
                    const Divider(height: 1),
                  ],
                );
              },
            ),
          ),
        };

        return Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: OltBreakpoints.contentMaxWidth),
                child: body,
              ),
            ),
            if (state.newPosts > 0)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _showNewPosts,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: Text(l10n.newPosts(state.newPosts)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Kartu ajakan menulis post di atas feed.
class ComposePromptCard extends StatelessWidget {
  const ComposePromptCard({super.key, this.initialStock});

  final String? initialStock;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final post = await showOltComposer(context, initialStock: initialStock);
            if (post != null && context.mounted) context.read<FeedCubit>().insertOwnPost(post);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                OltAvatar(user: deps.currentUser, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.oltL10n.composePrompt,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
