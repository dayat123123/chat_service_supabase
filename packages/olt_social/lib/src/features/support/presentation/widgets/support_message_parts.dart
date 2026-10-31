import 'package:flutter/material.dart';
import 'package:olt_social/src/features/chat/domain/entities/chat_message.dart';
import 'package:olt_social/src/features/support/presentation/widgets/support_message_actions.dart';
import 'package:olt_social/src/shared/domain/entities/user.dart';
import 'package:olt_social/src/shared/presentation/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportSystemNotice extends StatelessWidget {
  const SupportSystemNotice({super.key, required this.message});

  final ChatMessage message;

  static IconData iconFor(String? code) => switch (code) {
    'ticket_opened' => Icons.confirmation_number_outlined,
    'ticket_claimed' || 'ticket_reopened_owner' => Icons.support_agent,
    'ticket_transferred' => Icons.swap_horiz,
    'ticket_released' || 'ticket_reopened' => Icons.replay,
    'agent_away' => Icons.schedule,
    'ticket_resolved' => Icons.task_alt,
    'ticket_closed' => Icons.lock_outline,
    'secured' => Icons.shield_outlined,
    _ => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = OltSupportMessageActions.maybeOf(context);
    final ticketId = message.ticketId;
    final rateable = message.kind == MessageKind.csat &&
        ticketId != null &&
        actions?.onRate != null &&
        (actions?.canRate?.call(ticketId) ?? false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(iconFor(message.systemCode), size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.body ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.clockTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
              if (rateable)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: FilledButton.tonalIcon(
                    onPressed: () => actions!.onRate!(ticketId),
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text(l10n.supportRatePrompt),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfficialSenderLabel extends StatelessWidget {
  const OfficialSenderLabel({super.key, required this.sender, required this.color});

  final UserSummary sender;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            sender.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 6),
        OfficialBadge(color: color),
      ],
    );
  }
}

class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            context.oltL10n.supportOfficialBadge,
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class SupportMessageExtras extends StatelessWidget {
  const SupportMessageExtras({super.key, required this.message, required this.color, required this.mine});

  final ChatMessage message;
  final Color color;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final actions = OltSupportMessageActions.maybeOf(context);
    return switch (message.kind) {
      MessageKind.quickReply => _QuickReplies(
        options: [for (final o in (message.payload['options'] as List<Object?>? ?? const [])) '$o'],
        onSelected: mine ? null : actions?.onQuickReply,
      ),
      MessageKind.helpLink => _HelpLink(url: message.payload['url'] as String?, onOpen: actions?.onOpenLink),
      _ => const SizedBox.shrink(),
    };
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.options, required this.onSelected});

  final List<String> options;
  final void Function(String option)? onSelected;

  @override
  Widget build(BuildContext context) {
    final select = onSelected;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            ActionChip(
              label: Text(option),
              visualDensity: VisualDensity.compact,
              onPressed: select == null ? null : () => select(option),
            ),
        ],
      ),
    );
  }
}

class _HelpLink extends StatelessWidget {
  const _HelpLink({required this.url, required this.onOpen});

  final String? url;
  final void Function(Uri url)? onOpen;

  @override
  Widget build(BuildContext context) {
    final uri = url == null ? null : Uri.tryParse(url!);
    if (uri == null || uri.scheme != 'https') return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
        onPressed: () => onOpen == null ? launchUrl(uri, mode: LaunchMode.externalApplication) : onOpen!(uri),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(context.oltL10n.supportOpenLink),
      ),
    );
  }
}
