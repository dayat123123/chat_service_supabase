import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/entities/link_preview.dart';
import 'package:rendezvous_community/src/features/link_preview/domain/repositories/link_preview_repository.dart';

class LinkPreviewLoader {
  LinkPreviewLoader(
    this._repository, {
    this.batchDelay = const Duration(milliseconds: 80),
    this.retryDelays = const [Duration(seconds: 3), Duration(seconds: 10)],
    this.maxBatch = 20,
    this.maxEntries = 300,
  });

  final LinkPreviewRepository _repository;
  final Duration batchDelay;
  final List<Duration> retryDelays;
  final int maxBatch;
  final int maxEntries;

  final _entries = <String, ValueNotifier<LinkPreview?>>{};
  final _attempts = <String, int>{};
  final _queue = <String>{};
  final _inflight = <String>{};
  final _retries = <String, Timer>{};
  Timer? _batch;
  bool _disposed = false;

  ValueListenable<LinkPreview?> watch(String url) {
    final existing = _entries.remove(url);
    if (existing != null) {
      _entries[url] = existing;
      return existing;
    }
    final notifier = ValueNotifier<LinkPreview?>(null);
    _entries[url] = notifier;
    _evict();
    _enqueue(url);
    return notifier;
  }

  LinkPreview? cached(String url) => _entries[url]?.value;

  void _enqueue(String url) {
    if (_disposed || _inflight.contains(url)) return;
    _queue.add(url);
    _batch ??= Timer(batchDelay, _flush);
  }

  Future<void> _flush() async {
    _batch = null;
    while (_queue.isNotEmpty && !_disposed) {
      final urls = _queue.take(maxBatch).toList();
      _queue.removeAll(urls);
      _inflight.addAll(urls);
      try {
        final previews = await _repository.lookup(urls);
        final byUrl = {for (final p in previews) p.url: p};
        for (final url in urls) {
          _apply(url, byUrl[url] ?? LinkPreview(url: url));
        }
      } catch (_) {
        for (final url in urls) {
          _apply(url, LinkPreview(url: url));
        }
      } finally {
        _inflight.removeAll(urls);
      }
    }
  }

  void _apply(String url, LinkPreview preview) {
    if (_disposed) return;
    final notifier = _entries[url];
    if (notifier == null) return;
    if (preview.status != LinkPreviewStatus.pending) {
      _attempts.remove(url);
      notifier.value = preview;
      return;
    }
    final attempt = _attempts[url] ?? 0;
    if (attempt >= retryDelays.length) {
      _attempts.remove(url);
      notifier.value = preview.copyWith(status: LinkPreviewStatus.none);
      return;
    }
    _attempts[url] = attempt + 1;
    notifier.value = preview;
    _retries[url]?.cancel();
    _retries[url] = Timer(retryDelays[attempt], () {
      _retries.remove(url);
      if (_entries.containsKey(url)) _enqueue(url);
    });
  }

  void _evict() {
    while (_entries.length > maxEntries) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      _retries.remove(oldest)?.cancel();
      _attempts.remove(oldest);
    }
  }

  void clear() {
    for (final timer in _retries.values) {
      timer.cancel();
    }
    _retries.clear();
    _attempts.clear();
    _queue.clear();
    _entries.clear();
  }

  void dispose() {
    _disposed = true;
    _batch?.cancel();
    clear();
  }
}
