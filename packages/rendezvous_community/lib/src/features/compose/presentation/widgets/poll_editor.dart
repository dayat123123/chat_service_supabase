import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rendezvous_community/src/features/compose/presentation/cubit/compose_cubit.dart';
import 'package:rendezvous_community/src/features/poll/domain/entities/poll.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class PollEditor extends StatefulWidget {
  const PollEditor({super.key, required this.poll, required this.enabled});

  final PollDraft poll;
  final bool enabled;

  @override
  State<PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends State<PollEditor> {
  final _controllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PollEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final options = widget.poll.options;
    while (_controllers.length > options.length) {
      _controllers.removeLast().dispose();
    }
    for (var i = 0; i < options.length; i++) {
      if (i >= _controllers.length) {
        _controllers.add(TextEditingController(text: options[i]));
      } else if (_controllers[i].text != options[i]) {
        _controllers[i].text = options[i];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _durationLabel(BuildContext context, PollDuration duration) {
    final l10n = context.communityL10n;
    return switch (duration) {
      PollDuration.oneHour => l10n.pollDuration1h,
      PollDuration.sixHours => l10n.pollDuration6h,
      PollDuration.oneDay => l10n.pollDuration1d,
      PollDuration.threeDays => l10n.pollDuration3d,
      PollDuration.sevenDays => l10n.pollDuration7d,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final cubit = context.read<ComposeCubit>();
    final options = widget.poll.options;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.poll_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.pollAddTooltip, style: theme.textTheme.titleSmall)),
                IconButton(
                  tooltip: l10n.pollRemove,
                  onPressed: widget.enabled ? cubit.removePoll : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('poll-option-$i'),
                        controller: _controllers[i],
                        enabled: widget.enabled,
                        maxLength: PollDraft.maxOptionLength,
                        decoration: InputDecoration(
                          hintText: l10n.pollOptionHint(i + 1),
                          isDense: true,
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) => cubit.setPollOption(i, value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: options.length > PollDraft.minOptions
                          ? IconButton(
                              onPressed: widget.enabled ? () => cubit.removePollOption(i) : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                if (options.length < PollDraft.maxOptions)
                  TextButton.icon(
                    onPressed: widget.enabled ? cubit.addPollOption : null,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.pollAddOption),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.pollDuration, style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    DropdownButton<PollDuration>(
                      value: widget.poll.duration,
                      onChanged: widget.enabled ? (d) => d == null ? null : cubit.setPollDuration(d) : null,
                      items: [
                        for (final d in PollDuration.values)
                          DropdownMenuItem(value: d, child: Text(_durationLabel(context, d))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
