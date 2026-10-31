import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

class SupportRating {
  const SupportRating(this.rating, this.comment);

  final int rating;
  final String? comment;
}

Future<SupportRating?> askSupportRating(BuildContext context) =>
    showDialog<SupportRating>(context: context, builder: (_) => const _RatingDialog());

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final _comment = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final color = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: Text(l10n.supportRateTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i',
                    iconSize: 34,
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: color),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(labelText: l10n.supportRateComment, border: const OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () => Navigator.pop(
                  context,
                  SupportRating(_rating, _comment.text.trim().isEmpty ? null : _comment.text.trim()),
                ),
          child: Text(l10n.supportRateSubmit),
        ),
      ],
    );
  }
}

Future<String?> askFakeCsReport(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _FakeCsDialog());

class _FakeCsDialog extends StatefulWidget {
  const _FakeCsDialog();

  @override
  State<_FakeCsDialog> createState() => _FakeCsDialogState();
}

class _FakeCsDialogState extends State<_FakeCsDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final valid = _text.text.trim().length >= 5;
    return AlertDialog(
      title: Text(l10n.supportReportFake),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: l10n.supportReportFakeHint, border: const OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, _text.text.trim()) : null,
          child: Text(l10n.supportSend),
        ),
      ],
    );
  }
}

Future<bool> confirmSupport(BuildContext context, {required String message, required String confirm}) async {
  final l10n = context.communityL10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}
