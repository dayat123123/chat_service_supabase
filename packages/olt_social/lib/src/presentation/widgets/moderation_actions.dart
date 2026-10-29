import 'package:flutter/material.dart';

import '../../domain/entities/paged.dart';
import '../../domain/entities/user.dart';
import '../l10n/l10n.dart';
import '../olt_social_scope.dart';
import 'common.dart';

/// Dialog laporan konten / user. Mengembalikan true bila laporan terkirim.
Future<bool> showReportDialog(BuildContext context, {required ReportTarget target, required String targetId}) async {
  final deps = OltSocialScope.of(context);
  final sent = await showDialog<bool>(
    context: context,
    builder: (context) => OltSocialScope(
      dependencies: deps,
      child: _ReportDialog(target: target, targetId: targetId),
    ),
  );
  if ((sent ?? false) && context.mounted) showOltMessage(context, context.oltL10n.reportSent);
  return sent ?? false;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.target, required this.targetId});

  final ReportTarget target;
  final String targetId;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason _reason = ReportReason.spam;
  final _details = TextEditingController();
  bool _sending = false;
  Object? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await OltSocialScope.of(context).moderation.report(
        target: widget.target,
        targetId: widget.targetId,
        reason: _reason,
        details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.oltL10n;
    String label(ReportReason r) => switch (r) {
      ReportReason.spam => l10n.reasonSpam,
      ReportReason.abuse => l10n.reasonAbuse,
      ReportReason.scam => l10n.reasonScam,
      ReportReason.pumpAndDump => l10n.reasonPumpAndDump,
      ReportReason.misinformation => l10n.reasonMisinformation,
      ReportReason.other => l10n.reasonOther,
    };
    return AlertDialog(
      title: Text(l10n.reportTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (r) => setState(() => _reason = r ?? _reason),
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(value: r, title: Text(label(r)), dense: true),
                  ],
                ),
              ),
              TextField(
                controller: _details,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(hintText: l10n.reportDetailsHint),
              ),
              if (_error != null)
                Text(l10n.errorMessage(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: _sending ? null : _submit, child: Text(l10n.report)),
      ],
    );
  }
}

/// Konfirmasi lalu blokir user. Mengembalikan true bila berhasil.
Future<bool> blockUserWithConfirm(BuildContext context, UserSummary user) async {
  final l10n = context.oltL10n;
  if (!await confirmOlt(context, l10n.blockConfirm(user.name), confirmLabel: l10n.block)) return false;
  if (!context.mounted) return false;
  try {
    await OltSocialScope.of(context).profiles.block(user.id);
    if (context.mounted) showOltMessage(context, l10n.blocked(user.name));
    return true;
  } catch (e) {
    if (context.mounted) showOltError(context, e);
    return false;
  }
}
