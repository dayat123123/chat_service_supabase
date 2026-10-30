import 'dart:async';

import 'package:cs_console/src/core/error/console_error.dart';
import 'package:cs_console/src/features/agent/data/agent_repository.dart';
import 'package:cs_console/src/features/agent/domain/agent_profile.dart';
import 'package:cs_console/src/features/auth/data/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

part 'auth_cubit.freezed.dart';

enum SignOutReason { manual, idle, expired, notStaff }

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.checking() = AuthChecking;

  const factory AuthState.signedOut({@Default(false) bool busy, ConsoleError? error, SignOutReason? reason}) =
      AuthSignedOut;

  const factory AuthState.totp({required String factorId, @Default(false) bool busy, ConsoleError? error}) =
      AuthTotp;

  const factory AuthState.enroll({
    required String factorId,
    required String secret,
    required String uri,
    @Default(false) bool busy,
    ConsoleError? error,
  }) = AuthEnroll;

  const factory AuthState.password({@Default(false) bool busy, ConsoleError? error}) = AuthPassword;

  const factory AuthState.ready(AgentProfile agent) = AuthReady;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required this._auth, required this._agents}) : super(const AuthState.checking()) {
    _changes = _auth.changes.listen((event) {
      if (event == AuthChangeEvent.signedOut && state is AuthReady) {
        emit(const AuthState.signedOut(reason: SignOutReason.expired));
      }
    });
  }

  final AuthRepository _auth;
  final AgentRepository _agents;
  late final StreamSubscription<AuthChangeEvent> _changes;

  Future<void> start() => _advance(freshLogin: false);

  Future<void> signIn(String email, String password) async {
    emit(const AuthState.signedOut(busy: true));
    try {
      await _auth.signIn(email.trim(), password);
      await _advance(freshLogin: true);
    } catch (e) {
      if (!isClosed) emit(AuthState.signedOut(error: ConsoleError.from(e)));
    }
  }

  Future<void> verify(String code) async {
    final current = state;
    final factorId = switch (current) {
      AuthTotp(:final factorId) || AuthEnroll(:final factorId) => factorId,
      _ => null,
    };
    if (factorId == null) return;
    emit(_busy(current));
    try {
      await _auth.verify(factorId, code.trim());
      await _advance(freshLogin: true);
    } catch (e) {
      if (!isClosed) emit(_failed(current, ConsoleError.from(e)));
    }
  }

  Future<void> changePassword(String password) async {
    final current = state;
    if (current is! AuthPassword) return;
    emit(current.copyWith(busy: true, error: null));
    try {
      await _auth.changePassword(password);
      await _advance(freshLogin: true);
    } catch (e) {
      if (!isClosed) emit(current.copyWith(busy: false, error: ConsoleError.from(e)));
    }
  }

  Future<void> signOut({SignOutReason reason = SignOutReason.manual}) async {
    if (state is AuthReady) {
      try {
        await _agents.setStatus(AgentStatus.offline);
      } catch (_) {}
    }
    try {
      await _auth.signOut();
    } catch (_) {}
    if (!isClosed) emit(AuthState.signedOut(reason: reason));
  }

  Future<void> _advance({required bool freshLogin}) async {
    try {
      switch (await _auth.nextStep()) {
        case NoSession():
          emit(const AuthState.signedOut());
        case TotpRequired(:final factorId):
          emit(AuthState.totp(factorId: factorId));
        case TotpEnrollment(:final factorId, :final secret, :final uri):
          emit(AuthState.enroll(factorId: factorId, secret: secret, uri: uri));
        case PasswordChangeRequired():
          emit(const AuthState.password());
        case Verified():
          final agent = freshLogin ? await _agents.setStatus(AgentStatus.offline) : await _agents.me();
          if (!isClosed) emit(AuthState.ready(agent));
      }
    } catch (e) {
      final error = ConsoleError.from(e);
      if (error.code == 'agent_required') {
        try {
          await _auth.signOut();
        } catch (_) {}
        if (!isClosed) emit(const AuthState.signedOut(reason: SignOutReason.notStaff));
        return;
      }
      if (!isClosed) emit(AuthState.signedOut(error: error));
    }
  }

  AuthState _busy(AuthState state) => switch (state) {
    AuthTotp() => state.copyWith(busy: true, error: null),
    AuthEnroll() => state.copyWith(busy: true, error: null),
    _ => state,
  };

  AuthState _failed(AuthState state, ConsoleError error) => switch (state) {
    AuthTotp() => state.copyWith(busy: false, error: error),
    AuthEnroll() => state.copyWith(busy: false, error: error),
    _ => AuthState.signedOut(error: error),
  };

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
