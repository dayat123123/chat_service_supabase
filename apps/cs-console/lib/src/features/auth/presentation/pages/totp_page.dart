import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cs_console/src/features/auth/presentation/pages/auth_frame.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TotpPage extends StatelessWidget {
  const TotpPage({super.key, required this.busy, this.error});

  final bool busy;
  final ConsoleError? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthFrame(
      title: l10n.totpTitle,
      subtitle: l10n.totpHint,
      children: [
        if (error != null) AuthError(errorText(context, error!)),
        _CodeForm(busy: busy, submitLabel: l10n.verify),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.read<AuthCubit>().signOut(), child: Text(l10n.useOtherAccount)),
      ],
    );
  }
}

class EnrollPage extends StatelessWidget {
  const EnrollPage({super.key, required this.state});

  final AuthEnroll state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grouped = state.secret.replaceAllMapped(RegExp('.{4}'), (m) => '${m[0]} ').trim();
    return AuthFrame(
      title: l10n.enrollTitle,
      subtitle: l10n.enrollHint,
      children: [
        if (state.error != null) AuthError(errorText(context, state.error!)),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: QrImageView(data: state.uri, size: 184),
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.enrollKey, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                grouped,
                style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', letterSpacing: 1),
              ),
            ),
            IconButton(
              tooltip: l10n.copy,
              onPressed: () => Clipboard.setData(ClipboardData(text: state.secret)),
              icon: const Icon(Icons.copy, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CodeForm(busy: state.busy, submitLabel: l10n.enrollActivate),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.read<AuthCubit>().signOut(), child: Text(l10n.useOtherAccount)),
      ],
    );
  }
}

class _CodeForm extends StatefulWidget {
  const _CodeForm({required this.busy, required this.submitLabel});

  final bool busy;
  final String submitLabel;

  @override
  State<_CodeForm> createState() => _CodeFormState();
}

class _CodeFormState extends State<_CodeForm> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (_code.text.trim().length != 6) return;
    context.read<AuthCubit>().verify(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
          onChanged: (value) {
            if (value.length == 6) _submit();
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: l10n.totpCode, border: const OutlineInputBorder(), counterText: ''),
        ),
        const SizedBox(height: 16),
        BusyButton(label: widget.submitLabel, busy: widget.busy, onPressed: _submit),
      ],
    );
  }
}
