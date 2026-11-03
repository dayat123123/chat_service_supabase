import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:rendezvous_community/src/core/error/community_exception.dart';
import 'package:rendezvous_community/src/core/error/error_mapper.dart';
import 'package:rendezvous_community/src/core/logging/community_logger.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/chat_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/entities/outbox_message.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:rendezvous_community/src/features/chat/domain/repositories/outbox_repository.dart';

typedef OutboxGuard = Future<ChatMessage> Function(Future<ChatMessage> Function() send);

sealed class OutboxEvent {
  const OutboxEvent(this.roomId, this.clientId);

  final String roomId;
  final String clientId;
}

class OutboxChanged extends OutboxEvent {
  OutboxChanged(this.message) : super(message.roomId, message.clientId);

  final OutboxMessage message;
}

class OutboxDelivered extends OutboxEvent {
  OutboxDelivered(String clientId, this.message) : super(message.roomId, clientId);

  final ChatMessage message;
}

class OutboxRemoved extends OutboxEvent {
  const OutboxRemoved(super.roomId, super.clientId);
}

sealed class OutboxResult {
  const OutboxResult();
}

class OutboxSent extends OutboxResult {
  const OutboxSent(this.message);

  final ChatMessage message;
}

class OutboxQueued extends OutboxResult {
  const OutboxQueued(this.message, this.error);

  final OutboxMessage message;
  final CommunityException error;
}

class OutboxFailed extends OutboxResult {
  const OutboxFailed(this.message, this.error);

  final OutboxMessage message;
  final CommunityException error;
}

class OutboxBusy extends OutboxResult {
  const OutboxBusy();
}

bool isTransientSendError(CommunityException error) => switch (error.kind) {
  CommunityErrorKind.network || CommunityErrorKind.unavailable || CommunityErrorKind.unauthenticated => true,
  _ => false,
};

bool isRateLimitedSendError(CommunityException error) =>
    error.code == 'slow_mode' || error.kind == CommunityErrorKind.rateLimited;

Duration? outboxRetryDelay(
  CommunityException error, {
  required int attempts,
  required bool interactive,
  Duration baseDelay = const Duration(seconds: 2),
  Duration maxDelay = const Duration(minutes: 1),
  int maxRateLimitAttempts = 3,
}) {
  final backoff = baseDelay * pow(2, max(0, attempts - 1)).toInt();
  final capped = backoff > maxDelay ? maxDelay : backoff;
  if (isTransientSendError(error)) return capped;
  if (isRateLimitedSendError(error) && !interactive && attempts < maxRateLimitAttempts) {
    final wait = error.retryAfter;
    return wait != null && wait > Duration.zero ? wait : capped;
  }
  return null;
}

