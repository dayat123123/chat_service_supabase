import 'dart:async';

import 'package:rendezvous_community/src/features/config/domain/repositories/banner_dismissal_repository.dart';

class BannerDismissals {
  BannerDismissals(this._repository);

  final BannerDismissalRepository _repository;
  final _ids = <String>{};
  final _changes = StreamController<Set<String>>.broadcast();
  Future<void>? _loading;

  Stream<Set<String>> get changes => _changes.stream;

  Set<String> get ids => Set.unmodifiable(_ids);

  Future<Set<String>> load() async {
    await (_loading ??= _load());
    return ids;
  }

  Future<void> _load() async {
    try {
      _ids.addAll(await _repository.load());
    } catch (_) {}
  }

  Future<void> dismiss(String id) async {
    await load();
    if (!_ids.add(id)) return;
    if (!_changes.isClosed) _changes.add(ids);
    try {
      await _repository.save(_ids);
    } catch (_) {}
  }

  void reset() {
    _ids.clear();
    _loading = null;
    if (!_changes.isClosed) _changes.add(ids);
  }

  Future<void> dispose() => _changes.close();
}
