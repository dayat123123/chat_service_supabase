import 'package:cs_console/src/app/console_dependencies.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cs_console/src/features/auth/presentation/pages/login_page.dart';
import 'package:cs_console/src/features/auth/presentation/pages/password_page.dart';
import 'package:cs_console/src/features/auth/presentation/pages/totp_page.dart';
import 'package:cs_console/src/features/shell/console_shell.dart';
import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:olt_social/olt_social.dart';

class ConsoleApp extends StatelessWidget {
  const ConsoleApp({super.key, required this.deps});

  final ConsoleDependencies deps;

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0B57D0));
    return ThemeData(
      colorScheme: scheme,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: scheme.surface,
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      inputDecorationTheme: const InputDecorationTheme(isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(auth: deps.auth, agents: deps.agents)..start(),
      child: MaterialApp(
        title: 'CS Console',
        debugShowCheckedModeBanner: false,
        theme: theme(),
        locale: const Locale('id'),
        supportedLocales: ConsoleLocalizations.supportedLocales,
        localizationsDelegates: const [
          ConsoleLocalizations.delegate,
          OltSocialLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _AuthGate(deps: deps),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.deps});

  final ConsoleDependencies deps;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.runtimeType != b.runtimeType || b is! AuthReady,
      builder: (context, state) => switch (state) {
        AuthChecking() => const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthSignedOut() => LoginPage(state: state, idleMinutes: 30),
        AuthTotp(:final busy, :final error) => TotpPage(busy: busy, error: error),
        AuthEnroll() => EnrollPage(state: state),
        AuthPassword(:final busy, :final error) => PasswordPage(busy: busy, error: error),
        AuthReady(:final agent) => ConsoleShell(key: ValueKey(agent.id), agent: agent, deps: deps),
      },
    );
  }
}
