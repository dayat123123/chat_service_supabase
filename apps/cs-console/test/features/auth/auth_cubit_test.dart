import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/auth/data/auth_repository.dart';
import 'package:cs_console/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../support/fixtures.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockAgents extends Mock implements AgentRepository {}

void main() {
  late _MockAuth auth;
  late _MockAgents agents;

  setUpAll(() => registerFallbackValue(AgentStatus.offline));

  setUp(() {
    auth = _MockAuth();
    agents = _MockAgents();
    when(() => auth.changes).thenAnswer((_) => const Stream.empty());
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  test('login lalu TOTP: CS masuk dengan status default Offline', () async {
    when(() => auth.signIn(any(), any())).thenAnswer((_) async {});
    when(() => auth.nextStep()).thenAnswer((_) async => const TotpRequired('f-1'));
    when(() => agents.setStatus(AgentStatus.offline))
        .thenAnswer((_) async => AgentProfile.fromJson(agentJson()));
    final cubit = AuthCubit(auth: auth, agents: agents);

    await cubit.signIn(' nadia@cs.olt.local ', 'rahasia-dev-123');
    expect(cubit.state, const AuthState.totp(factorId: 'f-1'));
    verify(() => auth.signIn('nadia@cs.olt.local', 'rahasia-dev-123')).called(1);

    when(() => auth.verify('f-1', '123456')).thenAnswer((_) async {});
    when(() => auth.nextStep()).thenAnswer((_) async => const Verified());
    await cubit.verify(' 123456 ');

    final state = cubit.state;
    expect(state, isA<AuthReady>());
    expect((state as AuthReady).agent.status, AgentStatus.offline);
    verify(() => agents.setStatus(AgentStatus.offline)).called(1);
    await cubit.close();
  });

  test('kode TOTP salah tetap di halaman TOTP dengan pesan error', () async {
    when(() => auth.nextStep()).thenAnswer((_) async => const TotpRequired('f-1'));
    when(() => auth.verify(any(), any())).thenThrow(const AuthException('Invalid TOTP code', code: 'mfa_verification_failed'));
    final cubit = AuthCubit(auth: auth, agents: agents);
    await cubit.start();

    await cubit.verify('000000');

    final state = cubit.state as AuthTotp;
    expect(state.busy, isFalse);
    expect(state.error?.code, 'mfa_verification_failed');
    await cubit.close();
  });

  test('akun GoTrue yang bukan CS dikeluarkan lagi', () async {
    when(() => auth.nextStep()).thenAnswer((_) async => const Verified());
    when(() => agents.me()).thenThrow(const ConsoleError('agent_required', status: 403));
    final cubit = AuthCubit(auth: auth, agents: agents);

    await cubit.start();

    expect(cubit.state, const AuthState.signedOut(reason: SignOutReason.notStaff));
    verify(() => auth.signOut()).called(1);
    await cubit.close();
  });

  test('akun tanpa TOTP diminta mendaftarkan authenticator', () async {
    when(() => auth.nextStep()).thenAnswer(
      (_) async => const TotpEnrollment(factorId: 'f-2', secret: 'ABCDEFGH', uri: 'otpauth://totp/x'),
    );
    final cubit = AuthCubit(auth: auth, agents: agents);

    await cubit.start();

    expect(cubit.state, isA<AuthEnroll>());
    await cubit.close();
  });

  test('password sementara wajib diganti sebelum mendaftarkan 2FA', () async {
    when(() => auth.nextStep()).thenAnswer((_) async => const PasswordChangeRequired());
    final cubit = AuthCubit(auth: auth, agents: agents);
    await cubit.start();
    expect(cubit.state, const AuthState.password());

    when(() => auth.changePassword(any())).thenAnswer((_) async {});
    when(() => auth.nextStep()).thenAnswer(
      (_) async => const TotpEnrollment(factorId: 'f-3', secret: 'ABCDEFGH', uri: 'otpauth://totp/y'),
    );
    await cubit.changePassword('password-baru-kuat-123');

    expect(cubit.state, isA<AuthEnroll>());
    verify(() => auth.changePassword('password-baru-kuat-123')).called(1);
    await cubit.close();
  });

  test('password baru yang ditolak GoTrue tetap di halaman ganti password', () async {
    when(() => auth.nextStep()).thenAnswer((_) async => const PasswordChangeRequired());
    when(() => auth.changePassword(any())).thenThrow(const AuthException('same', code: 'same_password'));
    final cubit = AuthCubit(auth: auth, agents: agents);
    await cubit.start();

    await cubit.changePassword('password-sementara-1');

    final state = cubit.state as AuthPassword;
    expect(state.busy, isFalse);
    expect(state.error?.code, 'same_password');
    await cubit.close();
  });
}
