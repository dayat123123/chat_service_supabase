import 'dart:async';

import 'package:cs_console/src/l10n/l10n.dart';
import 'package:flutter/material.dart';

class IdleGuard extends StatefulWidget {
  const IdleGuard({
    super.key,
    required this.timeout,
    required this.onTimeout,
    this.warning = const Duration(seconds: 60),
    required this.child,
  });

  final Duration timeout;
  final Duration warning;
  final VoidCallback onTimeout;
  final Widget child;

  @override
  State<IdleGuard> createState() => _IdleGuardState();
}

class _IdleGuardState extends State<IdleGuard> {
  DateTime _lastActivity = DateTime.now();
  Timer? _ticker;
  bool _warning = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _touch() {
    _lastActivity = DateTime.now();
    if (_warning) setState(() => _warning = false);
  }

  void _check() {
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= widget.timeout) {
      _ticker?.cancel();
      widget.onTimeout();
      return;
    }
    final warn = idle >= widget.timeout - widget.warning;
    if (warn != _warning || warn) setState(() => _warning = warn);
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.timeout - DateTime.now().difference(_lastActivity);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      onPointerHover: (_) => _touch(),
      onPointerSignal: (_) => _touch(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, _) {
          _touch();
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            widget.child,
            if (_warning) _IdleWarning(secondsLeft: left.inSeconds.clamp(0, 9999), onStay: _touch),
          ],
        ),
      ),
    );
  }
}

class _IdleWarning extends StatelessWidget {
  const _IdleWarning({required this.secondsLeft, required this.onStay});

  final int secondsLeft;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(l10n.idleTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(l10n.idleBody(secondsLeft), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: onStay, child: Text(l10n.idleStay)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
