import 'dart:async';

import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/push/domain/entities/community_push_message.dart';
import 'package:rendezvous_community/src/features/push/domain/repositories/push_repository.dart';

class PushRegistrar {
  PushRegistrar(this._repository, {required this._currentUserId});

  final PushRepository _repository;
  final String? Function() _currentUserId;
  CommunityPushRegistration? _registration;
  String? _boundTo;

  CommunityPushRegistration? get registration => _registration;

  Future<void> register(CommunityPushRegistration registration) async {
    _registration = registration;
    await _repository.register(registration);
    _boundTo = _currentUserId();
  }

  Future<void> forget() async {
    final registration = _registration;
    _registration = null;
    _boundTo = null;
    if (registration != null) await _repository.unregister(registration.token);
  }

  Future<void> detach() async {
    final registration = _registration;
    if (registration == null || _boundTo == null) return;
    _boundTo = null;
    try {
      await _repository.unregister(registration.token);
    } catch (error) {
      CommunityLoggers.push.warning('Could not unregister the push token on sign-out', error);
    }
  }

  void release() => _boundTo = null;

  void onUserChanged(String? userId) {
    final registration = _registration;
    if (registration == null || userId == null || userId == _boundTo) return;
    unawaited(_rebind(registration));
  }

  Future<void> _rebind(CommunityPushRegistration registration) async {
    try {
      await register(registration);
    } catch (error) {
      CommunityLoggers.push.warning('Could not register the push token for the new session', error);
    }
  }
}
