import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_builders.dart';
import 'package:rendezvous_community/src/app/community_image_scope.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/app/community_support_scope.dart';
import 'package:rendezvous_community/src/features/chat/presentation/widgets/community_chat_room.dart';
import 'package:rendezvous_community/src/features/support/presentation/cubit/support_cubit.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_composer.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_dialogs.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_header.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_message_actions.dart';
import 'package:rendezvous_community/src/features/support/presentation/widgets/support_topic_picker.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/load_status.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/state_views.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class CommunitySupportChat extends StatelessWidget {
  const CommunitySupportChat({super.key, this.topic, this.screen, this.onClose});

  final String? topic;
  final String? screen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final support = CommunitySupportScope.of(context).support;
    final language = Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'id';
    return BlocProvider(
      create: (_) => SupportCubit(support: support, topic: topic, screen: screen, language: language)..load(),
      child: _SupportView(onClose: onClose),
    );
  }
}

class _SupportView extends StatelessWidget {
  const _SupportView({this.onClose});

  final VoidCallback? onClose;

  String _notice(CommunityLocalizations l10n, SupportNoticeKind kind) => switch (kind) {
    SupportNoticeKind.closed => l10n.supportClosed,
    SupportNoticeKind.complaintFiled => l10n.supportComplaintFiled,
    SupportNoticeKind.fakeReported => l10n.supportFakeReported,
    SupportNoticeKind.rated => l10n.supportRated,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<SupportCubit, SupportState>(
          listenWhen: (a, b) => a.noticeId != b.noticeId,
          listener: (context, state) => showCommunityMessage(context, _notice(l10n, state.notice!)),
        ),
        BlocListener<SupportCubit, SupportState>(
          listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
          listener: (context, state) => showCommunityError(context, state.actionError!),
        ),
      ],
      child: BlocBuilder<SupportCubit, SupportState>(
        builder: (context, state) {
          final cubit = context.read<SupportCubit>();
          return switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const CommunitySkeleton(itemCount: 5),
            LoadStatus.failure => CommunityErrorView(error: state.error!, onRetry: cubit.load),
            LoadStatus.ready => Column(
              children: [
                SupportHeader(onClose: onClose),
                Expanded(
                  child: state.showsConversation(DateTime.now())
                      ? _Conversation(state: state)
                      : const SupportTopicPicker(),
                ),
              ],
            ),
          };
        },
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.state});

  final SupportState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SupportCubit>();
    final roomId = state.home!.roomId!;
    final ticket = state.ticket;
    final chat = CommunitySupportScope.of(context).supportChat;
    final deps = CommunityScope.of(context);
    return CommunitySupportMessageActions(
      onQuickReply: (option) => chat.sendMessage(roomId, body: option, clientId: _uuid.v4()),
      canRate: state.canRate,
      onRate: (ticketId) async {
        final rating = await askSupportRating(context);
        if (rating != null) await cubit.rate(ticketId, rating.rating, comment: rating.comment);
      },
      child: CommunityScope(
        dependencies: deps,
        child: CommunityImagePersistence(
          persist: false,
          child: CommunityChatRoom(
            key: ValueKey(roomId),
            roomId: roomId,
            repository: chat,
            showHeader: false,
            composer: ticket == null || ticket.isActive || ticket.reopenable(DateTime.now())
                ? const SupportComposer()
                : SupportClosedBar(ticketNumber: ticket.ticketNumber),
          ),
        ),
      ),
    );
  }
}

class CommunitySupportPage extends StatelessWidget {
  const CommunitySupportPage({super.key, this.topic, this.screen});

  final String? topic;
  final String? screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.communityL10n.supportTitle)),
    body: SafeArea(
      top: false,
      child: CommunitySupportChat(topic: topic, screen: screen),
    ),
  );
}

Future<void> openCommunitySupport(BuildContext context, {String? topic, String? screen}) {
  final deps = CommunityScope.of(context);
  final support = CommunitySupportScope.of(context);
  final carry = carryCommunityBuilders(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => carry(
        CommunityScope(
          dependencies: deps,
          child: CommunitySupportScope(
            dependencies: support,
            child: CommunitySupportPage(topic: topic, screen: screen),
          ),
        ),
      ),
    ),
  );
}