class MessageOutbox {
  MessageOutbox(
    this._chat,
    this._store, {
    DateTime Function()? clock,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 1),
    this.maxRateLimitAttempts = 3,
  }) : _clock = clock ?? DateTime.now;

  final ChatRepository _chat;
  final OutboxRepository _store;
  final DateTime Function() _clock;
  final Duration baseDelay;
  final Duration maxDelay;
  final int maxRateLimitAttempts;
  final _events = StreamController<OutboxEvent>.broadcast();
  final _inFlight = <String>{};
  Timer? _timer;
  Future<void>? _flushing;
  int _generation = 0;
  bool _disposed = false;

  Stream<OutboxEvent> get events => _events.stream;

  Stream<OutboxEvent> eventsFor(String roomId) => _events.stream.where((event) => event.roomId == roomId);

  DateTime _now() => _clock().toUtc();

  Future<List<OutboxMessage>> messages(String roomId) async => [
    for (final message in await _store.load())
      if (message.roomId == roomId) message,
  ];

  Future<OutboxResult> send(OutboxMessage message, {OutboxGuard? guard}) async {
    final queued = message.copyWith(state: OutboxState.pending, attempts: 0, error: null, nextAttemptAt: null);
    Future<List<OutboxMessage>> ahead() async => [
      for (final m in await messages(message.roomId))
        if (!m.isFailed && m.clientId != message.clientId && !m.createdAt.isAfter(message.createdAt)) m,
    ];
    if ((await ahead()).isNotEmpty) await flush(force: true);
    await _store.save(queued);
    final blocking = await ahead();
    if (blocking.isNotEmpty) {
      _emit(OutboxChanged(queued));
      await _schedule();
      return OutboxQueued(queued, blocking.first.error ?? const CommunityException(CommunityErrorKind.network));
    }
    return _attempt(queued, guard: guard, interactive: true);
  }

  Future<void> discard(String clientId) async {
    final message = await _find(clientId);
    if (message == null || _inFlight.contains(clientId)) return;
    await _store.remove(clientId);
    _emit(OutboxRemoved(message.roomId, clientId));
  }

  Future<void> flush({bool force = false}) {
    if (_disposed) return Future.value();
    final running = _flushing;
    if (running != null) return running;
    final run = _flush(force: force).whenComplete(() => _flushing = null);
    _flushing = run;
    return run;
  }

  Future<void> _flush({required bool force}) async {
    final generation = _generation;
    final blocked = <String>{};
    try {
      for (final message in await _store.load()) {
        if (generation != _generation || _disposed) return;
        if (message.isFailed || blocked.contains(message.roomId)) continue;
        final due = message.nextAttemptAt;
        if (!force && due != null && due.isAfter(_now())) {
          blocked.add(message.roomId);
          continue;
        }
        final result = await _attempt(message, interactive: false);
        if (result is OutboxQueued || result is OutboxBusy) blocked.add(message.roomId);
        if (result is OutboxQueued && isTransientSendError(result.error)) break;
      }
    } finally {
      await _schedule();
    }
  }

  void reset() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<OutboxMessage?> _find(String clientId) async =>
      (await _store.load()).where((m) => m.clientId == clientId).firstOrNull;

  Future<OutboxResult> _attempt(OutboxMessage message, {OutboxGuard? guard, required bool interactive}) async {
    if (!_inFlight.add(message.clientId)) return const OutboxBusy();
    final generation = _generation;
    _emit(OutboxChanged(message.copyWith(state: OutboxState.sending)));
    try {
      Future<ChatMessage> deliver() => _chat.sendMessage(
        message.roomId,
        body: message.body,
        clientId: message.clientId,
        replyToId: message.replyToId,
      );
      final sent = await (guard == null ? deliver() : guard(deliver));
      if (generation == _generation) {
        await _store.remove(message.clientId);
        _emit(OutboxDelivered(message.clientId, sent));
        if (interactive) {
          _inFlight.remove(message.clientId);
          await _schedule();
        }
      }
      if (message.attempts > 0) {
        CommunityLoggers.chat.event(
          Level.FINE,
          'Queued message sent',
          fields: {'roomId': message.roomId, 'clientId': message.clientId, 'attemptCount': message.attempts + 1},
        );
      }
      return OutboxSent(sent);
    } catch (e) {
      final error = mapError(e);
      final attempts = message.attempts + 1;
      final delay = outboxRetryDelay(
        error,
        attempts: attempts,
        interactive: interactive,
        baseDelay: baseDelay,
        maxDelay: maxDelay,
        maxRateLimitAttempts: maxRateLimitAttempts,
      );
      final next = delay == null
          ? message.copyWith(state: OutboxState.failed, attempts: attempts, error: error, nextAttemptAt: null)
          : message.copyWith(
              state: OutboxState.pending,
              attempts: attempts,
              error: error,
              nextAttemptAt: _now().add(delay),
            );
      if (generation == _generation) {
        await _store.save(next);
        _emit(OutboxChanged(next));
      }
      CommunityLoggers.chat.event(
        delay == null ? Level.WARNING : Level.FINE,
        delay == null ? 'Queued message failed' : 'Message queued for retry',
        fields: {
          'roomId': message.roomId,
          'clientId': message.clientId,
          'attemptCount': attempts,
          'kind': error.kind,
          'code': error.code,
          if (delay != null) 'delayMs': delay.inMilliseconds,
        },
      );
      if (interactive && delay != null) {
        _inFlight.remove(message.clientId);
        await _schedule();
      }
      return delay == null ? OutboxFailed(next, error) : OutboxQueued(next, error);
    } finally {
      _inFlight.remove(message.clientId);
    }
  }

  Future<void> _schedule() async {
    if (_disposed) return;
    final heads = <String, OutboxMessage>{};
    for (final message in await _store.load()) {
      if (!message.isFailed) heads.putIfAbsent(message.roomId, () => message);
    }
    final due = [
      for (final message in heads.values)
        if (!_inFlight.contains(message.clientId)) message.nextAttemptAt ?? _now(),
    ];
    _timer?.cancel();
    _timer = null;
    if (due.isEmpty || _disposed) return;
    final next = due.reduce((a, b) => a.isBefore(b) ? a : b);
    final wait = next.difference(_now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _timer = null;
      unawaited(flush());
    });
  }

  void _emit(OutboxEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> dispose() async {
    _disposed = true;
    reset();
    await _events.close();
  }
}
