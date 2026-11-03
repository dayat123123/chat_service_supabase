import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/app/community_scope.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_builders.dart';
import 'package:rendezvous_community/src/features/feed/presentation/builders/community_feed_details.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/features/poll/presentation/cubit/poll_cubit.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_part_builder.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/widgets/feedback.dart';

class CommunityPollView extends StatefulWidget {
  const CommunityPollView({super.key, required this.postId, required this.poll, this.canVote = true});

  final String postId;
  final Poll poll;
  final bool canVote;

  @override
  State<CommunityPollView> createState() => _CommunityPollViewState();
}

class _CommunityPollViewState extends State<CommunityPollView> {
  late final PollCubit _cubit = PollCubit(
    polls: CommunityScope.of(context).polls,
    postId: widget.postId,
    poll: widget.poll,
  );

  @override
  void didUpdateWidget(CommunityPollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.poll != oldWidget.poll) _cubit.sync(widget.poll);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<PollCubit, PollState>(
        listenWhen: (a, b) => a.errorId != b.errorId,
        listener: (context, state) => showCommunityError(context, state.error!),
        builder: (context, state) {
          final l10n = context.communityL10n;
          final poll = state.poll;
          final now = DateTime.now();
          final closed = poll.isClosedAt(now);
          final details = CommunityPollDetails(
            postId: widget.postId,
            poll: poll,
            canVote: widget.canVote,
            closed: closed,
            showResults: poll.resultsVisible || closed || poll.hasVoted || !widget.canVote,
            summary: [
              l10n.pollVotes(poll.totalVotes),
              if (closed) l10n.pollEnded else l10n.pollEndsIn(l10n.remainingTime(poll.endsAt.difference(now))),
            ].join(' · '),
            pendingOptionId: state.pendingOptionId,
            onVote: widget.canVote && !closed && !poll.hasVoted && state.pendingOptionId == null ? _cubit.vote : null,
          );
          return buildCommunityPart(
            CommunityFeedBuilders.of(context).poll,
            context,
            details,
            _PollBody(details: details),
          );
        },
      ),
    );
  }
}

class _PollBody extends StatelessWidget {
  const _PollBody({required this.details});

  final CommunityPollDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poll = details.poll;
    final showResults = details.showResults;
    final leading = poll.leadingOptionId;
    final meta = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: showResults
                  ? _ResultBar(
                      option: option,
                      share: poll.share(option),
                      visible: poll.resultsVisible,
                      mine: option.id == poll.myOptionId,
                      leading: option.id == leading,
                    )
                  : _VoteButton(
                      option: option,
                      pending: details.pendingOptionId == option.id,
                      enabled: details.pendingOptionId == null,
                      onVote: () => context.read<PollCubit>().vote(option),
                    ),
            ),
          Text(details.summary, style: meta),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.option, required this.pending, required this.enabled, required this.onVote});

  final PollOption option;
  final bool pending;
  final bool enabled;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onVote : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: pending
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({
    required this.option,
    required this.share,
    required this.visible,
    required this.mine,
    required this.leading,
  });

  final PollOption option;
  final double share;
  final bool visible;
  final bool mine;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weight = leading ? FontWeight.w700 : FontWeight.w500;
    return Semantics(
      label: '${option.label}${mine ? ', ${l10n.pollYourVote}' : ''}',
      value: visible ? '${(share * 100).round()}%' : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: scheme.surfaceContainerHighest)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: visible ? share.clamp(0, 1) : 0,
                child: ColoredBox(color: leading ? scheme.primaryContainer : scheme.secondaryContainer),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: weight),
                    ),
                  ),
                  if (mine) ...[Icon(Icons.check_circle, size: 16, color: scheme.primary), const SizedBox(width: 6)],
                  if (visible)
                    Text('${(share * 100).round()}%', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: weight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
