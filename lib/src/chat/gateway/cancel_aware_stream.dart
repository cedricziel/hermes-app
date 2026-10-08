import 'dart:async';

/// Set once the listener of a [CancelAwareStream] has cancelled it.
class CancelFlag {
  bool value = false;
}

/// A stream that raises [flag] the moment its listener cancels, before the
/// cancel reaches [source].
///
/// An `async*` generator only sees a cancel at its next `yield`, which a long
/// `await` (a reconnect, say) may be far from. The flag is visible to that
/// `await` at once. Everything else, pause and resume included, goes straight
/// to the subscription to [source].
class CancelAwareStream<T> extends Stream<T> {
  CancelAwareStream(this._source, this.flag);

  final Stream<T> _source;
  final CancelFlag flag;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _CancelAwareSubscription(
    _source.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
    flag,
  );
}

class _CancelAwareSubscription<T> implements StreamSubscription<T> {
  _CancelAwareSubscription(this._inner, this._flag);

  final StreamSubscription<T> _inner;
  final CancelFlag _flag;

  @override
  Future<void> cancel() {
    _flag.value = true;
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
