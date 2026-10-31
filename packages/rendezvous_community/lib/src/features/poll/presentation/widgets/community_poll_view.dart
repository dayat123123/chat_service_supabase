import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:olt_social/src/app/olt_social_scope.dart';
import 'package:olt_social/src/features/poll/domain/entities/poll.dart';
import 'package:olt_social/src/features/poll/presentation/cubit/poll_cubit.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:olt_social/src/shared/presentation/widgets/feedback.dart';

class OltPollView extends StatefulWidget {
  const OltPollView({super.key, required this.postId, required this.poll, this.canVote = true});

  final String postId;
  final Poll poll;
  final bool canVote;

  @override
  State<OltPollView> createState() => _OltPollViewState();
}

class _OltPollViewState extends State<OltPollView> {
  late final PollCubit _cubit = PollCubit(
    polls: OltSocialScope.of(context).polls,
    postId: widget.postId,
    poll: widget.poll,
  );

  @override
  void didUpdateWidget(OltPollView oldWidget) {
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
        listener: (context, state) => showOltError(context, state.error!),
        builder: (context, state) => _PollBody(state: state, interactive: widget.canVote),
      ),
    );
  }
}

class _PollBody extends StatelessWidget {
  const _PollBody({required this.state, required this.interactive});

  final PollState state;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final poll = state.poll;
    final now = DateTime.now();
    final closed = poll.isClosedAt(now);
    final showResults = poll.resultsVisible || closed || poll.hasVoted || !interactive;
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
                      pending: state.pendingOptionId == option.id,
                      enabled: state.pendingOptionId == null,
                      onVote: () => context.read<PollCubit>().vote(option),
                    ),
            ),
          Text(
            [
              l10n.pollVotes(poll.totalVotes),
              if (closed) l10n.pollEnded else l10n.pollEndsIn(l10n.remainingTime(poll.endsAt.difference(now))),
            ].join(' · '),
            style: meta,
          ),
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
    final l10n = context.oltL10n;
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
                  if (mine) ...[
                    Icon(Icons.check_circle, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  if (visible) Text('${(share * 100).round()}%', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: weight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
