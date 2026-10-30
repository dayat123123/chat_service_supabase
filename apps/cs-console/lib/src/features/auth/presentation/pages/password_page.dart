import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cs_console/src/features/auth/presentation/pages/auth_frame.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, required this.busy, this.error});

  static const minLength = 12;

  final bool busy;
  final ConsoleError? error;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _problem;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final problem = _password.text.length < PasswordPage.minLength
        ? l10n.passwordTooShort
        : _password.text != _confirm.text
            ? l10n.passwordMismatch
            : null;
    setState(() => _problem = problem);
    if (problem == null) context.read<AuthCubit>().changePassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _problem ?? (widget.error == null ? null : errorText(context, widget.error!));
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      ),
    );
    return AuthFrame(
      title: l10n.changePasswordTitle,
      subtitle: l10n.changePasswordSubtitle,
      children: [
        if (error != null) AuthError(error),
        AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: _password,
                autofocus: true,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: decoration(l10n.newPassword),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                decoration: decoration(l10n.confirmPassword),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.passwordRules, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        BusyButton(label: l10n.savePassword, busy: widget.busy, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.read<AuthCubit>().signOut(), child: Text(l10n.useOtherAccount)),
      ],
    );
  }
}
