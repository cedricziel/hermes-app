/// Why a curator call did not produce a value. A kind only: the server's own
/// words (they can name a profile or a server path) and the request that
/// failed (its URL carries the profile) never travel with it.
enum CuratorFailure {
  /// The request never left the device: no connection.
  offline,

  /// A read that got no answer in time. Reads may be repeated.
  timeout,

  /// 401 or 403 after the auth interceptor gave up.
  unauthorized,

  /// Hermes rejected the request (400, 422, another 4xx): nothing changed and
  /// nothing started.
  refused,

  /// 500 "Curator unavailable": the curator module could not load.
  unavailable,

  /// A run Hermes could not spawn: nothing started.
  spawnFailed,

  /// Any other answer of Hermes that says it failed.
  server,

  /// A read whose answer is not an object.
  unreadable,

  /// A pause or a run that got no usable answer, or one that is not Hermes':
  /// it may have been done. Settled by reading, never by sending again.
  lostAnswer,
}

/// The outcome of a curator call. The repository answers one of these
/// instead of throwing.
sealed class CuratorResult<T> {
  const CuratorResult();
}

final class CuratorOk<T> extends CuratorResult<T> {
  const CuratorOk(this.value);

  final T value;
}

/// The server has no such route (404 or 405, or a page where JSON was
/// expected): the curator section is hidden, not shown as an error.
final class CuratorUnsupported<T> extends CuratorResult<T> {
  const CuratorUnsupported();
}

/// Hermes says the profile does not exist (a 404 whose detail starts
/// `Profile '`, or a run's 500 that carries that 404). Not an old server.
final class CuratorProfileGone<T> extends CuratorResult<T> {
  const CuratorProfileGone();
}

final class CuratorFailed<T> extends CuratorResult<T> {
  const CuratorFailed(this.kind);

  final CuratorFailure kind;

  @override
  String toString() => 'CuratorFailed(${kind.name})';
}

/// `POST /api/curator/run` was accepted: a child process was spawned. How it
/// ends is read from the action status.
class CuratorRunStarted {
  const CuratorRunStarted();
}
