import 'dart:async';

import 'package:flutter/foundation.dart';

class OfficialAccounts extends ValueNotifier<Set<String>> {
  OfficialAccounts(this._load, {this.retryAfter = const Duration(seconds: 30)}) : super(const <String>{});

  final Future<Set<String>> Function() _load;
  final Duration retryAfter;
  bool _requested = false;
  DateTime? _nextTry;

  bool isOfficial(String userId) => value.contains(userId);

  void ensureLoaded() {
    if (_requested) return;
    final next = _nextTry;
    if (next != null && DateTime.now().isBefore(next)) return;
    _requested = true;
    unawaited(_fetch());
  }

  Future<void> reload() {
    _requested = true;
    return _fetch();
  }

  Future<void> _fetch() async {
    try {
      value = await _load();
    } catch (_) {
      _requested = false;
      _nextTry = DateTime.now().add(retryAfter);
    }
  }
}
