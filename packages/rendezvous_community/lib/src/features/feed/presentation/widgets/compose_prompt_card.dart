import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/compose/presentation/widgets/community_compose_post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';

class ComposePromptCard extends StatelessWidget {
  const ComposePromptCard({super.key, this.initialStock});

  final String? initialStock;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final post = await showCommunityComposer(context, initialStock: initialStock);
            if (post != null && context.mounted) context.read<FeedCubit>().insertOwnPost(post);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CommunityAvatar(user: deps.currentUser, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.communityL10n.composePrompt,
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
