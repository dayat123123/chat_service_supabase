import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/feed/domain/entities/post.dart';
import 'package:olt_social/src/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:olt_social/src/features/feed/presentation/widgets/post_card.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/theme/olt_social_theme.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';

class OltFeedList extends StatelessWidget {
  const OltFeedList({super.key, required this.scope, required this.emptyMessage, this.header});

  final FeedScope scope;
  final String emptyMessage;

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

