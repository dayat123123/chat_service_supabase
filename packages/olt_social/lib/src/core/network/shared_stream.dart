import 'dart:async';

class SharedStream<T> {
  SharedStream(this._source);

  final Stream<T> Function() _source;
  late final StreamController<T> _controller = StreamController<T>.broadcast(onListen: _start, onCancel: _stop);
  StreamSubscription<T>? _subscription;

  Stream<T> get stream => _controller.stream;

  void _start() {
    _subscription = _source().listen(_controller.add, onError: _controller.addError);
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> close() async {
    await _stop();
    await _controller.close();
  }
}
