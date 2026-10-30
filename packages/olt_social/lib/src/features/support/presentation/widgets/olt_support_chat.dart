import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/app/olt_support_scope.dart';
import 'package:olt_social/src/features/chat/presentation/widgets/olt_chat_room.dart';
import 'package:olt_social/src/features/support/domain/entities/support_ticket.dart';
import 'package:olt_social/src/features/support/presentation/cubit/support_cubit.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_composer.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_dialogs.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_header.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_message_actions.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_topic_picker.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/load_status.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';
import 'package:olt_social/src/shared/presentation/widgets/state_views.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class OltSupportChat extends StatelessWidget {
  const OltSupportChat({super.key, this.topic, this.card, this.screen, this.onClose});

  final String? topic;
  final SupportCard? card;
  final String? screen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final support = OltSupportScope.of(context).support;
    final language = Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'id';
    return BlocProvider(
      create: (_) => SupportCubit(support: support, topic: topic, card: card, screen: screen, language: language)..load(),
      child: _SupportView(onClose: onClose),
    );
  }
}

class _SupportView extends StatelessWidget {
  const _SupportView({this.onClose});

  final VoidCallback? onClose;

  String _notice(OltSocialLocalizations l10n, SupportNoticeKind kind) => switch (kind) {
    SupportNoticeKind.closed => l10n.supportClosed,
    SupportNoticeKind.complaintFiled => l10n.supportComplaintFiled,
    SupportNoticeKind.fakeReported => l10n.supportFakeReported,
    SupportNoticeKind.rated => l10n.supportRated,
    SupportNoticeKind.cardSent => l10n.supportCardSent,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<SupportCubit, SupportState>(
          listenWhen: (a, b) => a.noticeId != b.noticeId,
          listener: (context, state) => showOltMessage(context, _notice(l10n, state.notice!)),
        ),
        BlocListener<SupportCubit, SupportState>(
          listenWhen: (a, b) => a.actionErrorId != b.actionErrorId,
          listener: (context, state) => showOltError(context, state.actionError!),
        ),
      ],
      child: BlocBuilder<SupportCubit, SupportState>(
        builder: (context, state) {
          final cubit = context.read<SupportCubit>();
          return switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const OltSkeleton(itemCount: 5),
            LoadStatus.failure => OltErrorView(error: state.error!, onRetry: cubit.load),
            LoadStatus.ready => Column(
              children: [
                SupportHeader(onClose: onClose),
                Expanded(
                  child: state.showsConversation(DateTime.now()) ? _Conversation(state: state) : const SupportTopicPicker(),
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
    final chat = OltSupportScope.of(context).supportChat;
    final deps = OltSocialScope.of(context);
    return OltSupportMessageActions(
      onQuickReply: (option) => chat.sendMessage(roomId, body: option, clientId: _uuid.v4()),
      canRate: state.canRate,
      onRate: (ticketId) async {
        final rating = await askSupportRating(context);
        if (rating != null) await cubit.rate(ticketId, rating.rating, comment: rating.comment);
      },
      child: OltSocialScope(
        dependencies: deps,
        child: OltChatRoom(
          key: ValueKey(roomId),
          roomId: roomId,
          repository: chat,
          showHeader: false,
          composer: const SupportComposer(),
        ),
      ),
    );
  }
}

class OltSupportPage extends StatelessWidget {
  const OltSupportPage({super.key, this.topic, this.card, this.screen});

  final String? topic;
  final SupportCard? card;
  final String? screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.oltL10n.supportTitle)),
    body: SafeArea(top: false, child: OltSupportChat(topic: topic, card: card, screen: screen)),
  );
}

Future<void> openOltSupport(BuildContext context, {String? topic, SupportCard? card, String? screen}) {
  final deps = OltSocialScope.of(context);
  final support = OltSupportScope.of(context);
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => OltSocialScope(
      dependencies: deps,
      child: OltSupportScope(
        dependencies: support,
        child: OltSupportPage(topic: topic, card: card, screen: screen),
      ),
    ),
  ));
}
