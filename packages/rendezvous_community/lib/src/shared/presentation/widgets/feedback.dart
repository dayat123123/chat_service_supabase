import 'package:flutter/material.dart';
import 'package:rendezvous_community/src/shared/presentation/l10n/l10n.dart';

void showCommunityError(BuildContext context, Object error) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.communityL10n.errorMessage(error))));
}

void showCommunityMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmCommunityAction(BuildContext context, String message, {String? confirmLabel}) async {
  final l10n = context.communityL10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel ?? l10n.delete)),
      ],
    ),
  );
  return ok ?? false;
}
