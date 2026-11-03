import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/receipt.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';
import 'package:rendezvous_community/src/shared/presentation/theme/community_theme.dart';

class ReceiptIcon extends StatelessWidget {
  const ReceiptIcon({
    super.key,
    required this.receipt,
    required this.color,
    this.sendStatus = MessageStatus.sent,
    this.size = 16,
  });

  final ReceiptStatus? receipt;
  final MessageStatus sendStatus;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return switch (sendStatus) {
      MessageStatus.sending => Icon(Icons.schedule, size: size - 2, color: color, semanticLabel: l10n.messageSending),
      MessageStatus.pending => Icon(
        Icons.cloud_upload_outlined,
        size: size - 2,
        color: color,
        semanticLabel: l10n.messagePending,
      ),
      MessageStatus.failed => Icon(
        Icons.error_outline,
        size: size - 2,
        color: Theme.of(context).colorScheme.error,
        semanticLabel: l10n.messageFailed,
      ),
      MessageStatus.sent => switch (receipt) {
        null => const SizedBox.shrink(),
        ReceiptStatus.sent => Icon(Icons.done, size: size, color: color, semanticLabel: l10n.messageSent),
        ReceiptStatus.delivered => Icon(Icons.done_all, size: size, color: color, semanticLabel: l10n.messageDelivered),
        ReceiptStatus.read => Icon(
          Icons.done_all,
          size: size,
          color: CommunityTheme.of(context).readReceipt,
          semanticLabel: l10n.messageRead,
        ),
      },
    };
  }
}
