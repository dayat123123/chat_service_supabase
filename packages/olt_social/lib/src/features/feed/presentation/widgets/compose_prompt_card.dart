import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/compose/presentation/widgets/olt_compose_post.dart';
import 'package:olt_social/src/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/widgets/olt_avatar.dart';

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
