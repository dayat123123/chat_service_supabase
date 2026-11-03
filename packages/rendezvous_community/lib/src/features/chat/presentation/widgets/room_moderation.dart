import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/room_moderation.dart';
import 'package:rendezvous_community/src/features/chat/presentation/cubit/chat_room_cubit.dart';
import 'package:rendezvous_community/src/features/moderation/domain/entities/report.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_builders.dart';
import 'package:rendezvous_community/src/shared/presentation/builders/community_badge_details.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class RoomModerationInput {
  const RoomModerationInput({required this.reason, this.duration, this.note});

  final ReportReason reason;
  final Duration? duration;
  final String? note;
}

String roomModerationTime(CommunityLocalizations l10n, DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final sameDay = local.year == current.year && local.month == current.month && local.day == current.day;
  return sameDay ? l10n.clockTime(time) : '${DateFormat.MMMd(l10n.localeName).format(local)} ${l10n.clockTime(time)}';
}

String roomMuteDurationLabel(CommunityLocalizations l10n, Duration duration) =>
    duration.inMinutes < 60 ? l10n.roomModMinutes(duration.inMinutes) : l10n.roomModHours(duration.inHours);

String reportReasonLabel(CommunityLocalizations l10n, ReportReason reason) => switch (reason) {
  ReportReason.spam => l10n.reasonSpam,
  ReportReason.abuse => l10n.reasonAbuse,
  ReportReason.scam => l10n.reasonScam,
  ReportReason.pumpAndDump => l10n.reasonPumpAndDump,
  ReportReason.misinformation => l10n.reasonMisinformation,
  ReportReason.other => l10n.reasonOther,
};

Future<void> runRoomModeration(
  BuildContext context,
  ChatRoomCubit cubit,
  ChatMessage message,
  RoomModerationAction action,
) async {
  final l10n = context.communityL10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final name = message.sender?.name ?? l10n.someone;
  final input = await showDialog<RoomModerationInput>(
    context: context,
    builder: (_) => RoomModerationDialog(action: action, memberName: name),
  );
  if (input == null) return;
  void notify(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  switch (action) {
    case RoomModerationAction.hide:
      if (await cubit.hideMessage(message, input.reason, note: input.note)) notify(l10n.roomModHidden);
    case RoomModerationAction.mute:
      final result = await cubit.muteMember(
        message,
        input.duration ?? roomMuteDurations.first,
        input.reason,
        note: input.note,
      );
      final until = result?.muteUntil ?? cubit.state.memberMutedUntil(message.senderId);
      if (result != null && until != null) notify(l10n.roomModMuted(name, roomModerationTime(l10n, until)));
    case RoomModerationAction.escalate:
      if (await cubit.escalateMessage(message, input.reason, note: input.note)) notify(l10n.roomModEscalated);
  }
}

class RoomModerationDialog extends StatefulWidget {
  const RoomModerationDialog({super.key, required this.action, required this.memberName});

  final RoomModerationAction action;
  final String memberName;

  @override
  State<RoomModerationDialog> createState() => _RoomModerationDialogState();
}

class _RoomModerationDialogState extends State<RoomModerationDialog> {
  ReportReason _reason = ReportReason.spam;
  Duration _duration = roomMuteDurations[1];
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    Navigator.pop(
      context,
      RoomModerationInput(
        reason: _reason,
        duration: widget.action == RoomModerationAction.mute ? _duration : null,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final (title, body, confirm) = switch (widget.action) {
      RoomModerationAction.hide => (l10n.roomModHideTitle, l10n.roomModHideBody, l10n.roomModHide),
      RoomModerationAction.mute => (l10n.roomModMuteTitle(widget.memberName), l10n.roomModMuteBody, l10n.roomModMute),
      RoomModerationAction.escalate => (l10n.roomModEscalateTitle, l10n.roomModEscalateBody, l10n.roomModEscalate),
    };
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (widget.action == RoomModerationAction.mute) ...[
                const SizedBox(height: 12),
                Text(l10n.roomModDuration, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final duration in roomMuteDurations)
                      ChoiceChip(
                        label: Text(roomMuteDurationLabel(l10n, duration)),
                        selected: duration == _duration,
                        onSelected: (_) => setState(() => _duration = duration),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(l10n.roomModReason, style: theme.textTheme.labelLarge),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (r) => setState(() => _reason = r ?? _reason),
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(value: r, title: Text(reportReasonLabel(l10n, r)), dense: true),
                  ],
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(hintText: l10n.roomModNoteHint),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: widget.action == RoomModerationAction.escalate
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
          onPressed: _submit,
          child: Text(confirm),
        ),
      ],
    );
  }
}

class RoomModeratorBadge extends StatelessWidget {
  const RoomModeratorBadge({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.communityL10n.roomModeratorBadge;
    final accent = color ?? theme.colorScheme.primary;
    final details = CommunityLabelBadgeDetails(
      kind: CommunityBadgeKind.roomModerator,
      label: label,
      icon: Icons.shield_outlined,
      foreground: accent,
      background: accent.withValues(alpha: 0.12),
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: buildLabelBadge(context, details, _DefaultModeratorBadge(details: details)),
    );
  }
}

class _DefaultModeratorBadge extends StatelessWidget {
  const _DefaultModeratorBadge({required this.details});

  final CommunityLabelBadgeDetails details;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: details.background, borderRadius: BorderRadius.circular(6)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(details.icon, size: 11, color: details.foreground),
        const SizedBox(width: 2),
        Text(
          details.label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: details.foreground, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class RoomModerationBanner extends StatelessWidget {
  const RoomModerationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((ChatRoomCubit c) => c.state);
    if (!state.isStockRoom) return const SizedBox.shrink();
    final l10n = context.communityL10n;
    final theme = Theme.of(context);
    final muted = state.mutedUntil();
    if (muted != null) {
      return _Strip(
        icon: Icons.volume_off_outlined,
        text: l10n.roomMutedBanner(roomModerationTime(l10n, muted)),
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.onErrorContainer,
      );
    }
    if (state.isRoomModerator) {
      return _Strip(
        icon: Icons.shield_outlined,
        text: l10n.roomModeratorNotice,
        background: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        foreground: theme.colorScheme.onPrimaryContainer,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.icon, required this.text, required this.background, required this.foreground});

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: background,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: foreground)),
        ),
      ],
    ),
  );
}
