import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_feature_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/media/presentation/widgets/attachment_grid.dart';
import 'package:rendezvous_community/src/features/message_requests/domain/entities/message_request.dart';
import 'package:rendezvous_community/src/features/message_requests/presentation/cubit/message_request_room_cubit.dart';
import 'package:rendezvous_community/src/features/message_requests/presentation/cubit/message_requests_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_avatar.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_count_badge.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/community_user_name.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';

Widget _scoped(BuildContext context, Widget child) {
  final deps = CommunityScope.of(context);
  final features = CommunityFeatureScope.of(context);
  return CommunityFeatureScope(
    dependencies: features,
    child: CommunityScope(dependencies: deps, child: child),
  );
}

Future<bool> openCommunityMessageRequests(BuildContext context) async {
  final title = context.communityL10n.messageRequests;
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (pageContext) => _scoped(
        context,
        Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const SafeArea(top: false, child: CommunityMessageRequests()),
        ),
      ),
    ),
  );
  return changed ?? false;
}

class MessageRequestsEntry extends StatefulWidget {
  const MessageRequestsEntry({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<MessageRequestsEntry> createState() => _MessageRequestsEntryState();
}

class _MessageRequestsEntryState extends State<MessageRequestsEntry> {
  MessageRequestsCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final features = CommunityFeatureScope.maybeOf(context);
    if (_cubit == null && features != null) _cubit = MessageRequestsCubit(features.messageRequests)..loadCount();
  }

  @override
  void didUpdateWidget(MessageRequestsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _cubit?.loadCount();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _open() async {
    await openCommunityMessageRequests(context);
    await _cubit?.loadCount();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<MessageRequestsCubit, MessageRequestsState>(
      bloc: cubit,
      buildWhen: (a, b) => a.count != b.count,
      builder: (context, state) {
        if (state.count <= 0) return const SizedBox.shrink();
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.mark_email_unread_outlined)),
          title: Text(context.communityL10n.messageRequests),
          trailing: CommunityCountBadge(count: state.count, kind: CommunityCountKind.messageRequests),
          onTap: _open,
        );
      },
    );
  }
}

class CommunityMessageRequests extends StatelessWidget {
  const CommunityMessageRequests({super.key});

  @override
  Widget build(BuildContext context) {
    final features = CommunityFeatureScope.of(context);
    return BlocProvider(
      create: (_) => MessageRequestsCubit(features.messageRequests)..load(),
      child: const _RequestsView(),
    );
  }
}

class _RequestsView extends StatelessWidget {
  const _RequestsView();

  Future<void> _open(BuildContext context, MessageRequest request) async {
    final cubit = context.read<MessageRequestsCubit>();
    final result = await Navigator.of(context).push<MessageRequestAction>(
      MaterialPageRoute(
        builder: (_) => _scoped(
          context,
          Scaffold(
            appBar: AppBar(title: Text(request.sender.name)),
            body: SafeArea(top: false, child: MessageRequestRoom(request: request)),
          ),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    cubit.removeRequest(request.roomId);
    if (result == MessageRequestAction.accept) CommunityNavigator.openRoom(context, request.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    return BlocConsumer<MessageRequestsCubit, MessageRequestsState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<MessageRequestsCubit>();
        return switch (state.status) {
          LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(itemCount: 4),
          LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
          LoadStatus.ready when state.requests.isEmpty => CommunityEmptyView(
            message: l10n.messageRequestsEmpty,
            icon: Icons.mark_email_read_outlined,
          ),
          LoadStatus.ready => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 300) cubit.loadMore();
                    return false;
                  },
                  child: ListView.separated(
                    addAutomaticKeepAlives: false,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: state.requests.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final request = state.requests[i];
                      final time = request.lastMessageAt ?? request.createdAt;
                      return ListTile(
                        leading: CommunityAvatar(user: request.sender),
                        title: CommunityUserName(user: request.sender, showUsername: false),
                        subtitle: Text(
                          [if (request.hasImage) '📷', request.lastMessagePreview ?? l10n.attachment].join(' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(l10n.relativeTime(time), style: theme.textTheme.bodySmall),
                            Text(
                              l10n.messageRequestMessages(request.messageCount),
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                        onTap: () => _open(context, request),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}

class MessageRequestRoom extends StatelessWidget {
  const MessageRequestRoom({super.key, required this.request});

  final MessageRequest request;

  @override
  Widget build(BuildContext context) {
    final deps = CommunityScope.of(context);
    final features = CommunityFeatureScope.of(context);
    return BlocProvider(
      create: (_) =>
          MessageRequestRoomCubit(chat: deps.chat, requests: features.messageRequests, roomId: request.roomId)..load(),
      child: _RequestRoomView(request: request),
    );
  }
}

class _RequestRoomView extends StatelessWidget {
  const _RequestRoomView({required this.request});

  final MessageRequest request;

  Future<void> _respond(BuildContext context, MessageRequestAction action) async {
    final l10n = context.communityL10n;
    if (action == MessageRequestAction.block &&
        !await confirmCommunityAction(
          context,
          l10n.messageRequestBlockConfirm(request.sender.name),
          confirmLabel: l10n.messageRequestBlock,
        )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await context.read<MessageRequestRoomCubit>().respond(action);
    if (!ok || !context.mounted) return;
    showCommunityMessage(context, switch (action) {
      MessageRequestAction.accept => l10n.messageRequestAccepted,
      MessageRequestAction.decline => l10n.messageRequestDeclined,
      MessageRequestAction.block => l10n.blocked(request.sender.name),
    });
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    return BlocConsumer<MessageRequestRoomCubit, MessageRequestRoomState>(
      listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
      listener: (context, state) => showCommunityError(context, state.actionError!),
      builder: (context, state) {
        final cubit = context.read<MessageRequestRoomCubit>();
        final busy = state.responding != null;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CommunityBreakpoints.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.messageRequestIntro(request.sender.name)),
                      if (request.hasImage)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.messageRequestImageHidden,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (state.status) {
                    LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(itemCount: 3),
                    LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
                    LoadStatus.ready => ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      children: [for (final m in state.messages) _RequestBubble(message: m)],
                    ),
                  },
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: busy ? null : () => _respond(context, MessageRequestAction.block),
                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                          icon: const Icon(Icons.block),
                          label: Text(l10n.messageRequestBlock),
                        ),
                        OutlinedButton(
                          onPressed: busy ? null : () => _respond(context, MessageRequestAction.decline),
                          child: Text(l10n.messageRequestDecline),
                        ),
                        FilledButton(
                          onPressed: busy ? null : () => _respond(context, MessageRequestAction.accept),
                          child: state.responding == MessageRequestAction.accept
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(l10n.messageRequestAccept),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestBubble extends StatelessWidget {
  const _RequestBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final colors = CommunityTheme.of(context);
    final body = message.body ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(color: colors.otherBubble, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isDeleted)
              Text(l10n.messageDeleted, style: const TextStyle(fontStyle: FontStyle.italic))
            else ...[
              if (message.attachments.isNotEmpty)
                AttachmentGrid(attachments: message.attachments, maxHeight: 200, blurred: true),
              if (body.isNotEmpty) Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onOtherBubble)),
            ],
            Text(
              l10n.clockTime(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(color: colors.onOtherBubble.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
