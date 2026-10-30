import 'package:cs_console/src/core/error/error_text.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cs_console/src/features/auth/presentation/pages/auth_frame.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state, required this.idleMinutes});

  final AuthSignedOut state;
  final int idleMinutes;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    context.read<AuthCubit>().signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final notice = switch (state.reason) {
      SignOutReason.idle => l10n.signedOutIdle(widget.idleMinutes),
      SignOutReason.expired => l10n.signedOutExpired,
      SignOutReason.notStaff => l10n.signedOutNotStaff,
      _ => null,
    };
    return AuthFrame(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      children: [
        if (state.error != null) AuthError(errorText(context, state.error!)) else if (notice != null) AuthError(notice),
        AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.email, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BusyButton(label: l10n.signIn, busy: state.busy, onPressed: _submit),
      ],
    );
  }
}
