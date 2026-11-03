import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/share_post_cubit.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_visuals.dart';
import 'package:rendezvous_community/src/features/feed/domain/entities/post.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

Future<bool> showSharePostToChat(BuildContext context, Post post) async {
  final features = CommunityFeatureScope.maybeOf(context);
  if (features == null) return false;
  final deps = CommunityScope.of(context);
  final shared = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CommunityScope(
      dependencies: deps,
      child: BlocProvider(
        create: (_) => SharePostCubit(chat: deps.chat, extras: features.chatExtras, postId: post.id)..load(),
        child: const _SharePostSheet(),
      ),
    ),
  );
  if (shared == true && context.mounted) showCommunityMessage(context, context.communityL10n.shareSent);
  return shared ?? false;
}

class _SharePostSheet extends StatefulWidget {
  const _SharePostSheet();

  @override
  State<_SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<_SharePostSheet> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _share(ChatRoom room) async {
    if (await context.read<SharePostCubit>().share(room.id, body: _message.text) && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return BlocConsumer<SharePostCubit, SharePostState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<SharePostCubit>();
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l10n.sharePickRoom, style: Theme.of(context).textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _message,
                    maxLength: 4000,
                    decoration: InputDecoration(
                      hintText: l10n.shareMessageHint,
                      border: const OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: switch (state.status) {
                    LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(itemCount: 4),
                    LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
                    LoadStatus.ready when state.rooms.isEmpty => CommunityEmptyView(
                      message: l10n.shareNoRooms,
                      icon: Icons.chat_bubble_outline,
                    ),
                    LoadStatus.ready => ListView.builder(
                      addAutomaticKeepAlives: false,
                      itemCount: state.rooms.length,
                      itemBuilder: (context, i) {
                        final room = state.rooms[i];
                        final sending = state.sendingRoomId == room.id;
                        return ListTile(
                          leading: CommunityRoomAvatar(room: room),
                          title: Text(roomTitle(room), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: sending
                              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_outlined),
                          enabled: state.sendingRoomId == null,
                          onTap: () => _share(room),
                        );
                      },
                    ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
