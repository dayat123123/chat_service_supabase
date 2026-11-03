import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_offline_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/core/network/realtime_status.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_room.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_builders.dart';
import 'package:rendezvous_community/src/features/chat/presentation/builders/community_chat_details.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_composer.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/message_list.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_banners.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_header.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/typing_text.dart';
import 'package:rendezvous_community/src/features/config/presentation/widgets/community_social_gate.dart';
import 'package:rendezvous_community/src/features/legal/presentation/widgets/community_consent_flow.dart';
import 'package:rendezvous_community/src/features/offline/presentation/widgets/community_offline_banner.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

class CommunityChatRoom extends StatelessWidget {
  const CommunityChatRoom({
    super.key,
    required this.roomId,
    this.showHeader = true,
    this.repository,
    this.header,
    this.composer,
    this.builders,
  });

  final String roomId;
  final bool showHeader;
  final ChatRepository? repository;
  final Widget? header;
  final Widget? composer;
  final CommunityChatBuilders? builders;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final features = repository == null ? context.communityFeatures : null;
    final offline = CommunityOfflineScope.maybeOf(context);
    final cached = repository == null ? offline : null;
    return withChatBuilders(
      context,
      builders,
      BlocProvider(
        create: (_) => ChatRoomCubit(
          chat: repository ?? deps.chat,
          media: deps.media,
          me: deps.ensureSignedIn,
          roomId: roomId,
          consent: communityConsentGate(context),
          extras: features?.chatExtras,
          analytics: features?.analytics,
          requests: features?.messageRequests,
          cache: cached?.chatCache,
          outbox: cached?.outbox,
          connectivity: offline?.connectivity,
        )..load(),
        child: _ChatRoomView(showHeader: showHeader, header: header, composer: composer),
      ),
    );
  }
}

class _ChatRoomView extends StatelessWidget {
  const _ChatRoomView({required this.showHeader, this.header, this.composer});

  final bool showHeader;
  final Widget? header;
  final Widget? composer;

  @override
  Widget build(BuildContext context) {
    final builders = CommunityChatBuilders.of(context);
    return BlocConsumer<ChatRoomCubit, ChatRoomState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        final cubit = context.read<ChatRoomCubit>();
        return switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => buildChatPart(
            builders.loading,
            context,
            const CommunityLoadingDetails(CommunityChatLoad.messages),
            const CommunitySkeleton(itemCount: 6),
          ),
          LoadStatus.failure => buildChatPart(
            builders.error,
            context,
            CommunityErrorDetails(
              error: state.error!,
              message: context.communityL10n.errorMessage(state.error!),
              onRetry: cubit.load,
            ),
            CommunityErrorView(error: state.error!, onRetry: cubit.load),
          ),
          LoadStatus.ready => _gate(
            state,
            Column(
              children: [
                if (header != null) header! else if (showHeader) const RoomHeader(),
                const _ReconnectBanner(),
                const StockRoomBanner(),
                const RoomModerationBanner(),
                const DmRequestNotice(),
                const Expanded(child: MessageList()),
                const _TypingIndicator(),
                const Divider(height: 1),
                composer ?? const MessageComposer(),
              ],
            ),
          ),
        };
      },
    );
  }
}

Widget _gate(ChatRoomState state, Widget child) =>
    state.room?.type == RoomType.support ? child : CommunitySocialGate(child: child);

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final connectivity = CommunityOfflineScope.maybeOf(context)?.connectivity;
    if (connectivity == null) return const _RealtimeBanner();
    return ValueListenableBuilder<bool>(
      valueListenable: connectivity.online,
      builder: (context, online, _) => online ? const _RealtimeBanner() : const _OfflineBanner(),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatRoomCubit>();
    final status = context.select((ChatRoomCubit c) => c.state.connection);
    final l10n = context.communityL10n;
    final label = cubit.queuesOffline ? l10n.offlineChatBanner : l10n.errorNetwork;
    return buildChatPart(
      CommunityChatBuilders.of(context).connectionBanner,
      context,
      CommunityConnectionDetails(status: status, label: label, offline: true),
      CommunityOfflineNotice(message: label),
    );
  }
}

class _RealtimeBanner extends StatelessWidget {
  const _RealtimeBanner();

  @override
  Widget build(BuildContext context) {
    final status = context.select((ChatRoomCubit c) => c.state.connection);
    if (status != RealtimeStatus.reconnecting) return const SizedBox.shrink();
    final label = context.communityL10n.reconnecting;
    final theme = Theme.of(context);
    return buildChatPart(
      CommunityChatBuilders.of(context).connectionBanner,
      context,
      CommunityConnectionDetails(status: status, label: label),
      Container(
        width: double.infinity,
        color: theme.colorScheme.tertiaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final state = context.select((ChatRoomCubit c) => c.state);
    if (state.typing.isEmpty) return const SizedBox(height: 0);
    final theme = Theme.of(context);
    final text = typingText(context.communityL10n, state.typing.values, direct: state.room?.type == RoomType.direct);
    return buildChatPart(
      CommunityChatBuilders.of(context).typingIndicator,
      context,
      CommunityTypingDetails(users: state.typing.values.toList(), text: text),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
