import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/legal/domain/entities/legal_document.dart';
import 'package:rendezvous_community/src/features/legal/domain/repositories/legal_repository.dart';

class CommunityConsent extends ChangeNotifier {
  CommunityConsent(this._repository, {this.retryAfter = const Duration(seconds: 30), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LegalRepository _repository;
  final Duration retryAfter;
  final DateTime Function() _clock;

  List<LegalDocument>? _documents;
  Future<List<LegalDocument>>? _inflight;
  Future<bool>? _prompting;
  final _dismissed = <String>{};
  String? _userId;
  DateTime? _nextTry;
  int _sequence = 0;
  bool _disposed = false;

  List<LegalDocument>? get loaded => _documents;

  List<LegalDocument> get pendingNow => [
    for (final document in _documents ?? const <LegalDocument>[])
      if (document.isPending) document,
  ];

  List<LegalDocument> get bannerDocuments => [
    for (final document in pendingNow)
      if (!_dismissed.contains(document.id)) document,
  ];

  Future<List<LegalDocument>> documents({bool refresh = false}) {
    final cached = _documents;
    if (cached != null && !refresh) return Future.value(cached);
    final inflight = _inflight;
    if (inflight != null && !refresh) return inflight;
    final future = _load(++_sequence);
    _inflight = future;
    future.whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    }).ignore();
    return future;
  }

  Future<List<LegalDocument>> pending({bool refresh = false}) async => [
    for (final document in await documents(refresh: refresh))
      if (document.isPending) document,
  ];

  void ensureLoaded() {
    if (_documents != null || _inflight != null || _userId == null) return;
    final next = _nextTry;
    if (next != null && _clock().isBefore(next)) return;
    unawaited(documents().then<void>((_) {}, onError: (Object _) {}));
  }

  Future<void> accept(Iterable<String> documentIds) async {
    final ids = documentIds.toSet();
    for (final id in ids) {
      await _repository.accept(id);
    }
    final current = _documents;
    if (current != null) {
      _set([for (final d in current) ids.contains(d.id) ? d.copyWith(isAccepted: true) : d]);
    }
    try {
      await documents(refresh: true);
    } catch (_) {}
  }

  void dismissBanner() {
    _dismissed.addAll(pendingNow.map((document) => document.id));
    _notify();
  }

  Future<bool> prompt(Future<bool> Function() show) => _prompting ??= show().whenComplete(() => _prompting = null);

  void onUserChanged(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _sequence++;
    _documents = null;
    _inflight = null;
    _nextTry = null;
    _dismissed.clear();
    _notify();
    if (userId != null) ensureLoaded();
  }

  Future<List<LegalDocument>> _load(int sequence) async {
    try {
      final documents = await _repository.getDocuments();
      if (sequence == _sequence) {
        _nextTry = null;
        _set(documents);
      }
      return documents;
    } catch (error) {
      if (sequence == _sequence) _nextTry = _clock().add(retryAfter);
      final mapped = mapError(error);
      CommunityLoggers.account.event(
        Level.WARNING,
        'Could not load legal documents',
        fields: {'kind': mapped.kind, 'code': mapped.code},
      );
      throw mapped;
    }
  }

  void _set(List<LegalDocument> documents) {
    _documents = List.unmodifiable(documents);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
