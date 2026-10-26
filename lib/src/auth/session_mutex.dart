import 'dart:async';

/// A short critical section for secure-storage mutations, never HTTP work.
abstract interface class SessionMutex {
  Future<T> run<T>(Future<T> Function() body);
}

/// For injected stores in tests. Production uses a cross-engine native lock.
class MemorySessionMutex implements SessionMutex {
  Future<void> _tail = Future.value();

  @override
  Future<T> run<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
