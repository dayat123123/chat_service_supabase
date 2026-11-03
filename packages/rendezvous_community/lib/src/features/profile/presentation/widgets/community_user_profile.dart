import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/core/media/image_mime.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/features/feed/presentation/widgets/community_feed_list.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:rendezvous_community/src/features/profile/domain/entities/user_profile.dart';
import 'package:rendezvous_community/src/features/profile/presentation/builders/community_profile_builders.dart';
import 'package:rendezvous_community/src/features/profile/presentation/builders/community_profile_details.dart';
import 'package:rendezvous_community/src/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/social_text.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

class CommunityUserProfile extends StatelessWidget {
  const CommunityUserProfile({super.key, this.userId, this.username, this.builders})
    : assert(userId != null || username != null, 'Either userId or username is required');

  final String? userId;
  final String? username;
  final CommunityProfileBuilders? builders;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    return withProfileBuilders(
      context,
      builders,
      BlocProvider(
        create: (_) =>
            ProfileCubit(profiles: deps.profiles, chat: deps.chat, userId: userId, username: username)..load(),
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
          listener: (context, state) => showCommunityError(context, state.actionError!),
          buildWhen: (a, b) =>
              a.status != b.status ||
              a.profile?.user.id != b.profile?.user.id ||
              a.profile?.isBlocked != b.profile?.isBlocked,
          builder: (context, state) {
            final l10n = context.communityL10n;
            switch (state.status) {
              case LoadStatus.initial || LoadStatus.loading:
                return const CommunitySkeleton(itemCount: 3);
              case LoadStatus.failure:
                return CommunityErrorView(error: state.error!, onRetry: context.read<ProfileCubit>().load);
              case LoadStatus.ready:
                final profile = state.profile;
                if (profile == null) {
                  return CommunityEmptyView(message: l10n.profileNotFound, icon: Icons.person_off_outlined);
                }
                if (profile.isBlocked) return const _ProfileHeader();
                return CommunityFeedList(
                  scope: FeedScope.user(profile.user.id),
                  emptyMessage: l10n.userFeedEmpty,
                  header: const _ProfileHeader(),
                );
            }
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final profile = state.profile!;
        final user = profile.user;
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        final parts = CommunityProfileBuilders.of(context);
        final details = CommunityProfileDetails(
          profile: profile,
          busy: state.busy,
          followersLabel: l10n.followers(profile.followerCount),
          followingLabel: l10n.followingCount(profile.followingCount),
          postsLabel: l10n.postsCount(profile.postCount),
          onToggleFollow: profile.isMe || profile.isBlocked ? null : cubit.toggleFollow,
          onMessage: profile.isMe || profile.isBlocked
              ? null
              : () async {
                  final roomId = await cubit.openDirectRoom();
                  if (roomId != null && context.mounted) CommunityNavigator.openRoom(context, roomId);
                },
          onEdit: profile.isMe && !state.busy ? () => _editProfile(context, profile) : null,
          onReport: profile.isMe ? null : () => showReportDialog(context, target: ReportTarget.user, targetId: user.id),
          onBlock: profile.isMe || profile.isBlocked
              ? null
              : () async {
                  if (await blockUserWithConfirm(context, user)) await cubit.load();
                },
          onUnblock: profile.isMe || !profile.isBlocked ? null : cubit.unblock,
        );
        return buildCommunityPart(parts.header, context, details, _defaultHeader(context, details, parts, muted));
      },
    );
  }

  Widget _defaultHeader(
    BuildContext context,
    CommunityProfileDetails details,
    CommunityProfileBuilders parts,
    TextStyle? muted,
  ) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final profile = details.profile;
    final user = profile.user;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAvatar(user: user, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommunityUserName(user: user, showUsername: false, style: theme.textTheme.titleLarge),
                    Text('@${user.username}', style: muted),
                    if (profile.followsMe) Text(l10n.followsYou, style: muted),
                  ],
                ),
              ),
              if (!profile.isMe)
                PopupMenuButton<String>(
                  onSelected: (action) => switch (action) {
                    'report' => details.onReport?.call(),
                    'block' => details.onBlock?.call(),
                    'unblock' => details.onUnblock?.call(),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'report', child: Text(l10n.report)),
                    PopupMenuItem(
                      value: profile.isBlocked ? 'unblock' : 'block',
                      child: Text(profile.isBlocked ? l10n.unblock : l10n.block),
                    ),
                  ],
                ),
            ],
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[const SizedBox(height: 12), SocialText(profile.bio!)],
          const SizedBox(height: 12),
          buildCommunityPart(
            parts.stats,
            context,
            details,
            Wrap(
              spacing: 16,
              children: [
                Text(details.followersLabel, style: muted),
                Text(details.followingLabel, style: muted),
                Text(details.postsLabel, style: muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (profile.isMe)
            OutlinedButton.icon(
              onPressed: details.onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.editProfile),
            )
          else if (!profile.isBlocked)
            Wrap(
              spacing: 8,
              children: [
                buildCommunityPart(
                  parts.followButton,
                  context,
                  details,
                  profile.isFollowing
                      ? FilledButton.tonal(onPressed: details.onToggleFollow, child: Text(l10n.followingLabel))
                      : FilledButton(onPressed: details.onToggleFollow, child: Text(l10n.follow)),
                ),
                OutlinedButton.icon(
                  onPressed: details.onMessage,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(l10n.sendMessage),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, UserProfile profile) async {
    final cubit = context.read<ProfileCubit>();
    final l10n = context.communityL10n;
    final name = TextEditingController(text: profile.user.displayName ?? '');
    final bio = TextEditingController(text: profile.bio ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editProfile),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () async {
                  const group = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
                  final file = await openFile(acceptedTypeGroups: const [group]);
                  if (file == null) return;
                  await cubit.changeAvatar(await file.readAsBytes(), mimeFromName(file.name, file.mimeType));
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.changeAvatar),
              ),
              TextField(
                controller: name,
                maxLength: 60,
                decoration: InputDecoration(labelText: l10n.displayName),
              ),
              TextField(
                controller: bio,
                maxLength: 300,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.bio),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              final ok = await cubit.saveProfile(displayName: name.text.trim(), bio: bio.text.trim());
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    name.dispose();
    bio.dispose();
  }
}
