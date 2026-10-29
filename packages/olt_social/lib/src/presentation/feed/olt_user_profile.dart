import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/paged.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';
import '../compose/olt_compose_post.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import '../widgets/common.dart';
import '../widgets/moderation_actions.dart';
import 'feed_cubit.dart';
import 'feed_list.dart';

part 'olt_user_profile.freezed.dart';

@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(LoadStatus.initial) LoadStatus status,
    UserProfile? profile,
    @Default(false) bool busy,
    Object? error,
    Object? actionError,
    @Default(0) int actionErrorId,
  }) = _ProfileState;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this._profiles, required this._chat, this.userId, this.username})
    : super(const ProfileState());

  final ProfileRepository _profiles;
  final ChatRepository _chat;
  final String? userId;
  final String? username;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final profile = await _profiles.getProfile(userId: userId, username: userId == null ? username : null);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, profile: profile));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e));
    }
  }

  /// Follow/unfollow optimistic.
  Future<void> toggleFollow() async {
    final before = state.profile;
    if (before == null) return;
    final follow = !before.isFollowing;
    emit(state.copyWith(
      profile: before.copyWith(isFollowing: follow, followerCount: before.followerCount + (follow ? 1 : -1)),
    ));
    try {
      follow ? await _profiles.follow(before.user.id) : await _profiles.unfollow(before.user.id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(profile: before));
      _fail(e);
    }
  }

  Future<void> unblock() async {
    final p = state.profile;
    if (p == null) return;
    try {
      await _profiles.unblock(p.user.id);
      await load();
    } catch (e) {
      _fail(e);
    }
  }

  Future<String?> openDirectRoom() async {
    final p = state.profile;
    if (p == null) return null;
    try {
      return await _chat.getOrCreateDirectRoom(p.user.id);
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> saveProfile({required String displayName, required String bio}) async {
    emit(state.copyWith(busy: true));
    try {
      await _profiles.updateMyProfile(displayName: displayName, bio: bio);
      await load();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    } finally {
      if (!isClosed) emit(state.copyWith(busy: false));
    }
  }

  Future<void> changeAvatar(List<int> bytes, String mimeType) async {
    emit(state.copyWith(busy: true));
    try {
      await _profiles.uploadAvatar(Uint8List.fromList(bytes), mimeType: mimeType);
      await load();
    } catch (e) {
      _fail(e);
    } finally {
      if (!isClosed) emit(state.copyWith(busy: false));
    }
  }

  void _fail(Object e) {
    if (!isClosed) emit(state.copyWith(actionError: e, actionErrorId: state.actionErrorId + 1));
  }
}

/// Profil user + daftar post-nya. Tombol follow, kirim pesan, blokir, lapor.
class OltUserProfile extends StatelessWidget {
  const OltUserProfile({super.key, this.userId, this.username})
    : assert(userId != null || username != null, 'userId atau username wajib diisi');

  final String? userId;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final deps = OltSocialScope.of(context);
    return BlocProvider(
      create: (_) => ProfileCubit(profiles: deps.profiles, chat: deps.chat, userId: userId, username: username)..load(),
      child: BlocConsumer<ProfileCubit, ProfileState>(
        listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
        listener: (context, state) => showOltError(context, state.actionError!),
        buildWhen: (a, b) => a.status != b.status || a.profile?.user.id != b.profile?.user.id || a.profile?.isBlocked != b.profile?.isBlocked,
        builder: (context, state) {
          final l10n = context.oltL10n;
          switch (state.status) {
            case LoadStatus.initial || LoadStatus.loading:
              return const OltSkeleton(itemCount: 3);
            case LoadStatus.failure:
              return OltErrorView(error: state.error!, onRetry: context.read<ProfileCubit>().load);
            case LoadStatus.ready:
              final profile = state.profile;
              if (profile == null) return OltEmptyView(message: l10n.profileNotFound, icon: Icons.person_off_outlined);
              if (profile.isBlocked) return const _ProfileHeader();
              return OltFeedList(
                scope: FeedScope.user(profile.user.id),
                emptyMessage: l10n.userFeedEmpty,
                header: const _ProfileHeader(),
              );
          }
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final profile = state.profile!;
        final user = profile.user;
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OltAvatar(user: user, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OltUserName(user: user, showUsername: false, style: theme.textTheme.titleLarge),
                        Text('@${user.username}', style: muted),
                        if (profile.followsMe) Text(l10n.followsYou, style: muted),
                      ],
                    ),
                  ),
                  if (!profile.isMe)
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'report') {
                          await showReportDialog(context, target: ReportTarget.user, targetId: user.id);
                        } else if (action == 'block') {
                          if (await blockUserWithConfirm(context, user)) await cubit.load();
                        } else if (action == 'unblock') {
                          await cubit.unblock();
                        }
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
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SocialText(profile.bio!),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                children: [
                  Text(l10n.followers(profile.followerCount), style: muted),
                  Text(l10n.followingCount(profile.followingCount), style: muted),
                  Text(l10n.postsCount(profile.postCount), style: muted),
                ],
              ),
              const SizedBox(height: 12),
              if (profile.isMe)
                OutlinedButton.icon(
                  onPressed: state.busy ? null : () => _editProfile(context, profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.editProfile),
                )
              else if (!profile.isBlocked)
                Wrap(
                  spacing: 8,
                  children: [
                    profile.isFollowing
                        ? FilledButton.tonal(onPressed: cubit.toggleFollow, child: Text(l10n.followingLabel))
                        : FilledButton(onPressed: cubit.toggleFollow, child: Text(l10n.follow)),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final roomId = await cubit.openDirectRoom();
                        if (roomId != null && context.mounted) OltNavigator.openRoom(context, roomId);
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(l10n.sendMessage),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editProfile(BuildContext context, UserProfile profile) async {
    final cubit = context.read<ProfileCubit>();
    final l10n = context.oltL10n;
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
              TextField(controller: name, maxLength: 60, decoration: InputDecoration(labelText: l10n.displayName)),
              TextField(controller: bio, maxLength: 300, maxLines: 3, decoration: InputDecoration(labelText: l10n.bio)),
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
