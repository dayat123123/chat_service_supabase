import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/compose/presentation/widgets/community_compose_post.dart';
import 'package:rendezvous_community/src/features/drafts/domain/entities/post_draft.dart';
import 'package:rendezvous_community/src/features/drafts/presentation/cubit/post_drafts_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

Future<void> openCommunityPostDrafts(BuildContext context) {
  final deps = CommunityScope.of(context);
  final features = context.getInheritedWidgetOfExactType<CommunityFeatureScope>()?.dependencies;
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) {
        final page = CommunityScope(
          dependencies: deps,
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text(context.communityL10n.draftsTitle)),
              body: const CommunityPostDrafts(),
            ),
          ),
        );
        return features == null ? page : CommunityFeatureScope(dependencies: features, child: page);
      },
    ),
  );
}

class CommunityPostDrafts extends StatelessWidget {
  const CommunityPostDrafts({super.key});

  @override
  Widget build(BuildContext context) {
    final drafts = context.communityFeatures?.drafts;
    if (drafts == null) return const SizedBox.shrink();
    return BlocProvider(create: (_) => PostDraftsCubit(drafts)..load(), child: const _DraftsView());
  }
}

class _DraftsView extends StatelessWidget {
  const _DraftsView();

  Future<void> _open(BuildContext context, PostDraft draft) async {
    final cubit = context.read<PostDraftsCubit>();
    await showCommunityComposer(context, draft: draft);
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return BlocBuilder<PostDraftsCubit, PostDraftsState>(
      builder: (context, state) {
        final cubit = context.read<PostDraftsCubit>();
        return switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(itemCount: 3),
          LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready when state.drafts.isEmpty => CommunityEmptyView(
            message: l10n.draftsEmpty,
            icon: Icons.drafts_outlined,
          ),
          LoadStatus.ready => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView.separated(
              addAutomaticKeepAlives: false,
              itemCount: state.drafts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final draft = state.drafts[index];
                final preview = draft.body.trim().isEmpty ? l10n.draftNoText : draft.body.trim();
                return ListTile(
                  leading: Icon(draft.synced ? Icons.cloud_done_outlined : Icons.phone_android_outlined),
                  title: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    draft.synced
                        ? l10n.relativeTime(draft.updatedAt)
                        : '${l10n.relativeTime(draft.updatedAt)} · ${l10n.draftSavedLocally}',
                  ),
                  onTap: () => _open(context, draft),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    onPressed: () => cubit.delete(draft),
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              },
            ),
          ),
        };
      },
    );
  }
}
